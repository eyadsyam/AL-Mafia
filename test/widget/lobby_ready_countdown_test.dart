import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// F8 + D9: the lobby's 45 s ready countdown reads the seat's server deadline
/// through the transport's local clock, so a phone with a wrong clock shows
/// the same seconds as everyone else.
void main() {
  test('the snapshot carries unready seats\' deadlines in the lobby only', () async {
    final serverNow = DateTime.utc(2026, 9, 2, 12);
    final deadline = serverNow.add(const Duration(seconds: 45));
    final players = [
      for (final p in roster(5))
        p.seat == 1
            ? RoomPlayer.fromJson({
                'user_id': p.userId,
                'seat': 1,
                'name': p.name,
                'ready_deadline': deadline.toIso8601String(),
              })
            : p,
    ];
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'lobby', status: 'lobby', serverNow: serverNow),
      players: players,
      own: const OwnSeat(seat: 1, role: null),
      userId: 'u1',
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
      now: () => serverNow.subtract(const Duration(minutes: 2)),
    );
    addTearDown(transport.dispose);
    final raw = transport.snapshot.lobbyReadyDeadlines[1];
    expect(raw, deadline);
    // Two minutes slow: the local deadline moves with the phone's clock.
    expect(
      transport.onLocalClock(raw),
      deadline.subtract(const Duration(minutes: 2)),
    );
  });

  testWidgets('shows the seconds left, then nothing once it passes', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: ReadyCountdown(
            deadline: DateTime.now().add(const Duration(seconds: 3)),
          ),
        ),
      ),
    );
    expect(find.byKey(ReadyCountdown.countdownKey), findsOneWidget);
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: ReadyCountdown(
            deadline: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        ),
      ),
    );
    expect(find.byKey(ReadyCountdown.countdownKey), findsNothing);
    await tester.pumpWidget(localizedApp(const Scaffold(body: ReadyCountdown(deadline: null))));
    expect(find.byKey(ReadyCountdown.countdownKey), findsNothing);
  });
}
