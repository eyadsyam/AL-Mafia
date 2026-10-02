import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/online_session_store.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/online/room_settings_panel.dart';
import 'package:mafia_master/ui/screens/online/safety_center.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/stores.dart';

/// P1 — the online front door, for a player who already has a profile.
///
/// The thing under test here is not the transport, which has its own suite. It
/// is what the screen *asks* and what it *sends*: a saved profile must not be
/// re-typed at the door, an empty server and an unreachable one must not read
/// the same, and a room must be created with the settings its host chose rather
/// than created first and corrected afterwards — a public room that appears
/// with the wrong capacity for a second is a room somebody can join by mistake.
void main() {
  setUp(seedReturningProfile);
  late FakeBackend backend;

  ProviderContainer containerWith({
    List<Map<String, dynamic>> rooms = const [],
    bool unreachable = false,
    BackendException? refuseCreate,
  }) {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
    );
    backend
      ..responses['browse_rooms'] = {'rooms': rooms}
      ..responses['create_room'] = {'roomId': 'room-1', 'code': 'ABCDEF'}
      ..unreachable = unreachable;
    if (refuseCreate != null) {
      backend.refusals['create_room'] = refuseCreate;
      backend.stickyRefusals.add('create_room');
    }
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpEntry(
    WidgetTester tester,
    ProviderContainer container, {
    VoidCallback? onJoined,
    Size surface = const Size(420, 900),
  }) async {
    // Tall enough that the settings panel's list builds all of itself. These
    // tests are about what the screen sends, not about what is above the fold.
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await container.read(playerProfileProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          OnlineEntryScreen(onJoined: onJoined ?? () {}, onPlayOffline: () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Map<String, dynamic> createPayload() =>
      backend.calls.firstWhere((call) => call.function == 'create_room').body;

  testWidgets(
    'create stays reachable without scrolling at phone and desktop sizes',
    (tester) async {
      for (final size in [
        const Size(390, 844),
        const Size(844, 390),
        const Size(1280, 800),
      ]) {
        final container = containerWith();
        await pumpEntry(tester, container, surface: size);
        await tester.tap(find.byKey(OnlineEntryScreen.hostButton));
        await tester.pump();
        final button = find.byKey(const ValueKey('online_create_confirm'));
        expect(button.hitTestable(), findsOneWidget);
        final bounds = tester.getRect(button);
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        expect(bounds.width, lessThanOrEqualTo(480));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  group('the list is the front door', () {
    testWidgets('play now asks the server for one compatible public seat', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        communityRulesKey: true,
        ProfileStore.profileKey: '{"name":"A","gender":"male"}',
      });
      final container = containerWith();
      backend.responses['quick_match'] = {
        'roomId': 'room-1',
        'code': 'ABCDEF',
        'seat': 0,
        'created': true,
      };
      var joined = false;
      await pumpEntry(tester, container, onJoined: () => joined = true);

      await tester.tap(find.byKey(OnlineEntryScreen.quickMatchButton));
      await tester.pump();
      await tester.pump();

      expect(backend.called('quick_match'), isTrue);
      expect(backend.lastCall('quick_match')?.body, {
        'name': 'A',
        'gender': 'male',
      });
      expect(joined, isTrue);
    });

    testWidgets('public rooms are there without asking for them', (
      tester,
    ) async {
      final container = containerWith(
        rooms: [
          {
            'code': 'AAAAAA',
            'title': 'ليلة الخميس',
            'players': 4,
            'voice': true,
          },
        ],
      );
      await pumpEntry(tester, container);

      expect(find.byKey(const ValueKey('public_room_AAAAAA')), findsOneWidget);
      expect(
        find.byKey(OnlineEntryScreen.codeField),
        findsNothing,
        reason: 'the code is the second way in, not the first',
      );
    });

    testWidgets('a name already saved is never asked for again', (
      tester,
    ) async {
      final container = containerWith(
        rooms: [
          {'code': 'AAAAAA', 'players': 4, 'voice': true},
        ],
      );
      var joined = false;
      await pumpEntry(tester, container, onJoined: () => joined = true);

      await tester.tap(find.byKey(const ValueKey('public_room_AAAAAA')));
      await tester.pump();
      await tester.pump();

      expect(joined, isTrue);
      final join = backend.calls.firstWhere(
        (call) => call.function == 'joinRoom',
      );
      expect(join.body['name'], 'A', reason: 'the profile is the identity');
      expect(find.byKey(const ValueKey('profile_name')), findsNothing);
    });

    testWidgets('an empty server says the list is empty', (tester) async {
      await pumpEntry(tester, containerWith());

      expect(find.text(arStrings.onlineNoPublicRooms), findsOneWidget);
      expect(find.text(arStrings.onlineUnreachable), findsNothing);
    });

    testWidgets('a server that did not answer says something else', (
      tester,
    ) async {
      await pumpEntry(tester, containerWith(unreachable: true));

      expect(find.text(arStrings.onlineUnreachable), findsOneWidget);
      expect(
        find.text(arStrings.onlineNoPublicRooms),
        findsNothing,
        reason:
            'a server that did not answer has not said there is nothing '
            'to join — the two sentences send a player to different places',
      );
    });
  });

  group('creating a room', () {
    Future<void> openCreate(WidgetTester tester) async {
      await tester.tap(find.byKey(OnlineEntryScreen.hostButton));
      await tester.pump();
      expect(find.byKey(RoomSettingsPanel.panel), findsOneWidget);
    }

    testWidgets('every setting travels with the room that is being made', (
      tester,
    ) async {
      final container = containerWith();
      await pumpEntry(tester, container, surface: const Size(500, 2200));
      await openCreate(tester);

      await tester.tap(find.byKey(RoomSettingsPanel.visibilityPublic));
      await tester.pump();
      await tester.enterText(
        find.byKey(RoomSettingsPanel.titleField),
        'ليلة الخميس',
      );
      await tester.pump();
      // Structured is the default, so free is the one a host has to be able to
      // reach — and the one the mic policy reads.
      await tester.tap(find.byKey(RoomSettingsPanel.discussionFree));
      await tester.pump();
      await tester.tap(find.byKey(RoomSettingsPanel.muteAtNightSwitch));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('online_create_confirm')));
      await tester.pump();
      await tester.pump();

      final body = createPayload();
      expect(body['visibility'], 'public');
      expect(body['title'], 'ليلة الخميس');
      expect(body['name'], 'A');
      final settings = Map<String, dynamic>.from(body['settings'] as Map);
      expect(settings['discussionMode'], 'free');
      expect(settings['maxPlayers'], 10);
      expect(settings['voice'], isTrue);
      expect(
        settings['muteAllAtNight'],
        isFalse,
        reason: 'the host\'s room choice must travel in the create request',
      );
      expect(
        backend.calls.where((call) => call.function == 'room_settings'),
        isEmpty,
        reason:
            'a room corrected after it was listed is a room somebody can join '
            'under the wrong settings',
      );
    });

    testWidgets('the night switch is a live room choice', (tester) async {
      await pumpEntry(tester, containerWith(), surface: const Size(500, 2200));
      await openCreate(tester);

      expect(find.text(arStrings.onlineNightPrivacyHint), findsOneWidget);
      final before = tester.widget<Switch>(
        find.byKey(RoomSettingsPanel.muteAtNightSwitch),
      );
      expect(before.value, isTrue);
      expect(before.onChanged, isNotNull);

      await tester.tap(find.byKey(RoomSettingsPanel.muteAtNightSwitch));
      await tester.pump();

      expect(
        tester
            .widget<Switch>(find.byKey(RoomSettingsPanel.muteAtNightSwitch))
            .value,
        isFalse,
      );
    });

    testWidgets('a refused creation keeps the draft on screen', (tester) async {
      final container = containerWith(
        refuseCreate: const BackendException('UNREACHABLE', 'no'),
      );
      await pumpEntry(tester, container, surface: const Size(500, 2200));
      await openCreate(tester);

      await tester.tap(find.byKey(RoomSettingsPanel.visibilityPublic));
      await tester.pump();
      await tester.enterText(
        find.byKey(RoomSettingsPanel.titleField),
        'ليلة الخميس',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('online_create_confirm')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(RoomSettingsPanel.panel), findsOneWidget);
      expect(
        find.text('ليلة الخميس'),
        findsOneWidget,
        reason: 'a failed request must not cost the host their answers',
      );
    });

    testWidgets('a capacity pause explains that existing rooms still work', (
      tester,
    ) async {
      final container = containerWith(
        refuseCreate: const BackendException(
          'NEW_ROOMS_PAUSED',
          'paused',
        ),
      );
      await pumpEntry(tester, container, surface: const Size(500, 2200));
      await openCreate(tester);
      await tester.tap(find.byKey(const ValueKey('online_create_confirm')));
      await tester.pump();
      await tester.pump();

      expect(find.text(arStrings.onlineNewRoomsPaused), findsWidgets);
      expect(find.byKey(RoomSettingsPanel.panel), findsOneWidget);
    });
  });

  group('a room this device remembers', () {
    testWidgets('is offered with a way to forget it', (tester) async {
      SharedPreferences.setMockInitialValues({
        'community_rules_2026_09': true,
        ProfileStore.profileKey: '{"name":"A","gender":"male"}',
        OnlineSessionStore.key: '{"roomId":"old-room","code":"ABCDEF"}',
      });
      final container = containerWith();
      await pumpEntry(tester, container);
      await tester.pump();

      expect(find.byKey(OnlineEntryScreen.resumeButton), findsOneWidget);
      expect(find.byKey(OnlineEntryScreen.discardButton), findsOneWidget);

      await tester.tap(find.byKey(OnlineEntryScreen.discardButton));
      await tester.pump();
      await tester.pump();

      expect(backend.lastCall('leave_room')?.body['roomId'], 'old-room');
      expect(await OnlineSessionStore.load(), isNull);
      expect(find.byKey(OnlineEntryScreen.resumeButton), findsNothing);
      expect(find.byKey(OnlineEntryScreen.discardButton), findsNothing);
    });

    testWidgets('stops being offered once the server says it is gone', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'community_rules_2026_09': true,
        ProfileStore.profileKey: '{"name":"A","gender":"male"}',
        OnlineSessionStore.key: '{"roomId":"old-room","code":"ABCDEF"}',
      });
      final container = containerWith();
      backend.refusals['joinRoom'] = const BackendException(
        'ROOM_NOT_FOUND',
        'gone',
      );
      backend.stickyRefusals.add('joinRoom');
      await pumpEntry(tester, container);
      await tester.pump();

      await tester.tap(find.byKey(OnlineEntryScreen.resumeButton));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(OnlineEntryScreen.errorText), findsOneWidget);
      expect(await OnlineSessionStore.load(), isNull);
      expect(find.byKey(OnlineEntryScreen.resumeButton), findsNothing);
    });
  });

  group('a device that cannot save', () {
    testWidgets('says so once, and the room is still entered', (tester) async {
      OnlineSessionStore.writeOverride = (_, __) async => false;
      addTearDown(() => OnlineSessionStore.writeOverride = null);
      var joined = false;
      final container = containerWith();
      await pumpEntry(
        tester,
        container,
        onJoined: () => joined = true,
        surface: const Size(500, 2200),
      );

      await tester.tap(find.byKey(OnlineEntryScreen.hostButton));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('online_create_confirm')));
      await tester.pump();
      await tester.pump();

      expect(joined, isTrue, reason: 'storage is not load-bearing');
      expect(container.read(onlineSessionProvider).storageWarning, isTrue);
      // The entry screen is what is still on screen in this test; it carries
      // the same note the lobby does, and the same dismissal.
      await tester.pump();
      expect(find.byKey(OnlineEntryScreen.storageWarning), findsWidgets);
    });
  });
}
