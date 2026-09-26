import 'dart:async';

import '../../transport/voice_link.dart' show VoicePeer;
import 'voice_diagnostics.dart';

/// [VoicePeer] is a fact about the room rather than about the call, so it is
/// declared with the link and re-exported here for the engines that consume it.
export '../../transport/voice_link.dart' show VoicePeer;

/// The rungs of doc 10 §6.2, in the order they are tried.
///
/// ```
/// 1. STUN only (public)   → ~80–85% of pairs connect
/// 2. TURN (free tier)     → ~+13%
/// 3. Neither              → text mode for that player, and the match is
///                           unaffected (V3)
/// ```
enum VoiceRung { stun, turn, text }

/// The ICE servers for one rung.
///
/// Deliberately a plain map: it is handed to `flutter_webrtc` verbatim and to
/// the fake engine not at all, and nothing in between needs to understand it.
class IceConfig {
  final VoiceRung rung;
  final List<Map<String, dynamic>> servers;

  const IceConfig(this.rung, this.servers);

  /// Google's public STUN. No account, no credential, no cost — which is why
  /// it is the first rung rather than a fallback.
  static const IceConfig stun = IceConfig(VoiceRung.stun, [
    {
      'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
    },
  ]);

  /// A relay, if this build was given one.
  ///
  /// There is no default and no bundled provider: a TURN server costs money or
  /// an account, and inventing one here would be a promise the app cannot keep.
  /// A build without the three defines simply has a two-rung ladder, and the
  /// third rung — text — always works.
  static IceConfig? relay({
    String url = const String.fromEnvironment('TURN_URL'),
    String username = const String.fromEnvironment('TURN_USERNAME'),
    String credential = const String.fromEnvironment('TURN_CREDENTIAL'),
  }) {
    if (url.isEmpty) return null;
    return IceConfig(VoiceRung.turn, [
      {
        'urls': [url],
        'username': username,
        'credential': credential,
      },
    ]);
  }
}

/// Something the transport-independent part of the call needs to know about.
sealed class VoiceEngineEvent {
  const VoiceEngineEvent();
}

/// An SDP offer, an answer, or an ICE candidate, bound for one peer.
///
/// The engine never sends this itself. It hands it up, the controller puts it
/// on the [VoiceLink], and the link is the only thing that knows Supabase
/// exists — which is what keeps `webrtc_voice_engine.dart` the one file in the
/// app that imports `flutter_webrtc`.
class OutboundSignal extends VoiceEngineEvent {
  final String toUserId;
  final Map<String, dynamic> payload;

  const OutboundSignal(this.toUserId, this.payload);
}

/// A peer whose audio is now flowing.
class PeerConnected extends VoiceEngineEvent {
  final String userId;

  const PeerConnected(this.userId);
}

/// A peer that will not connect on this rung. The controller counts these:
/// when none of the peers came up, the rung failed and the ladder moves.
class PeerFailed extends VoiceEngineEvent {
  final String userId;

  const PeerFailed(this.userId);
}

/// The call itself: audio, and nothing about the game.
///
/// ## Why this is an interface
///
/// Doc 10 §1.2 is the whole reason: *"an online match must be 100% playable
/// with voice completely broken."* A rule like that is only believable if
/// "completely broken" is a thing the test suite can actually produce, and a
/// real `RTCPeerConnection` cannot be made to fail on demand in a unit test.
/// Behind this interface it can: [NullVoiceEngine] is voice that never works,
/// the fake in `test/support/fake_voice_engine.dart` is voice that fails
/// exactly where V1–V9 say it should, and the match must finish through all of
/// them.
///
/// ## What is not on it
///
/// A microphone button. Whether this device's microphone is live is decided by
/// the phase and the floor, never by the person holding it — doc 10 §6.1:
/// *"never trust the client to mute itself politely"*. So the only mic method
/// here is [setMicrophoneLive], and the only caller is [VoiceController]
/// applying a policy it did not choose.
abstract interface class VoicePlayout {
  Future<bool> resumePlayout();
  Future<void> sampleMediaStats();

  /// Sanitised local and remote audio levels for the speaking ring. These are
  /// local presentation facts only; they never enter the game snapshot or
  /// Metered signalling.
  Map<String, double> get speakingLevels;
  double get localSpeakingLevel;
}

abstract class VoiceEngine {
  /// Asks the platform for the microphone.
  ///
  /// False is not an error and must never be treated as one (V1, V2): the
  /// player has no microphone, or said no to it, and the answer is a
  /// receive-only call and a match that carries on.
  Future<bool> acquireMicrophone();

  /// Brings up connections to [peers] on one rung of the ladder.
  ///
  /// Returns true when at least one peer connected before [timeout]. A false
  /// is the signal to climb: it never throws, because a failed rung is the
  /// expected case for about a sixth of pairs.
  Future<bool> connect({
    required String selfId,
    required IceConfig ice,
    required List<VoicePeer> peers,
    Duration timeout,
  });

  /// Feeds in one signal that arrived for this device.
  Future<void> acceptSignal(String fromUserId, Map<String, dynamic> payload);

  /// Publishes or hard-mutes the local track.
  Future<void> setMicrophoneLive(bool live);

  /// Silences every inbound track except the ones named.
  ///
  /// This is the receiving half of V4. The sending half — the server refusing
  /// the floor — stops an honest client; this stops a modified one, because a
  /// track nobody renders is a track that was not heard. Both halves are
  /// needed and neither is sufficient: the mesh has no server in the media
  /// path to drop a stream, so the drop happens at every ear instead.
  Future<void> setAudiblePeers(Set<String> userIds);

  /// Sends this device's audio only to the peers named, or to every peer when
  /// [userIds] is null.
  ///
  /// The sending half of the witness wall (doc 12 §4.1, owner decision
  /// 2026-09-23): an eliminated player talks to the other eliminated players
  /// and to nobody alive. [setAudiblePeers] on the living devices already
  /// refuses the audio; this makes sure it is never on the wire to them, so a
  /// modified living client has nothing to un-mute.
  Future<void> setSendingPeers(Set<String>? userIds);

  /// Drops every connection and the local track (V6).
  Future<void> teardown();

  Stream<VoiceEngineEvent> get events;

  /// What the media chain actually did, for a person holding two phones.
  ///
  /// Read-only, and nothing in the game reads it at all. It exists because
  /// every failure on this interface is deliberately swallowed — a call that
  /// throws into a phase would break non-negotiable 5 — and a stack that
  /// swallows its errors has to write them down somewhere or become
  /// undiagnosable, which is precisely what happened.
  VoiceDiagnostics get diagnostics;

  Future<void> dispose();
}

/// Voice that is not there.
///
/// Not a stub for later: it is what the app uses when a build has no voice,
/// when the platform has no WebRTC, and in every test that is about the game
/// rather than about the call. Every method succeeds at doing nothing, so the
/// controller's ladder falls straight through to [VoiceRung.text] and the
/// match plays.
class NullVoiceEngine implements VoiceEngine {
  final _events = StreamController<VoiceEngineEvent>.broadcast();

  @override
  final VoiceDiagnostics diagnostics = VoiceDiagnostics();

  @override
  Future<bool> acquireMicrophone() async => false;

  @override
  Future<bool> connect({
    required String selfId,
    required IceConfig ice,
    required List<VoicePeer> peers,
    Duration timeout = const Duration(seconds: 8),
  }) async => false;

  @override
  Future<void> acceptSignal(
    String fromUserId,
    Map<String, dynamic> payload,
  ) async {}

  @override
  Future<void> setMicrophoneLive(bool live) async {}

  @override
  Future<void> setAudiblePeers(Set<String> userIds) async {}

  @override
  Future<void> setSendingPeers(Set<String>? userIds) async {}

  @override
  Future<void> teardown() async {}

  @override
  Stream<VoiceEngineEvent> get events => _events.stream;

  @override
  Future<void> dispose() async {
    await _events.close();
  }
}
