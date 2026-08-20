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

  /// Whether the pad is currently under a finger.
  ///
  /// Drives nothing but the press scale. Deliberately separate from `_timer`,
  /// which is the load-bearing state: if these two ever disagree the visual is
  /// wrong for a frame and the timing is still exact.
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ring.duration = widget.holdDuration;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ring.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    if (_done || _timer != null) return;
    setState(() => _pressed = true);
    _ring.forward();
    _timer = Timer(widget.holdDuration, () {
      _timer = null;
      if (!mounted || _done) return;
      _done = true;
      widget.onHoldComplete();
    });
  }

  void _release([PointerEvent? _]) {
    if (mounted && _pressed) setState(() => _pressed = false);
    if (_done) return;
    _timer?.cancel();
    _timer = null;
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
