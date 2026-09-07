/// Doc 15 §5, the one box a widget test cannot close: **60fps with fifteen
/// seats**.
///
/// Everything structural that budget rests on is asserted in
/// `doc15_acceptance_test.dart` — one `CustomPainter`, one `AnimationController`
/// in the band, no `BackdropFilter` anywhere on the online surface. None of
/// that is a frame time. This is: a real build, on a real device, driving the
/// council through every animation doc 15 §3 names, with
/// `watchPerformance` recording what the raster thread actually did.
///
///     flutter test integration_test/council_frames_test.dart --profile \
///       -d <device>
///
/// The summary lands in `build/integration_response_data/`. Read the numbers,
/// not the green tick: this file asserts only that the run happened, because a
/// threshold hard-coded here would be a claim about somebody else's hardware.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mafia_master/app/l10n/app_localizations.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart' hide VoteTally;
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/screens/online/council/voice_band.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';

/// Fifteen, which is the worst case doc 15 §1.2 designs for.
const _players = 15;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  GameSnapshot snapshotOf(GamePhase phase, {int? speaker}) => GameSnapshot(
    public: PublicMatchView(
      phase: phase,
      dayNumber: 2,
      players: [
        for (var seat = 0; seat < _players; seat++)
          PublicPlayer(
            seat: seat,
            name: 'لاعب $seat',
            status: PlayerStatus.alive,
          ),
      ],
    ),
    viewerSeat: 0,
    activeSpeakerSeat: speaker,
  );

  testWidgets('the council holds its frame budget at fifteen seats', (
    tester,
  ) async {
    await binding.watchPerformance(() async {
      var selected = 3;
      var reveal = 0.0;
      late StateSetter refresh;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: MafiaTheme.dark,
          home: StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return TableScene(
                snapshot: snapshotOf(GamePhase.night, speaker: 2),
                selectedSeat: selected,
                selectableSeats: const {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
                revealProgress: reveal,
                centre: const CouncilVoice(headline: 'مين تقتل الليلة؟'),
              );
            },
          ),
        ),
      );

      // The heartbeat, on its own, for a full breath. Fifteen seats redrawn
      // from one painter is the frame this whole design exists to make cheap.
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Selection by subtraction, moved thirty times. Every seat changes
      // opacity on every one of these, which is the repaint doc 15 §1.6 asks
      // for and the reason the band is a painter rather than fifteen widgets.
      for (var tap = 0; tap < 30; tap++) {
        refresh(() => selected = 1 + (tap % 10));
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      // §S-O13 beat 2: every ring turning at once. The most expensive frame
      // the council ever draws — fifteen scaled rings, fifteen glyph blits.
      for (var step = 0; step <= 40; step++) {
        refresh(() => reveal = step / 40);
        await tester.pump(const Duration(milliseconds: 16));
      }
    }, reportKey: 'council_15_seats');
  });
}
