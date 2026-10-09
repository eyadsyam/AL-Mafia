import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/screens/setup/store_shop.dart';
import 'package:mafia_master/ui/widgets/deck/deck_public.dart' show GoldButton;

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/store_nav.dart';

Map<String, dynamic> _wallet({
  int balance = 1000,
  List<String> owned = const [],
}) => {
  'balance': balance,
  'catalog': [
    {
      'code': 'role_elder',
      'price': 500,
      'charge': 500,
      'kind': 'role',
      'slot': null,
    },
    {
      'code': 'narrator_keeper',
      'price': 300,
      'charge': 300,
      'kind': 'narrator_pack',
      'slot': 'narrator',
    },
    {
      'code': 'plate_noir',
      'price': 150,
      'charge': 150,
      'kind': 'nameplate',
      'slot': 'nameplate',
    },
    {
      'code': 'pack_midnight_manor',
      'price': 600,
      'charge': 600,
      'kind': 'presentation_pack',
      'slot': 'room_pack',
    },
    {
      'code': 'frame_gilded',
      'price': 200,
      'charge': 200,
      'kind': 'frame',
      'slot': 'frame',
    },
  ],
  'owned': owned,
  'equipped': const <String, String>{},
  'history': const [],
};

Map<String, dynamic> _tools({int balance = 1000, int charges = 0}) => {
  'balance': balance,
  'tools': [
    {
      'code': 'anon_note',
      'tier': 'light',
      'packs': {'1': 40, '3': 100},
      'charges': charges,
      'perMatch': 1,
      'phase': 'discuss',
      'targets': 0,
    },
  ],
};

void main() {
  late FakeBackend backend;
  late AudioDirector audio;
  var wallet = _wallet();
  var tools = _tools();

  setUp(() {
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    audio = AudioDirector();
    wallet = _wallet();
    tools = _tools();
    backend.responders['economy'] = (body) =>
        body['action'] == 'toolsGet' || body['action'] == 'toolBuy'
        ? tools
        : wallet;
  });

  Future<void> pumpStore(WidgetTester tester, {Size? size}) async {
    await tester.binding.setSurfaceSize(size ?? const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          audioDirectorProvider.overrideWithValue(audio),
          paymentCapabilitiesProvider.overrideWithValue(
            const PaymentCapabilities(transfer: false),
          ),
        ],
        child: localizedApp(const CoinStore()),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Iterable<FakeCall> calls(String action) => backend.calls.where(
    (c) => c.function == 'economy' && c.body['action'] == action,
  );

  testWidgets('categories come from one list; empty drawers are not shown', (
    tester,
  ) async {
    await pumpStore(tester);
    // Tools+roles, narrator, rooms and look have items; bundles do not.
    expect(find.byKey(StoreShopKeys.drawer('tools')), findsOneWidget);
    expect(find.byKey(StoreShopKeys.drawer('narrator')), findsOneWidget);
    expect(find.byKey(StoreShopKeys.drawer('look')), findsOneWidget);
    expect(find.byKey(StoreShopKeys.drawer('rooms')), findsOneWidget);
    expect(find.byKey(StoreShopKeys.drawer('bundles')), findsNothing);
    expect(storeCategories.map((c) => c.id), [
      'tools',
      'narrator',
      'rooms',
      'look',
      'bundles',
    ]);
  });

  testWidgets('a role is sold in the tools drawer and lands as «sold»', (
    tester,
  ) async {
    await pumpStore(tester);
    await openStoreItem(tester, 'role_elder');
    expect(find.text(arStrings.storeKindRole), findsOneWidget);
    expect(find.text(arStrings.storePermanent), findsOneWidget);
    wallet = _wallet(balance: 500, owned: ['role_elder']);
    await tester.tap(find.byKey(CoinStore.buy('role_elder')));
    await tester.pumpAndSettle();
    expect(calls('buy').single.body['item'], 'role_elder');
    expect(find.byKey(StoreShopKeys.sold), findsOneWidget);
    expect(find.text(arStrings.storeRoleHint), findsOneWidget);
    // A role has no slot: the button after the sale just closes the sheet.
    expect(find.text(arStrings.storeRevealDone), findsOneWidget);
  });

  testWidgets('a tool is bought by pack; the gold button carries the cost', (
    tester,
  ) async {
    await pumpStore(tester);
    await openStoreItem(tester, 'anon_note');
    expect(find.text(arStrings.storeOnce), findsOneWidget);
    expect(find.text(arStrings.storeBuyFor(40)), findsOneWidget);
    await tester.tap(find.byKey(StoreShopKeys.pack('anon_note', 3)));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.storeBuyFor(100)), findsOneWidget);
    expect(find.text(arStrings.storeLeftAfter(900)), findsOneWidget);
    tools = _tools(balance: 900, charges: 3);
    wallet = _wallet(balance: 900);
    await tester.tap(find.byKey(CoinStore.buy('anon_note')));
    await tester.pumpAndSettle();
    final buy = calls('toolBuy').single;
    expect(buy.body['tool'], 'anon_note');
    expect(buy.body['pack'], 3);
    expect(find.byKey(StoreShopKeys.sold), findsOneWidget);
    expect(find.text(arStrings.storeToolHint), findsOneWidget);
  });

  testWidgets('not enough: gold button disabled and says what is missing', (
    tester,
  ) async {
    wallet = _wallet(balance: 100);
    await pumpStore(tester);
    await openStoreItem(tester, 'role_elder');
    final button = tester.widget<GoldButton>(
      find.byKey(CoinStore.buy('role_elder')),
    );
    expect(button.onPressed, isNull);
    expect(find.text(arStrings.storeNotEnough(400)), findsOneWidget);
    expect(calls('buy'), isEmpty);
  });

  testWidgets('a refused purchase is said in the sheet and charges nothing', (
    tester,
  ) async {
    await pumpStore(tester);
    await openStoreItem(tester, 'role_elder');
    backend.responders['economy'] = (body) => body['action'] == 'buy'
        ? throw const BackendException('INSUFFICIENT_COINS', 'x')
        : wallet;
    await tester.tap(find.byKey(CoinStore.buy('role_elder')));
    await tester.pumpAndSettle();
    expect(find.byKey(StoreShopKeys.sold), findsNothing);
    expect(find.byKey(CoinStore.buy('role_elder')), findsOneWidget);
  });

  testWidgets('a narrator has a ▶ that previews it; owned shows «عندك»', (
    tester,
  ) async {
    wallet = _wallet(owned: ['narrator_keeper']);
    await pumpStore(tester);
    await openDrawer(tester, 'narrator');
    expect(
      find.descendant(
        of: find.byKey(CoinStore.item('narrator_keeper')),
        matching: find.text(arStrings.storeOwned),
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(StoreShopKeys.listen('narrator_keeper')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final (code, slot) in [
    ('frame_gilded', 'frame'),
    ('plate_noir', 'nameplate'),
    ('pack_midnight_manor', 'room_pack'),
    ('narrator_keeper', 'narrator'),
  ]) {
    testWidgets('«استخدم» puts $code in the $slot slot', (tester) async {
      wallet = _wallet(owned: [code]);
      await pumpStore(tester);
      await openStoreItem(tester, code);
      // «عندك» is on the shelf item and the sheet says so too.
      expect(find.text(arStrings.storeOwned), findsWidgets);
      await tester.tap(find.byKey(CoinStore.equip(code)));
      await tester.pumpAndSettle();
      final equip = calls('equip').single;
      expect(equip.body['slot'], slot);
      expect(equip.body['item'], code);
    });
  }

  testWidgets('no money words on any shop surface', (tester) async {
    await pumpStore(tester);
    await openStoreItem(tester, 'role_elder');
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    for (final word in ['جنيه', 'دولار', r'$', 'EGP', 'USD']) {
      expect(texts.contains(word), isFalse, reason: word);
    }
  });
}
