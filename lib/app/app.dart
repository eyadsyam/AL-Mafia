import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/motion_preference.dart';
import '../data/player_group_provider.dart';
import '../platform/audio_director.dart';
import '../platform/narrator_bank.dart';
import '../platform/optional_service.dart';
import '../platform/metrics.dart';
import '../platform/review_prompt.dart';
import '../ui/screens/setup/setup_draft.dart';
import '../ui/screens/setup/scenario_store.dart';
import '../ui/l10n_ext.dart';
import '../ui/theme/mafia_theme.dart';
import '../ui/widgets/splash_gate.dart';
import 'l10n/app_localizations.dart';
import 'onboarding_gate.dart';
import 'update_gate.dart';
import 'resume_gate.dart';
import 'router.dart';
import '../ui/economy/app_open_gate.dart';
import '../ui/economy/economy_capabilities.dart'
    show
        EconomyCapabilities,
        economyCapabilitiesProvider,
        retryCapabilitiesIfFailed;
import '../ui/economy/interstitial_coordinator.dart';
import '../ui/economy/coin_packs.dart';
import '../ui/economy/play_offers.dart';
import '../ui/economy/wallet.dart';
import '../ui/economy/web_ads.dart';
import '../platform/monetization/web_ad_rules.dart';
import '../ui/social/invite_privacy.dart';
import '../ui/theme/design_tokens.dart';
import '../platform/push/push_service.dart';
import '../ui/screens/online/online_session.dart' show SupabaseConfig;
import 'locale_controller.dart';
import '../ui/widgets/warmup_gate.dart';
import '../ui/social/incoming_invite.dart';

/// Root app widget for Mafia Master.
///
/// Arabic is the primary locale and the app is RTL-first (FR-034); English is
/// supported but is the fallback, not the default.
class MafiaApp extends ConsumerStatefulWidget {
  /// See [buildRouter]'s parameter of the same name. Tests only.
  final String? initialLocation;

  const MafiaApp({super.key, this.initialLocation});

  @override
  ConsumerState<MafiaApp> createState() => _MafiaAppState();
}

class _MafiaAppState extends ConsumerState<MafiaApp>
    with WidgetsBindingObserver {
  /// Owned here, not global: two app instances in one test process would
  /// otherwise fight over the same key.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _paymentPush;
  Timer? _paymentPoll;
  bool _webAdShowing = false;
  bool _webAppOpenRequested = false;
  int _webCompletedMatches = 0;

  Future<void> _showWebAd(WebAdMoment moment) async {
    if (!kIsWeb || _webAdShowing || !mounted) return;
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (ref.read(privateMomentProvider) ||
        (path == Routes.match && moment != WebAdMoment.afterMatch)) {
      return;
    }
    final caps = await ref
        .read(economyCapabilitiesProvider.future)
        .catchError((_) => EconomyCapabilities.none);
    if (!mounted || ref.read(privateMomentProvider)) return;
    if (moment == WebAdMoment.afterMatch) _webCompletedMatches++;
    if (!caps.webAds.allows(
      moment,
      privatePhase: false,
      adFree: caps.automaticAdsDisabled,
      completedMatches: _webCompletedMatches,
    )) {
      return;
    }
    final current = _router.routerDelegate.currentConfiguration.uri.path;
    if (ref.read(privateMomentProvider) ||
        (current == Routes.match && moment != WebAdMoment.afterMatch)) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _webAdShowing = true;
    ref.read(webBreakActiveProvider.notifier).state = true;
    try {
      // Hold the public screen in place while H5 decides. A player cannot tap
      // through to a private turn while a late Google break is pending.
      final dialog = showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: context.l10n.adBannerLabel,
        barrierColor: Theme.of(context).colorScheme.surface,
        transitionDuration: WebAdTokens.transition,
        pageBuilder: (_, _, _) => HouseWebInterstitial(moment: moment),
      );
      final house = await needsHouseInterstitial(
        caps.webAds,
        moment,
        ref.read(webBreakAttemptProvider),
      );
      if (!house && mounted && context.mounted) {
        _navigatorKey.currentState?.pop();
      }
      await dialog;
    } finally {
      _webAdShowing = false;
      if (mounted) ref.read(webBreakActiveProvider.notifier).state = false;
    }
  }

  Future<void> _refreshPayment() async {
    if (ref.exists(coinShopProvider)) {
      await ref.read(coinShopProvider.notifier).reload();
    } else {
      await ref.read(walletProvider.notifier).refresh();
    }
  }

  late final GoRouter _router = buildRouter(
    ref,
    navigatorKey: _navigatorKey,
    initialLocation: widget.initialLocation,
  );

  AudioDirector get _audio => ref.read(audioDirectorProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ads v3 (phase 110): the menu clock and the session ad follow the
    // router. A listener only: it never changes where the player goes.
    _lastPath = _router.routerDelegate.currentConfiguration.uri.path;
    _router.routerDelegate.addListener(_routeChanged);
    ref.read(interstitialCoordinatorProvider).foreground(true);
    _paymentPush = ref.read(pushServiceProvider).foreground.listen((_) {
      // The push payload contains no financial data. Ask the server for its
      // committed order and wallet state; this also refreshes owned items.
      unawaited(_refreshPayment());
    });
    _paymentPoll = Timer.periodic(StoreTokens.orderReviewPoll, (_) {
      if (ref.exists(coinShopProvider) &&
          (ref.read(coinShopProvider).valueOrNull?.pending.isNotEmpty ??
              false)) {
        unawaited(_refreshPayment());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && SupabaseConfig.isConfigured) {
        unawaited(ref.read(playOffersProvider.notifier).start());
      }
      if (mounted && kIsWeb) {
        unawaited(
          Future<void>.delayed(WebAdTokens.appOpenDelay, () {
            if (mounted &&
                !_webAppOpenRequested &&
                _router.routerDelegate.currentConfiguration.uri.path ==
                    Routes.home) {
              _webAppOpenRequested = true;
              requestWebAd(ref, WebAdMoment.appOpen);
            }
          }),
        );
      }
    });
    // Warm the saved groups now, while the splash is still up.
    //
    // The choice they feed — picker, or straight to an empty roster — is made
    // inside a router callback, which cannot await. Reading here means the list
    // is in hand long before anyone can tap "مباراة جديدة", and the read is a
    // handful of local rows. If it somehow has not landed, the caller treats
    // that as "no groups" and behaves exactly as the app did before groups
    // existed, so the worst case is the old behaviour rather than a stall.
    ref.read(playerGroupsProvider);
    // Ads are not started here (phase 100). The consent form and the ad SDK
    // start only when a player taps the optional post-match reward (or opens
    // the ad privacy choices), so nothing ad-related appears over first run
    // or onboarding, and a player who never uses ads never starts the SDK.
    //
    // The purchase store is opened by the scenario controller, not here: it
    // has to be listening before the store connects, because Play replays
    // restored and unfinished purchases the moment it does.
    unawaited(
      runOptionalService(
        'purchases',
        ref.read(scenarioPurchaseProvider.notifier).start,
      ),
    );
    // Started at the app root rather than at the match, because the score is
    // continuous across everything: it does not restart when a match begins, so
    // there is no seam at the one moment the table is paying most attention.
    //
    // The warm-up goes first and is awaited before the score starts, so the
    // session is configured while nothing is sounding. Configuring it *after* a
    // player exists is how the two ended up fighting over audio focus.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadNarrator();
      await _audio.warmUp();
      if (!mounted) return;
      // F19: the sonic mark as the app opens. Never on the web before a
      // gesture (browsers would refuse it, and a refused cue is a warning).
      if (!kIsWeb) {
        try {
          _audio.play(AudioCue.brandMotif);
        } on StateError {
          // A resumed match can open with the phone in a hand; then: silence.
        }
      }
      _syncScore();
    });
  }

  /// The system back control (Android's gesture or button).
  ///
  /// Registered in [initState], so this observer stands ahead of the router's
  /// own dispatcher: anything the Navigator can pop — a sheet, a dialog, the
  /// how-to-play cards — is left to it, and otherwise the screen's logical
  /// parent is shown instead of the activity finishing (see
  /// [systemBackTarget]).
  @override
  Future<bool> didPopRoute() async {
    if (_navigatorKey.currentState?.canPop() ?? false) return false;
    final location = _router.routerDelegate.currentConfiguration.uri.path;
    final target = systemBackTarget(
      location,
      hasGroups:
          ref.read(playerGroupsProvider).valueOrNull?.isNotEmpty ?? false,
    );
    if (target == null) return false;
    _router.go(target);
    return true;
  }

  String _lastPath = '/';

  void _routeChanged() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (path == _lastPath) return;
    final from = _lastPath;
    _lastPath = path;
    ref.read(interstitialCoordinatorProvider).navigated(from, path);
    if (kIsWeb) {
      if (path == Routes.mode) requestWebAd(ref, WebAdMoment.enterLocal);
      if (path == Routes.online) requestWebAd(ref, WebAdMoment.enterOnline);
      if (path == Routes.home && !_webAppOpenRequested) {
        _webAppOpenRequested = true;
        requestWebAd(ref, WebAdMoment.appOpen);
      }
    }
    if (path == Routes.home) _calmHome();
  }

  /// F13/P8 and P9 on arriving home. Both follow capabilities something else
  /// already loaded: `exists` first, so this never starts a request of its
  /// own and never delays a frame.
  void _calmHome() {
    if (!ref.exists(economyCapabilitiesProvider)) return;
    final caps = ref.read(economyCapabilitiesProvider).valueOrNull;
    if (caps == null) return;
    if (caps.metrics) unawaited(ref.read(firstOpenAttributionProvider).run());
    if (caps.reviewPrompt) _maybeAskForReview();
  }

  void _maybeAskForReview() {
    if (_router.routerDelegate.currentConfiguration.uri.path != Routes.home) {
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context != null) {
      unawaited(ref.read(reviewPromptProvider).maybeAsk(context));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The one thing that may silence the loop besides a setting: the app going
    // to the background. Leaving it running would have the phone playing music
    // from a pocket, and it is not information about the game either way.
    if (state == AppLifecycleState.resumed) {
      ref.read(interstitialCoordinatorProvider).foreground(true);
      _syncScore();
      // A vault capability read that could not reach the server is retried.
      retryCapabilitiesIfFailed(ref);
      if (SupabaseConfig.isConfigured) {
        unawaited(ref.read(playOffersProvider.notifier).start());
      }
      if (ref.exists(coinShopProvider)) {
        unawaited(ref.read(coinShopProvider.notifier).reload());
      }
    } else if (state == AppLifecycleState.paused) {
      ref.read(interstitialCoordinatorProvider).foreground(false);
      _audio.scoreEnabled = false;
      _audio.syncScore();
      _audio.scoreEnabled = _settingsScoreEnabled;
    }
  }

  bool get _settingsScoreEnabled =>
      ref.read(setupDraftProvider).settings.scoreEnabled;

  /// F16: the installed narrator pack, if any. A missing or unreadable
  /// manifest leaves the narrator silent; nothing else depends on it.
  Future<void> _loadNarrator() async {
    try {
      final source = await rootBundle.loadString(narratorManifest);
      _audio.narrator = NarratorBank.fromJson(source);
    } catch (_) {}
    for (final entry in narratorPackManifests.entries) {
      try {
        final source = await rootBundle.loadString(entry.value);
        _audio.registerNarratorBank(entry.key, NarratorBank.fromJson(source));
      } catch (_) {}
    }
  }

  void _syncScore() {
    final settings = ref.read(setupDraftProvider).settings;
    _audio
      ..scoreEnabled = settings.scoreEnabled
      ..narrationEnabled = settings.narrationEnabled
      ..muted = settings.muteAllAudio
      ..syncScore();
  }

  @override
  void dispose() {
    _paymentPush?.cancel();
    _paymentPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router.routerDelegate.removeListener(_routeChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WebAdRequest?>(webAdRequestProvider, (_, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_showWebAd(next.moment));
        });
      }
    });
    ref.listen(setupDraftProvider.select((draft) => draft.settings), (_, next) {
      _syncScore();
    });
    return MaterialApp.router(
      // `onGenerateTitle` rather than `title`, because this string is the
      // browser tab and the task-switcher label, and the app is Arabic-first.
      // A hardcoded Latin title would name an Arabic game in English on the
      // one surface outside the app's own frame.
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: MafiaTheme.dark,
      routerConfig: _router,
      locale: ref.watch(localeProvider),
      supportedLocales: const <Locale>[Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      // Wrapping here rather than inside a route means the unfinished-match
      // check runs once per launch, not on every visit to Home.
      // Two wrappers, outermost last. `SplashGate` has to be above everything
      // so the veil covers the resume prompt too — a dialog appearing through a
      // dissolve is the one thing that would make the handover look broken.
      //
      // Text scaling is pinned at 1.0 in both directions, above everything
      // else, so the clamp is in force for the splash, the resume dialog and
      // every route alike.
      //
      // # Why an app that is otherwise careful about accessibility does this
      //
      // This is a pass-the-phone game. Four roles have to produce *structurally
      // identical* night screens — same slots, same rects, same emitted light —
      // and the leakage suite asserts that by measuring pixels. A layout that
      // reflows under the OS font setting reflows by different amounts for
      // different strings, and the strings differ by role. At 130% the turn
      // header already overflowed its reservation by 13px. An overflow that
      // depends on how long a role's prompt is turns the OS font setting into a
      // channel that reports on the role.
      //
      // The cost is real and worth naming: a player who has enlarged type
      // system-wide does not get it here. That is a genuine loss of an
      // accessibility affordance, accepted because the alternative is a game
      // that leaks. The type scale is set generously for a dim table to
      // compensate, and 7:1 contrast is enforced by
      // `role_accent_parity_test.dart`.
      //
      // If this is ever relaxed, clamp to something like 1.0–1.15 rather than
      // removing it — that absorbs most real settings while keeping the
      // reserved slots intact — and re-run the whole leakage suite at the top
      // of the range, not just at 1.0.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.0,
        // A browser starts no sound before a tap; every tap offers the score
        // a second chance (`AudioBackend.unlock`, a no-op off the web).
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerUp: (_) => unawaited(_audio.unlock()),
          child: _MotionPreference(
            reduce: ref.watch(reduceMotionPreferenceProvider),
            // Phase 108: the app-open ad is considered only while the launch
            // picture is up. A pass-through in builds without an app-open unit.
            child: AppOpenGate(
              currentPath: () =>
                  _router.routerDelegate.currentConfiguration.uri.path,
              child: SplashGate(
                // First launch (and after an art update): read every asset and
                // warm the server behind «بنجهّز الترابيزة». Later launches warm
                // quietly in the background.
                child: WarmupGate(
                  child: ResumeGate(
                    navigatorKey: _navigatorKey,
                    // Inside the resume gate, not outside it: the resume prompt is a
                    // dialog and this is a route change, so the two are not competing
                    // for the same slot — but a first launch that also has an
                    // unfinished match must get the prompt, and `OnboardingGate` stands
                    // down on its own when it finds one.
                    child: OnboardingGate(
                      navigatorKey: _navigatorKey,
                      // An invite from inside the game, wherever the player
                      // is (never over a private phase).
                      child: IncomingInviteHost(
                        onJoin: (code) => _router.go(Routes.joinLink(code)),
                        child: UpdateGate(
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The in-game reduce-motion choice, added to the system one. Every animation
/// already asks `MediaQuery.disableAnimationsOf`, so this is the only place
/// that needs to know the setting exists.
class _MotionPreference extends StatelessWidget {
  final bool reduce;
  final Widget child;
  const _MotionPreference({required this.reduce, required this.child});

  @override
  Widget build(BuildContext context) {
    // Always the same wrapper: returning `child` bare while the setting is off
    // and a MediaQuery when it is on re-created the whole app under it (every
    // open screen lost its state) the moment the switch was flipped.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        disableAnimations: media.disableAnimations || reduce,
      ),
      child: child,
    );
  }
}
