import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/economy/pass_table_dress.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/widgets/deck/seat_card.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

/// The host's bought frame reaches their own seat on the one-phone setup
/// screen, matched by the profile name, and nobody else's.
void main() {
  Future<void> pump(WidgetTester tester, {String? frame}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedApp(
        HostIdentityScope(
          hostName: ' Ahmed ',
          frame: frame,
          plate: null,
          child: AddPlayersScreen(
            onBack: () {},
            onNext: (_) {},
            initialNames: const ['Mona', 'ahmed', 'Karim'],
          ),
        ),
      ),
    );
    await loadArtwork(tester);
    await tester.pumpAndSettle();
  }

  FrameStyle? dressOf(WidgetTester tester, String name) {
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byType(SeatCardFrame),
    );
    return tester.widget<SeatCardFrame>(card.first).dress;
  }

  testWidgets('host.seat.wears.the.equipped.frame', (tester) async {
    await pump(tester, frame: 'frame_gilded');
    expect(dressOf(tester, 'ahmed'), same(Cosmetics.frames['frame_gilded']));
    expect(dressOf(tester, 'Mona'), isNull);
    expect(dressOf(tester, 'Karim'), isNull);
  });

  testWidgets('no.frame.equipped.dresses.nobody', (tester) async {
    await pump(tester);
    for (final n in ['Mona', 'ahmed', 'Karim']) {
      expect(dressOf(tester, n), isNull);
    }
  });

  testWidgets('unknown.frame.code.is.ignored', (tester) async {
    await pump(tester, frame: 'frame_from_a_newer_build');
    expect(dressOf(tester, 'ahmed'), isNull);
  });
}
