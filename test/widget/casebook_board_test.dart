import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/mafia_coin.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/missions/casebook_data.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';
import 'package:mafia_master/ui/widgets/case_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/casebook_fixture.dart';
import '../support/localized.dart';

/// Takes a daily case for real: the note turns «claimed» the way the server's
/// hub would say it, so the stamp has something to land on.
class _ClosingCasebook extends FakeCasebookController {
  @override
  Future<CaseGrant> claimMission({
    required bool weekly,
    required int slot,
  }) async {
    final grant = await super.claimMission(weekly: weekly, slot: slot);
    final raw = casebookJson();
    final missions = (raw['daily'] as Map)['missions'] as List;
    (missions[slot] as Map)['claimed'] = true;
    (missions[slot] as Map)['claimable'] = false;
    state = AsyncData(Casebook.fromJson(raw));
    return grant;
  }
}

class _Wallet extends WalletController {
  @override
  Future<WalletState?> build() async => const WalletState(
    balance: 340,
    catalog: [],
    owned: {},
    equipped: {},
    history: [],
  );
}

void main() {
  Future<_ClosingCasebook> pump(
    WidgetTester tester,
    Size size, {
    bool reduced = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _ClosingCasebook();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const sheet = Scaffold(body: CasebookSheet());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          casebookProvider.overrideWith(() => fake),
          walletProvider.overrideWith(_Wallet.new),
        ],
        child: localizedApp(
          reduced
              ? Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: true),
                    child: sheet,
                  ),
                )
              : sheet,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  for (final size in const [Size(360, 640), Size(430, 932)]) {
    testWidgets('the board and its pill fit ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      await pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.byKey(CasebookSheet.boardKey), findsOneWidget);
      expect(find.byKey(CasebookSheet.pillKey), findsOneWidget);
      expect(find.text('340'), findsOneWidget);
    });
  }

  testWidgets(
    'a taken case is stamped «اتقفلت» and its coins fly to the pill',
    (tester) async {
      final fake = await pump(tester, const Size(360, 800));
      await tester.tap(find.byKey(CasebookSheet.claimKey('d1')));
      await tester.pump();
      await tester.pump();
      // Mid-air: coins are drawn over the board.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MafiaCoin), findsWidgets);
      await tester.pumpAndSettle();
      expect(fake.claims, ['daily:1']);
      expect(find.byKey(CasebookSheet.stampKey('d1')), findsOneWidget);
      expect(find.byType(CaseStamp), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced motion: the stamp is there at once, nothing flies', (
    tester,
  ) async {
    await pump(tester, const Size(360, 800), reduced: true);
    await tester.tap(find.byKey(CasebookSheet.claimKey('d1')));
    await tester.pump();
    await tester.pump();
    final stamp = find.descendant(
      of: find.byKey(CasebookSheet.stampKey('d1')),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(stamp).opacity, 1);
    expect(tester.takeException(), isNull);
  });
}
