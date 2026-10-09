import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// One card of a [CardFan]. [id] keeps the card's identity when the hand
/// changes, so a card that stays slides to its new place instead of being
/// replaced.
class FanCard {
  final Object id;
  final Widget child;

  /// Painted over its neighbours and raised by [lift] dp, still standing in
  /// its place in the hand (your own card at the computer's table).
  final bool front;
  final double lift;
  const FanCard({
    required this.id,
    required this.child,
    this.front = false,
    this.lift = 0,
  });
}

class _Pose {
  final double dx;
  final double dy;
  final double angle;
  final double scale;
  final double opacity;
  const _Pose(this.dx, this.dy, this.angle, this.scale, this.opacity);

  static _Pose lerp(_Pose a, _Pose b, double t) => _Pose(
    a.dx + (b.dx - a.dx) * t,
    a.dy + (b.dy - a.dy) * t,
    a.angle + (b.angle - a.angle) * t,
    a.scale + (b.scale - a.scale) * t,
    a.opacity + (b.opacity - a.opacity) * t,
  );
}

class _PoseTween extends Tween<_Pose> {
  _PoseTween({super.begin, super.end});

  @override
  _Pose lerp(double t) => _Pose.lerp(begin!, end!, t);
}

/// A hand of cards spread like a fan, standing on the bottom edge of its box.
/// When the hand changes, cards that stay slide and turn to their new places
/// and new ones open out from the middle. Transform and opacity only, each
/// card on its own repaint boundary; with animations off it simply is.
///
/// Public screens only. It draws what it is given and knows nothing of roles.
class CardFan extends StatelessWidget {
  final List<FanCard> cards;
  final Size cardSize;
  final double step;
  final double height;

  const CardFan({
    super.key,
    required this.cards,
    required this.cardSize,
    required this.step,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // The first card sits at the reading side's start.
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              final n = cards.length;
              final mid = (n - 1) / 2;
              // Tighten until the hand fits the stage, and never turn it
              // past the cap however many cards it holds.
              final room = n > 1
                  ? (box.maxWidth - cardSize.width) / (n - 1)
                  : 0.0;
              final gap = n > 1 ? math.min(step, room) : 0.0;
              final tilt = n > 1
                  ? math.min(FanTokens.tilt, FanTokens.maxSpread / (n - 1))
                  : 0.0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cards that stand in front are painted last.
                  for (final i in [
                    for (var i = 0; i < n; i++)
                      if (!cards[i].front) i,
                    for (var i = 0; i < n; i++)
                      if (cards[i].front) i,
                  ])
                    Positioned(
                      key: ValueKey(cards[i].id),
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: _FanSlot(
                          pose: _Pose(
                            dir * (i - mid) * gap,
                            -cards[i].lift,
                            dir * (i - mid) * tilt,
                            1,
                            1,
                          ),
                          still: still,
                          size: cardSize,
                          child: cards[i].child,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FanSlot extends StatelessWidget {
  final _Pose pose;
  final bool still;
  final Size size;
  final Widget child;

  const _FanSlot({
    required this.pose,
    required this.still,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final body = RepaintBoundary(
      child: SizedBox.fromSize(size: size, child: child),
    );
    return TweenAnimationBuilder<_Pose>(
      tween: _PoseTween(
        begin: const _Pose(0, 0, 0, FanTokens.enterScale, 0),
        end: pose,
      ),
      duration: still ? Duration.zero : FanTokens.move,
      curve: Curves.easeOutCubic,
      builder: (context, p, child) => Opacity(
        opacity: p.opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: const Alignment(0, FanTokens.pivot),
          transform: Matrix4.identity()
            ..translateByDouble(p.dx, p.dy, 0, 1)
            ..rotateZ(p.angle)
            ..scaleByDouble(p.scale, p.scale, 1, 1),
          child: child,
        ),
      ),
      child: body,
    );
  }
}
