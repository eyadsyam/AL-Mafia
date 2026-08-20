import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/turn_shell_harness.dart';

/// US2 / T040–T041 — timing parity for [TurnShell].
///
/// Leakage invariants L-07 (dwell gate), L-08 (turn floor) and L-09 (no
/// per-role duration override).
///
/// Rather than asserting that the gates equal the constants this file already
/// knows about, each gate is **measured** by binary-searching the instant at
/// which the control flips from disabled to enabled, at 1 ms resolution, on the
/// test binding's fake clock. The measured instants are then compared across
/// roles and across action speeds. A hard-coded expectation could be satisfied
/// by a widget that reads the same constant; a measurement cannot.
void main() {
  const timing = MafiaTiming.defaults;
  const searchCeiling = Duration(seconds: 20);
  const resolution = Duration(milliseconds: 1);

  /// Runs one turn and reports whether the primary action button is enabled at
  /// turn-time [probeAt].
  ///
  /// Selection and confirmation are only performed if they fall at or before
  /// the probe instant, which keeps the probe monotonic in [probeAt] — the
  /// precondition the binary search relies on.
  Future<bool> probe(
    WidgetTester tester, {
    required Role role,
    required Duration probeAt,
    required Duration selectAt,
    Duration? confirmAt,
  }) async {
    await TurnShellHarness.pump(
      tester,
      role: role,
      prompt: TurnShellHarness.naturalPrompt(role),
    );
    await TurnShellHarness.completeHold(tester); // turn-time t = 0

    var now = Duration.zero;
    Future<void> advanceTo(Duration target) async {
      if (target > now) {
        await tester.pump(target - now);
        now = target;
      }
    }

    if (probeAt >= selectAt) {
      await advanceTo(selectAt);
      await tester.tap(find.text('Seat 1'));
      await tester.pump();
    }
    if (confirmAt != null && probeAt >= confirmAt) {
      await advanceTo(confirmAt);
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pump();
    }
    await advanceTo(probeAt);
    return TurnShellHarness.actionEnabled(tester);
  }

  /// Binary-searches the earliest turn-time at which the button is enabled.
  Future<Duration> measureUnlock(
    WidgetTester tester, {
    required Role role,
    Duration selectAt = Duration.zero,
    Duration? confirmAt,
  }) async {
    var lo = confirmAt ?? Duration.zero; // must be locked here
    var hi = searchCeiling; // must be unlocked here

    expect(
      await probe(tester, role: role, probeAt: lo, selectAt: selectAt, confirmAt: confirmAt),
      isFalse,
      reason: 'search lower bound $lo was already unlocked',
    );
    expect(
      await probe(tester, role: role, probeAt: hi, selectAt: selectAt, confirmAt: confirmAt),
      isTrue,
      reason: 'never unlocked by $hi',
    );

    while (hi - lo > resolution) {
      final mid = Duration(microseconds: (lo.inMicroseconds + hi.inMicroseconds) ~/ 2);
      final unlocked =
          await probe(tester, role: role, probeAt: mid, selectAt: selectAt, confirmAt: confirmAt);
      if (unlocked) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    // Snap to the measurement resolution. The bisection converges to a
    // sub-millisecond neighbourhood of the true instant whose exact endpoint
    // depends on where the search started, so comparing raw microseconds would
    // compare the search, not the widget. 1 ms is well below anything a player
    // at the table could perceive.
    return Duration(milliseconds: (hi.inMicroseconds / 1000).round());
  }

  group('L-07 dwell gate', () {
    testWidgets('Confirm unlocks at the same measured instant for all four roles',
        (tester) async {
      final measured = <Role, Duration>{};
      for (final role in Role.values) {
        measured[role] = await measureUnlock(tester, role: role);
      }

      final distinct = measured.values.toSet();
      expect(distinct.length, equals(1),
          reason: 'LEAK: Confirm unlock time varies by role: $measured');
      // And it is the token value, not some accidental constant.
      expect(distinct.single.inMilliseconds,
          closeTo(timing.dwellGate.inMilliseconds, resolution.inMilliseconds));
    });

    testWidgets('Confirm unlock is unaffected by how quickly the target was picked',
        (tester) async {
      const pickTimes = [
        Duration.zero,
        Duration(seconds: 3),
        Duration(milliseconds: 7900),
      ];

      final measured = <Duration, Duration>{};
      for (final pickAt in pickTimes) {
        measured[pickAt] =
            await measureUnlock(tester, role: Role.detective, selectAt: pickAt);
      }

      expect(measured.values.toSet().length, equals(1),
          reason: 'LEAK: Confirm unlock time varies with selection speed: $measured');
    });

    testWidgets('Confirm is genuinely locked just before the gate and open just after',
        (tester) async {
      for (final role in Role.values) {
        final justBefore = timing.dwellGate - resolution;
        expect(
          await probe(tester, role: role, probeAt: justBefore, selectAt: Duration.zero),
          isFalse,
          reason: '${role.name}: Confirm was enabled at $justBefore',
        );
        expect(
          await probe(tester, role: role, probeAt: timing.dwellGate, selectAt: Duration.zero),
          isTrue,
          reason: '${role.name}: Confirm was still disabled at ${timing.dwellGate}',
        );
      }
    });
  });

  group('L-08 pass gate', () {
    testWidgets('Pass unlocks at the same measured instant for all four roles',
        (tester) async {
      final measured = <Role, Duration>{};
      for (final role in Role.values) {
        measured[role] = await measureUnlock(
          tester,
          role: role,
          confirmAt: timing.dwellGate,
        );
      }

      final distinct = measured.values.toSet();
      expect(distinct.length, equals(1),
          reason: 'LEAK: Pass unlock time varies by role: $measured');
      expect(distinct.single.inMilliseconds,
          closeTo(timing.turnFloor.inMilliseconds, resolution.inMilliseconds));
    });

    testWidgets(
        'Pass unlock is measured from the reveal, not from the confirm — so it does '
        'not depend on how fast the action was taken', (tester) async {
      // Three players who all confirm at different speeds, every one of them
      // before the floor. If the floor were relative to the confirm instant,
      // these would come out 3.5s apart.
      const confirmTimes = [
        Duration(seconds: 8),
        Duration(milliseconds: 9500),
        Duration(milliseconds: 11500),
      ];

      final measured = <Duration, Duration>{};
      for (final confirmAt in confirmTimes) {
        measured[confirmAt] = await measureUnlock(
          tester,
          role: Role.mafia,
          confirmAt: confirmAt,
        );
      }

      expect(measured.values.toSet().length, equals(1),
          reason: 'LEAK: Pass unlock time varies with action speed: $measured');
      expect(measured.values.first.inMilliseconds,
          closeTo(timing.turnFloor.inMilliseconds, resolution.inMilliseconds));
    });

    testWidgets('a player who dawdles past the floor is not made to wait again',
        (tester) async {
      // Confirming after the floor has already passed must unlock Pass
      // immediately: the shell adds delay, it never adds it twice.
      const lateConfirm = Duration(seconds: 15);
      for (final role in Role.values) {
        final enabled = await probe(
          tester,
          role: role,
          probeAt: lateConfirm,
          selectAt: Duration.zero,
          confirmAt: lateConfirm,
        );
        expect(enabled, isTrue, reason: '${role.name}: Pass still locked at $lateConfirm');
      }
    });

    testWidgets('Pass is locked just before the floor and open just after',
        (tester) async {
      for (final role in Role.values) {
        expect(
          await probe(
            tester,
            role: role,
            probeAt: timing.turnFloor - resolution,
            selectAt: Duration.zero,
            confirmAt: timing.dwellGate,
          ),
          isFalse,
          reason: '${role.name}: Pass was enabled before the floor',
        );
        expect(
          await probe(
            tester,
            role: role,
            probeAt: timing.turnFloor,
            selectAt: Duration.zero,
            confirmAt: timing.dwellGate,
          ),
          isTrue,
          reason: '${role.name}: Pass was still locked at the floor',
        );
      }
    });
  });

  group('L-09 no per-role timing path exists at all', () {
    test('turn_shell.dart never mentions a specific role', () {
      final source = File('lib/ui/widgets/turn_shell.dart').readAsStringSync();
      final mentions = Role.values
          .map((r) => 'Role.${r.name}')
          .where(source.contains)
          .toList();
      expect(mentions, isEmpty,
          reason: 'TurnShell branches on a specific role: $mentions');
    });

    test('turn_shell.dart declares no inline Duration literals', () {
      final source = File('lib/ui/widgets/turn_shell.dart').readAsStringSync();
      // `Duration.zero` is permitted (it is the placeholder replaced from
      // tokens); a constructed Duration is not.
      final inline = RegExp(r'Duration\s*\(').allMatches(source).length;
      expect(inline, equals(0),
          reason: 'TurnShell hard-codes a duration instead of reading MafiaTiming');
    });
  });

  group('abandoned hold', () {
    testWidgets('releasing the pad early does not start the turn clock',
        (tester) async {
      await TurnShellHarness.pump(tester, role: Role.doctor, prompt: 'p');
      final gesture =
          await tester.startGesture(tester.getCenter(find.byKey(TurnShell.holdPad)));
      await tester.pump();
      await tester.pump(timing.holdToReveal - resolution);
      await gesture.up();
      await tester.pump();

      // Still on the pad.
      expect(find.byKey(TurnShell.holdPad), findsOneWidget);

      // Waiting out the whole floor changes nothing: no clock is running.
      await tester.pump(timing.turnFloor);
      expect(find.byKey(TurnShell.holdPad), findsOneWidget);

      // A fresh, complete hold starts t = 0 now, so Confirm is still gated by
      // the full dwell.
      await TurnShellHarness.completeHold(tester);
      await tester.tap(find.text('Seat 1'));
      await tester.pump(timing.dwellGate - resolution);
      expect(TurnShellHarness.actionEnabled(tester), isFalse);
      await tester.pump(resolution);
      expect(TurnShellHarness.actionEnabled(tester), isTrue);
    });
  });
}
