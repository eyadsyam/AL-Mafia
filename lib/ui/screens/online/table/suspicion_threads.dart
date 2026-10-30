import 'package:flutter/material.dart';

import '../../../../engine/models/enums.dart' show GamePhase;
import '../../../../transport/game_snapshot.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// «أنا شاكك في» on the table (owner, 2026-10-30): today's public suspicions
/// as threads and a count on each named seat. Public by design: the same
/// drawing for every seat, alive or dead, so nothing about a role shows.

/// The day phases the threads stay up in: from the discussion they were made
/// in to the end of that day's vote.
const _shown = {
  GamePhase.discussion,
  GamePhase.voting,
  GamePhase.voteResolving,
  GamePhase.reveal,
};

/// (from seat, to seat), ordered by the seat that suspects, so every device
/// draws them in the same order.
List<(int, int)> suspicionThreads(GameSnapshot snapshot) {
  if (!_shown.contains(snapshot.phase)) return const [];
  final entries = snapshot.publicSuspicions.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [for (final e in entries) (e.key, e.value)];
}

/// How many named each seat today, as a small pill on its shoulder.
Map<int, Widget> suspicionMarks(BuildContext context, GameSnapshot snapshot) {
  if (!_shown.contains(snapshot.phase)) return const {};
  final counts = <int, int>{};
  for (final target in snapshot.publicSuspicions.values) {
    counts[target] = (counts[target] ?? 0) + 1;
  }
  return {
    for (final e in counts.entries)
      e.key: SuspicionCount(key: SuspicionCount.keyFor(e.key), count: e.value),
  };
}

class SuspicionCount extends StatelessWidget {
  final int count;
  const SuspicionCount({super.key, required this.count});

  static Key keyFor(int seat) => ValueKey('suspicion_count_$seat');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = context.l10n.suspectCount(count);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.roleMafia,
          borderRadius: BorderRadius.circular(
            CouncilTokens.suspicionPillRadius,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CouncilTokens.suspicionPillPadding,
          ),
          child: ExcludeSemantics(
            child: Text(
              context.l10n.suspectCountShort(count),
              style: context.typography.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
