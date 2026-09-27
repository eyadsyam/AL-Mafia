import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mafia_master/platform/links/external_link.dart';
import 'package:mafia_master/platform/payment_capabilities.dart';
import 'package:mafia_master/platform/payment_proof.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/account_protection.dart';
import 'package:mafia_master/ui/economy/coin_packs.dart';
import 'package:mafia_master/ui/screens/admin/payments_admin_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

const instapayUrl = 'https://pay.example/instapay/owner';

/// A small stand-in for `coin_orders` (Payments v2): server-held orders,
/// server-owned prices, a per-platform switch, proof required, at most two
/// pending, and no balance change from anything but an admin approval.
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
  bool adFree = false;
  BackendException? createRefusal;
  BackendException? submitRefusal;
  final orders = <Map<String, dynamic>>[];
  final hashes = <String>{};
  int balance = 0;

  Map<String, dynamic> _order(String id) =>
      orders.firstWhere((o) => o['id'] == id);

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
    final pending = orders.where(
      (o) => const {
        'awaiting_transfer',
        'claimed',
        'needs_info',
      }.contains(o['status']),
    );
    switch (body['action']) {
      case 'shop':
        return {
          'enabled': enabled,
          'recoverable': recoverable,
          'maxPending': 2,
          'packs': [
            {
              'code': 'coins_500',
              'coins': 500,
              'pricePiastres': 4999,
              'playProduct': 'mm_coins_500',
            },
            {
              'code': 'quiet_pass',
              'coins': 0,
              'pricePiastres': 19999,
              'entitlement': 'remove_interruptions',
              'playProduct': 'mm_remove_interruptions',
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
        if (createRefusal case final refusal?) throw refusal;
        if (pending.length >= 2) {
          throw const BackendException('TOO_MANY_PENDING', 'no');
        }
        final order = {
          'id': 'order-${orders.length + 1}',
          'reference': 'MM-ABCD000${orders.length + 1}',
          'pack': body['pack'],
          'coins': body['pack'] == 'coins_500' ? 500 : 0,
          'amountPiastres': body['pack'] == 'coins_500' ? 4999 : 19999,
          'method': body['method'],
          'status': 'awaiting_transfer',
        };
        orders.insert(0, order);
        return {'order': order, 'resumed': false};
      case 'submit':
        if (submitRefusal case final refusal?) throw refusal;
        final image = body['image'] as String?;
        final sender = (body['senderName'] as String? ?? '').trim();
        if (image == null || sender.length < 2) {
          throw const BackendException('BAD_REQUEST', 'proof required');
        }
        if (!hashes.add(image)) {
          throw const BackendException('DUPLICATE_PROOF', 'no');
        }
        final order = _order(body['order'] as String);
        order
          ..['status'] = 'claimed'
          ..['senderName'] = sender
          ..['proofSubmitted'] = true;
        return {'order': order};
      case 'cancel':
        _order(body['order'] as String)['status'] = 'cancelled';
        return {'order': _order(body['order'] as String)};
      case 'admin_whoami':
        return {'admin': admin};
      case 'admin_list':
        if (!admin) throw const BackendException('NOT_ADMIN', 'no');
        return {
          'orders': [
            for (final o in orders)
              if (body['status'] != 'pending' || o['status'] == 'claimed')
                {...o, 'proofUrl': null, 'displayName': 'Player One'},
          ],
        };
      case 'admin_approve':
        if (!admin) throw const BackendException('NOT_ADMIN', 'no');
        final order = _order(body['order'] as String);
        order['status'] = 'paid';
        balance += order['coins'] as int;
        return {'order': order};
      case 'admin_reject':
        if (!admin) throw const BackendException('NOT_ADMIN', 'no');
        final order = _order(body['order'] as String);
        order
          ..['status'] = 'rejected'
          ..['playerNote'] = body['reason'];
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

  String? redirectTo;

  /// What the server says once the emailed link was opened elsewhere.
  bool linkOpened = false;
  final authChanges = StreamController<AccountStatus>.broadcast();

  @override
  Future<void> requestRecovery(String email, {String? redirectTo}) async {
    codeSentTo = email;
    this.redirectTo = redirectTo;
  }

  @override
  Future<AccountStatus> confirmRecovery(String email, String code) =>
      confirmLink(email, code);

  @override
  Future<AccountStatus> confirmLinkByLink(String email) async {
    if (!linkOpened) throw const AccountFailure('LINK_PENDING');
    linked = true;
    return status();
  }

  @override
  Future<AccountStatus> confirmRecoveryByLink(String email) async {
    if (!linkOpened) throw const AccountFailure('LINK_ELSEWHERE');
    linked = true;
    return status();
  }

  @override
  Stream<AccountStatus> changes() => authChanges.stream;
}

Uint8List jpegOf(int width, int height, [int shade = 0]) => Uint8List.fromList(
  img.encodeJpg(
    img.Image(width: width, height: height)
      ..clear(img.ColorRgb8(shade, shade, shade)),
  ),
);

void main() {
  late CoinServer server;
  late FakeAccounts accounts;
  late List<String> opened;
  late bool openWorks;
  late Uint8List? picked;
  late Uint8List? lost;

  setUp(() {
    server = CoinServer();
    accounts = FakeAccounts();
    opened = [];
    openWorks = true;
    picked = jpegOf(8, 8);
    lost = null;
  });

  const android = PaymentCapabilities(transfer: true, platform: 'android');
  const web = PaymentCapabilities(transfer: true, platform: 'web');

  Widget app(Widget child, {PaymentCapabilities caps = android}) =>
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => server),
          accountServiceProvider.overrideWithValue(accounts),
          paymentCapabilitiesProvider.overrideWithValue(caps),
          proofPickerProvider.overrideWithValue(() async => picked),
          lostProofProvider.overrideWithValue(() async => lost),
          externalLinkOpenerProvider.overrideWithValue((url) {
            opened.add(url);
            return openWorks;
          }),
        ],
        child: localizedApp(child),
      );

  Future<void> pumpPacks(
    WidgetTester tester, {
    PaymentCapabilities caps = android,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(const Scaffold(body: CoinPacksTab()), caps: caps),
    );
    await tester.pumpAndSettle();
  }

  Iterable<FakeCall> coinCalls(String action) => server.calls.where(
    (c) => c.function == 'coin_orders' && c.body['action'] == action,
  );

  Map<String, dynamic> order(String id, String status, {String? note}) => {
    'id': id,
    'reference': 'MM-$id',
    'pack': 'coins_500',
    'coins': 500,
    'amountPiastres': 4999,
    'method': 'instapay',
    'status': status,
    'playerNote': ?note,
  };

  group('capabilities', () {
    test('Android and web can show transfers; other platforms cannot', () {
      final a = paymentCapabilitiesFor(
        web: false,
        target: TargetPlatform.android,
      );
      expect((a.transfer, a.platform), (true, 'android'));
      final w = paymentCapabilitiesFor(web: true, target: TargetPlatform.iOS);
      expect((w.transfer, w.platform), (true, 'web'));
      final i = paymentCapabilitiesFor(web: false, target: TargetPlatform.iOS);
      expect(i.transfer, isFalse);
    });

    test('no payment destination or transfer URL ships in the app', () {
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
        for (final banned in [
          'ipn.eg',
          'vf.eg',
          'vfcash',
          'instapay/',
          'api.telegram.org',
        ]) {
          expect(
            text.contains(banned),
            isFalse,
            reason: '${file.path} contains $banned',
          );
        }
      }
    });

    test('the proof is re-encoded as a JPEG of at most 1600px', () {
      final out = compressProof(
        Uint8List.fromList(img.encodePng(img.Image(width: 3200, height: 900))),
      )!;
      expect(out.sublist(0, 3), [0xff, 0xd8, 0xff]);
      final back = img.decodeJpg(out)!;
      expect((back.width, back.height), (1600, 450));
      final tall = img.decodeJpg(compressProof(jpegOf(500, 2400))!)!;
      expect((tall.width, tall.height), (333, 1600));
      expect(compressProof(Uint8List.fromList(utf8.encode('not an image'))), isNull);
    });
  });

  group('Android: kill switch', () {
    testWidgets('switch off: no transfer tab and no transfer buttons', (
      tester,
    ) async {
      server.enabled = false;
      await tester.pumpWidget(app(const CoinStore()));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.pay2TabTransfer), findsNothing);
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: TransferMethodButtons(playProduct: 'mm_coins_500'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(TransferMethodButtons.button('mm_coins_500', 'instapay')),
        findsNothing,
      );
    });

    testWidgets('switch on: the tab and «إنستا باي» under the Play item', (
      tester,
    ) async {
      await tester.pumpWidget(app(const CoinStore()));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.pay2TabTransfer), findsOneWidget);
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: TransferMethodButtons(playProduct: 'mm_coins_500'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(
        TransferMethodButtons.button('mm_coins_500', 'instapay'),
      );
      expect(button, findsOneWidget);
      expect(find.text(arStrings.coinPayInstapay), findsOneWidget);
      // An unconfigured method is not offered at all.
      expect(
        find.byKey(TransferMethodButtons.button('mm_coins_500', 'vodafone_cash')),
        findsNothing,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(opened, [instapayUrl], reason: 'opened once the order exists');
      expect(coinCalls('create').single.body, {
        'action': 'create',
        'pack': 'coins_500',
        'method': 'instapay',
        'platform': 'android',
      });
      // The order's steps open over the Play tab.
      expect(find.byType(ProofOrderCard), findsOneWidget);
    });

    testWidgets('an owned Quiet Pass is not offered by transfer', (
      tester,
    ) async {
      server.adFree = true;
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: TransferMethodButtons(playProduct: 'mm_remove_interruptions'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('transfer flow', () {
    Future<void> startOrder(WidgetTester tester) async {
      await tester.tap(find.byKey(CoinPacksTab.pack('coins_500')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CoinPacksTab.method('instapay')));
      await tester.pumpAndSettle();
    }

    FilledButton submit(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(ProofOrderCard.submitButton));

    testWidgets('choose → pay in the other app → upload proof; coins only after review', (
      tester,
    ) async {
      await pumpPacks(tester);
      expect(find.text(arStrings.coinManualNotice), findsOneWidget);
      await startOrder(tester);
      expect(opened, [instapayUrl]);
      expect(find.text(arStrings.coinOrderTitle('MM-ABCD0001')), findsOneWidget);
      expect(find.text(arStrings.pay2StepPay('49.99', arStrings.coinPayInstapay)), findsOneWidget);

      // Coming back: the page can be opened again from the order.
      await tester.tap(find.byKey(CoinPacksTab.openButton));
      expect(opened, [instapayUrl, instapayUrl]);

      await tester.tap(find.byKey(ProofOrderCard.pickButton));
      await tester.pumpAndSettle();
      expect(find.byKey(ProofOrderCard.imageReady), findsOneWidget);
      await tester.enterText(find.byKey(ProofOrderCard.senderField), 'Eyad S');
      await tester.pump();
      await tester.tap(find.byKey(ProofOrderCard.submitButton));
      await tester.pumpAndSettle();

      final sent = coinCalls('submit').single.body;
      expect(sent['senderName'], 'Eyad S');
      expect(base64Decode(sent['image'] as String), picked);
      expect(sent['platform'], 'android');
      expect(sent.keys.toSet(), {
        'action',
        'order',
        'senderName',
        'image',
        'platform',
      }, reason: 'no price, amount or coins from the client');
      expect(find.text(arStrings.pay2StatusPending), findsWidgets);
      expect(server.balance, 0, reason: 'a proof is not a payment');
    });

    testWidgets('the screenshot and the sender name are both required', (
      tester,
    ) async {
      await pumpPacks(tester);
      await startOrder(tester);
      expect(submit(tester).onPressed, isNull);
      // A name alone is not enough.
      await tester.enterText(find.byKey(ProofOrderCard.senderField), 'Eyad S');
      await tester.pump();
      expect(submit(tester).onPressed, isNull);
      // Backing out of the picker leaves nothing chosen.
      picked = null;
      await tester.tap(find.byKey(ProofOrderCard.pickButton));
      await tester.pumpAndSettle();
      expect(submit(tester).onPressed, isNull);
      // An image without a name is not enough either.
      picked = jpegOf(8, 8, 9);
      await tester.tap(find.byKey(ProofOrderCard.pickButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ProofOrderCard.senderField), ' ');
      await tester.pump();
      expect(submit(tester).onPressed, isNull);
      await tester.enterText(find.byKey(ProofOrderCard.senderField), 'Eyad S');
      await tester.pump();
      expect(submit(tester).onPressed, isNotNull);
      expect(coinCalls('submit'), isEmpty);
    });

    testWidgets('a refused order opens no payment page and says why', (
      tester,
    ) async {
      server.createRefusal = const BackendException('SALES_DISABLED', 'off');
      await pumpPacks(tester);
      await startOrder(tester);
      expect(coinCalls('create'), hasLength(1));
      expect(opened, isEmpty, reason: 'nobody pays for a refused order');
      expect(find.text(arStrings.coinPacksUnavailable), findsOneWidget);
      expect(find.byType(ProofOrderCard), findsNothing);

      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .clearSnackBars();
      await tester.pumpAndSettle();
      server.createRefusal = const BackendException('TOO_MANY_PENDING', 'no');
      await tester.tap(find.byKey(CoinPacksTab.method('instapay')));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
      expect(find.text(arStrings.pay2TooMany), findsOneWidget);
    });

    testWidgets('the sender name follows the server pattern', (tester) async {
      expect(validSenderName('  إياد   عبد الرحمن '), isTrue);
      expect(validSenderName('01012345678'), isTrue);
      expect(validSenderName("O'Brien-Smith (VF)"), isTrue);
      expect(validSenderName('E'), isFalse);
      expect(validSenderName('<b>x</b>'), isFalse);
      expect(validSenderName('a' * 81), isFalse);
      expect(validSenderName('a' * 80), isTrue);
      expect(normalizeSenderName('  Eyad \n  S '), 'Eyad S');

      await pumpPacks(tester);
      await startOrder(tester);
      await tester.tap(find.byKey(ProofOrderCard.pickButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ProofOrderCard.senderField), 'Eyad <S>');
      await tester.pump();
      expect(submit(tester).onPressed, isNull, reason: 'the server would refuse it');

      // Should the server still refuse the name, the player reads the proof
      // message, not a generic failure.
      await tester.enterText(find.byKey(ProofOrderCard.senderField), 'Eyad S');
      await tester.pump();
      server.submitRefusal = const BackendException(
        'SENDER_REQUIRED',
        'sender name required',
      );
      await tester.tap(find.byKey(ProofOrderCard.submitButton));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.pay2ProofRequired), findsWidgets);
      expect(find.text(arStrings.coinOrderFailed), findsNothing);
      server.submitRefusal = const BackendException(
        'BAD_REQUEST',
        'sender name required',
      );
      await tester.tap(find.byKey(ProofOrderCard.submitButton));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.coinOrderFailed), findsNothing);
    });

    testWidgets('a photo picked before Android killed the app comes back', (
      tester,
    ) async {
      server.orders.add(order('a', 'awaiting_transfer'));
      lost = jpegOf(8, 8, 5);
      await pumpPacks(tester);
      expect(find.byKey(ProofOrderCard.imageReady), findsOneWidget);
      await tester.enterText(find.byKey(ProofOrderCard.senderField), 'Eyad S');
      await tester.pump();
      await tester.tap(find.byKey(ProofOrderCard.submitButton));
      await tester.pumpAndSettle();
      expect(base64Decode(coinCalls('submit').single.body['image'] as String), lost);
    });

    testWidgets('a reused screenshot is refused in words', (tester) async {
      server.hashes.add(base64Encode(picked!));
      await pumpPacks(tester);
      await startOrder(tester);
      await tester.tap(find.byKey(ProofOrderCard.pickButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ProofOrderCard.senderField), 'Eyad S');
      await tester.pump();
      await tester.tap(find.byKey(ProofOrderCard.submitButton));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.pay2Duplicate), findsOneWidget);
    });

    testWidgets('two pending orders: no third, said plainly', (tester) async {
      server.orders.addAll([order('a', 'claimed'), order('b', 'claimed')]);
      await pumpPacks(tester);
      expect(find.byKey(CoinPacksTab.fullNote), findsOneWidget);
      expect(find.byKey(CoinPacksTab.method('instapay')), findsNothing);
    });

    testWidgets('order status list: pending, approved, rejected with reason, expired', (
      tester,
    ) async {
      server.orders.addAll([
        order('p', 'claimed'),
        order('ok', 'paid'),
        order('no', 'rejected', note: 'المبلغ ما وصلش'),
        order('old', 'expired'),
      ]);
      await pumpPacks(tester);
      String status(String id) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(CoinPacksTab.status(id)),
              matching: find.byType(Text),
            ).last,
          )
          .data!;
      expect(status('p'), arStrings.pay2StatusPending);
      expect(status('ok'), arStrings.coinStatusPaid(500));
      expect(status('no'), arStrings.coinStatusRejected('المبلغ ما وصلش'));
      expect(status('old'), arStrings.pay2StatusExpired);
    });

    testWidgets('an approval refreshes the wallet when the app resumes', (
      tester,
    ) async {
      server.orders.add(order('p', 'claimed'));
      await pumpPacks(tester);
      final before = server.calls.where((c) => c.function == 'economy').length;
      server
        ..orders.first['status'] = 'paid'
        ..balance = 500;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        server.calls.where((c) => c.function == 'economy').length,
        greaterThan(before),
      );
      expect(find.text(arStrings.coinStatusPaid(500)), findsOneWidget);
    });

    testWidgets('the web build uses its own switch', (tester) async {
      await pumpPacks(tester, caps: web);
      expect(coinCalls('shop').first.body['platform'], 'web');
    });

    testWidgets('an unprotected account must link an email first', (
      tester,
    ) async {
      server.recoverable = false;
      await pumpPacks(tester);
      expect(find.text(arStrings.coinPacksNeedAccount), findsOneWidget);
      expect(find.byType(AccountProtectionCard), findsOneWidget);
      expect(find.byKey(CoinPacksTab.method('instapay')), findsNothing);
    });

    testWidgets('a blocked pop-up is reported, not assumed opened', (
      tester,
    ) async {
      openWorks = false;
      server.orders.add(order('a', 'awaiting_transfer'));
      await pumpPacks(tester);
      await tester.tap(find.byKey(CoinPacksTab.openButton));
      await tester.pump();
      expect(find.text(arStrings.coinOpenFailed), findsOneWidget);
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
        'p@example.test',
      );
      await tester.tap(find.byKey(AccountProtectionCard.sendButton));
      await tester.pumpAndSettle();
      expect(accounts.codeSentTo, 'p@example.test');
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

    Future<void> sendFor(WidgetTester tester, Key mode) async {
      await tester.pumpWidget(
        app(
          const Scaffold(
            body: SingleChildScrollView(child: AccountProtectionCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(mode));
      await tester.pump();
      await tester.enterText(
        find.byKey(AccountProtectionCard.emailField),
        'p@example.test',
      );
      await tester.tap(find.byKey(AccountProtectionCard.sendButton));
      await tester.pumpAndSettle();
    }

    testWidgets('after sending: says code or link, keeps the code field', (
      tester,
    ) async {
      await sendFor(tester, AccountProtectionCard.linkButton);
      expect(
        find.text(arStrings.accountCodeSent('p@example.test')),
        findsOneWidget,
      );
      expect(find.byKey(AccountProtectionCard.codeField), findsOneWidget);
      expect(find.text(arStrings.accountLinkOpened), findsOneWidget);
      expect(find.byKey(AccountProtectionCard.recoverLinkNote), findsNothing);
    });

    testWidgets('link: «I opened the email link» before opening it waits', (
      tester,
    ) async {
      await sendFor(tester, AccountProtectionCard.linkButton);
      await tester.tap(find.byKey(AccountProtectionCard.linkOpenedButton));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.accountErrorLinkPending), findsOneWidget);
      expect(find.byKey(AccountProtectionCard.codeField), findsOneWidget);
      expect(accounts.linked, isFalse);
    });

    testWidgets('link: the link opened elsewhere protects this account', (
      tester,
    ) async {
      await sendFor(tester, AccountProtectionCard.linkButton);
      accounts.linkOpened = true;
      await tester.tap(find.byKey(AccountProtectionCard.linkOpenedButton));
      await tester.pumpAndSettle();
      expect(
        find.text(arStrings.accountProtected('p@example.test')),
        findsOneWidget,
      );
    });

    testWidgets('recovery: says plainly the link cannot sign this app in', (
      tester,
    ) async {
      await sendFor(tester, AccountProtectionCard.recoverButton);
      expect(accounts.redirectTo, isNull);
      expect(find.byKey(AccountProtectionCard.recoverLinkNote), findsOneWidget);
      await tester.tap(find.byKey(AccountProtectionCard.linkOpenedButton));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.accountErrorLinkElsewhere), findsOneWidget);
      // The code path stays open.
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

  group('admin page', () {
    Future<void> pumpAdmin(WidgetTester tester, {bool isWeb = true}) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(PaymentsAdminScreen(web: isWeb), caps: web),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('outside the web build: a guard, and no server call', (
      tester,
    ) async {
      accounts.linked = true;
      server.admin = true;
      await pumpAdmin(tester, isWeb: false);
      expect(find.text(arStrings.adminWebOnly), findsOneWidget);
      expect(coinCalls('admin_whoami'), isEmpty);
      expect(coinCalls('admin_list'), isEmpty);
    });

    testWidgets('not signed in: the email code sign-in, nothing else', (
      tester,
    ) async {
      server.orders.add(order('o1', 'claimed'));
      await pumpAdmin(tester);
      expect(find.text(arStrings.adminSignInHint), findsOneWidget);
      expect(find.byType(AccountProtectionCard), findsOneWidget);
      expect(coinCalls('admin_list'), isEmpty);
      expect(find.byKey(PaymentsAdminScreen.approve('o1')), findsNothing);
    });

    testWidgets('a session from the emailed link skips the code step', (
      tester,
    ) async {
      server.admin = true;
      server.orders.add(order('o1', 'claimed'));
      await pumpAdmin(tester);
      expect(find.byType(AccountProtectionCard), findsOneWidget);
      expect(find.byKey(PaymentsAdminScreen.signedInAs), findsNothing);

      // The web client reads the session from the link's URL.
      accounts.linked = true;
      accounts.authChanges.add(
        const AccountStatus(recoverable: true, email: 'p@example.test'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(arStrings.adminSignedInAs('p@example.test')),
        findsOneWidget,
      );
      expect(find.byType(AccountProtectionCard), findsNothing);
      expect(find.byKey(AccountProtectionCard.codeField), findsNothing);
      expect(coinCalls('admin_whoami'), isNotEmpty);
      expect(find.byKey(PaymentsAdminScreen.order('o1')), findsOneWidget);
    });

    testWidgets('already signed in on arrival: shows who, no code step', (
      tester,
    ) async {
      accounts.linked = true;
      server.admin = true;
      await pumpAdmin(tester);
      expect(
        find.text(arStrings.adminSignedInAs('p@example.test')),
        findsOneWidget,
      );
      expect(find.byType(AccountProtectionCard), findsNothing);
    });

    testWidgets('an anonymous auth event changes nothing', (tester) async {
      await pumpAdmin(tester);
      accounts.authChanges.add(AccountStatus.anonymous);
      await tester.pumpAndSettle();
      expect(find.byType(AccountProtectionCard), findsOneWidget);
      expect(coinCalls('admin_whoami'), isEmpty);
    });

    testWidgets('signed in but not an admin: refused, no orders asked', (
      tester,
    ) async {
      accounts.linked = true;
      server.orders.add(order('o1', 'claimed'));
      await pumpAdmin(tester);
      expect(find.byKey(PaymentsAdminScreen.guard), findsOneWidget);
      expect(find.text(arStrings.adminNotAdmin), findsOneWidget);
      expect(coinCalls('admin_list'), isEmpty);
      expect(find.byKey(PaymentsAdminScreen.approve('o1')), findsNothing);
    });

    testWidgets('an admin approves, and rejects only with a reason', (
      tester,
    ) async {
      accounts.linked = true;
      server
        ..admin = true
        ..orders.addAll([
          {...order('o1', 'claimed'), 'senderName': 'Eyad S', 'proofSubmitted': true},
          {...order('o2', 'claimed'), 'senderName': 'Other', 'proofSubmitted': true},
        ]);
      await pumpAdmin(tester);
      expect(coinCalls('admin_list').last.body['status'], 'pending');
      expect(find.text(arStrings.adminSender('Eyad S')), findsOneWidget);
      expect(find.text(arStrings.adminPlayer('Player One')), findsNWidgets(2));

      await tester.tap(find.byKey(PaymentsAdminScreen.approve('o1')));
      await tester.pumpAndSettle();
      expect(coinCalls('admin_approve').single.body['order'], 'o1');
      expect(server.balance, 500);

      await tester.tap(find.byKey(PaymentsAdminScreen.reject('o2')));
      await tester.pumpAndSettle();
      expect(find.text(arStrings.adminReasonRequired), findsOneWidget);
      expect(coinCalls('admin_reject'), isEmpty);
      await tester.enterText(
        find.byKey(PaymentsAdminScreen.reason('o2')),
        'المبلغ ما وصلش',
      );
      await tester.tap(find.byKey(PaymentsAdminScreen.reject('o2')));
      await tester.pumpAndSettle();
      expect(coinCalls('admin_reject').single.body['reason'], 'المبلغ ما وصلش');
    });
  });
}
