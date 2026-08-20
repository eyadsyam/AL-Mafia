import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';
import 'ambient_motion.dart';
import 'icon_painters.dart';

/// A widget that displays the four role icons drifting slowly downward like ash.
///
/// Designed as a barely-there atmospheric background layer.
/// It uses a deterministic seeded random for testability and parity,
/// and draws all particles in a single paint call for efficiency.
class FallingIcons extends StatefulWidget {
  const FallingIcons({super.key});

  @override
  State<FallingIcons> createState() => _FallingIconsState();
}

class _Particle {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double opacity;
  final int iconType; // 0=Pistol, 1=Cross, 2=Lens, 3=Spade

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.iconType,
  });
}

class _FallingIconsState extends State<FallingIcons> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Particle> _particles = [];
  final Random _random = Random(42); // Seeded so the effect is deterministic
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    _initParticles();
    _ticker = createTicker((elapsed) {
      _elapsed.value = elapsed;
    });
  }

  void _initParticles() {
    for (int i = 0; i < 24; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          // Speed: how many screen heights to cover per second
          speed: 0.015 + _random.nextDouble() * 0.025,
          // Varied sizes for depth
          size: 16.0 + _random.nextDouble() * 24.0,
          // Very low opacity: 4% to 8%
          opacity: 0.04 + _random.nextDouble() * 0.04,
          iconType: i % 4, // Guarantee an equal mix of all 4 roles to prevent leakage
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Two independent reasons to hold still, and either one is sufficient:
    // the OS accessibility setting, and a caller that wants a settled frame
    // (see [AmbientMotion]). Stopped rather than disposed, so toggling either
    // one back resumes the drift from where it was instead of snapping the
    // whole field back to its seed positions.
    final animate = !ReduceMotion.of(context) && AmbientMotion.of(context);
    if (animate) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CustomPaint(
      size: Size.infinite,
      painter: _FallingIconsPainter(
        particles: _particles,
        elapsed: _elapsed,
        color: colors.textPrimary,
      ),
    );
  }
}

class _FallingIconsPainter extends CustomPainter {
  final List<_Particle> particles;
  final ValueNotifier<Duration> elapsed;
  final Color color;

  _FallingIconsPainter({
    required this.particles,
    required this.elapsed,
    required this.color,
  }) : super(repaint: elapsed);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    final seconds = elapsed.value.inMicroseconds / 1000000.0;

    for (final p in particles) {
      // Y offset goes downwards and wraps around cleanly
      final currentY = (p.y + (seconds * p.speed)) % 1.0;
      
      final dx = p.x * size.width;
      final dy = currentY * size.height;

      canvas.save();
      canvas.translate(dx, dy);

      // The particle's opacity goes in the `opacity` argument, *not* baked into
      // the colour. The painters end with `color.withOpacity(opacity)`, and
      // `withOpacity` **replaces** alpha rather than multiplying it — so a
      // pre-dimmed colour arriving with the default `opacity: 1.0` came back
      // out at full strength. That is why the ash drifting behind the home
      // screen was, for a while, the most prominent thing on it.
      final glyph = Size(p.size, p.size);
      switch (p.iconType) {
        case 0:
          PistolPainter(color: color, opacity: p.opacity).paint(canvas, glyph);
          break;
        case 1:
          CrossPainter(color: color, opacity: p.opacity).paint(canvas, glyph);
          break;
        case 2:
          LensPainter(color: color, opacity: p.opacity).paint(canvas, glyph);
          break;
        case 3:
          SpadePainter(color: color, opacity: p.opacity).paint(canvas, glyph);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FallingIconsPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.particles != particles;
  }
}
