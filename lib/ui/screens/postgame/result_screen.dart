import 'package:flutter/material.dart';

import '../../../engine/models/enums.dart' as engine;
import '../../l10n_ext.dart';
import '../../../app/asset_constants.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/textured_surface.dart';

/// A single row in the result table showing a player's role and status.
class ResultRow {
  final int seat;
  final String name;
  final engine.Role role;

  /// When the player was eliminated (e.g. "Night 1", "Day 2", "نجا").
  /// Null means they survived.
  final String? eliminatedLabel;

  const ResultRow({
    required this.seat,
    required this.name,
    required this.role,
    this.eliminatedLabel,
  });
}

/// Result Screen (S-14) — post-game winner reveal and role exposure.
///
/// Displayed after the match ends. Shows the winning alignment prominently,
/// then a table of all players with their true roles and elimination times.
/// This is the ONLY screen that reveals roles during the match (since it's
/// after the match).
///
/// Reference: spec FR-022, T036
class ResultScreen extends StatelessWidget {
  /// The winning alignment (Mafia or Town).
  final engine.Alignment winner;

  /// All players with their roles and elimination status.
  final List<ResultRow> rows;

  /// Callback when "التحليلات" is tapped.
  final VoidCallback onAnalytics;

  /// Callback when "الرئيسية" is tapped.
  final VoidCallback onHome;

  const ResultScreen({
    super.key,
    required this.winner,
    required this.rows,
    required this.onAnalytics,
    required this.onHome,
  });

  String _winnerText(BuildContext context, engine.Alignment alignment) =>
      alignment == engine.Alignment.mafia
      ? context.l10n.mafiaWins
      : context.l10n.townWins;

  Color _getRoleColor(BuildContext context, engine.Role role) {
    final colors = context.colors;
    switch (role) {
      case engine.Role.mafia:
        return colors.roleMafia;
      case engine.Role.doctor:
        return colors.roleDoctor;
      case engine.Role.detective:
        return colors.roleDetective;
      case engine.Role.citizen:
        return colors.roleCitizen;
    }
  }

  String _getRoleLabel(BuildContext context, engine.Role role) =>
      EngineCopy.roleName(context.l10n, role);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    final winnerColor = winner == engine.Alignment.mafia
        ? colors.roleMafia
        : colors.roleDoctor; // Use a town-aligned color

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
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
                    // Winner announcement
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.md,
                        vertical: spacing.lg,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceRaised,
                        borderRadius: BorderRadius.circular(radii.card),
                        border: Border.all(color: winnerColor, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            context.l10n.gameOver,
                            style: type.caption.copyWith(
                              color: colors.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: spacing.md),
                          Text(
                            _winnerText(context, winner),
                            style: type.headline.copyWith(color: winnerColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing.lg),

                    // Player roles table
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: spacing.sm),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final roleColor = _getRoleColor(context, row.role);

                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.md,
                              vertical: spacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceRaised,
                              borderRadius: BorderRadius.circular(radii.card),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                // The player's card, in full colour at last.
                                //
                                // This is the payoff for a whole match of
                                // looking at a monochrome back: the gallery art
                                // is the same painting the in-match face was cut
                                // from, without the desaturation and without the
                                // luminance matching. It is safe here and only
                                // here — the match has an outcome, every role is
                                // already public, and nothing on this screen can
                                // influence play.
                                _GalleryThumb(role: row.role),
                                SizedBox(width: spacing.md),

                                // Seat number
                                Container(
                                  width: spacing.lg + spacing.md,
                                  height: spacing.lg + spacing.md,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceOverlay,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${row.seat + 1}',
                                    style: type.caption.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                SizedBox(width: spacing.md),

                                // Player name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        row.name,
                                        style: type.body.emphasised.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (row.eliminatedLabel != null) ...[
                                        SizedBox(height: spacing.xs),
                                        Text(
                                          row.eliminatedLabel!,
                                          style: type.bodySmall.copyWith(
                                            color: colors.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: spacing.md),

                                // Role chip
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing.sm,
                                    vertical: spacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: roleColor,
                                    borderRadius: BorderRadius.circular(
                                      radii.button,
                                    ),
                                  ),
                                  child: Text(
                                    _getRoleLabel(context, row.role),
                                    style: type.caption.copyWith(
                                      color: colors.surfaceBase,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: spacing.lg),

                    // Action buttons
                    FilledButton(
                      onPressed: onAnalytics,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accentGold,
                        foregroundColor: colors.surfaceBase,
                        padding: EdgeInsets.symmetric(vertical: spacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(context.l10n.analytics, style: type.title),
                    ),
                    SizedBox(height: spacing.md),
                    OutlinedButton(
                      onPressed: onHome,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.borderSubtle),
                        padding: EdgeInsets.symmetric(vertical: spacing.lg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radii.button),
                        ),
                      ),
                      child: Text(
                        context.l10n.homeAction,
                        style: type.title.copyWith(color: colors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full-colour role card for one player, at roster-row size.
///
/// ## Why this widget exists rather than an inline `Image.asset`
///
/// The `Role -> gallery asset` map is the single dangerous line on this screen,
/// and putting it in one named place means there is exactly one thing for
/// `handoff_purity_test.dart` to find if it ever migrates somewhere it should
/// not. The gallery art is deliberately *not* luminance-matched across roles —
/// matching it would defeat the point of having a full-colour set — so a copy of
/// this mapping on an in-hand surface would leak brightness and hue at once,
/// and would sail past `luminance_budget_test.dart`, which only measures
/// `card_face_*`.
class _GalleryThumb extends StatelessWidget {
  final engine.Role role;

  const _GalleryThumb({required this.role});

  String get _art => switch (role) {
    engine.Role.mafia => AppGallery.galleryMafia,
    engine.Role.doctor => AppGallery.galleryDoctor,
    engine.Role.detective => AppGallery.galleryDetective,
    engine.Role.citizen => AppGallery.galleryCitizen,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;

    // Card proportions, not a square thumbnail: at a glance the roster should
    // read as a hand of cards laid face-up on the table.
    final height = spacing.xl + spacing.lg;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radii.button),
      child: SizedBox(
        width: height * 2 / 3,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.surfaceOverlay),
          child: Image.asset(
            _art,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Decoded down to roughly what is drawn. The source is 1024x1536 and
            // there is one of these per player; at full resolution a ten-player
            // roster would hold ~60MB of decoded bitmaps for thumbnails a
            // centimetre tall.
            cacheHeight: 256,
            // The role is already stated in text on the same row. Announcing the
            // art as well would make a screen reader say it twice.
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}
