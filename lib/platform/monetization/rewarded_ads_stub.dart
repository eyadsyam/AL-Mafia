import 'package:flutter/widgets.dart';

import 'ad_formats.dart';
import 'interstitial_ads.dart';
import 'rewarded_ads.dart';

RewardedAds createRewardedAds() => _NoRewardedAds();
InterstitialAds createInterstitialAds() => const _NoInterstitialAds();
AppOpenAds createAppOpenAds() => const _NoAppOpenAds();
BannerAds createBannerAds() => const _NoBannerAds();
NativeAds createNativeAds() => const _NoNativeAds();
ShellBannerAds createShellBannerAds() => const _NoShellBannerAds();

class _NoShellBannerAds implements ShellBannerAds {
  const _NoShellBannerAds();
  @override
  bool get configured => false;
  @override
  Widget band({Key? key, required String label, required bool visible}) =>
      SizedBox.shrink(key: key);
}

class _NoNativeAds implements NativeAds {
  const _NoNativeAds();
  @override
  bool get configured => false;
  @override
  Widget slot({Key? key, required NativePlacement placement}) =>
      SizedBox.shrink(key: key);
}

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
  Future<void> preload({bool online = true}) async {}
  @override
  Future<bool> showIfReady() async => false;
  @override
  Future<bool> canRequestAds() async => false;
  @override
  void dispose() {}
}

/// The web shows no ads at all.
class _NoAppOpenAds implements AppOpenAds {
  const _NoAppOpenAds();
  @override
  bool get configured => false;
  @override
  Future<bool> canRequestAds() async => false;
  @override
  Future<int?> load(Duration timeout, {bool resume = false}) async => null;
  @override
  Future<bool> show() async => false;
  @override
  void discard() {}
}

class _NoBannerAds implements BannerAds {
  const _NoBannerAds();
  @override
  bool get configured => false;
  @override
  Widget slot({
    Key? key,
    required String label,
    required double gap,
    BannerPlacement placement = BannerPlacement.lobby,
  }) => SizedBox.shrink(key: key);
}
