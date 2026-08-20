import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repository_provider.dart';
import '../../../data/repository_types.dart';
import '../../../engine/analytics_builder.dart';
import '../../../engine/models/enums.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../match_controller.dart';
import '../../widgets/textured_surface.dart';
import '../../widgets/staggered_entrance.dart';

/// Post-game analytics for the match that was just played (S-15).
///
/// Reads the finished match straight off the engine rather than round-tripping
/// through storage, so analytics still works if the write failed.
class LiveAnalyticsScreen extends ConsumerWidget {
  final VoidCallback onClose;

  const LiveAnalyticsScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.read(matchControllerProvider.notifier).engine.match;
    return AnalyticsView(
      data: AnalyticsBuilder.build(match),
      names: {for (final p in match.players) p.seat: p.name},
      onClose: onClose,
    );
  }
}

/// Post-game analytics for a match reopened from History.
class StoredAnalyticsScreen extends ConsumerWidget {
  final int matchId;
  final VoidCallback onClose;

  const StoredAnalyticsScreen({
    super.key,
    required this.matchId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<MatchAnalytics>(
      future: ref.read(matchRepositoryProvider).loadAnalytics(matchId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Message(
            text: context.l10n.analyticsLoadFailed,
            onClose: onClose,
          );
        }
        final analytics = snapshot.data;
        if (analytics == null) {
          return _Message(text: '…', onClose: onClose);
        }
        return AnalyticsView(
          data: analytics.data,
          names: analytics.playerNames,
          onClose: onClose,
        );
      },
    );
  }
}

/// The four analytics tabs (S-15).
///
/// ## Why every role is on screen here and nowhere else
///
/// This view is the one place in the app that is allowed to show who was what
/// and who suspected whom. It is reachable only once a match has an outcome, so
/// nothing it renders can influence play (FR-019, FR-031). Everything shown is
/// a pure projection of the event log — no new facts are invented here.
class AnalyticsView extends StatelessWidget {
  final MatchAnalyticsData data;
  final Map<int, String> names;
  final VoidCallback onClose;

  const AnalyticsView({
    super.key,
    required this.data,
    required this.names,
    required this.onClose,
  });

  static const Key timelineTab = ValueKey('analytics_tab_timeline');
  static const Key playersTab = ValueKey('analytics_tab_players');
  static const Key suspicionTab = ValueKey('analytics_tab_suspicion');
  static const Key achievementsTab = ValueKey('analytics_tab_achievements');

  String _name(BuildContext context, int? seat) =>
      seat == null ? '—' : (names[seat] ?? context.l10n.seatFallback(seat));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final l10n = context.l10n;
    String nameOf(int? seat) => _name(context, seat);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: colors.surfaceBase,
        appBar: AppBar(
          backgroundColor: colors.surfaceBase,
          foregroundColor: colors.textPrimary,
          title: Text(l10n.analyticsTitle, style: type.title),
          leading: IconButton(
            onPressed: onClose,
            // `arrow_back`, not `arrow_forward`. Both are declared
          // `matchTextDirection: true`, so Flutter mirrors them under RTL:
          // `arrow_forward` renders pointing *left* in Arabic, which is the
          // wrong way for a back control. `arrow_back` means "backwards" and
          // the framework resolves which way that points.
          icon: const Icon(Icons.arrow_back),
            tooltip: l10n.back,
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: colors.accentGold,
            unselectedLabelColor: colors.textMuted,
            indicatorColor: colors.accentGold,
            tabs: [
              Tab(key: timelineTab, text: l10n.tabEvents),
              Tab(key: playersTab, text: l10n.tabPlayers),
              Tab(key: suspicionTab, text: l10n.tabSuspicions),
              Tab(key: achievementsTab, text: l10n.tabAchievements),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TimelineTab(data: data, nameOf: nameOf),
            _PlayersTab(data: data, nameOf: nameOf),
            _SuspicionTab(data: data, nameOf: nameOf),
            _AchievementsTab(data: data, nameOf: nameOf),
          ],
        ),
      ),
    );
  }
}

typedef _NameOf = String Function(int? seat);

// -----------------------------------------------------------------------------
// Timeline
// -----------------------------------------------------------------------------

class _TimelineTab extends StatelessWidget {
  final MatchAnalyticsData data;
  final _NameOf nameOf;

  const _TimelineTab({required this.data, required this.nameOf});

  String _describe(BuildContext context, TimelineRowData row) {
    final l10n = context.l10n;
    final actor = nameOf(row.actorSeat);
    final target = nameOf(row.targetSeat);
    return switch (row.kind) {
      'mafiaVote' => l10n.timelineMafiaVote(actor, target),
      'protect' => l10n.timelineProtect(actor, target),
      'investigate' => l10n.timelineInvestigate(actor, target),
      'suspect' => l10n.timelineSuspect(actor, target),
      'nightKill' => l10n.timelineNightKill(target),
      'saved' => l10n.timelineSaved(target),
      'dayElimination' => l10n.timelineDayElimination(target),
      // An unrecognised kind is a new engine event with no copy yet; showing
      // the raw key makes that obvious in review rather than hiding the row.
      _ => row.kind,
    };
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final l10n = context.l10n;
    if (data.timeline.isEmpty) {
      return _Empty(text: l10n.noEventsRecorded);
    }

    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: data.timeline.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final row = data.timeline[index];
        return TimelineRow(
          label: row.phase == GamePhase.night
              ? l10n.nightNumbered(row.dayNumber)
              : l10n.dayNumbered(row.dayNumber),
          description: _describe(context, row),
        );
      },
    );
  }
}

/// A single event line in the post-game timeline.
class TimelineRow extends StatelessWidget {
  final String label;
  final String description;

  const TimelineRow({
    super.key,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(label, style: type.caption.copyWith(color: colors.textMuted)),
          SizedBox(width: spacing.md),
          Expanded(
            child: Text(
              description,
              style: type.body.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Players
// -----------------------------------------------------------------------------

class _PlayersTab extends StatelessWidget {
  final MatchAnalyticsData data;
  final _NameOf nameOf;

  const _PlayersTab({required this.data, required this.nameOf});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    final seats = data.finalRoles.keys.toList()..sort();
    if (seats.isEmpty) return _Empty(text: l10n.noPlayerData);

    final accuracyBySeat = {for (final a in data.suspicionAccuracy) a.seat: a};

    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: seats.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final seat = seats[index];
        final role = data.finalRoles[seat]!;
        final accuracy = accuracyBySeat[seat];

        return Container(
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(radii.card),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameOf(seat),
                      style: type.body.copyWith(color: colors.textPrimary),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      accuracy == null
                          ? l10n.noSuspicionsByPlayer
                          : l10n.suspicionAccuracyLine(
                              accuracy.correctSuspicions,
                              accuracy.totalSuspicions,
                            ),
                      style: type.caption.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                EngineCopy.roleName(l10n, role),
                style: type.body.copyWith(color: colors.accentGold),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Suspicion map
// -----------------------------------------------------------------------------

class _SuspicionTab extends StatelessWidget {
  final MatchAnalyticsData data;
  final _NameOf nameOf;

  const _SuspicionTab({required this.data, required this.nameOf});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final l10n = context.l10n;

    final rows = <Widget>[];
    final voters = data.suspicionMatrix.counts.keys.toList()..sort();
    for (final voter in voters) {
      final targets = data.suspicionMatrix.counts[voter]!;
      final targetSeats = targets.keys.toList()..sort();
      rows.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nameOf(voter),
                style: type.body.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: spacing.xs),
              Text(
                [
                  for (final t in targetSeats) '${nameOf(t)} ×${targets[t]}',
                ].join(l10n.listSeparator),
                style: type.bodySmall.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (rows.isEmpty) return _Empty(text: l10n.noSuspicionsRecorded);

    return ListView(padding: EdgeInsets.all(spacing.md), children: rows);
  }
}

// -----------------------------------------------------------------------------
// Achievements
// -----------------------------------------------------------------------------

class _AchievementsTab extends StatelessWidget {
  final MatchAnalyticsData data;
  final _NameOf nameOf;

  const _AchievementsTab({required this.data, required this.nameOf});

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    if (data.achievements.isEmpty) {
      return _Empty(text: context.l10n.noAchievements);
    }

    return ListView.separated(
      padding: EdgeInsets.all(spacing.md),
      itemCount: data.achievements.length,
      separatorBuilder: (_, __) => SizedBox(height: spacing.sm),
      itemBuilder: (context, index) {
        final achievement = data.achievements[index];
        final l10n = context.l10n;
        // Badges arrive one after another rather than all at once. This is the
        // match's curtain call and the only place in the app where a list is
        // allowed to show off — everything in here is post-game and public.
        return StaggeredEntrance(
          index: index,
          child: AchievementBadge(
            title: EngineCopy.achievementTitle(l10n, achievement.code),
            description: EngineCopy.achievementDescription(
              l10n,
              achievement.code,
            ),
            holders: [
              for (final seat in achievement.seats) nameOf(seat),
            ].join(l10n.listSeparator),
          ),
        );
      },
    );
  }
}

/// One earned achievement and who holds it.
class AchievementBadge extends StatelessWidget {
  final String title;
  final String description;
  final String holders;

  const AchievementBadge({
    super.key,
    required this.title,
    required this.description,
    required this.holders,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(color: colors.accentGold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: type.title.copyWith(color: colors.accentGold)),
          SizedBox(height: spacing.xs),
          Text(
            description,
            style: type.bodySmall.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.sm),
          Text(holders, style: type.body.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _Empty extends StatelessWidget {
  final String text;

  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Text(
        text,
        style: context.typography.body.copyWith(color: colors.textMuted),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback onClose;

  const _Message({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: context.typography.body.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                SizedBox(height: spacing.lg),
                TextButton(onPressed: onClose, child: Text(context.l10n.back)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
