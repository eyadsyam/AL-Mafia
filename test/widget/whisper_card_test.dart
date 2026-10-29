import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/whisper_card.dart';

import '../support/localized.dart';

/// An arriving whisper (doc 14 §3.3–3.4): over the table, never instead of it;
/// shown once, then gone — by the button or by the clock, and reported as
/// delivered exactly once either way.
void main() {
  final dwell = MafiaTiming.defaults.whisperCardDwell;

  Future<List<int>> pump(WidgetTester tester) async {
    final dismissed = <int>[];
    await tester.pumpWidget(
      localizedApp(
        Stack(
          children: [
            const Placeholder(),
            WhisperCard(
              senderName: 'كريم',
              body: 'صوّت على زياد',
              onDismissed: () => dismissed.add(1),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return dismissed;
  }

  testWidgets('who sent it and the words, over a live table', (tester) async {
    await pump(tester);
    expect(find.text(arStrings.whisperFromTitle('كريم')), findsOneWidget);
    expect(find.text('صوّت على زياد'), findsOneWidget);
    expect(find.byType(Placeholder), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('the button closes it once', (tester) async {
    final dismissed = await pump(tester);
    await tester.tap(find.byKey(WhisperCard.dismiss));
    await tester.tap(find.byKey(WhisperCard.dismiss));
    await tester.pump(dwell);
    expect(dismissed, [1]);
  });

  testWidgets('left alone it withdraws after its dwell, once', (tester) async {
    final dismissed = await pump(tester);
    await tester.pump(dwell ~/ 2);
    expect(dismissed, isEmpty);
    await tester.pump(dwell ~/ 2);
    expect(dismissed, [1]);
    await tester.tap(find.byKey(WhisperCard.dismiss));
    expect(dismissed, [1]);
  });

  testWidgets('a table that closes first reports nothing', (tester) async {
    final dismissed = await pump(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(dwell * 2);
    expect(dismissed, isEmpty);
  });

  testWidgets('a full hundred and twenty characters fit a small phone', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        WhisperCard(
          senderName: 'اسم طويل شوية للاعب',
          body: 'م' * 120,
          onDismissed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
