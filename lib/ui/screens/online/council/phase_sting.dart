import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../platform/reduce_motion.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// Which change of light a [PhaseSting] marks.
enum PhaseLight {
  /// Day into night: the dark closes in from the edges.
  dusk,

  /// Night into morning: light falls from the top edge (doc 12 §3.4 beat 1).
  dawn,
}

/// Doc 16 V1/V2: the moment the light changes, drawn rather than played.
///
/// ## Why it is not a video any more
///
/// It was a 16:9 clip, cover-fitted onto a portrait phone at partial opacity.
/// Zoomed that far it was grain; it arrived at full strength on its first
/// decoded frame and vanished on its last, so the table darkened in one frame
/// and snapped back in another. The owner saw exactly that and called it
/// rough, and it was. This is the same beat as light and type — it eases in,
/// holds, and eases out, and every frame of it is drawn at the phone's own
/// resolution.
///
/// ## Why it is over the council and not instead of it
///
/// Doc 15 §1.1: the match is one place, and a phase change re-dresses it rather
/// than replacing it. The seats stay where they are underneath, the curtain is
/// translucent at its darkest, and pointer events pass straight through.
///
/// ## Why nothing waits on it
///
/// The phase has already changed; this is the flourish on top of it. It calls
/// [onFinished] when it is over and holds nothing else up.
class PhaseSting extends StatefulWidget {
  final PhaseLight light;

  /// «الليلة ٢», «اليوم ٢» — the words the light change carries.
  final String title;

  /// Called when the curtain has lifted.
  final VoidCallback onFinished;

  const PhaseSting({
    super.key,
    required this.light,
    required this.title,
    required this.onFinished,
  });

  static const Key surface = ValueKey('council_phase_sting');

  @override
  State<PhaseSting> createState() => _PhaseStingState();
}

class _PhaseStingState extends State<PhaseSting>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduce Motion keeps the words — they are information — and loses the
    // travelling light, which is motion. A short cross-fade, nothing else.
    _run.duration = ReduceMotion.of(context)
        ? MafiaTiming.phaseCurtainReduced
        : MafiaTiming.phaseCurtain;
    _run.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  /// 0 → 1 → 1 → 0 across the run: in over [from, to], out over the mirror.
  static double _envelope(double t, double inEnd, double outStart) {
    if (t <= 0 || t >= 1) return 0;
    if (t < inEnd) return Curves.easeOutCubic.transform(t / inEnd);
    if (t > outStart) {
      return 1 - Curves.easeInCubic.transform((t - outStart) / (1 - outStart));
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final still = ReduceMotion.of(context);

    return IgnorePointer(
      key: PhaseSting.surface,
      child: AnimatedBuilder(
        animation: _run,
        builder: (context, _) {
          final t = _run.value;
          final light = _envelope(t, 0.3, 0.7);
          // The words arrive once the veil is already down, so they are never
          // read on top of the sentence underneath.
          final words = _envelope(
            ((t - CouncilTokens.curtainWordsDelay) /
                    (1 - CouncilTokens.curtainWordsDelay))
                .clamp(0.0, 1.0),
            0.35,
            0.75,
          );
          // How far the words have travelled into place: they rise a little
          // and settle, and keep settling while they fade — never a bounce.
          final rise = Curves.easeOutCubic.transform(
            (t / 0.45).clamp(0.0, 1.0),
          );

          final Decoration curtain = switch (widget.light) {
            // The dark closes in from the edges over a veil across the whole
            // table, so the title never sits on top of the words under it.
            PhaseLight.dusk => BoxDecoration(
              gradient: RadialGradient(
                radius: 1.2,
                colors: [
                  colors.surfaceBase.withValues(
                    alpha: CouncilTokens.curtainVeil * light,
                  ),
                  colors.surfaceBase.withValues(
                    alpha: CouncilTokens.curtainDarkness * light,
                  ),
                ],
                // The clear middle shrinks as the dark closes in.
                stops: [math.max(0.05, 0.55 - 0.45 * light), 1],
              ),
            ),
            PhaseLight.dawn => BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.accentGold.withValues(
                    alpha: CouncilTokens.curtainDawnGlow * light,
                  ),
                  colors.accentGold.withValues(alpha: 0),
                ],
                // The light travels down the table as it arrives.
                stops: [0, math.max(0.2, 0.9 * rise)],
              ),
            ),
          };

          return DecoratedBox(
            // Under the dawn glow, the same veil the dusk has: the title is
            // read on a quiet ground, never over the morning report.
            decoration: BoxDecoration(
              color: widget.light == PhaseLight.dawn
                  ? colors.surfaceBase.withValues(
                      alpha: CouncilTokens.curtainVeil * light,
                    )
                  : null,
            ),
            child: DecoratedBox(
              decoration: curtain,
              child: Center(
                child: Opacity(
                  opacity: words,
                  child: Transform.translate(
                    offset: Offset(0, still ? 0 : spacing.lg * (1 - rise)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: type.display.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: spacing.sm),
                        // A hairline that draws outward from the centre under the
                        // words — the one ornament. Gold at dawn; never at dusk,
                        // because warm colour does not appear on a night surface
                        // (doc 05 rule 3).
                        Container(
                          width: CouncilTokens.curtainRuleWidth * rise,
                          height: CouncilTokens.curtainRuleHeight,
                          color: widget.light == PhaseLight.dawn
                              ? colors.accentGold
                              : colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
