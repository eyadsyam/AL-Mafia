import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../data/repository_provider.dart';
import '../../../data/online_match_history.dart';
import '../../../data/repository_types.dart';
// Prefixed: the engine's `Alignment` collides with Flutter's.
import '../../../engine/models/enums.dart' as engine;
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/textured_surface.dart';
import '../../economy/waiting_banner.dart';

/// Finished matches, newest first (S-16).
///
/// Shows players, winner and night count — deliberately not roles. Who was what
/// lives one tap deeper, in analytics, so a glance at History over someone's
/// shoulder gives nothing away about a group's habits.
class HistoryScreen extends ConsumerStatefulWidget {
  /// Opens analytics for a stored match.
  final void Function(int matchId) onOpen;

  final VoidCallback onBack;

  const HistoryScreen({super.key, required this.onOpen, required this.onBack});

  static const Key list = ValueKey('history_list');
  static const Key deleteConfirm = ValueKey('history_delete_confirm');
  static const Key deleteCancel = ValueKey('history_delete_cancel');

  static Key tileFor(int matchId) => ValueKey('history_tile_$matchId');

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Null until the first load completes; empty means "nothing played yet".
  ///
  /// The list is held in state rather than rebuilt from a `Future` on every
  /// frame because `Dismissible` requires its widget to leave the tree in the
  /// same frame the dismissal completes. Re-reading storage would put the old
  /// row back for however long the read takes, and Flutter asserts on exactly
  /// that ("a dismissed Dismissible widget is still part of the tree").
  List<MatchSummary>? _summaries;
  List<Map<String, dynamic>> _online = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summaries = await ref.read(matchRepositoryProvider).listHistory();
    if (!mounted) return;
    setState(() => _summaries = summaries);
    // The online summaries come from platform storage, which is a different
    // dependency with a different failure mode: a harness with no plugin, or a
    // browser with site data blocked, can leave that read pending forever.
    // Read it after the offline list is already on screen so the screen never
    // waits on it.
    final online = await OnlineMatchHistory.load();
    if (!mounted || online.isEmpty) return;
    setState(() => _online = online);
  }

  /// Deleting a match is not undoable, so it is confirmed before the swipe is
  /// allowed to complete rather than after.
  Future<bool> _confirmDelete(MatchSummary summary) async {
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
          l10n.deleteMatchTitle,
          style: type.title.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          l10n.deleteMatchBody,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            key: HistoryScreen.deleteCancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancel,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
          TextButton(
            key: HistoryScreen.deleteConfirm,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.deleteAction,
              style: type.body.copyWith(color: colors.accentCrimson),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;
    await ref.read(matchRepositoryProvider).deleteMatch(summary.id);
    return true;
  }

  String _winnerLabel(engine.Alignment? winner) => switch (winner) {
    engine.Alignment.mafia => context.l10n.mafiaWon,
    engine.Alignment.town => context.l10n.townWon,
    null => context.l10n.endedWithoutResult,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      appBar: AppBar(
        backgroundColor: colors.surfaceBase,
        foregroundColor: colors.textPrimary,
        title: Text(l10n.historyTitle, style: type.title),
        leading: IconButton(
          onPressed: widget.onBack,
          // `arrow_back`, not `arrow_forward`. Both are declared
          // `matchTextDirection: true`, so Flutter mirrors them under RTL:
          // `arrow_forward` renders pointing *left* in Arabic, which is the
          // wrong way for a back control. `arrow_back` means "backwards" and
          // the framework resolves which way that points.
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.back,
        ),
      ),
      // Phase 108: history is a waiting surface; zero size unless switched
      // on and filled.
      bottomNavigationBar: const SafeArea(top: false, child: WaitingBanner()),
      body: AppBackdrop(
        image: AppImages.bgNight,
        child: Builder(
          builder: (context) {
            final summaries = _summaries;
            if (summaries == null) {
              return Center(
                child: SizedBox.square(
                  dimension: UiPolishTokens.progressSize,
                  child: CircularProgressIndicator(
                    strokeWidth: UiPolishTokens.progressStroke,
                    color: colors.accentGold,
                  ),
                ),
              );
            }
            if (summaries.isEmpty && _online.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(spacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AppCouncilArt.whisperSeal,
                        width: UiPolishTokens.emptyEmblem,
                        height: UiPolishTokens.emptyEmblem,
                        color: colors.accentGold.withValues(
                          alpha: UiPolishTokens.emptyEmblemOpacity,
                        ),
                        excludeFromSemantics: true,
                      ),
                      SizedBox(height: spacing.lg),
                      Text(
                        l10n.noPastMatches,
                        textAlign: TextAlign.center,
                        style: type.title.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              key: HistoryScreen.list,
              padding: EdgeInsets.all(spacing.md),
              itemCount: summaries.length + _online.length,
              separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
              itemBuilder: (context, index) {
                if (index < _online.length) {
                  final row = _online[index];
                  final names = (row['names'] as List).whereType<String>();
                  final winner = row['winner'] == 'mafia'
                      ? engine.Alignment.mafia
                      : engine.Alignment.town;
                  return _CaseFile(
                    key: ValueKey('online_history_${row['roomId']}'),
                    winner: winner,
                    title:
                        '${l10n.onlineHistoryLabel} · ${_winnerLabel(winner)}',
                    meta: l10n.onlineMatchMeta(
                      names.length,
                      row['days'] as int,
                    ),
                    names: names.join(l10n.listSeparator),
                  );
                }
                final summary = summaries[index - _online.length];
                return Dismissible(
                  key: HistoryScreen.tileFor(summary.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(summary),
                  // Drop the row from local state in the same frame the
                  // dismissal completes; storage has already been updated by
                  // `_confirmDelete`.
                  onDismissed: (_) => setState(
                    () => _summaries = [
                      for (final s in summaries)
                        if (s.id != summary.id) s,
                    ],
                  ),
                  background: Container(
                    alignment: AlignmentDirectional.centerStart,
                    padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                    decoration: BoxDecoration(
                      color: colors.accentCrimson,
                      borderRadius: BorderRadius.circular(radii.card),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: colors.textPrimary,
                    ),
                  ),
                  child: _CaseFile(
                    winner: summary.winner,
                    title: _winnerLabel(summary.winner),
                    meta: l10n.matchMeta(summary.playerCount, summary.nights),
                    names: summary.playerNames.join(l10n.listSeparator),
                    onTap: () => widget.onOpen(summary.id),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// One finished match as a case file: the winning side's emblem, the verdict,
/// the table. The emblem is the council's public victory mask; the winner is
/// already the row's title, so it tells a glance nothing the text does not.
class _CaseFile extends StatelessWidget {
  final engine.Alignment? winner;
  final String title;
  final String meta;
  final String names;
  final VoidCallback? onTap;

  const _CaseFile({
    super.key,
    required this.winner,
    required this.title,
    required this.meta,
    required this.names,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final tint = switch (winner) {
      engine.Alignment.mafia => colors.accentCrimson,
      engine.Alignment.town => colors.accentGold,
      null => colors.textMuted,
    };
    final emblem = switch (winner) {
      engine.Alignment.mafia => AppCouncilArt.victoryMafia,
      engine.Alignment.town => AppCouncilArt.victoryTown,
      null => AppCouncilArt.whisperSeal,
    };
    return Material(
      color: colors.surfaceRaised.withValues(
        alpha: UiPolishTokens.caseSurfaceOpacity,
      ),
      borderRadius: BorderRadius.circular(radii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: tint, width: UiPolishTokens.caseStripe),
            ),
          ),
          padding: EdgeInsets.all(spacing.md),
          child: Row(
            children: [
              Image.asset(
                emblem,
                width: UiPolishTokens.caseEmblem,
                height: UiPolishTokens.caseEmblem,
                color: tint.withValues(alpha: UiPolishTokens.emblemOpacity),
                excludeFromSemantics: true,
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: type.body.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          meta,
                          style: type.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      names,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.bodySmall.emphasised.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
