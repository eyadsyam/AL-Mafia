import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/fake_backend.dart';

/// Owner decision 2026-09-23: once a match starts it moves by itself, for
/// everybody at once — no «كمل» for the host. The beats the room only reads
/// end after a reading pause, kept silently by the host's device.
///
/// `testWidgets` for its fake clock: the alarms are real `Timer`s.
void main() {
  Future<(FakeBackend, OnlineTransport)> connect(
    WidgetTester tester,
    RoomState state, {
    String userId = 'u0',
    List<RoomPlayer>? players,
  }) async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: state,
      players: players ?? roster(5),
      own: const OwnSeat(seat: 0, role: 'citizen'),
      userId: userId,
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      // Non-zero: zero switches every alarm off, which is what the other
      // transport tests rely on.
      heartbeatInterval: const Duration(hours: 1),
    );
    return (backend, transport);
  }

  testWidgets('the morning moves on by itself on the host device', (
    tester,
  ) async {
    final (backend, transport) = await connect(
      tester,
      roomState(phase: 'morning'),
    );
    await tester.pump(MafiaTiming.autoMorningRead - const Duration(seconds: 1));
    expect(backend.called('open_phase'), isFalse, reason: 'still being read');
    await tester.pump(const Duration(seconds: 2));
    expect(backend.called('open_phase'), isTrue);
    await tester.runAsync(transport.dispose);
  });

  testWidgets('the verdict moves on by itself on the host device', (
    tester,
  ) async {
    final (backend, transport) = await connect(
      tester,
      roomState(phase: 'verdict'),
    );
    await tester.pump(MafiaTiming.autoVerdictRead + const Duration(seconds: 1));
    expect(backend.lastCall('open_phase')?.body['phase'], 'night');
    await tester.runAsync(transport.dispose);
  });

  testWidgets('a guest keeps no early clock — only the deadline fallback', (
    tester,
  ) async {
    final (backend, transport) = await connect(
      tester,
      roomState(phase: 'morning'),
      userId: 'u3',
    );
    await tester.pump(MafiaTiming.autoMorningRead + const Duration(seconds: 1));
    expect(backend.called('open_phase'), isFalse);
    await tester.runAsync(transport.dispose);
  });

  testWidgets('the deal waits for every card, then opens the night', (
    tester,
  ) async {
    final (backend, transport) = await connect(
      tester,
      roomState(phase: 'reveal'),
      players: [for (final p in roster(5)) p.copyWith(sawRole: p.seat != 3)],
    );
    await tester.pump(const Duration(seconds: 30));
    expect(
      backend.called('open_phase'),
      isFalse,
      reason: 'seat 3 has not looked at their card',
    );
    backend.pushPlayer(roster(5)[3].copyWith(sawRole: true));
    await tester.pump();
    await tester.pump(
      MafiaTiming.autoRevealSettle + const Duration(seconds: 1),
    );
    expect(backend.lastCall('open_phase')?.body['phase'], 'night');
    await tester.runAsync(transport.dispose);
  });
}
