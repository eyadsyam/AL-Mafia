import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/balance_guard.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/lobby_deal.dart';
import 'package:mafia_master/ui/screens/online/online_deal_panel.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:mafia_master/ui/screens/setup/role_deal_grid.dart';

import '../support/localized.dart';

class _Owns extends WalletController {
  final Set<String> codes;
  _Owns(this.codes);

  @override
  Future<WalletState?> build() async => WalletState(
    balance: 0,
    catalog: const [],
    owned: codes,
    equipped: const {},
    history: const [],
  );
}

/// The online host's deal (owner, 2026-10-29): the same cards as offline,
/// the host owns the counts, the server still deals the seats at random.
void main() {
  Future<({List<LobbyBase> bases, List<(OptionalRole, bool)> roles})> pump(
    WidgetTester tester, {
    int players = 10,
    Set<String> owns = const {},
    MatchSettings settings = const MatchSettings(),
    LobbyBase? base,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final bases = <LobbyBase>[];
    final roles = <(OptionalRole, bool)>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletProvider.overrideWith(() => _Owns(owns))],
        child: localizedApp(
          Stack(
            children: [
              OnlineDealPanel(
                visible: true,
                players: players,
                settings: settings,
                base: base,
                onBase: bases.add,
                onRole: (r, on) => roles.add((r, on)),
                onClose: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (bases: bases, roles: roles);
  }

  testWidgets('the host adds a Mafioso: the base moves, citizens follow', (
    tester,
  ) async {
    final out = await pump(tester);
    final rec = BalanceGuard.recommended(10);
    await tester.tap(find.byKey(RoleDealGrid.plus(Role.mafia)));
    expect(out.bases.single, (
      mafia: rec[Role.mafia]! + 1,
      detective: rec[Role.detective] ?? 0,
      doctor: rec[Role.doctor] ?? 0,
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a role not owned is locked; an owned one is switched', (
    tester,
  ) async {
    final out = await pump(tester, owns: {'role_elder'});
    expect(find.byKey(RoleDealGrid.lock(Role.sniper)), findsOneWidget);
    expect(find.byKey(RoleDealGrid.plus(Role.sniper)), findsNothing);
    await tester.ensureVisible(find.byKey(RoleDealGrid.plus(Role.elder)));
    await tester.tap(find.byKey(RoleDealGrid.plus(Role.elder)));
    expect(out.roles.single, (OptionalRole.elder, true));
  });

  testWidgets('the counts shown add up to the table', (tester) async {
    await pump(tester, base: (mafia: 3, detective: 1, doctor: 2));
    var sum = 0;
    for (final r in Role.values) {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(RoleDealGrid.count(r)),
          matching: find.byType(Text),
        ),
      );
      sum += int.parse(text.data!);
    }
    expect(sum, 10);
  });
}
