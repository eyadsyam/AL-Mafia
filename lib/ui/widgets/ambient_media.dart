import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';

/// Silent, decorative shared media. Loading never gates a game control.
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
    Widget image(String asset, {bool fallback = false}) => Image.asset(
      asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback
          ? const SizedBox.expand()
          : Image.asset(
              still,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
    return IgnorePointer(
      child: ClipRect(
        child: RepaintBoundary(
          child: image(moving ? loop! : still, fallback: !moving),
        ),
      ),
    );
  }
}
