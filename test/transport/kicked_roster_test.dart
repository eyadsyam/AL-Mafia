import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/room_codec.dart';

void main() {
  GameSnapshot decode(String phase, {List<int>? seats, int viewer = 0}) =>
      snapshotFrom(
        state: RoomState(
          phase: phase,
          phaseNumber: 1,
          phaseEndsAt: null,
          activeSpeaker: null,
          publicData: {if (seats != null) 'rosterSeats': seats},
          status: phase == 'lobby' ? 'lobby' : 'playing',
          settings: const {},
          hostId: 'host',
          code: 'KCKS78',
          serverNow: DateTime.utc(2026),
        ),
        players: const [
          RoomPlayer(userId: 'host', seat: 0, name: 'host', sawRole: true),
          RoomPlayer(
            userId: 'removed',
            seat: 1,
            name: 'removed',
            kicked: true,
            alive: false,
          ),
          RoomPlayer(
            userId: 'replacement',
            seat: 2,
            name: 'replacement',
            sawRole: true,
          ),
        ],
        viewerSeat: viewer,
        isHost: viewer == 0,
        connection: ConnectionQuality.connected,
        skew: Duration.zero,
      );
  test('lobby hides a removed seat but keeps its own removal notification', () {
    expect(decode('lobby').public.players.map((p) => p.seat), [0, 2]);
    expect(decode('lobby', viewer: 1).viewerKicked, isTrue);
  });
  test(
    'pre-deal removal neither joins the match nor holds the reveal gate',
    () {
      final result = decode('reveal', seats: [0, 2], viewer: 1);
      expect(result.public.players.map((p) => p.seat), [0, 2]);
      expect(result.unseenRoleSeats, isEmpty);
      expect(result.viewerKicked, isTrue);
    },
  );
  test('removal after deal retains the actual participant', () {
    expect(
      decode('night', seats: [0, 1, 2]).public.players.map((p) => p.seat),
      [0, 1, 2],
    );
  });
  test('older matches without a participant list retain their roster', () {
    expect(decode('night').public.players.length, 3);
  });
}
