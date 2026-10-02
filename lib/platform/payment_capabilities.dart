import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What this distribution may offer for real money.
///
/// Per distribution, not per screen (docs/CLAUDE-UX-ECONOMY-NEXT.md, newest
/// instruction): the independent web store may offer manual-review transfer
/// links; the Google Play app offers no real-money coin purchase, no link, no
/// QR and no message pointing anywhere else. The payment destinations are not
/// in this binary at all: the server hands them to a web client that asks.
class PaymentCapabilities {
  /// Coin packs paid by InstaPay / Vodafone Cash transfer, reviewed by hand.
  final bool webTransfer;
  const PaymentCapabilities({required this.webTransfer});
}

/// Compiled in only for a web build made with `--dart-define=WEB_COIN_SALES=true`.
/// Android ignores it even if set.
const bool _webCoinSales = bool.fromEnvironment('WEB_COIN_SALES');

final paymentCapabilitiesProvider = Provider<PaymentCapabilities>(
  (ref) => const PaymentCapabilities(webTransfer: kIsWeb && _webCoinSales),
);
