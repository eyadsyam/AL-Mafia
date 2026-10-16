import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/balance_guard.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/online/lobby_deal.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';

/// Rulings RL11 and RL12 (docs/specs/17-roles-and-tools.md §12): the online
/// lobby deals the same split as offline and never offers the server a sold
/// role the table is too small for.
void main() {
  const allOn = MatchSettings(
    silencerEnabled: true,
    elderEnabled: true,
    sniperEnabled: true,
  );

  test('every size deals a valid split the guard accepts', () {
    for (var n = 5; n <= 15; n++) {
      final deal = lobbyDeal(n, allOn);
      final report = BalanceGuard.evaluate(
        playerCount: n,
        roleCounts: deal.counts,
      );
      expect(report.valid, isTrue, reason: '$n players: ${report.issues}');
      expect(deal.counts.values.fold(0, (a, b) => a + b), n);
    }
  });

  test('five players skip all three sold roles and say so', () {
    final deal = lobbyDeal(5, allOn);
    expect(deal.skipped, OptionalRole.values);
    expect(deal.settings.silencerEnabled, isFalse);
    expect(deal.counts.containsKey(Role.elder), isFalse);
  });

  test('a big enough table deals every sold role the host switched on', () {
    final deal = lobbyDeal(12, allOn);
    expect(deal.skipped, isEmpty);
    expect(deal.counts[Role.silencer], 1);
    expect(deal.counts[Role.elder], 1);
    expect(deal.counts[Role.sniper], 1);
  });

  test('nothing switched on deals the plain recommended split', () {
    expect(
      lobbyDeal(9, const MatchSettings()).counts,
      BalanceGuard.recommended(9),
    );
  });
}
