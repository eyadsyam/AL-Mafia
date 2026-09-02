/// Generates `supabase/tests/golden_vectors.json` — the contract between the
/// Dart generators and their TypeScript port.
///
/// ```
/// dart run tool/golden_vectors.dart
/// ```
///
/// # What this file is for
///
/// Doc 10 §5.1 requires the two implementations to produce **byte-identical**
/// output and puts a golden-vector test in CI to prove it. This writes the
/// vectors; `test/engine/golden_vectors_test.dart` holds the Dart side to them
/// and `supabase/tests/golden_vectors.test.ts` holds the TypeScript side to the
/// same file. Neither test can pass by agreeing with itself.
///
/// # Regenerating is a decision, not a fix
///
/// If the Dart test fails, the generator changed and the vectors are now a
/// record of the old behaviour — which is exactly what they are for. Rerunning
/// this tool makes the failure go away and takes the port with it only if
/// somebody then updates the TypeScript too. Regenerate deliberately, in the
/// same commit as the change, and check the TS test still passes.
library tool.golden_vectors;

import 'dart:convert';
import 'dart:io';

import 'package:mafia_master/engine/information/confrontation_generator.dart';
import 'package:mafia_master/engine/information/game_history.dart';
import 'package:mafia_master/engine/information/records.dart';
import 'package:mafia_master/engine/information/trace_generator.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/information_enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';

const String outputPath = 'supabase/tests/golden_vectors.json';

// ---------------------------------------------------------------------------
// The wire shape. Deliberately flat and deliberately boring: it is read by two
// languages, so anything clever here is a chance for them to disagree.
// ---------------------------------------------------------------------------

Map<String, dynamic> encodeNight(NightRecord n) => {
      'nightNumber': n.nightNumber,
      'suspicions': {
        for (final e in n.suspicions.entries) '${e.key}': e.value,
      },
      'victim': n.victim,
      'saveOccurred': n.saveOccurred,
      'savedSeat': n.savedSeat,
      'revealedTrace': n.revealedTrace?.name,
      'resolved': n.resolved,
    };

Map<String, dynamic> encodeDay(DayRecord d) => {
      'dayNumber': d.dayNumber,
      'openingAccusations': {
        for (final e in d.openingAccusations.entries) '${e.key}': e.value,
      },
      'confrontation':
          d.confrontation == null ? null : encodeConfrontation(d.confrontation!),
      'votes': {for (final e in d.votes.entries) '${e.key}': e.value},
      'speakingSeconds': {
        for (final e in d.speakingSeconds.entries) '${e.key}': e.value,
      },
      'whispers': [
        for (final w in d.whispers)
          {'day': w.day, 'fromSeat': w.fromSeat, 'toSeat': w.toSeat},
      ],
    };

Map<String, dynamic> encodeConfrontation(Confrontation c) => {
      'type': c.type.name,
      'targetSeat': c.targetSeat,
      'evidenceSeat': c.evidenceSeat,
      'evidenceSeat2': c.evidenceSeat2,
      'evidenceDay': c.evidenceDay,
      'count': c.count,
    };

Map<String, dynamic> encodeTrace(TraceResult t) => {
      'type': t.type.name,
      'subjectSeat': t.subjectSeat,
      'targetSeat': t.targetSeat,
      'count': t.count,
    };

// ---------------------------------------------------------------------------
// Scenarios. One per eligibility branch, plus the awkward ones: a forced tie,
// a fairness cap that has to yield, an empty history.
// ---------------------------------------------------------------------------

NightRecord night({
  required int number,
  Map<int, int?> suspicions = const {},
  int? victim,
  int? savedSeat,
  TraceType? revealed,
  bool resolved = true,
}) =>
    NightRecord(
      nightNumber: number,
      suspicions: suspicions,
      reasons: const {},
      victim: victim,
      saveOccurred: savedSeat != null,
      savedSeat: savedSeat,
      revealedTrace: revealed,
      resolved: resolved,
    );

DayRecord day({
  required int number,
  Map<int, int> opening = const {},
  Map<int, int?> votes = const {},
  Confrontation? confrontation,
  Map<int, int> speaking = const {},
  List<WhisperMeta> whispers = const [],
}) =>
    DayRecord(
      dayNumber: number,
      openingAccusations: opening,
      votes: votes,
      votesByRound: {1: votes},
      confrontation: confrontation,
      speakingSeconds: speaking,
      whispers: whispers,
    );

List<Player> roster(Set<int> alive, {int count = 7}) => [
      for (var seat = 0; seat < count; seat++)
        Player(
          seat: seat,
          name: 'P$seat',
          role: Role.citizen,
          status: alive.contains(seat) ? PlayerStatus.alive : PlayerStatus.dead,
          eliminatedOn: alive.contains(seat)
              ? null
              : const PhaseRef(phase: GamePhase.night, number: 1),
        ),
    ];

const Set<int> allSeven = {0, 1, 2, 3, 4, 5, 6};

class TraceCase {
  final String name;
  final NightRecord tonight;
  final List<NightRecord> history;
  final Set<int> alive;
  final int nightNumber;
  final int seed;

  const TraceCase(
    this.name, {
    required this.tonight,
    this.history = const [],
    this.alive = allSeven,
    required this.nightNumber,
    required this.seed,
  });
}

final List<TraceCase> traceCases = [
  TraceCase('nothing eligible',
      tonight: night(number: 1), nightNumber: 1, seed: 1),
  TraceCase('t1 fires',
      tonight: night(number: 1, victim: 3, suspicions: {3: 5}),
      alive: {0, 1, 2, 4, 5, 6},
      nightNumber: 1,
      seed: 2),
  TraceCase('t1 target already dead',
      tonight: night(number: 2, victim: 3, suspicions: {3: 5}),
      history: [night(number: 1)],
      alive: {0, 1, 2, 4, 6},
      nightNumber: 2,
      seed: 3),
  TraceCase('t1 victim skipped',
      tonight: night(number: 1, victim: 3, suspicions: {3: null}),
      alive: {0, 1, 2, 4, 5, 6},
      nightNumber: 1,
      seed: 4),
  TraceCase('t2 save',
      tonight: night(number: 1, savedSeat: 4), nightNumber: 1, seed: 5),
  TraceCase('t3 agreement of three',
      tonight: night(number: 1, suspicions: {0: 5, 1: 5, 2: 5}),
      nightNumber: 1,
      seed: 6),
  TraceCase('t4 two changed',
      tonight: night(number: 2, suspicions: {0: 3, 1: 4, 2: 5}),
      history: [night(number: 1, suspicions: {0: 6, 1: 6, 2: 5})],
      nightNumber: 2,
      seed: 7),
  TraceCase('t5 shadow from night two',
      tonight: night(number: 2, suspicions: {0: 1}),
      history: [night(number: 1, suspicions: {0: 1, 2: 1})],
      nightNumber: 2,
      seed: 8),
  TraceCase('t6 two skips',
      tonight: night(number: 1, suspicions: {0: null, 1: null, 2: 3}),
      nightNumber: 1,
      seed: 9),
  TraceCase('t7 mutual',
      tonight: night(number: 1, suspicions: {0: 1, 1: 0}),
      nightNumber: 1,
      seed: 10),
  TraceCase('t8 consensus of five',
      tonight: night(number: 1, suspicions: {0: 6, 1: 6, 2: 6, 3: 6, 4: 6}),
      nightNumber: 1,
      seed: 11),
  TraceCase('back-to-back exclusion',
      tonight: night(number: 2, savedSeat: 4),
      history: [night(number: 1, savedSeat: 3, revealed: TraceType.t2)],
      nightNumber: 2,
      seed: 12),
  TraceCase('novelty worn down',
      tonight: night(number: 5, suspicions: {0: 1, 1: 0}, savedSeat: 4),
      history: [
        night(number: 1, revealed: TraceType.t7),
        night(number: 2, revealed: TraceType.t7),
        night(number: 3, revealed: TraceType.t7),
        night(number: 4, revealed: TraceType.t3),
      ],
      nightNumber: 5,
      seed: 13),
  // A deliberate tie, driven over several seeds so the tie-break itself is in
  // the contract rather than only the scoring.
  for (final seed in [101, 202, 303, 404, 505])
    TraceCase('tie seed $seed',
        tonight: night(number: 3, suspicions: {0: 1, 1: 0}, savedSeat: 4),
        history: [
          night(number: 1, revealed: TraceType.t5),
          night(number: 2, revealed: TraceType.t6),
        ],
        nightNumber: 3,
        seed: seed),
];

class ConfrontationCase {
  final String name;
  final List<NightRecord> nights;
  final List<DayRecord> days;
  final Set<int> alive;
  final int dayNumber;
  final int seed;
  final MatchSettings settings;

  const ConfrontationCase(
    this.name, {
    this.nights = const [],
    this.days = const [],
    this.alive = allSeven,
    required this.dayNumber,
    required this.seed,
    this.settings = const MatchSettings(whisperEnabled: true),
  });
}

final List<ConfrontationCase> confrontationCases = [
  ConfrontationCase('day one is refused',
      days: [day(number: 1, opening: {0: 1})], dayNumber: 1, seed: 21),
  ConfrontationCase('empty history', dayNumber: 2, seed: 22),
  ConfrontationCase('c1 contradiction',
      days: [day(number: 1, opening: {3: 5}, votes: {3: 2})],
      dayNumber: 2,
      seed: 23),
  ConfrontationCase('c5 twins',
      days: [
        for (var d = 1; d <= 3; d++) day(number: d, votes: {1: 4, 2: 4}),
      ],
      dayNumber: 4,
      seed: 24),
  ConfrontationCase('c6 quietest',
      days: [
        day(number: 1, speaking: {0: 90, 1: 10, 2: 60}),
        day(number: 2, speaking: {0: 90, 1: 5, 2: 60}),
      ],
      alive: {0, 1, 2},
      dayNumber: 3,
      seed: 25),
  ConfrontationCase('c7 the dead speak',
      nights: [night(number: 1, victim: 6, suspicions: {6: 2})],
      alive: {0, 1, 2, 3, 4, 5},
      dayNumber: 2,
      seed: 26),
  ConfrontationCase('c8 whisperer',
      days: [
        day(number: 1, whispers: const [
          WhisperMeta(id: 'w:1:0:4', day: 1, fromSeat: 0, toSeat: 4),
        ]),
        day(number: 2, whispers: const [
          WhisperMeta(id: 'w:2:0:4', day: 2, fromSeat: 0, toSeat: 4),
        ]),
      ],
      dayNumber: 3,
      seed: 27),
  ConfrontationCase('c8 excluded with whispers off',
      days: [
        day(number: 1, whispers: const [
          WhisperMeta(id: 'w:1:0:4', day: 1, fromSeat: 0, toSeat: 4),
        ]),
        day(number: 2, whispers: const [
          WhisperMeta(id: 'w:2:0:4', day: 2, fromSeat: 0, toSeat: 4),
        ]),
      ],
      dayNumber: 3,
      seed: 28,
      settings: const MatchSettings()),
  ConfrontationCase('c11 off by default',
      nights: [night(number: 1, savedSeat: 3)], dayNumber: 2, seed: 29),
  ConfrontationCase('c11 on',
      nights: [night(number: 1, savedSeat: 3)],
      dayNumber: 2,
      seed: 30,
      settings: const MatchSettings(
        whisperEnabled: true,
        survivorConfrontationEnabled: true,
      )),
  ConfrontationCase('back-to-back player is skipped',
      days: [
        day(number: 1, opening: {3: 5}, votes: {3: 2}),
        day(
          number: 2,
          confrontation:
              const Confrontation(type: ConfrontationType.c1, targetSeat: 3),
        ),
      ],
      dayNumber: 3,
      seed: 31),
  ConfrontationCase('fairness cap hands the day on',
      nights: [
        for (var n = 1; n <= 4; n++)
          night(number: n, suspicions: {0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 0}),
      ],
      days: [
        day(number: 1, opening: {3: 5, 4: 6}, votes: {3: 2, 4: 1}),
        day(
          number: 2,
          confrontation:
              const Confrontation(type: ConfrontationType.c1, targetSeat: 3),
        ),
        day(
          number: 3,
          confrontation:
              const Confrontation(type: ConfrontationType.c7, targetSeat: 3),
        ),
        day(
          number: 4,
          confrontation:
              const Confrontation(type: ConfrontationType.c6, targetSeat: 6),
        ),
      ],
      dayNumber: 5,
      seed: 32),
  for (final seed in [601, 602, 603, 604, 605])
    ConfrontationCase('two-way tie seed $seed',
        days: [day(number: 1, opening: {3: 5, 4: 6}, votes: {3: 2, 4: 1})],
        dayNumber: 2,
        seed: seed),
];

// ---------------------------------------------------------------------------

Map<String, dynamic> buildVectors() {
  final traces = <Map<String, dynamic>>[];
  for (final c in traceCases) {
    final result = selectTrace(
      night: c.tonight,
      history: c.history,
      players: roster(c.alive),
      nightNumber: c.nightNumber,
      matchSeed: c.seed,
    );
    traces.add({
      'name': c.name,
      'matchSeed': c.seed,
      'nightNumber': c.nightNumber,
      'alive': c.alive.toList()..sort(),
      'night': encodeNight(c.tonight),
      'history': [for (final n in c.history) encodeNight(n)],
      'expected': encodeTrace(result),
    });
  }

  final confrontations = <Map<String, dynamic>>[];
  for (final c in confrontationCases) {
    final history = GameHistory(
      nights: c.nights,
      days: c.days,
      names: {for (final s in c.alive) s: 'P$s'},
      alive: c.alive,
    );
    final result = selectConfrontation(
      history: history,
      players: roster(c.alive),
      dayNumber: c.dayNumber,
      matchSeed: c.seed,
      settings: c.settings,
    );
    confrontations.add({
      'name': c.name,
      'matchSeed': c.seed,
      'dayNumber': c.dayNumber,
      'alive': c.alive.toList()..sort(),
      'nights': [for (final n in c.nights) encodeNight(n)],
      'days': [for (final d in c.days) encodeDay(d)],
      'settings': {
        'whisperEnabled': c.settings.whisperEnabled,
        'survivorConfrontationEnabled': c.settings.survivorConfrontationEnabled,
      },
      'expected': result == null ? null : encodeConfrontation(result),
    });
  }

  return {
    'version': 1,
    'note': 'Generated by tool/golden_vectors.dart. Both implementations are '
        'held to this file; neither may regenerate it to make itself pass.',
    'traces': traces,
    'confrontations': confrontations,
  };
}

void main() {
  final json = const JsonEncoder.withIndent('  ').convert(buildVectors());
  File(outputPath).writeAsStringSync('$json\n');
  stdout.writeln(
    'wrote $outputPath: ${traceCases.length} trace cases, '
    '${confrontationCases.length} confrontation cases',
  );
}
