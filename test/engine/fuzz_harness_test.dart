import 'package:test/test.dart';

import '../support/fuzz_driver.dart';

/// The fuzz harness of `11-edge-cases-and-tests.md` §9.
///
/// Ten thousand random matches, the four invariants checked after every single
/// transition, and a non-termination guard. Doc 11 calls the guard *"the single
/// most valuable assertion in the codebase"*, and the reasoning is that a stall
/// is the one bug class that a table cannot work around: a crash gets restarted
/// and a wrong tally gets argued about, but a screen with no forward button
/// ends the evening.
///
/// It runs in seconds, so it belongs in the default suite rather than behind a
/// tag. A fuzz harness that only runs nightly finds the same bugs a day later.
void main() {
  group('fuzz harness', () {
    test('10,000 random matches terminate with no invariant violation', () {
      const runs = 10000;
      final failures = <FuzzOutcome>[];
      var totalMoves = 0;
      var longest = 0;

      for (var seed = 0; seed < runs; seed++) {
        final outcome = runFuzzedMatch(seed);
        totalMoves += outcome.moveCount;
        if (outcome.moveCount > longest) longest = outcome.moveCount;

        if (!outcome.ok) {
          // Replay the failing seed with the move trail on, so the report says
          // how the engine got there and not merely where it ended up.
          failures.add(runFuzzedMatch(seed, recordTrail: true));
          // Five is enough to see whether this is one bug or several; the rest
          // would be pages of the same trace.
          if (failures.length >= 5) break;
        }
      }

      expect(
        failures,
        isEmpty,
        reason:
            'the engine can reach a bad state:\n\n'
            '${failures.join('\n\n')}',
      );

      // Not an assertion about correctness — a guard against the harness
      // quietly degrading into 10,000 matches that end on move three because a
      // future refactor made `legalMoves` return the terminal move too early.
      final mean = totalMoves / runs;
      expect(
        mean,
        greaterThan(20),
        reason:
            'matches are averaging only $mean moves — the harness is '
            'probably no longer exercising a whole game',
      );
      expect(longest, lessThanOrEqualTo(kStallGuard));
    });

    test('a seed replays identically', () {
      // The property the whole harness rests on: a reported failure has to be
      // reproducible from its seed alone, and offline/online parity (doc 10
      // §5.1) is the same claim applied across two runtimes.
      final first = runFuzzedMatch(4242, recordTrail: true);
      final second = runFuzzedMatch(4242, recordTrail: true);

      expect(second.playerCount, first.playerCount);
      expect(second.moveCount, first.moveCount);
      expect(second.trail, first.trail);
    });

    test('every fuzzed match reaches a definite winner', () {
      // Doc 11 §9: *"Every match must reach a definite conclusion."* Checked
      // over a smaller sample because it re-runs matches the big test already
      // walked; its job is to state the property explicitly, not to add
      // coverage.
      for (var seed = 0; seed < 500; seed++) {
        final outcome = runFuzzedMatch(seed);
        expect(outcome.ok, isTrue, reason: outcome.toString());
      }
    });
  });
}
