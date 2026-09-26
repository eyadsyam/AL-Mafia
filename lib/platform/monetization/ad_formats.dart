import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rewarded_ads_stub.dart' if (dart.library.io) 'rewarded_ads_mobile.dart';

/// The app-open ad (phase 108). See `app_open_policy.dart` for when.
///
/// Never shows a consent form: only an answer the player already gave lets
/// it load. Load is bounded by the caller; a late ad is thrown away.
abstract interface class AppOpenAds {
  bool get configured;

  /// Whether ads may be requested under the consent already given. Never
  /// shows a form; false on any failure.
  Future<bool> canRequestAds();

  /// Loads one ad within [timeout]. Returns the load time (epoch ms) of a
  /// ready ad, or null when none arrived in time.
  Future<int?> load(Duration timeout);

  /// Shows the loaded ad and completes when it is dismissed or failed.
  Future<bool> show();
  void discard();
}

/// The anchored adaptive banner for waiting surfaces only. The widget is a
/// zero-size box until an ad has actually filled.
abstract interface class BannerAds {
  bool get configured;

  /// [gap] is kept above the banner only once it has filled, so an empty
  /// slot takes no space at all.
  Widget slot({Key? key, required String label, required double gap});
}

final appOpenAdsProvider = Provider<AppOpenAds>((ref) {
  final ads = createAppOpenAds();
  ref.onDispose(ads.discard);
  return ads;
});

final bannerAdsProvider = Provider<BannerAds>((ref) => createBannerAds());
