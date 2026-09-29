/// When an automatic full-screen ad may appear. Pure: no clock, no storage,
/// no SDK.
///
/// Ads v3 (phase 110): ads per match, never inside a match phase.
/// * pre-match: the player tapped Create / Join / «روم جديدة للشلة», before
///   the lobby is entered — never the first match after a launch (the
///   app-open ad already had that moment);
/// * post-match: Home from the result of a *completed* match;
/// * pass-and-play: after the setup is confirmed and before the first pass
///   screen (no role exists yet), and after leaving the result;
/// * session: after [InterstitialRules.sessionAfter] of menu time without
///   any full-screen ad, only on a navigation between two menu screens.
///
/// Global for every full-screen ad (the app-open ad included): at most
/// [InterstitialRules.maxPerDay] a day and [InterstitialRules.gap] apart;
/// never [InterstitialRules.afterReward] after a rewarded ad; none around a
/// brand-new player's first match; none with the Quiet Pass; consent
/// (canRequestAds) required; preloaded-or-skip, never waited for.
library;

import '../../ui/theme/design_tokens.dart';

/// Where an automatic interstitial is being considered.
enum AdPlacement { preMatch, postMatch, passAndPlayDeal, passAndPlayResult, session }

class InterstitialRules {
  /// Post-match (the phase-103 switch).
  final bool enabled;
  final bool preMatch;
  final bool passAndPlay;
  final bool session;
  final Duration sessionAfter;

  /// Global full-screen pacing: a safety cap per day and a minimum gap.
  final int maxPerDay;
  final Duration gap;
  final Duration afterReward;

  /// Completed matches per install that never end in an automatic ad (and
  /// before which none starts).
  final int graceMatches;

  const InterstitialRules({
    required this.enabled,
    this.preMatch = false,
    this.passAndPlay = false,
    this.session = false,
    this.sessionAfter = AdTokens.sessionInterstitialAfter,
    required this.maxPerDay,
    required this.gap,
    required this.afterReward,
    required this.graceMatches,
  });

  static const off = InterstitialRules(
    enabled: false,
    maxPerDay: AdTokens.fullScreenMaxPerDay,
    gap: AdTokens.fullScreenMinGap,
    afterReward: MafiaTiming.interstitialAfterReward,
    graceMatches: 1,
  );

  /// Pacing used before the server has answered (the app-open ad on a
  /// launch that trusts its remembered answer).
  static const pacingDefaults = off;

  static final _minGap = AdTokens.fullScreenMinGap.inSeconds;
  static final _minAfter = MafiaTiming.interstitialAfterReward.inSeconds;
  static final _minSession = AdTokens.sessionInterstitialAfter.inSeconds;
  static final _day = const Duration(days: 1).inSeconds;

  /// The server's numbers, clamped to the product rules whatever it says.
  /// A missing key is off (or the safe default for a number).
  factory InterstitialRules.fromJson(Map<String, dynamic> json) {
    int read(String key, int fallback) =>
        (json[key] as num?)?.toInt() ?? fallback;
    bool flag(String key) => json[key] == true;
    // A pre-v3 server sent a 3-a-day / 10-minute pair; v3 sends the global
    // pacing under the same keys. Either way the ceiling is the safety cap.
    return InterstitialRules(
      enabled: flag('enabled'),
      preMatch: flag('preMatch'),
      passAndPlay: flag('passAndPlay'),
      session: flag('session'),
      sessionAfter: Duration(
        seconds: read('sessionAfterSeconds', _minSession).clamp(_minSession, _day),
      ),
      maxPerDay: read(
        'maxPerDay',
        AdTokens.fullScreenMaxPerDay,
      ).clamp(0, AdTokens.fullScreenMaxPerDay),
      gap: Duration(seconds: read('gapSeconds', _minGap).clamp(_minGap, _day)),
      afterReward: Duration(
        seconds: read('afterRewardSeconds', _minAfter).clamp(_minAfter, _day),
      ),
      graceMatches: read('graceMatches', 1).clamp(1, 100),
    );
  }

  bool allows(AdPlacement placement) => switch (placement) {
    AdPlacement.postMatch => enabled,
    AdPlacement.preMatch => preMatch,
    AdPlacement.passAndPlayDeal || AdPlacement.passAndPlayResult => passAndPlay,
    AdPlacement.session => session,
  };

  bool get anyPlacement => enabled || preMatch || passAndPlay || session;
}

/// How the player left the result screen.
enum ResultExit { homeAfterCompleted, rematch, back, kicked, disconnected }

/// The durable counters, persisted on the device. Shared by every
/// full-screen ad: [shown] records an app-open ad as well as interstitials.
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

  /// Counts a completed match once per room (or pass-and-play match id).
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
  busy,
  notThisExit,
  grace,
  firstAfterLaunch,
  notDue,
  dailyCap,
  tooSoon,
  afterReward,
  noConsent,
  notLoaded,
}

/// The global pacing every full-screen ad obeys, or null when it allows one
/// now: [InterstitialVerdict.dailyCap] or [InterstitialVerdict.tooSoon].
InterstitialVerdict? fullScreenPacing({
  required InterstitialRules rules,
  required InterstitialLedger ledger,
  required int nowMs,
}) {
  if (rules.maxPerDay <= 0) return InterstitialVerdict.dailyCap;
  final now = ledger.effectiveNow(nowMs);
  final today = InterstitialLedger.dayOf(now);
  final shownToday = today == ledger.day ? ledger.shownToday : 0;
  if (shownToday >= rules.maxPerDay) return InterstitialVerdict.dailyCap;
  final lastShown = ledger.lastShownMs;
  if (lastShown != null && now - lastShown < rules.gap.inMilliseconds) {
    return InterstitialVerdict.tooSoon;
  }
  return null;
}

/// [gameplay]: a match, a pass-and-play game in progress, an online room
/// (lobby countdown, voice) — never. [firstMatchOfLaunch]: no match has
/// been started since the app launched. [menuMs]: menu time banked since
/// the last full-screen ad (session placement only).
InterstitialVerdict decideInterstitial({
  required InterstitialRules rules,
  required InterstitialLedger ledger,
  required int nowMs,
  AdPlacement placement = AdPlacement.postMatch,
  ResultExit exit = ResultExit.homeAfterCompleted,
  required bool adFree,
  required bool loaded,
  bool canRequestAds = true,
  bool firstMatchOfLaunch = false,
  bool gameplay = false,
  int menuMs = 0,
}) {
  if (!rules.allows(placement) || rules.maxPerDay <= 0) {
    return InterstitialVerdict.off;
  }
  if (adFree) return InterstitialVerdict.adFree;
  if (gameplay) return InterstitialVerdict.busy;
  final after =
      placement == AdPlacement.postMatch ||
      placement == AdPlacement.passAndPlayResult;
  if (after && exit != ResultExit.homeAfterCompleted) {
    return InterstitialVerdict.notThisExit;
  }
  // A brand-new player's first match: nothing before it, nothing after it.
  if (after
      ? ledger.completedMatches <= rules.graceMatches
      : ledger.completedMatches < rules.graceMatches) {
    return InterstitialVerdict.grace;
  }
  final before =
      placement == AdPlacement.preMatch ||
      placement == AdPlacement.passAndPlayDeal;
  if (before && firstMatchOfLaunch) return InterstitialVerdict.firstAfterLaunch;
  if (placement == AdPlacement.session &&
      menuMs < rules.sessionAfter.inMilliseconds) {
    return InterstitialVerdict.notDue;
  }
  final pacing = fullScreenPacing(rules: rules, ledger: ledger, nowMs: nowMs);
  if (pacing != null) return pacing;
  final now = ledger.effectiveNow(nowMs);
  final lastReward = ledger.lastRewardMs;
  if (lastReward != null &&
      now - lastReward < rules.afterReward.inMilliseconds) {
    return InterstitialVerdict.afterReward;
  }
  if (!canRequestAds) return InterstitialVerdict.noConsent;
  if (!loaded) return InterstitialVerdict.notLoaded;
  return InterstitialVerdict.show;
}

/// What a route is, for the automatic ads.
enum AdSurface {
  /// A match (pass-and-play or online). Never an ad; the clock stops.
  gameplay,

  /// The online lobby: time counts, never an ad (countdown, voice).
  waiting,

  /// A menu between matches: time counts, a session ad may follow a
  /// navigation between two of these.
  menu,

  /// Setup, onboarding, invites: time counts, never an ad.
  other,
}

const _menuPaths = {
  '/',
  '/mode',
  '/online',
  '/history',
  '/profile',
  '/settings',
  '/how-to-play',
  '/analytics',
};

AdSurface adSurfaceOf(String path) {
  if (path.startsWith('/match')) return AdSurface.gameplay;
  if (path.startsWith('/online/lobby')) return AdSurface.waiting;
  if (_menuPaths.contains(path) || RegExp(r'^/history/\d+$').hasMatch(path)) {
    return AdSurface.menu;
  }
  return AdSurface.other;
}

/// A navigation the session ad may follow: from one menu to another.
bool sessionNavigation(String from, String to) =>
    from != to &&
    adSurfaceOf(from) == AdSurface.menu &&
    adSurfaceOf(to) == AdSurface.menu;

/// Menu time banked since the last full-screen ad. Runs only while the app
/// is in the foreground and off a gameplay surface. Pure.
class MenuClock {
  final int bankedMs;
  final int? sinceMs;
  const MenuClock({this.bankedMs = 0, this.sinceMs});

  static const stopped = MenuClock();

  bool get running => sinceMs != null;

  MenuClock run(int nowMs) =>
      running ? this : MenuClock(bankedMs: bankedMs, sinceMs: nowMs);

  MenuClock pause(int nowMs) =>
      running ? MenuClock(bankedMs: elapsed(nowMs)) : this;

  /// A full-screen ad was shown: the count starts again.
  MenuClock reset(int nowMs) => MenuClock(sinceMs: running ? nowMs : null);

  int elapsed(int nowMs) {
    final since = sinceMs;
    if (since == null) return bankedMs;
    final delta = nowMs - since;
    return bankedMs + (delta > 0 ? delta : 0);
  }
}
