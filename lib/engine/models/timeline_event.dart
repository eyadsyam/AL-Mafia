import 'enums.dart';
import 'player.dart';

/// Result of a Detective's investigation: the role discovered.
/// Reference: data-model.md §5
class InvestigateResult {
  final int targetSeat;
  final Role revealedRole;

  const InvestigateResult({
    required this.targetSeat,
    required this.revealedRole,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestigateResult &&
          runtimeType == other.runtimeType &&
          targetSeat == other.targetSeat &&
          revealedRole == other.revealedRole;

  @override
  int get hashCode => targetSeat.hashCode ^ revealedRole.hashCode;

  @override
  String toString() => 'InvestigateResult(targetSeat=$targetSeat, revealedRole=$revealedRole)';
}

/// A night action taken by a player.
/// Reference: data-model.md §5
class NightAction {
  final int night;
  final int actorSeat;
  final NightActionKind kind;
  final int targetSeat;
  final InvestigateResult? result;
  final String? reason;

  const NightAction({
    required this.night,
    required this.actorSeat,
    required this.kind,
    required this.targetSeat,
    this.result,
    this.reason,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NightAction &&
          runtimeType == other.runtimeType &&
          night == other.night &&
          actorSeat == other.actorSeat &&
          kind == other.kind &&
          targetSeat == other.targetSeat &&
          result == other.result &&
          reason == other.reason;

  @override
  int get hashCode =>
      night.hashCode ^
      actorSeat.hashCode ^
      kind.hashCode ^
      targetSeat.hashCode ^
      result.hashCode ^
      reason.hashCode;

  @override
  String toString() =>
      'NightAction(night=$night, actorSeat=$actorSeat, kind=$kind, targetSeat=$targetSeat, '
      'result=$result, reason=$reason)';
}

/// A vote cast during a day phase.
/// Reference: data-model.md §6
class Vote {
  final int day;
  final int voterSeat;
  final int? targetSeat; // null means abstain

  const Vote({
    required this.day,
    required this.voterSeat,
    this.targetSeat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vote &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          voterSeat == other.voterSeat &&
          targetSeat == other.targetSeat;

  @override
  int get hashCode => day.hashCode ^ voterSeat.hashCode ^ targetSeat.hashCode;

  @override
  String toString() => 'Vote(day=$day, voterSeat=$voterSeat, targetSeat=$targetSeat)';
}

/// Base class for all timeline events.
/// The append-only log powering resume and analytics.
/// Reference: data-model.md §7
sealed class TimelineEvent {
  final DateTime at;
  final PhaseRef phaseRef;

  const TimelineEvent({
    required this.at,
    required this.phaseRef,
  });
}

/// A role was assigned to a player at distribution.
class RoleAssigned extends TimelineEvent {
  final int seat;
  final Role role;

  const RoleAssigned({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.seat,
    required this.role,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleAssigned &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          seat == other.seat &&
          role == other.role;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ seat.hashCode ^ role.hashCode;

  @override
  String toString() => 'RoleAssigned(at=$at, phaseRef=$phaseRef, seat=$seat, role=$role)';
}

/// The night phase has started.
class NightOpened extends TimelineEvent {
  const NightOpened({
    required DateTime at,
    required PhaseRef phaseRef,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NightOpened &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef;

  @override
  int get hashCode => at.hashCode ^ phaseRef.hashCode;

  @override
  String toString() => 'NightOpened(at=$at, phaseRef=$phaseRef)';
}

/// A Mafia member voted to eliminate a target.
class MafiaVoteCast extends TimelineEvent {
  final int actorSeat;
  final int targetSeat;

  const MafiaVoteCast({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.actorSeat,
    required this.targetSeat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MafiaVoteCast &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          actorSeat == other.actorSeat &&
          targetSeat == other.targetSeat;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ actorSeat.hashCode ^ targetSeat.hashCode;

  @override
  String toString() =>
      'MafiaVoteCast(at=$at, phaseRef=$phaseRef, actorSeat=$actorSeat, targetSeat=$targetSeat)';
}

/// A Doctor protected a player.
class ProtectCast extends TimelineEvent {
  final int actorSeat;
  final int targetSeat;

  const ProtectCast({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.actorSeat,
    required this.targetSeat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtectCast &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          actorSeat == other.actorSeat &&
          targetSeat == other.targetSeat;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ actorSeat.hashCode ^ targetSeat.hashCode;

  @override
  String toString() =>
      'ProtectCast(at=$at, phaseRef=$phaseRef, actorSeat=$actorSeat, targetSeat=$targetSeat)';
}

/// A Detective investigated a player.
class InvestigateCast extends TimelineEvent {
  final int actorSeat;
  final int targetSeat;

  const InvestigateCast({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.actorSeat,
    required this.targetSeat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestigateCast &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          actorSeat == other.actorSeat &&
          targetSeat == other.targetSeat;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ actorSeat.hashCode ^ targetSeat.hashCode;

  @override
  String toString() =>
      'InvestigateCast(at=$at, phaseRef=$phaseRef, actorSeat=$actorSeat, targetSeat=$targetSeat)';
}

/// A Citizen recorded a suspicion.
class SuspectCast extends TimelineEvent {
  final int actorSeat;
  final int targetSeat;
  final String? reason;

  const SuspectCast({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.actorSeat,
    required this.targetSeat,
    this.reason,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuspectCast &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          actorSeat == other.actorSeat &&
          targetSeat == other.targetSeat &&
          reason == other.reason;

  @override
  int get hashCode =>
      at.hashCode ^
      phaseRef.hashCode ^
      actorSeat.hashCode ^
      targetSeat.hashCode ^
      reason.hashCode;

  @override
  String toString() =>
      'SuspectCast(at=$at, phaseRef=$phaseRef, actorSeat=$actorSeat, targetSeat=$targetSeat, reason=$reason)';
}

/// The night phase resolved with possible victim and save.
class NightResolved extends TimelineEvent {
  final int? victimSeat;
  final int? savedSeat;

  const NightResolved({
    required DateTime at,
    required PhaseRef phaseRef,
    this.victimSeat,
    this.savedSeat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NightResolved &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          victimSeat == other.victimSeat &&
          savedSeat == other.savedSeat;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ victimSeat.hashCode ^ savedSeat.hashCode;

  @override
  String toString() =>
      'NightResolved(at=$at, phaseRef=$phaseRef, victimSeat=$victimSeat, savedSeat=$savedSeat)';
}

/// The morning briefing has been announced.
class MorningAnnounced extends TimelineEvent {
  const MorningAnnounced({
    required DateTime at,
    required PhaseRef phaseRef,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MorningAnnounced &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef;

  @override
  int get hashCode => at.hashCode ^ phaseRef.hashCode;

  @override
  String toString() => 'MorningAnnounced(at=$at, phaseRef=$phaseRef)';
}

/// A discussion round has started.
class DiscussionRound extends TimelineEvent {
  const DiscussionRound({
    required DateTime at,
    required PhaseRef phaseRef,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscussionRound &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef;

  @override
  int get hashCode => at.hashCode ^ phaseRef.hashCode;

  @override
  String toString() => 'DiscussionRound(at=$at, phaseRef=$phaseRef)';
}

/// A player asked a question during discussion.
class QuestionAsked extends TimelineEvent {
  final int fromSeat;
  final int toSeat;

  const QuestionAsked({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.fromSeat,
    required this.toSeat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionAsked &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          fromSeat == other.fromSeat &&
          toSeat == other.toSeat;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ fromSeat.hashCode ^ toSeat.hashCode;

  @override
  String toString() =>
      'QuestionAsked(at=$at, phaseRef=$phaseRef, fromSeat=$fromSeat, toSeat=$toSeat)';
}

/// A vote was cast during day voting.
class VoteCast extends TimelineEvent {
  final int voterSeat;
  final int? targetSeat;

  /// Which balloting round of this day the vote belongs to. Round 1 is the
  /// opening ballot; a tie under [DayTieRule.revote] opens round 2, and so on.
  /// Tallies MUST filter on this, otherwise a revote would be counted on top of
  /// the round that produced the tie (FR-020).
  final int round;

  const VoteCast({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.voterSeat,
    this.targetSeat,
    this.round = 1,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoteCast &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          voterSeat == other.voterSeat &&
          targetSeat == other.targetSeat &&
          round == other.round;

  @override
  int get hashCode =>
      at.hashCode ^
      phaseRef.hashCode ^
      voterSeat.hashCode ^
      targetSeat.hashCode ^
      round.hashCode;

  @override
  String toString() =>
      'VoteCast(at=$at, phaseRef=$phaseRef, voterSeat=$voterSeat, '
      'targetSeat=$targetSeat, round=$round)';
}

/// A day vote tied and a revote was called among [tiedSeats] only.
///
/// Recording this in the log (rather than keeping it in a field on the engine)
/// is what makes a revote survive a force-quit: the round number and the legal
/// candidate set are both re-derivable from the persisted event log alone
/// (repository contract inv. 2).
class DayRevoteCalled extends TimelineEvent {
  final List<int> tiedSeats;

  const DayRevoteCalled({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.tiedSeats,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayRevoteCalled &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          _sameSeats(tiedSeats, other.tiedSeats);

  static bool _sameSeats(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ Object.hashAll(tiedSeats);

  @override
  String toString() =>
      'DayRevoteCalled(at=$at, phaseRef=$phaseRef, tiedSeats=$tiedSeats)';
}

/// The day vote phase resolved with an elimination and tally.
class DayResolved extends TimelineEvent {
  final int eliminatedSeat;
  final Map<int, int> tally; // targetSeat -> vote count

  const DayResolved({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.eliminatedSeat,
    required this.tally,
  }) : super(at: at, phaseRef: phaseRef);

  /// Entry-wise map comparison — `Map` is identity-equal, which would make a
  /// reloaded tally never match the one that was written (repository inv. 5).
  static bool _sameTally(Map<int, int> a, Map<int, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayResolved &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          eliminatedSeat == other.eliminatedSeat &&
          _sameTally(tally, other.tally);

  @override
  int get hashCode => Object.hash(
        at,
        phaseRef,
        eliminatedSeat,
        Object.hashAll([
          for (final key in tally.keys.toList()..sort()) '$key:${tally[key]}',
        ]),
      );

  @override
  String toString() =>
      'DayResolved(at=$at, phaseRef=$phaseRef, eliminatedSeat=$eliminatedSeat, tally=$tally)';
}

/// A player was removed from the game (host action).
class PlayerRemoved extends TimelineEvent {
  final int seat;

  const PlayerRemoved({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.seat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerRemoved &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          seat == other.seat;

  @override
  int get hashCode => at.hashCode ^ phaseRef.hashCode ^ seat.hashCode;

  @override
  String toString() => 'PlayerRemoved(at=$at, phaseRef=$phaseRef, seat=$seat)';
}

/// The game has reached a win condition.
class WinReached extends TimelineEvent {
  final Alignment alignment;

  const WinReached({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.alignment,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WinReached &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          alignment == other.alignment;

  @override
  int get hashCode => at.hashCode ^ phaseRef.hashCode ^ alignment.hashCode;

  @override
  String toString() => 'WinReached(at=$at, phaseRef=$phaseRef, alignment=$alignment)';
}
