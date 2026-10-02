import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/monetization/rewarded_ads.dart';
import '../screens/online/online_session.dart';
import 'ad_extras.dart';
import 'ad_veil.dart';
import 'council.dart';
import 'daily_rewards.dart';
import 'reward_poll.dart';
import 'wallet.dart';

/// The vault's rewarded offers. Each is one optional ad a UTC day, credited
/// only by the server once AdMob's signed callback (SSV) lands.
enum AdReward { dailyAd, extraSpin, extraCoffer, extraSwap }

extension AdRewardWire on AdReward {
  /// The server's name for an extra (`extra_claim`'s `kind`).
  String? get extraKind => switch (this) {
    AdReward.dailyAd => null,
    AdReward.extraSpin => 'spin',
    AdReward.extraCoffer => 'coffer',
    AdReward.extraSwap => 'swap',
  };

  /// The ledger prefix in the ad's custom data (see `_shared/ad_rewards.ts`).
  String get prefix => this == AdReward.dailyAd ? 'd1' : 'x1';

  RewardedPlacement get placement => this == AdReward.dailyAd
      ? RewardedPlacement.daily
      : RewardedPlacement.extra;
}

/// Where one offer stands on this device.
enum AdRewardPhase {
  idle,

  /// Claim requested, ad loading or on screen.
  watching,

  /// The ad was watched to the end; waiting for the server to confirm it.
  verifying,

  /// Watched, but the server had not confirmed it inside the check window.
  /// Never offered as "watch again": the screen says it is on its way and
  /// checks again on a tap, on return to the app and when the tab opens.
  late,
}

/// A reward the server confirmed, for the win animation. [seq] grows with
/// every landing, so a screen can tell a new one from one it already showed.
@immutable
class AdRewardLanded {
  final AdReward kind;
  final int amount;
  final int? slot;
  final int seq;
  const AdRewardLanded(this.kind, this.amount, this.slot, this.seq);
}

@immutable
class AdRewardFlowState {
  final Map<AdReward, AdRewardPhase> phases;
  final AdRewardLanded? landed;
  const AdRewardFlowState({this.phases = const {}, this.landed});

  AdRewardPhase phaseOf(AdReward kind) => phases[kind] ?? AdRewardPhase.idle;

  /// An ad is loading, on screen, or being confirmed: no second one starts.
  bool get busy => phases.values.any(
    (p) => p == AdRewardPhase.watching || p == AdRewardPhase.verifying,
  );

  AdRewardFlowState copyWith(
    AdReward kind,
    AdRewardPhase phase, {
    AdRewardLanded? landed,
  }) => AdRewardFlowState(
    phases: {...phases, kind: phase},
    landed: landed ?? this.landed,
  );
}

/// What a tap on an offer came to, for the screen's one-line answer.
@immutable
class AdRewardAttempt {
  final RewardedAdOutcome? outcome;

  /// The server's refusal code ('' when unknown); null when not refused.
  final String? refusal;
  final bool alreadyAwarded;
  final bool busy;

  const AdRewardAttempt._({
    this.outcome,
    this.refusal,
    this.alreadyAwarded = false,
    this.busy = false,
  });

  const AdRewardAttempt.shown(RewardedAdOutcome outcome)
    : this._(outcome: outcome);
  const AdRewardAttempt.refused(String? code) : this._(refusal: code ?? '');
  static const awarded = AdRewardAttempt._(alreadyAwarded: true);
  static const waiting = AdRewardAttempt._(busy: true);
}

final adRewardFlowProvider = NotifierProvider<AdRewardFlow, AdRewardFlowState>(
  AdRewardFlow.new,
);

/// One place that runs every vault offer from tap to credited coins:
/// claim → ad → wait for the server's word → balance and animation.
///
/// It lives above the screens on purpose. The wait for AdMob's callback can
/// outlast the tab that started it (a tab rebuilt when the app resumes, the
/// vault closed): the wait carries on, the balance still moves, and the
/// offer still reads "confirmed" the next time it is drawn. Nothing here
/// grants anything — the server credits exactly once per claim, and a
/// second tap while one is in flight starts nothing.
class AdRewardFlow extends Notifier<AdRewardFlowState> {
  final _epochs = <AdReward, int>{};
  bool _disposed = false;

  @override
  AdRewardFlowState build() {
    ref.onDispose(() => _disposed = true);
    return const AdRewardFlowState();
  }

  void _set(AdReward kind, AdRewardPhase phase, {AdRewardLanded? landed}) {
    if (_disposed) return;
    state = state.copyWith(kind, phase, landed: landed);
  }

  int _bump(AdReward kind) => _epochs[kind] = (_epochs[kind] ?? 0) + 1;

  Future<String?> _claim(AdReward kind, int? slot) => kind == AdReward.dailyAd
      ? ref.read(dailyProvider.notifier).createAdClaim()
      : ref.read(adExtrasProvider.notifier).claim(kind.extraKind!, slot: slot);

  Future<bool> _isAwarded(AdReward kind) => kind == AdReward.dailyAd
      ? ref.read(dailyProvider.notifier).adAwarded()
      : ref.read(adExtrasProvider.notifier).awarded(kind.extraKind!);

  /// Runs one offer. Completes when the ad is gone; the server's
  /// confirmation follows in [state].
  Future<AdRewardAttempt> watch(AdReward kind, {int? slot}) async {
    if (state.busy) return AdRewardAttempt.waiting;
    _bump(kind);
    _set(kind, AdRewardPhase.watching);
    try {
      final claimId = await _claim(kind, slot);
      if (claimId == null) {
        // Already credited today (another device, an earlier session): the
        // claim call refreshed the status; nothing to show.
        _set(kind, AdRewardPhase.idle);
        return AdRewardAttempt.awarded;
      }
      final backend = await ref.read(onlineBackendFactoryProvider)();
      final userId = await backend.ensureSession();
      final outcome = await showRewardedWith(
        ref.read,
        customData: '${kind.prefix}:$claimId',
        userId: userId,
        placement: kind.placement,
      );
      if (outcome == RewardedAdOutcome.earned) {
        _set(kind, AdRewardPhase.verifying);
        unawaited(_verify(kind));
      } else {
        _set(kind, AdRewardPhase.idle);
      }
      return AdRewardAttempt.shown(outcome);
    } on DailyActionFailed catch (error) {
      _set(kind, AdRewardPhase.idle);
      return AdRewardAttempt.refused(error.code);
    } on AdExtraFailed catch (error) {
      _set(kind, AdRewardPhase.idle);
      return AdRewardAttempt.refused(error.code);
    } catch (_) {
      _set(kind, AdRewardPhase.idle);
      return const AdRewardAttempt.shown(RewardedAdOutcome.failed);
    }
  }

  Future<void> _verify(AdReward kind) async {
    final epoch = _bump(kind);
    bool alive() => !_disposed && _epochs[kind] == epoch;
    final landed = await pollForReward(
      awarded: () => _isAwarded(kind),
      alive: alive,
    );
    if (!alive()) return;
    if (landed) {
      _land(kind);
    } else {
      _set(kind, AdRewardPhase.late);
    }
  }

  /// One more look at a watched offer the server had not confirmed yet.
  Future<bool> recheck(AdReward kind) async {
    if (state.phaseOf(kind) != AdRewardPhase.late) return false;
    final epoch = _bump(kind);
    _set(kind, AdRewardPhase.verifying);
    var done = false;
    try {
      done = await _isAwarded(kind);
    } catch (_) {}
    if (_disposed || _epochs[kind] != epoch) return done;
    if (done) {
      _land(kind);
    } else {
      _set(kind, AdRewardPhase.late);
    }
    return done;
  }

  /// The app came back, or a screen with offers opened: every late reward
  /// is looked at again.
  void recheckLate() {
    for (final kind in AdReward.values) {
      if (state.phaseOf(kind) == AdRewardPhase.late) unawaited(recheck(kind));
    }
  }

  void _land(AdReward kind) {
    final daily = ref.read(dailyProvider).valueOrNull;
    final extras = ref.read(adExtrasProvider).valueOrNull;
    final (amount, slot) = switch (kind) {
      AdReward.dailyAd => (daily?.adAmount ?? 0, null),
      AdReward.extraSpin => (extras?.spin.amount ?? 0, extras?.spin.slot),
      AdReward.extraCoffer => (extras?.coffer.amount ?? 0, null),
      AdReward.extraSwap => (0, null),
    };
    _set(
      kind,
      AdRewardPhase.idle,
      landed: AdRewardLanded(kind, amount, slot, (state.landed?.seq ?? 0) + 1),
    );
    // Every balance on screen follows at once, then the server's number.
    unawaited(ref.read(walletProvider.notifier).settle(credited: amount));
    if (kind == AdReward.extraSwap &&
        ref.read(councilProvider).valueOrNull != null) {
      unawaited(ref.read(councilProvider.notifier).refresh());
    }
  }
}
