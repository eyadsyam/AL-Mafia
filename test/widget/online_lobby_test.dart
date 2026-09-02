import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/widgets/connection_banner.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// S-20 and S-21, against a backend that is not there.
///
/// Every one of these is a doc 11 §6 case that a player actually sees: a code
/// that does not exist, a room that is full, a server that is asleep, a host
/// who has not started yet. They are about *copy and affordances*, which is why
/// they are widget tests — the transport's half of the same cases is in
/// `test/transport/online_transport_test.dart`.
void main() {
  late FakeBackend backend;

  ProviderContainer containerWith({
    RoomState? state,
    List<RoomPlayer>? players,
    OwnSeat? own,
    String userId = 'u0',
    BackendException? refuseJoin,
  }) {
    backend = FakeBackend(
      roomId: 'room-1',
      state: state ?? roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: players ?? roster(3),
      own: own ?? const OwnSeat(seat: 0),
      userId: userId,
    );
    if (refuseJoin != null) {
      backend.refusals['joinRoom'] = refuseJoin;
      backend.stickyRefusals.add('joinRoom');
    }
    final container = ProviderContainer(overrides: [
      onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      // No periodic beat: a widget test that left one running would fail on a
      // pending timer, and nothing on these screens is driven by it.
      onlineHeartbeatProvider.overrideWithValue(Duration.zero),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpLobby(WidgetTester tester, ProviderContainer container) async {
    await container.read(onlineSessionProvider.notifier).host('A');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(LobbyScreen(onStarted: () {}, onLeave: () {})),
      ),
    );
    await tester.pump();
  }

  group('S-21 the lobby', () {
    testWidgets('shows the room code, the roster and the headphones line',
        (tester) async {
      final container = containerWith();
      await pumpLobby(tester, container);

      expect(find.byKey(LobbyScreen.codeText), findsOneWidget);
      expect(
        (tester.widget(find.byKey(LobbyScreen.codeText)) as Text).data,
        equals('ABCDEF'),
      );
      expect(find.byKey(LobbyScreen.seatTile(0)), findsOneWidget);
      expect(find.byKey(LobbyScreen.seatTile(2)), findsOneWidget);
      // V7 — two players in one room is a feedback loop, and the fix is a
      // sentence rather than an echo canceller.
      expect(find.byKey(LobbyScreen.headphonesWarning), findsOneWidget);
      expect(find.text(arStrings.onlineHeadphonesWarning), findsOneWidget);
    });

    testWidgets('offers the host a start, and refuses it under five players',
        (tester) async {
      final container = containerWith();
      await pumpLobby(tester, container);

      final button = tester.widget<FilledButton>(
        find.byKey(LobbyScreen.startButton),
      );
      expect(button.onPressed, isNull, reason: 'three players is not a match');
      expect(find.text(arStrings.onlineNeedFivePlayers), findsOneWidget);
    });

    testWidgets('lets the host start once the table is big enough',
        (tester) async {
      final container = containerWith(players: roster(6));
      await pumpLobby(tester, container);

      final button = tester.widget<FilledButton>(
        find.byKey(LobbyScreen.startButton),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text(arStrings.onlineStartMatch), findsOneWidget);
    });

    testWidgets('a guest waits for the host and is offered nothing to press',
        (tester) async {
      final container = containerWith(
        userId: 'u2',
        state: roomState(
          phase: 'lobby',
          phaseNumber: 0,
          status: 'lobby',
          hostId: 'u0',
        ),
        own: const OwnSeat(seat: 2),
        players: roster(6),
      );
      await pumpLobby(tester, container);

      expect(find.byKey(LobbyScreen.startButton), findsNothing);
      expect(find.text(arStrings.onlineWaitingForHost), findsOneWidget);
    });

    testWidgets('marks a player who has dropped', (tester) async {
      final container = containerWith(
        players: [
          ...roster(2),
          RoomPlayer(
            userId: 'u2',
            seat: 2,
            name: 'C',
            connected: false,
            lastSeen: DateTime.utc(2026, 9, 2, 11),
          ),
        ],
      );
      await pumpLobby(tester, container);

      expect(find.text(arStrings.onlineNotConnected), findsOneWidget);
    });

    testWidgets('the banner is silent while the link is good', (tester) async {
      final container = containerWith();
      await pumpLobby(tester, container);

      expect(find.byKey(ConnectionBanner.bannerKey), findsNothing);
    });
  });

  group('S-20 joining', () {
    Future<void> pumpEntry(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineEntryScreen(onJoined: () {}, onPlayOffline: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> attemptJoin(WidgetTester tester) async {
      await tester.enterText(find.byKey(OnlineEntryScreen.nameField), 'A');
      await tester.enterText(find.byKey(OnlineEntryScreen.codeField), 'ABCDEF');
      await tester.pump();
      await tester.tap(find.byKey(OnlineEntryScreen.joinButton));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('O14 — a code with no room behind it says so', (tester) async {
      final container = containerWith(
        refuseJoin: const BackendException('ROOM_NOT_FOUND', 'no'),
      );
      await pumpEntry(tester, container);
      await attemptJoin(tester);

      expect(find.text(arStrings.onlineRoomNotFound), findsOneWidget);
    });

    testWidgets('O15 — a full room says so', (tester) async {
      final container = containerWith(
        refuseJoin: const BackendException('ROOM_FULL', 'full'),
      );
      await pumpEntry(tester, container);
      await attemptJoin(tester);

      expect(find.text(arStrings.onlineRoomFull), findsOneWidget);
    });

    testWidgets('O9 — an unreachable server offers offline instead',
        (tester) async {
      final container = containerWith();
      backend.unreachable = true;
      await pumpEntry(tester, container);
      await attemptJoin(tester);

      expect(find.text(arStrings.onlineUnreachable), findsOneWidget);
      expect(find.byKey(OnlineEntryScreen.offlineButton), findsOneWidget);
    });

    testWidgets('O11 — a paused project is its own sentence', (tester) async {
      final container = containerWith();
      backend
        ..unreachable = true
        ..projectPaused = true;
      await pumpEntry(tester, container);
      await attemptJoin(tester);

      expect(find.text(arStrings.onlineProjectPaused), findsOneWidget);
    });

    testWidgets('neither action is offered without a name', (tester) async {
      final container = containerWith();
      await pumpEntry(tester, container);

      expect(
        tester
            .widget<OutlinedButton>(find.byKey(OnlineEntryScreen.hostButton))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(OnlineEntryScreen.joinButton))
            .onPressed,
        isNull,
      );
    });
  });
}
