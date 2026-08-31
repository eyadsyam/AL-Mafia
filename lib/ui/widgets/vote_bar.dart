import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';

/// One row of the day-vote tally.
///
/// Shown on-table after voting closes, so it names candidates and counts — but
/// never who cast which vote. Individual ballots stay secret until the post-game
/// analytics screen (FR-019, FR-031).
///
/// ## Why the bars fill, and why they fill in order
///
/// A tally that appears fully drawn is a table of numbers: everyone reads their
/// own row first and the result arrives at four different moments. Filling the
/// bars from zero, one after another, makes the whole table watch the same
/// thing at the same time and land on the outcome together — which is the point
/// of the screen. The eliminated player's row being last is what the pause is
/// for.
///
/// This is on-table, public, and post-vote. Nothing here is leakage-sensitive:
/// the information is already common knowledge by the time the widget is built,
/// which is exactly why it may be dramatic when nothing during the night can be.
class VoteBar extends StatefulWidget {
  final String name;
  final int votes;

  /// Highest vote count in the tally, used to scale the bar. Zero-safe.
  final int maxVotes;

  /// Marks the eliminated player (or a tied candidate).
  final bool highlighted;

  /// Row position in the tally, counted from the top.
  ///
  /// Only ever delays this row's fill. It is not read for anything else, so an
  /// out-of-order or repeated value costs a slightly odd cascade and nothing
  /// more.
  final int index;

  const VoteBar({
    super.key,
    required this.name,
    required this.votes,
    required this.maxVotes,
    this.highlighted = false,
    this.index = 0,
  });

  @override
  State<VoteBar> createState() => _VoteBarState();
}

class _VoteBarState extends State<VoteBar> with SingleTickerProviderStateMixin {
  late final AnimationController _fill;

  /// The slice of [_fill] during which this row actually moves.
  ///
  /// The stagger is expressed as an [Interval] on one controller rather than as
  /// a delayed `forward()`, so there is no pending `Timer` to leak if the screen
  /// is popped mid-cascade and `pumpAndSettle` settles the whole tally in tests.
  late Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, duration: Duration.zero);
    _curve = const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.motion;

    if (ReduceMotion.of(context)) {
      // Straight to the answer. The tally is information first and theatre
      // second, so removing the theatre must not remove the information.
      _fill.duration = Duration.zero;
      _curve = const AlwaysStoppedAnimation<double>(1.0);
      _fill.value = 1.0;
      return;
    }

    final delay = motion.stagger * widget.index;
    final total = delay + motion.standard;
    _fill.duration = total;
    _curve = CurvedAnimation(
      parent: _fill,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1.0,
        curve: motion.standardCurve,
      ),
    );
    _fill.forward();
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    final fraction = widget.maxVotes <= 0
        ? 0.0
        : (widget.votes / widget.maxVotes).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.name,
                  style: type.body.emphasised.copyWith(
                    color: widget.highlighted
                        ? colors.textPrimary
                        : colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: spacing.sm),
              // The count is text from the first frame. Counting it up alongside
              // the bar would look livelier and would mean the number on screen
              // is briefly wrong, which is not a trade this screen can make.
              Text(
                '${widget.votes}',
                style: type.body.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          SizedBox(height: spacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(radii.button),
            child: SizedBox(
              height: spacing.sm,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: colors.surfaceOverlay),
                  ),
                  AnimatedBuilder(
                    animation: _curve,
                    builder: (context, child) => FractionallySizedBox(
                      widthFactor: fraction * _curve.value,
                      child: child,
                    ),
                    child: ColoredBox(
                      color: widget.highlighted
                          ? colors.accentGold
                          : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
