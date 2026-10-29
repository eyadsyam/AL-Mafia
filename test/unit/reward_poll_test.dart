import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/reward_poll.dart';

/// After a rewarded ad the server confirms the reward a little later; the app
/// asks again with a growing gap until it answers, the screen goes, or the
/// window runs out. Runs on the test binding's fake clock.
void main() {
  const first = Duration(seconds: 1);
  const cap = Duration(seconds: 4);
  const window = Duration(seconds: 20);

  Future<(bool?, List<Duration>)> run(
    WidgetTester tester, {
    required bool Function(int call) answer,
    bool Function()? alive,
    Duration pumpFor = const Duration(seconds: 30),
  }) async {
    final asked = <Duration>[];
    var elapsed = Duration.zero;
    var calls = 0;
    bool? result;
    pollForReward(
      awarded: () async {
        asked.add(elapsed);
        return answer(calls++);
      },
      alive: alive ?? () => true,
      first: first,
      cap: cap,
      window: window,
    ).then((v) => result = v);
    const tick = Duration(milliseconds: 250);
    while (elapsed < pumpFor && result == null) {
      elapsed += tick;
      await tester.pump(tick);
    }
    await tester.pumpWidget(const SizedBox());
    return (result, asked);
  }

  testWidgets('the gap doubles up to the cap, then the window closes', (
    tester,
  ) async {
    final (result, asked) = await run(tester, answer: (_) => false);
    expect(result, isFalse);
    // 1, 2, 4, then the 4-second cap; the last wait starts inside the window.
    expect(asked.map((d) => d.inSeconds), [1, 3, 7, 11, 15, 19, 23]);
  });

  testWidgets('the first yes ends the wait', (tester) async {
    final (result, asked) = await run(tester, answer: (call) => call == 2);
    expect(result, isTrue);
    expect(asked, hasLength(3));
  });

  testWidgets('a failed check is only a check that has not answered', (
    tester,
  ) async {
    final (result, asked) = await run(
      tester,
      answer: (call) => call == 0 ? throw StateError('offline') : true,
    );
    expect(result, isTrue);
    expect(asked, hasLength(2));
  });

  testWidgets('a closed screen stops asking', (tester) async {
    var open = true;
    final (result, asked) = await run(
      tester,
      answer: (call) {
        open = false;
        return false;
      },
      alive: () => open,
    );
    expect(result, isFalse);
    expect(asked, hasLength(1));
  });

  testWidgets('a screen closed before the first check never asks', (
    tester,
  ) async {
    final (result, asked) = await run(
      tester,
      answer: (_) => true,
      alive: () => false,
    );
    expect(result, isFalse);
    expect(asked, isEmpty);
  });
}
