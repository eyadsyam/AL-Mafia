import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/engine/voice_policy.dart';
import 'package:mafia_master/platform/voice/voice_controller.dart';
import 'package:mafia_master/platform/voice/voice_engine.dart';
import 'package:mafia_master/transport/game_snapshot.dart';

import '../support/fake_voice_engine.dart';

/// V1–V9 of doc 11 §7 — the call, and every way it is allowed to fail.
///
/// Every test in this file ends the same way whatever it did to the microphone:
/// the game state it was handed is untouched. That is the phase gate, doc 10
/// §1.2, and it is why the assertions are so often about what did *not* happen.
void main() {
  final peers = [
    const VoicePeer(userId: 'u0', seat: 0),
    const VoicePeer(userId: 'u1', seat: 1),
    const VoicePeer(userId: 'u2', seat: 2),
  ];

  GameSnapshot snapshotIn(
    GamePhase phase, {
    int? speaker,
    DiscussionMode discussion = DiscussionMode.structured,
  }) =>
      GameSnapshot(
        public: PublicMatchView(phase: phase, dayNumber: 1, players: const []),
        settings: MatchSettings(discussionMode: discussion),
        activeSpeakerSeat: speaker,
        viewerSeat: 1,
      );

  Future<(VoiceController, FakeVoiceEngine, FakeVoiceLink)> connected({
    bool microphone = true,
    Set<VoiceRung>? rungs,
    IceConfig? relay,
  }) async {
    final engine = FakeVoiceEngine(
      microphonePresent: microphone,
      workingRungs: rungs,
    );
    final link = FakeVoiceLink(selfId: 'u1');
    final controller = VoiceController(
      engine: engine,
      link: link,
      relay: relay,
      rungTimeout: Duration.zero,
    );
    addTearDown(controller.dispose);
    await controller.start(selfSeat: 1, peers: peers);
    return (controller, engine, link);
  }

  group('V1 — the microphone is refused', () {
    test('the call runs anyway, receive-only', () async {
      final (controller, engine, _) = await connected(microphone: false);

      expect(controller.state.mode, equals(VoiceMode.live),
          reason: 'a player with no microphone still hears the room');
      expect(controller.state.microphoneAvailable, isFalse);
      expect(engine.connections, equals(1));
    });

    test('and is told once, then never again', () async {
      final engine = FakeVoiceEngine(microphonePresent: false);
      final link = FakeVoiceLink(selfId: 'u1');
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      final notices = <bool>[];
      controller.watch().listen((s) => notices.add(s.receiveOnlyNotice));

      await controller.start(selfSeat: 1, peers: peers);
      // A whole night and back: the ladder is climbed again, and the
      // permission is not asked for again.
      await controller.apply(snapshotIn(GamePhase.night));
      await controller.apply(snapshotIn(GamePhase.morning));
      await Future<void>.delayed(Duration.zero);

      expect(notices.where((n) => n).length, equals(1),
          reason: 'V1 — told once, calmly, then never again');
    });
  });

  group('V2 — there is no microphone at all', () {
    test('is the same case, and the same outcome', () async {
      // The platform cannot tell a refused permission from absent hardware
      // without asking a question the player did not agree to answer, so the
      // app does not try: both arrive as false and both mean receive-only.
      final (controller, _, _) = await connected(microphone: false);
      await controller.apply(snapshotIn(GamePhase.discussion, speaker: 1));

      expect(controller.state.microphoneLive, isFalse,
          reason: 'holding the floor with no microphone is still silence');
      expect(controller.state.mode, equals(VoiceMode.live));
    });
  });

  group('V3 — STUN and TURN both fail', () {
    test('this player goes to text mode', () async {
      final (controller, engine, _) = await connected(rungs: const {});

      expect(controller.state.mode, equals(VoiceMode.text));
      expect(controller.state.rung, equals(VoiceRung.text));
      expect(engine.attempted, equals([VoiceRung.stun]),
          reason: 'no relay was configured, so the ladder has two rungs');
    });

    test('the relay is tried before text, when there is one', () async {
      final (controller, engine, _) = await connected(
        rungs: const {VoiceRung.turn},
        relay: const IceConfig(VoiceRung.turn, [
          {'urls': 'turn:example.test'}
        ]),
      );

      expect(engine.attempted, equals([VoiceRung.stun, VoiceRung.turn]));
      expect(controller.state.rung, equals(VoiceRung.turn));
      expect(controller.state.mode, equals(VoiceMode.live));
    });

    test('and the match is unaffected', () async {
      final (controller, _, _) = await connected(rungs: const {});
      final before = snapshotIn(GamePhase.discussion, speaker: 2);

      await controller.apply(before);

      // The snapshot is the game. Nothing in this file may write to it, and
      // the assertion is that the object handed in came back untouched.
      expect(before.phase, equals(GamePhase.discussion));
      expect(before.activeSpeakerSeat, equals(2));
      expect(controller.state.mode, equals(VoiceMode.text));
    });
  });

  group('V4 — speaking out of turn', () {
    test('a seat that does not hold the floor is hard-muted', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(snapshotIn(GamePhase.discussion, speaker: 2));

      expect(engine.microphoneLive, isFalse);
      expect(controller.state.policy, equals(MicPolicy.activeSpeakerOnly));
    });

    test('and everybody else silences their track too', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(snapshotIn(GamePhase.discussion, speaker: 2));

      expect(engine.audiblePeers, equals({'u2'}),
          reason: 'a mesh has no server in the media path, so the drop happens '
              'at every ear');
    });

    test('the floor is a request to the server, never a local decision', () async {
      final (controller, engine, link) = await connected();
      link.grantFloor = false;

      expect(await controller.requestFloor(), isFalse);
      expect(link.claims, equals(1));
      expect(engine.microphoneLive, isFalse,
          reason: 'a refused claim must not unmute anything');
    });

    test('and the microphone opens only once the server has said so', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(snapshotIn(GamePhase.discussion, speaker: 1));

      expect(engine.microphoneLive, isTrue);
      expect(controller.state.microphoneLive, isTrue);
    });
  });

  group('V5 — the active speaker disappears', () {
    test('the client stops publishing the moment the floor moves', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(snapshotIn(GamePhase.discussion, speaker: 1));
      expect(engine.microphoneLive, isTrue);

      // The server's grant lapsed and it gave the floor to somebody else. The
      // client learns about it the way it learns everything: a snapshot.
      await controller.apply(snapshotIn(GamePhase.discussion, speaker: 2));

      expect(engine.microphoneLive, isFalse);
      expect(engine.audiblePeers, equals({'u2'}));
    });

    test('an empty floor leaves everyone muted and the control offered', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(snapshotIn(GamePhase.discussion));

      expect(engine.microphoneLive, isFalse);
      expect(engine.audiblePeers, isEmpty);
      expect(controller.state.canRequestFloor, isTrue);
    });
  });

  group('V6 — the night', () {
    test('voice is torn down, not merely muted', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(snapshotIn(GamePhase.night));

      expect(engine.teardowns, greaterThan(0));
      expect(controller.state.mode, equals(VoiceMode.off));
      expect(controller.state.rung, isNull);
    });

    test('a signal arriving during the night is refused', () async {
      final (controller, engine, link) = await connected();
      await controller.apply(snapshotIn(GamePhase.night));

      link.deliver('u2');
      await Future<void>.delayed(Duration.zero);

      expect(engine.accepted, isEmpty,
          reason: 'V6 — a connection during the night is impossible, not '
              'merely unwelcome');
    });

    test('the whole private stretch is dark, reveal included', () async {
      final (controller, engine, _) = await connected();

      for (final phase in [
        GamePhase.distributing,
        GamePhase.preNightLobby,
        GamePhase.night,
        GamePhase.nightResolving,
      ]) {
        await controller.apply(snapshotIn(phase));
        expect(controller.state.mode, equals(VoiceMode.off), reason: '$phase');
        expect(engine.microphoneLive, isFalse, reason: '$phase');
      }
    });

    test('and it comes back afterwards', () async {
      final (controller, engine, link) = await connected();
      await controller.apply(snapshotIn(GamePhase.night));

      await controller.apply(snapshotIn(GamePhase.morning));

      expect(controller.state.mode, equals(VoiceMode.live));
      expect(engine.connections, equals(2), reason: 'the ladder is climbed again');

      link.deliver('u2');
      await Future<void>.delayed(Duration.zero);
      expect(engine.accepted, equals(['u2']));
    });
  });

  group('V8 — the call collapses', () {
    test('an engine that throws at everything cannot fail a phase', () async {
      final controller = VoiceController(
        engine: ExplodingVoiceEngine(),
        link: FakeVoiceLink(selfId: 'u1'),
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start(selfSeat: 1, peers: peers);
      for (final phase in GamePhase.values) {
        // Not "does not throw a particular exception" — does not throw at all,
        // for every phase the game has. Doc 10 §1.2 is a total claim.
        await controller.apply(snapshotIn(phase));
      }

      expect(controller.state.mode, equals(VoiceMode.text));
    });
  });

  group('the phases the table calls open', () {
    test('the lobby and the result screen are a room, not a queue', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(snapshotIn(GamePhase.result));

      expect(engine.microphoneLive, isTrue);
      expect(engine.audiblePeers, equals({'u0', 'u1', 'u2'}));
      expect(controller.state.canRequestFloor, isFalse,
          reason: 'there is no floor to ask for when everybody has one');
    });

    test('free discussion is open; structured discussion is not', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(
          snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free));
      expect(engine.microphoneLive, isTrue);

      await controller.apply(snapshotIn(GamePhase.discussion));
      expect(engine.microphoneLive, isFalse);
    });
  });
}
