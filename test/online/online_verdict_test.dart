import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/council/card_rise.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// The beat between the ballot and the night that follows it.
///
/// Offline it has always existed — the eliminated player's card rises and turns
/// over, doc 15 §S-O12. Online it had nowhere to happen: `resolve_vote` set the
/// phase straight to `night`, `phaseFromServer` never produced
/// `GamePhase.reveal`, and every line of this screen written for it was
/// unreachable. A player cast a vote and arrived at a dark table.
void main() {
  late FakeBackend backend;
  late OnlineTransport transport;
  late ProviderContainer container;

  Future<void> pumpTable(
    WidgetTester tester, {
    required RoomState state,
    String userId = 'u0',
  }) async {
    backend = FakeBackend(
      roomId: 'room-1',
      state: state,
      players: roster(5),
      own: const OwnSeat(seat: 0, role: 'citizen'),
      userId: userId,
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
            onStepCommitted: () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  RoomState verdict({
    int? eliminatedSeat = 1,
    String? role = 'mafia',
    String hostId = 'u0',
    List<int> tiedSeats = const [],
  }) => roomState(
    phase: 'verdict',
    phaseNumber: 1,
    hostId: hostId,
    publicData: {
      'lastVote': {
        'tally': {'1': 3},
        'eliminatedSeat': eliminatedSeat,
        'eliminatedRole': role,
        'tiedSeats': tiedSeats,
      },
    },
  );

  testWidgets('the card rises, and says what they were', (tester) async {
    await pumpTable(tester, state: verdict());
    await tester.pump();

    expect(find.byType(CardRise), findsOneWidget);
    // The card carries the role. It is the one moment a role becomes public
    // without the match being over, and it is public because the table watched
    // the vote that made it so.
    final card = tester.widget<CardRise>(find.byType(CardRise));
    expect(card.role, equals(Role.mafia));
    expect(card.name, equals('B'));
  });

  testWidgets('a tie has no card to rise', (tester) async {
    await pumpTable(
      tester,
      state: verdict(eliminatedSeat: null, role: null, tiedSeats: [1, 2]),
    );
    await tester.pump();

    expect(find.byType(CardRise), findsNothing);
    expect(find.text(arStrings.tieNoEliminationHeadline), findsOneWidget);
    expect(find.text(arStrings.tieRevoteHeadline), findsNothing);
  });

  testWidgets('a verdict without elimination does not invent a tie or revote', (
    tester,
  ) async {
    await pumpTable(tester, state: verdict(eliminatedSeat: null, role: null));
    expect(find.text(arStrings.nobodyEliminated), findsOneWidget);
    expect(find.text(arStrings.tieRevoteHeadline), findsNothing);
    expect(find.text(arStrings.tieNoEliminationHeadline), findsNothing);
  });

  // Owner decision 2026-09-23: once the match starts the room moves by
  // itself, for everybody at once. The host sets the room up; they do not
  // press «كمل» through it.
  testWidgets('nobody is shown a «كمل», the host included', (tester) async {
    await pumpTable(tester, state: verdict());
    await tester.pump();
    expect(find.byKey(OnlineTableFlow.hostAdvance), findsNothing);
    expect(backend.called('open_phase'), isFalse);
  });

  testWidgets('a guest is shown no button they cannot press', (tester) async {
    await pumpTable(
      tester,
      state: verdict(hostId: 'u4'),
      userId: 'u0',
    );
    await tester.pump();

    expect(find.byKey(OnlineTableFlow.hostAdvance), findsNothing);
  });

  // The discussion used to run its full five minutes whatever the room did,
  // because there was no control to end it: `open_phase` allowed discuss → vote
  // at any time, and nothing on the screen ever asked for it.
  testWidgets('the discussion has no host control', (tester) async {
    await pumpTable(tester, state: roomState(phase: 'discuss', phaseNumber: 1));
    await tester.pump();
    expect(find.byKey(OnlineTableFlow.hostAdvance), findsNothing);
  });

  // Owner, 2026-09-24: the living end the discussion together. Each says
  // «جاهز للتصويت»; the server opens the ballot when every living seat has.
  group('ready to vote', () {
    RoomState discuss({Map<String, dynamic> publicData = const {}}) =>
        roomState(phase: 'discuss', phaseNumber: 2, publicData: publicData);

    testWidgets('the button says it and counts the table', (tester) async {
      await pumpTable(
        tester,
        state: discuss(
          publicData: {
            'readyToVote': {
              'number': 2,
              'seats': [3],
            },
          },
        ),
      );
      await tester.pump();
      expect(transport.snapshot.readyToVoteSeats, {3});
      expect(find.text(arStrings.readyToVote(1, 5)), findsOneWidget);

      await tester.tap(find.byKey(OnlineTableFlow.readyToVote));
      await tester.pump();
      expect(backend.lastCall('ready_to_vote')?.body['ready'], isTrue);
    });

    testWidgets('once said, the same button takes it back', (tester) async {
      await pumpTable(
        tester,
        state: discuss(
          publicData: {
            'readyToVote': {
              'number': 2,
              'seats': [0, 3],
            },
          },
        ),
      );
      await tester.pump();
      expect(find.text(arStrings.readyToVoteWaiting(2, 5)), findsOneWidget);
      await tester.tap(find.byKey(OnlineTableFlow.readyToVote));
      await tester.pump();
      expect(backend.lastCall('ready_to_vote')?.body['ready'], isFalse);
    });

    testWidgets('a set from an earlier day belongs to that day, not this one', (
      tester,
    ) async {
      await pumpTable(
        tester,
        state: discuss(
          publicData: {
            'readyToVote': {
              'number': 1,
              'seats': [0, 1, 2, 3, 4],
            },
          },
        ),
      );
      await tester.pump();
      expect(transport.snapshot.readyToVoteSeats, isEmpty);
      expect(find.text(arStrings.readyToVote(0, 5)), findsOneWidget);
    });
  });
}
