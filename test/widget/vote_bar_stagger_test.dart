import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/vote_bar.dart';

import '../support/localized.dart';

/// The day-tally cascade: bars fill from zero, one row after another.
///
/// ## Why this is worth a test at all
///
/// Because the failure mode is silent. A stagger that collapses to zero delay
/// still shows every bar at the right width a third of a second later, and
/// nobody reviewing a screenshot would notice. The thing that breaks is the
/// shared moment the screen exists to create — the table reading the outcome
/// together instead of four people reading their own row.
///
/// So the assertions are about *ordering in time*, which is the only part a
/// static check cannot see.
///
/// ## And why the Reduce Motion case is the more important half
///
/// A cascade implemented as "start at zero width, animate to the real width"
/// has an obvious degenerate form under Reduce Motion: the animation is
/// disabled, the controller never runs, and every bar sits at zero forever. The
/// screen is then not merely less lively, it is *wrong* — it reports that
/// nobody received any votes. Accessibility settings must not be able to change
/// what the app claims happened.
void main() {
  const motion = MafiaMotion.defaults;

  /// The drawn width of row [index] as a fraction of its track.
  double fillOf(WidgetTester tester, int index) {
    final box = tester.widgetList<FractionallySizedBox>(
      find.descendant(
        of: find.byType(VoteBar).at(index),
        matching: find.byType(FractionallySizedBox),
      ),
    ).single;
    return box.widthFactor ?? 0.0;
  }

  Widget tally({bool reduceMotion = false}) => localizedApp(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Column(
            children: const [
              VoteBar(name: 'A', votes: 3, maxVotes: 3, index: 0),
              VoteBar(name: 'B', votes: 3, maxVotes: 3, index: 1),
              VoteBar(name: 'C', votes: 3, maxVotes: 3, index: 2),
            ],
          ),
        ),
      );

  group('vote tally cascade', () {
    testWidgets('rows do not all start together', (tester) async {
      await tester.pumpWidget(tally());

      // One stagger step in: the first row is under way and the last has not
      // begun. This is the whole claim — if the Interval maths is wrong, every
      // row moves in lockstep and the third fill is non-zero here.
      await tester.pump(motion.stagger);

      expect(fillOf(tester, 0), greaterThan(0.0),
          reason: 'the first row has not started a full stagger step in, so '
              'nothing is cascading — the tally just appears late.');
      expect(fillOf(tester, 2), 0.0,
          reason: 'the last row started at the same time as the first, so the '
              'stagger is not being applied per index.');

      await tester.pumpAndSettle();
    });

    testWidgets('every row ends at its true width', (tester) async {
      await tester.pumpWidget(tally());
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        expect(fillOf(tester, i), 1.0,
            reason: 'row $i settled at ${fillOf(tester, i)} rather than its '
                'real share of the vote. The animation is not landing on the '
                'value, which means the bar is lying about the count printed '
                'next to it.');
      }
    });

    testWidgets('Reduce Motion shows the full tally immediately',
        (tester) async {
      await tester.pumpWidget(tally(reduceMotion: true));

      // First frame, no pump: the numbers must already be true.
      for (var i = 0; i < 3; i++) {
        expect(fillOf(tester, i), 1.0,
            reason: 'row $i is at ${fillOf(tester, i)} on the first frame with '
                'animations disabled. A player who turns on Reduce Motion is '
                'now being shown a tally that reports the wrong result.');
      }
    });

    testWidgets('the cascade does not change the widget tree', (tester) async {
      // FR-036: Reduce Motion alters timing, never structure. A different tree
      // would mean the two paths could drift apart in layout or semantics.
      await tester.pumpWidget(tally(reduceMotion: false));
      await tester.pumpAndSettle();
      final animated = tester.allWidgets.map((w) => w.runtimeType).toList();

      await tester.pumpWidget(tally(reduceMotion: true));
      await tester.pumpAndSettle();
      final still = tester.allWidgets.map((w) => w.runtimeType).toList();

      expect(still, equals(animated));
    });
  });
}
