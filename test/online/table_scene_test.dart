import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/information/records.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/online/council/seat_status.dart';
import 'package:mafia_master/ui/screens/online/table/table_mood.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

/// The council, on glass.
///
/// `doc12_acceptance_test.dart` asserts the *rules* — that the mood table
/// refuses per-seat status at night. This file asserts that the widget which
/// reads those rules actually obeys them, because a correct rule and a widget
/// that ignores it is the exact shape of every leak doc 05 has ever had.
///
/// Doc 15 replaced the seat widget with a single painter, so the seat's own
/// state is no longer a widget to interrogate: it is [CouncilSeatData], which
/// [TableScene.seatsFor] builds and the painter is handed. That is the honest
/// thing to assert against — it is the same object the pixels come from.
void main() {
  GameSnapshot snapshotOf({
    required GamePhase phase,
    int players = 6,
    int? viewerSeat = 0,
    Set<int> dead = const {},
    Map<int, bool> connected = const {},
    int? speaker,
    Map<int, int?> ballots = const {},
    List<WhisperMeta> whispers = const [],
    Confrontation? confrontation,
  }) => GameSnapshot(
    public: PublicMatchView(
      phase: phase,
      dayNumber: 1,
      players: [
        for (var seat = 0; seat < players; seat++)
          PublicPlayer(
            seat: seat,
            name: 'P$seat',
            status: dead.contains(seat) ? PlayerStatus.dead : PlayerStatus.alive,
          ),
      ],
    ),
    viewerSeat: viewerSeat,
    connectedSeats: connected,
    activeSpeakerSeat: speaker,
    liveBallots: ballots,
    whisperGraph: whispers,
    confrontation: confrontation,
  );

  Future<void> pump(
    WidgetTester tester,
    GameSnapshot snapshot, {
    int? selected,
  }) async {
    await tester.pumpWidget(
      localizedApp(
        Scaffold(body: TableScene(snapshot: snapshot, selectedSeat: selected)),
      ),
    );
    await tester.pump();
  }

  List<CouncilSeatData> chairsIn(WidgetTester tester) =>
      tester.widget<CouncilBand>(find.byType(CouncilBand)).seats;

  group('the council is one scene', () {
    testWidgets('every seat but yours is drawn, in every phase, alive or dead', (
      tester,
    ) async {
      for (final phase in GamePhase.values) {
        if (phase == GamePhase.setup || phase == GamePhase.rolesConfigured) {
          continue;
        }
        await pump(tester, snapshotOf(phase: phase, dead: const {3}));
        // Five, not six: doc 15 §1.1 takes the viewer out of the council and
        // puts them under their own hand in band 4.
        expect(
          chairsIn(tester),
          hasLength(5),
          reason: '$phase drew a different number of chairs',
        );
      }
    });

    testWidgets('the four bands are all there, at their stated proportions', (
      tester,
    ) async {
      await pump(tester, snapshotOf(phase: GamePhase.discussion));

      for (final band in [
        TableScene.header,
        TableScene.council,
        TableScene.voice,
        TableScene.hand,
      ]) {
        expect(find.byKey(band), findsOneWidget);
      }

      // Doc 15 §1.1: council 36%, voice 34%, hand 24% — of the same column, so
      // the flexes are the property and they are read from the tokens rather
      // than from a number typed into the widget.
      final total =
          CouncilTokens.councilFlex +
          CouncilTokens.voiceFlex +
          CouncilTokens.handFlex;
      expect(CouncilTokens.councilFlex / total, closeTo(0.383, 0.02));
      expect(CouncilTokens.voiceFlex / total, closeTo(0.362, 0.02));
      expect(CouncilTokens.handFlex / total, closeTo(0.255, 0.02));
    });

    testWidgets('your own seat is under your own hand, not in the council', (
      tester,
    ) async {
      await pump(
        tester,
        snapshotOf(phase: GamePhase.discussion, viewerSeat: 2),
      );
      expect(chairsIn(tester).any((chair) => chair.seat == 2), isFalse);
      expect(find.byKey(TableScene.seatKey(2)), findsNothing);
      expect(find.byKey(TableScene.viewerSeat), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(TableScene.viewerSeat),
          matching: find.textContaining('P2'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a device with no seat puts everybody in the council', (
      tester,
    ) async {
      // Offline. `viewerSeat` is null because the phone belongs to the table
      // rather than to a player, and there is no "you" to put at the bottom.
      await pump(
        tester,
        snapshotOf(phase: GamePhase.discussion, viewerSeat: null),
      );
      expect(chairsIn(tester), hasLength(6));
      expect(
        tableIsAvailableFor(
          snapshotOf(phase: GamePhase.discussion, viewerSeat: null),
        ),
        isFalse,
      );
    });
  });

  group('the night, on glass', () {
    testWidgets('no chair renders any status, however loud the snapshot is', (
      tester,
    ) async {
      // Everything that could possibly mark a seat, set at once: somebody
      // holding the floor, somebody disconnected, whispers on the table,
      // ballots in. The night must swallow all of it.
      await pump(
        tester,
        snapshotOf(
          phase: GamePhase.night,
          speaker: 1,
          connected: const {2: false, 4: false},
          ballots: const {1: 3, 2: 4},
          whispers: [WhisperMeta(id: 'w1', day: 1, fromSeat: 0, toSeat: 1)],
          dead: const {5},
        ),
      );

      for (final chair in chairsIn(tester)) {
        // P5 is dead, which is public — everybody watched it happen in the
        // morning. Everybody else is indistinguishable.
        expect(
          chair.status,
          chair.name == 'P5' ? SeatStatus.dead : SeatStatus.idle,
          reason: 'LEAK: ${chair.name} renders as ${chair.status} at night',
        );
      }
    });

    testWidgets('the same council by day does show what the night hid', (
      tester,
    ) async {
      // The other direction, so the test above cannot pass by the council
      // being permanently blank.
      await pump(
        tester,
        snapshotOf(
          phase: GamePhase.discussion,
          speaker: 1,
          connected: const {2: false},
        ),
      );

      final byName = {for (final chair in chairsIn(tester)) chair.name: chair};
      expect(byName['P1']!.status, SeatStatus.speaking);
      expect(byName['P2']!.status, SeatStatus.disconnected);
    });

    testWidgets('a night chair carries nothing a day chair does not', (
      tester,
    ) async {
      // Doc 12 §10's reserved slot, restated for a painter: every chair is the
      // same object with the same fields in every phase, so there is no shape
      // a night chair can have that a day chair cannot. Measured, because
      // "identical" is a claim about layout.
      await pump(tester, snapshotOf(phase: GamePhase.night, speaker: 1));
      final byNight = {
        for (var seat = 1; seat < 6; seat++)
          seat: tester.getRect(find.byKey(TableScene.seatKey(seat))),
      };

      await pump(tester, snapshotOf(phase: GamePhase.discussion, speaker: 1));
      final byDay = {
        for (var seat = 1; seat < 6; seat++)
          seat: tester.getRect(find.byKey(TableScene.seatKey(seat))),
      };

      expect(
        byNight,
        byDay,
        reason: 'a chair moved or resized when the phase changed, which makes '
            'the phase readable off the geometry',
      );
    });
  });

  group('selection is by subtraction, and draws no lines', () {
    testWidgets('only selectable seats accept a tap', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        localizedApp(
          Scaffold(
            body: TableScene(
              snapshot: snapshotOf(phase: GamePhase.voting),
              selectableSeats: const {1, 2},
              onSeatTap: taps.add,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(TableScene.seatKey(1)));
      await tester.tap(find.byKey(TableScene.seatKey(3)));
      await tester.pump();

      expect(taps, [1], reason: 'a seat outside the legal set accepted a tap');

      // And the inert seat is still *drawn* — hiding it would tell the room
      // which seats are not legal, and during a night that is a fact about the
      // actor's role.
      expect(find.byKey(TableScene.seatKey(3)), findsOneWidget);
    });

    testWidgets('a ballot on the table draws no connector', (tester) async {
      // Doc 15 §1.6 deleted the lines outright: *"zero connector lines"*. The
      // old table drew one per ballot and one per whisper, and on a ten-seat
      // ring that was a cat's cradle over the one thing you were trying to
      // read. The information did not go away — the tally in band 3 carries
      // it — but nothing is drawn between two chairs any more.
      await pump(
        tester,
        snapshotOf(
          phase: GamePhase.voting,
          ballots: const {1: 3, 2: null},
          whispers: [WhisperMeta(id: 'w', day: 1, fromSeat: 0, toSeat: 1)],
        ),
        selected: 4,
      );

      final band = tester.widget<CouncilBand>(find.byType(CouncilBand));
      // The one thing that still crosses the council is a whisper in flight,
      // and it is an animation with a lifetime rather than a published edge.
      expect(band.spark, isNull);
    });

    testWidgets('the chosen seat is the only one at full strength', (
      tester,
    ) async {
      // Doc 15 §1.6: selection is *subtractive*. There is no line and no
      // badge — the chosen chair lifts and everything else drops, which is a
      // property of the two opacities rather than of anything drawn.
      await pump(tester, snapshotOf(phase: GamePhase.voting), selected: 3);
      expect(
        tester.widget<CouncilBand>(find.byType(CouncilBand)).selectedSeat,
        3,
      );
      expect(CouncilTokens.selectedOthersOpacity, lessThan(1.0));
      expect(CouncilTokens.selectedScale, greaterThan(1.0));
    });
  });

  group('the clock', () {
    test('never turns red, however little is left', () {
      // Doc 12 §5 reserves red for elimination and doc 15 §1.2 restates it:
      // under ten seconds the digits gain weight and nothing else. Asserted on
      // the pure half, because a colour that is never chosen is best proved by
      // there being no branch that chooses one.
      expect(HeaderTimer.urgentBelow, 10);
      expect(HeaderTimer.format(0), '0:00');
      expect(HeaderTimer.format(9), '0:09');
      expect(HeaderTimer.format(75), '1:15');
      final source = File(
        'lib/ui/screens/online/table/table_scene.dart',
      ).readAsStringSync();
      expect(
        source.contains('errorRed') || source.contains('Colors.red'),
        isFalse,
        reason: 'the header timer reached for a red',
      );
    });

    test('a deadline already past reads zero rather than a negative', () {
      final deadline = DateTime.utc(2026, 9, 2, 12);
      expect(
        HeaderTimer.secondsLeft(deadline, deadline),
        0,
      );
      expect(
        HeaderTimer.secondsLeft(deadline, DateTime.utc(2026, 9, 2, 12, 1)),
        0,
      );
      expect(
        HeaderTimer.secondsLeft(deadline, DateTime.utc(2026, 9, 2, 11, 59, 30)),
        30,
      );
    });
  });

  group('the phase rule the council reads', () {
    test('statusFor collapses everything the night forbids', () {
      const player = PublicPlayer(seat: 1, name: 'P1', status: PlayerStatus.alive);
      final loud = snapshotOf(
        phase: GamePhase.night,
        speaker: 1,
        connected: const {1: false},
      );
      expect(
        TableScene.statusFor(
          loud,
          player,
          mood: TableMood.of(GamePhase.night),
        ),
        SeatStatus.idle,
      );
      expect(
        TableScene.statusFor(
          loud.copyWith(public: loud.public),
          player,
          mood: TableMood.of(GamePhase.discussion),
        ),
        SeatStatus.speaking,
      );
    });

    test('death survives the night, because death is public', () {
      expect(
        effectiveSeatStatus(SeatStatus.dead, showsStatus: false),
        SeatStatus.dead,
      );
      for (final status in [
        SeatStatus.speaking,
        SeatStatus.confronted,
        SeatStatus.disconnected,
      ]) {
        expect(effectiveSeatStatus(status, showsStatus: false), SeatStatus.idle);
      }
    });
  });
}
