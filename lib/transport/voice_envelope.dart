import 'dart:collection';
import 'dart:math';

import 'online_backend.dart' show VoiceSignal;

/// The wrapper every signalling message wears on the Metered wire, and the
/// eight questions it has to answer before the mesh is allowed to see it.
///
/// ## Why an envelope exists at all
///
/// Metered authenticates the sender of a direct message, and that is genuinely
/// worth something: `from` is a `sub` claim out of a JWT this app's own Edge
/// Function signed. What it is *not* is a statement about which match the
/// sender was authenticated for. Direct messages in this protocol are addressed
/// by peer id and are not scoped to the token's `channels` claim — confirmed
/// against the live service, where a token minted for one match successfully
/// put a frame on another match's socket.
///
/// So "Metered says this is user X" is true and insufficient. The envelope adds
/// the part Metered cannot: *which conversation this belongs to*.
///
/// ## What is in it, and what is deliberately not
///
/// ```
/// v   protocol version        n   nonce, against replay
/// s   opaque session id       ts  milliseconds, against staleness
/// f   sender user id          t   message type (offer | answer | candidate)
/// r   recipient user id       p   the SDP or candidate itself
/// ```
///
/// No role, no seat, no name, no phase, no match seed, no room id. `s` is an
/// HMAC the server derives — see `sessionIdFor` — so even the match's identity
/// travels as something opaque that only its own members were handed.
///
/// ## Why the sender is stated twice
///
/// `f` is what the sender *claims*; the `authenticatedFrom` argument to [open]
/// is what Metered *verified*. A message where those disagree is rejected. On
/// its own `f` would be worthless — anybody can type a user id into a JSON
/// object — and on its own the authenticated id cannot be bound into the
/// replay-protected, session-bound body. Together they are a sender identity
/// that is both attested and covered by the rest of the envelope.
///
/// ## Nothing here decides anything about the game
///
/// This is a bouncer, not a rule. Everything it consults — the roster, the
/// session id — came from Supabase, and a message that survives it is handed to
/// the mesh exactly as an unwrapped payload always was. The night policy,
/// `micPolicyFor` and `setAudiblePeers` are untouched and still decide who is
/// heard; this only decides whether a frame off the network is a signal at all.
class VoiceEnvelopes {
  /// Bumped only for a change a previous build could not read. A receiver
  /// rejects anything else rather than guessing.
  static const int version = 1;

  /// How far out of step a message's clock may be before it is stale.
  ///
  /// Signalling is a sub-second conversation, so two minutes is already far
  /// wider than any honest message needs. It is that wide because the number is
  /// bounding a *replay window*, not a network delay, and a device whose clock
  /// is a minute off is a support ticket rather than an attack.
  static const Duration maxAge = Duration(minutes: 2);

  /// How many recent nonces to remember. Enough to cover a whole match's
  /// negotiation several times over; small enough that it cannot grow into a
  /// leak on a long-lived call.
  static const int nonceMemory = 512;

  /// The message types the mesh understands. An envelope announcing anything
  /// else is not a signal this app produced.
  static const Set<String> kinds = {'offer', 'answer', 'candidate', 'ready'};

  /// This match's opaque session id, from `realtime_token`.
  final String sessionId;

  /// This device's user id — the only recipient it will accept.
  final String selfId;

  /// Whether a user id is seated in this match right now, per Supabase.
  final bool Function(String userId) isSeated;

  final Random _random;
  final Queue<String> _seen = Queue<String>();
  final Set<String> _seenIndex = <String>{};

  VoiceEnvelopes({
    required this.sessionId,
    required this.selfId,
    required this.isSeated,
    Random? random,
  }) : _random = random ?? Random.secure();

  /// Wraps one outbound payload for [to].
  Map<String, dynamic> seal(
    String to,
    Map<String, dynamic> payload, {
    DateTime? now,
  }) {
    return {
      'v': version,
      's': sessionId,
      'f': selfId,
      'r': to,
      't': payload['kind'],
      'ts': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'n': _nonce(),
      'p': payload,
    };
  }

  /// Unwraps one inbound frame, or returns null.
  ///
  /// [authenticatedFrom] is Metered's own view of the sender and is never taken
  /// from the frame. Null means *drop it* — there is deliberately no error
  /// type, because every rejection here has the same correct handling and a
  /// throw on this path would be an exception raised by a stranger.
  VoiceSignal? open(String authenticatedFrom, Object? frame, {DateTime? now}) {
    // 1 — schema and version.
    if (frame is! Map) return null;
    if (frame['v'] != version) return null;

    final claimedFrom = frame['f'];
    final to = frame['r'];
    final session = frame['s'];
    final kind = frame['t'];
    final stamp = frame['ts'];
    final nonce = frame['n'];
    final payload = frame['p'];
    if (claimedFrom is! String ||
        to is! String ||
        session is! String ||
        kind is! String ||
        nonce is! String ||
        stamp is! int ||
        payload is! Map) {
      return null;
    }
    if (nonce.isEmpty || claimedFrom.isEmpty) return null;

    // 2 — this match, and no other. The one check Metered cannot make for us.
    if (session != sessionId) return null;

    // 3 — addressed to this device.
    if (to != selfId) return null;

    // 4 — the claimed sender must be the authenticated one.
    if (claimedFrom != authenticatedFrom) return null;

    // A frame from this device is either an echo or somebody wearing its name.
    if (claimedFrom == selfId) return null;

    // 5 and 6 — seated in this match, per Supabase, right now. A player who
    // left, was kicked, or was never here has no negotiation to be part of.
    if (!isSeated(claimedFrom)) return null;

    // 7 — a type the mesh understands, agreeing with the payload it wraps. The
    // engine switches on `kind`, so an envelope whose header disagrees with its
    // body is a frame trying to be read two ways.
    if (!kinds.contains(kind)) return null;
    if (payload['kind'] != kind) return null;
    if (kind == 'ready' && payload.length != 1) return null;

    // 8 — not stale, and not from a clock claiming the future.
    final at = now ?? DateTime.now();
    final age = at.millisecondsSinceEpoch - stamp;
    if (age > maxAge.inMilliseconds || age < -maxAge.inMilliseconds) {
      return null;
    }

    // 8 — and not one already accepted. Checked last, so a frame rejected for
    // any other reason does not consume a slot and a flood of bad frames cannot
    // push a legitimate nonce out of memory.
    if (!_remember('$claimedFrom:$nonce')) return null;

    final out = <String, dynamic>{};
    for (final entry in payload.entries) {
      final key = entry.key;
      if (key is String) out[key] = entry.value;
    }
    if (out.isEmpty) return null;
    return VoiceSignal(fromUserId: claimedFrom, payload: out);
  }

  /// False when this nonce has been seen before.
  bool _remember(String nonce) {
    if (!_seenIndex.add(nonce)) return false;
    _seen.addLast(nonce);
    if (_seen.length > nonceMemory) _seenIndex.remove(_seen.removeFirst());
    return true;
  }

  String _nonce() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
