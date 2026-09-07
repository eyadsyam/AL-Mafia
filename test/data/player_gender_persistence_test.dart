import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/match_codec.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/data/player_group_codec.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/room_codec.dart';

/// **Gender survives every hop, and its absence is never an error.**
///
/// ## Why this file exists
///
/// The player's male/female choice is not decoration: the Arabic copy
/// conjugates on it, so a value dropped somewhere between the setup screen and
/// the morning report does not produce a missing field — it produces a sentence
/// that addresses a woman as a man, in the one language the app actually ships
/// in. That failure is invisible to every existing test, because every existing
/// test compares seats, names and roles, and all three survive it.
///
/// So each hop the value takes gets a round trip here: the saved match, the
/// saved roster, and the online room's public view. And each hop gets a second
/// test for the case that matters more in practice — a row written *before* the
/// column existed. Those must read back as [PlayerGender.unspecified] and must
/// not throw, because a resumed match or a rejoined room from an older build is
/// the normal upgrade path, not an edge case. It is the live one today: the
/// production room schema has not had the migration applied.
void main() {
  final now = DateTime.utc(2026, 9, 6, 20);

  // ───────────────────────────────────────────────────────────────────────
  // The saved match
  // ───────────────────────────────────────────────────────────────────────

  Match matchWith(List<Player> players) => Match(
    id: 1,
    createdAt: now,
    seed: 99,
    phase: GamePhase.night,
    dayNumber: 1,
    settings: const MatchSettings(),
    players: players,
    eventLog: const [],
  );

  /// Encodes, stringifies and reads back — the path storage actually takes, so
  /// a value that only survives in memory does not pass.
  Match roundTrip(Match match) => MatchCodec.decode(
    jsonDecode(jsonEncode(MatchCodec.encode(match))) as Map<String, dynamic>,
  );

  group('saved match', () {
    test('every gender survives the round trip', () {
      final match = matchWith(const [
        Player(
          seat: 0,
          name: 'ليلى',
          gender: PlayerGender.female,
          role: Role.doctor,
          status: PlayerStatus.alive,
        ),
        Player(
          seat: 1,
          name: 'عمر',
          gender: PlayerGender.male,
          role: Role.mafia,
          status: PlayerStatus.alive,
        ),
        Player(
          seat: 2,
          name: 'ندى',
          gender: PlayerGender.unspecified,
          role: Role.citizen,
          status: PlayerStatus.alive,
        ),
      ]);

      final players = roundTrip(match).players;
      expect(players[0].gender, PlayerGender.female);
      expect(players[1].gender, PlayerGender.male);
      expect(players[2].gender, PlayerGender.unspecified);
      // The whole match, not just the field: equality is the repository's own
      // invariant, and this proves the new column did not break it.
      expect(roundTrip(match), match);
    });

    test('a match written before the column reads back as unspecified', () {
      final json = MatchCodec.encode(
        matchWith(const [
          Player(
            seat: 0,
            name: 'ليلى',
            gender: PlayerGender.female,
            role: Role.doctor,
            status: PlayerStatus.alive,
          ),
        ]),
      );
      for (final p in json['players'] as List) {
        (p as Map<String, dynamic>).remove('gender');
      }

      final decoded = MatchCodec.decode(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(decoded.players.single.gender, PlayerGender.unspecified);
      expect(decoded.players.single.name, 'ليلى');
    });

    test('an unknown gender name degrades rather than throwing', () {
      final json = MatchCodec.encode(
        matchWith(const [
          Player(
            seat: 0,
            name: 'عمر',
            role: Role.citizen,
            status: PlayerStatus.alive,
          ),
        ]),
      );
      (json['players'] as List).cast<Map<String, dynamic>>().single['gender'] =
          'a-value-from-a-later-build';

      expect(
        MatchCodec.decode(json).players.single.gender,
        PlayerGender.unspecified,
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // The saved roster
  // ───────────────────────────────────────────────────────────────────────

  group('saved group', () {
    PlayerGroup group({Map<String, PlayerGender> genders = const {}}) =>
        PlayerGroup(
          id: 3,
          name: 'شلة الجمعة',
          memberNames: const ['عمر', 'ليلى', 'ندى'],
          genders: genders,
          createdAt: now,
          lastPlayedAt: now,
          playCount: 4,
        );

    PlayerGroup roundTripGroup(PlayerGroup g) => PlayerGroupCodec.decode(
      jsonDecode(jsonEncode(PlayerGroupCodec.encode(g)))
          as Map<String, dynamic>,
      id: g.id,
    );

    test('the choice per name survives, keyed by name', () {
      final decoded = roundTripGroup(
        group(
          genders: const {
            'عمر': PlayerGender.male,
            'ليلى': PlayerGender.female,
          },
        ),
      );

      expect(decoded.genders['عمر'], PlayerGender.male);
      expect(decoded.genders['ليلى'], PlayerGender.female);
      // A name nobody chose for is simply absent, not silently male.
      expect(decoded.genders.containsKey('ندى'), isFalse);
      expect(decoded.memberNames, group().memberNames);
    });

    test('a group saved before the column decodes with an empty map', () {
      final json = PlayerGroupCodec.encode(
        group(genders: const {'عمر': PlayerGender.male}),
      )..remove('genders');

      final decoded = PlayerGroupCodec.decode(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        id: 3,
      );
      expect(decoded.genders, isEmpty);
      expect(decoded.memberNames.length, 3);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // The online room
  // ───────────────────────────────────────────────────────────────────────

  group('online room', () {
    RoomState state() => RoomState(
      phase: 'discuss',
      phaseNumber: 1,
      status: 'playing',
      hostId: 'u0',
      code: 'ABCDEF',
      serverNow: now,
      publicData: const {},
    );

    GameSnapshot viewOf(List<RoomPlayer> players) => snapshotFrom(
      state: state(),
      players: players,
      viewerSeat: 0,
      isHost: true,
      connection: ConnectionQuality.connected,
      skew: Duration.zero,
    );

    test('the roster carries each seat gender into the public view', () {
      final view = viewOf(const [
        RoomPlayer(userId: 'u0', seat: 0, name: 'عمر', gender: 'male'),
        RoomPlayer(userId: 'u1', seat: 1, name: 'ليلى', gender: 'female'),
      ]);

      expect(view.public.players[0].gender, PlayerGender.male);
      expect(view.public.players[1].gender, PlayerGender.female);
    });

    test('a row from the deployed schema without the column is unspecified', () {
      // Exactly what `players_read` returns today: the migration adding the
      // column has not been applied to production, so the client must read the
      // old shape without throwing.
      final row = RoomPlayer.fromJson(const {
        'user_id': 'u1',
        'seat': 1,
        'name': 'ليلى',
        'alive': true,
      });

      expect(row.gender, 'unspecified');
      expect(
        viewOf([row]).public.players.single.gender,
        PlayerGender.unspecified,
      );
    });

    test('an update to liveness or presence does not reset the choice', () {
      // Every death, reconnection and heartbeat goes through `copyWith`. A
      // gender dropped there would look like it persisted right up until the
      // first player died.
      const row = RoomPlayer(
        userId: 'u1',
        seat: 1,
        name: 'ليلى',
        gender: 'female',
      );

      expect(row.copyWith(alive: false).gender, 'female');
      expect(row.copyWith(connected: false).gender, 'female');
      expect(
        viewOf([row.copyWith(alive: false)]).public.players.single.gender,
        PlayerGender.female,
      );
    });
  });
}
