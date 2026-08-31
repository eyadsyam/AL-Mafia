import 'dart:async';

import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';

/// The press-and-hold identity pad shared by every handoff surface.
///
/// The completion is driven by a [Timer], not by the progress ring's animation
/// finishing. A ring is decoration; a decoration must never be load-bearing for
/// a timing invariant, and a `Timer` is exactly as long for every player
/// regardless of frame rate or device (Constitution VI).
///
/// A decoration must not *lie*, either. The ring is therefore always driven
/// from zero over exactly [holdDuration], so it cannot reach the end of its
/// travel before the timer it is illustrating — see [_HoldPadState._down].
///
/// Nothing here emits audio or haptics: this widget only ever appears while the
/// phone is in someone's hand, where a click or a buzz is audible to the people
/// sitting next to them (L-10, L-11).
class HoldPad extends StatefulWidget {
  final Duration holdDuration;
  final String instruction;
  final VoidCallback onHoldComplete;

  /// Diameter of the pad. Defaults to a token-derived size.
  final double? diameter;

  const HoldPad({
    super.key,
    required this.holdDuration,
    required this.instruction,
    required this.onHoldComplete,
    this.diameter,
  });

  @override
  State<HoldPad> createState() => _HoldPadState();
}

class _HoldPadState extends State<HoldPad> with SingleTickerProviderStateMixin {
  late final AnimationController _ring;
  Timer? _timer;
  bool _done = false;

  /// The pointer that owns the hold in flight, or null when the pad is idle.
  ///
  /// A pad is held by one finger, not by "the screen is being touched". Without
  /// an owner, a second finger brushing the pad — the steadying hand on a phone
  /// being passed across a table — arrives as a pointer down that is ignored
  /// and then a pointer up that is *not*, and lifting it cancels the hold the
  /// first finger is still making. The player then holds a finger that is
  /// already on the pad for as long as they like and nothing ever happens.
  ///
  /// So every event is matched against the owner: only the finger that started
  /// the hold can end it, and every other pointer on the pad is inert.
  int? _pointer;

  /// Whether the pad is under its owning finger. Drives nothing but the press
  /// scale, and is derived rather than stored so it cannot drift out of step
  /// with the hold it is meant to be showing.
  bool get _pressed => _pointer != null;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ring.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (_done || _pointer != null) return;
    setState(() => _pointer = event.pointer);

    // `from: 0.0`, and the duration reset on every press, are both load-bearing.
    //
    // `AnimationController.forward()` scales its duration by the distance left
    // to travel, so a ring resumed from part-way fills in a *fraction* of
    // `holdDuration` while the timer beside it still runs the full length. That
    // is not a cosmetic drift: with a five-second identity hold, a player whose
    // finger slipped at 4.5s and pressed again 200ms later saw a completely
    // full ring after 600ms with 4.4s still to run. Reading the ring — which is
    // the only thing on screen that claims to know — they let go, which
    // cancelled the timer, which left the ring even fuller for the next
    // attempt, which filled even faster. The pad appeared to finish loading and
    // then do nothing, permanently, and it got worse every time it was tried.
    _ring.duration = widget.holdDuration;
    _ring.forward(from: 0.0);

    _timer = Timer(widget.holdDuration, () {
      _timer = null;
      if (!mounted || _done) return;
      _done = true;
      widget.onHoldComplete();
    });
  }

  void _release(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (!mounted) {
      // `dispose` has already cancelled the timer.
      _pointer = null;
      return;
    }
    setState(() => _pointer = null);
    if (_done) return;
    _timer?.cancel();
    _timer = null;

    // Drained quickly rather than unwound over the hold's own length. The drain
    // is the only feedback that the progress was lost, so it has to finish
    // before the player's next press rather than still be running underneath
    // it.
    _ring.duration = context.motion.quick;
    _ring.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    final motion = context.motion;
    final size = widget.diameter ?? spacing.xxl * 3;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: Semantics(
        button: true,
        label: widget.instruction,
        // The pad dips under the finger and snaps back on release. It is the
        // only confirmation that the press registered before the ring has moved
        // far enough to read, and a pad that does not acknowledge a touch gets
        // pressed twice.
        //
        // Scale, not colour or elevation: this widget is on screen while the
        // phone is in someone's hand, and a brightness change is visible from
        // across the table in a way a 3% geometric change is not (L-10).
        //
        // Under Reduce Motion the scale still applies, instantly — removing the
        // feedback entirely would leave those players with no press
        // confirmation at all, which is a usability regression dressed up as
        // an accessibility feature. `reduce_motion_test.dart` asserts the
        // widget tree keeps its shape either way.
        child: AnimatedScale(
          scale: _pressed ? motion.pressScale : 1.0,
          duration: ReduceMotion.of(context) ? Duration.zero : motion.instant,
          curve: motion.quickCurve,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _ring,
                    builder: (context, _) => CircularProgressIndicator(
                      value: _ring.value,
                      strokeWidth: spacing.xs,
                      backgroundColor: colors.surfaceOverlay,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                  child: Text(
                    widget.instruction,
                    style: type.bodySmall.copyWith(color: colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
