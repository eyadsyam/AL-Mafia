/// Doc 14 §1.3 on glass: one grid, *N* tiles, the special one last — and the
/// four roles build the same geometry out of it.
///
/// # Why this is a golden test and not a unit test
///
/// The claim is about *pixels on a phone*, not about a field on a widget. Four
/// players hand one device round; the only thing any of them can compare is
/// where things are. A tile that sits four pixels higher for the Doctor than
/// for the Citizen is a tile that names the Doctor to anybody who has held the
/// phone twice — and nothing short of measuring the rendered rect catches that,
/// because every one of those four trees is "correct".
///
/// # And why the grid replaced a scrolling list
///
/// The list it replaced put the ability control between the seats and the
/// confirm, and the skip control *under* the confirm — three places to look for
/// one decision, two of them below the fold at twelve players. This suite pins
/// the property that fixed it: every option is a tile, every tile is the same
/// tile, and the last one is always in the last position.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/turn_shell_harness.dart';

void main() {
  /// Opens the turn for [role] with the full grid its night screen builds.
  Future<void> open(
    WidgetTester tester,
    Role role, {
    bool spent = false,
  }) async {
    await TurnShellHarness.pump(
      tester,
      role: role,
      prompt: TurnShellHarness.naturalPrompt(role),
      targetList: TurnShellHarness.withSpecial(role, spent: spent),
    );
    await TurnShellHarness.completeHold(tester);
  }

  /// The rect of the special tile — the last one, whatever it says.
  Rect specialRect(WidgetTester tester, Role role) {
    final seat = role == Role.doctor ? 99 : NightChoice.skipSeat;
    return tester.getRect(find.byKey(NightGrid.tile(seat)));
  }

  group('doc 14 §1.3 — the special tile is in the same place for everybody',
      () {
    testWidgets('one rect, and all four roles get it', (tester) async {
      final rects = <Role, Rect>{};
      for (final role in Role.values) {
        await open(tester, role);
        rects[role] = specialRect(tester, role);
      }

      final first = rects[Role.values.first]!;
      for (final entry in rects.entries) {
        expect(entry.value, first,
            reason: '${entry.key} draws its special tile somewhere else');
      }
      // And it is a real tile rather than a collapsed one, so that "identical"
      // is not being satisfied by four zero-height boxes.
      expect(first.height, greaterThan(0));
      expect(first.width, greaterThan(0));
    });

    testWidgets('a spent tile keeps the rect it had when it was live',
        (tester) async {
      // Doc 14 §1.3: *"It never disappears — a disappearing tile changes the
      // grid shape, and grid shape is a tell."*
      for (final role in [Role.mafia, Role.doctor]) {
        await open(tester, role);
        final live = specialRect(tester, role);
        await open(tester, role, spent: true);
        final used = specialRect(tester, role);
        expect(used, live, reason: '$role moves its tile once it is spent');
      }
    });

    testWidgets('a spent tile is still on screen, and no longer tappable',
        (tester) async {
      await open(tester, Role.doctor, spent: true);

      final tile = find.byKey(NightGrid.tile(99));
      expect(tile, findsOneWidget);
      expect(
        tester.widget<NightGridTile>(tile).onTap,
        isNull,
        reason: 'a spent tile that still accepts taps is a second use',
      );

      // Tapping it selects nothing, so the confirm stays shut.
      await tester.tap(tile, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 9));
      expect(TurnShellHarness.actionEnabled(tester), isFalse);
    });

    testWidgets('every role builds the same tree', (tester) async {
      // The structural half: the same widget types in the same nesting for
      // every role, so the only difference between two screens is the string
      // inside one Text. `skeleton` deliberately records types and depth and no
      // metrics at all.
      final skeletons = <Role, List<String>>{};
      for (final role in Role.values) {
        await open(tester, role);
        skeletons[role] = TurnShellHarness.skeleton(tester);
      }

      final first = skeletons[Role.values.first]!;
      for (final entry in skeletons.entries) {
        expect(entry.value, first,
            reason: '${entry.key} builds a different tree');
      }
    });
  });

  group('the grid fits, at every table size', () {
    /// Doc 14 §1.3's column table.
    testWidgets('the column count follows the tile count', (tester) async {
      expect(NightGrid.columnsFor(5), 2);
      expect(NightGrid.columnsFor(6), 2);
      expect(NightGrid.columnsFor(7), 3);
      expect(NightGrid.columnsFor(12), 3);
      expect(NightGrid.columnsFor(13), 4);
      expect(NightGrid.columnsFor(15), 4);
    });

    testWidgets('nothing scrolls and nothing overflows, 5 through 15',
        (tester) async {
      for (final players in [5, 9, 12, 15]) {
        await TurnShellHarness.pump(
          tester,
          role: Role.citizen,
          prompt: TurnShellHarness.naturalPrompt(Role.citizen),
          targetList: [
            for (var seat = 0; seat < players - 1; seat++)
              NightChoice(seat: seat, label: 'لاعب $seat'),
            const NightChoice(
              seat: NightChoice.skipSeat,
              label: 'مش شاكك في حد',
              special: true,
            ),
          ],
        );
        await TurnShellHarness.completeHold(tester);

        // Every tile is mounted *and* inside the grid's own bounds. A tile
        // below the fold is a seat a hurried player never considers, which is
        // the viewport deciding who dies.
        final grid = tester.getRect(find.byKey(TurnShell.slotGrid));
        for (var seat = 0; seat < players - 1; seat++) {
          final tile = find.byKey(NightGrid.tile(seat));
          expect(tile, findsOneWidget, reason: 'seat $seat at $players');
          final rect = tester.getRect(tile);
          expect(rect.top, greaterThanOrEqualTo(grid.top - 0.5),
              reason: 'seat $seat is above the grid at $players');
          expect(rect.bottom, lessThanOrEqualTo(grid.bottom + 0.5),
              reason: 'seat $seat is below the fold at $players');
        }
        expect(find.byType(Scrollable), findsNothing,
            reason: 'the grid scrolled at $players players');
      }
    });
  });

  group('one tap confirms', () {
    testWidgets('pick, wait out the dwell, confirm — no long press anywhere',
        (tester) async {
      int? confirmed;
      await TurnShellHarness.pump(
        tester,
        role: Role.mafia,
        prompt: TurnShellHarness.naturalPrompt(Role.mafia),
        targetList: TurnShellHarness.withSpecial(Role.mafia),
        onConfirmed: (seat) => confirmed = seat,
      );
      await TurnShellHarness.completeHold(tester);

      await tester.tap(find.byKey(NightGrid.tile(1)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pump();

      expect(confirmed, 1);
    });

    testWidgets('the special tile confirms through the same button',
        (tester) async {
      // Doc 14 §4.1 removed the separate "choose nobody" control under the
      // confirm. There is one path off this screen now, and this is it.
      int? confirmed;
      await TurnShellHarness.pump(
        tester,
        role: Role.citizen,
        prompt: TurnShellHarness.naturalPrompt(Role.citizen),
        targetList: TurnShellHarness.withSpecial(Role.citizen),
        onConfirmed: (seat) => confirmed = seat,
      );
      await TurnShellHarness.completeHold(tester);

      await tester.tap(find.byKey(NightGrid.tile(NightChoice.skipSeat)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pump();

      expect(confirmed, NightChoice.skipSeat);
    });
  });
}
