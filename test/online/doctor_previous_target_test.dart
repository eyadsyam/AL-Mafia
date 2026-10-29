import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';

import '../support/fake_backend.dart';

void main() {
  test('doctor can select a different living target', () {
    const lastProtectedSeat = 1;
    expect(
      doctorMaySelectNightTarget(Role.doctor, 1, lastProtectedSeat),
      isFalse,
    );
    expect(
      doctorMaySelectNightTarget(Role.doctor, 2, lastProtectedSeat),
      isTrue,
    );
  });

  test('previous protection reaches only the viewer selection state', () async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'night', phaseNumber: 2),
      players: roster(5),
      userId: 'u0',
      own: const OwnSeat(seat: 0, role: 'doctor', lastProtectSeat: 1),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    addTearDown(transport.dispose);
    expect(transport.snapshot.viewerLastProtectSeat, 1);
    expect(
      doctorMaySelectNightTarget(
        Role.doctor,
        1,
        transport.snapshot.viewerLastProtectSeat,
      ),
      isFalse,
    );
    expect(
      doctorMaySelectNightTarget(
        Role.doctor,
        2,
        transport.snapshot.viewerLastProtectSeat,
      ),
      isTrue,
    );
  });
}
