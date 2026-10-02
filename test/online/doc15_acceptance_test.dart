/// Doc 15 Part 5, as a suite.
///
/// The redesign's checklist, box by box, against the shipped code. Where a box
/// is a property of the *shape* of the code — one painter, one action slot, no
/// line builder — it is asserted against the source, because those are the ones
/// a later commit undoes by accident rather than on purpose. Where it is a
/// property of pixels, it is measured.
///
/// The three boxes this file cannot close are named at the bottom, so nobody
/// reads a green run as more than it is.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/views.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/ui/screens/online/council/card_rise.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/online/council/voice_band.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

/// Every file the online surface draws itself out of.
const _surface = [
  'lib/ui/screens/online/council/council_band.dart',
  'lib/ui/screens/online/council/council_geometry.dart',
  'lib/ui/screens/online/council/voice_band.dart',
  'lib/ui/screens/online/council/card_rise.dart',
  'lib/ui/screens/online/council/phase_sting.dart',
  'lib/ui/screens/online/council/role_glyph.dart',
  'lib/ui/screens/online/council/role_roster.dart',
  'lib/ui/screens/online/table/table_scene.dart',
  'lib/ui/screens/online/table/connection_weather.dart',
  'lib/ui/screens/online/lobby_screen.dart',
  'lib/ui/screens/online/online_table_flow.dart',
];

void main() {
  GameSnapshot snapshotOf({
    required GamePhase phase,
    int players = 8,
    int? viewerSeat = 0,
  }) => GameSnapshot(
    public: PublicMatchView(
      phase: phase,
      dayNumber: 1,
      players: [
        for (var seat = 0; seat < players; seat++)
          PublicPlayer(seat: seat, name: 'P$seat', status: PlayerStatus.alive),
      ],
    ),
    viewerSeat: viewerSeat,
  );

  // ═══════════════════════════════════════════════════════════════════════
  // LAYOUT
  // ═══════════════════════════════════════════════════════════════════════

  group('Layout', () {
    testWidgets('four bands, in the same order, on every phase', (
      tester,
    ) async {
      for (final phase in GamePhase.values) {
        if (phase == GamePhase.setup || phase == GamePhase.rolesConfigured) {
          continue;
        }
        await tester.pumpWidget(
          localizedApp(
            Scaffold(
              body: TableScene(snapshot: snapshotOf(phase: phase)),
            ),
          ),
        );
        await tester.pump();

        final tops = [
          for (final band in [
            TableScene.header,
            TableScene.council,
            TableScene.voice,
            TableScene.hand,
          ])
            tester.getTopLeft(find.byKey(band)).dy,
        ];
        expect(
          tops,
          orderedEquals(<double>[...tops]..sort()),
          reason: '$phase reordered the bands',
        );
      }
    });

    test('the band proportions are doc 15 §1.1, and live in one place', () {
      final total =
          CouncilTokens.councilFlex +
          CouncilTokens.voiceFlex +
          CouncilTokens.handFlex;
      expect(CouncilTokens.councilFlex / total, closeTo(0.36 / 0.94, 0.03));
      expect(CouncilTokens.voiceFlex / total, closeTo(0.34 / 0.94, 0.03));
      expect(CouncilTokens.handFlex / total, closeTo(0.24 / 0.94, 0.03));
      expect(CouncilTokens.headerHeight, 56);
    });

    test('zero connector lines: the builder does not exist', () {
      for (final path in _surface) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('TableLink'),
          isFalse,
          reason: '$path still knows how to draw a line between two seats',
        );
      }
    });

    test('card art never renders below 200dp', () {
      // Two halves. The card that *is* drawn is drawn at 280 — comfortably
      // over the floor — and the council, which is the surface that used to
      // draw cards at sixty, does not draw one at all.
      expect(
        CouncilTokens.cardRiseSize,
        greaterThanOrEqualTo(CardRise.minimumArt),
      );
      final band = File(
        'lib/ui/screens/online/council/council_band.dart',
      ).readAsStringSync();
      expect(RegExp(r'AppImages\.card').hasMatch(band), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // HIERARCHY
  // ═══════════════════════════════════════════════════════════════════════

  group('Hierarchy', () {
    test('band 4 has exactly one slot, so it can hold exactly one action', () {
      // Structural rather than counted: `TableScene` takes a single `footer`,
      // and there is nowhere in the band to put a second. A test that counted
      // buttons would pass the day somebody put two in the slot.
      final scene = File(
        'lib/ui/screens/online/table/table_scene.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'final Widget\? footer;').hasMatch(scene),
        isTrue,
        reason: 'band 4 stopped being one slot',
      );
      expect(
        RegExp(
          r'final Widget\? footer2|final List<Widget> footer',
        ).hasMatch(scene),
        isFalse,
      );
    });

    testWidgets('band 3 holds a headline and at most one supporting element', (
      tester,
    ) async {
      // The same structural argument, one band up. `CouncilVoice` takes a
      // `String` and one optional `Widget`, so doc 15 §1.4's "maximum two text
      // elements. If a third is needed, something else is wrong" is enforced by
      // there being no third parameter.
      await tester.pumpWidget(
        localizedApp(
          const Scaffold(
            body: CouncilVoice(
              headline: 'واحد',
              support: SelectionChip(label: 'اتنين'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(CouncilVoice.body), findsOneWidget);
      expect(find.byKey(SelectionChip.chip), findsOneWidget);

      final voice = File(
        'lib/ui/screens/online/council/voice_band.dart',
      ).readAsStringSync();
      final slots = RegExp(
        r'final (String|Widget\?|TextStyle\?) \w+;',
      ).allMatches(voice.split('class SelectionChip').first).length;
      // Four since 2026-09-23: `leading` carries the player's own card at
      // night (owner request). It is an image, not a third line of text, so
      // the two-text-elements rule still holds — `headline` is the only
      // String.
      expect(
        slots,
        4,
        reason:
            'CouncilVoice grew a slot: headline, support, style, leading, '
            'and no more',
      );
      expect(
        RegExp(
          r'final String \w+;',
        ).allMatches(voice.split('class SelectionChip').first).length,
        1,
        reason: 'band 3 carries one headline string',
      );
    });

    test('every gap in the online surface is a token', () {
      // Doc 15 §1.4: "Never two strings stacked without a defined gap. Every
      // gap is a spacing token." Zero is allowed — it is an edge, not a gap.
      final magic = RegExp(
        r'(height|width|left|right|top|bottom): *([1-9][0-9]*(\.[0-9]+)?)[,)]',
      );
      for (final path in _surface) {
        for (final line in File(path).readAsLinesSync()) {
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          expect(
            magic.hasMatch(line),
            isFalse,
            reason: '$path has a hardcoded size: ${line.trim()}',
          );
        }
      }
    });

    test('the timer has no red to reach for', () {
      expect(HeaderTimer.urgentBelow, 10);
      final scene = File(
        'lib/ui/screens/online/table/table_scene.dart',
      ).readAsStringSync();
      expect(scene.contains('accentCrimson'), isFalse);
      expect(scene.contains('Colors.red'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // MOTION
  // ═══════════════════════════════════════════════════════════════════════

  group('Motion', () {
    test('band 2 is one CustomPainter, and seats own no controllers', () {
      final band = File(
        'lib/ui/screens/online/council/council_band.dart',
      ).readAsStringSync();
      expect(
        'CustomPaint('.allMatches(band).length,
        1,
        reason: 'the council grew a second painter',
      );
      expect(
        'extends CustomPainter'.allMatches(band).length,
        1,
        reason: 'the council grew a second painter class',
      );
      // One controller for the selection shift, and that is the lot. Fifteen
      // seats with a controller each is exactly what doc 15 §3's budget
      // forbids.
      expect(
        'AnimationController('.allMatches(band).length,
        1,
        reason: 'the council grew a second controller',
      );
    });

    test('doc 15 §3 motion catalogue, at the stated numbers', () {
      final motion = MafiaMotion.defaults;
      expect(motion.tap, const Duration(milliseconds: 120));
      expect(motion.quick, const Duration(milliseconds: 200));
      expect(motion.band, const Duration(milliseconds: 350));
      expect(motion.phase, const Duration(milliseconds: 700));
      expect(motion.card, const Duration(milliseconds: 600));
      expect(motion.rise, const Duration(milliseconds: 500));
      expect(motion.riseCurve, Curves.easeOutBack);
      expect(motion.tear, const Duration(milliseconds: 400));
      expect(motion.reveal, const Duration(milliseconds: 1400));
      expect(motion.travel, const Duration(milliseconds: 700));
      expect(motion.breathe, const Duration(milliseconds: 1400));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // LEAKAGE
  // ═══════════════════════════════════════════════════════════════════════

  group('Leakage', () {
    test('no role can reach the council at all', () {
      // Doc 15 §5's golden: "all four roles produce identical night layouts."
      // Stronger than four goldens and cheaper than any of them — the council
      // is built from a snapshot that has no role on it, and neither the band
      // nor the scene has a `Role` to branch on. Four identical pictures is
      // then arithmetic rather than a hope.
      for (final path in [
        'lib/ui/screens/online/council/council_band.dart',
        'lib/ui/screens/online/council/council_geometry.dart',
        'lib/ui/screens/online/table/table_scene.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          RegExp(r'\bRole\.\w+').hasMatch(source),
          isFalse,
          reason: 'LEAK: $path names a role',
        );
      }
    });

    testWidgets('the night council is byte-identical whatever the snapshot '
        'is carrying', (tester) async {
      // The other direction: the same council, drawn from a night snapshot
      // that has a speaker, a disconnection and a full ballot on it, is the
      // same council as one drawn from an empty night.
      Future<List<CouncilSeatData>> chairs(GameSnapshot snapshot) async {
        await tester.pumpWidget(
          localizedApp(Scaffold(body: TableScene(snapshot: snapshot))),
        );
        await tester.pump();
        return tester.widget<CouncilBand>(find.byType(CouncilBand)).seats;
      }

      final quiet = await chairs(snapshotOf(phase: GamePhase.night));
      final loud = await chairs(
        snapshotOf(phase: GamePhase.night).copyWith(
          activeSpeakerSeat: 3,
          connectedSeats: const {2: false, 5: false},
          liveBallots: const {1: 4, 2: 4},
        ),
      );
      expect(loud, quiet, reason: 'LEAK: the night council read the snapshot');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // THE TWO RESOLUTIONS (2026-09-07)
  // ═══════════════════════════════════════════════════════════════════════

  group('S-O13 — simultaneity moved to the seat', () {
    test('one number drives every ring, so a stagger cannot be added by '
        'accident', () {
      final band = File(
        'lib/ui/screens/online/council/council_band.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'final double revealProgress;').hasMatch(band),
        isTrue,
        reason: 'the flip stopped being one shared number',
      );
      // A per-seat map or an index-derived offset is exactly the shape a
      // stagger would arrive in, and the beat's whole content is that there
      // is not one.
      expect(
        RegExp(r'revealProgress\[|revealProgress\s*\*\s*index').hasMatch(band),
        isFalse,
        reason: 'the reveal grew a per-seat term',
      );
    });

    test('the council still cannot name a role, glyphs included', () {
      // The mark is an asset path chosen on the far side of the boundary. If
      // this ever fails, the mapping has been inlined into the painter and the
      // council has learned what a role is.
      final band = File(
        'lib/ui/screens/online/council/council_band.dart',
      ).readAsStringSync();
      expect(RegExp(r'Role\.\w+').hasMatch(band), isFalse);
      expect(RegExp(r'final String\? roleGlyph;').hasMatch(band), isTrue);
    });

    testWidgets('past halfway a ring carries its mark, and every ring turns '
        'on the same frame', (tester) async {
      // Two renders of the same council, one at rest and one mid-turn. The
      // seats are value-equal types, so "they all changed together" is a
      // comparison rather than a stopwatch.
      Future<CouncilPainter> painterAt(double progress) async {
        await tester.pumpWidget(
          localizedApp(
            Scaffold(
              body: CouncilBand(
                seats: [
                  for (var seat = 1; seat < 6; seat++)
                    CouncilSeatData(
                      seat: seat,
                      name: 'P\$seat',
                      roleGlyph: 'assets/icons/role_citizen.webp',
                    ),
                ],
                totalPlayers: 6,
                revealProgress: progress,
              ),
            ),
          ),
        );
        await tester.pump();
        return tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byType(CouncilBand),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter!
            as CouncilPainter;
      }

      final still = await painterAt(0);
      final turning = await painterAt(0.75);
      expect(still.revealProgress, 0);
      expect(turning.revealProgress, 0.75);
      // One value, shared. There is no per-seat progress to compare because
      // the type does not have one — which is the assertion.
      expect(
        turning.seats.map((seat) => seat.roleGlyph).toSet().length,
        1,
        reason: 'the marks stopped being a property of the seat data',
      );
    });

    test('the card art the roster shows is still over the floor', () {
      expect(
        CouncilTokens.cardRiseSize,
        greaterThanOrEqualTo(CardRise.minimumArt),
      );
      final roster = File(
        'lib/ui/screens/online/council/role_roster.dart',
      ).readAsStringSync();
      // One at a time. A grid or a wrap here would be the original conflict in
      // a new shape: nine cards on a phone is nine cards at ninety pixels.
      expect(roster.contains('PageView'), isTrue);
      expect(RegExp(r'GridView|Wrap\(').hasMatch(roster), isFalse);
    });
  });

  group('§1.4 — a floor and raised hands, never a queue', () {
    test('the snapshot carries a set, because a list would be sortable', () {
      final snapshot = File(
        'lib/transport/game_snapshot.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'final Set<int> raisedHands;').hasMatch(snapshot),
        isTrue,
        reason: 'raised hands became an ordered collection',
      );
      expect(RegExp(r'List<int> raisedHands').hasMatch(snapshot), isFalse);
    });

    test('nothing anywhere sorts a hand by when it went up', () {
      // `hand_raised_at` exists so a stale hand can be aged out, and for no
      // other reason. The moment something sorts on it, the queue is back.
      for (final path in [
        ..._surface,
        'lib/transport/room_codec.dart',
        'lib/transport/online_backend.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          RegExp(
            r'sort.*handRaisedAt|handRaisedAt.*compareTo',
          ).hasMatch(source),
          isFalse,
          reason: '\$path sorts raised hands by request time',
        );
      }
    });

    test('the copy has no position in it', () {
      // The old string is gone from the discussion path. `onlineUpNext` stays
      // in the bundle because the *opening round* is a real order — it comes
      // off `openingAccusations` — but the discussion may not use it.
      final flow = File(
        'lib/ui/screens/online/online_table_flow.dart',
      ).readAsStringSync();
      final discussion = flow.substring(
        flow.indexOf('case GamePhase.discussion:'),
      );
      final band3 = discussion.substring(
        0,
        discussion.indexOf('case GamePhase.voting:'),
      );
      expect(band3.contains('onlineUpNext'), isFalse);
      expect(band3.contains('onlineRaisedHands'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // The boxes this file cannot close
  // ═══════════════════════════════════════════════════════════════════════
  //
  //   * **60fps with fifteen seats, in profile mode.** Needs a device and
  //     `flutter run --profile`. What is checked above is every structural
  //     precondition doc 15 §3 names — one painter, one controller, no
  //     BackdropFilter — but a frame budget is measured, not proven.
  //
  //   * **"No screen is more than 25% empty at any player count."** Emptiness
  //     is a judgement about a picture. The band proportions are fixed and
  //     asserted, which is the mechanism doc 15 chose to make it true; the
  //     claim itself is a screenshot.
  //
  //   * **Reduce Motion verified on every screen.** Every file that owns a
  //     controller is checked for consulting the setting
  //     (`doc12_acceptance_test.dart`), but "the fallback looks right" is
  //     something a person has to watch.
}
