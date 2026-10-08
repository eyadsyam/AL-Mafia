import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/monetization/ad_formats.dart';
export '../../platform/monetization/ad_formats.dart' show NativePlacement;
import '../fun/loaded_capabilities.dart';
import 'waiting_banner.dart';

/// A native ad card inside a menu list (home, history, the hubs, the vault,
/// the characters). Same gate as the banner: a build with ads, the server's
/// banner switch, no Quiet Pass, and an ad that actually filled — otherwise
/// a zero-size box, so a list never shows a hole. Never in a match.
class NativeAdCard extends ConsumerStatefulWidget {
  final NativePlacement placement;
  const NativeAdCard({super.key, required this.placement});

  @override
  ConsumerState<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends ConsumerState<NativeAdCard> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final ads = ref.watch(nativeAdsProvider);
    if (!ads.configured) return const SizedBox.shrink();
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    if (!shouldShowWaitingBanner(caps)) return const SizedBox.shrink();
    return ads.slot(placement: widget.placement);
  }
}
