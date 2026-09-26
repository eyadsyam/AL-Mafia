import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/monetization/ad_formats.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'economy_capabilities.dart';

/// The one banner (phase 108), for non-gameplay waiting surfaces only: the
/// online lobby, the online hub, match history, the vault and the profile.
///
/// Never on a role reveal, night, day, discussion or vote screen, a
/// pass-the-phone screen, a dialog, or beside a primary button:
/// `test/unit/banner_placement_test.dart` fails if this widget appears in any
/// file outside its allowlist. It is a zero-size box unless the build has a
/// banner unit, the server switched banners on, the player has no Quiet Pass,
/// and an ad actually filled. Web: never.
class WaitingBanner extends ConsumerWidget {
  const WaitingBanner({super.key});

  static const slotKey = ValueKey('waiting_banner_slot');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();
    final ads = ref.watch(bannerAdsProvider);
    // Checked before the capabilities: a build without a banner unit never
    // asks the server anything on these screens.
    if (!ads.configured) return const SizedBox.shrink();
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull;
    if (caps == null || !caps.ads.banner || caps.adFree) {
      return const SizedBox.shrink();
    }
    return ads.slot(
      key: slotKey,
      label: context.l10n.adBannerLabel,
      gap: context.spacing.md,
    );
  }
}
