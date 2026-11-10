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
/// No screen goes over the game while the ad is fetched (owner, 2026-11-10:
/// the «بنجهّز الإعلان» veil sat there until players killed the app). The
/// button that was tapped shows its own spinner, the attempt is bounded
/// ([MafiaTiming.adTapBudget]), and the flag below only tells buttons that
/// an attempt is running.
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
  // One frame for the button's spinner to paint (and for a second tap in the
  // same instant to find the attempt already running).
  await nextFrame();
  try {
    // Bounded: a voice link that never answers must not hold the veil up.
    if (micWasOpen) {
      await voice.setSelfMuted(true).timeout(MafiaTiming.adConsentInfoTimeout);
    }
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

/// Kept so the app shell's wrapper stays where it is: it draws nothing over
/// the game any more. A rewarded attempt is shown on the button that started
/// it (its spinner), never as a screen the player has to leave the app to
/// get out of.
class RewardedAdVeil extends StatelessWidget {
  final Widget child;
  const RewardedAdVeil({super.key, required this.child});

  static const veilKey = ValueKey('rewarded_ad_veil');

  @override
  Widget build(BuildContext context) => child;
}
