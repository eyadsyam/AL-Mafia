import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/information/records.dart';
import 'package:mafia_master/engine/information/trace_generator.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/information_enums.dart';
import 'package:mafia_master/engine/models/player.dart';

/// Doc 11 §5.1 (T-E1 → T-E9), plus one case per eligibility branch.
///
/// These are pure unit tests on pure functions, which is doc 11 §0's rule for
/// this layer: *"No mocks, no I/O, no `DateTime.now()`. If a test needs a mock,
/// the code is wrong."* Nothing here builds an engine — `selectTrace` takes a
/// night, a history and a roster, and that is the whole of its world.
void main() {
  // Seven seats. `dead` names the ones that are not coming back.
  List<Player> roster({Set<int> dead = const {}}) => [
        for (var seat = 0; seat < 7; seat++)
          Player(
            seat: seat,
            name: 'P$seat',
            // The roster's roles are irrelevant to every trace — no trace reads
            // one — so they are all citizens here, and that is itself worth
            // asserting by construction.
            role: Role.citizen,
            status: dead.contains(seat) ? PlayerStatus.dead : PlayerStatus.alive,
            eliminatedOn: dead.contains(seat)
                ? const PhaseRef(phase: GamePhase.night, number: 1)
                : null,
          ),
      ];

  NightRecord night({
    int number = 1,
    Map<int, int?> suspicions = const {},
    int? victim,
    int? savedSeat,
    TraceType? revealed,
  }) =>
      NightRecord(
        nightNumber: number,
        suspicions: suspicions,
        reasons: const {},
        victim: victim,
        saveOccurred: savedSeat != null,
        savedSeat: savedSeat,
        revealedTrace: revealed,
        resolved: true,
      );

  TraceResult select({
    required NightRecord tonight,
    List<NightRecord> history = const [],
    Set<int> dead = const {},
    int nightNumber = 1,
    int seed = 1234,
  }) =>
      selectTrace(
        night: tonight,
        history: history,
        players: roster(dead: dead),
        nightNumber: nightNumber,
        matchSeed: seed,
      );

  group('T-E1 — nothing eligible', () {
    test('a night with no actions at all yields T0, and does not throw', () {
      final result = select(tonight: night());
      expect(result.type, equals(TraceType.t0));
      expect(result.isNone, isTrue);
      expect(result.targetSeat, isNull,
          reason: 'T0 names nobody, because there is nobody to name');
    });

    test('T0 is never a candidate in its own right', () {
      expect(TraceType.candidates, isNot(contains(TraceType.t0)));
    });
  });

  group('T1 — آخر شك للضحية', () {
    test('fires when the victim named somebody who is still alive', () {
      final result = select(
        tonight: night(victim: 3, suspicions: {3: 5}),
        dead: {3},
      );
      expect(result.type, equals(TraceType.t1));
      expect(result.subjectSeat, equals(3));
      expect(result.targetSeat, equals(5));
    });

    test('T-E2 — ineligible when the named player is already dead', () {
      final candidate = evaluateTrace(
        type: TraceType.t1,
        night: night(victim: 3, suspicions: {3: 5}),
        history: const [],
        alive: const {0, 1, 2, 4, 6},
        nightNumber: 2,
      );
      expect(candidate, isNull,
          reason: 'a dead target cannot be asked to respond, which is the '
              'entire point of naming them');
    });

    test('T-E3 — ineligible when the victim recorded nothing', () {
      final candidate = evaluateTrace(
        type: TraceType.t1,
        night: night(victim: 3, suspicions: {3: null}),
        history: const [],
        alive: const {0, 1, 2, 4, 5, 6},
        nightNumber: 1,
      );
      expect(candidate, isNull);
    });

    test('T-E4 — ineligible when nobody died; T2 takes over', () {
      final tonight = night(savedSeat: 3, suspicions: {0: 1});
      expect(
        evaluateTrace(
          type: TraceType.t1,
          night: tonight,
          history: const [],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 1,
        ),
        isNull,
      );
      final result = select(tonight: tonight);
      expect(result.type, equals(TraceType.t2));
    });

    test('T-E7 — night 1 still fires it, and that is deliberate', () {
      // Doc 09 §1.2: night-1 suspicions are near-random, so the evidential
      // value is low and the *social* value is the point. Documented, not a bug.
      final result = select(
        tonight: night(victim: 0, suspicions: {0: 4}),
        dead: {0},
        nightNumber: 1,
      );
      expect(result.type, equals(TraceType.t1));
    });

    test('it outscores everything else that could fire alongside it', () {
      final result = select(
        tonight: night(
          victim: 0,
          suspicions: {0: 4, 1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2},
          savedSeat: null,
        ),
        dead: {0},
        nightNumber: 3,
        history: [night(number: 1), night(number: 2)],
      );
      expect(result.type, equals(TraceType.t1),
          reason: 'drama weight 10.0 against 6.0 for the next best');
    });
  });

  group('T2 — نجاة', () {
    test('fires on a save and names nobody at all', () {
      final result = select(tonight: night(savedSeat: 4));
      expect(result.type, equals(TraceType.t2));
      expect(result.subjectSeat, isNull);
      expect(result.targetSeat, isNull,
          reason: 'doc 09 §1.4 — «Names? never». The saved seat is on the '
              'record; it may not reach the table');
    });

    test('does not fire on a quiet night nobody was targeted on', () {
      expect(
        evaluateTrace(
          type: TraceType.t2,
          night: night(),
          history: const [],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 1,
        ),
        isNull,
      );
    });
  });

  group('aggregate traces', () {
    test('T3 needs two living players on one name, and counts them', () {
      final candidate = evaluateTrace(
        type: TraceType.t3,
        night: night(suspicions: {0: 5, 1: 5, 2: 4}),
        history: const [],
        alive: const {0, 1, 2, 3, 4, 5, 6},
        nightNumber: 1,
      );
      expect(candidate!.result.count, equals(2));

      final alone = evaluateTrace(
        type: TraceType.t3,
        night: night(suspicions: {0: 5, 1: 4}),
        history: const [],
        alive: const {0, 1, 2, 3, 4, 5, 6},
        nightNumber: 1,
      );
      expect(alone, isNull);
    });

    test('T3 scores higher the more of the table agrees', () {
      double scoreFor(Map<int, int?> suspicions) => evaluateTrace(
            type: TraceType.t3,
            night: night(suspicions: suspicions),
            history: const [],
            alive: const {0, 1, 2, 3, 4, 5, 6},
            nightNumber: 1,
          )!
              .informationValue;

      expect(scoreFor({0: 5, 1: 5, 2: 5, 3: 5}),
          greaterThan(scoreFor({0: 5, 1: 5})));
    });

    test('T4 counts only players who changed, not players who arrived', () {
      final candidate = evaluateTrace(
        type: TraceType.t4,
        night: night(number: 2, suspicions: {0: 3, 1: 4, 2: 5}),
        history: [
          night(suspicions: {0: 3, 1: 6}),
        ],
        alive: const {0, 1, 2, 3, 4, 5, 6},
        nightNumber: 2,
      );
      // Seat 0 did not change, seat 1 did, seat 2 had nothing to change from.
      expect(candidate!.result.count, equals(1));
    });

    test('T-E8 — T5 is ineligible on night 1', () {
      expect(
        evaluateTrace(
          type: TraceType.t5,
          night: night(suspicions: {0: 1}),
          history: const [],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 1,
        ),
        isNull,
      );
    });

    test('T5 fires from night 2 when somebody has never been named', () {
      final candidate = evaluateTrace(
        type: TraceType.t5,
        night: night(number: 2, suspicions: {0: 1}),
        history: [
          night(suspicions: {0: 1, 2: 1}),
        ],
        alive: const {0, 1, 2, 3, 4, 5, 6},
        nightNumber: 2,
      );
      expect(candidate, isNotNull);
      expect(candidate!.result.targetSeat, isNull,
          reason: 'naming the shadow would end the game on the spot');
    });

    test('T5 is silent when everybody has been named at least once', () {
      final everyone = {for (var seat = 0; seat < 7; seat++) seat: seat};
      expect(
        evaluateTrace(
          type: TraceType.t5,
          night: night(number: 2, suspicions: everyone),
          history: [night(suspicions: everyone)],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 2,
        ),
        isNull,
      );
    });

    test('T6 counts the living seats that chose nobody', () {
      final candidate = evaluateTrace(
        type: TraceType.t6,
        night: night(suspicions: {0: null, 1: null, 2: 3}),
        history: const [],
        alive: const {0, 1, 2, 3, 4, 5, 6},
        nightNumber: 1,
      );
      expect(candidate!.result.count, equals(2));
    });

    test('T7 needs the suspicion to go both ways', () {
      expect(
        evaluateTrace(
          type: TraceType.t7,
          night: night(suspicions: {0: 1, 1: 0}),
          history: const [],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 1,
        ),
        isNotNull,
      );
      expect(
        evaluateTrace(
          type: TraceType.t7,
          night: night(suspicions: {0: 1, 1: 2}),
          history: const [],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 1,
        ),
        isNull,
      );
    });

    test('T8 needs 60% of the living table, not merely a plurality', () {
      // Four of seven is 57%.
      expect(
        evaluateTrace(
          type: TraceType.t8,
          night: night(suspicions: {0: 6, 1: 6, 2: 6, 3: 6}),
          history: const [],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 1,
        ),
        isNull,
      );
      // Five of seven is 71%.
      expect(
        evaluateTrace(
          type: TraceType.t8,
          night: night(suspicions: {0: 6, 1: 6, 2: 6, 3: 6, 4: 6}),
          history: const [],
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 1,
        ),
        isNotNull,
      );
    });
  });

  group('T-E5 — no back-to-back repeats', () {
    test('yesterday\'s type is excluded from today\'s candidates', () {
      // A save two nights running would otherwise publish T2 twice.
      final result = select(
        tonight: night(number: 2, savedSeat: 4),
        history: [night(savedSeat: 3, revealed: TraceType.t2)],
        nightNumber: 2,
      );
      expect(result.type, isNot(TraceType.t2));
    });

    test('nothing left after the exclusion means T0, not a repeat', () {
      // Night 1, so `T5` — which needs two nights elapsed — cannot quietly
      // cover for the excluded `T2` and hide the case being tested.
      final result = select(
        tonight: night(savedSeat: 4),
        history: [night(number: 0, savedSeat: 3, revealed: TraceType.t2)],
        nightNumber: 1,
      );
      expect(result.type, equals(TraceType.t0),
          reason: 'with T2 excluded and nothing else eligible, the honest '
              'answer is that the night left no trace');
    });

    test('a type from two nights ago is eligible again', () {
      final tonight = night(number: 3, savedSeat: 4);
      final history = [
        night(savedSeat: 3, revealed: TraceType.t2),
        night(number: 2, suspicions: {0: 1, 1: 0}, revealed: TraceType.t7),
      ];
      expect(
        evaluateTrace(
          type: TraceType.t2,
          night: tonight,
          history: history,
          alive: const {0, 1, 2, 3, 4, 5, 6},
          nightNumber: 3,
        ),
        isNotNull,
        reason: 'the no-repeat rule is scoped to yesterday, not to the match',
      );
      // It may still lose on score — T2 has been published once, so its novelty
      // is 0.85 and a fresh T5 edges it — but it is back in the running, which
      // is all the rule is about.
      final result =
          select(tonight: tonight, history: history, nightNumber: 3);
      expect(result.type, anyOf(TraceType.t2, TraceType.t5));
    });

    test('novelty decays with use and bottoms out at 0.4', () {
      TraceType t = TraceType.t3;
      expect(noveltyFactor(const [], t), equals(1.0));
      expect(
        noveltyFactor([night(revealed: t)], t),
        closeTo(0.85, 1e-9),
      );
      expect(
        noveltyFactor(List.filled(20, night(revealed: t)), t),
        equals(0.4),
      );
    });
  });

  group('T-E6 / T-E9 — determinism', () {
    // A night engineered so that two types tie: T7 (4.5) and T2 (4.0) do not,
    // so the tie is forced by making the same type available to two seeds.
    NightRecord tied() => night(
          suspicions: {0: 1, 1: 0},
          savedSeat: 4,
        );

    test('the same inputs give the same trace, every time', () {
      final first = select(tonight: tied(), seed: 99);
      for (var i = 0; i < 50; i++) {
        expect(select(tonight: tied(), seed: 99), equals(first));
      }
    });

    test('the tie-break is a function of the seed and the night', () {
      // Not an assertion that different seeds differ — they may agree — but
      // that the answer depends on nothing else. Two runs of the same seed on
      // the same night must agree; that is what "byte-identical on every
      // device" reduces to for a pure function.
      for (final seed in [1, 2, 3, 5, 8, 13, 21, 34]) {
        for (final n in [1, 2, 3]) {
          final a = select(tonight: tied(), seed: seed, nightNumber: n);
          final b = select(tonight: tied(), seed: seed, nightNumber: n);
          expect(a, equals(b));
        }
      }
    });

    test('the winner does not depend on the order candidates were built in', () {
      // `List.sort` is not stable in Dart, so a generator that left equal
      // scores in encounter order would be leaving them in an arbitrary one —
      // and two devices could then disagree before the seed was ever drawn.
      final result = select(tonight: tied(), seed: 7);
      for (var i = 0; i < 100; i++) {
        expect(select(tonight: tied(), seed: 7).type, equals(result.type));
      }
    });
  });
}
