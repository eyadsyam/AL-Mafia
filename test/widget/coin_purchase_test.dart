import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/links/external_link.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/account_protection.dart';
import 'package:mafia_master/ui/economy/coin_packs.dart';
import 'package:mafia_master/ui/screens/admin/coin_review_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

const instapayUrl = 'https://pay.example/instapay/owner';

/// A small stand-in for `coin_orders`: server-held orders that survive a
/// "reload", server-owned prices, and no balance change from anything but an
/// admin approval.
class CoinServer extends FakeBackend {
  CoinServer()
    : super(
        roomId: 'r',
        state: roomState(phase: 'lobby'),
        players: roster(5),
      );

  bool enabled = true;
  bool recoverable = true;
  bool admin = false;
  bool pass = false;
  bool adFree = false;
  final orders = <Map<String, dynamic>>[];
  int balance = 0;

  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, dynamic> body,
  ) async {
    if (function == 'economy') {
      calls.add(FakeCall(function, body));
      return {'balance': balance, 'catalog': [], 'owned': []};
    }
    if (function != 'coin_orders' || refusals.containsKey(function)) {
      return super.call(function, body);
    }
    calls.add(FakeCall(function, body));
    switch (body['action']) {
      case 'shop':
        return {
          'enabled': enabled,
          'recoverable': recoverable,
          'packs': [
            {'code': 'coins_500', 'coins': 500, 'pricePiastres': 5000},
            {'code': 'coins_1200', 'coins': 1200, 'pricePiastres': 11000},
            if (pass)
              {
                'code': 'quiet_pass',
                'coins': 0,
                'pricePiastres': 15000,
                'entitlement': 'remove_interruptions',
              },
          ],
          'adFree': adFree,
          'methods': enabled
              ? [
                  {'code': 'instapay', 'available': true, 'url': instapayUrl},
                  {'code': 'vodafone_cash', 'available': false},
                ]
              : [],
          'orders': orders,
        };
      case 'create':
        final open = orders.where((o) => o['status'] == 'awaiting_transfer');
        if (open.isNotEmpty) return {'order': open.first, 'resumed': true};
        final order = {
          'id': 'order-${orders.length + 1}',
          'reference': 'MM-ABCD1234',
          'coins': body['pack'] == 'coins_500'
              ? 500
              : body['pack'] == 'quiet_pass'
              ? 0
              : 1200,
          'amountPiastres': body['pack'] == 'coins_500'
              ? 5000
              : body['pack'] == 'quiet_pass'
              ? 15000
              : 11000,
          'method': body['method'],
          'status': 'awaiting_transfer',
        };
        orders.insert(0, order);
        return {'order': order, 'resumed': false};
      case 'claim':
        final order = orders.firstWhere((o) => o['id'] == body['order']);
        order['status'] = 'claimed';
        order['claimReference'] = body['reference'];
        return {'order': order};
      case 'cancel':
        final order = orders.firstWhere((o) => o['id'] == body['order']);
        order['status'] = 'cancelled';
        return {'order': order};
      case 'admin_list':
        if (!admin) throw const BackendException('NOT_ADMIN', 'no');
        return {'orders': orders};
      case 'admin_review':
        if (!admin) throw const BackendException('NOT_ADMIN', 'no');
        final order = orders.firstWhere((o) => o['id'] == body['order']);
        if (body['decision'] == 'approve') {
          if (body['receivedPiastres'] != order['amountPiastres']) {
            throw const BackendException('AMOUNT_MISMATCH', 'no');
          }
          order['status'] = 'paid';
          balance += order['coins'] as int;
        }
        return {'order': order};
    }
    throw const BackendException('BAD_REQUEST', 'no');
  }
}

class FakeAccounts implements AccountService {
  bool linked = false;
  String? codeSentTo;
  @override
  Future<AccountStatus> status() async => linked
      ? const AccountStatus(recoverable: true, email: 'p@example.test')
      : AccountStatus.anonymous;
  @override
  Future<void> requestLink(String email) async {
    if (!email.contains('@')) throw const AccountFailure('INVALID_EMAIL');
    codeSentTo = email;
  }

  @override
  Future<AccountStatus> confirmLink(String email, String code) async {
    if (code != '123456') throw const AccountFailure('INVALID_CODE');
    linked = true;
    return status();
  }

  @override
  Future<void> requestRecovery(String email) async => codeSentTo = email;
  @override
  Future<AccountStatus> confirmRecovery(String email, String code) =>
      confirmLink(email, code);
}

void main() {
  late CoinServer server;
  late FakeAccounts accounts;
  late List<String> opened;
  late bool openWorks;

  setUp(() {
    server = CoinServer();
    accounts = FakeAccounts();
    opened = [];
    openWorks = true;
  });

  Widget app(Widget child, {bool web = true}) => ProviderScope(
    overrides: [
      onlineBackendFactoryProvider.overrideWithValue(() async => server),
      accountServiceProvider.overrideWithValue(accounts),
      paymentCapabilitiesProvider.overrideWithValue(
        PaymentCapabilities(webTransfer: web),
      ),
      externalLinkOpenerProvider.overrideWithValue((url) {
        opened.add(url);
        return openWorks;
      }),
    ],
    child: localizedApp(child),
  );

  Future<void> pumpPacks(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const Scaffold(body: CoinPacksTab())));
    await tester.pumpAndSettle();
  }

  Iterable<FakeCall> coinCalls(String action) => server.calls.where(
    (c) => c.function == 'coin_orders' && c.body['action'] == action,
  );

  group('Google Play build', () {
    testWidgets('the store has no coin purchase at all', (tester) async {
      await tester.pumpWidget(app(const CoinStore(), web: false));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.storeTabCoins), findsNothing);
      expect(find.byType(CoinPacksTab), findsNothing);
      expect(coinCalls('shop'), isEmpty);
    });

    test(
      'no payment destination, wallet link or transfer URL ships in the app',
      () {
        final sources =
            [
              ...Directory('lib').listSync(recursive: true),
              ...Directory('android/app/src').listSync(recursive: true),
              ...Directory('web').listSync(recursive: true),
            ].whereType<File>().where(
              (f) => RegExp(r'\.(dart|kt|xml|html|json|js)$').hasMatch(f.path),
            );
        for (final file in sources) {
          final text = file.readAsStringSync();
          for (final banned in ['ipn.eg', 'vf.eg', 'vfcash', 'instapay/']) {
            expect(
              text.contains(banned),
              isFalse,
              reason: '${file.path} contains $banned',
            );
          }
        }
      },
    );

    test('the web capability cannot turn on outside a browser', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(paymentCapabilitiesProvider).webTransfer, isFalse);
    });
  });

  group('web coin packs (manual review)', () {
    testWidgets('sales switched off: an honest sentence, no buttons', (
      tester,
    ) async {
      server.enabled = false;
      await pumpPacks(tester);
      expect(find.text(arStrings.coinPacksUnavailable), findsOneWidget);
      expect(find.byKey(CoinPacksTab.createButton), findsNothing);
    });

    testWidgets('a server without orders says so, with a retry', (
      tester,
    ) async {
      server.refusals['coin_orders'] = const BackendException('NETWORK', 'x');
      server.stickyRefusals.add('coin_orders');
      await pumpPacks(tester);
      expect(find.text(arStrings.coinPacksUnavailable), findsOneWidget);
      expect(find.text(arStrings.videoRetry), findsOneWidget);
    });

    testWidgets('an unprotected account must link an email first', (
      tester,
    ) async {
      server.recoverable = false;
      await pumpPacks(tester);
      expect(find.text(arStrings.coinPacksNeedAccount), findsOneWidget);
      expect(find.byType(AccountProtectionCard), findsOneWidget);
      expect(find.byKey(CoinPacksTab.createButton), findsNothing);
    });

    testWidgets('pack, then the method opens its page and makes the order; claim: coins only after review', (
      tester,
    ) async {
      await pumpPacks(tester);
      // The notice is on screen before anything is ordered or opened.
      expect(find.text(arStrings.coinManualNotice), findsOneWidget);
      FilledButton method(String code) => tester.widget<FilledButton>(
        find.byKey(CoinPacksTab.method(code)),
      );
      // Nothing to pay for until a pack is chosen.
      expect(method('instapay').onPressed, isNull);
      await tester.tap(find.byKey(CoinPacksTab.pack('coins_500')));
      await tester.pumpAndSettle();
      // An unconfigured method cannot be used.
      expect(method('vodafone_cash').onPressed, isNull);
      expect(opened, isEmpty);
      // The method is the link: it opens inside the tap and the order is
      // made alongside it.
      await tester.tap(find.byKey(CoinPacksTab.method('instapay')));
      expect(opened, [instapayUrl], reason: 'opened in the tap itself');
      await tester.pumpAndSettle();

      final created = coinCalls('create').single.body;
      expect(created.keys.toSet(), {
        'action',
        'pack',
        'method',
      }, reason: 'no price, amount or coins from the client');
      expect(
        find.text(arStrings.coinOrderTitle('MM-ABCD1234')),
        findsOneWidget,
      );

      // Coming back: the page can be opened again from the order.
      await tester.tap(find.byKey(CoinPacksTab.openButton));
      expect(opened, [instapayUrl, instapayUrl], reason: 'exactly the configured link');
      // Opening (and coming back) adds nothing.
      expect(server.balance, 0);

      final claim = find.byKey(CoinPacksTab.claimButton);
      expect(tester.widget<FilledButton>(claim).onPressed, isNull);
      await tester.enterText(find.byKey(CoinPacksTab.referenceField), 'TX99');
      await tester.pump();
      await tester.tap(claim);
      await tester.pumpAndSettle();
      expect(coinCalls('claim').single.body['reference'], 'TX99');
      expect(find.text(arStrings.coinStatusClaimed), findsOneWidget);
      expect(server.balance, 0, reason: 'a claim is not a payment');
    });

    testWidgets('the web Quiet Pass: ordered like a pack, says it is for the Android app', (
      tester,
    ) async {
      server.pass = true;
      await pumpPacks(tester);
      await tester.ensureVisible(find.byKey(CoinPacksTab.pack('quiet_pass')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoinPacksTab.pack('quiet_pass')));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.webPassBody), findsOneWidget);
      await tester.tap(find.byKey(CoinPacksTab.method('instapay')));
      await tester.pumpAndSettle();
      expect(coinCalls('create').single.body['pack'], 'quiet_pass');
      expect(opened, [instapayUrl]);
      expect(find.text(arStrings.coinOrderPassSummary('150', arStrings.coinPayInstapay)), findsOneWidget);
    });

    testWidgets('an account that owns the pass cannot order it again', (
      tester,
    ) async {
      server
        ..pass = true
        ..adFree = true;
      await pumpPacks(tester);
      await tester.ensureVisible(find.byKey(CoinPacksTab.pack('quiet_pass')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoinPacksTab.pack('quiet_pass')));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.webPassOwned), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(CoinPacksTab.method('instapay'))).onPressed,
        isNull,
      );
    });

    testWidgets('a reload shows the same pending order, not a new one', (      tester,
    ) async {
      server.orders.add({
        'id': 'order-1',
        'reference': 'MM-KEEP0001',
        'coins': 500,
        'amountPiastres': 5000,
        'method': 'instapay',
        'status': 'awaiting_transfer',
      });
      await pumpPacks(tester);
      expect(
        find.text(arStrings.coinOrderTitle('MM-KEEP0001')),
        findsOneWidget,
      );
      expect(find.byKey(CoinPacksTab.createButton), findsNothing);
      expect(find.byKey(CoinPacksTab.cancelButton), findsOneWidget);
    });

    testWidgets('a blocked pop-up is reported, not assumed opened', (
      tester,
    ) async {
      openWorks = false;
      server.orders.add({
        'id': 'order-1',
        'reference': 'MM-POP00001',
        'coins': 500,
        'amountPiastres': 5000,
        'method': 'instapay',
        'status': 'awaiting_transfer',
      });
      await pumpPacks(tester);
      await tester.tap(find.byKey(CoinPacksTab.openButton));
      await tester.pump();
      expect(find.text(arStrings.coinOpenFailed), findsOneWidget);
    });

    testWidgets('a paid order says how many coins were added', (tester) async {
      server.orders.add({
        'id': 'order-1',
        'reference': 'MM-PAID0001',
        'coins': 500,
        'amountPiastres': 5000,
        'method': 'instapay',
        'status': 'paid',
      });
      await pumpPacks(tester);
      expect(find.text(arStrings.coinStatusPaid(500)), findsOneWidget);
    });
  });

  group('account protection', () {
    testWidgets('link an email with a one-time code', (tester) async {
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: SingleChildScrollView(child: AccountProtectionCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AccountProtectionCard.linkButton));
      await tester.pump();
      await tester.enterText(
        find.byKey(AccountProtectionCard.emailField),
        'bad',
      );
      await tester.tap(find.byKey(AccountProtectionCard.sendButton));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.accountErrorEmail), findsOneWidget);
      await tester.enterText(
        find.byKey(AccountProtectionCard.emailField),
        'p@example.test',
      );
      await tester.tap(find.byKey(AccountProtectionCard.sendButton));
      await tester.pumpAndSettle();
      expect(accounts.codeSentTo, 'p@example.test');
      await tester.enterText(
        find.byKey(AccountProtectionCard.codeField),
        '000000',
      );
      await tester.tap(find.byKey(AccountProtectionCard.confirmButton));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.accountErrorCode), findsOneWidget);
      await tester.enterText(
        find.byKey(AccountProtectionCard.codeField),
        '123456',
      );
      await tester.tap(find.byKey(AccountProtectionCard.confirmButton));
      await tester.pumpAndSettle();
      expect(
        find.text(arStrings.accountProtected('p@example.test')),
        findsOneWidget,
      );
    });
  });

  group('admin review', () {
    Future<void> pumpAdmin(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(const CoinReviewScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('a non-admin sees a refusal and no orders', (tester) async {
      server.orders.add({'id': 'o1', 'reference': 'MM-1', 'status': 'claimed'});
      await pumpAdmin(tester);
      expect(find.text(arStrings.adminNotAdmin), findsOneWidget);
      expect(find.byKey(CoinReviewScreen.approve('o1')), findsNothing);
    });

    testWidgets('approval sends the matched transaction and amount', (
      tester,
    ) async {
      server
        ..admin = true
        ..orders.add({
          'id': 'o1',
          'reference': 'MM-1',
          'coins': 500,
          'amountPiastres': 5000,
          'method': 'instapay',
          'status': 'claimed',
          'claimReference': 'TX99',
          'account': 'p@example.test',
        });
      await pumpAdmin(tester);
      await tester.enterText(
        find.byKey(CoinReviewScreen.transaction('o1')),
        'BANK-1',
      );
      await tester.enterText(find.byKey(CoinReviewScreen.received('o1')), '40');
      await tester.tap(find.byKey(CoinReviewScreen.approve('o1')));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.adminErrorAmount), findsOneWidget);
      expect(server.balance, 0);

      await tester.enterText(find.byKey(CoinReviewScreen.received('o1')), '50');
      await tester.tap(find.byKey(CoinReviewScreen.approve('o1')));
      await tester.pumpAndSettle();
      final review = server.calls
          .where((c) => c.body['action'] == 'admin_review')
          .last
          .body;
      expect(review['decision'], 'approve');
      expect(review['transaction'], 'BANK-1');
      expect(review['receivedPiastres'], 5000);
      expect(server.balance, 500);
    });
  });
}
