/// Web pacing is separate from Android's AdMob pacing. Only public menu and
/// result surfaces may request a break; the game table is always excluded.
enum WebAdMoment { appOpen, enterOnline, enterLocal, afterMatch, banner }

class WebAdRules {
  final bool enabled;
  final String provider;
  final int interstitialEveryMatches;
  final bool appOpen;
  final bool bannerAlways;

  /// AdSense display slot served by the server (`web_ads_banner_slot`), so a
  /// new slot needs no rebuild. Empty means "use the build-time define".
  final String bannerSlot;

  const WebAdRules({
    this.enabled = false,
    this.provider = 'house',
    this.interstitialEveryMatches = 1,
    this.appOpen = true,
    this.bannerAlways = true,
    this.bannerSlot = '',
  });

  static const off = WebAdRules();

  factory WebAdRules.fromJson(Object? value) {
    if (value is! Map) return off;
    final count = (value['interstitialEveryMatches'] as num?)?.toInt() ?? 1;
    return WebAdRules(
      enabled: value['enabled'] == true,
      provider:
          value['provider'] == 'adsense' || value['provider'] == 'adsense_h5'
          ? 'adsense'
          : 'house',
      interstitialEveryMatches: count.clamp(1, 20),
      appOpen: value['appOpen'] != false,
      bannerAlways: value['bannerAlways'] != false,
      bannerSlot: _slot(value['bannerSlot']),
    );
  }

  static final _slotShape = RegExp(r'^[0-9]{5,20}$');
  static String _slot(Object? raw) =>
      raw is String && _slotShape.hasMatch(raw) ? raw : '';

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

/// Keeps navigation-driven breaks (entering local or online) from chaining.
/// Back-navigating through /mode and /online must not earn a break every
/// visit. Match ends and app open are never gated: they are not repeatable by
/// tapping back. Time is injected so it is testable and never read in rules.
class WebBreakPacer {
  final Duration gap;
  final int Function() _nowMs;
  int? _lastEndMs;

  WebBreakPacer({required this.gap, int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  bool canStart(WebAdMoment moment) {
    if (moment != WebAdMoment.enterLocal && moment != WebAdMoment.enterOnline) {
      return true;
    }
    final last = _lastEndMs;
    return last == null || _nowMs() - last >= gap.inMilliseconds;
  }

  /// Call when any break (Google or house) has finished.
  void breakEnded() => _lastEndMs = _nowMs();
}
