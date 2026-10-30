import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/public_web_origin.dart';
import '../platform/links/external_link.dart';
import '../data/motion_preference.dart';
import '../data/player_profile.dart' show playerProfileProvider;
import '../data/terms_consent.dart' show termsAcceptanceProvider;
import '../data/player_group_provider.dart';
import '../engine/models/enums.dart' show GamePhase;
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
import '../ui/economy/shell_banner_host.dart';
import '../ui/economy/coin_packs.dart';
import '../ui/economy/play_offers.dart';
import '../ui/economy/wallet.dart';
import '../ui/economy/web_ads.dart';
import '../platform/monetization/full_screen_away.dart';
import '../platform/monetization/web_ad_rules.dart';
import '../ui/economy/ad_veil.dart';
import '../ui/social/invite_privacy.dart';
import '../ui/theme/design_tokens.dart';
import '../platform/push/push_service.dart';
import '../ui/screens/online/online_session.dart'
    show SupabaseConfig, onlineSessionProvider;
import 'locale_controller.dart';
import '../data/story_catalog.dart' show StoryCatalog;
import '../ui/screens/online/council/council_band.dart' show CouncilBand;
import '../ui/widgets/add_to_home_sheet.dart' show AddToHome;
import '../ui/widgets/warmup_gate.dart';
import '../ui/social/incoming_invite.dart';
import '../ui/social/friends.dart' show showFriendsSheet;
import '../ui/economy/daily_rewards.dart' show DailyRewardsTab;
import '../ui/screens/setup/coin_store.dart' show CoinStore, CoinStoreStart;
import '../transport/account_auth.dart' show AccountProfile;
import '../transport/account_service.dart' show AccountFailure;
import '../ui/account/account_sheet.dart'
    show
        AccountSheet,
        AccountStep,
        accountAuthProvider,
        accountProfileProvider,
        passwordRecoveryProvider,
        showAccountSheet;
import '../ui/account/onboarding_account_step.dart'
    show accountsAvailableProvider;

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
  void _openOtherPush(PushOpen open) {
    switch (open.destination) {
      case PushDestination.onlineRoom:
        _router.go(
          ref.read(onlineSessionProvider).isInRoom
              ? Routes.lobby
              : Routes.online,
        );
        return;
      case PushDestination.onlineEntry:
        _router.go(Routes.online);
        return;
      case PushDestination.ownerAdmin:
        // The owner's notices open the admin page on the website, where
        // every review lives (owner, 2026-10-30).
        unawaited(
          Future.value(
            ref.read(externalLinkOpenerProvider)(
              '$kPublicWebOrigin${kOwnerPushPaths[open.kind]}',
            ),
          ),
        );
        return;
      case PushDestination.storeUpdate:
        unawaited(ref.read(storeOpenerProvider)());
        return;
      case PushDestination.daily:
      case PushDestination.orders:
      case PushDestination.friends:
        _router.go(Routes.home);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final context = _navigatorKey.currentContext;
          if (context == null) return;
          if (open.destination == PushDestination.daily) {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FractionallySizedBox(
                heightFactor: PassInventoryTokens.sheetHeight,
                child: SingleChildScrollView(child: DailyRewardsTab()),
              ),
            );
          } else if (open.destination == PushDestination.orders) {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const FractionallySizedBox(
                heightFactor: PassInventoryTokens.sheetHeight,
                child: CoinStore(start: CoinStoreStart.orders),
              ),
            );
          } else {
            showFriendsSheet(
              context,
              onJoin: (code) => _router.go(Routes.joinLink(code)),
            );
          }
        });
        return;
      case PushDestination.invite:
        return;
    }
  }

  /// Owned here, not global: two app instances in one test process would
  /// otherwise fight over the same key.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _paymentPush;
  Timer? _paymentPoll;
  bool _webAdShowing = false;
  bool _webAppOpenRequested = false;
  int _webCompletedMatches = 0;
  final WebBreakPacer _webPacer = WebBreakPacer(gap: WebAdTokens.minBreakGap);

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
    // Full-screen breaks are Google's only (owner, 2026-10-01): no house
    // creative between screens. With the provider on `house` (AdSense not
    // approved yet) there is no break at all; the bottom banner stays.
    if (caps.webAds.provider != 'adsense') return;
    // Back-navigation through /mode and /online must not chain breaks.
    if (!_webPacer.canStart(moment)) return;
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    _webAdShowing = true;
    ref.read(webBreakActiveProvider.notifier).state = true;
    try {
      // A plain hold covers the public screen while Google decides, so a
      // player cannot tap through to a private turn. Whether Google filled or
      // not, the hold closes when it answers (or times out).
      var closed = false;
      final dialog = showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: context.l10n.adBannerLabel,
        barrierColor: Theme.of(context).colorScheme.surface,
        transitionDuration: WebAdTokens.transition,
        pageBuilder: (_, _, _) => const WebAdHold(),
      );
      unawaited(dialog.whenComplete(() => closed = true));
      await needsHouseInterstitial(
        caps.webAds,
        moment,
        ref.read(webBreakAttemptProvider),
      );
      if (!closed && mounted && context.mounted) {
        _navigatorKey.currentState?.pop();
      }
      await dialog;
    } finally {
      _webAdShowing = false;
      _webPacer.breakEnded();
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
      // The council's rings and lights, decoded once in the background so the
      // first lobby shows them with the room instead of a beat later.
      CouncilBand.warmArt(rootBundle);
      await _loadNarrator();
      await _audio.warmUp();
      // The cases, read once the cues are ready, so the first Stories visit
      // finds them parsed.
      if (kOfferStories) StoryCatalog.prefetch();
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
    // A back pressed to leave a full-screen ad (again, while it was closing)
    // belongs to the ad: it never closes the vault, leaves a room or exits.
    if (FullScreenAway.swallowsBack()) return true;
    // Whatever is on top answers first: a sheet or dialog pops, and an
    // overlay that holds its own PopScope (the vault, opened from Home, a
    // menu or a waiting lobby) closes itself. Only then is the screen's
    // logical parent shown — the vault's back once dropped a player out of
    // their lobby.
    if (await _navigatorKey.currentState?.maybePop() ?? false) return true;
    // First run (or the terms prompt) stands in for whatever route is open,
    // and owns back itself: one chapter at a time (its PopScope). Going to
    // the route's logical parent instead built a new first-run screen at the
    // first chapter, so back from the name restarted onboarding.
    if (_setupPending()) return false;
    final location = _router.routerDelegate.currentConfiguration.uri.path;
    final target = systemBackTarget(
      location,
      hasGroups:
          ref.read(playerGroupsProvider).valueOrNull?.isNotEmpty ?? false,
    );
    if (target == null) return false;
    if (location == Routes.lobby) {
      final session = ref.read(onlineSessionProvider);
      if (session.isInRoom &&
          session.transport!.snapshot.phase != GamePhase.setup) {
        _router.go(Routes.match);
        return true;
      }
      await ref.read(onlineSessionProvider.notifier).leave();
      if (!mounted ||
          _router.routerDelegate.currentConfiguration.uri.path !=
              Routes.lobby) {
        return true;
      }
    }
    _router.go(target);
    return true;
  }

  /// Whether `SetupRequired` is showing the first-run screen over the route.
  bool _setupPending() {
    final profile = ref.read(playerProfileProvider);
    final terms = ref.read(termsAcceptanceProvider);
    if (profile.isLoading || terms.isLoading) return false;
    return profile.valueOrNull == null || terms.valueOrNull?.current != true;
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
    // iPhone browser tab only, once, after the first finished match.
    final homeContext = _navigatorKey.currentContext;
    if (kIsWeb && homeContext != null) {
      unawaited(AddToHome.maybeOffer(homeContext, ref));
    }
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
    for (final manifest in [narratorManifest, narratorFallbackManifest]) {
      try {
        final source = await rootBundle.loadString(manifest);
        final bank = NarratorBank.fromJson(source);
        if (bank.isEmpty) continue;
        _audio.narrator = bank;
        break;
      } catch (_) {}
    }
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

  /// A Google return refused because that Google account is already another
  /// player's, arriving when no account sheet is open (the app was closed
  /// while the browser was up, and the sheet with it). Without this the guest
  /// came back to Home, still a guest, told nothing. The player tapped Google
  /// to be that player, so it signs in to it; only a second refusal in a row
  /// opens the sheet with the two choices: sign in, or stay the guest.
  void _accountReturned(
    AsyncValue<AccountProfile>? _,
    AsyncValue<AccountProfile> next,
  ) {
    final failure = next.error;
    if (!next.hasError || failure is! AccountFailure) return;
    if (failure.code != 'EMAIL_TAKEN' || AccountSheet.isOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (await ref.read(accountAuthProvider).switchToTakenGoogle()) return;
      } on AccountFailure {
        /* Said by the sheet below. */
      }
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted || AccountSheet.isOpen) return;
      unawaited(showAccountSheet(context, failure: failure.code));
    });
  }

  /// A password-reset link signed this device in: it came for a new password,
  /// so the account screen opens on that step. An account screen already open
  /// is left alone; its own code step still finishes the reset.
  void _passwordRecovered() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted || AccountSheet.isOpen) return;
      unawaited(showAccountSheet(context, initial: AccountStep.password));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(accountsAvailableProvider)) {
      ref.listen<AsyncValue<AccountProfile>>(
        accountProfileProvider,
        _accountReturned,
      );
      ref.listen<AsyncValue<int>>(passwordRecoveryProvider, (_, next) {
        if (next.hasValue) _passwordRecovered();
      });
    }
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
                    // dialog and this is a route change.
                    // An invite from inside the game, wherever the player
                    // is (never over a private phase).
                    child: IncomingInviteHost(
                      onJoin: (code) => _router.go(Routes.joinLink(code)),
                      onOtherPush: _openOtherPush,
                      child: UpdateGate(
                        currentPath: () => _router
                            .routerDelegate
                            .currentConfiguration
                            .uri
                            .path,
                        routeChanges: _router.routerDelegate,
                        // Over every route and overlay (the vault included):
                        // the instant answer to a tap on a rewarded offer.
                        child: RewardedAdVeil(
                          // WP4: the one banner (banner_mode = shell). Under
                          // the veil, above the router; a pass-through
                          // column in every other mode.
                          child: ShellBannerHost(
                            currentPath: () => _router
                                .routerDelegate
                                .currentConfiguration
                                .uri
                                .path,
                            routeChanges: _router.routerDelegate,
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
