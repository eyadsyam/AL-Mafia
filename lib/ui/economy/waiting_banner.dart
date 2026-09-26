import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/monetization/ad_formats.dart';
import '../fun/loaded_capabilities.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// The one banner (phase 108), for non-gameplay waiting surfaces only: the
/// online lobby, the online hub, match history, the vault and the profile.
///
/// Never on a role reveal, night, day, discussion or vote screen, a
/// pass-the-phone screen, a dialog, or beside a primary button:
/// `test/unit/banner_placement_test.dart` fails if this widget appears in any
/// file outside its allowlist. It is a zero-size box unless the build has a
/// banner unit, the server switched banners on, the player has no Quiet Pass,
/// and an ad actually filled. Web: never.
class WaitingBanner extends ConsumerStatefulWidget {
  /// On a surface whose primary action sits above the banner (the lobby's
  /// Start button), the banner keeps [AdTokens.bannerActionClearance] clear
  /// of it instead of the ordinary gap, so a tap meant for the button never
  /// lands on the ad.
  final bool belowPrimaryAction;

  const WaitingBanner({super.key, this.belowPrimaryAction = false});

  static const slotKey = ValueKey('waiting_banner_slot');

  @override
  ConsumerState<WaitingBanner> createState() => _WaitingBannerState();
}

class _WaitingBannerState extends ConsumerState<WaitingBanner> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    final ads = ref.watch(bannerAdsProvider);
    // Checked before the capabilities: a build without a banner unit never
    // asks the server anything on these screens.
    if (!ads.configured) return const SizedBox.shrink();
    // Never starts a capabilities read (and so never an anonymous sign-in):
    // an offline player on History or the profile costs no network at all.
    // Once something else has asked, the answer is watched.
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    if (caps == null || !caps.ads.banner || caps.adFree) {
      return const SizedBox.shrink();
    }
    return ads.slot(
      key: WaitingBanner.slotKey,
      label: context.l10n.adBannerLabel,
      gap: widget.belowPrimaryAction
          ? AdTokens.bannerActionClearance
          : context.spacing.md,
    );
  }
}
