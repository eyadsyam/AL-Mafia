import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show mapEquals;

import '../engine/models/enums.dart';
import '../engine/models/timeline_event.dart' show InvestigateResult;
import '../engine/views.dart';
import 'game_snapshot.dart';
import 'game_transport.dart';
import 'online_backend.dart';
import 'room_codec.dart';
import 'metered_voice_link.dart';
import 'voice_link.dart';
import 'witness_channel.dart';
import '../ui/theme/design_tokens.dart';

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

  /// How often this client says it is alive and checks the host. Zero disables
  /// the timer entirely, which is how tests drive [tick] by hand.
  final Duration heartbeatInterval;

  /// Injected so tests can hold a wrong clock deliberately (O8).
  final DateTime Function() now;

  final StreamController<GameSnapshot> _controller =
      StreamController<GameSnapshot>.broadcast();
  final Random _ids = Random();

  StreamSubscription<RoomPush>? _pushes;
  Timer? _ticker;
  Timer? _retry;

  /// Fires once, at the moment this client becomes entitled to drive the room
  /// forward. The heartbeat would find the same expiry eventually, but "within
  /// ten seconds" is not the same phase change as "on the second", and the
  /// difference is the whole of whether a match feels timed or merely slow.
  Timer? _deadlineAlarm;

  /// The room moves on by itself (owner decision 2026-09-23): no «كمل» for
  /// the host. The beats that are *read* — the deal once every card is seen,
  /// the morning, the verdict — end after a reading pause rather than at their
  /// long server deadline. The host's device keeps that time silently; every
  /// other device still takes over at the deadline if the host is gone.
  Timer? _earlyAlarm;
  String? _earlyKey;
  DateTime? _phaseSeenAt;

  /// Whether a drive is already in flight, so a push and an alarm landing
  /// together do not both advance the room.
  bool _driving = false;

  RoomState? _state;
  List<RoomPlayer> _players = const [];
  VoiceLink? _voice;
  WitnessChannel? _witness;
  OwnSeat? _own;
  List<WhisperRow> _whispers = const [];
  Set<String> _blocked = const {};

  /// The open ballot, voter seat to target seat (doc 12 §3.6).
  ///
  /// Empty in every room that did not opt in, and empty outside the vote
  /// phase — but not because this file checks. The `votes_read` policy refuses
  /// the rows, so an open ballot is a thing the *database* is doing and this is
  /// only where the answer is kept.
  Map<int, int?> _ballots = const {};
  (int, int)? _ballotEpoch;
  int _ballotRequest = 0;
  int _ballotApplied = 0;

  /// Polls the ballot while it is open, and only then.
  ///
  /// The one thing on the snapshot that moves within a phase, so the one thing
  /// the phase-change resync cannot deliver. Doc 12 §3.6 is asking to watch a
  /// player change their mind, and a fifteen-second heartbeat would show that
  /// as a line that had already moved.
  ///
  /// Bounded by construction: it starts when the vote opens, stops when it
  /// closes, and never runs at all unless the host chose an open ballot — so a
  /// default room pays nothing for it. The honest cost in a room that did opt
  /// in is one narrow read every [_ballotInterval] for the length of a ballot.
  Timer? _ballotPoll;

  /// Full reads are triggered by more than one Realtime table. They must not
  /// race: a lobby read that started before `start_match` can otherwise finish
  /// after the reveal read and put the guest's private role back to null.
  Future<void>? _resyncInFlight;
  bool _resyncAgain = false;

  /// A same-phase row landed while a full read was on the wire. That read was
  /// taken before the row, so publishing it would put the old speaker or
  /// opening seat back; it is dropped and read again instead, at most
  /// [_maxSupersededReads] times in a row so a busy room still converges.
  bool _deltaDuringRead = false;
  static const int _maxSupersededReads = 2;

  static const Duration _ballotInterval = Duration(seconds: 2);

  /// The connection map as it stood when the night began, or null outside one.
  ///
  /// Doc 10 §6.3: *"Freeze all per-player status indicators for the whole night
  /// phase."* Captured on the way in and dropped on the way out, so the freeze
  /// cannot outlive the phase that needs it.
  Map<int, bool>? _frozenConnected;
  Map<int, SeatPresence>? _frozenPresence;

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
    this.heartbeatInterval = MafiaTiming.onlineHeartbeat,
    this.now = DateTime.now,
  }) : _snapshot = const GameSnapshot(
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
    Duration heartbeatInterval = MafiaTiming.onlineHeartbeat,
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
    _pushes = backend
        .pushes(roomId)
        .listen(
          _onPush,
          onError: (_) {
            _degrade();
          },
        );
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
  VoiceLink? get voice => _voice ??= MeteredVoiceLink(
    backend: backend,
    roomId: roomId,
    roster: () => [
      for (final p in _players)
        if (p.status != 'left' && !p.kicked)
          VoicePeer(userId: p.userId, seat: p.seat),
    ],
  );

  /// The graveyard, built on the first ask.
  ///
  /// Like [voice], nothing in the phase flow reads this back. It exists so the
  /// witness surface has somewhere to send a message, and it can be broken for
  /// the whole match without one rule noticing.
  @override
  WitnessChannel? get witness => _witness ??= BackendWitnessChannel(
    backend: backend,
    roomId: roomId,
    blocked: () => _blocked,
    roster: () => {
      for (final p in _players) p.userId: (seat: p.seat, name: p.name),
    },
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
      _state != null &&
      backend.userId != null &&
      _state!.hostId == backend.userId;

  /// The room code, for the share sheet in the lobby.
  String get code => _state?.code ?? '';

  /// The next table the host opened from this finished room (`rematch_room`),
  /// announced in the room's public data. Null until the host opens one.
  ({String roomId, String code})? get rematch {
    final next = _state?.publicData['rematch'];
    if (next is Map && next['roomId'] is String && next['code'] is String) {
      return (roomId: next['roomId'] as String, code: next['code'] as String);
    }
    return null;
  }

  ConnectionQuality get connection => _connection;

  void _publish() {
    final state = _state;
    if (state == null) return;

    final dark = state.phase == 'night' || state.phase == 'reveal';
    if (dark) {
      _frozenConnected ??= {for (final p in _players) p.seat: p.connected};
      _frozenPresence ??= {
        for (final p in _players) p.seat: SeatPresence.fromServer(p.status),
      };
    } else {
      _frozenConnected = null;
      _frozenPresence = null;
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
      viewerVoteRecorded:
          state.phase == 'vote' && _own?.votedRound == _round(state),
      frozenConnected: _frozenConnected,
      frozenPresence: _frozenPresence,
      liveBallots: _ballots,
    );
    if (!_controller.isClosed) _controller.add(_snapshot);
    _syncBallotPolling();
    _armDeadlineAlarm();
  }

  /// Re-arms the one-shot alarm for the current phase's deadline.
  ///
  /// Driven off the published snapshot for the same reason the ballot poll is:
  /// every route into a new phase — a delta, a resync, a reconnection — leaves
  /// the timer right without three call sites having to agree.
  void _armDeadlineAlarm() {
    _armEarlyAlarm();
    _deadlineAlarm?.cancel();
    _deadlineAlarm = null;
    // Zero disables the periodic timer in tests, and it disables this with it:
    // a test that wanted a beat calls `tick()`, and one that did not must not
    // find the room advancing under it.
    if (heartbeatInterval == Duration.zero) return;
    final due = _driveDueAt();
    if (due == null) return;
    final wait = due.difference(now().toUtc());
    _deadlineAlarm = Timer(
      wait.isNegative ? Duration.zero : wait,
      () => unawaited(_applyExpiryIfDue()),
    );
  }

  void _armEarlyAlarm() {
    final state = _state;
    final key = state == null ? null : '${state.phase}-${state.phaseNumber}';
    if (key != _earlyKey) {
      _earlyKey = key;
      _phaseSeenAt = now().toUtc();
    }
    _earlyAlarm?.cancel();
    _earlyAlarm = null;
    if (heartbeatInterval == Duration.zero || state == null || !isHost) return;
    final seen = _phaseSeenAt!;
    final due = switch (state.phase) {
      'reveal' when _snapshot.unseenRoleSeats.isEmpty => seen.add(
        MafiaTiming.autoRevealSettle,
      ),
      'morning' => seen.add(MafiaTiming.autoMorningRead),
      'verdict' => seen.add(MafiaTiming.autoVerdictRead),
      _ => null,
    };
    if (due == null) return;
    final wait = due.difference(now().toUtc());
    _earlyAlarm = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (_driving || _earlyKey != key) return;
      _driving = true;
      unawaited(
        advancePhase().catchError((_) {}).whenComplete(() => _driving = false),
      );
    });
  }

  /// When this client may start driving the room, or null when the phase has
  /// no clock.
  ///
  /// The host's answer is the deadline itself. A guest's is a little later, and
  /// later again for each seat: the point is not to race the host, only to be
  /// there if the host is not. See [MafiaTiming.onlineDriveGrace].
  DateTime? _driveDueAt() {
    final deadline = _state?.phaseEndsAt;
    if (deadline == null) return null;
    final corrected = deadline.subtract(_skew);
    if (isHost) return corrected;
    return corrected
        .add(MafiaTiming.onlineDriveGrace)
        .add(MafiaTiming.onlineDriveStep * (mySeat ?? 0));
  }

  /// Whether this client may move the room on right now.
  ///
  /// Doc 10 §8.2 says no phase may stall. That is not a promise the room can
  /// keep while only the host may end a phase — a host whose screen has locked
  /// looks, from every other seat, exactly like a match that has broken. So the
  /// deadline opens the transition to everybody, staggered. The server re-reads
  /// the same `phase_ends_at` before agreeing, so this is a client asking, never
  /// a client deciding.
  bool get _mayDrive {
    final due = _driveDueAt();
    return due != null && !due.isAfter(now().toUtc());
  }

  /// Starts or stops the ballot poll to match the phase.
  ///
  /// Driven off the published snapshot rather than off the push handler so
  /// that every route into a new phase — a delta, a resync, a reconnection —
  /// leaves the timer in the right state without three call sites agreeing.
  void _syncBallotPolling() {
    final state = _state;
    final epoch =
        state != null &&
            _snapshot.phase == GamePhase.voting &&
            _snapshot.settings.openVoting
        ? (state.phaseNumber, _round(state))
        : null;
    if (_ballotEpoch != epoch) {
      _ballotEpoch = epoch;
      _ballotRequest++;
      _ballotApplied = _ballotRequest;
      _ballotPoll?.cancel();
      _ballotPoll = null;
      // A revote can begin without changing the day or phase name.
      _ballots = const {};
      _publishWithoutPolling();
    }
    if (epoch != null && _ballotPoll == null) {
      _ballotPoll = Timer.periodic(_ballotInterval, (_) => _refreshBallots());
      unawaited(_refreshBallots());
    }
  }

  /// Republish without re-entering [_syncBallotPolling].
  void _publishWithoutPolling() {
    final state = _state;
    if (state == null) return;
    _snapshot = _snapshot.copyWith(liveBallots: _ballots);
    if (!_controller.isClosed) _controller.add(_snapshot);
  }

  /// One narrow read of the open ballot.
  ///
  /// Failures are swallowed. A ballot line that did not arrive is a line that
  /// is not drawn yet; it is never a reason to degrade a live match, and the
  /// next tick two seconds later will have it.
  Future<void> _refreshBallots() async {
    final epoch = _ballotEpoch;
    if (epoch == null) return;
    final request = ++_ballotRequest;
    try {
      final ballots = await backend.ballots(roomId);
      if (_controller.isClosed ||
          _ballotEpoch != epoch ||
          request <= _ballotApplied) {
        return;
      }
      // A pending newer poll must not starve valid replies on slow networks.
      // Only a newer reply already applied can supersede this one.
      _ballotApplied = request;
      if (mapEquals(_ballots, ballots)) return;
      _ballots = ballots;
      _publishWithoutPolling();
    } catch (_) {
      // Deliberately silent. See above.
    }
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
      'reveal' =>
        _players
            .where((player) => player.userId == backend.userId)
            .any((player) => !player.sawRole),
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
      // A roster delta is applied in place: a full read for each would cost
      // more than the whole rest of the match (doc 10 §3.1). Since M3 the
      // deltas are transitions only — beats never reach the stream.
      final incoming = push.player!;
      final next = [..._players];
      final at = next.indexWhere((p) => p.userId == incoming.userId);
      if (at == -1) {
        next.add(incoming);
      } else {
        final previousSeen = next[at].lastSeen;
        final incomingSeen = incoming.lastSeen;
        if (previousSeen != null &&
            incomingSeen != null &&
            incomingSeen.isBefore(previousSeen))
          return;
        next[at] = incoming;
      }
      _players = next..sort((a, b) => a.seat.compareTo(b.seat));
      if (incoming.userId == backend.userId && _own != null) {
        _own = _own!.copyWith(alive: incoming.alive);
      }
      _restore();
      _publish();
      return;
    }
    final pushed = push.state;
    if (pushed == null) return;

    final previous = _state;
    if (push.partial && previous == null) {
      await resync();
      return;
    }
    final state = push.partial ? pushed.withRoomFieldsFrom(previous!) : pushed;
    _state = state;
    // A realtime row carries no server clock — its `serverNow` is stamped on
    // this device when it arrives — so only a full read may correct the skew.
    if (!push.partial) _skew = state.serverNow.difference(now().toUtc());
    _restore();

    // A phase change is the one push worth a full read: it is when the whisper
    // graph moves, when this client's night obligation resets, and when the
    // public payload it depends on was rewritten. Once per phase is exactly the
    // budget doc 10 §3.1 sets.
    if (previous == null ||
        previous.phase != state.phase ||
        previous.phaseNumber != state.phaseNumber) {
      await resync();
    } else if (_resyncInFlight != null) {
      // The read on the wire predates this row; it will be read again and
      // published once, rather than published now and then overwritten.
      _deltaDuringRead = true;
      _resyncAgain = true;
    } else {
      _publish();
    }
  }

  /// Reads everything again and republishes. The recovery path (doc 10 §8.4).
  @override
  Future<void> resync() async {
    final inFlight = _resyncInFlight;
    if (inFlight != null) {
      _resyncAgain = true;
      await inFlight;
      return;
    }

    final operation = _drainResyncs();
    _resyncInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_resyncInFlight, operation)) {
        _resyncInFlight = null;
      }
    }
  }

  Future<void> _drainResyncs() async {
    var superseded = 0;
    do {
      _resyncAgain = false;
      _deltaDuringRead = false;
      final applied = await _performResync(
        discardIfSuperseded: superseded < _maxSupersededReads,
      );
      superseded = applied ? 0 : superseded + 1;
    } while (_resyncAgain);
  }

  /// False when the read was dropped because a newer row arrived meanwhile.
  Future<bool> _performResync({bool discardIfSuperseded = false}) async {
    try {
      final rows = await backend.fetchRows(roomId);
      if (discardIfSuperseded && _deltaDuringRead) {
        _resyncAgain = true;
        return false;
      }
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
    return true;
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
  bool _foreground = true;

  Future<void> tick() async {
    if (!_foreground) return;
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

  /// Removes a player and bars them from the code. Host only; the server
  /// checks, and the ban is what makes it a removal rather than a nudge.
  Future<void> kickPlayer(int seat) async {
    await _send('kick_player', {'seat': seat}, hostOnly: true);
    await resync();
  }

  /// Silences one player for the whole room, or lets them speak again. Host
  /// only; the server checks. The value is passed rather than toggled so two
  /// taps on a slow network cannot leave the room disagreeing.
  Future<void> setPlayerMuted(int seat, bool muted) async {
    await _send('mute_player', {'seat': seat, 'muted': muted}, hostOnly: true);
    await resync();
  }

  /// Changes the room's settings, live, for everybody in the lobby (task 10).
  ///
  /// Host only, and the server both checks that and decides what a settings
  /// object may contain — the allow-list in `room_settings` is the schema, not
  /// this call site. Every other client learns about it from the `rooms`
  /// delta, which asks them to re-read rather than telling them what changed.
  Future<void> setRoomSettings({
    String? visibility,
    String? title,
    Map<String, dynamic>? settings,
  }) async {
    await _send('room_settings', {
      if (visibility != null) 'visibility': visibility,
      if (title != null) 'title': title,
      if (settings != null) 'settings': settings,
    }, hostOnly: true);
    await resync();
  }

  /// Ends the match for everybody. Host only; the server checks.
  ///
  /// Deliberately not what leaving does. A host whose battery died must not
  /// take four other people's game with them, so the only way to reach this is
  /// a host tapping words that say so, behind a confirmation.
  Future<void> closeRoom() async {
    await _send('close_room', const {}, hostOnly: true);
    await resync();
  }

  /// Says what just happened to this device: connected | away | left.
  ///
  /// The ageing job on the server is what makes presence true for a client
  /// that crashed. This is for the one that did not: backgrounding the app
  /// empties this player's ring on every other table *now*, rather than in the
  /// few seconds it would take the ageing clock to notice.
  ///
  /// Never throws and is never awaited by anything in the phase flow.
  Future<void> setPresence(String status) async {
    _foreground = status == 'connected';
    try {
      await backend.call('set_presence', {'roomId': roomId, 'status': status});
      _restore();
    } on BackendException {
      // Not a member any more, or the room is gone. The screen finds out from
      // the next read; a presence update is not the place to say so.
    } on BackendUnreachable {
      _degrade();
    }
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

    // M3 — beats no longer reach the roster, so `lastSeen` is the time of the
    // last transition, not the last beat. Freshness is the server's status,
    // which it ages every five seconds from the beats it alone sees:
    // `connected` means heard in the last 25 s. A host gone quiet reads `away`
    // and this device asks; the server grants the room only once the host has
    // been silent for its full 30 s, and until then the ask is simply refused
    // and repeated on the next tick.
    bool holdsRoom(RoomPlayer p) => p.status == 'connected' && p.connected;
    bool eligible(RoomPlayer p) => p.status == 'connected' && p.connected;

    final host = _players.where((p) => p.userId == state.hostId).firstOrNull;
    if (host != null && holdsRoom(host)) return;

    final heir = _players
        .where(eligible)
        .fold<RoomPlayer?>(
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
    if (_state == null || _driving || !_mayDrive) return;
    _driving = true;
    try {
      await advancePhase();
    } finally {
      _driving = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// One request, with everything the client is allowed to get wrong handled.
  ///
  /// Separates a superseded command from a request that received no
  /// acknowledgement. Both have no payload, but only the latter may be retried:
  /// a `PHASE_CLOSED` response means the room already moved on.
  Future<({Map<String, dynamic>? payload, bool superseded})> _send(
    String function,
    Map<String, dynamic> body, {
    bool hostOnly = false,
    bool assured = false,
  }) async {
    if (hostOnly && !isHost) return (payload: null, superseded: false);
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
      return (payload: result, superseded: false);
    } on BackendException catch (e) {
      if (e.isPhaseClosed) {
        await resync();
        return (payload: null, superseded: true);
      }
      if (e.isNotHost) return (payload: null, superseded: false);
      rethrow;
    } on BackendUnreachable {
      _degrade();
      // A move the player made is not allowed to disappear quietly.
      //
      // `_degrade` paints the weather, and for a phase this client is merely
      // *driving* that is enough — the next deadline alarm asks again. It is
      // not enough for something the player did: the caller clears the screen
      // once this returns, and that screen was the only remaining way to try
      // again. A reveal card was dismissed this way for a seat the server went
      // on listing as waiting, with the card gone and «كمل» refused for the
      // whole room, permanently. So an assured call reports the truth: the
      // room was never told.
      if (assured) rethrow;
      return (payload: null, superseded: false);
    }
  }

  /// An RFC 4122 v4 identifier, because that is what the column is.
  ///
  /// `night_actions.action_id` and `votes.action_id` are `uuid`. This used to
  /// return `<hex microseconds>-<hex salt>`, which is unique, readable, and
  /// not a UUID — so Postgres refused the row with `22P02`, the Edge Function
  /// turned that into a 400, and the *move the key was riding on* was refused
  /// with it. Every night action and every vote in every online match, told to
  /// the player as «اختيارك متسجلش». The key is not the point of the request;
  /// it must never be the thing that loses it.
  String _actionId() {
    // Sixteen bytes, with the version and variant nibbles pinned. Not
    // `1 << 32` anywhere: on the web that shift is 32-bit and evaluates to
    // zero, and `nextInt(0)` throws. See `newMatchSeed`.
    final bytes = List<int>.generate(16, (_) => _ids.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int from, int to) => [
      for (var i = from; i < to; i++)
        bytes[i].toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-'
        '${hex(10, 16)}';
  }

  @override
  Future<void> beginNight() async {
    await _send('open_phase', {'phase': 'night'}, hostOnly: true);
  }

  @override
  Future<void> confirmRevealed() async {
    // There is nothing to hand on — this client is looking at its own card —
    // but the room does have to know the card was looked at. Offline that fact
    // is witnessed: the phone comes back. Online it is a claim, so it is sent
    // to the one place that may hold it, and `open_phase` reads it there
    // rather than taking any client's word for the room's readiness.
    //
    // What crosses is a boolean about *this* seat. Nothing about what was on
    // the card goes with it.
    await _send('saw_role', const {}, assured: true);
    await resync();

    // The server's word for it, not the request's.
    //
    // A card may only leave the screen once the room actually holds the fact
    // that it was seen, because dismissing it is irreversible on this device
    // and the phase it gates is refused until every seat has one. A request
    // that was lost, quietly refused, or answered by something that never
    // reached the row leaves this seat in the waiting list with nothing left
    // to press — so it ends here, as an error the card can be shown for again.
    final me = backend.userId;
    final mine = _players.where((player) => player.userId == me).firstOrNull;
    if (_state?.phase == 'reveal' && mine != null && !mine.sawRole) {
      throw const BackendException(
        'NOT_ACKNOWLEDGED',
        'the room was not told the card was seen',
      );
    }
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
    bool useBullet = false,
  }) async {
    // The seat is not sent. The server takes the actor from the JWT, and a
    // client that could name one would be O17 with a different noun.
    if (seat != mySeat) return null;
    final sent = await _send('submit_night_action', {
      'action': targetSeat == null ? 'skip' : nightActionToServer(kind),
      'targetSeat': targetSeat,
      // The *intention*, and nothing more. Whether it is honoured is the
      // server's call: it checks the role it holds, the room's settings, and
      // whether this player has already spent theirs. A client that asked for
      // a move it does not have is refused rather than obeyed.
      'useBullet': useBullet,
    }, assured: true);
    if (sent.superseded) return null;
    final result = sent.payload;
    if (result == null) {
      throw const BackendException('ACTION_NOT_SAVED', 'No acknowledgement');
    }
    final own = _own;
    if (own != null) {
      _own = own.copyWith(
        actedThisNight: true,
        // From the ack, not from the request. The client asked; the server
        // decided; this is the decision. `??` rather than a default so an
        // older server that does not send the field leaves the flag alone
        // instead of clearing a bullet that was spent.
        bulletSpent:
            (result['bulletSpent'] as bool? ?? false) || own.bulletSpent,
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

  /// Yes, since `submit_night_action` learned what one is.
  ///
  /// It used to be false, and the comment here used to say why: the night is
  /// resolved server-side (doc 10 §5), so a client offering the control would
  /// have been offering a move the server silently dropped. That was true and
  /// it cost the online Doctor their self-protection outright — the server
  /// refused a self-target with `"not yourself"`, so the tile bearing their own
  /// name was a tile that could not be pressed.
  ///
  /// The server now validates both bullets against the role *it* holds, spends
  /// them into `night_actions.used_bullet`, and refuses a second one against a
  /// partial unique index. Constant for the whole match either way, which is
  /// what makes the answer safe to read: it is a fact about this match, never
  /// about whoever is holding the phone.
  @override
  bool get supportsBullets => true;

  @override
  bool get currentActorBulletSpent => _own?.bulletSpent ?? false;

  @override
  Future<void> resolveNight() async {
    await _send('resolve_night', const {}, hostOnly: !_mayDrive);
  }

  @override
  Future<void> beginDay() async {
    final state = _state;
    // The morning carries a clock now, so a guest may open the day once it has
    // run out — otherwise the one beat with nothing to answer would be the one
    // beat that could strand the match.
    if (state == null || (!isHost && !_mayDrive)) return;
    // Day 1 opens on «اسم واحد»; every later day opens on the confrontation the
    // server chooses, or on discussion when it finds nothing true to say.
    if (state.phaseNumber <= 1) {
      await _send('open_phase', {'phase': 'opening'}, hostOnly: !_mayDrive);
    } else {
      await _send('generate_confrontation', const {}, hostOnly: !_mayDrive);
    }
  }

  @override
  Future<void> submitOpeningAccusation({
    required int seat,
    required int targetSeat,
  }) async {
    if (seat != mySeat) return;
    final sent = await _send('submit_accusation', {
      'targetSeat': targetSeat,
    }, assured: true);
    if (sent.superseded) return;
    final result = sent.payload;
    if (result == null) {
      throw const BackendException('ACTION_NOT_SAVED', 'No acknowledgement');
    }
  }

  @override
  Future<void> endConfrontation({required bool silent}) async {
    // Not `hostOnly`. The button belongs to the *confronted player* — the
    // table draws it for `confrontation.targetSeat` and for nobody else — so
    // gating the call on the host meant that unless the accused happened to be
    // holding the room, «خلصت» posted a request the server refused with
    // `NOT_HOST` and the table waited out the full forty-five seconds instead.
    // The server now recognises the target as entitled to close their own
    // window, which is the same shape as the deal: the gate is the gate, not
    // the caller's identity.
    await _send('open_phase', {'phase': 'discuss', 'silent': silent});
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
    final sent = await _send('send_whisper', {
      'toSeat': toSeat,
      'body': body,
    }, assured: true);
    // A whisper that could not be sent has no id, and the compose screen is
    // entitled to know that rather than to be told a lie it can quote.
    final id = sent.payload?['id'] as String?;
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
  Future<void> setReadyToVote(bool ready) async {
    await _send('ready_to_vote', {'ready': ready});
  }

  @override
  Future<void> submitVote({required int seat, required int? targetSeat}) async {
    if (seat != mySeat) return;
    final state = _state;
    final sent = await _send('submit_vote', {
      'targetSeat': targetSeat,
      'round': state == null ? 1 : _round(state),
    }, assured: true);
    if (sent.superseded) return;
    final result = sent.payload;
    if (result == null) {
      throw const BackendException('ACTION_NOT_SAVED', 'No acknowledgement');
    }
    final own = _own;
    if (own != null &&
        state != null &&
        _state?.phase == state.phase &&
        _state?.phaseNumber == state.phaseNumber &&
        _round(_state!) == _round(state)) {
      _own = own.copyWith(votedRound: _round(state));
      _publish();
    }
  }

  @override
  Future<void> resolveDayVote() async {
    await _send('resolve_vote', const {}, hostOnly: !_mayDrive);
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
    if (state == null) return;

    // The deal is the one phase that ends on a decision rather than on a
    // clock, and `advance_phase` — which exists to apply *expiry defaults* —
    // has no row for it. That mismatch is why «كمل» did nothing: the button
    // posted to a function that looked at `reveal`, found no default to apply,
    // and honestly answered that it had applied none.
    //
    // The deal ends by opening the night, and any member may ask for it: the
    // server refuses until every seat has dismissed its card, so the gate is
    // the gate and not the caller's identity.
    if (state.phase == 'reveal') {
      await _send('open_phase', const {'phase': 'night'});
      return;
    }

    // The morning is the second phase that ends on a decision rather than on a
    // clock, and it stalled for exactly the same reason the deal did: «كمل»
    // posted to `advance_phase`, which exists to apply *expiry defaults*, has
    // no row for a phase with no deadline, and honestly answered that it had
    // applied none. The room sat on the morning report forever.
    //
    // A morning ends by the day opening — day 1 on «اسم واحد», any later day
    // on the confrontation the server chooses or on nothing, which is what
    // `beginDay` already knows how to ask for.
    if (state.phase == 'morning') {
      await beginDay();
      return;
    }

    // The verdict is the third phase that ends on a decision: the card has
    // risen, the room has read it, and what comes next is either the night that
    // follows this day or the end of the match. Which of the two is not the
    // client's judgement — `outcome` is written by `resolve_vote`, and
    // `open_phase` refuses `result` unless the server holds one.
    if (state.phase == 'verdict') {
      if (!isHost && !_mayDrive) return;
      final decided = state.publicData['outcome'] != null;
      await _send('open_phase', {
        'phase': decided ? 'result' : 'night',
      }, hostOnly: !_mayDrive);
      return;
    }

    if (!isHost && !_mayDrive) return;
    await _send('advance_phase', const {}, hostOnly: !_mayDrive);
    // The defaults fill in the moves nobody made; somebody still has to tally
    // them, and online that somebody is whichever client is driving.
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
    var own = _own;
    var state = _state;
    if (own == null || state == null || seat != own.seat) return null;

    var role = roleFromServer(own.role);
    if (state.phase == 'reveal') {
      // A phase push can race an older full read already in flight. Re-read on
      // the private request itself instead of waiting for an unrelated push;
      // the server still decides which role this JWT may receive.
      if (role == null) {
        await resync();
        own = _own;
        state = _state;
        if (own == null || state?.phase != 'reveal' || seat != own.seat) {
          return null;
        }
        role = roleFromServer(own.role);
      }
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
    await refreshBlocks();
  }

  Set<String> get blockedUserIds => Set.unmodifiable(_blocked);
  List<RoomPlayer> get safetyPlayers =>
      List.unmodifiable(_players.where((p) => p.userId != backend.userId));

  Future<void> refreshBlocks() async {
    _blocked = await backend.blockedSenders(roomId);
    final channel = _witness;
    if (channel is BackendWitnessChannel) channel.refreshBlocks();
    _publish();
  }

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    _deadlineAlarm?.cancel();
    _earlyAlarm?.cancel();
    _ballotPoll?.cancel();
    _retry?.cancel();
    await _pushes?.cancel();
    await _witness?.dispose();
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
