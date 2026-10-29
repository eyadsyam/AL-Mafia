import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';

import '../support/fake_backend.dart';

void main() {
  final serverNow = DateTime.utc(2026, 9, 2, 12);
  final serverDeadline = serverNow.add(const Duration(minutes: 2));

  for (final offset in <int>[-10, 10]) {
    test(
      'X16 clock ${offset < 0 ? 'behind' : 'ahead'} cannot expire early',
      () async {
        var localNow = serverNow.add(Duration(minutes: offset));
        final backend = FakeBackend(
          roomId: 'room-1',
          state: roomState(
            phase: 'night',
            serverNow: serverNow,
            endsAt: serverDeadline,
          ),
          players: roster(5),
          own: const OwnSeat(seat: 0, role: 'citizen'),
        );
        final transport = await OnlineTransport.connect(
          backend: backend,
          roomId: 'room-1',
          heartbeatInterval: Duration.zero,
          now: () => localNow,
        );
        addTearDown(transport.dispose);
        expect(transport.snapshot.phase, GamePhase.night);
        expect(
          transport.snapshot.phaseDeadline,
          serverDeadline.add(Duration(minutes: offset)),
        );
        expect(
          transport.snapshot.phaseDeadline!.difference(localNow),
          const Duration(minutes: 2),
        );

        localNow = localNow.add(const Duration(minutes: 1, seconds: 59));
        await transport.tick();
        expect(backend.called('advance_phase'), isFalse);
        expect(transport.snapshot.phase, GamePhase.night);
        expect(transport.snapshot.currentActorSeat, 0);

        localNow = localNow.add(const Duration(seconds: 1));
        await transport.tick();
        expect(backend.called('advance_phase'), isTrue);
        // A client request cannot change the phase without a server snapshot.
        expect(transport.snapshot.phase, GamePhase.night);
      },
    );
  }

  test(
    'X16 a skewed realtime row does not replace full-read clock offset',
    () async {
      var localNow = serverNow.add(const Duration(minutes: 10));
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(
          phase: 'night',
          serverNow: serverNow,
          endsAt: serverDeadline,
        ),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'citizen'),
      );
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
        now: () => localNow,
      );
      addTearDown(transport.dispose);
      final corrected = transport.snapshot.phaseDeadline;
      backend.pushStateDelta(
        roomState(phase: 'night', endsAt: serverDeadline),
        receivedAt: localNow,
      );
      await pumpEventQueue();
      expect(transport.snapshot.phaseDeadline, corrected);
      await transport.tick();
      expect(backend.called('advance_phase'), isFalse);
      localNow = localNow.add(const Duration(minutes: 2));
      await transport.tick();
      expect(backend.called('advance_phase'), isTrue);
    },
  );
}
