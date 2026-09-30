import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/links/external_link.dart';
import '../../platform/monetization/web_ad_bridge.dart';
import '../../platform/monetization/web_ad_rules.dart';
import '../social/invite_privacy.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'economy_capabilities.dart';

const kWebAdsenseClient = String.fromEnvironment(
  'WEB_ADSENSE_CLIENT',
  defaultValue:
      'ca-pub-'
      '91790639'
      '36085117',
);
const kWebAdsenseBannerSlot = String.fromEnvironment('WEB_ADSENSE_BANNER_SLOT');
const kPlayListing =
    'https://play.google.com/store/apps/details?id=com.mafiamaster.mafia_master';

typedef WebBreakAttempt =
    Future<bool> Function(String client, String type, String name);
typedef WebBannerAttempt = Future<bool> Function(String client, String slot);

final webBreakAttemptProvider = Provider<WebBreakAttempt>((_) => tryH5Break);
final webBannerAttemptProvider = Provider<WebBannerAttempt>((_) => tryH5Banner);
final webAdsPlatformProvider = Provider<bool>((_) => kIsWeb);
final webBannerSlotProvider = Provider<String>((_) => kWebAdsenseBannerSlot);
final webBreakActiveProvider = StateProvider<bool>((_) => false);

Future<bool> needsHouseInterstitial(
  WebAdRules rules,
  WebAdMoment moment,
  WebBreakAttempt attempt,
) async {
  if (rules.provider != 'adsense') return true;
  try {
    return !await attempt(
      kWebAdsenseClient,
      moment == WebAdMoment.appOpen ? 'start' : 'next',
      moment.name,
    );
  } catch (_) {
    return true;
  }
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
  bool _googleFilled = false;
  bool _requested = false;

  @override
  void dispose() {
    hideH5Banner();
    super.dispose();
  }

  Future<void> _probe() async {
    var filled = false;
    try {
      filled = await ref.read(webBannerAttemptProvider)(
        kWebAdsenseClient,
        ref.read(webBannerSlotProvider),
      );
    } catch (_) {
      // Blockers and incomplete approval must leave the house slot intact.
    }
    if (!mounted || ref.read(privateMomentProvider)) {
      hideH5Banner();
      return;
    }
    setState(() => _googleFilled = filled);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(webAdsPlatformProvider) ||
        ref.watch(webBreakActiveProvider) ||
        ref.watch(privateMomentProvider)) {
      hideH5Banner();
      _googleFilled = false;
      _requested = false;
      return const SizedBox.shrink();
    }
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull;
    if (caps == null ||
        !caps.webAds.allows(
          WebAdMoment.banner,
          privatePhase: false,
          adFree: caps.automaticAdsDisabled,
        )) {
      hideH5Banner();
      _googleFilled = false;
      _requested = false;
      return const SizedBox.shrink();
    }
    if (!_requested &&
        caps.webAds.provider == 'adsense' &&
        ref.watch(webBannerSlotProvider).isNotEmpty) {
      _requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_probe());
      });
    }
    final colors = context.colors;
    final spacing = context.spacing;
    return SafeArea(
      top: false,
      child: SizedBox(
        key: WebAdBanner.slotKey,
        height: WebAdTokens.bannerHeight,
        child: _googleFilled
            ? const SizedBox.expand()
            : Material(
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
