import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/economy/all_access.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';
import 'package:mafia_master/ui/economy/my_vault.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/widgets/deck/deck_public.dart' show BoneButton;

import '../support/localized.dart';

class _Tools extends TableToolsController {
  @override
  Future<TableToolsState> build() async => const TableToolsState(
    balance: 0,
    tools: [
      TableTool(
        code: 'lock_door',
        tier: ToolTier.heavy,
        packs: {1: 0},
        perMatch: 1,
        phase: 'discuss',
        targets: 0,
        charges: 1,
      ),
      TableTool(
        code: 'sense',
        tier: ToolTier.medium,
        packs: {1: 0},
        perMatch: 1,
        phase: 'night',
        targets: 3,
        charges: 2,
      ),
    ],
  );
}

/// «خزنتي» (owner, 2026-10-29): every kind owned has its own room, its art,
/// and its one choice, sent to the server as an equip.
void main() {
  const everything = WalletState(
    balance: 0,
    catalog: [],
    owned: {
      'role_silencer',
      'role_elder',
      'frame_gilded',
      'frame_crimson',
      'plate_noir',
      'pack_midnight_manor',
      'pack_old_town',
      'narrator_storyteller',
      'narrator_keeper',
    },
    equipped: {'narrator': 'narrator_storyteller'},
    history: [],
  );

  Future<List<(CosmeticSlot, String?)>> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool unlimited = false,
    WalletState wallet = everything,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    final equips = <(CosmeticSlot, String?)>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tableToolsProvider.overrideWith(_Tools.new),
          allAccessProvider.overrideWithValue(unlimited),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
        ],
        child: localizedApp(
          Scaffold(
            body: MyVaultTab(
              wallet: wallet,
              busy: false,
              onEquip: (slot, code) async => equips.add((slot, code)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return equips;
  }

  for (final size in [const Size(360, 640), const Size(390, 844)]) {
    testWidgets('every room opens and fits at $size', (tester) async {
      await pump(tester, size: size);
      for (final page in MyVaultPage.values.skip(1)) {
        final tile = find.byKey(MyVaultTab.tile(page));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$page');
        await tester.tap(find.byKey(MyVaultTab.backKey));
        await tester.pumpAndSettle();
        expect(find.byKey(MyVaultTab.tile(page)), findsOneWidget);
      }
    });
  }

  testWidgets('the narrator: pick another and it is equipped', (tester) async {
    final equips = await pump(tester);
    await tester.tap(find.byKey(MyVaultTab.tile(MyVaultPage.narrator)));
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    // The one already narrating cannot be picked again.
    await tester.scrollUntilVisible(
      find.byKey(MyVaultTab.pick('narrator_storyteller')),
      200,
      scrollable: list,
    );
    final now = tester.widget<BoneButton>(
      find.byKey(MyVaultTab.pick('narrator_storyteller')),
    );
    expect(now.onPressed, isNull);
    await tester.tap(find.text('حارس الأسرار'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(MyVaultTab.pick('narrator_keeper')),
      200,
      scrollable: list,
    );
    await tester.tap(find.byKey(MyVaultTab.pick('narrator_keeper')));
    expect(equips.single, (CosmeticSlot.narrator, 'narrator_keeper'));
  });

  testWidgets('the room: its scene is chosen for the host room', (
    tester,
  ) async {
    final equips = await pump(tester);
    await tester.tap(find.byKey(MyVaultTab.tile(MyVaultPage.room)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(MyVaultTab.pick('pack_midnight_manor')),
    );
    await tester.tap(find.byKey(MyVaultTab.pick('pack_midnight_manor')));
    expect(equips.single, (CosmeticSlot.roomPack, 'pack_midnight_manor'));
  });

  testWidgets('the look: a frame and a plate, each in its slot', (
    tester,
  ) async {
    final equips = await pump(tester);
    await tester.tap(find.byKey(MyVaultTab.tile(MyVaultPage.look)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MyVaultTab.pick('frame_crimson')));
    await tester.ensureVisible(find.byKey(MyVaultTab.pick('plate_noir')));
    await tester.tap(find.byKey(MyVaultTab.pick('plate_noir')));
    expect(equips, [
      (CosmeticSlot.frame, 'frame_crimson'),
      (CosmeticSlot.nameplate, 'plate_noir'),
    ]);
  });

  testWidgets('the tool bag: what is left, or no count on an owner grant', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(MyVaultTab.tile(MyVaultPage.tools)));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.vaultToolLeft(2)), findsOneWidget);
    expect(find.text(arStrings.vaultToolPhaseNight), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pump(tester, unlimited: true);
    await tester.tap(find.byKey(MyVaultTab.tile(MyVaultPage.tools)));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.vaultToolLeft(2)), findsNothing);
    expect(find.text(arStrings.vaultToolsUnlimited), findsWidgets);
  });

  testWidgets('a room with nothing in it says where to find it', (
    tester,
  ) async {
    await pump(
      tester,
      wallet: const WalletState(
        balance: 0,
        catalog: [],
        owned: {},
        equipped: {},
        history: [],
      ),
    );
    await tester.tap(find.byKey(MyVaultTab.tile(MyVaultPage.narrator)));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.vaultNothingHere), findsOneWidget);
  });
}
