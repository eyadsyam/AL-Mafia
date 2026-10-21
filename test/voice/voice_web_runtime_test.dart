@TestOn('browser')
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/voice/voice_engine.dart';
import 'package:mafia_master/platform/voice/webrtc_voice_engine.dart';
import 'package:mafia_master/transport/voice_envelope.dart';

/// Actual browser RTCPeerConnections, with Chrome's synthetic microphone.
/// Proves RTP delivery, not that a human heard a loudspeaker or Metered routing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'late peer recovers a lost offer and exchanges real audio RTP',
    () async {
      final a = WebRtcVoiceEngine();
      final b = WebRtcVoiceEngine();
      final ea = VoiceEnvelopes(
        sessionId: 'runtime-session',
        selfId: 'a',
        isSeated: (id) => id == 'b',
      );
      final eb = VoiceEnvelopes(
        sessionId: 'runtime-session',
        selfId: 'b',
        isSeated: (id) => id == 'a',
      );
      final subscriptions = <StreamSubscription>[];
      subscriptions.add(
        a.events.listen((event) {
          if (event is OutboundSignal) {
            final signal = eb.open('a', ea.seal('b', event.payload));
            if (signal != null) unawaited(b.acceptSignal('a', signal.payload));
          }
        }),
      );
      subscriptions.add(
        b.events.listen((event) {
          if (event is OutboundSignal) {
            final signal = ea.open('b', eb.seal('a', event.payload));
            if (signal != null) unawaited(a.acceptSignal('b', signal.payload));
          }
        }),
      );
      addTearDown(() async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        await a.dispose();
        await b.dispose();
      });
      expect(await a.acquireMicrophone(), isTrue);
      expect(await b.acquireMicrophone(), isTrue);
      await a.setAudiblePeers({'b'});
      await b.setAudiblePeers({'a'});
      final connectingA = a.connect(
        selfId: 'a',
        ice: const IceConfig(VoiceRung.stun, []),
        peers: [const VoicePeer(userId: 'b', seat: 1)],
        timeout: const Duration(seconds: 15),
      );
      // Intentionally drop A's first negotiation while B has no admitted peers.
      await Future<void>.delayed(const Duration(seconds: 1));
      final connectingB = b.connect(
        selfId: 'b',
        ice: const IceConfig(VoiceRung.stun, []),
        peers: [const VoicePeer(userId: 'a', seat: 0)],
        timeout: const Duration(seconds: 15),
      );
      expect(await connectingA, isTrue, reason: a.diagnostics.report());
      expect(await connectingB, isTrue, reason: b.diagnostics.report());
      await a.setMicrophoneLive(true);
      await b.setMicrophoneLive(true);
      await a.resumePlayout();
      await b.resumePlayout();
      await Future<void>.delayed(const Duration(seconds: 3));
      await a.sampleMediaStats();
      await b.sampleMediaStats();
      for (final engine in [a, b]) {
        final trace = engine.diagnostics.peers.values.single;
        expect(trace.audioSenders, 1);
        expect(trace.trackReceived, isTrue);
        expect(trace.audible, isTrue);
        expect(trace.playoutAttached, isTrue);
        expect(
          trace.receivedPackets,
          greaterThan(0),
          reason: engine.diagnostics.report(),
        );
        expect(trace.sentPackets, greaterThan(0));
      }
      // A silenced seat (audit M2-34, M2-100): the controller turns its
      // microphone off, and the table then hears nothing from it.
      Future<double> loudestFromA() async {
        var loudest = 0.0;
        for (var i = 0; i < 8; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await b.sampleMediaStats();
          final level = b.speakingLevels['a'] ?? 0;
          if (level > loudest) loudest = level;
        }
        return loudest;
      }

      expect(await loudestFromA(), greaterThan(0), reason: 'A is heard first');
      await a.setMicrophoneLive(false);
      expect(a.diagnostics.localTrackEnabled, isFalse);
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(
        await loudestFromA(),
        lessThan(0.001),
        reason: b.diagnostics.report(),
      );
      await a.setMicrophoneLive(true);

      await a.setAudiblePeers({});
      expect(a.diagnostics.peers.values.single.remoteTrackEnabled, isFalse);
      await a.teardown();
      expect(a.diagnostics.peers, isEmpty);
      expect(a.diagnostics.localTrackEnabled, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
