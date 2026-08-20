import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

/// T021a — day-vote tie handling. To make the tie deterministic and clean we
/// keep the intended candidates alive at night (the doctor self-protects and the
/// mafia targets the doctor → saved), then cast a 2–2 tie by seat number.
/// Night/day are always driven via the engine's own currentActorSeat loop.
void main() {
  group('Day Tie and Revote (T021a)', () {
    late MatchEngine engine;
    late int doctorSeat;
    late List<int> citizenSeats;

    void startFive(DayTieRule rule) {
      engine = MatchEngine();
      engine.start(
        names: const ['A', 'B', 'C', 'D', 'E'],
        roleCounts: const {Role.mafia: 1, Role.doctor: 1, Role.detective: 1, Role.citizen: 2},
        settings: MatchSettings(dayTieRule: rule),
        seed: 1,
      );
      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }
      doctorSeat = [for (int i = 0; i < 5; i++) if (engine.match.players[i].role == Role.doctor) i].first;
      citizenSeats = [for (int i = 0; i < 5; i++) if (engine.match.players[i].role == Role.citizen) i];
    }

    // Drive one night. If [killSeat] is null the doctor self-protects and the
    // mafia targets the doctor → nobody dies. Otherwise the mafia targets
    // [killSeat] and the doctor protects itself → [killSeat] dies.
    void runNight({int? killSeat}) {
      engine.beginNight();
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        switch (engine.match.players[seat].role) {
          case Role.mafia:
            engine.submitNightAction(
                seat: seat, kind: NightActionKind.mafiaVote, targetSeat: killSeat ?? doctorSeat);
          case Role.doctor:
            engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: doctorSeat);
          case Role.detective:
            engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: (seat + 1) % 5);
          case Role.citizen:
            engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: (seat + 1) % 5);
        }
      }
      engine.resolveNight();
      engine.beginDiscussion();
      engine.beginVoting();
    }

    // Cast votes from a seat→target map, driven by the engine's actor order.
    void castVotes(Map<int, int> votes) {
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        engine.submitVote(seat: seat, voterSeat: seat, targetSeat: votes[seat]!);
      }
    }

    test('tie with revote rule → returns tie with tiedSeats and phase returns to voting', () {
      startFive(DayTieRule.revote);
      runNight(); // nobody dies, all five alive
      // seat1 ← {0,2}, seat3 ← {1,4}, seat0 ← {3}: 2–2 tie between 1 and 3, no self-votes.
      castVotes({0: 1, 1: 3, 2: 1, 3: 0, 4: 3});

      final result = engine.resolveDayVote();
      expect(result.tie, isTrue);
      expect(result.tiedSeats, isNotNull);
      expect(result.tiedSeats!.toSet(), equals({1, 3}));
      expect(engine.match.phase, equals(GamePhase.voting));
      expect(engine.match.currentActorSeat, isNotNull);
      expect(engine.match.players[engine.match.currentActorSeat!].status, equals(PlayerStatus.alive));
    });

    test('tie with noElimination rule → nobody eliminated, phase reveal', () {
      startFive(DayTieRule.noElimination);
      runNight();
      final aliveBefore = engine.match.players.where((p) => p.status == PlayerStatus.alive).length;
      castVotes({0: 1, 1: 3, 2: 1, 3: 0, 4: 3});

      final result = engine.resolveDayVote();
      expect(result.eliminatedSeat, isNull);
      expect(engine.match.phase, equals(GamePhase.reveal));
      final aliveAfter = engine.match.players.where((p) => p.status == PlayerStatus.alive).length;
      expect(aliveAfter, equals(aliveBefore));
    });

    test('revote ballot is restricted to the tied seats only', () {
      startFive(DayTieRule.revote);
      runNight();
      castVotes({0: 1, 1: 3, 2: 1, 3: 0, 4: 3});
      final tied = engine.resolveDayVote().tiedSeats!;
      expect(tied, equals([1, 3]));

      // A seat that was not tied is not a legal target on the revote. Pick one
      // that is neither tied nor the voter, so the rejection can only be the
      // ballot restriction and not the self-vote rule.
      final voter = engine.match.currentActorSeat!;
      final untied = [
        for (int i = 0; i < 5; i++)
          if (!tied.contains(i) && i != voter) i
      ].first;
      expect(
        () => engine.submitVote(seat: voter, voterSeat: voter, targetSeat: untied),
        throwsStateError,
      );
    });

    test('revote is tallied on its own, not on top of the round that tied', () {
      startFive(DayTieRule.revote);
      runNight();
      castVotes({0: 1, 1: 3, 2: 1, 3: 0, 4: 3}); // 1←2, 3←2
      final tied = engine.resolveDayVote().tiedSeats!;
      expect(tied, equals([1, 3]));

      // Round 2: everyone who can, votes seat 3. If round 1 were counted too,
      // seat 1 would still be carrying two votes and this would tie again.
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        engine.submitVote(seat: seat, voterSeat: seat, targetSeat: seat == 3 ? 1 : 3);
      }

      final second = engine.resolveDayVote();
      expect(second.tie, isFalse);
      expect(second.eliminatedSeat, equals(3));
      expect(second.tally, equals({3: 4, 1: 1}));
      expect(second.eliminatedRole, equals(engine.match.players[3].role));
      expect(engine.match.players[3].status, equals(PlayerStatus.dead));
    });

    test('dead players never appear in tiedSeats', () {
      startFive(DayTieRule.revote);
      final deadSeat = citizenSeats.first;
      runNight(killSeat: deadSeat); // one citizen dies at night
      expect(engine.match.players[deadSeat].status, equals(PlayerStatus.dead));

      // Build a clean 2–2 tie among the four living seats, in ascending order.
      final living = [for (int i = 0; i < 5; i++) if (engine.match.players[i].status == PlayerStatus.alive) i];
      final x = living[2], y = living[0];
      final votes = <int, int>{
        living[0]: x,
        living[1]: x,
        living[2]: y,
        living[3]: y,
      };
      castVotes(votes);

      final result = engine.resolveDayVote();
      expect(result.tie, isTrue);
      expect(result.tiedSeats!.toSet(), equals({x, y}));
      for (final seat in result.tiedSeats!) {
        expect(engine.match.players[seat].status, equals(PlayerStatus.alive));
        expect(seat, isNot(equals(deadSeat)));
      }
    });
  });
}
