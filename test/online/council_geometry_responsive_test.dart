import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/online/council/council_geometry.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

void main() {
  for (final size in [
    const Size(320, 240),
    const Size(350, 260),
    const Size(728, 320),
    const Size(1240, 250),
    const Size(1880, 350),
  ]) {
    for (final count in [4, 6, 10, 15]) {
      test('$count players fit council $size without overlapping', () {
        final seats = CouncilGeometry.layout(
          size: size,
          seatCount: count - 1,
          totalPlayers: count,
        );
        expect(seats, hasLength(count - 1));
        final viewport = Offset.zero & size;
        for (var i = 0; i < seats.length; i++) {
          expect(viewport.contains(seats[i].hitRect.topLeft), isTrue);
          expect(viewport.contains(seats[i].hitRect.bottomRight), isTrue);
          for (var j = i + 1; j < seats.length; j++) {
            expect(seats[i].hitRect.overlaps(seats[j].hitRect), isFalse);
          }
        }
      });
    }
  }
  test(
    'a phone held sideways gets one row of real chairs, not two rows of dots (E-3)',
    () {
      // The lobby band on an 844x390 phone is about 130px tall. Five chairs
      // used to be packed by width alone into two rows sixteen pixels wide.
      // Rows are told apart by the vertical spread of the chair centres: the
      // arc lifts the middle of a row by less than a chair, a second row
      // sits more than a chair lower.
      double spread(List<CouncilSeatLayout> seats) {
        final ys = seats.map((s) => s.centre.dy);
        return ys.reduce((a, b) => a > b ? a : b) -
            ys.reduce((a, b) => a < b ? a : b);
      }

      final sideways = CouncilGeometry.layout(
        size: const Size(804, 130),
        seatCount: 5,
        totalPlayers: 5,
      );
      expect(spread(sideways), lessThan(sideways.first.diameter));
      expect(
        sideways.first.diameter,
        greaterThanOrEqualTo(CouncilTokens.seatCompact),
      );
      // A band with the height for two rows still takes them, because the
      // chairs come out larger that way.
      final tall = CouncilGeometry.layout(
        size: const Size(1264, 500),
        seatCount: 10,
        totalPlayers: 10,
      );
      expect(spread(tall), greaterThan(tall.first.diameter));
      expect(tall.first.diameter, greaterThan(sideways.first.diameter));
    },
  );
  test('desktop grows chairs and uses fewer rows than a phone', () {
    final phone = CouncilGeometry.layout(
      size: const Size(350, 300),
      seatCount: 14,
      totalPlayers: 15,
    );
    final desktop = CouncilGeometry.layout(
      size: const Size(1880, 350),
      seatCount: 14,
      totalPlayers: 15,
    );
    expect(desktop.first.diameter, greaterThan(phone.first.diameter));
    expect(desktop.last.centre.dx - desktop.first.centre.dx, greaterThan(1000));
  });
}
