import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../engine/models/enums.dart' show Alignment;
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

  /// One ghost-chat feed per room, so several screens watching the graveyard
  /// share a single Realtime channel.
  final Map<String, StreamController<List<GhostRow>>> _ghost = {};

  RealtimeChannel? _signalChannel;
  StreamController<VoiceSignal>? _signals;

  /// The caller's own role and, for a Mafioso, the fellow Mafia.
  ///
  /// Cached because a role does not change once dealt, and because the call
  /// that answers it is the one call in the app that reads a role at all —
  /// `room_players.role` carries no column privilege for any client role, so
  /// there is no view, policy or PostgREST route that could return it instead.
  _Identity? _identity;
  String? _identityRoomId;

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
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  /// A refusal from an Edge Function, as the code the client acts on.
  ///
  /// `functions.invoke` **throws** on any non-2xx — it does not hand back a
  /// response with a status to inspect — so the `if (status >= 400)` this used
  /// to do was unreachable, and every refusal fell through the catch-all in
  /// [_guarded] and came back as [BackendUnreachable]. The consequences were
  /// all of one shape and none of them true: a `PHASE_CLOSED` tap half a second
  /// late became «الاتصال قطع» and «اختيارك متسجلش» instead of a resync onto
  /// the phase the room had actually moved to; a full room became a network
  /// failure; `NOT_HOST` became one too, and the client stopped trusting a
  /// connection that was working perfectly.
  ///
  /// So the refusal is decoded here, from the `{error, message}` every function
  /// answers with. A 5xx is the one case that really is the server being
  /// unavailable rather than saying no, and it keeps the old meaning.
  /// Static, and public, so the translation can be tested without a network:
  /// it is a pure function of the exception, and the bug it replaces was
  /// invisible precisely because nothing could reach it.
  static Object refusalFor(FunctionException e) {
    final details = e.details;
    final map = details is Map ? details : const {};
    final code = map['error'] as String?;
    if (code == null && e.status >= 500) {
      return BackendUnreachable(
        e,
        projectPaused: '$details'.toLowerCase().contains('paused'),
      );
    }
    return BackendException(
      code ?? 'BAD_REQUEST',
      map['message'] as String? ?? 'the request was refused',
    );
  }

  @override
  Future<RoomHandle> createRoom({
    required String name,
    String gender = 'unspecified',
  }) async {
    await ensureSession();
    final result = await call('create_room', {'name': name, 'gender': gender});
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
    String gender = 'unspecified',
  }) async {
    await ensureSession();
    final result = await call('join_room', {
      'code': code,
      'name': name,
      'gender': gender,
    });
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
    final results = await _guarded(
      () => Future.wait([
        client.from('room_state').select().eq('room_id', roomId).maybeSingle(),
        client
            .from('rooms_public')
            .select('code, host_id, status, settings, visibility, title')
            .eq('id', roomId)
            .maybeSingle(),
        client
            .from('room_players_public')
            .select()
            .eq('room_id', roomId)
            .order('seat'),
        // `used_bullet` rides along on the query that was already being
        // made. RLS returns this client's rows and nobody else's, which is
        // exactly the audience for "have I spent mine" — the fact that a
        // seat holds a bullet at all is a fact about its role.
        client
            .from('night_actions')
            .select('night, used_bullet')
            .eq('room_id', roomId),
        client
            .from('votes')
            .select('day, round, voter_id, target_id')
            .eq('room_id', roomId),
        client
            .from('whisper_meta')
            .select('id, day, from_id, to_id, voided')
            .eq('room_id', roomId),
        client.rpc('server_now'),
      ]),
    );

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

    final players = [for (final row in playerRows) RoomPlayer.fromJson(row)];

    final seatOf = {for (final p in players) p.userId: p.seat};
    final mine = players.where((p) => p.userId == me).toList();
    OwnSeat? own;
    if (mine.isNotEmpty) {
      final identity = await _ownIdentity(roomId, state.phase);
      own = OwnSeat(
        seat: mine.first.seat,
        role: identity.role,
        alive: mine.first.alive,
        teammateNames: identity.teammates,
        actedThisNight: actionRows.any(
          (row) => (row['night'] as num).toInt() == state.phaseNumber,
        ),
        // Any night, not tonight: a bullet is spent once for the whole match.
        bulletSpent: actionRows.any((row) => row['used_bullet'] == true),
        votedRound: voteRows
            .where(
              (row) =>
                  row['voter_id'] == me &&
                  (row['day'] as num).toInt() == state.phaseNumber,
            )
            .map((row) => (row['round'] as num).toInt())
            .fold<int?>(null, (best, r) => best == null || r > best ? r : best),
      );
    }

    return RoomRows(
      state: state,
      players: players,
      own: own,
      ballots: _ballotsFrom(voteRows, state: state, seatOf: seatOf),
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

  @override
  Future<Map<int, int?>> ballots(String roomId) async {
    final results = await _guarded(
      () => Future.wait<dynamic>([
        client
            .from('room_state')
            .select('phase, phase_number')
            .eq('room_id', roomId)
            .maybeSingle(),
        client
            .from('votes')
            .select('day, round, voter_id, target_id')
            .eq('room_id', roomId),
        client
            .from('room_players_public')
            .select('user_id, seat')
            .eq('room_id', roomId),
      ]),
    );

    final stateRow = results[0] as Map<String, dynamic>?;
    if (stateRow == null) return const {};

    final seatOf = {
      for (final row in (results[2] as List).cast<Map<String, dynamic>>())
        row['user_id'] as String: (row['seat'] as num).toInt(),
    };

    return _ballotsFromRows(
      (results[1] as List).cast<Map<String, dynamic>>(),
      phase: stateRow['phase'] as String? ?? '',
      day: (stateRow['phase_number'] as num?)?.toInt() ?? 0,
      seatOf: seatOf,
    );
  }

  /// The current day's ballot, as seats.
  ///
  /// ## Why the round matters
  ///
  /// A tie produces a revote, and the revote's rows sit beside the ones that
  /// tied under the same `(day, voter)` with a higher `round`. Drawing lines
  /// for both would show the table a graph of two different votes at once, and
  /// the older one would be the wrong answer stated confidently. Only the
  /// highest round present is kept.
  ///
  /// ## Why it is scoped to the open day
  ///
  /// Rows for a day that has closed are readable by everyone by design — that
  /// is the tally. They are not this: this is *intent, while it can still
  /// change*, and rendering yesterday's settled ballot as though it were live
  /// would be the app inventing a fact.
  static Map<int, int?> _ballotsFrom(
    List<Map<String, dynamic>> rows, {
    required RoomState state,
    required Map<String, int> seatOf,
  }) => _ballotsFromRows(
    rows,
    phase: state.phase,
    day: state.phaseNumber,
    seatOf: seatOf,
  );

  static Map<int, int?> _ballotsFromRows(
    List<Map<String, dynamic>> rows, {
    required String phase,
    required int day,
    required Map<String, int> seatOf,
  }) {
    if (phase != 'vote') return const {};

    final today = rows.where((row) => (row['day'] as num).toInt() == day);
    if (today.isEmpty) return const {};

    final round = today
        .map((row) => (row['round'] as num).toInt())
        .reduce((a, b) => a > b ? a : b);

    final out = <int, int?>{};
    for (final row in today) {
      if ((row['round'] as num).toInt() != round) continue;
      final voter = seatOf[row['voter_id']];
      if (voter == null) continue;
      out[voter] = seatOf[row['target_id']];
    }
    return out;
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
  Future<_Identity> _ownIdentity(String roomId, String phase) async {
    if (phase == 'lobby') return const _Identity(null, <String>[]);

    final cached = _identity;
    if (cached != null && _identityRoomId == roomId) return cached;

    final result = await call('my_team', {'roomId': roomId});
    final identity = _Identity(result['role'] as String?, <String>[
      for (final name in (result['teammates'] as List? ?? const []))
        name as String,
    ]);
    // A null role means the deal has not landed for this seat yet — a race
    // against `start_match`, not an answer. Caching it would freeze the blank.
    if (identity.role != null) {
      _identity = identity;
      _identityRoomId = roomId;
    }
    return identity;
  }

  /// Realtime, over the published tables (doc 10 §9 migration; the whisper
  /// graph joined them in `whisper_graph_realtime`).
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
          controller.add(
            RoomPush.stateDelta(
              RoomState.fromJson({
                ...payload.newRecord,
                'status': 'playing',
                'host_id': '',
                'code': '',
                'server_now': DateTime.now().toUtc().toIso8601String(),
              }),
            ),
          );
        },
      )
      // Task 10 — the host can change the room's rules while nine people are
      // looking at the lobby. `rooms` carries no phase, so there is nothing to
      // decode into a delta: this asks for a full read, which is doc 10 §9's
      // rule for everything a client did not watch happen.
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: roomId,
        ),
        callback: (_) => controller.add(const RoomPush.resync()),
      )
      // A whisper is written between phases, and the graph is read only on a
      // full read (once per phase): the recipient used to get the chime and
      // the card at the *next* phase. The graph is public by design (doc 09
      // §3.1), the row reaches room members only (RLS holds on the stream),
      // and a whisper is a once-a-day event, so it is worth the read.
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'whisper_meta',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (_) => controller.add(const RoomPush.resync()),
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
          controller.add(
            VoiceSignal(
              fromUserId: row['from_id'] as String,
              payload: Map<String, dynamic>.from(
                (row['payload'] as Map?) ?? const {},
              ),
            ),
          );
        },
      );

    channel.subscribe();
    _signalChannel = channel;
    return controller.stream;
  }

  @override
  Future<String?> whisperBody(String whisperId) async {
    final row = await _guarded(
      () => client
          .from('whisper_content')
          .select('body')
          .eq('whisper_id', whisperId)
          .maybeSingle(),
    );
    return row?['body'] as String?;
  }

  @override
  Stream<List<GhostRow>> ghostMessages(String roomId) {
    final existing = _ghost[roomId];
    if (existing != null) return existing.stream;

    // Kept as a running list rather than as individual inserts, because the
    // screen wants a conversation and a conversation is a list. The first
    // emission is the backlog, so a player eliminated on day three arrives to
    // find what was said on day two.
    final rows = <GhostRow>[];
    late final StreamController<List<GhostRow>> controller;

    Future<void> load() async {
      try {
        final data = await client
            .from('ghost_messages')
            .select('id, author_id, body, created_at')
            .eq('room_id', roomId)
            .order('created_at');
        rows
          ..clear()
          ..addAll([
            for (final row in (data as List).cast<Map<String, dynamic>>())
              _ghostRow(row),
          ]);
        if (!controller.isClosed) controller.add(List.unmodifiable(rows));
      } catch (_) {
        // A living caller lands here with an empty list, which is the correct
        // answer and not an error worth surfacing.
        if (!controller.isClosed) controller.add(const []);
      }
    }

    final channel = client.channel('ghost:$roomId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'ghost_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: roomId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row.isEmpty) return;
          final message = _ghostRow(row);
          if (rows.any((existing) => existing.id == message.id)) return;
          rows.add(message);
          if (!controller.isClosed) controller.add(List.unmodifiable(rows));
        },
      );

    controller = StreamController<List<GhostRow>>.broadcast(
      onListen: load,
      onCancel: () {
        _ghost.remove(roomId);
        client.removeChannel(channel);
      },
    );
    _ghost[roomId] = controller;
    channel.subscribe();
    return controller.stream;
  }

  static GhostRow _ghostRow(Map<String, dynamic> row) => GhostRow(
    id: row['id'] as String,
    authorId: row['author_id'] as String,
    body: row['body'] as String? ?? '',
    at:
        DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  @override
  Future<Prediction?> myPrediction(String roomId) async {
    final me = userId;
    if (me == null) return null;
    final row = await _guarded(
      () => client
          .from('predictions')
          .select('winner, mafia_seats')
          .eq('room_id', roomId)
          .eq('user_id', me)
          .maybeSingle(),
    );
    if (row == null) return null;
    return Prediction(
      winner: row['winner'] == 'mafia' ? Alignment.mafia : Alignment.town,
      mafiaSeats: {
        for (final seat in (row['mafia_seats'] as List? ?? const []))
          (seat as num).toInt(),
      },
    );
  }

  @override
  Future<void> blockSender(String roomId, String senderId) async {
    final rows = await fetchRows(roomId);
    final seat = rows.players
        .where((p) => p.userId == senderId)
        .firstOrNull
        ?.seat;
    if (seat == null)
      throw const BackendException('BAD_REQUEST', 'unknown player');
    await call('player_safety', {
      'action': 'block',
      'roomId': roomId,
      'seat': seat,
    });
  }

  @override
  Future<Set<String>> blockedSenders(String roomId) async {
    final rows = await _guarded(
      () => client
          .from('whisper_blocks')
          .select('blocked_id')
          .eq('room_id', roomId),
    );
    final global = await _guarded(
      () => client.from('player_blocks').select('blocked_id'),
    );
    return {
      for (final row in global) row['blocked_id'] as String,
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
    } on FunctionsFetchException {
      // The request never reached a function. This one really is the network.
      rethrow;
    } on FunctionException catch (e) {
      throw refusalFor(e);
    } on AuthException catch (e) {
      throw BackendException('UNAUTHENTICATED', e.message);
    } on PostgrestException catch (e) {
      throw BackendException(e.code ?? 'BAD_REQUEST', e.message);
    } catch (e) {
      final text = e.toString().toLowerCase();
      final paused =
          text.contains('paused') ||
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
