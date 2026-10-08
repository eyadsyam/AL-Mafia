import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/artwork.dart';
import '../support/localized.dart';
import '../support/reveal_flow.dart';

/// «العب ضد البوتات»: one human at seat 0, six bots. The table must reach a
/// result through the widget tree with only the human's taps.
void main() {
  const surface = Size(390, 844);
  const names = ['إنت', 'أمينة', 'كريم', 'سارة', 'يوسف', 'ليلى', 'حسن'];

  late ProviderContainer container;
  MatchController controller() =>
      container.read(matchControllerProvider.notifier);
  GamePhase phase() => controller().engine.match.phase;
  bool humanTurn() => controller().engine.match.currentActorSeat == 0;

  Future<void> hold(WidgetTester tester) async {
    final pad = find.byType(HoldPad).first;
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(
      MafiaMotion.defaults.dramatic +
          MafiaTiming.defaults.phaseHold +
          MafiaMotion.defaults.dramatic,
    );
    await tester.pumpAndSettle();
  }

  for (final seed in [3, 7, 11, 19, 23, 42]) {
    testWidgets('a match against bots reaches a result (seed $seed)', (
      tester,
    ) async {
      await loadArtwork(tester);
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
        seed: seed,
        botSeats: const {1, 2, 3, 4, 5, 6},
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: MatchFlow(onExit: () {}, onAnalytics: () {}),
            ),
          ),
        ),
      );

      // Only the human's card is dealt by hand.
      expect(phase(), GamePhase.distributing);
      await tester.pumpAndSettle();
      await tester.confirmIdentity(hold: MafiaTiming.defaults.holdToReveal);
      await tester.swipeToFlip();
      await tester.awaitConceal();
      await tester.tap(find.byKey(RoleCard.dismiss));
      await tester.pumpAndSettle();

      var guard = 0;
      while (phase() != GamePhase.result && guard++ < 400) {
        await tester.pumpAndSettle();
        switch (phase()) {
          case GamePhase.night when humanTurn():
            await hold(tester);
            await tester.tap(
              find
                  .byWidgetPredicate(
                    (w) => w is NightGridTile && w.onTap != null,
                  )
                  .first,
            );
            await tester.pump();
            await tester.pump(MafiaTiming.defaults.dwellGate);
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(TurnShell.actionButton));
            await tester.pumpAndSettle();
            await tester.pump(MafiaTiming.defaults.turnFloor);
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(TurnShell.actionButton));
            await tester.pumpAndSettle();
          case GamePhase.morning:
            if (find.text('ابدأ النقاش').evaluate().isNotEmpty) {
              await tester.tap(find.text('ابدأ النقاش'));
            }
            await settle(tester);
          case GamePhase.openingRound when humanTurn():
            await tester.tap(find.byType(PlayerTile).first);
          case GamePhase.confrontation:
            await tester.tap(find.text('خلصت'));
          case GamePhase.discussion:
            // The bots say who they suspect.
            expect(
              find.byKey(const ValueKey('discussion_table_talk')),
              findsOneWidget,
            );
            await tester.tap(find.text('خلص النقاش'));
            await tester.pump();
            await settle(tester);
          case GamePhase.voting when humanTurn():
            await hold(tester);
            await tester.tap(find.byType(PlayerTile).first);
            await tester.pump();
            await tester.tap(find.text('أكد صوتك'));
          case GamePhase.reveal:
            await tester.tap(find.text('كمل'));
          default:
            await settle(tester);
        }
      }
      expect(phase(), GamePhase.result, reason: 'stuck in ${phase()}');
      expect(controller().engine.match.outcome, isNotNull);

      // «ماتش تاني»: a new deal at the same table, on the same screen.
      await tester.pump();
      await tester.pump(MafiaTiming.victoryReveal);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ResultScreen.playAgainKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ResultScreen.playAgainKey));
      await tester.pumpAndSettle();
      expect(phase(), GamePhase.distributing);
      expect(controller().playingWithBots, isTrue);
    });
  }
}
