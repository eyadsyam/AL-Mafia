import 'package:flutter/material.dart';

import '../economy/mafia_coin.dart';
import '../theme/design_tokens.dart';

/// Wraps a screen so coins can fly across it: [CoinFlightLayerState.fly]
/// takes the centres of two widgets (by key) and sends a handful of coins from
/// the first to the second. Transform and opacity only; under reduced motion
/// nothing flies and the call answers at once.
class CoinFlightLayer extends StatefulWidget {
  final Widget child;
  const CoinFlightLayer({super.key, required this.child});

  @override
  State<CoinFlightLayer> createState() => CoinFlightLayerState();
}

class CoinFlightLayerState extends State<CoinFlightLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: ResultTokens.flight,
  );
  Offset? _from;
  Offset? _to;
  VoidCallback? _landed;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      final landed = _landed;
      _landed = null;
      if (mounted) setState(() => _from = _to = null);
      landed?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Sends the coins from the widget keyed [from] to the one keyed [to];
  /// [onLanded] runs when the last one arrives (or at once when nothing flies).
  void fly(GlobalKey from, GlobalKey to, {VoidCallback? onLanded}) {
    final stack = context.findRenderObject();
    Offset? centre(GlobalKey key) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || stack is! RenderBox) {
        return null;
      }
      return stack.globalToLocal(
        box.localToGlobal(box.size.center(Offset.zero)),
      );
    }

    final a = centre(from);
    final b = centre(to);
    if ((MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        a == null ||
        b == null) {
      onLanded?.call();
      return;
    }
    setState(() {
      _from = a;
      _to = b;
      _landed = onLanded;
    });
    _c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    final to = _to;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (from != null && to != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    const n = ResultTokens.flightCoins;
                    const window = 1 - (n - 1) * ResultTokens.flightStagger;
                    return Stack(
                      children: [
                        for (var i = 0; i < n; i++)
                          () {
                            final p = Curves.easeIn.transform(
                              ((_c.value - i * ResultTokens.flightStagger) /
                                      window)
                                  .clamp(0.0, 1.0),
                            );
                            final at = Offset.lerp(from, to, p)!;
                            return Positioned(
                              left: at.dx - ResultTokens.flightCoinSize / 2,
                              top: at.dy - ResultTokens.flightCoinSize / 2,
                              child: Opacity(
                                opacity: p == 0 ? 0 : 1 - 0.8 * p,
                                child: const MafiaCoin(
                                  size: ResultTokens.flightCoinSize,
                                ),
                              ),
                            );
                          }(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
