import 'dart:async';
import 'dart:developer' as developer;

import '../../engine/voice_policy.dart';
import '../../transport/game_snapshot.dart';
import '../../transport/online_backend.dart' show VoiceSignal;
import '../../transport/voice_link.dart';
import 'voice_engine.dart';

/// Where the call is, from the point of view of a person looking at a screen.
enum VoiceMode {
  /// Not running: before the lobby, and for the whole of the night (V6).
  off,

  /// Climbing the ladder. The match does not wait for this.
  connecting,

  /// Audio is flowing on some rung.
  live,

  /// Neither rung came up, so this player reads and types (V3). Everybody
  /// else's call is unaffected — that is the point of a per-player fallback.
  text,
}

/// What the voice controls and nothing else may render.
class VoiceState {
  final VoiceMode mode;
  final VoiceRung? rung;

  /// False when the platform said no, or when there is no microphone at all
  /// (V1, V2). The call still runs; this player only listens.
  final bool microphoneAvailable;

  /// Whether this device's own track is actually publishing right now.
  final bool microphoneLive;

  /// What the phase permits, which is never the same question as the one
  /// above.
  final MicPolicy policy;

  final int? activeSpeakerSeat;

  /// True when the floor is this device's. Not the same as [microphoneLive]:
  /// a player with no microphone can hold the floor and be silent, which is
  /// V1 and V2 and is not an error state.
  final bool holdsFloor;

  /// True for exactly one state, the first one after the microphone was
  /// refused. V1: *"told once, calmly, then never again."*
  final bool receiveOnlyNotice;

  /// Whether this player has silenced their own microphone.
  ///
  /// The one thing about the call a player decides. It only ever subtracts —
  /// see [VoiceController.setSelfMuted] — so it is a fact about this device
  /// and never a permission.
  final bool selfMuted;

  const VoiceState({
    this.mode = VoiceMode.off,
    this.rung,
    this.microphoneAvailable = false,
    this.microphoneLive = false,
    this.policy = MicPolicy.muted,
    this.activeSpeakerSeat,
    this.holdsFloor = false,
    this.receiveOnlyNotice = false,
    this.selfMuted = false,
  });

  /// Whether this device may ask for the floor at all right now.
  ///
  /// A control that is offered and then refused teaches a player that the app
  /// is unreliable; one that is not offered teaches them the rule.
  bool get canRequestFloor =>
      policy == MicPolicy.activeSpeakerOnly && activeSpeakerSeat == null;

  /// Whether the microphone switch is worth offering.
  ///
  /// There is a microphone to silence and a call to silence it in. Offered
  /// while the ladder is still climbing as well as after it settles, so a
  /// player who wants to be muted before anybody can hear them can be —
  /// [VoiceController.setSelfMuted] is remembered and applied when the call
  /// comes up.
  ///
  /// Not conditioned on the phase: a player who wants to be sure they are
  /// silent should be able to see that they are, and the switch cannot make
  /// them audible in a phase that does not already allow it.
  bool get canMuteSelf =>
      microphoneAvailable &&
      (mode == VoiceMode.live || mode == VoiceMode.connecting);

  VoiceState copyWith({
    VoiceMode? mode,
    VoiceRung? rung,
    bool? microphoneAvailable,
    bool? microphoneLive,
    MicPolicy? policy,
    int? activeSpeakerSeat,
    bool? holdsFloor,
    bool? receiveOnlyNotice,
    bool? selfMuted,
    bool clearRung = false,
    bool clearSpeaker = false,
  }) =>
      VoiceState(
        mode: mode ?? this.mode,
        rung: clearRung ? null : (rung ?? this.rung),
        microphoneAvailable: microphoneAvailable ?? this.microphoneAvailable,
        microphoneLive: microphoneLive ?? this.microphoneLive,
        policy: policy ?? this.policy,
        activeSpeakerSeat:
            clearSpeaker ? null : (activeSpeakerSeat ?? this.activeSpeakerSeat),
        holdsFloor: clearSpeaker ? false : (holdsFloor ?? this.holdsFloor),
        // Never carried forward. The notice is a one-shot by construction
        // rather than by anybody remembering to clear it (V1).
        receiveOnlyNotice: receiveOnlyNotice ?? false,
        selfMuted: selfMuted ?? this.selfMuted,
      );

  @override
  String toString() =>
      'VoiceState($mode, rung=$rung, mic=$microphoneLive, policy=$policy, '
      'speaker=$activeSpeakerSeat, selfMuted=$selfMuted)';
}

/// The call, driven by the game.
///
/// ## The one rule it exists to enforce
///
/// A microphone is live because the *phase* says so and the *server* says who,
/// and for no other reason. There is no path through this class where a tap
/// unmutes anybody: [requestFloor] asks the server, and the answer arrives as
/// an ordinary [GameSnapshot] like every other fact in the game. Doc 10 §6.1
/// is blunt about why — *"never trust the client to mute itself politely"* —
/// and this is the shape that follows from taking it seriously.
///
/// ## And the one rule it exists not to break
///
/// Every method here can fail and none of them can fail the match. There is no
/// `await` in the phase flow that reaches this class, no snapshot field it
/// writes, and nothing in [apply] that can throw into a caller: it is handed a
/// snapshot after the fact and it reacts. Voice is never load-bearing
/// (doc 10 §1.2), which is a claim the test suite makes good on by playing
/// whole matches with a [VoiceEngine] that fails at every rung.
class VoiceController {
  final VoiceEngine engine;
  final VoiceLink link;

  /// The second rung, if this build was given one. Null is an ordinary
  /// configuration and not a degraded one — see [IceConfig.relay].
  final IceConfig? relay;

  /// How long one rung is given before the ladder moves on. Doc 10 §6.2 puts
  /// voice "in the background during the lobby"; nothing waits for it, so the
  /// only cost of patience here is a slower fallback to text.
  final Duration rungTimeout;

  VoiceController({
    required this.engine,
    required this.link,
    IceConfig? relay,
    this.rungTimeout = const Duration(seconds: 8),
  }) : relay = relay ?? IceConfig.relay();

  final _states = StreamController<VoiceState>.broadcast();

  VoiceState _state = const VoiceState();
  StreamSubscription<VoiceSignal>? _inbound;
  StreamSubscription<VoiceEngineEvent>? _outbound;

  int? _selfSeat;
  List<VoicePeer> _peers = const [];

  /// True while the phase forbids a call existing at all. Gates the signal
  /// pump as well as the connection, so a peer cannot talk this device into a
  /// negotiation during the night (V6).
  bool _tornDown = false;

  /// Whether the ladder has been climbed at least once, so a reconnection
  /// after the night does not re-ask for microphone permission.
  bool _started = false;

  bool _micAvailable = false;
  bool _micAsked = false;

  /// The room's ICE servers, fetched once for the whole match.
  ///
  /// Once, not once per peer: the credentials are the same for every
  /// connection in the mesh, and a fetch per peer would be fifteen round trips
  /// to say the same thing — and, on a fifteen-seat table, fifteen chances for
  /// one of them to be slow at the exact moment the lobby fills.
  IceConfig? _fetched;
  bool _fetchAttempted = false;

  /// Set by the player, cleared by the player, and by nothing else.
  bool _selfMuted = false;

  /// The seats the host has silenced (task 6), as the last snapshot reported.
  ///
  /// Enforced twice, deliberately. The muted device stops publishing, which is
  /// the polite half and the one a modified client can skip; every *listener*
  /// also refuses to render that peer, which is the half that holds. The same
  /// two-sided argument as doc 10 §6.1's V4, for the same reason: a mesh has
  /// nothing in the middle to drop a stream.
  Set<int> _mutedSeats = const {};

  VoiceState get state => _state;

  Stream<VoiceState> watch() => _states.stream;

  /// Brings the call up in the background, in the lobby.
  ///
  /// Returns when the ladder has settled, which no caller is expected to wait
  /// for: the lobby's start button does not await this, and a match begun three
  /// seconds after the room filled begins with the call still connecting.
  Future<void> start({
    required int? selfSeat,
    required List<VoicePeer> peers,
  }) async {
    _selfSeat = selfSeat;
    _peers = peers;
    if (_started) return;
    _started = true;

    _inbound = link.incoming.listen((signal) {
      // Not merely ignored — refused. A signal arriving during the night is
      // either a straggler or an attempt, and neither one gets a peer
      // connection out of this device.
      if (_tornDown) return;
      engine.acceptSignal(signal.fromUserId, signal.payload);
    });

    _outbound = engine.events.listen((event) {
      if (event is OutboundSignal) {
        // Fire and forget: a dropped signal costs one peer's audio, and the
        // ladder already treats a peer that never connects as ordinary.
        link.send(event.toUserId, event.payload).catchError((_) {});
      }
    });

    await _climb();
  }

  /// Reacts to a new snapshot. Never throws, and nothing awaits its result.
  Future<void> apply(GameSnapshot snapshot) async {
    final policy = micPolicyFor(
      snapshot.phase,
      discussion: snapshot.settings.discussionMode,
    );

    // The seat comes from the snapshot rather than from whatever was known
    // when the call started. In the lobby the call comes up first and the
    // room fills afterwards, so a seat captured at `start` would be the seat
    // this device had before half the room existed.
    _selfSeat = snapshot.viewerSeat ?? _selfSeat;
    _mutedSeats = snapshot.mutedSeats;

    if (voiceTornDownIn(snapshot.phase)) {
      if (!_tornDown) {
        _tornDown = true;
        await _quietly(engine.teardown);
      }
      _emit(_state.copyWith(
        mode: VoiceMode.off,
        clearRung: true,
        microphoneLive: false,
        policy: policy,
        clearSpeaker: true,
      ));
      return;
    }

    // The night is over. Come back up — from the bottom of the ladder, because
    // the network under a room that has been quiet for four minutes is not
    // necessarily the one the first rung succeeded on.
    if (_tornDown) {
      _tornDown = false;
      _peers = link.peers;
      if (_started) await _climb();
    } else if (_started &&
        link.peers.isNotEmpty &&
        _rosterChanged(link.peers)) {
      // Somebody joined or left. The call was made to the room as it was, and
      // a player who arrived after it came up would otherwise be in a room
      // that cannot hear them — which is the whole point of bringing voice up
      // in the lobby rather than at kick-off.
      _peers = link.peers;
      await _climb();
    }

    final speaker = snapshot.activeSpeakerSeat;
    final maySpeak = switch (policy) {
      MicPolicy.open => true,
      MicPolicy.activeSpeakerOnly => speaker != null && speaker == _selfSeat,
      MicPolicy.muted => false,
    };

    await _quietly(() => engine.setAudiblePeers(_audible(policy, speaker)));

    _emit(_state.copyWith(
      policy: policy,
      activeSpeakerSeat: speaker,
      holdsFloor: maySpeak && policy == MicPolicy.activeSpeakerOnly,
      clearSpeaker: speaker == null,
    ));

    // The microphone is decided in one place, from the state that was just
    // published, so a player's own switch and a phase change cannot reach
    // different conclusions about the same facts.
    await _syncMicrophone();
  }

  /// Silences this device's microphone, or lets it go back to whatever the
  /// phase and the server already allow.
  ///
  /// This is not the client-side mute doc 10 §6.1 forbids. That rule is about
  /// a client that decides it *may speak*; this only ever subtracts. Muting
  /// works in every phase, and unmuting grants nothing — [_syncMicrophone]
  /// asks [micPolicyFor] and the active speaker exactly as it does after a
  /// snapshot, so a player who unmutes during a night is still silent.
  Future<void> setSelfMuted(bool muted) async {
    if (_selfMuted == muted) return;
    _selfMuted = muted;
    await _syncMicrophone();
  }

  /// Whether this player has silenced themselves.
  bool get selfMuted => _selfMuted;

  /// Re-decides whether the microphone publishes, from what is already known.
  ///
  /// Called after every snapshot, whenever the player touches the switch, and
  /// once the ladder settles — that last one matters in a lobby, where a call
  /// that came up between two joins would otherwise stay silent until somebody
  /// else arrived and produced the next snapshot.
  Future<void> _syncMicrophone() async {
    final policy = _state.policy;
    final speaker = _state.activeSpeakerSeat;
    final maySpeak = switch (policy) {
      MicPolicy.open => true,
      MicPolicy.activeSpeakerOnly => speaker != null && speaker == _selfSeat,
      MicPolicy.muted => false,
    };
    final live = maySpeak &&
        _micAvailable &&
        !_selfMuted &&
        !_mutedSeats.contains(_selfSeat) &&
        _state.mode == VoiceMode.live;
    await _quietly(() => engine.setMicrophoneLive(live));
    _emit(_state.copyWith(microphoneLive: live, selfMuted: _selfMuted));
  }

  /// Asks the server for the floor. False is an ordinary answer.
  Future<bool> requestFloor() => link.claimFloor();

  /// Hands the floor back.
  Future<void> yieldFloor() => link.releaseFloor();

  Future<void> dispose() async {
    await _inbound?.cancel();
    await _outbound?.cancel();
    await _quietly(engine.teardown);
    await _quietly(engine.dispose);
    await _states.close();
  }

  // ---------------------------------------------------------------------------

  /// STUN, then TURN, then text (doc 10 §6.2).
  Future<void> _climb() async {
    _emit(_state.copyWith(mode: VoiceMode.connecting, clearRung: true));

    // Asked once per session, not once per rung: a permission dialog that
    // reappears every time a night ends is the opposite of "told once, calmly".
    if (!_micAsked) {
      _micAsked = true;
      _micAvailable = await _quietly(engine.acquireMicrophone) ?? false;
      _emit(_state.copyWith(
        microphoneAvailable: _micAvailable,
        receiveOnlyNotice: !_micAvailable,
      ));
    }

    // Before any `RTCPeerConnection` exists. A mesh brought up on public STUN
    // alone dies silently behind symmetric NAT — the microphone is granted,
    // candidates are gathered, and nothing ever connects — which is the shape
    // of the failure this repository has been carrying.
    await _fetchIceServers();

    final selfId = link.selfId;
    final others = _peers.where((p) => p.userId != selfId).toList();

    for (final ice in _ladder()) {
      final up = await _quietly(() => engine.connect(
                selfId: selfId,
                ice: ice,
                peers: others,
                timeout: rungTimeout,
              )) ??
          false;
      if (up) {
        _emit(_state.copyWith(mode: VoiceMode.live, rung: ice.rung));
        await _syncMicrophone();
        return;
      }
    }

    // V3. This player types; the match does not notice.
    await _quietly(engine.teardown);
    _emit(_state.copyWith(
      mode: VoiceMode.text,
      rung: VoiceRung.text,
      microphoneLive: false,
    ));
  }

  /// The rungs to try, in order.
  ///
  /// One rung when the server answered: the array it hands back already holds
  /// STUN *and* TURN, and ICE tries the cheap candidates first on its own —
  /// a relay is only used when nothing else reaches. Splitting that into two
  /// rungs would make every symmetric-NAT pair wait out a whole STUN timeout
  /// before being allowed the thing that was going to work.
  ///
  /// Two rungs when it did not: public STUN, then whatever a build-time TURN
  /// define supplied, which is what this app had before.
  List<IceConfig> _ladder() {
    final fetched = _fetched;
    if (fetched != null) return [fetched];
    return [IceConfig.stun, if (relay != null) relay!];
  }

  /// Asks the server for the room's ICE servers, once.
  ///
  /// A failure is not a failure of the call: the ladder falls back to public
  /// STUN, which is what the app used before this existed, and the warning is
  /// logged rather than shown. Non-negotiable 5 — voice is never load-bearing,
  /// and that has to include the thing that configures it.
  Future<void> _fetchIceServers() async {
    if (_fetchAttempted) return;
    _fetchAttempted = true;
    final servers = await _quietly(link.iceServers);
    if (servers == null || servers.isEmpty) {
      developer.log(
        'ice_servers unavailable — falling back to public STUN. Voice will '
        'fail for any pair behind symmetric NAT.',
        name: 'voice',
        level: 900,
      );
      return;
    }
    final relaying = servers.any(
      (server) => server['urls'].toString().contains('turn'),
    );
    if (!relaying) {
      developer.log(
        'ice_servers returned no relay — STUN only.',
        name: 'voice',
        level: 900,
      );
    }
    _fetched = IceConfig(relaying ? VoiceRung.turn : VoiceRung.stun, servers);
  }

  /// Whether the room's addresses have changed since the call was made to it.
  ///
  /// Addresses, not seats: a seat that moved is not a peer that has to be
  /// dialled again, and [VoiceEngine.connect] tears the mesh down to rebuild
  /// it. Cheap to ask on every snapshot, and false on nearly all of them.
  ///
  /// An empty roster is never a change. A link that is not reporting anybody
  /// is saying "I do not know who is here", and the answer to that is to keep
  /// calling the room that was there — not to hang up on it.
  bool _rosterChanged(List<VoicePeer> roster) {
    final now = roster.map((p) => p.userId).toSet();
    final before = _peers.map((p) => p.userId).toSet();
    return now.length != before.length || !now.containsAll(before);
  }

  Set<String> _audible(MicPolicy policy, int? speaker) {
    // Subtracted last and from every branch, so there is no policy under which
    // a silenced player is heard — including the open discussion, which is the
    // one a host would be muting somebody *during*.
    bool allowed(VoicePeer p) => !_mutedSeats.contains(p.seat);

    switch (policy) {
      case MicPolicy.open:
        return _peers.where(allowed).map((p) => p.userId).toSet();
      case MicPolicy.activeSpeakerOnly:
        if (speaker == null) return const {};
        return _peers
            .where((p) => p.seat == speaker && allowed(p))
            .map((p) => p.userId)
            .toSet();
      case MicPolicy.muted:
        return const {};
    }
  }

  void _emit(VoiceState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
    // The state kept for the next reader has the notice spent. What went out
    // on the stream carries it; nothing after does.
    if (next.receiveOnlyNotice) {
      _state = next.copyWith(receiveOnlyNotice: false);
    }
  }

  /// Runs something that belongs to the call, and swallows what it throws.
  ///
  /// Not laziness about errors — it is the enforcement point for doc 10 §1.2.
  /// An exception out of a media stack is allowed to end the call and is not
  /// allowed to reach a phase.
  Future<T?> _quietly<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (_) {
      return null;
    }
  }
}
