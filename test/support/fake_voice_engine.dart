import 'dart:async';

import 'package:mafia_master/platform/voice/voice_diagnostics.dart';
import 'package:mafia_master/platform/voice/voice_engine.dart';
import 'package:mafia_master/transport/online_backend.dart' show VoiceSignal;
import 'package:mafia_master/transport/voice_link.dart';

/// Voice that fails exactly where doc 11 §7 says it should.
///
/// Doc 10 §1.2 makes a promise — *"an online match must be 100% playable with
/// voice completely broken"* — and a promise like that is only worth what the
/// suite can make it prove. A real `RTCPeerConnection` cannot be told to refuse
/// a microphone, fail STUN, succeed on TURN, and then die mid-sentence, so the
/// V-cases are driven from here instead: three fields, and every one of them is
/// a row in that table.
class FakeVoiceEngine implements VoiceEngine {
  /// V1 and V2. False is a refused permission and a phone with no microphone,
  /// which are the same case to everything above this line.
  bool microphonePresent;

  /// The rungs that work. Empty is V3 — STUN and TURN both fail, and this
  /// player types.
  Set<VoiceRung> workingRungs;

  FakeVoiceEngine({this.microphonePresent = true, Set<VoiceRung>? workingRungs})
    : workingRungs = workingRungs ?? {VoiceRung.stun};

  final _events = StreamController<VoiceEngineEvent>.broadcast();

  @override
  final VoiceDiagnostics diagnostics = VoiceDiagnostics();

  /// Every rung the ladder tried, in order.
  final List<VoiceRung> attempted = [];

  /// The full configuration each of those rungs was handed. `attempted` says
  /// which rung; this says whether the relay the server minted actually
  /// reached the thing that builds `RTCPeerConnection`s — which for a while it
  /// did not.
  final List<IceConfig> attemptedConfigs = [];

  /// The peers of the last `connect`, so a test can see the roster the mesh
  /// was actually made to.
  List<VoicePeer> lastPeers = const [];

  /// Puts an event on the engine's stream, as the real one does when a peer
  /// connects late or a candidate needs sending.
  void emit(VoiceEngineEvent event) => _events.add(event);

  /// Every signal the engine was fed. Empty during the night, or V6 is broken.
  final List<String> accepted = [];

  bool microphoneAcquired = false;

  /// How many times the platform was asked. V1 allows exactly one per session.
  int microphoneRequests = 0;
  bool microphoneLive = false;
  Set<String> audiblePeers = const {};

  /// Null means "every peer", which is what a living device sends to.
  Set<String>? sendingPeers;
  int teardowns = 0;
  int connections = 0;

  /// How many `connect` calls were ever in flight at once.
  ///
  /// One is the only correct answer. Two overlapping climbs build two meshes
  /// to the same peers and their offers cross connections the other one has
  /// already replaced — the failure mode is a room where everybody is
  /// connected and nobody is audible.
  int peakConcurrentConnects = 0;
  int _inFlight = 0;

  /// Holds the next `connect` open until a test completes it.
  ///
  /// A climb is a long sequence of awaits and the interesting failures all
  /// happen *inside* it — a night that lands while the mesh is being built,
  /// and the day that follows before it has finished. Consumed on use, so the
  /// re-climb the day triggers is not held as well and the test can watch it
  /// finish.
  Completer<void>? holdConnect;

  @override
  Stream<VoiceEngineEvent> get events => _events.stream;

  @override
  Future<bool> acquireMicrophone() async {
    microphoneRequests++;
    microphoneAcquired = microphonePresent;
    return microphonePresent;
  }

  @override
  Future<bool> connect({
    required String selfId,
    required IceConfig ice,
    required List<VoicePeer> peers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _inFlight++;
    if (_inFlight > peakConcurrentConnects) peakConcurrentConnects = _inFlight;
    try {
      attempted.add(ice.rung);
      attemptedConfigs.add(ice);
      lastPeers = peers;
      final gate = holdConnect;
      if (gate != null) {
        holdConnect = null;
        await gate.future;
      }
      if (!workingRungs.contains(ice.rung)) return false;
      connections++;
      return true;
    } finally {
      _inFlight--;
    }
  }

  @override
  Future<void> acceptSignal(
    String fromUserId,
    Map<String, dynamic> payload,
  ) async {
    accepted.add(fromUserId);
  }

  @override
  Future<void> setMicrophoneLive(bool live) async {
    microphoneLive = live;
  }

  @override
  Future<void> setAudiblePeers(Set<String> userIds) async {
    audiblePeers = userIds;
  }

  @override
  Future<void> setSendingPeers(Set<String>? userIds) async {
    sendingPeers = userIds;
  }

  @override
  Future<void> teardown() async {
    teardowns++;
    microphoneLive = false;
    audiblePeers = const {};
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

/// A [VoiceEngine] that throws at every single call.
///
/// Not a rung failing — a media stack that is *broken*, which is the harsher
/// reading of "voice entirely disabled" and the one worth testing. Nothing
/// above may notice.
class ExplodingVoiceEngine implements VoiceEngine {
  @override
  final VoiceDiagnostics diagnostics = VoiceDiagnostics();

  final _events = StreamController<VoiceEngineEvent>.broadcast();

  @override
  Stream<VoiceEngineEvent> get events => _events.stream;

  @override
  Future<bool> acquireMicrophone() async => throw StateError('no media');

  @override
  Future<bool> connect({
    required String selfId,
    required IceConfig ice,
    required List<VoicePeer> peers,
    Duration timeout = const Duration(seconds: 8),
  }) async => throw StateError('no ice');

  @override
  Future<void> acceptSignal(
    String fromUserId,
    Map<String, dynamic> payload,
  ) async => throw StateError('no peer');

  @override
  Future<void> setMicrophoneLive(bool live) async =>
      throw StateError('no track');

  @override
  Future<void> setAudiblePeers(Set<String> userIds) async =>
      throw StateError('no track');

  @override
  Future<void> setSendingPeers(Set<String>? userIds) async =>
      throw StateError('no track');

  @override
  Future<void> teardown() async => throw StateError('nothing to tear down');

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}

/// A [VoiceLink] with no server behind it.
///
/// The floor is the server's decision, so a test that wants to see what a
/// client does when it is refused sets [grantFloor] and does not have to think
/// about phases at all — the two halves are separate on purpose, and this is
/// where that pays.
class FakeVoiceLink implements VoiceLink {
  FakeVoiceLink({this.selfId = 'u0', this.grantFloor = false});

  @override
  final String selfId;

  @override
  List<VoicePeer> peers = const [];

  bool grantFloor;

  final _incoming = StreamController<VoiceSignal>.broadcast();

  /// Every peer this client signalled, in order.
  final List<String> sent = [];

  /// Every payload, in the order it actually reached the wire — which is not
  /// the order it was created in unless something keeps it so.
  final List<Map<String, dynamic>> sentPayloads = [];

  /// Milliseconds to hold a send before it completes, per message kind. Lets a
  /// test make an offer slow and a candidate fast, which is exactly the shape
  /// that used to let a candidate overtake the offer it belonged to.
  Map<String, int> sendDelays = const {};

  int claims = 0;
  int releases = 0;

  @override
  Stream<VoiceSignal> get incoming => _incoming.stream;

  @override
  Future<void> send(String toUserId, Map<String, dynamic> payload) async {
    final delay = sendDelays['${payload['kind']}'] ?? 0;
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
    sent.add(toUserId);
    sentPayloads.add(payload);
  }

  /// What the `ice_servers` function would have answered. Null by default:
  /// every existing test predates the fetch and must keep behaving as though
  /// the app fell back to public STUN.
  List<Map<String, dynamic>>? ice;

  @override
  Future<List<Map<String, dynamic>>?> iceServers() async => ice;

  @override
  Future<bool> claimFloor() async {
    claims++;
    return grantFloor;
  }

  @override
  Future<void> releaseFloor() async {
    releases++;
  }

  /// Delivers one signal, as the `signals` table would.
  void deliver(String from) => _incoming.add(
    VoiceSignal(fromUserId: from, payload: const {'kind': 'offer'}),
  );

  @override
  Future<void> dispose() async {
    await _incoming.close();
  }
}
