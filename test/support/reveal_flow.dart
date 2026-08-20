import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';

/// Drives the three-step reveal: hold, swipe-flip, auto-conceal.
///
/// ## Why this is shared rather than repeated
///
/// Four test files walk this flow, and each step of it is load-bearing for a
/// different leakage invariant. When the choreography changed from
/// hold-to-flip to hold-then-swipe, every one of those files broke in the same
/// way — silently, by finding a widget that no longer existed in that phase and
/// timing out. Putting the sequence in one place means the next change to it
/// breaks compilation once instead of behaviour four times.
///
/// The durations are read from [MafiaTiming.defaults] rather than written down,
/// so a token change moves the tests with it.
extension RevealFlow on WidgetTester {
  /// Step 1 — hold the identity pad until it completes.
  ///
  /// [hold] must match whatever was passed to `RoleCard.identityHold`, or the
  /// gate will still be counting when this returns.
  Future<void> confirmIdentity({Duration? hold, bool settle = true}) async {
    final pad = find.byKey(RoleCard.holdPad);
    expect(pad, findsOneWidget,
        reason: 'the identity gate is not on screen; the card is already past '
            'step 1');

    final gesture = await startGesture(getCenter(pad));
    await pump();
    await pump(hold ?? MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await pump();
    if (settle) await pumpAndSettle();
  }

  /// Step 2 — swipe right across the card to flip it.
  ///
  /// Crosses the distance threshold rather than relying on velocity, because a
  /// synthetic fling's velocity depends on how the test's clock is being
  /// advanced and a distance does not.
  ///
  /// [settle] advances the clock by exactly the flip and no further.
  ///
  /// Deliberately not `pumpAndSettle`. The auto-conceal countdown is a
  /// five-second *animation* — it drives the progress line under the card — so
  /// it schedules frames the whole time it is running, and settling would run
  /// clean through the reveal window and land on an already-concealed card. The
  /// first version of this helper did exactly that, and every test that thought
  /// it was looking at a face-up card was looking at a face-down one.
  ///
  /// Pass false when measuring the reveal window itself.
  Future<void> swipeToFlip({bool settle = true}) async {
    final card = find.byKey(RoleCard.slotCard);
    expect(card, findsOneWidget,
        reason: 'there is no card to swipe; step 1 has not completed');

    final box = getRect(card);
    final start = Offset(box.left + box.width * 0.15, box.center.dy);

    final gesture = await startGesture(start);
    // Several moves rather than one: the card follows the finger, and a single
    // jump would exercise the end-of-drag branch without ever exercising the
    // tracking that makes the gesture feel physical.
    for (var i = 1; i <= 6; i++) {
      await gesture.moveBy(Offset(box.width * 0.09, 0));
      await pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await pump();
    if (settle) {
      await pump(MafiaMotion.defaults.dramatic + const Duration(milliseconds: 1));
    }
  }

  /// Steps 1 and 2 together — the usual case.
  Future<void> revealCard({Duration? hold}) async {
    await confirmIdentity(hold: hold);
    await swipeToFlip();
  }

  /// Waits out the auto-conceal window and the flip back.
  Future<void> awaitConceal() async {
    await pump(MafiaTiming.defaults.autoRevealDuration);
    await pumpAndSettle();
  }

  /// Pumps until the pass control appears, and returns how long that took.
  ///
  /// Sampled rather than computed. The floor is measured from the moment
  /// identity was confirmed, not from the flip, and how much fake-clock time a
  /// test has already consumed depends on how many animations it settled — so
  /// the honest thing is to watch for the button and report the offset, which
  /// also makes the returned value directly comparable between roles.
  Future<Duration> awaitPassUnlocked({
    Duration step = const Duration(milliseconds: 100),
    Duration limit = const Duration(seconds: 30),
  }) async {
    var waited = Duration.zero;
    while (!passButtonVisible && waited < limit) {
      await pump(step);
      waited += step;
    }
    expect(passButtonVisible, isTrue,
        reason: 'the pass control never unlocked within $limit');
    return waited;
  }

  bool get passButtonVisible =>
      find.byKey(RoleCard.dismiss).evaluate().isNotEmpty;
}
