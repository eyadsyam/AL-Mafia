import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/memory_player_group_repository.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/data/player_group_provider.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/screens/setup/group_picker_screen.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:mafia_master/ui/widgets/back_action.dart';

/// UX-2 — saved groups, driven through the app's own router.
///
/// ## The number this file exists to defend
///
/// **A rematch with a known group reaches role distribution in three taps from
/// launch.** Everything else in the feature is in service of it: the picker
/// exists so tap two is a roster, the remembered configuration exists so tap
/// three can be "ابدأ فوراً" instead of a walk through roles and settings.
///
/// A tap-count assertion looks like a strange thing to automate until you
/// notice that every plausible addition to this flow — a confirmation, an
/// "are you sure", a settings review — costs exactly one tap and each one looks
/// harmless on its own. The count is the requirement, so the count is the test.
void main() {
  // Tall enough that nothing needs scrolling to reach.
  const surface = Size(390, 1400);
  const friday = ['Ahmed', 'Fatima', 'Salem', 'Laila', 'Omar', 'Nada'];

  late ProviderContainer container;
  late MemoryPlayerGroupStore groupStore;

  /// Boots the app. Passing an existing [groups] store is a relaunch: the group
  /// bytes survive, the process does not.
  Future<void> pumpApp(
    WidgetTester tester, {
    MemoryPlayerGroupStore? groups,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Tear the old tree down first. Pumping a second `MafiaApp` over the first
    // *updates* it — same widget type, so the element, its `State`, and the
    // router it built are all reused, and the "relaunch" would resume mid-match
    // instead of starting at Home. An empty frame in between is what makes this
    // a process death rather than a rebuild.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    groupStore = groups ?? MemoryPlayerGroupStore();
    container = ProviderContainer(
      overrides: [
        matchRepositoryProvider
            .overrideWithValue(MemoryMatchRepository(MemoryMatchStore())),
        playerGroupRepositoryProvider
            .overrideWithValue(MemoryPlayerGroupRepository(groupStore)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AmbientMotion(
          // The home screen's drifting icons never stop, so `pumpAndSettle`
          // would spin forever on a flow test that has nothing to do with them.
          enabled: false,
          child: MafiaApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterNames(WidgetTester tester, List<String> toAdd) async {
    for (final name in toAdd) {
      await tester.enterText(find.byType(TextField).first, name);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
  }

  /// The full manual setup, ending in a started match, saving the roster as a
  /// group on the way through. This is the *first* night with a new group; the
  /// three-tap path is what every night after it looks like.
  Future<void> firstNight(WidgetTester tester) async {
    await tester.tap(find.text('ابدأ اللعبة'));
    await tester.pumpAndSettle();
    await enterNames(tester, friday);

    // The offer to remember these people, and the name dialog behind it.
    expect(find.byKey(AddPlayersScreen.saveGroupPrompt), findsOneWidget);
    await tester.tap(find.byKey(AddPlayersScreen.saveGroupAccept));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('group_name_field')), 'شلة الجمعة');
    await tester.tap(find.byKey(const ValueKey('group_name_confirm')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AddPlayersScreen.nextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي')); // roles
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ')); // settings → start
    await tester.pumpAndSettle();
  }

  group('the three-tap rematch', () {
    testWidgets('a saved group reaches role distribution in three taps',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);

      // A new evening: the app has been closed and reopened. The match store is
      // fresh, so nothing is offering to resume; the group store is not.
      await pumpApp(tester, groups: groupStore);
      expect(find.byType(HomeScreen), findsOneWidget);

      var taps = 0;

      await tester.tap(find.text('ابدأ اللعبة'));
      taps++;
      await tester.pumpAndSettle();
      expect(find.byType(GroupPickerScreen), findsOneWidget,
          reason: 'a host with saved groups must land on the picker');

      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;
      await tester.tap(find.byKey(GroupPickerScreen.tileFor(group.id)));
      taps++;
      await tester.pumpAndSettle();
      expect(find.byType(AddPlayersScreen), findsOneWidget);
      for (final name in friday) {
        expect(find.text(name), findsOneWidget,
            reason: 'the roster did not arrive pre-filled');
      }

      await tester.tap(find.byKey(AddPlayersScreen.quickStartButton));
      taps++;
      await tester.pumpAndSettle();

      final match =
          container.read(matchControllerProvider.notifier).engine.match;
      expect(match.phase, equals(GamePhase.distributing),
          reason: 'three taps must reach role distribution');
      expect(taps, lessThanOrEqualTo(3),
          reason: 'the rematch budget is three taps from launch. Every '
              'confirmation added to this path costs one of them.');
    });

    testWidgets('the pre-filled roster is in the saved seating order',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;
      await tester.tap(find.byKey(GroupPickerScreen.tileFor(group.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AddPlayersScreen.quickStartButton));
      await tester.pumpAndSettle();

      final match =
          container.read(matchControllerProvider.notifier).engine.match;
      expect(match.players.map((p) => p.name).toList(), orderedEquals(friday),
          reason: 'seat order is the phone-passing order; it may not be '
              're-sorted anywhere between the group and the engine');
      expect(match.players.map((p) => p.seat).toList(),
          equals(List.generate(friday.length, (i) => i)));
    });

    testWidgets('the first night saves the group with its configuration',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);

      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;

      expect(group.name, equals('شلة الجمعة'));
      expect(group.memberNames, orderedEquals(friday));
      expect(group.playCount, equals(1));
      expect(group.canQuickStart, isTrue,
          reason: 'without the remembered configuration the next rematch is '
              'five taps, not three');
    });
  });

  group('first run is unchanged', () {
    testWidgets('a host with no saved groups goes straight to the roster',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();

      expect(find.byType(AddPlayersScreen), findsOneWidget);
      expect(find.byType(GroupPickerScreen), findsNothing,
          reason: 'an empty picker asking a first-run host to choose from '
              'nothing is worse than the screen they used to get');
    });

    testWidgets('the save prompt is not offered for a roster already saved',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);

      // Reach the empty roster screen the long way, then type the same people.
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GroupPickerScreen.newGroupButton));
      await tester.pumpAndSettle();
      await enterNames(tester, friday);

      expect(find.byKey(AddPlayersScreen.saveGroupPrompt), findsNothing,
          reason: 'asking to remember people the app already remembers turns a '
              'helpful prompt into noise');
    });
  });

  group('attendance', () {
    /// Picks the saved group and lands on the pre-filled roster.
    Future<PlayerGroup> openGroup(WidgetTester tester) async {
      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;
      await tester.tap(find.byKey(GroupPickerScreen.tileFor(group.id)));
      await tester.pumpAndSettle();
      return group;
    }

    testWidgets('marking someone away leaves the saved group untouched',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);
      await openGroup(tester);

      // Seat 2 is away tonight.
      await tester.tap(find.byKey(AddPlayersScreen.attendanceToggleFor(2)));
      await tester.pumpAndSettle();

      // Still listed — the whole point. Deleting them would lose the roster
      // this feature exists to keep.
      expect(find.text('Fatima'), findsOneWidget);

      await tester.tap(find.byKey(AddPlayersScreen.nextButton));
      await tester.pumpAndSettle();
      expect(find.byType(RolesScreen), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final match =
          container.read(matchControllerProvider.notifier).engine.match;
      expect(match.players.map((p) => p.name), isNot(contains('Fatima')),
          reason: 'an absent player is not in tonight\'s match');
      expect(match.players, hasLength(friday.length - 1));

      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;
      expect(group.memberNames, orderedEquals(friday),
          reason: 'the saved group must be exactly as it was — a Friday '
              'absence may not cost someone their place on Saturday');
    });

    testWidgets('quick start withdraws when the head count changes',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);
      await openGroup(tester);

      expect(find.byKey(AddPlayersScreen.quickStartButton), findsOneWidget);

      await tester.tap(find.byKey(AddPlayersScreen.attendanceToggleFor(2)));
      await tester.pumpAndSettle();

      expect(find.byKey(AddPlayersScreen.quickStartButton), findsNothing,
          reason: 'a distribution for six does not sum for five. Rather than '
              'silently reshuffling roles, the action withdraws and the roles '
              'screen takes over — which is where that decision belongs.');
    });

    testWidgets('marking someone back present restores quick start',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);
      await openGroup(tester);

      await tester.tap(find.byKey(AddPlayersScreen.attendanceToggleFor(2)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AddPlayersScreen.attendanceToggleFor(2)));
      await tester.pumpAndSettle();

      expect(find.byKey(AddPlayersScreen.quickStartButton), findsOneWidget);
    });

    testWidgets('a guest added for one night is not added to the group',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);
      await openGroup(tester);

      await enterNames(tester, ['Karim']);
      await tester.pumpAndSettle();

      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;
      expect(group.memberNames, isNot(contains('Karim')),
          reason: 'joining the group is a decision taken at the end of the '
              'night, not a side effect of typing a name');
    });
  });

  group('managing groups', () {
    testWidgets('deleting asks first, and a cancelled delete keeps the group',
        (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;

      await tester.longPress(find.byKey(GroupPickerScreen.tileFor(group.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group_action_delete')));
      await tester.pumpAndSettle();

      // The confirmation is not optional: a deleted roster is a minute of
      // typing and the reason the feature exists.
      expect(find.byKey(const ValueKey('group_delete_confirm')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group_delete_cancel')));
      await tester.pumpAndSettle();

      expect(
        await container.read(playerGroupRepositoryProvider).listGroups(),
        hasLength(1),
      );
    });

    testWidgets('a confirmed delete removes the group', (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;

      await tester.longPress(find.byKey(GroupPickerScreen.tileFor(group.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group_action_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group_delete_confirm')));
      await tester.pumpAndSettle();

      expect(
        await container.read(playerGroupRepositoryProvider).listGroups(),
        isEmpty,
      );
      // Nothing left to pick from, so the picker gets out of the way rather
      // than showing an empty list.
      expect(find.byType(AddPlayersScreen), findsOneWidget);
    });

    testWidgets('deleting the last group leaves no trace of it on the roster '
        'screen', (tester) async {
      // Found by running the app, not by the suite. Deleting the last group
      // bounced to the roster screen with the *deleted* group still attached to
      // the draft: its names pre-filled, its attendance toggles, and an
      // "ابدأ فوراً" offering to play a group that no longer existed. Accepting
      // a match-end prompt on it would then have written it straight back.
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      final group = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;

      // Select it first, then go back — this is what leaves it on the draft.
      await tester.tap(find.byKey(GroupPickerScreen.tileFor(group.id)));
      await tester.pumpAndSettle();
      expect(find.byKey(AddPlayersScreen.quickStartButton), findsOneWidget);
      // The app's own back control, not `pageBack()` — these screens use
      // `BackAction`, not a Material `AppBar`.
      await tester.tap(find.byKey(BackAction.button));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(GroupPickerScreen.tileFor(group.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group_action_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group_delete_confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(AddPlayersScreen), findsOneWidget);
      expect(container.read(setupDraftProvider).group, isNull,
          reason: 'a deleted group must not stay attached to the draft');
      expect(find.byKey(AddPlayersScreen.quickStartButton), findsNothing,
          reason: 'the app must not offer to start a match on a group the '
              'host has just deleted');
      for (final name in friday) {
        expect(find.text(name), findsNothing,
            reason: 'the deleted roster is still on screen, which reads as the '
                'delete having failed');
      }
    });

    testWidgets('renaming keeps the roster and the play count', (tester) async {
      await pumpApp(tester);
      await firstNight(tester);
      await pumpApp(tester, groups: groupStore);

      await tester.tap(find.text('ابدأ اللعبة'));
      await tester.pumpAndSettle();
      final before = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;

      await tester.longPress(find.byKey(GroupPickerScreen.tileFor(before.id)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('group_action_rename')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('group_name_field')), 'شلة السبت');
      await tester.tap(find.byKey(const ValueKey('group_name_confirm')));
      await tester.pumpAndSettle();

      final after = (await container
              .read(playerGroupRepositoryProvider)
              .listGroups())
          .single;
      expect(after.name, equals('شلة السبت'));
      expect(after.id, equals(before.id));
      expect(after.memberNames, orderedEquals(friday));
      expect(after.playCount, equals(before.playCount));
      expect(after.canQuickStart, isTrue,
          reason: 'a rename must not cost the group its remembered '
              'configuration and drop the next rematch back to five taps');
    });
  });
}
