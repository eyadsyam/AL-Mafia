import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../platform/audio_director.dart';
import '../../platform/monetization/interstitial_ads.dart';
import '../../platform/monetization/interstitial_policy.dart';
import '../screens/online/voice_session.dart';
import '../theme/design_tokens.dart';
import 'economy_capabilities.dart';

/// Wall clock for the coordinator; a test replaces it.
final interstitialClockProvider = Provider<int Function()>(
  (ref) =>
      () => DateTime.now().millisecondsSinceEpoch,
);

/// Owns the device-side counters of the one automatic ad and asks
/// [decideInterstitial] before anything is shown.
///
/// Everything here is best effort and never blocks navigation: a failed
/// preference read counts as "no ad", a missing ad is skipped.
class InterstitialCoordinator {
  InterstitialCoordinator(this._ref);
  final Ref _ref;

  static const _key = 'interstitial_ledger_v1';
  InterstitialLedger? _cache;
  bool _showing = false;

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

  Future<EconomyCapabilities> _caps() async {
    try {
      return await _ref.read(economyCapabilitiesProvider.future);
    } catch (_) {
      return EconomyCapabilities.none;
    }
  }

  /// The result of a completed match is on screen. Counts it once and, when
  /// an ad could follow, starts loading one in the background.
  Future<void> matchCompleted(String roomId) async {
    await _save((await _load()).matchCompleted(roomId, _now()));
    final caps = await _caps();
    final ads = _ref.read(interstitialAdsProvider);
    if (!ads.configured || caps.adFree || !caps.interstitial.enabled) return;
    final verdict = decideInterstitial(
      rules: caps.interstitial,
      ledger: await _load(),
      nowMs: _now(),
      exit: ResultExit.homeAfterCompleted,
      adFree: caps.adFree,
      loaded: true,
    );
    if (verdict == InterstitialVerdict.show) unawaited(ads.preload());
  }

  /// Any rewarded ad was shown: the automatic one keeps its distance.
  Future<void> rewardedShown() async => _save((await _load()).rewarded(_now()));

  /// The player left a result. Shows the ad only if it is already loaded and
  /// every rule allows it; returns what was decided. Never throws.
  Future<InterstitialVerdict> leftResult(ResultExit exit) async {
    if (_showing) return InterstitialVerdict.notLoaded;
    try {
      final caps = await _caps();
      final ads = _ref.read(interstitialAdsProvider);
      final verdict = decideInterstitial(
        rules: ads.configured ? caps.interstitial : InterstitialRules.off,
        ledger: await _load(),
        nowMs: _now(),
        exit: exit,
        adFree: caps.adFree,
        loaded: ads.ready,
      );
      if (verdict != InterstitialVerdict.show) return verdict;
      _showing = true;
      // Recorded before showing: a crash mid-ad must not unlock another.
      await _save((await _load()).shown(_now()));
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
