import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';

import '../support/fake_backend.dart';

/// Phase 7's gate, in the half that can be proved without five phones: what the
/// client does with every answer the server can give it (doc 11 §6).
///
/// The other half — RLS, the three forged requests, the migrations — is proved
/// where it runs, in `supabase/tests/`. Between them they cover O1–O20; neither
/// could cover the other's cases, and a test that mocked the server's *rules*
/// would only be checking that two of my own guesses agree.
void main() {
  late FakeBackend backend;
  late OnlineTransport transport;

  /// A clock the tests move by hand. Everything about a deadline is measured
  /// against it, including a deliberately wrong one (O8).
  DateTime localNow = DateTime.utc(2026, 9, 2, 12);

  Future<OnlineTransport> connect({
    RoomState? state,
    List<RoomPlayer>? players,
    OwnSeat? own,
    List<WhisperRow> whispers = const [],
    String userId = 'u0',
  }) async {
    backend = FakeBackend(
      roomId: 'room-1',
      state: state ?? roomState(),
      players: players ?? roster(5),
      own: own ?? const OwnSeat(seat: 0, role: 'detective'),
      whispers: whispers,
      userId: userId,
    );
    transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      // Zero disables the periodic timer: every test that wants a beat calls
      // `tick()`, so nothing here depends on real seconds passing.
      heartbeatInterval: Duration.zero,
      now: () => localNow,
    );
    addTearDown(transport.dispose);
    return transport;
  }

  setUp(() => localNow = DateTime.utc(2026, 9, 2, 12));

  test('an unacknowledged night action remains retryable', () async {
    await connect();
    backend.unreachable = true;
    await expectLater(
      transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.investigate,
        targetSeat: 1,
      ),
      throwsA(isA<BackendException>()),
    );
    expect(transport.snapshot.currentActorSeat, 0);
    backend.unreachable = false;
    await transport.submitNightAction(
      seat: 0,
      kind: NightActionKind.investigate,
      targetSeat: 1,
    );
    expect(transport.snapshot.currentActorSeat, isNull);
  });

  group('the snapshot', () {
    test('carries the room and never a role', () async {
      await connect();
      final snapshot = transport.snapshot;

      expect(snapshot.phase, equals(GamePhase.night));
      expect(snapshot.public.players, hasLength(5));
      expect(snapshot.viewerSeat, equals(0));
      expect(snapshot.connection, equals(ConnectionQuality.connected));
      // `PublicPlayer` has no role field; this is the assertion that the
      // *rendered* form carries none either.
      expect(snapshot.toString(), isNot(contains('detective')));
    });

    test('is authoritative nowhere', () async {
      await connect();
      expect(transport.isAuthoritative, isFalse);
    });

    test('says whose turn it is by saying "yours" or nobody', () async {
      await connect(own: const OwnSeat(seat: 3, role: 'citizen'));
      expect(transport.snapshot.currentActorSeat, equals(3));

      await transport.submitNightAction(
        seat: 3,
        kind: NightActionKind.suspect,
        targetSeat: 1,
      );
      expect(
        transport.snapshot.currentActorSeat,
        isNull,
        reason: 'a client that has acted is waiting, not holding the room up',
      );
    });

    test('a dead player is never the current actor', () async {
      await connect(
        own: const OwnSeat(seat: 2, role: 'citizen', alive: false),
        players: roster(5, dead: {2}),
      );
      expect(transport.snapshot.currentActorSeat, isNull);
      expect(await transport.secretsFor(2), isNull);
    });
  });

  group('O8 — the client clock is never trusted', () {
    test(
      'a phone ten minutes fast still renders the right countdown',
      () async {
        final serverNow = DateTime.utc(2026, 9, 2, 12);
        // The device believes it is 12:10 while the server is at 12:00.
        localNow = serverNow.add(const Duration(minutes: 10));

        await connect(
          state: roomState(
            serverNow: serverNow,
            endsAt: serverNow.add(const Duration(seconds: 90)),
          ),
        );

        final deadline = transport.snapshot.phaseDeadline!;
        final remaining = deadline.difference(localNow);
        expect(
          remaining,
          equals(const Duration(seconds: 90)),
          reason:
              'the countdown is 90s on every device, whatever it thinks '
              'the time is',
        );
      },
    );

    test('a phase with no deadline renders none', () async {
      await connect(state: roomState(phase: 'morning'));
      expect(transport.snapshot.phaseDeadline, isNull);
    });

    test(
      'a host does not advance a phase whose deadline has not passed',
      () async {
        final serverNow = DateTime.utc(2026, 9, 2, 12);
        localNow = serverNow.add(const Duration(minutes: 10));
        await connect(
          state: roomState(
            serverNow: serverNow,
            endsAt: serverNow.add(const Duration(seconds: 90)),
          ),
        );

        await transport.tick();
        expect(
          backend.called('advance_phase'),
          isFalse,
          reason: 'the fast clock must not end the phase early',
        );

        localNow = localNow.add(const Duration(seconds: 91));
        await transport.tick();
        expect(backend.called('advance_phase'), isTrue);
      },
    );
  });

  group('O7 — the phase moved while the tap was in flight', () {
    test('PHASE_CLOSED resyncs instead of raising', () async {
      await connect();
      backend.refusals['submit_vote'] = const BackendException(
        'PHASE_CLOSED',
        'the ballot is closed',
      );
      final before = backend.fetches;

      await transport.submitVote(seat: 0, targetSeat: 2);

      expect(
        backend.fetches,
        greaterThan(before),
        reason: 'the client force-resyncs from a snapshot',
      );
    });

    test('any other refusal reaches the caller', () async {
      await connect();
      backend.refusals['send_whisper'] = const BackendException(
        'RATE_LIMITED',
        'one a day',
      );

      await expectLater(
        transport.sendWhisper(fromSeat: 0, toSeat: 1, body: 'hi'),
        throwsA(isA<BackendException>()),
      );
    });
  });

  group('O10 — the server drops mid-match', () {
    test('the last snapshot stays and the banner goes up', () async {
      await connect();
      final before = transport.snapshot;

      backend.unreachable = true;
      await expectLater(
        transport.submitVote(seat: 0, targetSeat: 1),
        throwsA(isA<BackendException>()),
      );

      expect(
        transport.snapshot.phase,
        equals(before.phase),
        reason: 'state is preserved locally throughout',
      );
      expect(
        transport.snapshot.connection,
        equals(ConnectionQuality.reconnecting),
      );
    });

    test('a reachable server puts the banner down again', () async {
      await connect();
      backend.unreachable = true;
      await expectLater(
        transport.submitVote(seat: 0, targetSeat: 1),
        throwsA(isA<BackendException>()),
      );
      expect(
        transport.snapshot.connection,
        equals(ConnectionQuality.reconnecting),
      );

      backend.unreachable = false;
      await transport.resync();
      expect(
        transport.snapshot.connection,
        equals(ConnectionQuality.connected),
      );
    });

    test('a dropped subscription is a resync, not a lost match', () async {
      await connect();
      final before = backend.fetches;
      backend.pushDisconnected();
      await pumpEventQueue();
      expect(
        transport.snapshot.connection,
        equals(ConnectionQuality.reconnecting),
      );

      backend.pushResync();
      await pumpEventQueue();
      expect(backend.fetches, greaterThan(before));
      expect(
        transport.snapshot.connection,
        equals(ConnectionQuality.connected),
      );
    });
  });

  group('O9, O11 — the server is not there at all', () {
    test('connecting to an unreachable project fails loudly', () async {
      final dead = FakeBackend(
        roomId: 'room-1',
        state: roomState(),
        players: roster(5),
      )..unreachable = true;

      await expectLater(
        OnlineTransport.connect(backend: dead, roomId: 'room-1'),
        throwsA(isA<BackendUnreachable>()),
      );
    });

    test('a paused project is distinguishable from a dropped one', () async {
      final paused =
          FakeBackend(roomId: 'room-1', state: roomState(), players: roster(5))
            ..unreachable = true
            ..projectPaused = true;

      await expectLater(
        OnlineTransport.connect(backend: paused, roomId: 'room-1'),
        throwsA(
          isA<BackendUnreachable>().having(
            (e) => e.projectPaused,
            'projectPaused',
            isTrue,
          ),
        ),
      );
    });
  });

  group('O12 — deltas are the happy path, snapshots are the recovery', () {
    test('a phase change is read in full', () async {
      await connect();
      final before = backend.fetches;

      backend.setState(roomState(phase: 'morning', phaseNumber: 1));
      await pumpEventQueue();

      expect(backend.fetches, greaterThan(before));
      expect(transport.snapshot.phase, equals(GamePhase.morning));
    });

    test('a roster delta is applied in place', () async {
      await connect();
      final before = backend.fetches;

      backend.pushPlayer(
        RoomPlayer(
          userId: 'u2',
          seat: 2,
          name: 'C',
          alive: false,
          lastSeen: localNow,
        ),
      );
      await pumpEventQueue();

      expect(
        backend.fetches,
        equals(before),
        reason: 'a heartbeat must not cost a full read',
      );
      expect(
        transport.snapshot.public.players[2].status,
        equals(PlayerStatus.dead),
      );
    });
  });

  group('O19 — a retried request is a no-op', () {
    test('every command carries an idempotency key, and they differ', () async {
      await connect();
      await transport.submitVote(seat: 0, targetSeat: 1);
      await transport.submitVote(seat: 0, targetSeat: 2);

      final votes = backend.calls.where((c) => c.function == 'submit_vote');
      expect(votes, hasLength(2));
      final keys = votes.map((c) => c.body['actionId']).toSet();
      expect(keys, hasLength(2));
      expect(keys.every((k) => k is String && k.isNotEmpty), isTrue);
    });
  });

  group('O20 — the app was in the background for ten minutes', () {
    test('one beat says we are here and reads everything again', () async {
      await connect();
      final before = backend.fetches;
      localNow = localNow.add(const Duration(minutes: 10));

      await transport.tick();
      await transport.resync();

      expect(backend.called('heartbeat'), isTrue);
      expect(backend.fetches, greaterThan(before));
    });
  });

  group('O1, O2 — the host left', () {
    RoomState hostedBy(String host) => roomState(hostId: host);

    test('the lowest-seat connected player claims the room', () async {
      final stale = DateTime.utc(2026, 9, 2, 11, 58);
      await connect(
        state: hostedBy('u2'),
        players: [
          RoomPlayer(userId: 'u0', seat: 0, name: 'A', lastSeen: localNow),
          RoomPlayer(userId: 'u1', seat: 1, name: 'B', lastSeen: localNow),
          RoomPlayer(userId: 'u2', seat: 2, name: 'C', lastSeen: stale),
        ],
      );

      await transport.tick();
      expect(backend.called('claim_host'), isTrue);
    });

    test('a player who is not the heir does not ask', () async {
      final stale = DateTime.utc(2026, 9, 2, 11, 58);
      await connect(
        userId: 'u1',
        state: hostedBy('u2'),
        own: const OwnSeat(seat: 1, role: 'citizen'),
        players: [
          RoomPlayer(userId: 'u0', seat: 0, name: 'A', lastSeen: localNow),
          RoomPlayer(userId: 'u1', seat: 1, name: 'B', lastSeen: localNow),
          RoomPlayer(userId: 'u2', seat: 2, name: 'C', lastSeen: stale),
        ],
      );

      await transport.tick();
      expect(
        backend.called('claim_host'),
        isFalse,
        reason: 'seat 0 is connected and is the heir',
      );
    });

    test('it cascades when the heir has gone too (O2)', () async {
      final stale = DateTime.utc(2026, 9, 2, 11, 58);
      await connect(
        userId: 'u1',
        state: hostedBy('u2'),
        own: const OwnSeat(seat: 1, role: 'citizen'),
        players: [
          RoomPlayer(userId: 'u0', seat: 0, name: 'A', lastSeen: stale),
          RoomPlayer(userId: 'u1', seat: 1, name: 'B', lastSeen: localNow),
          RoomPlayer(userId: 'u2', seat: 2, name: 'C', lastSeen: stale),
        ],
      );

      await transport.tick();
      expect(backend.called('claim_host'), isTrue);
    });

    test('a live host is left alone', () async {
      await connect(
        userId: 'u1',
        state: hostedBy('u2'),
        own: const OwnSeat(seat: 1, role: 'citizen'),
        players: [
          RoomPlayer(userId: 'u1', seat: 1, name: 'B', lastSeen: localNow),
          RoomPlayer(userId: 'u2', seat: 2, name: 'C', lastSeen: localNow),
        ],
      );

      await transport.tick();
      expect(backend.called('claim_host'), isFalse);
    });
  });

  group('one device drives (doc 10 §7)', () {
    test('a guest makes no phase call the host owns', () async {
      await connect(
        userId: 'u3',
        state: roomState(phase: 'morning', hostId: 'u0'),
        own: const OwnSeat(seat: 3, role: 'citizen'),
      );

      await transport.beginNight();
      await transport.resolveNight();
      await transport.beginVoting();
      await transport.advancePhase();

      expect(backend.calls.map((c) => c.function), isEmpty);
      expect(transport.snapshot.canAdvance, isFalse);
    });

    test('ending the deal is the one call a guest may make', () async {
      // The deal ends when the last card is dismissed, and the person who
      // dismissed it is whoever it is. Making the room wait for the host to
      // notice would strand it on the one screen where everybody is looking at
      // their own phone — and it costs nothing to allow, because `open_phase`
      // refuses the transition until every seat has `saw_role`.
      await connect(
        userId: 'u3',
        state: roomState(phase: 'reveal', hostId: 'u0'),
        own: const OwnSeat(seat: 3, role: 'citizen'),
      );

      await transport.advancePhase();

      expect(backend.lastCall('open_phase')?.body['phase'], equals('night'));
      expect(transport.snapshot.canAdvance, isFalse);
    });

    test('the host does', () async {
      await connect(
        state: roomState(phase: 'reveal', hostId: 'u0'),
      );
      await transport.beginNight();

      expect(backend.lastCall('open_phase')?.body['phase'], equals('night'));
      expect(transport.snapshot.canAdvance, isTrue);
    });

    test(
      'day 1 opens the naming round, day 2 asks for a confrontation',
      () async {
        await connect(state: roomState(phase: 'morning', phaseNumber: 1));
        await transport.beginDay();
        expect(
          backend.lastCall('open_phase')?.body['phase'],
          equals('opening'),
        );

        backend.setState(
          roomState(phase: 'morning', phaseNumber: 2),
          push: false,
        );
        await transport.resync();
        await transport.beginDay();
        expect(backend.called('generate_confrontation'), isTrue);
      },
    );
  });

  group('«الطلقة الواحدة», online (doc 13 §2 / doc 14 §4)', () {
    // **This used to be the one thing online could not do.**
    // `supportsBullets` returned false, so the last tile on the night grid was
    // an ordinary skip. For the Mafia that cost only the "once per match" part
    // — a skip already makes a quiet night. For the Doctor it cost the whole
    // move: `submit_night_action` refused a self-target outright, so the tile
    // bearing their own name was a tile the server rejected.

    test('the transport says it can carry one', () async {
      await connect();
      expect(transport.supportsBullets, isTrue);
    });

    test('the intention travels, and only the intention', () async {
      await connect(own: const OwnSeat(seat: 0, role: 'doctor'));
      backend.responses['submit_night_action'] = {'bulletSpent': true};

      await transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.protect,
        targetSeat: 0,
        useBullet: true,
      );

      final body = backend.lastCall('submit_night_action')!.body;
      expect(body['useBullet'], isTrue);
      // The actor is never named: the server takes it from the JWT, and a
      // field that named one would be O17 with a different noun.
      expect(body.containsKey('seat'), isFalse);
      expect(body['targetSeat'], equals(0));
    });

    test('the answer comes from the ack, not from the asking', () async {
      await connect(own: const OwnSeat(seat: 0, role: 'mafia'));
      // The client asked. The server said no — the room has this bullet
      // switched off, which is a fact the client does not get to overrule.
      backend.responses['submit_night_action'] = {'bulletSpent': false};

      await transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.mafiaVote,
        targetSeat: null,
        useBullet: true,
      );

      expect(transport.currentActorBulletSpent, isFalse);
    });

    test('a spent bullet stays spent for the rest of the match', () async {
      await connect(own: const OwnSeat(seat: 0, role: 'doctor'));
      backend.responses['submit_night_action'] = {'bulletSpent': true};
      await transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.protect,
        targetSeat: 0,
        useBullet: true,
      );
      expect(transport.currentActorBulletSpent, isTrue);

      // A later, ordinary night. The ack says `false` because *this* move did
      // not spend one, and that must not un-spend the one already gone.
      backend.responses['submit_night_action'] = {'bulletSpent': false};
      await transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.protect,
        targetSeat: 2,
      );
      expect(transport.currentActorBulletSpent, isTrue);
    });

    test('a reconnect finds it out again from its own rows', () async {
      // The flag is not kept in the client's head. It is read back from
      // `night_actions.used_bullet`, whose read policy is `actor_id =
      // auth.uid()` — so a phone that dropped mid-match and came back knows
      // what it has left, and no other phone can be told.
      await connect(
        own: const OwnSeat(seat: 0, role: 'doctor', bulletSpent: true),
      );
      expect(transport.currentActorBulletSpent, isTrue);
    });

    test('nothing about it reaches the rendered snapshot', () async {
      // Only two of the four roles hold one, so a public "seat 0 has spent
      // theirs" would say *seat 0 is the Mafia or the Doctor*, which is most
      // of the game. It is on the own row and nowhere else.
      await connect(
        own: const OwnSeat(seat: 0, role: 'doctor', bulletSpent: true),
      );
      expect(transport.snapshot.toString(), isNot(contains('bulletSpent')));
      expect(transport.snapshot.toString(), isNot(contains('doctor')));
    });
  });

  group('a client never acts for another seat', () {
    test('a night action for somebody else is not sent', () async {
      await connect(own: const OwnSeat(seat: 0, role: 'mafia'));
      await transport.submitNightAction(
        seat: 2,
        kind: NightActionKind.mafiaVote,
        targetSeat: 3,
      );
      expect(backend.called('submit_night_action'), isFalse);
    });

    test('and its own carries no seat for the server to believe', () async {
      await connect(own: const OwnSeat(seat: 0, role: 'mafia'));
      await transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.mafiaVote,
        targetSeat: 3,
      );
      final body = backend.lastCall('submit_night_action')!.body;
      expect(
        body['action'],
        equals('kill'),
        reason: 'the engine calls it a vote, the server calls it a kill',
      );
      expect(body.containsKey('seat'), isFalse);
      expect(body.containsKey('actorSeat'), isFalse);
    });

    test('a vote for somebody else is not sent', () async {
      await connect(own: const OwnSeat(seat: 0, role: 'citizen'));
      await transport.submitVote(seat: 4, targetSeat: 1);
      expect(backend.called('submit_vote'), isFalse);
    });

    test('secrets are refused for every seat but this one', () async {
      await connect(
        state: roomState(phase: 'reveal'),
        own: const OwnSeat(seat: 0, role: 'mafia', teammateNames: ['C']),
      );

      final mine = await transport.secretsFor(0);
      expect(mine!.role, equals(Role.mafia));
      expect(mine.teammateNames, equals(['C']));

      for (var seat = 1; seat < 5; seat++) {
        expect(await transport.secretsFor(seat), isNull);
      }
    });

    test('a skipped night action says so without naming anybody', () async {
      await connect(own: const OwnSeat(seat: 0, role: 'citizen'));
      await transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.suspect,
        targetSeat: null,
      );
      expect(
        backend.lastCall('submit_night_action')!.body['action'],
        equals('skip'),
      );
    });
  });

  group('whispers', () {
    test(
      'the body is fetched for the recipient and never held in the graph',
      () async {
        final whisper = const WhisperRow(
          id: 'w1',
          day: 1,
          fromSeat: 2,
          toSeat: 0,
          toMe: true,
        );
        await connect(
          own: const OwnSeat(seat: 0, role: 'citizen'),
          whispers: [whisper],
        );
        backend.bodies['w1'] = 'watch seat four';

        final secrets = await transport.secretsFor(0);
        expect(secrets!.whisperBody, equals('watch seat four'));
        expect(transport.snapshot.whisperGraph, hasLength(1));
        expect(
          transport.snapshot.whisperGraph.single.toString(),
          isNot(contains('watch seat four')),
        );
      },
    );

    test('a blocked sender is dropped silently (H-E9)', () async {
      await connect(
        own: const OwnSeat(seat: 0, role: 'citizen'),
        whispers: const [
          WhisperRow(id: 'w1', day: 1, fromSeat: 2, toSeat: 0, toMe: true),
        ],
      );
      backend.bodies['w1'] = 'you should not read this';

      await transport.block('u2');
      final secrets = await transport.secretsFor(0);
      expect(secrets!.whisperBody, isNull);
      expect(
        transport.snapshot.whisperGraph,
        hasLength(1),
        reason:
            'the edge stays public — a block the table could see would '
            'be a channel of its own',
      );
    });

    test('a voided whisper tells its sender, not the room', () async {
      await connect(
        own: const OwnSeat(seat: 0, role: 'citizen'),
        whispers: const [
          WhisperRow(id: 'w1', day: 1, fromSeat: 0, toSeat: 3, voided: true),
        ],
      );

      final secrets = await transport.secretsFor(0);
      expect(secrets!.whisperUndelivered, isTrue);
      expect(secrets.whisperBody, isNull);
    });
  });
}
