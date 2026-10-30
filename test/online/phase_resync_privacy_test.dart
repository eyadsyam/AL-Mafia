import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const phases = <String, GamePhase>{
    'reveal': GamePhase.distributing,
    'night': GamePhase.night,
    'morning': GamePhase.morning,
    'confront': GamePhase.confrontation,
    'discuss': GamePhase.discussion,
    'vote': GamePhase.voting,
    'verdict': GamePhase.reveal,
    'result': GamePhase.result,
  };

  for (final entry in phases.entries) {
    testWidgets('X10 reconnect in ${entry.key} rebuilds its current screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(phase: 'night', phaseNumber: 1),
        players: roster(5),
        own: const OwnSeat(seat: 2, role: 'detective'),
        userId: 'u2',
      );
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      addTearDown(transport.dispose);
      backend.pushDisconnected();
      await tester.pump(const Duration(milliseconds: 16));
      backend.setState(
        roomState(
          phase: entry.key,
          phaseNumber: 2,
          status: entry.key == 'result' ? 'finished' : 'playing',
        ),
        push: false,
      );
      await transport.resync();

      expect(transport.snapshot.phase, entry.value);
      expect(transport.snapshot.dayNumber, 2);
      expect(transport.snapshot.viewerSeat, 2);
      expect(transport.mySeat, 2);
      expect(backend.fetches, 2);
      expect(await transport.secretsFor(1), isNull);
      final mine = await transport.secretsFor(2);
      if (entry.key == 'result') {
        expect(mine, isNull);
      } else {
        expect(mine?.seat, 2);
        expect(mine?.role, Role.detective);
        expect(mine?.investigation, isNull);
        expect(mine?.whisperBody, isNull);
      }
      final container = ProviderContainer(
        overrides: [
          gameTransportProvider.overrideWithValue(transport),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
        ],
      );
      addTearDown(container.dispose);
      container.read(matchControllerProvider.notifier).adoptSnapshot();
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
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.widget<TableScene>(find.byType(TableScene)).snapshot.phase,
        entry.value,
      );
    });
  }

  test(
    'X10 resync drops last night detective answer and whisper from UI state',
    () async {
      final backend = FakeBackend(
        roomId: 'room-1',
        state: roomState(
          phase: 'night',
          phaseNumber: 1,
          settings: const {'whisperEnabled': true},
        ),
        players: roster(5),
        own: const OwnSeat(seat: 0, role: 'detective'),
        whispers: const [
          WhisperRow(id: 'w1', day: 1, fromSeat: 1, toSeat: 0, toMe: true),
        ],
      );
      backend.bodies['w1'] = 'private answer';
      backend.responses['submit_night_action'] = const {
        'ok': true,
        'revealedRole': 'mafia',
      };
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room-1',
        heartbeatInterval: Duration.zero,
      );
      final container = ProviderContainer(
        overrides: [gameTransportProvider.overrideWithValue(transport)],
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
      });
      final controller = container.read(matchControllerProvider.notifier);
      controller.adoptSnapshot();
      await controller.openActorTurn();
      expect(container.read(matchControllerProvider)?.whisper, isNotNull);
      await controller.submitNightAction(
        kind: NightActionKind.investigate,
        targetSeat: 1,
      );
      expect(
        container.read(matchControllerProvider)?.investigateResult,
        isNotNull,
      );

      backend.setWhispers(const []);
      backend.setState(
        roomState(phase: 'morning', phaseNumber: 2),
        push: false,
      );
      await transport.resync();
      await pumpEventQueue();
      final state = container.read(matchControllerProvider);
      expect(state?.phase, GamePhase.morning);
      // Doc 05 rule 10: a new server phase must clear every old private answer.
      expect(state?.investigateResult, isNull);
      expect(state?.whisper, isNull);
      expect(state?.actorTurn, isNull);
      expect((await transport.secretsFor(0))?.investigation, isNull);
      expect((await transport.secretsFor(0))?.whisperBody, isNull);
    },
  );
}
