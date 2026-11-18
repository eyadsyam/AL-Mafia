import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/online_session_store.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';

import '../support/fake_backend.dart';
import '../support/stores.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, FakeBackend)> enterRoom() async {
    seedReturningProfile();
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', phaseNumber: 0, status: 'lobby'),
      players: roster(3),
      own: const OwnSeat(seat: 0),
      userId: 'u0',
    );
    final container = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        onlineHeartbeatProvider.overrideWithValue(Duration.zero),
        voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    await container.read(onlineSessionProvider.notifier).host('A');
    return (container, backend);
  }

  test('network loss retries twice after local leave has returned', () async {
    final (container, backend) = await enterRoom();
    var attempts = 0;
    backend.responders['leave_room'] = (_) {
      if (++attempts < 3) throw const BackendUnreachable('network');
      return const {'ok': true};
    };

    await container
        .read(onlineSessionProvider.notifier)
        .leave(
          retryFirst: const Duration(milliseconds: 1),
          retrySecond: const Duration(milliseconds: 1),
        );
    expect(attempts, 1);
    expect(container.read(onlineSessionProvider).isInRoom, isFalse);
    expect(await OnlineSessionStore.load(), isNull);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(attempts, 3);
    expect(
      backend.calls.where((call) => call.function == 'leave_room').length,
      3,
    );
    expect(backend.lastCall('leave_room')?.body['roomId'], 'room-1');
  });

  test('server refusal makes one call and still clears local room', () async {
    final (container, backend) = await enterRoom();
    backend.refusals['leave_room'] = const BackendException(
      'NOT_A_MEMBER',
      'gone',
    );

    await container
        .read(onlineSessionProvider.notifier)
        .leave(
          retryFirst: const Duration(milliseconds: 1),
          retrySecond: const Duration(milliseconds: 1),
        );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(container.read(onlineSessionProvider).isInRoom, isFalse);
    expect(await OnlineSessionStore.load(), isNull);
    expect(
      backend.calls.where((call) => call.function == 'leave_room').length,
      1,
    );
  });
}
