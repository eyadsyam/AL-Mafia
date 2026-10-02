// Standalone browser probe: the real project media engine, no game, no secrets
// in the output.
//
//   flutter build web -t tool/voice_runtime_probe.dart --output build/voice-probe
//     --base-href / [--dart-define-from-file=dart_defines.json]
//
// Two modes, chosen by the `role` query parameter the runner appends:
//   (none)  local — two engines in this page, envelopes passed hand to hand.
//           Proves the media stack. Proves nothing about Metered.
//   A / B   hosted — this page is *one* player, with its own Supabase identity
//           and its own browser profile, signalling through MeteredVoiceLink.
//           The two sides never share a page, because two clients that share a
//           page share an auth session and stop being two clients.
//
// Not a production entry point and never bundled into the app or the site.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'package:mafia_master/platform/voice/voice_engine.dart';
import 'package:mafia_master/platform/voice/webrtc_voice_engine.dart';
import 'package:mafia_master/transport/voice_envelope.dart';
import 'voice_probe_hosted.dart';

late final web.Element _result;

void _publish(Map<String, Object?> report) {
  _result.textContent = jsonEncode(report);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  _result = web.document.createElement('pre')..id = 'voice-runtime-result';
  web.document.body!.append(_result);
  _result.textContent = 'RUNNING';

  final query = Uri.parse(web.window.location.href).queryParameters;
  final role = query['role'];
  if (role == 'A' || role == 'B') {
    await _hosted(isHost: role == 'A', code: query['code']);
  } else {
    await _local();
  }
}

// ── hosted: one player, one browser, signalling over Metered ────────────────

Future<void> _hosted({required bool isHost, String? code}) async {
  final probe = HostedVoiceProbe(isHost: isHost, code: code);
  final engine = WebRtcVoiceEngine();
  final checks = <String, bool>{};
  final subscriptions = <StreamSubscription>[];
  var stage = 'hosted-authorization';
  String? failure;

  void require(String name, bool value) {
    checks[name] = value;
    if (!value) throw StateError(name);
  }

  try {
    // The runner needs the code to start the guest, and it needs it *before*
    // the host starts waiting for the guest to appear. Handed over in the DOM,
    // never logged, never written into the report below.
    await probe.open(onRoomCreated: (code) {
      web.document.body!.append(
        web.document.createElement('pre')
          ..id = 'voice-probe-code'
          ..textContent = code,
      );
    });
    require('metered', probe.link!.connected);
    require('distinctIdentities', probe.evidence['distinctIdentities'] == true);
    require('distinctAfterAuthorization',
        probe.evidence['distinctAfterAuthorization'] == true);
    require('rosterIsTwo', probe.evidence['rosterSize'] == 2);
    require('grant', probe.evidence['token'] == true);
    require('grantCarriesNoGameState',
        probe.evidence['grantCarriesNoGameState'] == true);

    stage = 'ice';
    final servers = await probe.link!.iceServers();
    require('iceReceived', servers != null && servers.isNotEmpty);
    final ice = IceConfig(VoiceRung.turn, servers!);
    // Only shapes are recorded. No urls, no usernames, no credentials.
    bool anyUrl(String scheme) => ice.servers.any(
        (server) => server['urls'].toString().contains(scheme));
    checks['iceHasStun'] = anyUrl('stun:');
    checks['iceHasTurn'] = anyUrl('turn:');
    checks['iceHasTurns'] = anyUrl('turns:');
    require('turnOffered', checks['iceHasTurn']! || checks['iceHasTurns']!);

    // Direct peer send with the existing envelope. No broadcast signalling.
    subscriptions.add(probe.link!.incoming.listen(
        (signal) => unawaited(engine.acceptSignal(signal.fromUserId, signal.payload))));
    subscriptions.add(engine.events.listen((event) {
      if (event is OutboundSignal) {
        unawaited(probe.link!.send(event.toUserId, event.payload));
      }
    }));

    stage = 'microphone';
    require('micGranted', await engine.acquireMicrophone());
    require('localTrack', engine.diagnostics.localAudioTracks == 1);

    stage = 'negotiation';
    await engine.setAudiblePeers({probe.peerId});
    require(
      'connected',
      await engine.connect(
        selfId: probe.link!.selfId,
        ice: ice,
        peers: [VoicePeer(userId: probe.peerId, seat: probe.peerSeat)],
        timeout: const Duration(seconds: 25),
      ),
    );

    stage = 'media';
    await engine.setMicrophoneLive(true);
    require('playout', await engine.resumePlayout());
    await Future<void>.delayed(const Duration(seconds: 4));
    await engine.sampleMediaStats();
    final trace = engine.diagnostics.peers.values.single;
    checks['offering'] = trace.offering;
    // Half of the negotiation booleans belong to one side only, so each is
    // recorded and only the ones this side owns are required.
    checks['offerCreated'] = trace.offerCreated;
    checks['offerSent'] = trace.offerSent;
    checks['offerReceived'] = trace.offerReceived;
    checks['remoteOfferSet'] = trace.remoteOfferSet;
    checks['answerCreated'] = trace.answerCreated;
    checks['answerSent'] = trace.answerSent;
    checks['answerReceived'] = trace.answerReceived;
    checks['remoteAnswerSet'] = trace.remoteAnswerSet;
    if (trace.offering) {
      require('offerLeg', trace.offerCreated && trace.offerSent);
      require('answerLeg', trace.answerReceived && trace.remoteAnswerSet);
    } else {
      require('offerLeg', trace.offerReceived && trace.remoteOfferSet);
      require('answerLeg', trace.answerCreated && trace.answerSent);
    }
    require('sender', trace.audioSenders == 1);
    require('direction', trace.direction?.toLowerCase().contains('sendrecv') == true);
    require('remoteTrack', trace.trackReceived && trace.remoteAudioTracks > 0);
    require('audible', trace.audible && trace.remoteTrackEnabled);
    require('receivedRtp', trace.receivedPackets > 0);
    require('sentRtp', trace.sentPackets > 0);
    // `RTCPeerConnectionStateConnected` — compared case-insensitively, because
    // the enum's own spelling is not the contract.
    require('pcConnected',
        trace.connectionState?.toLowerCase().contains('connected') == true);
    require('iceConnected',
        trace.iceConnectionState?.toLowerCase().contains('connected') == true ||
        trace.iceConnectionState?.toLowerCase().contains('completed') == true);
    require('signalingStable',
        trace.signalingState?.toLowerCase().contains('stable') == true);
    checks['candidatesQueuedThenApplied'] =
        trace.candidatesQueued == 0 || trace.candidatesApplied > 0;
    require('noRejectedCandidates', trace.candidatesRejected == 0);

    stage = 'mute';
    await engine.setMicrophoneLive(false);
    require('muteStopsLocalTrack', !engine.diagnostics.localTrackEnabled);
    await engine.setMicrophoneLive(true);
    require('unmuteRestoresLocalTrack', engine.diagnostics.localTrackEnabled);
    require('senderSurvivesMute',
        engine.diagnostics.peers.values.single.audioSenders == 1);

    stage = 'receive-revocation';
    await engine.setAudiblePeers({});
    require('receiveDisabled',
        !engine.diagnostics.peers.values.single.remoteTrackEnabled);
  } catch (_) {
    // Never serialise a media exception: it routinely quotes the SDP it choked
    // on. The stage name and the trace's own failure category are the report.
    failure = stage;
  } finally {
    // Read before dispose: a disposed engine has no peers left to describe.
    final trace = engine.diagnostics.report();
    final candidateTypes = [
      for (final peer in engine.diagnostics.peers.values) peer.candidatePairType,
    ];
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await engine.dispose();
    try {
      await probe.dispose();
    } catch (_) {
      checks['cleanup'] = false;
      failure ??= 'cleanup';
    }
    final safe = Map<String, Object?>.from(probe.evidence);
    _publish({
      'role': isHost ? 'A' : 'B',
      'status': failure == null ? 'PASS' : 'FAIL',
      'failedStage': failure,
      'checks': checks,
      'evidence': safe,
      'candidatePairTypes': candidateTypes,
      'trace': _redact(trace, probe.selfId, probe.peerId),
      'humanAudibility': 'NOT VERIFIED',
    });
  }
}

/// Ids never reach the report, not even inside a formatted trace.
String _redact(String trace, String selfId, String peerId) {
  var out = trace;
  if (selfId.length > 8) out = out.replaceAll(selfId, 'probe-self');
  if (peerId.length > 8) out = out.replaceAll(peerId, 'probe-peer');
  return out;
}

// ── local: both engines in this page, no network beyond STUN ────────────────

Future<void> _local() async {
  final a = WebRtcVoiceEngine();
  final b = WebRtcVoiceEngine();
  final ea = VoiceEnvelopes(sessionId: 'probe', selfId: 'a', isSeated: (id) => id == 'b');
  final eb = VoiceEnvelopes(sessionId: 'probe', selfId: 'b', isSeated: (id) => id == 'a');
  final subscriptions = <StreamSubscription>[];
  final checks = <String, bool>{};
  var stage = 'microphone';
  String? failure;

  void require(String name, bool value) {
    checks[name] = value;
    if (!value) throw StateError(name);
  }

  try {
    subscriptions.add(a.events.listen((event) {
      if (event is OutboundSignal) {
        final signal = eb.open('a', ea.seal('b', event.payload));
        if (signal != null) unawaited(b.acceptSignal('a', signal.payload));
      }
    }));
    subscriptions.add(b.events.listen((event) {
      if (event is OutboundSignal) {
        final signal = ea.open('b', eb.seal('a', event.payload));
        if (signal != null) unawaited(a.acceptSignal('b', signal.payload));
      }
    }));
    require('micA', await a.acquireMicrophone());
    require('micB', await b.acquireMicrophone());
    await a.setAudiblePeers({'b'});
    await b.setAudiblePeers({'a'});

    stage = 'negotiation';
    final connectingA = a.connect(
        selfId: 'a',
        ice: IceConfig.stun,
        peers: [const VoicePeer(userId: 'b', seat: 1)],
        timeout: const Duration(seconds: 15));
    await Future<void>.delayed(const Duration(seconds: 1));
    final connectingB = b.connect(
        selfId: 'b',
        ice: IceConfig.stun,
        peers: [const VoicePeer(userId: 'a', seat: 0)],
        timeout: const Duration(seconds: 15));
    require('connectedA', await connectingA);
    require('connectedB', await connectingB);

    stage = 'media';
    await a.setMicrophoneLive(true);
    await b.setMicrophoneLive(true);
    require('playoutA', await a.resumePlayout());
    require('playoutB', await b.resumePlayout());
    await Future<void>.delayed(const Duration(seconds: 3));
    await a.sampleMediaStats();
    await b.sampleMediaStats();
    for (final entry in {'A': a, 'B': b}.entries) {
      final trace = entry.value.diagnostics.peers.values.single;
      require('sender${entry.key}', trace.audioSenders == 1);
      require('remoteTrack${entry.key}', trace.trackReceived);
      require('audible${entry.key}', trace.audible && trace.remoteTrackEnabled);
      require('receivedRtp${entry.key}', trace.receivedPackets > 0);
      require('sentRtp${entry.key}', trace.sentPackets > 0);
    }

    stage = 'receive-revocation';
    await a.setAudiblePeers({});
    require('receiveDisabled', !a.diagnostics.peers.values.single.remoteTrackEnabled);
  } catch (_) {
    failure = stage;
  } finally {
    final traceA = a.diagnostics.report();
    final traceB = b.diagnostics.report();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await a.dispose();
    await b.dispose();
    _publish({
      'role': 'local',
      'status': failure == null ? 'PASS' : 'FAIL',
      'failedStage': failure,
      'checks': checks,
      'A': traceA,
      'B': traceB,
      'humanAudibility': 'NOT VERIFIED',
      'meteredRouting': 'NOT VERIFIED',
    });
  }
}
