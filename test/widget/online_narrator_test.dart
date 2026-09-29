import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/narrator_bank.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

NarratorClip _clip(NarratorBeat beat) => NarratorClip(
  id: 'pack_${beat.name}',
  beat: beat,
  when: 'always',
  family: true,
  file: 'voice/narrator_noir/${beat.name}.ogg',
);

RoomState _state(
  String phase, {
  int number = 1,
  Map<String, dynamic> publicData = const {},
}) => RoomState(
  phase: phase,
  phaseNumber: number,
  status: phase == 'result' ? 'finished' : 'playing',
  hostId: 'u0',
  code: 'ABCDEF',
  serverNow: DateTime.utc(2026, 9, 29, 18),
  publicData: publicData,
  settings: const {'narratorPack': 'narrator_noir'},
);

void main() {
  testWidgets('online public beats narrate once and never in-hand', (
    tester,
  ) async {
    final backend = FakeBackend(
      roomId: 'room',
      state: _state('lobby'),
      players: roster(5),
      own: const OwnSeat(seat: 0, role: 'citizen'),
    );
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room',
      heartbeatInterval: Duration.zero,
    );
    final audio = AudioDirector()
      ..registerNarratorBank(
        'narrator_noir',
        NarratorBank([
          _clip(NarratorBeat.night),
          _clip(NarratorBeat.morning),
          _clip(NarratorBeat.discussion),
          _clip(NarratorBeat.voting),
          _clip(NarratorBeat.win),
        ]),
      );
    final container = ProviderContainer(
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await transport.dispose();
    });
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
    await tester.pump();

    Future<void> enter(RoomState state, NarratorBeat beat) async {
      final before = audio.emittedNarration.length;
      backend.setState(state);
      await tester.pump();
      await tester.pump();
      expect(audio.emittedNarration.length, before + 1, reason: beat.name);
      expect(audio.emittedNarration.last, 'pack_${beat.name}');
      await tester.pump();
      expect(
        audio.emittedNarration.length,
        before + 1,
        reason: '${beat.name} replayed',
      );
    }

    await enter(_state('night'), NarratorBeat.night);
    await enter(
      _state(
        'morning',
        publicData: const {
          'morning': {'victimSeat': 2},
        },
      ),
      NarratorBeat.morning,
    );
    await enter(_state('discuss', number: 2), NarratorBeat.discussion);
    await enter(_state('vote', number: 2), NarratorBeat.voting);
    await enter(
      _state('result', number: 2, publicData: const {'outcome': 'town'}),
      NarratorBeat.win,
    );

    audio.setLocation(PhoneLocation.inHand);
    final beforePrivate = audio.emittedNarration.length;
    backend.setState(_state('discuss', number: 3));
    await tester.pump();
    await tester.pump();
    expect(audio.emittedNarration.length, beforePrivate);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
