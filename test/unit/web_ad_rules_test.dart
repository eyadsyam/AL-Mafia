import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/platform/monetization/web_ad_rules.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

void main() {
  test('web has more breaks than Android with the default grace match', () {
    final web = WebAdRules.fromJson(const {
      'enabled': true,
      'provider': 'house',
      'interstitialEveryMatches': 1,
      'appOpen': true,
      'bannerAlways': true,
    });
    expect(
      web.allows(WebAdMoment.appOpen, privatePhase: false, adFree: false),
      isTrue,
    );
    expect(
      web.allows(WebAdMoment.enterOnline, privatePhase: false, adFree: false),
      isTrue,
    );
    expect(
      web.allows(WebAdMoment.enterLocal, privatePhase: false, adFree: false),
      isTrue,
    );
    expect(
      web.allows(
        WebAdMoment.afterMatch,
        privatePhase: false,
        adFree: false,
        completedMatches: 1,
      ),
      isTrue,
    );
    expect(
      web.allows(WebAdMoment.banner, privatePhase: false, adFree: false),
      isTrue,
    );
    const android = InterstitialRules(
      enabled: true,
      preMatch: true,
      passAndPlay: true,
      session: true,
      maxPerDay: 40,
      gap: Duration(seconds: 90),
      afterReward: Duration(seconds: 180),
      graceMatches: 1,
    );
    final first = InterstitialLedger.empty.matchCompleted('first', 1000000);
    expect(
      decideInterstitial(
        rules: android,
        ledger: first,
        nowMs: 1000000,
        adFree: false,
        loaded: true,
      ),
      InterstitialVerdict.grace,
    );
    final second = first.matchCompleted('second', 1001000).shown(1001000);
    expect(
      decideInterstitial(
        rules: android,
        ledger: second,
        nowMs: 1002000,
        adFree: false,
        loaded: true,
      ),
      InterstitialVerdict.tooSoon,
    );
    expect(
      web.allows(
        WebAdMoment.afterMatch,
        privatePhase: false,
        adFree: false,
        completedMatches: 2,
      ),
      isTrue,
    );
  });

  test('no web break or banner during any private phase', () {
    const web = WebAdRules(enabled: true);
    for (final moment in WebAdMoment.values) {
      expect(
        web.allows(
          moment,
          privatePhase: true,
          adFree: false,
          completedMatches: 4,
        ),
        isFalse,
        reason: moment.name,
      );
      expect(
        web.allows(
          moment,
          privatePhase: false,
          adFree: true,
          completedMatches: 4,
        ),
        isFalse,
        reason: moment.name,
      );
    }
  });

  test('navigation breaks keep a minimum gap, match ends and open do not', () {
    var now = 1000000;
    final pacer = WebBreakPacer(
      gap: const Duration(seconds: 90),
      nowMs: () => now,
    );
    expect(pacer.canStart(WebAdMoment.enterLocal), isTrue);
    pacer.breakEnded();
    now += 10000;
    // Back-navigation through /mode and /online right after a break.
    expect(pacer.canStart(WebAdMoment.enterLocal), isFalse);
    expect(pacer.canStart(WebAdMoment.enterOnline), isFalse);
    expect(pacer.canStart(WebAdMoment.afterMatch), isTrue);
    expect(pacer.canStart(WebAdMoment.appOpen), isTrue);
    now += 79999;
    expect(pacer.canStart(WebAdMoment.enterLocal), isFalse);
    now += 1;
    expect(pacer.canStart(WebAdMoment.enterLocal), isTrue);
  });

  test('the web gap is the Android gap, so web stays heavier per match', () {
    expect(WebAdTokens.minBreakGap, const Duration(seconds: 90));
  });

  test('a server banner slot is accepted only in the AdSense shape', () {
    expect(
      WebAdRules.fromJson(const {'bannerSlot': '1234567890'}).bannerSlot,
      '1234567890',
    );
    for (final bad in ['abc', '1234', '12345678901234567890123', '', null, 5]) {
      expect(
        WebAdRules.fromJson({'bannerSlot': bad}).bannerSlot,
        isEmpty,
        reason: '$bad',
      );
    }
    expect(WebAdRules.fromJson(const {'enabled': true}).bannerSlot, isEmpty);
  });

  test('server settings are bounded and missing settings are off', () {
    expect(WebAdRules.fromJson(null).enabled, isFalse);
    final web = WebAdRules.fromJson(const {
      'enabled': true,
      'interstitialEveryMatches': 99,
    });
    expect(web.interstitialEveryMatches, 20);
    expect(
      web.allows(
        WebAdMoment.afterMatch,
        privatePhase: false,
        adFree: false,
        completedMatches: 1,
      ),
      isFalse,
    );
  });
}
