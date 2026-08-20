import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/night/night_action_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/pass_screen.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';

import '../support/localized.dart';

/// T049 / L-12 / T6 — the wrong person picking up the phone learns nothing.
///
/// ## The scenario this defends against
///
/// The phone is passed down the table and lands one seat short. Someone who is
/// not the intended actor is now holding it, in the dark, with the screen on.
/// What they can see before they do anything deliberate must be: the name of the
/// person it is for, and nothing else. No role, no target list, no phase detail,
/// no count of anything.
///
/// The gate that enforces this is a *deliberate* action — a sustained hold, not
/// a tap — because the whole point is that content cannot appear by accident.
void main() {
  const surface = Size(390, 844);
  const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  late ProviderContainer container;
  MatchController controller() =>
      container.read(matchControllerProvider.notifier);

  /// Starts a match and parks it on the first night turn's pass screen.
  Future<void> pumpNightHandoff(WidgetTester tester) async {
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
      settings: const MatchSettings(),
      seed: 7,
    );

    // Skip distribution at the engine level; the property under test is the
    // night handoff, and driving fourteen holds first only adds noise.
    final engine = controller().engine;
    while (engine.match.phase == GamePhase.distributing) {
      engine.revealFor(engine.match.currentActorSeat!);
      engine.confirmRevealed();
    }
    controller().adoptMatch(engine.match);
    controller().beginNight();
    controller().openActorTurn();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(MatchFlow(onExit: () {}, onAnalytics: () {})
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Every string currently rendered anywhere in the tree.
  List<String> visibleText(WidgetTester tester) => [
        for (final w in tester.widgetList<Text>(find.byType(Text)))
          if (w.data != null && w.data!.trim().isNotEmpty) w.data!.trim(),
      ];

  group('L-12 the handoff exposes nothing', () {
    testWidgets('a night turn opens on the identity gate, not on content',
        (tester) async {
      await pumpNightHandoff(tester);

      // The shell is in its handoff state: a hold pad and nothing selectable.
      expect(find.byType(HoldPad), findsOneWidget);
      expect(find.byType(PlayerTile), findsNothing,
          reason: 'the target list is visible before anyone identified '
              'themselves');
    });

    testWidgets('no role name and no prompt is on screen before the hold',
        (tester) async {
      await pumpNightHandoff(tester);
      final text = visibleText(tester);

      for (final roleWord in ['مافيا', 'دكتور', 'محقق', 'مواطن']) {
        expect(text, isNot(contains(roleWord)),
            reason: '"$roleWord" was visible to whoever is holding the phone');
      }

      for (final role in Role.values) {
        expect(text, isNot(contains(EngineCopy.nightPrompt(arStrings, role))),
            reason: 'the ${role.name} question was on screen before the gate');
      }
    });

    testWidgets('the screen looks the same regardless of whose turn it is',
        (tester) async {
      // The only thing that may differ between two handoffs is the name. If
      // anything else changed, the person holding the phone could tell whose
      // turn — and eventually which role — is coming up.
      await pumpNightHandoff(tester);
      final first = visibleText(tester);
      final firstSeat = controller().engine.match.currentActorSeat!;

      // Advance to the next actor and re-render.
      controller().submitNightAction(
        kind: nightActionFor(
            controller().engine.match.players[firstSeat].role),
        targetSeat: controller()
            .engine
            .match
            .players
            .firstWhere((p) => p.seat != firstSeat)
            .seat,
      );
      controller().passTurn();
      controller().openActorTurn();
      await tester.pumpAndSettle();

      final second = visibleText(tester);
      final secondSeat = controller().engine.match.currentActorSeat!;

      // Drop the one legitimately different item: the recipient's name.
      final firstWithoutName = [...first]
        ..remove(controller().engine.match.players[firstSeat].name);
      final secondWithoutName = [...second]
        ..remove(controller().engine.match.players[secondSeat].name);
      expect(secondWithoutName, equals(firstWithoutName));
    });

    testWidgets('"not you?" is offered and exposes nothing when taken',
        (tester) async {
      var rerouted = false;

      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        localizedApp(PassScreen(
            targetName: 'Fatima',
            subtitle: 'الليلة الأولى',
            onConfirmed: () {},
            onWrongPerson: () => rerouted = true,
          )
        ),
      );

      expect(find.byKey(PassScreen.wrongPerson), findsOneWidget);
      await tester.tap(find.byKey(PassScreen.wrongPerson));
      await tester.pumpAndSettle();

      expect(rerouted, isTrue);
      // Taking the escape hatch must not have revealed anything on the way out.
      expect(find.byType(PlayerTile), findsNothing);
      final text = visibleText(tester);
      for (final roleWord in ['مافيا', 'دكتور', 'محقق', 'مواطن']) {
        expect(text, isNot(contains(roleWord)));
      }
    });

    testWidgets('a tap cannot open the turn — only a sustained hold can',
        (tester) async {
      await pumpNightHandoff(tester);

      await tester.tap(find.byType(HoldPad));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerTile), findsNothing,
          reason: 'a stray tap revealed the turn');

      // A hold that is released early must not count either.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(HoldPad)));
      await tester.pump(MafiaTiming.defaults.holdToReveal ~/ 2);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(PlayerTile), findsNothing,
          reason: 'an abandoned hold revealed the turn');

      // The full hold does open it — otherwise this test proves nothing.
      final full =
          await tester.startGesture(tester.getCenter(find.byType(HoldPad)));
      await tester.pump();
      await tester.pump(MafiaTiming.defaults.holdToReveal);
      await full.up();
      await tester.pumpAndSettle();
      expect(find.byType(PlayerTile), findsWidgets);
    });

    testWidgets('the target list is identical for every role', (tester) async {
      // Once the right person has identified themselves, what they see must
      // still not distinguish them: same seats, same order, same tile states.
      await pumpNightHandoff(tester);
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(HoldPad)));
      await tester.pump();
      await tester.pump(MafiaTiming.defaults.holdToReveal);
      await gesture.up();
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<PlayerTile>(find.byType(PlayerTile));
      expect(tiles, hasLength(names.length - 1));
      // Nothing on a tile may encode a role; the indicator slot is the only
      // data-bearing part and it is empty for everyone but a mafioso.
      final shellRole = controller().engine.match.players[
          controller().engine.match.currentActorSeat!].role;
      if (shellRole != Role.mafia) {
        expect(tiles.every((t) => t.indicatorCount == 0), isTrue);
      }
    });
  });
}
