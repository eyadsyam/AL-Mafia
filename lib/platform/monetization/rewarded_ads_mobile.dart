import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ui/theme/design_tokens.dart';
import 'interstitial_ads.dart';
import 'rewarded_ads.dart';

RewardedAds createRewardedAds() => GoogleRewardedAds();
InterstitialAds createInterstitialAds() => GoogleInterstitialAds();

abstract final class _Units {
  static const enabled = bool.fromEnvironment('ADS_ENABLED');
  static const testMode = bool.fromEnvironment('ADMOB_TEST_MODE');
  static const rewarded = String.fromEnvironment('ADMOB_REWARDED_ANDROID_ID');
  static const rewardedV2 = String.fromEnvironment(
    'ADMOB_REWARDED_V2_ANDROID_ID',
  );
  static const interstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID_ID',
  );

  // Google's documented sample units.
  static const testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const testInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  static bool get rewardedConfigured =>
      enabled && (testMode || rewarded.isNotEmpty);
  static bool get interstitialConfigured =>
      enabled && (testMode || interstitial.isNotEmpty);

  static String rewardedFor(RewardedPlacement placement) {
    if (testMode) return testRewarded;
    if (placement == RewardedPlacement.matchLegacy) return rewarded;
    return rewardedV2.isNotEmpty ? rewardedV2 : rewarded;
  }

  static String get interstitialUnit =>
      testMode ? testInterstitial : interstitial;
}

/// Consent and SDK start, shared by the rewarded offers and the interstitial.
///
/// One attempt at a time: parallel callers await the same future, so two
/// taps cannot put two consent forms up or start the SDK twice.
class _AdsRuntime {
  _AdsRuntime._();
  static final instance = _AdsRuntime._();

  bool initialized = false;
  bool privacyRequired = false;
  Future<bool>? _prompting;
  final _consentChanged = <void Function()>[];

  void onConsentChanged(void Function() listener) =>
      _consentChanged.add(listener);
  void offConsentChanged(void Function() listener) =>
      _consentChanged.remove(listener);
  Future<bool>? _quiet;

  /// Asks Google for the current consent requirement, bounded: this is a
  /// network call, and nothing waits on it longer than the token allows.
  Future<void> updateInfo() async {
    final done = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!done.isCompleted) done.complete();
        },
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );
    } catch (_) {
      if (!done.isCompleted) done.complete();
    }
    await done.future.timeout(MafiaTiming.adConsentInfoTimeout, onTimeout: () {});
  }

  Future<void> refreshPrivacyRequirement() async {
    try {
      privacyRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      privacyRequired = false;
    }
  }

  Future<bool> _canRequest() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _startSdk() async {
    if (initialized) return true;
    try {
      await MobileAds.instance.initialize();
      initialized = true;
    } catch (_) {
      initialized = false;
    }
    return initialized;
  }

  /// Consent (with the form when [prompt] and Google requires it), then the
  /// SDK. Returns whether ads may be requested now.
  Future<bool> start({required bool prompt}) {
    if (initialized) return Future.value(true);
    if (!prompt) {
      // A quiet caller rides along with a player's attempt if one is running.
      return _prompting ??
          (_quiet ??= _start(false).whenComplete(() => _quiet = null));
    }
    return _prompting ??= () async {
      // A quiet attempt in flight finishes first; the player's own tap then
      // gets its chance at the form.
      final quiet = _quiet;
      if (quiet != null && await quiet) return true;
      return _start(true);
    }().whenComplete(() => _prompting = null);
  }

  Future<bool> _start(bool prompt) async {
    await updateInfo();
    if (prompt) {
      // The form is a person reading and choosing: no timeout here.
      final shown = Completer<void>();
      try {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!shown.isCompleted) shown.complete();
        });
      } catch (_) {
        if (!shown.isCompleted) shown.complete();
      }
      await shown.future;
    }
    await refreshPrivacyRequirement();
    // canRequestAds decides — not the button the player pressed: a
    // "do not consent" answer can still allow limited ads in some regions.
    if (!await _canRequest()) return false;
    return _startSdk();
  }

  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    try {
      ConsentForm.showPrivacyOptionsForm((_) {
        if (!done.isCompleted) done.complete();
      });
    } catch (_) {
      if (!done.isCompleted) done.complete();
    }
    // A person reading and choosing: never timed out.
    await done.future;
    await refreshPrivacyRequirement();
    // Anything loaded under the previous answer is thrown away.
    for (final listener in List.of(_consentChanged)) {
      listener();
    }
    // A changed answer may now allow ads (start the SDK) or forbid them —
    // every later load re-checks canRequestAds, so the SDK may stay started.
    if (await _canRequest()) await _startSdk();
  }

  Future<bool> canRequestNow() => _canRequest();
}

class GoogleRewardedAds implements RewardedAds {
  _AdsRuntime get _runtime => _AdsRuntime.instance;

  @override
  bool get configured => _Units.rewardedConfigured;

  @override
  bool get privacyOptionsRequired => _runtime.privacyRequired;

  @override
  Future<void> initialize() async {
    if (!configured) return;
    await _runtime.start(prompt: true);
  }

  @override
  Future<bool> checkPrivacyOptions() async {
    if (!configured) return false;
    if (!_runtime.initialized) await _runtime.updateInfo();
    await _runtime.refreshPrivacyRequirement();
    return _runtime.privacyRequired;
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (!configured) return;
    await _runtime.showPrivacyOptions();
  }

  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async {
    if (!configured) return RewardedAdOutcome.unavailable;
    final allowed = await _runtime.start(prompt: true);
    if (!allowed) {
      return _runtime.initialized
          ? RewardedAdOutcome.unavailable
          : RewardedAdOutcome.notConsented;
    }
    if (!await _runtime.canRequestNow()) return RewardedAdOutcome.notConsented;

    final loaded = Completer<RewardedAd?>();
    try {
      await RewardedAd.load(
        adUnitId: _Units.rewardedFor(placement),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            // An ad that arrives after the timeout below has nobody to show
            // it; left alone it holds native resources until the process dies.
            if (loaded.isCompleted) {
              ad.dispose();
            } else {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
    } catch (_) {
      if (!loaded.isCompleted) loaded.complete(null);
    }
    final ad = await loaded.future.timeout(
      MafiaTiming.adLoadTimeout,
      onTimeout: () {
        loaded.complete(null);
        return null;
      },
    );
    if (ad == null) return RewardedAdOutcome.unavailable;

    try {
      // Before show: the claim id must travel in AdMob's signed callback, or
      // the view can never be credited.
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(customData: claimId, userId: userId),
      );
    } catch (_) {
      ad.dispose();
      return RewardedAdOutcome.failed;
    }
    final finished = Completer<RewardedAdOutcome>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        if (!finished.isCompleted) {
          finished.complete(
            earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (shown, _) {
        shown.dispose();
        if (!finished.isCompleted) {
          finished.complete(RewardedAdOutcome.failed);
        }
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (_) {
      ad.dispose();
      return RewardedAdOutcome.failed;
    }
    return finished.future.timeout(
      MafiaTiming.adShowTimeout,
      onTimeout: () {
        ad.dispose();
        return RewardedAdOutcome.failed;
      },
    );
  }

  @override
  void dispose() {}
}

class GoogleInterstitialAds implements InterstitialAds {
  _AdsRuntime get _runtime => _AdsRuntime.instance;
  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;

  @override
  bool get configured => _Units.interstitialConfigured;

  @override
  bool get ready => _ad != null && !_showing;

  bool _listening = false;
  void _discard() {
    _ad?.dispose();
    _ad = null;
  }

  @override
  Future<void> preload() async {
    if (!configured || _ad != null || _loading || _showing) return;
    if (!_listening) {
      _listening = true;
      _runtime.onConsentChanged(_discard);
    }
    _loading = true;
    try {
      // Never a consent form from an automatic ad: only an answer already
      // given lets this load.
      if (!await _runtime.start(prompt: false)) return;
      if (!await _runtime.canRequestNow()) return;
      final loaded = Completer<InterstitialAd?>();
      await InterstitialAd.load(
        adUnitId: _Units.interstitialUnit,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (loaded.isCompleted) {
              ad.dispose();
            } else {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      _ad = await loaded.future.timeout(
        MafiaTiming.interstitialLoadTimeout,
        onTimeout: () {
          loaded.complete(null);
          return null;
        },
      );
    } catch (_) {
      _ad = null;
    } finally {
      _loading = false;
    }
  }

  @override
  Future<bool> showIfReady() async {
    if (_ad == null || _showing) return false;
    // Consent may have been withdrawn since this ad was loaded.
    if (!await _runtime.canRequestNow()) {
      _discard();
      return false;
    }
    final ad = _ad;
    if (ad == null || _showing) return false;
    _ad = null;
    _showing = true;
    final finished = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        if (!finished.isCompleted) finished.complete(true);
      },
      onAdFailedToShowFullScreenContent: (shown, _) {
        shown.dispose();
        if (!finished.isCompleted) finished.complete(false);
      },
    );
    try {
      await ad.show();
      return await finished.future.timeout(
        MafiaTiming.adShowTimeout,
        onTimeout: () {
          ad.dispose();
          return false;
        },
      );
    } catch (_) {
      ad.dispose();
      return false;
    } finally {
      _showing = false;
    }
  }

  @override
  void dispose() {
    _runtime.offConsentChanged(_discard);
    _discard();
  }
}
