import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'rewarded_ads.dart';

RewardedAds createRewardedAds() => GoogleRewardedAds();

class GoogleRewardedAds implements RewardedAds {
  static const _enabled = bool.fromEnvironment('ADS_ENABLED');
  static const _testMode = bool.fromEnvironment('ADMOB_TEST_MODE');
  static const _productionUnit = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID_ID',
  );
  static const _testUnit = 'ca-app-pub-3940256099942544/5224354917';

  bool _initialized = false;
  bool _initializing = false;
  bool _privacyRequired = false;

  String get _unitId => _testMode ? _testUnit : _productionUnit;

  @override
  bool get configured => _enabled && (_testMode || _productionUnit.isNotEmpty);

  @override
  bool get privacyOptionsRequired => _privacyRequired;

  @override
  Future<void> initialize() async {
    if (!configured || _initialized || _initializing) return;
    _initializing = true;
    final consentDone = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        ConsentForm.loadAndShowConsentFormIfRequired((_) async {
          _privacyRequired =
              await ConsentInformation.instance
                  .getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;
          if (!consentDone.isCompleted) consentDone.complete();
        });
      },
      (_) {
        if (!consentDone.isCompleted) consentDone.complete();
      },
    );
    await consentDone.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {},
    );
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (canRequest) {
      await MobileAds.instance.initialize();
      _initialized = true;
    }
    _initializing = false;
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (!configured) return;
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
  }) async {
    if (!configured) return RewardedAdOutcome.unavailable;
    await initialize();
    if (!_initialized) return RewardedAdOutcome.unavailable;

    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => loaded.complete(ad),
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
    if (ad == null) return RewardedAdOutcome.unavailable;

    ad.setServerSideOptions(
      ServerSideVerificationOptions(customData: claimId, userId: userId),
    );
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
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return finished.future.timeout(
      const Duration(minutes: 3),
      onTimeout: () {
        ad.dispose();
        return RewardedAdOutcome.failed;
      },
    );
  }

  @override
  void dispose() {}
}
