/// Deterministic cross-engine night matrix. Run: dart run tool/night_matrix.dart.
/// Actions are taken from real MatchEngine events, using night_vectors helpers.
import 'dart:convert';
import 'dart:io';

import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'night_vectors.dart' as vectors;

const voteModes = ['citizen', 'doctor', 'detective', 'elder', 'sniper',
  'split', 'majority', 'one_skips', 'all_skip', 'quiet', 'quiet_spent',
  'quiet_disabled'];
const doctorModes = ['victim', 'other', 'self_first', 'self_spent',
  'repeat_refused', 'skip'];
const silenceModes = ['town', 'victim', 'shot', 'nobody'];
const sniperModes = ['mafia', 'silencer', 'town', 'victim', 'nobody', 'spent'];
const detectiveModes = ['mafia', 'silencer', 'doctor', 'detective', 'elder',
  'sniper', 'citizen'];

int? firstRole(MatchEngine engine, Role role, {int? except}) {
  for (final p in engine.match.players) {
    if (p.role == role && p.status == PlayerStatus.alive && p.seat != except) {
      return p.seat;
    }
  }
  return null;
}

int? roleTarget(MatchEngine e, String kind) => switch (kind) {
  'mafia' => firstRole(e, Role.mafia),
  'silencer' => firstRole(e, Role.silencer),
  'doctor' => firstRole(e, Role.doctor),
  'detective' => firstRole(e, Role.detective),
  'elder' => firstRole(e, Role.elder),
  'sniper' => firstRole(e, Role.sniper),
  _ => firstRole(e, Role.citizen),
};

Map<String, dynamic>? build(int count, int mask, int index) {
  // RL22 / MatchPreset.classic, plus a three-Mafia twelve for 2-1 and 1-1-1.
  final mafiaCount = count <= 6 ? 1 : count == 12 && (index ~/ 2).isOdd ? 3 : 2;
  final silencer = mask & 1 != 0;
  final sniper = mask & 2 != 0;
  final elder = mask & 4 != 0;
  final detective = mask & 8 != 0;
  if ((silencer && mafiaCount < 2) || (sniper && count < 7) ||
      (elder && count < 6)) return null;
  final doctor = count >= 7;
  final counts = <Role, int>{
    Role.mafia: mafiaCount - (silencer ? 1 : 0),
    if (silencer) Role.silencer: 1,
    if (doctor) Role.doctor: 1,
    if (detective) Role.detective: 1,
    if (sniper) Role.sniper: 1,
    if (elder) Role.elder: 1,
    Role.citizen: count - mafiaCount - (doctor ? 1 : 0) -
      (detective ? 1 : 0) - (sniper ? 1 : 0) - (elder ? 1 : 0),
  };
  if (counts[Role.citizen]! < 1) return null;
  final vote = voteModes[(index + mask) % voteModes.length];
  final doctorMode = doctorModes[(index * 5 + mask) % doctorModes.length];
  final silenceMode = silenceModes[(index + mask ~/ 2) % silenceModes.length];
  final sniperMode = sniperModes[(index * 5 + mask ~/ 3) % sniperModes.length];
  final detectiveMode = detectiveModes[(index * 3 + mask) % detectiveModes.length];
  final secondNight = index % 4 == 3 || doctorMode == 'self_spent' ||
    doctorMode == 'repeat_refused' || sniperMode == 'spent' || vote == 'quiet_spent';
  final bulletsEnabled = vote != 'quiet_disabled';
  final settings = MatchSettings(
    abstainAllowed: true, bulletsEnabled: bulletsEnabled,
    sniperEnabled: sniper, silencerEnabled: silencer, elderEnabled: elder,
  );
  final seed = 1009 + count * 1000 + mask * 101 + index;
  final e = vectors.start(counts, settings, seed);
  final mafiosi = vectors.seatsOf(e, Role.mafia);
  final doctorSeat = firstRole(e, Role.doctor);
  final sniperSeat = firstRole(e, Role.sniper);
  final silencerSeat = firstRole(e, Role.silencer);
  final citizen = firstRole(e, Role.citizen)!;
  // A previous night provides actual engine history for spent bullets and the
  // doctor's no-repeat guard. No prior action is synthesized in the input.
  int? lastProtect;
  if (secondNight) {
    e.beginNight();
    while (e.match.currentActorSeat != null) {
      final actor = e.match.currentActorSeat!;
      final role = e.match.players[actor].role;
      if (role == Role.doctor) {
        if (doctorMode == 'self_spent') {
          e.skipNightAction(seat: actor, useBullet: true);
          lastProtect = actor;
        } else {
          lastProtect = citizen == actor ? mafiosi.first : citizen;
          e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: lastProtect!);
        }
      } else if (role == Role.sniper && sniperMode == 'spent') {
        // Shoot a Mafioso; the second night must still be reachable.
        e.submitNightAction(seat: actor, kind: NightActionKind.suspect,
          targetSeat: mafiosi.first, useBullet: true);
      } else if (role == Role.mafia && vote == 'quiet_spent' &&
          actor == mafiosi.first) {
        e.skipNightAction(seat: actor, useBullet: true);
      } else {
        e.skipNightAction(seat: actor);
      }
    }
    e.resolveNight();
    if (e.outcomeAfterNight() != null) return null;
    vectors.nextNight(e);
  }
  e.beginNight();
  final roster = [for (final p in e.match.players)
    {'user_id': 'u${p.seat}', 'seat': p.seat, 'role': p.role.name,
      'alive': p.status == PlayerStatus.alive}];
  final victimKind = ['citizen','doctor','detective','elder','sniper'].contains(vote)
    ? vote : 'citizen';
  final victim = roleTarget(e, victimKind) ?? citizen;
  final other = firstRole(e, Role.citizen, except: victim) ??
    firstRole(e, Role.mafia) ?? citizen;
  final shot = switch (sniperMode) {
    'mafia' => firstRole(e, Role.mafia),
    'silencer' => silencerSeat,
    'town' => firstRole(e, Role.citizen, except: victim) ?? citizen,
    _ => victim,
  };
  final actions = <Map<String, dynamic>>[];
  final investigations = <Map<String, dynamic>>[];
  var refusedRepeat = false;
  var refusedBullet = false;
  while (e.match.currentActorSeat != null) {
    final actor = e.match.currentActorSeat!;
    final role = e.match.players[actor].role;
    final before = e.match.eventLog.length;
    if (role == Role.mafia) {
      final slot = mafiosi.indexOf(actor);
      if (vote == 'all_skip' || (vote == 'one_skips' && slot == 0) ||
          (vote == 'quiet_spent' && slot == 0)) {
        e.skipNightAction(seat: actor);
      } else if (vote == 'quiet' && slot == 0) {
        e.submitNightAction(seat: actor, kind: NightActionKind.mafiaVote,
          targetSeat: victim, useBullet: true);
      } else {
        // 'split': 1-1 with two Mafiosi, 1-1-1 with three (the third takes
        // a second town seat); 'majority': 2-1 when there are three.
        final third = e.match.players
            .where((p) => p.status == PlayerStatus.alive &&
                p.role.alignment != Alignment.mafia &&
                p.seat != victim && p.seat != other)
            .map((p) => p.seat)
            .firstOrNull;
        final target = switch (vote) {
          'split' when slot == 1 &&
              e.match.players[other].role.alignment != Alignment.mafia => other,
          'split' when slot == 2 && third != null && third != victim &&
              third != other => third,
          'majority' when slot == 2 &&
              e.match.players[other].role.alignment != Alignment.mafia => other,
          _ => victim,
        };
        e.submitNightAction(seat: actor, kind: NightActionKind.mafiaVote,
          targetSeat: target);
      }
    } else if (role == Role.doctor) {
      if (doctorMode == 'repeat_refused' && lastProtect != null &&
          lastProtect != actor) {
        try {
          e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: lastProtect);
        } on StateError catch (error) {
          if (!error.toString().contains('consecutive nights')) rethrow;
          refusedRepeat = true;
        }
      }
      if (doctorMode == 'self_spent' && secondNight) {
        try {
          e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: victim, useBullet: true);
        } on StateError catch (error) {
          if (!error.toString().contains('bullet')) rethrow;
          refusedBullet = true;
        }
      }
      if (doctorMode == 'self_first') {
        if (secondNight && lastProtect == actor) {
          e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: other);
        } else {
          e.submitNightAction(seat: actor, kind: NightActionKind.protect,
            targetSeat: victim, useBullet: true);
        }
      } else if (doctorMode == 'skip') {
        e.skipNightAction(seat: actor);
      } else {
        var target = doctorMode == 'victim' ? victim : other;
        if (target == actor || target == lastProtect) {
          target = e.match.players.firstWhere((p) =>
            p.status == PlayerStatus.alive && p.seat != actor &&
            p.seat != lastProtect).seat;
        }
        e.submitNightAction(seat: actor, kind: NightActionKind.protect,
          targetSeat: target);
      }
    } else if (role == Role.silencer) {
      if (silenceMode == 'nobody') {
        e.skipNightAction(seat: actor);
      } else {
        final target = silenceMode == 'victim' ? victim :
          silenceMode == 'shot' && sniper && shot != null ? shot : citizen;
        e.submitNightAction(seat: actor, kind: NightActionKind.silence,
          targetSeat: target);
      }
    } else if (role == Role.sniper &&
        !['nobody', 'spent'].contains(sniperMode) && shot != null &&
        shot != actor) {
      e.submitNightAction(seat: actor, kind: NightActionKind.suspect,
        targetSeat: shot, useBullet: true);
    } else if (role == Role.detective) {
      final target = roleTarget(e, detectiveMode) ?? citizen;
      // Never the Detective's own seat: the engine refuses a self-target.
      final actual = target != actor
          ? target
          : e.match.players.firstWhere((p) =>
              p.status == PlayerStatus.alive && p.seat != actor).seat;
      final result = e.submitNightAction(seat: actor,
        kind: NightActionKind.investigate, targetSeat: actual);
      investigations.add({'targetSeat': actual,
        'revealedRole': result!.revealedRole.name});
    } else {
      e.skipNightAction(seat: actor);
    }
    actions.add(vectors.actionRow(e.match.eventLog.skip(before).toList(), actor));
  }
  final report = e.resolveNight();
  final resolved = e.match.eventLog.whereType<NightResolved>().last;
  final tally = <int, int>{};
  for (final action in actions.where((a) => a['action'] == 'kill')) {
    final seat = int.parse((action['target_id'] as String).substring(1));
    tally[seat] = (tally[seat] ?? 0) + 1;
  }
  final top = tally.values.isEmpty ? 0 : tally.values.reduce((a,b) => a > b ? a : b);
  final tied = [for (final entry in tally.entries) if (entry.value == top) entry.key]..sort();
  return {
    'name': 'n$count mask$mask row$index $vote $doctorMode $silenceMode $sniperMode $detectiveMode',
    'axes': {'table': count, 'silencer': silencer, 'sniper': sniper,
      'elder': elder, 'detective': detective, 'mafiaVote': vote,
      'doctor': doctor ? doctorMode : 'absent',
      'silence': silencer ? silenceMode : 'absent',
      'sniperShot': sniper ? sniperMode : 'absent',
      'investigate': detective ? detectiveMode : 'absent',
      'night': secondNight ? 2 : 1},
    'input': {'roster': roster, 'actions': actions,
      'matchSeed': e.match.seed, 'night': e.match.dayNumber,
      'settings': {'bulletsEnabled': settings.bulletsEnabled,
        'quietNightEnabled': settings.quietNightEnabled,
        'sniperEnabled': settings.sniperEnabled,
        'silencerEnabled': settings.silencerEnabled,
        'elderEnabled': settings.elderEnabled},
      'lockedSeatSet': <int>[], 'noSilenceSeatSet': <int>[]},
    'expected': {'deathSeats': report.victimSeats,
      'savedSeat': resolved.savedSeat,
      'saveTold': report.someoneSavedUnnamed,
      'silencedSeat': report.silencedSeat},
    if (tied.length > 1) 'tiedSeats': tied,
    if (investigations.isNotEmpty) 'investigations': investigations,
    // Only a table with a Doctor can refuse a Doctor's move.
    if (doctor && doctorMode == 'repeat_refused' && lastProtect != null)
      'repeatRefused': refusedRepeat,
    if (doctor && doctorMode == 'self_spent' && secondNight)
      'secondBulletRefused': refusedBullet,
  };
}

void main() {
  final scenarios = <Map<String, dynamic>>[];
  for (final count in [5, 7, 9, 12]) {
    for (var mask = 0; mask < 16; mask++) {
      for (var index = 0; index < 24; index++) {
        final row = build(count, mask, index);
        if (row != null) scenarios.add(row);
      }
    }
  }
  File('supabase/tests/night_matrix.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'version': 1,
      'scenarios': scenarios})}\n');
  stdout.writeln('night matrix: ${scenarios.length} cases');
}
