import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_route.dart';

import '../support/localized.dart';

/// The day's «كارتي» and the match's end cross share a corner in Arabic.
///
/// Drawn on top of each other, the cross took the card's label and its taps:
/// a player reaching for their card got the end-match dialog instead.
void main() {
  for (final phase in [GamePhase.morning, GamePhase.voting]) {
    testWidgets('your card and the end cross both answer in ${phase.name}', (
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

      final card = find.ancestor(
        of: find.text(arStrings.myCard),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      final end = find.byKey(MatchRoute.endMatchButton);
      expect(tester.getRect(card).overlaps(tester.getRect(end)), isFalse);

      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget);
      expect(find.byKey(MatchRoute.endMatchCancel), findsNothing);
    });
  }
}
