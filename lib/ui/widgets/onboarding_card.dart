import 'package:flutter/material.dart';

import '../theme/mafia_theme.dart';
import 'textured_surface.dart';

/// One face of the onboarding deck.
///
/// ## What it is made of, and why none of it is new art
///
/// There is no painting for "the night" or "the pass", and there cannot be one
/// yet — image generation is unavailable (HANDOFF §6) and the tier-3 backdrop
/// slots are still empty for the same reason. Rather than invent a visual
/// language for six cards, this face is built from what the app already owns:
/// the [PaperPanel] stock every other panel is cut from, the canvas weave that
/// comes with it, a short gold rule, and the chapter's own numeral set large and
/// faint behind the type.
///
/// The numeral is doing a specific job. A deck needs its cards to be *distinct
/// at a glance* — that is what makes "there are two left" legible — and six
/// panels of text in the same type are not. A numeral is the cheapest possible
/// mark that differs on every card, and it is the one piece of ornament that
/// cannot be mistaken for game information.
///
/// ## The seam for real paintings
///
/// [image] is the drop-in. When tier-3 art exists, an `onboarding_*` asset name
/// goes into the chapter table and lands here as a band above the type, exactly
/// the way [AppBackdrop] already takes an optional backdrop. No caller changes.
class OnboardingCard extends StatelessWidget {
  /// The numeral printed faint behind the type. Also what distinguishes one
  /// card from another in peripheral vision.
  final String numeral;

  final String title;

  final String body;

  /// Optional painting for this chapter. Null today for all six — see the class
  /// comment.
  final String? image;

  /// Optional content below the body: the roles chapter puts its four cards
  /// here. Null for every other chapter.
  final Widget? child;

  const OnboardingCard({
    super.key,
    required this.numeral,
    required this.title,
    required this.body,
    this.image,
    this.child,
  });

  /// How much larger the watermark is than the display face it is derived from.
  ///
  /// A ratio rather than a size: if the type scale moves, the ornament moves
  /// with it instead of drifting out of proportion to the heading beside it.
  static const double _watermarkScale = 3.2;

  /// Alpha of the watermark against the panel.
  ///
  /// Low enough that it never competes with the body text for the eye, high
  /// enough to survive a dim room — the same band the ambient icon layer uses.
  static const double _watermarkAlpha = 0.07;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return PaperPanel(
      child: Stack(
        children: [
          Positioned.fill(
            child: _Watermark(numeral: numeral),
          ),
          // The card scrolls rather than shrinking its type. Five bullet lines
          // on the pass card do not fit a small phone at any size worth
          // reading, and a card whose text is smaller than its neighbours'
          // reads as less important than them.
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image != null) ...[
                  _ChapterImage(image: image!),
                  SizedBox(height: spacing.lg),
                ],
                SizedBox(
                  width: spacing.xl,
                  child: Divider(
                    color: colors.accentGold,
                    height: 1,
                    thickness: 1,
                  ),
                ),
                SizedBox(height: spacing.sm),
                Text(
                  title,
                  style: type.headline.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: spacing.sm),
                Text(
                  body,
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
                if (child != null) ...[
                  SizedBox(height: spacing.lg),
                  child!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The chapter numeral, set large and faint in the trailing bottom corner.
///
/// Ignores pointers and semantics: it is paint. Announcing "3" to a screen
/// reader before the heading would be worse than useless — the pip row already
/// says where in the deck this card is, in words.
class _Watermark extends StatelessWidget {
  final String numeral;

  const _Watermark({required this.numeral});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final display = context.typography.display;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            child: Text(
              numeral,
              style: display.copyWith(
                fontSize:
                    (display.fontSize ?? 0) * OnboardingCard._watermarkScale,
                color: colors.textPrimary
                    .withValues(alpha: OnboardingCard._watermarkAlpha),
                // Set solid. The token's 1.6 leading exists so Arabic
                // ascenders are not clipped; on a single Latin digit it only
                // adds a band of empty space under the mark.
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A chapter's painting, if one exists.
///
/// Contained, never cropped — the same rule the card faces and the gallery
/// follow. When these assets arrive they will be tier-3, which means they are
/// gained into a luminance band so bone-white type keeps its contrast over
/// them; nothing here needs to know that.
class _ChapterImage extends StatelessWidget {
  final String image;

  const _ChapterImage({required this.image});

  /// Decode width. These are full-bleed sources and the band is at most the
  /// width of a card; decoding at source size would cost megabytes per chapter
  /// for no visible gain. Same reasoning as `_Face._decodeWidth`.
  static const int _decodeWidth = 512;

  @override
  Widget build(BuildContext context) {
    final radii = context.radii;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radii.card),
      child: Image.asset(
        image,
        fit: BoxFit.contain,
        cacheWidth: _decodeWidth,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}
