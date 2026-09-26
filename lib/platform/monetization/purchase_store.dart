import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'purchase_store_stub.dart'
    if (dart.library.io) 'purchase_store_mobile.dart';

enum StorePurchaseState { purchased, restored, pending, canceled, failed }

class StoreProduct {
  final String id;
  final String price;
  const StoreProduct({required this.id, required this.price});
}

class StorePurchaseEvent {
  final StorePurchaseState state;
  final String productId;
  final String? token;
  final String? error;
  const StorePurchaseEvent({
    required this.state,
    required this.productId,
    this.token,
    this.error,
  });
}

abstract interface class PurchaseStore {
  bool get configured;
  Stream<StorePurchaseEvent> get events;
  Future<void> initialize();
  Future<StoreProduct?> product();
  Future<bool> buy();
  Future<void> restore();
  Future<void> complete(String token);
  void dispose();
}

final purchaseStoreProvider = Provider<PurchaseStore>((ref) {
  final store = createPurchaseStore();
  ref.onDispose(store.dispose);
  return store;
});
