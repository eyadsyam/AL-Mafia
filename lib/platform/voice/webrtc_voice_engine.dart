import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'voice_engine.dart';

/// The only file in the app that knows WebRTC exists.
///
/// Everything above it — [VoiceController], the voice controls, the phase flow
/// — talks to [VoiceEngine]. That is not architecture for its own sake: doc 10
/// §1.2 requires that a match complete with voice "completely broken", and the
/// only honest way to test *completely* is for the thing that breaks to be
/// swappable. The fake in `test/support/fake_voice_engine.dart` is the same
/// interface with the failures written down.
///
/// ## The mesh, and why it is small
///
/// Doc 10 §6.1: the game already enforces one speaker at a time, so during
/// structured phases exactly one peer publishes and everyone else listens. The
/// connections are still a mesh — every pair has a peer connection — but only
/// one of them carries audio at a time, which is what keeps fifteen players
/// affordable on a phone's uplink.
///
/// ## Glare
///
/// Two devices that both offer at the same moment deadlock. The tie-break is
/// the user id: the lexicographically smaller one offers, the other one waits.
/// No negotiation, no rollback, no politeness protocol — a total order over
/// two random UUIDs is enough, and it costs nothing to be right about.
class WebRtcVoiceEngine implements VoiceEngine {
  final _events = StreamController<VoiceEngineEvent>.broadcast();

  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, MediaStream> _inbound = {};
  final Set<String> _live = {};

  /// Peers this session has already spent its one automatic ICE restart on.
  final Set<String> _restarted = {};

  MediaStream? _local;
  String _selfId = '';

  @override
  Stream<VoiceEngineEvent> get events => _events.stream;

  @override
  Future<bool> acquireMicrophone() async {
    if (_local != null) return _local!.getAudioTracks().isNotEmpty;
    try {
      _local = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      // Nothing publishes on acquisition. The track exists muted, and only
      // [setMicrophoneLive] — driven by the phase and the server's floor —
      // ever turns it on.
      for (final track in _local!.getAudioTracks()) {
        track.enabled = false;
      }
      return _local!.getAudioTracks().isNotEmpty;
    } catch (_) {
      // V1 and V2 are the same case here: permission refused and no hardware
      // both arrive as an exception, and both mean receive-only.
      return false;
    }
  }

  @override
  Future<bool> connect({
    required String selfId,
    required IceConfig ice,
    required List<VoicePeer> peers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _selfId = selfId;
    await _closeConnections();
    if (peers.isEmpty) return false;

    final configuration = {
      'iceServers': ice.servers,
      'sdpSemantics': 'unified-plan',
    };

    for (final peer in peers) {
      try {
        final pc = await createPeerConnection(configuration);
        _connections[peer.userId] = pc;

        if (_local != null) {
          for (final track in _local!.getAudioTracks()) {
            await pc.addTrack(track, _local!);
          }
        }

        pc.onIceCandidate = (candidate) {
          _events.add(OutboundSignal(peer.userId, {
            'kind': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }));
        };

        pc.onTrack = (event) {
          if (event.streams.isEmpty) return;
          _inbound[peer.userId] = event.streams.first;
          // Inbound audio arrives silent. The floor decides what is heard,
          // and the floor is not known to this layer (V4).
          for (final track in event.streams.first.getAudioTracks()) {
            track.enabled = _live.contains(peer.userId);
          }
        };

        pc.onConnectionState = (state) {
          switch (state) {
            case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
              _events.add(PeerConnected(peer.userId));
              unawaited(_logCandidateType(peer.userId, pc));
            case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
              // Once, automatically, before giving up. A `failed` is usually a
              // network that moved — Wi-Fi to cellular, a NAT binding that
              // expired — and the candidates that were gathered describe an
              // address the device no longer has. Gathering again is the whole
              // fix, and it is cheap.
              //
              // Once and not repeatedly: a peer that fails a restart is a peer
              // that is genuinely unreachable, and a loop of restarts would
              // keep a dead connection alive in the UI for ever.
              if (_restarted.add(peer.userId)) {
                unawaited(_restartIce(peer.userId));
              } else {
                _events.add(PeerFailed(peer.userId));
              }
            case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
              _events.add(PeerFailed(peer.userId));
            default:
              break;
          }
        };

        if (_selfId.compareTo(peer.userId) < 0) {
          final offer = await pc.createOffer({});
          await pc.setLocalDescription(offer);
          _events.add(OutboundSignal(peer.userId, {
            'kind': 'offer',
            'sdp': offer.sdp,
            'type': offer.type,
          }));
        }
      } catch (_) {
        // One peer that will not come up is not a failed rung. The rung fails
        // when *none* of them does, which is what the wait below measures.
        _events.add(PeerFailed(peer.userId));
      }
    }

    return _waitForFirstConnection(timeout);
  }

  @override
  Future<void> acceptSignal(
    String fromUserId,
    Map<String, dynamic> payload,
  ) async {
    final pc = _connections[fromUserId];
    if (pc == null) return;

    try {
      switch (payload['kind']) {
        case 'offer':
          await pc.setRemoteDescription(
            RTCSessionDescription(payload['sdp'] as String?, 'offer'),
          );
          final answer = await pc.createAnswer({});
          await pc.setLocalDescription(answer);
          _events.add(OutboundSignal(fromUserId, {
            'kind': 'answer',
            'sdp': answer.sdp,
            'type': answer.type,
          }));
        case 'answer':
          await pc.setRemoteDescription(
            RTCSessionDescription(payload['sdp'] as String?, 'answer'),
          );
        case 'candidate':
          await pc.addCandidate(RTCIceCandidate(
            payload['candidate'] as String?,
            payload['sdpMid'] as String?,
            (payload['sdpMLineIndex'] as num?)?.toInt(),
          ));
      }
    } catch (_) {
      _events.add(PeerFailed(fromUserId));
    }
  }

  @override
  Future<void> setMicrophoneLive(bool live) async {
    final stream = _local;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = live;
    }
  }

  @override
  Future<void> setAudiblePeers(Set<String> userIds) async {
    _live
      ..clear()
      ..addAll(userIds);
    for (final entry in _inbound.entries) {
      final audible = userIds.contains(entry.key);
      for (final track in entry.value.getAudioTracks()) {
        track.enabled = audible;
      }
    }
  }

  /// Drops every connection (V6) and silences the local track — but does not
  /// release it.
  ///
  /// The microphone is acquired once per session and kept for the length of
  /// it. Stopping the track here is what made voice a one-night affair: every
  /// night tears the mesh down, and a stopped track cannot be added to the
  /// connections built when the night ends, so the second day was silent and
  /// nothing said so. Worse on the web, where re-acquiring can put the
  /// permission prompt back in front of a player mid-match.
  ///
  /// So: mute, keep, re-add. [dispose] is the one place the hardware is
  /// handed back.
  @override
  Future<void> teardown() async {
    await _closeConnections();
    final stream = _local;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = false;
    }
  }

  @override
  Future<void> dispose() async {
    await _closeConnections();
    final stream = _local;
    _local = null;
    if (stream != null) {
      for (final track in stream.getAudioTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    await _events.close();
  }

  // ---------------------------------------------------------------------------

  /// Logs which kind of candidate the connection actually settled on.
  ///
  /// `host` is the same network, `srflx` is a direct connection through NAT,
  /// and `relay` is TURN. It matters because the three failure modes are
  /// indistinguishable from the UI — a call that never connects looks like a
  /// call nobody is talking on — and because "did the relay get used" is the
  /// only way to know whether the TURN credentials are doing anything.
  ///
  /// Log-only, on purpose. Nothing in the game reads it, so it cannot become
  /// load-bearing.
  Future<void> _logCandidateType(String peerId, RTCPeerConnection pc) async {
    try {
      final stats = await pc.getStats();
      final pairs = stats.where(
        (report) =>
            report.type == 'candidate-pair' &&
            report.values['state'] == 'succeeded',
      );
      for (final pair in pairs) {
        final localId = pair.values['localCandidateId'];
        final local = stats.where((r) => r.id == localId).firstOrNull;
        final type = local?.values['candidateType'] ?? 'unknown';
        developer.log(
          'peer $peerId connected via $type',
          name: 'voice',
        );
        return;
      }
    } catch (_) {
      // A stats call that fails tells us nothing and must cost nothing.
    }
  }

  /// Re-gathers candidates for one peer and re-offers if this side offers.
  ///
  /// The glare tie-break decides who re-offers, exactly as it decided who
  /// offered first: both sides restarting at once is the same deadlock by
  /// another name. The answering side still calls `restartIce`, which arms the
  /// connection to accept the new offer when it arrives.
  Future<void> _restartIce(String peerId) async {
    final pc = _connections[peerId];
    if (pc == null) return;
    try {
      await pc.restartIce();
      if (_selfId.compareTo(peerId) >= 0) return;
      final offer = await pc.createOffer({'iceRestart': true});
      await pc.setLocalDescription(offer);
      _events.add(OutboundSignal(peerId, {
        'kind': 'offer',
        'sdp': offer.sdp,
        'type': offer.type,
      }));
    } catch (_) {
      _events.add(PeerFailed(peerId));
    }
  }

  Future<void> _closeConnections() async {
    for (final pc in _connections.values) {
      try {
        await pc.close();
      } catch (_) {
        // A connection that will not close is already gone.
      }
    }
    _connections.clear();
    _inbound.clear();
    _restarted.clear();
  }

  /// True as soon as one peer reports connected, false when [timeout] passes
  /// with none.
  ///
  /// One is the threshold rather than all, because "all" would mean a single
  /// player behind a symmetric NAT drags the whole room down to TURN, and then
  /// to text. Doc 10 §6.2's ladder is per-player for the same reason.
  Future<bool> _waitForFirstConnection(Duration timeout) {
    final done = Completer<bool>();
    late StreamSubscription<VoiceEngineEvent> sub;

    void finish(bool value) {
      if (done.isCompleted) return;
      sub.cancel();
      done.complete(value);
    }

    sub = _events.stream.listen((event) {
      if (event is PeerConnected) finish(true);
    });
    Timer(timeout, () => finish(false));

    return done.future;
  }
}
