import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import '../../../theme/design_tokens.dart';

class CouncilSeatLayout {
  final Offset centre;
  final double diameter;

  const CouncilSeatLayout(this.centre, this.diameter);

  Rect get hitRect => Rect.fromCenter(
    center: centre,
    width: diameter,
    height: diameter + CouncilTokens.nameHeight,
  );

  @override
  bool operator ==(Object other) =>
      other is CouncilSeatLayout &&
      other.centre == centre &&
      other.diameter == diameter;

  @override
  int get hashCode => Object.hash(centre, diameter);
}

/// Pure portrait geometry for doc 15's shallow council arc.
abstract final class CouncilGeometry {
  static int rowsFor(int totalPlayers) {
    if (totalPlayers <= 6) return 1;
    if (totalPlayers <= 11) return 2;
    return 3;
  }

  static double diameterFor(int totalPlayers) {
    if (totalPlayers <= 6) return CouncilTokens.seatLarge;
    if (totalPlayers <= 8) return CouncilTokens.seatMedium;
    if (totalPlayers <= 11) return CouncilTokens.seatSmall;
    return CouncilTokens.seatCompact;
  }

  static double gapFor(int totalPlayers) {
    if (totalPlayers <= 6) return 16;
    if (totalPlayers <= 8) return 14;
    if (totalPlayers <= 11) return 12;
    return 10;
  }

  static List<CouncilSeatLayout> layout({
    required Size size,
    required int seatCount,
    required int totalPlayers,
    double margin = 8,
  }) {
    if (seatCount <= 0 || size.isEmpty) return const [];
    final wide = size.width >= CouncilTokens.wideCouncilBreakpoint;
    final nominal =
        diameterFor(totalPlayers) *
        (wide ? CouncilTokens.wideCouncilSeatScale : 1);
    // A wide band picks its row count from the width *and* the height. It
    // used to pack as many chairs across as the width allowed and stack the
    // rest, which on a phone held sideways (844x390, band ~130px tall) put
    // five chairs in two rows of a band that had room for one and drew them
    // sixteen pixels wide (E-3). Every row count is tried and the one that
    // gives the largest chair wins; a tie goes to the fewer rows.
    var rows = wide ? 1 : math.min(rowsFor(totalPlayers), seatCount);
    if (wide) {
      final wideGap = CouncilTokens.wideCouncilTargetGap;
      var best = 0.0;
      for (var candidate = 1; candidate <= seatCount; candidate++) {
        final columns = (seatCount / candidate).ceil();
        final widthFit =
            (size.width - margin * 2 - wideGap * (columns - 1)) / columns;
        final heightFit =
            (size.height / candidate - wideGap - CouncilTokens.nameHeight) /
            (1 + CouncilTokens.arcDepth);
        final fit = math.min(nominal, math.min(widthFit, heightFit));
        if (fit > best) {
          best = fit;
          rows = candidate;
        }
      }
    }
    final base = seatCount ~/ rows;
    final remainder = seatCount % rows;
    final counts = <int>[
      for (var row = 0; row < rows; row++) base + (row < remainder ? 1 : 0),
    ];
    final gap = wide
        ? CouncilTokens.wideCouncilTargetGap
        : gapFor(totalPlayers);
    final rowHeight = size.height / rows;
    final answer = <CouncilSeatLayout>[];

    for (var row = 0; row < rows; row++) {
      final count = counts[row];
      final perspective = row == 0 ? CouncilTokens.backRowScale : 1.0;
      final widthFit = (size.width - margin * 2 - gap * (count - 1)) / count;
      // The arc lifts the middle of a row by `arcDepth` of a chair, so a row
      // is taller than one chair and the height it is allowed to be must be
      // divided by that. Without this the top row's middle chairs were drawn
      // seven pixels above the band and clipped against the header rule — a
      // chair half outside its band is half a tap target, which is the same
      // class of bug as two chairs sharing pixels.
      final heightFit =
          (rowHeight - gap - CouncilTokens.nameHeight) /
          (1 + CouncilTokens.arcDepth);
      final diameter = math.max(
        1.0,
        math.min(nominal * perspective, math.min(widthFit, heightFit)),
      );
      final used = diameter * count + gap * (count - 1);
      final startX = (size.width - used) / 2 + diameter / 2;
      // Centre the whole arc — chair *and* its lift — in the row, then measure
      // the baseline from the top of it. `baseY` is where the outermost chairs
      // sit; everything between them rises off it.
      // A chair's footprint is its ring *and* the name under it — that is what
      // `CouncilSeatLayout.hitRect` is, and it is the rectangle a thumb lands
      // in. Centre ring, name and lift together in the row, then measure the
      // baseline from the top of that span.
      final lift = CouncilTokens.arcDepth * diameter;
      final span = diameter + CouncilTokens.nameHeight + lift;
      final baseY =
          rowHeight * row +
          (rowHeight - span) / 2 +
          lift +
          (diameter + CouncilTokens.nameHeight) / 2;

      for (var index = 0; index < count; index++) {
        final t = count == 1 ? 0.5 : index / (count - 1);
        final rise = math.sin(t * math.pi) * lift;
        answer.add(
          CouncilSeatLayout(
            Offset(startX + index * (diameter + gap), baseY - rise),
            diameter,
          ),
        );
      }
    }
    return answer;
  }
}
