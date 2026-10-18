/// Generates the night outcome contract from real `MatchEngine` resolutions.
///
/// Run `dart run tool/night_vectors.dart`, then run both night vector tests.
/// Regeneration is a deliberate contract change: inspect any changed outcomes
/// before accepting the new JSON. The file is never authored by hand.
library tool.night_vectors;

import 'dart:convert';
import 'dart:io';

import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';

const outputPath = 'supabase/tests/night_vectors.json';

// Dart event name -> server night_actions.action. A Silencer's inherited
// MafiaVoteCast is therefore a server `kill`, even though the submitted Dart
// command was NightActionKind.silence. BulletSpent is carried separately.
const moveNames = <Type, String>{
  MafiaVoteCast: 'kill',
  ProtectCast: 'protect',
  InvestigateCast: 'investigate',
  SuspectCast: 'suspect',
  SilenceCast: 'silence',
  NightActionSkipped: 'skip',
};

const modes = <String>[
  'plain kill',
  'protected kill',
  'doctor self protect bullet',
  'quiet night',
  'quiet night with protect',
  'save with bullets disabled',
  'save with quiet night disabled',
  'sniper shoots mafia',
  'sniper shoots town',
  'sniper shoots protected victim',
  'silencer silences',
  'silenced target killed',
  'silencer inherits kill',
  'elder targeted',
  'nine seats',
  'twelve seats',
];

int seatOf(MatchEngine e, Role role) =>
    e.match.players.firstWhere((p) => p.role == role).seat;

List<int> seatsOf(MatchEngine e, Role role) => [
  for (final p in e.match.players)
    if (p.role == role) p.seat,
];

MatchEngine start(Map<Role, int> roles, MatchSettings settings, int seed) {
  final count = roles.values.fold<int>(0, (sum, n) => sum + n);
  final e = MatchEngine(clock: Clocks.monotonic());
  e.start(
    names: [for (var i = 0; i < count; i++) 'P$i'],
    roleCounts: roles,
    settings: settings,
    seed: seed,
  );
  for (var i = 0; i < count; i++) {
    e.revealFor(i);
    e.confirmRevealed();
  }
  return e;
}

void nextNight(MatchEngine e, {int? eliminateSeat}) {
  e.beginDay();
  while (e.match.phase == GamePhase.openingRound) {
    final actor = e.match.currentActorSeat!;
    final target = e.match.players.firstWhere(
      (p) => p.status == PlayerStatus.alive && p.seat != actor,
    ).seat;
    e.submitOpeningAccusation(seat: actor, targetSeat: target);
  }
  if (e.match.phase == GamePhase.confrontation) e.endConfrontation();
  e.beginVoting();
  while (e.match.phase == GamePhase.voting) {
    final actor = e.match.currentActorSeat!;
    if (e.silencedSeatToday == actor) {
      e.skipSilencedVote(actor);
    } else {
      final target = eliminateSeat == null
          ? null
          : actor == eliminateSeat
              ? e.match.players.firstWhere((p) =>
                  p.status == PlayerStatus.alive && p.seat != actor).seat
              : eliminateSeat;
      e.submitVote(seat: actor, voterSeat: actor, targetSeat: target);
    }
  }
  e.resolveDayVote();
  if (e.winCheck() != null) throw StateError('fixture ended before next night');
}

Map<String, dynamic> actionRow(List<TimelineEvent> added, int actor) {
  final moves = added.where((event) => moveNames.containsKey(event.runtimeType)).toList();
  if (moves.length != 1) throw StateError('expected one night move from u$actor');
  final move = moves.single;
  final target = switch (move) {
    MafiaVoteCast m => m.targetSeat,
    ProtectCast m => m.targetSeat,
    InvestigateCast m => m.targetSeat,
    SuspectCast m => m.targetSeat,
    SilenceCast m => m.targetSeat,
    _ => null,
  };
  return {
    'actor_id': 'u$actor',
    'action': moveNames[move.runtimeType],
    'target_id': target == null ? null : 'u$target',
    'used_bullet': added.any((event) => event is BulletSpent),
  };
}

Map<String, dynamic> scenario(String mode, int seed) {
  final hasSniper = mode.startsWith('sniper');
  final hasSilencer = mode.startsWith('silencer') || mode == 'silenced target killed';
  final hasElder = mode == 'elder targeted';
  final count = mode == 'nine seats' ? 9 : mode == 'twelve seats' ? 12 : 7;
  final mafiaCount = count == 12 ? 3 : count == 9 ? 2 : 1;
  final roles = <Role, int>{
    Role.mafia: mafiaCount,
    if (hasSilencer) Role.silencer: 1,
    Role.doctor: 1,
    if (hasSniper) Role.sniper: 1,
    if (hasElder) Role.elder: 1,
    Role.citizen: count - mafiaCount - 1 - (hasSilencer ? 1 : 0) -
        (hasSniper ? 1 : 0) - (hasElder ? 1 : 0),
  };
  final settings = MatchSettings(
    abstainAllowed: true,
    bulletsEnabled: mode != 'save with bullets disabled',
    quietNightEnabled: mode != 'save with quiet night disabled',
    sniperEnabled: hasSniper,
    silencerEnabled: hasSilencer,
    elderEnabled: hasElder,
  );
  final e = start(roles, settings, seed);

  if (mode == 'silencer inherits kill') {
    final mafioso = seatOf(e, Role.mafia);
    e.beginNight();
    while (e.match.currentActorSeat != null) {
      final actor = e.match.currentActorSeat!;
      e.skipNightAction(seat: actor);
    }
    e.resolveNight();
    nextNight(e, eliminateSeat: mafioso);
  }

  final mafia = seatsOf(e, Role.mafia);
  final doctor = seatOf(e, Role.doctor);
  final citizens = seatsOf(e, Role.citizen);
  final argued = mode == 'doctor self protect bullet'
      ? doctor
      : mode == 'elder targeted'
          ? seatOf(e, Role.elder)
          : citizens.first;
  final cover = {
    'protected kill', 'quiet night with protect',
    'save with bullets disabled', 'save with quiet night disabled',
    'sniper shoots protected victim',
  }.contains(mode) ? argued :
      mode == 'silencer inherits kill' ? citizens.last : mafia.first;
  final shot = mode == 'sniper shoots mafia'
      ? mafia.first
      : mode == 'sniper shoots town'
          ? citizens.last
          : argued;

  e.beginNight();
  final roster = [
    for (final p in e.match.players)
      {'user_id': 'u${p.seat}', 'seat': p.seat,
       'role': p.role.name, 'alive': p.status == PlayerStatus.alive},
  ];
  final night = e.match.dayNumber;
  final actions = <Map<String, dynamic>>[];
  while (e.match.currentActorSeat != null) {
    final actor = e.match.currentActorSeat!;
    final role = e.match.players[actor].role;
    final before = e.match.eventLog.length;
    if (role == Role.mafia) {
      if (mode == 'quiet night' || mode == 'quiet night with protect') {
        if (actor == mafia.first) {
          e.submitNightAction(seat: actor, kind: NightActionKind.mafiaVote,
              targetSeat: argued, useBullet: true);
        } else {
          e.submitNightAction(seat: actor, kind: NightActionKind.mafiaVote,
              targetSeat: argued);
        }
      } else {
        e.submitNightAction(seat: actor, kind: NightActionKind.mafiaVote,
            targetSeat: argued);
      }
    } else if (role == Role.silencer && mode == 'silencer inherits kill') {
      e.submitNightAction(seat: actor, kind: NightActionKind.silence,
          targetSeat: argued);
    } else if (role == Role.silencer &&
        (mode == 'silencer silences' || mode == 'silenced target killed')) {
      e.submitNightAction(seat: actor, kind: NightActionKind.silence,
          targetSeat: mode == 'silenced target killed' ? argued : citizens.last);
    } else if (role == Role.doctor) {
      if (mode == 'doctor self protect bullet') {
        e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: actor, useBullet: true);
      } else {
        e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: cover);
      }
    } else if (role == Role.sniper && mode.startsWith('sniper')) {
      e.submitNightAction(seat: actor, kind: NightActionKind.suspect,
          targetSeat: shot, useBullet: true);
    } else {
      e.skipNightAction(seat: actor);
    }
    actions.add(actionRow(e.match.eventLog.skip(before).toList(), actor));
  }
  final report = e.resolveNight();
  final resolved = e.match.eventLog.whereType<NightResolved>().last;
  return {
    'name': '$mode seed $seed',
    'input': {
      'roster': roster,
      'actions': actions,
      'matchSeed': e.match.seed,
      'night': night,
      'settings': {
        'bulletsEnabled': settings.bulletsEnabled,
        'quietNightEnabled': settings.quietNightEnabled,
        'sniperEnabled': settings.sniperEnabled,
        'silencerEnabled': settings.silencerEnabled,
        'elderEnabled': settings.elderEnabled,
      },
      'lockedSeatSet': <int>[],
      'noSilenceSeatSet': <int>[],
    },
    'expected': {
      'deathSeats': report.victimSeats,
      'savedSeat': resolved.savedSeat,
      'saveTold': report.someoneSavedUnnamed,
      'silencedSeat': report.silencedSeat,
    },
  };
}

List<Map<String, dynamic>> generateNightVectors() => [
  for (final mode in modes)
    for (final seed in [3, 11, 29]) scenario(mode, seed),
];

void main() {
  final vectors = {'version': 1, 'scenarios': generateNightVectors()};
  File(outputPath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(vectors)}\n');
}
