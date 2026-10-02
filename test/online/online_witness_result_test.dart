import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/witness/witness_panel.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// A seat put out of the match keeps the witness panel — the graveyard, the
/// prediction, the record — for as long as there is a match to witness.
/// Once the room is on its result, the panel asked «مين هيكسب؟» of an outcome
/// already on the table and stood in front of the result's own two controls:
/// the last player voted out had no «الرئيسية» to press.
void main() {
  late FakeBackend backend;
  late OnlineTransport transport;
  late ProviderContainer container;
  var exits = 0;

  Future<void> pumpTable(
    WidgetTester tester, {
    required RoomState state,
  }) async {
    // A phone, not the 800×600 default: the hand band's share of a 600px
    // surface is a hair short of the result's two stacked controls.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend = FakeBackend(
      roomId: 'room-1',
      state: state,
      players: roster(5, dead: const {0, 1}),
      own: const OwnSeat(seat: 0, role: 'mafia', alive: false),
      userId: 'u0',
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
            onExit: () => exits++,
            onAnalytics: () {},
            onStepCommitted: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    // The elimination beat plays out first; the witness panel comes after it.
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
  }

  testWidgets(
    'a dead seat at the result gets the result controls, not the witness panel',
    (tester) async {
      await pumpTable(
        tester,
        state: roomState(
          phase: 'result',
          phaseNumber: 2,
          status: 'finished',
          publicData: const {
            'outcome': 'town',
            'rosterSeats': [0, 1, 2, 3, 4],
            'standings': [
              {
                'seat': 0,
                'role': 'mafia',
                'eliminatedPhase': 'day',
                'eliminatedNumber': 2,
              },
              {
                'seat': 1,
                'role': 'citizen',
                'eliminatedPhase': 'night',
                'eliminatedNumber': 1,
              },
              {'seat': 2, 'role': 'doctor'},
              {'seat': 3, 'role': 'detective'},
              {'seat': 4, 'role': 'citizen'},
            ],
          },
        ),
      );

      expect(
        find.byType(WitnessPanel),
        findsNothing,
        reason: 'the match is over; there is nothing left to predict',
      );
      expect(find.byKey(OnlineTableFlow.seeRoles), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'الرئيسية'));
      // Home from a completed result leaves the room first (1.0.1), then
      // exits — at the latest when the leave bound runs out.
      await tester.pump();
      await tester.pump(MafiaTiming.leaveBeforeAd);
      expect(exits, 1);
    },
  );
}
