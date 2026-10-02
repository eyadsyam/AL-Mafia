import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:metered_realtime/metered_realtime.dart';
import 'package:mafia_master/transport/metered_voice_link.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/voice_link.dart';

import '../support/fake_backend.dart';

/// The voice link: which endpoint it asks, what it degrades to, and what it
/// refuses to let Metered decide.
///
/// ## Why the degraded path is what gets tested hardest
///
/// The Metered path is verified against the real service, because a socket and
/// a JWT are not things a fake proves anything about. What a fake *can* prove
/// is the half that has to keep working when Metered does not: non-negotiable 5
/// says voice is never load-bearing, and the only way that stays true is if
/// every failure here is a value rather than a throw, and if the game's own
/// decisions never moved onto the wire that broke.
/// A [SignallingClient] with no socket under it.
///
/// The Metered path is verified against the live service, because a JWT and a
/// WebSocket are not things a fake proves anything about. What only a fake can
/// drive is the *lifecycle*: a connection that drops and comes back, which is
/// an ordinary event on a phone and used to leave signalling permanently on
/// the slow path.
class FakeSignallingClient extends SignallingClient {
  FakeSignallingClient()
    : super(SignallingClientOptions(tokenProvider: () async => 'jwt'));

  final _connected = StreamController<ConnectedEvent>.broadcast();
  final _disconnected = StreamController<DisconnectedEvent>.broadcast();
  final _direct = StreamController<DirectMessageEvent>.broadcast();
  final _presence = StreamController<PresenceEvent>.broadcast();
  final _serverErrors = StreamController<ServerErrorEvent>.broadcast();
  final _tokenErrors = StreamController<TokenProviderError>.broadcast();

  /// Every direct message that went over the socket rather than the database.
  final List<(String, Object?)> sent = [];
  final List<String> subscribed = [];
  Completer<void>? subscribeGate;

  @override
  Stream<ConnectedEvent> get onConnected => _connected.stream;
  @override
  Stream<DisconnectedEvent> get onDisconnected => _disconnected.stream;
  @override
  Stream<DirectMessageEvent> get onDirect => _direct.stream;
  @override
  Stream<PresenceEvent> get onPresence => _presence.stream;
  @override
  Stream<ServerErrorEvent> get onServerError => _serverErrors.stream;
  @override
  Stream<TokenProviderError> get onTokenProviderError => _tokenErrors.stream;

  /// The real SDK emits its welcome frame from inside `connect`, and the link
  /// waits on it for the relay credentials. A fake that stayed silent would
  /// make every test here pay the whole welcome timeout.
  @override
  Future<void> connect() async {
    welcome(isReconnect: false);
  }

  @override
  Future<void> subscribe(String channel, [SubscribeOptions? opts]) async {
    subscribed.add(channel);
    await subscribeGate?.future;
  }

  @override
  Future<void> send(String toPeerId, Object? data) async {
    sent.add((toPeerId, data));
  }

  /// One welcome frame, as the SDK emits after a connect or a reconnect.
  void welcome({
    required bool isReconnect,
    List<IceServerConfig>? iceServers,
  }) => _connected.add(
    ConnectedEvent(
      peerId: 'u0',
      serverTime: 0,
      expiresAt: null,
      isReconnect: isReconnect,
      maxMessageSize: 1048576,
      iceServers: iceServers,
    ),
  );

  @override
  Future<void> dispose() async {
    await _connected.close();
    await _disconnected.close();
    await _direct.close();
    await _presence.close();
    await _serverErrors.close();
    await _tokenErrors.close();
  }
}

void main() {
  FakeBackend backendWith(Map<String, Map<String, dynamic>> responses) {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(),
      players: roster(5),
      own: const OwnSeat(seat: 0, role: 'detective'),
      userId: 'u0',
    );
    backend.responses.addAll(responses);
    return backend;
  }

  const relay = {
    'urls': 'turn:relay.example:80',
    'username': 'u',
    'credential': 'c',
  };
  const stun = {'urls': 'stun:stun.l.google.com:19302'};

  group('BackendVoiceLink — the floor of the ladder', () {
    BackendVoiceLink linkTo(FakeBackend backend) => BackendVoiceLink(
      backend: backend,
      roomId: 'room-1',
      roster: () => const <VoicePeer>[],
    );

    test('asks ice_servers, and hands the list back unchanged', () async {
      final backend = backendWith({
        'ice_servers': {
          'iceServers': [relay],
          'relay': true,
        },
      });

      expect(await linkTo(backend).iceServers(), [relay]);
      expect(backend.called('ice_servers'), isTrue);
    });

    test('a refusal is null, never an exception', () async {
      final backend = backendWith(const {})
        ..refusals['ice_servers'] = BackendException('BAD_REQUEST', 'nope')
        ..stickyRefusals.add('ice_servers');

      // Null is the caller's signal to fall back to public STUN. A throw would
      // climb into the controller and take the match down with the microphone.
      expect(await linkTo(backend).iceServers(), isNull);
    });

    test('an unreachable network is null, not a throw', () async {
      final backend = backendWith(const {})..unreachable = true;
      expect(await linkTo(backend).iceServers(), isNull);
    });

    test('an empty ladder is null rather than an empty mesh', () async {
      final backend = backendWith({
        'ice_servers': {'iceServers': <dynamic>[], 'relay': false},
      });
      expect(await linkTo(backend).iceServers(), isNull);
    });
  });

  group('MeteredVoiceLink — what Metered is never allowed to decide', () {
    MeteredVoiceLink linkTo(
      FakeBackend backend, {
      List<VoicePeer> peers = const [],
    }) => MeteredVoiceLink(
      backend: backend,
      roomId: 'room-1',
      roster: () => peers,
    );

    test('mints against realtime_token, scoped to this room', () async {
      final backend = backendWith(const {});
      final link = linkTo(backend);
      await pumpEventQueue();

      final mint = backend.calls.firstWhere(
        (c) => c.function == 'realtime_token',
      );
      // The room id is the only argument. The channel is derived from it on
      // the server, so there is nothing here for a modified client to widen.
      expect(mint.body, {'roomId': 'room-1'});
      await link.dispose();
    });

    test('no realtime credential falls back to Postgres signalling', () async {
      // `realtime_token` answering without a token is the shape a deployment
      // with no Realtime key returns, and it must not cost the match its voice.
      final backend = backendWith({
        'realtime_token': {'token': null, 'channel': null, 'reason': 'no-key'},
      });
      final link = linkTo(backend);
      await pumpEventQueue();

      expect(link.connected, isFalse);

      // Signals still arrive, over the database.
      final received = <VoiceSignal>[];
      final sub = link.incoming.listen(received.add);
      backend.deliverSignal(
        const VoiceSignal(fromUserId: 'u1', payload: {'type': 'offer'}),
      );
      await pumpEventQueue();
      expect(received.single.fromUserId, 'u1');

      // And still leave, over the database.
      await link.send('u1', const {'type': 'answer'});
      expect(backend.sentSignals, isNotEmpty);

      await sub.cancel();
      await link.dispose();
    });

    test('the roster is Supabase, never Metered presence', () async {
      const seated = [
        VoicePeer(userId: 'u0', seat: 0),
        VoicePeer(userId: 'u1', seat: 1),
      ];
      final backend = backendWith(const {});
      final link = linkTo(backend, peers: seated);

      // Doc 10 §7: the room state is the room. A peer id on a signalling
      // channel is not a seat, and a player whose socket dropped is still
      // playing.
      expect(link.peers, seated);
      await link.dispose();
    });

    test('the floor stays on the server, not on the socket', () async {
      final backend = backendWith({
        'claim_floor': {'granted': true},
      });
      final link = linkTo(backend);

      expect(await link.claimFloor(), isTrue);
      await link.releaseFloor();

      // Who may speak is a rule of the game, so it is decided where every
      // other rule is — never by whoever happens to hold a signalling socket.
      expect(backend.called('claim_floor'), isTrue);
      expect(backend.called('release_floor'), isTrue);
      await link.dispose();
    });

    test('with no Metered session, nothing is admitted on that path', () async {
      // The grant carried no token, so there is no socket and no session id to
      // bind an envelope to. Anything claiming to arrive over Metered is
      // therefore not something this app sent, whatever it looks like.
      // Signalling is coming over the database instead, where RLS already
      // scopes `signals` to `to_id = auth.uid()`.
      final backend = backendWith({
        'realtime_token': {'token': null, 'channel': null, 'sessionId': null},
      });
      final link = linkTo(
        backend,
        peers: const [
          VoicePeer(userId: 'u0', seat: 0),
          VoicePeer(userId: 'u1', seat: 1),
        ],
      );
      await pumpEventQueue();

      expect(link.admit('u1', const {'v': 1, 'f': 'u1', 'r': 'u0'}), isNull);
      await link.dispose();
    });

    test('ICE comes from the grant until a welcome frame arrives', () async {
      final backend = backendWith({
        'realtime_token': {
          'token': null,
          'channel': null,
          'iceServers': [stun],
        },
        'ice_servers': {
          'iceServers': [relay],
        },
      });
      final link = linkTo(backend);
      await pumpEventQueue();

      // No socket, so no welcome — but the grant carried a STUN floor, and a
      // call that starts on STUN beats a call that waits for a relay.
      expect(await link.iceServers(), [stun]);
      await link.dispose();
    });

    test('ICE asked for before the mint answers still waits for it', () async {
      // The bug that kept TURN out of every `RTCPeerConnection`. The completer
      // the welcome frame finishes used to be created *inside* `_open`, after
      // an awaited mint — so a controller that asked for ICE first found
      // nothing to wait on, fell through to the legacy endpoint, and cached
      // that answer for the whole match. The relay arrived a moment later with
      // nowhere to go.
      final backend = backendWith({
        'realtime_token': {
          'token': null,
          'channel': null,
          'iceServers': [stun],
        },
        'ice_servers': {
          'iceServers': [relay],
        },
      });
      final link = linkTo(backend);

      // Asked immediately, with the mint still in flight.
      expect(await link.iceServers(), [stun]);
      await link.dispose();
    });

    test('a socket that will never open does not stall every climb', () async {
      // The other half of the same completer: something has to finish it when
      // no welcome frame is coming, or each climb pays the full welcome
      // timeout before falling back — six seconds of silence per phase.
      final backend = backendWith({
        'realtime_token': {'token': null, 'channel': null},
        'ice_servers': {
          'iceServers': [relay],
        },
      });
      final link = linkTo(backend);

      final clock = Stopwatch()..start();
      await link.iceServers();
      clock.stop();

      expect(
        clock.elapsed,
        lessThan(MeteredVoiceLink.welcomeTimeout),
        reason: 'the wait is released when nothing can arrive',
      );
      await link.dispose();
    });

    test(
      'first welcome carries direct signalling before subscribe completes',
      () async {
        final backend = backendWith({
          'realtime_token': {
            'token': 'jwt',
            'channel': 'room-1',
            'sessionId': 'session-1',
          },
        });
        final gate = Completer<void>();
        final client = FakeSignallingClient()..subscribeGate = gate;
        final link = MeteredVoiceLink(
          backend: backend,
          roomId: 'room-1',
          roster: () => const [VoicePeer(userId: 'u1', seat: 1)],
          clientFactory: (_) => client,
        );
        addTearDown(() async {
          gate.complete();
          await pumpEventQueue();
          await link.dispose();
        });
        await link.iceServers();
        expect(gate.isCompleted, isFalse);
        expect(link.connected, isTrue);
        await link.send('u1', const {'kind': 'ready'});
        expect(client.sent, hasLength(1));
        expect(backend.sentSignals, isEmpty);
      },
    );

    test(
      'a socket that dropped and came back carries signalling again',
      () async {
        // The bug this test exists for cost nothing visible and everything
        // measurable. `_live` was set in exactly one place — after the first
        // connect — and cleared on every disconnect. The SDK reconnects by
        // itself and replays its subscriptions, so the socket came back and the
        // flag did not: from one blip of network onward, every offer, answer and
        // candidate for the rest of the match took the database path.
        //
        // Nothing reported it, because the fallback works. Signalling was simply
        // slower, for ever — and a mesh that has to renegotiate after a network
        // change is exactly the moment that matters.
        final backend = backendWith({
          'realtime_token': {
            'token': 'jwt',
            'channel': 'room-1',
            'sessionId': 'session-1',
          },
        });
        final client = FakeSignallingClient();
        final link = MeteredVoiceLink(
          backend: backend,
          roomId: 'room-1',
          roster: () => const [
            VoicePeer(userId: 'u0', seat: 0),
            VoicePeer(userId: 'u1', seat: 1),
          ],
          clientFactory: (_) => client,
        );
        addTearDown(link.dispose);
        await pumpEventQueue();

        expect(link.connected, isTrue, reason: 'the first connect came up');
        await link.send('u1', const {'kind': 'offer'});
        expect(client.sent, hasLength(1));
        expect(backend.sentSignals, isEmpty);

        // The network moves. Signalling degrades to the database, which is the
        // designed behaviour and not the bug.
        link.handleDisconnected();
        expect(link.connected, isFalse);
        await link.send('u1', const {'kind': 'candidate'});
        expect(client.sent, hasLength(1));
        expect(backend.sentSignals, hasLength(1));

        // And the SDK gets it back. This is the half that was missing.
        client.welcome(isReconnect: true);
        await pumpEventQueue();

        expect(link.connected, isTrue);
        await link.send('u1', const {'kind': 'answer'});
        expect(
          client.sent,
          hasLength(2),
          reason: 'the socket carries signalling again after a reconnect',
        );
        expect(
          backend.sentSignals,
          hasLength(1),
          reason: 'and stops paying for the database path',
        );
      },
    );

    test(
      'a reconnect refreshes the relay credentials it arrives with',
      () async {
        // TURN credentials are minted per socket and they expire. A reconnect is
        // where a fresh set arrives, and a link that ignored the second welcome
        // would hand an `RTCPeerConnection` a relay the service has since
        // stopped honouring.
        final backend = backendWith({
          'realtime_token': {
            'token': 'jwt',
            'channel': 'room-1',
            'sessionId': 'session-1',
            'iceServers': [stun],
          },
        });
        final client = FakeSignallingClient();
        final link = MeteredVoiceLink(
          backend: backend,
          roomId: 'room-1',
          roster: () => const <VoicePeer>[],
          clientFactory: (_) => client,
        );
        addTearDown(link.dispose);
        await pumpEventQueue();

        expect(await link.iceServers(), [stun]);

        link.handleDisconnected();
        client.welcome(
          isReconnect: true,
          iceServers: const [
            IceServerConfig(
              urls: 'turn:relay.example:80',
              username: 'u',
              credential: 'c',
            ),
          ],
        );
        await pumpEventQueue();

        expect(await link.iceServers(), [relay]);
      },
    );

    test(
      'a welcome after dispose does not revive a link that is gone',
      () async {
        // The socket is torn down asynchronously, and a frame already in flight
        // can land after `dispose`. A link that went live again here would be
        // holding a client it has already thrown away.
        final backend = backendWith({
          'realtime_token': {
            'token': 'jwt',
            'channel': 'room-1',
            'sessionId': 'session-1',
          },
        });
        final client = FakeSignallingClient();
        final link = MeteredVoiceLink(
          backend: backend,
          roomId: 'room-1',
          roster: () => const <VoicePeer>[],
          clientFactory: (_) => client,
        );
        await pumpEventQueue();
        await link.dispose();

        link.handleConnected(
          const ConnectedEvent(
            peerId: 'u0',
            serverTime: 0,
            expiresAt: null,
            isReconnect: true,
            maxMessageSize: 1048576,
          ),
        );

        expect(link.connected, isFalse);
      },
    );

    test('no grant at all still reaches the legacy endpoint', () async {
      final backend =
          backendWith({
              'ice_servers': {
                'iceServers': [relay],
              },
            })
            ..refusals['realtime_token'] = BackendException(
              'BAD_REQUEST',
              'gone',
            )
            ..stickyRefusals.add('realtime_token');
      final link = linkTo(backend);
      await pumpEventQueue();

      expect(await link.iceServers(), [relay]);
      await link.dispose();
    });
  });
}
