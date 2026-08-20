import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/platform/reduce_motion.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/localized.dart';

import '../support/turn_shell_harness.dart';

/// T075 / FR-036 — Reduce Motion shortens animation without touching structure
/// or timing.
///
/// ## The line this draws
///
/// Reduce Motion is an accessibility setting, and honouring it normally means
/// "make things instant". Here it must not, because the turn gates *are* the
/// privacy mechanism: if a player with Reduce Motion on could confirm sooner
/// than one without, their turn would be visibly shorter and their role
/// correspondingly guessable — and worse, someone would eventually turn the
/// setting on to get an edge.
///
/// So: decoration may shorten or vanish; the dwell gate, the turn floor and the
/// layout may not move at all.
void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required Role role,
    required bool reduceMotion,
  }) async {
    await tester.binding.setSurfaceSize(TurnShellHarness.surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      localizedApp(MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TurnShell(
            labels: TurnShellLabels.of(arStrings),
            turnId: 'rm-$reduceMotion-${role.name}',
            playerName: 'Player',
            role: role,
            promptText: TurnShellHarness.naturalPrompt(role),
            targets: TurnShellHarness.targets,
            onConfirmed: (_) {},
            onPass: () {},
          ),
        )
      ),
    );
  }

  Future<void> completeHold(WidgetTester tester) async {
    final gesture =
        await tester.startGesture(tester.getCenter(find.byKey(TurnShell.holdPad)));
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pump();
  }

  bool actionEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(TurnShell.actionButton)).onPressed !=
      null;

  group('FR-036 the gates are unaffected by Reduce Motion', () {
    testWidgets('the dwell gate still takes the full 8 seconds', (tester) async {
      final dwell = MafiaTiming.defaults.dwellGate;
      const epsilon = Duration(milliseconds: 50);

      for (final reduceMotion in [false, true]) {
        await pumpShell(tester, role: Role.mafia, reduceMotion: reduceMotion);
        await completeHold(tester);
        await tester.tap(find.text('Seat 1'));
        await tester.pump();

        await tester.pump(dwell - epsilon);
        expect(actionEnabled(tester), isFalse,
            reason: 'Confirm unlocked early with disableAnimations='
                '$reduceMotion');

        await tester.pump(epsilon * 2);
        expect(actionEnabled(tester), isTrue,
            reason: 'Confirm never unlocked with disableAnimations='
                '$reduceMotion');
      }
    });

    testWidgets('the turn floor still takes the full 12 seconds',
        (tester) async {
      final floor = MafiaTiming.defaults.turnFloor;
      final dwell = MafiaTiming.defaults.dwellGate;
      const epsilon = Duration(milliseconds: 50);

      for (final reduceMotion in [false, true]) {
        await pumpShell(tester, role: Role.doctor, reduceMotion: reduceMotion);
        await completeHold(tester);
        await tester.tap(find.text('Seat 1'));
        await tester.pump(dwell + epsilon);
        await tester.tap(find.byKey(TurnShell.actionButton));
        await tester.pump();

        await tester.pump(floor - dwell - epsilon * 3);
        expect(actionEnabled(tester), isFalse,
            reason: 'Pass unlocked early with disableAnimations=$reduceMotion');

        await tester.pump(epsilon * 6);
        expect(actionEnabled(tester), isTrue,
            reason: 'Pass never unlocked with disableAnimations=$reduceMotion');
      }
    });

    testWidgets('the hold-to-reveal duration is unchanged', (tester) async {
      // Shortening this would make the identity gate easier to trip by
      // accident, which is the opposite of what it is for.
      for (final reduceMotion in [false, true]) {
        await pumpShell(tester, role: Role.citizen, reduceMotion: reduceMotion);

        final gesture = await tester
            .startGesture(tester.getCenter(find.byKey(TurnShell.holdPad)));
        await tester.pump();
        await tester.pump(MafiaTiming.defaults.holdToReveal ~/ 2);
        expect(find.byKey(TurnShell.holdPad), findsOneWidget,
            reason: 'the pad revealed at half the hold duration with '
                'disableAnimations=$reduceMotion');
        await gesture.up();
        await tester.pumpAndSettle();
      }
    });
  });

  group('FR-036 structure is unaffected by Reduce Motion', () {
    testWidgets('reserved slot geometry is identical either way',
        (tester) async {
      Map<String, Rect> slots(WidgetTester t) => {
            'header': t.getRect(find.byKey(TurnShell.slotHeader)),
            'rail': t.getRect(find.byKey(TurnShell.slotRail)),
            'body': t.getRect(find.byKey(TurnShell.slotBody)),
            'detail': t.getRect(find.byKey(TurnShell.slotDetail)),
            'action': t.getRect(find.byKey(TurnShell.slotAction)),
            'footnote': t.getRect(find.byKey(TurnShell.slotFootnote)),
          };

      await pumpShell(tester, role: Role.detective, reduceMotion: false);
      await completeHold(tester);
      final normal = slots(tester);

      await pumpShell(tester, role: Role.detective, reduceMotion: true);
      await completeHold(tester);
      final reduced = slots(tester);

      expect(reduced, equals(normal),
          reason: 'Reduce Motion moved the layout; it may only affect '
              'decoration');
    });
  });

  group('the Reduce Motion reader', () {
    testWidgets('reports the OS setting', (tester) async {
      late bool reported;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reported = ReduceMotion.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(reported, isTrue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              reported = ReduceMotion.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(reported, isFalse);
    });
  });
}
