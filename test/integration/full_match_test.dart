import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

/// T023 — drive a full 7-player match to a definite win using ONLY engine
/// commands, respecting the engine's seating-order actor loop (never manually
/// setting currentActorSeat). Strategy that provably converges to a town win:
///   - Night: mafia kill the lowest-seat alive TOWN player; doctor protects a
///     fixed ally (detective) so the kill lands; detective/citizens act.
///   - Day: every living player votes out the lowest-seat alive MAFIA.
/// 7 players (2 mafia / 5 town): N1 kill→ D1 vote a mafia → N2 kill → D2 vote
/// the last mafia → town wins, with mafia never reaching parity.
void main() {
  group('Full Match Integration (T023)', () {
    test('7-player match reaches a definite town win and phase==result', () {
      final engine = MatchEngine();
      engine.start(
        names: const ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace'],
        roleCounts: const {Role.mafia: 2, Role.doctor: 1, Role.detective: 1, Role.citizen: 3},
        settings: const MatchSettings.defaults(),
        seed: 7,
      );
      expect(engine.match.phase, equals(GamePhase.distributing));

      for (int i = 0; i < 7; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }
      expect(engine.match.phase, equals(GamePhase.preNightLobby));

      bool isAlive(int seat) => engine.match.players[seat].status == PlayerStatus.alive;
      List<int> aliveWhere(bool Function(Role) f) => [
            for (int i = 0; i < 7; i++)
              if (isAlive(i) && f(engine.match.players[i].role)) i
          ];

      int cycles = 0;
      int? lastProtect; // doctor may not protect the same seat two nights running
      while (engine.match.phase != GamePhase.result && cycles < 12) {
        cycles++;

        // ---- NIGHT ----
        engine.beginNight();
        expect(engine.match.phase, equals(GamePhase.night));

        final townSeats = aliveWhere((r) => r != Role.mafia);
        final firstAliveTown = townSeats.first;
        // Alternate the protected seat so the no-repeat rule is never violated.
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
        expect(engine.match.phase, equals(GamePhase.nightResolving));
        engine.resolveNight();
        expect(engine.match.phase, equals(GamePhase.morning));

        // ---- DAY ----
        engine.beginDiscussion();
        engine.beginVoting();

        final aliveMafia = aliveWhere((r) => r == Role.mafia);
        // If mafia already gone, resolveNight didn't end it (win is checked below); pick any target.
        final voteTarget = aliveMafia.isNotEmpty
            ? aliveMafia.first
            : aliveWhere((_) => true).first;

        while (engine.match.currentActorSeat != null) {
          final seat = engine.match.currentActorSeat!;
          // Voter can't self-vote: if this voter IS the target, vote the next alive instead.
          final target = seat == voteTarget
              ? aliveWhere((_) => true).firstWhere((s) => s != seat)
              : voteTarget;
          engine.submitVote(seat: seat, voterSeat: seat, targetSeat: target);
        }
        expect(engine.match.phase, equals(GamePhase.voteResolving));
        final dayResult = engine.resolveDayVote();
        // Clean majority expected → an elimination, phase reveal.
        expect(dayResult.eliminatedSeat, isNotNull);
        expect(engine.match.phase, equals(GamePhase.reveal));

        final winner = engine.winCheck();
        if (winner != null) {
          expect(engine.match.phase, equals(GamePhase.result));
          break;
        }
        expect(engine.match.phase, equals(GamePhase.preNightLobby));
      }

      expect(engine.match.phase, equals(GamePhase.result),
          reason: 'Match did not reach result after $cycles cycles');
      expect(engine.match.outcome, isNotNull);
      expect(engine.match.outcome!.winner, equals(Alignment.town));
    });
  });
}
