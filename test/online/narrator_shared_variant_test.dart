import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/narrator_bank.dart' as voice;
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Audit M4-16: an online table hears one narrator. Each phone used to roll
/// its own dice among a beat's recordings, so two seats on the same voice
/// call could speak two different lines over each other.
const _pack = 'narrator_keeper';

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
  settings: const {'narratorPack': _pack, 'discussionMode': 'structured'},
);

voice.NarratorBank _bank(Random random) => voice.NarratorBank.fromJson(
  File(voice.narratorPackManifests[_pack]!).readAsStringSync(),
  random: random,
);

void main() {
  test('the variant number is the same on every platform', () {
    // FNV-1a, fixed here so a change to it is a decision, not an accident:
    // web and Android phones at one table must compute the same number.
    expect(voice.NarratorBank.variantFor('room/2/1/night'), 731585586);
  });

  test('one variant names one recording, whatever a phone played before', () {
    final a = _bank(Random(1));
    final b = _bank(Random(99));
    // A morning after one death fits several recordings in this pack.
    const facts = voice.NarrationFacts(nightEliminated: 1);
    // B has already spoken a line for this beat; A has not.
    b.pick(voice.NarratorBeat.morning, facts);
    final seen = <String>{};
    for (var v = 0; v < 12; v++) {
      final fromA = a.pick(voice.NarratorBeat.morning, facts, variant: v);
      final fromB = b.pick(voice.NarratorBeat.morning, facts, variant: v);
      expect(fromA?.id, fromB?.id, reason: 'variant $v');
      seen.add(fromA!.id);
    }
    expect(seen.length, greaterThan(1), reason: 'variants still vary');
  });

  testWidgets('two seats at one online table hear the same recordings', (
    tester,
  ) async {
    Future<List<String>> listen(OwnSeat own, Random dice) async {
      final backend = FakeBackend(
        roomId: 'room',
        state: _state('lobby'),
        players: roster(7),
        own: own,
      );
      final transport = await OnlineTransport.connect(
        backend: backend,
        roomId: 'room',
        heartbeatInterval: Duration.zero,
      );
      final bank = _bank(dice);
      // This phone has spoken before, so its "not twice in a row" memory
      // differs from the other phone's.
      bank.pick(voice.NarratorBeat.night, voice.NarrationFacts.none);
      final audio = AudioDirector()..registerNarratorBank(_pack, bank);
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
      for (final state in [
        _state('night'),
        _state(
          'morning',
          publicData: const {
            'morning': {'victimSeat': 2},
          },
        ),
        _state('discuss', number: 2),
        _state('vote', number: 2),
        _state('night', number: 2),
        _state('morning', number: 2),
        _state('discuss', number: 3),
        _state('vote', number: 3),
        _state('result', number: 3, publicData: const {'outcome': 'town'}),
      ]) {
        backend.setState(state);
        await tester.pump();
        await tester.pump();
      }
      final heard = List<String>.of(audio.emittedNarration);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      return heard;
    }

    final citizen = await listen(
      const OwnSeat(seat: 0, role: 'citizen'),
      Random(3),
    );
    final mafioso = await listen(
      const OwnSeat(seat: 4, role: 'mafia'),
      Random(41),
    );
    expect(citizen, isNotEmpty);
    expect(mafioso, citizen);
  });
}
