import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/metrics.dart';
import 'package:mafia_master/platform/monetization/metered_rewarded_ads.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';

/// Usage counts (owner, 2026-10-30): every rewarded ad leaves one count of
/// its offer and outcome, and nothing about the claim or the account.
void main() {
  late List<Map<String, Object?>> sent;
  late MetricsClient metrics;

  setUp(() {
    sent = [];
    metrics = MetricsClient(
      enabled: () async => true,
      send: (body) async => sent.add(body),
      requestId: () => '00000000-0000-4000-8000-000000000001',
    );
  });

  test('each outcome is counted under its offer', () async {
    for (final outcome in RewardedAdOutcome.values) {
      final ads = MeteredRewardedAds(_Ads(outcome: outcome), metrics);
      expect(
        await ads.show(
          claimId: 'claim',
          userId: 'user',
          placement: RewardedPlacement.daily,
        ),
        outcome,
      );
      await metrics.settled;
    }
    expect(sent.map((b) => b['prop']), [
      'daily:earned',
      'daily:dismissed',
      'daily:unavailable',
      'daily:failed',
      'daily:not_consented',
    ]);
    for (final body in sent) {
      expect(body['event'], 'ad_result');
      expect(body.values.whereType<String>(), isNot(contains('claim')));
      expect(body.values.whereType<String>(), isNot(contains('user')));
    }
  });

  test('a thrown ad counts as failed and still throws', () async {
    final ads = MeteredRewardedAds(_Ads(throws: true), metrics);
    await expectLater(
      ads.show(
        claimId: 'c',
        userId: 'u',
        placement: RewardedPlacement.matchStepTwo,
      ),
      throwsStateError,
    );
    await metrics.settled;
    expect(sent.single['prop'], 'match_step_two:failed');
  });

  test('every offer has a name the server accepts', () {
    expect(RewardedPlacement.values.map(MeteredRewardedAds.offer), [
      'match',
      'match_step',
      'match_step_two',
      'daily',
      'extra',
    ]);
  });

  test('the wrapper forwards the rest and preloads only a preloader', () async {
    final inner = _Ads();
    final ads = MeteredRewardedAds(inner, metrics);
    expect(ads.configured, isTrue);
    await ads.preload(RewardedPlacement.extra);
    expect(inner.preloaded, [RewardedPlacement.extra]);
    await MeteredRewardedAds(
      _Plain(),
      metrics,
    ).preload(RewardedPlacement.extra);
    ads.dispose();
    expect(inner.disposed, isTrue);
    expect(sent, isEmpty);
  });

  test('table size goes out as a range', () {
    expect(tableSizeBucket(5), 'p4_6');
    expect(tableSizeBucket(6), 'p4_6');
    expect(tableSizeBucket(7), 'p7_9');
    expect(tableSizeBucket(12), 'p10_12');
    expect(tableSizeBucket(16), 'p13_plus');
  });
}

class _Plain implements RewardedAds {
  @override
  bool get configured => true;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> checkPrivacyOptions() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async => RewardedAdOutcome.earned;
  @override
  void dispose() {}
}

class _Ads extends _Plain implements RewardedPreload {
  _Ads({this.outcome = RewardedAdOutcome.earned, this.throws = false});
  final RewardedAdOutcome outcome;
  final bool throws;
  final preloaded = <RewardedPlacement>[];
  bool disposed = false;

  @override
  Future<RewardedAdOutcome> show({
    required String claimId,
    required String userId,
    RewardedPlacement placement = RewardedPlacement.matchLegacy,
  }) async {
    if (throws) throw StateError('sdk');
    return outcome;
  }

  @override
  Future<void> preload(RewardedPlacement placement) async =>
      preloaded.add(placement);

  @override
  void dispose() => disposed = true;
}
