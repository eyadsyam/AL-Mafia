import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/haptics.dart';
import '../../platform/monetization/rewarded_ads.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../screens/online/rewarded_reward_button.dart'
    show showRewardedSilenced;
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'council.dart';
import 'council_hub.dart' show contractName;
import 'daily_rewards.dart';
import 'economy_capabilities.dart';
import 'reward_poll.dart';
import 'vault_kit.dart';
import 'wallet.dart';

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

/// "20.00" → "20", "2.50" → "2.5": the exact published number, shorter.
String _trimPercent(String value) =>
    value.contains('.') ? value.replaceFirst(RegExp(r'\.?0+$'), '') : value;

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

  Future<bool> awarded(String kind) async {
    await refresh();
    final status = state.valueOrNull;
    final extra = switch (kind) {
      'spin' => status?.spin,
      'coffer' => status?.coffer,
      _ => status?.swap,
    };
    final done = extra?.awarded ?? false;
    if (done) {
      ref.invalidate(walletProvider);
      if (kind == 'swap') ref.invalidate(councilProvider);
    }
    return done;
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

/// «إضافات اختيارية» (phase 108): a second wheel spin, a doubled coffer and
/// a swapped contract, each one optional rewarded ad once a UTC day,
/// credited only by the server after AdMob's signed callback. Shown only
/// when the server switched each on and the build can show rewarded ads.
class AdExtrasPanel extends ConsumerStatefulWidget {
  const AdExtrasPanel({super.key});

  static const spinKey = ValueKey('ad_extra_spin');
  static const cofferKey = ValueKey('ad_extra_coffer');
  static const swapKey = ValueKey('ad_extra_swap');
  static ValueKey<String> swapSlotKey(int slot) =>
      ValueKey('ad_extra_swap_slot_$slot');

  @override
  ConsumerState<AdExtrasPanel> createState() => _AdExtrasPanelState();
}

class _AdExtrasPanelState extends ConsumerState<AdExtrasPanel> {
  bool _busy = false;
  String? _pending;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adExtrasProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  Future<void> _watch(String kind, {int? slot}) async {
    if (_busy || _pending != null) return;
    setState(() => _busy = true);
    final l = context.l10n;
    final controller = ref.read(adExtrasProvider.notifier);
    try {
      final claimId = await controller.claim(kind, slot: slot);
      if (!mounted || claimId == null) return;
      final backend = await ref.read(onlineBackendFactoryProvider)();
      final userId = await backend.ensureSession();
      if (!mounted) return;
      final outcome = await showRewardedSilenced(
        ref,
        customData: 'x1:$claimId',
        userId: userId,
        placement: RewardedPlacement.extra,
      );
      if (!mounted) return;
      switch (outcome) {
        case RewardedAdOutcome.earned:
          final epoch = ++_epoch;
          setState(() => _pending = kind);
          final landed = await pollForReward(
            awarded: () => controller.awarded(kind),
            alive: () => mounted && epoch == _epoch,
          );
          if (!mounted) return;
          setState(() => _pending = null);
          if (!landed) {
            _say(l.adRewardPending);
            return;
          }
          Haptics.confirm();
          final status = ref.read(adExtrasProvider).valueOrNull;
          _say(switch (kind) {
            'spin' => l.adExtraSpinResult(status?.spin.amount ?? 0),
            'coffer' => l.adExtraCofferDone(status?.coffer.amount ?? 0),
            _ => l.adExtraSwapDone,
          });
        case RewardedAdOutcome.notConsented:
          _say(l.adRewardNotConsented);
        case RewardedAdOutcome.unavailable:
        case RewardedAdOutcome.failed:
          _say(l.adRewardUnavailable);
        case RewardedAdOutcome.dismissed:
          break;
      }
    } on AdExtraFailed catch (error) {
      if (!mounted) return;
      _say(switch (error.code) {
        'IN_MATCH' => l.dailyAdInMatch,
        'DAY_CHANGED' => l.dailyDayChanged,
        'EXTRA_NOT_READY' when kind == 'spin' => l.adExtraSpinNotReady,
        'EXTRA_NOT_READY' when kind == 'coffer' => l.adExtraCofferNotReady,
        'EXTRA_NOT_READY' => l.adExtraNoneLeft,
        _ => l.dailyFailed,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseSwap() async {
    if (_busy || _pending != null) return;
    setState(() => _busy = true);
    final contracts = await ref.read(adExtrasProvider.notifier).contracts();
    if (!mounted) return;
    setState(() => _busy = false);
    final open = [
      for (final c in contracts.contracts)
        if (!c.claimed) c,
    ];
    final l = context.l10n;
    if (open.isEmpty) {
      _say(l.adExtraNoneLeft);
      return;
    }
    final slot = await showModalBottomSheet<int>(
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
                key: AdExtrasPanel.swapSlotKey(c.slot),
                title: Text(contractName(l, c)),
                subtitle: Text(l.adExtraSwapSlot(c.slot + 1)),
                onTap: () => Navigator.of(sheet).pop(c.slot),
              ),
            SizedBox(height: sheet.spacing.sm),
          ],
        ),
      ),
    );
    if (slot != null && mounted) await _watch('swap', slot: slot);
  }

  @override
  Widget build(BuildContext context) {
    // Opening the coffer or spinning the free wheel makes an extra ready.
    ref.listen(dailyProvider, (previous, next) {
      final a = previous?.valueOrNull;
      final b = next.valueOrNull;
      if (b != null &&
          (a?.cofferClaimed != b.cofferClaimed ||
              a?.wheelSpun != b.wheelSpun)) {
        ref.read(adExtrasProvider.notifier).refresh();
      }
    });
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull?.ads;
    final status = ref.watch(adExtrasProvider).valueOrNull;
    if (caps == null || !caps.extras || status == null) {
      return const SizedBox.shrink();
    }
    if (!ref.watch(rewardedAdsProvider).configured) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final spin = caps.extraSpin && status.spin.enabled;
    final coffer = caps.extraCoffer && status.coffer.enabled;
    final swap = caps.extraSwap && status.swap.enabled;
    if (!spin && !coffer && !swap) return const SizedBox.shrink();
    final idle = !_busy && _pending == null && !status.inMatch;

    Widget row({
      required IconData icon,
      required String title,
      required String body,
      required Widget action,
      bool first = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        first ? SizedBox(height: s.md) : const VaultDivider(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: CouncilLifeTokens.contractIcon,
              height: CouncilLifeTokens.contractIcon,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VaultTokens.enamel,
                border: Border.all(
                  color: VaultTokens.gold.withValues(alpha: 0.7),
                ),
              ),
              child: Icon(
                icon,
                size: CouncilLifeTokens.contractIcon / 2,
                color: VaultTokens.gold,
              ),
            ),
            SizedBox(width: s.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: type.body.emphasised.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    body,
                    style: type.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: s.sm),
        VaultPress(child: action),
      ],
    );

    String label(AdExtra extra, String kind, String ready) => extra.awarded
        ? l.adExtraUsed
        : _pending == kind
        ? l.adRewardPending
        : ready;

    final odds = [
      for (final p in status.prizes)
        '${p.coins} · ${l.dailyWheelPercent(_trimPercent(p.percent))}',
    ].join(l.listSeparator);

    final outline = vaultOutlineStyle(context);
    return VaultCard(
      children: [
        VaultHeading(
          title: l.adExtrasTitle,
          subtitle: status.inMatch ? l.dailyAdInMatch : l.adExtrasBody,
        ),
        if (spin)
          row(
            first: true,
            icon: Icons.casino_outlined,
            title: l.adExtraSpinTitle,
            body: status.spin.ready || status.spin.awarded
                ? '${l.adExtraSpinBody}\n${l.adExtraSpinOdds(odds)}'
                : l.adExtraSpinNotReady,
            action: OutlinedButton.icon(
              key: AdExtrasPanel.spinKey,
              style: outline,
              onPressed: idle && status.spin.ready && !status.spin.awarded
                  ? () => _watch('spin')
                  : null,
              icon: const Icon(Icons.ondemand_video_outlined),
              label: Text(
                status.spin.awarded
                    ? l.adExtraSpinResult(status.spin.amount ?? 0)
                    : label(status.spin, 'spin', l.adExtraSpinAction),
              ),
            ),
          ),
        if (coffer)
          row(
            first: !spin,
            icon: Icons.inventory_2_outlined,
            title: l.adExtraCofferTitle,
            body: status.coffer.ready || status.coffer.awarded
                ? l.adExtraCofferAction(status.coffer.amount ?? 0)
                : l.adExtraCofferNotReady,
            action: OutlinedButton.icon(
              key: AdExtrasPanel.cofferKey,
              style: outline,
              onPressed: idle && status.coffer.ready && !status.coffer.awarded
                  ? () => _watch('coffer')
                  : null,
              icon: const Icon(Icons.ondemand_video_outlined),
              label: Text(
                label(
                  status.coffer,
                  'coffer',
                  l.adExtraCofferAction(status.coffer.amount ?? 0),
                ),
              ),
            ),
          ),
        if (swap)
          row(
            first: !spin && !coffer,
            icon: Icons.swap_horiz_rounded,
            title: l.adExtraSwapTitle,
            body: l.adExtraSwapBody,
            action: OutlinedButton.icon(
              key: AdExtrasPanel.swapKey,
              style: outline,
              onPressed: idle && !status.swap.awarded ? _chooseSwap : null,
              icon: const Icon(Icons.swap_horiz),
              label: Text(label(status.swap, 'swap', l.adExtraSwapAction)),
            ),
          ),
      ],
    );
  }
}
