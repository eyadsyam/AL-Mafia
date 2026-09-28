import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/app_open_policy.dart';
import 'package:mafia_master/platform/monetization/interstitial_policy.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/waiting_banner.dart';

void main() {
  final now = DateTime.utc(2026, 9, 28, 12).millisecondsSinceEpoch;

  EconomyCapabilities capabilities({required bool creator}) =>
      EconomyCapabilities.fromJson({
        'version': 2,
        'creator': creator,
        'dailyAd': true,
        'interstitial': {'enabled': true},
        'ads': {
          'appOpen': {'enabled': true},
          'banner': {'enabled': true},
          'extras': {'spin': true, 'coffer': true, 'swap': true},
        },
      });

  InterstitialVerdict interstitial(EconomyCapabilities caps) {
    var ledger = InterstitialLedger.empty;
    ledger = ledger.matchCompleted('one', now - 10000000);
    ledger = ledger.matchCompleted('two', now - 9000000);
    return decideInterstitial(
      rules: caps.interstitial,
      ledger: ledger,
      nowMs: now,
      adFree: caps.automaticAdsDisabled,
      loaded: true,
    );
  }

  AppOpenVerdict appOpen(EconomyCapabilities caps) => decideAppOpen(
    rules: caps.ads.appOpen,
    ledger: AppOpenLedger.empty
        .launched(now - const Duration(days: 2).inMilliseconds)
        .launched(now),
    nowMs: now,
    trigger: AppOpenTrigger.coldStart,
    adFree: caps.automaticAdsDisabled,
    onboarded: true,
    busy: false,
    canRequestAds: true,
    loadedAtMs: now,
  );

  test('creator suppresses every automatic ad decision', () {
    final caps = capabilities(creator: true);

    expect(interstitial(caps), InterstitialVerdict.adFree);
    expect(appOpen(caps), AppOpenVerdict.adFree);
    expect(shouldShowWaitingBanner(caps), isFalse);
  });

  test('creator leaves rewarded offers unchanged', () {
    final ordinary = capabilities(creator: false);
    final creator = capabilities(creator: true);

    expect(creator.dailyAd, ordinary.dailyAd);
    expect(creator.ads.extraSpin, ordinary.ads.extraSpin);
    expect(creator.ads.extraCoffer, ordinary.ads.extraCoffer);
    expect(creator.ads.extraSwap, ordinary.ads.extraSwap);
  });

  test('non-creator keeps the ordinary automatic ad model', () {
    final caps = capabilities(creator: false);

    expect(caps.automaticAdsDisabled, isFalse);
    expect(interstitial(caps), InterstitialVerdict.show);
    expect(appOpen(caps), AppOpenVerdict.show);
    expect(shouldShowWaitingBanner(caps), isTrue);
  });
}
