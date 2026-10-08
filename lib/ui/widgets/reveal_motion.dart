import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// Flips its child in once, from edge-on to face-up, the first time it is
/// built. Key it by the thing it shows so only new items flip.
class FlipIn extends StatelessWidget {
  const FlipIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ReduceMotion.of(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: MotionTokens.flipFromRadians, end: 0),
      duration: context.motion.dramatic,
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, angle, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, MotionTokens.flipPerspective)
          ..rotateY(angle),
        child: child,
      ),
    );
  }
}

/// Lands its child like a rubber stamp: large and faint, then pressed down.
class StampIn extends StatelessWidget {
  const StampIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ReduceMotion.of(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion.standard,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale:
              MotionTokens.stampFromScale +
              (1 - MotionTokens.stampFromScale) * t,
          child: child,
        ),
      ),
    );
  }
}

/// A small public mark on a seat («×٣», «متسكّت»), stamped in.
class SeatMark extends StatelessWidget {
  const SeatMark({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StampIn(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: colors.accentGold),
          borderRadius: BorderRadius.circular(context.radii.button),
        ),
        child: Text(
          label,
          style: context.typography.caption.copyWith(color: colors.accentGold),
          maxLines: 1,
        ),
      ),
    );
  }
}
