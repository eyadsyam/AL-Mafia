import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

/// Identity-neutral motion: Mafia's lists and the stories' hub both deal
/// their cards in with it.

/// A card's arrival, once, when its screen opens: it rises a little and
/// fades in, [index] beats after the first, so a list deals itself like a
/// hand of cards. Transform and opacity only, over a repaint boundary — the
/// card is painted once and the compositor moves it. Past
/// [DeckTokens.enterStaggered] cards, and with animations switched off, it
/// is simply there.
class DeckRise extends StatefulWidget {
  final int index;
  final Widget child;

  const DeckRise({super.key, required this.index, required this.child});

  @override
  State<DeckRise> createState() => _DeckRiseState();
}

class _DeckRiseState extends State<DeckRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration:
        DeckTokens.enter +
        DeckTokens.enterStagger *
            widget.index.clamp(0, DeckTokens.enterStaggered),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      1 -
          DeckTokens.enter.inMicroseconds /
              _controller.duration!.inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still || widget.index >= DeckTokens.enterStaggered) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    return FadeTransition(
      opacity: _t,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, DeckTokens.enterRise * (1 - _t.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
