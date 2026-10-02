import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/haptics.dart';
import '../../platform/monetization/rewarded_ads.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'ad_reward_flow.dart';
import 'council.dart';
import 'council_hub.dart' show contractName;
import 'daily_rewards.dart';
import 'economy_capabilities.dart';
import 'vault_kit.dart';

/// One voluntary extra as the server describes it.
class AdExtra {
  final bool enabled;
  final bool ready;
  final String state;
  final int? amount;
  final int? slot;
  final String? code;
  const AdExtra({
    this.enabled = false,
    this.ready = false,
    this.state = 'available',
    this.amount,
    this.slot,
    this.code,
  });

  bool get awarded => state == 'awarded';

  factory AdExtra.fromJson(Object? json) {
    if (json is! Map) return const AdExtra();
    return AdExtra(
      enabled: json['enabled'] == true,
      ready: json['ready'] == true,
      state: json['state'] as String? ?? 'available',
      amount: (json['amount'] as num?)?.toInt(),
      slot: (json['slot'] as num?)?.toInt(),
      code: json['code'] as String?,
    );
  }
}

class AdExtrasStatus {
  final String day;
  final bool inMatch;
  final AdExtra spin;
  final AdExtra coffer;
  final AdExtra swap;
  final List<WheelPrize> prizes;
  const AdExtrasStatus({
    required this.day,
    required this.inMatch,
    required this.spin,
    required this.coffer,
    required this.swap,
    required this.prizes,
  });

  factory AdExtrasStatus.fromJson(Map<String, dynamic> json) {
    final spin = json['spin'];
    return AdExtrasStatus(
      day: json['day'] as String? ?? '',
      inMatch: json['inMatch'] == true,
      spin: AdExtra.fromJson(spin),
      coffer: AdExtra.fromJson(json['coffer']),
      swap: AdExtra.fromJson(json['swap']),
      prizes: [
        if (spin is Map)
          for (final row in (spin['prizes'] as List?) ?? const [])
            if (row is Map)
              WheelPrize(
                (row['slot'] as num?)?.toInt() ?? 0,
                (row['coins'] as num?)?.toInt() ?? 0,
                (row['weight'] as num?)?.toInt() ?? 0,
                '${row['percent'] ?? ''}',
              ),
      ],
    );
  }
}

class AdExtraFailed implements Exception {
  final String? code;
  const AdExtraFailed(this.code);
}

final adExtrasProvider =
    AsyncNotifierProvider<AdExtrasController, AdExtrasStatus?>(
      AdExtrasController.new,
    );

class AdExtrasController extends AsyncNotifier<AdExtrasStatus?> {
  @override
  Future<AdExtrasStatus?> build() async => null;

  Future<OnlineBackend> _backend() async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend;
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async =>
      (await _backend()).call('economy', body);

  Future<void> refresh() async {
    state = const AsyncLoading<AdExtrasStatus?>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () async =>
          AdExtrasStatus.fromJson(await _call({'action': 'extras_status'})),
    );
  }

  /// The claim to show an ad for, or null when today's is already used.
  Future<String?> claim(String kind, {int? slot}) async {
    final day = state.valueOrNull?.day;
    if (day == null || day.isEmpty) throw const AdExtraFailed(null);
    try {
      final answer = await _call({
        'action': 'extra_claim',
        'day': day,
        'kind': kind,
        'slot': ?slot,
      });
      if (answer['state'] == 'awarded') {
        await refresh();
        return null;
      }
      final id = answer['claimId'];
      if (id is! String) throw const AdExtraFailed(null);
      return id;
    } on BackendException catch (error) {
      if (error.code == 'DAY_CHANGED') await refresh();
      throw AdExtraFailed(error.code);
    } on AdExtraFailed {
      rethrow;
    } catch (_) {
      throw const AdExtraFailed(null);
    }
  }

  /// Whether the server has credited today's [kind]. The balance (and the
  /// contracts, for a swap) are the caller's to move: see `AdRewardFlow`.
  Future<bool> awarded(String kind) async {
    await refresh();
    final status = state.valueOrNull;
    final extra = switch (kind) {
      'spin' => status?.spin,
      'coffer' => status?.coffer,
      _ => status?.swap,
    };
    return extra?.awarded ?? false;
  }

  /// Today's contracts, for choosing which one to swap.
  Future<CouncilContracts> contracts() async {
    try {
      return CouncilContracts.fromJson(
        await _call({'action': 'contracts_get'}),
      );
    } catch (_) {
      return CouncilContracts.off;
    }
  }
}

//// Whether today's [extra] can be offered at all: switched on by the server
/// (both the capability and today's status), and a build that can show
/// rewarded ads.
bool extraOffered(WidgetRef ref, AdReward kind) {
  final caps = ref.watch(economyCapabilitiesProvider).valueOrNull?.ads;
  final status = ref.watch(adExtrasProvider).valueOrNull;
  if (caps == null || !caps.extras || status == null) return false;
  if (!ref.watch(rewardedAdsProvider).configured) return false;
  return switch (kind) {
    AdReward.extraSpin => caps.extraSpin && status.spin.enabled,
    AdReward.extraCoffer => caps.extraCoffer && status.coffer.enabled,
    AdReward.extraSwap => caps.extraSwap && status.swap.enabled,
    AdReward.dailyAd => false,
  };
}

/// One line for what a tap on an offer came to. Silence for a watched or
/// closed ad: the button itself says what happens next.
void sayAdAttempt(BuildContext context, AdRewardAttempt attempt, AdReward kind) {
  final l = context.l10n;
  final refusal = attempt.refusal;
  final String? message = refusal != null
      ? switch (refusal) {
          'IN_MATCH' => l.dailyAdInMatch,
          'DAY_CHANGED' => l.dailyDayChanged,
          'EXTRA_NOT_READY' when kind == AdReward.extraSpin =>
            l.adExtraSpinNotReady,
          'EXTRA_NOT_READY' when kind == AdReward.extraCoffer =>
            l.adExtraCofferNotReady,
          'EXTRA_NOT_READY' => l.adExtraNoneLeft,
          _ => l.dailyFailed,
        }
      : switch (attempt.outcome) {
          RewardedAdOutcome.unavailable ||
          RewardedAdOutcome.failed => l.adRewardUnavailable,
          RewardedAdOutcome.notConsented => l.adRewardNotConsented,
          _ => null,
        };
  if (message == null) return;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

/// A rewarded offer's button, drawn where the offer belongs (the wheel, the
/// coffer, the contracts) rather than in a list of ads.
///
/// It follows [AdRewardFlow]: the idle label, a spinner while the ad loads,
/// «confirming» while the server checks the view, and «on its way · check
/// again» if that takes longer than the check window — never "watch" again
/// for an ad already watched. While the offer sits idle on screen its ad is
/// loaded in the background, so the tap shows it at once.
class AdOfferButton extends ConsumerStatefulWidget {
  final AdReward kind;
  final String label;
  final bool gold;

  /// False while the offer cannot be taken (in a match, not ready yet).
  final bool enabled;

  /// Replaces the default (watch [kind]) — the swap picks a contract first.
  final Future<void> Function()? onTap;

  const AdOfferButton({
    super.key,
    required this.kind,
    required this.label,
    this.gold = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  ConsumerState<AdOfferButton> createState() => _AdOfferButtonState();
}

class _AdOfferButtonState extends ConsumerState<AdOfferButton> {
  Timer? _warm;
  bool _warmed = false;

  @override
  void dispose() {
    _warm?.cancel();
    super.dispose();
  }

  void _warmSoon() {
    if (_warmed || _warm != null) return;
    _warm = Timer(AdTokens.rewardedPreloadAfter, () {
      _warm = null;
      if (!mounted) return;
      _warmed = true;
      preloadRewarded(ref.read(rewardedAdsProvider), widget.kind.placement);
    });
  }

  Future<void> _watch() async {
    final custom = widget.onTap;
    if (custom != null) return custom();
    final attempt = await ref
        .read(adRewardFlowProvider.notifier)
        .watch(widget.kind);
    if (mounted) sayAdAttempt(context, attempt, widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final phase = ref.watch(
      adRewardFlowProvider.select((f) => f.phaseOf(widget.kind)),
    );
    final busy = ref.watch(adRewardFlowProvider.select((f) => f.busy));
    if (phase == AdRewardPhase.idle && widget.enabled) _warmSoon();
    final spinner = SizedBox.square(
      dimension: s.md,
      child: const CircularProgressIndicator(
        strokeWidth: StoreTokens.busyStroke,
      ),
    );
    final (label, icon, onPressed) = switch (phase) {
      AdRewardPhase.idle => (
        widget.label,
        const Icon(Icons.ondemand_video_rounded) as Widget,
        widget.enabled && !busy ? _watch : null,
      ),
      AdRewardPhase.watching => (widget.label, spinner as Widget, null),
      AdRewardPhase.verifying => (l.adRewardVerifying, spinner as Widget, null),
      AdRewardPhase.late => (
        l.adRewardLateCheck,
        const Icon(Icons.refresh_rounded) as Widget,
        () => ref.read(adRewardFlowProvider.notifier).recheck(widget.kind),
      ),
    };
    final text = Text(label, textAlign: TextAlign.center);
    return VaultPress(
      child: widget.gold
          ? FilledButton.icon(
              style: vaultGoldStyle(context),
              onPressed: onPressed,
              icon: icon,
              label: text,
            )
          : OutlinedButton.icon(
              style: vaultOutlineStyle(context),
              onPressed: onPressed,
              icon: icon,
              label: text,
            ),
    );
  }
}

/// Lets the player pick which of today's unclaimed contracts to swap.
Future<int?> pickContractToSwap(
  BuildContext context,
  CouncilContracts contracts,
) {
  final l = context.l10n;
  final open = [
    for (final c in contracts.contracts)
      if (!c.claimed) c,
  ];
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sheet.spacing.md),
            child: Text(
              l.adExtraSwapPick,
              style: sheet.typography.title.copyWith(
                color: sheet.colors.textPrimary,
              ),
            ),
          ),
          SizedBox(height: sheet.spacing.sm),
          for (final c in open)
            ListTile(
              key: ContractSwapOffer.slotKey(c.slot),
              title: Text(contractName(l, c)),
              subtitle: Text(l.adExtraSwapSlot(c.slot + 1)),
              onTap: () => Navigator.of(sheet).pop(c.slot),
            ),
          SizedBox(height: sheet.spacing.sm),
        ],
      ),
    ),
  );
}

/// «مهمة مش عاجباك؟ بدّلها بإعلان»: under today's contracts, only while one
/// is still open and today's swap is unused. Picks the contract in a sheet,
/// then shows the ad; the server swaps it once the view is verified.
class ContractSwapOffer extends ConsumerStatefulWidget {
  final CouncilContracts contracts;
  const ContractSwapOffer({super.key, required this.contracts});

  static const actionKey = ValueKey('ad_extra_swap');
  static ValueKey<String> slotKey(int slot) =>
      ValueKey('ad_extra_swap_slot_$slot');

  @override
  ConsumerState<ContractSwapOffer> createState() => _ContractSwapOfferState();
}

class _ContractSwapOfferState extends ConsumerState<ContractSwapOffer> {
  bool _asked = false;

  /// Today's extras are read once, as soon as the server says the swap is
  /// on (the capabilities may land after this card is drawn).
  void _askOnce(EconomyCapabilities? caps) {
    if (_asked || !(caps?.ads.extraSwap ?? false)) return;
    if (!ref.read(rewardedAdsProvider).configured) return;
    _asked = true;
    if (ref.read(adExtrasProvider).valueOrNull != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adExtrasProvider.notifier).refresh();
    });
  }

  Future<void> _swap() async {
    final slot = await pickContractToSwap(context, widget.contracts);
    if (slot == null || !mounted) return;
    final attempt = await ref
        .read(adRewardFlowProvider.notifier)
        .watch(AdReward.extraSwap, slot: slot);
    if (mounted) sayAdAttempt(context, attempt, AdReward.extraSwap);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AdRewardFlowState>(adRewardFlowProvider, (previous, next) {
      final landed = next.landed;
      if (landed != null &&
          landed.kind == AdReward.extraSwap &&
          landed.seq != previous?.landed?.seq) {
        Haptics.confirm();
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(context.l10n.adExtraSwapDone)));
      }
    });
    _askOnce(ref.watch(economyCapabilitiesProvider).valueOrNull);
    final status = ref.watch(adExtrasProvider).valueOrNull;
    final open = widget.contracts.contracts.any((c) => !c.claimed);
    if (!extraOffered(ref, AdReward.extraSwap) ||
        status == null ||
        status.swap.awarded ||
        !open) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.sm),
      child: AdOfferButton(
        key: ContractSwapOffer.actionKey,
        kind: AdReward.extraSwap,
        label: context.l10n.contractSwapAd,
        enabled: !status.inMatch,
        onTap: _swap,
      ),
    );
  }
}
