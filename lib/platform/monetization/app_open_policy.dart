/// When the app-open ad may appear. Pure: no clock, no storage, no SDK.
///
/// Placement (AdMob app-open guidance + our own rules): only while the
/// branded launch screen is up — on a cold start, or on a return after at
/// least [AppOpenRules.resumeAfter] away. Never on the very first launch,
/// before onboarding and the terms are done, into an active online room, a
/// live match or a pass-and-play game in progress, during a purchase, or
/// right after the player came back from another full-screen ad or an
/// external payment page. Preloaded-within-a-few-seconds-or-skip.
///
/// Ads v3 (phase 110): no per-format daily cap any more. The app-open ad
/// obeys the global full-screen pacing shared with the interstitials (a
/// safety cap per day and a minimum gap; see `interstitial_policy.dart`).
library;

import '../../ui/theme/design_tokens.dart';
import 'interstitial_policy.dart';

class AppOpenRules {
  final bool enabled;
  final Duration resumeAfter;

  const AppOpenRules({required this.enabled, required this.resumeAfter});

  static const off = AppOpenRules(
    enabled: false,
    resumeAfter: AdTokens.appOpenResumeAfter,
  );

  static const on = AppOpenRules(
    enabled: true,
    resumeAfter: AdTokens.appOpenResumeAfter,
  );

  static final _minResume = AdTokens.appOpenResumeAfter.inSeconds;
  static final _day = const Duration(days: 1).inSeconds;

  /// The server's numbers, clamped to the product rules whatever it says.
  factory AppOpenRules.fromJson(Object? json) {
    if (json is! Map) return off;
    int read(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    return AppOpenRules(
      enabled: json['enabled'] == true,
      resumeAfter: Duration(
        seconds: read('resumeAfterSeconds', _minResume).clamp(_minResume, _day),
      ),
    );
  }
}

enum AppOpenTrigger { coldStart, resume }

/// The durable counters, persisted on the device.
class AppOpenLedger {
  /// Cold starts seen by this install, this one included once counted.
  final int launches;
  final int? lastShownMs;
  final String? day;
  final int shownToday;

  /// When the app last went to the background.
  final int? backgroundedMs;

  /// When the player last left for another full-screen ad, a purchase sheet
  /// or an external payment page.
  final int? awayMs;

  /// The server's last answer, so a launch never waits on the network to
  /// learn the feature is off.
  final bool knownEnabled;
  final bool knownAdFree;

  /// The latest wall-clock time seen: a clock moved backwards is read as "no
  /// time has passed", never as a fresh day.
  final int highWaterMs;

  const AppOpenLedger({
    this.launches = 0,
    this.lastShownMs,
    this.day,
    this.shownToday = 0,
    this.backgroundedMs,
    this.awayMs,
    this.knownEnabled = false,
    this.knownAdFree = false,
    this.highWaterMs = 0,
  });

  static const empty = AppOpenLedger();

  static String dayOf(int ms) => DateTime.fromMillisecondsSinceEpoch(
    ms,
    isUtc: true,
  ).toIso8601String().substring(0, 10);

  int effectiveNow(int nowMs) => nowMs > highWaterMs ? nowMs : highWaterMs;

  AppOpenLedger _copy({
    int? launches,
    int? lastShownMs,
    String? day,
    int? shownToday,
    int? backgroundedMs,
    int? awayMs,
    bool? knownEnabled,
    bool? knownAdFree,
    int? highWaterMs,
  }) => AppOpenLedger(
    launches: launches ?? this.launches,
    lastShownMs: lastShownMs ?? this.lastShownMs,
    day: day ?? this.day,
    shownToday: shownToday ?? this.shownToday,
    backgroundedMs: backgroundedMs ?? this.backgroundedMs,
    awayMs: awayMs ?? this.awayMs,
    knownEnabled: knownEnabled ?? this.knownEnabled,
    knownAdFree: knownAdFree ?? this.knownAdFree,
    highWaterMs: highWaterMs ?? this.highWaterMs,
  );

  AppOpenLedger _at(int nowMs) {
    final now = effectiveNow(nowMs);
    final today = dayOf(now);
    return _copy(
      day: today,
      shownToday: today == day ? shownToday : 0,
      highWaterMs: now,
    );
  }

  AppOpenLedger launched(int nowMs) => _at(nowMs)._copy(launches: launches + 1);

  AppOpenLedger shown(int nowMs) {
    final base = _at(nowMs);
    return base._copy(
      lastShownMs: base.highWaterMs,
      shownToday: base.shownToday + 1,
    );
  }

  AppOpenLedger backgrounded(int nowMs) {
    final base = _at(nowMs);
    return base._copy(backgroundedMs: base.highWaterMs);
  }

  /// [atMs] is when the player left, which may be earlier than now (it is
  /// recorded in memory and folded in on the next decision). Never later
  /// than the latest time seen.
  AppOpenLedger away(int atMs) {
    final base = _at(atMs);
    return base._copy(
      awayMs: atMs < base.highWaterMs ? atMs : base.highWaterMs,
    );
  }

  AppOpenLedger known({required bool enabled, required bool adFree}) =>
      _copy(knownEnabled: enabled, knownAdFree: adFree);

  Map<String, Object?> toJson() => {
    'launches': launches,
    'lastShownMs': lastShownMs,
    'day': day,
    'shownToday': shownToday,
    'backgroundedMs': backgroundedMs,
    'awayMs': awayMs,
    'knownEnabled': knownEnabled,
    'knownAdFree': knownAdFree,
    'highWaterMs': highWaterMs,
  };

  factory AppOpenLedger.fromJson(Map<String, dynamic> json) {
    int? read(String key) => (json[key] as num?)?.toInt();
    return AppOpenLedger(
      launches: read('launches') ?? 0,
      lastShownMs: read('lastShownMs'),
      day: json['day'] as String?,
      shownToday: read('shownToday') ?? 0,
      backgroundedMs: read('backgroundedMs'),
      awayMs: read('awayMs'),
      knownEnabled: json['knownEnabled'] == true,
      knownAdFree: json['knownAdFree'] == true,
      highWaterMs: read('highWaterMs') ?? 0,
    );
  }
}

enum AppOpenVerdict {
  show,
  off,
  adFree,
  firstLaunch,
  onboarding,
  busy,
  justReturned,
  notLongAway,
  dailyCap,
  tooSoon,
  noConsent,
  notLoaded,
  expired,
}

/// [busy]: an active online room, a live match, a pass-and-play game in
/// progress, or a purchase flow. [loadedAtMs] is null when no ad is loaded.
/// [pacing] and [fullScreen] are the global full-screen rules and ledger.
AppOpenVerdict decideAppOpen({
  required AppOpenRules rules,
  required AppOpenLedger ledger,
  InterstitialRules pacing = InterstitialRules.pacingDefaults,
  InterstitialLedger fullScreen = InterstitialLedger.empty,
  required int nowMs,
  required AppOpenTrigger trigger,
  required bool adFree,
  required bool onboarded,
  required bool busy,
  required bool canRequestAds,
  required int? loadedAtMs,
}) {
  if (!rules.enabled) return AppOpenVerdict.off;
  if (adFree) return AppOpenVerdict.adFree;
  // The launch being decided has been counted: the first is launch 1.
  if (ledger.launches <= 1) return AppOpenVerdict.firstLaunch;
  if (!onboarded) return AppOpenVerdict.onboarding;
  if (busy) return AppOpenVerdict.busy;
  final now = ledger.effectiveNow(nowMs);
  final resume = rules.resumeAfter.inMilliseconds;
  final away = ledger.awayMs;
  if (away != null && now - away < resume) return AppOpenVerdict.justReturned;
  if (trigger == AppOpenTrigger.resume) {
    final left = ledger.backgroundedMs;
    if (left == null || now - left < resume) return AppOpenVerdict.notLongAway;
  }
  final paced = fullScreenPacing(
    rules: pacing,
    ledger: fullScreen,
    nowMs: now,
  );
  if (paced == InterstitialVerdict.dailyCap) return AppOpenVerdict.dailyCap;
  if (paced == InterstitialVerdict.tooSoon) return AppOpenVerdict.tooSoon;
  if (!canRequestAds) return AppOpenVerdict.noConsent;
  if (loadedAtMs == null) return AppOpenVerdict.notLoaded;
  if (now - loadedAtMs >= AdTokens.appOpenExpiry.inMilliseconds) {
    return AppOpenVerdict.expired;
  }
  return AppOpenVerdict.show;
}
