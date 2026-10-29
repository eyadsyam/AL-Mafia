import 'package:flutter/material.dart';
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

/// Update 1.5 / WP8 (#u6): the vote button names who it is about to vote for,
/// and a tie reads as a revote between the tied players. Copy only: the rules
/// (one revote, a second tie sends nobody out) are the engine's and unchanged.
void main() {
  final long = List.filled(20, 'م').join();

  Future<OnlineTransport> pumpVote(
    WidgetTester tester,
    Size size, {
    Map<String, dynamic> publicData = const {},
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'vote', publicData: publicData),
      players: [
        for (var seat = 0; seat < 5; seat++)
          RoomPlayer(
            userId: 'u$seat',
            seat: seat,
            name: seat == 1 || seat == 2
                ? long
                : String.fromCharCode(65 + seat),
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
    await tester.pump(const Duration(milliseconds: 600));
    return transport;
  }

  String buttonText(WidgetTester tester) {
    final button = find.byKey(OnlineTableFlow.confirmAction);
    return tester
        .widget<Text>(
          find.descendant(of: button, matching: find.byType(Text)).first,
        )
        .data!;
  }

  const sizes = [Size(360, 640), Size(390, 844), Size(640, 360)];

  for (final size in sizes) {
    testWidgets('the vote button names the chosen player at $size', (
      tester,
    ) async {
      await pumpVote(tester, size);
      expect(buttonText(tester), arStrings.confirmVote);
      await tester.tap(find.byKey(TableScene.seatKey(1)));
      await tester.pump();
      expect(buttonText(tester), arStrings.voteFor(long));
      expect(tester.takeException(), isNull);
      // A 20-letter name stays on the button's one line, inside the screen.
      final rect = tester.getRect(find.byKey(OnlineTableFlow.confirmAction));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
    });

    testWidgets('a tie reads as a revote between the tied at $size', (
      tester,
    ) async {
      await pumpVote(
        tester,
        size,
        publicData: {
          'revote': {
            'round': 2,
            'tiedSeats': [1, 2],
          },
        },
      );
      expect(find.text(arStrings.revoteBanner), findsOneWidget);
      expect(
        find.text(
          arStrings.revoteSlot([long, long].join(arStrings.revoteNamesJoiner)),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('the Arabic copy is the approved copy', () {
    expect(arStrings.voteFor('سيف'), 'صوّت على سيف');
    expect(arStrings.revoteBanner, 'إعادة تصويت بين المتعادلين');
    expect(
      arStrings.revoteSlot(['منى', 'هبة'].join(arStrings.revoteNamesJoiner)),
      'تقدر تختار منى أو هبة بس. لو اتعادلوا تاني محدش هيخرج.',
    );
  });
}
