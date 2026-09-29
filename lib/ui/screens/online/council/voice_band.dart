import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/asset_constants.dart';
import '../../../../platform/reduce_motion.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// Doc 15 Band 3: where the game speaks.
///
/// ## The contract every phase in here keeps
///
/// Doc 15 §1.4: *"Maximum **two** text elements. If a third is needed,
/// something else is wrong."* That is not a style note — it is the reason the
/// old screen had a stack of tiny overlapping strings. So the band is not a
/// free-form slot: it is [CouncilVoice], which takes a headline and at most one
/// supporting element, and there is nowhere to put a third.
///
/// Vertically centred, never top-aligned, never crammed to the bottom. Every
/// gap is a spacing token.
class CouncilVoice extends StatelessWidget {
  /// The one idea. Rendered at [style], defaulting to `headline`.
  final String headline;

  /// The single supporting element, if there is one. A chip, a tally, a
  /// queue — never a second paragraph.
  final Widget? support;

  /// Overrides the headline's size for the phases doc 15 asks to shout in
  /// (`display` for the current speaker and for the winner).
  final TextStyle? style;

  /// Above the headline, when a phase has something to *show* first — your
  /// own card at night.
  final Widget? leading;

  const CouncilVoice({
    super.key,
    required this.headline,
    this.support,
    this.style,
    this.leading,
  });

  static const Key body = ValueKey('council_voice_body');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              SizedBox(height: spacing.md),
            ],
            Flexible(
              child: Text(
                headline,
                key: body,
                textAlign: TextAlign.center,
                style: (style ?? type.headline).copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (support != null) ...[
              SizedBox(height: spacing.md),
              support!,
            ],
          ],
        ),
      ),
    );
  }
}

/// «اخترت: أمينة» — doc 15 §1.6's third selection signal.
///
/// The other two are local to the seat (it lifts; everything else drops). This
/// one is the only place the *name* is written, and it is deliberately not a
/// line drawn across the screen.
class SelectionChip extends StatelessWidget {
  final String label;

  const SelectionChip({super.key, required this.label});

  static const Key chip = ValueKey('council_selection_chip');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final radii = context.radii;

    return Container(
      key: chip,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radii.button),
        border: Border.all(
          color: colors.accentGold,
          width: CouncilTokens.hairline,
        ),
      ),
      child: Text(
        label,
        style: type.caption.copyWith(color: colors.accentGold),
      ),
    );
  }
}

/// The live tally, as horizontal bars (doc 15 §S-O11).
///
/// Public information only: these are the ballots the server already sent
/// everybody. When the vote is secret the map is empty and there is nothing
/// here to draw, which is the enforcement — this widget never checks a setting.
class VoteTally extends StatelessWidget {
  /// Name to count, already ordered by the caller.
  final List<({String name, int votes})> rows;

  /// The largest count, so every bar is drawn against the same scale.
  final int peak;

  const VoteTally({super.key, required this.rows, required this.peak});

  static const Key bars = ValueKey('council_vote_tally');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final spacing = context.spacing;
    final motion = context.motion;
    final still = ReduceMotion.of(context);

    return Column(
      key: bars,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < rows.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: spacing.xxl * 2,
                  child: Text(
                    rows[index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.caption.copyWith(color: colors.textSecondary),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    // Staggered, 80ms apart, and only ever over public rows —
                    // stagger on anything role-derived would make list
                    // position a timing channel.
                    duration: still
                        ? Duration.zero
                        : motion.band + motion.stagger * index * 2,
                    curve: motion.standardCurve,
                    tween: Tween(
                      begin: 0,
                      end: peak == 0 ? 0 : rows[index].votes / peak,
                    ),
                    builder: (context, value, _) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(
                          height: CouncilTokens.tallyBarHeight,
                          decoration: BoxDecoration(
                            color: colors.accentGold,
                            borderRadius: BorderRadius.circular(
                              CouncilTokens.tallyBarHeight / 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Text(
                  '${rows[index].votes}',
                  style: type.caption.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The confrontation's answer clock (doc 15 §1.4).
///
/// The ornament from doc 15 A5 with the remaining fraction burnt out of it, so
/// the one phase that is *about* a person running out of time says so with
/// something other than a number.
class TimerRing extends StatelessWidget {
  final double remaining;
  final String seconds;

  const TimerRing({super.key, required this.remaining, required this.seconds});

  static const Key ring = ValueKey('council_timer_ring');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    return SizedBox(
      key: ring,
      width: CouncilTokens.timerRingSize,
      height: CouncilTokens.timerRingSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AppCouncilArt.timerRing,
            color: colors.borderSubtle,
            excludeFromSemantics: true,
          ),
          CustomPaint(
            size: const Size.square(CouncilTokens.timerRingSize),
            painter: _RingArcPainter(
              fraction: remaining.clamp(0.0, 1.0),
              colour: colors.accentGold,
            ),
          ),
          Text(
            seconds,
            textDirection: TextDirection.ltr,
            style: type.title.copyWith(
              color: colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingArcPainter extends CustomPainter {
  final double fraction;
  final Color colour;

  const _RingArcPainter({required this.fraction, required this.colour});

  @override
  void paint(Canvas canvas, Size size) {
    if (fraction <= 0) return;
    canvas.drawArc(
      Offset.zero & size,
      -math.pi / 2,
      fraction * 2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CouncilTokens.selectedRingWidth
        ..strokeCap = StrokeCap.round
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(_RingArcPainter old) =>
      old.fraction != fraction || old.colour != colour;
}

/// The winner's emblem, for the one screen that has earned an emblem.
class VictoryEmblem extends StatelessWidget {
  final bool mafiaWon;

  const VictoryEmblem({super.key, required this.mafiaWon});

  static const Key emblem = ValueKey('council_victory_emblem');

  @override
  Widget build(BuildContext context) => Image.asset(
    mafiaWon ? AppCouncilArt.victoryMafia : AppCouncilArt.victoryTown,
    key: emblem,
    width: CouncilTokens.victoryEmblemSize,
    height: CouncilTokens.victoryEmblemSize,
    color: context.colors.textPrimary,
    excludeFromSemantics: true,
  );
}
