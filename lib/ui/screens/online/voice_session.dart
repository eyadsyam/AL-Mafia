import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/voice/voice_controller.dart';
import '../../../platform/voice/voice_engine.dart';
import '../../../platform/voice/webrtc_voice_engine.dart';
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
final voiceControllerProvider = Provider<VoiceController?>((ref) {
  final session = ref.watch(onlineSessionProvider);
  final transport = session.transport;
  final link = transport?.voice;
  if (transport == null || link == null) return null;

  final controller = VoiceController(
    engine: ref.read(voiceEngineFactoryProvider)(),
    link: link,
  );

  // The call watches the game. Nothing here is awaited by the phase flow, and
  // a failure inside `apply` cannot reach it — see [VoiceController].
  final subscription = transport.watch().listen(controller.apply);

  unawaited(controller.start(
    selfSeat: transport.mySeat,
    peers: link.peers,
  ));

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
