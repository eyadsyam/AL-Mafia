import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'purchase_store.dart';
import 'play_billing_stub.dart' if (dart.library.io) 'play_billing_mobile.dart';

/// A product as Google Play describes it to this device: the localized price
/// string is Play's, never computed or stored by the app.
class PlayListing {
  final String id;
  final String title;
  final String price;
  const PlayListing({
    required this.id,
    required this.title,
    required this.price,
  });
}

/// The 1.0.1 Play products (Quiet Pass and Council Coins packs).
///
/// Nothing here grants anything. A purchase event carries a token to the
/// server, which verifies it with Google, credits once, and then
/// acknowledges or consumes. Consumables are bought with auto-consume off so
/// the device can never consume a pack the server has not credited.
abstract interface class PlayBilling {
  /// Built with billing and running where Play Billing exists.
  bool get supported;
  Stream<StorePurchaseEvent> get events;
  Future<void> start();
  Future<bool> available();
  Future<Map<String, PlayListing>> listings(Set<String> ids);
  Future<bool> buy(
    String productId, {
    required bool consumable,
    required String accountTag,
  });
  Future<void> restore();

  /// Lets the plugin forget a non-consumable the server has acknowledged.
  Future<void> finishEntitlement(String token);
  void dispose();
}

final playBillingProvider = Provider<PlayBilling>((ref) {
  final billing = createPlayBilling();
  ref.onDispose(billing.dispose);
  return billing;
});
