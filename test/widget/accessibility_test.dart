import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/localized.dart';

import '../support/turn_shell_harness.dart';

/// T074 / FR-035 — accessibility, with one extra rule this app cannot skip.
///
/// ## The extra rule
///
/// Standard accessibility work makes information available to more people. Here
/// that has to be qualified: a screen reader is audible, and a phone being read
/// aloud at a table broadcasts to everyone. So semantics must describe the
/// *structure* — "player three, Fatima, selected" — and never the role. A
/// semantics label naming the role would be a perfect leak: inaudible to the
/// tests, obvious to the room.
void main() {
  /// Relative luminance per WCAG 2.1.
  double relativeLuminance(Color color) {
    double channel(double v) {
      final s = v / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel((color.r * 255).roundToDouble()) +
        0.7152 * channel((color.g * 255).roundToDouble()) +
        0.0722 * channel((color.b * 255).roundToDouble());
  }

  double contrast(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  const colors = MafiaColors.dark;

  group('FR-035 colour contrast', () {
    test('primary text on every surface clears 7:1 (AAA)', () {
      for (final surface in {
        'base': colors.surfaceBase,
        'raised': colors.surfaceRaised,
        'overlay': colors.surfaceOverlay,
      }.entries) {
        final ratio = contrast(colors.textPrimary, surface.value);
        expect(ratio, greaterThanOrEqualTo(7.0),
            reason: 'primary text on ${surface.key} is only '
                '${ratio.toStringAsFixed(2)}:1');
      }
    });

    test('secondary text clears 4.5:1 (AA) on every surface', () {
      for (final surface in {
        'base': colors.surfaceBase,
        'raised': colors.surfaceRaised,
        'overlay': colors.surfaceOverlay,
      }.entries) {
        final ratio = contrast(colors.textSecondary, surface.value);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'secondary text on ${surface.key} is only '
                '${ratio.toStringAsFixed(2)}:1');
      }
    });

    test('the primary button label clears 4.5:1 against its own fill', () {
      // Gold fill with the base surface as the label colour (design §5.1).
      final ratio = contrast(colors.surfaceBase, colors.accentGold);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'the primary action label is only '
              '${ratio.toStringAsFixed(2)}:1 against the gold fill');
    });
  });

  group('FR-035 touch targets', () {
    testWidgets('every interactive control in a turn is at least 48dp tall',
        (tester) async {
      await TurnShellHarness.pump(
        tester,
        role: Role.citizen,
        prompt: TurnShellHarness.naturalPrompt(Role.citizen),
      );
      await TurnShellHarness.completeHold(tester);

      for (final finder in [
        find.byKey(TurnShell.actionButton),
        find.byType(InkWell),
      ]) {
        for (final element in finder.evaluate()) {
          final size = tester.getSize(find.byElementPredicate((e) => e == element));
          if (size.height == 0) continue; // not laid out in this state
          expect(size.height, greaterThanOrEqualTo(48.0),
              reason: 'a control is only ${size.height}dp tall; the minimum '
                  'touch target is 48dp');
        }
      }
    });
  });

  group('FR-035 Dynamic Type', () {
    testWidgets('a night turn survives 130% text scale without overflowing',
        (tester) async {
      await tester.binding.setSurfaceSize(TurnShellHarness.surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        localizedApp(MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: TurnShell(
              labels: TurnShellLabels.of(arStrings),
              turnId: 'a11y',
              playerName: 'عبد الرحمن',
              role: Role.detective,
              promptText: TurnShellHarness.naturalPrompt(Role.detective),
              targets: TurnShellHarness.targets,
              onConfirmed: (_) {},
              onPass: () {},
            ),
          )
        ),
      );
      await tester.pumpAndSettle();

      // A RenderFlex overflow surfaces as a thrown exception in tests.
      expect(tester.takeException(), isNull,
          reason: 'the night turn overflows at 130% text scale');
    });
  });

  group('Constitution VII — semantics must not encode role', () {
    testWidgets('nothing announced during a turn names a role', (tester) async {
      // Disposed inline rather than via addTearDown: the framework verifies
      // that no handle is outstanding *before* tear-downs run.
      final handle = tester.ensureSemantics();

      for (final role in Role.values) {
        await TurnShellHarness.pump(
          tester,
          role: role,
          prompt: TurnShellHarness.naturalPrompt(role),
        );
        await TurnShellHarness.completeHold(tester);

        final announced = <String>[];
        void collect(SemanticsNode node) {
          if (node.label.isNotEmpty) announced.add(node.label);
          if (node.hint.isNotEmpty) announced.add(node.hint);
          if (node.value.isNotEmpty) announced.add(node.value);
          node.visitChildren((child) {
            collect(child);
            return true;
          });
        }

        collect(tester.getSemantics(find.byType(TurnShell)));
        final all = announced.join(' ');

        for (final roleWord in ['مافيا', 'دكتور', 'طبيب', 'محقق', 'مواطن']) {
          expect(all.contains(roleWord), isFalse,
              reason: 'a screen reader would say "$roleWord" during a '
                  '${role.name} turn');
        }
      }

      handle.dispose();
    });

    testWidgets('the semantics tree is the same shape for every role',
        (tester) async {
      final handle = tester.ensureSemantics();

      final shapes = <Role, int>{};
      for (final role in Role.values) {
        await TurnShellHarness.pump(
          tester,
          role: role,
          prompt: TurnShellHarness.naturalPrompt(role),
        );
        await TurnShellHarness.completeHold(tester);

        var count = 0;
        void countNodes(SemanticsNode node) {
          count++;
          node.visitChildren((child) {
            countNodes(child);
            return true;
          });
        }

        countNodes(tester.getSemantics(find.byType(TurnShell)));
        shapes[role] = count;
      }

      expect(shapes.values.toSet(), hasLength(1),
          reason: 'the number of semantics nodes varies with the role: $shapes');

      handle.dispose();
    });
  });
}
