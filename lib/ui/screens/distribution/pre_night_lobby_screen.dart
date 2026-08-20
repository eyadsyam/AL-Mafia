import 'package:flutter/material.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/textured_surface.dart';

/// Pre-Night Lobby Screen (S-07) — calm transition before night begins.
///
/// Displayed on-table to all players when day ends and night is about to begin.
/// Shows the night number, player count, and an instruction to place the phone
/// on the table. No secret information is shown.
///
/// Reference: spec FR-017, T030
class PreNightLobbyScreen extends StatelessWidget {
  /// Night number (1-indexed).
  final int dayNumber;

  /// Number of players still alive in this night.
  final int aliveCount;

  /// Callback when "ابدأ الليل" is tapped.
  final VoidCallback onBeginNight;

  const PreNightLobbyScreen({
    super.key,
    required this.dayNumber,
    required this.aliveCount,
    required this.onBeginNight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      // Centred when the content fits, scrollable when it does not.
      //
      // The display face is deliberately large and this screen stacks three
      // blocks beneath it, so on a short viewport — or at the 130% text scale
      // the accessibility spec calls for — the column is taller than the screen.
      // `minHeight` keeps [Spacer] working (and so keeps the button on the
      // bottom edge) whenever there is slack; [IntrinsicHeight] lets the column
      // fall back to its natural height and scroll when there is not.
      body: AppBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: spacing.maxContentWidth,
                    minHeight: viewport.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.screenMargin,
                        vertical: spacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.nightApproaching,
                            style: type.display.copyWith(
                              color: colors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacing.xl),
                          _StatCard(
                            label: l10n.nightLabel,
                            value: '$dayNumber',
                            valueColor: colors.accentGold,
                          ),
                          SizedBox(height: spacing.lg),
                          _StatCard(
                            label: l10n.aliveCountLabel,
                            value: '$aliveCount',
                            valueColor: colors.accentSage,
                          ),
                          SizedBox(height: spacing.xl),
                          _Instruction(text: l10n.placePhoneOnTable),
                          const Spacer(),
                          SizedBox(height: spacing.lg),
                          _BeginButton(
                            label: l10n.beginNight,
                            onPressed: onBeginNight,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled figure — the night number or the living count.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: type.caption.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.sm),
          Text(
            value,
            style: type.display.copyWith(color: valueColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  final String text;

  const _Instruction({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.lg,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceOverlay,
        borderRadius: BorderRadius.circular(radii.card),
      ),
      child: Text(
        text,
        style: type.body.copyWith(color: colors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _BeginButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BeginButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.accentGold,
        foregroundColor: colors.surfaceBase,
        padding: EdgeInsets.symmetric(vertical: spacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.button),
        ),
      ),
      child: Text(label, style: type.title),
    );
  }
}
