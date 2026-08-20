import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';
import 'ambient_motion.dart';

/// Haze along the bottom edge of the screen.
///
/// A single vertical gradient, painted over everything and under the controls.
/// Not a particle system: smoke that moves draws the eye, and the job here is
/// the opposite — to give the spread somewhere to sit and to stop the cards
/// looking like they are floating in a void.
///
/// The colour is [MafiaColors.surfaceBase] fading to nothing, so on the app's
/// own ground it reads as depth rather than as a grey band.
class BottomHaze extends StatelessWidget {
  /// Fraction of the available height the haze covers.
  final double extent;

  const BottomHaze({super.key, this.extent = 0.28});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: extent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.surfaceBase.withValues(alpha: 0.0),
                  colors.surfaceBase.withValues(alpha: 0.30),
                  // Not opaque. At 0.92 this reached the app's near-black and
                  // put a flat black band across the bottom third of a screen
                  // whose whole point is that it is *not* black — it undid the
                  // warm ground exactly where the title and the primary action
                  // sit. It only has to settle the cards onto something.
                  colors.surfaceBase.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A very slow, very slight brightness wander, like a bulb that is not quite
/// steady.
///
/// ## Why it is not random
///
/// A flicker built from `Random()` reads as a fault — the eye is extremely good
/// at spotting a discontinuity and will keep going back to it. What actually
/// reads as an old bulb is a *continuous* drift with no obvious period, which is
/// what three sine waves at unrelated frequencies produce: it never repeats
/// inside a session and it never jumps.
///
/// ## Why the range is so small
///
/// It sits over the home screen, and the home screen has the deck on it. A
/// brightness wobble large enough to notice would make four paintings appear to
/// change relative to each other, which is exactly the perception this app
/// spends its whole test suite preventing. 3% is enough to feel alive and far
/// too little to compare two cards by.
///
/// Ambient by definition, so it stops for Reduce Motion and for
/// [AmbientMotion] — and it stops at full brightness, never dark.
class BulbFlicker extends StatefulWidget {
  final Widget child;

  const BulbFlicker({super.key, required this.child});

  @override
  State<BulbFlicker> createState() => _BulbFlickerState();
}

class _BulbFlickerState extends State<BulbFlicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _brightness = ValueNotifier(1.0);

  /// Peak deviation from full brightness.
  static const double _depth = 0.03;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      // Three periods with no common multiple worth waiting for.
      final wander = math.sin(t / 2.7) * 0.5 +
          math.sin(t / 1.13 + 1.7) * 0.32 +
          math.sin(t / 0.41 + 3.1) * 0.18;
      _brightness.value = 1.0 - _depth * (0.5 + 0.5 * wander);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !ReduceMotion.of(context) && AmbientMotion.of(context);
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
      _brightness.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _brightness.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // A scrim, not a colour filter.
        //
        // The first version wrapped the whole screen in `ColorFiltered` with a
        // modulate blend. That forces the entire subtree into an offscreen
        // layer every frame, and this subtree is the whole home screen — five
        // card images, a tiled weave, a gradient and a particle field.
        //
        // Honest note on the evidence: swapping it out did **not** move the
        // measured raster time, because the only device available was an
        // emulator whose software rasteriser sits at a flat ~18ms per frame
        // whatever is drawn (a static text screen measured the same). So this
        // is a change made on the mechanism rather than on a measurement — a
        // per-frame `saveLayer` the size of the screen is a known cost on real
        // GPUs, and one translucent black fill is not. On a near-black ground
        // the two look the same: both take a few percent of light out of
        // everything underneath.
        IgnorePointer(
          child: ValueListenableBuilder<double>(
            valueListenable: _brightness,
            builder: (context, brightness, _) => ColoredBox(
              color: Colors.black.withValues(alpha: 1.0 - brightness),
            ),
          ),
        ),
      ],
    );
  }
}
