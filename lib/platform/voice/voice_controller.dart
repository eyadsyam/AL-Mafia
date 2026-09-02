import 'dart:async';

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

  const VoiceState({
    this.mode = VoiceMode.off,
    this.rung,
    this.microphoneAvailable = false,
    this.microphoneLive = false,
    this.policy = MicPolicy.muted,
    this.activeSpeakerSeat,
    this.holdsFloor = false,
    this.receiveOnlyNotice = false,
  });

  /// Whether this device may ask for the floor at all right now.
  ///
  /// A control that is offered and then refused teaches a player that the app
  /// is unreliable; one that is not offered teaches them the rule.
  bool get canRequestFloor =>
      policy == MicPolicy.activeSpeakerOnly && activeSpeakerSeat == null;

  VoiceState copyWith({
    VoiceMode? mode,
    VoiceRung? rung,
    bool? microphoneAvailable,
    bool? microphoneLive,
    MicPolicy? policy,
    int? activeSpeakerSeat,
    bool? holdsFloor,
    bool? receiveOnlyNotice,
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
      );

  @override
  String toString() =>
      'VoiceState($mode, rung=$rung, mic=$microphoneLive, policy=$policy, '
      'speaker=$activeSpeakerSeat)';
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
      if (_started) await _climb();
    }

    final speaker = snapshot.activeSpeakerSeat;
    final maySpeak = switch (policy) {
      MicPolicy.open => true,
      MicPolicy.activeSpeakerOnly => speaker != null && speaker == _selfSeat,
      MicPolicy.muted => false,
    };

    final live = maySpeak && _micAvailable && _state.mode == VoiceMode.live;
    await _quietly(() => engine.setMicrophoneLive(live));
    await _quietly(() => engine.setAudiblePeers(_audible(policy, speaker)));

    _emit(_state.copyWith(
      microphoneLive: live,
      policy: policy,
      activeSpeakerSeat: speaker,
      holdsFloor: maySpeak && policy == MicPolicy.activeSpeakerOnly,
      clearSpeaker: speaker == null,
    ));
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

    final selfId = link.selfId;
    final others = _peers.where((p) => p.userId != selfId).toList();

    for (final ice in [IceConfig.stun, if (relay != null) relay!]) {
      final up = await _quietly(() => engine.connect(
                selfId: selfId,
                ice: ice,
                peers: others,
                timeout: rungTimeout,
              )) ??
          false;
      if (up) {
        _emit(_state.copyWith(mode: VoiceMode.live, rung: ice.rung));
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

  Set<String> _audible(MicPolicy policy, int? speaker) {
    switch (policy) {
      case MicPolicy.open:
        return _peers.map((p) => p.userId).toSet();
      case MicPolicy.activeSpeakerOnly:
        if (speaker == null) return const {};
        return _peers
            .where((p) => p.seat == speaker)
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
