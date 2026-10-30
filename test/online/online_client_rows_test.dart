import 'dart:async';

import 'package:flutter/material.dart' hide Alignment;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/online_match_history.dart';
import 'package:mafia_master/data/online_session_store.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/ui/information_text.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/council/role_roster.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/screens/online/voice_session.dart';

import '../support/fake_backend.dart';
import '../support/fake_voice_engine.dart';
import '../support/localized.dart';
import '../support/stores.dart';

/// Online client rows of `docs/plans/audit/M3-online.md` that had no proof
/// (M3-19, M3-21, M3-23, M3-55, M3-58) and the client half of two M2 rows
/// (M2-34, M2-100).
///
/// Everything runs on the fakes the other online suites use: [FakeBackend] as
/// the server (it answers; it does not simulate), a real [OnlineTransport] on
/// top of it, and for the screens the real `OnlineTableFlow` behind a fixed
/// `OnlineSession`. Copy comes from the app's own l10n lookups.
void main() {
  setUp(() {
    seedReturningProfile();
    OnlineSessionStore.writeOverride = null;
    OnlineMatchHistory.writeOverride = null;
  });
  tearDown(() {
    OnlineSessionStore.writeOverride = null;
    OnlineMatchHistory.writeOverride = null;
  });

  // ---------------------------------------------------------------------------
  // M3-19: a reconnect lands on the server's phase
  // ---------------------------------------------------------------------------
  group('M3-19', () {
    final phases =
        <({String server, GamePhase client, Map<String, dynamic> data})>[
          (
            server: 'morning',
            client: GamePhase.morning,
            data: {
              'morning': {
                'victimSeats': [1],
              },
            },
          ),
          (
            server: 'confront',
            client: GamePhase.confrontation,
            data: {
              'confrontation': {'type': 'c10', 'targetSeat': 0},
            },
          ),
          (server: 'discuss', client: GamePhase.discussion, data: const {}),
          (server: 'vote', client: GamePhase.voting, data: const {}),
          (
            server: 'verdict',
            client: GamePhase.reveal,
            data: {
              'lastVote': {'eliminatedSeat': null},
            },
          ),
          (
            server: 'result',
            client: GamePhase.result,
            data: {
              'outcome': 'town',
              'rosterSeats': [0, 1, 2, 3, 4],
              'standings': [
                {'seat': 0, 'role': 'citizen'},
              ],
            },
          ),
        ];

    for (final p in phases) {
      test('the transport reads the server\'s ${p.server} phase after a '
          'dropped link, whatever it showed before', () async {
        final backend = FakeBackend(
          roomId: 'room-1',
          state: roomState(phase: 'night', phaseNumber: 1),
          players: roster(5),
          own: const OwnSeat(seat: 0, role: 'citizen'),
        );
        final transport = await OnlineTransport.connect(
          backend: backend,
          roomId: 'room-1',
          heartbeatInterval: Duration.zero,
        );
        addTearDown(transport.dispose);
        expect(transport.snapshot.phase, GamePhase.night);

        backend.pushDisconnected();
        await pumpEventQueue();
        expect(transport.snapshot.connection, ConnectionQuality.reconnecting);

        // The room moved on while this device was away: no push reached it.
        backend.setState(
          roomState(
            phase: p.server,
            phaseNumber: 2,
            status: p.server == 'result' ? 'finished' : 'playing',
            publicData: p.data,
          ),
          push: false,
        );
        final reads = backend.fetches;
        backend.pushResync();
        await pumpEventQueue();

        expect(backend.fetches, greaterThan(reads), reason: 'it rereads');
        expect(transport.snapshot.phase, p.client);
        expect(transport.snapshot.dayNumber, 2);
        expect(transport.snapshot.connection, ConnectionQuality.connected);
      });
    }

    // The screens, for the five phases that have a line or a control of their
    // own to find; the result is drawn in M3-55 and M3-58.
    final screens =
        <({String server, Map<String, dynamic> data, Finder Function() find})>[
          (
            server: 'morning',
            data: {
              'morning': {
                'victimSeats': [1],
              },
            },
            find: () => find.text(arStrings.lostPlayerLastNight('B')),
          ),
          (
            server: 'confront',
            data: {
              'confrontation': {'type': 'c10', 'targetSeat': 0},
            },
            find: () => find.byKey(OnlineTableFlow.confrontationDone),
          ),
          (
            server: 'discuss',
            data: const {},
            find: () => find.text(arStrings.onlineFloorOpen),
          ),
          (
            server: 'vote',
            data: const {},
            find: () => find.text(arStrings.whoDoYouVoteOut),
          ),
          (
            server: 'verdict',
            data: {
              'lastVote': {'eliminatedSeat': null},
            },
            find: () => find.text(arStrings.nobodyEliminated),
          ),
        ];

    for (final s in screens) {
      _screenTest('the table shows the server\'s ${s.server} phase after a '
          'reconnect', (tester) async {
        final t = await _pumpTable(tester, phase: 'night');
        expect(s.find(), findsNothing);

        t.backend.pushDisconnected();
        await tester.pump();
        t.backend.setState(
          roomState(phase: s.server, phaseNumber: 2, publicData: s.data),
          push: false,
        );
        t.backend.pushResync();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(t.transport.snapshot.phase, isNot(GamePhase.night));
        expect(s.find(), findsOneWidget);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // M3-21: app killed during a paid write
  // ---------------------------------------------------------------------------
  group('M3-21', () {
    late FakeBackend economy;
    late _Server server;
    late OnlineTransport transport;

    setUp(() async {
      economy = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'discuss', phaseNumber: 2),
        players: roster(5),
      );
      server = _Server();
      economy.responders['economy'] = server.respond;
      // The table the tool is used at: day 2, so a kept narrator answer is
      // matched against phase number 2.
      transport = await OnlineTransport.connect(
        backend: FakeBackend(
          roomId: 'room-1',
          state: roomState(phase: 'discuss', phaseNumber: 2),
          players: roster(5),
          own: const OwnSeat(seat: 0, role: 'citizen'),
        ),
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      addTearDown(transport.dispose);
    });

    ProviderContainer start() {
      final container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => economy),
          gameTransportProvider.overrideWithValue(transport),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    List<Object?> actions() => [
      for (final call in economy.calls)
        if (call.function == 'economy') call.body['action'],
    ];

    int shelfCharges(ProviderContainer container, String code) => container
        .read(tableToolsProvider)
        .requireValue
        .tools
        .firstWhere((tool) => tool.code == code)
        .charges;

    test('a paid use whose answer is lost is sent once; the shelf is reread '
        'before anything else, and nothing is resent', () async {
      final container = start();
      await container.read(tableToolsProvider.future);
      expect(shelfCharges(container, 'anon_note'), 2);
      economy.calls.clear();

      await expectLater(
        container
            .read(tableToolsProvider.notifier)
            .use('room-1', 'anon_note', note: 'hi'),
        throwsA(isA<ToolActionFailed>()),
      );
      await pumpEventQueue();

      final sent = actions();
      expect(sent.where((a) => a == 'toolUse'), hasLength(1));
      final after = sent.sublist(sent.indexOf('toolUse') + 1);
      expect(after, contains('toolsGet'), reason: 'the receipt is reread');
      expect(after, isNot(contains('toolUse')), reason: 'and nothing retried');
      expect(server.uses, 1);
      // What the player sees is the server's record: one charge was spent.
      expect(shelfCharges(container, 'anon_note'), 1);

      // Time passing resends nothing either.
      await pumpEventQueue();
      expect(actions().where((a) => a == 'toolUse'), hasLength(1));
    });

    test('a narrator tool whose answer is lost returns the kept receipt '
        'instead of paying again', () async {
      final container = start();
      await container.read(tableToolsProvider.future);
      economy.calls.clear();

      final answer = await container
          .read(tableToolsProvider.notifier)
          .use('room-1', 'sense', targets: [3]);
      await pumpEventQueue();

      expect(answer, isTrue, reason: 'the answer the server kept');
      final sent = actions();
      expect(sent.where((a) => a == 'toolUse'), hasLength(1));
      expect(sent.indexOf('toolAnswers'), greaterThan(sent.indexOf('toolUse')));
      expect(server.uses, 1);
    });

    test('after the app is killed and started again the shelf is reread '
        'first and no paid write is sent by the client', () async {
      final killed = start();
      await killed.read(tableToolsProvider.future);
      await expectLater(
        killed
            .read(tableToolsProvider.notifier)
            .use('room-1', 'anon_note', note: 'hi'),
        throwsA(isA<ToolActionFailed>()),
      );
      await pumpEventQueue();
      expect(server.uses, 1);

      // The process dies; the server kept the use.
      killed.dispose();
      economy.calls.clear();

      final restarted = start();
      await restarted.read(tableToolsProvider.future);
      await pumpEventQueue();

      expect(actions(), ['toolsGet'], reason: 'a read, and nothing else');
      expect(shelfCharges(restarted, 'anon_note'), 1);
      expect(server.uses, 1, reason: 'the paid write was not sent again');
    });
  });

  // ---------------------------------------------------------------------------
  // M3-23: a network loss backs off, rereads and never goes backwards
  // ---------------------------------------------------------------------------
  group('M3-23', () {
    testWidgets('a lost link retries on a doubling clock, rereads the '
        'server\'s phase and forgets the delay once it is back', (
      tester,
    ) async {
      final backend = _CountingBackend(
        roomId: 'room-1',
        state: roomState(phase: 'discuss', phaseNumber: 2),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'citizen'),
      );
      // Non-zero: zero switches every timer off. An hour keeps the heartbeat
      // out of the way of the retry clock under test.
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: const Duration(hours: 1),
      );
      backend.attempts = 0;

      Future<void> elapse(int milliseconds) =>
          tester.pump(Duration(milliseconds: milliseconds));

      backend.unreachable = true;
      backend.pushDisconnected();
      await tester.pump();
      expect(transport.snapshot.connection, ConnectionQuality.reconnecting);
      // The room moves on while this device cannot hear it.
      backend.setState(roomState(phase: 'vote', phaseNumber: 2), push: false);

      await elapse(900);
      expect(backend.attempts, 0, reason: 'first retry waits a second');
      await elapse(200); // t = 1.1 s
      expect(backend.attempts, 1);
      await elapse(1700); // t = 2.8 s
      expect(backend.attempts, 1, reason: 'then two seconds');
      await elapse(400); // t = 3.2 s
      expect(backend.attempts, 2);
      await elapse(3600); // t = 6.8 s
      expect(backend.attempts, 2, reason: 'then four seconds');
      await elapse(400); // t = 7.2 s
      expect(backend.attempts, 3);
      expect(transport.snapshot.connection, ConnectionQuality.reconnecting);
      expect(transport.snapshot.phase, GamePhase.discussion);

      // The link comes back before the next attempt (eight seconds on).
      backend.unreachable = false;
      await tester.pump(const Duration(seconds: 8)); // t = 15.2 s
      expect(backend.attempts, 4);
      expect(transport.snapshot.phase, GamePhase.voting, reason: 'reread');
      expect(transport.snapshot.connection, ConnectionQuality.connected);

      // The delay is forgotten: the next loss retries after one second again.
      backend.unreachable = true;
      backend.pushDisconnected();
      await tester.pump();
      await elapse(1100);
      expect(backend.attempts, 5);

      await tester.runAsync(transport.dispose);
    });

    test('a slow reread overtaken by a newer phase push never puts an older '
        'phase back on screen', () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'discuss', phaseNumber: 2),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'citizen'),
      );
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      addTearDown(transport.dispose);
      final shown = <GamePhase>[];
      final sub = transport.watch().listen((s) => shown.add(s.phase));
      addTearDown(sub.cancel);
      await pumpEventQueue();

      backend.pushDisconnected();
      await pumpEventQueue();
      // The reconnect read leaves while the room is still in discussion.
      final slow = Completer<void>();
      backend.fetchGate = slow.future;
      backend.pushResync();
      await pumpEventQueue();
      // A newer push: the ballot has opened.
      backend.pushStateDelta(roomState(phase: 'vote', phaseNumber: 2));
      await pumpEventQueue();
      backend.fetchGate = null;
      slow.complete();
      await pumpEventQueue();

      expect(transport.snapshot.phase, GamePhase.voting);
      final firstBallot = shown.indexOf(GamePhase.voting);
      expect(firstBallot, isNonNegative);
      expect(
        shown.skip(firstBallot),
        everyElement(GamePhase.voting),
        reason: 'once the ballot is shown, nothing older follows it',
      );
    });

    // `testWidgets` takes a bool for `skip`; `group` takes the reason string.
    group('a roster push during a reconnect read', () {
      test('is not overwritten by the older read', () async {
        final backend = FakeBackend(
          roomId: 'room-1',
          state: roomState(phase: 'discuss', phaseNumber: 2),
          players: roster(5),
          own: const OwnSeat(seat: 0, role: 'citizen'),
        );
        final transport = await OnlineTransport.connect(
          backend: backend,
          roomId: 'room-1',
          heartbeatInterval: Duration.zero,
        );
        addTearDown(transport.dispose);

        backend.pushDisconnected();
        await pumpEventQueue();
        final slow = Completer<void>();
        backend.fetchGate = slow.future;
        backend.pushResync(); // reads the roster with everyone alive
        await pumpEventQueue();
        // Seat 2 dies; the push lands while that read is on the wire.
        backend.pushPlayer(
          roster(5)[2].copyWith(
            alive: false,
            lastSeen: DateTime.utc(2026, 9, 2, 12, 0, 1),
          ),
        );
        await pumpEventQueue();
        expect(transport.snapshot.public.players[2].status, PlayerStatus.dead);

        backend.fetchGate = null;
        slow.complete();
        await pumpEventQueue();

        expect(
          transport.snapshot.public.players[2].status,
          PlayerStatus.dead,
          reason: 'the older read must not bring seat 2 back to life',
        );
      });
    });
  });

  // ---------------------------------------------------------------------------
  // M3-55: a finished result survives a reconnect
  // ---------------------------------------------------------------------------
  group('M3-55', () {
    RoomState finished() => roomState(
      phase: 'result',
      phaseNumber: 3,
      status: 'finished',
      publicData: const {'outcome': 'town'},
    );

    FakeBackend fake() => FakeBackend(
      roomId: 'room-1',
      state: finished(),
      players: roster(3),
      own: const OwnSeat(seat: 0),
      userId: 'u0',
    );

    ProviderContainer containerFor(FakeBackend backend) {
      final container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          onlineHeartbeatProvider.overrideWithValue(Duration.zero),
          voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    int syncs(FakeBackend backend) => backend.calls
        .where((c) => c.function == 'economy' && c.body['action'] == 'sync')
        .length;

    test('saving a result refreshes both profile totals and record', () async {
      var statsReads = 0;
      var recordReads = 0;
      final backend = fake();
      final container = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          onlineHeartbeatProvider.overrideWithValue(Duration.zero),
          profileStatsProvider.overrideWith((ref) async {
            ref.watch(onlineHistoryRevisionProvider);
            statsReads++;
            return (0, 0);
          }),
          profileRecordProvider.overrideWith((ref) async {
            ref.watch(onlineHistoryRevisionProvider);
            recordReads++;
            return ProfileRecord.empty;
          }),
        ],
      );
      addTearDown(container.dispose);
      final stats = container.listen(profileStatsProvider, (_, __) {});
      final record = container.listen(profileRecordProvider, (_, __) {});
      addTearDown(stats.close);
      addTearDown(record.close);
      await container.read(profileStatsProvider.future);
      await container.read(profileRecordProvider.future);
      await container
          .read(onlineSessionProvider.notifier)
          .join(code: 'ABCDEF', name: 'A');
      await pumpEventQueue();
      expect(statsReads, greaterThan(1));
      expect(recordReads, greaterThan(1));
    });

    Future<void> reconnect(
      FakeBackend backend,
      OnlineTransport transport,
    ) async {
      backend.pushDisconnected();
      await pumpEventQueue();
      backend.pushResync();
      await pumpEventQueue();
      backend.setState(finished());
      await pumpEventQueue();
      await transport.resync();
      await pumpEventQueue();
    }

    test('the result is still there after a reconnect; the history row is '
        'written once and the reward sync is attempted once', () async {
      final backend = fake();
      final container = containerFor(backend);
      await container
          .read(onlineSessionProvider.notifier)
          .join(code: 'ABCDEF', name: 'A');
      await pumpEventQueue();

      expect(await OnlineMatchHistory.load(userId: 'u0'), hasLength(1));
      expect(syncs(backend), 1);
      final transport = container.read(onlineSessionProvider).transport!;

      await reconnect(backend, transport);

      expect(transport.snapshot.phase, GamePhase.result);
      expect(transport.snapshot.outcome?.winner, Alignment.town);
      expect(transport.snapshot.connection, ConnectionQuality.connected);
      final rows = await OnlineMatchHistory.load(userId: 'u0');
      expect(rows, hasLength(1), reason: 'written once');
      expect(rows.single['roomId'], 'room-1');
      expect(rows.single['winner'], 'town');
      expect(syncs(backend), 1, reason: 'the reward sync is not repeated');
      expect(await OnlineSessionStore.load(), isNull);
      expect(container.read(onlineSessionProvider).storageWarning, isFalse);
    });

    test('a reward service that refuses does not hide the result or get '
        'asked again on reconnect', () async {
      final backend = fake();
      backend.refusals['economy'] = const BackendException(
        'FEATURE_OFF',
        'rewards are off',
      );
      backend.stickyRefusals.add('economy');
      final container = containerFor(backend);
      await container
          .read(onlineSessionProvider.notifier)
          .join(code: 'ABCDEF', name: 'A');
      await pumpEventQueue();
      final transport = container.read(onlineSessionProvider).transport!;

      await reconnect(backend, transport);

      expect(transport.snapshot.phase, GamePhase.result);
      expect(await OnlineMatchHistory.load(userId: 'u0'), hasLength(1));
      expect(syncs(backend), 1, reason: 'attempted once, outage or not');
      expect(container.read(onlineSessionProvider).isInRoom, isTrue);
    });

    test('a restarted client reads the same finished room: still one history '
        'row, and its own single reward sync', () async {
      final first = fake();
      final before = containerFor(first);
      await before
          .read(onlineSessionProvider.notifier)
          .join(code: 'ABCDEF', name: 'A');
      await pumpEventQueue();
      expect(await OnlineMatchHistory.load(userId: 'u0'), hasLength(1));

      // The process dies and a new one rejoins the room by code.
      before.dispose();
      final second = fake();
      final after = containerFor(second);
      await after
          .read(onlineSessionProvider.notifier)
          .join(code: 'ABCDEF', name: 'A');
      await pumpEventQueue();

      expect(
        after.read(onlineSessionProvider).transport!.snapshot.phase,
        GamePhase.result,
      );
      expect(await OnlineMatchHistory.load(userId: 'u0'), hasLength(1));
      expect(syncs(second), 1);
    });
  });

  // ---------------------------------------------------------------------------
  // M3-58: result copy comes from the committed outcome and record
  // ---------------------------------------------------------------------------
  group('M3-58', () {
    /// A finished room: seat 1 died, seat 2 was silenced the morning of day 2
    /// (the stale morning block is still in the public data), seat 3 was
    /// removed by the host.
    Map<String, dynamic> resultData(String winner) => {
      'outcome': winner,
      'rosterSeats': [0, 1, 2, 3, 4],
      'morning': {'silencedSeat': 2},
      'standings': [
        {'seat': 0, 'role': 'mafia'},
        {'seat': 1, 'role': 'citizen', 'eliminatedPhase': 'night'},
        {'seat': 2, 'role': 'doctor'},
        {'seat': 3, 'role': 'detective', 'eliminatedPhase': 'day'},
        {'seat': 4, 'role': 'citizen'},
      ],
    };

    List<RoomPlayer> players() => [
      for (final p in roster(5))
        if (p.seat == 1)
          p.copyWith(alive: false)
        else if (p.seat == 3)
          p.copyWith(alive: false, kicked: true)
        else
          p,
    ];

    for (final winner in ['town', 'mafia']) {
      _screenTest('the result headline is the committed $winner outcome, '
          'whatever happened to a silenced or kicked seat', (tester) async {
        await _pumpTable(
          tester,
          phase: 'result',
          phaseNumber: 3,
          status: 'finished',
          publicData: resultData(winner),
          players: players(),
          settle: true,
        );

        final mafiaWon = winner == 'mafia';
        expect(
          find.text(mafiaWon ? arStrings.mafiaWins : arStrings.townWins),
          findsOneWidget,
        );
        expect(
          find.text(mafiaWon ? arStrings.townWins : arStrings.mafiaWins),
          findsNothing,
        );
        // The silence belonged to a morning; the result does not replay it.
        expect(find.text(arStrings.silencedAnnouncement('C')), findsNothing);
      });
    }

    test('the standings the client holds are exactly the committed record, '
        'dead, silenced and removed seats included', () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(
          phase: 'result',
          phaseNumber: 3,
          status: 'finished',
          publicData: resultData('town'),
        ),
        players: players(),
        own: const OwnSeat(seat: 0, role: 'mafia'),
      );
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      addTearDown(transport.dispose);

      final s = transport.snapshot;
      expect(s.outcome?.winner, Alignment.town);
      expect(
        [for (final standing in s.standings) (standing.seat, standing.role)],
        [
          (0, Role.mafia),
          (1, Role.citizen),
          (2, Role.doctor),
          (3, Role.detective),
          (4, Role.citizen),
        ],
      );
      // The result has no local record to open an autopsy from.
      expect(s.analyticsAvailable, isFalse);
      // The removed seat is still a seat of the table.
      expect(s.public.players, hasLength(5));
      expect(s.public.players[3].status, PlayerStatus.dead);
    });

    _screenTest('«شوف الأدوار» pages exactly the committed standings and '
        'names the first card\'s role from the record', (tester) async {
      await _pumpTable(
        tester,
        phase: 'result',
        phaseNumber: 3,
        status: 'finished',
        publicData: resultData('town'),
        players: players(),
        settle: true,
      );
      await tester.scrollUntilVisible(
        find.byKey(OnlineTableFlow.seeRoles),
        40,
        scrollable: find
            .descendant(
              of: find.byKey(OnlineTableFlow.resultScroll),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(OnlineTableFlow.seeRoles));
      // The result keeps animating behind the roster, so it never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(RoleRoster.page), findsOneWidget);
      expect(find.text(arStrings.onlineRosterOf(1, 5)), findsOneWidget);
      expect(
        find.text(EngineCopy.roleName(arStrings, Role.mafia)),
        findsOneWidget,
      );
      // One card at a time: no other role is on screen with it.
      expect(find.byType(RosterCard), findsOneWidget);
      expect(
        find.text(EngineCopy.roleName(arStrings, Role.detective)),
        findsNothing,
      );
      expect(
        find.text(EngineCopy.roleName(arStrings, Role.doctor)),
        findsNothing,
      );
    });

    _screenTest('a room closed without an outcome claims no winner and the '
        'device goes home', (tester) async {
      var exits = 0;
      await _pumpTable(
        tester,
        phase: 'result',
        phaseNumber: 3,
        status: 'finished',
        publicData: const {
          'rosterSeats': [0, 1, 2, 3, 4],
        },
        onExit: () => exits++,
        settle: true,
      );

      expect(find.text(arStrings.townWins), findsNothing);
      expect(find.text(arStrings.mafiaWins), findsNothing);
      await _letLeaveFinish(tester);
      expect(exits, 1);
    });

    for (final phase in ['reveal', 'night', 'morning', 'vote', 'verdict']) {
      _screenTest('a host closure during $phase sends the guest home without '
          'showing a result', (tester) async {
        var exits = 0;
        await _pumpTable(
          tester,
          phase: phase,
          status: 'finished',
          publicData: const {'rosterSeats': [0, 1, 2, 3, 4]},
          onExit: () => exits++,
        );
        await _letLeaveFinish(tester);
        expect(exits, 1, reason: phase);
        expect(find.text(arStrings.townWins), findsNothing);
        expect(find.text(arStrings.mafiaWins), findsNothing);
      });
    }

    _screenTest('a removed player is told so and goes home, with no winner '
        'and no role on their screen', (tester) async {
      var exits = 0;
      await _pumpTable(
        tester,
        phase: 'vote',
        phaseNumber: 2,
        players: [
          for (final p in roster(5))
            if (p.seat == 0) p.copyWith(alive: false, kicked: true) else p,
        ],
        onExit: () => exits++,
        settle: true,
      );

      expect(find.text(arStrings.onlineKickedByHost), findsOneWidget);
      await _letLeaveFinish(tester);
      expect(exits, 1);
      expect(find.text(arStrings.townWins), findsNothing);
      expect(find.text(arStrings.mafiaWins), findsNothing);
      for (final role in Role.values) {
        expect(find.text(EngineCopy.roleName(arStrings, role)), findsNothing);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // M2-34, client half: the online morning names the silenced seat
  // ---------------------------------------------------------------------------
  group('M2-34', () {
    _screenTest('the morning names the silenced seat for everyone', (
      tester,
    ) async {
      await _pumpTable(
        tester,
        phase: 'morning',
        phaseNumber: 2,
        publicData: {
          'morning': {
            'victimSeats': [1],
            'silencedSeat': 2,
          },
        },
      );

      expect(find.text(arStrings.lostPlayerLastNight('B')), findsOneWidget);
      expect(find.text(arStrings.silencedAnnouncement('C')), findsOneWidget);
    });

    _screenTest('a quiet morning with a silenced seat still names the seat', (
      tester,
    ) async {
      await _pumpTable(
        tester,
        phase: 'morning',
        phaseNumber: 2,
        publicData: {
          'morning': {'silencedSeat': 3},
        },
      );

      expect(find.text(arStrings.quietNight), findsOneWidget);
      expect(find.text(arStrings.silencedAnnouncement('D')), findsOneWidget);
    });

    _screenTest('every death is named with the silenced seat, in seat order '
        '(ruling RL10 with RL8)', (tester) async {
      await _pumpTable(
        tester,
        phase: 'morning',
        phaseNumber: 2,
        publicData: {
          'morning': {
            'victimSeats': [1, 4],
            'silencedSeat': 2,
          },
        },
      );

      expect(find.text(arStrings.lostPlayerLastNight('B · E')), findsOneWidget);
      expect(find.text(arStrings.silencedAnnouncement('C')), findsOneWidget);
    });

    _screenTest('a morning with nobody silenced announces no silence', (
      tester,
    ) async {
      await _pumpTable(
        tester,
        phase: 'morning',
        phaseNumber: 2,
        publicData: {
          'morning': {
            'victimSeats': [1],
          },
        },
      );

      for (final name in ['A', 'B', 'C', 'D', 'E']) {
        expect(find.text(arStrings.silencedAnnouncement(name)), findsNothing);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // M2-100, client half: a silenced Citizen has no ballot that day
  // ---------------------------------------------------------------------------
  group('M2-100', () {
    FilledButton confirm(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(OnlineTableFlow.confirmAction));

    _screenTest('the silenced Citizen has no ballot control that day, and '
        'nothing is sent', (tester) async {
      final t = await _pumpTable(
        tester,
        phase: 'vote',
        phaseNumber: 2,
        publicData: {
          'morning': {'silencedSeat': 0},
        },
      );

      expect(t.transport.snapshot.viewerSilenced, isTrue);
      expect(find.text(arStrings.silencedCannotVote), findsWidgets);
      expect(confirm(tester).onPressed, isNull);
      expect(find.byKey(OnlineTableFlow.abstain), findsNothing);

      // Picking a seat does not bring a ballot back.
      await tester.tap(find.byKey(TableScene.seatKey(1)));
      await tester.pump();
      expect(confirm(tester).onPressed, isNull);
      expect(t.backend.called('submit_vote'), isFalse);
    });

    _screenTest('the silenced seat is still on the table for the others to '
        'vote out', (tester) async {
      final t = await _pumpTable(
        tester,
        phase: 'vote',
        phaseNumber: 2,
        publicData: {
          'morning': {'silencedSeat': 0},
        },
        own: const OwnSeat(seat: 1, role: 'citizen'),
        userId: 'u1',
        seat: 1,
      );

      expect(t.transport.snapshot.viewerSilenced, isFalse);
      expect(
        t.transport.snapshot.public.players[0].status,
        PlayerStatus.alive,
        reason: 'still in the roster, still eligible',
      );
      await tester.tap(find.byKey(TableScene.seatKey(0)));
      await tester.pump();
      expect(find.text(arStrings.onlineChosen('A')), findsOneWidget);
      expect(confirm(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
      await tester.pump();
      await tester.pump();
      expect(t.backend.lastCall('submit_vote')?.body['targetSeat'], 0);
    });

    _screenTest('the next day the same Citizen has a live ballot again', (
      tester,
    ) async {
      final t = await _pumpTable(
        tester,
        phase: 'vote',
        phaseNumber: 2,
        publicData: {
          'morning': {'silencedSeat': 0},
        },
      );
      expect(confirm(tester).onPressed, isNull);

      // Day 3: a new vote, and nobody is silenced in its morning.
      t.backend.setState(
        roomState(
          phase: 'vote',
          phaseNumber: 3,
          publicData: {
            'morning': {
              'victimSeats': [4],
            },
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(t.transport.snapshot.viewerSilenced, isFalse);
      await tester.tap(find.byKey(TableScene.seatKey(1)));
      await tester.pump();
      expect(confirm(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
      await tester.pump();
      await tester.pump();
      expect(t.backend.lastCall('submit_vote')?.body['targetSeat'], 1);
    });

    test('the copy a silenced voter reads is the shared one, in both '
        'genders of address', () {
      expect(
        InformationText.silencedCannotVote(arStrings, female: false),
        arStrings.silencedCannotVote,
      );
      expect(
        InformationText.silencedCannotVote(arStrings, female: true),
        arStrings.silencedCannotVoteFemale,
      );
    });
  });
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

/// `testWidgets`, with the tree always taken down before the container goes,
/// so a failing expectation stays the only failure (see the offline rows file).
void _screenTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}

/// Leaving a room finishes on real I/O (the resume pointer is cleared in
/// shared preferences), so the fake clock has to let it run.
Future<void> _letLeaveFinish(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

/// The economy answers the result screen asks for (the layout suite's).
Map<String, dynamic> _economy(Map<String, dynamic> body) =>
    switch (body['action']) {
      'capabilities' => {
        'version': 2,
        'fun': {'awards': true, 'reactions': true, 'known': true},
      },
      'awards_get' => {
        'enabled': true,
        'ready': true,
        'awards': [
          {
            'code': 'mvp',
            'seats': [2],
            'names': ['C'],
            'coins': 20,
          },
        ],
        'mine': <String>[],
        'granted': 0,
      },
      _ => {'ok': true},
    };

class _Table {
  final FakeBackend backend;
  final OnlineTransport transport;
  final ProviderContainer container;
  const _Table(this.backend, this.transport, this.container);
}

/// The real `OnlineTableFlow` over a real transport on a [FakeBackend], behind
/// a fixed online session (as `online_result_layout_test` builds it).
Future<_Table> _pumpTable(
  WidgetTester tester, {
  String phase = 'vote',
  int phaseNumber = 1,
  String status = 'playing',
  Map<String, dynamic> publicData = const {},
  List<RoomPlayer>? players,
  OwnSeat own = const OwnSeat(seat: 0, role: 'citizen'),
  String userId = 'u0',
  int seat = 0,
  VoidCallback? onExit,
  bool settle = false,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final backend = FakeBackend(
    roomId: 'room-1',
    state: roomState(
      phase: phase,
      phaseNumber: phaseNumber,
      status: status,
      publicData: publicData,
    ),
    players: players ?? roster(5),
    own: own,
    userId: userId,
  );
  backend.responders['economy'] = _economy;
  final transport = await OnlineTransport.connect(
    backend: backend,
    roomId: 'room-1',
    heartbeatInterval: Duration.zero,
  );
  final container = ProviderContainer(
    overrides: [
      onlineBackendFactoryProvider.overrideWithValue(() async => backend),
      audioDirectorProvider.overrideWithValue(AudioDirector()),
      voiceEngineFactoryProvider.overrideWithValue(FakeVoiceEngine.new),
      voiceStatsIntervalProvider.overrideWithValue(Duration.zero),
      onlineSessionProvider.overrideWith(
        () => _FixedOnlineSession(
          RoomHandle(roomId: 'room-1', code: 'ABCDEF', seat: seat),
          transport,
        ),
      ),
    ],
  );
  addTearDown(() async {
    // A screen that sent the player home has already left the room, and with
    // it disposed the transport; disposing it a second time never completes.
    final left = container.read(onlineSessionProvider).transport == null;
    container.dispose();
    if (!left) await transport.dispose();
  });
  container.read(matchControllerProvider.notifier).adoptSnapshot();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: localizedApp(
        Scaffold(
          body: OnlineTableFlow(
            onExit: onExit ?? () {},
            onAnalytics: () {},
            onStepCommitted: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  if (settle) {
    await tester.pump(const Duration(seconds: 12));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }
  return _Table(backend, transport, container);
}

class _FixedOnlineSession extends OnlineSession {
  final RoomHandle handle;
  final OnlineTransport transport;
  _FixedOnlineSession(this.handle, this.transport);

  @override
  OnlineSessionState build() =>
      OnlineSessionState(room: handle, transport: transport);
}

/// A fake economy that keeps the server's books: what a paid use cost, and
/// the narrator's answer kept on the use row. It can lose the reply to a use,
/// which is the case under test.
class _Server {
  int charges = 2;
  int uses = 0;
  final List<Map<String, dynamic>> answers = [];

  Map<String, dynamic> _tool(String code, int targets) => {
    'code': code,
    'tier': 'light',
    'packs': {'1': 40},
    'charges': charges,
    'perMatch': 1,
    'phase': 'discuss',
    'targets': targets,
  };

  Map<String, dynamic> respond(Map<String, dynamic> body) {
    switch (body['action']) {
      case 'toolsGet':
        return {
          'balance': 100,
          'tools': [_tool('anon_note', 0), _tool('sense', 1)],
        };
      case 'toolUse':
        // Recorded and charged first, then the reply is lost.
        uses++;
        charges--;
        answers.add({
          'tool': body['tool'],
          'phaseNumber': 2,
          'targets': body['targets'],
          'answer': true,
        });
        throw const BackendUnreachable('connection reset');
      case 'toolAnswers':
        return {'answers': answers};
      default:
        return const {};
    }
  }
}

/// A [FakeBackend] that counts every full read it is asked for, including the
/// ones it refuses (the stock counter only counts reads that were answered).
class _CountingBackend extends FakeBackend {
  _CountingBackend({
    required super.roomId,
    required super.state,
    required super.players,
    super.own,
  });

  int attempts = 0;

  @override
  Future<RoomRows> fetchRows(String room) {
    attempts++;
    return super.fetchRows(room);
  }
}
