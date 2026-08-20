import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';

/// Fades and lifts its child into place, delayed by its position in a list.
///
/// ## Where this belongs, and where it does not
///
/// Post-game surfaces only. A staggered entrance draws the eye down a list one
/// item at a time, which is exactly what you want when the match is over and the
/// table is reading its own history together — and exactly what you must not do
/// on any surface a single player holds, where the animation is a moving,
/// role-shaped light source pointed at their face.
///
/// ## Why the delay is an Interval and not a Timer
///
/// One controller runs for `delay + duration` and the child's slice of it is an
/// [Interval]. A `Future.delayed(...).then(forward)` would do the same thing and
/// would also leave a pending callback behind if the screen is popped
/// mid-cascade, and would make `pumpAndSettle` unable to see the animation at
/// all. This way the whole list settles.
///
/// ## Reduce Motion
///
/// Snaps to the finished state on the first frame — never to the initial one.
/// An entrance that starts at zero opacity and never runs is an empty screen,
/// which is a far worse outcome than a missing flourish.
class StaggeredEntrance extends StatefulWidget {
  /// Position in the list, counted from the top. Only delays this item.
  final int index;

  /// How far the child rises into place, in logical pixels.
  final double rise;

  final Widget child;

  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.rise = 12.0,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration.zero);
    _curve = const AlwaysStoppedAnimation<double>(1.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (ReduceMotion.of(context)) {
      _curve = const AlwaysStoppedAnimation<double>(1.0);
      _controller.value = 1.0;
      return;
    }

    final motion = context.motion;
    final delay = motion.stagger * widget.index;
    final total = delay + motion.standard;

    _controller.duration = total;
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1.0,
        curve: motion.quickCurve,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      // The child is built once and reused across every frame of the
      // animation — only the transform and opacity change.
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.rise * (1 - _curve.value)),
          child: child,
        ),
      ),
    );
  }
}
