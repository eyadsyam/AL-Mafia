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
  /// [resume] picks the return-to-app unit instead of the cold-start one.
  Future<int?> load(Duration timeout, {bool resume = false});

  /// Shows the loaded ad and completes when it is dismissed or failed.
  Future<bool> show();
  void discard();
}

/// The large anchored adaptive banner for waiting surfaces only (full width,
/// the height Google gives that width). The slot's place is reserved from the
/// first frame, filled or not, so nothing moves when the ad arrives; the
/// surface decides whether to ask for one at all.
abstract interface class BannerAds {
  bool get configured;

  /// [gap] is kept above the slot; the slot itself always has the same height
  /// (the adaptive height plus the frame), empty or filled.
  Widget slot({
    Key? key,
    required String label,
    required double gap,
    BannerPlacement placement = BannerPlacement.lobby,
  });
}

/// Where a banner sits. Each surface has its own ad unit so its earnings are
/// reported apart; the lobby keeps the original unit.
enum BannerPlacement {
  lobby,
  onlineHub,
  history,
  vault,
  profile,
  home,
  stories,
  characters,

  /// The one banner of the shell host (banner_mode = shell).
  shell,
}

/// The shell's single banner (WP4, banner_mode = shell). The host mounts it
/// once, above the router, for the whole session: it owns ONE ad that loads
/// once and is reused across routes. [visible] only decides whether the ad is
/// on screen; hiding and showing never reload it.
abstract interface class ShellBannerAds {
  bool get configured;

  /// The band for the host's bottom edge, [size] being the adaptive size the
  /// host resolved for this window. Zero-size while not [visible] (the host
  /// only shows it once [size] is known, so a drawn band never changes
  /// height).
  Widget band({
    Key? key,
    required String label,
    required bool visible,
    required BannerSize? size,
  });
}

/// An adaptive banner size: the width asked for and the height Google gives
/// it. [native] is the platform's own size object (null in tests).
class BannerSize {
  final int width;
  final int height;
  final Object? native;
  const BannerSize(this.width, this.height, [this.native]);

  @override
  bool operator ==(Object other) =>
      other is BannerSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Resolves the large anchored adaptive size. It depends only on the width
/// and the orientation, never on an ad, so the layout can know a banner's
/// height before anything is requested. Answers are cached for the session.
abstract interface class BannerSizing {
  /// The cached size, or null when it has not been resolved yet.
  BannerSize? peek(int width, Orientation orientation);

  /// Resolves (and caches) the size; null when the platform has none.
  Future<BannerSize?> resolve(int width, Orientation orientation);
}

final bannerSizingProvider = Provider<BannerSizing>(
  (ref) => createBannerSizing(),
);

/// Where a native ad card sits inside a menu list (its own unit each).
enum NativePlacement {
  home,
  history,
  onlineHub,
  vault,
  council,
  characters,
  stories,
}

/// A native ad card in a menu list. A zero-size box until an ad has filled.
abstract interface class NativeAds {
  bool get configured;
  Widget slot({Key? key, required NativePlacement placement});
}

final nativeAdsProvider = Provider<NativeAds>((ref) => createNativeAds());

final appOpenAdsProvider = Provider<AppOpenAds>((ref) {
  final ads = createAppOpenAds();
  ref.onDispose(ads.discard);
  return ads;
});

final bannerAdsProvider = Provider<BannerAds>((ref) => createBannerAds());
final shellBannerAdsProvider = Provider<ShellBannerAds>(
  (ref) => createShellBannerAds(),
);
