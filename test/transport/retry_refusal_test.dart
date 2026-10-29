import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';

import '../support/fake_backend.dart';

/// O10: a scheduled reconnect that the server answers with an error (not
/// "room gone", not "unreachable") keeps the backoff going. Before, the error
/// escaped the retry timer and nothing tried again until another event.
///
/// `testWidgets` for its fake clock: the retry is a real `Timer`.
void main() {
  testWidgets('a refused reconnect is retried, and the banner comes down', (
    tester,
  ) async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'night'),
      players: roster(5),
      own: const OwnSeat(seat: 0, role: 'citizen'),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      // Non-zero: zero switches the retry timer off.
      heartbeatInterval: const Duration(hours: 1),
    );

    backend.unreachable = true;
    await transport.resync();
    expect(transport.snapshot.connection, ConnectionQuality.reconnecting);

    backend.unreachable = false;
    backend.fetchRefusal = const BackendException('INTERNAL', 'boom');
    final before = backend.fetches;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(backend.fetches, greaterThan(before), reason: 'first retry ran');
    expect(transport.snapshot.connection, isNot(ConnectionQuality.connected));

    backend.fetchRefusal = null;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(transport.snapshot.connection, ConnectionQuality.connected);

    await tester.runAsync(transport.dispose);
  });
}
