import 'dart:async';

import 'online_backend.dart';

/// The call's half of the transport: signalling, and the floor.
///
/// ## Why it is a separate interface from [GameTransport]
///
/// Because of doc 10 §1.2 — *"voice is never load-bearing"* — and because the
/// cheapest way to keep a promise like that is to make it structural. A
/// transport hands back a `VoiceLink?`, and offline it hands back null. There
/// is no method on the game interface that voice could make fail, no field on
/// a [GameSnapshot] a broken call could poison, and nothing in the phase flow
/// that has to check whether the microphone is working. If this whole file
/// were deleted, every screen would still play a match.
///
/// ## What the server decides
///
/// Everything that matters. [claimFloor] is a request, not a claim: the Edge
/// Function checks the phase against the same policy table the client reads
/// (`lib/engine/voice_policy.dart`), checks the seat, and either writes
/// `room_state.active_speaker` or refuses. The client learns the answer the
/// same way every other client does — from the room state — which is why a
/// modified client cannot grant itself the floor by lying to its own UI.
/// One other device in the call.
///
/// A seat and a user id, which is the pair nothing else in the app holds
/// together: a [GameSnapshot] has seats and no user ids (deliberately — a user
/// id on a snapshot is a fact about a person that no screen needs), and the
/// backend has user ids and no opinion about the game. The link is where the
/// two meet, because signalling needs an address and the mic policy needs a
/// seat.
class VoicePeer {
  final String userId;
  final int seat;

  const VoicePeer({required this.userId, required this.seat});
}

abstract class VoiceLink {
  /// This device's user id, which is also its address in [send].
  String get selfId;

  /// Everyone in the room, by seat and address. Read at connection time and
  /// again whenever the call is rebuilt, so a player who rejoined between two
  /// nights is in it.
  List<VoicePeer> get peers;

  /// Signals addressed to this device. RLS makes that literal: the policy on
  /// `signals` is `to_id = auth.uid()`, so a client cannot read the offers
  /// meant for somebody else even if it asks for them.
  Stream<VoiceSignal> get incoming;

  /// One SDP offer, answer, or ICE candidate.
  ///
  /// Failures are swallowed by the caller, not by this method: a signal that
  /// does not arrive costs a peer connection and nothing else.
  Future<void> send(String toUserId, Map<String, dynamic> payload);

  /// The ICE servers this match should use.
  ///
  /// The production path is Metered's welcome frame — see [MeteredVoiceLink] —
  /// and this is the floor under it: the `ice_servers` Edge Function, which
  /// answers with public STUN.
  ///
  /// Null means the server could not be asked at all; the caller falls back to
  /// public STUN and logs it. The list itself is opaque here — it is whatever
  /// the function returned, handed to the media stack verbatim — because the
  /// transport has no business understanding a TURN credential, only fetching
  /// one.
  Future<List<Map<String, dynamic>>?> iceServers();

  /// Asks the server for the microphone. False is an ordinary refusal —
  /// wrong phase, wrong seat, or somebody else already holds it.
  Future<bool> claimFloor();

  /// Gives it back. Idempotent, and safe to call when this device does not
  /// hold the floor.
  Future<void> releaseFloor();

  Future<void> dispose();
}

/// A [VoiceLink] over the ordinary backend.
///
/// No rules of its own: two Edge Function calls and two table operations. Every
/// decision this file could have made is made on the server, which is the only
/// place a decision about who may speak is worth anything.
class BackendVoiceLink implements VoiceLink {
  final OnlineBackend backend;
  final String roomId;

  /// The roster, asked for rather than held: the transport's copy changes as
  /// players join, leave and rejoin, and a list captured once would be a call
  /// to the room as it was.
  final List<VoicePeer> Function() roster;

  BackendVoiceLink({
    required this.backend,
    required this.roomId,
    required this.roster,
  });

  @override
  String get selfId => backend.userId ?? '';

  @override
  List<VoicePeer> get peers => roster();

  @override
  Stream<VoiceSignal> get incoming => backend.signals(roomId);

  @override
  Future<void> send(String toUserId, Map<String, dynamic> payload) =>
      backend.sendSignal(roomId, toUserId, payload);

  @override
  Future<List<Map<String, dynamic>>?> iceServers() async {
    Map<String, dynamic>? ticket;
    try {
      ticket = await backend.call('ice_servers', const {});
    } on BackendException {
      return null;
    } on BackendUnreachable {
      return null;
    }
    final servers = ticket['iceServers'];
    if (servers is! List || servers.isEmpty) return null;
    return [
      for (final server in servers)
        if (server is Map) Map<String, dynamic>.from(server),
    ];
  }

  @override
  Future<bool> claimFloor() async {
    try {
      final result = await backend.call('claim_floor', {'roomId': roomId});
      return result['granted'] == true;
    } on BackendException {
      // A refusal is the expected answer for most of the game: the night, the
      // ballot, and every moment somebody else is speaking. It is not worth a
      // banner and it is certainly not worth an exception reaching a screen.
      return false;
    } on BackendUnreachable {
      return false;
    }
  }

  @override
  Future<void> releaseFloor() async {
    try {
      await backend.call('release_floor', {'roomId': roomId});
    } on BackendException {
      // Nothing to do: either it was already released, or the phase moved and
      // the server released it for us.
    } on BackendUnreachable {
      // The floor has a deadline on the server precisely so that a client
      // which vanished mid-sentence does not hold it forever (V5).
    }
  }

  @override
  Future<void> dispose() async {}
}
