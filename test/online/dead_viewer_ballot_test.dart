import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Found in a real web match on the hosted server (2026-11-10): a player
/// killed on night one landed on a ballot the bots had already opened, and the
/// table asked «مين يخرج؟ … أكّد صوتك» of the dead, before their death beat
/// had finished. The dead never get a ballot.
void main() {
  testWidgets('a dead viewer is never offered the ballot', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'vote'),
      players: [
        for (var seat = 0; seat < 5; seat++)
          RoomPlayer(
            userId: 'u$seat',
            seat: seat,
            name: String.fromCharCode(65 + seat),
            alive: seat != 0,
            lastSeen: DateTime.utc(2026, 11, 10, 12),
          ),
      ],
      own: const OwnSeat(seat: 0, role: 'citizen'),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    final container = ProviderContainer(
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
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(OnlineTableFlow.confirmAction), findsNothing);
    expect(find.text(arStrings.whoDoYouVoteOut), findsNothing);
    expect(find.text(arStrings.onlineVoteSelectHint), findsNothing);

    // And after the death beat has played out: still no ballot.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(OnlineTableFlow.confirmAction), findsNothing);
  });
}
