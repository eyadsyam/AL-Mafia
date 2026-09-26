import 'dart:async';
import 'dart:math' as math;

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
import 'economy_capabilities.dart';
import 'mafia_coin.dart';
import 'ad_extras.dart';
import 'reward_poll.dart';
import 'store_art.dart';
import 'wallet.dart';

class WheelPrize {
  final int slot;
  final int coins;
  final int weight;

  /// As the server publishes it, e.g. "20.00".
  final String percent;
  const WheelPrize(this.slot, this.coins, this.weight, this.percent);
}

/// The server's word on today. Nothing here is decided on the device: the
/// day is the server's UTC date, and every amount comes back from it.
class DailyStatus {
  final bool enabled;
  final String day;
  final bool cofferClaimed;
  final int cofferAmount;
  final bool wheelSpun;
  final int? wheelSlot;
  final int? wheelAmount;
  final List<WheelPrize> prizes;
  final int weekProgress;
  final int weekLength;
  final int weekBonus;
  final bool adEnabled;
  final int adAmount;
  final String adState;
  final bool inMatch;

  const DailyStatus({
    required this.enabled,
    required this.day,
    required this.cofferClaimed,
    required this.cofferAmount,
    required this.wheelSpun,
    required this.wheelSlot,
    required this.wheelAmount,
    required this.prizes,
    required this.weekProgress,
    required this.weekLength,
    required this.weekBonus,
    required this.adEnabled,
    required this.adAmount,
    required this.adState,
    required this.inMatch,
  });

  factory DailyStatus.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> part(String key) =>
        Map<String, dynamic>.from((json[key] as Map?) ?? const {});
    int read(Map<String, dynamic> map, String key, [int fallback = 0]) =>
        (map[key] as num?)?.toInt() ?? fallback;
    final coffer = part('coffer');
    final wheel = part('wheel');
    final week = part('week');
    final ad = part('ad');
    return DailyStatus(
      enabled: json['enabled'] == true,
      day: json['day'] as String? ?? '',
      cofferClaimed: coffer['claimed'] == true,
      cofferAmount: read(coffer, 'amount'),
      wheelSpun: wheel['spun'] == true,
      wheelSlot: (wheel['slot'] as num?)?.toInt(),
      wheelAmount: (wheel['amount'] as num?)?.toInt(),
      prizes: [
        for (final row in (wheel['prizes'] as List?) ?? const [])
          if (row is Map)
            WheelPrize(
              (row['slot'] as num?)?.toInt() ?? 0,
              (row['coins'] as num?)?.toInt() ?? 0,
              (row['weight'] as num?)?.toInt() ?? 0,
              '${row['percent'] ?? ''}',
            ),
      ]..sort((a, b) => a.slot.compareTo(b.slot)),
      weekProgress: read(week, 'progress'),
      weekLength: read(week, 'length', 7),
      weekBonus: read(week, 'bonus'),
      adEnabled: ad['enabled'] == true,
      adAmount: read(ad, 'amount'),
      adState: ad['state'] as String? ?? 'available',
      inMatch: ad['inMatch'] == true,
    );
  }
}

class DailyActionFailed implements Exception {
  final String? code;
  const DailyActionFailed(this.code);
}

/// What a claim or spin granted, for the reveal.
class DailyGrant {
  final int granted;
  final int bonus;
  final int? slot;
  const DailyGrant({required this.granted, this.bonus = 0, this.slot});
}

final dailyProvider = AsyncNotifierProvider<DailyController, DailyStatus?>(
  DailyController.new,
);

class DailyController extends AsyncNotifier<DailyStatus?> {
  @override
  Future<DailyStatus?> build() async => null;

  Future<OnlineBackend> _backend() async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend;
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async =>
      (await _backend()).call('economy', body);

  Future<void> refresh() async {
    state = const AsyncLoading<DailyStatus?>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () async => DailyStatus.fromJson(await _call({'action': 'daily_status'})),
    );
  }

  Future<Map<String, dynamic>> _act(String action) async {
    final day = state.valueOrNull?.day;
    if (day == null || day.isEmpty) throw const DailyActionFailed(null);
    try {
      return await _call({'action': action, 'day': day});
    } on BackendException catch (error) {
      if (error.code == 'DAY_CHANGED') await refresh();
      throw DailyActionFailed(error.code);
    } catch (_) {
      throw const DailyActionFailed(null);
    }
  }

  void _absorb(Map<String, dynamic> answer) {
    final daily = answer['daily'];
    if (daily is Map) {
      state = AsyncData(DailyStatus.fromJson(Map<String, dynamic>.from(daily)));
    }
    ref.invalidate(walletProvider);
  }

  Future<DailyGrant> claimCoffer() async {
    final answer = await _act('daily_coffer');
    _absorb(answer);
    return DailyGrant(
      granted: (answer['granted'] as num?)?.toInt() ?? 0,
      bonus: (answer['bonus'] as num?)?.toInt() ?? 0,
    );
  }

  /// The outcome is drawn and stored by the server before this returns; the
  /// wheel only animates to it.
  Future<DailyGrant> spin() async {
    final answer = await _act('daily_spin');
    _absorb(answer);
    return DailyGrant(
      granted: (answer['amount'] as num?)?.toInt() ?? 0,
      slot: (answer['slot'] as num?)?.toInt(),
    );
  }

  /// The claim to show an ad for, or null when today's is already awarded —
  /// then no ad is shown at all.
  Future<String?> createAdClaim() async {
    final answer = await _act('daily_ad_claim');
    if (answer['state'] == 'awarded') {
      await refresh();
      ref.invalidate(walletProvider);
      return null;
    }
    final id = answer['claimId'];
    if (id is! String) throw const DailyActionFailed(null);
    return id;
  }

  Future<bool> adAwarded() async {
    await refresh();
    final awarded = state.valueOrNull?.adState == 'awarded';
    if (awarded) ref.invalidate(walletProvider);
    return awarded;
  }
}

/// «المكافآت»: the daily coffer, the free wheel, the seven-day card and the
/// optional daily ad. Shown only when the server negotiated daily rewards.
class DailyRewardsTab extends ConsumerStatefulWidget {
  const DailyRewardsTab({super.key});

  static const cofferKey = ValueKey('daily_coffer_claim');
  static const spinKey = ValueKey('daily_wheel_spin');
  static const adKey = ValueKey('daily_ad_watch');
  static const wheelKey = ValueKey('daily_wheel');
  static const outcomeKey = ValueKey('daily_wheel_outcome');

  @override
  ConsumerState<DailyRewardsTab> createState() => _DailyRewardsTabState();
}

class _DailyRewardsTabState extends ConsumerState<DailyRewardsTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: MafiaTiming.wheelSpin,
  );
  double _from = 0;
  double _to = 0;
  bool _busy = false;
  bool _adPending = false;
  int _epoch = 0;

  /// The sentence under the wheel, set only once it has stopped.
  String? _outcome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(dailyProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _epoch++;
    _spin.dispose();
    super.dispose();
  }

  void _say(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  void _sayFailure(DailyActionFailed error) {
    final l = context.l10n;
    _say(error.code == 'DAY_CHANGED' ? l.dailyDayChanged : l.dailyFailed);
  }

  double _restingAngle(List<WheelPrize> prizes, int? slot) =>
      slot == null ? 0 : WheelGeometry.of(prizes).restingRotation(slot);

  Future<void> _claimCoffer() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final grant = await ref.read(dailyProvider.notifier).claimCoffer();
      if (!mounted) return;
      if (grant.granted > 0) {
        Haptics.confirm();
        _say(
          grant.bonus > 0
              ? '${l.dailyCofferGranted(grant.granted)} ${l.dailyWeekBonusGranted(grant.bonus)}'
              : l.dailyCofferGranted(grant.granted),
        );
      }
    } on DailyActionFailed catch (error) {
      if (mounted) _sayFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _spinWheel(List<WheelPrize> prizes) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });
    final l = context.l10n;
    try {
      final grant = await ref.read(dailyProvider.notifier).spin();
      if (!mounted || grant.slot == null) return;
      final target = WheelGeometry.of(prizes).restingRotation(grant.slot!);
      final reduce = MediaQuery.disableAnimationsOf(context);
      _from = 0;
      _to = reduce ? target : target + DailyTokens.wheelTurns * 2 * math.pi;
      if (reduce) {
        _spin.value = 1;
      } else {
        await _spin.forward(from: 0);
      }
      if (!mounted) return;
      Haptics.confirm();
      setState(() => _outcome = l.dailyWheelResult(grant.granted));
    } on DailyActionFailed catch (error) {
      if (mounted) _sayFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _watchDailyAd() async {
    if (_busy || _adPending) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final controller = ref.read(dailyProvider.notifier);
      final claimId = await controller.createAdClaim();
      if (!mounted || claimId == null) return;
      final backend = await ref.read(onlineBackendFactoryProvider)();
      final userId = await backend.ensureSession();
      if (!mounted) return;
      final outcome = await showRewardedSilenced(
        ref,
        customData: 'd1:$claimId',
        userId: userId,
        placement: RewardedPlacement.daily,
      );
      if (!mounted) return;
      switch (outcome) {
        case RewardedAdOutcome.earned:
          final epoch = ++_epoch;
          setState(() => _adPending = true);
          final landed = await pollForReward(
            awarded: controller.adAwarded,
            alive: () => mounted && epoch == _epoch,
          );
          if (!mounted) return;
          setState(() => _adPending = false);
          _say(
            landed
                ? l.dailyCofferGranted(
                    ref.read(dailyProvider).valueOrNull?.adAmount ?? 0,
                  )
                : l.adRewardPending,
          );
        case RewardedAdOutcome.notConsented:
          _say(l.adRewardNotConsented);
        case RewardedAdOutcome.unavailable:
        case RewardedAdOutcome.failed:
          _say(l.adRewardUnavailable);
        case RewardedAdOutcome.dismissed:
          break;
      }
    } on DailyActionFailed catch (error) {
      if (!mounted) return;
      if (error.code == 'IN_MATCH') {
        _say(l.dailyAdInMatch);
      } else {
        _sayFailure(error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final daily = ref.watch(dailyProvider);
    final status = daily.valueOrNull;
    if (status == null) {
      return Center(
        child: daily.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.dailyFailed, style: context.typography.body),
                  TextButton(
                    onPressed: () => ref.read(dailyProvider.notifier).refresh(),
                    child: Text(l.videoRetry),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull;
    final adsOffered =
        status.adEnabled &&
        (caps?.dailyAd ?? false) &&
        ref.watch(rewardedAdsProvider).configured;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.max(
          s.md,
          (box.maxWidth - DailyTokens.cardMaxWidth) / 2,
        );
        return ListView(
          padding: EdgeInsets.symmetric(horizontal: side, vertical: s.md),
          children: [
            _cofferCard(context, status),
            SizedBox(height: s.md),
            _wheelCard(context, status),
            SizedBox(height: s.md),
            _weekCard(context, status),
            if (adsOffered) ...[
              SizedBox(height: s.md),
              _adCard(context, status),
            ],
            // Phase 108: the optional extras, each switched on by the
            // server; a zero-size box otherwise.
            if (caps?.ads.extras ?? false) ...[
              SizedBox(height: s.md),
              const AdExtrasPanel(),
            ],
            SizedBox(height: s.md),
            Text(
              l.dailyResetNote,
              style: context.typography.caption.copyWith(
                color: context.colors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, List<Widget> children) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: BorderRadius.circular(context.radii.card),
      border: Border.all(color: context.colors.borderSubtle),
    ),
    child: Padding(
      padding: EdgeInsets.all(context.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _title(BuildContext context, String text) => Semantics(
    header: true,
    child: Text(
      text,
      style: context.typography.title.copyWith(
        color: context.colors.textPrimary,
      ),
    ),
  );

  Widget _cofferCard(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    return _card(context, [
      Row(
        children: [
          Image.asset(
            StoreArt.dailyCoffer,
            width: DailyTokens.cofferArt,
            height: DailyTokens.cofferArt,
            cacheWidth: StoreTokens.frameDecodeWidth,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) =>
                const MafiaCoin(size: DailyTokens.cofferArt / 2),
          ),
          SizedBox(width: s.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(context, l.dailyCofferTitle),
                SizedBox(height: s.xs),
                Text(
                  status.cofferClaimed
                      ? l.dailyCofferClaimed
                      : l.dailyCofferBody(status.cofferAmount),
                  style: context.typography.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: s.sm),
      FilledButton(
        key: DailyRewardsTab.cofferKey,
        onPressed: status.cofferClaimed || _busy || !status.enabled
            ? null
            : _claimCoffer,
        child: Text(
          status.cofferClaimed
              ? l.dailyCofferClaimed
              : l.dailyCofferClaim(status.cofferAmount),
        ),
      ),
    ]);
  }

  Widget _wheelCard(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    final prizes = status.prizes;
    final spinning = _spin.isAnimating;
    // Not while a spin is being requested: the stored outcome must not flash
    // into place before the wheel has started to turn.
    final settled = status.wheelSpun && !spinning && !_busy;
    // Reopened after today's spin: rest on the stored outcome.
    final rest = settled && _outcome == null
        ? _restingAngle(prizes, status.wheelSlot)
        : null;
    final outcome =
        _outcome ??
        (settled && status.wheelAmount != null
            ? l.dailyWheelDone(status.wheelAmount!)
            : null);
    return _card(context, [
      _title(context, l.dailyWheelTitle),
      SizedBox(height: s.xs),
      Text(
        l.dailyWheelBody,
        style: context.typography.bodySmall.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      SizedBox(height: s.md),
      if (prizes.isNotEmpty)
        Center(
          child: ExcludeSemantics(
            child: SizedBox.square(
              key: DailyRewardsTab.wheelKey,
              dimension: DailyTokens.wheelSize,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(_spin.value);
                  final angle = rest ?? (_from + (_to - _from) * t);
                  return CustomPaint(
                    painter: WheelPainter(
                      prizes: prizes,
                      rotation: angle,
                      colors: context.colors,
                      label: context.typography.caption,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      SizedBox(height: s.sm),
      if (outcome != null)
        Semantics(
          liveRegion: true,
          child: Text(
            outcome,
            key: DailyRewardsTab.outcomeKey,
            textAlign: TextAlign.center,
            style: context.typography.body.copyWith(
              color: context.colors.accentGold,
            ),
          ),
        ),
      SizedBox(height: s.sm),
      FilledButton(
        key: DailyRewardsTab.spinKey,
        onPressed: status.wheelSpun || _busy || !status.enabled
            ? null
            : () => _spinWheel(prizes),
        child: Text(l.dailyWheelSpin),
      ),
      SizedBox(height: s.sm),
      _OddsTable(prizes: prizes),
    ]);
  }

  Widget _weekCard(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    return _card(context, [
      _title(context, l.dailyWeekTitle),
      SizedBox(height: s.sm),
      Semantics(
        label: l.dailyWeekBody(status.weekProgress, status.weekBonus),
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var day = 1; day <= status.weekLength; day++)
              Container(
                width: DailyTokens.weekDot,
                height: DailyTokens.weekDot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: day <= status.weekProgress
                      ? colors.accentGold
                      : colors.surfaceBase,
                  border: Border.all(
                    color: day == status.weekLength
                        ? colors.accentCrimson
                        : colors.borderSubtle,
                  ),
                ),
              ),
          ],
        ),
      ),
      SizedBox(height: s.sm),
      Text(
        l.dailyWeekBody(status.weekProgress, status.weekBonus),
        style: context.typography.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
      ),
    ]);
  }

  Widget _adCard(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    final done = status.adState == 'awarded';
    return _card(context, [
      _title(context, l.dailyAdTitle),
      SizedBox(height: s.xs),
      Text(
        status.inMatch ? l.dailyAdInMatch : l.dailyAdBody(status.adAmount),
        style: context.typography.bodySmall.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      SizedBox(height: s.sm),
      OutlinedButton.icon(
        key: DailyRewardsTab.adKey,
        onPressed: done || _busy || _adPending || status.inMatch
            ? null
            : _watchDailyAd,
        icon: const Icon(Icons.ondemand_video_outlined),
        label: Text(
          done
              ? l.dailyAdDone
              : _adPending
              ? l.adRewardPending
              : l.dailyAdAction(status.adAmount),
        ),
      ),
    ]);
  }
}

/// Every prize with its exact published probability, beside the wheel.
class _OddsTable extends StatelessWidget {
  final List<WheelPrize> prizes;
  const _OddsTable({required this.prizes});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = context.typography.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.dailyWheelOdds,
          style: style.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final prize in prizes)
          Padding(
            padding: EdgeInsets.only(top: context.spacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.dailyWheelOddsRow(prize.coins), style: style),
                ),
                Text(
                  l.dailyWheelPercent(_trim(prize.percent)),
                  style: style.copyWith(color: context.colors.accentGold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _trim(String value) =>
      value.contains('.') ? value.replaceFirst(RegExp(r'\.?0+$'), '') : value;
}

/// Slices proportional to their real probability, starting at the top and
/// running clockwise. The pointer is at the top.
class WheelGeometry {
  final List<int> slots;
  final List<double> starts;
  final List<double> sweeps;
  const WheelGeometry(this.slots, this.starts, this.sweeps);

  factory WheelGeometry.of(List<WheelPrize> prizes) {
    final total = prizes.fold<int>(0, (sum, p) => sum + p.weight);
    final starts = <double>[];
    final sweeps = <double>[];
    var at = -math.pi / 2;
    for (final prize in prizes) {
      final sweep = total == 0 ? 0.0 : 2 * math.pi * prize.weight / total;
      starts.add(at);
      sweeps.add(sweep);
      at += sweep;
    }
    return WheelGeometry([for (final p in prizes) p.slot], starts, sweeps);
  }

  /// The rotation that puts the middle of [slot]'s slice under the pointer:
  /// exactly the server's outcome, never an edge.
  double restingRotation(int slot) {
    // By the server's slot value, not by list position: slots may have gaps.
    final found = slots.indexOf(slot);
    final index = found < 0 ? 0 : found;
    final middle = starts[index] + sweeps[index] / 2;
    final raw = -math.pi / 2 - middle;
    const full = 2 * math.pi;
    return ((raw % full) + full) % full;
  }
}

class WheelPainter extends CustomPainter {
  final List<WheelPrize> prizes;
  final double rotation;
  final MafiaColors colors;
  final TextStyle label;

  WheelPainter({
    required this.prizes,
    required this.rotation,
    required this.colors,
    required this.label,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - DailyTokens.pointer / 2;
    final geometry = WheelGeometry.of(prizes);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    for (var i = 0; i < prizes.length; i++) {
      final fill = Paint()
        ..color = i.isEven
            ? colors.accentCrimson.withValues(alpha: DailyTokens.sliceWash)
            : colors.accentGold.withValues(alpha: DailyTokens.sliceWashAlt);
      canvas.drawArc(rect, geometry.starts[i], geometry.sweeps[i], true, fill);
      final edge = Paint()
        ..color = colors.surfaceBase
        ..style = PaintingStyle.stroke
        ..strokeWidth = DailyTokens.wheelRim / 2;
      canvas.drawArc(rect, geometry.starts[i], geometry.sweeps[i], true, edge);
      if (geometry.sweeps[i] * 180 / math.pi >=
          DailyTokens.minLabelSweepDegrees) {
        final mid = geometry.starts[i] + geometry.sweeps[i] / 2;
        final painter = TextPainter(
          text: TextSpan(
            text: '+${prizes[i].coins}',
            style: label.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final at =
            center +
            Offset(math.cos(mid), math.sin(mid)) *
                (radius * DailyTokens.labelRadius) -
            Offset(painter.width / 2, painter.height / 2);
        painter.paint(canvas, at);
      }
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = colors.accentGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = DailyTokens.wheelRim,
    );
    canvas.drawCircle(
      center,
      DailyTokens.wheelHub,
      Paint()..color = colors.surfaceRaised,
    );
    canvas.drawCircle(
      center,
      DailyTokens.wheelHub,
      Paint()
        ..color = colors.accentGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = DailyTokens.wheelRim,
    );
    // The pointer, fixed at the top.
    final tip = Offset(center.dx, center.dy - radius + DailyTokens.pointer / 2);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - DailyTokens.pointer / 2, tip.dy - DailyTokens.pointer)
      ..lineTo(tip.dx + DailyTokens.pointer / 2, tip.dy - DailyTokens.pointer)
      ..close();
    canvas.drawPath(path, Paint()..color = colors.accentGold);
  }

  @override
  bool shouldRepaint(WheelPainter old) =>
      old.rotation != rotation || old.prizes != prizes || old.colors != colors;
}
