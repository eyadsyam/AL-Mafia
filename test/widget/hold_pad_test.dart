import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';

import '../support/localized.dart';

/// The identity hold as distribution actually configures it
/// (`MatchSettings.identityHoldSeconds`), not the 600ms token. The bugs these
/// tests cover are only reachable at a duration long enough for a hand to
/// fumble during it, and five seconds is what ships.
const _hold = Duration(seconds: 5);
const _frame = Duration(milliseconds: 50);

double _ring(WidgetTester tester) => tester
        .widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .value ??
    -1;

Future<void> _pad(WidgetTester tester, VoidCallback onComplete) async {
  await tester.pumpWidget(
    localizedApp(
      Center(
        child: HoldPad(
          holdDuration: _hold,
          instruction: 'hold',
          onHoldComplete: onComplete,
        ),
      ),
    ),
  );
}

/// Pumps real frames for [d], returning when the ring first reads full.
Future<Duration?> _pumpWatchingRing(WidgetTester tester, Duration d) async {
  var elapsed = Duration.zero;
  Duration? full;
  while (elapsed < d) {
    await tester.pump(_frame);
    elapsed += _frame;
    if (full == null && _ring(tester) >= 0.999) full = elapsed;
  }
  return full;
}

void main() {
  testWidgets('a clean hold completes once, at the end of the duration',
      (tester) async {
    var completions = 0;
    await _pad(tester, () => completions++);

    final g = await tester.startGesture(tester.getCenter(find.byType(HoldPad)));
    await tester.pump(_hold - const Duration(milliseconds: 100));
    expect(completions, 0, reason: 'fired before the hold was up');

    await tester.pump(const Duration(milliseconds: 200));
    expect(completions, 1);

    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1, reason: 'releasing must not fire it again');
  });

  testWidgets('releasing early cancels the hold', (tester) async {
    var completions = 0;
    await _pad(tester, () => completions++);

    final g = await tester.startGesture(tester.getCenter(find.byType(HoldPad)));
    await tester.pump(const Duration(seconds: 2));
    await g.up();
    await tester.pump(const Duration(seconds: 10));
    expect(completions, 0);
  });

  // Regression: the ring used to be resumed from wherever the previous attempt
  // left it. `AnimationController.forward()` scales its duration by the
  // distance still to travel, so the ring filled in a fraction of the hold
  // while the timer beside it ran the full length — and each abandoned attempt
  // left the ring fuller, so the next one filled faster still. The pad read as
  // finished and did nothing, permanently.
  testWidgets('the ring never reads full before the hold has completed',
      (tester) async {
    var completions = 0;
    await _pad(tester, () => completions++);
    final centre = tester.getCenter(find.byType(HoldPad));

    // A hold that gets almost all the way there, then the finger slips.
    final slipped = await tester.startGesture(centre);
    await _pumpWatchingRing(tester, const Duration(milliseconds: 4500));
    await slipped.up();
    await tester.pump(_frame * 4);

    // The player presses again and watches the ring for the whole hold.
    final again = await tester.startGesture(centre);
    final full = await _pumpWatchingRing(tester, _hold + _frame * 3);
    await again.up();

    expect(completions, 1, reason: 'the second hold ran its full length');
    expect(
      full,
      isNotNull,
      reason: 'the ring should have filled during a completed hold',
    );
    expect(
      full!.inMilliseconds,
      greaterThanOrEqualTo(_hold.inMilliseconds - _frame.inMilliseconds),
      reason: 'the ring said done at ${full.inMilliseconds}ms of a '
          '${_hold.inMilliseconds}ms hold',
    );
  });

  // Regression: a second finger's pointer-down was ignored but its pointer-up
  // was not, so a steadying touch on the pad cancelled the hold the first
  // finger was still making — and that finger, never having lifted, could not
  // start another one.
  testWidgets('a second finger on the pad cannot cancel the hold',
      (tester) async {
    var completions = 0;
    await _pad(tester, () => completions++);
    final centre = tester.getCenter(find.byType(HoldPad));

    final thumb = await tester.startGesture(centre, pointer: 1);
    await tester.pump(const Duration(milliseconds: 500));

    final brush = await tester.startGesture(centre, pointer: 2);
    await tester.pump(const Duration(milliseconds: 100));
    await brush.up();

    await tester.pump(_hold);
    expect(completions, 1, reason: 'the owning finger never left the pad');

    await thumb.up();
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  testWidgets('a second finger cannot start a hold of its own', (tester) async {
    var completions = 0;
    await _pad(tester, () => completions++);
    final centre = tester.getCenter(find.byType(HoldPad));

    final thumb = await tester.startGesture(centre, pointer: 1);
    await tester.pump(const Duration(seconds: 1));
    final other = await tester.startGesture(centre, pointer: 2);

    // The owning finger lifts three seconds in; the hold dies with it even
    // though the pad is still being touched by the other one.
    await tester.pump(const Duration(seconds: 2));
    await thumb.up();
    await tester.pump(const Duration(seconds: 10));
    expect(completions, 0);

    await other.up();
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 0);
  });

  testWidgets('the pad recovers after an abandoned attempt', (tester) async {
    var completions = 0;
    await _pad(tester, () => completions++);
    final centre = tester.getCenter(find.byType(HoldPad));

    for (var attempt = 0; attempt < 3; attempt++) {
      final g = await tester.startGesture(centre);
      await tester.pump(const Duration(seconds: 3));
      await g.up();
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(completions, 0);

    final g = await tester.startGesture(centre);
    await tester.pump(_hold + const Duration(milliseconds: 100));
    await g.up();
    await tester.pump();
    expect(completions, 1, reason: 'a fourth, complete hold must still work');
  });
}
