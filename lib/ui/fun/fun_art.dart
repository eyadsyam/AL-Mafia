import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../economy/council_art.dart' show RasterOr;
import '../theme/design_tokens.dart';
import 'match_awards.dart';
import 'reactions.dart' show ReactionKind;

/// Phase 109 artwork. The painted versions below stand in until each file in
/// `assets/images/{awards,reactions,launch,profile}/` exists (see the README
/// in each folder), and whenever a file fails to decode.
abstract final class FunRaster {
  static const awards = 'assets/images/awards';
  static const reactions = 'assets/images/reactions';
  static const launch = 'assets/images/launch';
  static const profile = 'assets/images/profile';

  static String award(AwardKind kind) => '$awards/${kind.art}.webp';
  static const awardsBanner = '$awards/awards_banner.webp';
  static String reaction(ReactionKind kind) =>
      '$reactions/react_${kind.code}.webp';
  static const welcomeBack = '$launch/welcome_back_card.webp';
  static const founderBadge = '$profile/badge_founder.webp';
}

/// A round medal for [kind], the file when bundled, else painted.
class AwardMedal extends StatelessWidget {
  final AwardKind kind;
  final double size;
  const AwardMedal({
    super.key,
    required this.kind,
    this.size = FunTokens.awardMedal,
  });

  static IconData glyph(AwardKind kind) => switch (kind) {
    AwardKind.mvp => Icons.star_rounded,
    AwardKind.sharpEye => Icons.visibility_rounded,
    AwardKind.silverTongue => Icons.record_voice_over_rounded,
    AwardKind.firstBlood => Icons.gps_fixed_rounded,
    AwardKind.lifesaver => Icons.healing_rounded,
    AwardKind.perfectCrime => Icons.local_florist_rounded,
    AwardKind.survivor => Icons.local_fire_department_rounded,
  };

  @override
  Widget build(BuildContext context) => RasterOr(
    path: FunRaster.award(kind),
    width: size,
    height: size,
    fallback: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MedalPainter(FunTokens.ribbons[kind.index]),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: size * 0.18),
            child: Icon(
              glyph(kind),
              size: size * 0.34,
              color: FunTokens.medalDark,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MedalPainter extends CustomPainter {
  final Color ribbon;
  const _MedalPainter(this.ribbon);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // Two ribbon tails behind the disc.
    // Silk: lit along one edge, in shadow along the other.
    final tail = Paint()
      ..shader = LinearGradient(
        colors: [
          Color.lerp(ribbon, FunTokens.medalLight, 0.25)!,
          ribbon,
          Color.lerp(ribbon, VaultTokens.goldInk, 0.45)!,
        ],
      ).createShader(Rect.fromLTWH(w * 0.3, 0, w * 0.4, w * 0.42));
    final left = Path()
      ..moveTo(w * 0.30, 0)
      ..lineTo(w * 0.46, 0)
      ..lineTo(w * 0.52, w * 0.42)
      ..lineTo(w * 0.36, w * 0.42)
      ..close();
    final right = Path()
      ..moveTo(w * 0.54, 0)
      ..lineTo(w * 0.70, 0)
      ..lineTo(w * 0.64, w * 0.42)
      ..lineTo(w * 0.48, w * 0.42)
      ..close();
    canvas
      ..drawPath(left, tail)
      ..drawPath(right, tail);
    // A stitched fold where the two tails cross.
    canvas.drawLine(
      Offset(w * 0.40, w * 0.36),
      Offset(w * 0.60, w * 0.36),
      Paint()
        ..color = FunTokens.medalLight.withValues(alpha: 0.35)
        ..strokeWidth = FunTokens.awardStroke / 2,
    );
    final centre = Offset(w / 2, size.height * 0.62);
    final r = w * 0.36;
    // Light from the top left, like every other piece of the family.
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [
            FunTokens.medalLight,
            FunTokens.medalMid,
            FunTokens.medalDark,
          ],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
    canvas.drawCircle(
      centre,
      r * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = FunTokens.awardStroke
        ..color = FunTokens.medalDark.withValues(alpha: 0.6),
    );
    // A milled edge: fine ticks around the rim, like a struck coin.
    final mill = Paint()
      ..color = FunTokens.medalDark.withValues(alpha: 0.5)
      ..strokeWidth = FunTokens.awardStroke / 3;
    for (var i = 0; i < 36; i++) {
      final a = i * 2 * math.pi / 36;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(centre + d * r * 0.88, centre + d * r * 0.98, mill);
    }
    // The lamp catches the top-left of the rim.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: r * 0.93),
      math.pi * 1.05,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = FunTokens.awardStroke / 1.5
        ..strokeCap = StrokeCap.round
        ..color = FunTokens.medalLight.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_MedalPainter old) => old.ribbon != ribbon;
}

/// A coloured wax seal carrying one reaction: the file when bundled, else
/// painted with the glyph pressed into it.
class ReactionSeal extends StatelessWidget {
  final ReactionKind kind;
  final double size;
  const ReactionSeal({
    super.key,
    required this.kind,
    this.size = FunTokens.reactionSeal,
  });

  @override
  Widget build(BuildContext context) => RasterOr(
    path: FunRaster.reaction(kind),
    width: size,
    height: size,
    fallback: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SealPainter(FunTokens.waxes[kind.index]),
        child: Center(
          child: Text(
            kind.glyph,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: size * 0.46,
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SealPainter extends CustomPainter {
  final Color wax;
  const _SealPainter(this.wax);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // A wax blob: a circle with a softly scalloped edge.
    final path = Path();
    const lobes = 12;
    for (var i = 0; i <= lobes * 4; i++) {
      final t = i / (lobes * 4) * 2 * math.pi;
      final rr = r * (0.94 + 0.06 * math.sin(t * lobes));
      final p = c + Offset(math.cos(t) * rr, math.sin(t) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [
            Color.lerp(wax, Colors.white, 0.25)!,
            wax,
            Color.lerp(wax, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = FunTokens.awardStroke / 2
        ..color = Colors.black.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) => old.wax != wax;
}
