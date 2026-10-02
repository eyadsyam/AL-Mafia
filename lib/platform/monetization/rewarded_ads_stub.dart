import 'rewarded_ads.dart';

RewardedAds createRewardedAds() => _NoRewardedAds();

class _NoRewardedAds implements RewardedAds {
  @override
  bool get configured => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
  }) async => RewardedAdOutcome.unavailable;

  @override
  void dispose() {}
}
