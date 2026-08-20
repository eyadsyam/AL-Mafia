import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_route.dart';

import '../support/localized.dart';

/// T051 / L-15 — the back gesture cannot leave a match; only "End match" can.
///
/// ## Why this is a leakage test and not a navigation nicety
///
/// A back gesture during the night is nearly always accidental — a thumb on the
/// screen edge while the phone is held at an angle to keep it private. If it
/// popped the route, the actor would be dropped mid-turn and the app would
/// surface whatever is underneath, in front of whoever happens to be looking.
/// So the route refuses to pop, and leaving requires a deliberate, named,
/// confirmed action (FR-027).
void main() {
  late ProviderContainer container;

  MatchController controller() =>
      container.read(matchControllerProvider.notifier);

  /// Mounts [MatchRoute] under a navigator, with a match parked in [phase].
  Future<int> pumpMatch(
    WidgetTester tester, {
    required GamePhase phase,
    required VoidCallback onExit,
  }) async {
    container = ProviderContainer();
    addTearDown(container.dispose);

    controller().startMatch(
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
    controller().adoptMatch(
      controller().engine.match.copyWith(phase: phase, currentActorSeat: 0),
    );

    var popCount = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(Navigator(
            onPopPage: (route, result) {
              popCount++;
              return route.didPop(result);
            },
            pages: [
              MaterialPage(
                child: MatchRoute(onExit: onExit, onAnalytics: () {}),
              ),
            ],
          )
        ),
      ),
    );
    await tester.pumpAndSettle();
    return popCount;
  }

  group('L-15 back is suppressed during play', () {
    for (final phase in [
      GamePhase.distributing,
      GamePhase.night,
      GamePhase.voting,
      GamePhase.reveal,
    ]) {
      testWidgets('a back gesture in ${phase.name} does not leave the match',
          (tester) async {
        var exited = false;
        await pumpMatch(tester, phase: phase, onExit: () => exited = true);

        // `PopScope(canPop: false)` is what the framework consults; asserting on
        // it directly is more honest than simulating a platform back event,
        // which the test binding routes differently on each platform.
        final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
        expect(popScope.canPop, isFalse,
            reason: 'back is poppable during ${phase.name}');
        expect(exited, isFalse);
      });
    }

    testWidgets('back works again once the match is over', (tester) async {
      await pumpMatch(tester, phase: GamePhase.result, onExit: () {});
      final popScope = tester.widget<PopScope>(find.byType(PopScope).first);
      expect(popScope.canPop, isTrue,
          reason: 'there is nothing left to protect after the result screen');
    });

    test('MatchRoute.isLocked matches the phases that need protecting', () {
      for (final phase in GamePhase.values) {
        final locked = MatchRoute.isLocked(phase);
        final expected =
            phase != GamePhase.result && phase != GamePhase.analytics;
        expect(locked, equals(expected), reason: '$phase');
      }
    });
  });

  group('L-15 the End-match escape hatch', () {
    testWidgets('is present during play and confirms before exiting',
        (tester) async {
      var exited = false;
      await pumpMatch(
        tester,
        phase: GamePhase.night,
        onExit: () => exited = true,
      );

      expect(find.byKey(MatchRoute.endMatchButton), findsOneWidget);
      await tester.tap(find.byKey(MatchRoute.endMatchButton));
      await tester.pumpAndSettle();

      // A confirm step exists, and backing out of it keeps the match running.
      expect(find.byKey(MatchRoute.endMatchCancel), findsOneWidget);
      await tester.tap(find.byKey(MatchRoute.endMatchCancel));
      await tester.pumpAndSettle();
      expect(exited, isFalse,
          reason: 'cancelling the dialog still ended the match');

      // Confirming does exit.
      await tester.tap(find.byKey(MatchRoute.endMatchButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(MatchRoute.endMatchConfirm));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });

    testWidgets('the dialog says what will be lost', (tester) async {
      await pumpMatch(tester, phase: GamePhase.night, onExit: () {});
      await tester.tap(find.byKey(MatchRoute.endMatchButton));
      await tester.pumpAndSettle();

      // A bare "are you sure?" is not enough: the host is about to discard a
      // match that will not appear in history.
      expect(find.textContaining('السجل'), findsOneWidget);
    });

    testWidgets('the escape hatch disappears once the match is over',
        (tester) async {
      await pumpMatch(tester, phase: GamePhase.result, onExit: () {});
      expect(find.byKey(MatchRoute.endMatchButton), findsNothing);
    });
  });
}
