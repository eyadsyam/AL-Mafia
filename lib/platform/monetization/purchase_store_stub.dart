import 'purchase_store.dart';

PurchaseStore createPurchaseStore() => _NoPurchaseStore();

class _NoPurchaseStore implements PurchaseStore {
  @override
  bool get configured => false;
  @override
  Stream<StorePurchaseEvent> get events => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<StoreProduct?> product() async => null;
  @override
  Future<bool> buy() async => false;
  @override
  Future<void> restore() async {}
  @override
  Future<void> complete(String token) async {}
  @override
  void dispose() {}
}
