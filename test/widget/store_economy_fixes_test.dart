import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/table_tools.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';
import 'package:mafia_master/ui/screens/setup/store_shop.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/store_nav.dart';

Map<String, dynamic> _wallet({
  int balance = 1000,
  List<String> owned = const [],
  List<Map<String, Object?>> history = const [],
}) => {
  'balance': balance,
  'catalog': [
    {
      'code': 'frame_gilded',
      'price': 200,
      'charge': 200,
      'kind': 'frame',
      'slot': 'frame',
    },
    {
      'code': 'pack_midnight_manor',
      'price': 600,
      'charge': 600,
      'kind': 'presentation_pack',
      'slot': 'room_pack',
    },
  ],
  'owned': owned,
  'equipped': const <String, String>{},
  'history': history,
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
  var wallet = _wallet();
  var tools = _tools();
  Object? toolBuyThrows;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    wallet = _wallet();
    tools = _tools();
    toolBuyThrows = null;
    backend.responders['economy'] = (body) {
      if (body['action'] == 'toolBuy' && toolBuyThrows != null) {
        throw toolBuyThrows!;
      }
      return body['action'] == 'toolsGet' || body['action'] == 'toolBuy'
          ? tools
          : wallet;
    };
  });

  Future<void> pumpStore(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
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

  group('buy sheet', () {
    testWidgets('a double tap buys once and shows no failure', (tester) async {
      await pumpStore(tester);
      await openStoreItem(tester, 'frame_gilded');
      wallet = _wallet(balance: 800, owned: ['frame_gilded']);
      final buy = find.byKey(StoreShopKeys.buy('frame_gilded'));
      await tester.tap(buy);
      await tester.tap(buy, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(calls('buy'), hasLength(1));
      expect(find.byKey(StoreShopKeys.sold), findsOneWidget);
      expect(find.text(arStrings.storeFailed), findsNothing);
      expect(find.text(arStrings.storeBusy), findsNothing);
    });

    testWidgets('a bought tool stays on sale: chips and button remain', (
      tester,
    ) async {
      await pumpStore(tester);
      await openStoreItem(tester, 'anon_note');
      tools = _tools(balance: 960, charges: 1);
      wallet = _wallet(balance: 960);
      await tester.tap(find.byKey(StoreShopKeys.buy('anon_note')));
      await tester.pumpAndSettle();
      expect(calls('toolBuy'), hasLength(1));
      expect(find.byKey(StoreShopKeys.pack('anon_note', 3)), findsOneWidget);
      expect(find.byKey(StoreShopKeys.buy('anon_note')), findsOneWidget);
    });

    testWidgets('a tool purchase carries a request id, a new one per tap', (
      tester,
    ) async {
      await pumpStore(tester);
      await openStoreItem(tester, 'anon_note');
      await tester.tap(find.byKey(StoreShopKeys.buy('anon_note')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(StoreShopKeys.buy('anon_note')));
      await tester.pumpAndSettle();
      final ids = [for (final c in calls('toolBuy')) c.body['requestId']];
      expect(ids, hasLength(2));
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(ids.every((i) => i is String && uuid.hasMatch(i)), isTrue);
      expect(ids.toSet(), hasLength(2));
    });

    testWidgets('any failure on a tool purchase is a neutral message', (
      tester,
    ) async {
      await pumpStore(tester);
      await openStoreItem(tester, 'anon_note');
      toolBuyThrows = StateError('connection reset');
      await tester.tap(find.byKey(StoreShopKeys.buy('anon_note')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(arStrings.toolBuyFailed), findsOneWidget);
      // The shelf was re-read from the server after the failure.
      expect(calls('toolsGet').length, greaterThanOrEqualTo(2));
    });

    testWidgets('a refusal from the server on a coin item says the same', (
      tester,
    ) async {
      await pumpStore(tester);
      await openStoreItem(tester, 'frame_gilded');
      backend.responders['economy'] = (body) =>
          body['action'] == 'buy' ? throw StateError('lost') : wallet;
      await tester.tap(find.byKey(StoreShopKeys.buy('frame_gilded')));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.storeFailed), findsOneWidget);
    });
  });

  group('shelf', () {
    testWidgets('an owned item the catalog no longer lists stays reachable', (
      tester,
    ) async {
      wallet = _wallet(owned: ['frame_crimson']);
      await pumpStore(tester);
      await openDrawer(tester, 'look');
      expect(find.byKey(StoreShopKeys.item('frame_crimson')), findsOneWidget);
    });

    testWidgets('«وصل جديد» picks an item that is on sale', (tester) async {
      await pumpStore(tester);
      // The catalog has no moonlit pack; the featured card is the room pack
      // that is listed.
      expect(find.byKey(StoreShopKeys.featured), findsOneWidget);
    });
  });

  group('store search', () {
    test('Arabic is folded: marks, tatweel, alef forms, ta marbuta, ya', () {
      expect(normalizeStoreSearch('أُسطورة'), normalizeStoreSearch('اسطوره'));
      expect(normalizeStoreSearch('إطــار'), normalizeStoreSearch('اطار'));
      expect(normalizeStoreSearch('مَوْلى'), normalizeStoreSearch('مولي'));
      expect(normalizeStoreSearch(' Noir '), 'noir');
    });
  });

  group('history', () {
    testWidgets('tool, bot win, story and role purchases have names', (
      tester,
    ) async {
      wallet = _wallet(
        history: [
          {
            'kind': 'tool_spend',
            'amount': -40,
            'item': 'anon_note',
            'at': '2026-10-01T10:00:00Z',
          },
          {'kind': 'bot_win', 'amount': 20, 'at': '2026-10-02T10:00:00Z'},
          {
            'kind': 'story_first_solve',
            'amount': 30,
            'at': '2026-10-03T10:00:00Z',
          },
          {
            'kind': 'catalog_spend',
            'amount': -500,
            'item': 'role_elder',
            'at': '2026-10-04T10:00:00Z',
          },
        ],
      );
      await pumpStore(tester);
      await tester.ensureVisible(find.text(arStrings.storeTabHistory));
      await tester.pumpAndSettle();
      await tester.tap(find.text(arStrings.storeTabHistory));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.historyBotWin), findsOneWidget);
      expect(find.text(arStrings.historyStoryFirstSolve), findsOneWidget);
      expect(
        find.text(arStrings.historyCatalogSpend(arStrings.roleElder)),
        findsOneWidget,
      );
      expect(find.text(arStrings.historyAdjustment), findsNothing);
    });
  });

  group('parsing', () {
    test('a bad tool row is skipped, the rest of the shelf stays', () {
      final state = TableToolsState.fromJson({
        'balance': 5,
        'tools': [
          {
            'code': 'a',
            'tier': 'light',
            'packs': {'1': 'forty'},
          },
          'not a map',
          {
            'code': 'anon_note',
            'tier': 'light',
            'packs': {'1': 40},
          },
          {'code': 7, 'tier': 'light', 'packs': {}},
        ],
      });
      // Row one keeps its code with the unreadable pack dropped; the rest
      // of the shelf is intact.
      expect(state.tools.map((t) => t.code), ['a', 'anon_note']);
      expect(state.tools.last.packs, {1: 40});
    });

    test('a bad catalog row or history row is skipped', () {
      final state = WalletState.fromJson({
        'balance': 10,
        'catalog': [
          {'code': 5, 'price': 1},
          {'code': 'frame_gilded', 'price': 200, 'kind': 'frame'},
          'junk',
        ],
        'owned': ['frame_gilded'],
        'history': [
          {'kind': 'match_win', 'amount': 'x'},
          {'kind': 'match_win', 'amount': 5, 'at': 12},
          {'kind': 'bot_win', 'amount': 5},
        ],
      });
      expect(state.catalog.map((i) => i.code), ['frame_gilded']);
      expect(state.history.map((e) => e.kind), contains('bot_win'));
      expect(state.balance, 10);
    });
  });

  group('table tools controller', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'buy: a lost answer reconciles and throws a neutral failure',
      () async {
        final c = container();
        await c.read(tableToolsProvider.future);
        final before = calls('toolsGet').length;
        toolBuyThrows = StateError('timeout');
        await expectLater(
          c.read(tableToolsProvider.notifier).buy('anon_note', 1),
          throwsA(isA<ToolActionFailed>()),
        );
        expect(calls('toolsGet').length, greaterThan(before));
      },
    );

    test('buy: an explicit request id is sent unchanged', () async {
      final c = container();
      await c.read(tableToolsProvider.future);
      await c
          .read(tableToolsProvider.notifier)
          .buy(
            'anon_note',
            1,
            requestId: '11111111-1111-4111-8111-111111111111',
          );
      expect(
        calls('toolBuy').single.body['requestId'],
        '11111111-1111-4111-8111-111111111111',
      );
    });

    test('a shelf that failed to load is asked again', () async {
      var fail = true;
      backend.responders['economy'] = (body) {
        if (body['action'] == 'toolsGet' && fail) {
          throw const BackendException('NETWORK', 'down');
        }
        return tools;
      };
      final c = container();
      await expectLater(c.read(tableToolsProvider.future), throwsA(anything));
      expect(c.read(tableToolsProvider).hasError, isTrue);
      fail = false;
      c.read(tableToolsProvider.notifier).retryIfFailed();
      final again = await c.read(tableToolsProvider.future);
      expect(again.tools, isNotEmpty);
    });
  });
}
