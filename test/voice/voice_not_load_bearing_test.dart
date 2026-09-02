import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/voice/voice_controller.dart';
import 'package:mafia_master/platform/voice/voice_engine.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';

import '../support/fake_backend.dart';
import '../support/fake_voice_engine.dart';

/// **The phase gate.** A whole online match, played with voice entirely
/// disabled, finishes normally.
///
/// Doc 10 §1.2 and the acceptance criterion for the voice phase: *"an online
/// match must be 100% playable with voice completely broken."* This is that
/// sentence as a test. The engine attached to it throws from every method it
/// has — no microphone, no ICE, no track, and an exception even from the
/// teardown that is supposed to clean up after the others — and the match is
/// driven through every phase from the deal to the result while it does.
///
/// What is asserted is not that voice recovers. It is that nothing above the
/// call can tell the difference: every command returns, every snapshot arrives,
/// and the room reaches `result`.
void main() {
  test('a match plays from the deal to the result with voice broken', () async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'reveal', phaseNumber: 0),
      players: roster(5),
      own: const OwnSeat(seat: 1, role: 'doctor'),
    );

    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    addTearDown(transport.dispose);

    final voice = VoiceController(
      engine: ExplodingVoiceEngine(),
      link: transport.voice!,
      rungTimeout: Duration.zero,
    );
    addTearDown(voice.dispose);

    // Exactly the wiring the app uses: the call watches the game, and the game
    // does not watch the call.
    final seen = <GamePhase>[];
    final sub = transport.watch().listen((snapshot) {
      seen.add(snapshot.phase);
      voice.apply(snapshot);
    });
    addTearDown(sub.cancel);

    await voice.start(
      selfSeat: transport.mySeat,
      peers: [for (var s = 0; s < 5; s++) VoicePeer(userId: 'u$s', seat: s)],
    );

    Future<void> phase(String name, {int number = 1, Map<String, dynamic> data = const {}}) async {
      backend.setState(roomState(phase: name, phaseNumber: number, publicData: data));
      await pumpEventQueue();
    }

    // ── the deal ────────────────────────────────────────────────────────
    await transport.confirmRevealed();

    // ── the night ───────────────────────────────────────────────────────
    await phase('night');
    await transport.submitNightAction(
      seat: 1,
      kind: NightActionKind.protect,
      targetSeat: 3,
    );

    // ── the morning ─────────────────────────────────────────────────────
    await phase('morning', data: {
      'morning': {'killedSeat': 4, 'trace': null},
    });

    // ── the day ─────────────────────────────────────────────────────────
    await phase('opening', data: {'openingSeat': 1});
    await transport.submitOpeningAccusation(seat: 1, targetSeat: 0);

    await phase('discuss');
    await transport.recordSpeaking(seat: 1, seconds: 30);
    backend.responses['send_whisper'] = {'id': 'w-1'};
    await transport.sendWhisper(fromSeat: 1, toSeat: 2, body: 'anything');

    // ── the ballot ──────────────────────────────────────────────────────
    await phase('vote');
    await transport.submitVote(seat: 1, targetSeat: 0);

    // ── the end ─────────────────────────────────────────────────────────
    await phase('result', data: {
      'outcome': 'town',
      'standings': [
        for (var s = 0; s < 5; s++)
          {'seat': s, 'role': s == 0 ? 'mafia' : 'citizen'},
      ],
    });

    expect(transport.snapshot.phase, equals(GamePhase.result));
    expect(seen, contains(GamePhase.night));
    expect(seen, contains(GamePhase.voting));

    // And the call is exactly where a broken call should be: nowhere.
    expect(voice.state.mode, equals(VoiceMode.text));
    expect(voice.state.microphoneLive, isFalse);
  });
}
