import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/asset_constants.dart';
import '../../data/online_session_store.dart';
import '../../data/player_profile.dart';
import '../../data/repository_provider.dart';
import '../../data/terms_consent.dart';
import '../../platform/audio_director.dart';
import '../../platform/monetization/ad_formats.dart';
import '../../platform/monetization/app_open_policy.dart';
import '../../platform/monetization/full_screen_away.dart';
import '../../platform/reduce_motion.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/splash_gate.dart';
import 'economy_capabilities.dart';
import 'interstitial_coordinator.dart';

/// Wall clock for the app-open coordinator; a test replaces it.
final appOpenClockProvider = Provider<int Function()>(
  (ref) =>
      () => DateTime.now().millisecondsSinceEpoch,
);

/// Owns the device-side counters of the app-open ad and asks
/// [decideAppOpen] before anything is loaded or shown.
///
/// Best effort, never blocking: everything runs inside
/// [AdTokens.appOpenLoadTimeout]; a failed read counts as "no ad".
class AppOpenCoordinator {
  AppOpenCoordinator(this._ref);
  final Ref _ref;

  static const _key = 'app_open_ledger_v1';
  AppOpenLedger? _cache;
  bool _running = false;

  int _now() => _ref.read(appOpenClockProvider)();

  Future<AppOpenLedger> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      _cache = raw == null
          ? AppOpenLedger.empty
          : AppOpenLedger.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
    } catch (_) {
      _cache = AppOpenLedger.empty;
    }
    return _cache!;
  }

  Future<void> _save(AppOpenLedger ledger) async {
    _cache = ledger;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(ledger.toJson()));
    } catch (_) {}
  }

  /// The server answered (read anywhere in the app): remembered so the next
  /// launch knows without asking whether the feature is on at all.
  Future<void> remember(EconomyCapabilities caps) async {
    if (caps.failed) return;
    final ledger = await _load();
    await _save(
      ledger.known(enabled: caps.ads.appOpen.enabled, adFree: caps.adFree),
    );
  }

  Future<void> backgrounded() async =>
      _save((await _load()).backgrounded(_now()));

  /// Without any network: whether a return right now could show an ad, so
  /// the launch screen is raised only when it might be needed.
  Future<bool> mightShowOnResume() async {
    final ledger = await _load();
    if (!ledger.knownEnabled || ledger.knownAdFree) return false;
    final left = ledger.backgroundedMs;
    return left != null &&
        ledger.effectiveNow(_now()) - left >=
            AdTokens.appOpenResumeAfter.inMilliseconds;
  }

  /// Decides, loads within the budget and shows. Returns the verdict; never
  /// throws.
  Future<AppOpenVerdict> attempt({
    required AppOpenTrigger trigger,
    required Future<bool> Function() busy,
    required Future<bool> Function() onboarded,
  }) async {
    if (_running) return AppOpenVerdict.notLoaded;
    _running = true;
    Future<int?>? loading;
    final ads = _ref.read(appOpenAdsProvider);
    try {
      var ledger = await _load();
      if (trigger == AppOpenTrigger.coldStart) {
        ledger = ledger.launched(_now());
      }
      final away = FullScreenAway.lastMs;
      if (away != null && (ledger.awayMs ?? 0) < away) {
        ledger = ledger.away(away);
      }
      await _save(ledger);
      if (!ads.configured) return AppOpenVerdict.off;

      // The remembered answer first: a feature the server switched off (the
      // default) never costs a launch a network round trip.
      // Ads v3: the global full-screen pacing (cap and gap) shared with the
      // interstitials replaces the app-open ad's own daily cap.
      final pacing = _ref.read(interstitialCoordinatorProvider);
      final pre = decideAppOpen(
        rules: ledger.knownEnabled ? AppOpenRules.on : AppOpenRules.off,
        ledger: ledger,
        fullScreen: await pacing.pacingLedger(),
        nowMs: _now(),
        trigger: trigger,
        adFree: ledger.knownAdFree,
        onboarded: await onboarded(),
        busy: await busy(),
        canRequestAds: true,
        loadedAtMs: _now(),
      );
      if (pre != AppOpenVerdict.show) return pre;

      // Set when the 3 s budget runs out: the work still in flight must not
      // start an ad load nobody will show.
      var timedOut = false;
      final verdict =
          await () async {
            EconomyCapabilities caps;
            try {
              caps = await _ref.read(economyCapabilitiesProvider.future);
            } catch (_) {
              caps = EconomyCapabilities.unreachable;
            }
            await remember(caps);
            final fresh = await _load();
            final fullScreen = await pacing.pacingLedger();
            AppOpenVerdict decide(bool consent, int? loadedAt) => decideAppOpen(
              rules: caps.ads.appOpen,
              ledger: fresh,
              pacing: caps.interstitial,
              fullScreen: fullScreen,
              nowMs: _now(),
              trigger: trigger,
              adFree: caps.adFree,
              onboarded: true,
              busy: false,
              canRequestAds: consent,
              loadedAtMs: loadedAt,
            );
            final consent = await ads.canRequestAds();
            final before = decide(consent, _now());
            if (before != AppOpenVerdict.show) return before;
            if (timedOut) return AppOpenVerdict.notLoaded;
            loading = ads.load(AdTokens.appOpenLoadTimeout);
            return decide(consent, await loading);
          }().timeout(
            AdTokens.appOpenLoadTimeout,
            onTimeout: () {
              timedOut = true;
              return AppOpenVerdict.notLoaded;
            },
          );
      if (verdict != AppOpenVerdict.show) {
        // A late ad has nobody to show it.
        unawaited(loading?.then((_) => ads.discard()) ?? Future.value());
        ads.discard();
        return verdict;
      }
      // Recorded before showing: a crash mid-ad must not unlock another.
      await _save((await _load()).shown(_now()));
      await pacing.fullScreenShown();
      final audio = _ref.read(audioDirectorProvider);
      final wasMuted = audio.muted;
      audio.muted = true;
      try {
        await ads.show();
      } finally {
        audio.muted = wasMuted;
      }
      return verdict;
    } catch (_) {
      ads.discard();
      return AppOpenVerdict.off;
    } finally {
      _running = false;
    }
  }
}

final appOpenCoordinatorProvider = Provider<AppOpenCoordinator>(
  AppOpenCoordinator.new,
);

/// Routes where a return must never be interrupted: a match (pass-and-play
/// or online) and an online room.
bool appOpenBlockedPath(String path) =>
    path.startsWith('/match') || path.startsWith('/online/lobby');

/// Holds the branded launch picture while an app-open ad is considered.
///
/// Passes straight through (no veil, no timer) when the build has no
/// app-open unit — every test, the web, and any build without the define.
/// Otherwise the veil is the same picture as [SplashGate]'s, so nothing
/// visibly changes while it waits; it waits at most
/// [AdTokens.appOpenLoadTimeout], and only when the remembered server
/// answer says the feature is on.
class AppOpenGate extends ConsumerStatefulWidget {
  final Widget child;
  final String Function() currentPath;

  const AppOpenGate({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  ConsumerState<AppOpenGate> createState() => _AppOpenGateState();
}

class _AppOpenGateState extends ConsumerState<AppOpenGate>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _veil = AnimationController(
    vsync: this,
    value: 0,
  );
  late final bool _active = ref.read(appOpenAdsProvider).configured;

  AppOpenCoordinator get _coordinator => ref.read(appOpenCoordinatorProvider);

  @override
  void initState() {
    super.initState();
    if (!_active) return;
    _veil.value = 1;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_consider(AppOpenTrigger.coldStart));
  }

  Future<bool> _onboarded() async {
    try {
      final seen =
          await ref.read(profileStoreProvider).introSeen ||
          await ref.read(matchRepositoryProvider).hasSeenOnboarding();
      final terms = await ref.read(termsStoreProvider).load();
      return seen && (terms?.current ?? false);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _busy(AppOpenTrigger trigger) async {
    try {
      if (ref.read(onlineSessionProvider).isInRoom) return true;
      if (appOpenBlockedPath(widget.currentPath())) return true;
      if (trigger == AppOpenTrigger.coldStart) {
        if (await OnlineSessionStore.load() != null) return true;
        if (await ref.read(matchRepositoryProvider).loadActiveMatch() != null) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _consider(AppOpenTrigger trigger) async {
    await _coordinator.attempt(
      trigger: trigger,
      busy: () => _busy(trigger),
      onboarded: _onboarded,
    );
    if (!mounted) return;
    if (ReduceMotion.of(context)) {
      _veil.value = 0;
    } else {
      _veil.duration = context.motion.dramatic;
      unawaited(_veil.reverse());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Remember an answer the app already has; never start a read here
      // (that would sign in and call the server on every launch).
      if (ref.exists(economyCapabilitiesProvider)) {
        final caps = ref.read(economyCapabilitiesProvider).valueOrNull;
        if (caps != null) unawaited(_coordinator.remember(caps));
      }
      unawaited(_coordinator.backgrounded());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumed());
    }
  }

  Future<void> _resumed() async {
    if (!await _coordinator.mightShowOnResume() || !mounted) return;
    if (await _busy(AppOpenTrigger.resume) || !mounted) return;
    // The branded screen is back up while the ad is considered.
    _veil.value = 1;
    await _consider(AppOpenTrigger.resume);
  }

  @override
  void dispose() {
    // Inactive (no app-open unit): the veil was never created.
    if (_active) {
      WidgetsBinding.instance.removeObserver(this);
      _veil.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _veil,
          builder: (context, _) => _veil.value == 0
              ? const SizedBox.shrink()
              : AbsorbPointer(
                  child: Opacity(
                    opacity: _veil.value,
                    child: ColoredBox(
                      color: context.colors.surfaceBase,
                      child: Center(
                        child: Image.asset(
                          AppImages.splashMask,
                          width: SplashGate.maskSize,
                          height: SplashGate.maskSize,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
