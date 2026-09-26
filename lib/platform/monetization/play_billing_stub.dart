import 'play_billing.dart';
import 'purchase_store.dart';

PlayBilling createPlayBilling() => const _NoPlayBilling();

/// The web and any build without Play: no purchase path at all.
class _NoPlayBilling implements PlayBilling {
  const _NoPlayBilling();
  @override
  bool get supported => false;
  @override
  Stream<StorePurchaseEvent> get events => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<bool> available() async => false;
  @override
  Future<Map<String, PlayListing>> listings(Set<String> ids) async => const {};
  @override
  Future<bool> buy(
    String productId, {
    required bool consumable,
    required String accountTag,
  }) async => false;
  @override
  Future<void> restore() async {}
  @override
  Future<void> finishEntitlement(String token) async {}
  @override
  void dispose() {}
}
