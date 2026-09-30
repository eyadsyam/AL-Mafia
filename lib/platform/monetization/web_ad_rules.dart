/// Web pacing is separate from Android's AdMob pacing. Only public menu and
/// result surfaces may request a break; the game table is always excluded.
enum WebAdMoment { appOpen, enterOnline, enterLocal, afterMatch, banner }

class WebAdRules {
  final bool enabled;
  final String provider;
  final int interstitialEveryMatches;
  final bool appOpen;
  final bool bannerAlways;

  const WebAdRules({
    this.enabled = false,
    this.provider = 'house',
    this.interstitialEveryMatches = 1,
    this.appOpen = true,
    this.bannerAlways = true,
  });

  static const off = WebAdRules();

  factory WebAdRules.fromJson(Object? value) {
    if (value is! Map) return off;
    final count = (value['interstitialEveryMatches'] as num?)?.toInt() ?? 1;
    return WebAdRules(
      enabled: value['enabled'] == true,
      provider: value['provider'] == 'adsense_h5' ? 'adsense_h5' : 'house',
      interstitialEveryMatches: count.clamp(1, 20),
      appOpen: value['appOpen'] != false,
      bannerAlways: value['bannerAlways'] != false,
    );
  }

  bool allows(
    WebAdMoment moment, {
    required bool privatePhase,
    required bool adFree,
    int completedMatches = 0,
  }) {
    if (!enabled || privatePhase || adFree) return false;
    return switch (moment) {
      WebAdMoment.appOpen => appOpen,
      WebAdMoment.enterOnline || WebAdMoment.enterLocal => true,
      WebAdMoment.afterMatch =>
        completedMatches > 0 &&
            completedMatches % interstitialEveryMatches == 0,
      WebAdMoment.banner => bannerAlways,
    };
  }
}
