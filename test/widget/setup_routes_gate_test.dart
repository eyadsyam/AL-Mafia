import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/app/router.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/screens/setup/group_picker_screen.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/artwork.dart';
import '../support/fake_backend.dart';
import '../support/stores.dart';

/// The one-phone setup and match routes need a finished setup, and the players
/// route reopens what the host left rather than the saved roster.
void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester,
    String at, {
    required bool setUp,
    void Function(ProviderContainer)? seed,
  }) async {
    final store = setUp
        ? returningHostStore()
        : (MemoryMatchStore()..onboardingSeen = true);
    if (!setUp) SharedPreferences.setMockInitialValues({});
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    );
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      ],
    );
    addTearDown(container.dispose);
    seed?.call(container);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AmbientMotion(
          enabled: false,
          child: MafiaApp(initialLocation: at),
        ),
      ),
    );
    await loadArtwork(tester);
    await tester.pumpAndSettle();
    return container;
  }

  final five = ['a', 'b', 'c', 'd', 'e'];

  for (final route in [
    Routes.groups,
    Routes.players,
    Routes.roles,
    Routes.settings,
  ]) {
    testWidgets('$route without a finished setup shows first run', (
      tester,
    ) async {
      await launch(
        tester,
        route,
        setUp: false,
        seed: (c) => c.read(setupDraftProvider.notifier).setNames(five),
      );
      expect(find.byKey(FirstRunScreen.screenKey), findsOneWidget);
      expect(find.byType(AddPlayersScreen), findsNothing);
      expect(find.byType(GroupPickerScreen), findsNothing);
      expect(find.byType(RolesScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsNothing);
    });
  }

  testWidgets('players reopens the roster the host left, guests included', (
    tester,
  ) async {
    await launch(
      tester,
      Routes.players,
      setUp: true,
      seed: (c) {
        final n = c.read(setupDraftProvider.notifier);
        n.setRoster(['z', 'a', 'guest', 'b', 'c', 'd'], {'a'});
        n.setNames(['z', 'guest', 'b', 'c', 'd']);
      },
    );
    expect(find.byType(AddPlayersScreen), findsOneWidget);
    final names = ['z', 'a', 'guest', 'b', 'c', 'd'];
    for (final n in names) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
  });

  testWidgets('a Stories link lands on the mode choice while it is closed', (
    tester,
  ) async {
    expect(kOfferStories, isFalse);
    await launch(tester, Routes.stories, setUp: true);
    expect(find.byType(ModeScreen), findsOneWidget);
    expect(find.byType(StoriesScreen), findsNothing);
    expect(find.byKey(ModeScreen.storiesCard), findsNothing);
  });

  testWidgets('roles reopens the split chosen before going back', (
    tester,
  ) async {
    await launch(
      tester,
      Routes.roles,
      setUp: true,
      seed: (c) {
        final n = c.read(setupDraftProvider.notifier);
        n.setNames(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']);
        n.setRoleCounts({
          Role.mafia: 3,
          Role.detective: 1,
          Role.doctor: 1,
          Role.citizen: 3,
        });
      },
    );
    expect(find.byType(RolesScreen), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('roles_citizen_count')))
          .data,
      '3',
    );
  });
}
