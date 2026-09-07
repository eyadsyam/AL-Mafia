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

  Future<void> pumpTable(WidgetTester tester) async {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'vote'),
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
            onStepCommitted: () => committed++,
          ),
        ),
      ),
    );
    await tester.pump();
    // Seat 1 on the council. Doc 15 §1.3 moved the name onto the painter's
    // canvas, so there is no `Text` to find — the seat's hit target is the
    // shipped affordance and the only honest thing to tap.
    await tester.tap(find.byKey(TableScene.seatKey(1)));
    await tester.pump();
  }

  setUp(() => committed = 0);

  testWidgets('a failed vote stays selected and can be retried', (
    tester,
  ) async {
    await pumpTable(tester);
    backend.unreachable = true;

    await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
    await tester.pump();
    await tester.pump();

    expect(find.text(arStrings.actionNotSaved), findsOneWidget);
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

    acknowledgement.complete(const {'ok': true});
    await tester.pump();
    await tester.pump();
    expect(committed, 1);
  });
}
