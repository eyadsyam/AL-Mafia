import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/turn_shell_harness.dart';

/// US2 / T037 — golden symmetry for [TurnShell].
///
/// This suite compares *rendered pixels*, not committed golden files. Committed
/// goldens verify a widget against its own past; what Constitution I actually
/// requires is that four roles are indistinguishable from each other **right
/// now**, on whatever host is running CI. Capturing four frames in one process
/// and diffing them gives exactly that, with no font- or platform-dependent
/// baseline to drift.
///
/// Covers L-01 (identical night-turn tree per role) and L-02 (reserved slot
/// dimensions are role-invariant).
void main() {
  const neutralPrompt = 'اختر لاعبًا';
  const neutralDetail = 'تفصيل';

  const allStates = <TurnShellState>[
    TurnShellState.handoff,
    TurnShellState.revealed,
    TurnShellState.selecting,
    TurnShellState.confirmed,
    TurnShellState.passUnlocked,
  ];

  /// Drives one complete turn on a fixed pump schedule, capturing a frame at
  /// each of the five states.
  Future<Map<TurnShellState, Uint8List>> captureAllStates(
    WidgetTester tester,
    Role role, {
    String prompt = neutralPrompt,
    String? detail = neutralDetail,
  }) async {
    final frames = <TurnShellState, Uint8List>{};

    await TurnShellHarness.pump(
      tester,
      role: role,
      prompt: prompt,
      confirmationDetail: detail,
    );

    frames[TurnShellState.handoff] = await TurnShellHarness.capture(tester);

    await TurnShellHarness.completeHold(tester);
    frames[TurnShellState.revealed] = await TurnShellHarness.capture(tester);

    await tester.tap(find.text('Seat 1'));
    await tester.pump();
    frames[TurnShellState.selecting] = await TurnShellHarness.capture(tester);

    // Past the dwell gate, then confirm.
    await tester.pump(const Duration(seconds: 9));
    await tester.tap(find.byKey(TurnShell.actionButton));
    await tester.pump();
    frames[TurnShellState.confirmed] = await TurnShellHarness.capture(tester);

    // Past the turn floor.
    await tester.pump(const Duration(seconds: 4));
    frames[TurnShellState.passUnlocked] = await TurnShellHarness.capture(tester);

    return frames;
  }

  /// Same schedule, but only records slot rects and the widget-type skeleton.
  Future<Map<TurnShellState, (List<String>, Map<String, Rect>)>> captureAllStructures(
    WidgetTester tester,
    Role role, {
    required String prompt,
  }) async {
    final out = <TurnShellState, (List<String>, Map<String, Rect>)>{};
    void record(TurnShellState state) {
      out[state] = (
        TurnShellHarness.skeleton(tester),
        TurnShellHarness.slotRects(tester),
      );
    }

    await TurnShellHarness.pump(tester, role: role, prompt: prompt);
    record(TurnShellState.handoff);

    await TurnShellHarness.completeHold(tester);
    record(TurnShellState.revealed);

    await tester.tap(find.text('Seat 1'));
    await tester.pump();
    record(TurnShellState.selecting);

    await tester.pump(const Duration(seconds: 9));
    await tester.tap(find.byKey(TurnShell.actionButton));
    await tester.pump();
    record(TurnShellState.confirmed);

    await tester.pump(const Duration(seconds: 4));
    record(TurnShellState.passUnlocked);

    return out;
  }

  group('L-01 pixel symmetry across roles', () {
    // One frame set per role, captured with identical copy and identical data,
    // so any pixel difference can only have come from the role itself.
    final captured = <Role, Map<TurnShellState, Uint8List>>{};

    for (final role in Role.values) {
      testWidgets('captures all five states for ${role.name}', (tester) async {
        captured[role] = await captureAllStates(tester, role);
        expect(captured[role]!.keys.toSet(), equals(allStates.toSet()));
        // A blank capture would make every comparison below trivially pass.
        for (final entry in captured[role]!.entries) {
          expect(entry.value.length, greaterThan(0),
              reason: 'empty capture for ${role.name}/${entry.key.name}');
        }
      });
    }

    testWidgets('all four roles render byte-identical frames in every state',
        (tester) async {
      // Re-capture inside a single test so the comparison never depends on
      // cross-test ordering.
      final frames = <Role, Map<TurnShellState, Uint8List>>{};
      for (final role in Role.values) {
        frames[role] = await captureAllStates(tester, role);
      }

      final reference = frames[Role.mafia]!;
      for (final state in allStates) {
        for (final role in Role.values) {
          if (role == Role.mafia) continue;
          expect(
            frames[role]![state],
            orderedEquals(reference[state]!),
            reason: 'LEAK: ${role.name} renders differently from mafia in '
                'state ${state.name}',
          );
        }
      }
    });

    testWidgets('the comparison is capable of detecting a difference',
        (tester) async {
      // Guards the suite itself: if capture() ever returned a constant, every
      // assertion above would pass vacuously. Two genuinely different prompts
      // must produce different bytes.
      final a = await captureAllStates(tester, Role.mafia, prompt: 'أ');
      final b = await captureAllStates(tester, Role.mafia, prompt: 'ب ب ب ب ب');
      expect(
        a[TurnShellState.revealed],
        isNot(orderedEquals(b[TurnShellState.revealed]!)),
        reason: 'pixel capture is not sensitive to content changes',
      );
    });
  });

  group('L-01/L-02 structural symmetry with role-natural copy', () {
    testWidgets(
        'widget-type skeleton and reserved slot rects are identical across roles '
        'even when the question text differs', (tester) async {
      final structures = <Role, Map<TurnShellState, (List<String>, Map<String, Rect>)>>{};
      for (final role in Role.values) {
        structures[role] = await captureAllStructures(
          tester,
          role,
          prompt: TurnShellHarness.naturalPrompt(role),
        );
      }

      final reference = structures[Role.mafia]!;
      for (final state in allStates) {
        for (final role in Role.values) {
          if (role == Role.mafia) continue;
          final (skeleton, rects) = structures[role]![state]!;
          final (refSkeleton, refRects) = reference[state]!;

          expect(skeleton, orderedEquals(refSkeleton),
              reason: 'LEAK: ${role.name} builds a different widget tree in '
                  'state ${state.name}');
          expect(rects, equals(refRects),
              reason: 'LEAK: ${role.name} moves a reserved slot in '
                  'state ${state.name}');
        }
      }
    });

    testWidgets('prompts really do differ, so the check is not vacuous',
        (tester) async {
      final prompts = Role.values.map(TurnShellHarness.naturalPrompt).toSet();
      expect(prompts.length, equals(Role.values.length));
    });
  });

  group('L-02 reserved detail slot', () {
    testWidgets('detail slot occupies identical bounds whether or not it is filled',
        (tester) async {
      Future<Rect> detailRectWith(String? detail) async {
        await TurnShellHarness.pump(
          tester,
          role: Role.detective,
          prompt: neutralPrompt,
          confirmationDetail: detail,
        );
        await TurnShellHarness.completeHold(tester);
        await tester.tap(find.text('Seat 1'));
        await tester.pump(const Duration(seconds: 9));
        await tester.tap(find.byKey(TurnShell.actionButton));
        await tester.pump(const Duration(seconds: 4));
        return tester.getRect(find.byKey(TurnShell.slotDetail));
      }

      final filled = await detailRectWith('مافيا');
      final empty = await detailRectWith(null);
      expect(filled, equals(empty));
    });
  });
}
