import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads.dart';
import 'package:mafia_master/platform/monetization/rewarded_ads_mobile.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

void main() {
  testWidgets('a tap joins the in-flight load', (tester) async {
    final gate = RewardedLoadGate();
    final loaded = Completer<void>();
    var starts = 0;
    Future<void> load() {
      starts++;
      return loaded.future;
    }

    final warm = gate.run('unit', load);
    final tap = gate.run('unit', load);
    expect(starts, 1);
    var done = 0;
    unawaited(warm.then((_) => done++));
    unawaited(tap.then((_) => done++));
    loaded.complete();
    await tester.pump();
    expect(done, 2);
    expect(starts, 1);
    // Once it lands, the next call is a new load.
    unawaited(gate.run('unit', load));
    expect(starts, 2);
  });

  testWidgets('failed loads retry with capped backoff and stop at the cap', (
    tester,
  ) async {
    final retried = <RewardedPlacement>[];
    final queue = RewardedRetryQueue(retried.add);
    addTearDown(queue.dispose);

    for (
      var attempt = 1;
      attempt <= AdTokens.rewardedMaxLoadAttempts;
      attempt++
    ) {
      queue.failed(RewardedPlacement.extra);
      if (attempt == AdTokens.rewardedMaxLoadAttempts) break;
      const delays = AdTokens.rewardedRetryDelays;
      final delay = delays[(attempt - 1).clamp(0, delays.length - 1)];
      await tester.pump(delay);
      expect(retried.length, attempt);
    }
    await tester.pump(AdTokens.rewardedRetryDelays.last);
    expect(retried.length, AdTokens.rewardedMaxLoadAttempts - 1);
  });

  testWidgets('success and disposal cancel pending retries', (tester) async {
    final retried = <RewardedPlacement>[];
    final queue = RewardedRetryQueue(retried.add);
    queue.failed(RewardedPlacement.extra);
    queue.succeeded(RewardedPlacement.extra);
    await tester.pump(AdTokens.rewardedRetryDelays.first);
    expect(retried, isEmpty);

    queue.failed(RewardedPlacement.daily);
    queue.dispose();
    await tester.pump(AdTokens.rewardedRetryDelays.first);
    expect(retried, isEmpty);
  });

  testWidgets('a failed preload can recover on its scheduled retry', (
    tester,
  ) async {
    var loads = 1; // The visible offer's first load failed.
    late RewardedRetryQueue queue;
    queue = RewardedRetryQueue((placement) {
      loads++;
      queue.succeeded(placement);
    });
    addTearDown(queue.dispose);
    queue.failed(RewardedPlacement.extra);
    await tester.pump(AdTokens.rewardedRetryDelays.first);
    expect(loads, 2);
    await tester.pump(AdTokens.rewardedRetryDelays.last);
    expect(loads, 2);
  });
}
