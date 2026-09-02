import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/information/confrontation_generator.dart';
import 'package:mafia_master/engine/information/game_history.dart';
import 'package:mafia_master/engine/information/records.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/information_enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';

/// Doc 11 §5.2 (C-E1 → C-E8), plus one case per shipped finder.
///
/// Pure unit tests on a hand-built [GameHistory]: the generator's whole world
/// is a history, a roster and a day number, so there is nothing to mock and
/// nothing to drive.
void main() {
  const settings = MatchSettings(whisperEnabled: true);

  List<Player> roster({Set<int> dead = const {}, int count = 7}) => [
        for (var seat = 0; seat < count; seat++)
          Player(
            seat: seat,
            name: 'P$seat',
            role: Role.citizen,
            status: dead.contains(seat) ? PlayerStatus.dead : PlayerStatus.alive,
            eliminatedOn: dead.contains(seat)
                ? const PhaseRef(phase: GamePhase.voting, number: 1)
                : null,
          ),
      ];

  NightRecord night({
    required int number,
    Map<int, int?> suspicions = const {},
    int? victim,
    int? savedSeat,
  }) =>
      NightRecord(
        nightNumber: number,
        suspicions: suspicions,
        reasons: const {},
        victim: victim,
        saveOccurred: savedSeat != null,
        savedSeat: savedSeat,
        resolved: true,
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

  GameHistory history({
    List<NightRecord> nights = const [],
    List<DayRecord> days = const [],
    Set<int> dead = const {},
    int count = 7,
  }) =>
      GameHistory(
        nights: nights,
        days: days,
        names: {for (var s = 0; s < count; s++) s: 'P$s'},
        alive: {
          for (var s = 0; s < count; s++)
            if (!dead.contains(s)) s,
        },
      );

  Confrontation? select(
    GameHistory h, {
    required int dayNumber,
    Set<int> dead = const {},
    MatchSettings s = settings,
    int seed = 4242,
    int count = 7,
  }) =>
      selectConfrontation(
        history: h,
        players: roster(dead: dead, count: count),
        dayNumber: dayNumber,
        matchSeed: seed,
        settings: s,
      );

  group('C-E1 — day 1 has no confrontation', () {
    test('the generator refuses day 1 outright', () {
      final h = history(days: [day(number: 1, opening: {0: 1, 1: 0})]);
      expect(select(h, dayNumber: 1), isNull,
          reason: 'day 1 has no behavioural history; the «اسم واحد» opener '
              'runs instead (doc 09 §2.2)');
    });
  });

  group('C-E2 — nothing qualifies', () {
    test('an empty history produces nothing, silently', () {
      expect(select(history(), dayNumber: 2), isNull);
    });

    test('a day with votes but no contradiction produces nothing', () {
      final h = history(days: [
        day(number: 1, opening: {0: 1}, votes: {0: 1, 1: 2}),
      ]);
      // Seat 0 named 1 and voted for 1 — consistent, so C1 has nothing to say.
      expect(select(h, dayNumber: 2)?.type, isNot(ConfrontationType.c1));
    });
  });

  group('C1 — تناقض التصويت', () {
    test('fires when the opener and the ballot disagree, naming both', () {
      final h = history(days: [
        day(number: 1, opening: {3: 5}, votes: {3: 2}),
      ]);
      final result = select(h, dayNumber: 2);
      expect(result!.type, equals(ConfrontationType.c1));
      expect(result.targetSeat, equals(3));
      expect(result.evidenceSeat, equals(5), reason: 'who they accused');
      expect(result.evidenceSeat2, equals(2), reason: 'who they voted for');
      expect(result.evidenceDay, equals(1));
    });

    test('an abstention is not a contradiction', () {
      final h = history(days: [
        day(number: 1, opening: {3: 5}, votes: {3: null}),
      ]);
      expect(
        findConfrontations(
          type: ConfrontationType.c1,
          history: h,
          alive: const {0, 1, 2, 3, 4, 5, 6},
          dayNumber: 2,
        ),
        isEmpty,
      );
    });

    test('at most one candidate per player — the freshest', () {
      final h = history(days: [
        day(number: 1, opening: {3: 5}, votes: {3: 2}),
        day(number: 2, opening: {}, votes: {3: 1}),
      ]);
      final found = findConfrontations(
        type: ConfrontationType.c1,
        history: h,
        alive: const {0, 1, 2, 3, 4, 5, 6},
        dayNumber: 3,
      );
      expect(found, hasLength(1));
      expect(found.single.evidenceDay, equals(2));
    });
  });

  group('C5 — التوأم', () {
    test('needs three matching ballots and names the pair both ways', () {
      final h = history(days: [
        for (var d = 1; d <= 3; d++) day(number: d, votes: {1: 4, 2: 4}),
      ]);
      final found = findConfrontations(
        type: ConfrontationType.c5,
        history: h,
        alive: const {0, 1, 2, 3, 4, 5, 6},
        dayNumber: 4,
      );
      expect(found, hasLength(2));
      expect(found.map((c) => c.target).toSet(), equals({1, 2}));
      expect(found.first.confrontation.count, equals(3));
    });

    test('two matching ballots are a coincidence, not evidence', () {
      final h = history(days: [
        for (var d = 1; d <= 2; d++) day(number: d, votes: {1: 4, 2: 4}),
      ]);
      expect(
        findConfrontations(
          type: ConfrontationType.c5,
          history: h,
          alive: const {0, 1, 2, 3, 4, 5, 6},
          dayNumber: 3,
        ),
        isEmpty,
      );
    });

    test('two abstentions are not agreement', () {
      final h = history(days: [
        for (var d = 1; d <= 3; d++)
          day(number: d, votes: {1: null, 2: null}),
      ]);
      expect(
        findConfrontations(
          type: ConfrontationType.c5,
          history: h,
          alive: const {0, 1, 2, 3, 4, 5, 6},
          dayNumber: 4,
        ),
        isEmpty,
      );
    });
  });

  group('C6 — الصامت', () {
    test('needs a single quietest player', () {
      final h = history(days: [
        day(number: 1, speaking: {0: 90, 1: 10, 2: 60}),
        day(number: 2, speaking: {0: 90, 1: 5, 2: 60}),
      ]);
      // Seats 3–6 have no record at all, so they are all on zero and tie.
      expect(
        findConfrontations(
          type: ConfrontationType.c6,
          history: h,
          alive: const {0, 1, 2, 3, 4, 5, 6},
          dayNumber: 3,
        ),
        isEmpty,
        reason: '"you have talked the least" is not true of a four-way tie',
      );

      final found = findConfrontations(
        type: ConfrontationType.c6,
        history: h,
        alive: const {0, 1, 2},
        dayNumber: 3,
      );
      expect(found.single.target, equals(1));
    });

    test('needs two days elapsed', () {
      final h = history(days: [day(number: 1, speaking: {0: 90, 1: 10})]);
      expect(
        findConfrontations(
          type: ConfrontationType.c6,
          history: h,
          alive: const {0, 1},
          dayNumber: 2,
        ),
        isEmpty,
      );
    });
  });

  group('C7 — الميت يتكلم', () {
    test('C-E7 — the evidence names a dead player, and reads correctly', () {
      final h = history(
        nights: [night(number: 1, victim: 6, suspicions: {6: 2})],
        dead: {6},
      );
      final found = findConfrontations(
        type: ConfrontationType.c7,
        history: h,
        alive: const {0, 1, 2, 3, 4, 5},
        dayNumber: 2,
      );
      expect(found.single.target, equals(2));
      expect(found.single.confrontation.evidenceSeat, equals(6),
          reason: 'the subject of the sentence is the dead player — that is '
              'the whole conceit of «الميت يتكلم»');
    });

    test('silent when the victim named somebody who has since died', () {
      final h = history(
        nights: [night(number: 1, victim: 6, suspicions: {6: 5})],
        dead: {5, 6},
      );
      expect(
        findConfrontations(
          type: ConfrontationType.c7,
          history: h,
          alive: const {0, 1, 2, 3, 4},
          dayNumber: 2,
        ),
        isEmpty,
      );
    });
  });

  group('C8 — الهمّاس', () {
    test('needs the same recipient on consecutive days', () {
      final h = history(days: [
        day(number: 1, whispers: [
          const WhisperMeta(id: 'w:1:0:4', day: 1, fromSeat: 0, toSeat: 4),
        ]),
        day(number: 2, whispers: [
          const WhisperMeta(id: 'w:2:0:4', day: 2, fromSeat: 0, toSeat: 4),
        ]),
      ]);
      final found = findConfrontations(
        type: ConfrontationType.c8,
        history: h,
        alive: const {0, 1, 2, 3, 4, 5, 6},
        dayNumber: 3,
      );
      expect(found.single.target, equals(0));
      expect(found.single.confrontation.evidenceSeat, equals(4));
    });

    test('C-E8 — excluded entirely when whispers are off', () {
      expect(
        ConfrontationCatalogue.enabledFor(const MatchSettings()),
        isNot(contains(ConfrontationType.c8)),
      );
      expect(
        ConfrontationCatalogue.enabledFor(
            const MatchSettings(whisperEnabled: true)),
        contains(ConfrontationType.c8),
      );
    });
  });

  group('C11 — الناجي is gated off', () {
    test('absent from the catalogue unless the host switched it on', () {
      expect(
        ConfrontationCatalogue.enabledFor(settings),
        isNot(contains(ConfrontationType.c11)),
      );
      expect(
        ConfrontationCatalogue.enabledFor(
          const MatchSettings(survivorConfrontationEnabled: true),
        ),
        contains(ConfrontationType.c11),
      );
    });

    test('with it on, it names the saved player and not the doctor', () {
      final h = history(nights: [night(number: 1, savedSeat: 3)]);
      final found = findConfrontations(
        type: ConfrontationType.c11,
        history: h,
        alive: const {0, 1, 2, 3, 4, 5, 6},
        dayNumber: 2,
      );
      expect(found.single.target, equals(3));
    });
  });

  group('the three types held back for leaking a role', () {
    test('C3, C9 and C10 are never generated', () {
      for (final type in const [
        ConfrontationType.c3,
        ConfrontationType.c9,
        ConfrontationType.c10,
      ]) {
        expect(ConfrontationCatalogue.shipped, isNot(contains(type)),
            reason: '${type.name} would announce that a living, named player '
                'recorded a night suspicion — which is to say, that they are '
                'a Citizen (doc 05)');
        expect(type.namesANightSuspicion, isTrue);
      }
    });

    test('C2 is absent because the game has no defence to record', () {
      expect(ConfrontationCatalogue.shipped,
          isNot(contains(ConfrontationType.c2)));
      expect(
        findConfrontations(
          type: ConfrontationType.c2,
          history: history(days: [day(number: 1, votes: {0: 1})]),
          alive: const {0, 1, 2},
          dayNumber: 2,
        ),
        isEmpty,
      );
    });

    test('no shipped type reads a living player\'s own suspicion record', () {
      // Four nights of suspicions and nothing public at all. Every seat has
      // been named by somebody, so `C4` — which asserts a negative about the
      // confronted player and nothing about anyone's notes — has nothing to
      // say either. Nothing else can fire, because nothing public happened.
      final everyoneNamed = {for (var s = 0; s < 7; s++) s: (s + 1) % 7};
      final h = history(
        nights: [
          for (var n = 1; n <= 4; n++)
            night(number: n, suspicions: everyoneNamed),
        ],
        days: [for (var d = 1; d <= 4; d++) day(number: d)],
      );
      expect(select(h, dayNumber: 5), isNull,
          reason: 'a match whose only record is private must produce no '
              'confrontation at all');
    });
  });

  group('C-E3 / C-E6 — the hard filters and the fairness cap', () {
    Confrontation confrontationOf(int seat) =>
        Confrontation(type: ConfrontationType.c1, targetSeat: seat);

    test('C-E3 — the player confronted yesterday is skipped', () {
      final h = history(days: [
        day(number: 1, opening: {3: 5}, votes: {3: 2}),
        day(number: 2, confrontation: confrontationOf(3)),
      ]);
      // Seat 3 is the only contradiction on the board, and it was them
      // yesterday, so today has nobody to ask.
      expect(select(h, dayNumber: 3), isNull);
    });

    test('the same type cannot run two days running', () {
      final h = history(days: [
        day(number: 1, opening: {3: 5, 4: 6}, votes: {3: 2, 4: 1}),
        day(number: 2, confrontation: confrontationOf(3)),
      ]);
      final result = select(h, dayNumber: 3);
      // Seat 4 also contradicted themselves, but C1 ran yesterday.
      expect(result, isNull);
    });

    // Everybody has been named by somebody, so `C4` cannot quietly supply an
    // alternative candidate and hide what the cap is doing.
    final allNamed = [
      for (var n = 1; n <= 4; n++)
        NightRecord(
          nightNumber: n,
          suspicions: {for (var s = 0; s < 7; s++) s: (s + 1) % 7},
          reasons: const {},
          resolved: true,
        ),
    ];

    Confrontation typed(ConfrontationType type, int seat) =>
        Confrontation(type: type, targetSeat: seat);

    test('C-E6 — a third confrontation is blocked while anyone else fits', () {
      final h = history(nights: allNamed, days: [
        day(number: 1, opening: {3: 5, 4: 6}, votes: {3: 2, 4: 1}),
        day(number: 2, confrontation: typed(ConfrontationType.c1, 3)),
        day(number: 3, confrontation: typed(ConfrontationType.c7, 3)),
        day(number: 4, confrontation: typed(ConfrontationType.c6, 6)),
      ]);
      final result = select(h, dayNumber: 5);
      expect(result, isNotNull);
      expect(result!.targetSeat, equals(4),
          reason: 'seat 3 has had two; the cap hands the day to somebody else');
    });

    test('the cap yields when there is literally nobody else', () {
      final h = history(nights: allNamed, days: [
        day(number: 1, opening: {3: 5}, votes: {3: 2}),
        day(number: 2, confrontation: typed(ConfrontationType.c1, 3)),
        day(number: 3, confrontation: typed(ConfrontationType.c7, 3)),
        day(number: 4, confrontation: typed(ConfrontationType.c6, 6)),
      ]);
      final result = select(h, dayNumber: 5);
      expect(result?.targetSeat, equals(3),
          reason: 'doc 09 §2.4: "unless there are no other candidates"');
    });

    test('fairness scales the way the spec describes', () {
      final none = history();
      expect(fairnessFactor(none, 3), equals(1.0));
      final once =
          history(days: [day(number: 1, confrontation: confrontationOf(3))]);
      expect(fairnessFactor(once, 3), equals(0.5));
    });

    test('the dead are never confronted', () {
      final h = history(
        days: [day(number: 1, opening: {3: 5}, votes: {3: 2})],
        dead: {3},
      );
      expect(select(h, dayNumber: 2, dead: {3}), isNull);
    });
  });

  group('recency', () {
    test('today and yesterday score alike; older evidence decays to a floor',
        () {
      expect(recencyBoost(5, 5), equals(1.0));
      expect(recencyBoost(4, 5), equals(1.0));
      expect(recencyBoost(3, 5), closeTo(0.85, 1e-9));
      expect(recencyBoost(1, 20), equals(0.5));
      expect(recencyBoost(null, 5), equals(1.0));
    });
  });

  group('determinism', () {
    test('the same history and seed always give the same confrontation', () {
      final h = history(days: [
        day(number: 1, opening: {3: 5, 4: 6}, votes: {3: 2, 4: 1}),
      ]);
      final first = select(h, dayNumber: 2);
      for (var i = 0; i < 50; i++) {
        expect(select(h, dayNumber: 2), equals(first));
      }
    });
  });
}
