import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';

import '../support/fake_backend.dart';

/// Row 4: process death in every private phase.
///
/// The app is killed and started again: nothing survives on the device but
/// the room id, so the new transport is built from the server's rows alone.
/// Whatever this seat already did must read as done (no second submission is
/// offered), and whatever it had not done must be offered again, exactly as
/// before the death (the last safe snapshot).
void main() {
  Future<OnlineTransport> restart(FakeBackend backend) => OnlineTransport.connect(
    backend: backend,
    roomId: 'room-1',
    heartbeatInterval: Duration.zero,
  );

  group('reveal', () {
    test('an unacknowledged card comes back after a restart', () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'reveal'),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'detective'),
      );
      final transport = await restart(backend);
      addTearDown(transport.dispose);
      expect(transport.snapshot.currentActorSeat, 0, reason: 'the card is owed');
      expect((await transport.secretsFor(0))?.role, isNotNull);
    });

    test('an acknowledged card stays gone after a restart', () async {
      final players = [
        for (final p in roster(5)) p.seat == 0 ? p.copyWith(sawRole: true) : p,
      ];
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'reveal'),
        players: players,
        own: const OwnSeat(seat: 0, role: 'detective'),
      );
      final transport = await restart(backend);
      addTearDown(transport.dispose);
      expect(transport.snapshot.currentActorSeat, isNull);
      expect(backend.calls.where((c) => c.function == 'saw_role'), isEmpty,
          reason: 'nothing is re-sent on resume');
    });
  });

  group('night action', () {
    test('a move the server holds is frozen after a restart', () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'night'),
        players: roster(5),
        own: const OwnSeat(
          seat: 0, role: 'mafia', actedThisNight: true, bulletSpent: true),
      );
      final transport = await restart(backend);
      addTearDown(transport.dispose);
      expect(transport.snapshot.currentActorSeat, isNull,
          reason: 'no second move is offered');
      expect(transport.currentActorBulletSpent, isTrue,
          reason: 'a spent bullet is still spent after the restart');
      expect(backend.calls.where((c) => c.function == 'submit_night_action'), isEmpty);
    });

    test('a move the server never received is offered again', () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'night'),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'doctor'),
      );
      final transport = await restart(backend);
      addTearDown(transport.dispose);
      expect(transport.snapshot.currentActorSeat, 0);
      expect(transport.currentActorBulletSpent, isFalse);
    });

    test('every role resumes with the same urgency', () async {
      final seen = <String, int?>{};
      for (final role in ['mafia', 'doctor', 'detective', 'citizen']) {
        final backend = FakeBackend(
          roomId: 'room-1',
          state: roomState(phase: 'night'),
          players: roster(5),
          own: OwnSeat(seat: 0, role: role),
        );
        final transport = await restart(backend);
        seen[role] = transport.snapshot.currentActorSeat;
        await transport.dispose();
      }
      expect(seen.values.toSet(), {0}, reason: 'no role resumes differently');
    });
  });

  group('whisper compose', () {
    test("today's sent whisper is in the graph after a restart", () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'discuss', phaseNumber: 2),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'citizen'),
        whispers: const [WhisperRow(id: 'w1', day: 2, fromSeat: 0, toSeat: 3)],
      );
      final transport = await restart(backend);
      addTearDown(transport.dispose);
      final mine = transport.snapshot.whisperGraph
          .where((w) => w.fromSeat == 0 && w.day == 2);
      expect(mine, hasLength(1), reason: 'the compose door reads as used');
      expect(backend.calls.where((c) => c.function == 'send_whisper'), isEmpty);
    });

    test('an unsent whisper leaves the door open', () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'discuss', phaseNumber: 2),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'citizen'),
        whispers: const [WhisperRow(id: 'w0', day: 1, fromSeat: 0, toSeat: 3)],
      );
      final transport = await restart(backend);
      addTearDown(transport.dispose);
      expect(
        transport.snapshot.whisperGraph.where((w) => w.fromSeat == 0 && w.day == 2),
        isEmpty,
      );
    });
  });
}
