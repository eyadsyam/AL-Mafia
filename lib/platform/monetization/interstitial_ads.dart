import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewarded_ads_stub.dart' if (dart.library.io) 'rewarded_ads_mobile.dart';

/// The one automatic ad (see `interstitial_policy.dart` for when).
///
/// Preloaded-or-skip: [showIfReady] never waits on the network. [preload]
/// never shows a consent form — it only uses a consent answer the player has
/// already given from a rewarded offer or Settings.
abstract interface class InterstitialAds {
  bool get configured;

  /// An ad is loaded and not yet shown.
  bool get ready;
  Future<void> preload();

  /// Shows a loaded ad and completes when it is dismissed (or failed).
  /// Returns whether an ad was actually shown. False at once when none is
  /// loaded.
  Future<bool> showIfReady();

  /// Whether ads may be requested under the consent already given. Never
  /// shows a form; false on any failure.
  Future<bool> canRequestAds();
  void dispose();
}

final interstitialAdsProvider = Provider<InterstitialAds>((ref) {
  final ads = createInterstitialAds();
  ref.onDispose(ads.dispose);
  return ads;
});
