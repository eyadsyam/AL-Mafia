/// When the one automatic ad may appear. Pure: no clock, no storage, no SDK.
///
/// Placement (Play policy on unexpected ads): only after the player chose to
/// leave the result of a *completed* match for the menu. Never before or
/// during a match, on resume, on an invite, on back, after a kick or a lost
/// connection, or right after a rewarded ad. Preloaded-or-skip.
library;

import '../../ui/theme/design_tokens.dart';

class InterstitialRules {
  final bool enabled;
  final int maxPerDay;
  final Duration gap;
  final Duration afterReward;

  /// Completed matches per install that never end in an automatic ad.
  final int graceMatches;

  const InterstitialRules({
    required this.enabled,
    required this.maxPerDay,
    required this.gap,
    required this.afterReward,
    required this.graceMatches,
  });

  static const off = InterstitialRules(
    enabled: false,
    maxPerDay: 0,
    gap: MafiaTiming.interstitialMinGap,
    afterReward: MafiaTiming.interstitialAfterReward,
    graceMatches: 1,
  );

  static final _minGap = MafiaTiming.interstitialMinGap.inSeconds;
  static final _minAfter = MafiaTiming.interstitialAfterReward.inSeconds;
  static final _day = const Duration(days: 1).inSeconds;

  /// The server's numbers, clamped to the product rules whatever it says.
  factory InterstitialRules.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    return InterstitialRules(
      enabled: json['enabled'] == true,
      maxPerDay: read('maxPerDay', 0).clamp(0, 3),
      gap: Duration(seconds: read('gapSeconds', _minGap).clamp(_minGap, _day)),
      afterReward: Duration(
        seconds: read('afterRewardSeconds', _minAfter).clamp(_minAfter, _day),
      ),
      graceMatches: read('graceMatches', 1).clamp(1, 100),
    );
  }
}

/// How the player left the result screen.
enum ResultExit { homeAfterCompleted, rematch, back, kicked, disconnected }

/// The durable counters, persisted on the device.
class InterstitialLedger {
  final int completedMatches;
  final String? lastCountedRoom;
  final int? lastShownMs;
  final int? lastRewardMs;
  final String? day;
  final int shownToday;

  /// The latest wall-clock time this ledger has seen. A clock moved
  /// backwards is read as "no time has passed", never as a fresh day.
  final int highWaterMs;

  const InterstitialLedger({
    this.completedMatches = 0,
    this.lastCountedRoom,
    this.lastShownMs,
    this.lastRewardMs,
    this.day,
    this.shownToday = 0,
    this.highWaterMs = 0,
  });

  static const empty = InterstitialLedger();

  static String dayOf(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(
        ms,
        isUtc: true,
      ).toIso8601String().substring(0, 10);

  int effectiveNow(int nowMs) => nowMs > highWaterMs ? nowMs : highWaterMs;

  InterstitialLedger _at(int nowMs) {
    final now = effectiveNow(nowMs);
    final today = dayOf(now);
    return InterstitialLedger(
      completedMatches: completedMatches,
      lastCountedRoom: lastCountedRoom,
      lastShownMs: lastShownMs,
      lastRewardMs: lastRewardMs,
      day: today,
      shownToday: today == day ? shownToday : 0,
      highWaterMs: now,
    );
  }

  /// Counts a completed match once per room.
  InterstitialLedger matchCompleted(String roomId, int nowMs) {
    final base = _at(nowMs);
    if (roomId == lastCountedRoom) return base;
    return base._copy(
      completedMatches: completedMatches + 1,
      lastCountedRoom: roomId,
    );
  }

  InterstitialLedger rewarded(int nowMs) {
    final base = _at(nowMs);
    return base._copy(lastRewardMs: base.highWaterMs);
  }

  InterstitialLedger shown(int nowMs) {
    final base = _at(nowMs);
    return base._copy(
      lastShownMs: base.highWaterMs,
      shownToday: base.shownToday + 1,
    );
  }

  InterstitialLedger _copy({
    int? completedMatches,
    String? lastCountedRoom,
    int? lastShownMs,
    int? lastRewardMs,
    int? shownToday,
  }) => InterstitialLedger(
    completedMatches: completedMatches ?? this.completedMatches,
    lastCountedRoom: lastCountedRoom ?? this.lastCountedRoom,
    lastShownMs: lastShownMs ?? this.lastShownMs,
    lastRewardMs: lastRewardMs ?? this.lastRewardMs,
    day: day,
    shownToday: shownToday ?? this.shownToday,
    highWaterMs: highWaterMs,
  );

  Map<String, Object?> toJson() => {
    'completedMatches': completedMatches,
    'lastCountedRoom': lastCountedRoom,
    'lastShownMs': lastShownMs,
    'lastRewardMs': lastRewardMs,
    'day': day,
    'shownToday': shownToday,
    'highWaterMs': highWaterMs,
  };

  factory InterstitialLedger.fromJson(Map<String, dynamic> json) {
    int? read(String key) => (json[key] as num?)?.toInt();
    return InterstitialLedger(
      completedMatches: read('completedMatches') ?? 0,
      lastCountedRoom: json['lastCountedRoom'] as String?,
      lastShownMs: read('lastShownMs'),
      lastRewardMs: read('lastRewardMs'),
      day: json['day'] as String?,
      shownToday: read('shownToday') ?? 0,
      highWaterMs: read('highWaterMs') ?? 0,
    );
  }
}

enum InterstitialVerdict {
  show,
  off,
  adFree,
  notThisExit,
  grace,
  dailyCap,
  tooSoon,
  afterReward,
  notLoaded,
}

InterstitialVerdict decideInterstitial({
  required InterstitialRules rules,
  required InterstitialLedger ledger,
  required int nowMs,
  required ResultExit exit,
  required bool adFree,
  required bool loaded,
}) {
  if (!rules.enabled || rules.maxPerDay <= 0) return InterstitialVerdict.off;
  if (adFree) return InterstitialVerdict.adFree;
  if (exit != ResultExit.homeAfterCompleted) {
    return InterstitialVerdict.notThisExit;
  }
  if (ledger.completedMatches <= rules.graceMatches) {
    return InterstitialVerdict.grace;
  }
  final now = ledger.effectiveNow(nowMs);
  final today = InterstitialLedger.dayOf(now);
  final shownToday = today == ledger.day ? ledger.shownToday : 0;
  if (shownToday >= rules.maxPerDay) return InterstitialVerdict.dailyCap;
  final lastShown = ledger.lastShownMs;
  if (lastShown != null && now - lastShown < rules.gap.inMilliseconds) {
    return InterstitialVerdict.tooSoon;
  }
  final lastReward = ledger.lastRewardMs;
  if (lastReward != null && now - lastReward < rules.afterReward.inMilliseconds) {
    return InterstitialVerdict.afterReward;
  }
  if (!loaded) return InterstitialVerdict.notLoaded;
  return InterstitialVerdict.show;
}
