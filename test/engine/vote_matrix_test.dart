import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

int? seat(String? id) => id == null ? null : int.parse(id.substring(1));

/// Independent reading of doc 17 §6 and doc 11 D1-D4, D11-D12.
Map<String, dynamic> oracle(Map<String, dynamic> input) {
  final roster = (input['roster'] as List).cast<Map<String, dynamic>>();
  final cast = (input['cast'] as List).cast<Map<String, dynamic>>();
  final settings = input['settings'] as Map<String, dynamic>;
  final alive = {
    for (final p in roster)
      if (p['alive'] == true) p['seat'] as int,
  };
  final roles = {for (final p in roster) p['seat'] as int: p['role'] as String};
  final round = input['round'] as int;
  final tied = round == 2
      ? ((input['revoteState'] as Map<String, dynamic>)['tiedSeats'] as List)
            .cast<int>()
      : <int>[];
  final revealed = (input['revealedElderSeats'] as List).cast<int>().toSet();
  final tally = <int, int>{};
  for (final ballot in cast) {
    final voter = seat(ballot['voter_id'] as String)!;
    final target = seat(ballot['target_id'] as String?);
    if (ballot['round'] != round ||
        !alive.contains(voter) ||
        (target != null && !alive.contains(target)) ||
        (round == 2 && target != null && !tied.contains(target))) {
      continue;
    }
    if (target != null) {
      final weight = roles[voter] == 'elder' && revealed.contains(voter)
          ? 3
          : 1;
      tally.update(target, (n) => n + weight, ifAbsent: () => weight);
    }
  }
  final maximum = tally.isEmpty
      ? 0
      : tally.values.reduce((a, b) => a > b ? a : b);
  final leaders = [
    for (final entry in tally.entries)
      if (entry.value == maximum) entry.key,
  ]..sort();
  final tie = leaders.length > 1;
  final revote = tie && round == 1 && settings['dayTieRule'] == 'revote';
  final eliminated = leaders.length == 1 ? leaders.first : null;
  final survivors = [
    for (final s in alive)
      if (s != eliminated) s,
  ];
  final mafia = survivors
      .where((s) => roles[s] == 'mafia' || roles[s] == 'silencer')
      .length;
  final town = survivors.length - mafia;
  final outcome = revote
      ? null
      : mafia == 0
      ? 'town'
      : mafia >= town
      ? 'mafia'
      : null;
  return {
    'eliminatedSeat': eliminated,
    'tie': tie,
    'tiedSeats': tie ? leaders : <int>[],
    'revote': revote,
    'outcome': outcome,
  };
}

void main() {
  final document =
      jsonDecode(File('supabase/tests/vote_matrix.json').readAsStringSync())
          as Map<String, dynamic>;
  final cases = (document['scenarios'] as List)
      .cast<Map<String, dynamic>>()
      .where((row) => row['kind'] != 'tool')
      .toList();
  test('version and coverage', () {
    expect(document['version'], 1);
    expect(cases.length >= 400, true);
    for (final table in [5, 7, 9, 12]) {
      expect(cases.any((row) => (row['axes'] as Map)['table'] == table), true);
    }
  });
  for (final row in cases) {
    test(row['name'] as String, () {
      final input = row['input'] as Map<String, dynamic>;
      if (row['kind'] == 'refusal') {
        final attempt = row['attempt'] as Map<String, dynamic>;
        final settings = input['settings'] as Map<String, dynamic>;
        expect(row['expected'], {
          'refused':
              attempt['target_id'] == null &&
              settings['abstainAllowed'] != true,
        }, reason: row['name'] as String);
        return;
      }
      expect(row['expected'], oracle(input), reason: row['name'] as String);
      if (row['outsideRefusal'] != null) expect(row['outsideRefusal'], true);
      if (row['deadTargetRefusal'] != null) {
        expect(row['deadTargetRefusal'], true);
      }
    }, skip: row['knownDivergence'] as String?);
  }
}
