import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mafia_master/transport/metered_voice_link.dart';
import 'package:mafia_master/transport/supabase_backend.dart';
import 'package:mafia_master/transport/voice_link.dart';
import 'package:mafia_master/transport/online_backend.dart';

/// One disposable authenticated player, in one browser.
///
/// The previous version ran both players in a single page and they ended up
/// being the same person: GoTrue keeps tabs of the same origin in step through
/// a `BroadcastChannel`, so the second anonymous sign-in overwrote the first
/// and the engine — correctly — refused to call itself. A probe cannot patch
/// its way out of that honestly, because the thing being tested is two
/// independent clients. So this class is now *one side*, and the runner starts
/// two browsers with two profiles that share nothing.
///
/// Nothing here logs an id, a code, a token or an address. Identity is
/// published only as `String.hashCode` in hex, which is enough for the runner
/// to assert that A's peer is B and B's peer is A, and is not reversible.
class HostedVoiceProbe {
  HostedVoiceProbe({required this.isHost, this.code});

  /// The host creates the room; the guest joins the code the host published.
  final bool isHost;
  final String? code;

  late final SupabaseClient client;
  late final SupabaseBackend backend;
  MeteredVoiceLink? link;

  final evidence = <String, Object?>{};

  String? roomId;

  /// Only the host has this, and only the runner reads it — to start the guest.
  /// It is never written into the report.
  String? createdCode;

  var _roster = <VoicePeer>[];
  String selfId = '';
  String peerId = '';
  int peerSeat = 0;

  static String fingerprint(String id) =>
      id.hashCode.toUnsigned(32).toRadixString(16);

  /// Membership comes from Supabase, never from Metered presence.
  Future<List<VoicePeer>> _readRoster() async {
    final rows = await client
        .from('room_players_public')
        .select('user_id,seat,status,kicked')
        .eq('room_id', roomId!);
    return [
      for (final row in rows)
        if (row['status'] != 'left' && row['kicked'] != true)
          VoicePeer(
            userId: row['user_id'] as String,
            seat: (row['seat'] as num).toInt(),
          ),
    ];
  }

  /// Called the moment the room exists, before the wait for the guest. The
  /// host cannot wait for a roster of two until the runner has been handed the
  /// code that lets the guest join — publishing it afterwards is a deadlock.
  Future<void> open({void Function(String code)? onRoomCreated}) async {
    client = SupabaseClient(
      const String.fromEnvironment('SUPABASE_URL'),
      const String.fromEnvironment('SUPABASE_KEY'),
    );
    backend = SupabaseBackend(client);
    await backend.ensureSession();
    selfId = backend.userId ?? '';
    evidence['auth'] = selfId.isNotEmpty;
    evidence['self'] = fingerprint(selfId);

    if (isHost) {
      final room = await backend.call('create_room', {
        'name': 'VoiceProbeA',
        'gender': 'male',
        'visibility': 'private',
      });
      roomId = room['roomId'] as String;
      createdCode = room['code'] as String;
      onRoomCreated?.call(createdCode!);
    } else {
      final joined = await backend.call('join_room', {
        'code': code,
        'name': 'VoiceProbeB',
        'gender': 'female',
      });
      roomId = joined['roomId'] as String;
    }
    evidence['room'] = roomId != null;

    // The host waits for the guest to arrive; the guest waits for the roster to
    // show them both. Neither side negotiates against a roster of one.
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      _roster = await _readRoster();
      if (_roster.length >= 2) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    evidence['rosterSize'] = _roster.length;
    if (_roster.length != 2) {
      throw StateError('roster did not reach two members');
    }

    final others = _roster.where((peer) => peer.userId != selfId).toList();
    evidence['selfInRoster'] = others.length == _roster.length - 1;
    if (others.length != 1) throw StateError('roster is not two distinct members');
    peerId = others.single.userId;
    peerSeat = others.single.seat;
    evidence['peer'] = fingerprint(peerId);
    evidence['distinctIdentities'] = selfId != peerId;
    if (selfId == peerId) throw StateError('probe sessions synchronized');

    final grant = await backend.call('realtime_token', {'roomId': roomId});
    evidence['grant'] = true;
    evidence['token'] = grant['token'] is String;
    evidence['channel'] = grant['channel'] is String;
    evidence['session'] = grant['sessionId'] is String;
    // A signalling grant that carries game state would leak roles into a
    // transport the players' own browsers can read.
    const forbidden = {'role', 'roles', 'seatRole', 'team', 'alive', 'alignment'};
    evidence['grantCarriesNoGameState'] =
        grant.keys.every((key) => !forbidden.contains(key));

    link = MeteredVoiceLink(
      backend: backend,
      roomId: roomId!,
      roster: () => _roster,
    );
    final live = DateTime.now().add(const Duration(seconds: 30));
    while (!link!.connected && DateTime.now().isBefore(live)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    evidence['metered'] = link!.connected;
    evidence['distinctAfterAuthorization'] = link!.selfId != peerId;
    if (!link!.connected) throw StateError('metered transport did not come up');
  }

  /// Re-reads membership from Supabase. The engine is allowed to talk to
  /// whoever this returns and to nobody else.
  Future<void> refreshRoster() async {
    _roster = await _readRoster();
  }

  Future<void> dispose() async {
    try {
      await link?.dispose();
    } catch (_) {
      evidence['linkCleanup'] = false;
    }
    if (roomId != null) {
      // Verified before it is acted on: this membership is one the probe made.
      try {
        await backend.call('leave_room', {'roomId': roomId});
        evidence['roomCleanup'] = true;
      } on BackendException catch (e) {
        evidence['roomCleanupError'] = e.code;
      } catch (_) {
        evidence['roomCleanupError'] = 'unreachable';
      }
    }
    try {
      await backend.dispose();
    } catch (_) {
      evidence['backendCleanup'] = false;
    }
    try {
      await client.dispose();
    } catch (_) {
      evidence['clientCleanup'] = false;
    }
  }
}
