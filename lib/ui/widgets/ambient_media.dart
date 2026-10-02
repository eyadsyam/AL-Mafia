import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/design_tokens.dart';

/// Silent, decorative shared media. Loading never gates a game control.
///
/// ## The still is always painted, and the loop fades in over it
///
/// A 60-frame animated WebP takes a moment to decode the first time — on a
/// cold start, and on the web where the file is fetched on first use. Drawn
/// on its own, the backdrop was simply *missing* for that moment, and came
/// back only on a later visit once the image cache held it: «the video isn't
/// there when I open the game, and it is when I come back to Home»
/// (owner, 2026-09-24). So the still — the frame the loop rests on — is the
/// floor, and the loop is laid over it and faded in on its first frame. There
/// is never a moment with nothing behind the screen.
class AmbientMedia extends StatelessWidget {
  final String still;
  final String? loop;

  const AmbientMedia({super.key, required this.still, this.loop});

  @override
  Widget build(BuildContext context) {
    final moving =
        loop != null &&
        !ReduceMotion.of(context) &&
        TickerMode.valuesOf(context).enabled;
    Widget image(String asset, {ImageFrameBuilder? frameBuilder}) =>
        Image.asset(
          asset,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          excludeFromSemantics: true,
          gaplessPlayback: true,
          frameBuilder: frameBuilder,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        );
    final fade =
        Theme.of(context).extension<MafiaMotion>()?.standard ??
        MafiaMotion.defaults.standard;
    return IgnorePointer(
      child: ClipRect(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              image(still),
              if (moving)
                image(
                  loop!,
                  frameBuilder: (context, child, frame, synchronous) =>
                      synchronous
                      ? child
                      : AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: fade,
                          child: child,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
