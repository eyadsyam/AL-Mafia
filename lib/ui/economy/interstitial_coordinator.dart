import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repository_provider.dart';
import '../../platform/audio_director.dart';
import '../../platform/monetization/interstitial_ads.dart';
import '../../platform/monetization/interstitial_policy.dart';
import '../screens/online/online_session.dart';
import '../screens/online/voice_session.dart';
import '../theme/design_tokens.dart';
import 'economy_capabilities.dart';

/// Wall clock for the coordinator; a test replaces it.
final interstitialClockProvider = Provider<int Function()>(
  (ref) =>
      () => DateTime.now().millisecondsSinceEpoch,
);

/// Owns the device-side counters shared by every full-screen ad (Ads v3,
/// phase 110) and asks [decideInterstitial] before anything is shown.
///
/// Everything here is best effort and never blocks navigation: a failed
/// preference read counts as "no ad", a missing ad is skipped, and the
/// server is never asked just to decide (only an answer the app already
/// has is used; the online door starts a read in the background).
class InterstitialCoordinator {
  InterstitialCoordinator(this._ref);
  final Ref _ref;

  static const _key = 'interstitial_ledger_v1';
  InterstitialLedger? _cache;
  bool _showing = false;

  /// No match has been started since this launch: the app-open ad had that
  /// moment, so the first pre-match / pass-and-play deal ad is skipped.
  bool _firstMatchOfLaunch = true;
  MenuClock _clock = MenuClock.stopped;
  String _path = '/';
  bool _foreground = true;

  int _now() => _ref.read(interstitialClockProvider)();

  Future<InterstitialLedger> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      _cache = raw == null
          ? InterstitialLedger.empty
          : InterstitialLedger.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map),
            );
    } catch (_) {
      _cache = InterstitialLedger.empty;
    }
    return _cache!;
  }

  Future<void> _save(InterstitialLedger ledger) async {
    _cache = ledger;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(ledger.toJson()));
    } catch (_) {}
  }

  /// The answer the app already has, never a new read.
  EconomyCapabilities? _loadedCaps() {
    try {
      if (!_ref.exists(economyCapabilitiesProvider)) return null;
      return _ref.read(economyCapabilitiesProvider).valueOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<EconomyCapabilities> _caps() async {
    try {
      return await _ref.read(economyCapabilitiesProvider.future);
    } catch (_) {
      return EconomyCapabilities.none;
    }
  }

  bool _inRoom() {
    try {
      return _ref.read(onlineSessionProvider).isInRoom;
    } catch (_) {
      return false;
    }
  }

  /// Starts loading an ad in the background when some placement could use
  /// one. Never shows a consent form (see [InterstitialAds.preload]).
  void _warm(EconomyCapabilities? caps) {
    final ads = _ref.read(interstitialAdsProvider);
    if (caps == null || !ads.configured || caps.automaticAdsDisabled) return;
    if (!caps.interstitial.anyPlacement || ads.ready) return;
    unawaited(ads.preload());
  }

  /// The result of a completed match is on screen (online room id, or a
  /// pass-and-play match id). Counts it once and warms an ad.
  Future<void> matchCompleted(String matchId, {bool online = true}) async {
    await _save((await _load()).matchCompleted(matchId, _now()));
    _warm(online ? await _caps() : _loadedCaps());
  }

  /// Any rewarded ad was shown: the automatic ones keep their distance.
  Future<void> rewardedShown() async => _save((await _load()).rewarded(_now()));

  /// Another full-screen ad (the app-open ad) was shown: it counts toward
  /// the global cap and gap, and the menu clock starts again.
  Future<void> fullScreenShown() async {
    await _save((await _load()).shown(_now()));
    _clock = _clock.reset(_now());
  }

  /// The global pacing, for the app-open ad.
  Future<InterstitialLedger> pacingLedger() => _load();

  // --- the menu clock ----------------------------------------------------------

  void _syncClock() {
    final now = _now();
    final counts =
        _foreground && adSurfaceOf(_path) != AdSurface.gameplay && !_showing;
    _clock = counts ? _clock.run(now) : _clock.pause(now);
  }

  /// The app went to the background or came back.
  void foreground(bool value) {
    _foreground = value;
    _syncClock();
  }

  /// Menu time since the last full-screen ad (for tests and the session ad).
  int menuMs() => _clock.elapsed(_now());

  /// The router moved from [from] to [to]. Keeps the menu clock and warms an
  /// ad where one may soon be wanted. Never shows anything: by the time the
  /// router reports a move the destination is already on screen, and a back
  /// or pop is a move too. The session ad is [beforeMenuNavigation]'s.
  /// Never throws.
  void navigated(String from, String to) {
    _path = to;
    _syncClock();
    try {
      // A build without an interstitial unit never asks anything.
      if (!_ref.read(interstitialAdsProvider).configured) return;
      if (to == '/online' || to.startsWith('/join/')) {
        // The online door: pre-match is next. Starting the read here is fine
        // (the player is going online anyway) and never awaited.
        unawaited(_caps().then(_warm));
      } else {
        _warm(_loadedCaps());
      }
    } catch (_) {}
  }

  /// A menu control is about to move forward from the current menu screen to
  /// [to]. Considers the session ad *before* the move, so it never covers a
  /// destination already on screen; the caller navigates once this completes
  /// (at once when no ad is due). Back controls and the system back never
  /// call this. Never throws.
  Future<InterstitialVerdict> beforeMenuNavigation(String to) async {
    try {
      if (!_ref.read(interstitialAdsProvider).configured) {
        return InterstitialVerdict.off;
      }
      if (!sessionNavigation(_path, to)) return InterstitialVerdict.notThisExit;
      // A pass-and-play match left paused (resumable from Home) is still a
      // game in progress: no session ad over it, as the app-open ad.
      if (await _ref.read(matchRepositoryProvider).loadActiveMatch() != null) {
        return InterstitialVerdict.busy;
      }
      return await _consider(AdPlacement.session);
    } catch (_) {
      return InterstitialVerdict.off;
    }
  }

  // --- placements ----------------------------------------------------------------

  /// Create / Join, before the lobby. Completes when the ad (if any) is
  /// dismissed; returns at once when none is ready.
  Future<InterstitialVerdict> beforeOnlineMatch() async {
    if (_rematchPaid) {
      // «روم جديدة للشلة» already showed this match's pre-match ad.
      _rematchPaid = false;
      return InterstitialVerdict.notDue;
    }
    return _before(AdPlacement.preMatch);
  }

  /// «روم جديدة للشلة» from a result: the next match's pre-match ad, shown
  /// before the online door. The Create / Join that follows shows none.
  Future<InterstitialVerdict> beforeRematch() async {
    final verdict = await _before(AdPlacement.preMatch);
    _rematchPaid = verdict == InterstitialVerdict.show;
    return verdict;
  }

  bool _rematchPaid = false;

  /// Pass-and-play: setup confirmed, before the first pass screen.
  Future<InterstitialVerdict> beforeDeal() => _before(AdPlacement.passAndPlayDeal);

  Future<InterstitialVerdict> _before(AdPlacement placement) async {
    if (!_ref.read(interstitialAdsProvider).configured) {
      _firstMatchOfLaunch = false;
      return InterstitialVerdict.off;
    }
    final first = _firstMatchOfLaunch;
    _firstMatchOfLaunch = false;
    return _consider(placement, firstMatchOfLaunch: first);
  }

  /// The player left a completed online result. Shows the ad only if it is
  /// already loaded and every rule allows it.
  Future<InterstitialVerdict> leftResult(ResultExit exit) =>
      _consider(AdPlacement.postMatch, exit: exit);

  /// The player left a completed pass-and-play result ([matchId] is that
  /// match, counted once). Home is already on screen.
  ///
  /// P6: at most one of these per app session, inside the global daily cap.
  Future<InterstitialVerdict> leftPassAndPlayResult(String matchId) async {
    if (!_ref.read(interstitialAdsProvider).configured) {
      return InterstitialVerdict.off;
    }
    try {
      await _save((await _load()).matchCompleted(matchId, _now()));
    } catch (_) {}
    if (_passResultShown) return InterstitialVerdict.notDue;
    final verdict = await _consider(AdPlacement.passAndPlayResult);
    if (verdict == InterstitialVerdict.show) _passResultShown = true;
    return verdict;
  }

  /// P6: a pass-and-play result-exit ad was shown in this app session.
  bool _passResultShown = false;

  Future<InterstitialVerdict> _consider(
    AdPlacement placement, {
    ResultExit exit = ResultExit.homeAfterCompleted,
    bool firstMatchOfLaunch = false,
  }) async {
    if (_showing) return InterstitialVerdict.notLoaded;
    try {
      final ads = _ref.read(interstitialAdsProvider);
      // A build without the unit (every test, the web) decides nothing and
      // touches no storage, so a tap is never held up.
      if (!ads.configured) return InterstitialVerdict.off;
      final caps = _loadedCaps() ?? EconomyCapabilities.none;
      final gameplay =
          _inRoom() ||
          (placement == AdPlacement.session &&
              adSurfaceOf(_path) != AdSurface.menu);
      InterstitialVerdict decide({required bool consent}) => decideInterstitial(
        rules: ads.configured ? caps.interstitial : InterstitialRules.off,
        ledger: _cache ?? InterstitialLedger.empty,
        nowMs: _now(),
        placement: placement,
        exit: exit,
        adFree: caps.automaticAdsDisabled,
        loaded: ads.ready,
        canRequestAds: consent,
        firstMatchOfLaunch: firstMatchOfLaunch,
        gameplay: gameplay,
        menuMs: menuMs(),
      );
      await _load();
      var verdict = decide(consent: true);
      if (verdict == InterstitialVerdict.notLoaded) _warm(caps);
      if (verdict != InterstitialVerdict.show) return verdict;
      verdict = decide(consent: await ads.canRequestAds());
      if (verdict != InterstitialVerdict.show) return verdict;
      _showing = true;
      _syncClock();
      // Recorded before showing: a crash mid-ad must not unlock another.
      await _save((await _load()).shown(_now()));
      _clock = _clock.reset(_now());
      final audio = _ref.read(audioDirectorProvider);
      final voice = _ref.read(voiceControllerProvider);
      final wasMuted = audio.muted;
      final micOpen = voice != null && !voice.selfMuted;
      audio.muted = true;
      try {
        if (micOpen) await voice.setSelfMuted(true);
      } catch (_) {}
      try {
        await ads.showIfReady();
      } finally {
        audio.muted = wasMuted;
        try {
          if (micOpen) await voice.setSelfMuted(false);
        } catch (_) {}
        _showing = false;
        _clock = _clock.reset(_now());
        _syncClock();
      }
      return verdict;
    } catch (_) {
      _showing = false;
      return InterstitialVerdict.off;
    }
  }
}

/// Home from a completed online result: leave the room (heartbeat, channel,
/// voice link) first, then exit, then — only if the room was actually left
/// in time — let the automatic ad be considered. A slow or failed leave
/// never delays the exit beyond [timeout]; it just means no ad.
Future<bool> leaveThenMaybeAd({
  required Future<void> Function() leave,
  required void Function() exit,
  required Future<void> Function() ad,
  Duration timeout = MafiaTiming.leaveBeforeAd,
}) async {
  var left = false;
  try {
    await leave().timeout(timeout);
    left = true;
  } catch (_) {
    // Timed out or failed: the leave carries on by itself; no ad this time.
  }
  exit();
  if (left) unawaited(ad());
  return left;
}

final interstitialCoordinatorProvider = Provider<InterstitialCoordinator>(
  InterstitialCoordinator.new,
);
