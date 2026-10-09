import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/models/player.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

/// The Mafia card's frame, drawn once and only here: a lit centre falling to
/// dark, a bone-grey rim and an inner hairline. When the game gets its own
/// player-card frame art, this is the one widget that changes.
///
/// Public screens only (the setup flow). It carries no role information.
class SeatCardFrame extends StatelessWidget {
  final Widget child;

  /// Lifted under a finger: a deeper shadow.
  final bool lifted;

  const SeatCardFrame({super.key, required this.child, this.lifted = false});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeatTokens.radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: DeckTokens.ground.withValues(alpha: SeatTokens.shadowAlpha),
            blurRadius: lifted
                ? SeatTokens.liftShadowBlur
                : SeatTokens.shadowBlur,
            offset: const Offset(0, SeatTokens.shadowDrop),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.1,
              colors: [SeatTokens.frameLit, SeatTokens.frameDark],
              stops: [0, 0.7],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Padding(
                padding: const EdgeInsets.all(SeatTokens.inset),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        SeatTokens.insetRadius,
                      ),
                      border: Border.all(
                        color: DeckTokens.bone.withValues(
                          alpha: SeatTokens.hairlineAlpha,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: SeatTokens.rim,
                      width: SeatTokens.rimWidth,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One player as a small Mafia card: the hooded portrait, the name on a plate,
/// the seat number, and a corner control (remove, or away for tonight).
class SeatCard extends StatelessWidget {
  final String name;

  /// 1-based seat.
  final int seat;
  final PlayerGender gender;

  /// Replaces the stock hooded portrait once a bigger art set exists.
  final String? avatarAsset;
  final bool lifted;

  /// Away tonight: dimmed, still on the table.
  final bool away;
  final Key? cornerKey;
  final VoidCallback? onCorner;
  final String cornerLabel;
  final IconData cornerIcon;

  const SeatCard({
    super.key,
    required this.name,
    required this.seat,
    required this.gender,
    this.avatarAsset,
    this.lifted = false,
    this.away = false,
    this.cornerKey,
    this.onCorner,
    this.cornerLabel = '',
    this.cornerIcon = Icons.close,
  });

  /// The portrait for a gender: the Mafia game's own hooded figures.
  static String defaultAvatar(PlayerGender gender) =>
      gender == PlayerGender.female
      ? AppCouncilArt.avatarFemale
      : AppCouncilArt.avatarMale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final meta = DeckTokens.meta(type);
    return Semantics(
      label: '$name, $seat',
      container: true,
      child: SeatCardFrame(
        lifted: lifted,
        child: LayoutBuilder(
          builder: (context, box) {
            final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
            final side = (box.maxHeight * SeatTokens.avatarHeight * dpr)
                .round();
            return Opacity(
              opacity: away ? SeatTokens.awayAlpha : 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: box.maxHeight * SeatTokens.avatarBottom,
                    height: box.maxHeight * SeatTokens.avatarHeight,
                    child: Image(
                      image: ResizeImage(
                        AssetImage(avatarAsset ?? defaultAvatar(gender)),
                        height: side,
                        policy: ResizeImagePolicy.fit,
                      ),
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      gaplessPlayback: true,
                    ),
                  ),
                  PositionedDirectional(
                    start: SeatTokens.plateInset + SeatTokens.inset,
                    top: SeatTokens.plateInset + 1,
                    child: Text(
                      '$seat',
                      style: meta.copyWith(color: DeckTokens.text2),
                    ),
                  ),
                  Positioned(
                    left: SeatTokens.plateInset,
                    right: SeatTokens.plateInset,
                    bottom: SeatTokens.plateInset,
                    height: SeatTokens.plateHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DeckTokens.ground.withValues(
                          alpha: SeatTokens.plateAlpha,
                        ),
                        borderRadius: BorderRadius.circular(
                          SeatTokens.insetRadius,
                        ),
                        border: Border.all(
                          color: DeckTokens.bone.withValues(
                            alpha: SeatTokens.hairlineAlpha,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spacing.xs,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              name,
                              maxLines: 1,
                              style: meta.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onCorner != null)
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Semantics(
                        button: true,
                        label: cornerLabel,
                        child: GestureDetector(
                          key: cornerKey,
                          behavior: HitTestBehavior.opaque,
                          onTap: onCorner,
                          child: SizedBox(
                            width: SeatTokens.corner,
                            height: SeatTokens.corner,
                            child: Align(
                              alignment: AlignmentDirectional.topEnd,
                              child: Padding(
                                padding: EdgeInsets.all(
                                  context.spacing.sm + context.spacing.xs,
                                ),
                                child: Icon(
                                  cornerIcon,
                                  size: SeatTokens.cornerGlyph,
                                  color: DeckTokens.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The next seat, waiting: a dashed, dim card that says what is missing.
class EmptySeatCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const EmptySeatCard({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          painter: const _DashedCardPainter(DeckTokens.silver),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.sm),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: DeckTokens.meta(
                  context.typography,
                ).copyWith(color: DeckTokens.muted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCardPainter extends CustomPainter {
  final Color color;
  const _DashedCardPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = SeatTokens.emptyStroke;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(SeatTokens.radius),
        ),
      );
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + SeatTokens.emptyDash), paint);
        d += SeatTokens.emptyDash + SeatTokens.emptyGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCardPainter old) => old.color != color;
}
