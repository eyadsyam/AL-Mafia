import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';

import '../platform/links/page_reload.dart';
import '../transport/supabase_backend.dart';
import '../ui/l10n_ext.dart';
import '../ui/screens/online/online_session.dart';
import '../ui/social/invite_privacy.dart';
import '../ui/theme/design_tokens.dart';
import '../ui/theme/mafia_theme.dart';
import 'app_build.dart';
import 'router.dart' show Routes;

/// Where this build runs, as far as the minimum-build check cares.
enum UpdateSurface { android, web, other }

final updateSurfaceProvider = Provider<UpdateSurface>((ref) {
  if (kIsWeb) return UpdateSurface.web;
  return defaultTargetPlatform == TargetPlatform.android
      ? UpdateSurface.android
      : UpdateSurface.other;
});

/// This build's number; overridable so a test can be "an old build".
final appBuildNumberProvider = Provider<int>((ref) => kAppBuildNumber);

/// Anything unreadable is zero ("nothing announced"): a malformed answer must
/// never lock a player out of a game that works, nor nag them.
int _count(Object? v) => v is num && v.isFinite && v >= 0 ? v.toInt() : 0;

/// The server's minimum build per platform. 0 means no minimum.
@immutable
class MinBuild {
  final int android;
  final int web;
  const MinBuild({this.android = 0, this.web = 0});

  static const none = MinBuild();

  /// Anything unreadable is "no minimum": a malformed answer must never lock
  /// a player out of a game that works.
  factory MinBuild.fromJson(Object? json) {
    if (json is! Map) return none;
    return MinBuild(android: _count(json['android']), web: _count(json['web']));
  }

  /// Whether a build numbered [build] on [surface] is below the minimum.
  bool blocks(int build, UpdateSurface surface) => switch (surface) {
    UpdateSurface.android => android > build,
    UpdateSurface.web => web > build,
    UpdateSurface.other => false,
  };
}

/// Where the ad banner lives, as the server says (`app_config.banner_mode`).
/// Anything unknown is [perScreen]: the layout the shipped builds already use.
enum BannerMode {
  perScreen,
  shell;

  static BannerMode parse(Object? value) =>
      value == 'shell' ? BannerMode.shell : BannerMode.perScreen;

  String get wire => this == BannerMode.shell ? 'shell' : 'per_screen';
}

/// The last banner mode the server announced (the cached one when offline).
/// Nothing reads it yet; it is here so the shell banner can follow the server
/// without another request.
final bannerModeProvider = StateProvider<BannerMode>(
  (_) => BannerMode.perScreen,
);

/// The one row of `public.app_config`: the minimum build (hard block), the
/// newest build (soft «فيه نسخة جديدة») and the banner mode.
@immutable
class UpdatePolicy {
  final MinBuild min;
  final int latestAndroid;
  final int latestWeb;
  final BannerMode bannerMode;

  const UpdatePolicy({
    this.min = MinBuild.none,
    this.latestAndroid = 0,
    this.latestWeb = 0,
    this.bannerMode = BannerMode.perScreen,
  });

  static const none = UpdatePolicy();

  /// [json] is a row as the server (or the cache) gives it. A missing column
  /// (an older server) is zero; a malformed value is zero; none of it throws.
  factory UpdatePolicy.fromJson(Object? json) {
    if (json is! Map) return none;
    return UpdatePolicy(
      min: MinBuild(
        android: _count(json['min_build_android']),
        web: _count(json['min_build_web']),
      ),
      latestAndroid: _count(json['latest_build_android']),
      latestWeb: _count(json['latest_build_web']),
      bannerMode: BannerMode.parse(json['banner_mode']),
    );
  }

  Map<String, Object?> toJson() => {
    'min_build_android': min.android,
    'min_build_web': min.web,
    'latest_build_android': latestAndroid,
    'latest_build_web': latestWeb,
    'banner_mode': bannerMode.wire,
  };

  /// Below the minimum: the blocking screen.
  bool blocks(int build, UpdateSurface surface) => min.blocks(build, surface);

  /// At or above the minimum but below the newest: the soft sheet.
  bool offersSoft(int build, UpdateSurface surface) {
    if (blocks(build, surface)) return false;
    return switch (surface) {
      UpdateSurface.android => latestAndroid > build,
      UpdateSurface.web => latestWeb > build,
      UpdateSurface.other => false,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is UpdatePolicy &&
      other.min.android == min.android &&
      other.min.web == min.web &&
      other.latestAndroid == latestAndroid &&
      other.latestWeb == latestWeb &&
      other.bannerMode == bannerMode;

  @override
  int get hashCode =>
      Object.hash(min.android, min.web, latestAndroid, latestWeb, bannerMode);
}

/// `null` means "could not ask" (offline, timeout, no server in this build);
/// the gate then falls back to the last good answer.
typedef UpdatePolicyFetch = Future<UpdatePolicy?> Function();

/// Reads the policy from the server (`public.app_config`, public config
/// readable with the publishable key alone, migration 20261001000100).
///
/// It never signs anybody in: a launch must not create an anonymous user just
/// to ask a question (per-IP sign-in limits, bot visits). With no session the
/// request simply goes out as `anon`.
///
/// A server that has not had migration 20261029000100 yet answers the first
/// request with a column error; the read is then repeated for the two minimum
/// columns alone, so an old server behaves exactly as before.
final updatePolicyFetchProvider = Provider<UpdatePolicyFetch>((ref) {
  return () async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      if (backend is! SupabaseBackend) return null;
      Future<Map<String, dynamic>?> read(String columns) => backend.client
          .from('app_config')
          .select(columns)
          .maybeSingle()
          .timeout(UpdateGateTokens.fetchTimeout);
      Map<String, dynamic>? row;
      try {
        row = await read(
          'min_build_android, min_build_web, latest_build_android, '
          'latest_build_web, banner_mode',
        );
      } on PostgrestException {
        // The server answered, but without the new columns.
        row = await read('min_build_android, min_build_web');
      }
      return UpdatePolicy.fromJson(row);
    } catch (_) {
      return null;
    }
  };
});

/// The last good policy, kept so a launch without a network still knows it.
abstract class UpdatePolicyCache {
  Future<UpdatePolicy?> load();
  Future<void> save(UpdatePolicy policy);
}

class PrefsUpdatePolicyCache implements UpdatePolicyCache {
  const PrefsUpdatePolicyCache();

  static const key = 'mafia.updatePolicy.v1';

  @override
  Future<UpdatePolicy?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null) return null;
      return UpdatePolicy.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(UpdatePolicy policy) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode(policy.toJson()),
      );
    } catch (_) {
      /* A cache that cannot be written is just no cache. */
    }
  }
}

final updatePolicyCacheProvider = Provider<UpdatePolicyCache>(
  (ref) => const PrefsUpdatePolicyCache(),
);

/// Opens one address outside the app; false (or a throw) when nothing handled it.
typedef StoreLauncher = Future<bool> Function(Uri uri);

final storeLauncherProvider = Provider<StoreLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Opens this app's Play Store page (Android): the Play app through `market:`
/// first, then the web page. True when one of them opened.
typedef StoreOpener = Future<bool> Function();

final storeOpenerProvider = Provider<StoreOpener>((ref) {
  final launch = ref.read(storeLauncherProvider);
  return () async {
    for (final uri in UpdateGateTokens.storeUris) {
      try {
        if (await launch(uri)) return true;
      } catch (_) {
        /* Try the next address. */
      }
    }
    return false;
  };
});

/// Raises «حدّث التطبيق» when the server's minimum build is above this one, and
/// «فيه نسخة جديدة» (once per launch, Home only) when a newer build exists. A
/// pass-through otherwise, including whenever the server cannot be asked: an
/// update prompt is never a reason to lose the game.
///
/// Mounted above the router (like the other gates), so it draws its own screen
/// over everything instead of asking a navigator for one. That is also why it
/// is told where the router is: [currentPath] and [routeChanges].
class UpdateGate extends ConsumerStatefulWidget {
  final Widget child;

  /// The router's current path. Without it the soft sheet is never shown (it
  /// must not appear anywhere but Home); the hard block needs no path.
  final String Function()? currentPath;

  /// Notifies when the router's location may have changed.
  final Listenable? routeChanges;

  const UpdateGate({
    super.key,
    required this.child,
    this.currentPath,
    this.routeChanges,
  });

  static const sheetKey = ValueKey('update_required_sheet');
  static const storeKey = ValueKey('update_required_store');
  static const reloadKey = ValueKey('update_required_reload');
  static const softKey = ValueKey('update_soft_sheet');
  static const laterKey = ValueKey('update_soft_later');
  static const failedKey = ValueKey('update_store_failed');

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate>
    with WidgetsBindingObserver {
  UpdatePolicy _policy = UpdatePolicy.none;
  bool _fresh = false; // a real answer from the server this launch
  bool _hard = false;
  bool _softShowing = false;
  bool _softUsed = false; // once per launch, shown or not
  DateTime? _checked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.routeChanges?.addListener(_routeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    widget.routeChanges?.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The system back button while a screen is up never reaches the router
  /// underneath: on «حدّث التطبيق» it leaves the app (there is nothing else
  /// to go back to), on «فيه نسخة جديدة» it means «بعدين».
  @override
  Future<bool> didPopRoute() async {
    if (_hard) {
      await SystemNavigator.pop();
      return true;
    }
    if (_softShowing) {
      _later();
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _hard) return;
    final last = _checked;
    if (last == null ||
        DateTime.now().difference(last) >= UpdateGateTokens.recheck) {
      _check();
    }
  }

  // The router can notify in the middle of a build: look after the frame.
  void _routeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _evaluate();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  bool get _onHome => widget.currentPath?.call() == Routes.home;

  Future<void> _check() async {
    _checked = DateTime.now();
    final fetched = await ref.read(updatePolicyFetchProvider)();
    if (!mounted) return;
    if (fetched != null) {
      _fresh = true;
      unawaited(ref.read(updatePolicyCacheProvider).save(fetched));
      _apply(fetched);
      return;
    }
    // Could not ask. The last good answer stands, but a real one from this
    // launch is never replaced by an older one, and with nothing cached
    // nothing is shown: offline never blocks on its own.
    if (_fresh) return;
    final cached = await ref.read(updatePolicyCacheProvider).load();
    if (!mounted || _fresh || cached == null) return;
    _apply(cached);
  }

  void _apply(UpdatePolicy policy) {
    _policy = policy;
    ref.read(bannerModeProvider.notifier).state = policy.bannerMode;
    _evaluate();
  }

  void _evaluate() {
    final build = ref.read(appBuildNumberProvider);
    final surface = ref.read(updateSurfaceProvider);
    final hard = _policy.blocks(build, surface);
    var soft = _softShowing;
    if (hard) {
      soft = false;
    } else if (soft) {
      // Left Home (a push, an invite): it goes, and does not come back.
      if (!_onHome) soft = false;
    } else if (!_softUsed &&
        _policy.offersSoft(build, surface) &&
        _onHome &&
        !ref.read(privateMomentProvider)) {
      soft = true;
      _softUsed = true;
    }
    if (hard != _hard || soft != _softShowing) {
      setState(() {
        _hard = hard;
        _softShowing = soft;
      });
    }
  }

  void _later() => setState(() => _softShowing = false);

  @override
  Widget build(BuildContext context) {
    final covered = _hard || _softShowing;
    final web = ref.read(updateSurfaceProvider) == UpdateSurface.web;
    // The child is always the first, unconditional entry of the same Stack,
    // so raising the screen never remounts the router underneath it.
    return Stack(
      children: [
        // Nothing underneath can be tapped or read while the screen is up.
        ExcludeSemantics(
          excluding: covered,
          child: IgnorePointer(ignoring: covered, child: widget.child),
        ),
        if (covered)
          Positioned.fill(
            child: _UpdateScreen(
              key: _hard ? UpdateGate.sheetKey : UpdateGate.softKey,
              web: web,
              soft: !_hard,
              onLater: _later,
            ),
          ),
      ],
    );
  }
}

/// «حدّث التطبيق» (hard) or «فيه نسخة جديدة» (soft, with «بعدين»): the same
/// centred screen, drawn over the whole app.
class _UpdateScreen extends ConsumerStatefulWidget {
  final bool web;
  final bool soft;
  final VoidCallback onLater;
  const _UpdateScreen({
    super.key,
    required this.web,
    required this.soft,
    required this.onLater,
  });

  @override
  ConsumerState<_UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<_UpdateScreen> {
  bool _failed = false;
  bool _opening = false;

  Future<void> _openStore() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened = await ref.read(storeOpenerProvider)();
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failed = !opened;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final soft = widget.soft;
    // The web has no store line; its soft screen keeps just the title.
    final showBody = !(soft && widget.web);
    return Material(
      color: colors.surfaceBase,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: EdgeInsets.all(s.screenMargin),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0.0, box.maxHeight - 2 * s.screenMargin),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: s.maxContentWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          soft ? l.updateSoftTitle : l.updateRequiredTitle,
                          textAlign: TextAlign.center,
                          style: type.headline.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (showBody) ...[
                        SizedBox(height: s.sm),
                        Text(
                          soft ? l.updateSoftBody : l.updateRequiredBody,
                          textAlign: TextAlign.center,
                          style: type.body.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      SizedBox(height: s.lg),
                      if (widget.web)
                        FilledButton(
                          key: UpdateGate.reloadKey,
                          onPressed: ref.read(pageReloaderProvider),
                          child: Text(l.updateRequiredReload),
                        )
                      else
                        FilledButton(
                          key: UpdateGate.storeKey,
                          onPressed: _opening ? null : _openStore,
                          child: Text(
                            soft ? l.updateSoftNow : l.updateRequiredStore,
                          ),
                        ),
                      if (_failed) ...[
                        SizedBox(height: s.md),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            key: UpdateGate.failedKey,
                            padding: EdgeInsets.symmetric(
                              horizontal: s.md,
                              vertical: s.sm,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceOverlay,
                              borderRadius: BorderRadius.circular(
                                UpdateGateTokens.noteRadius,
                              ),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Text(
                              l.updateStoreFailed,
                              textAlign: TextAlign.center,
                              style: type.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (soft) ...[
                        SizedBox(height: s.sm),
                        TextButton(
                          key: UpdateGate.laterKey,
                          onPressed: widget.onLater,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                          ),
                          child: Text(l.updateSoftLater),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
