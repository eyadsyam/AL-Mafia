import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/council/voice_band.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Online, the Elder's waiting screen carries one button «اكشف نفسي الصبح»
/// (owner, 2026-11-19), only for a living Elder who has not revealed. It
/// sends `reveal`, can be undone with `unreveal`, and nobody else sees it.
void main() {
  late FakeBackend backend;

  Future<void> pumpAs(
    WidgetTester tester,
    Role role, {
    Map<String, dynamic> publicData = const {},
    bool dead = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'night', phaseNumber: 1, publicData: publicData),
      players: roster(6),
      own: OwnSeat(seat: 0, role: role.name, alive: !dead),
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
  }

  Iterable<FakeCall> sent() =>
      backend.calls.where((c) => c.function == 'submit_night_action');

  testWidgets('a living unrevealed Elder gets the button and it sends reveal', (
    tester,
  ) async {
    await pumpAs(tester, Role.elder);
    expect(find.text(arStrings.nightElderRevealTile), findsOneWidget);
    await tester.tap(find.byKey(ElderRevealChip.tile));
    await tester.pump();
    await tester.pump();
    expect(sent().single.body['action'], 'reveal');
    expect(find.text(arStrings.nightElderRevealNote), findsOneWidget);
    expect(find.text(arStrings.nightElderRevealUndo), findsOneWidget);

    await tester.tap(find.byKey(ElderRevealChip.undo));
    await tester.pump();
    await tester.pump();
    expect(sent().last.body['action'], 'unreveal');
    expect(find.text(arStrings.nightElderRevealTile), findsOneWidget);
  });

  for (final role in [Role.citizen, Role.mafia, Role.doctor, Role.detective]) {
    testWidgets('a ${role.name} never sees it', (tester) async {
      await pumpAs(tester, role);
      expect(find.text(arStrings.nightElderRevealTile), findsNothing);
      expect(find.byKey(ElderRevealChip.tile), findsNothing);
    });
  }

  testWidgets('a revealed Elder no longer sees it', (tester) async {
    await pumpAs(
      tester,
      Role.elder,
      publicData: const {
        'elderRevealedSeats': [0],
      },
    );
    expect(find.byKey(ElderRevealChip.tile), findsNothing);
  });
}
