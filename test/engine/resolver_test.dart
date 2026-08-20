import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

void main() {
  group('Resolver (T020)', () {
    late MatchEngine engine;

    test('mafia target dies without doctor protection', () {
      engine = MatchEngine();
      engine.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 2, Role.detective: 1, Role.doctor: 1, Role.citizen: 1},
        settings: MatchSettings.defaults(),
      );

      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      // Process all alive actors in the order the engine provides
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        final role = engine.match.players[seat].role;

        if (role == Role.mafia) {
          engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: 2);
        } else if (role == Role.doctor) {
          engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: 3);
        } else if (role == Role.detective) {
          engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: 0);
        } else {
          engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: 0);
        }
      }

      final report = engine.resolveNight();

      expect(report.victimSeat, equals(2));
      expect(engine.match.players[2].status, equals(PlayerStatus.dead));
    });

    test('doctor protecting mafia target → saved', () {
      engine = MatchEngine();
      engine.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 2, Role.detective: 1, Role.doctor: 1, Role.citizen: 1},
        settings: MatchSettings.defaults(),
      );

      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        final role = engine.match.players[seat].role;

        if (role == Role.mafia) {
          engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: 2);
        } else if (role == Role.doctor) {
          engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: 2);
        } else if (role == Role.detective) {
          engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: 0);
        } else {
          engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: 0);
        }
      }

      final report = engine.resolveNight();

      expect(report.victimSeat, isNull);
      expect(report.someoneSavedUnnamed, isTrue);
      expect(report.allSurvived, isTrue);
    });

    test('seeded tie-break: deterministic resolution with same seed', () {
      const testSeed = 42;

      int? victim1, victim2;

      // First run
      MatchEngine engine1 = MatchEngine();
      engine1.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 2, Role.detective: 1, Role.doctor: 1, Role.citizen: 1},
        settings: MatchSettings.defaults(),
        seed: testSeed,
      );

      for (int i = 0; i < 5; i++) {
        engine1.revealFor(i);
        engine1.confirmRevealed();
      }

      engine1.beginNight();

      int mafiaCount = 0;
      while (engine1.match.currentActorSeat != null) {
        final seat = engine1.match.currentActorSeat!;
        final role = engine1.match.players[seat].role;

        if (role == Role.mafia) {
          // First mafia votes for 2, second for 3 (creates tie)
          final target = mafiaCount == 0 ? 2 : 3;
          engine1.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: target);
          mafiaCount++;
        } else if (role == Role.doctor) {
          engine1.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: 0);
        } else if (role == Role.detective) {
          engine1.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: 0);
        } else {
          engine1.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: 0);
        }
      }

      final report1 = engine1.resolveNight();
      victim1 = report1.victimSeat;

      // Second run with same seed
      MatchEngine engine2 = MatchEngine();
      engine2.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 2, Role.detective: 1, Role.doctor: 1, Role.citizen: 1},
        settings: MatchSettings.defaults(),
        seed: testSeed,
      );

      for (int i = 0; i < 5; i++) {
        engine2.revealFor(i);
        engine2.confirmRevealed();
      }

      engine2.beginNight();

      mafiaCount = 0;
      while (engine2.match.currentActorSeat != null) {
        final seat = engine2.match.currentActorSeat!;
        final role = engine2.match.players[seat].role;

        if (role == Role.mafia) {
          final target = mafiaCount == 0 ? 2 : 3;
          engine2.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: target);
          mafiaCount++;
        } else if (role == Role.doctor) {
          engine2.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: 0);
        } else if (role == Role.detective) {
          engine2.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: 0);
        } else {
          engine2.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: 0);
        }
      }

      final report2 = engine2.resolveNight();
      victim2 = report2.victimSeat;

      expect(victim1, equals(victim2));
    });

    test('doctor no-repeat: protecting same seat twice in a row throws', () {
      // 1 mafia / 3 town so the game survives a day into a second night.
      engine = MatchEngine();
      engine.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 1, Role.detective: 1, Role.doctor: 1, Role.citizen: 2},
        settings: MatchSettings.defaults(),
        seed: 3,
      );
      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      final doctorSeat = [for (int i = 0; i < 5; i++) if (engine.match.players[i].role == Role.doctor) i].first;
      final detectiveSeat = [for (int i = 0; i < 5; i++) if (engine.match.players[i].role == Role.detective) i].first;
      final citizenSeats = [for (int i = 0; i < 5; i++) if (engine.match.players[i].role == Role.citizen) i];
      final protectTarget = detectiveSeat; // a living town seat the doctor will re-protect

      // --- Night 1: doctor protects the detective; mafia kills citizen[0]. ---
      engine.beginNight();
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        switch (engine.match.players[seat].role) {
          case Role.mafia:
            engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: citizenSeats[0]);
          case Role.doctor:
            engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectTarget);
          case Role.detective:
            engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: (seat + 1) % 5);
          case Role.citizen:
            engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: (seat + 1) % 5);
        }
      }
      engine.resolveNight();
      engine.beginDiscussion();
      engine.beginVoting();

      // --- Day 1: converge to eliminate the surviving citizen (game continues). ---
      final dayTarget = citizenSeats[1];
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        final target = seat == dayTarget
            ? [for (int i = 0; i < 5; i++) if (engine.match.players[i].status == PlayerStatus.alive && i != seat) i].first
            : dayTarget;
        engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
      }
      engine.resolveDayVote();
      final winner = engine.winCheck();
      expect(winner, isNull, reason: 'game should continue into night 2');
      expect(engine.match.phase, equals(GamePhase.preNightLobby));

      // --- Night 2: doctor re-protects the same seat → must throw. ---
      engine.beginNight();
      expect(
        () {
          while (engine.match.currentActorSeat != null) {
            final seat = engine.match.currentActorSeat!;
            switch (engine.match.players[seat].role) {
              case Role.mafia:
                engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: doctorSeat);
              case Role.doctor:
                engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectTarget);
              case Role.detective:
                engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: (seat + 1) % 5);
              case Role.citizen:
                engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: (seat + 1) % 5);
            }
          }
        },
        throwsA(isA<StateError>()),
      );
    });
  });
}
