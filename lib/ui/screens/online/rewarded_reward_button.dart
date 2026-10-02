import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/audio_director.dart';
import '../../../platform/monetization/rewarded_ads.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/settings_kit.dart';
import 'online_session.dart';
import 'voice_session.dart';

class RewardedRewardButton extends ConsumerStatefulWidget {
  final String roomId;
  const RewardedRewardButton({super.key, required this.roomId});

  static const actionKey = ValueKey('result_rewarded_ad');

  @override
  ConsumerState<RewardedRewardButton> createState() =>
      _RewardedRewardButtonState();
}

class _RewardedRewardButtonState extends ConsumerState<RewardedRewardButton> {
  bool _busy = false;
  bool _awarded = false;

  /// Waiting on AdMob's signed callback. Only while we are actively checking:
  /// a claim the server still calls "pending" may just as well be an ad that
  /// was closed early or never filled, and that must stay retryable. The
  /// server grants at most one credit per claim, so a retry cannot double it.
  bool _pending = false;
  int _amount = 100;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<Map<String, dynamic>> _call(String action) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', {'action': action, 'roomId': widget.roomId});
  }

  Future<void> _recover() async {
    if (!ref.read(rewardedAdsProvider).configured) return;
    try {
      final status = await _call('ad_status');
      if (!mounted) return;
      setState(() {
        _amount = (status['amount'] as num?)?.toInt() ?? 100;
        _awarded = status['state'] == 'awarded';
      });
      // A reward verified while the app was closed shows up here; one that is
      // still on its way gets a short look before the button is offered again.
      if (status['state'] == 'pending') await _awaitAward();
    } catch (_) {
      // A reward status is optional UI; the match result remains usable.
    }
  }

  /// Polls for the signed callback. Returns whether the reward landed.
  Future<bool> _awaitAward() async {
    if (mounted) setState(() => _pending = true);
    try {
      for (var attempt = 0; attempt < 6; attempt++) {
        await Future<void>.delayed(MafiaTiming.adRewardPoll);
        if (!mounted) return false;
        final status = await _call('ad_status');
        if (status['state'] == 'awarded') {
          if (mounted) setState(() => _awarded = true);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  /// Shows the ad with the table silenced: the player's microphone would
  /// otherwise carry the ad's audio into the room, and the score would play
  /// over it. Both are put back exactly as they were, whatever the outcome.
  Future<RewardedAdOutcome> _showSilenced(String claimId, String userId) async {
    final voice = ref.read(voiceControllerProvider);
    final audio = ref.read(audioDirectorProvider);
    final micWasOpen = voice != null && !voice.selfMuted;
    final audioWasMuted = audio.muted;
    try {
      if (micWasOpen) await voice.setSelfMuted(true);
    } catch (_) {
      // Voice is never load-bearing; the ad still runs.
    }
    audio.muted = true;
    try {
      return await ref
          .read(rewardedAdsProvider)
          .show(claimId: claimId, userId: userId);
    } finally {
      audio.muted = audioWasMuted;
      try {
        if (micWasOpen) await voice.setSelfMuted(false);
      } catch (_) {}
    }
  }

  Future<void> _show() async {
    if (_busy || _awarded) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      final userId = await backend.ensureSession();
      await backend.call('economy', {'action': 'sync'});
      final claim = await _call('create_ad_claim');
      _amount = (claim['amount'] as num?)?.toInt() ?? 100;
      if (claim['state'] == 'awarded') {
        if (mounted) setState(() => _awarded = true);
        return;
      }
      final outcome = await _showSilenced(claim['claimId'] as String, userId);
      if (!mounted) return;
      if (outcome == RewardedAdOutcome.earned) {
        if (await _awaitAward()) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.adRewardGranted(_amount))));
          }
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.adRewardPending)));
        }
      } else if (outcome == RewardedAdOutcome.unavailable ||
          outcome == RewardedAdOutcome.failed) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.adRewardUnavailable)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.adRewardUnavailable)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(rewardedAdsProvider).configured) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: RewardedRewardButton.actionKey,
            onPressed: _busy || _awarded || _pending ? null : _show,
            icon: _busy
                ? SizedBox.square(
                    dimension: spacing.md,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ondemand_video_outlined),
            label: Text(
              _awarded
                  ? l.adRewardUsed
                  : _pending
                  ? l.adRewardPending
                  : l.adRewardAction(_amount),
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(l.adRewardHint, style: context.typography.caption),
        ],
      ),
    );
  }
}

class AdPrivacyButton extends ConsumerStatefulWidget {
  const AdPrivacyButton({super.key});

  @override
  ConsumerState<AdPrivacyButton> createState() => _AdPrivacyButtonState();
}

class _AdPrivacyButtonState extends ConsumerState<AdPrivacyButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Status only: opening Settings never shows a consent form or starts
      // the ad SDK.
      final ads = ref.read(rewardedAdsProvider);
      if (!ads.configured) return;
      final required = await ads.checkPrivacyOptions();
      if (mounted) setState(() => _visible = required);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return SettingsLinkRow(
      icon: Icons.ads_click_outlined,
      label: context.l10n.privacyChoices,
      hint: context.l10n.privacyChoicesHint,
      onTap: () => ref.read(rewardedAdsProvider).showPrivacyOptions(),
    );
  }
}
