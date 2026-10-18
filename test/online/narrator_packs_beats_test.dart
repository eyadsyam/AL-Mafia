import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/narrator_bank.dart' as voice;
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/table/room_presentation.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

RoomState _state(
  String phase,
  String pack, {
  int number = 1,
  String discussionMode = 'structured',
  Map<String, dynamic> publicData = const {},
}) => RoomState(
  phase: phase,
  phaseNumber: number,
  status: phase == 'result' ? 'finished' : 'playing',
  hostId: 'u0',
  code: 'ABCDEF',
  serverNow: DateTime.utc(2026, 9, 29, 18),
  publicData: publicData,
  settings: {'narratorPack': pack, 'discussionMode': discussionMode},
);

GameSnapshot _table(
  GamePhase phase,
  String pack, {
  int day = 1,
  required int seats,
}) => GameSnapshot(
  public: PublicMatchView(
    phase: phase,
    dayNumber: day,
    players: [
      for (var seat = 0; seat < seats; seat++)
        PublicPlayer(seat: seat, name: 'P$seat', status: PlayerStatus.alive),
    ],
  ),
  viewerSeat: 0,
  connection: ConnectionQuality.connected,
  room: RoomOptions(narratorPack: pack),
);

void main() {
  for (final pack in const [
    'narrator_storyteller',
    'narrator_keeper',
    'narrator_noir',
  ]) {
    for (final seats in [4, 20]) {
      testWidgets(
        '$pack ($seats seats): public beats show safe text and request its clips',
        (tester) async {
          // The same transport, provider overrides, and phase driver used by
          // test/widget/online_narrator_test.dart; the bank is the pack's shipped manifest.
          final backend = FakeBackend(
            roomId: 'room',
            state: _state('lobby', pack),
            players: roster(seats),
            own: const OwnSeat(seat: 0, role: 'citizen'),
          );
          final transport = await OnlineTransport.connect(
            backend: backend,
            roomId: 'room',
            heartbeatInterval: Duration.zero,
          );
          final bank = voice.NarratorBank.fromJson(
            File(voice.narratorPackManifests[pack]!).readAsStringSync(),
          );
          final audio = AudioDirector()..registerNarratorBank(pack, bank);
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

          Future<void> enter(RoomState state, voice.NarratorBeat beat) async {
            final before = audio.emittedNarration.length;
            backend.setState(state);
            await tester.pump();
            await tester.pump();
            expect(
              audio.emittedNarration.length,
              before + 1,
              reason: beat.name,
            );
            final id = audio.emittedNarration.last;
            final clip = bank.clips.singleWhere((c) => c.id == id);
            expect(clip.beat, beat);
            expect(clip.id, startsWith('${pack}_'));
            expect(clip.file, startsWith('voice/$pack/'));
            expect(
              File('assets/${clip.file}').existsSync(),
              isTrue,
              reason: 'Selected recording must ship with the app',
            );
          }

          await enter(_state('night', pack), voice.NarratorBeat.night);
          await enter(
            _state(
              'morning',
              pack,
              publicData: const {
                'morning': {'victimSeat': 2},
              },
            ),
            voice.NarratorBeat.morning,
          );
          // The public discussion beat is offered in both free and structured talk.
          await enter(
            _state('discuss', pack, number: 2, discussionMode: 'free'),
            voice.NarratorBeat.discussion,
          );
          await enter(
            _state('vote', pack, number: 2),
            voice.NarratorBeat.voting,
          );
          await enter(
            _state('discuss', pack, number: 3, discussionMode: 'structured'),
            voice.NarratorBeat.discussion,
          );
          await enter(
            _state('vote', pack, number: 3),
            voice.NarratorBeat.voting,
          );
          await enter(
            _state(
              'verdict',
              pack,
              number: 3,
              publicData: const {
                'lastVote': {
                  'tally': {'1': 3},
                  'eliminatedSeat': 1,
                  'eliminatedRole': 'mafia',
                  'tiedSeats': <int>[],
                },
              },
            ),
            voice.NarratorBeat.result,
          );
          await enter(
            _state(
              'result',
              pack,
              number: 3,
              publicData: const {'outcome': 'town'},
            ),
            voice.NarratorBeat.win,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();

          // RoomPresentationLayer is the existing caption driver. Its local
          // public-moment constructor also exposes the vote-result announcement.
          final narrationCount = audio.emittedNarration.length;
          audio.muted = true;
          audio.emittedAccents.clear();
          final narrator = Cosmetics.narrators[pack]!;
          Future<void> show(
            GamePhase phase, {
            int day = 1,
            NarrationBeat? moment,
            bool check = true,
          }) async {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [audioDirectorProvider.overrideWithValue(audio)],
                child: localizedApp(
                  Stack(
                    children: [
                      if (moment == null)
                        RoomPresentationLayer(
                          key: const ValueKey('layer'),
                          snapshot: _table(phase, pack, day: day, seats: seats),
                        )
                      else
                        RoomPresentationLayer.local(
                          key: const ValueKey('layer'),
                          snapshot: _table(phase, pack, day: day, seats: seats),
                          packCode: null,
                          narratorCode: pack,
                          visibleIn: (_) => false,
                          moment: moment,
                        ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pump();
            if (!check) return;
            final beat = moment ?? beatFor(phase)!;
            final line = narrator.line(arStrings, beat);
            expect(
              find.text(line),
              findsOneWidget,
              reason: '$pack ${beat.name} must remain readable when muted',
            );
            for (var seat = 0; seat < seats; seat++) {
              expect(
                line,
                isNot(contains('P$seat')),
                reason: 'doc 05: a narrator line cannot identify a seat',
              );
            }
            for (final role in [
              arStrings.roleMafia,
              arStrings.roleSilencer,
              arStrings.roleDoctor,
              arStrings.roleDetective,
              arStrings.roleElder,
              arStrings.roleSniper,
              arStrings.roleCitizen,
            ]) {
              expect(
                line,
                isNot(contains(role)),
                reason: 'doc 05: a narrator line cannot name a role',
              );
            }
            if (audio.muted) expect(audio.emittedAccents, isEmpty);
          }

          for (final muted in [false, true]) {
            audio.muted = muted;
            audio.emittedAccents.clear();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await show(GamePhase.discussion, check: false);
            await show(GamePhase.night);
            await show(GamePhase.morning);
            await show(GamePhase.discussion);
            await show(GamePhase.voting);
            await show(GamePhase.reveal, moment: NarrationBeat.result);
            await show(GamePhase.result);
          }
          expect(audio.emittedNarration.length, narrationCount);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        },
      );
    }
  }
}
