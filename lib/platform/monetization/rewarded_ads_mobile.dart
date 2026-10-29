import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ui/economy/banner_frame.dart';
import '../../ui/theme/design_tokens.dart';
import '../../ui/theme/mafia_theme.dart';
import 'ad_formats.dart';
import 'full_screen_away.dart';
import 'interstitial_ads.dart';
import 'rewarded_ads.dart';

RewardedAds createRewardedAds() => GoogleRewardedAds();
InterstitialAds createInterstitialAds() => GoogleInterstitialAds();
AppOpenAds createAppOpenAds() => GoogleAppOpenAds();
BannerAds createBannerAds() => const GoogleBannerAds();
NativeAds createNativeAds() => const GoogleNativeAds();
ShellBannerAds createShellBannerAds() => const GoogleShellBannerAds();

abstract final class _Units {
  static const enabled = bool.fromEnvironment('ADS_ENABLED');

  /// Google's sample units unless this is a release build with test mode
  /// off: a debug or profile run with the production defines must never
  /// request (or click) a live unit — that is invalid traffic on the
  /// account. A non-release build also carries Google's sample app id in
  /// the manifest (build.gradle.kts), which a live unit would not serve.
  static const testMode =
      bool.fromEnvironment('ADMOB_TEST_MODE') || !kReleaseMode;
  static const rewarded = String.fromEnvironment('ADMOB_REWARDED_ANDROID_ID');
  static const rewardedV2 = String.fromEnvironment(
    'ADMOB_REWARDED_V2_ANDROID_ID',
  );
  static const interstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID_ID',
  );
  static const appOpen = String.fromEnvironment('ADMOB_APP_OPEN_ANDROID_ID');
  static const banner = String.fromEnvironment('ADMOB_BANNER_ANDROID_ID');

  // Google's documented sample units.
  static const testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const testBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const testNative = 'ca-app-pub-3940256099942544/2247696110';

  static bool get rewardedConfigured =>
      enabled && (testMode || rewarded.isNotEmpty);
  static bool get interstitialConfigured =>
      enabled && (testMode || interstitial.isNotEmpty);

  static String rewardedFor(RewardedPlacement placement) {
    if (testMode) return testRewarded;
    return switch (placement) {
      RewardedPlacement.matchLegacy => rewarded,
      // Per-offer units (2026-10-07), each with SSV to admob_ssv.
      RewardedPlacement.matchStep => '$_pub/7753405421',
      RewardedPlacement.matchStepTwo => '$_pub/3404106030',
      RewardedPlacement.daily => '$_pub/4661347383',
      RewardedPlacement.extra => rewardedV2.isNotEmpty ? rewardedV2 : rewarded,
    };
  }

  static String interstitialUnit({required bool online}) {
    if (testMode) return testInterstitial;
    return online ? '$_pub/9296305972' : '$_pub/9969514385';
  }

  static bool get appOpenConfigured =>
      enabled && (testMode || appOpen.isNotEmpty);
  static bool get bannerConfigured =>
      enabled && (testMode || banner.isNotEmpty);
  static String appOpenUnit({required bool resume}) {
    if (testMode) return testAppOpen;
    return resume ? '$_pub/7983224304' : '$_pub/7952715977';
  }

  /// Per-surface banner units (AdMob, created 2026-10-07). Public
  /// identifiers, not credentials. The lobby keeps the original unit.
  // Split so no 16-digit run sits in the source: the web compiler test flags
  // any as an integer literal.
  static const _pub = 'ca-app-pub-91790639' '36085117';

  static bool get nativeConfigured => enabled;

  static String nativeUnitFor(NativePlacement placement) {
    if (testMode) return testNative;
    return switch (placement) {
      NativePlacement.home => '$_pub/4235550981',
      NativePlacement.history => '$_pub/9293717805',
      NativePlacement.onlineHub => '$_pub/2692650431',
      NativePlacement.vault => '$_pub/1609387640',
      NativePlacement.council => '$_pub/3136512721',
      NativePlacement.characters => '$_pub/4449594399',
      NativePlacement.stories => '$_pub/1243837397',
    };
  }

  static String bannerUnitFor(BannerPlacement placement) {
    if (testMode) return testBanner;
    return switch (placement) {
      BannerPlacement.lobby => banner,
      BannerPlacement.onlineHub => '$_pub/8419619834',
      BannerPlacement.history => '$_pub/9258058781',
      BannerPlacement.vault => '$_pub/5318813774',
      BannerPlacement.profile => '$_pub/2919881145',
      BannerPlacement.home => '$_pub/8363779511',
      BannerPlacement.stories => '$_pub/9972374654',
      BannerPlacement.characters => '$_pub/8174795996',
      BannerPlacement.shell =>
        _shellDedicatedUnit.isNotEmpty
            ? _shellDedicatedUnit
            : bannerUnitFor(BannerPlacement.home),
    };
  }

  /// TODO(owner): create a dedicated AdMob banner unit for the shell host and
  /// put its id here. Until then the shell banner reports under the home
  /// unit. Deliberately empty: no unit id is invented.
  static const _shellDedicatedUnit = '';
}

/// Consent and SDK start, shared by the rewarded offers and the interstitial.
///
/// One attempt at a time: parallel callers await the same future, so two
/// taps cannot put two consent forms up or start the SDK twice.
class _AdsRuntime {
  _AdsRuntime._();
  static final instance = _AdsRuntime._();

  bool initialized = false;
  bool privacyRequired = false;
  Future<bool>? _prompting;
  final _consentChanged = <void Function()>[];

  void onConsentChanged(void Function() listener) =>
      _consentChanged.add(listener);
  void offConsentChanged(void Function() listener) =>
      _consentChanged.remove(listener);
  Future<bool>? _quiet;

  /// Asks Google for the current consent requirement, bounded: this is a
  /// network call, and nothing waits on it longer than the token allows.
  Future<void> updateInfo() async {
    final done = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!done.isCompleted) done.complete();
        },
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );
    } catch (_) {
      if (!done.isCompleted) done.complete();
    }
    await done.future.timeout(
      MafiaTiming.adConsentInfoTimeout,
      onTimeout: () {},
    );
  }

  Future<void> refreshPrivacyRequirement() async {
    try {
      privacyRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      privacyRequired = false;
    }
  }

  Future<bool> _canRequest() async {
    try {
      return await ConsentInformation.instance.canRequestAds().timeout(
        MafiaTiming.adConsentInfoTimeout,
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void>? _initializing;

  /// Starts the SDK, bounded: a start that never answers (seen on a real
  /// emulator, 2026-10-02) used to hold the tap — and the loading veil — up
  /// for good. The start keeps running; a later tap finds it finished.
  Future<bool> _startSdk() async {
    if (initialized) return true;
    _initializing ??= MobileAds.instance
        .initialize()
        .then<void>((_) => initialized = true)
        .catchError((Object _) {})
        .whenComplete(() => _initializing = null);
    try {
      await _initializing!.timeout(MafiaTiming.adLoadTimeout);
    } catch (_) {}
    return initialized;
  }

  /// Whether Google says a consent form must be shown before ads.
  Future<bool> _formRequired() async {
    try {
      return await ConsentInformation.instance.getConsentStatus().timeout(
            MafiaTiming.adConsentInfoTimeout,
          ) ==
          ConsentStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Consent (with the form when [prompt] and Google requires it), then the
  /// SDK. Returns whether ads may be requested now.
  Future<bool> start({required bool prompt}) {
    if (initialized) return Future.value(true);
    if (!prompt) {
      // A quiet caller rides along with a player's attempt if one is running.
      return _prompting ??
          (_quiet ??= _start(false).whenComplete(() => _quiet = null));
    }
    return _prompting ??= () async {
      // A quiet attempt in flight finishes first; the player's own tap then
      // gets its chance at the form.
      final quiet = _quiet;
      if (quiet != null &&
          await quiet.timeout(
            MafiaTiming.adLoadTimeout,
            onTimeout: () => false,
          )) {
        return true;
      }
      return _start(true);
    }().whenComplete(() => _prompting = null);
  }

  Future<bool> _start(bool prompt) async {
    await updateInfo();
    if (prompt && await _formRequired()) {
      // The form is a person reading and choosing: no timeout here. Only
      // when Google says one is due — a form that is not required answers
      // nothing on some devices, and that used to freeze the tap.
      final shown = Completer<void>();
      try {
        ConsentForm.loadAndShowConsentFormIfRequired((_) {
          if (!shown.isCompleted) shown.complete();
        });
      } catch (_) {
        if (!shown.isCompleted) shown.complete();
      }
      await shown.future;
    }
    await refreshPrivacyRequirement();
    // canRequestAds decides — not the button the player pressed: a
    // "do not consent" answer can still allow limited ads in some regions.
    if (!await _canRequest()) return false;
    return _startSdk();
  }

  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    try {
      ConsentForm.showPrivacyOptionsForm((_) {
        if (!done.isCompleted) done.complete();
      });
    } catch (_) {
      if (!done.isCompleted) done.complete();
    }
    // A person reading and choosing: never timed out.
    await done.future;
    await refreshPrivacyRequirement();
    // Anything loaded under the previous answer is thrown away.
    for (final listener in List.of(_consentChanged)) {
      listener();
    }
    // A changed answer may now allow ads (start the SDK) or forbid them —
    // every later load re-checks canRequestAds, so the SDK may stay started.
    if (await _canRequest()) await _startSdk();
  }

  Future<bool> canRequestNow() => _canRequest();
}

class GoogleRewardedAds implements RewardedAds, RewardedPreload {
  _AdsRuntime get _runtime => _AdsRuntime.instance;

  /// One loaded ad per unit, with when it loaded. A tap takes it at once.
  final _ready = <String, (RewardedAd, int)>{};

  /// A load in flight per unit, shared by a preload and a tap.
  final _loading = <String, Future<void>>{};
  bool _listening = false;

  @override
  bool get configured => _Units.rewardedConfigured;

  @override
  bool get privacyOptionsRequired => _runtime.privacyRequired;

  @override
  Future<void> initialize() async {
    if (!configured) return;
    await _runtime.start(prompt: true);
  }

  @override
  Future<bool> checkPrivacyOptions() async {
    if (!configured) return false;
    if (!_runtime.initialized) await _runtime.updateInfo();
    await _runtime.refreshPrivacyRequirement();
    return _runtime.privacyRequired;
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (!configured) return;
    await _runtime.showPrivacyOptions();
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    // Anything loaded under a consent answer that changed is thrown away.
    _runtime.onConsentChanged(_discardAll);
  }

  void _discardAll() {
    for (final (ad, _) in _ready.values) {
      ad.dispose();
    }
    _ready.clear();
  }

  /// The ready ad for [unit], if it is still fresh. Removes it either way.
  RewardedAd? _take(String unit) {
    final entry = _ready.remove(unit);
    if (entry == null) return null;
    final (ad, loadedAt) = entry;
    final age = DateTime.now().millisecondsSinceEpoch - loadedAt;
    if (age >= AdTokens.rewardedExpiry.inMilliseconds) {
      ad.dispose();
      return null;
    }
    return ad;
  }

  /// Loads one ad for [unit] into [_ready]. Parallel callers share it.
  Future<void> _load(String unit) => _loading[unit] ??= _loadNow(
    unit,
  ).whenComplete(() => _loading.remove(unit));

  Future<void> _loadNow(String unit) async {
    final loaded = Completer<RewardedAd?>();
    // Not awaited: the plugin's load call can itself take as long as the
    // SDK's own HTTP timeout (60 s), and the bound below only starts once it
    // returns — which is how a first, slow ad held the veil up for a minute
    // on a real emulator (2026-10-02). The callbacks complete [loaded].
    try {
      unawaited(
        RewardedAd.load(
          adUnitId: unit,
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              // An ad that arrives after the timeout below has nobody to show
              // it; left alone it holds native resources until the process dies.
              if (loaded.isCompleted) {
                ad.dispose();
              } else {
                loaded.complete(ad);
              }
            },
            onAdFailedToLoad: (_) {
              if (!loaded.isCompleted) loaded.complete(null);
            },
          ),
        ).catchError((Object _) {
          if (!loaded.isCompleted) loaded.complete(null);
        }),
      );
    } catch (_) {
      if (!loaded.isCompleted) loaded.complete(null);
    }
    final ad = await loaded.future.timeout(
      MafiaTiming.adLoadTimeout,
      onTimeout: () {
        if (!loaded.isCompleted) loaded.complete(null);
        return null;
      },
    );
    if (ad == null) return;
    _ready.remove(unit)?.$1.dispose();
    _ready[unit] = (ad, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> preload(RewardedPlacement placement) async {
    if (!configured) return;
    final unit = _Units.rewardedFor(placement);
    if (_ready.containsKey(unit) || _loading.containsKey(unit)) return;
    _listen();
    try {
      // Never a consent form from a preload: only an answer already given
      // (or a region that needs none) lets it load. Starting the SDK here,
      // while the player is only looking at the offer, keeps that work off
      // the tap.
      if (!await _runtime.start(prompt: false)) return;
      if (!await _runtime.canRequestNow()) return;
      await _load(unit);
    } catch (_) {}
  }

  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async {
    if (!configured) return RewardedAdOutcome.unavailable;
    _listen();
    final allowed = await _runtime.start(prompt: true);
    if (!allowed) {
      return _runtime.initialized
          ? RewardedAdOutcome.unavailable
          : RewardedAdOutcome.notConsented;
    }
    if (!await _runtime.canRequestNow()) {
      _discardAll();
      return RewardedAdOutcome.notConsented;
    }

    final unit = _Units.rewardedFor(placement);
    // A preloaded ad shows at once; otherwise this tap loads one (or joins
    // the preload already on its way).
    var ad = _take(unit);
    if (ad == null) {
      await _load(unit);
      ad = _take(unit);
    }
    if (ad == null) return RewardedAdOutcome.unavailable;
    final showing = ad;

    try {
      // Before show: the claim id must travel in AdMob's signed callback, or
      // the view can never be credited.
      await showing.setServerSideOptions(
        ServerSideVerificationOptions(customData: claimId, userId: userId),
      );
    } catch (_) {
      showing.dispose();
      return RewardedAdOutcome.failed;
    }
    final finished = Completer<RewardedAdOutcome>();
    var earned = false;
    showing.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        FullScreenAway.adClosed();
        if (!finished.isCompleted) {
          finished.complete(
            earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (shown, _) {
        shown.dispose();
        FullScreenAway.adClosed();
        if (!finished.isCompleted) {
          finished.complete(RewardedAdOutcome.failed);
        }
      },
    );
    try {
      FullScreenAway.adOpened();
      await showing.show(onUserEarnedReward: (_, _) => earned = true);
    } catch (_) {
      FullScreenAway.adClosed();
      showing.dispose();
      return RewardedAdOutcome.failed;
    }
    return finished.future.timeout(
      MafiaTiming.adShowTimeout,
      onTimeout: () {
        FullScreenAway.adClosed();
        showing.dispose();
        // Earned even if the close never reached us: the server still
        // decides, so the screen checks rather than calling it a failure.
        return earned ? RewardedAdOutcome.earned : RewardedAdOutcome.failed;
      },
    );
  }

  @override
  void dispose() {
    _runtime.offConsentChanged(_discardAll);
    _discardAll();
  }
}

class GoogleInterstitialAds implements InterstitialAds {
  _AdsRuntime get _runtime => _AdsRuntime.instance;
  InterstitialAd? _ad;
  bool _loading = false;
  bool _showing = false;

  @override
  bool get configured => _Units.interstitialConfigured;

  @override
  bool get ready => _ad != null && !_showing;

  bool _listening = false;
  void _discard() {
    _ad?.dispose();
    _ad = null;
  }

  @override
  Future<void> preload({bool online = true}) async {
    if (!configured || _ad != null || _loading || _showing) return;
    if (!_listening) {
      _listening = true;
      _runtime.onConsentChanged(_discard);
    }
    _loading = true;
    try {
      // Never a consent form from an automatic ad: only an answer already
      // given lets this load.
      if (!await _runtime.start(prompt: false)) return;
      if (!await _runtime.canRequestNow()) return;
      final loaded = Completer<InterstitialAd?>();
      // Not awaited: see `_loadNow` — the bound must start at the call.
      unawaited(
        InterstitialAd.load(
          adUnitId: _Units.interstitialUnit(online: online),
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              if (loaded.isCompleted) {
                ad.dispose();
              } else {
                loaded.complete(ad);
              }
            },
            onAdFailedToLoad: (_) {
              if (!loaded.isCompleted) loaded.complete(null);
            },
          ),
        ).catchError((Object _) {
          if (!loaded.isCompleted) loaded.complete(null);
        }),
      );
      _ad = await loaded.future.timeout(
        MafiaTiming.interstitialLoadTimeout,
        onTimeout: () {
          loaded.complete(null);
          return null;
        },
      );
    } catch (_) {
      _ad = null;
    } finally {
      _loading = false;
    }
  }

  @override
  Future<bool> showIfReady() async {
    if (_ad == null || _showing) return false;
    // Consent may have been withdrawn since this ad was loaded.
    if (!await _runtime.canRequestNow()) {
      _discard();
      return false;
    }
    final ad = _ad;
    if (ad == null || _showing) return false;
    _ad = null;
    _showing = true;
    final finished = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        if (!finished.isCompleted) finished.complete(true);
      },
      onAdFailedToShowFullScreenContent: (shown, _) {
        shown.dispose();
        if (!finished.isCompleted) finished.complete(false);
      },
    );
    try {
      FullScreenAway.adOpened();
      await ad.show();
      return await finished.future.timeout(
        MafiaTiming.adShowTimeout,
        onTimeout: () {
          ad.dispose();
          return false;
        },
      );
    } catch (_) {
      ad.dispose();
      return false;
    } finally {
      FullScreenAway.adClosed();
      _showing = false;
    }
  }

  @override
  Future<bool> canRequestAds() async {
    try {
      return await _runtime.canRequestNow();
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _runtime.offConsentChanged(_discard);
    _discard();
  }
}

/// Phase 108: the app-open ad. Loaded only under consent already given, only
/// for the few seconds the launch screen may wait, and discarded if late.
class GoogleAppOpenAds implements AppOpenAds {
  _AdsRuntime get _runtime => _AdsRuntime.instance;
  AppOpenAd? _ad;
  bool _showing = false;
  bool _listening = false;

  @override
  bool get configured => _Units.appOpenConfigured;

  @override
  Future<bool> canRequestAds() async {
    if (!configured) return false;
    // Never a consent form from an automatic ad.
    if (!await _runtime.start(prompt: false)) return false;
    return _runtime.canRequestNow();
  }

  @override
  Future<int?> load(Duration timeout, {bool resume = false}) async {
    if (!configured || _showing) return null;
    if (!_listening) {
      _listening = true;
      _runtime.onConsentChanged(discard);
    }
    discard();
    final loaded = Completer<AppOpenAd?>();
    try {
      // Not awaited: see `_loadNow` — the bound must start at the call.
      unawaited(
        AppOpenAd.load(
          adUnitId: _Units.appOpenUnit(resume: resume),
          request: const AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              // Late: the launch screen is gone and nobody will show it.
              if (loaded.isCompleted) {
                ad.dispose();
              } else {
                loaded.complete(ad);
              }
            },
            onAdFailedToLoad: (_) {
              if (!loaded.isCompleted) loaded.complete(null);
            },
          ),
        ).catchError((Object _) {
          if (!loaded.isCompleted) loaded.complete(null);
        }),
      );
    } catch (_) {
      if (!loaded.isCompleted) loaded.complete(null);
    }
    _ad = await loaded.future.timeout(
      timeout,
      onTimeout: () {
        loaded.complete(null);
        return null;
      },
    );
    return _ad == null ? null : DateTime.now().millisecondsSinceEpoch;
  }

  @override
  Future<bool> show() async {
    final ad = _ad;
    if (ad == null || _showing) return false;
    _ad = null;
    _showing = true;
    final finished = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (shown) {
        shown.dispose();
        if (!finished.isCompleted) finished.complete(true);
      },
      onAdFailedToShowFullScreenContent: (shown, _) {
        shown.dispose();
        if (!finished.isCompleted) finished.complete(false);
      },
    );
    try {
      FullScreenAway.adOpened();
      await ad.show();
      return await finished.future.timeout(
        MafiaTiming.adShowTimeout,
        onTimeout: () {
          ad.dispose();
          return false;
        },
      );
    } catch (_) {
      ad.dispose();
      return false;
    } finally {
      FullScreenAway.adClosed();
      _showing = false;
    }
  }

  @override
  void discard() {
    _ad?.dispose();
    _ad = null;
  }
}

/// Phase 108: the anchored adaptive banner for waiting surfaces.
class GoogleBannerAds implements BannerAds {
  const GoogleBannerAds();

  @override
  bool get configured => _Units.bannerConfigured;

  @override
  Widget slot({
    Key? key,
    required String label,
    required double gap,
    BannerPlacement placement = BannerPlacement.lobby,
  }) => configured
      ? _BannerSlot(key: key, label: label, gap: gap, placement: placement)
      : SizedBox.shrink(key: key);
}

class _BannerSlot extends StatefulWidget {
  final String label;
  final double gap;
  final BannerPlacement placement;
  const _BannerSlot({
    super.key,
    required this.label,
    required this.gap,
    required this.placement,
  });

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> with WidgetsBindingObserver {
  BannerAd? _ad;
  bool _filled = false;
  int? _width;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _AdsRuntime.instance.onConsentChanged(_drop);
  }

  /// Sized from the space the slot is actually given (a surface may pad it
  /// in from the screen edges), less the frame on both sides, floored: an
  /// ad wider than its box would be cropped, which AdMob forbids. The ad is
  /// always the standard 320x50, so it is only asked for when that fits.
  void _fitTo(BoxConstraints constraints) {
    final available = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;
    final width = (available - 2 * AdTokens.bannerFrame)
        .clamp(0.0, AdTokens.bannerMaxWidth)
        .floor();
    if (width == _width) return;
    _width = width;
    // Never load (or drop) mid-layout: after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _width == width) _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No banner refreshes while the app is in the background; a new one is
    // asked for on return. Voice and the mic are never touched.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _drop();
    } else if (state == AppLifecycleState.resumed && _ad == null) {
      _load();
    }
  }

  void _drop() {
    _epoch++;
    _ad?.dispose();
    _ad = null;
    if (mounted && _filled) setState(() => _filled = false);
  }

  Future<void> _load() async {
    _drop();
    final epoch = _epoch;
    final width = _width;
    if (width == null || width < AdTokens.bannerAdWidth) return;
    try {
      if (!await _AdsRuntime.instance.start(prompt: false)) return;
      if (!await _AdsRuntime.instance.canRequestNow()) return;
      if (!mounted || epoch != _epoch) return;
      final ad = BannerAd(
        size: AdSize.banner,
        adUnitId: _Units.bannerUnitFor(widget.placement),
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted && epoch == _epoch) setState(() => _filled = true);
          },
          onAdFailedToLoad: (failed, _) {
            failed.dispose();
            if (identical(_ad, failed)) _ad = null;
            if (mounted && _filled) setState(() => _filled = false);
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (_) {
      _drop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _AdsRuntime.instance.offConsentChanged(_drop);
    _epoch++;
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _fitTo(constraints);
      final ad = _ad;
      // The box is there from the first frame; the ad only fills it.
      return BannerFrame(
        label: widget.label,
        gap: widget.gap,
        ad: _filled && ad != null ? AdWidget(ad: ad) : null,
      );
    },
  );
}

/// WP4: the shell host's one banner (banner_mode = shell).
class GoogleShellBannerAds implements ShellBannerAds {
  const GoogleShellBannerAds();

  @override
  bool get configured => _Units.bannerConfigured;

  @override
  Widget band({Key? key, required String label, required bool visible}) =>
      configured
      ? _ShellBand(key: key, label: label, visible: visible)
      : SizedBox.shrink(key: key);
}

/// Mounted by the host for the whole session, shown or not. It owns the one
/// BannerAd: asked for the first time the band is shown, and never again
/// because a route came and went. While the band is hidden the AdWidget is
/// simply not in the tree (the same ad can be mounted again afterwards, one
/// widget at a time). Its refresh is the AdMob unit's own; there is no timer
/// or reload loop here. Disposed when the app detaches.
class _ShellBand extends StatefulWidget {
  final String label;
  final bool visible;
  const _ShellBand({super.key, required this.label, required this.visible});

  @override
  State<_ShellBand> createState() => _ShellBandState();
}

class _ShellBandState extends State<_ShellBand> with WidgetsBindingObserver {
  BannerAd? _ad;
  bool _filled = false;
  bool _asked = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _AdsRuntime.instance.onConsentChanged(_onConsent);
    _askIfShown();
  }

  @override
  void didUpdateWidget(_ShellBand old) {
    super.didUpdateWidget(old);
    _askIfShown();
  }

  void _askIfShown() {
    if (!widget.visible || _asked) return;
    _asked = true;
    // Never load mid-build: after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _onConsent() {
    _drop();
    if (_asked && mounted) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _drop();
    } else if (state == AppLifecycleState.resumed && _asked && _ad == null) {
      _load();
    }
  }

  void _drop() {
    _epoch++;
    _ad?.dispose();
    _ad = null;
    if (mounted && _filled) setState(() => _filled = false);
  }

  Future<void> _load() async {
    _drop();
    final epoch = _epoch;
    try {
      if (!await _AdsRuntime.instance.start(prompt: false)) return;
      if (!await _AdsRuntime.instance.canRequestNow()) return;
      if (!mounted || epoch != _epoch) return;
      final ad = BannerAd(
        size: AdSize.banner,
        adUnitId: _Units.bannerUnitFor(BannerPlacement.shell),
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted && epoch == _epoch) setState(() => _filled = true);
          },
          onAdFailedToLoad: (failed, _) {
            failed.dispose();
            if (identical(_ad, failed)) _ad = null;
            if (mounted && _filled) setState(() => _filled = false);
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (_) {
      _drop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _AdsRuntime.instance.offConsentChanged(_onConsent);
    _epoch++;
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final ad = _ad;
    return ShellBandFrame(
      label: widget.label,
      ad: _filled && ad != null ? AdWidget(ad: ad) : null,
    );
  }
}

class GoogleNativeAds implements NativeAds {
  const GoogleNativeAds();

  @override
  bool get configured => _Units.nativeConfigured;

  @override
  Widget slot({Key? key, required NativePlacement placement}) => configured
      ? _NativeSlot(key: key, placement: placement)
      : SizedBox.shrink(key: key);
}

class _NativeSlot extends StatefulWidget {
  final NativePlacement placement;
  const _NativeSlot({super.key, required this.placement});

  @override
  State<_NativeSlot> createState() => _NativeSlotState();
}

class _NativeSlotState extends State<_NativeSlot> {
  NativeAd? _ad;
  bool _filled = false;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    _AdsRuntime.instance.onConsentChanged(_drop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    // The template takes its colours from the theme, read here once.
    final colors = context.colors;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(colors);
    });
  }

  void _drop() {
    _ad?.dispose();
    _ad = null;
    if (mounted && _filled) setState(() => _filled = false);
  }

  Future<void> _load(MafiaColors colors) async {
    try {
      if (!await _AdsRuntime.instance.start(prompt: false)) return;
      if (!await _AdsRuntime.instance.canRequestNow()) return;
      if (!mounted) return;
      final ad = NativeAd(
        adUnitId: _Units.nativeUnitFor(widget.placement),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.small,
          mainBackgroundColor: colors.surfaceRaised,
          cornerRadius: AdTokens.nativeCorner,
          callToActionTextStyle: NativeTemplateTextStyle(
            textColor: colors.surfaceBase,
            backgroundColor: colors.accentGold,
          ),
          primaryTextStyle: NativeTemplateTextStyle(
            textColor: colors.textPrimary,
          ),
          secondaryTextStyle: NativeTemplateTextStyle(
            textColor: colors.textSecondary,
          ),
          tertiaryTextStyle: NativeTemplateTextStyle(
            textColor: colors.textMuted,
          ),
        ),
        listener: NativeAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _filled = true);
          },
          onAdFailedToLoad: (failed, _) {
            failed.dispose();
            if (identical(_ad, failed)) _ad = null;
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (_) {
      _drop();
    }
  }

  @override
  void dispose() {
    _AdsRuntime.instance.offConsentChanged(_drop);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_filled || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AdTokens.nativeMinHeight,
          maxHeight: AdTokens.nativeMaxHeight,
        ),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
