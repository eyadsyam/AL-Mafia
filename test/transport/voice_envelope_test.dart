import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/voice_envelope.dart';

/// The signalling envelope: eight questions asked of every frame that arrives
/// over Metered, and the seven ways a frame can fail to be a signal.
///
/// ## Why this is tested here and not through a socket
///
/// This class *is* the guard. `MeteredVoiceLink.admit` adds exactly one fact to
/// it — the sender id Metered authenticated, as opposed to the one the frame
/// claims — and then delegates. Testing the guard directly means every branch
/// is reachable, the clock is injectable, and no test needs a network.
///
/// ## The threat being modelled
///
/// Metered direct messages are addressed by peer id and are not scoped to the
/// token's `channels` claim; that is confirmed behaviour of the live service,
/// not a hypothetical. So the attacker here is not an outsider — it is a real,
/// fully authenticated Mafia Master player, in a real match, who is not in
/// *your* match, or is no longer in it, or is replaying something they captured
/// from it. Every test below is one of those people.
void main() {
  const self = 'u-self';
  const peer = 'u-peer';
  const session = 'session-alpha';

  late List<String> seated;
  late VoiceEnvelopes envelopes;
  final at = DateTime.utc(2026, 9, 8, 12);

  setUp(() {
    seated = [self, peer];
    envelopes = VoiceEnvelopes(
      sessionId: session,
      selfId: self,
      isSeated: seated.contains,
      // Seeded, so a nonce is reproducible and a test never depends on entropy.
      random: Random(7),
    );
  });

  /// A well-formed frame from [peer] to [self], which each test then spoils in
  /// exactly one way — so a failure names the check that stopped it.
  Map<String, dynamic> frame({
    String from = peer,
    String to = self,
    String sessionId = session,
    String kind = 'offer',
    int version = VoiceEnvelopes.version,
    DateTime? stamped,
    String nonce = 'n-1',
    Map<String, dynamic>? payload,
  }) => {
    'v': version,
    's': sessionId,
    'f': from,
    'r': to,
    't': kind,
    'ts': (stamped ?? at).millisecondsSinceEpoch,
    'n': nonce,
    'p': payload ?? {'kind': kind, 'sdp': 'v=0'},
  };

  group('what is accepted', () {
    test('valid current-match signalling is admitted', () {
      final signal = envelopes.open(peer, frame(), now: at);

      expect(signal, isNotNull);
      expect(signal!.fromUserId, peer);
      // The mesh receives the inner payload, unchanged and unwrapped — the
      // envelope is a gate, not a transformation.
      expect(signal.payload, {'kind': 'offer', 'sdp': 'v=0'});
    });

    test('all three signalling types pass', () {
      for (final kind in ['offer', 'answer', 'candidate']) {
        expect(
          envelopes.open(
            peer,
            frame(kind: kind, nonce: 'n-$kind'),
            now: at,
          ),
          isNotNull,
          reason: '$kind should be a signal',
        );
      }
    });

    test('a sealed envelope opens at the other end', () {
      // Proves the two halves agree: anything this app sends is something this
      // app accepts, so the guard cannot be tightened into rejecting itself.
      final other = VoiceEnvelopes(
        sessionId: session,
        selfId: peer,
        isSeated: seated.contains,
      );
      final sealed = other.seal(self, {
        'kind': 'answer',
        'sdp': 'v=0',
      }, now: at);

      expect(envelopes.open(peer, sealed, now: at), isNotNull);
    });
  });

  group('what is rejected', () {
    test('a cross-match direct message', () {
      // The headline case: a fully authenticated player of another match,
      // whose token Metered accepted, directing a frame at this socket.
      expect(
        envelopes.open(peer, frame(sessionId: 'session-beta'), now: at),
        isNull,
      );
    });

    test('the right sender, but another session of the same room', () {
      // Same person, same room row, older incarnation — the session id is
      // bound to the match seed, so it does not survive a new one.
      expect(
        envelopes.open(peer, frame(sessionId: 'session-alpha-old'), now: at),
        isNull,
      );
    });

    test('a spoofed sender field', () {
      // Metered says this is `peer`; the frame claims to be somebody else.
      // Neither identity is trusted alone, and they must agree.
      final spoofed = frame(from: 'u-someone-else');
      expect(envelopes.open(peer, spoofed, now: at), isNull);

      // And the mirror image: the body names a real seated peer while the
      // authenticated sender is a different one.
      expect(envelopes.open('u-someone-else', frame(), now: at), isNull);
    });

    test('a frame addressed to somebody else', () {
      expect(envelopes.open(peer, frame(to: 'u-other'), now: at), isNull);
    });

    test('a sender who has been removed from the Supabase roster', () {
      // Accepted while seated…
      expect(envelopes.open(peer, frame(nonce: 'n-a'), now: at), isNotNull);

      // …and refused the moment they are not. The roster is read through a
      // closure, so a kick takes effect on the next frame rather than on the
      // next reconnect.
      seated.remove(peer);
      expect(envelopes.open(peer, frame(nonce: 'n-b'), now: at), isNull);
    });

    test('a stale frame, and one from a clock claiming the future', () {
      final old = at.subtract(VoiceEnvelopes.maxAge * 2);
      expect(envelopes.open(peer, frame(stamped: old), now: at), isNull);

      final ahead = at.add(VoiceEnvelopes.maxAge * 2);
      expect(
        envelopes.open(
          peer,
          frame(stamped: ahead, nonce: 'n-f'),
          now: at,
        ),
        isNull,
      );
    });

    test('a replay of a frame already accepted', () {
      final captured = frame(nonce: 'n-replay');
      expect(envelopes.open(peer, captured, now: at), isNotNull);
      expect(envelopes.open(peer, captured, now: at), isNull);
    });

    test('an unknown protocol version', () {
      expect(envelopes.open(peer, frame(version: 99), now: at), isNull);
    });

    test('a header that disagrees with the payload it wraps', () {
      // The engine switches on the payload's `kind`; a frame whose type says
      // one thing and whose body says another is a frame trying to be read two
      // ways, and is not read at all.
      final mismatched = frame(
        kind: 'offer',
        payload: {'kind': 'candidate', 'candidate': 'x'},
      );
      expect(envelopes.open(peer, mismatched, now: at), isNull);
    });

    test('a type the mesh does not understand', () {
      final odd = frame(kind: 'rollback', payload: {'kind': 'rollback'});
      expect(envelopes.open(peer, odd, now: at), isNull);
    });

    test('this device receiving its own name', () {
      expect(envelopes.open(self, frame(from: self), now: at), isNull);
    });

    test('malformed frames, of every shape', () {
      expect(envelopes.open(peer, null, now: at), isNull);
      expect(envelopes.open(peer, 'not a map', now: at), isNull);
      expect(envelopes.open(peer, const <String, dynamic>{}, now: at), isNull);

      for (final missing in ['v', 's', 'f', 'r', 't', 'ts', 'n', 'p']) {
        final partial = frame()..remove(missing);
        expect(
          envelopes.open(peer, partial, now: at),
          isNull,
          reason: 'a frame with no "$missing" is not a signal',
        );
      }

      // Right keys, wrong types.
      expect(envelopes.open(peer, frame()..['ts'] = 'soon', now: at), isNull);
      expect(envelopes.open(peer, frame()..['p'] = 'sdp', now: at), isNull);
      expect(envelopes.open(peer, frame()..['n'] = '', now: at), isNull);
    });

    test('a rejected frame does not consume nonce memory', () {
      // The nonce is remembered last, deliberately: otherwise a flood of frames
      // that fail a later check could evict a legitimate nonce, and the check
      // meant to stop replays would become the way to cause one.
      final captured = frame(nonce: 'n-shared');
      expect(
        envelopes.open(
          peer,
          frame(nonce: 'n-shared', to: 'u-other'),
          now: at,
        ),
        isNull,
      );
      expect(envelopes.open(peer, captured, now: at), isNotNull);
    });
  });

  /// `ready` is the newest thing on this wire and the only one that carries no
  /// payload of its own, which makes it the one worth stating separately.
  ///
  /// It exists because a peer that grants the microphone late misses the only
  /// offer it was ever going to get: an offer is made once per `connect`, and
  /// a device still showing a permission dialog has no engine to answer with.
  /// `ready` is that device saying *ask me again*.
  ///
  /// The risk it introduces is that it is cheap. An offer costs the sender an
  /// SDP; a `ready` is four bytes that make somebody else renegotiate. So it
  /// is admitted through exactly the same eight questions as everything else,
  /// and one more: its body must be empty. A `ready` with a field in it is a
  /// message trying to be two things.
  group('the ready frame', () {
    Map<String, dynamic> ready({
      String from = peer,
      String to = self,
      String sessionId = session,
      String nonce = 'n-ready',
      Map<String, dynamic>? payload,
    }) => frame(
      from: from,
      to: to,
      sessionId: sessionId,
      kind: 'ready',
      nonce: nonce,
      payload: payload ?? {'kind': 'ready'},
    );

    test('the one correct shape is admitted', () {
      final signal = envelopes.open(peer, ready(), now: at);

      expect(signal, isNotNull);
      expect(signal!.payload, {
        'kind': 'ready',
      }, reason: 'nothing rides along with it');
    });

    test('a sealed ready opens at the other end', () {
      final other = VoiceEnvelopes(
        sessionId: session,
        selfId: peer,
        isSeated: seated.contains,
      );
      final sealed = other.seal(self, const {'kind': 'ready'}, now: at);

      expect(envelopes.open(peer, sealed, now: at)?.payload, {'kind': 'ready'});
    });

    test('a body with anything else in it is not a ready', () {
      // The whole point of the length check. Somewhere to hide a field is
      // somewhere to hide a role, a seat, or a phase — and this frame has no
      // legitimate use for any of them.
      for (final extra in [
        {'kind': 'ready', 'sdp': 'v=0'},
        {'kind': 'ready', 'seat': 3},
        {'kind': 'ready', 'role': 'mafia'},
        {'kind': 'ready', 'kind2': 'ready'},
      ]) {
        expect(
          envelopes.open(
            peer,
            ready(payload: extra, nonce: 'n-${extra.keys.last}'),
            now: at,
          ),
          isNull,
          reason: '$extra is not a ready frame',
        );
      }
    });

    test('an empty body is not a ready either', () {
      // `t` says ready and `p` does not. The header and the body have to agree
      // before the length rule is even reached.
      expect(envelopes.open(peer, ready(payload: const {}), now: at), isNull);
    });

    test('a ready from another match is refused like any other frame', () {
      expect(
        envelopes.open(peer, ready(sessionId: 'session-beta'), now: at),
        isNull,
      );
    });

    test('a spoofed sender cannot ask this device to renegotiate', () {
      // The frame claims the peer; Metered authenticated somebody else. A
      // cheap message is still a message, and this is the one that would make
      // a stranger the reason two players re-offer.
      expect(envelopes.open('u-other', ready(), now: at), isNull);
    });

    test('a player who has left cannot ask to be dialled again', () {
      seated.remove(peer);
      expect(envelopes.open(peer, ready(), now: at), isNull);
    });

    test('a ready addressed to somebody else is not read', () {
      expect(envelopes.open(peer, ready(to: 'u-third'), now: at), isNull);
    });

    test('a captured ready cannot be replayed', () {
      final captured = ready();

      expect(envelopes.open(peer, captured, now: at), isNotNull);
      expect(
        envelopes.open(peer, captured, now: at),
        isNull,
        reason: 'renegotiation is not something a recording can trigger',
      );
    });
  });

  group('sealing', () {
    test('carries routing context and nothing about the game', () {
      final sealed = envelopes.seal(peer, {
        'kind': 'offer',
        'sdp': 'v=0',
      }, now: at);

      expect(sealed['v'], VoiceEnvelopes.version);
      expect(sealed['s'], session);
      expect(sealed['f'], self);
      expect(sealed['r'], peer);
      expect(sealed['t'], 'offer');
      expect(sealed['n'], isNotEmpty);

      // Doc 05: nothing on this wire may describe the table. The keys are the
      // whole surface, so the assertion is on the key set itself.
      expect(sealed.keys.toSet(), {'v', 's', 'f', 'r', 't', 'ts', 'n', 'p'});
      final body = sealed.toString().toLowerCase();
      for (final secret in [
        'mafia',
        'doctor',
        'detective',
        'citizen',
        'seat',
        'role',
        'seed',
      ]) {
        expect(body.contains(secret), isFalse, reason: '"$secret" on the wire');
      }
    });

    test('a fresh nonce every time', () {
      final nonces = {
        for (var i = 0; i < 50; i++)
          envelopes.seal(peer, {'kind': 'candidate'}, now: at)['n'],
      };
      expect(nonces.length, 50);
    });
  });
}
