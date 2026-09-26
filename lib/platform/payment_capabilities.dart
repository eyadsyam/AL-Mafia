import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What this build may offer for real money (Payments v2, owner's decision).
///
/// The Android app offers Google Play Billing AND manual InstaPay / Vodafone
/// Cash transfers; the web offers the transfers. Whether transfers are on is
/// the server's call per platform (economy_config.transfer_enabled_android /
/// transfer_enabled_web, default off) — this only says which switch to ask.
/// The payment destinations are not in this binary: the server hands them
/// out, and a tap opens exactly that link in the payment app or browser.
class PaymentCapabilities {
  /// This build can show manual transfers (if the server has them on).
  final bool transfer;

  /// `android` or `web`: the kill switch this build asks the server about.
  final String? platform;

  const PaymentCapabilities({required this.transfer, this.platform = 'web'});

  static const none = PaymentCapabilities(transfer: false, platform: null);
}

PaymentCapabilities paymentCapabilitiesFor({
  required bool web,
  required TargetPlatform target,
}) {
  if (web) return const PaymentCapabilities(transfer: true, platform: 'web');
  if (target == TargetPlatform.android) {
    return const PaymentCapabilities(transfer: true, platform: 'android');
  }
  return PaymentCapabilities.none;
}

final paymentCapabilitiesProvider = Provider<PaymentCapabilities>(
  (ref) =>
      paymentCapabilitiesFor(web: kIsWeb, target: defaultTargetPlatform),
);
