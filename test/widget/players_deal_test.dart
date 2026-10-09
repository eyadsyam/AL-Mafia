import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/widgets/deck/seat_card.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

/// «مين بيلعب؟» (P5): every player a small card dealt into a grid.
void main() {
  const phones = <Size>[Size(360, 640), Size(430, 932)];

  void phone(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<List<List<String>>> pump(
    WidgetTester tester, {
    int players = 0,
    bool still = false,
  }) async {
    final out = <List<String>>[];
    await tester.pumpWidget(
      localizedApp(
        MediaQuery(
          data: MediaQueryData(
            size: tester.view.physicalSize / tester.view.devicePixelRatio,
            disableAnimations: still,
          ),
          child: AddPlayersScreen(
            onBack: () {},
            onNext: out.add,
            initialNames: [for (var i = 1; i <= players; i++) 'P$i'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return out;
  }

  Future<void> add(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.byKey(AddPlayersScreen.addButton));
    await tester.pumpAndSettle();
  }

  Finder next() =>
      find.ancestor(of: find.text('كمل'), matching: find.byType(FilledButton));

  for (final size in phones) {
    for (final n in [5, 10]) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} with $n', (
        tester,
      ) async {
        await loadArtwork(tester);
        phone(tester, size);
        await pump(tester, players: n);
        expect(tester.takeException(), isNull);
        expect(find.byType(SeatCard), findsNWidgets(n));
        expect(find.byType(EmptySeatCard), findsOneWidget);
        expect(find.text('P$n'), findsOneWidget);
      });
    }
  }

  testWidgets('adding with + and with Enter deals a card', (tester) async {
    phone(tester, phones[0]);
    await pump(tester);
    await add(tester, 'Ali');
    expect(find.byType(SeatCard), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Mona');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(SeatCard), findsNWidgets(2));
  });

  testWidgets('removing flies the card out and frees its seat', (tester) async {
    phone(tester, phones[1]);
    await pump(tester, players: 6);
    await tester.tap(find.byKey(const ValueKey('delete_player_2')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('P2'), findsOneWidget, reason: 'still flying out');
    await tester.pumpAndSettle();
    expect(find.text('P2'), findsNothing);
    expect(find.byType(SeatCard), findsNWidgets(5));
  });

  testWidgets('long-press and drag moves a card to another seat', (
    tester,
  ) async {
    phone(tester, phones[1]);
    final out = await pump(tester, players: 6);

    final a = tester.getCenter(find.text('P1'));
    final b = tester.getCenter(find.text('P2'));
    // Seat 1 is at the right in RTL: P2 sits to its left.
    expect(b.dx, lessThan(a.dx));

    final g = await tester.startGesture(a);
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveBy(Offset(b.dx - a.dx, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pumpAndSettle();

    await tester.tap(next());
    await tester.pumpAndSettle();
    expect(out.single, ['P2', 'P1', 'P3', 'P4', 'P5', 'P6']);
  });

  testWidgets('a plain drag does not reorder', (tester) async {
    phone(tester, phones[1]);
    final out = await pump(tester, players: 6);
    await tester.drag(find.text('P1'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(next());
    await tester.pumpAndSettle();
    expect(out.single, ['P1', 'P2', 'P3', 'P4', 'P5', 'P6']);
  });

  testWidgets('reduced motion: cards are simply there', (tester) async {
    phone(tester, phones[0]);
    await pump(tester, players: 5, still: true);
    expect(find.byType(SeatCard), findsNWidgets(5));
    await tester.tap(find.byKey(const ValueKey('delete_player_5')));
    await tester.pump();
    expect(find.text('P5'), findsNothing, reason: 'no fly-out under reduced');
  });

  testWidgets('كمّل is off under 5 and says how many are missing', (
    tester,
  ) async {
    phone(tester, phones[0]);
    await pump(tester);
    await add(tester, 'A');
    await add(tester, 'B');
    expect(tester.widget<FilledButton>(next()).onPressed, isNull);
    expect(find.text('لسه 3'), findsWidgets);
    for (final n in ['C', 'D', 'E']) {
      await add(tester, n);
    }
    expect(tester.widget<FilledButton>(next()).onPressed, isNotNull);
  });

  testWidgets('the empty seat focuses the name field', (tester) async {
    phone(tester, phones[0]);
    await pump(tester);
    await tester.tap(find.byType(EmptySeatCard));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
  });
}
