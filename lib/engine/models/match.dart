import 'enums.dart';
import 'match_settings.dart';
import 'player.dart';
import 'timeline_event.dart';

/// Outcome of a completed match.
class MatchOutcome {
  final Alignment winner;
  final DateTime completedAt;

  const MatchOutcome({
    required this.winner,
    required this.completedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchOutcome &&
          runtimeType == other.runtimeType &&
          winner == other.winner &&
          completedAt == other.completedAt;

  @override
  int get hashCode => winner.hashCode ^ completedAt.hashCode;

  @override
  String toString() => 'MatchOutcome(winner=$winner, completedAt=$completedAt)';
}

/// The aggregate root for one game session.
/// Reference: data-model.md §1
class Match {
  final int id;
  final DateTime createdAt;
  final int seed;
  final List<Player> players;
  final MatchSettings settings;
  final GamePhase phase;
  final int dayNumber;
  final int? currentActorSeat;
  final List<TimelineEvent> eventLog;
  final MatchOutcome? outcome;

  const Match({
    required this.id,
    required this.createdAt,
    required this.seed,
    required this.players,
    required this.settings,
    required this.phase,
    required this.dayNumber,
    this.currentActorSeat,
    required this.eventLog,
    this.outcome,
  });

  /// Validation: player count must be 5-20.
  bool get isPlayerCountValid => players.length >= 5 && players.length <= 20;

  /// Validation: seating indices must be contiguous 0..n-1.
  bool get isSeatingValid {
    if (players.isEmpty) return false;
    final seats = players.map((p) => p.seat).toList();
    seats.sort();
    for (int i = 0; i < seats.length; i++) {
      if (seats[i] != i) return false;
    }
    return true;
  }

  /// Create a copy with optional field overrides.
  /// Lists are replaced immutably.
  /// Special handling: pass currentActorSeat even if null to clear it.
  Match copyWith({
    int? id,
    DateTime? createdAt,
    int? seed,
    List<Player>? players,
    MatchSettings? settings,
    GamePhase? phase,
    int? dayNumber,
    int? currentActorSeat,
    bool clearCurrentActorSeat = false,
    List<TimelineEvent>? eventLog,
    MatchOutcome? outcome,
  }) =>
      Match(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        seed: seed ?? this.seed,
        players: players ?? this.players,
        settings: settings ?? this.settings,
        phase: phase ?? this.phase,
        dayNumber: dayNumber ?? this.dayNumber,
        currentActorSeat: clearCurrentActorSeat ? currentActorSeat : (currentActorSeat ?? this.currentActorSeat),
        eventLog: eventLog ?? this.eventLog,
        outcome: outcome ?? this.outcome,
      );

  /// Element-wise list comparison.
  ///
  /// `List` uses identity equality, so without this a match reloaded from
  /// storage could never compare equal to the one that was written — which is
  /// exactly the round-trip fidelity the repository contract requires (inv. 5).
  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Match &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          createdAt == other.createdAt &&
          seed == other.seed &&
          _listEquals(players, other.players) &&
          settings == other.settings &&
          phase == other.phase &&
          dayNumber == other.dayNumber &&
          currentActorSeat == other.currentActorSeat &&
          _listEquals(eventLog, other.eventLog) &&
          outcome == other.outcome;

  @override
  int get hashCode => Object.hash(
        id,
        createdAt,
        seed,
        Object.hashAll(players),
        settings,
        phase,
        dayNumber,
        currentActorSeat,
        Object.hashAll(eventLog),
        outcome,
      );

  @override
  String toString() =>
      'Match(id=$id, phase=$phase, dayNumber=$dayNumber, players=${players.length}, '
      'currentActorSeat=$currentActorSeat, outcome=$outcome)';
}
