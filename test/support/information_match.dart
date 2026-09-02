import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/resolver.dart';

/// Drivers for the Information Engine's suites.
///
/// Separate from `scripted_match.dart` on purpose. That helper exists to build
/// *realistic persistence fixtures* and takes the shortest route through a day;
/// these tests need the opposite — control over exactly who suspects whom, so
/// an eligibility branch can be aimed at rather than stumbled into.
const List<String> kNames = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

const Map<Role, int> kRoles = {
  Role.mafia: 2,
  Role.doctor: 1,
  Role.detective: 1,
  Role.citizen: 3,
};

/// A started match with the three layers on and the roles above dealt.
MatchEngine informationMatch({
  int seed = 7,
  MatchSettings settings = const MatchSettings(whisperEnabled: true),
  List<String> names = kNames,
  Map<Role, int> roles = kRoles,
}) {
  final engine = MatchEngine(clock: Clocks.monotonic());
  engine.start(
    names: names,
    roleCounts: roles,
    settings: settings,
    seed: seed,
  );
  while (engine.match.phase == GamePhase.distributing) {
    engine.confirmRevealed();
  }
  return engine;
}

/// Opens the night. Assumes the match is in the pre-night lobby.
void openNight(MatchEngine engine) => engine.beginNight();

/// The lowest-numbered living seat [seat] may legally act on tonight.
int firstLegalTarget(MatchEngine engine, int seat) {
  final match = engine.match;
  final isDoctor = match.players[seat].role == Role.doctor;
  for (final p in match.players) {
    if (p.seat == seat || p.status != PlayerStatus.alive) continue;
    if (isDoctor &&
        NightResolver.wouldViolateDoctorNoRepeat(
          match: match,
          doctorSeat: seat,
          targetSeat: p.seat,
        )) {
      continue;
    }
    return p.seat;
  }
  throw StateError('no legal target for seat $seat');
}

/// Plays a whole night in which everybody skips, so nobody dies and no
/// suspicion is recorded — the cleanest possible starting point for a test that
/// wants to control the *next* night exactly.
void playQuietNight(MatchEngine engine) {
  engine.beginNight();
  while (engine.match.currentActorSeat != null) {
    engine.skipNightAction(seat: engine.match.currentActorSeat!);
  }
  engine.resolveNight();
}

/// Plays a night from an explicit script of `seat -> target`.
///
/// A seat absent from [choices] skips. The map is read against the roles that
/// were actually dealt, so a caller usually builds it from
/// `engine.match.players` rather than by hand.
void playScriptedNight(MatchEngine engine, Map<int, int?> choices) {
  engine.beginNight();
  while (engine.match.currentActorSeat != null) {
    final seat = engine.match.currentActorSeat!;
    final target = choices[seat];
    if (target == null) {
      engine.skipNightAction(seat: seat);
      continue;
    }
    engine.submitNightAction(
      seat: seat,
      kind: engine.match.players[seat].role.nightAction,
      targetSeat: target,
    );
  }
  engine.resolveNight();
}

/// Walks the day from the morning to the ballot, playing whatever opening
/// surface the engine chose.
///
/// [accuse] picks a target for the «اسم واحد» round; the default names the next
/// seat round the table.
void openDay(MatchEngine engine, {int Function(int seat)? accuse}) {
  engine.beginDay();
  while (engine.match.phase == GamePhase.openingRound) {
    final seat = engine.match.currentActorSeat!;
    final pick = accuse?.call(seat) ?? _nextLivingSeat(engine, seat);
    engine.submitOpeningAccusation(seat: seat, targetSeat: pick);
  }
  if (engine.match.phase == GamePhase.confrontation) {
    engine.endConfrontation();
  }
}

/// Runs a whole day: opening surface, then a ballot in which everybody votes
/// for [target] (or for the next living seat when null).
void playDay(MatchEngine engine, {int? target, int Function(int)? accuse}) {
  openDay(engine, accuse: accuse);
  engine.beginVoting();
  while (engine.match.currentActorSeat != null) {
    final seat = engine.match.currentActorSeat!;
    final pick = target != null && target != seat
        ? target
        : _nextLivingSeat(engine, seat);
    engine.submitVote(seat: seat, voterSeat: seat, targetSeat: pick);
  }
  engine.resolveDayVote();
  if (engine.match.phase == GamePhase.reveal) engine.winCheck();
}

int _nextLivingSeat(MatchEngine engine, int seat) {
  final players = engine.match.players;
  for (var i = 1; i <= players.length; i++) {
    final candidate = players[(seat + i) % players.length];
    if (candidate.seat != seat && candidate.status == PlayerStatus.alive) {
      return candidate.seat;
    }
  }
  throw StateError('nobody left for seat $seat to name');
}
