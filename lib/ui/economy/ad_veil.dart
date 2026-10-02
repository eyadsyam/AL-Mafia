import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/audio_director.dart';
import '../../platform/monetization/rewarded_ads.dart';
import '../l10n_ext.dart';
import '../screens/online/voice_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'interstitial_coordinator.dart';

/// Up from the moment a rewarded offer is tapped until the attempt ends. The
/// veil itself steps aside as soon as the ad covers the game.
final rewardedAdLoadingProvider = StateProvider<bool>((ref) => false);

/// `ref.read` of either a widget or a provider.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// Shows a rewarded ad with the table silenced: the player's microphone would
/// otherwise carry the ad's audio into the room, and the score would play
/// over it. Both are put back exactly as they were, whatever the outcome.
///
/// The tap is answered at once: the loading veil goes up and gets one frame
/// to paint before any SDK or platform-channel work starts, so a slow first
/// ad never looks like a frozen phone.
Future<RewardedAdOutcome> showRewardedWith(
  ProviderReader read, {
  required String customData,
  required String userId,
  required RewardedPlacement placement,
}) async {
  final veil = read(rewardedAdLoadingProvider.notifier);
  final voice = read(voiceControllerProvider);
  final audio = read(audioDirectorProvider);
  final coordinator = read(interstitialCoordinatorProvider);
  final micWasOpen = voice != null && !voice.selfMuted;
  final audioWasMuted = audio.muted;
  veil.state = true;
  await nextFrame();
  try {
    if (micWasOpen) await voice.setSelfMuted(true);
  } catch (_) {
    // Voice is never load-bearing; the ad still runs.
  }
  audio.muted = true;
  try {
    final outcome = await read(
      rewardedAdsProvider,
    ).show(claimId: customData, userId: userId, placement: placement);
    if (outcome == RewardedAdOutcome.earned ||
        outcome == RewardedAdOutcome.dismissed) {
      unawaited(coordinator.rewardedShown());
    }
    return outcome;
  } finally {
    audio.muted = audioWasMuted;
    veil.state = false;
    try {
      if (micWasOpen) await voice.setSelfMuted(false);
    } catch (_) {}
  }
}

/// Waits for the frame in progress (or the next one) to be drawn, bounded:
/// a phone that is not drawing (backgrounded) never holds a tap up.
Future<void> nextFrame() async {
  try {
    final binding = SchedulerBinding.instance;
    binding.ensureVisualUpdate();
    await binding.endOfFrame.timeout(AdTokens.loadingVeilFade);
  } catch (_) {
    // No binding (a plain unit test) or no frame in time: carry on.
  }
}

/// The instant, light answer to a tap on a rewarded offer: a dim veil with a
/// spinner and one line, over every route and overlay. No blur and no art,
/// so it costs nothing to draw while the ad SDK works.
class RewardedAdVeil extends ConsumerStatefulWidget {
  final Widget child;
  const RewardedAdVeil({super.key, required this.child});

  static const veilKey = ValueKey('rewarded_ad_veil');

  @override
  ConsumerState<RewardedAdVeil> createState() => _RewardedAdVeilState();
}

class _RewardedAdVeilState extends ConsumerState<RewardedAdVeil>
    with WidgetsBindingObserver {
  /// The ad has covered the game since the veil went up: it stays down, so
  /// it never flashes back while the player returns from the ad.
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        !_covered &&
        ref.read(rewardedAdLoadingProvider)) {
      setState(() => _covered = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(rewardedAdLoadingProvider, (_, next) {
      if (next && _covered) setState(() => _covered = false);
    });
    final visible = ref.watch(rewardedAdLoadingProvider) && !_covered;
    final colors = context.colors;
    // Always the same Stack, so raising the veil never remounts the app.
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AdTokens.loadingVeilFade,
              child: visible
                  ? Semantics(
                      key: RewardedAdVeil.veilKey,
                      liveRegion: true,
                      label: context.l10n.adPreparing,
                      child: Material(
                        type: MaterialType.canvas,
                        color: colors.surfaceBase.withValues(
                          alpha: AdTokens.loadingVeilAlpha,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: AdTokens.loadingVeilSpinner,
                                child: CircularProgressIndicator(
                                  strokeWidth: AdTokens.loadingVeilStroke,
                                  color: colors.accentGold,
                                ),
                              ),
                              SizedBox(height: context.spacing.sm),
                              ExcludeSemantics(
                                child: Text(
                                  context.l10n.adPreparing,
                                  style: context.typography.body.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
