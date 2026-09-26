import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mafia_master/app/app.dart';
import 'package:mafia_master/app/router.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/online_session_store.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/setup/home_screen.dart';
import 'package:mafia_master/ui/widgets/ambient_motion.dart';

import '../support/fake_backend.dart';
import '../support/stores.dart';

/// A browser refresh keeps the URL and drops the session. `/online/lobby`
/// and `/match` used to render on nothing — an empty room that told the host
/// it was waiting for the host, a match flow with no match behind it and a
/// close button in the corner. Observed in Chrome at 390×844 during the
/// section E review (build/review/m-14-after-reload.jpg).
void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester,
    String at, {
    MemoryMatchStore? store,
  }) async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    );
    backend.responses['browse_rooms'] = const {'rooms': []};
    final container = ProviderContainer(
      overrides: [
        matchRepositoryProvider.overrideWithValue(
          MemoryMatchRepository(store ?? returningHostStore()),
        ),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(420, 900));
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
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the lobby without a session lands on the online entry', (
    tester,
  ) async {
    await launch(tester, Routes.lobby);
    expect(find.byType(LobbyScreen), findsNothing);
    expect(find.byType(OnlineEntryScreen), findsOneWidget);
  });

  testWidgets('the lobby with a session is the lobby', (tester) async {
    final container = await launch(tester, Routes.online);
    await container.read(onlineSessionProvider.notifier).host('A');
    expect(container.read(onlineSessionProvider).isInRoom, isTrue);
    GoRouter.of(
      tester.element(find.byType(OnlineEntryScreen)),
    ).go(Routes.lobby);
    // The lobby animates (seat rings); pump a bounded stretch, not to rest.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(LobbyScreen), findsOneWidget);
  });

  testWidgets('the match without a match and without a pointer goes Home', (
    tester,
  ) async {
    await launch(tester, Routes.match);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'the match without a match but with a room to return to offers it',
    (tester) async {
      // The store seeds the mock preferences; the pointer goes in after it.
      final store = returningHostStore();
      await OnlineSessionStore.save(
        const OnlineRoomResume(roomId: 'room-1', code: 'ABCDEF'),
      );
      await launch(tester, Routes.match, store: store);
      expect(find.byType(OnlineEntryScreen), findsOneWidget);
      expect(find.byKey(OnlineEntryScreen.resumeButton), findsOneWidget);
    },
  );
}
