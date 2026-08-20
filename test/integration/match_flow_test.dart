import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/localized.dart';
import '../support/reveal_flow.dart';

/// Drives [MatchFlow] the way a table actually would: taps, holds and waits, no
/// direct engine calls after the initial start.
///
/// The point is not to re-test the engine — that is covered by the engine suite
/// — but to prove that the screens are wired to it correctly, that every phase
/// hands off to the next without a dead end, and that a full match can be played
/// with nothing but the widget tree (US1).
void main() {
  const surface = Size(390, 844);
  const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  late ProviderContainer container;
  MatchController controller() => container.read(matchControllerProvider.notifier);

  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    container = ProviderContainer();
    addTearDown(container.dispose);

    controller().startMatch(
      names: names,
      roleCounts: const {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 3,
      },
      settings: const MatchSettings(discussionMode: DiscussionMode.free),
      seed: 7,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(MatchFlow(onExit: () {}, onAnalytics: () {})
        ),
      ),
    );
  }

  /// Completes a hold-to-reveal gesture on the first [HoldPad] on screen.
  Future<void> hold(WidgetTester tester) async {
    final pad = find.byType(HoldPad).first;
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Runs the whole distribution: for each seat, the pass gate, the identity
  /// gate, the swipe that turns the card over, the auto-conceal, and the pass.
  ///
  /// Deliberately walks the real choreography rather than reaching for the
  /// controller. The point of this test is that the flow is playable through
  /// the widget tree alone, and a shortcut past the part a player actually does
  /// would be testing the engine twice instead.
  Future<void> distribute(WidgetTester tester) async {
    // Read from the match rather than hardcoded: the identity hold is a host
    // setting now, and a test that assumed the default would start failing the
    // day somebody changed it for a reason unrelated to this file.
    final identityHold = Duration(
      seconds: controller().engine.match.settings.identityHoldSeconds,
    );

    for (var i = 0; i < names.length; i++) {
      // One gate, not two. Distribution has no separate pass screen — the
      // identity gate *is* the handoff gate, and a second hold before it was
      // the reported "it just loops and nothing happens".
      await tester.pumpAndSettle(); // the frame that draws the role
      await tester.confirmIdentity(hold: identityHold); // step 1
      await tester.swipeToFlip(); // step 2
      await tester.awaitConceal(); // step 3 — and the pass unlocks here
      await tester.tap(find.byKey(RoleCard.dismiss));
      await tester.pumpAndSettle();
    }
  }

  /// Runs one night: every living actor takes the phone, picks the first legal
  /// target, waits out both gates and passes on.
  Future<void> playNight(WidgetTester tester) async {
    await tester.tap(find.text('ابدأ الليل'));
    await tester.pumpAndSettle();

    while (controller().engine.match.phase == GamePhase.night) {
      await hold(tester);

      // Any target will do; the flow is what is under test, not the strategy.
      await tester.tap(find.byType(PlayerTile).first);
      await tester.pump();

      await tester.pump(MafiaTiming.defaults.dwellGate);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pumpAndSettle();

      await tester.pump(MafiaTiming.defaults.turnFloor);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pumpAndSettle();
    }
  }

  /// Runs one day: morning briefing, discussion, then a full ballot.
  Future<void> playDay(WidgetTester tester) async {
    expect(controller().engine.match.phase, GamePhase.morning);
    await tester.tap(find.text('ابدأ النقاش'));
    await tester.pumpAndSettle();

    // A night can end the match. The morning is still announced first (doc 06
    // §4), and only when it is dismissed does the result arrive — so this is
    // the point at which the day may turn out not to happen at all.
    if (controller().engine.match.phase == GamePhase.result) return;

    expect(controller().engine.match.phase, GamePhase.discussion);
    await tester.tap(find.text('إنهاء النقاش'));
    await tester.pumpAndSettle();

    expect(controller().engine.match.phase, GamePhase.voting);
    while (controller().engine.match.phase == GamePhase.voting) {
      await hold(tester); // ballot identity gate
      await tester.tap(find.byType(PlayerTile).first);
      await tester.pump();
      await tester.tap(find.text('تأكيد الصوت'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('a full match is playable through the widget tree alone',
      (WidgetTester tester) async {
    await pumpFlow(tester);

    expect(controller().engine.match.phase, GamePhase.distributing);
    await distribute(tester);
    expect(controller().engine.match.phase, GamePhase.preNightLobby);

    // Bounded so a wiring bug shows up as a failed expectation rather than a
    // hung test.
    var guard = 0;
    while (controller().engine.match.phase != GamePhase.result && guard < 12) {
      guard++;
      await playNight(tester);
      await playDay(tester);

      // Reveal → win check.
      if (controller().engine.match.phase == GamePhase.reveal) {
        await tester.tap(find.text('متابعة'));
        await tester.pumpAndSettle();
      }
    }

    expect(controller().engine.match.phase, GamePhase.result,
        reason: 'the match should reach a result within $guard day cycles');
    expect(controller().engine.match.outcome, isNotNull);

    // The result screen is the only in-flow screen that names roles.
    expect(find.textContaining('كسب'), findsWidgets);
  });

  testWidgets('no screen in the night loop names a role',
      (WidgetTester tester) async {
    await pumpFlow(tester);
    await distribute(tester);

    await tester.tap(find.text('ابدأ الليل'));
    await tester.pumpAndSettle();
    await hold(tester);

    // The four role names must not appear on a night turn. The Detective's own
    // result is the sole exception, and it only exists after a confirm.
    for (final roleName in ['مافيا', 'دكتور', 'محقق', 'مواطن']) {
      expect(find.text(roleName), findsNothing,
          reason: '"$roleName" must not be visible during a night turn');
    }
  });
}
