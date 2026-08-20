import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';

import '../support/artwork.dart';
import '../support/localized.dart';
import '../support/reveal_flow.dart';

/// L-04 — the card flip is identical across roles at every stage, not just at
/// the ends.
///
/// # Why the endpoints are not enough
///
/// `reveal_symmetry_test.dart` compares the card face-down and the card
/// face-up. Both of those are correct and neither says anything about the
/// second in between — which is the second the table is actually watching,
/// because a card being turned over is the most conspicuous thing that happens
/// all game.
///
/// Everything that could make the middle of the flip role-dependent is
/// invisible at the endpoints:
///
///   * a curve or duration derived from the role, so one card turns faster;
///   * the front face swapping in early, so a brighter painting is exposed a
///     frame or two sooner for one role than another;
///   * artwork of a different size being scaled during the rotation.
///
/// Any of those reads as "the Mafia card flips differently", which is a tell
/// even though both endpoints match perfectly.
///
/// # What is compared
///
/// Five sample points across the flip.
///
/// Three of them — face-down, a quarter turned, and edge-on at the halfway
/// mark — are the stages the table can see, and at each one all four roles are
/// rendered and compared **to each other**. Not to a checked-in golden file: a
/// golden would have to be regenerated every time the art changed, and a golden
/// that gets regenerated on every art change has stopped asserting anything.
///
/// The fourth checks that the mafia teammate list is not yet painted at the
/// halfway point — a leak the pixel comparison alone could miss, because all
/// four front faces are luminance-matched to each other by
/// `luminance_budget_test.dart` and an early swap would barely move the mean.
///
/// The fifth is the fully revealed card, and it asserts the **opposite**: past
/// 90 degrees the front is showing, the four fronts are four different
/// paintings, and they had better measure as different. That is the vacuity
/// guard for the whole file — if the frame capture were seeing nothing, it would
/// report "identical" everywhere and every assertion above would be empty.
void main() {
  const surface = Size(390, 844);
  const boundaryKey = ValueKey('flip_boundary');
  final flipDuration = MafiaMotion.defaults.dramatic;

  var mountCounter = 0;

  /// Renders [role] and advances the flip to [elapsed], returning the frame.
  Future<Uint8List> frameAt(
    WidgetTester tester,
    Role role,
    Duration elapsed,
  ) async {
    await tester.binding.setSurfaceSize(surface);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: localizedApp(
          RoleCard(
            // A fresh key per mount so each stage starts from a face-down card.
            key: ValueKey('flip-${mountCounter++}'),
            playerName: 'Player',
            role: role,
            // Mafia's teammate list is the one piece of role-conditional
            // content on the card. It lives on the front face, so it must not
            // be visible before the halfway point — including it here is what
            // makes that testable rather than assumed.
            teammateNames:
                role == Role.mafia ? const ['Aaaa', 'Bbbb'] : const [],
            onDismissed: () {},
          ),
        ),
      ),
    );
    await loadArtwork(tester);

    // Step 1, then step 2. The swipe is what starts the flip, and it ends on
    // frame zero of it — `settle: false` because advancing the clock here is
    // exactly what the caller is about to do deliberately.
    await tester.confirmIdentity();
    await tester.swipeToFlip(settle: false);

    if (elapsed > Duration.zero) await tester.pump(elapsed);
    await loadArtwork(tester);

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final bytes = await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    });
    return bytes!;
  }

  /// Mean absolute per-channel difference between two frames, in levels.
  ///
  /// A scalar rather than an exact-equality check because WebP decode and the
  /// rasteriser are not bit-reproducible across runs; what matters is whether a
  /// person could see the difference, and a mean of a fraction of a level is far
  /// below that.
  double meanDelta(Uint8List a, Uint8List b) {
    expect(a.length, b.length,
        reason: 'frames are different sizes, so the two roles are not even '
            'laying out to the same bounds — that is a leak on its own.');
    var total = 0.0;
    for (var i = 0; i < a.length; i++) {
      total += (a[i] - b[i]).abs();
    }
    return total / a.length;
  }

  /// Well under the threshold of visibility; comfortably above codec noise.
  const budget = 1.0;

  /// The fraction of [flipDuration] at which the card passes edge-on and its
  /// front — and the text beneath it — become visible.
  ///
  /// Solved rather than assumed to be 0.5. The flip runs through
  /// `MafiaMotion.dramaticCurve`, which is not symmetric, so half the *duration*
  /// is not half the *rotation*. Sampling on the wrong side of this boundary was
  /// how the halfway stage below spent a while reporting the reveal itself as a
  /// leak.
  double swapFraction() {
    final curve = MafiaMotion.defaults.dramaticCurve;
    var lo = 0.0, hi = 1.0;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (curve.transform(mid) < 0.5) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hi;
  }

  group('L-04 flip stage symmetry', () {
    final swap = swapFraction();

    /// Named fractions of the flip, all strictly *before* the card turns past
    /// edge-on. These are the frames the table can see while the card still
    /// says nothing, and nothing in them may depend on the role.
    final stages = <String, double>{
      'face-down, before any rotation': 0.0,
      'a quarter turned': swap * 0.5,
      'the last frame before the card passes edge-on': swap * 0.95,
    };

    for (final stage in stages.entries) {
      testWidgets('all four roles match ${stage.key}', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final elapsed = flipDuration * stage.value;
        final frames = <Role, Uint8List>{};
        for (final role in Role.values) {
          frames[role] = await frameAt(tester, role, elapsed);
        }

        final reference = frames[Role.citizen]!;
        for (final entry in frames.entries) {
          if (entry.key == Role.citizen) continue;
          final delta = meanDelta(reference, entry.value);
          expect(
            delta,
            lessThan(budget),
            reason: 'LEAK: at "${stage.key}" the ${entry.key.name} card differs '
                'from the citizen card by ${delta.toStringAsFixed(3)} levels on '
                'average. The card is still edge-on or face-down here, so the '
                'table can see this frame and nothing in it may depend on the '
                'role. Check for a role-derived curve, duration, or an early '
                'front-face swap.',
          );
        }
      });
    }

    testWidgets('nothing the card says is legible before it turns past edge-on',
        (tester) async {
      // The stages above could pass for the wrong reason. If the front swapped
      // in early but all four fronts happened to be luminance-matched (they
      // are — see luminance_budget_test.dart), a pixel comparison could stay
      // under budget while the reveal had already begun. The mafia teammate
      // list is the tell that cannot be luminance-matched away, and it is only
      // ever rendered for one role.
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final before = await frameAt(tester, Role.mafia, flipDuration * (swap * 0.95));
      expect(
        find.text('Aaaa', skipOffstage: false).evaluate().where((e) {
          // Laid out but not painted is fine and is how the slot keeps its
          // size; what matters is whether it reaches the screen.
          final visibility =
              e.findAncestorWidgetOfExactType<Visibility>();
          return visibility == null || visibility.visible;
        }),
        isEmpty,
        reason: 'the mafia teammate list is visible while the card is still '
            'side-on to the table. Everyone opposite can read it.',
      );
      expect(before, isNotEmpty);
    });

    testWidgets('all four roles begin to differ on the same frame',
        (tester) async {
      // The pair of facts that pins the reveal: identical up to the boundary,
      // different immediately after it. Without the second half, a card that
      // never revealed anything at all would satisfy every assertion in this
      // file.
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final justAfter = flipDuration * (swap * 1.05);
      final frames = <Role, Uint8List>{};
      for (final role in Role.values) {
        frames[role] = await frameAt(tester, role, justAfter);
      }

      for (final entry in frames.entries) {
        if (entry.key == Role.citizen) continue;
        expect(meanDelta(frames[Role.citizen]!, entry.value),
            greaterThan(budget),
            reason: 'one frame past edge-on the ${entry.key.name} card is '
                'still indistinguishable from the citizen card, so either the '
                'reveal happens later for some roles than others, or it is not '
                'happening at all');
      }
    });

    testWidgets('the comparison can detect a real difference', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Fully revealed: the four fronts are four different paintings, and the
      // mafia card carries a teammate list nobody else has. If this passes as
      // "identical", every assertion above is measuring nothing.
      final citizen = await frameAt(tester, Role.citizen, flipDuration);
      final mafia = await frameAt(tester, Role.mafia, flipDuration);

      expect(meanDelta(citizen, mafia), greaterThan(budget),
          reason: 'the revealed mafia and citizen cards measured as identical. '
              'They are different paintings with different text, so the frame '
              'capture is not seeing the card at all — every "roles match" '
              'assertion in this file is therefore vacuous.');
    });
  });
}
