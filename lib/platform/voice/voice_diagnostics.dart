/// What the media chain actually did, as a value that can be read out loud.
///
/// ## Why this exists
///
/// A call that produces no sound looks identical from the UI to a call nobody
/// is talking on, and identical again to a call whose ICE never converged. The
/// three have completely different fixes and the app had no way to tell them
/// apart — every failure in `webrtc_voice_engine.dart` was swallowed into a
/// `PeerFailed` event or a bare `catch (_)`, which is correct for the *match*
/// (non-negotiable 5: voice is never load-bearing) and useless for anybody
/// trying to work out why the room is silent.
///
/// So the swallowing stays and the facts are written down beside it. Nothing in
/// the game reads this, nothing waits on it, and no method here can throw — it
/// is a notebook, not a control path.
///
/// ## What may be written in it
///
/// Booleans, counts, and enum names. That is the whole permitted vocabulary.
///
/// No SDP, because an SDP body carries every local IP the device has. No
/// candidate strings, for the same reason. No TURN username or credential —
/// those are bearer credentials for the account's relay. No JWT. No user id
/// beyond the peer key the mesh already dials by, and no seat, role, or phase,
/// because doc 05 does not permit the app to hand out a fact about the table
/// through a side door marked "debug".
///
/// The one thing about ICE that is reported is the *type* of the candidate pair
/// that won — `host`, `srflx`, or `relay` — which says whether the relay is
/// doing anything without saying where anybody is.
library;

/// One end of one peer's media chain, in the order the chain runs.
///
/// Every field starts at its "has not happened" value, so a trace read halfway
/// through a negotiation is honest about how far it got rather than about what
/// was expected to happen.
class PeerTrace {
  final String peerId;

  /// Whether this device is the one that offers to [peerId]. The glare
  /// tie-break, recorded because half the steps below only apply to one side
  /// and a trace that lists them all as FAIL for the answering side is a trace
  /// that cries wolf.
  bool offering = false;

  bool connectionCreated = false;

  /// Audio senders attached to this connection. Zero here means this device is
  /// negotiating a connection it can never speak on, whatever the mic UI says.
  int audioSenders = 0;

  /// The transceiver's negotiated direction — `sendRecv`, `recvOnly`, and so
  /// on. Null until the negotiation has settled enough to have one.
  String? direction;

  bool offerCreated = false;
  bool offerSent = false;
  bool offerReceived = false;
  bool remoteOfferSet = false;
  bool answerCreated = false;
  bool answerSent = false;
  bool answerReceived = false;
  bool remoteAnswerSet = false;

  int candidatesSent = 0;
  int candidatesReceived = 0;
  int candidatesApplied = 0;
  int candidatesQueued = 0;
  int candidatesRejected = 0;

  String? signalingState;
  String? iceGatheringState;
  String? iceConnectionState;
  String? connectionState;

  /// Whether `onTrack` fired at all. The single most diagnostic bit in the
  /// whole structure: if this is false the fault is upstream of media, in
  /// negotiation or senders or ICE, and looking at audio routing is wasted
  /// time.
  bool trackReceived = false;
  int remoteAudioTracks = 0;
  bool remoteTrackEnabled = false;
  bool? remoteTrackMuted;

  /// Whether this end has somewhere to play the peer's audio out of. Always
  /// true on a phone, where the platform does it; on the web it means the
  /// remote stream reached an audio element instead of being decoded into
  /// nothing.
  bool playoutAttached = false;
  int receivedPackets = 0;
  int sentPackets = 0;

  /// Whether the privacy policy currently admits this peer — the receiving
  /// half of V4. False with everything above green is a silent call that is
  /// working exactly as designed, and is a completely different bug.
  bool audible = false;

  /// `host`, `srflx`, `relay`, or null while nothing has been selected.
  String? candidatePairType;

  /// A short category for the last thing that went wrong on this leg —
  /// `set-remote-offer`, `add-candidate`, `create-answer`. Never the exception
  /// text, which on a media stack routinely quotes the SDP that upset it.
  String? lastFailure;

  PeerTrace(this.peerId);
}

/// The whole call, from this device's point of view.
class VoiceDiagnostics {
  // ── local media ──────────────────────────────────────────────────────────

  bool micRequested = false;
  bool micGranted = false;
  int localAudioTracks = 0;
  bool localTrackEnabled = false;
  bool? localTrackMuted;

  /// Whether the platform's voice-call audio mode was applied. On Android a
  /// WebRTC session left in `normal` mode plays remote audio through the media
  /// stream at the media volume — which on a phone with the media slider down
  /// is indistinguishable from no audio at all.
  bool audioSessionConfigured = false;

  /// Whether output was routed to the loudspeaker. This is a party game played
  /// with a phone on a table, so the earpiece is never the right answer.
  bool speakerphoneOn = false;

  /// Why the audio session could not be configured, as a category.
  String? audioSessionFailure;

  // ── ICE configuration ────────────────────────────────────────────────────

  int iceServerCount = 0;
  bool hasStun = false;
  bool hasTurn = false;
  bool hasTurns = false;

  final Map<String, PeerTrace> peers = {};

  PeerTrace peer(String id) => peers.putIfAbsent(id, () => PeerTrace(id));

  void forget(String id) => peers.remove(id);

  void reset() => peers.clear();

  /// Records the ICE ladder actually handed to `createPeerConnection`.
  ///
  /// Counts and schemes, never the servers themselves: the `credential` field
  /// of a TURN entry is the secret the relay is bought with.
  void describeIce(List<Map<String, dynamic>> servers) {
    final urls = <String>[
      for (final server in servers)
        ...switch (server['urls']) {
          final String one => [one],
          final List<dynamic> many => many.map((u) => '$u'),
          _ => const <String>[],
        },
    ];
    iceServerCount = servers.length;
    hasStun = urls.any((u) => u.startsWith('stun:'));
    hasTurn = urls.any((u) => u.startsWith('turn:'));
    hasTurns = urls.any((u) => u.startsWith('turns:'));
  }

  /// The trace, as the lines a person reads top to bottom to find the first
  /// thing that is not PASS.
  ///
  /// The order is the order the chain runs in, deliberately: the first FAIL is
  /// the bug, and everything under it is a symptom. A step that does not apply
  /// to this side of the negotiation reads `n/a` rather than FAIL.
  String report() {
    final out = StringBuffer();
    String mark(bool ok) => ok ? 'PASS' : 'FAIL';

    out.writeln('LOCAL');
    out.writeln('  mic requested        ${mark(micRequested)}');
    out.writeln('  mic granted          ${mark(micGranted)}');
    out.writeln('  local audio tracks   $localAudioTracks');
    out.writeln('  local track enabled  $localTrackEnabled');
    out.writeln('  local track muted    ${localTrackMuted ?? 'unknown'}');
    out.writeln(
      '  audio session        ${mark(audioSessionConfigured)}'
      '${audioSessionFailure == null ? '' : ' ($audioSessionFailure)'}',
    );
    out.writeln('  speakerphone         $speakerphoneOn');
    out.writeln('ICE CONFIG');
    out.writeln('  servers              $iceServerCount');
    out.writeln('  stun / turn / turns  $hasStun / $hasTurn / $hasTurns');

    if (peers.isEmpty) out.writeln('PEERS  (none)');
    for (final p in peers.values) {
      out.writeln('PEER ${p.peerId}  (${p.offering ? 'offerer' : 'answerer'})');
      out.writeln('  connection created   ${mark(p.connectionCreated)}');
      out.writeln('  audio senders        ${p.audioSenders}');
      out.writeln('  direction            ${p.direction ?? 'unknown'}');
      if (p.offering) {
        out.writeln('  offer created        ${mark(p.offerCreated)}');
        out.writeln('  offer sent           ${mark(p.offerSent)}');
        out.writeln('  answer received      ${mark(p.answerReceived)}');
        out.writeln('  remote answer set    ${mark(p.remoteAnswerSet)}');
      } else {
        out.writeln('  offer received       ${mark(p.offerReceived)}');
        out.writeln('  remote offer set     ${mark(p.remoteOfferSet)}');
        out.writeln('  answer created       ${mark(p.answerCreated)}');
        out.writeln('  answer sent          ${mark(p.answerSent)}');
      }
      out.writeln(
        '  candidates out/in    '
        '${p.candidatesSent}/${p.candidatesReceived} '
        '(applied ${p.candidatesApplied}, queued ${p.candidatesQueued}, '
        'rejected ${p.candidatesRejected})',
      );
      out.writeln('  signaling            ${p.signalingState ?? 'unknown'}');
      out.writeln('  ice gathering        ${p.iceGatheringState ?? 'unknown'}');
      out.writeln(
        '  ice connection       ${p.iceConnectionState ?? 'unknown'}',
      );
      out.writeln('  pc state             ${p.connectionState ?? 'unknown'}');
      out.writeln('  candidate pair       ${p.candidatePairType ?? 'none'}');
      out.writeln('  remote track         ${mark(p.trackReceived)}');
      out.writeln('  remote audio tracks  ${p.remoteAudioTracks}');
      out.writeln('  remote enabled       ${p.remoteTrackEnabled}');
      out.writeln('  remote muted         ${p.remoteTrackMuted ?? 'unknown'}');
      out.writeln('  playout attached     ${mark(p.playoutAttached)}');
      out.writeln(
        '  audio packets in/out ${p.receivedPackets}/${p.sentPackets}',
      );
      out.writeln('  audible by policy    ${mark(p.audible)}');
      if (p.lastFailure != null) {
        out.writeln('  last failure         ${p.lastFailure}');
      }
    }
    return out.toString();
  }
}
