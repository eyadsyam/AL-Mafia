import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import '../support/fake_backend.dart';

RoomState ballotState({String phase = 'vote', int round = 1}) => RoomState(
  phase: phase,
  phaseNumber: 3,
  status: 'playing',
  hostId: 'u0',
  code: 'ABCDEF',
  serverNow: DateTime.utc(2026, 9, 23),
  settings: const {'openVoting': true},
  publicData: {
    'revote': {'round': round},
  },
);

void main() {
  testWidgets(
    'slow polling still shows replies while the next read is pending',
    (tester) async {
      final first = Completer<Map<int, int?>>();
      final second = Completer<Map<int, int?>>();
      final third = Completer<Map<int, int?>>();
      var reads = 0;
      final backend =
          FakeBackend(
              roomId: 'room-1',
              state: ballotState(),
              players: roster(5),
              own: const OwnSeat(seat: 0, role: 'citizen'),
            )
            ..readBallots = () =>
                [first.future, second.future, third.future][reads++];
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      try {
        await tester.pump(const Duration(seconds: 2));
        expect(reads, 2);
        first.complete({0: 1});
        await tester.pump();
        expect(transport.snapshot.liveBallots, {0: 1});
        await tester.pump(const Duration(seconds: 2));
        expect(reads, 3);
        third.complete({0: 1, 2: 3});
        await tester.pump();
        second.complete({0: 1});
        await tester.pump();
        expect(transport.snapshot.liveBallots, {0: 1, 2: 3});
      } finally {
        await tester.runAsync(transport.dispose);
      }
    },
  );

  for (final phase in ['night', 'vote']) {
    test(
      'late open ballot cannot enter ${phase == 'vote' ? 'a revote' : 'the next phase'}',
      () async {
        final stale = Completer<Map<int, int?>>();
        final fresh = Completer<Map<int, int?>>();
        var reads = 0;
        final backend = FakeBackend(
          roomId: 'room-1',
          state: ballotState(),
          players: roster(5),
          own: const OwnSeat(seat: 0, role: 'citizen'),
        )..readBallots = () => ++reads == 1 ? stale.future : fresh.future;
        final transport = await OnlineTransport.connect(
          backend: backend,
          roomId: 'room-1',
          heartbeatInterval: Duration.zero,
        );
        addTearDown(transport.dispose);
        await Future<void>.delayed(Duration.zero);
        expect(reads, 1);
        backend.setState(ballotState(phase: phase, round: 2));
        await Future<void>.delayed(Duration.zero);
        if (phase == 'vote') {
          expect(reads, 2);
          fresh.complete({2: 3});
          await Future<void>.delayed(Duration.zero);
          expect(transport.snapshot.liveBallots, {2: 3});
        }
        stale.complete({0: 1});
        await Future<void>.delayed(Duration.zero);
        expect(
          transport.snapshot.liveBallots,
          phase == 'vote' ? {2: 3} : isEmpty,
        );
      },
    );
  }

  test(
    'a revote that arrives as a realtime row keeps the open ballot',
    () async {
      final first = Completer<Map<int, int?>>();
      final second = Completer<Map<int, int?>>();
      var reads = 0;
      final backend = FakeBackend(
        roomId: 'room-1',
        state: ballotState(),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'citizen'),
      )..readBallots = () => ++reads == 1 ? first.future : second.future;
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      addTearDown(transport.dispose);
      await Future<void>.delayed(Duration.zero);
      first.complete({0: 1, 2: 1});
      await Future<void>.delayed(Duration.zero);
      expect(transport.snapshot.liveBallots, {0: 1, 2: 1});

      // Production: the revote is a same-phase `room_state` row with no `rooms`
      // fields, so `openVoting` and the host survive only by the merge.
      backend.pushStateDelta(ballotState(round: 2));
      await Future<void>.delayed(Duration.zero);
      expect(transport.snapshot.ballotRound, 2);
      expect(transport.snapshot.settings.openVoting, isTrue);
      expect(transport.isHost, isTrue);
      expect(transport.code, 'ABCDEF');
      expect(
        transport.snapshot.liveBallots,
        isEmpty,
        reason: 'round-one ballots are not round-two ballots',
      );
      expect(reads, 2, reason: 'the open ballot is read again for the revote');
      second.complete({3: 4});
      await Future<void>.delayed(Duration.zero);
      expect(transport.snapshot.liveBallots, {3: 4});
    },
  );
}
