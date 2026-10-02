import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewarded_ads_stub.dart' if (dart.library.io) 'rewarded_ads_mobile.dart';

enum RewardedAdOutcome { earned, dismissed, unavailable, failed }

abstract interface class RewardedAds {
  bool get configured;
  bool get privacyOptionsRequired;

  Future<void> initialize();
  Future<void> showPrivacyOptions();
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
  });
  void dispose();
}

final rewardedAdsProvider = Provider<RewardedAds>((ref) {
  final ads = createRewardedAds();
  ref.onDispose(ads.dispose);
  return ads;
});
