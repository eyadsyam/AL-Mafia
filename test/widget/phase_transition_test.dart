import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/phase_transition.dart';

import '../support/localized.dart';

/// L-14 — the phase dip never shows two phases at once.
///
/// This is the entire reason [PhaseTransition] exists instead of an
/// `AnimatedSwitcher`, and it is a property that no amount of looking at the app
/// will confirm: the overlap in a cross-fade lasts a few hundred milliseconds
/// and looks like a nice transition. What it *is*, at a handoff boundary, is a
/// ghost of one player's private turn on screen while the phone is being passed
/// across the table.
///
/// So the test steps through the dip frame by frame and asserts the outgoing
/// phase is gone before the incoming one exists — at every frame, not just at
/// the ends.
void main() {
  const motion = MafiaMotion.defaults;

  Widget harness(String phase, {bool reduceMotion = false}) => localizedApp(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: PhaseTransition(
        phaseKey: phase,
        child: Text(phase, key: ValueKey(phase)),
      ),
    ),
  );

  group('phase transition', () {
    testWidgets('the two phases are never both mounted', (tester) async {
      await tester.pumpWidget(harness('night'));
      expect(find.text('night'), findsOneWidget);

      await tester.pumpWidget(harness('morning'));

      // Walk the whole dip in small steps. `night` must disappear before
      // `morning` appears — there must be no frame containing both.
      final step = motion.quick ~/ 6;
      var sawBoth = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(step);
        final outgoing = find.text('night').evaluate().isNotEmpty;
        final incoming = find.text('morning').evaluate().isNotEmpty;
        if (outgoing && incoming) sawBoth = true;
      }

      expect(
        sawBoth,
        isFalse,
        reason:
            'both phases were mounted in the same frame. Even at partial '
            'opacity that puts the outgoing turn on screen during the '
            'handoff, which is what this widget exists to prevent — if this '
            'started failing, something replaced the dip with a cross-fade.',
      );

      await tester.pumpAndSettle();
      expect(find.text('morning'), findsOneWidget);
    });

    testWidgets('the incoming phase arrives fully opaque', (tester) async {
      // A dip that fades out and forgets to fade back leaves the app on a black
      // screen, which no other test here would notice.
      await tester.pumpWidget(harness('night'));
      await tester.pumpWidget(harness('morning'));
      await tester.pumpAndSettle();

      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(PhaseTransition),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(
        fade.opacity.value,
        1.0,
        reason:
            'the transition settled at ${fade.opacity.value} opacity, so '
            'the new phase is permanently dimmed or invisible.',
      );
    });

    testWidgets('a rebuild within one phase does not dip', (tester) async {
      await tester.pumpWidget(harness('night'));
      await tester.pumpAndSettle();

      // Same phaseKey, rebuilt. Dipping here would make a ticking timer strobe
      // the whole screen.
      await tester.pumpWidget(harness('night'));
      await tester.pump(motion.quick ~/ 2);

      final fade = tester.widget<FadeTransition>(
        find
            .descendant(
              of: find.byType(PhaseTransition),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(
        fade.opacity.value,
        1.0,
        reason:
            'a same-phase rebuild started a transition. Anything that '
            'rebuilds during a phase — the discussion timer, a target being '
            'selected — would flash the screen.',
      );
    });

    testWidgets('Reduce Motion cuts straight to the new phase', (tester) async {
      await tester.pumpWidget(harness('night', reduceMotion: true));
      await tester.pumpWidget(harness('morning', reduceMotion: true));
      await tester.pump();

      expect(
        find.text('morning'),
        findsOneWidget,
        reason:
            'with animations disabled the new phase must be on screen '
            'immediately. A dip that never runs would strand the match on a '
            'blank screen for players who use Reduce Motion.',
      );
      expect(find.text('night'), findsNothing);
    });
  });
}
