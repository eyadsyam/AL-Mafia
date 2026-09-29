import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/online_session_store.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/room_referral.dart';
import 'package:mafia_master/ui/screens/online/online_entry_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:mafia_master/ui/screens/online/room_settings_panel.dart';
import 'package:mafia_master/ui/screens/online/safety_center.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mafia_master/ui/economy/wallet.dart';

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
    VoidCallback? onBack,
    Size surface = const Size(420, 900),
    Locale locale = const Locale('ar'),
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
          OnlineEntryScreen(
            onJoined: onJoined ?? () {},
            onBack: onBack ?? () {},
          ),
          locale: locale,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Map<String, dynamic> createPayload() =>
      backend.calls.firstWhere((call) => call.function == 'create_room').body;

  testWidgets('nearly ready filter follows refreshed seats without joining', (
    tester,
  ) async {
    final container = containerWith(
      rooms: [
        {'code': 'NEARAA', 'players': 4, 'voice': true},
        {'code': 'READYA', 'players': 5, 'voice': false},
        {'code': 'EMPTYA', 'players': 0, 'waiting': true},
      ],
    );
    await pumpEntry(tester, container);
    await tester.tap(find.byKey(const ValueKey('rooms_filter_nearly')));
    await tester.pump();
    expect(find.byKey(const ValueKey('public_room_NEARAA')), findsOneWidget);
    expect(find.byKey(const ValueKey('public_room_READYA')), findsNothing);
    expect(find.byKey(const ValueKey('public_room_EMPTYA')), findsNothing);
    backend.responses['browse_rooms'] = {
      'rooms': [
        {'code': 'NEARAA', 'players': 5, 'voice': true},
      ],
    };
    await tester.pump(MafiaTiming.publicRoomsRefresh);
    await tester.pump();
    expect(find.text(arStrings.onlineRoomsNoFilterMatches), findsOneWidget);
    expect(backend.calls.where((c) => c.function == 'join_room'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('rooms_filter_all')));
    await tester.pump();
    expect(find.byKey(const ValueKey('public_room_NEARAA')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'room cards fit narrow Arabic and English screens with directional arrows',
    (tester) async {
      for (final locale in [const Locale('ar'), const Locale('en')]) {
        final container = containerWith(
          rooms: [
            {
              'code': 'NEARAA',
              'title': 'A long room name that must wrap safely',
              'players': 4,
              'voice': true,
            },
          ],
        );
        await pumpEntry(
          tester,
          container,
          surface: const Size(360, 800),
          locale: locale,
        );
        final card = find.byKey(const ValueKey('public_room_NEARAA'));
        await tester.ensureVisible(card);
        await tester.pump();
        expect(
          find.descendant(
            of: card,
            // One forward chevron in both languages: `chevron_right` mirrors
            // itself under RTL (matchTextDirection), so Arabic draws «‹».
            // Choosing `chevron_left` for Arabic mirrored it back to «›» —
            // pointing off the screen (phase 99 render).
            matching: find.byIcon(Icons.chevron_right),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            locale.languageCode == 'ar'
                ? arStrings.onlineRoomVoiceOn
                : enStrings.onlineRoomVoiceOn,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

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
    int browses() =>
        backend.calls.where((call) => call.function == 'browse_rooms').length;

    testWidgets('opening the list reads it and never seats anybody', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        communityRulesKey: true,
        ProfileStore.profileKey: '{"name":"A","gender":"male"}',
        ...acceptedTermsPrefs,
      });
      final container = containerWith(
        rooms: [
          {'code': 'AAAAAA', 'players': 4, 'voice': true},
        ],
      );
      await pumpEntry(tester, container);
      await tester.pump(MafiaTiming.publicRoomsRefresh);
      await tester.pump();

      expect(browses(), 2, reason: 'the list refreshes itself');
      expect(
        backend.calls.map((call) => call.function),
        // `economy` is the Casebook door asking what the feature flags say —
        // a read, never a seat.
        everyElement(isIn(['browse_rooms', 'economy'])),
        reason: 'looking is not joining, and there is no quick match',
      );
      expect(container.read(onlineSessionProvider).isInRoom, isFalse);
      expect(find.text(arStrings.onlinePlayOffline), findsNothing);
    });

    testWidgets('each card says how full it is and what it is waiting for', (
      tester,
    ) async {
      final container = containerWith(
        rooms: [
          {
            'code': 'FULLAA',
            'players': 8,
            'capacity': 8,
            'min_players': 5,
            'voice': true,
          },
          {
            'code': 'NEEDSA',
            'players': 3,
            'capacity': 10,
            'min_players': 5,
            'voice': true,
          },
          {
            'code': 'READYA',
            'players': 6,
            'capacity': 10,
            'min_players': 5,
            'voice': false,
          },
        ],
      );
      await pumpEntry(tester, container);

      String subtitle(String code) {
        final tile = tester.widget<ListTile>(
          find.descendant(
            of: find.byKey(ValueKey('public_room_$code')),
            matching: find.byType(ListTile),
          ),
        );
        return (tile.subtitle! as Text).data!;
      }

      expect(subtitle('NEEDSA'), contains('3/10'));
      expect(subtitle('NEEDSA'), contains(arStrings.publicRoomMissing(2)));
      expect(subtitle('READYA'), contains(arStrings.publicRoomReady));
      expect(subtitle('FULLAA'), contains(arStrings.publicRoomFullStatus));
      final full = tester.widget<ListTile>(
        find.descendant(
          of: find.byKey(const ValueKey('public_room_FULLAA')),
          matching: find.byType(ListTile),
        ),
      );
      expect(full.onTap, isNull, reason: 'a full room cannot be tapped');

      // Joinable and nearest to starting first; full last.
      final order = [
        for (final code in ['READYA', 'NEEDSA', 'FULLAA'])
          tester.getTopLeft(find.byKey(ValueKey('public_room_$code'))).dy,
      ];
      expect(order, orderedEquals([...order]..sort()));
    });

    testWidgets('a failed refresh keeps the list and says it may be stale', (
      tester,
    ) async {
      final container = containerWith(
        rooms: [
          {'code': 'AAAAAA', 'players': 4, 'voice': true},
        ],
      );
      await pumpEntry(tester, container);
      expect(browses(), 1);

      backend.unreachable = true;
      await tester.pump(MafiaTiming.publicRoomsRefresh);
      await tester.pump();

      expect(find.byKey(const ValueKey('public_room_AAAAAA')), findsOneWidget);
      expect(find.text(arStrings.publicRoomsStale), findsOneWidget);
      expect(find.text(arStrings.onlineNoPublicRooms), findsNothing);

      // Backed off: the next read is not fifteen seconds after a failure.
      backend.unreachable = false;
      await tester.pump(MafiaTiming.publicRoomsRefresh);
      await tester.pump();
      expect(browses(), 1);
      await tester.pump(MafiaTiming.publicRoomsRefresh);
      await tester.pump();
      expect(browses(), 2);
      expect(find.text(arStrings.publicRoomsStale), findsNothing);
    });

    testWidgets('the background pauses the refresh; returning reads at once', (
      tester,
    ) async {
      final container = containerWith();
      await pumpEntry(tester, container);
      expect(browses(), 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(MafiaTiming.publicRoomsBackoffCap * 2);
      expect(browses(), 1, reason: 'nobody is looking at the list');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(browses(), 2);
    });

    testWidgets('no refresh outlives the screen', (tester) async {
      final container = containerWith();
      await pumpEntry(tester, container);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(MafiaTiming.publicRoomsBackoffCap * 2);
      expect(browses(), 1);
    });

    testWidgets('a refresh keeps the player where they had scrolled', (
      tester,
    ) async {
      final rooms = [
        for (var i = 0; i < 30; i++)
          {
            'code': 'R${i.toString().padLeft(5, '0')}',
            'players': 1,
            'voice': true,
          },
      ];
      final container = containerWith(rooms: rooms);
      await pumpEntry(tester, container);
      final list = find.byKey(OnlineEntryScreen.browseList);
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)).first,
      );
      final before = scrollable.position.pixels;
      expect(before, greaterThan(0));

      await tester.pump(MafiaTiming.publicRoomsRefresh);
      await tester.pump();
      expect(browses(), 2);
      expect(scrollable.position.pixels, before);
    });

    testWidgets(
      'a room that filled meanwhile is refused and the list re-read',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          communityRulesKey: true,
          ProfileStore.profileKey: '{"name":"A","gender":"male"}',
          ...acceptedTermsPrefs,
        });
        final container = containerWith(
          rooms: [
            {'code': 'AAAAAA', 'players': 9, 'capacity': 10, 'voice': true},
          ],
        );
        backend.refusals['joinRoom'] = const BackendException('ROOM_FULL', 'x');
        var joined = false;
        await pumpEntry(tester, container, onJoined: () => joined = true);

        await tester.tap(find.byKey(const ValueKey('public_room_AAAAAA')));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(joined, isFalse);
        expect(find.text(arStrings.onlineRoomFull), findsOneWidget);
        expect(browses(), 2);
        expect(
          backend.calls.where((call) => call.function == 'joinRoom'),
          hasLength(1),
          reason: 'never moved into another room without choosing it',
        );
      },
    );

    testWidgets('no creation card: only the list and the two top actions', (
      tester,
    ) async {
      final container = containerWith();
      await pumpEntry(tester, container);
      expect(
        find.byKey(const ValueKey('online_new_public_room')),
        findsNothing,
      );
      expect(find.byIcon(Icons.add_home_outlined), findsNothing);
      expect(backend.called('create_room'), isFalse);
    });

    testWidgets('the server waiting room is shown empty and honest', (
      tester,
    ) async {
      final container = containerWith(
        rooms: [
          {
            'code': 'FULLRM',
            'title': 'مليانة',
            'players': 10,
            'capacity': 10,
            'min_players': 5,
            'voice': true,
          },
          {
            'code': 'WAITRM',
            'title': '',
            'players': 0,
            'capacity': 10,
            'min_players': 5,
            'voice': true,
            'waiting': true,
          },
          {
            'code': 'LIVERM',
            'title': 'ليلة',
            'players': 3,
            'capacity': 10,
            'min_players': 5,
            'voice': true,
          },
        ],
      );
      var joined = false;
      await pumpEntry(tester, container, onJoined: () => joined = true);
      final waiting = find.byKey(const ValueKey('public_room_WAITRM'));
      expect(
        find.descendant(
          of: waiting,
          matching: find.text(arStrings.publicRoomWaitingTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: waiting,
          matching: find.textContaining(arStrings.publicRoomWaitingStatus),
        ),
        findsOneWidget,
      );
      // People first, then the empty waiting room, then full rooms.
      final top = tester
          .getTopLeft(find.byKey(const ValueKey('public_room_LIVERM')))
          .dy;
      final mid = tester.getTopLeft(waiting).dy;
      final low = tester
          .getTopLeft(find.byKey(const ValueKey('public_room_FULLRM')))
          .dy;
      expect(top < mid && mid < low, isTrue);
      await tester.tap(waiting);
      await tester.pump();
      await tester.pump();
      expect(joined, isTrue);
      expect(
        backend.called('create_room'),
        isFalse,
        reason: 'joining claims the room; nothing is created client-side',
      );
    });

    testWidgets('back goes to the online/offline choice', (tester) async {
      var back = false;
      await pumpEntry(tester, containerWith(), onBack: () => back = true);
      await tester.tap(find.byKey(OnlineEntryScreen.backButton));
      expect(back, isTrue);
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

    testWidgets('a referral room link records the code after joining', (
      tester,
    ) async {
      final container = containerWith();
      backend.responders['economy'] = (body) =>
          body['action'] == 'invite_redeem'
          ? {'status': 'redeemed', 'enabled': true}
          : const {'ok': true};
      await container.read(playerProfileProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineEntryScreen(
              initialCode: 'ABCDEF',
              initialReferralCode: '43D4YUG',
              onJoined: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(OnlineEntryScreen.joinButton));
      await tester.pump();
      await tester.pump();
      final redeem = backend.calls.singleWhere(
        (call) =>
            call.function == 'economy' &&
            call.body['action'] == 'invite_redeem',
      );
      expect(redeem.body['code'], '43D4YUG');
    });

    Future<void> openLink(WidgetTester tester, ProviderContainer container) async {
      await container.read(playerProfileProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineEntryScreen(
              initialCode: 'ABCDEF',
              initialReferralCode: '43D4YUG',
              onJoined: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Iterable<FakeCall> redeems() => backend.calls.where(
      (call) =>
          call.function == 'economy' && call.body['action'] == 'invite_redeem',
    );

    testWidgets('a link referral waits through a refused join for the next room', (
      tester,
    ) async {
      final container = containerWith();
      backend.responders['economy'] = (_) => const {'status': 'redeemed'};
      backend.refusals['joinRoom'] = const BackendException(
        'ROOM_FULL',
        'full',
      );
      await openLink(tester, container);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(RoomReferral.storageKey), '43D4YUG');
      await tester.tap(find.byKey(OnlineEntryScreen.joinButton));
      await tester.pump();
      await tester.pump();
      expect(redeems(), isEmpty, reason: 'no seat, nothing recorded');
      expect(prefs.getString(RoomReferral.storageKey), '43D4YUG');
      await tester.tap(find.byKey(OnlineEntryScreen.joinButton));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(redeems().single.body['code'], '43D4YUG');
      expect(prefs.getString(RoomReferral.storageKey), isNull);
    });

    testWidgets('a referral the server refuses is forgotten, and the room kept', (
      tester,
    ) async {
      final container = containerWith();
      backend.refusals['economy'] = const BackendException(
        'INVITE_NOT_NEW',
        'not new',
      );
      await openLink(tester, container);
      await tester.tap(find.byKey(OnlineEntryScreen.joinButton));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(redeems(), hasLength(1));
      expect(container.read(onlineSessionProvider).isInRoom, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(RoomReferral.storageKey), isNull);
    });

    testWidgets('an unreachable referral is kept for the next room', (
      tester,
    ) async {
      await RoomReferral.remember('43D4YUG');
      await RoomReferral.redeemAfterJoin(
        () async => throw const BackendUnreachable('offline'),
      );
      expect(await RoomReferral.pending(), '43D4YUG');
      final server = FakeBackend(
        roomId: 'r',
        state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
        players: roster(3),
        own: const OwnSeat(seat: 0),
      )..responders['economy'] = (_) => const {'status': 'redeemed'};
      await RoomReferral.redeemAfterJoin(() async => server);
      expect(
        server.calls.single.body,
        {'action': 'invite_redeem', 'code': '43D4YUG'},
      );
      expect(await RoomReferral.pending(), isNull);
    });

    testWidgets('an empty server says the list is empty', (tester) async {
      await pumpEntry(tester, containerWith());

      expect(find.text(arStrings.onlineNoPublicRooms), findsOneWidget);
      expect(find.text(arStrings.publicRoomsUnavailable), findsNothing);
    });

    testWidgets('a server that did not answer says something else', (
      tester,
    ) async {
      await pumpEntry(tester, containerWith(unreachable: true));

      expect(find.text(arStrings.publicRoomsUnavailable), findsOneWidget);
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

    testWidgets(
      'an owned pack dresses the new room; unowned ones are not offered',
      (tester) async {
        final container = containerWith();
        backend.responses['economy'] = {
          'balance': 0,
          'catalog': <Object>[],
          'owned': ['pack_old_town'],
          'equipped': {'room_pack': 'pack_old_town'},
        };
        await container.read(walletProvider.notifier).refresh();
        await pumpEntry(tester, container, surface: const Size(500, 2200));
        await openCreate(tester);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('room_pack_old_town')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('room_pack_midnight_manor')),
          findsNothing,
        );
        await tester.tap(find.byKey(const ValueKey('online_create_confirm')));
        await tester.pump();
        await tester.pump();
        final settings = Map<String, dynamic>.from(
          createPayload()['settings'] as Map,
        );
        expect(settings['presentationPack'], 'pack_old_town');
        expect(settings.containsKey('narratorPack'), isFalse);
      },
    );

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
        refuseCreate: const BackendException('NEW_ROOMS_PAUSED', 'paused'),
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
        ...acceptedTermsPrefs,
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
        ...acceptedTermsPrefs,
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
