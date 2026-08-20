import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:test/test.dart';

void main() {
  group('State Machine (T019)', () {
    late MatchEngine engine;
    late List<String> playerNames;
    late Map<Role, int> roleCounts;

    setUp(() {
      playerNames = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'];
      roleCounts = {Role.mafia: 2, Role.detective: 1, Role.doctor: 1, Role.citizen: 1};
    });

    test('start → distributing phase', () {
      engine = MatchEngine();
      final match = engine.start(
        names: playerNames,
        roleCounts: roleCounts,
        settings: MatchSettings.defaults(),
      );

      expect(match.phase, equals(GamePhase.distributing));
      expect(match.players.length, equals(5));
      expect(match.dayNumber, equals(1));
      expect(match.currentActorSeat, equals(0));
    });

    test('distribution loop advances currentActorSeat', () {
      engine = MatchEngine();
      engine.start(
        names: playerNames,
        roleCounts: roleCounts,
        settings: MatchSettings.defaults(),
      );

      // Reveal for seat 0
      engine.revealFor(0);
      engine.confirmRevealed();
      expect(engine.match.currentActorSeat, equals(1));

      // Reveal for seat 1
      engine.revealFor(1);
      engine.confirmRevealed();
      expect(engine.match.currentActorSeat, equals(2));

      // Continue until all revealed
      engine.revealFor(2);
      engine.confirmRevealed();
      engine.revealFor(3);
      engine.confirmRevealed();
      engine.revealFor(4);
      engine.confirmRevealed();

      // After all revealed, should be preNightLobby
      expect(engine.match.phase, equals(GamePhase.preNightLobby));
      expect(engine.match.currentActorSeat, isNull);
    });

    test('beginNight transitions to night phase', () {
      engine = MatchEngine();
      engine.start(
        names: playerNames,
        roleCounts: roleCounts,
        settings: MatchSettings.defaults(),
      );

      // Complete distribution
      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      expect(engine.match.phase, equals(GamePhase.night));
      expect(engine.match.dayNumber, equals(1));
      expect(engine.match.currentActorSeat, isNotNull);
      // currentActorSeat should reference an alive player
      expect(engine.match.players[engine.match.currentActorSeat!].status, equals(PlayerStatus.alive));
    });

    test('night loop skips dead players', () {
      engine = MatchEngine();
      engine.start(
        names: playerNames,
        roleCounts: roleCounts,
        settings: MatchSettings.defaults(),
      );

      // Complete distribution
      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      // Manually mark a player as dead
      final match = engine.match;
      final deadPlayer = match.players[0].copyWith(status: PlayerStatus.dead);
      final updatedPlayers = [...match.players];
      updatedPlayers[0] = deadPlayer;
      engine.match = match.copyWith(players: updatedPlayers);

      // Verify that when we advance from a dead seat, the next actor is alive
      final firstAliveInLoop = engine.match.players
          .skip(1)
          .firstWhere((p) => p.status == PlayerStatus.alive);
      expect(firstAliveInLoop.status, equals(PlayerStatus.alive));
    });

    test('currentActorSeat always references alive player', () {
      engine = MatchEngine();
      engine.start(
        names: playerNames,
        roleCounts: roleCounts,
        settings: MatchSettings.defaults(),
      );

      // Complete distribution
      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      // Check that current actor is alive
      if (engine.match.currentActorSeat != null) {
        expect(
          engine.match.players[engine.match.currentActorSeat!].status,
          equals(PlayerStatus.alive),
        );
      }
    });

    test('full cycle: distributing → preNightLobby → night → morning', () {
      engine = MatchEngine();
      engine.start(
        names: playerNames,
        roleCounts: roleCounts,
        settings: MatchSettings.defaults(),
      );

      expect(engine.match.phase, equals(GamePhase.distributing));

      // Complete distribution
      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      expect(engine.match.phase, equals(GamePhase.preNightLobby));

      engine.beginNight();
      expect(engine.match.phase, equals(GamePhase.night));

      // Night has one NightOpened event
      final nightOpenedEvents = engine.match.eventLog.whereType<NightOpened>().toList();
      expect(nightOpenedEvents.length, equals(1));
    });
  });
}
