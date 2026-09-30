import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Doc 05: while the deal waits, the headline is a count. A Mafia card carries
/// the teammate list, so who is still looking at theirs would be a role signal.
void main() {
  testWidgets('the deal names nobody: a count of cards still being read', (
    tester,
  ) async {
    const names = ['Zaid', 'Yusuf', 'Karim', 'Hadeer', 'Mona'];
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'reveal', phaseNumber: 1),
      players: [
        for (var seat = 0; seat < names.length; seat++)
          RoomPlayer(
            userId: 'u$seat',
            seat: seat,
            name: names[seat],
            alive: true,
            lastSeen: DateTime.utc(2026, 9, 2, 12),
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
    await tester.pump();
    await container
        .read(matchControllerProvider.notifier)
        .confirmRevealedCommitted();
    await tester.pump();
    await tester.pump();

    expect(transport.snapshot.unseenRoleSeats, isNotEmpty);
    // Seat faces elsewhere on the table carry names as always; the waiting
    // line itself must carry none of them.
    final lines = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((text) => text.contains('لسه'))
        .toList();
    expect(lines, isNotEmpty, reason: 'the count line is shown');
    for (final line in lines) {
      for (final name in names) {
        expect(line.contains(name), isFalse, reason: '$name named in "$line"');
      }
    }
  });
}
