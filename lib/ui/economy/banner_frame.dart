import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// The banner's frame, drawn the same whether or not an ad has arrived.
///
/// The owner's complaint was a screen that jumped up when the ad filled. The
/// slot is now a fixed box from the first frame: [ad] (a 320x50 platform
/// view) goes inside it when there is one, and until then, or when none ever
/// comes, the box stays as a quiet surface: no text, no pretend ad. Its
/// height is `AdTokens.bannerSlotHeight` either way, plus the [gap] above.
class BannerFrame extends StatelessWidget {
  final String label;
  final double gap;

  /// The 320x50 ad, or null while there is none.
  final Widget? ad;

  const BannerFrame({
    super.key,
    required this.label,
    required this.gap,
    required this.ad,
  });

  static const adKey = ValueKey('banner_frame_ad');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = ad != null;
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: Semantics(
        container: true,
        label: filled ? label : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceBase,
            border: Border.all(
              color: colors.borderSubtle,
              width: AdTokens.bannerFrame,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AdTokens.bannerFrame),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // A box narrower than the ad (a very small screen) never
                // overflows: the ad is not requested there either.
                final room = constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : AdTokens.bannerAdWidth;
                final width = room < AdTokens.bannerAdWidth
                    ? room
                    : AdTokens.bannerAdWidth;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AdTokens.bannerLabelGap,
                      ),
                      child: SizedBox(
                        height: AdTokens.bannerLabelStrip,
                        child: Center(
                          child: filled
                              ? Text(
                                  label,
                                  maxLines: 1,
                                  style: context.typography.caption.copyWith(
                                    color: colors.textMuted,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      key: adKey,
                      width: width,
                      height: AdTokens.bannerAdHeight,
                      child: ad,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The shell host's band: one hairline above the ad, a little air around it,
/// the bottom system inset kept inside (the host's body does not repeat it).
/// Same quiet surface when there is no ad.
class ShellBandFrame extends StatelessWidget {
  final String label;
  final Widget? ad;

  const ShellBandFrame({super.key, required this.label, required this.ad});

  static const adKey = ValueKey('shell_band_ad');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        border: Border(
          top: BorderSide(
            color: colors.borderSubtle,
            width: AdTokens.bannerBandRule,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          container: true,
          label: ad != null ? label : null,
          child: SizedBox(
            height: AdTokens.bannerBandHeight,
            child: Center(
              child: SizedBox(
                key: adKey,
                width: AdTokens.bannerAdWidth,
                height: AdTokens.bannerAdHeight,
                child: ad,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
