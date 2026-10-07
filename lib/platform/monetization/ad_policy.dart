import '../../core/theme/design_tokens.dart';
import 'ad_placement_registry.dart';

enum AdEntitlementV4 { unknown, free, adFree }

enum AdVerdictV4 {
  show,
  disabled,
  unsupported,
  background,
  busy,
  entitlementUnknown,
  adFree,
  grace,
  consent,
  surface,
  optIn,
  cap,
  gap,
  mutex,
  notReady,
  expired,
}

class AdContextV4 {
  final bool android,
      foreground,
      busy,
      consent,
      contentReady,
      onboarded,
      optIn,
      eligibleClaim,
      explicitHomeExit;
  final AdEntitlementV4 entitlement;
  final String surface;
  final int launches, completedMatches, routeGeneration;
  final int? loadedAtMs, backgroundedAtMs, returnedFromAdOrPaymentAtMs;
  const AdContextV4({
    required this.surface,
    required this.android,
    required this.foreground,
    required this.busy,
    required this.consent,
    required this.contentReady,
    required this.onboarded,
    required this.entitlement,
    required this.launches,
    required this.completedMatches,
    required this.routeGeneration,
    this.loadedAtMs,
    this.backgroundedAtMs,
    this.returnedFromAdOrPaymentAtMs,
    this.optIn = false,
    this.eligibleClaim = false,
    this.explicitHomeExit = false,
  });
}

/// Device pacing is never a server reward authorization.
class AdLedgerV4 {
  final int highWaterMs;
  final List<int> automaticShows, appOpenShows;
  final int? lastDismissMs, lastRewardMs;
  const AdLedgerV4({
    this.highWaterMs = 0,
    this.automaticShows = const [],
    this.appOpenShows = const [],
    this.lastDismissMs,
    this.lastRewardMs,
  });
  int now(int value) => value > highWaterMs ? value : highWaterMs;
  AdLedgerV4 shown(AdPlacementV4 placement, int time) {
    final t = now(time);
    List<int> retain(List<int> values) =>
        values.where((v) => v >= t - AdV4Tokens.day.inMilliseconds).toList();
    return AdLedgerV4(
      highWaterMs: t,
      automaticShows: List.unmodifiable([
        ...retain(automaticShows),
        if (placement.automatic) t,
      ]),
      appOpenShows: List.unmodifiable([
        ...retain(appOpenShows),
        if (placement.format == AdFormatV4.appOpen) t,
      ]),
      lastDismissMs: placement.fullscreen ? t : lastDismissMs,
      lastRewardMs: placement.format == AdFormatV4.rewarded ? t : lastRewardMs,
    );
  }

  AdLedgerV4 dismissed(AdPlacementV4 placement, int time) => AdLedgerV4(
    highWaterMs: now(time),
    automaticShows: automaticShows,
    appOpenShows: appOpenShows,
    lastDismissMs: placement.fullscreen ? now(time) : lastDismissMs,
    lastRewardMs: placement.format == AdFormatV4.rewarded
        ? now(time)
        : lastRewardMs,
  );
  Map<String, Object?> toJson() => {
    'highWaterMs': highWaterMs,
    'automaticShows': automaticShows,
    'appOpenShows': appOpenShows,
    'lastDismissMs': lastDismissMs,
    'lastRewardMs': lastRewardMs,
  };
  factory AdLedgerV4.fromJson(Map<String, dynamic> raw) {
    int? timestamp(String key) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! int || value < 0)
        throw const FormatException('Invalid ad ledger timestamp');
      return value;
    }

    List<int> times(String key) {
      final values = raw[key];
      if (values == null) return const [];
      if (values is! List ||
          values.length > 64 ||
          values.any((v) => v is! int || v < 0)) {
        throw const FormatException('Invalid ad ledger counters');
      }
      return List.unmodifiable(values.cast<int>());
    }

    final automatic = times('automaticShows');
    final opens = times('appOpenShows');
    final dismiss = timestamp('lastDismissMs');
    final reward = timestamp('lastRewardMs');
    final timestamps = [
      timestamp('highWaterMs') ?? 0,
      ...automatic,
      ...opens,
      if (dismiss != null) dismiss,
      if (reward != null) reward,
    ];
    return AdLedgerV4(
      highWaterMs: timestamps.reduce((a, b) => a > b ? a : b),
      automaticShows: automatic,
      appOpenShows: opens,
      lastDismissMs: dismiss,
      lastRewardMs: reward,
    );
  }
}

AdVerdictV4 decideAdV4(
  AdPlacementV4 p,
  AdRegistryV4 registry,
  AdContextV4 c,
  AdLedgerV4 ledger,
  int time, {
  bool fullscreenBusy = false,
}) {
  final now = ledger.now(time);
  if (!registry.units.containsKey(p.id) || now >= registry.expiresAtMs) {
    return AdVerdictV4.disabled;
  }
  if (!c.android) return AdVerdictV4.unsupported;
  if (!c.foreground) return AdVerdictV4.background;
  if (c.busy) return AdVerdictV4.busy;
  if (c.entitlement == AdEntitlementV4.unknown) {
    return AdVerdictV4.entitlementUnknown;
  }
  if (c.entitlement == AdEntitlementV4.adFree &&
      p.format != AdFormatV4.rewarded) {
    return AdVerdictV4.adFree;
  }
  if (!c.onboarded ||
      (p.automatic && (c.launches <= 2 || c.completedMatches <= 1))) {
    return AdVerdictV4.grace;
  }
  if (!c.consent) return AdVerdictV4.consent;
  if (c.surface != p.surface ||
      !c.contentReady ||
      (p.format == AdFormatV4.interstitial && !c.explicitHomeExit)) {
    return AdVerdictV4.surface;
  }
  if (p.format == AdFormatV4.rewarded && (!c.optIn || !c.eligibleClaim)) {
    return AdVerdictV4.optIn;
  }
  if (p.id == 'open_resume' &&
      (c.backgroundedAtMs == null ||
          now - c.backgroundedAtMs! <
              AdV4Tokens.appOpenResume.inMilliseconds)) {
    return AdVerdictV4.gap;
  }
  if (p.format == AdFormatV4.appOpen &&
      c.returnedFromAdOrPaymentAtMs != null &&
      now - c.returnedFromAdOrPaymentAtMs! <
          AdV4Tokens.appOpenResume.inMilliseconds)
    return AdVerdictV4.gap;
  if (p.format == AdFormatV4.rewarded &&
      ledger.lastRewardMs != null &&
      now - ledger.lastRewardMs! < AdV4Tokens.rewardGap.inMilliseconds)
    return AdVerdictV4.gap;
  if (p.automatic) {
    final day = now ~/ AdV4Tokens.day.inMilliseconds;
    if (ledger.automaticShows
                .where((v) => v ~/ AdV4Tokens.day.inMilliseconds == day)
                .length >=
            6 ||
        ledger.automaticShows
                .where((v) => now - v < AdV4Tokens.rollingHour.inMilliseconds)
                .length >=
            2 ||
        (p.format == AdFormatV4.appOpen &&
            ledger.appOpenShows
                    .where((v) => v ~/ AdV4Tokens.day.inMilliseconds == day)
                    .length >=
                2)) {
      return AdVerdictV4.cap;
    }
    if ((ledger.lastDismissMs != null &&
            now - ledger.lastDismissMs! <
                AdV4Tokens.automaticGap.inMilliseconds) ||
        (ledger.lastRewardMs != null &&
            now - ledger.lastRewardMs! <
                AdV4Tokens.afterReward.inMilliseconds)) {
      return AdVerdictV4.gap;
    }
  }
  if (p.fullscreen && fullscreenBusy) return AdVerdictV4.mutex;
  if (c.loadedAtMs == null) return AdVerdictV4.notReady;
  if (c.loadedAtMs! > now ||
      now - c.loadedAtMs! >=
          (p.format == AdFormatV4.appOpen
              ? AdV4Tokens.appOpenResume.inMilliseconds
              : AdV4Tokens.rollingHour.inMilliseconds)) {
    return AdVerdictV4.expired;
  }
  return AdVerdictV4.show;
}
