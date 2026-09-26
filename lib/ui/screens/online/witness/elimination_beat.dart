import 'package:flutter/material.dart';

import '../../../../platform/reduce_motion.dart';
import '../../../l10n_ext.dart';
import '../../../theme/mafia_theme.dart';

/// The moment a player becomes a witness (doc 12 §4.2).
///
/// ```
/// Beat 1   Your card tears (the same animation the others see).
/// Beat 2   Screen desaturates fully to monochrome over 1.2s.
/// Beat 3   Text: «خرجت من اللعبة. بس لسه بتشوف.»
/// Beat 4   The table returns — in monochrome. You are still here, watching.
/// ```
///
/// ## Why it is not a cut to a spectator UI
///
/// *"Do not cut straight to a spectator UI. Give it weight."* An elimination
/// that is instantly followed by a different screen reads as being logged out.
/// The four beats say something else: the same table is still there, you are
/// still looking at it, and the only thing that changed is you.
///
/// Beat 1 is deliberately not in this widget. The tear belongs to the seat, and
/// every player sees it — including this one, on their own card, in the table
/// underneath. This overlay starts at beat 2, over a tear that is already
/// happening.
///
/// ## Reduce Motion
///
/// The desaturation is instant and the hold is unchanged. Doc 12 §6: dramatic
/// *holds* remain, because they are pacing rather than motion. Somebody who has
/// turned animations off still gets the beat of silence; they simply do not
/// watch the colour drain.
class EliminationBeat extends StatefulWidget {
  /// Called once the sentence has been read and the table is ready to return.
  final VoidCallback onFinished;

  const EliminationBeat({super.key, required this.onFinished});

  static const Key sentence = ValueKey('elimination_sentence');

  // Beats 2 and 3 are `MafiaTiming.eliminationDrain` and
  // `.eliminationHold`. They are read from the theme rather than declared here
  // so that "how long does dying take" is answerable from the token file like
  // every other duration in the app.

  @override
  State<EliminationBeat> createState() => _EliminationBeatState();
}

class _EliminationBeatState extends State<EliminationBeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final timing = context.timing;
    _controller.duration = timing.eliminationDrain;

    if (_started) return;
    _started = true;

    if (ReduceMotion.of(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }

    // The hold runs from the start of the drain, not from the end of it, so the
    // whole beat takes the same time whether or not the drain animated.
    //
    // It then lifts the way it fell — the veil and the sentence fade back out
    // over the table, now grey — instead of vanishing in one frame.
    Future<void>.delayed(timing.eliminationDrain + timing.eliminationHold, () {
      if (!mounted) return;
      if (ReduceMotion.of(context)) {
        widget.onFinished();
        return;
      }
      _controller.reverse().whenComplete(() {
        if (mounted) widget.onFinished();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return IgnorePointer(
          child: ColoredBox(
            // Not opaque. The table stays visible under the whole beat — that
            // is the sentence's entire argument.
            color: colors.surfaceBase.withValues(alpha: 0.82 * t),
            child: Center(
              child: Opacity(
                opacity: t,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.xl),
                  child: Text(
                    key: EliminationBeat.sentence,
                    context.l10n.witnessEliminated,
                    textAlign: TextAlign.center,
                    style: type.title.copyWith(color: colors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
