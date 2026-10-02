import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'purchase_store.dart';

PurchaseStore createPurchaseStore() => GooglePlayPurchaseStore();

class GooglePlayPurchaseStore implements PurchaseStore {
  static const _enabled = bool.fromEnvironment('PLAY_BILLING_ENABLED');
  static const _productId = String.fromEnvironment(
    'PLAY_SCENARIO_PRODUCT_ID',
    defaultValue: 'mafia_scenario_mastermind',
  );

  final _events = StreamController<StorePurchaseEvent>.broadcast();
  final _pending = <String, PurchaseDetails>{};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;

  @override
  bool get configured => _enabled && _productId.isNotEmpty;

  @override
  Stream<StorePurchaseEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    if (!configured || _subscription != null) return;
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => _events.add(
        StorePurchaseEvent(
          state: StorePurchaseState.failed,
          productId: _productId,
          error: error.toString(),
        ),
      ),
    );
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != _productId) continue;
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
  Future<StoreProduct?> product() async {
    if (!configured) return null;
    await initialize();
    if (!await InAppPurchase.instance.isAvailable()) return null;
    if (_product == null) {
      final response = await InAppPurchase.instance.queryProductDetails({
        _productId,
      });
      _product = response.productDetails
          .where((p) => p.id == _productId)
          .firstOrNull;
    }
    final value = _product;
    return value == null
        ? null
        : StoreProduct(id: value.id, price: value.price);
  }

  @override
  Future<bool> buy() async {
    final value = _product ?? (await product() == null ? null : _product);
    if (value == null) return false;
    return InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: value),
    );
  }

  @override
  Future<void> restore() async {
    if (!configured) return;
    await initialize();
    await InAppPurchase.instance.restorePurchases();
  }

  @override
  Future<void> complete(String token) async {
    final purchase = _pending.remove(token);
    if (purchase?.pendingCompletePurchase ?? false) {
      await InAppPurchase.instance.completePurchase(purchase!);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_events.close());
  }
}
