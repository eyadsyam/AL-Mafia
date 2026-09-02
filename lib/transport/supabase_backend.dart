import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'online_backend.dart';

/// [OnlineBackend] over Supabase. A translation layer with no rules of its own.
///
/// Every method here is one call and one decoding. The decisions — when to
/// resync, what a refusal means, who claims the host seat — are all in
/// [OnlineTransport], where they can be tested without a network. What is left
/// is the part that can only be got wrong once: the table names, the filters,
/// and the one rule this file *does* keep, which is that the client reads
/// `room_players_public` and never `room_players`.
///
/// ## The reads, and why they are these reads
///
/// | What | Where from | Why not somewhere else |
/// |---|---|---|
/// | phase, deadline, payload | `room_state` | the only public state there is |
/// | code, host, status | `rooms_public` | `rooms` carries `match_seed`, which no client may see (doc 10 §10) |
/// | roster | `room_players_public` | seats, names, alive, connected — and no role column at all |
/// | own night action | `night_actions` | RLS returns this client's rows and nobody else's |
/// | own ballot | `votes` | same |
/// | whisper graph | `whisper_meta` | public by design; bodies are a separate table |
/// | own role + teammates | `my_team` function | `role` has no client column privilege, so no view or route can return it |
class SupabaseBackend implements OnlineBackend {
  final SupabaseClient client;

  RealtimeChannel? _channel;
  StreamController<RoomPush>? _pushes;

  RealtimeChannel? _signalChannel;
  StreamController<VoiceSignal>? _signals;

  /// The caller's own role and, for a Mafioso, the fellow Mafia.
  ///
  /// Cached because a role does not change once dealt, and because the call
  /// that answers it is the one call in the app that reads a role at all —
  /// `room_players.role` carries no column privilege for any client role, so
  /// there is no view, policy or PostgREST route that could return it instead.
  _Identity? _identity;

  SupabaseBackend(this.client);

  /// Boots Supabase and returns a backend over the shared client.
  ///
  /// Anonymous auth and no PII (doc 10 §10): the only thing a player gives the
  /// server is a display name, and it is not an account.
  static Future<SupabaseBackend> initialize({
    required String url,
    required String publishableKey,
  }) async {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    return SupabaseBackend(Supabase.instance.client);
  }

  @override
  String? get userId => client.auth.currentUser?.id;

  @override
  Future<String> ensureSession() async {
    final existing = client.auth.currentUser;
    if (existing != null) return existing.id;
    final response = await _guarded(() => client.auth.signInAnonymously());
    final user = response.user;
    if (user == null) {
      throw const BackendException('UNAUTHENTICATED', 'no session');
    }
    return user.id;
  }

  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, dynamic> body,
  ) async {
    final response = await _guarded(
      () => client.functions.invoke(function, body: body),
    );

    final data = response.data;
    if (response.status >= 400) {
      // The Edge Functions answer a refusal with `{error, message}` and the
      // client acts on the code, not on the status: `PHASE_CLOSED` at 400 is
      // an ordinary event and a 400 with no code is a bug.
      final map = data is Map ? data : const {};
      throw BackendException(
        map['error'] as String? ?? 'BAD_REQUEST',
        map['message'] as String? ?? 'the request was refused',
      );
    }
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  @override
  Future<RoomHandle> createRoom({required String name}) async {
    await ensureSession();
    final result = await call('create_room', {'name': name});
    return RoomHandle(
      roomId: result['roomId'] as String,
      code: result['code'] as String,
      seat: (result['seat'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<RoomHandle> joinRoom({
    required String code,
    required String name,
  }) async {
    await ensureSession();
    final result = await call('join_room', {'code': code, 'name': name});
    return RoomHandle(
      roomId: result['roomId'] as String,
      code: code.toUpperCase(),
      seat: (result['seat'] as num?)?.toInt() ?? 0,
      rejoined: result['rejoined'] as bool? ?? false,
    );
  }

  @override
  Future<RoomRows> fetchRows(String roomId) async {
    final me = userId;

    // One round of parallel reads rather than a chain: a resync that took six
    // sequential round trips would be slowest exactly when the network is
    // worst, which is the only time it runs.
    final results = await _guarded(() => Future.wait([
          client
              .from('room_state')
              .select()
              .eq('room_id', roomId)
              .maybeSingle(),
          client
              .from('rooms_public')
              .select('code, host_id, status, settings')
              .eq('id', roomId)
              .maybeSingle(),
          client
              .from('room_players_public')
              .select()
              .eq('room_id', roomId)
              .order('seat'),
          client.from('night_actions').select('night').eq('room_id', roomId),
          client.from('votes').select('day, round, voter_id').eq('room_id', roomId),
          client
              .from('whisper_meta')
              .select('id, day, from_id, to_id, voided')
              .eq('room_id', roomId),
          client.rpc('server_now'),
        ]));

    final stateRow = results[0] as Map<String, dynamic>?;
    final roomRow = results[1] as Map<String, dynamic>?;
    if (stateRow == null || roomRow == null) {
      throw const BackendException('ROOM_NOT_FOUND', 'no such room');
    }
    final playerRows = (results[2] as List).cast<Map<String, dynamic>>();
    final actionRows = (results[3] as List).cast<Map<String, dynamic>>();
    final voteRows = (results[4] as List).cast<Map<String, dynamic>>();
    final whisperRows = (results[5] as List).cast<Map<String, dynamic>>();

    final state = RoomState.fromJson({
      ...stateRow,
      ...roomRow,
      'server_now': results[6],
    });

    final players = [
      for (final row in playerRows) RoomPlayer.fromJson(row),
    ];

    final seatOf = {for (final p in players) p.userId: p.seat};
    final mine = players.where((p) => p.userId == me).toList();
    OwnSeat? own;
    if (mine.isNotEmpty) {
      final identity = await _ownIdentity(roomId, state.status);
      own = OwnSeat(
        seat: mine.first.seat,
        role: identity.role,
        alive: mine.first.alive,
        teammateNames: identity.teammates,
        actedThisNight: actionRows
            .any((row) => (row['night'] as num).toInt() == state.phaseNumber),
        votedRound: voteRows
            .where((row) =>
                row['voter_id'] == me &&
                (row['day'] as num).toInt() == state.phaseNumber)
            .map((row) => (row['round'] as num).toInt())
            .fold<int?>(null, (best, r) => best == null || r > best ? r : best),
      );
    }

    return RoomRows(
      state: state,
      players: players,
      own: own,
      whispers: [
        for (final row in whisperRows)
          WhisperRow(
            id: row['id'] as String,
            day: (row['day'] as num).toInt(),
            fromSeat: seatOf[row['from_id']] ?? -1,
            toSeat: seatOf[row['to_id']] ?? -1,
            voided: row['voided'] as bool? ?? false,
            toMe: row['to_id'] == me,
          ),
      ],
    );
  }

  /// What this device is, asked once and remembered.
  ///
  /// Not asked at all while the room is still a lobby: there is no role to
  /// learn before `start_match` deals them, and asking would put one call per
  /// resync on the quietest screen in the app.
  ///
  /// A failure here is **not** swallowed. It used to be, when this call only
  /// added teammate names to a card that already knew it was Mafia; now it is
  /// the whole of how a player learns their role, and a reveal card with a
  /// blank on it is worse than a resync that says it could not finish.
  /// Once an answer arrives it is cached, so a later flaky moment cannot take
  /// the role away again.
  Future<_Identity> _ownIdentity(String roomId, String status) async {
    if (status == 'lobby') return const _Identity(null, <String>[]);

    final cached = _identity;
    if (cached != null) return cached;

    final result = await call('my_team', {'roomId': roomId});
    final identity = _Identity(
      result['role'] as String?,
      <String>[
        for (final name in (result['teammates'] as List? ?? const []))
          name as String,
      ],
    );
    // A null role means the deal has not landed for this seat yet — a race
    // against `start_match`, not an answer. Caching it would freeze the blank.
    if (identity.role != null) _identity = identity;
    return identity;
  }

  /// Realtime, over exactly the two published tables (doc 10 §9 migration).
  ///
  /// Nothing is decoded optimistically: a `room_state` change carries the new
  /// row and is handed on as a delta, and anything else — a resubscribe, a
  /// channel error — is reported as "read it all again", because the one thing
  /// a client must never do is guess what it missed.
  @override
  Stream<RoomPush> pushes(String roomId) {
    final existing = _pushes;
    if (existing != null) return existing.stream;

    final controller = StreamController<RoomPush>.broadcast();
    _pushes = controller;

    final channel = client.channel('room:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'room_state',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          // The row arrives without the two fields that live on `rooms`, so it
          // is passed on as a delta and the transport decides whether the
          // change is worth a full read. A phase change always is.
          controller.add(RoomPush.state(RoomState.fromJson({
            ...payload.newRecord,
            'status': 'playing',
            'host_id': '',
            'code': '',
            'server_now': DateTime.now().toUtc().toIso8601String(),
          })));
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'room_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row.isEmpty) {
            controller.add(const RoomPush.resync());
            return;
          }
          controller.add(RoomPush.player(RoomPlayer.fromJson(row)));
        },
      );

    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          controller.add(const RoomPush.resync());
        case RealtimeSubscribeStatus.channelError:
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          controller.add(const RoomPush.disconnected());
      }
    });

    _channel = channel;
    return controller.stream;
  }

  /// One WebRTC signal, written straight to `signals`.
  ///
  /// The one table a client inserts into directly (doc 10 §4): the payload is
  /// opaque SDP or ICE, it says nothing about the game, and the policy
  /// (`from_id = auth.uid()`) means a client can only ever sign its own.
  ///
  /// Failures are swallowed. A signal that does not arrive costs one peer
  /// connection, and doc 10 §1.2 does not allow that to cost anything else.
  @override
  Future<void> sendSignal(
    String roomId,
    String toUserId,
    Map<String, dynamic> payload,
  ) async {
    final me = userId;
    if (me == null) return;
    try {
      await client.from('signals').insert({
        'room_id': roomId,
        'from_id': me,
        'to_id': toUserId,
        'payload': payload,
      });
    } catch (_) {
      // Deliberately silent — see above.
    }
  }

  /// The signals addressed to this device.
  ///
  /// A channel of its own rather than another listener on `room:` because the
  /// two have different lifetimes and different consequences: the room channel
  /// is the match and a break in it is a resync, while this one is a phone call
  /// and a break in it is a phone call that ends.
  ///
  /// The filter is `to_id`, which is also the RLS policy, so a client that
  /// asked for somebody else's offers would be told about none of them.
  @override
  Stream<VoiceSignal> signals(String roomId) {
    final existing = _signals;
    if (existing != null) return existing.stream;

    final me = userId;
    final controller = StreamController<VoiceSignal>.broadcast();
    _signals = controller;
    if (me == null) return controller.stream;

    final channel = client.channel('signals:$roomId:$me')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'signals',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'to_id',
          value: me,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row['room_id'] != roomId) return;
          controller.add(VoiceSignal(
            fromUserId: row['from_id'] as String,
            payload: Map<String, dynamic>.from(
                (row['payload'] as Map?) ?? const {}),
          ));
        },
      );

    channel.subscribe();
    _signalChannel = channel;
    return controller.stream;
  }

  @override
  Future<String?> whisperBody(String whisperId) async {
    final row = await _guarded(() => client
        .from('whisper_content')
        .select('body')
        .eq('whisper_id', whisperId)
        .maybeSingle());
    return row?['body'] as String?;
  }

  @override
  Future<void> blockSender(String roomId, String senderId) async {
    final me = userId;
    if (me == null) return;
    await _guarded(() => client.from('whisper_blocks').insert({
          'room_id': roomId,
          'blocker_id': me,
          'blocked_id': senderId,
        }));
  }

  @override
  Future<Set<String>> blockedSenders(String roomId) async {
    final rows = await _guarded(() => client
        .from('whisper_blocks')
        .select('blocked_id')
        .eq('room_id', roomId));
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['blocked_id'] as String,
    };
  }

  @override
  Future<void> dispose() async {
    final channel = _channel;
    if (channel != null) await client.removeChannel(channel);
    _channel = null;
    await _pushes?.close();
    _pushes = null;

    final signals = _signalChannel;
    if (signals != null) await client.removeChannel(signals);
    _signalChannel = null;
    await _signals?.close();
    _signals = null;
  }

  /// Turns "the server did not answer" into [BackendUnreachable], and tells a
  /// paused free-tier project apart from a dropped connection (O9, O10, O11).
  ///
  /// The distinction is worth the string match: a paused project needs somebody
  /// to open a dashboard, and telling that player «مافيش نت» would send them to
  /// restart a router that was never the problem.
  Future<T> _guarded<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on BackendException {
      rethrow;
    } on AuthException catch (e) {
      throw BackendException('UNAUTHENTICATED', e.message);
    } on PostgrestException catch (e) {
      throw BackendException(e.code ?? 'BAD_REQUEST', e.message);
    } catch (e) {
      final text = e.toString().toLowerCase();
      final paused = text.contains('paused') ||
          text.contains('503') ||
          text.contains('project is inactive');
      throw BackendUnreachable(e, projectPaused: paused);
    }
  }
}

/// One device's own secret: what it is, and — only for the Mafia — who is with
/// it. Deliberately not part of [OwnSeat]: this is the cached answer to one
/// call, and [OwnSeat] is rebuilt from the roster on every read.
class _Identity {
  final String? role;
  final List<String> teammates;

  const _Identity(this.role, this.teammates);
}
