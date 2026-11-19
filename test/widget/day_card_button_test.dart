import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_route.dart';

import '../support/localized.dart';

/// The offline day no longer carries a «كارتي» button: the Elder's reveal moved
/// to his night tile, and the button (offered to everyone so nobody stood out)
/// went with it. The end-match cross stays where it was.
void main() {
  for (final phase in [GamePhase.morning, GamePhase.voting]) {
    testWidgets('there is no card button, only the end cross, in ${phase.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(matchControllerProvider.notifier);
      controller.startMatch(
        names: const ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
        roleCounts: const {
          Role.mafia: 2,
          Role.doctor: 1,
          Role.detective: 1,
          Role.citizen: 3,
        },
        settings: const MatchSettings(),
        seed: 7,
      );
      controller.adoptMatch(controller.engine.match.copyWith(phase: phase));
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

      // The offline day has no «كارتي» button at all (owner, 2026-11-19): the
      // Elder reveals at night, so nothing is left for it to open.
      expect(find.text(arStrings.myCard), findsNothing);
      expect(find.byKey(MatchRoute.endMatchButton), findsOneWidget);
    });
  }
}
