import 'dart:async';
import 'dart:developer' as developer;

import 'package:meta/meta.dart';

import 'package:metered_realtime/metered_realtime.dart';

import 'online_backend.dart';
import 'voice_envelope.dart';
import 'voice_link.dart';

/// The call's signalling, over Metered Realtime.
///
/// ## What moved, and what deliberately did not
///
/// ```
/// signalling   Postgres `signals` table  →  Metered direct messages
/// presence     (none)                    →  Metered channel presence
/// relay        public STUN only          →  TURN, injected into the welcome
///
/// who may speak      Supabase   — unchanged
/// who may be heard   the mesh   — unchanged
/// the roster         Supabase   — unchanged
/// media              ours       — unchanged
/// ```
///
/// Only the wire changed. Every decision about the *game* is still made where
/// it was, which is the point: doc 10 §6.1 says never trust the client, and a
/// signalling provider is a client.
///
/// ## Why [SignallingClient] and not `MeteredPeer`
///
/// The SDK ships a `MeteredPeer` that would do far more of this file's work: it
/// negotiates an `RTCPeerConnection` for every peer that appears on the channel
/// and hands up remote streams. That is the wrong shape for this game. Mafia's
/// night phases require that a player is *not connected* to the people they may
/// not hear — see [VoiceEngine.setAudiblePeers], which is the receiving half of
/// V4 — and an abstraction that connects everyone to everyone the moment they
/// join has already leaked by the time any policy could run. Muting a track
/// that has arrived is not the same guarantee as never negotiating it.
///
/// So this uses the layer below: a socket that carries offers, answers and
/// candidates between two named peers, and nothing that touches media. The mesh
/// stays ours, and so does every decision about who is in it.
///
/// ## Why the fallback is composition rather than a second architecture
///
/// [BackendVoiceLink] is still here, held as a delegate. It owns the floor —
/// which is authoritative game state and was never Metered's to hold — and it
/// carries signalling on the one path where Metered cannot: a deployment with
/// no Realtime key, or a socket that will not open. That is a rung on the same
/// ladder as STUN → TURN → text, not a competing design; there is exactly one
/// [VoiceLink] the app constructs, and it is this one.
///
/// ## What never crosses this wire
///
/// A role, a seat, a name, a night action, the match seed. The peer id is a
/// Supabase user id — which every client already holds for everyone in the
/// room, because the mesh has always dialled by it — and the payloads are SDP
/// and ICE candidates, which describe a network path and nothing about a game.
/// No `peerMetadata` is minted, so presence entries carry an id and nothing
/// else.
class MeteredVoiceLink implements VoiceLink {
  final OnlineBackend backend;
  final String roomId;
  final List<VoicePeer> Function() roster;

  /// The floor, and the signalling path used when Metered is unavailable.
  final BackendVoiceLink _fallback;

  /// How the signalling client is built.
  ///
  /// Injected only by tests, which need a socket's lifecycle — dropped,
  /// reconnected, welcomed a second time — without a socket. Production passes
  /// nothing and gets the SDK's own client.
  final SignallingClient Function(SignallingClientOptions options)
  _clientFactory;

  /// How long [iceServers] waits for the welcome frame before answering with
  /// what it already has. The mesh must not stall on a socket: a call that
  /// comes up on STUN is better than a call that comes up late.
  static const Duration welcomeTimeout = Duration(seconds: 6);

  final _signals = StreamController<VoiceSignal>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  SignallingClient? _client;
  VoiceEnvelopes? _envelopes;
  String? _channel;
  List<Map<String, dynamic>>? _ice;

  /// Completed by the welcome frame, and created in the constructor rather
  /// than when the socket is built.
  ///
  /// The difference is the whole reason TURN never reached an
  /// `RTCPeerConnection`. [iceServers] waits on this; it used to be null until
  /// `realtime_token` had answered *and* the SDK client had been constructed,
  /// so a controller that asked for ICE before then saw nothing to wait for,
  /// took the STUN floor, and cached it for the rest of the match. The relay
  /// arrived a second later and had nowhere to go.
  final Completer<void> _welcome = Completer<void>();
  StreamSubscription<VoiceSignal>? _postgres;
  bool _live = false;
  bool _disposed = false;

  MeteredVoiceLink({
    required this.backend,
    required this.roomId,
    required this.roster,
    @visibleForTesting
    SignallingClient Function(SignallingClientOptions options)? clientFactory,
  }) : _clientFactory = clientFactory ?? SignallingClient.new,
       _fallback = BackendVoiceLink(
         backend: backend,
         roomId: roomId,
         roster: roster,
       ) {
    // Opened first and never closed. A peer sends on exactly one path — Metered
    // when its socket is live, the database otherwise — so listening on both
    // cannot duplicate a signal, and it means a client whose Metered session
    // came up still hears one whose did not. During a rollout that is the
    // difference between a mixed room and a half-silent one.
    _listenOnPostgres();
    unawaited(_open());
  }

  /// Whether signalling is currently going over Metered. False means the
  /// Postgres path is carrying it, which is a degraded call and not a broken
  /// one.
  bool get connected => _live;

  @override
  String get selfId => backend.userId ?? '';

  /// Supabase, always.
  ///
  /// Metered presence knows who has a socket open; it does not know who is
  /// playing. A player whose phone is in a tunnel is still at the table, and a
  /// peer id on a channel is not a seat. Doc 10 §7: the room state is the room.
  @override
  List<VoicePeer> get peers => roster();

  @override
  Stream<VoiceSignal> get incoming => _signals.stream;

  // ── coming up ────────────────────────────────────────────────────────────

  Future<void> _open() async {
    final grant = await _mint();
    // A room left while the mint was in flight: whatever comes back now is for
    // a call that no longer exists, and opening a socket for it would leak one.
    if (_disposed) return;

    // The STUN floor, taken before anything else can go wrong: a grant that
    // arrived carries a usable ladder even if the socket never opens.
    _ice = _serversFrom(grant?['iceServers']);

    if (grant == null || grant['token'] == null) {
      developer.log(
        'no realtime credential — signalling over postgres',
        name: 'voice',
        level: 900,
      );
      // Nothing is coming, so nobody should wait for it. Every climb would
      // otherwise pay the welcome timeout before falling back to STUN.
      _giveUpOnWelcome();
      return;
    }
    // Server-derived, always. The client has no say in which channel it may
    // reach, and asking for a different one would fail the JWT's `channels`
    // claim at Metered rather than here.
    final channel = grant['channel'] as String?;
    final session = grant['sessionId'] as String?;
    if (channel == null || session == null || session.isEmpty) {
      // Without a session id there is nothing to bind an envelope to, and an
      // unbound envelope is exactly the hole this transport has to close. The
      // database path is the safer answer, so take it.
      developer.log(
        'grant carried no channel or session — signalling over postgres',
        name: 'voice',
        level: 900,
      );
      _giveUpOnWelcome();
      return;
    }
    _channel = channel;
    _envelopes = VoiceEnvelopes(
      sessionId: session,
      selfId: selfId,
      // Read through the roster closure rather than captured, so a player who
      // leaves mid-match stops being an acceptable sender immediately.
      isSeated: (userId) => roster().any((p) => p.userId == userId),
    );

    final client = _clientFactory(
      SignallingClientOptions(
        // Re-minted on every reconnect, and every mint re-runs the membership
        // checks on the server. A player removed while offline does not come
        // back with the socket.
        tokenProvider: () async {
          final fresh = await _mint();
          final token = fresh?['token'];
          if (token is! String || token.isEmpty) {
            throw StateError('realtime_token refused');
          }
          return token;
        },
        autoReconnect: true,
      ),
    );
    _client = client;

    _subscriptions.add(client.onConnected.listen(handleConnected));
    _subscriptions.add(client.onDirect.listen(_onDirect));
    _subscriptions.add(client.onPresence.listen(_onPresence));
    _subscriptions.add(
      client.onDisconnected.listen((_) => handleDisconnected()),
    );
    _subscriptions.add(
      client.onTokenProviderError.listen((_) {
        // Informational: the SDK keeps retrying with backoff. It becomes a
        // problem only if it never succeeds, and that shows up as a call that
        // never connects, which the ladder already handles.
        developer.log(
          'metered token refresh failing',
          name: 'voice',
          level: 900,
        );
      }),
    );
    _subscriptions.add(
      client.onServerError.listen((e) {
        developer.log('metered server error: ${e.rawCode}', name: 'voice');
      }),
    );

    try {
      await client.connect();
      if (_disposed) return;
      await client.subscribe(channel);
      _live = true;
      developer.log('metered signalling live', name: 'voice');
    } catch (e) {
      // A welcome frame may already have arrived and marked the socket live
      // before  threw. It did not survive, so neither does the flag.
      _live = false;
      developer.log('metered signalling unavailable', name: 'voice');
      _giveUpOnWelcome();
    }
  }

  /// Releases [iceServers] callers when no welcome frame can arrive.
  void _giveUpOnWelcome() {
    if (!_welcome.isCompleted) _welcome.complete();
  }

  Future<Map<String, dynamic>?> _mint() async {
    try {
      return await backend.call('realtime_token', {'roomId': roomId});
    } on BackendException {
      return null;
    } on BackendUnreachable {
      return null;
    }
  }

  /// The database signalling path, which is always listening.
  ///
  /// An error on it is swallowed rather than surfaced: this is the rung *under*
  /// the socket, and a rung that throws is worse than one that is quiet.
  void _listenOnPostgres() {
    _postgres = _fallback.incoming.listen(_signals.add, onError: (_) {});
  }

  /// One welcome frame: the first, or the one that ends a reconnect.
  ///
  /// ## Why the reconnect half exists
  ///
  /// [_live] used to be set in exactly one place — after the first
  /// `connect()`/`subscribe()` pair — and cleared on every disconnect. The SDK
  /// reconnects on its own and replays its subscriptions, so the socket came
  /// back; the flag did not. From the first dropped connection onward every
  /// offer, answer and candidate took the database path for the rest of the
  /// match. Nothing reported it, because the fallback works: signalling was
  /// simply slower, for ever, after one blip of network.
  ///
  /// The socket is usable the moment this frame lands. A direct message in
  /// this protocol is addressed by peer id and does not require a channel
  /// subscription — that is the same property [_onDirect] has to defend
  /// against on the way in — so there is nothing to wait for here.
  @visibleForTesting
  void handleConnected(ConnectedEvent event) {
    if (_disposed) return;
    // ICE callers resume as soon as this welcome completes. Direct signalling
    // must already be usable then, including the initial connection; waiting
    // for the subscribe acknowledgement sends the first offer down fallback.
    _live = true;
    if (event.isReconnect) {
      developer.log('metered signalling live again', name: 'voice');
    }
    final servers = event.iceServers;
    if (servers != null && servers.isNotEmpty) {
      _ice = [
        for (final s in servers)
          {
            'urls': s.urls,
            if (s.username != null) 'username': s.username,
            if (s.credential != null) 'credential': s.credential,
          },
      ];
    }
    _describeIce(_ice);
    if (!_welcome.isCompleted) _welcome.complete();
  }

  /// The socket is gone. Signalling drops to the database until a welcome
  /// frame says otherwise — a degraded call, not a broken one.
  @visibleForTesting
  void handleDisconnected() {
    _live = false;
    developer.log('metered signalling disconnected', name: 'voice');
  }

  /// Counts and schemes only.
  ///
  /// A TURN credential is a bearer credential for the account's relay. It is
  /// exactly as sensitive as the key that minted it, and a log line is the one
  /// place in this app where a secret would be written down and forgotten.
  void _describeIce(List<Map<String, dynamic>>? servers) {
    final urls = <String>[
      for (final s in servers ?? const <Map<String, dynamic>>[])
        ...switch (s['urls']) {
          final String one => [one],
          final List<dynamic> many => many.map((u) => '$u'),
          _ => const <String>[],
        },
    ];
    bool has(String scheme) => urls.any((u) => u.startsWith('$scheme:'));
    developer.log(
      'ice servers: ${servers?.length ?? 0} '
      '(stun ${has('stun')}, turn ${has('turn')}, turns ${has('turns')})',
      name: 'voice',
    );
  }

  /// Presence is a connectivity signal and never a roster.
  ///
  /// Logged as counts, because the ids are Supabase user ids and a log that
  /// pairs them with a moment in the match is a log that says who went quiet
  /// when — which is a tell, and doc 05 does not permit the app to hand out
  /// tells it was not asked for.
  void _onPresence(PresenceEvent event) {
    // The JWT scopes this socket to one channel, so anything else is either a
    // protocol surprise or a subscription we did not make. Either way it is not
    // this match, and it is dropped rather than reasoned about.
    if (event.channel != _channel) return;
    if (event.joined.isEmpty && event.left.isEmpty) return;
    developer.log(
      'presence: +${event.joined.length} -${event.left.length}',
      name: 'voice',
    );
  }

  /// One inbound offer, answer, or candidate.
  ///
  /// ## Why the roster is checked here and not only in the engine
  ///
  /// A direct message in this protocol is addressed by peer id and is *not*
  /// scoped to a channel — verified against the live service: a token minted
  /// for match B can direct-message a peer in match A. Metered documents this
  /// ("send by peerId, no channel required"), so the `channels` claim, which
  /// does constrain subscribe and publish, is not a boundary here.
  ///
  /// The mesh already survives it — [VoiceEngine.acceptSignal] looks the sender
  /// up in the connections it built from the server's roster and returns when
  /// there is none, so a stranger's offer reaches no peer connection and no
  /// audio. But that is a consequence of how the engine happens to be written,
  /// and a privacy guarantee should not rest on a map lookup somewhere else.
  ///
  /// So it is stated here, once, against the roster Supabase gave us: a signal
  /// from somebody who is not seated in this match is not a signal. That is
  /// also the only sensible reading — there is nothing to negotiate with a peer
  /// who is not at the table.
  void _onDirect(DirectMessageEvent event) {
    final signal = admit(event.from, event.data);
    if (signal != null) _signals.add(signal);
  }

  /// The admission rule, as a value rather than a side effect, so the thing
  /// this file most has to get right can be tested without a socket.
  ///
  /// Returns null for everything that is not a live signalling message from a
  /// player at this table, in this match, addressed to this device. The checks
  /// themselves live in [VoiceEnvelopes.open]; what this adds is the one fact
  /// only the link holds — [authenticatedFrom] is Metered's own view of the
  /// sender, never the frame's.
  @visibleForTesting
  VoiceSignal? admit(String authenticatedFrom, Object? frame, {DateTime? now}) {
    final envelopes = _envelopes;
    if (envelopes == null) {
      // No Metered session, so nothing legitimate arrives on this path.
      return null;
    }
    final signal = envelopes.open(authenticatedFrom, frame, now: now);
    if (signal == null) {
      developer.log('signalling frame rejected', name: 'voice', level: 900);
    }
    return signal;
  }

  // ── the interface ────────────────────────────────────────────────────────

  @override
  Future<void> send(String toUserId, Map<String, dynamic> payload) async {
    final client = _client;
    final envelopes = _envelopes;
    if (_live && client != null && envelopes != null) {
      try {
        await client.send(toUserId, envelopes.seal(toUserId, payload));
        return;
      } catch (e) {
        // One failed send is not a reason to abandon the socket — the SDK
        // reconnects on its own — but this particular offer still has to
        // arrive, so it goes the long way round.
        developer.log('metered send failed, using postgres', name: 'voice');
      }
    }
    await _fallback.send(toUserId, payload);
  }

  /// The ICE ladder for this call.
  ///
  /// Waits briefly for the welcome frame, because that is where Metered's relay
  /// credentials arrive and a mesh without a relay is the failure this whole
  /// change exists to fix. It waits *briefly*: a call on STUN now beats a call
  /// on TURN in fifteen seconds, and the controller re-climbs the ladder anyway
  /// when a rung fails.
  @override
  Future<List<Map<String, dynamic>>?> iceServers() async {
    if (!_welcome.isCompleted) {
      try {
        await _welcome.future.timeout(welcomeTimeout);
      } on TimeoutException {
        developer.log(
          'no welcome frame yet — ICE from the grant',
          name: 'voice',
        );
      }
    }
    final ice = _ice;
    if (ice != null && ice.isNotEmpty) return ice;
    // Nothing from Metered at all: ask the legacy endpoint, which is what an
    // older build would have called.
    return _fallback.iceServers();
  }

  /// The server's, not Metered's. Who may speak is a rule of the game.
  @override
  Future<bool> claimFloor() => _fallback.claimFloor();

  @override
  Future<void> releaseFloor() => _fallback.releaseFloor();

  @override
  Future<void> dispose() async {
    _disposed = true;
    _live = false;
    _giveUpOnWelcome();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _postgres?.cancel();
    _postgres = null;
    await _client?.dispose();
    _client = null;
    await _fallback.dispose();
    await _signals.close();
  }

  List<Map<String, dynamic>>? _serversFrom(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    return [
      for (final server in raw)
        if (server is Map) Map<String, dynamic>.from(server),
    ];
  }
}
