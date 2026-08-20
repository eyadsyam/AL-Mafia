import 'package:flutter/material.dart';

/// The four corner icons from the card art, redrawn as paths.
///
/// [opacity] is applied here rather than by the caller, and the reason is a
/// sharp edge in the Flutter API: `Color.withOpacity` **sets** alpha, it does
/// not scale it. A caller that dims the colour itself and then leaves `opacity`
/// at its default has its dimming silently thrown away by the very last line of
/// `paint`. Keeping the two in one place makes that impossible to get wrong.
abstract class _BaseIconPainter extends CustomPainter {
  final Color color;
  final double opacity;

  _BaseIconPainter({required this.color, this.opacity = 1.0});

  /// The stroke every subclass draws with.
  ///
  /// Stroke width scales with the glyph: these are drawn anywhere from 16 to
  /// 40 logical pixels, and a fixed 2px line makes the small ones look bolder
  /// than the large ones, which is the opposite of the depth the varied sizes
  /// are there to suggest.
  Paint strokeFor(Size size) => Paint()
    ..color = color.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = (size.shortestSide * 0.06).clamp(0.6, 2.0)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  bool shouldRepaint(covariant _BaseIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.opacity != opacity;
  }
}

/// A stylized pistol/revolver silhouette (Mafia icon).
class PistolPainter extends _BaseIconPainter {
  PistolPainter({required super.color, super.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = strokeFor(size);

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Barrel
    path.moveTo(w * 0.2, h * 0.3);
    path.lineTo(w * 0.8, h * 0.3);
    path.lineTo(w * 0.8, h * 0.45);
    path.lineTo(w * 0.5, h * 0.45);
    
    // Grip
    path.lineTo(w * 0.4, h * 0.8);
    path.lineTo(w * 0.2, h * 0.8);
    path.lineTo(w * 0.3, h * 0.45);
    path.lineTo(w * 0.2, h * 0.45);
    path.close();

    // Trigger guard
    path.moveTo(w * 0.45, h * 0.45);
    path.arcToPoint(Offset(w * 0.35, h * 0.55), radius: Radius.circular(w * 0.1));

    canvas.drawPath(path, paint);
  }

  static Widget icon({required Color color, double opacity = 1.0, double size = 24.0}) {
    return CustomPaint(
      size: Size(size, size),
      painter: PistolPainter(color: color, opacity: opacity),
    );
  }
}

/// A medical/healing cross (Doctor icon).
class CrossPainter extends _BaseIconPainter {
  CrossPainter({required super.color, super.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = strokeFor(size);

    final path = Path();
    final w = size.width;
    final h = size.height;
    final thick = w * 0.2;

    path.moveTo(w * 0.5 - thick, h * 0.1);
    path.lineTo(w * 0.5 + thick, h * 0.1);
    path.lineTo(w * 0.5 + thick, h * 0.5 - thick);
    path.lineTo(w * 0.9, h * 0.5 - thick);
    path.lineTo(w * 0.9, h * 0.5 + thick);
    path.lineTo(w * 0.5 + thick, h * 0.5 + thick);
    path.lineTo(w * 0.5 + thick, h * 0.9);
    path.lineTo(w * 0.5 - thick, h * 0.9);
    path.lineTo(w * 0.5 - thick, h * 0.5 + thick);
    path.lineTo(w * 0.1, h * 0.5 + thick);
    path.lineTo(w * 0.1, h * 0.5 - thick);
    path.lineTo(w * 0.5 - thick, h * 0.5 - thick);
    path.close();

    canvas.drawPath(path, paint);
  }

  static Widget icon({required Color color, double opacity = 1.0, double size = 24.0}) {
    return CustomPaint(
      size: Size(size, size),
      painter: CrossPainter(color: color, opacity: opacity),
    );
  }
}

/// A magnifying lens/glass (Detective icon).
class LensPainter extends _BaseIconPainter {
  LensPainter({required super.color, super.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = strokeFor(size);

    final w = size.width;
    final h = size.height;

    // Lens circle
    canvas.drawCircle(Offset(w * 0.4, h * 0.4), w * 0.25, paint);

    // Inner reflection
    final path = Path();
    path.moveTo(w * 0.25, h * 0.3);
    path.arcToPoint(Offset(w * 0.35, h * 0.2), radius: Radius.circular(w * 0.15));
    canvas.drawPath(path, paint);

    // Handle
    canvas.drawLine(Offset(w * 0.58, h * 0.58), Offset(w * 0.85, h * 0.85), paint);
  }

  static Widget icon({required Color color, double opacity = 1.0, double size = 24.0}) {
    return CustomPaint(
      size: Size(size, size),
      painter: LensPainter(color: color, opacity: opacity),
    );
  }
}

/// A spade/shovel shape (Citizen icon).
class SpadePainter extends _BaseIconPainter {
  SpadePainter({required super.color, super.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = strokeFor(size);

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Spade leaf
    path.moveTo(w * 0.5, h * 0.1);
    path.quadraticBezierTo(w * 0.9, h * 0.4, w * 0.8, h * 0.65);
    path.quadraticBezierTo(w * 0.7, h * 0.8, w * 0.5, h * 0.7);
    path.quadraticBezierTo(w * 0.3, h * 0.8, w * 0.2, h * 0.65);
    path.quadraticBezierTo(w * 0.1, h * 0.4, w * 0.5, h * 0.1);
    
    // Stem
    path.moveTo(w * 0.5, h * 0.7);
    path.lineTo(w * 0.6, h * 0.9);
    path.lineTo(w * 0.4, h * 0.9);
    path.close();

    canvas.drawPath(path, paint);
  }

  static Widget icon({required Color color, double opacity = 1.0, double size = 24.0}) {
    return CustomPaint(
      size: Size(size, size),
      painter: SpadePainter(color: color, opacity: opacity),
    );
  }
}
