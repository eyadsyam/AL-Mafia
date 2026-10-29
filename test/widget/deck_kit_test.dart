import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/core/theme/app_colors.dart';
import 'package:mafia_master/ui/economy/mafia_coin.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/deck/deck_public.dart';

import '../support/localized.dart';

/// The deck's buttons (docs/design/DECK-SYSTEM.md): one bone primary the
/// size of home's «ابدأ اللعبة», a silver-rim secondary, gold only with a
/// coin in it.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    localizedApp(
      Scaffold(
        body: Center(child: SizedBox(width: 320, child: child)),
      ),
    ),
  );

  testWidgets('bone is home\'s button: 56 high, parchment fill', (
    tester,
  ) async {
    await pump(tester, BoneButton(label: 'ابدأ', onPressed: () {}));
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      DeckTokens.primaryHeight,
    );
    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    expect(style.backgroundColor!.resolve({}), AppColors.agedParchment);
  });

  testWidgets('a disabled bone says why', (tester) async {
    await pump(
      tester,
      const BoneButton(
        label: 'كمّل',
        onPressed: null,
        disabledReason: 'اكتب اسمك الأول',
      ),
    );
    expect(find.text('اكتب اسمك الأول'), findsOneWidget);
  });

  testWidgets('rim is a 48 dp tap target', (tester) async {
    await pump(tester, RimButton(label: 'قصص', onPressed: () {}));
    expect(
      tester.getSize(find.byType(OutlinedButton)).height,
      greaterThanOrEqualTo(IdentityTokens.target),
    );
  });

  testWidgets('gold always carries the coin', (tester) async {
    await pump(tester, GoldButton(label: 'اشتري بـ 120', onPressed: () {}));
    expect(find.byType(MafiaCoin), findsOneWidget);
  });

  testWidgets('a chip is at least 48 dp', (tester) async {
    await pump(
      tester,
      DeckChip(label: '8', selected: true, onSelected: (_) {}),
    );
    final size = tester.getSize(find.byType(DeckChip));
    expect(size.height, greaterThanOrEqualTo(DeckTokens.chip));
  });
}
