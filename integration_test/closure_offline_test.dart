import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mafia_master/main.dart' as app;
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/app/resume_gate.dart';
import 'package:mafia_master/engine/models/enums.dart' as game;
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/screens/setup/group_picker_screen.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/screens/onboarding/onboarding_video_screen.dart';
import 'package:mafia_master/ui/screens/setup/how_to_play_screen.dart';
import 'package:mafia_master/ui/screens/day/voting_screen.dart';
import 'package:mafia_master/ui/screens/day/discussion_screen.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real offline setup to victory, with private reveal and two nights',
    (tester) async {
      await app.main();
      Future<void> pause([int ms = 700]) =>
          tester.pump(Duration(milliseconds: ms));
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
          await pause(250);
        }
        expect(finder, findsWidgets);
      }

      Future<void> tap(Finder finder) async {
        await waitFor(finder);
        await tester.tap(finder.first);
        await pause();
      }

      Future<void> hold(Finder finder) async {
        await waitFor(finder);
        final g = await tester.startGesture(tester.getCenter(finder.first));
        await pause(2000);
        await g.up();
        await pause();
      }

      await waitFor(find.byType(MafiaApp));
      for (var i = 0; i < 80; i++) {
        final endMatch = find.byKey(ResumeGate.endButton).hitTestable();
        final skipOnboarding = find
            .byKey(OnboardingVideoScreen.skipButton)
            .hitTestable();
        final startFromRules = find
            .byKey(HowToPlayScreen.startButton)
            .hitTestable();
        final startHome = find.byKey(HomeScreen.startButton).hitTestable();
        final playOffline = find.byKey(ModeScreen.offlineCard).hitTestable();
        if (endMatch.evaluate().isNotEmpty) {
          await tap(endMatch);
        } else if (skipOnboarding.evaluate().isNotEmpty) {
          await tap(skipOnboarding);
        } else if (startFromRules.evaluate().isNotEmpty) {
          await tap(startFromRules);
        } else if (playOffline.evaluate().isNotEmpty) {
          await tap(playOffline);
        } else if (find.byType(AddPlayersScreen).evaluate().isNotEmpty ||
            find.byType(GroupPickerScreen).evaluate().isNotEmpty) {
          break;
        } else if (startHome.evaluate().isNotEmpty) {
          await tap(startHome);
        } else {
          await pause(250);
        }
      }
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(MafiaApp)),
      );
      MatchController controller() =>
          scope.read(matchControllerProvider.notifier);
      expect(
        find.byType(AddPlayersScreen).evaluate().isNotEmpty ||
            find.byType(GroupPickerScreen).evaluate().isNotEmpty,
        isTrue,
      );
      if (find.text('مجموعة جديدة').evaluate().isNotEmpty) {
        await tap(find.text('مجموعة جديدة'));
      }
      const names = ['اياد', 'نور', 'عمر', 'سارة', 'يوسف', 'ملك', 'آدم'];
      for (final name in names) {
        await tester.enterText(find.byType(TextField).first, name);
        await tap(find.byKey(AddPlayersScreen.addButton));
      }
      await tap(find.byKey(AddPlayersScreen.nextButton));
      await waitFor(find.byType(RolesScreen));
      await tap(
        find.descendant(
          of: find.byKey(RolesScreen.stepper(game.Role.mafia)),
          matching: find.byIcon(Icons.remove),
        ),
      );
      await tap(find.byKey(RolesScreen.nextButton));
      await waitFor(find.byType(SettingsScreen));
      await tap(find.byKey(SettingsScreen.saveButton));
      for (var i = 0; i < names.length; i++) {
        await hold(find.byKey(RoleCard.holdPad));
        final card = find.byKey(RoleCard.slotCard);
        await tester.drag(card, const Offset(220, 0));
        await pause(700);
        await pause(5000);
        await tap(find.byKey(RoleCard.dismiss));
      }
      expect(find.text('الليل يقترب'), findsNothing);
      for (
        var cycle = 0;
        cycle < 5 && controller().engine.match.phase != game.GamePhase.result;
        cycle++
      ) {
        final match = controller().engine.match;
        final mafia = match.players
            .firstWhere((p) => p.role == game.Role.mafia)
            .seat;
        final victim = match.players
            .firstWhere(
              (p) =>
                  p.role == game.Role.citizen &&
                  p.status == game.PlayerStatus.alive,
            )
            .seat;
        while (controller().engine.match.phase == game.GamePhase.night) {
          final actor = controller().engine.match.currentActorSeat!;
          final role = controller().engine.match.players[actor].role;
          await hold(find.byKey(TurnShell.holdPad));
          final target = role == game.Role.mafia
              ? victim
              : role == game.Role.doctor && cycle == 0
              ? actor
              : mafia;
          await tap(find.byKey(NightGrid.tile(target)));
          await pause(8500);
          await tap(find.byKey(TurnShell.actionButton));
          await pause(MafiaTiming.defaults.turnFloor.inMilliseconds);
          await tap(find.byKey(TurnShell.actionButton));
        }
        await pause(5000);
        await tap(find.text('ابدأ النقاش'));
        if (controller().engine.match.phase == game.GamePhase.result) break;
        while (controller().engine.match.phase == game.GamePhase.openingRound) {
          await tap(find.byType(PlayerTile).first);
        }
        if (controller().engine.match.phase == game.GamePhase.confrontation) {
          await tap(find.text('خلصت'));
        }
        for (
          var i = 0;
          i < 100 &&
              controller().engine.match.phase == game.GamePhase.discussion;
          i++
        ) {
          final skipDiscussion = find
              .byKey(DiscussionScreen.skipButton)
              .hitTestable();
          if (skipDiscussion.evaluate().isNotEmpty) {
            await tester.tap(skipDiscussion);
            await pause();
          } else {
            await pause(250);
          }
        }
        await pause(5000);
        final voted = cycle == 0
            ? controller().engine.match.players
                  .firstWhere(
                    (p) =>
                        p.role == game.Role.citizen &&
                        p.status == game.PlayerStatus.alive,
                  )
                  .seat
            : mafia;
        while (controller().engine.match.phase == game.GamePhase.voting) {
          await hold(find.byType(HoldPad).first);
          final name = controller().engine.match.players[voted].name;
          final target = find.widgetWithText(PlayerTile, name);
          await tap(
            target.evaluate().isEmpty ? find.byType(PlayerTile).first : target,
          );
          await tap(find.byKey(VotingScreen.confirmButton));
        }
        if (controller().engine.match.phase == game.GamePhase.reveal) {
          await tap(find.text('كمل'));
        }
      }
      expect(controller().engine.match.phase, game.GamePhase.result);
      expect(controller().engine.match.dayNumber, greaterThanOrEqualTo(2));
      await pause(6500);
      await tap(find.text('التحليلات'));
      await scope.read(audioDirectorProvider).backend.dispose();
      await pause();
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
