import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../platform/links/page_reload.dart';
import '../transport/supabase_backend.dart';
import '../ui/l10n_ext.dart';
import '../ui/screens/online/online_session.dart';
import '../ui/theme/design_tokens.dart';
import '../ui/theme/mafia_theme.dart';
import 'app_build.dart';

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

/// The server's minimum build per platform (`public.app_min_build()`).
/// 0 means no minimum.
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
    int number(Object? v) => v is num && v >= 0 ? v.toInt() : 0;
    return MinBuild(android: number(json['android']), web: number(json['web']));
  }

  /// Whether a build numbered [build] on [surface] is below the minimum.
  bool blocks(int build, UpdateSurface surface) => switch (surface) {
    UpdateSurface.android => android > build,
    UpdateSurface.web => web > build,
    UpdateSurface.other => false,
  };
}

typedef MinBuildFetch = Future<MinBuild> Function();

/// Reads the minimum from the server with the publishable key and no session,
/// like `server_now()`: a build too old to sign in must still be told to
/// update. Every failure (no server in this build, offline, an older server
/// without the function) is [MinBuild.none].
final minBuildFetchProvider = Provider<MinBuildFetch>((ref) {
  return () async {
    if (!SupabaseConfig.isConfigured) return MinBuild.none;
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      if (backend is! SupabaseBackend) return MinBuild.none;
      final json = await backend.client
          .rpc('app_min_build')
          .timeout(UpdateGateTokens.fetchTimeout);
      return MinBuild.fromJson(json);
    } catch (_) {
      return MinBuild.none;
    }
  };
});

/// Opens this app's Play Store page (Android).
typedef StoreOpener = Future<void> Function();

final storeOpenerProvider = Provider<StoreOpener>(
  (ref) =>
      () => InAppReview.instance.openStoreListing(),
);

/// Blocks the app behind «حدّث التطبيق» when the server's minimum build is
/// above this one. A pass-through otherwise, including whenever the server
/// cannot be asked: an update prompt is never a reason to lose the game.
///
/// Mounted above the router (like the other gates), so it draws its own sheet
/// over everything instead of asking a navigator for one.
class UpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  static const sheetKey = ValueKey('update_required_sheet');
  static const storeKey = ValueKey('update_required_store');
  static const reloadKey = ValueKey('update_required_reload');

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate>
    with WidgetsBindingObserver {
  bool _required = false;
  DateTime? _checked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _required) return;
    final last = _checked;
    if (last == null ||
        DateTime.now().difference(last) >= UpdateGateTokens.recheck) {
      _check();
    }
  }

  Future<void> _check() async {
    _checked = DateTime.now();
    final minimum = await ref.read(minBuildFetchProvider)();
    if (!mounted) return;
    final blocked = minimum.blocks(
      ref.read(appBuildNumberProvider),
      ref.read(updateSurfaceProvider),
    );
    if (blocked != _required) setState(() => _required = blocked);
  }

  @override
  Widget build(BuildContext context) {
    // The child is always the first, unconditional entry of the same Stack,
    // so raising the sheet never remounts the router underneath it.
    return Stack(
      children: [
        // Nothing underneath can be tapped or read while the sheet is up.
        ExcludeSemantics(
          excluding: _required,
          child: IgnorePointer(ignoring: _required, child: widget.child),
        ),
        if (_required) ...[
          Positioned.fill(
            child: ModalBarrier(
              dismissible: false,
              color: context.colors.surfaceOverlay.withValues(
                alpha: UpdateGateTokens.scrimAlpha,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _UpdateSheet(
              web: ref.read(updateSurfaceProvider) == UpdateSurface.web,
            ),
          ),
        ],
      ],
    );
  }
}

class _UpdateSheet extends ConsumerWidget {
  final bool web;
  const _UpdateSheet({required this.web});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return Material(
      key: UpdateGate.sheetKey,
      color: colors.surfaceBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radii.card),
        ),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(s.screenMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: s.maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.system_update_alt_rounded,
                  size: UpdateGateTokens.iconSize,
                  color: colors.accentGold,
                ),
                SizedBox(height: s.sm),
                Semantics(
                  header: true,
                  child: Text(
                    l.updateRequiredTitle,
                    textAlign: TextAlign.center,
                    style: type.headline.copyWith(color: colors.textPrimary),
                  ),
                ),
                SizedBox(height: s.sm),
                Text(
                  l.updateRequiredBody,
                  textAlign: TextAlign.center,
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: s.lg),
                if (web)
                  FilledButton(
                    key: UpdateGate.reloadKey,
                    onPressed: ref.read(pageReloaderProvider),
                    child: Text(l.updateRequiredReload),
                  )
                else
                  FilledButton(
                    key: UpdateGate.storeKey,
                    onPressed: () async {
                      try {
                        await ref.read(storeOpenerProvider)();
                      } catch (_) {
                        /* The button stays; Play can also be opened by hand. */
                      }
                    },
                    child: Text(l.updateRequiredStore),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
