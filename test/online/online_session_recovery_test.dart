import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/online_match_history.dart';
import 'package:mafia_master/data/online_session_store.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/stores.dart';

/// The persistence contract at the seam between the session and this
/// device's storage: what is written, when it is dropped, and what happens
/// when the device refuses to write at all. Doc 10 §9 and the handoff's
/// section B — a room the server still holds must survive a client that
/// cannot remember it, and a pointer to a room that no longer has a seat for
/// this player must not be offered twice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    seedReturningProfile();
    OnlineSessionStore.writeOverride = null;
    OnlineMatchHistory.writeOverride = null;
  });
  tearDown(() {
    OnlineSessionStore.writeOverride = null;
    OnlineMatchHistory.writeOverride = null;
  });

  FakeBackend fake({RoomState? state, String roomId = 'room-1'}) => FakeBackend(
    roomId: roomId,
    state: state ?? roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
    players: roster(3),
    own: const OwnSeat(seat: 0),
    userId: 'u0',
  );

  ProviderContainer containerFor(Future<OnlineBackend> Function() factory) {
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(factory),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the resume pointer', () {
    test('is roomId and code and nothing else, written on entry', () async {
      final backend = fake();
      final container = containerFor(() async => backend);
      await container.read(onlineSessionProvider.notifier).host('A');

      final stored = await OnlineSessionStore.load();
      expect(stored?.roomId, 'room-1');
      expect(stored?.code, 'ABCDEF');
      final raw = (await SharedPreferences.getInstance()).getString(
        OnlineSessionStore.key,
      )!;
      expect(raw, isNot(contains('role')));
      expect(raw, isNot(contains('token')));
      expect(
        raw.split('"').where((k) => k == 'roomId' || k == 'code').length,
        2,
      );
    });

    test('a refusing device still enters the room and is told, once', () async {
      OnlineSessionStore.writeOverride = (_, __) async => false;
      final backend = fake();
      final container = containerFor(() async => backend);
      final session = container.read(onlineSessionProvider.notifier);
      await session.host('A');

      final state = container.read(onlineSessionProvider);
      expect(state.isInRoom, isTrue, reason: 'storage is not load-bearing');
      expect(state.storageWarning, isTrue);
      expect(await OnlineSessionStore.load(), isNull);

      session.dismissStorageWarning();
      expect(container.read(onlineSessionProvider).storageWarning, isFalse);
      expect(container.read(onlineSessionProvider).isInRoom, isTrue);
    });

    test(
      'is dropped when the server says the room has no seat for this player',
      () async {
        await OnlineSessionStore.save(
          const OnlineRoomResume(roomId: 'old-room', code: 'ABCDEF'),
        );
        final backend = fake();
        backend.refusals['joinRoom'] = const BackendException(
          'ROOM_NOT_FOUND',
          'gone',
        );
        final container = containerFor(() async => backend);
        await container
            .read(onlineSessionProvider.notifier)
            .join(code: 'abcdef', name: 'A');

        expect(
          container.read(onlineSessionProvider).errorCode,
          'ROOM_NOT_FOUND',
        );
        expect(await OnlineSessionStore.load(), isNull);
      },
    );

    test(
      'is kept when the refusal is about this attempt, not the room',
      () async {
        await OnlineSessionStore.save(
          const OnlineRoomResume(roomId: 'old-room', code: 'ABCDEF'),
        );
        final backend = fake();
        backend.refusals['joinRoom'] = const BackendException(
          'ROOM_FULL',
          'full',
        );
        final container = containerFor(() async => backend);
        await container
            .read(onlineSessionProvider.notifier)
            .join(code: 'ABCDEF', name: 'A');

        expect(container.read(onlineSessionProvider).errorCode, 'ROOM_FULL');
        expect((await OnlineSessionStore.load())?.code, 'ABCDEF');
      },
    );

    test('is kept when a different code was refused', () async {
      await OnlineSessionStore.save(
        const OnlineRoomResume(roomId: 'old-room', code: 'ABCDEF'),
      );
      final backend = fake();
      backend.refusals['joinRoom'] = const BackendException(
        'ROOM_NOT_FOUND',
        'gone',
      );
      final container = containerFor(() async => backend);
      await container
          .read(onlineSessionProvider.notifier)
          .join(code: 'ZZZZZZ', name: 'A');

      expect((await OnlineSessionStore.load())?.code, 'ABCDEF');
    });

    test(
      'discarding gives the seat up through leave_room and forgets',
      () async {
        await OnlineSessionStore.save(
          const OnlineRoomResume(roomId: 'old-room', code: 'ABCDEF'),
        );
        final backend = fake();
        final container = containerFor(() async => backend);
        await container
            .read(onlineSessionProvider.notifier)
            .discardResume(
              const OnlineRoomResume(roomId: 'old-room', code: 'ABCDEF'),
            );

        expect(backend.lastCall('leave_room')?.body['roomId'], 'old-room');
        expect(await OnlineSessionStore.load(), isNull);
      },
    );

    test(
      'discarding a room the server no longer knows still forgets',
      () async {
        await OnlineSessionStore.save(
          const OnlineRoomResume(roomId: 'old-room', code: 'ABCDEF'),
        );
        final backend = fake();
        backend.refusals['leave_room'] = const BackendException(
          'NOT_A_MEMBER',
          'gone',
        );
        final container = containerFor(() async => backend);
        await container
            .read(onlineSessionProvider.notifier)
            .discardResume(
              const OnlineRoomResume(roomId: 'old-room', code: 'ABCDEF'),
            );

        expect(await OnlineSessionStore.load(), isNull);
      },
    );
  });

  group('the finished-match summary', () {
    test(
      'is written from a room already on its result, then the pointer goes',
      () async {
        // The first snapshot this device ever sees is the result: a refresh
        // after the match ended. `watch()` replays it, so the summary is still
        // written and the pointer still cleared.
        final backend = fake(
          state: roomState(
            phase: 'result',
            phaseNumber: 3,
            status: 'finished',
            publicData: const {'outcome': 'town'},
          ),
        );
        final container = containerFor(() async => backend);
        await container
            .read(onlineSessionProvider.notifier)
            .join(code: 'ABCDEF', name: 'A');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final rows = await OnlineMatchHistory.load();
        expect(rows, hasLength(1));
        expect(rows.single['roomId'], 'room-1');
        expect(rows.single['winner'], 'town');
        expect(rows.single['days'], 3);
        expect(rows.single['names'], ['A', 'B', 'C']);
        expect(rows.single.keys, isNot(contains('roles')));
        expect(await OnlineSessionStore.load(), isNull);
        expect(container.read(onlineSessionProvider).storageWarning, isFalse);
        expect(
          backend.calls.any(
            (call) =>
                call.function == 'economy' && call.body['action'] == 'sync',
          ),
          isTrue,
        );
      },
    );

    test(
      'a device that cannot keep it still clears the pointer and says so',
      () async {
        OnlineMatchHistory.writeOverride = (_, __) async => false;
        final backend = fake(
          state: roomState(
            phase: 'result',
            phaseNumber: 2,
            status: 'finished',
            publicData: const {'outcome': 'mafia'},
          ),
        );
        final container = containerFor(() async => backend);
        await container
            .read(onlineSessionProvider.notifier)
            .join(code: 'ABCDEF', name: 'A');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(await OnlineMatchHistory.load(), isEmpty);
        expect(await OnlineSessionStore.load(), isNull);
        expect(container.read(onlineSessionProvider).storageWarning, isTrue);
        expect(container.read(onlineSessionProvider).isInRoom, isTrue);
      },
    );
  });

  group('one transport at a time', () {
    test('entering a second room disposes the first', () async {
      final first = fake(roomId: 'room-1');
      final second = fake(roomId: 'room-2');
      var handed = 0;
      final container = containerFor(
        () async => handed++ == 0 ? first : second,
      );
      final session = container.read(onlineSessionProvider.notifier);
      await session.host('A');
      final before = container.read(onlineSessionProvider).transport!;
      var closed = false;
      before.watch().listen(null, onDone: () => closed = true);

      await session.join(code: 'ABCDEF', name: 'A');
      await Future<void>.delayed(Duration.zero);

      final after = container.read(onlineSessionProvider);
      expect(after.room?.roomId, 'room-2');
      expect(identical(after.transport, before), isFalse);
      expect(closed, isTrue, reason: 'the first transport must be disposed');
    });

    test('a malformed answer is a sentence, not a spinner', () async {
      final backend = fake();
      backend.responses['create_room'] = {'unexpected': true};
      final container = containerFor(() async => backend);
      await container
          .read(onlineSessionProvider.notifier)
          .host(
            'A',
            configuration: const {
              'visibility': 'private',
              'title': '',
              'settings': {},
            },
          );

      final state = container.read(onlineSessionProvider);
      expect(state.busy, isFalse);
      expect(state.isInRoom, isFalse);
      expect(state.errorCode, 'BAD_RESPONSE');
      expect(await OnlineSessionStore.load(), isNull);
    });

    test(
      'leave() with no room is a no-op the result screen may call',
      () async {
        final backend = fake();
        final container = containerFor(() async => backend);
        await container.read(onlineSessionProvider.notifier).leave();
        expect(container.read(onlineSessionProvider).isInRoom, isFalse);
        expect(backend.calls, isEmpty);
      },
    );
  });
}
