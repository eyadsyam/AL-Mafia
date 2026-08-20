import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../theme/mafia_theme.dart';

/// The painterly surface treatment, in two pieces: a screen backdrop and a
/// panel.
///
/// ## Why these exist as widgets rather than as a decoration helper
///
/// The art direction is a painted card set, and what makes painted artwork read
/// as painted is the ground it sits on. Every screen therefore needs the same
/// canvas weave over the same charcoal, at the same strength. Left to a
/// `BoxDecoration` copied between screens, that strength drifts — one screen
/// ends up at 0.5 opacity because someone wanted to "see the texture", and the
/// app stops looking like one object.
///
/// ## Cost
///
/// The weave is a single 192px tile repeated by the engine, so it costs one
/// extra draw over a surface the screen was already painting — and, since it
/// uses `Image`'s own opacity rather than an `Opacity` widget, no offscreen
/// buffer. That matters now that [AppBackdrop] is behind every screen rather
/// than the two it started on.
///
/// The optional backdrop *image* is the expensive part and stays confined to the
/// screens allowed ambient art; passing nothing gets the charcoal ground and the
/// weave, which is all doc 05 allows a night surface anyway.

/// A full-screen painted ground.
///
/// [image] is optional: screens in the night register pass nothing and get the
/// charcoal ground plus weave, which is all doc 05 allows them.
class AppBackdrop extends StatelessWidget {
  /// Backdrop art. Only Result passes one — see [AppImages.homeBackdrop].
  final String? image;

  final Widget child;

  const AppBackdrop({super.key, this.image, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceBase),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Image.asset(
              image!,
              fit: BoxFit.cover,
              // The art is a backdrop, not content: it must never announce a
              // loading state or shift the layout when it decodes.
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
          const _CanvasWeave(opacity: _CanvasWeave.backdrop),
          child,
        ],
      ),
    );
  }
}

/// Ignores pointers and semantics — it is paint, and it must never sit between
/// a player and a control, or announce itself to a screen reader.
class _CanvasWeave extends StatelessWidget {
  /// The two strengths the app uses, as `Animation`s because that is what
  /// `Image.asset` takes. Held as constants so they are shared rather than
  /// allocated on every build of every screen.
  static const backdrop = AlwaysStoppedAnimation<double>(0.24);
  static const panel = AlwaysStoppedAnimation<double>(0.22);

  final Animation<double> opacity;

  const _CanvasWeave({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(
        AppImages.canvasTexture,
        repeat: ImageRepeat.repeat,
        fit: BoxFit.none,
        alignment: Alignment.topLeft,
        excludeFromSemantics: true,
        gaplessPlayback: true,
        // `Image`'s own opacity, not an `Opacity` widget wrapped around it.
        //
        // `Opacity` pushes a saveLayer: the subtree is rasterised into an
        // offscreen buffer, blended, and composited back, every frame. That was
        // affordable when the weave was on two screens. It is now behind every
        // screen in the app — including the night turns, which is where frame
        // budget is tightest and where a dropped frame during the flip is most
        // visible. `Image` applies the alpha in its own paint call instead, so
        // there is no offscreen buffer at all.
        opacity: opacity,
      ),
    );
  }
}

/// A raised panel with the same weave as the backdrop, one step lighter.
///
/// The counterpart to [AppBackdrop]: the ground is the table, this is a card of
/// stock laid on it. Same texture at a slightly lower strength, so the two read
/// as the same material rather than as a panel with a pattern on it.
///
/// The hairline is what actually separates it from the ground — on leather the
/// tonal step between [MafiaColors.surfaceBase] and [MafiaColors.surfaceRaised]
/// is only about nine levels, which is enough to feel and not enough to see an
/// edge by.
class PaperPanel extends StatelessWidget {
  final Widget child;

  /// Corner radius. Defaults to the card radius so panels and cards agree.
  final double? radius;

  const PaperPanel({super.key, required this.child, this.radius});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = BorderRadius.circular(radius ?? context.radii.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: shape,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          children: [
            const Positioned.fill(
              child: _CanvasWeave(opacity: _CanvasWeave.panel),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
