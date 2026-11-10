import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'mafia_kit.dart';

/// Faint outlines of the rows a list is about to show, for the length of its
/// first read: an icon mark, a title line and a shorter caption line on the
/// same panel a real row sits on. The screen keeps its shape while it waits,
/// so the rows that arrive land where the eye already is.
///
/// It breathes slowly between two strengths; with Reduce Motion it holds still.
/// It says nothing: screen readers hear the list's own loading state, not
/// three empty rows.
class SkeletonRows extends StatefulWidget {
  final int count;

  const SkeletonRows({super.key, this.count = SkeletonTokens.rows});

  static const Key surface = ValueKey('skeleton_rows');

  @override
  State<SkeletonRows> createState() => _SkeletonRowsState();
}

class _SkeletonRowsState extends State<SkeletonRows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: SkeletonTokens.pulse,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ReduceMotion.of(context)) {
      _breath.stop();
      _breath.value = 1;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final mark = context.colors.borderSubtle;
    final row = MafiaPanel(
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        children: [
          Container(
            width: SkeletonTokens.leading,
            height: SkeletonTokens.leading,
            decoration: BoxDecoration(color: mark, shape: BoxShape.circle),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Line(color: mark, widthFactor: SkeletonTokens.titleWidth),
                SizedBox(height: spacing.sm),
                _Line(color: mark, widthFactor: SkeletonTokens.captionWidth),
              ],
            ),
          ),
        ],
      ),
    );
    return ExcludeSemantics(
      child: FadeTransition(
        key: SkeletonRows.surface,
        opacity: Tween<double>(
          begin: SkeletonTokens.dim,
          end: SkeletonTokens.bright,
        ).animate(CurvedAnimation(parent: _breath, curve: Easing.standard)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.count; i++)
              Padding(padding: EdgeInsets.only(top: spacing.sm), child: row),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final Color color;
  final double widthFactor;

  const _Line({required this.color, required this.widthFactor});

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: widthFactor,
    child: Container(
      height: SkeletonTokens.lineHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.radii.button),
      ),
    ),
  );
}
