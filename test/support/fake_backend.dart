import 'dart:async';

import 'package:mafia_master/transport/online_backend.dart';

/// A programmable [OnlineBackend] — the server, as far as a client can tell.
///
/// ## Why the fake answers rather than simulates
///
/// The Edge Functions are the rules and they are tested where they run
/// (`supabase/tests/`). What the *client* has to get right is everything that
/// happens around an answer: a refusal it should absorb, a refusal it should
/// surface, a silence it should retry, a push it should not trust. Those are
/// decisions about responses, so this fake produces responses — programmed
/// ones, including the refusals — instead of re-implementing a game server
/// that would then have to be kept in step with the real one.
///
/// Every call is recorded in [calls], so a test can assert on what was *not*
/// sent as easily as on what was: "a client that is not the host makes no
/// request at all" is a property of the call log, and it is the whole of doc
/// 10 §7's rule that one device drives.
class FakeBackend implements OnlineBackend {
  FakeBackend({
    required this.roomId,
    required RoomState state,
    required List<RoomPlayer> players,
    OwnSeat? own,
    List<WhisperRow> whispers = const [],
    this.userId = 'u0',
  })  : _state = state,
        _players = players,
        _own = own,
        _whispers = whispers;

  final String roomId;

  @override
  String? userId;

  RoomState _state;
  List<RoomPlayer> _players;
  OwnSeat? _own;
  List<WhisperRow> _whispers;

  final _pushes = StreamController<RoomPush>.broadcast();

  /// Every call the transport made, in order.
  final List<FakeCall> calls = <FakeCall>[];

  /// How many times the transport asked for a full read.
  int fetches = 0;

  /// Refusals to hand back, by function name. Consumed on use unless
  /// [stickyRefusals] holds the name, so a test can make one call fail and the
  /// retry succeed.
  final Map<String, BackendException> refusals = {};
  final Set<String> stickyRefusals = {};

  /// When true, everything throws [BackendUnreachable] — the network, gone.
  bool unreachable = false;
  bool projectPaused = false;

  /// Bodies by whisper id.
  final Map<String, String> bodies = {};
  Set<String> blocked = {};

  /// What a successful call returns, by function name.
  final Map<String, Map<String, dynamic>> responses = {};

  // ---------------------------------------------------------------------------
  // Driving the fake
  // ---------------------------------------------------------------------------

  RoomState get state => _state;

  void setState(RoomState next, {bool push = true}) {
    _state = next;
    if (push) _pushes.add(RoomPush.state(next));
  }

  void setPlayers(List<RoomPlayer> players) => _players = players;

  void setOwn(OwnSeat? own) => _own = own;

  void setWhispers(List<WhisperRow> whispers) => _whispers = whispers;

  void pushPlayer(RoomPlayer player) {
    _players = [
      for (final p in _players)
        if (p.userId == player.userId) player else p,
    ];
    _pushes.add(RoomPush.player(player));
  }

  void pushResync() => _pushes.add(const RoomPush.resync());

  void pushDisconnected() => _pushes.add(const RoomPush.disconnected());

  bool called(String function) => calls.any((c) => c.function == function);

  FakeCall? lastCall(String function) {
    for (final call in calls.reversed) {
      if (call.function == function) return call;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // OnlineBackend
  // ---------------------------------------------------------------------------

  @override
  Future<String> ensureSession() async {
    _guard();
    return userId ??= 'u0';
  }

  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, dynamic> body,
  ) async {
    _guard();
    calls.add(FakeCall(function, body));
    final refusal = refusals[function];
    if (refusal != null) {
      if (!stickyRefusals.contains(function)) refusals.remove(function);
      throw refusal;
    }
    return responses[function] ?? const {'ok': true};
  }

  @override
  Future<RoomHandle> createRoom({required String name}) async {
    _guard();
    calls.add(FakeCall('createRoom', {'name': name}));
    return RoomHandle(roomId: roomId, code: _state.code, seat: 0);
  }

  @override
  Future<RoomHandle> joinRoom({
    required String code,
    required String name,
  }) async {
    _guard();
    calls.add(FakeCall('joinRoom', {'code': code, 'name': name}));
    final refusal = refusals['joinRoom'];
    if (refusal != null) {
      if (!stickyRefusals.contains('joinRoom')) refusals.remove('joinRoom');
      throw refusal;
    }
    return RoomHandle(roomId: roomId, code: code, seat: _own?.seat ?? 0);
  }

  @override
  Future<RoomRows> fetchRows(String room) async {
    _guard();
    fetches++;
    return RoomRows(
      state: _state,
      players: _players,
      own: _own,
      whispers: _whispers,
    );
  }

  @override
  Stream<RoomPush> pushes(String room) => _pushes.stream;

  @override
  Future<String?> whisperBody(String whisperId) async {
    _guard();
    return bodies[whisperId];
  }

  @override
  Future<void> blockSender(String room, String senderId) async {
    blocked = {...blocked, senderId};
  }

  @override
  Future<Set<String>> blockedSenders(String room) async => blocked;

  /// Every signal the client tried to send, in order. A test asserts on this
  /// to prove that nothing was signalled during the night (V6).
  final List<VoiceSignal> sentSignals = [];

  final _signals = StreamController<VoiceSignal>.broadcast();

  @override
  Future<void> sendSignal(
    String room,
    String toUserId,
    Map<String, dynamic> payload,
  ) async {
    sentSignals.add(VoiceSignal(fromUserId: userId ?? '', payload: payload));
  }

  @override
  Stream<VoiceSignal> signals(String room) => _signals.stream;

  /// Delivers one signal to the client under test, as the server would.
  void deliverSignal(VoiceSignal signal) => _signals.add(signal);

  @override
  Future<void> dispose() async {
    await _pushes.close();
    await _signals.close();
  }

  void _guard() {
    if (unreachable) {
      throw BackendUnreachable('fake', projectPaused: projectPaused);
    }
  }
}

class FakeCall {
  final String function;
  final Map<String, dynamic> body;

  const FakeCall(this.function, this.body);

  @override
  String toString() => '$function($body)';
}

/// A room in a known state, so tests read as "given a night, when …".
RoomState roomState({
  String phase = 'night',
  int phaseNumber = 1,
  DateTime? endsAt,
  Map<String, dynamic> publicData = const {},
  String status = 'playing',
  String hostId = 'u0',
  DateTime? serverNow,
  String? activeSpeaker,
}) =>
    RoomState(
      phase: phase,
      phaseNumber: phaseNumber,
      status: status,
      hostId: hostId,
      code: 'ABCDEF',
      serverNow: serverNow ?? DateTime.utc(2026, 9, 2, 12),
      phaseEndsAt: endsAt,
      publicData: publicData,
      activeSpeaker: activeSpeaker,
    );

List<RoomPlayer> roster(int count, {DateTime? lastSeen, Set<int> dead = const {}}) => [
      for (var seat = 0; seat < count; seat++)
        RoomPlayer(
          userId: 'u$seat',
          seat: seat,
          name: String.fromCharCode(65 + seat),
          alive: !dead.contains(seat),
          lastSeen: lastSeen ?? DateTime.utc(2026, 9, 2, 12),
        ),
    ];
