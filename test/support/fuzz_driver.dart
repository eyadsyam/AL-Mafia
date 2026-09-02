/// Drives one match to completion by repeatedly picking a random legal move.
///
/// # Why this is worth more than the rest of the suite put together
///
/// `11-edge-cases-and-tests.md` §9 makes the claim and it is right: the
/// non-termination guard *"catches every class of stall: infinite revote loops,
/// phases with no exit, doctor-save cycles, and win conditions that never
/// trigger."* A hand-written test asserts something about the path its author
/// thought of. This walks paths nobody thought of, ten thousand times, and
/// checks the four invariants after every single transition.
///
/// # Everything here is reproducible from one integer
///
/// The roster size, the role split, the settings and every move come from
/// `Random(seed)`. The engine's own randomness comes from the same seed, and
/// its clock is [Clocks.monotonic]. So a failure report needs to carry a seed
/// and nothing else, and re-running that seed reproduces the failure exactly —
/// which is the difference between a fuzz finding you can fix and one you can
/// only stare at.
library test.support.fuzz_driver;

import 'dart:math';

import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/invariants.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';


/// How one fuzzed match ended.
class FuzzOutcome {
  final int seed;
  final int playerCount;
  final int moveCount;

  /// The moves applied, in order. Populated only on failure — recording every
  /// move for 10,000 successful matches is pure garbage collection.
  final List<String> trail;

  /// Null when the match completed cleanly.
  final String? failure;

  /// The match as it stood when the run ended — finished, stalled or broken.
  ///
  /// Exposed so a caller can ask what the run actually *did* without replaying
  /// the seed through a second copy of the driver's draw order. A second copy
  /// drifts, and a drifted replay reports coverage for games that were never
  /// played.
  final Match? finished;

  const FuzzOutcome({
    required this.seed,
    required this.playerCount,
    required this.moveCount,
    this.trail = const [],
    this.failure,
    this.finished,
  });

  bool get ok => failure == null;

  @override
  String toString() => ok
      ? 'seed $seed: $playerCount players, $moveCount moves, completed'
      : 'seed $seed: $playerCount players, FAILED after $moveCount moves\n'
          '  $failure\n'
          '${trail.map((m) => '    $m').join('\n')}';
}

/// The ceiling on transitions before a match is declared stalled.
///
/// Doc 11 §9 fixes it at 500. A clean 15-player match runs to roughly 250
/// transitions in the worst case (every player acting every night and voting
/// every day, over the handful of days it takes to reach parity), so 500 leaves
/// headroom without letting a genuine loop run long enough to look like slow
/// progress.
const int kStallGuard = 500;

/// Plays one match end to end.
///
/// [recordTrail] keeps every move so a failure can be replayed by hand. The
/// harness turns it on only for the retry of a seed that already failed.
/// [onState] is called with every state the match passes through, before each
/// move is chosen. Used by the coverage suite to record which phases the
/// harness actually enters.
FuzzOutcome runFuzzedMatch(
  int seed, {
  bool recordTrail = false,
  void Function(Match state)? onState,
}) {
  final rng = Random(seed);
  final playerCount = 5 + rng.nextInt(11); // 5..15
  final engine = MatchEngine(clock: Clocks.monotonic());
  final trail = <String>[];

  try {
    engine.start(
      names: _names(playerCount),
      roleCounts: _randomValidConfig(playerCount, rng),
      settings: _randomSettings(rng),
      seed: seed,
    );
  } catch (e) {
    return FuzzOutcome(
      seed: seed,
      playerCount: playerCount,
      moveCount: 0,
      failure: 'start threw: $e',
    );
  }

  var moves = 0;
  while (!isTerminal(engine.match)) {
    onState?.call(engine.match);
    final options = legalMoves(engine.match);

    if (options.isEmpty) {
      return FuzzOutcome(
        seed: seed,
        playerCount: playerCount,
        moveCount: moves,
        trail: trail,
        finished: engine.match,
        failure: 'dead end: phase ${engine.match.phase.name}, '
            'day ${engine.match.dayNumber}, '
            'actor ${engine.match.currentActorSeat}, '
            '${_aliveCount(engine)} alive — no legal move and not terminal',
      );
    }

    final move = options[rng.nextInt(options.length)];
    if (recordTrail) trail.add('${engine.match.phase.name}: $move');

    try {
      move.apply(engine);
    } catch (e) {
      return FuzzOutcome(
        seed: seed,
        playerCount: playerCount,
        moveCount: moves,
        trail: trail,
        failure: 'legal move was rejected by the engine — legalMoves and the '
            'engine disagree about the rules.\n  move: $move\n  threw: $e',
      );
    }

    moves++;

    // Doc 11 §0: after *every* state mutation, not once per match. Checked
    // directly rather than through the `assert` the engine uses, because the
    // harness wants the list of what broke.
    final violations = checkMatchInvariants(engine.match);
    if (violations.isNotEmpty) {
      return FuzzOutcome(
        seed: seed,
        playerCount: playerCount,
        moveCount: moves,
        trail: trail,
        failure: 'invariant violation after $move:\n'
            '${violations.map((v) => '      $v').join('\n')}',
      );
    }

    if (moves > kStallGuard) {
      return FuzzOutcome(
        seed: seed,
        playerCount: playerCount,
        moveCount: moves,
        trail: trail,
        finished: engine.match,
        failure: 'did not terminate within $kStallGuard moves — '
            'stuck in ${engine.match.phase.name} on day '
            '${engine.match.dayNumber} with ${_aliveCount(engine)} alive',
      );
    }
  }

  onState?.call(engine.match);

  if (engine.match.outcome == null) {
    return FuzzOutcome(
      seed: seed,
      playerCount: playerCount,
      moveCount: moves,
      trail: trail,
      finished: engine.match,
      failure: 'reached terminal phase ${engine.match.phase.name} with no '
          'recorded outcome',
    );
  }

  return FuzzOutcome(
    seed: seed,
    playerCount: playerCount,
    moveCount: moves,
    trail: trail,
    finished: engine.match,
  );
}

int _aliveCount(MatchEngine engine) =>
    engine.match.players.where((p) => p.status == PlayerStatus.alive).length;

/// Distinct, stable names. Distinct because S7 (*two players named "أحمد"*) is
/// a setup-screen concern, not an engine one — letting the fuzz generate
/// collisions here would test the wrong layer.
List<String> _names(int n) => List.generate(n, (i) => 'P${i + 1}');

/// A role split the balance rules accept.
///
/// The constraints are the engine's own: at least one mafia, mafia strictly
/// below half, and citizens as the remainder rather than an entered number
/// (S6). Doctor and detective are each present or absent, which is what makes
/// the harness exercise N12 and N13 — the last doctor or detective dying and
/// the phase simply not existing thereafter.
Map<Role, int> _randomValidConfig(int playerCount, Random rng) {
  final maxMafia = (playerCount - 1) ~/ 2;
  final mafia = 1 + rng.nextInt(maxMafia);

  var remaining = playerCount - mafia;
  final doctor = remaining > 1 && rng.nextBool() ? 1 : 0;
  remaining -= doctor;
  final detective = remaining > 1 && rng.nextBool() ? 1 : 0;
  remaining -= detective;

  return {
    Role.mafia: mafia,
    if (doctor > 0) Role.doctor: doctor,
    if (detective > 0) Role.detective: detective,
    Role.citizen: remaining,
  };
}

/// Settings that change the *rules*, randomised. The rest — narration, audio,
/// hold duration — cannot affect a transition, so varying them would only slow
/// the harness down.
MatchSettings _randomSettings(Random rng) => MatchSettings(
      dayTieRule: rng.nextBool() ? DayTieRule.revote : DayTieRule.noElimination,
      abstainAllowed: rng.nextBool(),
      discussionMode:
          rng.nextBool() ? DiscussionMode.structured : DiscussionMode.free,
    );
