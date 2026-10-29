import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:mafia_master/platform/monetization/play_billing_mobile.dart';
import 'package:mafia_master/platform/monetization/purchase_store.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The Play Billing adapter, driven through a fake purchase platform — no
/// money, no Play. It grants nothing itself: it hands each purchase's token
/// to the server, buys coin packs without consuming them (the server consumes
/// after crediting), tags every purchase with the account, and finishes an
/// entitlement only when the server says so.
class _Platform extends InAppPurchasePlatform with MockPlatformInterfaceMixin {
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  bool throwOnBuy = false;
  final bought = <({String id, String? user, bool consumable, bool auto})>[];
  final completed = <String>[];
  int restores = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => stream.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
        productDetails: [
          for (final id in ids)
            if (id != 'missing')
              ProductDetails(
                id: id,
                title: 'T $id',
                description: '',
                price: 'EGP 49.99',
                rawPrice: 49.99,
                currencyCode: 'EGP',
              ),
        ],
        notFoundIDs: ids.where((id) => id == 'missing').toList(),
      );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    if (throwOnBuy) throw StateError('billing down');
    bought.add((
      id: purchaseParam.productDetails.id,
      user: purchaseParam.applicationUserName,
      consumable: false,
      auto: false,
    ));
    return true;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = true,
  }) async {
    if (throwOnBuy) throw StateError('billing down');
    bought.add((
      id: purchaseParam.productDetails.id,
      user: purchaseParam.applicationUserName,
      consumable: true,
      auto: autoConsume,
    ));
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase.verificationData.serverVerificationData);

  @override
  Future<void> restorePurchases({String? applicationUserName}) async =>
      restores++;
}

PurchaseDetails _purchase(
  String id,
  PurchaseStatus status, {
  String token = 'tok',
  bool pending = true,
}) =>
    PurchaseDetails(
        productID: id,
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: token,
          source: 'google_play',
        ),
        transactionDate: null,
        status: status,
      )
      ..pendingCompletePurchase = pending
      ..error = status == PurchaseStatus.error
          ? IAPError(source: 'google_play', code: 'x', message: 'declined')
          : null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Platform platform;
  late GooglePlayBilling billing;

  setUpAll(() {
    // The plugin registers (and connects) its own platform the first time it
    // is touched on Android; touch it as another platform so it never does.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = null;
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    platform = _Platform();
    InAppPurchasePlatform.instance = platform;
    billing = GooglePlayBilling();
  });

  tearDown(() {
    billing.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('supported only on Android', () {
    expect(billing.supported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(GooglePlayBilling().supported, isFalse);
    expect(GooglePlayBilling().available(), completion(isFalse));
  });

  test('listings carry Play\'s own price; unknown ids are left out', () async {
    final listed = await billing.listings({'coins_s', 'missing'});
    expect(listed.keys, ['coins_s']);
    expect(listed['coins_s']!.price, 'EGP 49.99');
    expect(await billing.listings(const {}), isEmpty);
    platform.available = false;
    expect(await billing.listings({'coins_m'}), isEmpty);
  });

  test(
    'a coin pack is bought unconsumed and tagged with the account',
    () async {
      await billing.listings({'coins_s', 'pass'});
      expect(
        await billing.buy('coins_s', consumable: true, accountTag: 'acct-1'),
        isTrue,
      );
      expect(
        await billing.buy('pass', consumable: false, accountTag: 'acct-1'),
        isTrue,
      );
      expect(platform.bought, [
        (id: 'coins_s', user: 'acct-1', consumable: true, auto: false),
        (id: 'pass', user: 'acct-1', consumable: false, auto: false),
      ]);
    },
  );

  test('an unlisted product or a billing failure buys nothing', () async {
    expect(
      await billing.buy('coins_s', consumable: true, accountTag: 'a'),
      isFalse,
      reason: 'never listed on this device',
    );
    await billing.listings({'coins_s'});
    platform.throwOnBuy = true;
    expect(
      await billing.buy('coins_s', consumable: true, accountTag: 'a'),
      isFalse,
    );
    expect(platform.bought, isEmpty);
  });

  test('every purchase status reaches the app with its token', () async {
    await billing.start();
    final events = <StorePurchaseEvent>[];
    final sub = billing.events.listen(events.add);
    platform.stream.add([
      _purchase('coins_s', PurchaseStatus.purchased, token: 't1'),
      _purchase('pass', PurchaseStatus.restored, token: 't2'),
      _purchase('coins_m', PurchaseStatus.pending, token: 't3'),
      _purchase('coins_l', PurchaseStatus.canceled, token: ''),
      _purchase('coins_l', PurchaseStatus.error, token: 't5'),
    ]);
    await pumpEventQueue();
    expect(events.map((e) => e.state), [
      StorePurchaseState.purchased,
      StorePurchaseState.restored,
      StorePurchaseState.pending,
      StorePurchaseState.canceled,
      StorePurchaseState.failed,
    ]);
    expect(events.map((e) => e.token), ['t1', 't2', 't3', null, 't5']);
    expect(events.last.error, 'declined');
    await sub.cancel();
  });

  test('a stream error is a failed purchase, not a crash', () async {
    await billing.start();
    final events = <StorePurchaseEvent>[];
    final sub = billing.events.listen(events.add);
    platform.stream.addError(StateError('lost'));
    await pumpEventQueue();
    expect(events.single.state, StorePurchaseState.failed);
    await sub.cancel();
  });

  test('an entitlement is finished once, only after the server says', () async {
    await billing.start();
    platform.stream.add([
      _purchase('pass', PurchaseStatus.purchased, token: 'p1'),
      _purchase(
        'coins_s',
        PurchaseStatus.purchased,
        token: 'p2',
        pending: false,
      ),
    ]);
    await pumpEventQueue();
    expect(platform.completed, isEmpty, reason: 'nothing finished on its own');
    await billing.finishEntitlement('p1');
    await billing.finishEntitlement('p1');
    await billing.finishEntitlement('p2');
    await billing.finishEntitlement('never-seen');
    expect(platform.completed, ['p1']);
  });

  test('start twice listens once; restore asks Play again', () async {
    await billing.start();
    await billing.start();
    expect(platform.stream.hasListener, isTrue);
    await billing.restore();
    expect(platform.restores, 1);
  });
}
