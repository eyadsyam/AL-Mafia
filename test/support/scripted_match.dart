import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';

/// Drives a match through the engine to a chosen point.
///
/// Shared by the persistence and resume suites so they all exercise the same
/// realistic event log rather than hand-built fixtures. A hand-built log would
/// happily round-trip while missing the event variant that a real match
/// actually produces — which is the failure this helper exists to avoid.
const _names = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

const _roleCounts = {
  Role.mafia: 2,
  Role.doctor: 1,
  Role.detective: 1,
  Role.citizen: 3,
};

NightActionKind _kindFor(Role role) => switch (role) {
      Role.mafia => NightActionKind.mafiaVote,
      Role.doctor => NightActionKind.protect,
      Role.detective => NightActionKind.investigate,
      Role.citizen => NightActionKind.suspect,
    };

/// A legal target for [seat] this night, avoiding the doctor's no-repeat rule.
int _targetFor(Match match, int seat) {
  final role = match.players[seat].role;
  final living = [
    for (final p in match.players)
      if (p.status == PlayerStatus.alive && p.seat != seat) p.seat,
  ];

  if (role == Role.doctor) {
    // Skip whoever this doctor protected last night, or the engine rejects it.
    final lastProtected = match.eventLog
        .whereType<ProtectCast>()
        .where((e) =>
            e.actorSeat == seat && e.phaseRef.number == match.dayNumber - 1)
        .map((e) => e.targetSeat)
        .lastOrNull;
    final allowed = living.where((s) => s != lastProtected).toList();
    return allowed.isEmpty ? living.first : allowed.first;
  }

  return living.first;
}

/// Builds a match and plays it forward.
///
/// * [stopAfterNightActions] — stop partway through night 1, after that many
///   actors have acted. Leaves the match in `night`, mid-hand: the state a
///   force-quit is most likely to interrupt.
/// * [playToEnd] — run full night/day cycles until someone wins.
MatchEngine scriptedMatch({
  int? stopAfterNightActions,
  bool playToEnd = false,
  int seed = 7,
  DateTime? createdAt,
  MatchSettings settings = const MatchSettings(),
}) {
  final engine = MatchEngine();
  engine.start(
    names: _names,
    roleCounts: _roleCounts,
    settings: settings,
    seed: seed,
    now: createdAt,
  );

  // Distribution.
  while (engine.match.phase == GamePhase.distributing) {
    engine.revealFor(engine.match.currentActorSeat!);
    engine.confirmRevealed();
  }

  if (stopAfterNightActions != null) {
    engine.beginNight();
    for (var i = 0; i < stopAfterNightActions; i++) {
      final seat = engine.match.currentActorSeat;
      if (seat == null) break;
      engine.submitNightAction(
        seat: seat,
        kind: _kindFor(engine.match.players[seat].role),
        targetSeat: _targetFor(engine.match, seat),
      );
    }
    return engine;
  }

  if (!playToEnd) return engine;

  // Bounded so a rule change that stalls the loop fails loudly instead of
  // hanging the suite.
  var guard = 0;
  while (engine.match.phase != GamePhase.result && guard < 30) {
    guard++;
    _playNight(engine);
    _playDay(engine);
  }
  return engine;
}

/// Plays until a day vote ties, so the revote path (and its event) is covered.
MatchEngine playToTiedVote() {
  final engine = MatchEngine();
  engine.start(
    names: const ['A', 'B', 'C', 'D', 'E'],
    roleCounts: const {
      Role.mafia: 1,
      Role.doctor: 1,
      Role.detective: 1,
      Role.citizen: 2,
    },
    settings: const MatchSettings(dayTieRule: DayTieRule.revote),
    seed: 1,
  );
  while (engine.match.phase == GamePhase.distributing) {
    engine.revealFor(engine.match.currentActorSeat!);
    engine.confirmRevealed();
  }

  // Night in which the doctor self-protects and the mafia targets the doctor,
  // so nobody dies and all five seats can vote.
  engine.beginNight();
  final doctorSeat =
      engine.match.players.firstWhere((p) => p.role == Role.doctor).seat;
  while (engine.match.currentActorSeat != null) {
    final seat = engine.match.currentActorSeat!;
    final role = engine.match.players[seat].role;
    engine.submitNightAction(
      seat: seat,
      kind: _kindFor(role),
      targetSeat: role == Role.mafia || role == Role.doctor
          ? doctorSeat
          : (seat + 1) % 5,
    );
  }
  engine.resolveNight();
  engine.beginDiscussion();
  engine.beginVoting();

  // 2–2 between seats 1 and 3, with no self-votes.
  const votes = {0: 1, 1: 3, 2: 1, 3: 0, 4: 3};
  while (engine.match.currentActorSeat != null) {
    final seat = engine.match.currentActorSeat!;
    engine.submitVote(seat: seat, voterSeat: seat, targetSeat: votes[seat]!);
  }
  engine.resolveDayVote();
  return engine;
}

void _playNight(MatchEngine engine) {
  if (engine.match.phase != GamePhase.preNightLobby) return;
  engine.beginNight();
  while (engine.match.currentActorSeat != null) {
    final seat = engine.match.currentActorSeat!;
    engine.submitNightAction(
      seat: seat,
      kind: _kindFor(engine.match.players[seat].role),
      targetSeat: _targetFor(engine.match, seat),
    );
  }
  engine.resolveNight();
}

void _playDay(MatchEngine engine) {
  if (engine.match.phase != GamePhase.morning) return;
  engine.beginDiscussion();
  engine.beginVoting();

  // Bounded for the same reason the outer loop is: a rule change that stops
  // the day resolving should fail loudly rather than hang the whole suite for
  // ten minutes with no indication of which test is stuck. An unbounded revote
  // did exactly that.
  var ballots = 0;
  while (engine.match.phase == GamePhase.voting && ballots < 200) {
    ballots++;
    final seat = engine.match.currentActorSeat;
    if (seat == null) break;
    final ballot = engine.currentVoteCandidates;
    final target = [
      for (final p in engine.match.players)
        if (p.status == PlayerStatus.alive &&
            p.seat != seat &&
            (ballot == null || ballot.contains(p.seat)))
          p.seat,
    ].first;
    engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);

    if (engine.match.phase == GamePhase.voteResolving) {
      engine.resolveDayVote();
    }
  }

  if (engine.match.phase == GamePhase.voting) {
    throw StateError(
      'the day never resolved: $ballots ballots cast and the match is still in '
      'GamePhase.voting. Something has made the vote loop unable to terminate.',
    );
  }

  if (engine.match.phase == GamePhase.reveal) {
    engine.winCheck();
  }
}
