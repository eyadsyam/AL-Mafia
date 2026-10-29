import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

int? seat(String? id) => id == null ? null : int.parse(id.substring(1));

/// Doc 17 §4 and rulings RL1, RL2, RL7, RL17, independently of NightResolver.
List<Map<String, dynamic>> oracle(Map<String, dynamic> input) {
  final roster = (input['roster'] as List).cast<Map<String, dynamic>>();
  final actions = (input['actions'] as List).cast<Map<String, dynamic>>();
  final settings = input['settings'] as Map<String, dynamic>;
  final roles = {for (final p in roster) p['seat'] as int: p['role'] as String};
  final alive = {
    for (final p in roster)
      if (p['alive'] == true) p['seat'] as int,
  };
  final locked = (input['lockedSeatSet'] as List).cast<int>().toSet();
  final noSilence = (input['noSilenceSeatSet'] as List).cast<int>().toSet();
  final votes = <int, int>{};
  final protections = <int, int>{};
  for (final action in actions) {
    final actor = seat(action['actor_id'] as String);
    final target = seat(action['target_id'] as String?);
    if (!alive.contains(actor) || !alive.contains(target)) continue;
    if (action['action'] == 'kill' &&
        roles[target] != 'mafia' &&
        roles[target] != 'silencer') {
      votes.update(target!, (n) => n + 1, ifAbsent: () => 1);
    }
    if (action['action'] == 'protect') {
      protections.update(target!, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  List<int?> winners(Map<int, int> tally) {
    if (tally.isEmpty) return [null];
    final top = tally.values.reduce((a, b) => a > b ? a : b);
    return [
      for (final entry in tally.entries)
        if (entry.value == top) entry.key,
    ]..sort((a, b) => (a ?? -1).compareTo(b ?? -1));
  }

  final quiet = actions.any(
    (a) =>
        a['used_bullet'] == true &&
        roles[seat(a['actor_id'] as String)] == 'mafia',
  );
  final possible = <Map<String, dynamic>>[];
  for (final chosen in winners(votes)) {
    for (final covered in winners(protections)) {
      var victim = locked.contains(chosen) ? null : chosen;
      int? saved;
      if (victim != null && victim == covered) {
        saved = victim;
        victim = null;
      }
      if (quiet) victim = null;
      final deaths = <int>{if (victim != null) victim};
      for (final action in actions) {
        if (action['action'] != 'suspect' || action['used_bullet'] != true)
          continue;
        final actor = seat(action['actor_id'] as String);
        final target = seat(action['target_id'] as String?);
        if (!alive.contains(actor) ||
            !alive.contains(target) ||
            locked.contains(target))
          continue;
        deaths.add(target!);
        if (roles[target] != 'mafia' && roles[target] != 'silencer') {
          deaths.add(actor!);
        }
      }
      if (deaths.contains(saved)) saved = null;
      int? silenced;
      for (final action in actions) {
        if (action['action'] != 'silence') continue;
        final actor = seat(action['actor_id'] as String);
        final target = seat(action['target_id'] as String?);
        if (alive.contains(actor) &&
            alive.contains(target) &&
            !locked.contains(target) &&
            !noSilence.contains(target) &&
            !deaths.contains(target)) {
          silenced = target;
          break;
        }
      }
      possible.add({
        'deathSeats': deaths.toList()..sort(),
        'savedSeat': saved,
        'saveTold':
            saved != null &&
            (settings['bulletsEnabled'] == false ||
                settings['quietNightEnabled'] == false),
        'silencedSeat': silenced,
      });
    }
  }
  return possible;
}

void main() {
  final json =
      jsonDecode(File('supabase/tests/night_matrix.json').readAsStringSync())
          as Map<String, dynamic>;
  final scenarios = (json['scenarios'] as List).cast<Map<String, dynamic>>();
  test('matrix is substantial and versioned', () {
    expect(json['version'], 1);
    expect(scenarios.length, greaterThanOrEqualTo(400));
  });
  for (final row in scenarios) {
    test(row['name'] as String, () {
      if (row['knownDivergence'] != null) {
        markTestSkipped(row['knownDivergence'] as String);
      }
      final input = row['input'] as Map<String, dynamic>;
      final expected = row['expected'] as Map<String, dynamic>;
      // Compared as JSON: a decoded map and a built one are never `==`.
      final allowed = [for (final o in oracle(input)) jsonEncode(o)];
      expect(
        allowed,
        contains(jsonEncode(expected)),
        reason: row['name'] as String,
      );
      if (row['repeatRefused'] != null) expect(row['repeatRefused'], true);
      if (row['secondBulletRefused'] != null)
        expect(row['secondBulletRefused'], true);
      for (final investigation in (row['investigations'] as List? ?? [])) {
        final fact = investigation as Map<String, dynamic>;
        final target = fact['targetSeat'] as int;
        final player = (input['roster'] as List)
            .cast<Map<String, dynamic>>()
            .singleWhere((p) => p['seat'] == target);
        expect(fact['revealedRole'], player['role']);
      }
    });
  }
}
