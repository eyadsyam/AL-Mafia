import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// One card file drawn as the card alone: the black margin every card file
/// carries is cropped away and the card keeps its own proportions, painted
/// border, corner letter and corner icon intact. Sized by its parent's width
/// or height — whichever binds — through [AspectRatio].
class CardArt extends StatelessWidget {
  final String image;
  final double radius;

  const CardArt({super.key, required this.image, required this.radius});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: CardArtTokens.cardAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: LayoutBuilder(
          builder: (context, box) => OverflowBox(
            maxWidth: box.maxWidth / (1 - 2 * CardArtTokens.marginX),
            maxHeight: box.maxHeight / (1 - 2 * CardArtTokens.marginY),
            child: Image.asset(
              image,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
  }
}
