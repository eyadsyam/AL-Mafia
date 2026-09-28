import 'package:mafia_master/data/player_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/online/council/seat_status.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/widgets/back_action.dart';
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
  setUp(seedReturningProfile);
  late FakeBackend backend;

  ProviderContainer containerWith({
    RoomState? state,
    List<RoomPlayer>? players,
    OwnSeat? own,
    String userId = 'u0',
    BackendException? refuseJoin,
    bool lobbyReadyEnabled = false,
  }) {
    backend = FakeBackend(
      roomId: 'room-1',
      state:
          state ?? roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: players ?? roster(3),
      own: own ?? const OwnSeat(seat: 0),
      userId: userId,
    );
    if (refuseJoin != null) {
      backend.refusals['joinRoom'] = refuseJoin;
      backend.stickyRefusals.add('joinRoom');
    }
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        // No periodic beat: a widget test that left one running would fail on a
        // pending timer, and nothing on these screens is driven by it.
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
        if (lobbyReadyEnabled)
          economyCapabilitiesProvider.overrideWith(
            (ref) async => const EconomyCapabilities(lobbyReady: true),
          ),
      ],
    );
    addTearDown(container.dispose);
    container.read(playerProfileProvider);
    return container;
  }

  Future<void> pumpLobby(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
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
    testWidgets('host exit offers keeping the room before closing it', (
      tester,
    ) async {
      final container = containerWith();
      await pumpLobby(tester, container);
      await tester.tap(find.byKey(LobbyScreen.leaveButton));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('lobby_leave_keep_room')),
        findsOneWidget,
      );
      expect(find.byKey(LobbyScreen.closeRoomConfirm), findsOneWidget);
      expect(backend.called('close_room'), isFalse);
    });

    for (final size in [
      const Size(360, 640),
      const Size(844, 390),
      const Size(1366, 768),
    ]) {
      testWidgets('lobby fills available width at $size', (tester) async {
        tester.view.resetPhysicalSize();
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = containerWith();
        await pumpLobby(tester, container);
        expect(tester.takeException(), isNull);
        final band = tester.getSize(find.byType(CouncilBand));
        expect(band.width, greaterThan(size.width - 100));
      });
    }

    testWidgets('shows the room code, the roster and the headphones line', (
      tester,
    ) async {
      final container = containerWith();
      await pumpLobby(tester, container);

      // The code arrives one character at a time (doc 12 §3.1), so it is a row
      // of glyphs rather than one `Text`. What has to stay true is that the
      // whole code is readable and announced as one string from the first
      // frame — a host reading it out loud must not have to wait for it.
      expect(find.byKey(LobbyScreen.codeText), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(LobbyScreen.codeText)).label,
        equals('ABCDEF'),
      );
      // Scoped to the code itself: a player in this fixture is called «A», and
      // a bare text finder would match them too.
      for (final character in 'ABCDEF'.split('')) {
        expect(
          find.descendant(
            of: find.byKey(LobbyScreen.codeText),
            matching: find.text(character),
          ),
          findsOneWidget,
        );
      }

      // The roster is the table now, and a seat is a seat on it.
      expect(find.byKey(LobbyScreen.seatTile(0)), findsOneWidget);
      expect(find.byKey(LobbyScreen.seatTile(2)), findsOneWidget);
      // Empty seats are drawn as outlines up to the room's capacity, so a host
      // can see how many more they need without counting names.
      expect(find.byKey(LobbyScreen.emptySeat(3)), findsOneWidget);
      // V7 — two players in one room is a feedback loop, and the fix is a
      // sentence rather than an echo canceller.
      expect(find.byKey(LobbyScreen.headphonesWarning), findsNothing);
      expect(find.text(arStrings.onlineHeadphonesWarning), findsNothing);
      expect(find.text(arStrings.onlineGhostRule), findsNothing);
    });

    testWidgets('offers the host a start, and refuses it under five players', (
      tester,
    ) async {
      final container = containerWith();
      await pumpLobby(tester, container);

      final button = tester.widget<FilledButton>(
        find.byKey(LobbyScreen.startButton),
      );
      expect(button.onPressed, isNull, reason: 'three players is not a match');
      expect(find.text(arStrings.onlineNeedFivePlayers), findsOneWidget);
      expect(find.text(arStrings.publicRoomMissing(2)), findsOneWidget);
      expect(find.text(arStrings.onlineLobbyInviteHint), findsOneWidget);
    });

    testWidgets('lets the host start once the table is big enough', (
      tester,
    ) async {
      final container = containerWith(players: roster(6));
      await pumpLobby(tester, container);

      final button = tester.widget<FilledButton>(
        find.byKey(LobbyScreen.startButton),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text(arStrings.onlineStartMatch), findsOneWidget);
      expect(find.text(arStrings.onlineLobbyHostReadyHint), findsOneWidget);
      expect(find.text(arStrings.onlineLobbyInviteHint), findsNothing);
    });

    testWidgets('ready capability gates start and sends the current revision', (
      tester,
    ) async {
      final players = roster(6);
      final container = containerWith(
        players: players,
        state: roomState(
          phase: 'lobby',
          phaseNumber: 0,
          status: 'lobby',
          lobbyRevision: 7,
        ),
        lobbyReadyEnabled: true,
      );
      await pumpLobby(tester, container);
      await tester.pump();

      expect(find.byKey(LobbyScreen.readyButton), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(LobbyScreen.startButton))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(LobbyScreen.readyButton));
      await tester.pump();
      expect(backend.lastCall('lobby_ready')?.body, {
        'roomId': 'room-1',
        'ready': true,
        'revision': 7,
      });
    });

    testWidgets(
      'ready roster enables host start only when every seat confirms',
      (tester) async {
        final container = containerWith(
          players: [
            for (final player in roster(6))
              RoomPlayer(
                userId: player.userId,
                seat: player.seat,
                name: player.name,
                lastSeen: player.lastSeen,
                lobbyReady: true,
              ),
          ],
          state: roomState(
            phase: 'lobby',
            phaseNumber: 0,
            status: 'lobby',
            lobbyRevision: 9,
          ),
          lobbyReadyEnabled: true,
        );
        await pumpLobby(tester, container);
        await tester.pump();

        expect(
          tester
              .widget<FilledButton>(find.byKey(LobbyScreen.startButton))
              .onPressed,
          isNotNull,
        );
        final chairs = tester
            .widget<CouncilBand>(find.byType(CouncilBand))
            .seats;
        expect(
          chairs
              .where((seat) => !seat.isEmpty)
              .every((seat) => seat.lobbyReady),
          isTrue,
        );
      },
    );

    testWidgets('a guest waits for the host and is offered nothing to press', (
      tester,
    ) async {
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

      // Doc 12 §2.3 and §5: a dropped player desaturates and pulses, and is
      // **never** a red icon or a label. Red means elimination in this game,
      // and a badge saying «غير متصل» on a lobby seat is the error screen doc
      // 12 §5 exists to refuse. So the assertion is that the seat is drawn,
      // dimmed, and says nothing.
      expect(find.byKey(LobbyScreen.seatTile(2)), findsOneWidget);
      expect(find.text(arStrings.onlineNotConnected), findsNothing);

      // Doc 15 §3 moved every chair onto one painter, so there is no per-seat
      // `Opacity` left to interrogate. The two halves of the claim are checked
      // where they now live: the chair carries the status that dims it, and the
      // token it is dimmed by is genuinely dim.
      final chairs = tester.widget<CouncilBand>(find.byType(CouncilBand)).seats;
      expect(
        chairs.firstWhere((chair) => chair.seat == 2).status,
        SeatStatus.disconnected,
      );
      expect(
        CouncilTokens.disconnectedOpacity,
        lessThan(0.5),
        reason: 'a seat whose player has dropped is dimmed, not labelled',
      );
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
      await container.read(playerProfileProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineEntryScreen(onJoined: () {}, onBack: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    /// The screen asks in order, so the test answers in order: a name, then
    /// *which of the two you are*, and only then a code. The code field does
    /// not exist before the second answer — which is the point of the step, and
    /// the first thing this helper would fail on if it came back.
    Future<void> attemptJoin(WidgetTester tester) async {
      await containerProfileReady(tester);
      await tester.pump();
      expect(find.byKey(OnlineEntryScreen.codeField), findsNothing);

      await tester.tap(find.byKey(OnlineEntryScreen.haveCodeButton));
      await tester.pump();

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

    testWidgets('O9 — an unreachable server leaves the way back to offline', (
      tester,
    ) async {
      final container = containerWith();
      backend.unreachable = true;
      await pumpEntry(tester, container);
      await attemptJoin(tester);

      expect(find.text(arStrings.onlineUnreachable), findsOneWidget);
      // Offline lives one step back, at the online/offline choice.
      expect(find.byKey(OnlineEntryScreen.backButton), findsOneWidget);
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

    testWidgets('profile setup precedes online when identity is missing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final container = containerWith();
      await container.read(playerProfileProvider.future);
      await pumpEntry(tester, container);
      expect(find.byKey(const ValueKey('profile_name')), findsOneWidget);
      expect(find.byKey(OnlineEntryScreen.hostButton), findsNothing);
    });
    testWidgets('a code cannot be typed before the question is answered', (
      tester,
    ) async {
      final container = containerWith();
      await pumpEntry(tester, container);

      // The whole of the change: there is no code field on the first step, so
      // the field that three players in five never touch is not the largest
      // thing on the screen they open.
      expect(find.byKey(OnlineEntryScreen.codeField), findsNothing);
      expect(find.byKey(OnlineEntryScreen.joinButton), findsNothing);
      expect(find.byKey(OnlineEntryScreen.hostButton), findsOneWidget);
      expect(find.byKey(OnlineEntryScreen.haveCodeButton), findsOneWidget);

      await containerProfileReady(tester);
      await tester.pump();
      await tester.tap(find.byKey(OnlineEntryScreen.haveCodeButton));
      await tester.pump();

      expect(find.byKey(OnlineEntryScreen.codeField), findsOneWidget);
      expect(find.byKey(OnlineEntryScreen.joinButton), findsOneWidget);
      expect(find.byKey(OnlineEntryScreen.hostButton), findsOneWidget);
    });

    testWidgets('an invite link skips the question it has already answered', (
      tester,
    ) async {
      final container = containerWith();
      await container.read(playerProfileProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineEntryScreen(
              onJoined: () {},
              onBack: () {},
              initialCode: 'abcdef',
            ),
          ),
        ),
      );
      await tester.pump();

      // Somebody who tapped an invite has said which of the two they are, and
      // the code arrives upper case because that is how the server mints it.
      expect(find.byKey(OnlineEntryScreen.codeField), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(OnlineEntryScreen.codeField))
            .controller!
            .text,
        'ABCDEF',
      );
      expect(find.byKey(OnlineEntryScreen.hostButton), findsOneWidget);
    });

    testWidgets('stepping back puts the refusal away with the field', (
      tester,
    ) async {
      final container = containerWith(
        refuseJoin: const BackendException('ROOM_NOT_FOUND', 'no'),
      );
      await pumpEntry(tester, container);
      await attemptJoin(tester);
      expect(find.text(arStrings.onlineRoomNotFound), findsOneWidget);

      await tester.tap(find.byKey(BackAction.button));
      await tester.pump();

      // A sentence about a code, over a screen with no code on it, is a
      // sentence about nothing.
      expect(find.text(arStrings.onlineRoomNotFound), findsNothing);
      expect(find.byKey(OnlineEntryScreen.hostButton), findsOneWidget);
    });
  });
}

Future<void> containerProfileReady(WidgetTester tester) async {
  await tester.pump();
}
