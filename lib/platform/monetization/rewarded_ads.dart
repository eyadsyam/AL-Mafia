import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewarded_ads_stub.dart' if (dart.library.io) 'rewarded_ads_mobile.dart';

enum RewardedAdOutcome {
  earned,
  dismissed,
  unavailable,
  failed,

  /// The consent form was answered, and the answer does not allow ads to be
  /// requested. Not an error: the player can change it in Settings.
  notConsented,
}

/// Which offer an ad belongs to. Only chooses the ad unit; the server alone
/// decides what a verified view is worth.
enum RewardedPlacement {
  /// The 1.0.0 one-ad post-match offer (primary unit).
  matchLegacy,

  /// The two post-match steps (v2 unit when configured, else primary).
  matchStep,

  /// The one fixed daily vault ad (v2 unit when configured, else primary).
  daily,
}

abstract interface class RewardedAds {
  bool get configured;
  bool get privacyOptionsRequired;

  /// Asks for consent (showing the form if required) and starts the ad SDK.
  /// Called only from a player's own tap on a rewarded offer. Parallel
  /// callers share one attempt.
  Future<void> initialize();

  /// Whether the ad privacy choices must be offered, from the consent
  /// status alone: never shows a form and never starts the ad SDK.
  Future<bool> checkPrivacyOptions();

  /// Shows Google's privacy options form, then re-reads what it changed.
  Future<void> showPrivacyOptions();
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  });
  void dispose();
}

final rewardedAdsProvider = Provider<RewardedAds>((ref) {
  final ads = createRewardedAds();
  ref.onDispose(ads.dispose);
  return ads;
});
