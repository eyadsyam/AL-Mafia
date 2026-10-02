import 'interstitial_ads.dart';
import 'rewarded_ads.dart';

RewardedAds createRewardedAds() => _NoRewardedAds();
InterstitialAds createInterstitialAds() => const _NoInterstitialAds();

class _NoRewardedAds implements RewardedAds {
  @override
  bool get configured => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> checkPrivacyOptions() async => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async => RewardedAdOutcome.unavailable;

  @override
  void dispose() {}
}

class _NoInterstitialAds implements InterstitialAds {
  const _NoInterstitialAds();
  @override
  bool get configured => false;
  @override
  bool get ready => false;
  @override
  Future<void> preload() async {}
  @override
  Future<bool> showIfReady() async => false;
  @override
  void dispose() {}
}
