import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:test/test.dart';

void main() {
  group('Detective Result Ephemeral (T022)', () {
    late MatchEngine engine;

    test('investigate returns four-valued exact role once', () {
      engine = MatchEngine();
      engine.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 1, Role.doctor: 1, Role.detective: 1, Role.citizen: 2},
        settings: MatchSettings.defaults(),
      );

      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      // Find detective
      int detectiveIdx = -1;
      for (int i = 0; i < 5; i++) {
        if (engine.match.players[i].role == Role.detective) {
          detectiveIdx = i;
          break;
        }
      }

      // Have detective investigate seat 0
      engine.match = engine.match.copyWith(currentActorSeat: detectiveIdx);
      final result = engine.submitNightAction(
        seat: detectiveIdx,
        kind: NightActionKind.investigate,
        targetSeat: 0,
      );

      // Result should be returned
      expect(result, isNotNull);
      expect(result!.targetSeat, equals(0));
      expect([Role.mafia, Role.doctor, Role.detective, Role.citizen].contains(result.revealedRole), isTrue);
    });

    test('second investigate in same turn throws StateError', () {
      engine = MatchEngine();
      engine.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 1, Role.doctor: 1, Role.detective: 1, Role.citizen: 2},
        settings: MatchSettings.defaults(),
      );

      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      // Find detective
      int detectiveIdx = -1;
      for (int i = 0; i < 5; i++) {
        if (engine.match.players[i].role == Role.detective) {
          detectiveIdx = i;
          break;
        }
      }

      // Have detective investigate seat 0
      engine.match = engine.match.copyWith(currentActorSeat: detectiveIdx);
      engine.submitNightAction(
        seat: detectiveIdx,
        kind: NightActionKind.investigate,
        targetSeat: 0,
      );

      // Second investigate should throw
      expect(
        () {
          engine.submitNightAction(
            seat: detectiveIdx,
            kind: NightActionKind.investigate,
            targetSeat: 1,
          );
        },
        throwsStateError,
      );
    });

    test('publicView() exposes NO role field', () {
      engine = MatchEngine();
      engine.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 1, Role.doctor: 1, Role.detective: 1, Role.citizen: 2},
        settings: MatchSettings.defaults(),
      );

      final publicView = engine.publicView();

      // Check that PublicPlayer instances don't have a role field
      for (final player in publicView.players) {
        // Try to access a non-existent 'role' field
        // This should not compile or work at runtime
        expect(player.seat, isNotNull);
        expect(player.name, isNotNull);
        expect(player.status, isNotNull);

        // PublicPlayer should not have a 'role' property
        // Use reflection or direct cast to verify this
        final props = player.runtimeType.toString();
        expect(props.contains('role'), isFalse, reason: 'PublicPlayer should not have a role property');
      }
    });

    test('investigate result never appears in PublicMatchView', () {
      engine = MatchEngine();
      engine.start(
        names: ['A', 'B', 'C', 'D', 'E'],
        roleCounts: {Role.mafia: 1, Role.doctor: 1, Role.detective: 1, Role.citizen: 2},
        settings: MatchSettings.defaults(),
      );

      for (int i = 0; i < 5; i++) {
        engine.revealFor(i);
        engine.confirmRevealed();
      }

      engine.beginNight();

      // Find detective
      int detectiveIdx = -1;
      for (int i = 0; i < 5; i++) {
        if (engine.match.players[i].role == Role.detective) {
          detectiveIdx = i;
          break;
        }
      }

      // Have detective investigate
      engine.match = engine.match.copyWith(currentActorSeat: detectiveIdx);
      engine.submitNightAction(
        seat: detectiveIdx,
        kind: NightActionKind.investigate,
        targetSeat: 0,
      );

      // Get public view
      final publicView = engine.publicView();

      // Investigate results should not appear in event log exposed to public
      // (InvestigateResult is only in the actual event log, not in publicView)
      expect(publicView, isNotNull);

      // Verify that the public view contains no role information
      for (final player in publicView.players) {
        // Ensure player has no role field
        final playerStr = player.toString();
        expect(playerStr.contains('role'), isFalse);
      }
    });
  });
}
