import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'voice_diagnostics.dart';
import 'voice_engine.dart';
import 'web_playout.dart';
import '../../ui/theme/design_tokens.dart';

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
///
/// ## The four things that made it silent
///
/// This file compiled, its tests passed, and it produced no audible audio on
/// real phones. Four separate faults, each sufficient on its own:
///
/// 1. **No audio session.** Nothing ever put Android into communication mode
///    or routed output anywhere, so remote audio was decoded and played into
///    the media stream at whatever the media slider happened to be.
/// 2. **ICE candidates were dropped.** [acceptSignal] handed every candidate
///    straight to `addCandidate`, which throws when no remote description is
///    set yet — and the answering side is *always* in that state for the first
///    few candidates. The throw was caught, the candidate was lost, and enough
///    of them were lost that ICE frequently had nothing to converge on. They
///    are queued now.
/// 3. **Interleaved signalling.** `acceptSignal` is a multi-step `await` chain
///    and nothing serialised it, so a candidate arriving mid-answer raced the
///    negotiation it belonged to. Every peer now has a queue of one.
/// 4. **An offer to a device that was not ready was gone for good.** In a
///    lobby, two clients climb the ladder seconds apart; the earlier one's
///    offer reached a peer with no connection yet, was dropped, and was never
///    repeated. A connection is now created on demand for any *authorised*
///    peer whose offer arrives, and a roster change no longer tears down the
///    connections that were already working.
class WebRtcVoiceEngine implements VoiceEngine, VoicePlayout {
  final _events = StreamController<VoiceEngineEvent>.broadcast();

  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, MediaStream> _playoutStreams = {};

  /// Every remote audio track this device has been handed, per peer.
  ///
  /// Kept separately from the stream it arrived in, because it does not always
  /// arrive in one. `onTrack` populates `event.streams` when the sender used
  /// `addTrack(track, stream)` — which is what the other end of this mesh does
  /// — but the specification does not require it, and a bare track is a legal
  /// delivery.
  ///
  /// [setAudiblePeers] used to walk the streams alone. A track that arrived
  /// without one was enabled once, at arrival, against whatever the policy
  /// happened to be, and was never revisited: a peer admitted during an open
  /// day stayed audible into the night, and a peer muted at arrival stayed
  /// silent for the rest of the match. V4 is a rule about tracks, so it is
  /// applied to tracks.
  final Map<String, List<MediaStreamTrack>> _remoteTracks = {};

  /// The thing that actually makes a remote track audible in a browser, one
  /// per peer.
  ///
  /// On Android and iOS the native WebRTC stack plays inbound audio itself the
  /// moment the track is live; nothing in Dart has to ask. The web has no such
  /// stack. A remote `MediaStream` that is never attached to an
  /// `HTMLMediaElement` is decoded and thrown away, which is exactly as silent
  /// as a connection that never came up and looks identical from every state
  /// this class reports.
  ///
  /// `RTCVideoRenderer` is the sanctioned way to attach one: setting
  /// `srcObject` builds a hidden `<audio autoplay>` inside a `display: none`
  /// container of its own and points it at the stream's audio tracks. The name
  /// is about video and this call is not — no view is built, `initialize()` is
  /// deliberately not called (it would append a bare `<video>` to the document
  /// body for a stream that has no video in it), and nothing renders.
  final Map<String, RTCVideoRenderer> _sinks = {};
  final Map<String, List<RTCRtpSender>> _senders = {};

  /// Who this device's audio may reach, or null for everybody. See
  /// [setSendingPeers].
  Set<String>? _sendTo;
  final Set<String> _live = {};
  final Map<String, double> _speakingLevels = {};
  double _localSpeakingLevel = 0;

  /// Remote candidates that arrived before there was a remote description to
  /// hang them on, per peer. Drained the moment there is one.
  ///
  /// This is not an optimisation. `addCandidate` before `setRemoteDescription`
  /// is an error in every WebRTC implementation, and the answering side of a
  /// negotiation receives candidates before it receives the offer roughly as
  /// often as not — the offerer starts gathering the instant its local
  /// description is set, which is before its offer has crossed the network.
  final Map<String, List<RTCIceCandidate>> _pendingCandidates = {};

  /// Peers whose remote description is set, and whose queue may therefore be
  /// drained.
  final Set<String> _remoteDescribed = {};

  /// One in-flight signal per peer. Signalling is a state machine and
  /// `acceptSignal` is re-entrant by construction — the stream that feeds it
  /// does not wait for the previous message — so without this an answer and a
  /// candidate for the same peer run their awaits inside one another.
  final Map<String, Future<void>> _serial = {};

  /// Peers this session has already spent its one automatic ICE restart on.
  final Set<String> _restarted = {};
  final Set<String> _offering = {};

  /// Who the server says is at this table. An offer from anybody else is not
  /// answered and gets no peer connection — the same rule the transport
  /// applies, restated here because this is the layer that would build the
  /// connection.
  final Set<String> _authorized = {};

  MediaStream? _local;
  String _selfId = '';
  IceConfig? _ice;
  bool _audioConfigured = false;

  /// Which media cycle the connections in this engine belong to.
  ///
  /// [connect] is a long sequence of awaits — an audio session, a peer
  /// connection per peer, local tracks, an offer, and up to [connect]'s whole
  /// timeout waiting for one of them to come up. [teardown] can land in the
  /// middle of any of them, and it does, on every single night: the phase
  /// closes the mesh while the previous climb is still building it.
  ///
  /// Nothing stopped the climb. It closed its connections, and then the loop
  /// it was already inside carried on creating the rest — so a night could end
  /// with peer connections that the teardown had no way to know about, built
  /// after it ran. That is a V6 hole, and a mesh is exactly the thing doc 05
  /// says must not exist during a private phase.
  ///
  /// So every cycle takes a number, captured before the first await and
  /// re-checked after each one. A climb that finds the number has moved stops
  /// where it is and cleans up only what it made — the current cycle owns the
  /// engine now, and closing its connections would be the same bug in the
  /// other direction.
  int _generation = 0;

  final VoiceDiagnostics _diagnostics = VoiceDiagnostics();

  @override
  VoiceDiagnostics get diagnostics => _diagnostics;

  @override
  Stream<VoiceEngineEvent> get events => _events.stream;

  @override
  Map<String, double> get speakingLevels => Map.unmodifiable(_speakingLevels);

  @override
  double get localSpeakingLevel => _localSpeakingLevel;

  // ── local media ────────────────────────────────────────────────────────────

  @override
  Future<bool> acquireMicrophone() async {
    // Before the first `RTCPeerConnection`, and before `getUserMedia`, because
    // `setAndroidAudioConfiguration` is documented as unable to change a
    // session already under way.
    await _configureAudioSession();

    _diagnostics.micRequested = true;
    if (_local != null) {
      final ok = _local!.getAudioTracks().isNotEmpty;
      _describeLocal();
      return ok;
    }
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
      // A microphone that arrives after the mesh was built is the ordinary case
      // when permission is granted from a dialog: the connections exist and
      // have no sender on them. Attach now rather than waiting for the next
      // teardown, which might be a whole phase away.
      await _attachLocalTracks();
      _diagnostics.micGranted = _local!.getAudioTracks().isNotEmpty;
      _describeLocal();
      return _diagnostics.micGranted;
    } catch (_) {
      // V1 and V2 are the same case here: permission refused and no hardware
      // both arrive as an exception, and both mean receive-only.
      _diagnostics.micGranted = false;
      _describeLocal();
      return false;
    }
  }

  /// Puts the platform into a voice call.
  ///
  /// On Android a WebRTC session in the default `normal` audio mode plays the
  /// remote track through the media stream: the media volume slider controls
  /// it, the proximity sensor does not, and on a phone with media muted it is
  /// simply inaudible. `inCommunication` plus the loudspeaker is what every
  /// other call app on the phone does, and it is what this game wants — the
  /// device is on a table with a room around it, so the earpiece is never the
  /// right output.
  ///
  /// Failure is recorded and ignored. This is the platform saying it will route
  /// audio its own way, which is a worse call and not a broken one.
  Future<void> _configureAudioSession() async {
    if (_audioConfigured) return;
    _audioConfigured = true;
    if (kIsWeb) {
      // The browser owns routing entirely, and the remote track is played by
      // the platform view. There is nothing to set and nothing that can fail.
      _diagnostics.audioSessionConfigured = true;
      return;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await Helper.setAppleAudioConfiguration(
          AppleAudioConfiguration(
            appleAudioCategory: AppleAudioCategory.playAndRecord,
            appleAudioCategoryOptions: {
              AppleAudioCategoryOption.defaultToSpeaker,
              AppleAudioCategoryOption.allowBluetooth,
            },
            appleAudioMode: AppleAudioMode.voiceChat,
          ),
        );
        await Helper.ensureAudioSession();
      } else {
        _diagnostics.audioSessionConfigured = true;
        return;
      }
      _diagnostics.audioSessionConfigured = true;
      await Helper.setSpeakerphoneOn(true);
      _diagnostics.speakerphoneOn = true;
    } catch (_) {
      // The category, not the message: a platform exception from an audio
      // stack routinely quotes device identifiers.
      _diagnostics.audioSessionFailure = 'audio-session';
      developer.log('audio session not configured', name: 'voice', level: 900);
    }
  }

  void _describeLocal() {
    final tracks = _local?.getAudioTracks() ?? const <MediaStreamTrack>[];
    _diagnostics.localAudioTracks = tracks.length;
    _diagnostics.localTrackEnabled = tracks.isNotEmpty && tracks.first.enabled;
    _diagnostics.localTrackMuted = tracks.isEmpty ? null : tracks.first.muted;
  }

  /// Adds this device's audio to every connection that has none.
  ///
  /// Idempotent, and checked per connection rather than per session: a peer
  /// added after the microphone arrived already has its sender, and adding a
  /// second one would publish the same audio twice.
  Future<void> _attachLocalTracks() async {
    final stream = _local;
    if (stream == null) return;
    for (final entry in _connections.entries) {
      if ((_senders[entry.key] ?? const []).isNotEmpty) continue;
      await _addLocalTracks(entry.key, entry.value);
    }
  }

  Future<void> _addLocalTracks(String peerId, RTCPeerConnection pc) async {
    final stream = _local;
    if (stream == null) return;
    final added = <RTCRtpSender>[];
    for (final track in stream.getAudioTracks()) {
      try {
        added.add(await pc.addTrack(track, stream));
      } catch (_) {
        _diagnostics.peer(peerId).lastFailure = 'add-track';
      }
    }
    if (added.isEmpty) return;
    // A peer this device may not reach gets a sender with nothing on it, so
    // a later [setSendingPeers] can put the track back without renegotiating.
    if (!_maySendTo(peerId)) {
      for (final sender in added) {
        await _quietReplace(sender, null);
      }
    }
    _senders.putIfAbsent(peerId, () => []).addAll(added);
    _diagnostics.peer(peerId).audioSenders = _senders[peerId]!.length;
  }

  // ── the mesh ───────────────────────────────────────────────────────────────

  @override
  Future<bool> connect({
    required String selfId,
    required IceConfig ice,
    required List<VoicePeer> peers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // Claimed before the first await, so a second climb entering here also
    // retires the first one rather than racing it.
    final generation = ++_generation;
    await _configureAudioSession();
    if (generation != _generation) return false;

    _selfId = selfId;
    final wanted = {for (final p in peers) p.userId}..remove(selfId);

    // A different ladder rung means different candidates, so nothing survives
    // it. The same rung with a changed roster is the common case — somebody
    // joined the lobby — and rebuilding a working connection for that is what
    // made a mid-lobby join silence the room: both sides tore down, both
    // re-offered, and the offers crossed connections that no longer existed.
    final rungChanged = !identical(_ice, ice) && _ice?.rung != ice.rung;
    if (rungChanged) await _closeConnections();
    if (generation != _generation) return false;
    _ice = ice;
    _diagnostics.describeIce(ice.servers);

    _authorized
      ..clear()
      ..addAll(wanted);

    // Peers who left. Their connections are closed and forgotten; everyone
    // else's is left exactly as it is.
    for (final gone in _connections.keys.toList()) {
      if (!wanted.contains(gone)) await _dropPeer(gone);
      if (generation != _generation) return false;
    }

    if (wanted.isEmpty) return false;

    for (final peerId in wanted) {
      if (generation != _generation) return false;
      if (_connections.containsKey(peerId)) continue;
      await _createPeer(
        peerId,
        offer: _selfId.compareTo(peerId) < 0,
        generation: generation,
      );
    }
    if (generation != _generation) return false;
    // A late microphone grant used to miss the only offer. Tell authorised
    // peers this engine is ready; the designated caller can resend its offer.
    for (final peerId in wanted) {
      _events.add(OutboundSignal(peerId, const {'kind': 'ready'}));
    }

    // A connection that is already up is an answer, not a reason to wait out
    // the timeout: this runs again on every roster change, and a lobby that
    // fills one player at a time would otherwise spend eight seconds inside
    // `apply` for each of them.
    for (final pc in _connections.values) {
      if (pc.connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        return true;
      }
    }

    final up = await _waitForFirstConnection(timeout);
    // Eight seconds is long enough for a whole night to have started and
    // ended. Whatever came up during one belongs to a mesh that no longer
    // exists, and reporting it live would put the call back on air.
    if (generation != _generation) return false;
    return up;
  }

  /// Builds one leg of the mesh.
  ///
  /// [offer] is the glare tie-break's answer for this pair, except when an
  /// offer has already arrived from a peer that had not been dialled yet — see
  /// [_peerFor], which creates the connection to *answer* with.
  Future<RTCPeerConnection?> _createPeer(
    String peerId, {
    required bool offer,
    required int generation,
  }) async {
    final ice = _ice;
    if (ice == null) return null;
    if (generation != _generation) return null;
    final trace = _diagnostics.peer(peerId)..offering = offer;

    try {
      final pc = await createPeerConnection({
        'iceServers': ice.servers,
        'sdpSemantics': 'unified-plan',
      });
      // Built for a cycle that ended while the platform was building it. It is
      // closed here and never registered, so nothing above ever sees a
      // connection the night tore down.
      if (generation != _generation) {
        await _close(pc);
        return null;
      }
      _connections[peerId] = pc;
      trace.connectionCreated = true;

      await _addLocalTracks(peerId, pc);
      if (generation != _generation) {
        await _discard(peerId, pc);
        return null;
      }

      pc.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        trace.candidatesSent++;
        _events.add(
          OutboundSignal(peerId, {
            'kind': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }),
        );
      };

      pc.onTrack = (event) {
        trace.trackReceived = true;
        // `streams` is what unified-plan populates when the sender used
        // `addTrack(track, stream)`, which is what the other end of this mesh
        // does. The bare track is the fallback for an implementation that does
        // not group them, so a stream that never arrives is not silence.
        final stream = event.streams.isNotEmpty ? event.streams.first : null;
        final arriving =
            stream?.getAudioTracks() ??
            (event.track.kind == 'audio'
                ? [event.track]
                : const <MediaStreamTrack>[]);
        if (arriving.isEmpty) return;
        // Remembered by identity, because renegotiation delivers the same
        // track again and a list that grew on every offer would apply the
        // policy to the same object a dozen times.
        final tracks = _remoteTracks.putIfAbsent(
          peerId,
          () => <MediaStreamTrack>[],
        );
        for (final track in arriving) {
          if (!tracks.any((known) => known.id == track.id)) tracks.add(track);
        }
        // Inbound audio is admitted or not by the floor, and the floor is not
        // known to this layer (V4). What *is* known is the last answer the
        // controller gave, which is why `_live` is consulted rather than
        // defaulted: a track that arrives during an open discussion must be
        // audible immediately, not on the next snapshot.
        final audible = _live.contains(peerId);
        for (final track in tracks) {
          track.enabled = audible;
        }
        if (stream != null) {
          _attachPlayout(peerId, stream);
        } else {
          unawaited(_attachStreamlessPlayout(peerId, pc, tracks));
        }
        trace
          ..remoteAudioTracks = tracks.length
          ..remoteTrackEnabled = tracks.first.enabled
          ..remoteTrackMuted = tracks.first.muted
          ..audible = audible;
        unawaited(_describeDirection(peerId, pc));
      };

      pc.onSignalingState = (state) => trace.signalingState = state.name;
      pc.onIceGatheringState = (state) => trace.iceGatheringState = state.name;
      pc.onIceConnectionState = (state) =>
          trace.iceConnectionState = state.name;

      pc.onConnectionState = (state) {
        trace.connectionState = state.name;
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _events.add(PeerConnected(peerId));
            unawaited(_logCandidateType(peerId, pc));
            unawaited(_describeDirection(peerId, pc));
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
            // Once, automatically, before giving up. A `failed` is usually a
            // network that moved — Wi-Fi to cellular, a NAT binding that
            // expired — and the candidates that were gathered describe an
            // address the device no longer has. Gathering again is the whole
            // fix, and it is cheap.
            //
            // Once and not repeatedly: a peer that fails a restart is a peer
            // that is genuinely unreachable, and a loop of restarts would keep
            // a dead connection alive in the UI for ever.
            if (_restarted.add(peerId)) {
              unawaited(_restartIce(peerId));
            } else {
              _events.add(PeerFailed(peerId));
            }
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _events.add(PeerFailed(peerId));
          default:
            break;
        }
      };

      if (offer) await _offer(peerId, pc);
      if (generation != _generation) {
        await _discard(peerId, pc);
        return null;
      }
      return pc;
    } catch (_) {
      // One peer that will not come up is not a failed rung. The rung fails
      // when *none* of them does, which is what the wait below measures.
      trace.lastFailure = 'create-connection';
      _events.add(PeerFailed(peerId));
      return null;
    }
  }

  Future<void> _offer(
    String peerId,
    RTCPeerConnection pc, {
    bool iceRestart = false,
  }) async {
    if (!_offering.add(peerId)) return;
    final generation = _generation;
    final trace = _diagnostics.peer(peerId);
    try {
      final offer = await pc.createOffer(
        iceRestart ? {'iceRestart': true} : {},
      );
      if (!_current(peerId, pc, generation)) return;
      trace.offerCreated = true;
      await pc.setLocalDescription(offer);
      // The last gate before the wire. An offer for a connection this device
      // has already thrown away asks the peer to renegotiate against nothing,
      // and their answer comes back to a connection that cannot use it.
      if (!_current(peerId, pc, generation)) return;
      _events.add(
        OutboundSignal(peerId, {
          'kind': 'offer',
          'sdp': offer.sdp,
          'type': offer.type,
        }),
      );
      trace.offerSent = true;
    } catch (_) {
      trace.lastFailure = 'create-offer';
      _events.add(PeerFailed(peerId));
    } finally {
      _offering.remove(peerId);
    }
  }

  // ── inbound signalling ─────────────────────────────────────────────────────

  @override
  Future<void> acceptSignal(String fromUserId, Map<String, dynamic> payload) {
    // One at a time, per peer. Ordering across peers does not matter — they are
    // independent negotiations — and serialising all of them would let one
    // slow `setRemoteDescription` hold up the whole mesh.
    final previous = _serial[fromUserId] ?? Future<void>.value();
    final next = previous
        .then((_) => _handleSignal(fromUserId, payload))
        .catchError((_) {});
    _serial[fromUserId] = next;
    return next;
  }

  Future<void> _handleSignal(
    String fromUserId,
    Map<String, dynamic> payload,
  ) async {
    // Read before the first await. Signalling is fed by a stream that does not
    // wait for this method, and the night runs on its own clock: every branch
    // below can wake up in a cycle that is no longer the one it started in.
    final generation = _generation;

    final kind = payload['kind'];
    if (kind == 'ready') {
      if (!_authorized.contains(fromUserId) ||
          _selfId.compareTo(fromUserId) >= 0)
        return;
      final connection = _connections[fromUserId];
      if (connection == null || _offering.contains(fromUserId)) return;
      if (connection.connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected)
        return;
      final offer = await connection.getLocalDescription();
      if (!_current(fromUserId, connection, generation)) return;
      if (offer?.type == 'offer') {
        _events.add(
          OutboundSignal(fromUserId, {
            'kind': 'offer',
            'sdp': offer!.sdp,
            'type': 'offer',
          }),
        );
      } else {
        await _offer(fromUserId, connection);
      }
      return;
    }

    // A candidate can arrive for a peer that has not been dialled, but it must
    // not *create* one: only an offer does that, because only an offer carries
    // the negotiation a connection would be for.
    //
    // Resolved before the trace is touched, so a stranger's signal leaves no
    // mark at all — an unauthorised peer that could add a row to the
    // diagnostics would be both an unbounded map and a way to learn that this
    // device is in a match.
    final pc = await _peerFor(fromUserId, creating: kind == 'offer');
    if (pc == null) return;
    final trace = _diagnostics.peer(fromUserId);

    try {
      switch (kind) {
        case 'offer':
          trace.offerReceived = true;
          await pc.setRemoteDescription(
            RTCSessionDescription(payload['sdp'] as String?, 'offer'),
          );
          if (!_current(fromUserId, pc, generation)) return;
          trace.remoteOfferSet = true;
          _remoteDescribed.add(fromUserId);
          final answer = await pc.createAnswer({});
          if (!_current(fromUserId, pc, generation)) return;
          trace.answerCreated = true;
          await pc.setLocalDescription(answer);
          // A stale answer is the worst of the three to let out. The peer is
          // not waiting for permission to apply it — an answer is the end of a
          // negotiation — so it lands on whatever offer they have open, which
          // by now is the one belonging to the connection that replaced this.
          if (!_current(fromUserId, pc, generation)) return;
          _events.add(
            OutboundSignal(fromUserId, {
              'kind': 'answer',
              'sdp': answer.sdp,
              'type': answer.type,
            }),
          );
          trace.answerSent = true;
          await _drainCandidates(fromUserId, pc);
          await _describeDirection(fromUserId, pc);

        case 'answer':
          trace.answerReceived = true;
          // An answer that arrives when nothing was offered is a straggler from
          // a negotiation that has already been replaced. Applying it would put
          // a settled connection into an illegal state; ignoring it costs
          // nothing, because the negotiation it belonged to is gone.
          if (pc.signalingState !=
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
            return;
          }
          await pc.setRemoteDescription(
            RTCSessionDescription(payload['sdp'] as String?, 'answer'),
          );
          if (!_current(fromUserId, pc, generation)) return;
          trace.remoteAnswerSet = true;
          _remoteDescribed.add(fromUserId);
          await _drainCandidates(fromUserId, pc);
          await _describeDirection(fromUserId, pc);

        case 'candidate':
          trace.candidatesReceived++;
          final candidate = RTCIceCandidate(
            payload['candidate'] as String?,
            payload['sdpMid'] as String?,
            (payload['sdpMLineIndex'] as num?)?.toInt(),
          );
          if (!_remoteDescribed.contains(fromUserId)) {
            _pendingCandidates.putIfAbsent(fromUserId, () => []).add(candidate);
            trace.candidatesQueued = _pendingCandidates[fromUserId]!.length;
            return;
          }
          await pc.addCandidate(candidate);
          trace.candidatesApplied++;
      }
    } catch (_) {
      trace.lastFailure = switch (kind) {
        'offer' => 'set-remote-offer',
        'answer' => 'set-remote-answer',
        'candidate' => 'add-candidate',
        _ => 'unknown-signal',
      };
      if (kind == 'candidate') {
        trace.candidatesRejected++;
        // A single unusable candidate is ordinary — an address the device
        // cannot reach — and is not a reason to declare the peer dead.
        return;
      }
      _events.add(PeerFailed(fromUserId));
    }
  }

  /// The connection for [peerId], built on demand when an offer arrives for a
  /// peer this device has not dialled yet.
  ///
  /// This is the fix for the lobby deadlock. Two clients climb the ladder
  /// seconds apart; the earlier one offers into a device whose engine has no
  /// connections at all, the offer is dropped, and — because an offer is made
  /// exactly once per `connect` — the pair is silent for the rest of the match.
  ///
  /// [_authorized] is what keeps this from being a hole: it is the roster the
  /// server gave, and a stranger's offer still builds nothing. That is the
  /// same rule the transport's envelope applies one layer out, stated twice
  /// because this is the layer that would otherwise create the connection.
  Future<RTCPeerConnection?> _peerFor(
    String peerId, {
    required bool creating,
  }) async {
    if (!_authorized.contains(peerId)) return null;
    final existing = _connections[peerId];
    if (existing != null) return existing;
    if (!creating) return null;
    if (!_authorized.contains(peerId)) return null;
    // Created to answer with, never to offer on: the peer that reached us is
    // the offerer by definition, and offering back would be the glare this
    // engine's tie-break exists to avoid.
    return _createPeer(peerId, offer: false, generation: _generation);
  }

  Future<void> _drainCandidates(String peerId, RTCPeerConnection pc) async {
    final queued = _pendingCandidates.remove(peerId);
    if (queued == null) return;
    final trace = _diagnostics.peer(peerId);
    for (final candidate in queued) {
      try {
        await pc.addCandidate(candidate);
        trace.candidatesApplied++;
      } catch (_) {
        trace.candidatesRejected++;
      }
    }
    trace.candidatesQueued = 0;
  }

  // ── what is heard, and what is sent ────────────────────────────────────────

  @override
  Future<void> setMicrophoneLive(bool live) async {
    final stream = _local;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = live;
    }
    _describeLocal();
  }

  @override
  Future<void> setAudiblePeers(Set<String> userIds) async {
    _live
      ..clear()
      ..addAll(userIds);
    _speakingLevels.removeWhere((peerId, _) => !userIds.contains(peerId));
    for (final entry in _remoteTracks.entries) {
      final audible = userIds.contains(entry.key);
      _sinks[entry.key]?.muted = !audible;
      final tracks = entry.value;
      for (final track in tracks) {
        track.enabled = audible;
      }
      final sink = _sinks[entry.key];
      if (audible && sink?.textureId != null) {
        unawaited(resumeWebPlayout(sink!.textureId!));
      }
      final trace = _diagnostics.peer(entry.key)..audible = audible;
      if (tracks.isNotEmpty) trace.remoteTrackEnabled = tracks.first.enabled;
    }
    // A peer whose track has not arrived yet still gets the verdict recorded,
    // so a trace read during the negotiation says what *will* happen.
    for (final id in _diagnostics.peers.keys) {
      if (!_remoteTracks.containsKey(id)) {
        _diagnostics.peer(id).audible = userIds.contains(id);
      }
    }
  }

  @override
  Future<void> setSendingPeers(Set<String>? userIds) async {
    _sendTo = userIds == null ? null : {...userIds};
    final track = _local?.getAudioTracks().firstOrNull;
    if (track == null) return;
    for (final entry in _senders.entries) {
      final allowed = _maySendTo(entry.key);
      for (final sender in entry.value) {
        await _quietReplace(sender, allowed ? track : null);
      }
    }
  }

  bool _maySendTo(String peerId) => _sendTo?.contains(peerId) ?? true;

  Future<void> _quietReplace(
    RTCRtpSender sender,
    MediaStreamTrack? track,
  ) async {
    try {
      await sender.replaceTrack(track);
    } catch (_) {
      // A connection closing under us. The next snapshot re-applies the rule.
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
    // First, before the awaits below: a climb that is mid-flight has to see
    // this even if it wakes up before `_closeConnections` has finished.
    _generation++;
    _authorized.clear();
    _live.clear();
    await _closeConnections();
    final stream = _local;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = false;
    }
    _describeLocal();
  }

  @override
  Future<void> dispose() async {
    _generation++;
    await _closeConnections();
    final stream = _local;
    _local = null;
    if (stream != null) {
      for (final track in stream.getAudioTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Helper.clearAndroidCommunicationDevice();
      } catch (_) {
        // The session is over either way; the platform can keep the route.
      }
    }
    await _events.close();
  }

  // ---------------------------------------------------------------------------

  /// Records the negotiated direction of the audio transceiver.
  ///
  /// `sendRecv` is what an ordinary two-way conversation settles on. `recvOnly`
  /// on both ends is a mesh where neither side attached a sender — which is
  /// exactly what a microphone acquired *after* the connections were built used
  /// to produce, and which looks from the UI like a working call.
  Future<void> _describeDirection(String peerId, RTCPeerConnection pc) async {
    try {
      final transceivers = await pc.getTransceivers();
      for (final t in transceivers) {
        if (t.receiver.track?.kind == 'video') continue;
        final direction = await t.getCurrentDirection();
        if (direction == null) continue;
        _diagnostics.peer(peerId).direction = direction.name;
        return;
      }
    } catch (_) {
      // Not knowing the direction is not a failure of the call.
    }
  }

  /// Logs which kind of candidate the connection actually settled on.
  ///
  /// `host` is the same network, `srflx` is a direct connection through NAT,
  /// and `relay` is TURN. It matters because the three failure modes are
  /// indistinguishable from the UI — a call that never connects looks like a
  /// call nobody is talking on — and because "did the relay get used" is the
  /// only way to know whether the TURN credentials are doing anything.
  ///
  /// The *type* only. A candidate string is an address, and an address is a
  /// fact about where a player is sitting.
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
        final type = '${local?.values['candidateType'] ?? 'unknown'}';
        _diagnostics.peer(peerId).candidatePairType = type;
        developer.log('peer connected via $type', name: 'voice');
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
    final generation = _generation;
    try {
      await pc.restartIce();
      // Checked before anything is cleared, and this one is not cosmetic. A
      // restart is triggered by a *failed* connection, which is exactly when a
      // roster change or the end of a night is likely to have rebuilt this
      // pair underneath it — and the two lines below would then empty the new
      // connection's candidate queue and forget that it has a remote
      // description at all. It would sit there queueing candidates it was
      // never going to apply, permanently, reporting nothing.
      if (!_current(peerId, pc, generation)) return;
      // The queue is emptied with the description it belonged to: the peer is
      // about to describe a different set of addresses.
      _remoteDescribed.remove(peerId);
      _pendingCandidates.remove(peerId);
      if (_selfId.compareTo(peerId) >= 0) return;
      await _offer(peerId, pc, iceRestart: true);
    } catch (_) {
      _diagnostics.peer(peerId).lastFailure = 'ice-restart';
      _events.add(PeerFailed(peerId));
    }
  }

  /// Gives the browser something to play the peer's audio out of.
  ///
  /// A no-op everywhere else, where playout is the platform's job and already
  /// done by the time this runs — which is why the trace records success on
  /// native rather than leaving a field that reads FAIL on a working phone.
  void _attachPlayout(String peerId, MediaStream stream) {
    final trace = _diagnostics.peer(peerId);
    if (!kIsWeb) {
      trace.playoutAttached = true;
      return;
    }
    try {
      final sink = _sinks.putIfAbsent(peerId, RTCVideoRenderer.new);
      sink.srcObject = stream;
      sink.muted = !_live.contains(peerId);
      unawaited(_startWebPlayout(peerId, sink));
    } catch (_) {
      // Autoplay refused, or a browser without the element. Either way the
      // call is up and this end cannot hear it, which is worth knowing.
      trace
        ..playoutAttached = false
        ..lastFailure = 'web-playout';
    }
  }

  /// Gives a newly-bound browser element a bounded second chance to start.
  ///
  /// Some browsers reject the first `play()` while the MediaStream is still
  /// being attached even when autoplay is otherwise permitted. A later room
  /// settings click used to be the first retry, making voice look as though it
  /// depended on toggling the room off and on. Autoplay policy is still
  /// respected: a genuine policy rejection remains registered with the
  /// gesture bridge and is never bypassed.
  Future<void> _startWebPlayout(String peerId, RTCVideoRenderer sink) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (!identical(_sinks[peerId], sink)) return;
      final textureId = sink.textureId;
      if (textureId != null && await resumeWebPlayout(textureId)) {
        _diagnostics.peer(peerId).playoutAttached = true;
        return;
      }
      if (attempt < 2) {
        await Future<void>.delayed(MafiaTiming.webPlayoutRetry);
      }
    }
    if (identical(_sinks[peerId], sink)) {
      _diagnostics.peer(peerId)
        ..playoutAttached = false
        ..lastFailure = 'web-playout';
    }
  }

  /// A remote track that arrived on its own, with no stream around it.
  ///
  /// Native decodes and plays it regardless — playout there is the platform's
  /// and never this file's. A browser cannot: `srcObject` takes a stream, so
  /// there is nothing to attach and this peer will be inaudible on the web
  /// however well the connection is doing. That is written down rather than
  /// guessed at, because a trace that reads PASS on a silent call is worse
  /// than no trace.
  Future<void> _attachStreamlessPlayout(
    String peerId,
    RTCPeerConnection pc,
    List<MediaStreamTrack> tracks,
  ) async {
    final trace = _diagnostics.peer(peerId);
    if (!kIsWeb) {
      trace.playoutAttached = true;
      return;
    }
    try {
      final stream = await createLocalMediaStream('voice-output');
      if (!identical(_connections[peerId], pc)) {
        await stream.dispose();
        return;
      }
      for (final track in tracks) {
        await stream.addTrack(track);
      }
      if (!identical(_connections[peerId], pc)) {
        await stream.dispose();
        return;
      }
      final old = _playoutStreams[peerId];
      _playoutStreams[peerId] = stream;
      _attachPlayout(peerId, stream);
      await old?.dispose();
    } catch (_) {
      trace
        ..playoutAttached = false
        ..lastFailure = 'no-remote-stream';
    }
  }

  @override
  Future<bool> resumePlayout() async {
    final results = await Future.wait(
      _sinks.entries.map((entry) async {
        final playing = await resumeWebPlayout(entry.value.textureId!);
        _diagnostics.peer(entry.key).playoutAttached = playing;
        return playing;
      }),
    );
    return results.every((playing) => playing);
  }

  /// Counters and local audio levels only. SDP, addresses, credentials and
  /// device IDs stay private.
  @override
  Future<void> sampleMediaStats() async {
    _localSpeakingLevel = 0;
    for (final entry in _connections.entries.toList()) {
      try {
        final reports = await entry.value.getStats();
        if (!identical(_connections[entry.key], entry.value)) continue;
        final trace = _diagnostics.peer(entry.key);
        var incomingLevel = 0.0;
        for (final report in reports) {
          final values = report.values;
          if (values['kind'] != 'audio' && values['mediaType'] != 'audio')
            continue;
          if (report.type == 'inbound-rtp') {
            trace.receivedPackets =
                (values['packetsReceived'] as num?)?.toInt() ?? 0;
            incomingLevel = math.max(
              incomingLevel,
              _normaliseAudioLevel(values['audioLevel']),
            );
          }
          if (report.type == 'outbound-rtp') {
            trace.sentPackets = (values['packetsSent'] as num?)?.toInt() ?? 0;
            _localSpeakingLevel = math.max(
              _localSpeakingLevel,
              _normaliseAudioLevel(values['audioLevel']),
            );
          }
        }
        _speakingLevels[entry.key] =
            _live.contains(entry.key) &&
                (_remoteTracks[entry.key]?.any((track) => track.enabled) ??
                    false)
            ? incomingLevel
            : 0;
      } catch (_) {
        /* A peer can leave while a sample is in flight. */
      }
    }
  }

  /// Browsers report this as 0..1; a few native implementations expose the
  /// same value on a 16-bit scale. Both become the same safe UI range here.
  double _normaliseAudioLevel(Object? raw) {
    if (raw is! num) return 0;
    final value = raw.toDouble();
    if (!value.isFinite || value <= 0) return 0;
    return (value > 1 ? value / 32767 : value).clamp(0.0, 1.0).toDouble();
  }

  /// Whether [pc] is still the connection this engine is negotiating with
  /// [peerId], in the cycle [generation] belongs to.
  ///
  /// Both halves are needed and neither implies the other. The generation
  /// catches a night that closed the whole mesh; the identity check catches
  /// the narrower case where this pair alone was rebuilt — a roster change, an
  /// ICE restart, an offer that arrived for a peer already being dialled.
  ///
  /// Every await between reading a description and putting one on the wire is
  /// a window for one of those. An answer computed against a connection that
  /// has since been replaced is not merely useless: the peer applies it to
  /// their *current* negotiation, which is the one that was going to work.
  bool _current(String peerId, RTCPeerConnection pc, int generation) =>
      generation == _generation && identical(_connections[peerId], pc);

  /// Closes a connection built for a cycle that has since ended, without
  /// touching whatever the current cycle has put in its place.
  ///
  /// The identity check is the whole point. A night tears the mesh down and
  /// the day rebuilds it, so by the time a stale `_createPeer` gets here the
  /// map may already hold a *live* connection to the same peer — and dropping
  /// that one would silence a player for the rest of the match on the strength
  /// of an await that finished late.
  Future<void> _discard(String peerId, RTCPeerConnection pc) async {
    if (identical(_connections[peerId], pc)) {
      await _dropPeer(peerId);
      return;
    }
    await _close(pc);
  }

  Future<void> _close(RTCPeerConnection pc) async {
    try {
      await pc.close();
    } catch (_) {
      // A connection that will not close is already gone.
    }
  }

  Future<void> _dropPeer(String peerId) async {
    final pc = _connections.remove(peerId);
    if (pc != null) await _close(pc);
    _remoteTracks.remove(peerId);
    _speakingLevels.remove(peerId);
    // Released with the connection, so a peer dropped and re-added inside one
    // negotiation is not refused an offer by the previous one's bookkeeping.
    _offering.remove(peerId);
    final sink = _sinks.remove(peerId);
    if (sink != null) {
      try {
        if (sink.textureId != null) forgetWebPlayout(sink.textureId!);
        await sink.dispose();
      } catch (_) {
        // Removing an element that is already gone.
      }
    }
    await _playoutStreams.remove(peerId)?.dispose();
    _senders.remove(peerId);
    _pendingCandidates.remove(peerId);
    _remoteDescribed.remove(peerId);
    _restarted.remove(peerId);
    _serial.remove(peerId);
    _diagnostics.forget(peerId);
  }

  Future<void> _closeConnections() async {
    for (final peerId in _connections.keys.toList()) {
      await _dropPeer(peerId);
    }
    _connections.clear();
    // Cleared with the connections it describes. `_offer` refuses to run twice
    // for a peer, so an entry left behind by a negotiation the night
    // interrupted made the *next* one a no-op: the day rebuilt the mesh, the
    // designated caller silently declined to call, and that pair was silent
    // for the rest of the match with every state reporting healthy.
    _offering.clear();
    _remoteTracks.clear();
    _sinks.clear();
    _senders.clear();
    _pendingCandidates.clear();
    _remoteDescribed.clear();
    _restarted.clear();
    _serial.clear();
    _diagnostics.reset();
    _speakingLevels.clear();
    _localSpeakingLevel = 0;
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
