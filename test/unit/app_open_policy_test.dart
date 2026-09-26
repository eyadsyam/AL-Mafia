import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/app_open_policy.dart';
import 'package:mafia_master/ui/economy/app_open_gate.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

void main() {
  const hour = 60 * 60 * 1000;
  // 2026-09-26 12:00 UTC
  final noon = DateTime.utc(2026, 9, 26, 12).millisecondsSinceEpoch;
  const on = AppOpenRules(
    enabled: true,
    maxPerDay: 3,
    gap: AdTokens.appOpenMinGap,
    resumeAfter: AdTokens.appOpenResumeAfter,
  );
  // A returning, onboarded player on their second launch.
  final seasoned = AppOpenLedger.empty
      .launched(noon - 48 * hour)
      .launched(noon);
  // Events in time order, then this launch at noon.
  AppOpenLedger before(AppOpenLedger Function(AppOpenLedger) events) =>
      events(AppOpenLedger.empty.launched(noon - 48 * hour)).launched(noon);

  AppOpenVerdict decide({
    AppOpenRules rules = on,
    AppOpenLedger? ledger,
    int? now,
    AppOpenTrigger trigger = AppOpenTrigger.coldStart,
    bool adFree = false,
    bool onboarded = true,
    bool busy = false,
    bool consent = true,
    int? loadedAt = -1,
  }) {
    final at = now ?? noon;
    return decideAppOpen(
      rules: rules,
      ledger: ledger ?? seasoned,
      nowMs: at,
      trigger: trigger,
      adFree: adFree,
      onboarded: onboarded,
      busy: busy,
      canRequestAds: consent,
      loadedAtMs: loadedAt == -1 ? at : loadedAt,
    );
  }

  test('shows for a returning, consented, onboarded player', () {
    expect(decide(), AppOpenVerdict.show);
  });

  test('off by default and when the server says off', () {
    expect(decide(rules: AppOpenRules.off), AppOpenVerdict.off);
    expect(
      decide(rules: AppOpenRules.fromJson(null)),
      AppOpenVerdict.off,
      reason: 'an old server has no ads key',
    );
    expect(
      decide(rules: AppOpenRules.fromJson({'enabled': true, 'maxPerDay': 0})),
      AppOpenVerdict.off,
    );
  });

  test('never on the very first launch', () {
    final first = AppOpenLedger.empty.launched(noon);
    expect(decide(ledger: first), AppOpenVerdict.firstLaunch);
  });

  test('never before onboarding and the terms are done', () {
    expect(decide(onboarded: false), AppOpenVerdict.onboarding);
  });

  test(
    'never into an active room, a live match, pass-and-play or a purchase',
    () {
      expect(decide(busy: true), AppOpenVerdict.busy);
      expect(appOpenBlockedPath('/match'), isTrue);
      expect(appOpenBlockedPath('/online/lobby'), isTrue);
      expect(appOpenBlockedPath('/'), isFalse);
      expect(appOpenBlockedPath('/history'), isFalse);
    },
  );

  test('never right after another full-screen ad or the purchase sheet', () {
    final back = seasoned.away(noon - 10 * 60 * 1000);
    expect(decide(ledger: back), AppOpenVerdict.justReturned);
    final longAgo = seasoned.away(noon - 5 * hour);
    expect(decide(ledger: longAgo), AppOpenVerdict.show);
  });

  test('on resume only after four hours in the background', () {
    final shortBreak = before((l) => l.backgrounded(noon - 30 * 60 * 1000));
    expect(
      decide(ledger: shortBreak, trigger: AppOpenTrigger.resume),
      AppOpenVerdict.notLongAway,
    );
    final noRecord = seasoned;
    expect(
      decide(ledger: noRecord, trigger: AppOpenTrigger.resume),
      AppOpenVerdict.notLongAway,
    );
    final longBreak = before((l) => l.backgrounded(noon - 4 * hour));
    expect(
      decide(ledger: longBreak, trigger: AppOpenTrigger.resume),
      AppOpenVerdict.show,
    );
  });

  test('daily cap and minimum gap', () {
    final ledger = before(
      (l) => l
          .shown(noon - 9 * hour)
          .shown(noon - 5 * hour)
          .shown(noon - 4 * hour - 1),
    );
    expect(decide(ledger: ledger), AppOpenVerdict.dailyCap);
    final once = before((l) => l.shown(noon - hour));
    expect(decide(ledger: once), AppOpenVerdict.tooSoon);
    expect(
      decide(ledger: once, now: noon + 3 * hour),
      AppOpenVerdict.show,
      reason: 'four hours after the last one',
    );
    // A new UTC day resets the count.
    final tomorrow = DateTime.utc(2026, 9, 27, 9).millisecondsSinceEpoch;
    expect(decide(ledger: ledger, now: tomorrow), AppOpenVerdict.show);
  });

  test('a clock moved backwards never frees the cap', () {
    final ledger = seasoned.shown(noon);
    expect(
      decide(ledger: ledger, now: noon - 24 * hour),
      AppOpenVerdict.tooSoon,
    );
  });

  test('the server can only widen the floors', () {
    final loose = AppOpenRules.fromJson({
      'enabled': true,
      'maxPerDay': 9,
      'gapSeconds': 60,
      'resumeAfterSeconds': 1,
    });
    expect(loose.maxPerDay, 3);
    expect(loose.gap, AdTokens.appOpenMinGap);
    expect(loose.resumeAfter, AdTokens.appOpenResumeAfter);
    final strict = AppOpenRules.fromJson({
      'enabled': true,
      'maxPerDay': 1,
      'gapSeconds': 8 * 3600,
    });
    expect(strict.maxPerDay, 1);
    expect(strict.gap, const Duration(hours: 8));
  });

  test('a loaded ad expires four hours after it loaded', () {
    expect(decide(loadedAt: noon - 4 * hour), AppOpenVerdict.expired);
    expect(decide(loadedAt: noon - 3 * hour), AppOpenVerdict.show);
    expect(decide(loadedAt: null), AppOpenVerdict.notLoaded);
  });

  test('the Quiet Pass removes it', () {
    expect(decide(adFree: true), AppOpenVerdict.adFree);
  });

  test('needs consent that allows ad requests', () {
    expect(decide(consent: false), AppOpenVerdict.noConsent);
  });

  test('the ledger survives a round trip', () {
    final ledger = seasoned
        .shown(noon)
        .away(noon + 1)
        .backgrounded(noon + 2)
        .known(enabled: true, adFree: false);
    final back = AppOpenLedger.fromJson(ledger.toJson());
    expect(back.toJson(), ledger.toJson());
  });

  group('capabilities', () {
    test('an old server (no ads key) is all off', () {
      final caps = EconomyCapabilities.fromJson({'version': 2});
      expect(caps.ads.appOpen.enabled, isFalse);
      expect(caps.ads.banner, isFalse);
      expect(caps.ads.extras, isFalse);
    });

    test('reads every switch', () {
      final caps = EconomyCapabilities.fromJson({
        'version': 2,
        'ads': {
          'appOpen': {'enabled': true, 'maxPerDay': 2, 'gapSeconds': 14400},
          'banner': {'enabled': true},
          'extras': {'spin': true, 'coffer': false, 'swap': true},
        },
      });
      expect(caps.ads.appOpen.enabled, isTrue);
      expect(caps.ads.appOpen.maxPerDay, 2);
      expect(caps.ads.banner, isTrue);
      expect(caps.ads.extraSpin, isTrue);
      expect(caps.ads.extraCoffer, isFalse);
      expect(caps.ads.extraSwap, isTrue);
    });

    test('garbage is off', () {
      final caps = EconomyCapabilities.fromJson({
        'version': 2,
        'ads': {'appOpen': 'yes', 'banner': true, 'extras': []},
      });
      expect(caps.ads.appOpen.enabled, isFalse);
      expect(caps.ads.banner, isFalse);
      expect(caps.ads.extras, isFalse);
    });
  });
}
