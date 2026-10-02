/// Renders the council at phone size and writes PNGs, for looking at.
///
/// **Not a test.** The filename has no `_test` suffix on purpose, so
/// `flutter test` never picks it up — it asserts nothing and would be a
/// green tick that means nothing if it did. It exists because doc 15 is a
/// document about a *picture*, and three of its acceptance boxes ("no screen is
/// more than 25% empty", "Reduce Motion verified", "all seats visible at 5, 8,
/// 11 and 15") are judgements a person makes by looking.
///
/// The online table cannot be reached on a device without a Supabase project
/// behind it — the room, the seats and the viewer's own seat all come from the
/// server — so this renders the same widgets the app builds, at the same size,
/// out of the same asset bundle.
///
///     flutter test test/online/council_screenshots.dart
///
/// Writes to `build/council-shots/`.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';
// The engine's `Alignment` is a win side; Flutter's is a layout anchor, and
// this file lays widgets out. The engine one keeps its name behind a prefix.
import 'package:mafia_master/engine/models/enums.dart' hide Alignment;
import 'package:mafia_master/engine/models/enums.dart' as engine show Alignment;
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart' hide VoteTally;
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/screens/online/council/role_roster.dart';
import 'package:mafia_master/ui/theme/mafia_theme.dart';
import 'package:mafia_master/ui/screens/online/council/voice_band.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';

import '../support/localized.dart';

/// A Pixel-class phone in logical pixels.
const _phone = Size(412, 915);

void main() {
  final out = Directory('build/council-shots')..createSync(recursive: true);

  GameSnapshot snapshotOf({
    required GamePhase phase,
    int players = 8,
    int? viewerSeat = 0,
    Set<int> dead = const {},
    int? speaker,
    Set<int> hands = const {},
    engine.Alignment? winner,
  }) => GameSnapshot(
    public: PublicMatchView(
      phase: phase,
      dayNumber: 2,
      players: [
        for (var seat = 0; seat < players; seat++)
          PublicPlayer(
            seat: seat,
            name: const [
              'أمينة',
              'كريم',
              'سارة',
              'يوسف',
              'ليلى',
              'حسن',
              'نور',
              'طارق',
              'دينا',
              'رامي',
              'هدى',
              'سامي',
              'ملك',
              'زياد',
              'جنى',
            ][seat],
            status: dead.contains(seat)
                ? PlayerStatus.dead
                : PlayerStatus.alive,
          ),
      ],
      outcome: winner == null
          ? null
          : MatchOutcome(winner: winner, completedAt: DateTime.utc(2026)),
    ),
    viewerSeat: viewerSeat,
    activeSpeakerSeat: speaker,
    raisedHands: hands,
    // Doc 15 §S-O13 beats 2 and 3 both read this: the marks the rings carry
    // and the sides they warm or dim to come from the same published
    // standings, and neither exists before the match is over.
    standings: winner == null
        ? const []
        : [
            for (var seat = 0; seat < players; seat++)
              FinalStanding(
                seat: seat,
                name: 'P\$seat',
                role: seat.isEven ? Role.citizen : Role.mafia,
              ),
          ],
  );

  Future<void> shoot(WidgetTester tester, String name, Widget child) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: _phone),
        child: localizedApp(
          RepaintBoundary(
            child: SizedBox.fromSize(size: _phone, child: child),
          ),
        ),
      ),
    );
    // The council loads its ring art off the bundle, so the first frames are
    // drawn without it. Real I/O needs real async.
    await tester.runAsync(() async {
      for (final asset in AppCouncilArt.values) {
        if (!asset.endsWith('.png')) continue;
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(SizedBox).first),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = boundary.toImageSync(pixelRatio: 2);
    // `toByteData` is real async. Awaited under the fake clock it never
    // completes, which is what hung the first version of this file at exactly
    // one picture per run.
    ByteData? bytes;
    await tester.runAsync(() async {
      bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    });
    File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
    // ignore: avoid_print
    print('wrote ${out.path}/$name.png');
  }

  void shot(String name, Widget Function() build) {
    // One `testWidgets` per picture. Two `shoot` calls in one test hang: the
    // first leaves `TablePulse`'s repeating controller running, and pumping a
    // second tree over it inside `runAsync` never settles. A fresh binding per
    // shot costs a second and cannot deadlock.
    testWidgets(name, (tester) async {
      tester.view.physicalSize = _phone * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await shoot(tester, name, build());
    });
  }

  for (final count in const [5, 8, 11, 15]) {
    shot(
      'council-$count',
      () => TableScene(
        snapshot: snapshotOf(
          phase: GamePhase.discussion,
          players: count,
          speaker: 2,
        ),
        centre: const CouncilVoice(headline: '« سارة »'),
        footer: FilledButton(onPressed: () {}, child: const Text('همسة')),
      ),
    );
  }

  // Two night screens, because there are two. The actor holds to confirm; the
  // rest of the room has no move and doc 05 will not let the app hint that
  // anybody does. Band 4 being quiet for a spectator is the guarantee, not a
  // gap in the design, so both are measured rather than only the fuller one.
  shot(
    'phase-night-actor',
    () => TableScene(
      snapshot: snapshotOf(phase: GamePhase.night),
      selectedSeat: 3,
      selectableSeats: const {1, 2, 3, 4, 5, 6, 7},
      centre: const CouncilVoice(
        headline: 'مين تقتل الليلة؟',
        support: SelectionChip(label: 'اخترت: يوسف'),
      ),
      footer: HoldPad(
        instruction: 'استمر بالضغط للتأكيد',
        holdDuration: const Duration(milliseconds: 1200),
        onHoldComplete: () {},
        diameter: 96,
      ),
    ),
  );

  shot(
    'phase-night-spectator',
    () => TableScene(
      snapshot: snapshotOf(phase: GamePhase.night),
      centre: const CouncilVoice(headline: 'المدينة نايمة'),
    ),
  );

  // The discussion, with the resolution of §1.4 on screen: who holds the floor
  // and who has asked for it. No numbers, and the names are in seat order.
  shot(
    'phase-discussion-hands',
    () => TableScene(
      snapshot: snapshotOf(
        phase: GamePhase.discussion,
        speaker: 2,
        hands: const {5, 1, 6},
      ),
      centre: CouncilVoice(
        headline: '« سارة »',
        // Styled the way the flow styles it. A bare `Text` this far from a
        // `Scaffold` picks up Flutter's un-parented debug style and comes out
        // red, which is a fact about the harness and not about the screen.
        support: Builder(
          builder: (context) => Text(
            'رافعين إيدهم: كريم · حسن · نور',
            textAlign: TextAlign.center,
            style: context.typography.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ),
      footer: FilledButton(onPressed: () {}, child: const Text('همسة')),
    ),
  );

  shot(
    'phase-vote',
    () => TableScene(
      snapshot: snapshotOf(phase: GamePhase.voting, dead: const {5}),
      selectableSeats: const {1, 2, 3, 4, 6, 7},
      centre: const CouncilVoice(
        headline: 'مين يخرج؟',
        support: VoteTally(
          rows: [
            (name: 'سارة', votes: 3),
            (name: 'كريم', votes: 2),
            (name: 'نور', votes: 1),
          ],
          peak: 3,
        ),
      ),
      footer: FilledButton(onPressed: () {}, child: const Text('أكّد صوتك')),
    ),
  );

  // Doc 15 §S-O13 as it was resolved: the rings have turned (`revealProgress`
  // at 1) and are carrying role marks, winners are warm and losers are at 30%,
  // and band 4 offers the roster rather than trying to draw fifteen cards.
  shot(
    'phase-result',
    () => TableScene(
      snapshot: snapshotOf(
        phase: GamePhase.result,
        dead: const {2, 5},
        winner: engine.Alignment.town,
      ),
      revealProgress: 1,
      centre: const CouncilVoice(
        headline: 'فاز المواطنون',
        support: VictoryEmblem(mafiaWon: false),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(onPressed: () {}, child: const Text('شوف الأدوار')),
          TextButton(onPressed: () {}, child: const Text('الرئيسية')),
        ],
      ),
    ),
  );

  // Mid-turn. Every ring edge-on on the same frame is the beat, so it is worth
  // a picture of its own — a still of this that showed some rings turned and
  // others not would be the stagger the resolution exists to forbid.
  shot(
    'phase-result-turning',
    () => TableScene(
      snapshot: snapshotOf(
        phase: GamePhase.result,
        winner: engine.Alignment.town,
      ),
      revealProgress: 0.42,
      centre: const CouncilVoice(headline: 'فاز المواطنون'),
    ),
  );

  // The roster: one card, at 280dp, which is the half of the beat that could
  // not live in the council.
  shot(
    'phase-roster',
    () => Stack(
      fit: StackFit.expand,
      children: [
        TableScene(
          snapshot: snapshotOf(
            phase: GamePhase.result,
            winner: engine.Alignment.town,
          ),
          revealProgress: 1,
          centre: const CouncilVoice(headline: 'فاز المواطنون'),
        ),
        RoleRoster(
          standings: const [
            FinalStanding(seat: 3, name: 'يوسف', role: Role.mafia),
          ],
          onClose: () {},
        ),
      ],
    ),
  );
}
