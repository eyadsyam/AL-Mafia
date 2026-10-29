import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_route.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/widgets/pass_screen.dart';

import '../support/localized.dart';

/// «كارتي» by day, offline: the Elder opens their own card behind the pass
/// gate and reveals from it — once — and every other card keeps the same
/// empty slot where the Elder's button sits, so nothing shows who holds what.
void main() {
  const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  Future<MatchController> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(matchControllerProvider.notifier);
    controller.startMatch(
      names: names,
      roleCounts: const {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.elder: 1,
        Role.citizen: 3,
      },
      settings: const MatchSettings(elderEnabled: true),
      seed: 11,
    );
    controller.adoptMatch(
      controller.engine.match.copyWith(phase: GamePhase.morning),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          Navigator(
            onDidRemovePage: (_) {},
            pages: [
              MaterialPage(
                child: MatchRoute(onExit: () {}, onAnalytics: () {}),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  int seatOf(MatchController c, Role role) =>
      c.engine.match.players.indexWhere((p) => p.role == role);

  Future<void> openCard(WidgetTester tester, int seat) async {
    await tester.tap(find.text(arStrings.myCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(names[seat]).last);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(PassScreen.holdPad)),
    );
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the Elder reveals from their card, once, and weighs three', (
    tester,
  ) async {
    final c = await pump(tester);
    final elder = seatOf(c, Role.elder);
    await openCard(tester, elder);
    expect(find.text(arStrings.elderRevealAction), findsOneWidget);

    await tester.tap(find.text(arStrings.elderRevealAction));
    await tester.pumpAndSettle();
    expect(c.snapshot.revealedElderSeats, {elder});
    expect(c.engine.voteWeightFor(elder), 3);

    // Opened again: the button is spent and says so.
    await openCard(tester, elder);
    final spent = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(arStrings.elderRevealedMark),
        matching: find.byType(FilledButton),
      ),
    );
    expect(spent.onPressed, isNull);
  });

  testWidgets('any other card has no reveal and keeps the same layout', (
    tester,
  ) async {
    final c = await pump(tester);
    await openCard(tester, seatOf(c, Role.elder));
    final elderClose = tester.getRect(find.byIcon(Icons.close));
    // The words differ in length from card to card; what must not differ is
    // the reserved slot under them, where only the Elder has a button.
    double slot(Role role) =>
        844 -
        tester
            .getRect(find.text(EngineCopy.roleDescription(arStrings, role)))
            .bottom;
    final elderSlot = slot(Role.elder);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    for (final role in [Role.mafia, Role.doctor, Role.citizen]) {
      await openCard(tester, seatOf(c, role));
      expect(find.text(arStrings.elderRevealAction), findsNothing);
      expect(find.text(arStrings.elderRevealedMark), findsNothing);
      expect(tester.getRect(find.byIcon(Icons.close)), elderClose);
      expect(slot(role), elderSlot, reason: role.name);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    }
    expect(c.snapshot.revealedElderSeats, isEmpty);
  });
}
