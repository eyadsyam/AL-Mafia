import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/platform/monetization/web_ad_rules.dart';

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
