import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/setup/store_shop.dart';

/// The drawer each store code lives in, as the shop's category list says.
String drawerOf(String code) => switch (code) {
  'frame_gilded' ||
  'frame_crimson' ||
  'frame_moonlit' ||
  'frame_council_seal' ||
  'frame_invite' ||
  'plate_noir' ||
  'plate_gilded' ||
  'plate_ember' => 'look',
  'pack_midnight_manor' || 'pack_old_town' || 'pack_moonlit_archive' => 'rooms',
  'narrator_storyteller' || 'narrator_keeper' || 'narrator_noir' => 'narrator',
  'bundle_council' || 'bundle_identity' || 'bundle_nocturne' => 'bundles',
  _ => 'tools',
};

/// Opens drawer [id] from the shop index.
Future<void> openDrawer(WidgetTester tester, String id) async {
  final tile = find.byKey(StoreShopKeys.drawer(id));
  if (tile.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(StoreShopKeys.shopList),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// Back to the index from inside a drawer.
Future<void> closeDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(StoreShopKeys.back));
  await tester.pumpAndSettle();
}

/// Opens the buy sheet of [code]: its drawer, then the item.
Future<void> openStoreItem(WidgetTester tester, String code) async {
  await openDrawer(tester, drawerOf(code));
  final item = find.byKey(StoreShopKeys.item(code));
  if (item.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      item,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(StoreShopKeys.drawerList),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}
