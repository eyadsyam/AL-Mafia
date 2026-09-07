import 'package:flutter/widgets.dart';

import '../../../../platform/reduce_motion.dart';
import '../../../theme/mafia_theme.dart';

/// One heartbeat for the whole table.
///
/// ## Why a shared ticker rather than a controller per seat
///
/// Doc 12 §6's performance budget: 60fps with fifteen seats. Fifteen seats each
/// owning a `AnimationController` is fifteen tickers, fifteen `setState`
/// cascades a frame, and fifteen independent phases — so the "breathing" glow
/// on two adjacent seats would visibly beat against each other. One controller
/// fixes both problems at once: one tick, and every breathing thing in the
/// scene inhales together.
///
/// It matters for a second reason, which is the one that actually binds. Doc 12
/// §2.3 requires every seat to render identically at night. Independent phases
/// would make two seats *differ* at any given instant — not by role, but
/// visibly — and a table where seats differ is a table where somebody starts
/// looking for a reason.
///
/// ## Reduce Motion
///
/// The value freezes at the midpoint. Doc 12 §6: every animation degrades to a
/// cross-fade, and dramatic holds remain. A glow that has stopped moving is
/// still a glow; it is just not breathing.
class TablePulse extends StatefulWidget {
  final Widget child;

  const TablePulse({super.key, required this.child});

  /// The current breath, 0 to 1 and back, or a constant 0.5 under Reduce
  /// Motion. Never null: a seat outside a [TablePulse] is a wiring bug, and a
  /// still glow is a better failure than a crash mid-match.
  static Animation<double> of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_TablePulseScope>();
    return scope?.breath ?? const AlwaysStoppedAnimation<double>(0.5);
  }

  @override
  State<TablePulse> createState() => _TablePulseState();
}

class _TablePulseState extends State<TablePulse>
    with SingleTickerProviderStateMixin {
  // Duration is set in `didChangeDependencies`, where the theme is readable.
  // Zero rather than a placeholder number, so there is never a second copy of
  // `MafiaMotion.breathe` in the tree to fall out of step with the first.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = context.motion.breathe;
    if (ReduceMotion.of(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TablePulseScope(
      breath: CurvedAnimation(
        parent: _controller,
        curve: context.motion.breatheCurve,
      ),
      child: widget.child,
    );
  }
}

class _TablePulseScope extends InheritedWidget {
  final Animation<double> breath;

  const _TablePulseScope({required this.breath, required super.child});

  @override
  bool updateShouldNotify(_TablePulseScope oldWidget) =>
      oldWidget.breath != breath;
}
