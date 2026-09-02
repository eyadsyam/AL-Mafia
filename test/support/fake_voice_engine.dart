import 'dart:async';

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

  FakeVoiceEngine({
    this.microphonePresent = true,
    Set<VoiceRung>? workingRungs,
  }) : workingRungs = workingRungs ?? {VoiceRung.stun};

  final _events = StreamController<VoiceEngineEvent>.broadcast();

  /// Every rung the ladder tried, in order.
  final List<VoiceRung> attempted = [];

  /// Every signal the engine was fed. Empty during the night, or V6 is broken.
  final List<String> accepted = [];

  bool microphoneAcquired = false;
  bool microphoneLive = false;
  Set<String> audiblePeers = const {};
  int teardowns = 0;
  int connections = 0;

  @override
  Stream<VoiceEngineEvent> get events => _events.stream;

  @override
  Future<bool> acquireMicrophone() async {
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
    attempted.add(ice.rung);
    if (!workingRungs.contains(ice.rung)) return false;
    connections++;
    return true;
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
  }) async =>
      throw StateError('no ice');

  @override
  Future<void> acceptSignal(String fromUserId, Map<String, dynamic> payload) async =>
      throw StateError('no peer');

  @override
  Future<void> setMicrophoneLive(bool live) async => throw StateError('no track');

  @override
  Future<void> setAudiblePeers(Set<String> userIds) async =>
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

  int claims = 0;
  int releases = 0;

  @override
  Stream<VoiceSignal> get incoming => _incoming.stream;

  @override
  Future<void> send(String toUserId, Map<String, dynamic> payload) async {
    sent.add(toUserId);
  }

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
  void deliver(String from) =>
      _incoming.add(VoiceSignal(fromUserId: from, payload: const {'kind': 'offer'}));

  @override
  Future<void> dispose() async {
    await _incoming.close();
  }
}
