import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'play_billing.dart';
import 'purchase_store.dart';

PlayBilling createPlayBilling() => GooglePlayBilling();

class GooglePlayBilling implements PlayBilling {
  /// A kill switch for a build that must not carry purchases at all.
  static const _disabled = bool.fromEnvironment('PLAY_PRODUCTS_DISABLED');

  final _events = StreamController<StorePurchaseEvent>.broadcast();
  final _pending = <String, PurchaseDetails>{};
  final _details = <String, ProductDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  bool get supported =>
      !_disabled && defaultTargetPlatform == TargetPlatform.android;

  @override
  Stream<StorePurchaseEvent> get events => _events.stream;

  @override
  Future<void> start() async {
    if (!supported || _subscription != null) return;
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => _events.add(
        StorePurchaseEvent(
          state: StorePurchaseState.failed,
          productId: '',
          error: error.toString(),
        ),
      ),
    );
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final token = purchase is GooglePlayPurchaseDetails
          ? purchase.billingClientPurchase.purchaseToken
          : purchase.verificationData.serverVerificationData;
      if (token.isNotEmpty) _pending[token] = purchase;
      final state = switch (purchase.status) {
        PurchaseStatus.purchased => StorePurchaseState.purchased,
        PurchaseStatus.restored => StorePurchaseState.restored,
        PurchaseStatus.pending => StorePurchaseState.pending,
        PurchaseStatus.canceled => StorePurchaseState.canceled,
        PurchaseStatus.error => StorePurchaseState.failed,
      };
      _events.add(
        StorePurchaseEvent(
          state: state,
          productId: purchase.productID,
          token: token.isEmpty ? null : token,
          error: purchase.error?.message,
        ),
      );
    }
  }

  @override
  Future<bool> available() async {
    if (!supported) return false;
    try {
      return await InAppPurchase.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, PlayListing>> listings(Set<String> ids) async {
    if (!supported || ids.isEmpty || !await available()) return const {};
    try {
      final response = await InAppPurchase.instance.queryProductDetails(ids);
      for (final product in response.productDetails) {
        _details[product.id] = product;
      }
    } catch (_) {
      return const {};
    }
    return {
      for (final id in ids)
        if (_details[id] case final product?)
          id: PlayListing(id: id, title: product.title, price: product.price),
    };
  }

  @override
  Future<bool> buy(
    String productId, {
    required bool consumable,
    required String accountTag,
  }) async {
    final product = _details[productId];
    if (!supported || product == null) return false;
    // applicationUserName becomes obfuscatedAccountId: the server refuses a
    // token presented by any other account.
    final param = PurchaseParam(
      productDetails: product,
      applicationUserName: accountTag,
    );
    try {
      return consumable
          ? await InAppPurchase.instance.buyConsumable(
              purchaseParam: param,
              // The server consumes, after it has credited the coins.
              autoConsume: false,
            )
          : await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> restore() async {
    if (!supported) return;
    await start();
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }

  @override
  Future<void> finishEntitlement(String token) async {
    final purchase = _pending.remove(token);
    if (purchase != null && purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_events.close());
  }
}
