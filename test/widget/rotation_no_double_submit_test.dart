import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

void main() {
  Future<(FakeBackend, ProviderContainer)> pumpTable(
    WidgetTester tester, String phase,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: phase),
      players: roster(5),
      own: OwnSeat(seat: 0, role: phase == 'night' ? 'doctor' : 'citizen'),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    final container = ProviderContainer(overrides: [
      gameTransportProvider.overrideWithValue(transport),
      audioDirectorProvider.overrideWithValue(AudioDirector()),
    ]);
    container.read(matchControllerProvider.notifier).adoptSnapshot();
    addTearDown(() async {
      container.dispose();
      await transport.dispose();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: localizedApp(OnlineTableFlow(
        onExit: () {}, onAnalytics: () {}, onStepCommitted: () {},
      )),
    ));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    return (backend, container);
  }

  for (final scenario in <({String phase, Size size, String label})>[
    (phase: 'vote', size: const Size(932, 430), label: 'landscape'),
    (phase: 'night', size: const Size(932, 430), label: 'landscape'),
    (phase: 'night', size: const Size(600, 800), label: 'screen resize'),
  ]) {
    testWidgets('X18 ${scenario.phase} target survives ${scenario.label} and submits once',
        (tester) async {
      final phase = scenario.phase;
      final (backend, _) = await pumpTable(tester, phase);
      await tester.tap(find.byKey(TableScene.seatKey(1)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<TableScene>(find.byType(TableScene)).selectedSeat, 1);

      await tester.binding.setSurfaceSize(scenario.size);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<TableScene>(find.byType(TableScene)).selectedSeat, 1);
      expect(backend.called(phase == 'vote' ? 'submit_vote' : 'submit_night_action'),
          isFalse);

      final acknowledgement = Completer<Map<String, dynamic>>();
      final function = phase == 'vote' ? 'submit_vote' : 'submit_night_action';
      backend.delayedResponses[function] = acknowledgement.future;
      if (phase == 'vote') {
        await tester.tap(find.byKey(OnlineTableFlow.confirmAction));
      } else {
        final hold = await tester.startGesture(
          tester.getCenter(find.byType(HoldPad)),
        );
        await tester.pump(MafiaTiming.defaults.holdToReveal);
        await hold.up();
      }
      await tester.pump(const Duration(milliseconds: 16));
      expect(backend.calls.where((c) => c.function == function), hasLength(1));
      expect(backend.lastCall(function)?.body['targetSeat'], 1);

      await tester.binding.setSurfaceSize(const Size(430, 932));
      await tester.pump(const Duration(milliseconds: 16));
      expect(backend.calls.where((c) => c.function == function), hasLength(1));
      acknowledgement.complete(const {'ok': true});
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(backend.calls.where((c) => c.function == function), hasLength(1));
    });
  }
}
