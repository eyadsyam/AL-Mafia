import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Android distribution is explicit; unknown build values default to Play.
enum AndroidDistribution { play, direct }

AndroidDistribution androidDistributionFor(String value) =>
    value == 'direct' ? AndroidDistribution.direct : AndroidDistribution.play;

/// What this build may offer for real money.
///
/// Play builds use Google Play Billing. Direct Android builds can offer
/// manual transfers only after explicit build approval AND server approval.
/// Web transfers still use their existing server switch. A client flag never
/// enables the server's payment methods or bypasses its approval gate.
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
  AndroidDistribution distribution = AndroidDistribution.play,
  bool androidTransfersApproved = false,
}) {
  if (web) return const PaymentCapabilities(transfer: true, platform: 'web');
  if (target == TargetPlatform.android) {
    return PaymentCapabilities(
      transfer:
          distribution == AndroidDistribution.direct &&
          androidTransfersApproved,
      platform: 'android',
    );
  }
  return PaymentCapabilities.none;
}

final paymentCapabilitiesProvider = Provider<PaymentCapabilities>(
  (ref) => paymentCapabilitiesFor(
    web: kIsWeb,
    target: defaultTargetPlatform,
    distribution: androidDistributionFor(
      const String.fromEnvironment(
        'ANDROID_DISTRIBUTION_CHANNEL',
        defaultValue: 'play',
      ),
    ),
    androidTransfersApproved: const bool.fromEnvironment(
      'ANDROID_MANUAL_TRANSFERS_APPROVED',
    ),
  ),
);
