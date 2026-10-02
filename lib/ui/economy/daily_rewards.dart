import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/haptics.dart';
import '../../platform/monetization/rewarded_ads.dart';
import '../../transport/online_backend.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/motion_sprite.dart';
import 'ad_extras.dart';
import 'ad_reward_flow.dart';
import 'coin_win.dart';
import 'council_art.dart' show CoinBurst;
import 'economy_capabilities.dart';
import 'mafia_coin.dart';
import 'store_art.dart';
import 'vault_kit.dart';
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

  void _absorb(Map<String, dynamic> answer, {int credited = 0}) {
    final daily = answer['daily'];
    if (daily is Map) {
      state = AsyncData(DailyStatus.fromJson(Map<String, dynamic>.from(daily)));
    }
    unawaited(ref.read(walletProvider.notifier).settle(credited: credited));
  }

  Future<DailyGrant> claimCoffer() async {
    final answer = await _act('daily_coffer');
    final grant = DailyGrant(
      granted: (answer['granted'] as num?)?.toInt() ?? 0,
      bonus: (answer['bonus'] as num?)?.toInt() ?? 0,
    );
    _absorb(answer, credited: grant.granted + grant.bonus);
    return grant;
  }

  /// The outcome is drawn and stored by the server before this returns; the
  /// wheel only animates to it.
  Future<DailyGrant> spin() async {
    final answer = await _act('daily_spin');
    final grant = DailyGrant(
      granted: (answer['amount'] as num?)?.toInt() ?? 0,
      slot: (answer['slot'] as num?)?.toInt(),
    );
    _absorb(answer, credited: grant.granted);
    return grant;
  }

  /// The claim to show an ad for, or null when today's is already awarded —
  /// then no ad is shown at all.
  Future<String?> createAdClaim() async {
    final answer = await _act('daily_ad_claim');
    if (answer['state'] == 'awarded') {
      await refresh();
      unawaited(ref.read(walletProvider.notifier).settle());
      return null;
    }
    final id = answer['claimId'];
    if (id is! String) throw const DailyActionFailed(null);
    return id;
  }

  /// Whether the server has credited today's ad. The balance is the
  /// caller's to move (see `AdRewardFlow`), with the confirmed amount.
  Future<bool> adAwarded() async {
    await refresh();
    return state.valueOrNull?.adState == 'awarded';
  }
}

//// «المكافآت»: the daily coffer, the free wheel and the seven-day card.
/// Shown only when the server negotiated daily rewards.
///
/// The optional ads are not a list at the bottom: each appears in the card
/// it adds to, and only once the free thing there is used — the wheel's own
/// button becomes «عايز تلف تاني؟» after today's spin, the coffer's becomes
/// «ضاعفها» once it is open, then «+N كمان». The wheel itself is the spin
/// button (the labelled one under it stays, for every reader).
class DailyRewardsTab extends ConsumerStatefulWidget {
  const DailyRewardsTab({super.key});

  static const cofferKey = ValueKey('daily_coffer_claim');
  static const spinKey = ValueKey('daily_wheel_spin');
  static const adKey = ValueKey('daily_ad_watch');
  static const extraSpinKey = ValueKey('ad_extra_spin');
  static const extraCofferKey = ValueKey('ad_extra_coffer');
  static const wheelKey = ValueKey('daily_wheel');
  static const outcomeKey = ValueKey('daily_wheel_outcome');
  static const wheelWinKey = ValueKey('daily_wheel_win');
  static const cofferWinKey = ValueKey('daily_coffer_win');

  @override
  ConsumerState<DailyRewardsTab> createState() => _DailyRewardsTabState();
}

class _DailyRewardsTabState extends ConsumerState<DailyRewardsTab>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: MafiaTiming.wheelSpin,
  );

  /// Turns the wheel steadily while the server confirms an extra spin.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: WinTokens.idleTurn,
  );
  late final Listenable _wheelMotion = Listenable.merge([_spin, _idle]);
  double _from = 0;
  double _to = 0;
  double _idleBase = 0;

  /// A spin has been animated on this screen: the wheel rests where it
  /// stopped rather than on the stored slot.
  bool _spun = false;
  bool _busy = false;

  /// Bumped on a paid coffer, so its coins burst over the button.
  int? _cofferBurst;

  /// The win being celebrated over the wheel or the coffer, and a key per
  /// celebration so a second one starts afresh. The next offer in that card
  /// waits until it is done.
  int? _wheelWin;
  int? _cofferWin;
  int _winSeq = 0;

  /// The slice under the pointer while the wheel turns: a tick each time a
  /// new one passes it.
  int _tickSlice = -1;
  List<WheelPrize> _tickPrizes = const [];

  /// The sentence under the wheel, set only once it has stopped.
  String? _outcome;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _spin.addListener(_tick);
    _idle.addListener(_tick);
    // A reward confirmed while the player was away shows on return.
    _life = AppLifecycleListener(
      onResume: () => ref.read(adRewardFlowProvider.notifier).recheckLate(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(dailyProvider.notifier).refresh();
      _refreshExtras();
      ref.read(adRewardFlowProvider.notifier).recheckLate();
    });
  }

  void _refreshExtras() {
    final caps = ref.read(economyCapabilitiesProvider).valueOrNull?.ads;
    if ((caps?.extras ?? false) && ref.read(rewardedAdsProvider).configured) {
      ref.read(adExtrasProvider.notifier).refresh();
    }
  }

  /// The angle the wheel is drawn at for a spin at [value] (0..1).
  double _angleAt(double value) =>
      _from + (_to - _from) * _wheelCurve.transform(value);

  /// A quick start that eases to a long, slow finish: the last slices
  /// crawl past the pointer, and it lands exactly on the server's slot.
  static const Curve _wheelCurve = Cubic(0.12, 0.72, 0.18, 1);

  double get _idleAngle => _idleBase + _idle.value * 2 * math.pi;

  void _tick() {
    if ((!_spin.isAnimating && !_idle.isAnimating) || _tickPrizes.isEmpty) {
      return;
    }
    final angle = _idle.isAnimating ? _idleAngle : _angleAt(_spin.value);
    final slice = WheelGeometry.of(_tickPrizes).sliceUnderPointer(angle);
    if (slice != _tickSlice) {
      if (_tickSlice >= 0) Haptics.select();
      _tickSlice = slice;
    }
  }

  @override
  void dispose() {
    _life.dispose();
    _spin.dispose();
    _idle.dispose();
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

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  Future<void> _claimCoffer() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = context.l10n;
    try {
      final grant = await ref.read(dailyProvider.notifier).claimCoffer();
      if (!mounted) return;
      if (grant.granted > 0) {
        Haptics.confirm();
        setState(() {
          _cofferBurst = (_cofferBurst ?? 0) + 1;
          _cofferWin = grant.granted + grant.bonus;
          _winSeq++;
        });
        showRewardFlourish(context);
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

  /// Turns the wheel from where it is to the server's [slot], adding a few
  /// full turns, then celebrates [amount].
  Future<void> _turnTo(
    List<WheelPrize> prizes,
    int slot, {
    required double from,
    required int amount,
    required String outcome,
  }) async {
    final target = WheelGeometry.of(prizes).restingRotation(slot);
    var to = target;
    if (_reduce) {
      to = target;
    } else {
      while (to < from + WinTokens.landTurns * 2 * math.pi) {
        to += 2 * math.pi;
      }
    }
    _from = _reduce ? to : from;
    _to = to;
    _tickPrizes = prizes;
    _tickSlice = -1;
    _spun = true;
    if (_reduce) {
      _spin.value = 1;
    } else {
      await _spin.forward(from: 0);
    }
    if (!mounted) return;
    Haptics.confirm();
    setState(() {
      _outcome = outcome;
      _wheelWin = amount;
      _winSeq++;
    });
    showRewardFlourish(context);
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
      await _turnTo(
        prizes,
        grant.slot!,
        from: 0,
        amount: grant.granted,
        outcome: l.dailyWheelResult(grant.granted),
      );
    } on DailyActionFailed catch (error) {
      if (mounted) _sayFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The ad was watched: the wheel turns on its own while the server
  /// confirms the view (it draws the prize at that moment).
  void _startWaitingSpin(List<WheelPrize> prizes, double from) {
    if (_idle.isAnimating || _reduce) return;
    setState(() {
      _outcome = null;
      _idleBase = from;
      _tickPrizes = prizes;
      _tickSlice = -1;
      _spun = true;
    });
    _idle.repeat();
  }

  /// The server's prize is in: the waiting wheel settles on it.
  Future<void> _landExtraSpin(
    List<WheelPrize> prizes,
    int? slot,
    int amount,
  ) async {
    final from = _idle.isAnimating ? _idleAngle : _angleAt(_spin.value);
    _idle.stop();
    final l = context.l10n;
    if (slot == null) {
      setState(() {
        _outcome = l.adExtraSpinResult(amount);
        _wheelWin = amount;
        _winSeq++;
      });
      return;
    }
    await _turnTo(
      prizes,
      slot,
      from: from,
      amount: amount,
      outcome: l.adExtraSpinResult(amount),
    );
  }

  /// The confirmation did not come in time: the wheel comes to rest where
  /// it is, without pretending to know the prize.
  void _stopWaitingSpin() {
    if (!_idle.isAnimating) return;
    final at = _idleAngle;
    _idle.stop();
    setState(() {
      _from = at;
      _to = at;
      _spin.value = 1;
    });
  }

  void _onFlow(
    AdRewardFlowState? previous,
    AdRewardFlowState next,
    List<WheelPrize> prizes,
  ) {
    final before = previous?.phaseOf(AdReward.extraSpin);
    final now = next.phaseOf(AdReward.extraSpin);
    if (now == AdRewardPhase.verifying && before == AdRewardPhase.watching) {
      final from = _spun ? _angleAt(_spin.value) : _currentRest(prizes);
      _startWaitingSpin(prizes, from);
    } else if (now == AdRewardPhase.late) {
      _stopWaitingSpin();
    }
    final landed = next.landed;
    if (landed == null || landed.seq == previous?.landed?.seq) return;
    switch (landed.kind) {
      case AdReward.extraSpin:
        unawaited(_landExtraSpin(prizes, landed.slot, landed.amount));
      case AdReward.extraCoffer:
      case AdReward.dailyAd:
        Haptics.confirm();
        setState(() {
          _cofferBurst = (_cofferBurst ?? 0) + 1;
          _cofferWin = landed.amount;
          _winSeq++;
        });
      case AdReward.extraSwap:
        break;
    }
  }

  /// Where the wheel rests when nothing has turned on this screen: on the
  /// latest outcome the server stored today.
  double _currentRest(List<WheelPrize> prizes) {
    final status = ref.read(dailyProvider).valueOrNull;
    final extras = ref.read(adExtrasProvider).valueOrNull;
    final extraSlot = extras?.spin.awarded ?? false ? extras?.spin.slot : null;
    return _restingAngle(prizes, extraSlot ?? status?.wheelSlot);
  }

  Future<void> _watch(AdReward kind) async {
    final attempt = await ref.read(adRewardFlowProvider.notifier).watch(kind);
    if (mounted) sayAdAttempt(context, attempt, kind);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final daily = ref.watch(dailyProvider);
    final status = daily.valueOrNull;
    // The server's answer on extras may arrive after this tab opened.
    ref.listen(economyCapabilitiesProvider, (previous, next) {
      final was = previous?.valueOrNull?.ads.extras ?? false;
      if (!was && (next.valueOrNull?.ads.extras ?? false)) _refreshExtras();
    });
    // Opening the coffer or spinning the free wheel makes an extra ready.
    ref.listen(dailyProvider, (previous, next) {
      final a = previous?.valueOrNull;
      final b = next.valueOrNull;
      if (b != null &&
          a != null &&
          (a.cofferClaimed != b.cofferClaimed || a.wheelSpun != b.wheelSpun)) {
        _refreshExtras();
      }
    });
    ref.listen<AdRewardFlowState>(
      adRewardFlowProvider,
      (previous, next) => _onFlow(
        previous,
        next,
        ref.read(dailyProvider).valueOrNull?.prizes ?? const [],
      ),
    );
    if (status == null) {
      return daily.hasError
          ? VaultRetry(
              message: l.dailyFailed,
              action: l.videoRetry,
              onRetry: () => ref.read(dailyProvider.notifier).refresh(),
            )
          : const VaultSkeleton();
    }
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
            SizedBox(height: s.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: CosmeticTokens.coinInline * 0.8,
                  color: context.colors.textMuted,
                ),
                SizedBox(width: s.xs),
                Flexible(
                  child: Text(
                    l.dailyResetNote,
                    style: context.typography.caption.copyWith(
                      color: context.colors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            SizedBox(height: s.md),
          ],
        );
      },
    );
  }

  Widget _card(
    BuildContext context,
    List<Widget> children, {
    bool lit = false,
  }) => VaultCard(lit: lit, children: children);

  /// The one action under the coffer: open it; then, once it is open (and
  /// the coins have landed), double it with an ad; then today's ad for a
  /// little more; then nothing until tomorrow.
  Widget _cofferAction(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final extras = ref.watch(adExtrasProvider).valueOrNull;
    final caps = ref.watch(economyCapabilitiesProvider).valueOrNull;
    final rewarded = ref.watch(rewardedAdsProvider).configured;
    final flow = ref.watch(adRewardFlowProvider);
    final celebrating = _cofferWin != null;
    final doubleIt =
        status.cofferClaimed &&
        extras != null &&
        extraOffered(ref, AdReward.extraCoffer) &&
        extras.coffer.ready &&
        !extras.coffer.awarded;
    final dailyAd =
        status.cofferClaimed &&
        status.adEnabled &&
        (caps?.dailyAd ?? false) &&
        rewarded &&
        status.adState != 'awarded';
    // An offer already started keeps its button through the celebration.
    bool started(AdReward kind) => flow.phaseOf(kind) != AdRewardPhase.idle;
    if (doubleIt && (!celebrating || started(AdReward.extraCoffer))) {
      return AdOfferButton(
        key: DailyRewardsTab.extraCofferKey,
        kind: AdReward.extraCoffer,
        gold: true,
        label: l.cofferDoubleAd(extras.coffer.amount ?? 0),
        enabled: !extras.inMatch,
      );
    }
    if (dailyAd && (!celebrating || started(AdReward.dailyAd))) {
      return AdOfferButton(
        key: DailyRewardsTab.adKey,
        kind: AdReward.dailyAd,
        label: status.inMatch
            ? l.dailyAdInMatch
            : l.dailyAdMore(status.adAmount),
        enabled: !status.inMatch,
      );
    }
    return VaultPress(
      child: FilledButton(
        key: DailyRewardsTab.cofferKey,
        style: vaultGoldStyle(context),
        onPressed: status.cofferClaimed || _busy || !status.enabled
            ? null
            : _claimCoffer,
        child: Text(
          status.cofferClaimed
              ? l.dailyCofferClaimed
              : l.dailyCofferClaim(status.cofferAmount),
        ),
      ),
    );
  }

  Widget _cofferCard(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    final ready = !status.cofferClaimed && status.enabled;
    final art = Image.asset(
      StoreArt.dailyCoffer,
      width: DailyTokens.cofferArt,
      height: DailyTokens.cofferArt,
      cacheWidth: StoreTokens.frameDecodeWidth,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) =>
          const MafiaCoin(size: DailyTokens.cofferArt / 2),
    );
    final win = _cofferWin;
    return VaultGlint(
      play: ready,
      child: _card(context, lit: ready, [
        VaultHeading(
          leading: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ready ? LampGlow(child: art) : Opacity(opacity: 0.7, child: art),
              if (win != null)
                CoinWinReveal(
                  key: ValueKey(('coffer', _winSeq)),
                  amount: win,
                  onDone: () {
                    if (mounted) setState(() => _cofferWin = null);
                  },
                ),
            ],
          ),
          title: l.dailyCofferTitle,
          subtitle: status.cofferClaimed
              ? l.dailyCofferClaimed
              : l.dailyCofferBody(status.cofferAmount),
        ),
        SizedBox(height: s.md),
        CoinBurst(
          trigger: _cofferBurst,
          child: AnimatedSwitcher(
            duration: _reduce ? Duration.zero : context.motion.standard,
            transitionBuilder: _swapTransition,
            child: KeyedSubtree(
              key: ValueKey(_cofferActionKind(status)),
              child: _cofferAction(context, status),
            ),
          ),
        ),
      ]),
    );
  }

  /// A cross-fade in which the button on its way out can no longer be
  /// pressed: a fading free claim must not be claimable twice.
  static Widget _swapTransition(Widget child, Animation<double> animation) =>
      FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => IgnorePointer(
            ignoring:
                animation.status == AnimationStatus.reverse ||
                animation.status == AnimationStatus.dismissed,
            child: child,
          ),
        ),
      );

  /// Which button the coffer shows, so the switch between them animates.
  String _cofferActionKind(DailyStatus status) {
    if (!status.cofferClaimed) return 'free';
    final extras = ref.read(adExtrasProvider).valueOrNull;
    if (extras != null && !extras.coffer.awarded && extras.coffer.ready) {
      return 'double';
    }
    return status.adState == 'awarded' ? 'done' : 'ad';
  }

  /// What a tap on the wheel (or its button) does right now, or null.
  VoidCallback? _wheelTap(DailyStatus status, bool adSpinShown) {
    final prizes = status.prizes;
    if (!status.wheelSpun) {
      return _busy || !status.enabled ? null : () => _spinWheel(prizes);
    }
    if (!adSpinShown) return null;
    final flow = ref.read(adRewardFlowProvider);
    final extras = ref.read(adExtrasProvider).valueOrNull;
    return switch (flow.phaseOf(AdReward.extraSpin)) {
      AdRewardPhase.idle when !flow.busy && !(extras?.inMatch ?? true) =>
        () => _watch(AdReward.extraSpin),
      AdRewardPhase.late => () => ref
          .read(adRewardFlowProvider.notifier)
          .recheck(AdReward.extraSpin),
      _ => null,
    };
  }

  Widget _wheelCard(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    final prizes = status.prizes;
    final extras = ref.watch(adExtrasProvider).valueOrNull;
    final flow = ref.watch(adRewardFlowProvider);
    final spinPhase = flow.phaseOf(AdReward.extraSpin);
    final turning = _spin.isAnimating || _idle.isAnimating;
    final extraAwarded = extras?.spin.awarded ?? false;
    // The second spin, offered only after today's free one, by the wheel's
    // own button — and only once the first win has finished landing.
    final adSpin =
        status.wheelSpun &&
        extras != null &&
        extraOffered(ref, AdReward.extraSpin) &&
        extras.spin.ready &&
        !extraAwarded;
    final adSpinShown =
        adSpin &&
        ((_wheelWin == null && !turning && !_busy) ||
            spinPhase != AdRewardPhase.idle);
    // Not while a spin is being requested: the stored outcome must not flash
    // into place before the wheel has started to turn.
    final settled = status.wheelSpun && !turning && !_busy;
    final rest = settled && !_spun ? _currentRest(prizes) : null;
    final outcome =
        _outcome ??
        (settled && !_spun
            ? extraAwarded && extras?.spin.amount != null
                  ? l.adExtraSpinResult(extras!.spin.amount!)
                  : status.wheelAmount != null
                  ? l.dailyWheelDone(status.wheelAmount!)
                  : null
            : null);
    final ready = !status.wheelSpun && status.enabled;
    final tap = _wheelTap(status, adSpinShown);
    final win = _wheelWin;
    return _card(context, lit: ready || adSpinShown, [
      VaultHeading(title: l.dailyWheelTitle, subtitle: l.dailyWheelBody),
      SizedBox(height: s.md),
      if (prizes.isNotEmpty)
        Center(
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tap,
              child: SizedBox.square(
                key: DailyRewardsTab.wheelKey,
                dimension: DailyTokens.wheelSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _wheelMotion,
                        builder: (context, _) {
                          final angle = _idle.isAnimating
                              ? _idleAngle
                              : rest ?? _angleAt(_spin.value);
                          return CustomPaint(
                            painter: WheelPainter(
                              prizes: prizes,
                              rotation: angle,
                              colors: context.colors,
                              label: context.typography.bodySmall,
                              spinning: _spin.isAnimating || _idle.isAnimating,
                            ),
                          );
                        },
                      ),
                    ),
                    const MafiaCoin(size: VaultTokens.wheelHubCoin),
                    if (win != null)
                      CoinWinReveal(
                        key: ValueKey(('wheel', _winSeq)),
                        amount: win,
                        onDone: () {
                          if (mounted) setState(() => _wheelWin = null);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      SizedBox(height: s.md),
      if (outcome != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            outcome,
            key: DailyRewardsTab.outcomeKey,
            textAlign: TextAlign.center,
            style: context.typography.title.copyWith(color: VaultTokens.gold),
          ),
        ),
        SizedBox(height: s.sm),
      ],
      AnimatedSwitcher(
        duration: _reduce ? Duration.zero : context.motion.standard,
        transitionBuilder: _swapTransition,
        child: adSpinShown
            ? AdOfferButton(
                key: DailyRewardsTab.extraSpinKey,
                kind: AdReward.extraSpin,
                gold: true,
                label: l.wheelAgainAd,
                enabled: !extras.inMatch,
              )
            : VaultPress(
                key: const ValueKey('daily_wheel_free'),
                child: FilledButton.icon(
                  key: DailyRewardsTab.spinKey,
                  style: vaultGoldStyle(context),
                  onPressed: status.wheelSpun || _busy || !status.enabled
                      ? null
                      : () => _spinWheel(prizes),
                  icon: const Icon(Icons.casino_outlined),
                  label: Text(l.dailyWheelSpin),
                ),
              ),
      ),
      SizedBox(height: s.md),
      _OddsTable(prizes: prizes),
    ]);
  }

  Widget _weekCard(BuildContext context, DailyStatus status) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    // Today's medal: the one the coffer is about to strike, or the one it
    // just struck.
    final today = status.cofferClaimed
        ? status.weekProgress
        : status.weekProgress + 1;
    return _card(context, [
      VaultHeading(
        title: l.dailyWeekTitle,
        trailing: RewardChip(
          status.weekBonus,
          muted: status.weekProgress < status.weekLength - 1,
        ),
      ),
      SizedBox(height: s.md),
      Semantics(
        label: l.dailyWeekBody(status.weekProgress, status.weekBonus),
        excludeSemantics: true,
        child: SizedBox(
          height: VaultTokens.dayMedal,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The chain the medals hang on, struck up to today.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VaultTokens.dayMedal / 2,
                ),
                child: VaultBar(
                  value: status.weekLength <= 1
                      ? 0
                      : (status.weekProgress - 1).clamp(0, status.weekLength) /
                            (status.weekLength - 1),
                  height: VaultTokens.chipRim * 4,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var day = 1; day <= status.weekLength; day++)
                    _DayMedal(
                      day: day,
                      done: day <= status.weekProgress,
                      today: day == today,
                      last: day == status.weekLength,
                    ),
                ],
              ),
            ],
          ),
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
}

/// One day of the seven: struck gold once opened, ringed today, and the
/// seventh in oxblood for its bonus.
class _DayMedal extends StatelessWidget {
  final int day;
  final bool done;
  final bool today;
  final bool last;
  const _DayMedal({
    required this.day,
    required this.done,
    required this.today,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final List<Color> metal = done
        ? const [VaultTokens.goldLight, VaultTokens.gold, VaultTokens.goldDeep]
        : last
        ? const [
            VaultTokens.oxbloodLight,
            VaultTokens.oxblood,
            VaultTokens.enamel,
          ]
        : [colors.surfaceOverlay, colors.surfaceRaised, colors.surfaceBase];
    return Container(
      width: VaultTokens.dayMedal,
      height: VaultTokens.dayMedal,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          colors: metal,
          stops: const [0, 0.6, 1],
        ),
        border: Border.all(
          color: today
              ? VaultTokens.goldLight
              : done || last
              ? VaultTokens.gold
              : colors.borderSubtle,
          width: today ? VaultTokens.dayMedalToday : 1,
        ),
        boxShadow: today
            ? [
                BoxShadow(
                  color: VaultTokens.gold.withValues(
                    alpha: VaultTokens.litGlowAlpha * 2,
                  ),
                  blurRadius: VaultTokens.litGlowBlur / 2,
                ),
              ]
            : null,
      ),
      child: done
          ? const Icon(
              Icons.check_rounded,
              size: VaultTokens.chipCoin,
              color: VaultTokens.goldInk,
            )
          : Text(
              '$day',
              style: context.typography.caption.emphasised.copyWith(
                color: last ? VaultTokens.goldLight : colors.textSecondary,
                height: 1.1,
              ),
            ),
    );
  }
}

/// Every prize with its exact published probability, beside the wheel.
class _OddsTable extends StatelessWidget {
  final List<WheelPrize> prizes;
  const _OddsTable({required this.prizes});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final style = context.typography.bodySmall;
    final top = prizes.isEmpty
        ? 0
        : prizes.map((p) => p.coins).reduce(math.max);
    return Container(
      padding: EdgeInsets.fromLTRB(s.sm, s.sm, s.sm, s.xs),
      decoration: BoxDecoration(
        color: VaultTokens.enamel,
        borderRadius: BorderRadius.circular(context.radii.button),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.balance_rounded,
                size: CosmeticTokens.coinInline * 0.8,
                color: VaultTokens.gold,
              ),
              SizedBox(width: s.xs),
              Text(
                l.dailyWheelOdds,
                style: style.emphasised.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          for (final (i, prize) in prizes.indexed)
            Container(
              padding: EdgeInsets.symmetric(vertical: s.xs),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(
                        top: BorderSide(
                          color: colors.borderSubtle.withValues(
                            alpha: VaultTokens.dividerAlpha,
                          ),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: prize.coins == top ? 1 : 0.75,
                    child: const MafiaCoin(size: VaultTokens.chipCoin),
                  ),
                  SizedBox(width: s.xs),
                  Expanded(
                    child: Text(
                      l.dailyWheelOddsRow(prize.coins),
                      style: prize.coins == top
                          ? style.emphasised.copyWith(color: VaultTokens.gold)
                          : style.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  Text(
                    l.dailyWheelPercent(_trim(prize.percent)),
                    style: style.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
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

  /// Which slice (by list position) sits under the pointer when the wheel is
  /// turned by [rotation].
  int sliceUnderPointer(double rotation) {
    const full = 2 * math.pi;
    // The pointer is at -π/2; in the wheel's own frame it sits at
    // -π/2 - rotation, which the slices' starts (from -π/2) are measured in.
    final at = (((-rotation) % full) + full) % full;
    for (var i = 0; i < starts.length; i++) {
      final from = starts[i] + math.pi / 2;
      if (at >= from && at < from + sweeps[i]) return i;
    }
    return starts.length - 1;
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

  /// While the wheel turns, the pointer flicks as each rim stud passes it.
  final bool spinning;

  WheelPainter({
    required this.prizes,
    required this.rotation,
    required this.colors,
    required this.label,
    this.spinning = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - DailyTokens.pointer / 2;
    final radius = outer - VaultTokens.wheelRimWidth;
    final geometry = WheelGeometry.of(prizes);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final top = prizes.isEmpty
        ? 0
        : prizes.map((p) => p.coins).reduce(math.max);

    // The wheel's cast shadow on the card.
    canvas.drawCircle(
      center.translate(0, VaultTokens.buttonGlowDrop),
      outer,
      Paint()
        ..color = colors.shadow
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          VaultTokens.buttonGlowBlur / 2,
        ),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    for (var i = 0; i < prizes.length; i++) {
      // The rarest, largest prize is struck in gold; the rest alternate
      // oxblood and smoked charcoal.
      final jackpot = prizes[i].coins == top;
      final base = jackpot
          ? VaultTokens.gold
          : i.isEven
          ? VaultTokens.oxblood
          : Color.lerp(colors.surfaceOverlay, VaultTokens.goldDeep, 0.25)!;
      canvas.drawArc(
        rect,
        geometry.starts[i],
        geometry.sweeps[i],
        true,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(base, VaultTokens.goldLight, jackpot ? 0.35 : 0.12)!,
              base,
              Color.lerp(base, VaultTokens.goldInk, 0.45)!,
            ],
            stops: const [0, 0.6, 1],
          ).createShader(rect),
      );
      if (geometry.sweeps[i] * 180 / math.pi >=
          DailyTokens.minLabelSweepDegrees) {
        final mid = geometry.starts[i] + geometry.sweeps[i] / 2;
        final painter = TextPainter(
          text: TextSpan(
            text: '+${prizes[i].coins}',
            style: label.copyWith(
              color: jackpot ? VaultTokens.goldInk : VaultTokens.goldLight,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final at =
            center +
            Offset(math.cos(mid), math.sin(mid)) *
                (radius * DailyTokens.labelRadius);
        // Always upright, whatever the slice's angle: a prize is read, not
        // decoded.
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(-rotation);
        painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
        canvas.restore();
      }
    }
    // Gold dividers between the slices.
    final divider = Paint()
      ..color = VaultTokens.gold.withValues(alpha: 0.85)
      ..strokeWidth = DailyTokens.wheelRim / 2;
    for (final start in geometry.starts) {
      canvas.drawLine(
        center,
        center + Offset(math.cos(start), math.sin(start)) * radius,
        divider,
      );
    }
    canvas.restore();

    // Depth: the face darkens toward the rim.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            VaultTokens.goldInk.withValues(alpha: 0),
            VaultTokens.goldInk.withValues(alpha: VaultTokens.sliceShade),
          ],
          stops: const [0.55, 1],
        ).createShader(rect),
    );

    // The rim: a band of metal under its studs, lit from the top left.
    final band = Rect.fromCircle(
      center: center,
      radius: radius + VaultTokens.wheelRimWidth / 2,
    );
    canvas.drawCircle(
      center,
      radius + VaultTokens.wheelRimWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = VaultTokens.wheelRimWidth
        ..shader = const SweepGradient(
          colors: [
            VaultTokens.goldLight,
            VaultTokens.gold,
            VaultTokens.goldDeep,
            VaultTokens.gold,
            VaultTokens.goldLight,
          ],
          transform: GradientRotation(-math.pi * 0.75),
        ).createShader(band),
    );
    // Studs set into the band; they turn with the wheel.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    final studShade = Paint()..color = VaultTokens.goldInk;
    final studLight = Paint()..color = VaultTokens.goldLight;
    final ring = radius + VaultTokens.wheelRimWidth / 2;
    for (var i = 0; i < VaultTokens.wheelStuds; i++) {
      final a = i * 2 * math.pi / VaultTokens.wheelStuds;
      final p = center + Offset(math.cos(a), math.sin(a)) * ring;
      canvas.drawCircle(p, VaultTokens.wheelStud, studShade);
      canvas.drawCircle(
        p.translate(-0.4, -0.4),
        VaultTokens.wheelStud * 0.7,
        studLight,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = VaultTokens.goldDeep,
    );

    // The hub: an enamel boss under the coin, with a gold ring.
    canvas.drawCircle(
      center,
      DailyTokens.wheelHub,
      Paint()..color = VaultTokens.enamel,
    );
    canvas.drawCircle(
      center,
      DailyTokens.wheelHub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = DailyTokens.wheelRim
        ..color = VaultTokens.gold,
    );

    // The pointer, fixed at the top: it flicks back as each stud passes.
    var flick = 0.0;
    if (spinning) {
      const step = 2 * math.pi / VaultTokens.wheelStuds;
      final phase = ((rotation % step) + step) % step / step;
      flick = -0.35 * math.max(0, 1 - phase * 4);
    }
    final tipY = center.dy - radius + DailyTokens.pointer * 0.35;
    final pivot = Offset(
      center.dx,
      center.dy - outer - DailyTokens.pointer * 0.15,
    );
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(flick);
    canvas.translate(-pivot.dx, -pivot.dy);
    final pointer = Path()
      ..moveTo(center.dx, tipY)
      ..lineTo(center.dx - DailyTokens.pointer / 2, pivot.dy)
      ..quadraticBezierTo(
        center.dx,
        pivot.dy - DailyTokens.pointer * 0.6,
        center.dx + DailyTokens.pointer / 2,
        pivot.dy,
      )
      ..close();
    canvas.drawShadow(
      pointer,
      colors.shadow,
      VaultTokens.buttonGlowDrop,
      false,
    );
    canvas.drawPath(
      pointer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            VaultTokens.goldLight,
            VaultTokens.gold,
            VaultTokens.goldDeep,
          ],
        ).createShader(pointer.getBounds()),
    );
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = VaultTokens.goldInk,
    );
    canvas.drawCircle(
      pivot.translate(0, -DailyTokens.pointer * 0.12),
      VaultTokens.wheelStud * 1.2,
      Paint()..color = VaultTokens.oxblood,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(WheelPainter old) =>
      old.rotation != rotation ||
      old.prizes != prizes ||
      old.colors != colors ||
      old.spinning != spinning;
}
