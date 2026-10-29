import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/update_gate.dart' show BannerMode, bannerModeProvider;
import '../../platform/monetization/ad_formats.dart';
export '../../platform/monetization/ad_formats.dart' show BannerPlacement;
import '../fun/loaded_capabilities.dart';
import 'economy_capabilities.dart';
import 'web_ads.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

bool shouldShowWaitingBanner(EconomyCapabilities? caps) =>
    caps != null && caps.ads.banner && !caps.automaticAdsDisabled;

/// The one banner (phase 108), for non-gameplay waiting surfaces only: the
/// online lobby, the online hub, match history, the vault and the profile.
///
/// Never on a role reveal, night, day, discussion or vote screen, a
/// pass-the-phone screen, a dialog, or beside a primary button:
/// `test/unit/banner_placement_test.dart` fails if this widget appears in any
/// file outside its allowlist. It is a zero-size box unless the build has a
/// banner unit, the capabilities are loaded, the server switched banners on
/// and the player has no Quiet Pass. Once all of that holds its place is
/// reserved from the first frame whether or not an ad ever fills (WP4), so
/// nothing moves when it arrives. With `banner_mode = shell` it draws nothing
/// (the shell host owns the one banner). Web uses a house creative when Google
/// has no fill.
class WaitingBanner extends ConsumerStatefulWidget {
  /// On a surface whose primary action sits above the banner (the lobby's
  /// Start button), the banner keeps [AdTokens.bannerActionClearance] clear
  /// of it instead of the ordinary gap, so a tap meant for the button never
  /// lands on the ad.
  final bool belowPrimaryAction;

  /// Which surface this is, for the per-surface ad unit.
  final BannerPlacement placement;

  const WaitingBanner({
    super.key,
    this.belowPrimaryAction = false,
    this.placement = BannerPlacement.lobby,
  });

  static const slotKey = ValueKey('waiting_banner_slot');

  @override
  ConsumerState<WaitingBanner> createState() => _WaitingBannerState();
}

class _WaitingBannerState extends ConsumerState<WaitingBanner> {
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const WebAdBanner();
    final ads = ref.watch(bannerAdsProvider);
    // Checked before the capabilities: a build without a banner unit never
    // asks the server anything on these screens.
    if (!ads.configured) return const SizedBox.shrink();
    // Never starts a capabilities read (and so never an anonymous sign-in):
    // an offline player on History or the profile costs no network at all.
    // Once something else has asked, the answer is watched.
    final caps = loadedCapabilities(ref);
    if (caps == null) recheckCapabilitiesAfterFrame(this);
    final eligible = shouldShowWaitingBanner(caps);

    // banner_mode = shell: the host above the router draws the one banner and
    // already shortens the body, so there is nothing to draw here. The one
    // thing a surface keeps is the clearance under its primary action.
    if (ref.watch(bannerModeProvider) == BannerMode.shell) {
      return eligible && widget.belowPrimaryAction
          ? const SizedBox(height: AdTokens.bannerActionClearance)
          : const SizedBox.shrink();
    }

    // Eligible: the place is reserved from this frame on (the slot is a fixed
    // box, filled or not), so the ad arriving moves nothing. A player who
    // goes ad-free mid-screen closes it over a short ease; growing is never
    // animated.
    final reduce = MediaQuery.disableAnimationsOf(context);
    return _ReservedBand(
      collapse: reduce ? Duration.zero : AdTokens.bannerCollapse,
      child: eligible
          ? ads.slot(
              key: WaitingBanner.slotKey,
              label: context.l10n.adBannerLabel,
              gap: widget.belowPrimaryAction
                  ? AdTokens.bannerActionClearance
                  : context.spacing.md,
              placement: widget.placement,
            )
          : null,
    );
  }
}

/// Holds the slot's place at full height while [child] is there, and when it
/// goes (the player turned ad-free) keeps the last slot on screen just long
/// enough to close over [collapse] instead of snapping. Opening is never
/// animated: a place that is reserved is reserved at once.
class _ReservedBand extends StatefulWidget {
  final Widget? child;
  final Duration collapse;
  const _ReservedBand({required this.child, required this.collapse});

  @override
  State<_ReservedBand> createState() => _ReservedBandState();
}

class _ReservedBandState extends State<_ReservedBand> {
  Widget? _held;

  @override
  Widget build(BuildContext context) {
    final open = widget.child != null;
    if (open) _held = widget.child;
    final held = _held;
    if (held == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: open ? 1 : 0),
      duration: open ? Duration.zero : widget.collapse,
      curve: Curves.easeOut,
      onEnd: () {
        if (mounted && widget.child == null) setState(() => _held = null);
      },
      child: held,
      builder: (context, factor, child) => factor == 0
          ? const SizedBox.shrink()
          : ClipRect(
              clipBehavior: factor == 1 ? Clip.none : Clip.hardEdge,
              child: Align(
                alignment: Alignment.topCenter,
                widthFactor: 1,
                heightFactor: factor,
                child: child,
              ),
            ),
    );
  }
}
