import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/monetization/rewarded_ads.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import 'online_session.dart';

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
        _pending = status['state'] == 'pending';
      });
    } catch (_) {
      // A reward status is optional UI; the match result remains usable.
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
      final outcome = await ref
          .read(rewardedAdsProvider)
          .show(claimId: claim['claimId'] as String, userId: userId);
      if (!mounted) return;
      if (outcome == RewardedAdOutcome.earned) {
        setState(() => _pending = true);
        for (var attempt = 0; attempt < 6 && mounted; attempt++) {
          await Future<void>.delayed(MafiaTiming.rewardStatusPoll);
          final status = await _call('ad_status');
          if (status['state'] == 'awarded') {
            if (mounted) {
              setState(() {
                _awarded = true;
                _pending = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.adRewardGranted(_amount))),
              );
            }
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.adRewardPending)));
        }
      } else if (outcome == RewardedAdOutcome.unavailable ||
          outcome == RewardedAdOutcome.failed) {
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
      final ads = ref.read(rewardedAdsProvider);
      await ads.initialize();
      if (mounted) setState(() => _visible = ads.privacyOptionsRequired);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.privacy_tip_outlined),
      title: Text(context.l10n.privacyChoices),
      subtitle: Text(context.l10n.privacyChoicesHint),
      onTap: () => ref.read(rewardedAdsProvider).showPrivacyOptions(),
    );
  }
}
