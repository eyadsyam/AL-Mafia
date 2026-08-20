import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/mafia_theme.dart';

/// The transition between two game phases: a dip through the ground.
///
/// # Why this is not a cross-fade
///
/// Every stock transition Flutter offers — `AnimatedSwitcher`, the Material page
/// route, a `FadeTransition` pair — shows the outgoing and incoming screens
/// **at the same time**, blended. That is fine in almost any app and is a
/// leak here.
///
/// The phase boundaries in this game are handoff boundaries. The screen the
/// phone is leaving is one player's private night turn; the screen it is
/// arriving at is the pass gate that the *next* player will be looking at. A
/// cross-fade puts a ghost of the outgoing turn — its prompt, its target list,
/// its role-shaped layout — on screen at the exact moment the phone is being
/// handed across the table and is visible to everyone. Half-opacity is not
/// unreadable; it is merely faint, and faint is enough when you already know
/// what you are looking for.
///
/// So the two halves never overlap. The outgoing phase fades to the charcoal
/// ground, the tree is swapped while nothing is drawn but the ground, and the
/// incoming phase fades up from it. It costs one extra beat and it means there
/// is no frame in which both phases exist.
///
/// # Why any transition at all
///
/// A hard cut between phases reads as a glitch rather than a beat, and the
/// phase change is the game's punctuation — night ending, the vote opening. The
/// dip gives the table a moment to look up, and the darkness in the middle is
/// doing real work: it is the only thing on screen that is the same for every
/// role, so it is where the eye is safe to rest.
class PhaseTransition extends StatefulWidget {
  /// Identity of the current phase. A change here — not a change in [child] —
  /// is what triggers the dip.
  ///
  /// Passing something that changes on every build (an object without value
  /// equality) would put the app into a permanent fade and is the one way to
  /// misuse this widget.
  final Object phaseKey;

  final Widget child;

  const PhaseTransition({
    super.key,
    required this.phaseKey,
    required this.child,
  });

  @override
  State<PhaseTransition> createState() => _PhaseTransitionState();
}

class _PhaseTransitionState extends State<PhaseTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dip;

  /// What is actually on screen. Held separately from `widget.child` so the
  /// outgoing phase can finish fading out *before* the swap — the whole point of
  /// the widget.
  late Widget _shown;
  late Object _shownKey;

  @override
  void initState() {
    super.initState();
    _shown = widget.child;
    _shownKey = widget.phaseKey;
    _dip = AnimationController(vsync: this, duration: Duration.zero, value: 1.0)
      ..addStatusListener(_swapAtTheBottom);
  }

  /// The swap happens at full darkness, which is `dismissed` here because the
  /// controller runs 1 -> 0 -> 1 (opacity, not progress).
  void _swapAtTheBottom(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted) return;
    setState(() {
      _shown = widget.child;
      _shownKey = widget.phaseKey;
    });
    _dip.forward();
  }

  @override
  void didUpdateWidget(PhaseTransition old) {
    super.didUpdateWidget(old);

    if (widget.phaseKey != _shownKey) {
      if (ReduceMotion.of(context)) {
        // A hard cut. Players who asked for less motion get the swap without
        // the beat; what they must not get is a phase that never arrives.
        setState(() {
          _shown = widget.child;
          _shownKey = widget.phaseKey;
        });
        _dip.value = 1.0;
        return;
      }
      _dip.reverse();
      return;
    }

    // Same phase, rebuilt content (a timer tick, a selection). Pass it straight
    // through — dipping on every rebuild would make the app strobe.
    if (widget.child != _shown) {
      setState(() => _shown = widget.child);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dip.duration = context.motion.quick;
  }

  @override
  void dispose() {
    _dip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ColoredBox(
      // The ground is painted underneath rather than faded to, so the gap in the
      // middle of the dip is opaque charcoal and not whatever the OS happens to
      // have behind the window.
      color: colors.surfaceBase,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _dip,
          curve: context.motion.quickCurve,
        ),
        child: _shown,
      ),
    );
  }
}
