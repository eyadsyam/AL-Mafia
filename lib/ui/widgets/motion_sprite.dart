import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../../platform/reduce_motion.dart';
import '../theme/design_tokens.dart';

/// One transparent animated sprite from [AppMotion], drawn on whatever is
/// behind it — no box, no background.
///
/// Decorative only: under reduced motion it draws nothing, and nothing may
/// depend on it being seen. A [once] sprite removes itself after [duration]
/// so a looping file can never keep replaying a one-shot moment.
class MotionSprite extends StatefulWidget {
  final String asset;
  final double width;
  final double height;
  final Duration? once;

  /// Drawn instead once a [once] sprite has played, and under reduced motion:
  /// a still that the moment settles into (a stamped seal stays stamped).
  final Widget? after;

  const MotionSprite(
    this.asset, {
    super.key,
    required this.width,
    double? height,
    this.once,
    this.after,
  }) : height = height ?? width;

  @override
  State<MotionSprite> createState() => _MotionSpriteState();
}

class _MotionSpriteState extends State<MotionSprite> {
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final once = widget.once;
    if (once != null) {
      _timer = Timer(once, () {
        if (mounted) setState(() => _done = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done || ReduceMotion.of(context)) {
      return widget.after ??
          SizedBox(width: widget.width, height: widget.height);
    }
    return Image.asset(
      widget.asset,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }
}

/// The moment a reward lands: gold sparks burst where [context] is, and a
/// coin spins up out of them and fades. Over everything, takes no taps, and
/// is gone in [MafiaTiming.rewardFlourish]. Nothing under reduced motion.
void showRewardFlourish(BuildContext context, {bool coin = true}) {
  if (ReduceMotion.of(context)) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final box = context.findRenderObject();
  if (overlay == null || box is! RenderBox || !box.hasSize) return;
  final centre = box.localToGlobal(box.size.center(Offset.zero));
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Flourish(
      centre: centre,
      coin: coin,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _Flourish extends StatefulWidget {
  final Offset centre;
  final bool coin;
  final VoidCallback onDone;
  const _Flourish({
    required this.centre,
    required this.coin,
    required this.onDone,
  });

  @override
  State<_Flourish> createState() => _FlourishState();
}

class _FlourishState extends State<_Flourish>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: MafiaTiming.rewardFlourish,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward().whenComplete(widget.onDone));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const burst = MotionTokens.burst;
    const coin = MotionTokens.coin;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: widget.centre.dx - burst / 2,
            top: widget.centre.dy - burst / 2,
            child: const MotionSprite(
              AppMotion.goldBurst,
              width: burst,
              once: MotionTokens.burstLength,
            ),
          ),
          if (widget.coin)
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_c.value);
                return Positioned(
                  left: widget.centre.dx - coin / 2,
                  top: widget.centre.dy - coin / 2 - t * MotionTokens.coinRise,
                  child: Opacity(
                    opacity: (1 - _c.value * _c.value).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: const MotionSprite(AppMotion.coinSpin, width: coin),
            ),
        ],
      ),
    );
  }
}
