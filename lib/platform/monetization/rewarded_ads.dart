import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewarded_ads_stub.dart' if (dart.library.io) 'rewarded_ads_mobile.dart';

enum RewardedAdOutcome { earned, dismissed, unavailable, failed }

abstract interface class RewardedAds {
  bool get configured;
  bool get privacyOptionsRequired;

  /// Asks for consent (showing the form if required) and starts the ad SDK.
  /// Called only from a player's own tap on a rewarded offer.
  Future<void> initialize();

  /// Whether the ad privacy choices must be offered, from the consent
  /// status alone: never shows a form and never starts the ad SDK.
  Future<bool> checkPrivacyOptions();
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
