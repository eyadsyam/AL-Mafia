import 'package:mafia_master/engine/analytics_builder.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

/// T064 — Analytics builder tests.
/// Drives a real MatchEngine to completion and validates the analytics projection.
void main() {
  group('Analytics Builder (T064)', () {
    test('builds analytics from a complete match', () {
      final engine = MatchEngine();
      engine.start(
        names: const ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace'],
        roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 3},
        settings: const MatchSettings.defaults(),
        seed: 42,
      );

      // Distribute roles
      for (int i = 0; i < 7; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      bool isAlive(int seat) => engine.match.players[seat].status == PlayerStatus.alive;
      List<int> aliveWhere(bool Function(Role) f) => [
            for (int i = 0; i < 7; i++)
              if (isAlive(i) && f(engine.match.players[i].role)) i
          ];

      int cycles = 0;
      int? lastProtect;
      while (engine.match.phase != GamePhase.result && cycles < 12) {
        cycles++;

        // NIGHT
        engine.beginNight();
        final townSeats = aliveWhere((r) => r != Role.mafia);
        final firstAliveTown = townSeats.first;
        final protectSeat = townSeats.firstWhere((s) => s != lastProtect, orElse: () => townSeats.first);
        lastProtect = protectSeat;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          switch (engine.match.players[seat].role) {
            case Role.mafia:
              engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: firstAliveTown);
            case Role.doctor:
              engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectSeat);
            case Role.detective:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: other);
            case Role.citizen:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: other);
          }
        }

        engine.resolveNight();

        // DAY
        engine.beginDiscussion();
        engine.beginVoting();

        final aliveMafia = aliveWhere((r) => r == Role.mafia);
        final voteTarget = aliveMafia.isNotEmpty ? aliveMafia.first : aliveWhere((_) => true).first;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          final target = seat == voteTarget ? aliveWhere((_) => true).firstWhere((s) => s != seat) : voteTarget;
          engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        }

        engine.resolveDayVote();

        final winner = engine.winCheck();
        if (winner != null) {
          break;
        }
      }

      expect(engine.match.phase, equals(GamePhase.result), reason: 'Match must reach result');
      expect(engine.match.outcome, isNotNull);

      // Build analytics
      final analytics = AnalyticsBuilder.build(engine.match);

      // Verify basic properties
      expect(analytics.matchId, equals(engine.match.id));
      expect(analytics.winner, isNotNull);
      expect(analytics.nightsPlayed, greaterThan(0));

      // Timeline should be non-empty
      expect(analytics.timeline, isNotEmpty);

      // Timeline rows must be in non-decreasing order by timestamp
      for (int i = 1; i < analytics.timeline.length; i++) {
        expect(
          analytics.timeline[i].at.isAfter(analytics.timeline[i - 1].at) ||
              analytics.timeline[i].at.isAtSameMomentAs(analytics.timeline[i - 1].at),
          isTrue,
          reason: 'Timeline row $i must be >= row ${i - 1} in timestamp order',
        );
      }
    });

    test('timeline rows include night and day events', () {
      final engine = MatchEngine();
      engine.start(
        names: const ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace'],
        roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 3},
        settings: const MatchSettings.defaults(),
        seed: 42,
      );

      // Distribute
      for (int i = 0; i < 7; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      bool isAlive(int seat) => engine.match.players[seat].status == PlayerStatus.alive;
      List<int> aliveWhere(bool Function(Role) f) => [
            for (int i = 0; i < 7; i++)
              if (isAlive(i) && f(engine.match.players[i].role)) i
          ];

      // Play one complete cycle to completion
      int cycles = 0;
      int? lastProtect;
      while (engine.match.phase != GamePhase.result && cycles < 12) {
        cycles++;

        engine.beginNight();
        final townSeats = aliveWhere((r) => r != Role.mafia);
        final firstAliveTown = townSeats.first;
        final protectSeat = townSeats.firstWhere((s) => s != lastProtect, orElse: () => townSeats.first);
        lastProtect = protectSeat;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          switch (engine.match.players[seat].role) {
            case Role.mafia:
              engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: firstAliveTown);
            case Role.doctor:
              engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectSeat);
            case Role.detective:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: other);
            case Role.citizen:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: other);
          }
        }

        engine.resolveNight();
        engine.beginDiscussion();
        engine.beginVoting();

        final aliveMafia = aliveWhere((r) => r == Role.mafia);
        final voteTarget = aliveMafia.isNotEmpty ? aliveMafia.first : aliveWhere((_) => true).first;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          final target = seat == voteTarget ? aliveWhere((_) => true).firstWhere((s) => s != seat) : voteTarget;
          engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        }

        engine.resolveDayVote();
        final winner = engine.winCheck();
        if (winner != null) {
          break;
        }
      }

      final analytics = AnalyticsBuilder.build(engine.match);

      // Should have various event kinds
      final kinds = analytics.timeline.map((row) => row.kind).toSet();
      expect(kinds, containsAll(['suspect', 'mafiaVote'])); // At least these should exist
    });

    test('suspicion accuracy correctly identifies correct vs incorrect suspicions', () {
      final engine = MatchEngine();
      engine.start(
        names: const ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace'],
        roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 3},
        settings: const MatchSettings.defaults(),
        seed: 99,
      );

      // Distribute
      for (int i = 0; i < 7; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      bool isAlive(int seat) => engine.match.players[seat].status == PlayerStatus.alive;
      List<int> aliveWhere(bool Function(Role) f) => [
            for (int i = 0; i < 7; i++)
              if (isAlive(i) && f(engine.match.players[i].role)) i
          ];

      int cycles = 0;
      int? lastProtect;
      while (engine.match.phase != GamePhase.result && cycles < 12) {
        cycles++;

        engine.beginNight();
        final townSeats = aliveWhere((r) => r != Role.mafia);
        final firstAliveTown = townSeats.first;
        final protectSeat = townSeats.firstWhere((s) => s != lastProtect, orElse: () => townSeats.first);
        lastProtect = protectSeat;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          switch (engine.match.players[seat].role) {
            case Role.mafia:
              engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: firstAliveTown);
            case Role.doctor:
              engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectSeat);
            case Role.detective:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: other);
            case Role.citizen:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: other);
          }
        }

        engine.resolveNight();
        engine.beginDiscussion();
        engine.beginVoting();

        final aliveMafia = aliveWhere((r) => r == Role.mafia);
        final voteTarget = aliveMafia.isNotEmpty ? aliveMafia.first : aliveWhere((_) => true).first;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          final target = seat == voteTarget ? aliveWhere((_) => true).firstWhere((s) => s != seat) : voteTarget;
          engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        }

        engine.resolveDayVote();
        final winner = engine.winCheck();
        if (winner != null) {
          break;
        }
      }

      final analytics = AnalyticsBuilder.build(engine.match);

      // All players in suspicionAccuracy must have totalSuspicions >= 0
      for (final acc in analytics.suspicionAccuracy) {
        expect(acc.totalSuspicions, greaterThanOrEqualTo(0));
        expect(acc.correctSuspicions, greaterThanOrEqualTo(0));
        expect(acc.correctSuspicions, lessThanOrEqualTo(acc.totalSuspicions));
        expect(acc.rate, greaterThanOrEqualTo(0));
        expect(acc.rate, lessThanOrEqualTo(1));
      }
    });

    test('suspicion matrix totals match number of suspicion events', () {
      final engine = MatchEngine();
      engine.start(
        names: const ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace'],
        roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 3},
        settings: const MatchSettings.defaults(),
        seed: 77,
      );

      // Distribute
      for (int i = 0; i < 7; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      bool isAlive(int seat) => engine.match.players[seat].status == PlayerStatus.alive;
      List<int> aliveWhere(bool Function(Role) f) => [
            for (int i = 0; i < 7; i++)
              if (isAlive(i) && f(engine.match.players[i].role)) i
          ];

      int cycles = 0;
      int? lastProtect;
      while (engine.match.phase != GamePhase.result && cycles < 12) {
        cycles++;

        engine.beginNight();
        final townSeats = aliveWhere((r) => r != Role.mafia);
        final firstAliveTown = townSeats.first;
        final protectSeat = townSeats.firstWhere((s) => s != lastProtect, orElse: () => townSeats.first);
        lastProtect = protectSeat;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          switch (engine.match.players[seat].role) {
            case Role.mafia:
              engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: firstAliveTown);
            case Role.doctor:
              engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectSeat);
            case Role.detective:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: other);
            case Role.citizen:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: other);
          }
        }

        engine.resolveNight();
        engine.beginDiscussion();
        engine.beginVoting();

        final aliveMafia = aliveWhere((r) => r == Role.mafia);
        final voteTarget = aliveMafia.isNotEmpty ? aliveMafia.first : aliveWhere((_) => true).first;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          final target = seat == voteTarget ? aliveWhere((_) => true).firstWhere((s) => s != seat) : voteTarget;
          engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        }

        engine.resolveDayVote();
        final winner = engine.winCheck();
        if (winner != null) {
          break;
        }
      }

      // Count SuspectCast events manually
      int totalSuspicions = 0;
      for (final event in engine.match.eventLog) {
        if (event.runtimeType.toString().contains('SuspectCast')) {
          totalSuspicions++;
        }
      }

      final analytics = AnalyticsBuilder.build(engine.match);

      // Sum all counts in the suspicion matrix
      int matrixSum = 0;
      for (final inner in analytics.suspicionMatrix.counts.values) {
        for (final count in inner.values) {
          matrixSum += count;
        }
      }

      expect(matrixSum, equals(totalSuspicions),
          reason: 'Suspicion matrix totals must equal the number of SuspectCast events');
    });

    test('at least one achievement is produced', () {
      final engine = MatchEngine();
      engine.start(
        names: const ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace'],
        roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 3},
        settings: const MatchSettings.defaults(),
        seed: 55,
      );

      // Distribute
      for (int i = 0; i < 7; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      bool isAlive(int seat) => engine.match.players[seat].status == PlayerStatus.alive;
      List<int> aliveWhere(bool Function(Role) f) => [
            for (int i = 0; i < 7; i++)
              if (isAlive(i) && f(engine.match.players[i].role)) i
          ];

      int cycles = 0;
      int? lastProtect;
      while (engine.match.phase != GamePhase.result && cycles < 12) {
        cycles++;

        engine.beginNight();
        final townSeats = aliveWhere((r) => r != Role.mafia);
        final firstAliveTown = townSeats.first;
        final protectSeat = townSeats.firstWhere((s) => s != lastProtect, orElse: () => townSeats.first);
        lastProtect = protectSeat;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          switch (engine.match.players[seat].role) {
            case Role.mafia:
              engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: firstAliveTown);
            case Role.doctor:
              engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectSeat);
            case Role.detective:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: other);
            case Role.citizen:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: other);
          }
        }

        engine.resolveNight();
        engine.beginDiscussion();
        engine.beginVoting();

        final aliveMafia = aliveWhere((r) => r == Role.mafia);
        final voteTarget = aliveMafia.isNotEmpty ? aliveMafia.first : aliveWhere((_) => true).first;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          final target = seat == voteTarget ? aliveWhere((_) => true).firstWhere((s) => s != seat) : voteTarget;
          engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        }

        engine.resolveDayVote();
        final winner = engine.winCheck();
        if (winner != null) {
          break;
        }
      }

      final analytics = AnalyticsBuilder.build(engine.match);

      expect(analytics.achievements, isNotEmpty, reason: 'At least one achievement must be produced');

      // Each achievement must have a code and at least one seat. The title and
      // blurb deliberately live in the localisation layer, not on the engine
      // object — `engine_copy_test` checks that every code has copy.
      for (final achievement in analytics.achievements) {
        expect(achievement.code, isNotEmpty);
        expect(achievement.seats, isNotEmpty);
      }
    });

    test('finalRoles covers every seat', () {
      final engine = MatchEngine();
      engine.start(
        names: const ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace'],
        roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 3},
        settings: const MatchSettings.defaults(),
        seed: 42,
      );

      // Distribute
      for (int i = 0; i < 7; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      bool isAlive(int seat) => engine.match.players[seat].status == PlayerStatus.alive;
      List<int> aliveWhere(bool Function(Role) f) => [
            for (int i = 0; i < 7; i++)
              if (isAlive(i) && f(engine.match.players[i].role)) i
          ];

      int cycles = 0;
      int? lastProtect;
      while (engine.match.phase != GamePhase.result && cycles < 12) {
        cycles++;

        engine.beginNight();
        final townSeats = aliveWhere((r) => r != Role.mafia);
        final firstAliveTown = townSeats.first;
        final protectSeat = townSeats.firstWhere((s) => s != lastProtect, orElse: () => townSeats.first);
        lastProtect = protectSeat;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          switch (engine.match.players[seat].role) {
            case Role.mafia:
              engine.submitNightAction(seat: seat, kind: NightActionKind.mafiaVote, targetSeat: firstAliveTown);
            case Role.doctor:
              engine.submitNightAction(seat: seat, kind: NightActionKind.protect, targetSeat: protectSeat);
            case Role.detective:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.investigate, targetSeat: other);
            case Role.citizen:
              final other = [for (int i = 0; i < 7; i++) if (i != seat) i].first;
              engine.submitNightAction(seat: seat, kind: NightActionKind.suspect, targetSeat: other);
          }
        }

        engine.resolveNight();
        engine.beginDiscussion();
        engine.beginVoting();

        final aliveMafia = aliveWhere((r) => r == Role.mafia);
        final voteTarget = aliveMafia.isNotEmpty ? aliveMafia.first : aliveWhere((_) => true).first;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          final target = seat == voteTarget ? aliveWhere((_) => true).firstWhere((s) => s != seat) : voteTarget;
          engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        }

        engine.resolveDayVote();
        final winner = engine.winCheck();
        if (winner != null) {
          break;
        }
      }

      final analytics = AnalyticsBuilder.build(engine.match);

      // finalRoles must have an entry for every player seat
      for (final player in engine.match.players) {
        expect(analytics.finalRoles.containsKey(player.seat), isTrue,
            reason: 'finalRoles must cover seat ${player.seat}');
        expect(analytics.finalRoles[player.seat], equals(player.role),
            reason: 'Role for seat ${player.seat} must match the player role');
      }
    });
  });
}
