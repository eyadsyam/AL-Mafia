import 'dart:async';
import 'dart:developer' as developer;

import '../../engine/models/enums.dart' show PlayerStatus;
import '../../engine/voice_policy.dart';
import '../../transport/game_snapshot.dart';
import '../../transport/online_backend.dart' show VoiceSignal;
import '../../transport/voice_link.dart';
import '../../ui/theme/design_tokens.dart';
import 'voice_diagnostics.dart';
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

  /// Local, safe audio levels by seat for the speaking ring. These values are
  /// never written to the game snapshot or sent over signalling.
  final Map<int, double> speakingLevels;

  /// This player is out, and talks only to the others who are out (doc 12
  /// §4.1, owner decision 2026-09-23). The floor is not theirs to ask for.
  final bool witness;

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
    this.speakingLevels = const {},
    this.witness = false,
  });

  /// Whether this device may ask for the floor at all right now.
  ///
  /// A control that is offered and then refused teaches a player that the app
  /// is unreliable; one that is not offered teaches them the rule.
  bool get canRequestFloor =>
      !witness &&
      policy == MicPolicy.activeSpeakerOnly &&
      activeSpeakerSeat == null;

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
    Map<int, double>? speakingLevels,
    bool? witness,
    bool clearRung = false,
    bool clearSpeaker = false,
  }) => VoiceState(
    mode: mode ?? this.mode,
    rung: clearRung ? null : (rung ?? this.rung),
    microphoneAvailable: microphoneAvailable ?? this.microphoneAvailable,
    microphoneLive: microphoneLive ?? this.microphoneLive,
    policy: policy ?? this.policy,
    activeSpeakerSeat: clearSpeaker
        ? null
        : (activeSpeakerSeat ?? this.activeSpeakerSeat),
    holdsFloor: clearSpeaker ? false : (holdsFloor ?? this.holdsFloor),
    // Never carried forward. The notice is a one-shot by construction
    // rather than by anybody remembering to clear it (V1).
    receiveOnlyNotice: receiveOnlyNotice ?? false,
    selfMuted: selfMuted ?? this.selfMuted,
    speakingLevels: speakingLevels ?? this.speakingLevels,
    witness: witness ?? this.witness,
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

  /// How often local WebRTC audio levels are sampled for the speaking ring.
  /// `Duration.zero` turns the sampler off — the state that widget tests want,
  /// so a leaked periodic timer cannot outlive a pumped frame.
  final Duration statsInterval;

  VoiceController({
    required this.engine,
    required this.link,
    IceConfig? relay,
    this.rungTimeout = const Duration(seconds: 8),
    this.statsInterval = MafiaTiming.voiceStatsSample,
  }) : relay = relay ?? IceConfig.relay();

  final _states = StreamController<VoiceState>.broadcast();

  VoiceState _state = const VoiceState();
  StreamSubscription<VoiceSignal>? _inbound;
  StreamSubscription<VoiceEngineEvent>? _outbound;
  Timer? _statsTicker;

  int? _selfSeat;

  /// Seats that are out of the match. The witness wall (doc 12 §4.1, owner
  /// decision 2026-09-23) runs on this set: the living hear only the living;
  /// the dead hear everybody; a dead device sends only to the dead.
  Set<int> _deadSeats = const {};
  bool get _selfDead => _selfSeat != null && _deadSeats.contains(_selfSeat);
  List<VoicePeer> _peers = const [];

  /// True while the phase forbids a call existing at all. Gates the signal
  /// pump as well as the connection, so a peer cannot talk this device into a
  /// negotiation during the night (V6).
  bool _tornDown = false;

  /// Which media cycle the call currently belongs to.
  ///
  /// [_tornDown] alone cannot answer "is this climb still the current one",
  /// because it is a *state* and the night is a *round trip*. A climb that
  /// began before a night and woke up after the day had already returned found
  /// `_tornDown == false`, decided it was fine, and published `live` for a mesh
  /// the night had closed underneath it — the microphone re-opened against a
  /// connection nobody was on the other end of, and the state the controls
  /// rendered was a call that did not exist.
  ///
  /// A counter cannot be fooled by a value returning to what it was. Every
  /// teardown bumps it; every climb captures it before its first await and
  /// abandons itself the moment it does not match. See
  /// [WebRtcVoiceEngine]'s own generation, which does the same for the
  /// connections themselves — this one is about what the *player* is told.
  int _mediaEpoch = 0;

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

  /// One outbound chain per peer, so signalling arrives in the order it was
  /// created. See [_sendInOrder].
  final Map<String, Future<void>> _sending = {};

  /// Set by the player, cleared by the player, and by nothing else.
  bool _selfMuted = false;
  int _revision = 0;
  bool _disposed = false;
  Future<void>? _connecting;
  bool _connectAgain = false;

  /// The seats the host has silenced (task 6), as the last snapshot reported.
  ///
  /// Enforced twice, deliberately. The muted device stops publishing, which is
  /// the polite half and the one a modified client can skip; every *listener*
  /// also refuses to render that peer, which is the half that holds. The same
  /// two-sided argument as doc 10 §6.1's V4, for the same reason: a mesh has
  /// nothing in the middle to drop a stream.
  Set<int> _mutedSeats = const {};
  Set<String> blockedUsers = const {};

  VoiceState get state => _state;

  Stream<VoiceState> watch() => Stream.multi((sink) {
    sink.add(_state);
    final subscription = _states.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.onCancel = subscription.cancel;
  }, isBroadcast: true);

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
      if (_tornDown ||
          _disposed ||
          !link.peers.any((p) => p.userId == signal.fromUserId))
        return;
      engine.acceptSignal(signal.fromUserId, signal.payload);
    });

    _outbound = engine.events.listen((event) {
      if (event is OutboundSignal) {
        _sendInOrder(event.toUserId, event.payload);
      } else if (event is PeerConnected) {
        // A peer that comes up after the ladder gave up. This happens: the
        // rung's timeout is eight seconds and a relayed connection through a
        // busy TURN can take longer, and it happens on every ICE restart. The
        // mesh is left standing when a rung fails precisely so that this can
        // promote it, rather than the call being permanently text because a
        // stopwatch ran out first.
        unawaited(_promoteToLive());
      }
    });

    if (statsInterval > Duration.zero) {
      _statsTicker ??= Timer.periodic(
        statsInterval,
        (_) => unawaited(_sampleSpeaking()),
      );
    }
    await _climb();
  }

  /// Reacts to a new snapshot. Never throws, and nothing awaits its result.
  Future<void> apply(GameSnapshot snapshot) async {
    if (_disposed) return;
    final revision = ++_revision;
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
    _deadSeats = {
      for (final player in snapshot.public.players)
        if (player.status == PlayerStatus.dead) player.seat,
    };
    _emit(
      _state.copyWith(
        policy: policy,
        witness: _selfDead,
        activeSpeakerSeat: snapshot.activeSpeakerSeat,
        clearSpeaker: snapshot.activeSpeakerSeat == null,
      ),
    );

    if (voiceTornDownIn(snapshot.phase) ||
        !snapshot.room.voice ||
        snapshot.roomClosed ||
        snapshot.viewerKicked) {
      if (!_tornDown) {
        _tornDown = true;
        _mediaEpoch++;
        await _quietly(engine.teardown);
      }
      _emit(
        _state.copyWith(
          mode: VoiceMode.off,
          clearRung: true,
          microphoneLive: false,
          policy: policy,
          clearSpeaker: true,
          speakingLevels: const {},
        ),
      );
      return;
    }

    // The night is over. Come back up — from the bottom of the ladder, because
    // the network under a room that has been quiet for four minutes is not
    // necessarily the one the first rung succeeded on.
    if (_tornDown) {
      _tornDown = false;
      _peers = link.peers;
      if (_started) await _climb();
    } else if (_started && _rosterChanged(link.peers)) {
      // Somebody joined or left. The call was made to the room as it was, and
      // a player who arrived after it came up would otherwise be in a room
      // that cannot hear them — which is the whole point of bringing voice up
      // in the lobby rather than at kick-off.
      _peers = link.peers;
      await _climb();
    }

    if (_disposed || revision != _revision || _tornDown) return;
    final speaker = snapshot.activeSpeakerSeat;
    final maySpeak =
        !_selfDead &&
        switch (policy) {
          MicPolicy.open => true,
          MicPolicy.activeSpeakerOnly =>
            speaker != null && speaker == _selfSeat,
          MicPolicy.muted => false,
        };

    // Sending first, then hearing: a device that has just died must stop
    // reaching the living before anything else about the call changes.
    await _quietly(() => engine.setSendingPeers(_sendingTo()));
    await _quietly(() => engine.setAudiblePeers(_audible(policy, speaker)));
    if (_disposed || revision != _revision || _tornDown) return;

    _emit(
      _state.copyWith(
        policy: policy,
        activeSpeakerSeat: speaker,
        holdsFloor: maySpeak && policy == MicPolicy.activeSpeakerOnly,
        clearSpeaker: speaker == null,
      ),
    );

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

  /// Called by a user gesture: browsers may refuse audio autoplay even with
  /// permission to capture the microphone. Retry output separately from mute.
  Future<void> enableAudio() async {
    if (_tornDown || _disposed) return;
    final epoch = _mediaEpoch;
    final output = engine;
    // Quietly, like everything else here. This one is reached from a tap, and
    // a media stack that throws on the way out of a `<audio>` element it no
    // longer owns — a night closed the renderers while the gesture was in
    // flight — would put an exception in front of a player mid-match. Doc 10
    // §1.2 does not have an exception for the paths a finger starts.
    if (output is VoicePlayout) {
      await _quietly((output as VoicePlayout).resumePlayout);
    }
    if (epoch != _mediaEpoch || _tornDown || _disposed) return;
    if (_state.mode == VoiceMode.text || !_micAvailable) {
      if (!_micAvailable) _micAsked = false;
      _peers = link.peers;
      await _climb();
    }
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
    // The dead talk among themselves whenever the call is up; the floor is a
    // rule for the living. Who can hear them is [_sendingTo]'s business.
    final maySpeak =
        _selfDead ||
        switch (policy) {
          MicPolicy.open => true,
          MicPolicy.activeSpeakerOnly =>
            speaker != null && speaker == _selfSeat,
          MicPolicy.muted => false,
        };
    final live =
        maySpeak &&
        _micAvailable &&
        !_selfMuted &&
        !_mutedSeats.contains(_selfSeat) &&
        _state.mode == VoiceMode.live;
    await _quietly(() => engine.setMicrophoneLive(live));
    _emit(_state.copyWith(microphoneLive: live, selfMuted: _selfMuted));
  }

  /// The media chain's own account of itself, for a person holding a phone.
  ///
  /// Safe by construction — see [VoiceDiagnostics], which may only hold
  /// booleans, counts and enum names. Nothing in the game reads it.
  Future<void> sampleDiagnostics() async {
    final output = engine;
    if (output is VoicePlayout) {
      await _quietly((output as VoicePlayout).sampleMediaStats);
    }
  }

  Future<void> _sampleSpeaking() async {
    if (_disposed) return;
    if (_state.mode != VoiceMode.live && _state.mode != VoiceMode.connecting) {
      if (_state.speakingLevels.isNotEmpty) {
        _emit(_state.copyWith(speakingLevels: const {}));
      }
      return;
    }
    await sampleDiagnostics();
    if (_disposed || engine is! VoicePlayout) return;
    final output = engine as VoicePlayout;
    final levels = <int, double>{};
    for (final peer in _peers) {
      final level = output.speakingLevels[peer.userId] ?? 0;
      if (level > CouncilTokens.voicePulseThreshold) {
        levels[peer.seat] = level;
      }
    }
    if (_state.microphoneLive &&
        _selfSeat != null &&
        output.localSpeakingLevel > CouncilTokens.voicePulseThreshold) {
      levels[_selfSeat!] = output.localSpeakingLevel;
    }
    if (_sameLevels(levels, _state.speakingLevels)) return;
    _emit(_state.copyWith(speakingLevels: levels));
  }

  bool _sameLevels(Map<int, double> a, Map<int, double> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if ((b[entry.key] ?? 0) != entry.value) return false;
    }
    return true;
  }

  String diagnosticsReport() {
    final buffer = StringBuffer()
      ..writeln(
        'MODE   ${_state.mode.name}'
        '${_state.rung == null ? '' : ' (${_state.rung!.name})'}',
      )
      ..writeln(
        'POLICY ${_state.policy.name}'
        '  speaker=${_state.activeSpeakerSeat ?? '-'}'
        '  floor=${_state.holdsFloor}',
      )
      ..writeln(
        'PEERS  ${_peers.length} in roster, '
        '${_peers.where((p) => p.userId != link.selfId).length} dialled',
      )
      ..write(engine.diagnostics.report());
    return buffer.toString();
  }

  /// Asks the server for the floor. False is an ordinary answer.
  Future<bool> requestFloor() => link.claimFloor();

  /// Hands the floor back.
  Future<void> yieldFloor() => link.releaseFloor();

  Future<void> dispose() async {
    _disposed = true;
    _statsTicker?.cancel();
    _statsTicker = null;
    _tornDown = true;
    _revision++;
    _mediaEpoch++;
    await _inbound?.cancel();
    await _outbound?.cancel();
    await _quietly(engine.teardown);
    await _quietly(engine.dispose);
    await _states.close();
  }

  // ---------------------------------------------------------------------------

  /// STUN, then TURN, then text (doc 10 §6.2).
  Future<void> _climb() async {
    if (_disposed || _tornDown) return;
    if (_connecting != null) {
      _connectAgain = true;
      return _connecting;
    }
    final work = _connectUntilCurrent();
    _connecting = work;
    try {
      await work;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _connectUntilCurrent() async {
    do {
      _connectAgain = false;
      await _connectOnce();
    } while (_connectAgain && !_disposed && !_tornDown);
  }

  Future<void> _connectOnce() async {
    // Captured before the first await. Everything below asks whether this is
    // still the cycle it started in; a climb that has been retired by a night
    // stops without touching the engine, because the cycle that retired it is
    // the one that owns the engine now.
    final epoch = _mediaEpoch;
    _emit(_state.copyWith(mode: VoiceMode.connecting, clearRung: true));

    // Asked once per session, not once per rung: a permission dialog that
    // reappears every time a night ends is the opposite of "told once, calmly".
    if (!_micAsked) {
      _micAsked = true;
      _micAvailable = await _quietly(engine.acquireMicrophone) ?? false;
      // Published even when the cycle has moved on: whether this device has a
      // microphone is a fact about the device, and V1's one calm notice is
      // owed to the player whether or not a night landed while the permission
      // dialog was up.
      _emit(
        _state.copyWith(
          microphoneAvailable: _micAvailable,
          receiveOnlyNotice: !_micAvailable,
        ),
      );
    }
    if (epoch != _mediaEpoch) return;

    // Before any `RTCPeerConnection` exists. A mesh brought up on public STUN
    // alone dies silently behind symmetric NAT — the microphone is granted,
    // candidates are gathered, and nothing ever connects — which is the shape
    // of the failure this repository has been carrying.
    await _fetchIceServers();
    if (epoch != _mediaEpoch || _disposed || _tornDown) return;

    final selfId = link.selfId;
    final others = _peers.where((p) => p.userId != selfId).toList();

    for (final ice in _ladder()) {
      final up =
          await _quietly(
            () => engine.connect(
              selfId: selfId,
              ice: ice,
              peers: others,
              timeout: rungTimeout,
            ),
          ) ??
          false;
      // Order matters. A cycle that has been retired must leave the engine
      // exactly as it found it — the mesh standing there was built by whoever
      // retired it, and tearing it down here is the same night-into-day bug
      // with the sign flipped.
      if (epoch != _mediaEpoch) return;
      if (_disposed || _tornDown) {
        await _quietly(engine.teardown);
        return;
      }
      if (up) {
        _emit(_state.copyWith(mode: VoiceMode.live, rung: ice.rung));
        // Before the microphone, and on every climb. `setAudiblePeers` is the
        // receiving half of V4 and the engine starts every session admitting
        // nobody, so a mesh that came up between two snapshots used to deliver
        // tracks with `enabled == false` and stay silent until the next phase
        // change happened to say otherwise.
        await _quietly(
          () => engine.setAudiblePeers(
            _audible(_state.policy, _state.activeSpeakerSeat),
          ),
        );
        if (epoch != _mediaEpoch) return;
        await _syncMicrophone();
        return;
      }
    }
    if (epoch != _mediaEpoch) return;

    // V3. This player types; the match does not notice.
    //
    // The mesh is *not* torn down here. A rung that timed out is a rung whose
    // connections are still negotiating, and closing them turned a slow call
    // into a permanently silent one — there was nothing left that could ever
    // report connected. Text mode is what this player sees now; if a peer
    // arrives late, `PeerConnected` promotes the call back to live.
    _emit(
      _state.copyWith(
        mode: VoiceMode.text,
        rung: VoiceRung.text,
        microphoneLive: false,
      ),
    );
  }

  /// Moves a call that had fallen to text back up, when a peer finally
  /// connects.
  ///
  /// Only from [VoiceMode.text] and [VoiceMode.connecting]: a torn-down night
  /// is [VoiceMode.off] and must stay that way (V6), and a straggler
  /// connecting during one is not a reason to bring the call back.
  Future<void> _promoteToLive() async {
    if (_disposed || _tornDown) return;
    if (_state.mode != VoiceMode.text && _state.mode != VoiceMode.connecting) {
      return;
    }
    _emit(_state.copyWith(mode: VoiceMode.live, rung: _fetched?.rung));
    await _quietly(
      () => engine.setAudiblePeers(
        _audible(_state.policy, _state.activeSpeakerSeat),
      ),
    );
    await _syncMicrophone();
  }

  /// One signal at a time, per peer, in the order the engine produced them.
  ///
  /// An offer and the candidates that follow it are a sequence, and the
  /// transport's `send` is asynchronous: firing them concurrently let a
  /// candidate overtake the offer it belonged to, at which point the receiving
  /// end has a candidate for a negotiation it has not heard of. The engine now
  /// queues those rather than dropping them, but arriving in order is cheaper
  /// than arriving early and being held.
  ///
  /// Still fire-and-forget from the caller's side: a dropped signal costs one
  /// peer's audio, and the ladder already treats a peer that never connects as
  /// ordinary.
  void _sendInOrder(String toUserId, Map<String, dynamic> payload) {
    final previous = _sending[toUserId] ?? Future<void>.value();
    _sending[toUserId] = previous
        .then((_) => link.send(toUserId, payload))
        .catchError((_) {});
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
    // Re-asked while the answer has no relay in it. The relay credentials
    // arrive on Metered's welcome frame, which is a socket handshake racing a
    // microphone permission dialog — so the first climb can legitimately get
    // STUN-only and the second one get TURN. Caching that first answer for the
    // whole match is how a build with working TURN credentials ends up never
    // using them.
    if (_fetchAttempted && _fetched?.rung == VoiceRung.turn) return;
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
    bool allowed(VoicePeer p) =>
        !_mutedSeats.contains(p.seat) && !blockedUsers.contains(p.userId);

    // A dead seat is never heard by the living, under any policy. Before the
    // witness wall this set let an eliminated player's open microphone reach
    // the table during a free discussion.
    bool living(VoicePeer p) => !_deadSeats.contains(p.seat);
    final fromTheTable = switch (policy) {
      MicPolicy.open =>
        _peers
            .where((p) => allowed(p) && living(p))
            .map((p) => p.userId)
            .toSet(),
      MicPolicy.activeSpeakerOnly =>
        speaker == null
            ? const <String>{}
            : _peers
                  .where((p) => p.seat == speaker && allowed(p) && living(p))
                  .map((p) => p.userId)
                  .toSet(),
      MicPolicy.muted => const <String>{},
    };
    if (!_selfDead) return fromTheTable;
    return {
      ...fromTheTable,
      for (final p in _peers)
        if (!living(p) && allowed(p) && p.seat != _selfSeat) p.userId,
    };
  }

  /// Null — everybody — for a living device. The other dead, and nobody else,
  /// for a dead one.
  Set<String>? _sendingTo() {
    if (!_selfDead) return null;
    return {
      for (final p in _peers)
        if (_deadSeats.contains(p.seat) && p.seat != _selfSeat) p.userId,
    };
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
