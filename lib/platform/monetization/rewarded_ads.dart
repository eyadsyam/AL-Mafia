import 'dart:async';

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

  /// Phase 108 voluntary extras: second spin, doubled coffer, contract swap
  /// (v2 unit when configured, else primary).
  extra,
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

/// An ad layer that can load an ad before it is asked for, so a tap shows it
/// at once instead of waiting on the network and the SDK. Separate from
/// [RewardedAds] so a test double never has to implement it.
abstract interface class RewardedPreload {
  /// Loads one ad for [placement] in the background. Never shows a consent
  /// form and never starts the SDK unless consent already allows ads; a
  /// second call while one is loading or ready does nothing.
  Future<void> preload(RewardedPlacement placement);
}

/// Warms an ad for an offer that is on screen. Never awaited by a tap and
/// never throws.
void preloadRewarded(RewardedAds ads, RewardedPlacement placement) {
  if (!ads.configured || ads is! RewardedPreload) return;
  unawaited(
    (ads as RewardedPreload).preload(placement).catchError((Object _) {}),
  );
}

final rewardedAdsProvider = Provider<RewardedAds>((ref) {
  final ads = createRewardedAds();
  ref.onDispose(ads.dispose);
  return ads;
});
