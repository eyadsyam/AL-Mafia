import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
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
  }) => GameSnapshot(
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
    final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
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

  test('personal block removes audio through every public policy', () async {
    final (controller, engine, _) = await connected();
    controller.blockedUsers = {'u0'};
    await controller.apply(
      snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free),
    );
    expect(engine.audiblePeers, isNot(contains('u0')));
    expect(engine.audiblePeers, contains('u2'));
    await controller.apply(snapshotIn(GamePhase.openingRound, speaker: 0));
    expect(engine.audiblePeers, isEmpty);
    await controller.apply(snapshotIn(GamePhase.night));
    expect(engine.audiblePeers, isEmpty);
  });

  test(
    'the current room policy is applied before the first voice climb',
    () async {
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      // This is the order used by voice_session.dart. The old provider started
      // both futures independently, so the mesh could settle against the
      // controller's default muted policy and only recover after a room setting
      // produced another snapshot.
      await controller.apply(snapshotIn(GamePhase.setup));
      await controller.start(selfSeat: 1, peers: peers);

      expect(controller.state.mode, VoiceMode.live);
      expect(engine.audiblePeers, {'u0', 'u1', 'u2'});
      expect(engine.microphoneLive, isTrue);
    },
  );

  // Owner decision 2026-09-23 (doc 12 §4.1): the living hear only the
  // living; the dead hear everybody; a dead device sends only to the dead.
  group('the witness wall, in voice', () {
    GameSnapshot withDead(
      Set<int> dead, {
      GamePhase phase = GamePhase.discussion,
      int? speaker,
    }) => GameSnapshot(
      public: PublicMatchView(
        phase: phase,
        dayNumber: 2,
        players: [
          for (final seat in [0, 1, 2])
            PublicPlayer(
              seat: seat,
              name: 'P$seat',
              status: dead.contains(seat)
                  ? PlayerStatus.dead
                  : PlayerStatus.alive,
            ),
        ],
      ),
      settings: const MatchSettings(discussionMode: DiscussionMode.free),
      activeSpeakerSeat: speaker,
      viewerSeat: 1,
    );

    test(
      'living: the dead are inaudible and nothing changes in sending',
      () async {
        final (controller, engine, _) = await connected();
        await controller.apply(withDead({2}));
        expect(
          engine.audiblePeers,
          isNot(contains('u2')),
          reason: 'an open discussion used to carry the dead seat',
        );
        expect(engine.audiblePeers, contains('u0'));
        expect(
          engine.sendingPeers,
          isNull,
          reason: 'the living reach everyone',
        );
        expect(engine.microphoneLive, isTrue);
      },
    );

    test(
      'dead: hears the living and the dead, sends only to the dead',
      () async {
        final (controller, engine, _) = await connected();
        await controller.apply(withDead({1, 2}));
        expect(engine.audiblePeers, containsAll(['u0', 'u2']));
        expect(
          engine.sendingPeers,
          {'u2'},
          reason: 'a dead device must never put audio on the wire to u0',
        );
        expect(
          engine.microphoneLive,
          isTrue,
          reason: 'the dead talk among themselves without the floor',
        );
      },
    );

    test(
      'dead under a held floor still hears the speaker and the dead',
      () async {
        final (controller, engine, _) = await connected();
        await controller.apply(
          withDead({1, 2}, phase: GamePhase.openingRound, speaker: 0),
        );
        expect(engine.audiblePeers, {'u0', 'u2'});
        expect(engine.sendingPeers, {'u2'});
      },
    );

    test('the dead are not offered the floor', () async {
      final (controller, _, _) = await connected();
      await controller.apply(withDead({1}, phase: GamePhase.discussion));
      expect(controller.state.witness, isTrue);
      expect(controller.state.canRequestFloor, isFalse);
    });

    test('a lone dead player sends to nobody', () async {
      final (controller, engine, _) = await connected();
      await controller.apply(withDead({1}));
      expect(engine.sendingPeers, isEmpty);
      expect(engine.audiblePeers, {'u0', 'u2'});
    });
  });

  group('V1 — the microphone is refused', () {
    test('the call runs anyway, receive-only', () async {
      final (controller, engine, _) = await connected(microphone: false);

      expect(
        controller.state.mode,
        equals(VoiceMode.live),
        reason: 'a player with no microphone still hears the room',
      );
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

      expect(
        notices.where((n) => n).length,
        equals(1),
        reason: 'V1 — told once, calmly, then never again',
      );
    });
  });

  group('V2 — there is no microphone at all', () {
    test('is the same case, and the same outcome', () async {
      // The platform cannot tell a refused permission from absent hardware
      // without asking a question the player did not agree to answer, so the
      // app does not try: both arrive as false and both mean receive-only.
      final (controller, _, _) = await connected(microphone: false);
      await controller.apply(snapshotIn(GamePhase.discussion, speaker: 1));

      expect(
        controller.state.microphoneLive,
        isFalse,
        reason: 'holding the floor with no microphone is still silence',
      );
      expect(controller.state.mode, equals(VoiceMode.live));
    });
  });

  group('V3 — STUN and TURN both fail', () {
    test('this player goes to text mode', () async {
      final (controller, engine, _) = await connected(rungs: const {});

      expect(controller.state.mode, equals(VoiceMode.text));
      expect(controller.state.rung, equals(VoiceRung.text));
      expect(
        engine.attempted,
        equals([VoiceRung.stun]),
        reason: 'no relay was configured, so the ladder has two rungs',
      );
    });

    test('the relay is tried before text, when there is one', () async {
      final (controller, engine, _) = await connected(
        rungs: const {VoiceRung.turn},
        relay: const IceConfig(VoiceRung.turn, [
          {'urls': 'turn:example.test'},
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

      expect(
        engine.audiblePeers,
        equals({'u2'}),
        reason:
            'a mesh has no server in the media path, so the drop happens '
            'at every ear',
      );
    });

    test(
      'the floor is a request to the server, never a local decision',
      () async {
        final (controller, engine, link) = await connected();
        link.grantFloor = false;

        expect(await controller.requestFloor(), isFalse);
        expect(link.claims, equals(1));
        expect(
          engine.microphoneLive,
          isFalse,
          reason: 'a refused claim must not unmute anything',
        );
      },
    );

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

    test(
      'an empty floor leaves everyone muted and the control offered',
      () async {
        final (controller, engine, _) = await connected();

        await controller.apply(snapshotIn(GamePhase.discussion));

        expect(engine.microphoneLive, isFalse);
        expect(engine.audiblePeers, isEmpty);
        expect(controller.state.canRequestFloor, isTrue);
      },
    );
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

      expect(
        engine.accepted,
        isEmpty,
        reason:
            'V6 — a connection during the night is impossible, not '
            'merely unwelcome',
      );
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
      expect(
        engine.connections,
        equals(2),
        reason: 'the ladder is climbed again',
      );

      link.deliver('u2');
      await Future<void>.delayed(Duration.zero);
      expect(engine.accepted, equals(['u2']));
    });

    test(
      'a climb that outlives the night does not publish the mesh it lost',
      () async {
        // The race the whole media epoch exists for. A climb is a long sequence
        // of awaits — a permission dialog, an ICE fetch, a peer connection each,
        // and up to the rung's whole timeout waiting for one of them to come up
        // — and a night is four minutes. Both ends of one land inside a single
        // climb routinely.
        //
        // `_tornDown` alone could not see it: it is a state, and the night is a
        // round trip. The stale climb woke up, read `_tornDown == false` because
        // the day had already put it back, and reported `live` for a mesh the
        // teardown had closed underneath it.
        final engine = FakeVoiceEngine();
        final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
        final controller = VoiceController(
          engine: engine,
          link: link,
          rungTimeout: Duration.zero,
        );
        addTearDown(controller.dispose);

        final seen = <VoiceMode>[];
        final watching = controller.watch().listen((s) => seen.add(s.mode));
        addTearDown(watching.cancel);

        final held = Completer<void>();
        engine.holdConnect = held;
        final climbing = controller.start(selfSeat: 1, peers: peers);
        await pumpEventQueue();

        // The night, and then the day, both while that first connect is still
        // in flight.
        await controller.apply(snapshotIn(GamePhase.night));
        expect(engine.teardowns, equals(1));
        final applying = controller.apply(snapshotIn(GamePhase.morning));

        // Only now does the connect the night interrupted come back.
        held.complete();
        await climbing;
        await applying;
        await pumpEventQueue();

        // It reported nothing. The state the player sees came from the climb the
        // day started, which is the one that owns the engine.
        expect(
          engine.attempted.length,
          equals(2),
          reason: 'the day climbs again rather than adopting the stale result',
        );
        expect(
          engine.teardowns,
          equals(1),
          reason: 'the stale climb must not tear down the mesh the day built',
        );
        expect(controller.state.mode, equals(VoiceMode.live));

        // And the call is genuinely back, not merely labelled live: the next
        // phase that admits speech admits it.
        await controller.apply(
          snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free),
        );
        expect(engine.audiblePeers, isNotEmpty);
        expect(engine.microphoneLive, isTrue);

        // And the order it was published in never says live while the night is
        // on. A single frame of that is a night with a microphone open in it.
        final night = seen.lastIndexOf(VoiceMode.off);
        expect(
          seen.sublist(0, night),
          isNot(contains(VoiceMode.live)),
          reason: 'V6 — nothing is live before or during the night',
        );
      },
    );

    test('a night that lands mid-climb leaves the microphone shut', () async {
      // The same race, read from the microphone rather than from the mode. The
      // stale climb used to run `_syncMicrophone` on the far side of the
      // night, and `setMicrophoneLive(true)` on a torn-down engine is exactly
      // the thing doc 05 says cannot happen in a private phase.
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);

      final held = Completer<void>();
      engine.holdConnect = held;
      final climbing = controller.start(selfSeat: 1, peers: peers);
      await pumpEventQueue();

      await controller.apply(snapshotIn(GamePhase.night));
      held.complete();
      await climbing;
      await pumpEventQueue();

      expect(controller.state.mode, equals(VoiceMode.off));
      expect(engine.microphoneLive, isFalse);
      expect(engine.audiblePeers, isEmpty);
    });
  });

  /// A climb is long and the room does not hold still for it.
  ///
  /// Everything in this group is the same shape: something changes while
  /// `connect` is still in flight. The engine and the controller each carry a
  /// media-cycle counter for exactly this, because the alternative — asking
  /// "are we torn down *now*" after an await — cannot tell a night that is
  /// still on from a night that has been and gone.
  group('the room moves while the call is being made', () {
    (VoiceController, FakeVoiceEngine, FakeVoiceLink) held() {
      final engine = FakeVoiceEngine();
      final link = FakeVoiceLink(selfId: 'u1')..peers = peers;
      final controller = VoiceController(
        engine: engine,
        link: link,
        rungTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);
      return (controller, engine, link);
    }

    test(
      'a player who joins mid-climb is dialled by the next one, not this one',
      () async {
        final (controller, engine, link) = held();
        final gate = Completer<void>();
        engine.holdConnect = gate;
        final climbing = controller.start(selfSeat: 1, peers: peers);
        await pumpEventQueue();

        // Somebody walks into the lobby while the first climb is still building
        // the mesh for the room as it was.
        link.peers = [...peers, const VoicePeer(userId: 'u3', seat: 3)];
        final applying = controller.apply(snapshotIn(GamePhase.setup));
        gate.complete();
        await climbing;
        await applying;
        await pumpEventQueue();

        expect(
          engine.attempted.length,
          equals(2),
          reason: 'the roster that changed is picked up by a second climb',
        );
        expect(
          engine.lastPeers.map((p) => p.userId),
          contains('u3'),
          reason: 'and that climb dials the room as it is now',
        );
        expect(
          engine.peakConcurrentConnects,
          equals(1),
          reason:
              'serialised — two meshes to the same peers cross their own '
              'offers and leave a connected, silent room',
        );
      },
    );

    test('a burst of roster changes collapses into one more climb', () async {
      // The lobby filling one player at a time. Each arrival is a snapshot,
      // and a climb per snapshot would rebuild the mesh under itself four
      // times over.
      final (controller, engine, link) = held();
      final gate = Completer<void>();
      engine.holdConnect = gate;
      final climbing = controller.start(selfSeat: 1, peers: peers);
      await pumpEventQueue();

      final applying = <Future<void>>[];
      for (var seat = 3; seat < 7; seat++) {
        link.peers = [...link.peers, VoicePeer(userId: 'u$seat', seat: seat)];
        applying.add(controller.apply(snapshotIn(GamePhase.setup)));
      }
      gate.complete();
      await climbing;
      await Future.wait(applying);
      await pumpEventQueue();

      expect(engine.attempted.length, equals(2));
      expect(engine.peakConcurrentConnects, equals(1));
      expect(
        engine.lastPeers.map((p) => p.userId),
        contains('u6'),
        reason: 'the one re-climb sees the room as it finally is',
      );
    });

    test('being kicked mid-climb cancels it and leaves nothing open', () async {
      final (controller, engine, _) = held();
      final gate = Completer<void>();
      engine.holdConnect = gate;
      final climbing = controller.start(selfSeat: 1, peers: peers);
      await pumpEventQueue();

      await controller.apply(
        snapshotIn(
          GamePhase.discussion,
          discussion: DiscussionMode.free,
        ).copyWith(viewerKicked: true),
      );
      gate.complete();
      await climbing;
      await pumpEventQueue();

      // An open discussion is the phase that would otherwise unmute this
      // device the moment the held climb reported success.
      expect(controller.state.mode, equals(VoiceMode.off));
      expect(engine.microphoneLive, isFalse);
      expect(engine.audiblePeers, isEmpty);
    });

    test('a room closing mid-climb cancels it too', () async {
      final (controller, engine, _) = held();
      final gate = Completer<void>();
      engine.holdConnect = gate;
      final climbing = controller.start(selfSeat: 1, peers: peers);
      await pumpEventQueue();

      await controller.apply(
        snapshotIn(
          GamePhase.discussion,
          discussion: DiscussionMode.free,
        ).copyWith(roomClosed: true),
      );
      gate.complete();
      await climbing;
      await pumpEventQueue();

      expect(controller.state.mode, equals(VoiceMode.off));
      expect(engine.microphoneLive, isFalse);
    });

    test('a room with voice switched off never comes up at all', () async {
      final (controller, engine, _) = held();
      final gate = Completer<void>();
      engine.holdConnect = gate;
      final climbing = controller.start(selfSeat: 1, peers: peers);
      await pumpEventQueue();

      await controller.apply(
        snapshotIn(
          GamePhase.discussion,
          discussion: DiscussionMode.free,
        ).copyWith(room: const RoomOptions(voice: false)),
      );
      gate.complete();
      await climbing;
      await pumpEventQueue();

      expect(controller.state.mode, equals(VoiceMode.off));
      expect(engine.microphoneLive, isFalse);
      expect(engine.audiblePeers, isEmpty);
    });

    test(
      'the microphone is asked for once, however many climbs there are',
      () async {
        // V1's "told once, calmly". A permission dialog that reappears every
        // time the lobby fills or a night ends is the opposite of it.
        final (controller, engine, link) = held();
        await controller.start(selfSeat: 1, peers: peers);
        await controller.apply(snapshotIn(GamePhase.night));
        await controller.apply(snapshotIn(GamePhase.morning));
        link.peers = [...peers, const VoicePeer(userId: 'u3', seat: 3)];
        await controller.apply(snapshotIn(GamePhase.morning));

        expect(engine.microphoneRequests, equals(1));
        expect(engine.attempted.length, greaterThan(1));
      },
    );
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
      expect(
        controller.state.canRequestFloor,
        isFalse,
        reason: 'there is no floor to ask for when everybody has one',
      );
    });

    test('free discussion is open; structured discussion is not', () async {
      final (controller, engine, _) = await connected();

      await controller.apply(
        snapshotIn(GamePhase.discussion, discussion: DiscussionMode.free),
      );
      expect(engine.microphoneLive, isTrue);

      await controller.apply(snapshotIn(GamePhase.discussion));
      expect(engine.microphoneLive, isFalse);
    });
  });
}
