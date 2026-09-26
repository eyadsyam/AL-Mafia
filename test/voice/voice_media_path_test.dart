import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/voice/voice_controller.dart';
import 'package:mafia_master/platform/voice/voice_diagnostics.dart';
import 'package:mafia_master/platform/voice/voice_engine.dart';
import 'package:mafia_master/platform/voice/webrtc_voice_engine.dart';
import 'package:mafia_master/transport/game_snapshot.dart';

import '../support/fake_voice_engine.dart';

/// The media path, as far as a test host without a media stack can follow it.
///
/// ## What this file can and cannot prove
///
/// Everything between the phase and `createPeerConnection` is ordinary Dart and
/// is tested here for real: which ICE servers reach the engine, whether a day
/// admits anybody, whether signals leave in the order they were made, what a
/// call does when a rung times out and a peer connects afterwards.
///
/// Everything past that point is native. There is no `RTCPeerConnection` on a
/// test host, so the candidate queue, the lazily-created answering connection
/// and the transceiver direction cannot be exercised here and are not claimed
/// to be — see the runtime section of the report. What *is* asserted about the
/// real engine is the part that matters most when the platform is missing: it
/// does not throw, and it writes down why.
void main() {
  // The real engine reaches for method channels the moment it is asked for a
  // microphone. A binding makes those answer null instead of throwing out of
  // the zone, which is the closest a test host gets to "a platform with no
  // WebRTC" — the state doc 10 §1.2 says the game must survive.
  TestWidgetsFlutterBinding.ensureInitialized();

  final peers = [
    const VoicePeer(userId: 'u0', seat: 0),
    const VoicePeer(userId: 'u1', seat: 1),
    const VoicePeer(userId: 'u2', seat: 2),
  ];

  GameSnapshot snapshotIn(
    GamePhase phase, {
    int? speaker,
    DiscussionMode discussion = DiscussionMode.structured,
  }) => GameSnapshot(
    public: PublicMatchView(phase: phase, dayNumber: 1, players: const []),
    settings: MatchSettings(discussionMode: discussion),
    activeSpeakerSeat: speaker,
    viewerSeat: 1,
  );

  const relay = [
    {'urls': 'stun:stun.metered.example:80'},
    {
      'urls': 'turn:relay.metered.example:80',
      'username': 'u',
      'credential': 'c',
    },
    {'urls': 'turns:relay.metered.example:443'},
  ];

  group("Metered's relay reaches the thing that builds connections", () {
    test('a TURN entry from the link is handed to connect()', () async {
      // The whole point of the migration: TURN credentials arrive on Metered's
      // welcome frame, and it is only worth anything if they end up in the
      // RTCConfiguration. Nothing between the link and `connect` may drop them.
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')..ice = relay;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start(selfSeat: 1, peers: peers);

      expect(
        engine.attemptedConfigs,
        hasLength(1),
        reason: 'one rung when the server answered, not two',
      );
      final servers = engine.attemptedConfigs.single.servers;
      expect(
        servers.any((s) => '${s['urls']}'.startsWith('turn:')),
        isTrue,
        reason: 'the relay must reach createPeerConnection',
      );
      expect(engine.attemptedConfigs.single.rung, equals(VoiceRung.turn));
    });

    test('a STUN-only answer is re-asked on the next climb', () async {
      // The welcome frame races the microphone permission dialog, so the first
      // climb can legitimately see STUN only. Caching that for the match is how
      // a build with working TURN never uses it.
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')
        ..ice = [
          {'urls': 'stun:stun.l.google.com:19302'},
        ];
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start(selfSeat: 1, peers: peers);
      expect(engine.attemptedConfigs.last.rung, equals(VoiceRung.stun));

      // The socket comes up; the welcome frame brings the relay.
      link.ice = relay;
      await controller.apply(snapshotIn(GamePhase.night));
      await controller.apply(snapshotIn(GamePhase.morning));

      expect(
        engine.attemptedConfigs.last.rung,
        equals(VoiceRung.turn),
        reason: 'the relay must be picked up once it exists',
      );
    });

    test('a relay that is already known is not re-fetched', () async {
      final engine = FakeVoiceEngine();
      final link = _CountingIceLink(selfId: 'u1')..ice = relay;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start(selfSeat: 1, peers: peers);
      await controller.apply(snapshotIn(GamePhase.night));
      await controller.apply(snapshotIn(GamePhase.morning));

      expect(
        link.fetches,
        equals(1),
        reason: 'one fetch for the match once a relay is in hand',
      );
    });
  });

  group('who is audible', () {
    test('an open day admits every living peer', () async {
      // The prime suspect for a silent room that looks connected: if the
      // receiving policy admits nobody, every remote track arrives disabled and
      // the call is mute with every other light green.
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);
      await controller.start(selfSeat: 1, peers: peers);

      await controller.apply(
        snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free),
      );

      expect(engine.audiblePeers, equals({'u0', 'u1', 'u2'}));
      expect(
        engine.audiblePeers,
        isNotEmpty,
        reason: 'A must consider B audible in a free day discussion',
      );
    });

    test('the night still admits nobody', () async {
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);
      await controller.start(selfSeat: 1, peers: peers);

      await controller.apply(snapshotIn(GamePhase.night));

      expect(engine.audiblePeers, isEmpty);
      expect(engine.microphoneLive, isFalse);
      expect(controller.state.mode, equals(VoiceMode.off));
    });

    test(
      'a structured day admits only the seat that holds the floor',
      () async {
        final engine = FakeVoiceEngine();
        final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
        final controller = VoiceController(
          engine: engine,
          link: link,
          rungTimeout: Duration.zero,
        );
        addTearDown(controller.dispose);
        await controller.start(selfSeat: 1, peers: peers);

        await controller.apply(snapshotIn(GamePhase.discussion, speaker: 2));

        expect(
          engine.audiblePeers,
          equals({'u2'}),
          reason: 'V4 — one voice at a time, decided by the server',
        );
      },
    );

    test('a call that comes up between snapshots is not left silent', () async {
      // `setAudiblePeers` used to be called only from `apply`. A mesh that came
      // up in the gap between two snapshots therefore delivered its tracks with
      // the engine still admitting nobody, and stayed mute until the phase
      // happened to change.
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);
      await controller.start(selfSeat: 1, peers: peers);

      await controller.apply(
        snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free),
      );
      engine.audiblePeers = const {};

      // A new player joins: the mesh is rebuilt, with no snapshot in between.
      link.peers = [...peers, const VoicePeer(userId: 'u3', seat: 3)];
      await controller.apply(
        snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free),
      );

      expect(
        engine.audiblePeers,
        isNotEmpty,
        reason: 'the policy is re-applied on every climb',
      );
    });
  });

  group('signalling leaves in the order it was made', () {
    test('a slow offer still precedes its candidates', () async {
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')
        // The offer is held; the candidates behind it are not. Unchained, they
        // overtake it and arrive for a negotiation the far end has not heard of.
        ..sendDelays = const {'offer': 20};
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);
      await controller.start(selfSeat: 1, peers: peers);

      engine
        ..emit(const OutboundSignal('u2', {'kind': 'offer'}))
        ..emit(const OutboundSignal('u2', {'kind': 'candidate', 'n': 1}))
        ..emit(const OutboundSignal('u2', {'kind': 'candidate', 'n': 2}));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        link.sentPayloads.map((p) => p['kind']).toList(),
        equals(['offer', 'candidate', 'candidate']),
      );
      expect(
        link.sentPayloads.map((p) => p['n']).whereType<int>().toList(),
        equals([1, 2]),
      );
    });

    test('one slow peer does not hold up another', () async {
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')
        ..sendDelays = const {'offer': 30};
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);
      await controller.start(selfSeat: 1, peers: peers);

      engine
        ..emit(const OutboundSignal('u0', {'kind': 'offer'}))
        ..emit(const OutboundSignal('u2', {'kind': 'candidate'}));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        link.sent,
        equals(['u2']),
        reason: 'the chains are per peer, not global',
      );
    });
  });

  group('a rung that ran out of time', () {
    test('does not tear the mesh down', () async {
      // It used to. A rung timing out closed every connection that was still
      // negotiating, so a call that would have connected at nine seconds could
      // never connect at all — there was nothing left to report it.
      final engine = FakeVoiceEngine(workingRungs: const {});
      final link = FakeVoiceLink(selfId: 'u1');
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start(selfSeat: 1, peers: peers);

      expect(controller.state.mode, equals(VoiceMode.text));
      expect(
        engine.teardowns,
        isZero,
        reason: 'the connections are left to finish converging',
      );
    });

    test('is promoted back to live by a peer that connects late', () async {
      final engine = FakeVoiceEngine(workingRungs: const {});
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start(selfSeat: 1, peers: peers);
      await controller.apply(
        snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free),
      );
      expect(controller.state.mode, equals(VoiceMode.text));

      engine.emit(const PeerConnected('u2'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.mode, equals(VoiceMode.live));
      expect(
        engine.audiblePeers,
        isNotEmpty,
        reason: 'the policy is applied to the call that just came up',
      );
      expect(
        engine.microphoneLive,
        isTrue,
        reason: 'an open discussion with the call live means a live mic',
      );
    });

    test('the night is not promoted back to live', () async {
      // V6. A straggler connecting during a night is not a reason to have a
      // call during one.
      final engine = FakeVoiceEngine(workingRungs: const {});
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start(selfSeat: 1, peers: peers);
      await controller.apply(snapshotIn(GamePhase.night));

      engine.emit(const PeerConnected('u2'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.mode, equals(VoiceMode.off));
      expect(engine.audiblePeers, isEmpty);
      expect(engine.microphoneLive, isFalse);
    });
  });

  group('the diagnostics', () {
    test('say nothing about the table and nothing about a network', () {
      // Doc 05 does not stop applying because a line is labelled "debug". The
      // report may hold booleans, counts and enum names, and the assertion is
      // on the rendered text because that is what a player would paste.
      final d = VoiceDiagnostics()
        ..micRequested = true
        ..micGranted = true
        ..localAudioTracks = 1
        ..describeIce(const [
          {'urls': 'stun:stun.l.google.com:19302'},
          {
            'urls': 'turn:relay.metered.example:80',
            'username': 'super-secret-user',
            'credential': 'super-secret-credential',
          },
        ]);
      d.peer('u2')
        ..offering = true
        ..offerSent = true
        ..candidatePairType = 'relay';

      final text = d.report().toLowerCase();
      for (final forbidden in [
        'super-secret-user',
        'super-secret-credential',
        'v=0',
        'sdp',
        'candidate:',
        'mafia',
        'doctor',
        'detective',
        'citizen',
        'seat',
        'role',
        'seed',
        'token',
      ]) {
        expect(
          text.contains(forbidden),
          isFalse,
          reason: '"$forbidden" must not appear in a diagnostics report',
        );
      }
      expect(text, contains('turn'));
      expect(text, contains('relay'));
    });

    test('tell a call with nowhere to play from a call nobody joined', () {
      // The web fault this line exists to name: the connection is up, the
      // track has arrived, the policy admits the peer, and the browser has no
      // element to play it out of. Every other line in the trace reads PASS,
      // which is why the trace needs this one.
      final d = VoiceDiagnostics()
        ..micRequested = true
        ..micGranted = true
        ..audioSessionConfigured = true;
      d.peer('u2')
        ..connectionCreated = true
        ..trackReceived = true
        ..remoteAudioTracks = 1
        ..audible = true;

      expect(d.report(), contains('playout attached     FAIL'));
      d.peer('u2').playoutAttached = true;
      expect(d.report(), contains('playout attached     PASS'));
    });

    test('name the first thing that is not PASS', () {
      final d = VoiceDiagnostics()
        ..micRequested = true
        ..micGranted = true;
      d.peer('u2')
        ..offering = true
        ..connectionCreated = true
        ..offerCreated = true
        ..offerSent = true;

      final lines = d.report().split('\n');
      final firstFail = lines.firstWhere((l) => l.contains('FAIL'));
      expect(
        firstFail,
        contains('audio session'),
        reason:
            'the chain is read top to bottom and the first FAIL is the '
            'bug; everything under it is a symptom',
      );
    });
  });

  group('the real engine, with no media stack under it', () {
    test('fails quietly and writes down why', () async {
      // There is no `RTCPeerConnection` on a test host. What must hold anyway
      // is non-negotiable 5: nothing here may throw into a caller, whatever the
      // platform does.
      //
      // Reported as a desktop platform, which is the honest description of a
      // Dart test host: no Android AudioManager and no iOS audio session, so
      // the engine takes the branch that configures neither. Pretending to be a
      // phone here would only exercise flutter_webrtc's method channels against
      // a binding that has none.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final engine = WebRtcVoiceEngine();
      addTearDown(engine.dispose);

      final granted = await engine.acquireMicrophone();
      expect(granted, isFalse);

      final up = await engine.connect(
        selfId: 'u1',
        ice: IceConfig.stun,
        peers: peers,
        timeout: const Duration(milliseconds: 20),
      );
      expect(up, isFalse);

      // And the ICE it was handed is on the record, which is the question that
      // could not be answered before: did the relay reach the connection?
      expect(engine.diagnostics.iceServerCount, equals(1));
      expect(engine.diagnostics.hasStun, isTrue);
      expect(engine.diagnostics.hasTurn, isFalse);

      // A signal for a peer that is not at the table builds nothing, whatever
      // the transport let through.
      await engine.acceptSignal('stranger', {'kind': 'offer', 'sdp': 'v=0'});
      expect(engine.diagnostics.peers.containsKey('stranger'), isFalse);

      await engine.setAudiblePeers({'u2'});
      await engine.setMicrophoneLive(true);
      await engine.teardown();
    });
  });
}

/// A link that counts how often the ICE ladder was asked for.
class _CountingIceLink extends FakeVoiceLink {
  _CountingIceLink({super.selfId});

  int fetches = 0;

  @override
  Future<List<Map<String, dynamic>>?> iceServers() async {
    fetches++;
    return ice;
  }
}
