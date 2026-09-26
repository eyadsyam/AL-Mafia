import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/audio_director.dart';
import '../../../platform/monetization/rewarded_ads.dart';
import '../../economy/economy_capabilities.dart';
import '../../economy/interstitial_coordinator.dart';
import '../../economy/reward_poll.dart';
import '../../economy/wallet.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/settings_kit.dart';
import 'online_session.dart';
import 'voice_session.dart';

/// Shows a rewarded ad with the table silenced: the player's microphone would
/// otherwise carry the ad's audio into the room, and the score would play
/// over it. Both are put back exactly as they were, whatever the outcome.
Future<RewardedAdOutcome> showRewardedSilenced(
  WidgetRef ref, {
  required String customData,
  required String userId,
  required RewardedPlacement placement,
}) async {
  final voice = ref.read(voiceControllerProvider);
  final audio = ref.read(audioDirectorProvider);
  final coordinator = ref.read(interstitialCoordinatorProvider);
  final micWasOpen = voice != null && !voice.selfMuted;
  final audioWasMuted = audio.muted;
  try {
    if (micWasOpen) await voice.setSelfMuted(true);
  } catch (_) {
    // Voice is never load-bearing; the ad still runs.
  }
  audio.muted = true;
  try {
    final outcome = await ref
        .read(rewardedAdsProvider)
        .show(claimId: customData, userId: userId, placement: placement);
    if (outcome == RewardedAdOutcome.earned ||
        outcome == RewardedAdOutcome.dismissed) {
      unawaited(coordinator.rewardedShown());
    }
    return outcome;
  } finally {
    audio.muted = audioWasMuted;
    try {
      if (micWasOpen) await voice.setSelfMuted(false);
    } catch (_) {}
  }
}

/// One post-match step as the server describes it.
class _Step {
  final int step;
  final int amount;
  final String state;
  const _Step(this.step, this.amount, this.state);
  bool get awarded => state == 'awarded';
}

enum _Mode { loading, legacy, steps }

/// The optional post-match reward.
///
/// Against a 1.0.0 server (or when the server has the two-step offer off) it
/// is the original single ad for the match's completion coins. Against a
/// 1.0.1 server it is two optional steps, each worth half, both amounts shown
/// before the first tap; a step that was verified is kept whatever happens to
/// the next one. A match whose single-ad claim already exists stays single.
class RewardedRewardButton extends ConsumerStatefulWidget {
  final String roomId;
  const RewardedRewardButton({super.key, required this.roomId});

  static const actionKey = ValueKey('result_rewarded_ad');
  static Key stepKey(int step) => ValueKey('result_rewarded_step_$step');
  static const checkAgainKey = ValueKey('result_rewarded_check');

  @override
  ConsumerState<RewardedRewardButton> createState() =>
      _RewardedRewardButtonState();
}

class _RewardedRewardButtonState extends ConsumerState<RewardedRewardButton>
    with WidgetsBindingObserver {
  _Mode _mode = _Mode.loading;
  bool _busy = false;
  bool _awarded = false;

  /// Waiting on AdMob's signed callback. Only while actively checking: a
  /// claim the server still calls "pending" may just as well be an ad that
  /// was closed early or never filled, and that must stay retryable. The
  /// server grants at most one credit per claim, so a retry cannot double it.
  bool _pending = false;

  /// The check window ran out after an earned ad; offer a manual recheck.
  bool _stale = false;
  int _amount = 100;
  List<_Step> _steps = const [];

  /// Bumped on dispose and on every new poll, so an older poll stops quietly.
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A reward verified while the app was in the background shows on return.
    if (state == AppLifecycleState.resumed && (_stale || _pending)) {
      unawaited(_checkOnce());
    }
  }

  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, Object?> extra = const {},
  ]) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', {
      'action': action,
      'roomId': widget.roomId,
      ...extra,
    });
  }

  void _say(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  // --- status ----------------------------------------------------------------

  Future<void> _load() async {
    if (!ref.read(rewardedAdsProvider).configured) return;
    var caps = EconomyCapabilities.none;
    try {
      caps = await ref.read(economyCapabilitiesProvider.future);
    } catch (_) {}
    if (!mounted) return;
    if (caps.adSteps) {
      try {
        final status = await _call('ad_steps_status_v2');
        if (!mounted) return;
        _apply(status);
        if (_mode == _Mode.legacy && status['state'] == 'pending') {
          await _recoverPoll();
        }
        return;
      } catch (_) {
        // Fall through to the single-ad offer every server understands.
      }
    }
    await _loadLegacy();
  }

  Future<void> _loadLegacy() async {
    try {
      final status = await _call('ad_status');
      if (!mounted) return;
      setState(() {
        _mode = _Mode.legacy;
        _amount = (status['amount'] as num?)?.toInt() ?? 100;
        _awarded = status['state'] == 'awarded';
      });
      // A reward verified while the app was closed shows up here; one that
      // is still on its way gets a short look before the offer returns.
      if (status['state'] == 'pending') await _recoverPoll();
    } catch (_) {
      // A reward status is optional UI; the match result remains usable.
      if (mounted) setState(() => _mode = _Mode.legacy);
    }
  }

  /// Reads either server answer into the screen's state.
  void _apply(Map<String, dynamic> status) {
    if (status['scheme'] == 'v1') {
      setState(() {
        _mode = _Mode.legacy;
        _amount = (status['amount'] as num?)?.toInt() ?? _amount;
        _awarded = status['state'] == 'awarded';
      });
      return;
    }
    final steps = [
      for (final row in (status['steps'] as List?) ?? const [])
        if (row is Map)
          _Step(
            (row['step'] as num?)?.toInt() ?? 0,
            (row['amount'] as num?)?.toInt() ?? 0,
            row['state'] as String? ?? 'available',
          ),
    ]..sort((a, b) => a.step.compareTo(b.step));
    if (steps.length != 2) {
      // An answer this build cannot draw: offer the single ad every server
      // understands rather than a button stuck on loading.
      if (_mode != _Mode.legacy) unawaited(_loadLegacy());
      return;
    }
    setState(() {
      _mode = _Mode.steps;
      _steps = steps;
      _amount = (status['total'] as num?)?.toInt() ?? _amount;
      _awarded = steps.every((s) => s.awarded);
    });
  }

  Future<bool> _isAwarded({int? step}) async {
    if (_mode == _Mode.steps) {
      final status = await _call('ad_steps_status_v2');
      if (!mounted) return false;
      _apply(status);
      if (step == null) return _awarded;
      return _steps.any((s) => s.step == step && s.awarded);
    }
    final status = await _call('ad_status');
    final done = status['state'] == 'awarded';
    if (done && mounted) setState(() => _awarded = true);
    return done;
  }

  Future<void> _recoverPoll() async {
    final epoch = ++_epoch;
    if (mounted) setState(() => _pending = true);
    await pollForReward(
      awarded: () => _isAwarded(),
      alive: () => mounted && epoch == _epoch,
      cap: MafiaTiming.adRewardPoll,
      window: MafiaTiming.adRewardRecoverWindow,
    );
    if (mounted && epoch == _epoch) setState(() => _pending = false);
  }

  /// After an earned ad: the full bounded wait. Returns whether it landed.
  Future<bool> _awaitAward({int? step}) async {
    final epoch = ++_epoch;
    if (mounted) {
      setState(() {
        _pending = true;
        _stale = false;
      });
    }
    final landed = await pollForReward(
      awarded: () => _isAwarded(step: step),
      alive: () => mounted && epoch == _epoch,
    );
    if (mounted && epoch == _epoch) {
      setState(() {
        _pending = false;
        _stale = !landed;
      });
    }
    if (landed) ref.invalidate(walletProvider);
    return landed;
  }

  Future<void> _checkOnce() async {
    try {
      final landed = await _isAwarded();
      if (!mounted) return;
      if (landed || _mode == _Mode.steps) {
        setState(() => _stale = false);
        ref.invalidate(walletProvider);
      }
    } catch (_) {}
  }

  // --- actions ---------------------------------------------------------------

  void _sayOutcome(RewardedAdOutcome outcome) {
    final l = context.l10n;
    switch (outcome) {
      case RewardedAdOutcome.unavailable:
      case RewardedAdOutcome.failed:
        _say(l.adRewardUnavailable);
      case RewardedAdOutcome.notConsented:
        _say(l.adRewardNotConsented);
      case RewardedAdOutcome.earned:
      case RewardedAdOutcome.dismissed:
        break;
    }
  }

  Future<void> _showLegacy() async {
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
      if (!mounted) return;
      final outcome = await showRewardedSilenced(
        ref,
        customData: claim['claimId'] as String,
        userId: userId,
        placement: RewardedPlacement.matchLegacy,
      );
      if (!mounted) return;
      if (outcome == RewardedAdOutcome.earned) {
        if (await _awaitAward()) {
          if (mounted) _say(l.adRewardGranted(_amount));
          return;
        }
        if (mounted) _say(l.adRewardPending);
      } else {
        _sayOutcome(outcome);
      }
    } catch (_) {
      if (mounted) _say(l.adRewardUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showStep(int step) async {
    if (_busy || _pending) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final backend = await ref.read(onlineBackendFactoryProvider)();
      final userId = await backend.ensureSession();
      await backend.call('economy', {'action': 'sync'});
      final claim = await _call('ad_step_claim_v2', {'step': step});
      if (!mounted) return;
      _apply(claim);
      if (_mode == _Mode.legacy) return; // a single-ad claim decides
      if (claim['claimState'] == 'awarded' || claim['claimId'] is! String) {
        return;
      }
      final amount = _steps.firstWhere((s) => s.step == step).amount;
      final outcome = await showRewardedSilenced(
        ref,
        customData: 's2:${claim['claimId']}',
        userId: userId,
        placement: RewardedPlacement.matchStep,
      );
      if (!mounted) return;
      if (outcome == RewardedAdOutcome.earned) {
        if (await _awaitAward(step: step)) {
          if (mounted) _say(l.adRewardGranted(amount));
          return;
        }
        if (mounted) _say(l.adRewardPending);
      } else {
        _sayOutcome(outcome);
      }
    } catch (_) {
      if (mounted) _say(l.adRewardUnavailable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- view --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(rewardedAdsProvider).configured) {
      return const SizedBox.shrink();
    }
    return switch (_mode) {
      _Mode.steps => _buildSteps(context),
      _ => _buildLegacy(context),
    };
  }

  Widget _checkAgain(BuildContext context) => TextButton.icon(
    key: RewardedRewardButton.checkAgainKey,
    onPressed: _checkOnce,
    icon: const Icon(Icons.refresh),
    label: Text(context.l10n.adRewardCheckAgain),
  );

  Widget _buildLegacy(BuildContext context) {
    final spacing = context.spacing;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: RewardedRewardButton.actionKey,
            onPressed: _busy || _awarded || _pending || _mode == _Mode.loading
                ? null
                : _showLegacy,
            icon: _busy
                ? SizedBox.square(
                    dimension: spacing.md,
                    child: const CircularProgressIndicator(strokeWidth: StoreTokens.busyStroke),
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
          if (_stale && !_awarded) _checkAgain(context),
          SizedBox(height: spacing.xs),
          Text(l.adRewardHint, style: context.typography.caption),
        ],
      ),
    );
  }

  Widget _buildSteps(BuildContext context) {
    final spacing = context.spacing;
    final l = context.l10n;
    final colors = context.colors;
    final total = _steps.fold<int>(0, (sum, s) => sum + s.amount);
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _awarded ? l.adStepsComplete(total) : l.adStepsTitle,
            style: context.typography.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: spacing.xs),
          for (final step in _steps) ...[
            _stepButton(context, step),
            SizedBox(height: spacing.xs),
          ],
          if (_stale && !_awarded) _checkAgain(context),
          Text(
            l.adStepsDisclosure(total),
            style: context.typography.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(BuildContext context, _Step step) {
    final spacing = context.spacing;
    final l = context.l10n;
    final previousDone =
        step.step == 1 ||
        _steps.any((s) => s.step == step.step - 1 && s.awarded);
    final enabled = !step.awarded && previousDone && !_busy && !_pending;
    return OutlinedButton.icon(
      key: RewardedRewardButton.stepKey(step.step),
      onPressed: enabled ? () => _showStep(step.step) : null,
      icon: step.awarded
          ? Icon(Icons.check_circle_outline, color: context.colors.accentGold)
          : _busy && previousDone
          ? SizedBox.square(
              dimension: spacing.md,
              child: const CircularProgressIndicator(strokeWidth: StoreTokens.busyStroke),
            )
          : const Icon(Icons.ondemand_video_outlined),
      label: Text(
        step.awarded
            ? l.adStepDone(step.step, step.amount)
            : _pending && previousDone
            ? l.adRewardPending
            : l.adStepAction(step.step, step.amount),
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

  Future<void> _open() async {
    final ads = ref.read(rewardedAdsProvider);
    await ads.showPrivacyOptions();
    // The answer may have changed what is required.
    final required = await ads.checkPrivacyOptions();
    if (mounted) setState(() => _visible = required);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return SettingsLinkRow(
      icon: Icons.ads_click_outlined,
      label: context.l10n.privacyChoices,
      hint: context.l10n.privacyChoicesHint,
      onTap: _open,
    );
  }
}
