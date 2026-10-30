import '../metrics.dart';
import 'rewarded_ads.dart';

/// Counts what each rewarded ad did (owner, 2026-10-30), so an ad that sticks
/// or never fills shows up in the daily usage page as a number. Sends only
/// the offer and the outcome, never the claim or the account; the ad itself
/// is untouched.
class MeteredRewardedAds implements RewardedAds, RewardedPreload {
  final RewardedAds _inner;
  final MetricsClient _metrics;

  MeteredRewardedAds(this._inner, this._metrics);

  static String offer(RewardedPlacement placement) => switch (placement) {
    RewardedPlacement.matchLegacy => 'match',
    RewardedPlacement.matchStep => 'match_step',
    RewardedPlacement.matchStepTwo => 'match_step_two',
    RewardedPlacement.daily => 'daily',
    RewardedPlacement.extra => 'extra',
  };

  static String outcome(RewardedAdOutcome outcome) => switch (outcome) {
    RewardedAdOutcome.earned => 'earned',
    RewardedAdOutcome.dismissed => 'dismissed',
    RewardedAdOutcome.unavailable => 'unavailable',
    RewardedAdOutcome.failed => 'failed',
    RewardedAdOutcome.notConsented => 'not_consented',
  };

  @override
  bool get configured => _inner.configured;

  @override
  bool get privacyOptionsRequired => _inner.privacyOptionsRequired;

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  Future<bool> checkPrivacyOptions() => _inner.checkPrivacyOptions();

  @override
  Future<void> showPrivacyOptions() => _inner.showPrivacyOptions();

  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async {
    RewardedAdOutcome result;
    try {
      result = await _inner.show(
        claimId: claimId,
        userId: userId,
        placement: placement,
      );
    } catch (_) {
      _metrics.record('ad_result', prop: '${offer(placement)}:failed');
      rethrow;
    }
    _metrics.record(
      'ad_result',
      prop: '${offer(placement)}:${outcome(result)}',
    );
    return result;
  }

  @override
  Future<void> preload(RewardedPlacement placement) async {
    final inner = _inner;
    if (inner is RewardedPreload) {
      await (inner as RewardedPreload).preload(placement);
    }
  }

  @override
  void dispose() => _inner.dispose();
}
