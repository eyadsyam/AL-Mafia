import 'package:mafia_master/engine/balance_guard.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:test/test.dart';

/// T057 — Balance Guard validation and recommendations.
///
/// Tests the BalanceGuard.evaluate() rules and BalanceGuard.recommended()
/// output validity.
void main() {
  group('Balance Guard (T057)', () {
    group('evaluate() — blocking rules', () {
      test('blocks fewer than 5 players', () {
        final report = BalanceGuard.evaluate(
          playerCount: 4,
          roleCounts: {Role.mafia: 1, Role.citizen: 3},
        );
        expect(report.valid, isFalse);
        expect(
          report.issues.where((i) => i.code == 'player_count_too_low'),
          isNotEmpty,
        );
      });

      test('blocks more than 20 players', () {
        final report = BalanceGuard.evaluate(
          playerCount: 21,
          roleCounts: {Role.mafia: 5, Role.citizen: 16},
        );
        expect(report.valid, isFalse);
        expect(
          report.issues.where((i) => i.code == 'player_count_too_high'),
          isNotEmpty,
        );
      });

      test('blocks when role counts do not sum to player count', () {
        final report = BalanceGuard.evaluate(
          playerCount: 7,
          roleCounts: {Role.mafia: 1, Role.citizen: 5}, // sum = 6, not 7
        );
        expect(report.valid, isFalse);
        expect(
          report.issues.where((i) => i.code == 'role_count_mismatch'),
          isNotEmpty,
        );
      });

      test('blocks zero mafia', () {
        final report = BalanceGuard.evaluate(
          playerCount: 5,
          roleCounts: {Role.citizen: 5},
        );
        expect(report.valid, isFalse);
        expect(
          report.issues.where((i) => i.code == 'no_mafia'),
          isNotEmpty,
        );
      });

      test('blocks mafia >= half of players', () {
        final report = BalanceGuard.evaluate(
          playerCount: 6,
          roleCounts: {Role.mafia: 3, Role.citizen: 3}, // 3 >= 3, violates
        );
        expect(report.valid, isFalse);
        expect(
          report.issues.where((i) => i.code == 'mafia_too_many'),
          isNotEmpty,
        );
      });

      test('blocks negative role count', () {
        final report = BalanceGuard.evaluate(
          playerCount: 5,
          roleCounts: {Role.mafia: -1, Role.citizen: 6},
        );
        expect(report.valid, isFalse);
        expect(
          report.issues.where((i) => i.code == 'negative_role_count'),
          isNotEmpty,
        );
      });

      test('allows valid 5-player configuration', () {
        final report = BalanceGuard.evaluate(
          playerCount: 5,
          roleCounts: {
            Role.mafia: 1,
            Role.detective: 1,
            Role.doctor: 1,
            Role.citizen: 2,
          },
        );
        expect(report.valid, isTrue);
        expect(report.issues.where((i) => i.blocking), isEmpty);
      });
    });

    group('evaluate() — advisory rules', () {
      test('recommends 3 Mafia at 9 players when configured differently', () {
        final report = BalanceGuard.evaluate(
          playerCount: 9,
          roleCounts: {
            Role.mafia: 2,
            Role.detective: 1,
            Role.doctor: 1,
            Role.citizen: 5,
          },
        );
        expect(report.valid, isTrue); // No blocking issues
        expect(
          report.issues.where((i) => i.code == 'recommend_three_mafia'),
          isNotEmpty,
        );
        final advisory = report.issues.firstWhere(
          (i) => i.code == 'recommend_three_mafia',
        );
        expect(advisory.blocking, isFalse);
      });

      test('does not advise when 3 Mafia at 9+ players', () {
        final report = BalanceGuard.evaluate(
          playerCount: 9,
          roleCounts: {
            Role.mafia: 3,
            Role.detective: 1,
            Role.doctor: 1,
            Role.citizen: 4,
          },
        );
        expect(
          report.issues.where((i) => i.code == 'recommend_three_mafia'),
          isEmpty,
        );
      });

      test('warns on 2 Detectives below 11 players', () {
        final report = BalanceGuard.evaluate(
          playerCount: 10,
          roleCounts: {
            Role.mafia: 2,
            Role.detective: 2,
            Role.doctor: 1,
            Role.citizen: 5,
          },
        );
        expect(report.valid, isTrue);
        expect(
          report.issues.where((i) => i.code == 'two_detectives_low_player_count'),
          isNotEmpty,
        );
      });

      test('does not warn on 2 Detectives at 11+ players', () {
        final report = BalanceGuard.evaluate(
          playerCount: 11,
          roleCounts: {
            Role.mafia: 3,
            Role.detective: 2,
            Role.doctor: 1,
            Role.citizen: 5,
          },
        );
        expect(
          report.issues.where((i) => i.code == 'two_detectives_low_player_count'),
          isEmpty,
        );
      });

      test('sorts blocking issues before advisory', () {
        final report = BalanceGuard.evaluate(
          playerCount: 10,
          roleCounts: {
            Role.mafia: 5, // >= half, blocking
            Role.detective: 2, // advisory on count/player combo
            Role.citizen: 3,
          },
        );
        // Blocking issues should come first
        final blockingIndex = report.issues.indexWhere((i) => i.blocking);
        final advisoryIndex = report.issues.indexWhere((i) => !i.blocking);
        if (blockingIndex >= 0 && advisoryIndex >= 0) {
          expect(blockingIndex, lessThan(advisoryIndex));
        }
      });
    });

    group('recommended()', () {
      test('returns valid distribution for 5 players (1 Mafia)', () {
        final dist = BalanceGuard.recommended(5);
        expect(dist[Role.mafia], equals(1));
        expect(dist[Role.detective], equals(1));
        expect(dist[Role.doctor], equals(1));
        expect(dist[Role.citizen], equals(2));

        final report = BalanceGuard.evaluate(
          playerCount: 5,
          roleCounts: dist,
        );
        expect(report.valid, isTrue);
      });

      test('returns valid distribution for 6 players (1 Mafia)', () {
        final dist = BalanceGuard.recommended(6);
        expect(dist[Role.mafia], equals(1));
        final sum = dist.values.fold(0, (a, b) => a + b);
        expect(sum, equals(6));

        final report = BalanceGuard.evaluate(playerCount: 6, roleCounts: dist);
        expect(report.valid, isTrue);
      });

      test('returns valid distribution for 7 players (2 Mafia)', () {
        final dist = BalanceGuard.recommended(7);
        expect(dist[Role.mafia], equals(2));
        final sum = dist.values.fold(0, (a, b) => a + b);
        expect(sum, equals(7));

        final report = BalanceGuard.evaluate(playerCount: 7, roleCounts: dist);
        expect(report.valid, isTrue);
      });

      test('returns valid distribution for 8 players (2 Mafia)', () {
        final dist = BalanceGuard.recommended(8);
        expect(dist[Role.mafia], equals(2));
        final sum = dist.values.fold(0, (a, b) => a + b);
        expect(sum, equals(8));

        final report = BalanceGuard.evaluate(playerCount: 8, roleCounts: dist);
        expect(report.valid, isTrue);
      });

      test('returns valid distribution for 9 players (3 Mafia)', () {
        final dist = BalanceGuard.recommended(9);
        expect(dist[Role.mafia], equals(3));
        final sum = dist.values.fold(0, (a, b) => a + b);
        expect(sum, equals(9));

        final report = BalanceGuard.evaluate(playerCount: 9, roleCounts: dist);
        expect(report.valid, isTrue);
      });

      test('returns valid distribution for 20 players (3 Mafia)', () {
        final dist = BalanceGuard.recommended(20);
        expect(dist[Role.mafia], equals(3));
        final sum = dist.values.fold(0, (a, b) => a + b);
        expect(sum, equals(20));

        final report = BalanceGuard.evaluate(playerCount: 20, roleCounts: dist);
        expect(report.valid, isTrue);
      });

      test('all recommended distributions are always valid', () {
        for (int players = 5; players <= 20; players++) {
          final dist = BalanceGuard.recommended(players);
          final report = BalanceGuard.evaluate(
            playerCount: players,
            roleCounts: dist,
          );
          expect(
            report.valid,
            isTrue,
            reason: 'recommended($players) produced invalid distribution',
          );
        }
      });

      test('clamps out-of-range player counts to 5–20', () {
        // Below 5 should be clamped to 5
        final dist3 = BalanceGuard.recommended(3);
        expect(dist3.values.fold(0, (a, b) => a + b), equals(5));

        // Above 20 should be clamped to 20
        final dist30 = BalanceGuard.recommended(30);
        expect(dist30.values.fold(0, (a, b) => a + b), equals(20));
      });
    });
  });
}
