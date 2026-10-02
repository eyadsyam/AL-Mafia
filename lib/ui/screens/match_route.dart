import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_provider.dart';
import '../../engine/models/enums.dart' show GamePhase;
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'match_controller.dart';
import 'online/table/table_scene.dart' show tableIsAvailableFor;
import 'match_flow.dart';

/// Hosts a live match and locks the way out of it.
///
/// ## Why back is disabled rather than confirmed
///
/// A back gesture during the night is almost never intentional — it is a thumb
/// on the edge of the screen while someone is holding the phone at an angle. If
/// it popped the route it would drop the actor mid-turn and, worse, could land
/// the next screen in front of the wrong person. So the route simply does not
/// pop (L-15, FR-027); leaving is a deliberate act through the End-match dialog,
/// which names what will be lost.
class MatchRoute extends ConsumerWidget {
  /// Leaves the match and returns Home.
  final VoidCallback onExit;

  /// Opens analytics for the just-finished match.
  final VoidCallback onAnalytics;
  final VoidCallback? onRematch;

  const MatchRoute({
    super.key,
    required this.onExit,
    required this.onAnalytics,
    this.onRematch,
  });

  static const Key endMatchButton = ValueKey('match_end_button');
  static const Key endMatchConfirm = ValueKey('match_end_confirm');
  static const Key endMatchCancel = ValueKey('match_end_cancel');

  /// Phases in which the back gesture is suppressed. Once the match is over
  /// there is nothing left to protect, so the result screen pops normally.
  static bool isLocked(GamePhase phase) =>
      phase != GamePhase.result && phase != GamePhase.analytics;

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final type = context.typography;
    final radii = context.radii;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.dialog),
        ),
        title: Text(
          l10n.endMatchTitle,
          style: type.title.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          l10n.endMatchBody,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            key: endMatchCancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.keepPlaying,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
          TextButton(
            key: endMatchConfirm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.endAction,
              style: type.body.copyWith(color: colors.accentCrimson),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) onExit();
  }

  bool _tableShown(WidgetRef ref) {
    final controller = ref.read(matchControllerProvider.notifier);
    try {
      return tableIsAvailableFor(controller.snapshot);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(matchControllerProvider)?.phase ?? GamePhase.setup;
    final locked = isLocked(phase);
    final colors = context.colors;
    final spacing = context.spacing;

    return PopScope(
      canPop: !locked,
      child: Scaffold(
        backgroundColor: colors.surfaceBase,
        body: Stack(
          children: [
            Positioned.fill(
              child: MatchFlow(
                onExit: onExit,
                onAnalytics: onAnalytics,
                onRematch: onRematch,
                onStepCommitted: () => _persist(ref),
              ),
            ),
            // Deliberately small and in the corner: the only way out, but never
            // competing with the action the current player is meant to take.
            // Not over a table: the table has its own way out in its header,
            // and this cross sat right on top of it (owner, 2026-09-23).
            if (locked && !_tableShown(ref))
              Positioned(
                top: spacing.sm,
                left: spacing.sm,
                child: SafeArea(
                  child: IconButton(
                    key: endMatchButton,
                    onPressed: () => _confirmEnd(context, ref),
                    icon: Icon(Icons.close, color: colors.textMuted),
                    tooltip: context.l10n.endMatchTooltip,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Writes the current match after a confirmed step.
  ///
  /// Fire-and-forget on purpose: a storage hiccup must never block the game in
  /// front of the players. The cost of a dropped write is one replayed step on
  /// resume, which the pass screen makes safe.
  ///
  /// Asks the engine whether there is anything to write rather than asking
  /// which transport is in use. There is no local match in an online room —
  /// the room's state is the server's, and resuming it is the server's
  /// business — so every committed step there used to reach `engine.match` and
  /// throw. The failure was silent to the player and total to the log: it
  /// landed on the first night action of every online match.
  void _persist(WidgetRef ref) {
    final engine = ref.read(matchControllerProvider.notifier).engine;
    if (!engine.hasMatch) return;
    ref
        .read(matchRepositoryProvider)
        .persistStep(engine.match)
        .catchError((_) {});
  }
}
