import 'package:flutter/material.dart';
import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';

/// Public setup only: never used for private role content.
class SetupEntrance extends StatelessWidget {
  final Widget child;
  const SetupEntrance({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (ReduceMotion.of(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion.quick,
      curve: context.motion.quickCurve,
      child: child,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
    );
  }
}
