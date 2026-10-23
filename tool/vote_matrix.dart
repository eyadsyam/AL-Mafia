// Deterministic cross-engine day ballot contract. Run: dart run tool/vote_matrix.dart.
import 'dart:convert';
import 'dart:io';
import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

const shapes = [
  'unanimous',
  'majority',
  'plurality',
  'tie2',
  'tie3',
  'allButOneAbstain',
  'allAbstain',
  'singleBallot',
];

Map<String, dynamic>? build(
  int count,
  int mafiaCount,
  int elderMode,
  bool abstain,
  DayTieRule rule,
  int round,
  int shapeIndex,
  int whoIndex,
) {
  if (round == 2 && rule != DayTieRule.revote) return null;
  final settings = MatchSettings(
    dayTieRule: rule,
    abstainAllowed: abstain,
    elderEnabled: elderMode != 0,
    openingRoundEnabled: false,
    confrontationEnabled: false,
    traceEnabled: false,
  );
  final e = MatchEngine(clock: Clocks.monotonic());
  e.start(
    names: [for (var i = 0; i < count; i++) 'P$i'],
    roleCounts: {
      Role.mafia: mafiaCount,
      Role.detective: 1,
      if (count >= 7) Role.doctor: 1,
      if (elderMode != 0) Role.elder: 1,
      Role.citizen:
          count -
          mafiaCount -
          1 -
          (count >= 7 ? 1 : 0) -
          (elderMode != 0 ? 1 : 0),
    },
    settings: settings,
    seed: 7100 + count * 100 + mafiaCount * 30 + elderMode * 10,
  );
  for (var i = 0; i < count; i++) {
    e.revealFor(i);
    e.confirmRevealed();
  }
  final mafia = [
    for (final p in e.match.players)
      if (p.role == Role.mafia) p.seat,
  ];
  final town = [
    for (final p in e.match.players)
      if (p.role != Role.mafia) p.seat,
  ];
  // Reach the three meaningful win boundaries before the ballot.
  if (whoIndex == 0) {
    for (final s in mafia.skip(1)) {
      e.removePlayer(s);
    }
  } else if (whoIndex == 1) {
    for (final s in town.take(town.length - mafia.length - 1)) {
      e.removePlayer(s);
    }
  }
  e.beginNight();
  while (e.match.currentActorSeat != null) {
    e.skipNightAction(seat: e.match.currentActorSeat!);
  }
  e.resolveNight();
  e.beginDiscussion();
  if (elderMode == 2 && round == 1) {
    final elder = e.match.players
        .where((p) => p.role == Role.elder && p.status == PlayerStatus.alive)
        .firstOrNull;
    if (elder != null) e.revealElder(elder.seat);
  }
  e.beginVoting();
  final alive = [
    for (final p in e.match.players)
      if (p.status == PlayerStatus.alive) p.seat,
  ];
  if (alive.length < 3) return null;
  final leader = whoIndex == 0
      ? mafia.first
      : (whoIndex == 1 ? town.last : town.first);
  if (!alive.contains(leader)) return null;
  final others = [
    for (final s in alive)
      if (s != leader) s,
  ];
  if (others.length < 2 && (shapeIndex == 4 || round == 2)) return null;
  final targets = [leader, ...others.take(2)];
  final shape = shapes[shapeIndex];
  if (!abstain && shape == 'unanimous') return null;
  final firstVotes = <int, int?>{};
  if (round == 2) {
    // Force a genuine first-round tie, then use its actual narrowed candidates.
    if (abstain) {
      for (final s in alive) {
        firstVotes[s] = null;
      }
      firstVotes[targets[0]] = targets[1];
      firstVotes[targets[1]] = targets[0];
    } else {
      final desired = [
        alive.length ~/ 2,
        alive.length ~/ 2,
        alive.length.isOdd ? 1 : 0,
      ];
      List<int>? assign(int index, List<int> remaining, List<int> chosen) {
        if (index == alive.length) return chosen;
        for (var j = 0; j < 3; j++) {
          if (remaining[j] == 0 || targets[j] == alive[index]) continue;
          final next = [...remaining];
          next[j]--;
          final result = assign(index + 1, next, [...chosen, targets[j]]);
          if (result != null) return result;
        }
        return null;
      }

      final assigned = assign(0, desired, <int>[]);
      if (assigned == null) return null;
      for (var i = 0; i < alive.length; i++) {
        firstVotes[alive[i]] = assigned[i];
      }
    }
    e.submitVote(
      seat: e.match.currentActorSeat!,
      voterSeat: e.match.currentActorSeat!,
      targetSeat: firstVotes[e.match.currentActorSeat!],
    );
    while (e.match.currentActorSeat != null) {
      final s = e.match.currentActorSeat!;
      e.submitVote(seat: s, voterSeat: s, targetSeat: firstVotes[s]);
    }
    final first = e.resolveDayVote();
    if (!first.tie || e.match.phase != GamePhase.voting) return null;
    if (elderMode == 2) {
      final elder = e.match.players
          .where((p) => p.role == Role.elder && p.status == PlayerStatus.alive)
          .firstOrNull;
      if (elder != null) e.revealElder(elder.seat);
    }
  }
  final candidates = round == 2 ? e.currentVoteCandidates! : targets;
  final picks = <int?>[];
  switch (shape) {
    case 'unanimous':
      picks.addAll(List.filled(alive.length, leader));
    case 'majority':
      picks.addAll([leader, leader, leader, candidates[1]]);
    case 'plurality':
      picks.addAll([
        leader,
        leader,
        candidates[1],
        if (candidates.length > 2) candidates[2],
      ]);
    case 'tie2':
      picks.addAll([leader, leader, candidates[1], candidates[1]]);
    case 'tie3':
      if (candidates.length < 3) return null;
      picks.addAll([leader, candidates[1], candidates[2]]);
    case 'allButOneAbstain':
      picks.add(leader);
    case 'allAbstain':
      break;
    case 'singleBallot':
      picks.add(leader);
  }
  while (picks.length < alive.length) {
    if (!abstain &&
        !{'allButOneAbstain', 'allAbstain', 'singleBallot'}.contains(shape)) {
      picks.add(
        shape == 'tie2'
            ? candidates[picks.length % 2]
            : shape == 'tie3'
            ? candidates[picks.length % 3]
            : leader,
      );
    } else {
      picks.add(null);
    }
  }
  final votes = <int, int?>{};
  for (var i = 0; i < alive.length; i++) {
    var target = picks[i];
    if (target == alive[i]) {
      target = shape == 'unanimous'
          ? candidates.firstWhere((s) => s != alive[i], orElse: () => leader)
          : !abstain && target != null
          ? candidates.firstWhere((s) => s != alive[i])
          : null;
    }
    votes[alive[i]] = target;
  }
  final refusedNull = !abstain && votes.values.contains(null);
  final refusedOutside =
      round == 2 &&
      alive.any(
        (s) => !candidates.contains(s) && s != e.match.currentActorSeat,
      );
  bool? nullRefusalObserved;
  if (refusedNull) {
    final snapshot = e.match;
    nullRefusalObserved = false;
    try {
      final actor = e.match.currentActorSeat!;
      e.submitVote(seat: actor, voterSeat: actor, targetSeat: null);
    } on StateError {
      nullRefusalObserved = true;
    }
    e.match = snapshot;
    return {
      'name':
          'n$count mafia$mafiaCount elder$elderMode abstain$abstain '
          '${rule.name} round$round $shape who$whoIndex null-refusal',
      'kind': 'refusal',
      'axes': {
        'table': count,
        'mafiaSeats': mafiaCount,
        'elder': elderMode,
        'abstainAllowed': abstain,
        'dayTieRule': rule.name,
        'round': round,
        'shape': shape,
        'who': ['lastMafia', 'parity', 'continue'][whoIndex],
      },
      'input': {
        'roster': [
          for (final p in e.match.players)
            {
              'user_id': 'u${p.seat}',
              'seat': p.seat,
              'alive': p.status == PlayerStatus.alive,
              'role': p.role.name,
            },
        ],
        'cast': <Map<String, dynamic>>[],
        'round': round,
        'revoteState': round == 2
            ? {'round': 2, 'tiedSeats': candidates}
            : null,
        'toolUses': <Map<String, dynamic>>[],
        'day': 1,
        'revealedElderSeats': elderMode == 2
            ? [
                for (final p in e.match.players)
                  if (p.role == Role.elder && p.status == PlayerStatus.alive)
                    p.seat,
              ]
            : <int>[],
        'decidedOutcome': null,
        'settings': {'dayTieRule': rule.name, 'abstainAllowed': abstain},
      },
      'attempt': {
        'voter_id': 'u${e.match.currentActorSeat}',
        'target_id': null,
        'round': round,
      },
      'expected': {'refused': nullRefusalObserved},
      'knownDivergence':
          'RL9: offline submitVote accepts null with abstainAllowed=false',
    };
  }
  bool outsideRejected = false;
  if (refusedOutside) {
    final outside = alive.firstWhere(
      (s) => !candidates.contains(s) && s != e.match.currentActorSeat,
    );
    try {
      e.submitVote(
        seat: e.match.currentActorSeat!,
        voterSeat: e.match.currentActorSeat!,
        targetSeat: outside,
      );
    } on StateError {
      outsideRejected = true;
    }
    if (!outsideRejected) throw StateError('round 2 outside target accepted');
  }
  bool deadTargetRejected = false;
  final dead = [
    for (final p in e.match.players)
      if (p.status == PlayerStatus.dead) p.seat,
  ];
  if (dead.isNotEmpty) {
    try {
      e.submitVote(
        seat: e.match.currentActorSeat!,
        voterSeat: e.match.currentActorSeat!,
        targetSeat: dead.first,
      );
    } on StateError {
      deadTargetRejected = true;
    }
    if (!deadTargetRejected) throw StateError('dead target accepted');
  }
  final cast = <Map<String, dynamic>>[];
  for (final s in alive) {
    final target = votes[s];
    e.submitVote(seat: s, voterSeat: s, targetSeat: target);
    cast.add({
      'voter_id': 'u$s',
      'target_id': target == null ? null : 'u$target',
      'round': round,
    });
  }
  final result = e.resolveDayVote();
  final opened = e.match.phase == GamePhase.voting;
  final outcome = opened ? null : e.winCheck()?.name;
  final roster = [
    for (final p in e.match.players)
      {
        'user_id': 'u${p.seat}',
        'seat': p.seat,
        'alive':
            p.status == PlayerStatus.alive || p.seat == result.eliminatedSeat,
        'role': p.role.name,
      },
  ];
  final input = <String, dynamic>{
    'roster': roster,
    'cast': cast,
    'round': round,
    'revoteState': round == 2 ? {'round': 2, 'tiedSeats': candidates} : null,
    'toolUses': [],
    'day': 1,
    'revealedElderSeats': elderMode == 2
        ? [
            for (final p in roster)
              if (p['role'] == 'elder' && p['alive'] == true) p['seat'],
          ]
        : [],
    'decidedOutcome': null,
    'settings': {'dayTieRule': rule.name, 'abstainAllowed': abstain},
  };
  final expected = {
    'eliminatedSeat': result.eliminatedSeat,
    'tie': result.tie,
    'tiedSeats': result.tiedSeats ?? <int>[],
    'revote': opened,
    'outcome': outcome,
  };
  final name =
      'n$count mafia$mafiaCount elder$elderMode abstain$abstain ${rule.name} '
      'round$round $shape who$whoIndex';
  if (refusedOutside) {
    final outside = alive.firstWhere((s) => !candidates.contains(s));
    cast.add({
      'voter_id': 'u${alive.first}',
      'target_id': 'u$outside',
      'round': round,
    });
  }
  if (dead.isNotEmpty) {
    // These historical or invalid rows are absent from the offline log and
    // must leave the server result identical to the real engine's result.
    cast.add({
      'voter_id': 'u${dead.first}',
      'target_id': 'u$leader',
      'round': round,
    });
    cast.add({
      'voter_id': 'u${alive.first}',
      'target_id': 'u${dead.first}',
      'round': round,
    });
  }
  return {
    'name': name,
    'axes': {
      'table': count,
      'mafiaSeats': mafiaCount,
      'elder': elderMode,
      'abstainAllowed': abstain,
      'dayTieRule': rule.name,
      'round': round,
      'shape': shape,
      'who': ['lastMafia', 'parity', 'continue'][whoIndex],
    },
    'input': input,
    'expected': expected,
    if (refusedOutside) 'outsideRefusal': outsideRejected,
    if (dead.isNotEmpty) 'deadTargetRefusal': deadTargetRejected,
    if (dead.isNotEmpty) 'deadVoterIgnored': true,
  };
}

void main() {
  final scenarios = <Map<String, dynamic>>[];
  for (final count in [5, 7, 9, 12]) {
    for (final mafiaCount in count == 12 ? [2, 3] : [count == 5 ? 1 : 2]) {
      for (var elder = 0; elder < 3; elder++) {
        if (count == 5 && elder != 0) continue;
        for (final abstain in [false, true]) {
          for (final rule in DayTieRule.values) {
            for (final round in [1, 2]) {
              for (var shape = 0; shape < shapes.length; shape++) {
                final who = (count + elder + shape + round) % 3;
                final row = build(
                  count,
                  mafiaCount,
                  elder,
                  abstain,
                  rule,
                  round,
                  shape,
                  who,
                );
                if (row != null) scenarios.add(row);
              }
            }
          }
        }
      }
    }
  }
  final baseRoster = [
    for (var seat = 0; seat < 7; seat++)
      {
        'user_id': 'u$seat',
        'seat': seat,
        'alive': true,
        'role': seat < 2
            ? 'mafia'
            : seat == 2
            ? 'elder'
            : 'citizen',
      },
  ];
  void toolCase(
    String name,
    List<int?> targets, {
    int round = 1,
    List<int> narrowed = const [3, 4, 5],
    String rule = 'noElimination',
    List<Map<String, dynamic>> uses = const [],
    List<int> revealed = const [],
    String? decided,
  }) {
    final ballots = [
      for (var voter = 0; voter < targets.length; voter++)
        {
          'voter_id': 'u$voter',
          'target_id': targets[voter] == null ? null : 'u${targets[voter]}',
          'round': round,
        },
    ];
    scenarios.add({
      'name': 'tool $name',
      'kind': 'tool',
      'input': {
        'roster': baseRoster,
        'cast': ballots,
        'round': round,
        'revoteState': round == 2 ? {'round': 2, 'tiedSeats': narrowed} : null,
        'toolUses': uses,
        'day': 1,
        'revealedElderSeats': revealed,
        'decidedOutcome': decided,
        'settings': {'dayTieRule': rule},
      },
      'axes': {'tool': name, 'round': round, 'dayTieRule': rule},
    });
  }

  Map<String, dynamic> use(String code, int seat) => {
    'user_id': 'u$seat',
    'seat': seat,
    'tool_code': code,
    'phase': 'vote',
    'phase_number': 1,
    'target_seats': <int>[],
    'note': null,
  };
  for (final round in [1, 2]) {
    for (var candidates = 0; candidates <= 3; candidates++) {
      final targets = <int?>[
        for (var i = 0; i < 7; i++) i < candidates ? 3 + i : null,
      ];
      toolCase(
        'boughtRevote candidates$candidates round$round',
        targets,
        round: round,
        uses: [use('revote', 0)],
      );
    }
  }
  toolCase(
    'boughtRevote ordinaryTie',
    [3, 3, 4, 4, null, null, null],
    rule: 'revote',
    uses: [use('revote', 0)],
  );
  toolCase(
    'boughtRevote noEliminationTie',
    [3, 3, 4, 4, null, null, null],
    uses: [use('revote', 0)],
  );
  toolCase(
    'doubleVote deciding',
    [3, 4, 3, 4, null, null, null],
    uses: [use('double_vote', 0)],
  );
  toolCase(
    'doubleVote tying',
    [3, 4, 4, null, null, null, null],
    uses: [use('double_vote', 0)],
  );
  toolCase(
    'doubleVote revealedElder six',
    [3, 4, 3, null, null, null, null],
    uses: [use('double_vote', 2)],
    revealed: [2],
  );
  toolCase(
    'voteShield current leader',
    [3, 3, 4, null, null, null, null],
    uses: [use('vote_shield', 3)],
  );
  for (final round in [1, 2]) {
    toolCase(
      'appeal upheld round$round',
      [3, 3, 3, 4, 3, 3, null],
      round: round,
      uses: [use('appeal', 3)],
    );
    toolCase(
      'appeal held round$round',
      [3, 3, 3, null, null, null, null],
      round: round,
      uses: [use('appeal', 3)],
    );
    toolCase(
      'appeal unrelated round$round',
      [3, 3, 4, null, null, null, null],
      round: round,
      uses: [use('appeal', 4)],
    );
  }
  toolCase('decided outcome ballots remain', [
    3,
    3,
    3,
    4,
    null,
    null,
    null,
  ], decided: 'town');
  File('supabase/tests/vote_matrix.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'version': 1, 'scenarios': scenarios})}\n',
  );
  final toolCount = scenarios.where((row) => row['kind'] == 'tool').length;
  stdout.writeln(
    'vote matrix: ${scenarios.length - toolCount} engine cases, '
    '$toolCount tool cases',
  );
}
