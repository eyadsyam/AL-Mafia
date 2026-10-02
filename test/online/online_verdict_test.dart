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
  }) => roomState(
    phase: 'verdict',
    phaseNumber: 1,
    hostId: hostId,
    publicData: {
      'lastVote': {
        'tally': {'1': 3},
        'eliminatedSeat': eliminatedSeat,
        'eliminatedRole': role,
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
      state: verdict(eliminatedSeat: null, role: null),
    );
    await tester.pump();

    expect(find.byType(CardRise), findsNothing);
  });

  testWidgets('the host moves the room on, and a guest waits', (tester) async {
    await pumpTable(tester, state: verdict());
    await tester.pump();
    expect(find.byKey(OnlineTableFlow.hostAdvance), findsOneWidget);

    await tester.tap(find.byKey(OnlineTableFlow.hostAdvance));
    await tester.pump();
    expect(backend.lastCall('open_phase')?.body['phase'], equals('night'));
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
  testWidgets('the host can open the ballot without waiting', (tester) async {
    await pumpTable(tester, state: roomState(phase: 'discuss', phaseNumber: 1));
    await tester.pump();

    expect(find.byKey(OnlineTableFlow.hostAdvance), findsOneWidget);
    await tester.tap(find.byKey(OnlineTableFlow.hostAdvance));
    await tester.pump();
    expect(backend.lastCall('open_phase')?.body['phase'], equals('vote'));
  });
}
