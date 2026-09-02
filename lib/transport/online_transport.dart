import 'dart:async';
import 'dart:math';

import '../engine/models/enums.dart';
import '../engine/models/timeline_event.dart' show InvestigateResult;
import '../engine/views.dart';
import 'game_snapshot.dart';
import 'game_transport.dart';
import 'online_backend.dart';
import 'room_codec.dart';
import 'voice_link.dart';

/// The online transport: the server is the authority (doc 10 §1.3).
///
/// ## What this class actually is
///
/// A set of rules about *distrust*, wrapped around a backend that has none.
/// The Edge Functions decide the game; this decides what a client does when the
/// answer is late, wrong, refused, or missing:
///
///   * a refusal of `PHASE_CLOSED` is not an error — the phase moved on while
///     the tap was in flight, so the client resyncs and shows where the room
///     actually is (O7, N16);
///   * a refusal of `NOT_HOST` is not an error either — every device runs the
///     same screens, and only one of them drives the phase;
///   * an unreachable server is not a lost match — the last snapshot stays on
///     screen, the banner goes up, and the client retries with backoff and
///     resyncs when it lands (O10);
///   * a reconnect reads the whole state rather than replaying deltas, which is
///     what makes a missed Realtime message a non-event (O12, doc 10 §8.4);
///   * the countdown is rendered against the server's deadline corrected for
///     this device's clock error, so a phone ten minutes out of true still
///     shows the right number (O8);
///   * when the host stops answering, the lowest-seat connected player claims
///     the room rather than the match ending (O1, O2).
///
/// ## What it is not
///
/// It is not a second engine. It never resolves a night, never tallies a
/// ballot, and never decides who died: `isAuthoritative` is false and means it.
/// Every command here is a *request*, and the state on screen is whatever the
/// server last said it was.
class OnlineTransport implements GameTransport {
  final OnlineBackend backend;
  final String roomId;

  /// How often this client says it is alive, and how often it checks whether
  /// the host still is. Zero disables the timer entirely, which is how tests
  /// drive [tick] by hand.
  final Duration heartbeatInterval;

  /// Injected so tests can hold a wrong clock deliberately (O8).
  final DateTime Function() now;

  /// How long a player may be silent before the room treats them as gone. Doc
  /// 10 §8.1 removes a lobby dropout after 30 seconds; the same threshold is
  /// what makes a host "not answering" for the purposes of migration.
  static const Duration presenceTimeout = Duration(seconds: 30);

  final StreamController<GameSnapshot> _controller =
      StreamController<GameSnapshot>.broadcast();
  final Random _ids = Random();

  StreamSubscription<RoomPush>? _pushes;
  Timer? _ticker;
  Timer? _retry;

  RoomState? _state;
  List<RoomPlayer> _players = const [];
  VoiceLink? _voice;
  OwnSeat? _own;
  List<WhisperRow> _whispers = const [];
  Set<String> _blocked = const {};

  /// The connection map as it stood when the night began, or null outside one.
  ///
  /// Doc 10 §6.3: *"Freeze all per-player status indicators for the whole night
  /// phase."* Captured on the way in and dropped on the way out, so the freeze
  /// cannot outlive the phase that needs it.
  Map<int, bool>? _frozenConnected;

  /// serverNow − localNow at the last read. Added to nothing but a deadline.
  Duration _skew = Duration.zero;
  ConnectionQuality _connection = ConnectionQuality.connected;
  Duration _backoff = const Duration(seconds: 1);

  /// Whispers this client has already been shown. Online delivery is instant,
  /// so "delivered" is a fact about this screen, not about the server.
  final Set<String> _read = <String>{};

  GameSnapshot _snapshot;

  OnlineTransport({
    required this.backend,
    required this.roomId,
    required List<RoomPlayer> players,
    required RoomState state,
    OwnSeat? own,
    List<WhisperRow> whispers = const [],
    this.heartbeatInterval = const Duration(seconds: 15),
    this.now = DateTime.now,
  })  : _snapshot = const GameSnapshot(
          public: PublicMatchView(
            phase: GamePhase.setup,
            dayNumber: 0,
            players: [],
          ),
        ) {
    _state = state;
    _players = players;
    _own = own;
    _whispers = whispers;
    _skew = state.serverNow.difference(now().toUtc());
    _publish();
  }

  /// Joins a room and brings back a transport already holding its first
  /// snapshot.
  ///
  /// The first read is a full one on purpose: a client that starts from a
  /// delta has no state to apply it to, and the same call is the recovery path
  /// later (doc 10 §8.4). Do it once, here, and reconnect is not a special
  /// case — it is this again.
  static Future<OnlineTransport> connect({
    required OnlineBackend backend,
    required String roomId,
    Duration heartbeatInterval = const Duration(seconds: 15),
    DateTime Function() now = DateTime.now,
  }) async {
    await backend.ensureSession();
    final rows = await backend.fetchRows(roomId);
    final transport = OnlineTransport(
      backend: backend,
      roomId: roomId,
      state: rows.state,
      players: rows.players,
      own: rows.own,
      whispers: rows.whispers,
      heartbeatInterval: heartbeatInterval,
      now: now,
    );
    await transport._listen();
    return transport;
  }

  Future<void> _listen() async {
    _blocked = await backend.blockedSenders(roomId);
    _pushes = backend.pushes(roomId).listen(_onPush, onError: (_) {
      _degrade();
    });
    if (heartbeatInterval > Duration.zero) {
      _ticker = Timer.periodic(heartbeatInterval, (_) => tick());
    }
  }

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  @override
  bool get isAuthoritative => false;

  /// The call, built on the first ask and never awaited by anything in the
  /// phase flow. Nothing in this transport reads it back: it exists so that
  /// the voice controls have somewhere to send a floor request, and it can be
  /// broken for the whole match without a single command above noticing.
  @override
  VoiceLink? get voice =>
      _voice ??= BackendVoiceLink(
        backend: backend,
        roomId: roomId,
        roster: () => [
          for (final p in _players) VoicePeer(userId: p.userId, seat: p.seat),
        ],
      );

  @override
  GameSnapshot get snapshot => _snapshot;

  @override
  Stream<GameSnapshot> watch() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  /// This client's own seat, or null before the roster has been read.
  int? get mySeat => _own?.seat;

  /// Whether this client is the room's host. Read from the state, so a
  /// migration changes it on every device at once.
  bool get isHost =>
      _state != null && backend.userId != null && _state!.hostId == backend.userId;

  /// The room code, for the share sheet in the lobby.
  String get code => _state?.code ?? '';

  ConnectionQuality get connection => _connection;

  void _publish() {
    final state = _state;
    if (state == null) return;

    final dark = state.phase == 'night' || state.phase == 'reveal';
    if (dark) {
      _frozenConnected ??= {for (final p in _players) p.seat: p.connected};
    } else {
      _frozenConnected = null;
    }
    _snapshot = snapshotFrom(
      state: state,
      players: _players,
      viewerSeat: _own?.seat,
      isHost: isHost,
      connection: _connection,
      skew: _skew,
      whispers: _whispers,
      ownTurnPending: _ownTurnPending(state),
      frozenConnected: _frozenConnected,
    );
    if (!_controller.isClosed) _controller.add(_snapshot);
  }

  /// Whether this device still owes the current phase a move.
  ///
  /// This is the online form of "whose turn is it": there is no phone to pass,
  /// so the answer is only ever *yours* or *nobody's*, and a client that has
  /// already acted is waiting for the room rather than holding it up.
  bool _ownTurnPending(RoomState state) {
    final own = _own;
    if (own == null || !own.alive) return false;
    return switch (state.phase) {
      'reveal' => true,
      'night' => !own.actedThisNight,
      'vote' => own.votedRound != _round(state),
      'opening' => _openingSeat(state) == own.seat,
      _ => false,
    };
  }

  int _round(RoomState state) =>
      ((state.publicData['revote'] as Map?)?['round'] as num?)?.toInt() ?? 1;

  /// The seat the «اسم واحد» round is currently pointing at, as the server
  /// records it. Null once every living player has been named.
  int? _openingSeat(RoomState state) =>
      (state.publicData['openingSeat'] as num?)?.toInt();

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  Future<void> _onPush(RoomPush push) async {
    if (push.disconnected) {
      _degrade();
      return;
    }
    if (push.resyncRequired) {
      await resync();
      return;
    }
    if (push.player != null) {
      // A roster delta is applied in place: heartbeats move `last_seen` every
      // few seconds and a full read for each would cost more than the whole
      // rest of the match (doc 10 §3.1).
      final incoming = push.player!;
      final next = [..._players];
      final at = next.indexWhere((p) => p.userId == incoming.userId);
      if (at == -1) {
        next.add(incoming);
      } else {
        next[at] = incoming;
      }
      _players = next..sort((a, b) => a.seat.compareTo(b.seat));
      if (incoming.userId == backend.userId && _own != null) {
        _own = OwnSeat(
          seat: _own!.seat,
          role: _own!.role,
          alive: incoming.alive,
          teammateNames: _own!.teammateNames,
          actedThisNight: _own!.actedThisNight,
          votedRound: _own!.votedRound,
        );
      }
      _restore();
      _publish();
      return;
    }
    final state = push.state;
    if (state == null) return;

    final previous = _state;
    _state = state;
    _skew = state.serverNow.difference(now().toUtc());
    _restore();

    // A phase change is the one push worth a full read: it is when the whisper
    // graph moves, when this client's night obligation resets, and when the
    // public payload it depends on was rewritten. Once per phase is exactly the
    // budget doc 10 §3.1 sets.
    if (previous == null ||
        previous.phase != state.phase ||
        previous.phaseNumber != state.phaseNumber) {
      await resync();
    } else {
      _publish();
    }
  }

  /// Reads everything again and republishes. The recovery path (doc 10 §8.4).
  @override
  Future<void> resync() async {
    try {
      final rows = await backend.fetchRows(roomId);
      _state = rows.state;
      _players = rows.players;
      _own = rows.own;
      _whispers = rows.whispers;
      _skew = rows.state.serverNow.difference(now().toUtc());
      _restore();
      _publish();
    } on BackendUnreachable {
      _degrade();
    }
  }

  /// Back to connected, and the backoff forgotten.
  void _restore() {
    _backoff = const Duration(seconds: 1);
    _retry?.cancel();
    _retry = null;
    if (_connection != ConnectionQuality.connected) {
      _connection = ConnectionQuality.connected;
    }
  }

  /// The link is gone. Play continues against the last snapshot, the banner
  /// goes up, and a retry is scheduled (O10).
  void _degrade() {
    if (_connection == ConnectionQuality.connected) {
      _connection = ConnectionQuality.reconnecting;
      _publish();
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_retry != null || heartbeatInterval == Duration.zero) return;
    _retry = Timer(_backoff, () async {
      _retry = null;
      _backoff = _backoff * 2;
      if (_backoff > const Duration(seconds: 30)) {
        _backoff = const Duration(seconds: 30);
        _connection = ConnectionQuality.offline;
        _publish();
      }
      await resync();
    });
  }

  /// One beat of the clock: say we are here, check the host is, and apply the
  /// phase's expiry default if the deadline has passed.
  ///
  /// Public so a test can run a match without waiting fifteen real seconds,
  /// and so the app can beat it once on resume from the background (O20).
  Future<void> tick() async {
    try {
      await backend.call('heartbeat', {'roomId': roomId});
      _restore();
    } on BackendUnreachable {
      _degrade();
      return;
    } on BackendException {
      // A refusal to a heartbeat is not worth acting on: it means this client
      // is no longer a member, and the screen it is on will find out from the
      // next read.
      return;
    }
    await _claimHostIfAbandoned();
    await _applyExpiryIfDue();
  }

  /// O1, O2 — the match never ends because the host left.
  ///
  /// Every client can see who the host is and when each player was last heard
  /// from, so every client can work out the same answer: the lowest-seat
  /// connected player takes over. Only that player asks, and the server checks
  /// the claim before granting it, so two clients racing produce one host.
  Future<void> _claimHostIfAbandoned() async {
    final state = _state;
    final me = backend.userId;
    if (state == null || me == null || state.hostId == me) return;
    if (state.status == 'finished') return;

    final cutoff = now().toUtc().subtract(presenceTimeout);
    bool live(RoomPlayer p) =>
        p.connected && (p.lastSeen == null || p.lastSeen!.isAfter(cutoff));

    final host = _players.where((p) => p.userId == state.hostId).firstOrNull;
    if (host != null && live(host)) return;

    final heir = _players.where(live).fold<RoomPlayer?>(
      null,
      (lowest, p) => lowest == null || p.seat < lowest.seat ? p : lowest,
    );
    if (heir?.userId != me) return;

    try {
      await backend.call('claim_host', {'roomId': roomId});
    } on BackendException {
      // Somebody else got there first, or the host answered after all. Either
      // way the room has a host, which is the only thing this cared about.
    } on BackendUnreachable {
      _degrade();
    }
  }

  /// Doc 10 §8.2 — no phase may stall.
  ///
  /// The deadline is the server's and the server re-checks it, so a client with
  /// a fast clock cannot end a phase early: it can only ask, and be refused.
  Future<void> _applyExpiryIfDue() async {
    final state = _state;
    if (state == null || !isHost) return;
    final deadline = state.phaseEndsAt;
    if (deadline == null) return;
    if (deadline.subtract(_skew).isAfter(now().toUtc())) return;
    await advancePhase();
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// One request, with everything the client is allowed to get wrong handled.
  ///
  /// Returns null when the call did not happen or was absorbed — a caller that
  /// needs the answer checks for it, and a caller that does not simply carries
  /// on, because the state it will render is coming from [watch] either way.
  Future<Map<String, dynamic>?> _send(
    String function,
    Map<String, dynamic> body, {
    bool hostOnly = false,
  }) async {
    if (hostOnly && !isHost) return null;
    try {
      final result = await backend.call(function, {
        'roomId': roomId,
        // O19 — a retried request on a flaky network must be a no-op, not a
        // second vote. The key is per call, not per phase, so a genuine change
        // of mind is a different action and still lands.
        'actionId': _actionId(),
        ...body,
      });
      _restore();
      return result;
    } on BackendException catch (e) {
      if (e.isPhaseClosed) {
        await resync();
        return null;
      }
      if (e.isNotHost) return null;
      rethrow;
    } on BackendUnreachable {
      _degrade();
      return null;
    }
  }

  String _actionId() {
    final stamp = now().microsecondsSinceEpoch.toRadixString(16);
    final salt = _ids.nextInt(1 << 32).toRadixString(16);
    return '$stamp-$salt';
  }

  @override
  Future<void> beginNight() async {
    await _send('open_phase', {'phase': 'night'}, hostOnly: true);
  }

  @override
  Future<void> confirmRevealed() async {
    // Nothing to hand on: this client is looking at its own card, and the room
    // moves when the host says it does. The card is dismissed locally and the
    // server is not troubled with the fact that somebody stopped looking at
    // something only they could see.
  }

  @override
  Future<void> beginDiscussion() async {
    await _send('open_phase', {'phase': 'discuss'}, hostOnly: true);
  }

  @override
  Future<void> removePlayer(int seat) async {
    await _send('remove_player', {'seat': seat}, hostOnly: true);
  }

  @override
  Future<InvestigateResult?> submitNightAction({
    required int seat,
    required NightActionKind kind,
    required int? targetSeat,
  }) async {
    // The seat is not sent. The server takes the actor from the JWT, and a
    // client that could name one would be O17 with a different noun.
    if (seat != mySeat) return null;
    final result = await _send('submit_night_action', {
      'action': targetSeat == null ? 'skip' : nightActionToServer(kind),
      'targetSeat': targetSeat,
    });
    if (result == null) return null;
    final own = _own;
    if (own != null) {
      _own = OwnSeat(
        seat: own.seat,
        role: own.role,
        alive: own.alive,
        teammateNames: own.teammateNames,
        actedThisNight: true,
        votedRound: own.votedRound,
      );
      _publish();
    }

    // The Detective's answer, on the only path it ever takes: back to the
    // client that asked, in the response to its own request. It is not in the
    // snapshot, not in the payload, and not in a table any client can read —
    // doc 05 rule 10, kept by there being nowhere else for it to be.
    final revealed = roleFromServer(result['revealedRole'] as String?);
    if (revealed == null || targetSeat == null) return null;
    return InvestigateResult(targetSeat: targetSeat, revealedRole: revealed);
  }

  @override
  Future<void> resolveNight() async {
    await _send('resolve_night', const {}, hostOnly: true);
  }

  @override
  Future<void> beginDay() async {
    final state = _state;
    if (state == null || !isHost) return;
    // Day 1 opens on «اسم واحد»; every later day opens on the confrontation the
    // server chooses, or on discussion when it finds nothing true to say.
    if (state.phaseNumber <= 1) {
      await _send('open_phase', {'phase': 'opening'}, hostOnly: true);
    } else {
      await _send('generate_confrontation', const {}, hostOnly: true);
    }
  }

  @override
  Future<void> submitOpeningAccusation({
    required int seat,
    required int targetSeat,
  }) async {
    if (seat != mySeat) return;
    await _send('submit_accusation', {'targetSeat': targetSeat});
  }

  @override
  Future<void> endConfrontation({required bool silent}) async {
    await _send('open_phase', {'phase': 'discuss', 'silent': silent},
        hostOnly: true);
  }

  @override
  Future<void> recordSpeaking({required int seat, required int seconds}) async {
    if (seat != mySeat) return;
    await _send('record_speaking', {'seconds': seconds});
  }

  @override
  Future<String> sendWhisper({
    required int fromSeat,
    required int toSeat,
    required String body,
  }) async {
    final result = await _send('send_whisper', {
      'toSeat': toSeat,
      'body': body,
    });
    // A whisper that could not be sent has no id, and the compose screen is
    // entitled to know that rather than to be told a lie it can quote.
    final id = result?['id'] as String?;
    if (id == null) {
      throw const BackendException('BAD_REQUEST', 'the whisper was not sent');
    }
    await resync();
    return id;
  }

  @override
  Future<void> markWhisperDelivered(String id) async {
    // Online a whisper is delivered the moment it is fetched, and the server
    // has nothing to record: the graph is already public and the body already
    // reached exactly one client. What "read" means here is "this screen has
    // shown it", which is this device's business alone.
    _read.add(id);
    _publish();
  }

  @override
  Future<void> beginVoting() async {
    await _send('open_phase', {'phase': 'vote'}, hostOnly: true);
  }

  @override
  Future<void> submitVote({required int seat, required int? targetSeat}) async {
    if (seat != mySeat) return;
    final state = _state;
    final result = await _send('submit_vote', {
      'targetSeat': targetSeat,
      'round': state == null ? 1 : _round(state),
    });
    if (result == null) return;
    final own = _own;
    if (own != null && state != null) {
      _own = OwnSeat(
        seat: own.seat,
        role: own.role,
        alive: own.alive,
        teammateNames: own.teammateNames,
        actedThisNight: own.actedThisNight,
        votedRound: _round(state),
      );
      _publish();
    }
  }

  @override
  Future<void> resolveDayVote() async {
    await _send('resolve_vote', const {}, hostOnly: true);
  }

  @override
  Future<void> winCheck() async {
    // `resolve_vote` already applied the death and already ran the check — the
    // room is either on the next night or on the result screen, and there is
    // nothing left for a client to decide. Offline this is a real command
    // because offline the device is the authority; online it is the same
    // guarantee, kept somewhere else.
  }

  @override
  Future<void> concludeAfterNight() async {
    await _send('open_phase', {'phase': 'result'}, hostOnly: true);
  }

  @override
  Future<void> advancePhase() async {
    final state = _state;
    if (state == null || !isHost) return;
    await _send('advance_phase', const {}, hostOnly: true);
    // The defaults fill in the moves nobody made; somebody still has to tally
    // them, and online that somebody is the host's client asking the server to.
    if (state.phase == 'night') {
      await resolveNight();
    } else if (state.phase == 'vote') {
      await resolveDayVote();
    }
  }

  // ---------------------------------------------------------------------------
  // Secrets
  // ---------------------------------------------------------------------------

  /// What this client may see about [seat] — which is nothing at all unless
  /// [seat] is its own.
  ///
  /// The check is not a filter over data that arrived: another player's role
  /// never reaches this device in the first place (RLS, doc 10 §4.1). It is
  /// here because the interface is shared with the offline transport, where the
  /// question genuinely is "whose turn is it", and answering `null` for every
  /// other seat is how the same screens mean the same thing in both modes.
  @override
  Future<ViewerSecrets?> secretsFor(int seat) async {
    final own = _own;
    final state = _state;
    if (own == null || state == null || seat != own.seat) return null;

    final role = roleFromServer(own.role);
    if (state.phase == 'reveal') {
      if (role == null) return null;
      return ViewerSecrets(
        seat: seat,
        role: role,
        teammateNames: own.teammateNames,
      );
    }

    if (state.phase != 'night' || role == null || !own.alive) return null;

    final waiting = _waitingWhisper();
    String? body;
    if (waiting != null) {
      body = await backend.whisperBody(waiting.id);
    }

    return ViewerSecrets(
      seat: seat,
      role: role,
      turn: own.actedThisNight
          ? null
          : turnFor(seat: seat, role: role, players: _players),
      whisperId: waiting?.id,
      whisperBody: body,
      whisperUndelivered: body == null && _voidedFromMe(),
    );
  }

  /// The whisper waiting for this client, if any.
  ///
  /// A blocked sender's whisper is simply not fetched (H-E9): the row exists,
  /// the graph shows the edge, and the sender is told nothing — which is the
  /// whole point of a block that cannot be used to probe.
  WhisperRow? _waitingWhisper() {
    final own = _own;
    if (own == null) return null;
    final sendersBlocked = _blocked;
    for (final w in _whispers) {
      if (!w.toMe || w.voided || _read.contains(w.id)) continue;
      final from = _players.where((p) => p.seat == w.fromSeat).firstOrNull;
      if (from != null && sendersBlocked.contains(from.userId)) continue;
      return w;
    }
    return null;
  }

  bool _voidedFromMe() {
    final own = _own;
    if (own == null) return false;
    return _whispers.any((w) => w.fromSeat == own.seat && w.voided);
  }

  /// Blocks a sender for this client only (doc 09 §3.7).
  Future<void> block(String senderId) async {
    await backend.blockSender(roomId, senderId);
    _blocked = await backend.blockedSenders(roomId);
    _publish();
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    _retry?.cancel();
    await _pushes?.cancel();
    await backend.dispose();
    await _controller.close();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
