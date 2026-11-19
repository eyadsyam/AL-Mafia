import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// The morning card «{name} كشف نفسه: شيخ الصالحين» with the line about his
/// three votes. Told to the whole table with the night's news; shared by the
/// on-table morning screen and the online council's morning.
class ElderRevealCard extends StatelessWidget {
  final String name;

  const ElderRevealCard({super.key, required this.name});

  static const Key card = ValueKey('morning_elder_revealed');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;
    return Container(
      key: card,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(radii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.morningElderRevealed(name),
            style: type.title.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.xs),
          Text(
            l10n.morningElderWeight,
            style: type.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
