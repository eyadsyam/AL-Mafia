import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/voice/voice_controller.dart';
import '../../../platform/voice/voice_engine.dart';
import '../../../platform/voice/webrtc_voice_engine.dart';
import '../../theme/design_tokens.dart';
import 'online_session.dart';

/// How a call is made.
///
/// A provider so a widget test can hand the app a [NullVoiceEngine] and drive
/// every screen with voice that never works — which is the state doc 10 §1.2
/// says the whole game must survive, and therefore the state most worth being
/// able to reproduce on demand.
final voiceEngineFactoryProvider = Provider<VoiceEngine Function()>(
  (ref) => WebRtcVoiceEngine.new,
);

/// The call for the room this device is in, or null when there is not one.
///
/// Null offline, null before a room is joined, and null in every test that did
/// not ask for a call. Every consumer treats null as "no voice", which is the
/// same thing they do with a call that failed — so the two cases need no
/// separate handling anywhere above.
/// How often the call samples local WebRTC audio levels for the speaking ring.
///
/// A provider for the same reason [onlineHeartbeatProvider] is one: a widget
/// test overrides it to [Duration.zero] so no periodic timer outlives the
/// frame it pumped.
final voiceStatsIntervalProvider = Provider<Duration>(
  (ref) => MafiaTiming.voiceStatsSample,
);

final voiceControllerProvider = Provider<VoiceController?>((ref) {
  final transport = ref.watch(onlineSessionProvider.select((s) => s.transport));
  final link = transport?.voice;
  if (transport == null || link == null) return null;

  final controller = VoiceController(
    engine: ref.read(voiceEngineFactoryProvider)(),
    link: link,
    statsInterval: ref.read(voiceStatsIntervalProvider),
  );

  // Apply the room's current policy before the first climb. `watch()` does
  // replay the snapshot, but an async stream listener does not wait for
  // `apply` before the independently-started call reaches WebRTC. On web that
  // race left the first mesh with the controller's default muted policy; a
  // later room-setting toggle supplied another snapshot and appeared to
  // "fix" voice. Skip the replay here, initialise once in order, then listen
  // to every newer snapshot.
  final subscription = transport.watch().skip(1).listen((snapshot) {
    controller.blockedUsers = transport.blockedUserIds;
    unawaited(controller.apply(snapshot));
  });
  unawaited(() async {
    controller.blockedUsers = transport.blockedUserIds;
    await controller.apply(transport.snapshot);
    await controller.start(selfSeat: transport.mySeat, peers: link.peers);
    // Complete the first media cycle without waiting for a settings toggle or
    // the retry control. Native uses this to re-apply the final microphone
    // state after negotiation; web also retries every remote audio sink and
    // leaves the gesture bridge armed only when the browser itself blocks
    // autoplay.
    await controller.enableAudio();
  }());

  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.dispose());
  });

  return controller;
});

/// What the voice controls render.
///
/// A stream provider rather than a field on the match state, because voice is
/// not part of the match: a widget that wants it asks for it, and a widget that
/// does not never learns that it exists.
final voiceStateProvider = StreamProvider<VoiceState?>((ref) {
  final controller = ref.watch(voiceControllerProvider);
  if (controller == null) return Stream.value(null);
  return controller.watch();
});
