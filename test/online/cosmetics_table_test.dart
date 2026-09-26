import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/screens/online/table/room_presentation.dart';
import 'package:mafia_master/ui/screens/online/table/table_mood.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';

import '../support/localized.dart';

GameSnapshot table(
  GamePhase phase, {
  int day = 1,
  int viewerSeat = 0,
  String pack = 'classic',
  String narrator = 'classic',
}) => GameSnapshot(
  public: PublicMatchView(
    phase: phase,
    dayNumber: day,
    players: [
      for (var seat = 0; seat < 6; seat++)
        PublicPlayer(seat: seat, name: 'P$seat', status: PlayerStatus.alive),
    ],
  ),
  viewerSeat: viewerSeat,
  connection: ConnectionQuality.connected,
  room: RoomOptions(presentationPack: pack, narratorPack: narrator),
  seatCosmetics: const {
    1: SeatCosmetics(frame: 'frame_crimson', plate: 'plate_ember'),
    2: SeatCosmetics(frame: 'frame_gilded'),
  },
);

void main() {
  group('purchased identity on the council', () {
    test('frames and plates show in every public phase', () {
      for (final phase in [
        GamePhase.morning,
        GamePhase.discussion,
        GamePhase.voting,
        GamePhase.reveal,
        GamePhase.result,
      ]) {
        final seats = TableScene.seatsFor(
          table(phase),
          mood: TableMood.of(phase),
        );
        final one = seats.singleWhere((s) => s.seat == 1);
        expect(one.frame, 'frame_crimson', reason: '$phase');
        expect(one.plate, 'plate_ember', reason: '$phase');
      }
    });

    test('doc 05 rule 3: no purchased colour on a night surface', () {
      for (final phase in [
        GamePhase.distributing,
        GamePhase.preNightLobby,
        GamePhase.night,
        GamePhase.nightResolving,
      ]) {
        final seats = TableScene.seatsFor(
          table(phase),
          mood: TableMood.of(phase),
        );
        expect(
          seats.every((s) => s.frame == null && s.plate == null),
          isTrue,
          reason: '$phase',
        );
      }
    });

    test('every device draws the same seats, whoever is looking', () {
      final a = TableScene.seatsFor(
        table(GamePhase.discussion, viewerSeat: 0),
        mood: TableMood.of(GamePhase.discussion),
      );
      final b = TableScene.seatsFor(
        table(GamePhase.discussion, viewerSeat: 5),
        mood: TableMood.of(GamePhase.discussion),
      );
      for (final seat in [1, 2, 3, 4]) {
        final x = a.singleWhere((s) => s.seat == seat);
        final y = b.singleWhere((s) => s.seat == seat);
        expect((x.frame, x.plate), (y.frame, y.plate));
      }
    });

    test('the server row carries the choice; unknown codes are harmless', () {
      final player = RoomPlayer.fromJson({
        'user_id': 'u',
        'seat': 3,
        'cosmetics': {'frame': 'frame_moonlit', 'nameplate': 'plate_x'},
      });
      expect(player.cosmetics!.frame, 'frame_moonlit');
      expect(Cosmetics.plates[player.cosmetics!.plate], isNull);
      expect(
        RoomPlayer.fromJson({'user_id': 'u', 'seat': 1}).cosmetics,
        isNull,
      );
      // Survives presence updates.
      expect(
        player.copyWith(connected: false).cosmetics!.frame,
        'frame_moonlit',
      );
    });
  });

  group('the room pack and narrator', () {
    late AudioDirector audio;
    setUp(() => audio = AudioDirector());

    Future<void> show(WidgetTester tester, GameSnapshot snapshot) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [audioDirectorProvider.overrideWithValue(audio)],
            child: localizedApp(
              Stack(children: [RoomPresentationLayer(snapshot: snapshot)]),
            ),
          ),
        );

    testWidgets('a fast private phase removes the public caption immediately', (
      tester,
    ) async {
      await show(tester, table(GamePhase.night, pack: 'pack_old_town'));
      await show(tester, table(GamePhase.morning, pack: 'pack_old_town'));
      expect(find.text(arStrings.packOldTownIntro), findsOneWidget);
      await show(tester, table(GamePhase.night, day: 2, pack: 'pack_old_town'));
      expect(find.byKey(NarrationCaption.captionKey), findsNothing);
      expect(find.byKey(PackTransitionOverlay.overlayKey), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('private resolving removes even the neutral night caption', (
      tester,
    ) async {
      await show(
        tester,
        table(GamePhase.discussion, narrator: 'narrator_storyteller'),
      );
      await show(
        tester,
        table(GamePhase.night, narrator: 'narrator_storyteller'),
      );
      expect(find.text(arStrings.narratorNight), findsOneWidget);
      await show(
        tester,
        table(GamePhase.nightResolving, narrator: 'narrator_storyteller'),
      );
      expect(find.byKey(NarrationCaption.captionKey), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('reduced motion hides an already running transition', (
      tester,
    ) async {
      Future<void> showTransition(int trigger, {bool reduced = false}) =>
          tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: PackTransitionOverlay(
                  pack: Cosmetics.packs['pack_old_town'],
                  trigger: trigger,
                ),
              ),
            ),
          );
      await showTransition(0);
      await showTransition(1);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(PackTransitionOverlay.overlayKey), findsOneWidget);
      await showTransition(1, reduced: true);
      expect(find.byKey(PackTransitionOverlay.overlayKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening line and sound on the first public morning only', (
      tester,
    ) async {
      await show(tester, table(GamePhase.night, pack: 'pack_old_town'));
      await tester.pump();
      expect(find.byKey(NarrationCaption.captionKey), findsNothing);
      expect(audio.emittedAccents, isEmpty);

      await show(tester, table(GamePhase.morning, pack: 'pack_old_town'));
      await tester.pump();
      expect(find.text(arStrings.packOldTownIntro), findsOneWidget);
      expect(audio.emittedAccents, [
        Cosmetics.packs['pack_old_town']!.introSound,
      ]);
      expect(find.byKey(PackTransitionOverlay.overlayKey), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await show(tester, table(GamePhase.night, day: 2, pack: 'pack_old_town'));
      await tester.pump();
      await show(
        tester,
        table(GamePhase.morning, day: 2, pack: 'pack_old_town'),
      );
      await tester.pump();
      expect(find.text(arStrings.packOldTownIntro), findsNothing);
      expect(audio.emittedAccents, hasLength(1));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await show(
        tester,
        table(GamePhase.result, day: 2, pack: 'pack_old_town'),
      );
      await tester.pump();
      expect(find.text(arStrings.packOldTownOutro), findsOneWidget);
      expect(
        audio.emittedAccents.last,
        Cosmetics.packs['pack_old_town']!.outroSound,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('the narrator marks the night in text, with no sound', (
      tester,
    ) async {
      await show(
        tester,
        table(GamePhase.discussion, narrator: 'narrator_storyteller'),
      );
      await show(
        tester,
        table(GamePhase.night, day: 2, narrator: 'narrator_storyteller'),
      );
      await tester.pump();
      expect(find.text(arStrings.narratorNight), findsOneWidget);
      expect(audio.emittedAccents, isEmpty);
      // Nothing is drawn over the night surface but the neutral caption.
      expect(find.byKey(PackTransitionOverlay.overlayKey), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.narratorNight), findsNothing);

      await show(
        tester,
        table(GamePhase.voting, day: 2, narrator: 'narrator_storyteller'),
      );
      await tester.pump();
      expect(find.text(arStrings.narratorVoting), findsOneWidget);
      expect(audio.emittedAccents, [
        Cosmetics.narrators['narrator_storyteller']!.accent,
      ]);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('a classic room adds nothing', (tester) async {
      await show(tester, table(GamePhase.discussion));
      await show(tester, table(GamePhase.voting));
      await tester.pump();
      expect(find.byKey(NarrationCaption.captionKey), findsNothing);
      expect(find.byKey(PackTransitionOverlay.overlayKey), findsNothing);
      expect(audio.emittedAccents, isEmpty);
    });

    testWidgets('muted rooms hear nothing, and still read the line', (
      tester,
    ) async {
      audio.muted = true;
      await show(
        tester,
        table(GamePhase.discussion, narrator: 'narrator_storyteller'),
      );
      await show(
        tester,
        table(GamePhase.voting, narrator: 'narrator_storyteller'),
      );
      await tester.pump();
      expect(find.text(arStrings.narratorVoting), findsOneWidget);
      expect(audio.emittedAccents, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
