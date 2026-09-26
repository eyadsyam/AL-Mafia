import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// The card comes back when it was taken away by mistake.
///
/// Dismissing a card is irreversible on the device that did it, and the phase
/// it gates is refused until every seat has been acknowledged *on the server*.
/// So the two have to be the same event. They were not: a `saw_role` the room
/// never received cleared the card anyway, and the screen's private-view hold
/// — a plain flag, set the first time a card appeared and never cleared until
/// the phase changed — made sure it could not be asked for again. The seat sat
/// in its own waiting list, «كمل» refused for the whole room, until everybody
/// gave up.
void main() {
  late FakeBackend backend;
  late OnlineTransport transport;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'reveal', phaseNumber: 1),
      players: roster(5),
      own: const OwnSeat(seat: 0, role: 'citizen'),
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
    await tester.pump();
  }

  testWidgets('the deal puts this seat its own card', (tester) async {
    await pump(tester);
    expect(find.byType(RoleCard), findsOneWidget);
  });

  testWidgets('a lost acknowledgement does not dismiss it', (tester) async {
    await pump(tester);
    expect(find.byType(RoleCard), findsOneWidget);

    backend.unreachable = true;
    await expectLater(
      container
          .read(matchControllerProvider.notifier)
          .confirmRevealedCommitted(),
      throwsA(isA<BackendUnreachable>()),
    );
    await tester.pump();

    expect(
      find.byType(RoleCard),
      findsOneWidget,
      reason: 'the only way left to try again may not be taken away',
    );
  });

  testWidgets('nor does a yes that wrote nothing', (tester) async {
    await pump(tester);
    backend.ignoreSawRole = true;

    await expectLater(
      container
          .read(matchControllerProvider.notifier)
          .confirmRevealedCommitted(),
      throwsA(isA<BackendException>()),
    );
    await tester.pump();

    expect(find.byType(RoleCard), findsOneWidget);
    expect(transport.snapshot.unseenRoleSeats, contains(0));
  });

  testWidgets('and the room is still told who it is waiting for', (
    tester,
  ) async {
    await pump(tester);
    backend.ignoreSawRole = true;
    await container
        .read(matchControllerProvider.notifier)
        .confirmRevealedCommitted()
        .catchError((_) {});
    await tester.pump();

    // Nobody may open the night on this room's behalf while it is still
    // waiting on a card, and the screen says so rather than offering a button
    // that would be refused.
    expect(transport.snapshot.unseenRoleSeats, isNotEmpty);
  });

  testWidgets('an acknowledged card leaves, and stays gone', (tester) async {
    await pump(tester);
    await container
        .read(matchControllerProvider.notifier)
        .confirmRevealedCommitted();
    await tester.pump();
    expect(find.byType(RoleCard), findsNothing);

    // A later push must not hand it back: this seat owes the deal nothing now,
    // and a card returning after it was put down would be the leak L-14 names.
    backend.setState(roomState(phase: 'reveal', phaseNumber: 1));
    await tester.pump();
    await tester.pump();
    expect(find.byType(RoleCard), findsNothing);
  });
}
