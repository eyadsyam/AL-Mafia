import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/character_bonds.dart';
import '../../../engine/models/enums.dart' as engine;
import '../../../engine/coaching.dart';
import '../../../transport/local_transport.dart';
import '../../../transport/online_transport.dart';
import '../../l10n_ext.dart';
import '../../../app/asset_constants.dart';
import '../../economy/economy_capabilities.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/textured_surface.dart';
import '../../fun/award_ribbon.dart';
import '../../fun/match_awards.dart';
import '../../fun/character_dossiers.dart' show BondLetterArrivedCard;
import '../match_controller.dart';

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
  /// Opens the post-game autopsy, or null when there is nothing to open.
  ///
  /// Null hides the button rather than disabling it: a greyed-out control on
  /// the last screen of a match reads as something broken, and there is nothing
  /// broken about an online match having no local record to inspect.
  final VoidCallback? onAnalytics;

  /// Callback when "الرئيسية" is tapped.
  final VoidCallback onHome;

  /// Doc 13 §4.4's «كان ممكن», by seat.
  ///
  /// # Why this tier is safe when the other two are not
  ///
  /// It is conditioned on a player's own role, their own suspicions and their
  /// own votes, which would be a leak anywhere else in the app. Here the match
  /// is over, every role is already printed on this very screen, and nothing
  /// said here can change a decision — there are none left. Doc 13 §4.1's
  /// table says so in as many words.
  ///
  /// # And why a seat can be missing
  ///
  /// Doc 13 §9: *"post-match coaching generates from real data only; no
  /// generic filler."* A player who did nothing remarkable gets nothing, not a
  /// platitude. An absent seat here is a correct result and not a gap to fill.
  final Map<int, List<CoachingNote>> coaching;

  /// Phase 109: the finished match's awards (`localMatchAwards`). Empty hides
  /// the ribbon. Safe here for the same reason the roles are: it is over.
  final List<MatchAward> awards;

  const ResultScreen({
    super.key,
    required this.winner,
    required this.rows,
    this.onAnalytics,
    required this.onHome,
    this.coaching = const {},
    this.awards = const [],
  });

  /// Key on the «كان ممكن» block for a given seat.
  static Key coachingKey(int seat) => ValueKey('coaching_$seat');

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

  List<Widget> _coachingLines(BuildContext context, int seat) {
    final notes = coaching[seat] ?? const <CoachingNote>[];
    if (notes.isEmpty) return const [];

    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final nameOf = {for (final r in rows) r.seat: r.name};

    return [
      SizedBox(height: spacing.sm),
      Column(
        key: ResultScreen.coachingKey(seat),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.coachingTitle,
            style: type.caption.copyWith(color: colors.accentGold),
          ),
          for (final note in notes) ...[
            SizedBox(height: spacing.xs),
            Text(
              EngineCopy.coaching(context.l10n, note, (s) => nameOf[s] ?? ''),
              style: type.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    final winnerColor = winner == engine.Alignment.mafia
        ? colors.roleMafia
        : colors.roleDoctor; // Use a town-aligned color

    return _BondResultRecorder(
      winner: winner,
      rows: rows,
      child: Scaffold(
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
                      // The announcement, the awards and the roster scroll as
                      // one; only the two buttons are pinned. On a 640-high
                      // phone the fixed stack above the roster (card + awards)
                      // left the roster a sliver and overflowed at larger text.
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: spacing.md,
                                  vertical: spacing.lg,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceRaised,
                                  borderRadius: BorderRadius.circular(
                                    radii.card,
                                  ),
                                  border: Border.all(
                                    color: winnerColor,
                                    width: 2,
                                  ),
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
                                      style: type.headline.copyWith(
                                        color: winnerColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: spacing.md),
                            ),
                            SliverToBoxAdapter(
                              child: _BondResultMoment(
                                winner: winner,
                                rows: rows,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(height: spacing.md),
                            ),
                            if (awards.isNotEmpty)
                              SliverToBoxAdapter(
                                child: AwardRibbon(awards: awards),
                              ),

                            // Player roles table
                            SliverList.separated(
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: spacing.sm),
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final roleColor = _getRoleColor(
                                  context,
                                  row.role,
                                );

                                return Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: spacing.md,
                                    vertical: spacing.md,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceRaised,
                                    borderRadius: BorderRadius.circular(
                                      radii.card,
                                    ),
                                    border: Border.all(
                                      color: colors.borderSubtle,
                                    ),
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
                                              style: type.body.emphasised
                                                  .copyWith(
                                                    color: colors.textPrimary,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (row.eliminatedLabel !=
                                                null) ...[
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
                                            // «كان ممكن» — doc 13 §4.4. Under the
                                            // player's own name, because it is about
                                            // them and about nobody else, and in
                                            // muted body text because doc 13 asks
                                            // for *"an observation, never a scold.
                                            // No score, no grade, no stars."*
                                            ..._coachingLines(
                                              context,
                                              row.seat,
                                            ),
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
                          ],
                        ),
                      ),
                      SizedBox(height: spacing.lg),

                      // Action buttons
                      if (onAnalytics != null) ...[
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
                          child: Text(
                            context.l10n.analytics,
                            style: type.title,
                          ),
                        ),
                        SizedBox(height: spacing.md),
                      ],
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
      ),
    );
  }
}

bool _bondsEnabled(BuildContext context) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!container.exists(economyCapabilitiesProvider)) return false;
    return container
            .read(economyCapabilitiesProvider)
            .valueOrNull
            ?.fun
            .characterBonds ==
        true;
  } catch (_) {
    return false;
  }
}

class _BondResultRecorder extends StatefulWidget {
  final engine.Alignment winner;
  final List<ResultRow> rows;
  final Widget child;
  const _BondResultRecorder({
    required this.winner,
    required this.rows,
    required this.child,
  });

  @override
  State<_BondResultRecorder> createState() => _BondResultRecorderState();
}

class _BondResultRecorderState extends State<_BondResultRecorder> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled || !_bondsEnabled(context)) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _record());
  }

  Future<void> _record() async {
    if (!mounted) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final controller = container.read(matchControllerProvider.notifier);
      final transport = controller.transport;
      final String receiptId;
      final DateTime completedAt;
      engine.Role? personal;
      if (transport is LocalTransport) {
        if (!transport.engine.hasMatch) return;
        final match = transport.engine.match;
        final outcome = match.outcome;
        if (match.phase != engine.GamePhase.result || outcome == null) return;
        receiptId = 'local-${match.id}';
        completedAt = outcome.completedAt;
      } else if (transport is OnlineTransport) {
        // The same public result every seat sees; this device adds the one
        // role it held, which the roster above has just shown to everyone.
        final snapshot = transport.snapshot;
        final outcome = snapshot.outcome;
        if (snapshot.phase != engine.GamePhase.result || outcome == null) {
          return;
        }
        receiptId = 'online-${transport.roomId}';
        completedAt = outcome.completedAt;
        final seat = snapshot.viewerSeat;
        personal = widget.rows
            .where((row) => row.seat == seat)
            .map((row) => row.role)
            .firstOrNull;
      } else {
        return;
      }
      final roles = widget.rows.map((row) => row.role).toSet();
      final survivors = widget.rows
          .where((row) => row.eliminatedLabel == null)
          .map((row) => row.role)
          .toSet();
      final zeroDeaths = widget.rows.every(
        (row) => row.eliminatedLabel == null,
      );
      final moment = characterMomentRole(
        winner: widget.winner,
        roles: roles,
        survivingRoles: survivors,
        personalRole: personal,
        zeroDeaths: zeroDeaths,
      );
      await container
          .read(characterBondLedgerProvider.notifier)
          .record(
            CharacterBondCase(
              receiptId: receiptId,
              completedAt: completedAt,
              winner: widget.winner,
              roles: roles,
              survivingRoles: survivors,
              personalRole: personal,
              zeroDeaths: zeroDeaths,
              momentRole: moment,
            ),
          );
    } catch (_) {
      // A flavour ledger must never obstruct or replace the public result.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BondResultMoment extends ConsumerWidget {
  final engine.Alignment winner;
  final List<ResultRow> rows;
  const _BondResultMoment({required this.winner, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_bondsEnabled(context) || rows.isEmpty) return const SizedBox.shrink();
    final arrived = ref.watch(bondLetterArrivedProvider);
    if (arrived != null) return BondLetterArrivedCard(arrival: arrived);
    return _momentLine(context);
  }

  Widget _momentLine(BuildContext context) {
    final roles = rows.map((row) => row.role).toSet();
    final survivors = rows
        .where((row) => row.eliminatedLabel == null)
        .map((row) => row.role)
        .toSet();
    final role = characterMomentRole(
      winner: winner,
      roles: roles,
      survivingRoles: survivors,
      zeroDeaths: rows.every((row) => row.eliminatedLabel == null),
    );
    final line = switch (role) {
      engine.Role.mafia => context.l10n.bondMomentMafia,
      engine.Role.doctor => context.l10n.bondMomentDoctor,
      engine.Role.detective => context.l10n.bondMomentDetective,
      engine.Role.citizen => context.l10n.bondMomentCitizen,
    };
    return Text(
      line,
      textAlign: TextAlign.center,
      style: context.typography.body.copyWith(
        color: context.colors.textSecondary,
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
/// Reuses the result screen's single role-to-gallery map on other public,
/// post-match-only surfaces. The map itself remains private and singular.
class RoleGalleryPortrait extends StatelessWidget {
  final engine.Role role;
  final double height;
  const RoleGalleryPortrait({
    super.key,
    required this.role,
    required this.height,
  });

  @override
  Widget build(BuildContext context) =>
      _GalleryThumb(role: role, height: height);

  /// The full-colour painting for [role]. The map itself stays in
  /// [_GalleryThumb], the one place that owns it.
  static String art(engine.Role role) => _GalleryThumb(role: role)._art;
}

class _GalleryThumb extends StatelessWidget {
  final engine.Role role;
  final double? height;

  const _GalleryThumb({required this.role, this.height});

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
    final resolvedHeight = height ?? spacing.xl + spacing.lg;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radii.button),
      child: SizedBox(
        width: resolvedHeight * 2 / 3,
        height: resolvedHeight,
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
