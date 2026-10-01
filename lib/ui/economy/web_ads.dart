import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/links/external_link.dart';
import '../../platform/monetization/web_ad_bridge.dart';
import '../../platform/monetization/web_ad_rules.dart';
import '../social/invite_privacy.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'economy_capabilities.dart';
import 'web_banner_controller.dart';

/// Must equal the publisher id in web/index.html, web/ads.txt and
/// web/app-ads.txt (tool/web_publisher_consistency.test.mjs enforces it).
/// See docs/WEB-ADS-SETUP.md.
const kWebAdsenseClient = String.fromEnvironment(
  'WEB_ADSENSE_CLIENT',
  defaultValue: 'ca-pub-9179063936085117',
);
const kWebAdsenseBannerSlot = String.fromEnvironment('WEB_ADSENSE_BANNER_SLOT');
const kPlayListing =
    'https://play.google.com/store/apps/details?id=com.mafiamaster.mafia_master';

typedef WebBreakAttempt =
    Future<bool> Function(String client, String type, String name);

final webBreakAttemptProvider = Provider<WebBreakAttempt>((_) => tryH5Break);
final webAdsPlatformProvider = Provider<bool>((_) => kIsWeb);

/// The build-time banner slot, used when the server has none. A slot the
/// server sends (`web_ads_banner_slot`) always wins, so a new slot needs no
/// rebuild.
final webBannerSlotProvider = Provider<String>((_) => kWebAdsenseBannerSlot);
final webBreakActiveProvider = StateProvider<bool>((_) => false);

String effectiveBannerSlot(WebAdRules rules, String buildTimeSlot) =>
    rules.bannerSlot.isNotEmpty ? rules.bannerSlot : buildTimeSlot;

/// Whether the house break must be shown. For Google, waits for the attempt
/// (bounded by [timeout]) before answering, so the house creative never
/// flashes ahead of a Google break; a Google result that arrives after the
/// answer is ignored because nothing is listening to it any more.
Future<bool> needsHouseInterstitial(
  WebAdRules rules,
  WebAdMoment moment,
  WebBreakAttempt attempt, {
  Duration timeout = WebAdTokens.googleBreakTimeout,
}) async {
  if (rules.provider != 'adsense') return true;
  final answer = Completer<bool>();
  void settle(bool shown) {
    if (!answer.isCompleted) answer.complete(shown);
  }

  final timer = Timer(timeout, () => settle(false));
  try {
    attempt(
      kWebAdsenseClient,
      moment == WebAdMoment.appOpen ? 'start' : 'next',
      moment.name,
    ).then(settle, onError: (Object _) => settle(false));
  } catch (_) {
    settle(false);
  }
  final shown = await answer.future;
  timer.cancel();
  return !shown;
}

/// A visible house creative is the default inventory; Google may replace it
/// only after a real fill. This widget is never mounted on a private table.
class WebAdBanner extends ConsumerStatefulWidget {
  const WebAdBanner({super.key});
  static const slotKey = ValueKey('web_ad_banner');
  static const appCtaKey = ValueKey('web_ad_play_cta');

  @override
  ConsumerState<WebAdBanner> createState() => _WebAdBannerState();
}

class _WebAdBannerState extends ConsumerState<WebAdBanner> {
  final GlobalKey _boxKey = GlobalKey();
  late final WebBannerController _controller;
  WebBannerClaim? _claim;
  ModalRoute<dynamic>? _route;
  bool _googleFilled = false;
  bool _syncQueued = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(webBannerControllerProvider);
    // Everything that can change whether this banner may own the Google
    // overlay is observed here, never from build().
    for (final provider in <ProviderListenable<Object?>>[
      webBreakActiveProvider,
      privateMomentProvider,
      economyCapabilitiesProvider,
      webBannerSlotProvider,
    ]) {
      ref.listenManual<Object?>(provider, (_, _) => _queueSync());
    }
    _queueSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribing to the route also tells us when it stops being the current
    // one (a screen or sheet opened over it).
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _detachRoute();
      _route = route;
      route?.animation?.addStatusListener(_onRouteMotion);
      route?.secondaryAnimation?.addStatusListener(_onRouteMotion);
    }
    _queueSync();
  }

  void _detachRoute() {
    _route?.animation?.removeStatusListener(_onRouteMotion);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteMotion);
  }

  void _onRouteMotion(AnimationStatus _) => _queueSync();

  @override
  void dispose() {
    _detachRoute();
    final claim = _claim;
    if (claim != null) _controller.release(claim);
    _claim = null;
    super.dispose();
  }

  /// Settled and on top: the slot is not sliding and nothing covers it.
  bool get _routeReady {
    final route = _route;
    if (route == null) return true;
    return route.isCurrent &&
        (route.animation?.status ?? AnimationStatus.completed) ==
            AnimationStatus.completed &&
        (route.secondaryAnimation?.status ?? AnimationStatus.dismissed) ==
            AnimationStatus.dismissed;
  }

  void _queueSync() {
    if (_syncQueued) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (mounted) _sync();
    });
  }

  String? _wantedSlot() {
    if (!ref.read(webAdsPlatformProvider) ||
        ref.read(webBreakActiveProvider) ||
        ref.read(privateMomentProvider) ||
        !_routeReady) {
      return null;
    }
    final caps = ref.read(economyCapabilitiesProvider).valueOrNull;
    if (caps == null ||
        caps.webAds.provider != 'adsense' ||
        !caps.webAds.allows(
          WebAdMoment.banner,
          privatePhase: false,
          adFree: caps.automaticAdsDisabled,
        )) {
      return null;
    }
    final slot = effectiveBannerSlot(
      caps.webAds,
      ref.read(webBannerSlotProvider),
    );
    return slot.isEmpty ? null : slot;
  }

  void _sync() {
    final slot = _wantedSlot();
    var claim = _claim;
    if (claim != null && claim.slot != slot) {
      _controller.release(claim);
      _claim = claim = null;
      if (_googleFilled) setState(() => _googleFilled = false);
    }
    if (slot != null && claim == null) {
      _claim = WebBannerClaim(
        client: kWebAdsenseClient,
        slot: slot,
        rect: _slotRect,
        onFilled: _onFilled,
      );
      _controller.claim(_claim!);
    }
  }

  Rect? _slotRect() {
    final box = _boxKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _onFilled(bool filled) {
    if (!mounted || filled == _googleFilled) return;
    setState(() => _googleFilled = filled);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(webAdsPlatformProvider) ||
        ref.watch(webBreakActiveProvider) ||
        ref.watch(privateMomentProvider)) {
      return const SizedBox.shrink();
    }
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull;
    if (caps == null ||
        !caps.webAds.allows(
          WebAdMoment.banner,
          privatePhase: false,
          adFree: caps.automaticAdsDisabled,
        )) {
      return const SizedBox.shrink();
    }
    final colors = context.colors;
    final spacing = context.spacing;
    return SafeArea(
      top: false,
      child: SizedBox(
        key: WebAdBanner.slotKey,
        height: WebAdTokens.bannerHeight,
        child: _googleFilled
            ? SizedBox.expand(key: _boxKey)
            : Material(
                key: _boxKey,
                color: colors.surfaceRaised,
                child: InkWell(
                  key: WebAdBanner.appCtaKey,
                  onTap: () =>
                      ref.read(externalLinkOpenerProvider)(kPlayListing),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.md),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/store_v3/quiet_pass_cover.webp',
                          width: WebAdTokens.bannerArt,
                          height: WebAdTokens.bannerArt,
                        ),
                        const SizedBox(width: WebAdTokens.bannerGap),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.webAdAppCta,
                                style: context.typography.title.copyWith(
                                  color: colors.accentGold,
                                ),
                              ),
                              Text(
                                context.l10n.webAdPlayCaption,
                                style: context.typography.caption.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.open_in_new, color: colors.accentGold),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A full-screen house break with a timed close control. No role or match fact
/// appears in the creative, and no action is available before the countdown.
class HouseWebInterstitial extends StatefulWidget {
  final WebAdMoment moment;
  const HouseWebInterstitial({super.key, required this.moment});
  static const closeKey = ValueKey('web_house_ad_close');

  @override
  State<HouseWebInterstitial> createState() => _HouseWebInterstitialState();
}

/// Shown while a Google break is being decided: the plain ground, no creative,
/// so the public screen cannot be tapped through and the house art never
/// flashes before a Google break. Swapped for [HouseWebInterstitial] only if
/// Google reports no fill.
class WebAdHold extends StatelessWidget {
  const WebAdHold({super.key});
  static const holdKey = ValueKey('web_ad_hold');

  @override
  Widget build(BuildContext context) =>
      Scaffold(key: holdKey, backgroundColor: context.colors.surfaceBase);
}

class WebAdRequest {
  final WebAdMoment moment;
  final int sequence;
  const WebAdRequest(this.moment, this.sequence);
}

final webAdRequestProvider = StateProvider<WebAdRequest?>((_) => null);

void requestWebAd(WidgetRef ref, WebAdMoment moment) {
  if (!ref.read(webAdsPlatformProvider)) return;
  final notifier = ref.read(webAdRequestProvider.notifier);
  notifier.state = WebAdRequest(moment, (notifier.state?.sequence ?? 0) + 1);
}

class _HouseWebInterstitialState extends State<HouseWebInterstitial> {
  Timer? _timer;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(WebAdTokens.closeDelay, () {
      if (mounted) setState(() => _canClose = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final isApp =
        widget.moment == WebAdMoment.appOpen ||
        widget.moment == WebAdMoment.afterMatch;
    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: WebAdTokens.interstitialMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.all(WebAdTokens.interstitialPad),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      isApp
                          ? 'assets/images/store_v3/quiet_pass_cover.webp'
                          : 'assets/images/council/council_hub_tab.webp',
                      width: WebAdTokens.interstitialArt,
                      height: WebAdTokens.interstitialArt,
                    ),
                    SizedBox(height: spacing.lg),
                    Text(
                      isApp
                          ? context.l10n.webAdAppCta
                          : context.l10n.webAdCouncilTitle,
                      textAlign: TextAlign.center,
                      style: context.typography.display.copyWith(
                        color: colors.accentGold,
                      ),
                    ),
                    SizedBox(height: spacing.md),
                    Text(
                      isApp
                          ? context.l10n.webAdPlayBody
                          : context.l10n.webAdCouncilBody,
                      textAlign: TextAlign.center,
                      style: context.typography.body.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(height: spacing.lg),
                    if (isApp)
                      FilledButton(
                        onPressed: () {
                          final open = ProviderScope.containerOf(
                            context,
                            listen: false,
                          ).read(externalLinkOpenerProvider);
                          Navigator.of(context).pop();
                          open(kPlayListing);
                        },
                        child: Text(context.l10n.webAdOpenPlay),
                      ),
                    SizedBox(height: spacing.lg),
                    TextButton(
                      key: HouseWebInterstitial.closeKey,
                      onPressed: _canClose
                          ? () => Navigator.of(context).pop()
                          : null,
                      child: Text(
                        _canClose
                            ? context.l10n.webAdContinue
                            : context.l10n.webAdCountdown,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
