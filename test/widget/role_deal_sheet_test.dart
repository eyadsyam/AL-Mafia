import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/setup/role_deal_grid.dart';
import 'package:mafia_master/ui/widgets/deck/deck_public.dart' show BoneButton;

import '../support/artwork.dart';
import '../support/localized.dart';

/// The card opened big from the deal (owner, 2026-10-29): its art, its side,
/// its rule in numbers, and the one action that fits — add or take out a
/// bought role, one more of a base role, or the store for a locked one.
void main() {
  const add = ValueKey('role_sheet_add');

  Future<List<String>> open(
    WidgetTester tester,
    RoleDealSpec Function(List<String> log) build, {
    bool actions = true,
  }) async {
    await loadArtwork(tester);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final log = <String>[];
    final spec = build(log);
    await tester.pumpWidget(
      ProviderScope(
        child: localizedApp(
          Scaffold(
            body: Builder(
              builder: (context) => actions
                  ? RoleDealGrid(cards: [spec])
                  : TextButton(
                      onPressed: () =>
                          showRoleSheet(context, spec, actions: false),
                      child: const Text('open'),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      actions ? find.byKey(RoleDealGrid.count(spec.role)) : find.text('open'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return log;
  }

  BoneButton primary(WidgetTester tester) =>
      tester.widget<BoneButton>(find.byKey(add));

  testWidgets('a base role: its side, its numbers, one more or one less', (
    tester,
  ) async {
    final log = await open(
      tester,
      (log) => RoleDealSpec(
        role: Role.mafia,
        name: 'مافيا',
        count: 2,
        minPlayers: 5,
        onPlus: () => log.add('+'),
        onMinus: () => log.add('-'),
      ),
    );
    expect(find.text(arStrings.roleTeamMafia), findsOneWidget);
    expect(
      find.text(EngineCopy.roleDescription(arStrings, Role.mafia)),
      findsOneWidget,
    );
    expect(find.text('5+'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text(arStrings.rolesSheetMore), findsOneWidget);
    await tester.tap(find.text(arStrings.rolesSheetLess));
    await tester.pumpAndSettle();
    expect(log, ['-']);
    expect(find.byKey(add), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('a bought role at zero is added, and the sheet closes', (
    tester,
  ) async {
    final log = await open(
      tester,
      (log) => RoleDealSpec(
        role: Role.elder,
        name: 'شيخ الصالحين',
        count: 0,
        owned: true,
        minPlayers: 6,
        max: 1,
        onPlus: () => log.add('+'),
        onMinus: () => log.add('-'),
      ),
    );
    expect(find.text(arStrings.roleTeamTown), findsOneWidget);
    expect(find.text(arStrings.rolesSheetLess), findsNothing);
    expect(primary(tester).label, arStrings.rolesSheetAdd);
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    expect(log, ['+']);
  });

  testWidgets('a bought role in the deal is taken out', (tester) async {
    final log = await open(
      tester,
      (log) => RoleDealSpec(
        role: Role.sniper,
        name: 'القناص',
        count: 1,
        owned: true,
        minPlayers: 7,
        max: 1,
        onPlus: () => log.add('+'),
        onMinus: () => log.add('-'),
      ),
    );
    expect(primary(tester).label, arStrings.rolesSheetRemove);
    await tester.tap(find.byKey(add));
    await tester.pumpAndSettle();
    expect(log, ['-']);
  });

  testWidgets('a table too small says why and cannot add', (tester) async {
    final log = await open(
      tester,
      (log) => const RoleDealSpec(
        role: Role.sniper,
        name: 'القناص',
        count: 0,
        owned: true,
        minPlayers: 7,
        blocked: 'من ٧ لاعيبة',
      ),
    );
    expect(find.text('من ٧ لاعيبة'), findsWidgets);
    expect(primary(tester).onPressed, isNull);
    expect(log, isEmpty);
  });

  testWidgets('a locked role opens the store, never the deal', (tester) async {
    final log = await open(
      tester,
      (log) => RoleDealSpec(
        role: Role.silencer,
        name: 'المُسكِت',
        count: 0,
        locked: true,
        onPlus: () => log.add('+'),
      ),
    );
    expect(find.byKey(add), findsNothing);
    expect(find.text(arStrings.roleLockedPill), findsWidgets);
    expect(log, isEmpty);
  });

  testWidgets('read-only: the card and its rule, no buttons', (tester) async {
    await open(
      tester,
      (log) => RoleDealSpec(
        role: Role.doctor,
        name: 'الدكتور',
        count: 1,
        onPlus: () => log.add('+'),
        onMinus: () => log.add('-'),
      ),
      actions: false,
    );
    expect(
      find.text(EngineCopy.roleDescription(arStrings, Role.doctor)),
      findsOneWidget,
    );
    expect(find.byKey(add), findsNothing);
    expect(find.text(arStrings.rolesSheetLess), findsNothing);
  });

  for (final size in [const Size(360, 640), const Size(320, 568)]) {
    testWidgets('the sheet fits a ${size.width.toInt()} phone', (tester) async {
      await open(
        tester,
        (log) => const RoleDealSpec(
          role: Role.detective,
          name: 'المحقق',
          count: 1,
          blocked: 'سطر طويل يشرح ليه الدور ده مش هينفع في القعدة دي دلوقتي',
        ),
      );
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
