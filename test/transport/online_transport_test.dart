import 'dart:async';

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
      throwsA(isA<BackendUnreachable>()),
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

    test('a realtime row inside the phase keeps the corrected clock', () async {
      final serverNow = DateTime.utc(2026, 9, 2, 12);
      // Twenty seconds fast, the case the review found.
      localNow = serverNow.add(const Duration(seconds: 20));
      final endsAt = serverNow.add(const Duration(seconds: 90));
      await connect(
        state: roomState(
          phase: 'discuss',
          serverNow: serverNow,
          endsAt: endsAt,
        ),
      );
      expect(
        transport.snapshot.phaseDeadline!.difference(localNow),
        const Duration(seconds: 90),
      );

      // The floor changes hands. The hosted row is stamped by this device's
      // clock on arrival, so it says nothing about the server's.
      backend.pushStateDelta(
        roomState(
          phase: 'discuss',
          serverNow: serverNow,
          endsAt: endsAt,
          activeSpeaker: 'u1',
        ),
        receivedAt: localNow,
      );
      await pumpEventQueue();

      expect(transport.snapshot.activeSpeakerSeat, 1);
      expect(
        transport.snapshot.phaseDeadline!.difference(localNow),
        const Duration(seconds: 90),
        reason: 'the countdown must not jump 20s when the speaker changes',
      );
      localNow = localNow.add(const Duration(seconds: 80));
      await transport.tick();
      expect(
        backend.called('advance_phase'),
        isFalse,
        reason: 'the host must not end the phase 20s early',
      );
      localNow = localNow.add(const Duration(seconds: 11));
      await transport.tick();
      expect(backend.called('advance_phase'), isTrue);
    });
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
      // `BackendUnreachable`, not a refusal: the ballot did not reach the
      // room, and saying "the server said no" about a server that said nothing
      // is the lie this transport is no longer allowed to tell.
      await expectLater(
        transport.submitVote(seat: 0, targetSeat: 1),
        throwsA(isA<BackendUnreachable>()),
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
        throwsA(isA<BackendUnreachable>()),
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

    test(
      'a row that lands during a slow full read is not overwritten by it',
      () async {
        await connect(state: roomState(phase: 'discuss'));
        final published = <int?>[];
        final sub = transport.watch().listen(
          (s) => published.add(s.activeSpeakerSeat),
        );
        addTearDown(sub.cancel);
        await pumpEventQueue();
        published.clear();
        final before = backend.fetches;

        // The phase moves; its full read leaves before the floor is taken.
        final slow = Completer<void>();
        backend.fetchGate = slow.future;
        backend.pushStateDelta(roomState(phase: 'vote', phaseNumber: 2));
        await pumpEventQueue();
        expect(backend.fetches, before + 1);

        // The floor is taken while that read is still on the wire.
        backend.pushStateDelta(
          roomState(phase: 'vote', phaseNumber: 2, activeSpeaker: 'u2'),
        );
        await pumpEventQueue();

        backend.fetchGate = null;
        slow.complete();
        await pumpEventQueue();

        expect(transport.snapshot.phase, GamePhase.voting);
        expect(transport.snapshot.activeSpeakerSeat, 2);
        expect(backend.fetches, before + 2, reason: 'exactly one reread');
        expect(published, isNotEmpty);
        expect(
          published,
          everyElement(2),
          reason: 'the older read must never be shown',
        );
      },
    );

    test('a stream of rows during reads still converges', () async {
      await connect(state: roomState(phase: 'discuss'));
      final before = backend.fetches;
      final gates = [Completer<void>(), Completer<void>(), Completer<void>()];

      backend.fetchGate = gates[0].future;
      backend.pushStateDelta(roomState(phase: 'vote', phaseNumber: 2));
      await pumpEventQueue();
      for (var i = 0; i < gates.length; i++) {
        // Every read is overtaken by a newer speaker before it returns.
        backend.pushStateDelta(
          roomState(phase: 'vote', phaseNumber: 2, activeSpeaker: 'u${i + 1}'),
        );
        await pumpEventQueue();
        backend.fetchGate = i + 1 < gates.length ? gates[i + 1].future : null;
        gates[i].complete();
        await pumpEventQueue();
      }
      await pumpEventQueue();

      expect(transport.snapshot.activeSpeakerSeat, 3);
      expect(
        backend.fetches,
        before + 4,
        reason: 'one read per overtaking row, then it stops',
      );
    });
  });

  // Every phase that ends on a *decision* rather than on a clock has to be
  // routed by hand, because `advance_phase` exists to apply expiry defaults and
  // has no row for a phase with no deadline. The deal was fixed once; the
  // morning was not, and the room sat on the morning report with «كمل» posting
  // to a function that honestly answered it had applied nothing.
  group('a phase that ends on a decision', () {
    test('the morning opens day 1 rather than asking for a default', () async {
      await connect(state: roomState(phase: 'morning', phaseNumber: 1));
      await transport.advancePhase();

      expect(backend.called('advance_phase'), isFalse);
      final opened = backend.lastCall('open_phase');
      expect(opened, isNotNull);
      expect(opened!.body['phase'], equals('opening'));
    });

    test('a later morning asks for the confrontation instead', () async {
      await connect(state: roomState(phase: 'morning', phaseNumber: 3));
      await transport.advancePhase();

      expect(backend.called('advance_phase'), isFalse);
      expect(backend.called('generate_confrontation'), isTrue);
    });

    test('the deal still opens the night, for anybody', () async {
      await connect(
        state: roomState(phase: 'reveal', phaseNumber: 1, hostId: 'u4'),
        userId: 'u0',
      );
      await transport.advancePhase();

      final opened = backend.lastCall('open_phase');
      expect(opened, isNotNull);
      expect(opened!.body['phase'], equals('night'));
    });

    // The button is drawn for the *confronted player*, so gating the call on
    // the host meant that unless the accused happened to be holding the room,
    // «خلصت» posted nothing and the table waited out the whole window.
    test('a confronted guest may close their own window', () async {
      await connect(
        state: roomState(
          phase: 'confront',
          phaseNumber: 2,
          hostId: 'u4',
          publicData: const {
            'confrontation': {'targetSeat': 0, 'sourceSeat': 1},
          },
        ),
        // Somebody else is the host. This is the case that did nothing.
        players: roster(5),
        userId: 'u0',
      );
      await transport.endConfrontation(silent: false);

      final opened = backend.lastCall('open_phase');
      expect(opened, isNotNull);
      expect(opened!.body['phase'], equals('discuss'));
      expect(opened.body['silent'], isFalse);
    });
  });

  // Doc 15 §S-O12: the eliminated player's card rises and turns over. Online it
  // had nowhere to happen — `resolve_vote` set the phase straight to `night`,
  // and `phaseFromServer` never produced `GamePhase.reveal` — so a player cast
  // a vote and arrived at a dark table with no idea what had happened.
  group('the verdict', () {
    test('the server phase reaches the screens as the reveal', () async {
      await connect(
        state: roomState(
          phase: 'verdict',
          phaseNumber: 2,
          publicData: const {
            'lastVote': {
              'tally': {'1': 3},
              'eliminatedSeat': 1,
              'eliminatedRole': 'mafia',
            },
          },
        ),
      );

      expect(transport.snapshot.phase, equals(GamePhase.reveal));
      expect(transport.snapshot.lastVote?.eliminatedSeat, equals(1));
      expect(transport.snapshot.lastVote?.eliminatedRole, equals(Role.mafia));
    });

    test('«كمل» opens the night that follows, not a default', () async {
      await connect(state: roomState(phase: 'verdict', phaseNumber: 2));
      await transport.advancePhase();

      expect(backend.called('advance_phase'), isFalse);
      expect(backend.lastCall('open_phase')?.body['phase'], equals('night'));
    });

    test('a verdict that ended the match opens the result', () async {
      await connect(
        state: roomState(
          phase: 'verdict',
          phaseNumber: 2,
          publicData: const {'outcome': 'town'},
        ),
      );
      await transport.advancePhase();

      expect(backend.lastCall('open_phase')?.body['phase'], equals('result'));
    });
  });

  // Doc 10 §8.2: no phase may stall. That is not a promise the room can keep
  // while only the host may end a phase — a host whose screen has locked looks,
  // from every other seat, exactly like a match that has broken.
  group('an expired phase belongs to the room, not to the host', () {
    test('the host drives the moment the clock runs out', () async {
      await connect(
        state: roomState(
          phase: 'vote',
          endsAt: localNow.subtract(const Duration(seconds: 1)),
        ),
      );
      await transport.tick();

      expect(backend.called('advance_phase'), isTrue);
      expect(backend.called('resolve_vote'), isTrue);
    });

    test('a guest holds back while the host still might', () async {
      await connect(
        userId: 'u3',
        own: const OwnSeat(seat: 3, role: 'citizen'),
        state: roomState(
          phase: 'vote',
          hostId: 'u0',
          endsAt: localNow.subtract(const Duration(seconds: 1)),
        ),
      );
      await transport.tick();

      expect(backend.called('advance_phase'), isFalse);
      expect(backend.called('resolve_vote'), isFalse);
    });

    test('and drives when the host plainly did not', () async {
      await connect(
        userId: 'u3',
        own: const OwnSeat(seat: 3, role: 'citizen'),
        state: roomState(
          phase: 'vote',
          hostId: 'u0',
          endsAt: localNow.subtract(const Duration(seconds: 1)),
        ),
      );
      // Past the grace and past this seat's place in the stagger.
      localNow = localNow.add(const Duration(seconds: 12));
      await transport.tick();

      expect(backend.called('advance_phase'), isTrue);
      expect(backend.called('resolve_vote'), isTrue);
    });

    test('a phase with no clock is never driven by a guest', () async {
      await connect(
        userId: 'u3',
        own: const OwnSeat(seat: 3, role: 'citizen'),
        state: roomState(phase: 'morning', hostId: 'u0'),
      );
      localNow = localNow.add(const Duration(seconds: 25));
      await transport.tick();

      expect(
        backend.calls.map((c) => c.function).where((f) => f != 'heartbeat'),
        isEmpty,
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

    // `night_actions.action_id` and `votes.action_id` are `uuid` columns. A key
    // that is merely unique is not enough: Postgres refuses anything that is
    // not RFC 4122 with `22P02`, the Edge Function turns that into a 400, and
    // the *move the key was riding on* is refused with it. This test is the one
    // that was missing — the old one asserted "a non-empty string", which a
    // key of the wrong shape passes on its way to losing every vote in the
    // match.
    test('the key is a UUID, because the column it lands in is one', () async {
      await connect();
      await transport.submitVote(seat: 0, targetSeat: 1);
      await transport.submitNightAction(
        seat: 0,
        kind: NightActionKind.mafiaVote,
        targetSeat: 1,
      );

      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final keys = backend.calls
          .where((c) => c.body.containsKey('actionId'))
          .map((c) => c.body['actionId'])
          .toList();
      expect(keys, isNotEmpty);
      for (final key in keys) {
        expect(key, isA<String>());
        expect(
          uuid.hasMatch(key as String),
          isTrue,
          reason: 'not a UUID: $key',
        );
      }
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

  group('private role delivery', () {
    test('a guest recovers its role without waiting for another push', () async {
      await connect(
        userId: 'u3',
        state: roomState(phase: 'reveal', hostId: 'u0'),
        own: const OwnSeat(seat: 3),
      );
      final before = backend.fetches;

      // Models the production ordering race: reveal reached this client while
      // its first full read still had the pre-deal private identity. The role
      // exists by the time the private card asks, but no second Realtime event
      // is required to rescue the player.
      backend.setOwn(const OwnSeat(seat: 3, role: 'citizen'));
      final secrets = await transport.secretsFor(3);

      expect(secrets?.role, Role.citizen);
      expect(backend.fetches, before + 1);
    });

    test('a player who already saw the role is not dealt it again', () async {
      final players = roster(5)
          .map(
            (player) =>
                player.userId == 'u3' ? player.copyWith(sawRole: true) : player,
          )
          .toList();
      await connect(
        userId: 'u3',
        state: roomState(phase: 'reveal', hostId: 'u0'),
        players: players,
        own: const OwnSeat(seat: 3, role: 'citizen'),
      );

      expect(transport.snapshot.currentActorSeat, isNull);
    });
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

  /// The two facts about presence the voice layer reads out of this transport,
  /// and the ways each of them used to be wrong.
  ///
  /// Neither is load-bearing for the match (doc 10 §1.2) and both are
  /// load-bearing for privacy, which is the awkward combination that makes
  /// them worth stating here rather than leaving to the call to notice.
  group('what the call is told about the room', () {
    test(
      'a delayed departure cannot remove a newly connected voice peer',
      () async {
        await connect(
          players: [
            ...roster(2),
            RoomPlayer(userId: 'u2', seat: 2, name: 'C', lastSeen: localNow),
          ],
        );
        backend.pushPlayer(
          RoomPlayer(
            userId: 'u2',
            seat: 2,
            name: 'C',
            status: 'left',
            lastSeen: localNow.subtract(const Duration(seconds: 10)),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(transport.voice!.peers.map((p) => p.userId), contains('u2'));
        backend.pushPlayer(
          RoomPlayer(
            userId: 'u2',
            seat: 2,
            name: 'C',
            status: 'left',
            lastSeen: localNow.add(const Duration(seconds: 1)),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          transport.voice!.peers.map((p) => p.userId),
          isNot(contains('u2')),
        );
      },
    );
    test(
      'the voice roster is who is at the table, not who has a row',
      () async {
        await connect(
          players: [
            ...roster(2),
            const RoomPlayer(userId: 'u2', seat: 2, name: 'C', status: 'away'),
            const RoomPlayer(userId: 'u3', seat: 3, name: 'D', status: 'left'),
            const RoomPlayer(userId: 'u4', seat: 4, name: 'E', kicked: true),
          ],
        );

        final seated = transport.voice!.peers.map((p) => p.userId).toList();

        // Away is a person deciding whether to come back. Their ring is empty
        // and their seat is not: hanging up on them would mean a player who
        // reopens the app finds a room that cannot hear them.
        expect(seated, containsAll(['u0', 'u1', 'u2']));

        // Left and kicked are neither. The mesh dials by this list, so a row
        // that stayed in it is a peer connection to somebody the room has
        // already removed — and the envelope's roster check reads the same
        // closure, so it would also start admitting their frames again.
        expect(seated, isNot(contains('u3')));
        expect(seated, isNot(contains('u4')));
      },
    );

    test(
      'the roster the call reads follows the room, not the moment it asked',
      () async {
        await connect(players: roster(3));
        expect(transport.voice!.peers, hasLength(3));

        // The link holds a closure rather than a copy, precisely so this works:
        // a player who leaves stops being dialable and stops being an acceptable
        // sender at the same instant, without anything having to remember to
        // tell the call.
        backend.setPlayers([
          ...roster(2),
          const RoomPlayer(userId: 'u2', seat: 2, name: 'C', status: 'left'),
        ]);
        await transport.resync();

        expect(
          transport.voice!.peers.map((p) => p.userId),
          isNot(contains('u2')),
        );
      },
    );
  });

  /// O20 — the app in the background.
  group('a backgrounded client', () {
    test('stops claiming to be at the table', () async {
      await connect();
      backend.calls.clear();

      await transport.setPresence('away');
      await transport.tick();

      // The heartbeat is what keeps `last_seen` fresh, and a fresh `last_seen`
      // is what every other device renders as a lit ring. A backgrounded
      // client that kept beating would sit in fifteen other people's rooms
      // looking present while its screen was off — and during a discussion
      // that is a player who appears to be listening and is not.
      expect(
        backend.calls.where((c) => c.function == 'heartbeat'),
        isEmpty,
        reason: 'the beat stops with the foreground, not with the process',
      );
      expect(backend.called('set_presence'), isTrue);
    });

    test('starts again when it comes back', () async {
      await connect();
      await transport.setPresence('away');
      backend.calls.clear();

      await transport.setPresence('connected');
      await transport.tick();

      expect(
        backend.calls.where((c) => c.function == 'heartbeat'),
        hasLength(1),
      );
    });

    test('leaving is not a background either', () async {
      // `left` is a decision, `away` is a circumstance, and neither one beats.
      await connect();
      await transport.setPresence('left');
      backend.calls.clear();

      await transport.tick();

      expect(backend.calls.where((c) => c.function == 'heartbeat'), isEmpty);
    });
  });

  /// A card may only leave the screen on the room's word.
  ///
  /// `_send` used to answer a lost request the way it answers a delivered one:
  /// it painted the connection weather and returned normally. `confirmRevealed`
  /// then returned normally too, the controller cleared the card, and the screen
  /// that was the only remaining way to try again was gone — while the server
  /// went on listing that seat as one the room was waiting for. Everybody's
  /// «كمل» stayed refused, the deal has no default of its own, and the match
  /// stopped there. Four of five players in a real room, on a real evening.
  group('a card that was never acknowledged', () {
    late FakeBackend backend;
    late OnlineTransport transport;

    Future<void> deal({bool unreachable = false, bool ignored = false}) async {
      backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'reveal', phaseNumber: 1),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'citizen'),
      );
      backend.ignoreSawRole = ignored;
      transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      backend.unreachable = unreachable;
      addTearDown(transport.dispose);
    }

    test('is not dismissed when the room could not be reached', () async {
      await deal(unreachable: true);
      await expectLater(
        transport.confirmRevealed(),
        throwsA(isA<BackendUnreachable>()),
      );
    });

    test('is not dismissed on a yes that wrote nothing', () async {
      await deal(ignored: true);
      await expectLater(
        transport.confirmRevealed(),
        throwsA(
          isA<BackendException>().having(
            (e) => e.code,
            'code',
            'NOT_ACKNOWLEDGED',
          ),
        ),
      );
    });

    test('is dismissed once the room holds it', () async {
      await deal();
      await transport.confirmRevealed();
      expect(backend.calls.map((c) => c.function), contains('saw_role'));
      // And the seat is no longer one the room is waiting for, which is what
      // lets the screen let go of the card.
      expect(transport.snapshot.unseenRoleSeats, isNot(contains(0)));
    });

    test('a night action lost on the way is not reported as made', () async {
      backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'night', phaseNumber: 1),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'mafia'),
      );
      transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      addTearDown(transport.dispose);
      backend.unreachable = true;
      await expectLater(
        transport.submitNightAction(
          seat: 0,
          kind: NightActionKind.mafiaVote,
          targetSeat: 2,
        ),
        throwsA(isA<BackendUnreachable>()),
      );
    });
  });
}
