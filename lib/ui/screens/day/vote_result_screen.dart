import 'package:flutter/material.dart';

import '../../../engine/models/enums.dart' show Role;
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/vote_bar.dart';
import '../../widgets/textured_surface.dart';

/// The on-table vote result (screen S-13).
///
/// Shows the tally and, when someone was eliminated, their true role — this is
/// the one moment in play where a role becomes public, and it is public to
/// everybody at once. Who voted for whom stays sealed until the post-game
/// analytics (FR-019/FR-020).
class VoteResultScreen extends StatelessWidget {
  /// seat -> display name, for every seat that received at least one vote.
  final Map<int, String> names;

  /// seat -> vote count.
  final Map<int, int> tally;

  /// Seat eliminated by this vote, or null on a tie / no-elimination rule.
  final int? eliminatedSeat;

  /// Revealed role of the eliminated player. Null when nobody was eliminated.
  final Role? eliminatedRole;

  /// Seats that tied, when the tie rule produced no elimination.
  final List<int> tiedSeats;

  /// True when the tie rule calls for a revote rather than continuing.
  final bool revoteRequired;

  final VoidCallback onContinue;

  const VoteResultScreen({
    super.key,
    required this.names,
    required this.tally,
    required this.onContinue,
    this.eliminatedSeat,
    this.eliminatedRole,
    this.tiedSeats = const [],
    this.revoteRequired = false,
  });

  Color _roleColor(BuildContext context, Role role) {
    final colors = context.colors;
    switch (role) {
      case Role.mafia:
        return colors.roleMafia;
      case Role.doctor:
        return colors.roleDoctor;
      case Role.detective:
        return colors.roleDetective;
      case Role.citizen:
        return colors.roleCitizen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final entries = tally.entries.toList()
      ..sort((a, b) {
        final byVotes = b.value.compareTo(a.value);
        return byVotes != 0 ? byVotes : a.key.compareTo(b.key);
      });
    final maxVotes = entries.isEmpty
        ? 0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final String headline;
    if (eliminatedSeat != null) {
      headline = l10n.eliminatedHeadline(names[eliminatedSeat] ?? '');
    } else if (revoteRequired) {
      headline = l10n.tieRevoteHeadline;
    } else if (tiedSeats.isNotEmpty) {
      headline = l10n.tieNoEliminationHeadline;
    } else {
      headline = l10n.nobodyEliminated;
    }

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
                  Text(
                    headline,
                    style: type.headline.copyWith(color: colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.sm),
                  // Reserved role-chip slot: the same height whether or not a
                  // role is being revealed.
                  SizedBox(
                    height: spacing.xl,
                    child: Center(
                      child: eliminatedRole == null
                          ? const SizedBox.shrink()
                          : Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing.md,
                                vertical: spacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceRaised,
                                borderRadius: BorderRadius.circular(
                                  radii.button,
                                ),
                                border: Border.all(
                                  color: _roleColor(context, eliminatedRole!),
                                ),
                              ),
                              child: Text(
                                l10n.wasRole(
                                  EngineCopy.roleName(l10n, eliminatedRole!),
                                ),
                                style: type.body.copyWith(
                                  color: _roleColor(context, eliminatedRole!),
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // `entries` is already in tally order, so the index is
                        // the row's rank and the cascade runs top to bottom —
                        // the eliminated player's bar lands last.
                        for (final (i, entry) in entries.indexed)
                          VoteBar(
                            name: names[entry.key] ?? '—',
                            votes: entry.value,
                            maxVotes: maxVotes,
                            index: i,
                            highlighted:
                                entry.key == eliminatedSeat ||
                                tiedSeats.contains(entry.key),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  SizedBox(
                    height: spacing.xxl + spacing.sm,
                    child: FilledButton(
                      onPressed: onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(
                        revoteRequired ? l10n.revote : l10n.continueAction,
                        style: type.title,
                      ),
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
