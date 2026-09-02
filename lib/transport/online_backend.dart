/// The seam between [OnlineTransport] and Supabase (doc 10 §7).
///
/// ## Why there is an interface here at all
///
/// The transport's job is a set of *decisions*: when to resync rather than
/// apply a delta, what a `PHASE_CLOSED` means, which client claims the host
/// seat when the host stops answering, how a countdown survives a wrong clock.
/// None of those decisions is about Supabase, and every one of them is a rule
/// out of doc 10 §8 that has to be right.
///
/// Behind this interface they are testable without a network, a project, or a
/// running Postgres — `test/support/fake_backend.dart` answers exactly the way
/// the Edge Functions do, including their refusals, and the O-cases of doc 11
/// §6 become ordinary unit tests. In front of it, [SupabaseBackend] is a
/// translation layer with no rules of its own: every method is one call, and
/// there is nothing in it to get wrong twice.
///
/// It is also the reason `lib/transport/` stays free of Flutter except for the
/// one file that names `supabase_flutter`.
library transport.online_backend;

import 'dart:async';

/// A refusal from the server, carrying the code the client acts on.
///
/// The codes are `ErrorCode` in `supabase/functions/_shared/api.ts`, verbatim.
/// They are strings rather than an enum because the set lives on the server and
/// a client that meets an unknown one should report it, not fail to parse it.
class BackendException implements Exception {
  final String code;
  final String message;

  const BackendException(this.code, this.message);

  /// The one refusal that is not an error (O7, N16): the client acted against a
  /// phase the server has already left. The cure is a resync, not a red banner.
  bool get isPhaseClosed => code == 'PHASE_CLOSED';

  /// This client is not the host. Ordinary online: only the host's device
  /// drives the phase, and every other device asked politely.
  bool get isNotHost => code == 'NOT_HOST';

  @override
  String toString() => 'BackendException($code: $message)';
}

/// The transport could not reach the server at all. Distinct from a
/// [BackendException], which *is* the server answering (O9, O10, O11).
class BackendUnreachable implements Exception {
  final Object cause;

  /// True when the failure looks like a paused free-tier project rather than a
  /// dropped connection — doc 11 O11 asks for a distinct, actionable message.
  final bool projectPaused;

  const BackendUnreachable(this.cause, {this.projectPaused = false});

  @override
  String toString() =>
      'BackendUnreachable(paused=$projectPaused, cause=$cause)';
}

/// One `room_state` row, joined to the two fields of `rooms` a client needs.
class RoomState {
  /// Server vocabulary: lobby|reveal|night|morning|opening|confront|discuss|
  /// defense|vote|result.
  final String phase;

  /// The night number during a night, the day number during a day.
  final int phaseNumber;

  /// The server's deadline for this phase, in the *server's* clock.
  final DateTime? phaseEndsAt;

  /// Whose microphone is live (doc 10 §6.1). Null during the phases where no
  /// microphone may be.
  final String? activeSpeaker;

  /// The table-visible payload for this phase. Never carries a role, a night
  /// action, a whisper body or the match seed — enforced on the way in, by the
  /// functions that write it.
  final Map<String, dynamic> publicData;

  /// lobby | playing | finished.
  final String status;

  /// The room's rules, as `rooms.settings` holds them. Public: they were chosen
  /// in the lobby in front of everybody, and every client renders against them.
  final Map<String, dynamic> settings;

  final String hostId;
  final String code;

  /// The server's clock at the moment this row was read. The whole of the
  /// skew correction (O8) is the difference between this and the local clock.
  final DateTime serverNow;

  const RoomState({
    required this.phase,
    required this.phaseNumber,
    required this.status,
    required this.hostId,
    required this.code,
    required this.serverNow,
    this.phaseEndsAt,
    this.activeSpeaker,
    this.publicData = const {},
    this.settings = const {},
  });

  factory RoomState.fromJson(Map<String, dynamic> json) => RoomState(
        phase: json['phase'] as String? ?? 'lobby',
        phaseNumber: (json['phase_number'] as num?)?.toInt() ?? 0,
        phaseEndsAt: _time(json['phase_ends_at']),
        activeSpeaker: json['active_speaker'] as String?,
        publicData: Map<String, dynamic>.from(
            (json['public_data'] as Map?) ?? const {}),
        status: json['status'] as String? ?? 'lobby',
        hostId: json['host_id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        settings:
            Map<String, dynamic>.from((json['settings'] as Map?) ?? const {}),
        serverNow: _time(json['server_now']) ?? DateTime.now().toUtc(),
      );

  RoomState copyWith({String? phase, String? status, String? hostId}) =>
      RoomState(
        phase: phase ?? this.phase,
        phaseNumber: phaseNumber,
        phaseEndsAt: phaseEndsAt,
        activeSpeaker: activeSpeaker,
        publicData: publicData,
        status: status ?? this.status,
        hostId: hostId ?? this.hostId,
        code: code,
        settings: settings,
        serverNow: serverNow,
      );

  @override
  String toString() =>
      'RoomState($phase#$phaseNumber, status=$status, endsAt=$phaseEndsAt)';
}

/// One row of `room_players_public` — everything about a player that the whole
/// room may see. There is no role here for anybody, including its owner: the
/// owner's role arrives as [OwnSeat], on a path that never fans out.
class RoomPlayer {
  final String userId;
  final int seat;
  final String name;
  final bool alive;
  final bool connected;
  final DateTime? lastSeen;

  const RoomPlayer({
    required this.userId,
    required this.seat,
    required this.name,
    this.alive = true,
    this.connected = true,
    this.lastSeen,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
        userId: json['user_id'] as String,
        seat: (json['seat'] as num).toInt(),
        name: json['name'] as String? ?? '',
        alive: json['alive'] as bool? ?? true,
        connected: json['connected'] as bool? ?? true,
        lastSeen: _time(json['last_seen']),
      );

  RoomPlayer copyWith({bool? alive, bool? connected, DateTime? lastSeen}) =>
      RoomPlayer(
        userId: userId,
        seat: seat,
        name: name,
        alive: alive ?? this.alive,
        connected: connected ?? this.connected,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

/// This client's own row, including the one secret column in the schema.
///
/// Fetched on its own rather than as part of the roster so that "the role"
/// travels on a path with exactly one recipient. Nothing merges it into
/// [RoomPlayer], and nothing puts it in a [GameSnapshot].
class OwnSeat {
  final int seat;

  /// mafia|doctor|detective|citizen, or null before the deal.
  final String? role;
  final bool alive;

  /// Fellow Mafia, by display name. Empty for every other role, and empty for
  /// a Mafioso playing alone.
  ///
  /// It comes back on the *secrets* path rather than out of the roster because
  /// the roster is a view every player in the room reads. A teammate list is a
  /// role by another name: knowing who is on your team means knowing what you
  /// are, and a client that could compute one for somebody else would have the
  /// whole game.
  final List<String> teammateNames;

  /// Whether this client already submitted tonight's action. Read back from
  /// `night_actions` (which RLS lets a player read for itself and nobody else),
  /// so a client that reconnects mid-night knows whether it still owes a move.
  final bool actedThisNight;

  /// The ballot round this client has already voted in, or null.
  final int? votedRound;

  const OwnSeat({
    required this.seat,
    this.role,
    this.alive = true,
    this.teammateNames = const [],
    this.actedThisNight = false,
    this.votedRound,
  });
}

/// One edge of the whisper graph. Public by design; the body is not here.
class WhisperRow {
  final String id;
  final int day;
  final int fromSeat;
  final int toSeat;
  final bool voided;

  /// True when this row is addressed to this client. The server does not say so
  /// in a column — the backend works it out from its own user id, because a
  /// client should not have to compare user ids to find its own whisper.
  final bool toMe;

  const WhisperRow({
    required this.id,
    required this.day,
    required this.fromSeat,
    required this.toSeat,
    this.voided = false,
    this.toMe = false,
  });
}

/// Everything one recovery fetch brings back (doc 10 §8.4).
///
/// One object rather than four calls because a resync must be *consistent*:
/// a roster read a second after the state it is merged into can disagree with
/// it, and the disagreement lands on screen as a dead player still voting.
class RoomRows {
  final RoomState state;
  final List<RoomPlayer> players;
  final OwnSeat? own;
  final List<WhisperRow> whispers;

  const RoomRows({
    required this.state,
    required this.players,
    this.own,
    this.whispers = const [],
  });
}

/// A push from Realtime.
///
/// Deltas are the happy path and snapshots are the recovery path (doc 10 §8.4),
/// so this type carries whichever the server actually sent and the transport
/// decides what it is worth: a roster delta is applied in place, a state change
/// is worth a full read, and a channel error is worth a resync.
class RoomPush {
  final RoomState? state;
  final RoomPlayer? player;

  /// The subscription broke and came back. Nothing may be assumed about what
  /// was missed, so the transport reads everything again (O12).
  final bool resyncRequired;

  /// The link is down and retries are in progress (O10).
  final bool disconnected;

  const RoomPush.state(RoomState this.state)
      : player = null,
        resyncRequired = false,
        disconnected = false;

  const RoomPush.player(RoomPlayer this.player)
      : state = null,
        resyncRequired = false,
        disconnected = false;

  const RoomPush.resync()
      : state = null,
        player = null,
        resyncRequired = true,
        disconnected = false;

  const RoomPush.disconnected()
      : state = null,
        player = null,
        resyncRequired = false,
        disconnected = true;
}

/// One WebRTC signal, addressed to this device.
///
/// The payload is opaque SDP or ICE and carries nothing about the game — which
/// is why `signals` is the one table a client writes to directly (doc 10 §4).
/// Nothing in it is worth reading and nothing in it is worth forging: the worst
/// a hostile row can do is fail to become a phone call.
class VoiceSignal {
  final String fromUserId;
  final Map<String, dynamic> payload;

  const VoiceSignal({required this.fromUserId, required this.payload});
}

/// What a client needs to join a room, before it has any state.
class RoomHandle {
  final String roomId;
  final String code;
  final int seat;
  final bool rejoined;

  const RoomHandle({
    required this.roomId,
    required this.code,
    required this.seat,
    this.rejoined = false,
  });
}

/// The Supabase surface, as narrow as the client can make it.
abstract class OnlineBackend {
  /// Anonymous sign-in, or the existing session. Returns the user id.
  ///
  /// Anonymous by design (doc 10 §10): display names only, no email, no PII.
  Future<String> ensureSession();

  /// The signed-in user id, or null before [ensureSession].
  String? get userId;

  /// Invokes an Edge Function. Throws [BackendException] on a refusal and
  /// [BackendUnreachable] when the server could not be reached at all.
  Future<Map<String, dynamic>> call(String function, Map<String, dynamic> body);

  /// Creates a room and takes seat 0.
  Future<RoomHandle> createRoom({required String name});

  /// Joins by code, or rejoins a seat this user already holds (O4).
  Future<RoomHandle> joinRoom({required String code, required String name});

  /// One consistent read of everything this client may see.
  Future<RoomRows> fetchRows(String roomId);

  /// The live feed for a room. Broadcast: several listeners, and a late one
  /// misses nothing that matters because the transport resyncs on subscribe.
  Stream<RoomPush> pushes(String roomId);

  /// A whisper's body, readable only by its two parties (RLS).
  Future<String?> whisperBody(String whisperId);

  /// Blocks a sender for this client only. Never visible to the blocked party
  /// (H-E9).
  Future<void> blockSender(String roomId, String senderId);

  /// The senders this client has blocked.
  Future<Set<String>> blockedSenders(String roomId);

  /// Writes one WebRTC signal for another member of the room.
  ///
  /// On the backend rather than on a voice-only interface because it is one
  /// insert against a table this client already has a session for, and because
  /// a second Supabase client for the call would be a second connection to
  /// keep alive on a free tier that charges for exactly that.
  Future<void> sendSignal(
    String roomId,
    String toUserId,
    Map<String, dynamic> payload,
  );

  /// The signals addressed to this device, live.
  ///
  /// A broadcast stream that may legitimately deliver nothing at all: a room
  /// where every player is on text mode is a room where nobody signals, and
  /// that is a working room.
  Stream<VoiceSignal> signals(String roomId);

  Future<void> dispose();
}

DateTime? _time(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value as String)?.toUtc();
}
