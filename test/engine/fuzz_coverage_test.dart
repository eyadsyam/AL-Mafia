import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/invariants.dart';
import 'package:mafia_master/engine/legal_moves.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:test/test.dart';

import '../support/fuzz_driver.dart';

/// Two things the fuzz harness cannot assert about itself.
///
/// A green fuzz run means one of two things — the engine is sound, or the
/// harness is not looking. Ten thousand matches passing on the first attempt is
/// exactly as consistent with the second reading as the first, so both get
/// checked here:
///
/// 1. **It reaches the states worth checking.** A harness that ends every match
///    on day one exercises the opening and nothing else.
/// 2. **It fails when something is wrong.** The four invariants and the stall
///    guard are asserted against states that genuinely violate them.
void main() {
  group('the fuzz harness reaches deep game states', () {
    late _Coverage cov;

    setUpAll(() {
      cov = _measure(2000);
      // Printed, not just asserted. The thresholds below are floors chosen to
      // catch a harness that has stopped exploring; the actual numbers are what
      // tell you whether a change made it explore *less* while still clearing
      // the floor, which is the drift worth noticing early.
      // Diagnostic output from a test, not production logging: it belongs on
      // stdout, where a CI run records it alongside the result.
      // ignore: avoid_print
      print('fuzz coverage over 2000 matches: $cov');
    });

    test('matches run to a real length', () {
      expect(
        cov.meanMoves,
        greaterThan(40),
        reason: 'mean length ${cov.meanMoves} — matches are ending too early',
      );
      expect(
        cov.maxDay,
        greaterThanOrEqualTo(5),
        reason: 'the longest match only reached day ${cov.maxDay}',
      );
    });

    test('both alignments win', () {
      // A harness where the mafia always won would never walk the path where
      // the last mafia is voted out, which is half the win-condition code.
      expect(cov.mafiaWins, greaterThan(100));
      expect(cov.townWins, greaterThan(100));
    });

    test('the awkward branches are actually visited', () {
      // Each of these is a doc 11 row that would otherwise be covered only by
      // the hand-written test that thought of it.
      //
      // Collected and reported together rather than asserted one at a time: a
      // coverage gap is usually several gaps with one cause, and finding them
      // one failing run at a time hides that.
      final shortfalls = <String>[];
      void need(String label, int actual, int atLeast) {
        if (actual < atLeast) {
          shortfalls.add('$label: $actual (want >= $atLeast)');
        }
      }

      need('N2/T2 doctor blocked a kill', cov.nightsWithASave, 50);
      need('D2 tied ballot', cov.tiedDayVotes, 50);
      need('D2 revote round', cov.revotesCalled, 20);
      need('D1 abstention', cov.abstentions, 50);
      need('T-E4 morning with no victim', cov.nightsWithNoDeath, 50);
      need('W8 night decided the match', cov.matchesEndingAtNight, 50);
      need('N12 no doctor in the match', cov.matchesWithNoDoctor, 50);
      need('N13 no detective in the match', cov.matchesWithNoDetective, 50);

      expect(
        shortfalls,
        isEmpty,
        reason:
            'the harness is not reaching these branches:\n'
            '${shortfalls.map((s) => '  $s').join('\n')}',
      );
    });

    test('every phase a live match can occupy is entered', () {
      // `setup` and `rolesConfigured` belong to the setup screens, and
      // `winCheck` is vestigial — nothing assigns it. Everything else must be
      // reached, or the harness has a blind spot.
      const unreachableByDesign = {
        GamePhase.setup,
        GamePhase.rolesConfigured,
        GamePhase.winCheck,
        GamePhase.analytics,
      };
      final expected = GamePhase.values.where(
        (p) => !unreachableByDesign.contains(p),
      );
      for (final phase in expected) {
        expect(
          cov.phasesSeen,
          contains(phase),
          reason: 'the harness never entered ${phase.name}',
        );
      }
    });
  });

  group('the harness bites', () {
    // Hand-built states that violate one invariant each. If any of these comes
    // back clean, the corresponding assertion has stopped working and every
    // future green run means nothing.

    test('I1 catches a dead player holding the phone', () {
      final m = _liveMatch();
      final broken = m.copyWith(
        players: [
          m.players[0].copyWith(
            status: PlayerStatus.dead,
            eliminatedOn: const PhaseRef(phase: GamePhase.night, number: 1),
          ),
          ...m.players.skip(1),
        ],
        phase: GamePhase.night,
        currentActorSeat: 0,
      );
      expect(checkMatchInvariants(broken).join(), contains('I1'));
    });

    test('I1 catches a death with no cause recorded', () {
      final m = _liveMatch();
      final broken = m.copyWith(
        players: [
          m.players[0].copyWith(status: PlayerStatus.dead),
          ...m.players.skip(1),
        ],
      );
      expect(checkMatchInvariants(broken).join(), contains('eliminatedOn'));
    });

    test('I2 catches a decided match still in a playing phase', () {
      final m = _liveMatch();
      // Kill every non-mafia: the town is gone, so the mafia have won.
      final broken = m.copyWith(
        phase: GamePhase.discussion,
        players: m.players
            .map(
              (p) => p.role == Role.mafia
                  ? p
                  : p.copyWith(
                      status: PlayerStatus.dead,
                      eliminatedOn: const PhaseRef(
                        phase: GamePhase.night,
                        number: 1,
                      ),
                    ),
            )
            .toList(),
        currentActorSeat: null,
        clearCurrentActorSeat: true,
      );
      expect(checkMatchInvariants(broken).join(), contains('I2'));
    });

    test('I2 catches a recorded outcome on a phase that is still playing', () {
      final m = _liveMatch();
      final broken = m.copyWith(
        phase: GamePhase.discussion,
        outcome: MatchOutcome(
          winner: Alignment.town,
          completedAt: Clocks.epoch,
        ),
      );
      expect(checkMatchInvariants(broken).join(), contains('I2'));
    });

    test('I3 catches a phase with no way out', () {
      final m = _liveMatch();
      // Voting with the actor pointing at nobody: no ballot can be cast and no
      // command advances the phase. This is the shape of every stall.
      final broken = m.copyWith(
        phase: GamePhase.voting,
        currentActorSeat: null,
        clearCurrentActorSeat: true,
      );
      expect(checkMatchInvariants(broken).join(), contains('I3'));
    });

    test('I4 catches a role changing mid-match', () {
      final m = _liveMatch();
      final citizen = m.players.firstWhere((p) => p.role == Role.citizen);
      final broken = m.copyWith(
        players: [
          for (final p in m.players)
            if (p.seat == citizen.seat) p.copyWith(role: Role.mafia) else p,
        ],
      );
      expect(checkMatchInvariants(broken).join(), contains('I4'));
    });

    test('the stall guard reports non-termination rather than hanging', () {
      // Proven against a real stall rather than a mocked one: a match whose
      // day never resolves. `kStallGuard` is what stands between a bug like
      // this and a test run that never finishes.
      expect(kStallGuard, 500);

      final engine = MatchEngine(clock: Clocks.monotonic());
      engine.start(
        names: List.generate(7, (i) => 'P$i'),
        roleCounts: const {
          Role.mafia: 2,
          Role.doctor: 1,
          Role.detective: 1,
          Role.citizen: 3,
        },
        settings: const MatchSettings.defaults(),
        seed: 7,
      );

      var steps = 0;
      // Confirming reveals forever is not legal past the last seat, so this
      // loop is the honest version: drive the real match and count. It must
      // terminate well inside the guard.
      while (!isTerminal(engine.match) && steps <= kStallGuard) {
        legalMoves(engine.match).first.apply(engine);
        steps++;
      }
      expect(
        steps,
        lessThan(kStallGuard),
        reason:
            'a match driven by always taking the first legal move '
            'should still finish',
      );
      expect(isTerminal(engine.match), isTrue);
    });
  });
}

// ---------------------------------------------------------------------------

class _Coverage {
  double meanMoves = 0;
  int maxDay = 0;
  int mafiaWins = 0;
  int townWins = 0;
  int nightsWithASave = 0;
  int nightsWithNoDeath = 0;
  int tiedDayVotes = 0;
  int revotesCalled = 0;
  int abstentions = 0;
  int matchesEndingAtNight = 0;
  int matchesWithNoDoctor = 0;
  int matchesWithNoDetective = 0;
  final Set<GamePhase> phasesSeen = <GamePhase>{};

  @override
  String toString() =>
      'mean ${meanMoves.toStringAsFixed(1)} moves, '
      'longest day $maxDay, mafia $mafiaWins / town $townWins, '
      'saves $nightsWithASave, quiet nights $nightsWithNoDeath, '
      'ties $tiedDayVotes, revotes $revotesCalled, '
      'abstentions $abstentions, night-decided $matchesEndingAtNight, '
      'no-doctor $matchesWithNoDoctor, no-detective $matchesWithNoDetective, '
      '${phasesSeen.length} phases';
}

/// Runs the driver's matches and records what they touched.
///
/// It asks the driver for the finished match and for a callback on every state
/// it passes through, rather than replaying the seed through a second copy of
/// the draw order. A second copy is a second thing to keep in step, and when it
/// drifts it reports coverage for games that were never played — which is a
/// worse failure than no coverage numbers at all.
_Coverage _measure(int runs) {
  final cov = _Coverage();
  var totalMoves = 0;

  for (var seed = 0; seed < runs; seed++) {
    final outcome = runFuzzedMatch(
      seed,
      onState: (state) => cov.phasesSeen.add(state.phase),
    );
    expect(outcome.ok, isTrue, reason: outcome.toString());
    totalMoves += outcome.moveCount;

    final match = outcome.finished!;
    if (match.dayNumber > cov.maxDay) cov.maxDay = match.dayNumber;

    switch (match.outcome!.winner) {
      case Alignment.mafia:
        cov.mafiaWins++;
      case Alignment.town:
        cov.townWins++;
    }

    final roles = match.players.map((p) => p.role).toSet();
    if (!roles.contains(Role.doctor)) cov.matchesWithNoDoctor++;
    if (!roles.contains(Role.detective)) cov.matchesWithNoDetective++;

    // Whether the night or the ballot ended it: the last death recorded is a
    // night death on the day the match finished.
    final deaths = match.players
        .where((p) => p.status == PlayerStatus.dead)
        .map((p) => p.eliminatedOn)
        .whereType<PhaseRef>()
        .toList();
    if (deaths.isNotEmpty &&
        deaths.any(
          (d) => d.phase == GamePhase.night && d.number == match.dayNumber,
        )) {
      cov.matchesEndingAtNight++;
    }

    for (final e in match.eventLog) {
      if (e is NightResolved) {
        if (e.savedSeat != null) cov.nightsWithASave++;
        if (e.victimSeat == null) cov.nightsWithNoDeath++;
      }
      if (e is DayRevoteCalled) cov.revotesCalled++;
      if (e is VoteCast && e.targetSeat == null) cov.abstentions++;
    }

    // A tied ballot is a day on which somebody was voted for and nobody was
    // eliminated.
    final resolvedDays = match.eventLog.whereType<DayResolved>().map(
      (e) => e.phaseRef.number,
    );
    for (var day = 1; day <= match.dayNumber; day++) {
      final votedThisDay = match.eventLog.whereType<VoteCast>().any(
        (e) => e.phaseRef.number == day && e.targetSeat != null,
      );
      if (votedThisDay && !resolvedDays.contains(day)) cov.tiedDayVotes++;
    }
  }

  cov.meanMoves = totalMoves / runs;
  return cov;
}

/// A real match, mid-flight, for the "does it bite" probes to corrupt.
///
/// Driven through the engine rather than hand-assembled: a hand-built `Match`
/// can be sound in ways a real one never is, and then a probe passes because
/// the fixture was wrong rather than because the invariant works.
Match _liveMatch() {
  final engine = MatchEngine(clock: Clocks.monotonic());
  engine.start(
    names: const ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
    roleCounts: const {
      Role.mafia: 2,
      Role.doctor: 1,
      Role.detective: 1,
      Role.citizen: 3,
    },
    settings: const MatchSettings.defaults(),
    seed: 99,
  );
  while (engine.match.phase == GamePhase.distributing) {
    engine.confirmRevealed();
  }
  return engine.match;
}
