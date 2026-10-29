import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/coin_win.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

/// The coins won: the number counts up to the full amount, says it once to a
/// screen reader, and hands back exactly once — moving or reduced.
void main() {
  Future<List<int>> pump(WidgetTester tester, {bool reduced = false}) async {
    final done = <int>[];
    await tester.pumpWidget(
      localizedApp(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: CoinWinReveal(amount: 40, onDone: () => done.add(1)),
          ),
        ),
      ),
    );
    return done;
  }

  String shown(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(CoinWinReveal.valueKey)).data!;

  testWidgets('counts up to the amount, then hands back once', (tester) async {
    final done = await pump(tester);
    expect(shown(tester), '+0');
    await tester.pump(WinTokens.reveal * WinTokens.countShare);
    expect(shown(tester), '+40');
    expect(done, isEmpty);
    await tester.pumpAndSettle();
    expect(done, [1]);
    await tester.pump(WinTokens.hold);
    expect(done, [1]);
  });

  testWidgets('reduced motion shows the whole amount and holds still', (
    tester,
  ) async {
    final done = await pump(tester, reduced: true);
    await tester.pump();
    expect(shown(tester), '+40');
    await tester.pump(WinTokens.hold);
    expect(done, [1]);
  });

  testWidgets('says the amount once as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      find.bySemanticsLabel(arStrings.dailyCofferGranted(40)),
      findsOneWidget,
    );
    handle.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('leaving early never calls back into a gone screen', (
    tester,
  ) async {
    final done = await pump(tester, reduced: true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(WinTokens.hold);
    expect(done, isEmpty);
  });
}
