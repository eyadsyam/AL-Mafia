import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/enums.dart' show PlayerStatus;
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/pass_screen.dart';
import '../../widgets/player_tile.dart';
import '../match_controller.dart';
import '../../widgets/textured_surface.dart';

/// The secret day ballot (screen S-12).
///
/// One tree for every voter, reached through the same identity gate as the
/// night turns: living players only, no self-vote, and an optional abstain
/// (FR-018). Because the ballot is identical for everyone, nothing about a
/// voter's role can be read off the screen they were handed (L-03).
class VotingScreen extends ConsumerStatefulWidget {
  /// Called once the last living player has voted.
  final VoidCallback onVotingComplete;

  /// Whether abstaining is offered. Comes from match settings.
  final bool allowAbstain;

  const VotingScreen({
    super.key,
    required this.onVotingComplete,
    this.allowAbstain = true,
  });

  static const Key confirmButton = ValueKey('voting_confirm');
  static const Key abstainButton = ValueKey('voting_abstain');

  @override
  ConsumerState<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends ConsumerState<VotingScreen> {
  /// Seat currently holding the phone, once they have passed the identity gate.
  int? _openedSeat;
  int? _selectedSeat;
  bool _abstaining = false;

  void _open(int seat) {
    setState(() {
      _openedSeat = seat;
      _selectedSeat = null;
      _abstaining = false;
    });
  }

  void _submit() {
    final controller = ref.read(matchControllerProvider.notifier);
    controller.submitVote(targetSeat: _abstaining ? null : _selectedSeat);
    setState(() {
      _openedSeat = null;
      _selectedSeat = null;
      _abstaining = false;
    });
    if (controller.engine.match.currentActorSeat == null) {
      widget.onVotingComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControllerProvider);
    if (state == null) return const SizedBox.shrink();

    final seat = state.currentActorSeat;
    if (seat == null) return const SizedBox.shrink();

    final players = state.public.players;

    if (_openedSeat != seat) {
      return PassScreen(
        targetName: players[seat].name,
        subtitle: context.l10n.votingSubtitle,
        onConfirmed: () => _open(seat),
      );
    }

    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    // On a revote the engine narrows the ballot to the tied seats (FR-020);
    // offering anything else would just produce a rejected vote.
    final ballot = ref
        .read(matchControllerProvider.notifier)
        .engine
        .currentVoteCandidates;
    final candidates = [
      for (final p in players)
        if (p.status == PlayerStatus.alive &&
            p.seat != seat &&
            (ballot == null || ballot.contains(p.seat)))
          p,
    ];

    final canSubmit = _abstaining || _selectedSeat != null;

    return AppBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.screenMargin,
                vertical: spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: spacing.xxl,
                    child: Center(
                      child: Text(
                        context.l10n.whoDoYouVoteOut,
                        style: type.title.copyWith(color: colors.textPrimary),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: candidates.length,
                      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
                      itemBuilder: (context, index) {
                        final p = candidates[index];
                        return PlayerTile(
                          seat: p.seat,
                          name: p.name,
                          state: _selectedSeat == p.seat && !_abstaining
                              ? PlayerTileState.selected
                              : PlayerTileState.normal,
                          onTap: () => setState(() {
                            _selectedSeat = p.seat;
                            _abstaining = false;
                          }),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  // The abstain slot is always laid out so the ballot's height
                  // does not change between matches that allow it and ones that
                  // do not.
                  SizedBox(
                    height: spacing.xxl,
                    child: widget.allowAbstain
                        ? OutlinedButton(
                            key: VotingScreen.abstainButton,
                            onPressed: () => setState(() {
                              _abstaining = true;
                              _selectedSeat = null;
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _abstaining
                                  ? colors.accentGold
                                  : colors.textSecondary,
                              side: BorderSide(
                                color: _abstaining
                                    ? colors.accentGold
                                    : colors.borderSubtle,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  radii.button,
                                ),
                              ),
                            ),
                            child: Text(context.l10n.abstain, style: type.body),
                          )
                        : const SizedBox.expand(),
                  ),
                  SizedBox(height: spacing.sm),
                  SizedBox(
                    height: spacing.xxl + spacing.sm,
                    child: FilledButton(
                      key: VotingScreen.confirmButton,
                      onPressed: canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        disabledBackgroundColor: colors.surfaceOverlay,
                        disabledForegroundColor: colors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(context.l10n.confirmVote, style: type.title),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
