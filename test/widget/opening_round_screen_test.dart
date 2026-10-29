import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/ui/screens/day/opening_round_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

/// Day 1's «اسم واحد» round (doc 09 §2.2), offline: the speaker names one
/// living player other than themselves; the count runs down and stops at
/// zero without skipping anybody; a new speaker gets the full time again.
void main() {
  const players = [
    PublicPlayer(seat: 0, name: 'سارة', status: PlayerStatus.alive),
    PublicPlayer(seat: 1, name: 'كريم', status: PlayerStatus.alive),
    PublicPlayer(seat: 2, name: 'منى', status: PlayerStatus.dead),
    PublicPlayer(seat: 3, name: 'زياد', status: PlayerStatus.alive),
    PublicPlayer(seat: 4, name: 'هدير', status: PlayerStatus.alive),
  ];
  final perPlayer = MafiaTiming.defaults.openingRoundPerPlayer.inSeconds;

  Future<List<int>> pump(WidgetTester tester, {int seat = 0}) async {
    final named = <int>[];
    await tester.pumpWidget(
      localizedApp(
        OpeningRoundScreen(
          dayNumber: 1,
          currentSeat: seat,
          players: players,
          onAccuse: named.add,
        ),
      ),
    );
    await tester.pump();
    return named;
  }

  testWidgets('the speaker names one of the living others', (tester) async {
    final named = await pump(tester);
    expect(find.text(arStrings.openingRoundPrompt('سارة')), findsOneWidget);
    // Not themselves, not the dead.
    expect(find.text('منى'), findsNothing);
    for (final name in ['كريم', 'زياد', 'هدير']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.text('زياد'));
    expect(named, [3]);
  });

  testWidgets('the count runs down and stops at zero; nobody is skipped', (
    tester,
  ) async {
    final named = await pump(tester);
    expect(find.text('$perPlayer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('${perPlayer - 3}'), findsOneWidget);
    await tester.pump(Duration(seconds: perPlayer + 5));
    expect(find.text('0'), findsOneWidget);
    expect(named, isEmpty);
  });

  testWidgets('the next speaker gets the whole time again', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(seconds: 4));
    await pump(tester, seat: 1);
    expect(find.text(arStrings.openingRoundPrompt('كريم')), findsOneWidget);
    expect(find.text('$perPlayer'), findsOneWidget);
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('كريم'), findsNothing);
  });

  testWidgets('leaving mid-count leaves no timer behind', (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 640), const Size(640, 360)]) {
    testWidgets('fits $size', (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = size;
      addTearDown(tester.view.reset);
      await pump(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
