import 'models/enums.dart';
import 'models/match.dart';
import 'models/timeline_event.dart';

/// One row of the post-game timeline, chronologically ordered.
class TimelineRowData {
  final int dayNumber;
  final GamePhase phase;
  final String kind;
  final int? actorSeat;
  final int? targetSeat;
  final DateTime at;

  const TimelineRowData({
    required this.dayNumber,
    required this.phase,
    required this.kind,
    this.actorSeat,
    this.targetSeat,
    required this.at,
  });

  @override
  String toString() =>
      'TimelineRowData(dayNumber=$dayNumber, phase=$phase, kind=$kind, '
      'actorSeat=$actorSeat, targetSeat=$targetSeat, at=$at)';
}

/// Per-player night-suspicion accuracy.
/// A citizen's suspicion of player X is "correct" iff X's role alignment is mafia.
class SuspicionAccuracy {
  final int seat;
  final int totalSuspicions;
  final int correctSuspicions;

  const SuspicionAccuracy({
    required this.seat,
    required this.totalSuspicions,
    required this.correctSuspicions,
  });

  /// The accuracy rate (correctSuspicions / totalSuspicions).
  /// Returns 0 if totalSuspicions is 0.
  double get rate => totalSuspicions == 0 ? 0.0 : correctSuspicions / totalSuspicions;

  @override
  String toString() =>
      'SuspicionAccuracy(seat=$seat, totalSuspicions=$totalSuspicions, '
      'correctSuspicions=$correctSuspicions, rate=$rate)';
}

/// Who suspected whom, and how often.
/// suspicionMatrix[voterSeat][targetSeat] = count
class SuspicionMatrix {
  final Map<int, Map<int, int>> counts;

  const SuspicionMatrix({required this.counts});

  @override
  String toString() => 'SuspicionMatrix(counts=$counts)';
}

/// A post-game achievement earned from the event log.
class Achievement {
  /// Stable snake_case identifier.
  ///
  /// The engine decides *that* an achievement was earned; the localisation
  /// layer decides what to call it. Keeping the title and blurb out of here is
  /// what lets `lib/engine` stay pure Dart and language-agnostic (L-16,
  /// FR-034).
  final String code;

  /// Player seats that earned this achievement.
  final List<int> seats;

  const Achievement({required this.code, required this.seats});

  @override
  String toString() => 'Achievement(code=$code, seats=$seats)';
}

/// Post-game analytics data for a completed match.
class MatchAnalyticsData {
  final int matchId;
  final Alignment? winner;
  final int nightsPlayed;
  final List<TimelineRowData> timeline; // chronological, stable order
  final List<SuspicionAccuracy> suspicionAccuracy;
  final SuspicionMatrix suspicionMatrix;
  final List<Achievement> achievements; // at least one is always produced
  final Map<int, Role> finalRoles; // seat -> role, post-game only

  const MatchAnalyticsData({
    required this.matchId,
    required this.winner,
    required this.nightsPlayed,
    required this.timeline,
    required this.suspicionAccuracy,
    required this.suspicionMatrix,
    required this.achievements,
    required this.finalRoles,
  });

  @override
  String toString() =>
      'MatchAnalyticsData(matchId=$matchId, winner=$winner, nightsPlayed=$nightsPlayed, '
      'timeline=${timeline.length} rows, suspicionAccuracy=${suspicionAccuracy.length}, '
      'achievements=${achievements.length})';
}

/// Pure projection builder for match analytics.
/// Derives all post-game data from the event log and match state.
class AnalyticsBuilder {
  /// Build complete analytics from a finished match.
  static MatchAnalyticsData build(Match match) {
    final finalRoles = _buildFinalRoles(match);
    final timeline = _buildTimeline(match);
    final (suspicionMatrix, suspicionAccuracy) = _buildSuspicionData(match, finalRoles);
    final achievements = _buildAchievements(match, finalRoles, suspicionMatrix, timeline);
    final nightsPlayed = _countNights(match.eventLog);
    final winner = match.outcome?.winner;

    return MatchAnalyticsData(
      matchId: match.id,
      winner: winner,
      nightsPlayed: nightsPlayed,
      timeline: timeline,
      suspicionAccuracy: suspicionAccuracy,
      suspicionMatrix: suspicionMatrix,
      achievements: achievements,
      finalRoles: finalRoles,
    );
  }

  /// Extract the final role for each player from RoleAssigned events.
  static Map<int, Role> _buildFinalRoles(Match match) {
    final roles = <int, Role>{};
    for (final event in match.eventLog) {
      if (event is RoleAssigned) {
        roles[event.seat] = event.role;
      }
    }
    return roles;
  }

  /// Build the chronological timeline of significant events.
  static List<TimelineRowData> _buildTimeline(Match match) {
    final rows = <TimelineRowData>[];

    for (final event in match.eventLog) {
      final dayNum = event.phaseRef.number;
      final phase = event.phaseRef.phase;

      if (event is MafiaVoteCast) {
        rows.add(TimelineRowData(
          dayNumber: dayNum,
          phase: phase,
          kind: 'mafiaVote',
          actorSeat: event.actorSeat,
          targetSeat: event.targetSeat,
          at: event.at,
        ));
      } else if (event is ProtectCast) {
        rows.add(TimelineRowData(
          dayNumber: dayNum,
          phase: phase,
          kind: 'protect',
          actorSeat: event.actorSeat,
          targetSeat: event.targetSeat,
          at: event.at,
        ));
      } else if (event is InvestigateCast) {
        rows.add(TimelineRowData(
          dayNumber: dayNum,
          phase: phase,
          kind: 'investigate',
          actorSeat: event.actorSeat,
          targetSeat: event.targetSeat,
          at: event.at,
        ));
      } else if (event is SuspectCast) {
        rows.add(TimelineRowData(
          dayNumber: dayNum,
          phase: phase,
          kind: 'suspect',
          actorSeat: event.actorSeat,
          targetSeat: event.targetSeat,
          at: event.at,
        ));
      } else if (event is NightResolved) {
        if (event.victimSeat != null) {
          rows.add(TimelineRowData(
            dayNumber: dayNum,
            phase: phase,
            kind: 'nightKill',
            actorSeat: null,
            targetSeat: event.victimSeat,
            at: event.at,
          ));
        }
        if (event.savedSeat != null) {
          rows.add(TimelineRowData(
            dayNumber: dayNum,
            phase: phase,
            kind: 'saved',
            actorSeat: null,
            targetSeat: event.savedSeat,
            at: event.at,
          ));
        }
      } else if (event is DayResolved) {
        rows.add(TimelineRowData(
          dayNumber: dayNum,
          phase: phase,
          kind: 'dayElimination',
          actorSeat: null,
          targetSeat: event.eliminatedSeat,
          at: event.at,
        ));
      }
    }

    // Ensure rows are sorted by timestamp (should already be, but guarantee it).
    rows.sort((a, b) => a.at.compareTo(b.at));
    return rows;
  }

  /// Build suspicion matrix and per-player accuracy.
  static (SuspicionMatrix, List<SuspicionAccuracy>) _buildSuspicionData(
    Match match,
    Map<int, Role> finalRoles,
  ) {
    // Build suspicion matrix: voterSeat -> targetSeat -> count
    final matrix = <int, Map<int, int>>{};

    // Per-seat suspicion accuracy
    final accuracy = <int, (int total, int correct)>{};

    for (final event in match.eventLog) {
      if (event is SuspectCast) {
        final voterSeat = event.actorSeat;
        final targetSeat = event.targetSeat;

        // Track in matrix
        matrix.putIfAbsent(voterSeat, () => {});
        matrix[voterSeat]![targetSeat] = (matrix[voterSeat]![targetSeat] ?? 0) + 1;

        // Track accuracy: a suspicion is correct iff target is mafia
        accuracy.putIfAbsent(voterSeat, () => (0, 0));
        final (total, correct) = accuracy[voterSeat]!;
        final targetRole = finalRoles[targetSeat];
        final isCorrect = targetRole?.alignment == Alignment.mafia ? 1 : 0;
        accuracy[voterSeat] = (total + 1, correct + isCorrect);
      }
    }

    // Convert accuracy to SuspicionAccuracy objects, sorted by seat.
    final accuracyList = <SuspicionAccuracy>[];
    final seats = accuracy.keys.toList()..sort();
    for (final seat in seats) {
      final (total, correct) = accuracy[seat]!;
      accuracyList.add(SuspicionAccuracy(
        seat: seat,
        totalSuspicions: total,
        correctSuspicions: correct,
      ));
    }

    return (SuspicionMatrix(counts: matrix), accuracyList);
  }

  /// Build a list of achievements from the event log.
  /// Always produces at least one achievement.
  static List<Achievement> _buildAchievements(
    Match match,
    Map<int, Role> finalRoles,
    SuspicionMatrix suspicionMatrix,
    List<TimelineRowData> timeline,
  ) {
    final achievements = <Achievement>[];

    // 1. Sharpest Eye: highest suspicion accuracy with >=1 suspicion
    SuspicionAccuracy? bestAccuracy;
    for (final event in match.eventLog) {
      if (event is SuspectCast) {
        if (bestAccuracy == null) {
          bestAccuracy = SuspicionAccuracy(
            seat: event.actorSeat,
            totalSuspicions: 0,
            correctSuspicions: 0,
          );
          break;
        }
      }
    }

    if (bestAccuracy != null) {
      // Recalculate to find the best
      final suspicionsByPlayer = <int, ({int total, int correct})>{};
      for (final event in match.eventLog) {
        if (event is SuspectCast) {
          suspicionsByPlayer.putIfAbsent(event.actorSeat, () => (total: 0, correct: 0));
          final targetRole = finalRoles[event.targetSeat];
          final isCorrect = targetRole?.alignment == Alignment.mafia ? 1 : 0;
          final current = suspicionsByPlayer[event.actorSeat]!;
          suspicionsByPlayer[event.actorSeat] = (
            total: current.total + 1,
            correct: current.correct + isCorrect,
          );
        }
      }

      if (suspicionsByPlayer.isNotEmpty) {
        SuspicionAccuracy? best;
        for (final entry in suspicionsByPlayer.entries) {
          final seat = entry.key;
          final (:total, :correct) = entry.value;
          if (total > 0) {
            final accuracy = SuspicionAccuracy(
              seat: seat,
              totalSuspicions: total,
              correctSuspicions: correct,
            );
            if (best == null || accuracy.rate > best.rate) {
              best = accuracy;
            }
          }
        }

        if (best != null && best.totalSuspicions > 0) {
          achievements.add(Achievement(
            code: 'sharpest_eye',
            seats: [best.seat],
          ));
        }
      }
    }

    // 2. Untouchable: survived to the end (alive at game end)
    final survivors = <int>[];
    for (final player in match.players) {
      if (player.status == PlayerStatus.alive) {
        survivors.add(player.seat);
      }
    }

    if (survivors.isNotEmpty) {
      achievements.add(Achievement(
        code: 'untouchable',
        seats: survivors,
      ));
    }

    // 3. Guardian: doctor whose protect blocked a mafia kill
    // This is only determinable if we can match NightResolved to ProtectCast
    final doctors = <int>[];
    for (final event in match.eventLog) {
      if (event is ProtectCast && finalRoles[event.actorSeat] == Role.doctor) {
        if (!doctors.contains(event.actorSeat)) {
          doctors.add(event.actorSeat);
        }
      }
    }

    for (final doctorSeat in doctors) {
      // Check if there's a NightResolved with a victimSeat and a savedSeat
      for (final event in match.eventLog) {
        if (event is NightResolved && event.victimSeat != null && event.savedSeat != null) {
          if (event.savedSeat == event.victimSeat) {
            // Doctor protected the target that was about to be killed
            achievements.add(Achievement(
              code: 'guardian',
              seats: [doctorSeat],
            ));
            break;
          }
        }
      }
    }

    // 4. First Blood: the first night victim
    for (final event in match.eventLog) {
      if (event is NightResolved && event.victimSeat != null) {
        achievements.add(Achievement(
          code: 'first_blood',
          seats: [event.victimSeat!],
        ));
        break; // Only first victim
      }
    }

    // Fallback: if no achievements, create a "survivors" achievement
    if (achievements.isEmpty) {
      achievements.add(Achievement(
        code: 'survivors',
        seats: survivors.isNotEmpty ? survivors : match.players.map((p) => p.seat).toList(),
      ));
    }

    return achievements;
  }

  /// Count the number of nights played.
  static int _countNights(List<TimelineEvent> eventLog) {
    int maxNight = 0;
    for (final event in eventLog) {
      if (event.phaseRef.phase == GamePhase.night) {
        maxNight = max(maxNight, event.phaseRef.number);
      }
    }
    return maxNight;
  }
}

/// Utility to get max of two values (Dart doesn't have a built-in max in engine code).
int max(int a, int b) => a > b ? a : b;
