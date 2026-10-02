/// Chairs do not overlap. In any band, at any roster size.
///
/// # The bug this file was opened for
///
/// The old table sized cards from the roster alone and then trusted whatever
/// box it was handed. The lobby handed it `Expanded` — whatever was left after
/// the room code, the buttons, the count, the voice line and the start button
/// had taken theirs. On a 360×640 phone that leftover was about 170 logical
/// pixels, and ten cards 58×84 were asked to stand on an ellipse 108 pixels
/// tall. They did, and they overlapped three deep down each side.
///
/// # Why doc 15 did not simply fix the arithmetic
///
/// Because the ellipse was the bug. Doc 15 Part 0: on a 9:19.5 viewport a table
/// seen from above puts seats at four corners and leaves the middle empty, and
/// there is no scale factor that makes that shape correct. The council is a
/// shallow arc across a band with a *fixed* proportion — 36% of the screen,
/// every phase, every screen — so the box is never a leftover and the geometry
/// never has to guess what it will be given.
///
/// # Why it is a correctness test and not a cosmetic one
///
/// A chair is a tap target: you touch one to accuse, to protect, to kill. Two
/// chairs sharing pixels are two hit targets sharing pixels, and the one drawn
/// last takes the tap. In a game where a mis-tap eliminates the wrong player, a
/// council that overlaps is a council that lies about what you pressed.
///
/// # What is asserted
///
/// Rectangles, in pixels, for every pair of chairs — the hit rectangles, not
/// the rings, because the hit rectangle is the thing a thumb actually lands in.
/// Over a grid of bands that includes the phone that showed the bug, and at the
/// roster sizes doc 15 §5 names.
library;

import 'dart:ui' show Rect, Size;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/online/council/council_band.dart';
import 'package:mafia_master/ui/screens/online/council/council_geometry.dart';
import 'package:mafia_master/ui/screens/online/table/table_pulse.dart';

import '../support/localized.dart';

/// Every band a council might plausibly be given.
///
/// Band 2 is 36% of what is left under the 56dp header, so these are real
/// heights rather than round numbers: 360×640 is the phone that showed the
/// original bug, and 480×900 is a desktop browser at full height.
const _bands = <Size>[
  Size(360, 200), // 360×640 phone
  Size(320, 175), // the smallest phone still sold, portrait
  Size(411, 235), // Pixel-class, the emulator this project verifies on
  Size(480, 300), // the app's own maxContentWidth
  Size(480, 320), // a desktop browser, full height
];

/// Doc 15 §5's roster sizes, as chair counts.
///
/// One fewer than the roster: you are not in the council. Doc 15 §1.1 puts the
/// viewer under their own hand in band 4, because the whole layout is the room
/// seen from your seat rather than from above.
const _rosters = <int>[5, 8, 11, 15];

void main() {
  group('no two chairs share a pixel', () {
    for (final band in _bands) {
      for (final roster in _rosters) {
        test(
          '${band.width.toInt()}x${band.height.toInt()}, $roster players',
          () {
            final layout = CouncilGeometry.layout(
              size: band,
              seatCount: roster - 1,
              totalPlayers: roster,
            );
            expect(layout, hasLength(roster - 1));

            for (var i = 0; i < layout.length; i++) {
              for (var j = i + 1; j < layout.length; j++) {
                expect(
                  // Deflated by a hair: two chairs may share an edge, and a
                  // shared edge is `overlaps` returning false already — this
                  // guards against the floating-point case where it does not.
                  layout[i].hitRect
                      .deflate(0.5)
                      .overlaps(layout[j].hitRect.deflate(0.5)),
                  isFalse,
                  reason:
                      'chairs $i and $j overlap: '
                      '${layout[i].hitRect} vs ${layout[j].hitRect}',
                );
              }
            }
          },
        );
      }
    }
  });

  test('the council stays inside the band it was given', () {
    for (final band in _bands) {
      for (final roster in _rosters) {
        final layout = CouncilGeometry.layout(
          size: band,
          seatCount: roster - 1,
          totalPlayers: roster,
        );
        for (final seat in layout) {
          final rect = seat.hitRect;
          expect(
            rect.left,
            greaterThanOrEqualTo(-0.01),
            reason: '$band $roster',
          );
          expect(
            rect.right,
            lessThanOrEqualTo(band.width + 0.01),
            reason: '$band $roster',
          );
          expect(
            rect.top,
            greaterThanOrEqualTo(-0.01),
            reason: '$band $roster',
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(band.height + 0.01),
            reason: '$band $roster',
          );
        }
      }
    }
  });

  test('a chair is never drawn smaller than a thumb can hit', () {
    // Doc 15 §1.3 shrinks the ring as the roster grows and stops. Fifteen
    // players on the smallest phone still sold is the worst case this app can
    // be in, and the chair there is still a target rather than a dot. Measured
    // on `hitRect`, because the tap goes to the rectangle rather than to the
    // ring drawn inside it.
    for (final band in _bands) {
      final layout = CouncilGeometry.layout(
        size: band,
        seatCount: 14,
        totalPlayers: 15,
      );
      for (final seat in layout) {
        expect(seat.hitRect.width, greaterThanOrEqualTo(24.0), reason: '$band');
        expect(
          seat.hitRect.height,
          greaterThanOrEqualTo(40.0),
          reason: '$band',
        );
      }
    }
  });

  testWidgets('the shipped band lays fourteen chairs out without overlapping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedApp(
        Center(
          child: SizedBox(
            width: 360,
            height: 200,
            child: TablePulse(
              child: CouncilBand(
                totalPlayers: 15,
                seats: [
                  for (var i = 1; i < 15; i++)
                    CouncilSeatData(seat: i, name: 'لاعب رقم $i'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final rects = <Rect>[];
    for (var i = 1; i < 15; i++) {
      final finder = find.byKey(CouncilBand.seatKey(i));
      expect(finder, findsOneWidget, reason: 'chair $i is missing');
      rects.add(tester.getTopLeft(finder) & tester.getSize(finder));
    }

    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].deflate(0.5).overlaps(rects[j].deflate(0.5)),
          isFalse,
          reason: 'chairs $i and $j overlap: ${rects[i]} vs ${rects[j]}',
        );
      }
    }
  });
}
