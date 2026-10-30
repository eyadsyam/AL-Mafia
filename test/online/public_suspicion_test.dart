import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/suspect_sheet.dart';
import 'package:mafia_master/ui/screens/online/table/suspicion_threads.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// «أنا شاكك في» online (owner, 2026-10-30): a living, unsilenced player taps
/// a seat in the discussion and names it out loud; the table draws the same
/// threads and counts for everyone; the dead and the silenced cannot.
void main() {
  Map<String, dynamic> data({
    Map<String, int> today = const {},
    int? silenced,
  }) => {
    'suspicions': {
      '2': today,
      '1': {'4': 0},
    },
    if (silenced != null) 'morning': {'silencedSeat': silenced},
  };

  Future<(FakeBackend, OnlineTransport)> connect({
    String phase = 'discuss',
    Map<String, int> today = const {},
    int? silenced,
    Set<int> dead = const {},
  }) async {
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(
        phase: phase,
        phaseNumber: 2,
        hostId: 'u4',
        publicData: data(today: today, silenced: silenced),
      ),
      players: roster(5, dead: dead),
      own: const OwnSeat(seat: 0, role: 'citizen'),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    addTearDown(transport.dispose);
    return (backend, transport);
  }

  test('today\'s picks are read, yesterday\'s are not', () async {
    final (_, t) = await connect(today: {'1': 3, '2': 3});
    expect(t.snapshot.publicSuspicions, {1: 3, 2: 3});
  });

  test('threads in seat order and a count per named seat', () async {
    final (_, t) = await connect(today: {'2': 3, '1': 3, '4': 1});
    expect(suspicionThreads(t.snapshot), [(1, 3), (2, 3), (4, 1)]);
  });

  test('no threads outside the day', () async {
    final (_, t) = await connect(phase: 'night', today: {'1': 3});
    expect(suspicionThreads(t.snapshot), isEmpty);
  });

  test('who may name whom', () async {
    var (_, t) = await connect();
    expect(SuspectSheet.mayName(t.snapshot, 2), isTrue);
    expect(SuspectSheet.mayName(t.snapshot, 0), isFalse, reason: 'yourself');
    (_, t) = await connect(dead: {2});
    expect(SuspectSheet.mayName(t.snapshot, 2), isFalse, reason: 'the dead');
    (_, t) = await connect(silenced: 0);
    expect(SuspectSheet.mayName(t.snapshot, 2), isFalse, reason: 'silenced');
    (_, t) = await connect(dead: {0});
    expect(SuspectSheet.mayName(t.snapshot, 2), isFalse, reason: 'dead viewer');
    (_, t) = await connect(phase: 'vote');
    expect(SuspectSheet.mayName(t.snapshot, 2), isFalse, reason: 'the vote');
  });

  late OnlineTransport live;
  late ProviderContainer scope;

  /// Timers on the table (clocks, the transport's alarm) go with the widget.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    scope.dispose();
    unawaited(live.dispose());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<FakeBackend> table(
    WidgetTester tester, {
    Map<String, int> today = const {},
    int? silenced,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(430, 932);
    addTearDown(tester.view.reset);
    final (backend, transport) = await connect(
      today: today,
      silenced: silenced,
    );
    final container = ProviderContainer(
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
        onlineSessionProvider.overrideWith(
          () => _Session(OnlineSessionState(transport: transport)),
        ),
      ],
    );
    live = transport;
    scope = container;
    container.read(matchControllerProvider.notifier).adoptSnapshot();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          OnlineTableFlow(
            onExit: () {},
            onAnalytics: () {},
            onStepCommitted: () {},
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return backend;
  }

  Future<void> tapSeat(WidgetTester tester, int seat) async {
    await tester.tap(
      find.byKey(CouncilBand.seatKey(seat)),
      warnIfMissed: false,
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a seat tap in the discussion names it out loud', (tester) async {
    final backend = await table(tester);
    await tapSeat(tester, 3);
    expect(find.byKey(SuspectSheet.suspectAction), findsOneWidget);
    await tester.tap(find.byKey(SuspectSheet.suspectAction));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final call = backend.lastCall('public_suspicion');
    expect(call?.body['targetSeat'], 3);
    expect(find.byKey(SuspectSheet.suspectAction), findsNothing);
    await done(tester);
  });

  testWidgets('the seat already named offers taking it back', (tester) async {
    final backend = await table(tester, today: {'0': 3});
    await tapSeat(tester, 3);
    await tester.tap(find.byKey(SuspectSheet.clearAction));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(backend.lastCall('public_suspicion')?.body['targetSeat'], isNull);
    expect(
      backend.lastCall('public_suspicion')?.body.containsKey('targetSeat'),
      isTrue,
    );
    await done(tester);
  });

  testWidgets('the named seat carries its count', (tester) async {
    await table(tester, today: {'1': 3, '2': 3});
    expect(find.byKey(SuspicionCount.keyFor(3)), findsOneWidget);
    expect(find.text(arStrings.suspectCountShort(2)), findsOneWidget);
    await done(tester);
  });

  testWidgets('a silenced player\'s tap opens nothing', (tester) async {
    final backend = await table(tester, silenced: 0);
    await tapSeat(tester, 3);
    expect(find.byKey(SuspectSheet.suspectAction), findsNothing);
    expect(backend.called('public_suspicion'), isFalse);
    await done(tester);
  });
}

class _Session extends OnlineSession {
  _Session(this.initial);
  final OnlineSessionState initial;

  @override
  OnlineSessionState build() => initial;
}
