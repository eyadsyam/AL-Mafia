import 'models/enums.dart';
import 'models/match.dart';
import 'models/player.dart';

/// Tally of votes cast for each target.
class VoteTally {
  final Map<int, int> votes; // targetSeat -> vote count

  const VoteTally({required this.votes});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoteTally &&
          runtimeType == other.runtimeType &&
          votes == other.votes;

  @override
  int get hashCode => votes.hashCode;

  @override
  String toString() => 'VoteTally($votes)';
}

/// Report of the morning after a night phase.
class MorningReport {
  final int? victimSeat; // null if nobody died
  final bool someoneSavedUnnamed; // true if mafia target was protected
  final bool allSurvived; // true if no one died

  const MorningReport({
    this.victimSeat,
    this.someoneSavedUnnamed = false,
    this.allSurvived = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MorningReport &&
          runtimeType == other.runtimeType &&
          victimSeat == other.victimSeat &&
          someoneSavedUnnamed == other.someoneSavedUnnamed &&
          allSurvived == other.allSurvived;

  @override
  int get hashCode =>
      victimSeat.hashCode ^ someoneSavedUnnamed.hashCode ^ allSurvived.hashCode;

  @override
  String toString() =>
      'MorningReport(victimSeat=$victimSeat, someoneSavedUnnamed=$someoneSavedUnnamed, allSurvived=$allSurvived)';
}

/// Result of a day vote resolution.
class DayVoteResult {
  final int? eliminatedSeat; // null if no elimination
  final Map<int, int>? tally; // targetSeat -> vote count (only if tie or elimination)
  final bool tie; // true if vote was tied
  final List<int>? tiedSeats; // seats that were tied (only if tie)

  /// Role of the eliminated player. A day elimination is public by design — the
  /// reveal screen names the role of whoever the table voted out (FR-019). Null
  /// whenever nobody was eliminated.
  final Role? eliminatedRole;

  const DayVoteResult({
    this.eliminatedSeat,
    this.tally,
    this.tie = false,
    this.tiedSeats,
    this.eliminatedRole,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayVoteResult &&
          runtimeType == other.runtimeType &&
          eliminatedSeat == other.eliminatedSeat &&
          tally == other.tally &&
          tie == other.tie &&
          tiedSeats == other.tiedSeats &&
          eliminatedRole == other.eliminatedRole;

  @override
  int get hashCode =>
      eliminatedSeat.hashCode ^
      tally.hashCode ^
      tie.hashCode ^
      tiedSeats.hashCode ^
      eliminatedRole.hashCode;

  @override
  String toString() =>
      'DayVoteResult(eliminatedSeat=$eliminatedSeat, tie=$tie, tiedSeats=$tiedSeats, '
      'eliminatedRole=$eliminatedRole)';
}

/// Private view given to an actor during their turn.
class ActorTurnView {
  final int actorSeat;
  final Role actorRole;
  final String questionText;
  final List<int> targets; // seats of other alive players
  final List<int> teammateVotes; // mafia votes this night (empty for non-mafia)

  const ActorTurnView({
    required this.actorSeat,
    required this.actorRole,
    required this.questionText,
    required this.targets,
    required this.teammateVotes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActorTurnView &&
          runtimeType == other.runtimeType &&
          actorSeat == other.actorSeat &&
          actorRole == other.actorRole &&
          questionText == other.questionText &&
          targets == other.targets &&
          teammateVotes == other.teammateVotes;

  @override
  int get hashCode =>
      actorSeat.hashCode ^
      actorRole.hashCode ^
      questionText.hashCode ^
      targets.hashCode ^
      teammateVotes.hashCode;

  @override
  String toString() =>
      'ActorTurnView(actorSeat=$actorSeat, actorRole=$actorRole, targets=${targets.length})';
}

/// Public view of the match state.
class PublicMatchView {
  final GamePhase phase;
  final int dayNumber;
  final List<PublicPlayer> players;
  final int? currentActorSeat;
  final MorningReport? morningReport;
  final VoteTally? lastTally;
  final MatchOutcome? outcome;

  const PublicMatchView({
    required this.phase,
    required this.dayNumber,
    required this.players,
    this.currentActorSeat,
    this.morningReport,
    this.lastTally,
    this.outcome,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicMatchView &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          dayNumber == other.dayNumber &&
          players == other.players &&
          currentActorSeat == other.currentActorSeat &&
          morningReport == other.morningReport &&
          lastTally == other.lastTally &&
          outcome == other.outcome;

  @override
  int get hashCode =>
      phase.hashCode ^
      dayNumber.hashCode ^
      players.hashCode ^
      currentActorSeat.hashCode ^
      morningReport.hashCode ^
      lastTally.hashCode ^
      outcome.hashCode;

  @override
  String toString() =>
      'PublicMatchView(phase=$phase, dayNumber=$dayNumber, players=${players.length}, outcome=$outcome)';
}

