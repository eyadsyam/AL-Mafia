import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

void main() {
  late FakeBackend backend;
  late OnlineTransport transport;
  late ProviderContainer container;
  var committed = 0;

  Future<void> pumpTable(
    WidgetTester tester, {
    String phase = 'vote',
    bool select = true,
    int? votedRound,
  }) async {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: phase),
      players: roster(5),
      own: OwnSeat(seat: 0, role: 'citizen', votedRound: votedRound),
    );
    transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    container = ProviderContainer(
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
    container.read(matchControllerProvider.notifier).adoptSnapshot();
    addTearDown(() async {
      container.dispose();
      await transport.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          OnlineTableFlow(
            onExit: () {},
            onAnalytics: () {},
            onStepCommitted: () => committed++,
          ),
        ),
      ),
    );
    await tester.pump();
    // Seat 1 on the council. Doc 15 §1.3 moved the name onto the painter's
    // canvas, so there is no `Text` to find — the seat's hit target is the
    // shipped affordance and the only honest thing to tap.
    if (select) await tester.tap(find.byKey(TableScene.seatKey(1)));
    await tester.pump();
  }

  setUp(() => committed = 0);

  testWidgets(
    'a revote selects only tied living opponents and sends round two',
    (tester) async {
      await pumpTable(tester, select: false);
      backend.setState(
        roomState(
          phase: 'vote',
          publicData: {
            'revote': {
              'round': 2,
              'tiedSeats': [1, 2],
            },
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(arStrings.tieRevoteHeadline), findsOneWidget);
      await tester.tap(find.byKey(TableScene.seatKey(3)));
      await tester.pump();
      expect(find.text(arStrings.onlineChosen('D')), findsNothing);
      expect(find.text(arStrings.onlineVoteSelectHint), findsOneWidget);
      await tester.tap(find.byKey(TableScene.seatKey(2)));
      await tester.pump();
      expect(find.text(arStrings.onlineChosen('C')), findsOneWidget);
      await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
      await tester.pump();
      await tester.pump();
      expect(backend.lastCall('submit_vote')?.body['targetSeat'], 2);
      expect(backend.lastCall('submit_vote')?.body['round'], 2);
      expect(find.text(arStrings.onlineVoteReceived), findsOneWidget);
    },
  );

  testWidgets('recovered server receipt keeps the ballot submitted', (
    tester,
  ) async {
    await pumpTable(tester, select: false, votedRound: 1);
    expect(find.text(arStrings.onlineVoteReceived), findsOneWidget);
    expect(find.byKey(OnlineTableFlow.confirmAction), findsNothing);
    expect(find.text(arStrings.whoDoYouVoteOut), findsNothing);
  });

  testWidgets(
    'a same-day revote unlocks the ballot without replaying an old receipt',
    (tester) async {
      await pumpTable(tester, select: false, votedRound: 1);
      backend.setState(
        roomState(
          phase: 'vote',
          publicData: {
            'revote': {
              'round': 2,
              'tiedSeats': [1, 2],
            },
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(arStrings.onlineVoteReceived), findsNothing);
      expect(find.byKey(OnlineTableFlow.confirmAction), findsOneWidget);
      expect(find.text(arStrings.onlineVoteSelectHint), findsOneWidget);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'old-round ${fails ? 'failure' : 'success'} cannot overwrite a new ballot',
      (tester) async {
        await pumpTable(tester);
        final old = Completer<Map<String, dynamic>>();
        backend.delayedResponses['submit_vote'] = old.future;
        await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
        await tester.pump();
        backend.setState(
          roomState(
            phase: 'vote',
            publicData: {
              'revote': {
                'round': 2,
                'tiedSeats': [1, 2],
              },
            },
          ),
        );
        await tester.pump();
        await tester.pump();
        if (fails) {
          old.completeError(const BackendUnreachable('offline'));
        } else {
          old.complete(const {'ok': true});
        }
        await tester.pump();
        await tester.pump();
        expect(committed, 0);
        expect(find.text(arStrings.actionNotSaved), findsNothing);
        expect(find.text(arStrings.onlineVoteReceived), findsNothing);
        expect(find.byKey(OnlineTableFlow.confirmAction), findsOneWidget);
      },
    );
  }

  testWidgets('a failed vote stays selected and can be retried', (
    tester,
  ) async {
    await pumpTable(tester);
    backend.unreachable = true;

    await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
    await tester.pump();
    await tester.pump();

    expect(find.text(arStrings.actionNotSaved), findsOneWidget);
    expect(find.text(arStrings.onlineVoteReceived), findsNothing);
    expect(find.text(arStrings.whoDoYouVoteOut), findsOneWidget);
    expect(find.byKey(OnlineTableFlow.confirmAction), findsOneWidget);
    expect(committed, 0);

    backend.unreachable = false;
    await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
    await tester.pump();
    await tester.pump();

    expect(find.text(arStrings.actionNotSaved), findsNothing);
    expect(
      backend.calls.where((call) => call.function == 'submit_vote'),
      hasLength(1),
    );
    expect(committed, 1);
    expect(find.text(arStrings.onlineVoteReceived), findsOneWidget);
  });

  testWidgets('two taps while an acknowledgement is pending send once', (
    tester,
  ) async {
    await pumpTable(tester);
    final acknowledgement = Completer<Map<String, dynamic>>();
    backend.delayedResponses['submit_vote'] = acknowledgement.future;

    final confirm = find.byKey(OnlineTableFlow.confirmAction);
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();

    expect(
      backend.calls.where((call) => call.function == 'submit_vote'),
      hasLength(1),
    );
    expect(committed, 0);
    expect(find.text(arStrings.onlineVoteSending), findsOneWidget);
    expect(find.text(arStrings.onlineVoteReceived), findsNothing);

    acknowledgement.complete(const {'ok': true});
    await tester.pump();
    await tester.pump();
    expect(committed, 1);
    expect(find.text(arStrings.onlineVoteSending), findsNothing);
    expect(find.text(arStrings.onlineVoteReceived), findsOneWidget);
  });

  testWidgets('an unselected ballot explains the required gesture', (
    tester,
  ) async {
    await pumpTable(tester, select: false);
    expect(find.text(arStrings.onlineVoteSelectHint), findsOneWidget);
    await tester.tap(find.byKey(TableScene.seatKey(1)));
    await tester.pump();
    expect(find.text(arStrings.onlineVoteSelectHint), findsNothing);
  });

  testWidgets(
    'a closed-phase refusal without a receipt is never reported as saved',
    (tester) async {
      await pumpTable(tester);
      backend.refusals['submit_vote'] = const BackendException(
        'PHASE_CLOSED',
        'closed',
      );
      await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
      await tester.pump();
      await tester.pump();
      expect(find.text(arStrings.onlineVoteReceived), findsNothing);
      expect(find.text(arStrings.actionNotSaved), findsOneWidget);
      expect(committed, 0);
    },
  );

  testWidgets('an older failed request cannot undo a successful revote', (
    tester,
  ) async {
    await pumpTable(tester);
    final old = Completer<Map<String, dynamic>>();
    backend.delayedResponses['submit_vote'] = old.future;
    await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
    await tester.pump();
    backend.setState(
      roomState(
        phase: 'vote',
        publicData: {
          'revote': {
            'round': 2,
            'tiedSeats': [1, 2],
          },
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    backend.delayedResponses.remove('submit_vote');
    await tester.tap(find.byKey(TableScene.seatKey(2)));
    await tester.pump();
    await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
    await tester.pump();
    await tester.pump();
    expect(find.text(arStrings.onlineVoteReceived), findsOneWidget);
    old.completeError(const BackendUnreachable('old request failed'));
    await tester.pump();
    await tester.pump();
    expect(committed, 1);
    expect(transport.snapshot.viewerVoteRecorded, isTrue);
    expect(transport.snapshot.ballotRound, 2);
    expect(find.text(arStrings.actionNotSaved), findsNothing);
    expect(find.byKey(OnlineTableFlow.confirmAction), findsNothing);
    expect(find.text(arStrings.onlineVoteReceived), findsOneWidget);
  });

  testWidgets('a late acknowledgement does not advance the next phase', (
    tester,
  ) async {
    await pumpTable(tester);
    final acknowledgement = Completer<Map<String, dynamic>>();
    backend.delayedResponses['submit_vote'] = acknowledgement.future;
    await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
    await tester.pump();
    backend.setState(roomState(phase: 'discuss', phaseNumber: 2));
    await tester.pump();
    await tester.pump();
    acknowledgement.complete(const {'ok': true});
    await tester.pump();
    await tester.pump();
    expect(committed, 0);
    expect(find.text(arStrings.onlineVoteReceived), findsNothing);
    expect(find.text(arStrings.onlineFloorOpen), findsOneWidget);
  });

  testWidgets('the host stays host while another seat holds the floor', (
    tester,
  ) async {
    // Found on a real device against the hosted server: a guest claimed the
    // floor and the host's «ابدأ التصويت» was nowhere on screen.
    await pumpTable(tester, phase: 'discuss', select: false);
    // The hosted realtime row: `room_state` columns only, no host or rules.
    backend.pushStateDelta(roomState(phase: 'discuss', activeSpeaker: 'u1'));
    await tester.pump();
    await tester.pump();
    expect(transport.isHost, isTrue);
    expect(transport.snapshot.canAdvance, isTrue);
    expect(transport.snapshot.activeSpeakerSeat, 1);
    // No name in the middle of the table and no host button: the speaker is
    // the glowing seat, and the ballot opens on the clock (owner, 2026-09-23).
    expect(find.text(arStrings.onlineDiscussionLive), findsOneWidget);
    expect(find.text(arStrings.onlineBeginVoting), findsNothing);
  });

  testWidgets('a same-phase realtime row keeps the room rules and code', (
    tester,
  ) async {
    await pumpTable(tester, phase: 'vote', select: false);
    // Rules that differ from every default, so losing them is visible.
    backend.setState(
      RoomState(
        phase: 'vote',
        phaseNumber: 1,
        status: 'playing',
        hostId: 'u0',
        code: 'ABCDEF',
        serverNow: DateTime.utc(2026, 9, 2, 12),
        settings: const {'abstainAllowed': true, 'whisperEnabled': true},
      ),
    );
    await tester.pump();
    await tester.pump();
    final before = transport.snapshot;
    expect(before.settings.abstainAllowed, isTrue);
    expect(before.settings.whisperEnabled, isTrue);
    backend.pushStateDelta(
      roomState(
        phase: 'vote',
        publicData: {
          'revote': {
            'round': 2,
            'tiedSeats': [1, 2],
          },
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    final after = transport.snapshot;
    expect(transport.code, 'ABCDEF');
    expect(after.canAdvance, isTrue);
    expect(after.settings.abstainAllowed, isTrue);
    expect(after.settings.whisperEnabled, isTrue);
    expect(after.ballotRound, 2);
  });
}
