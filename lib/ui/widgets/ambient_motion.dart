import 'package:flutter/widgets.dart';

/// Switches off the app's *ambient* animation — the motion that runs forever
/// with no beginning or end, like the drifting icons behind the home screen.
///
/// ## Why this exists at all
///
/// Ambient motion is the one kind of animation that never finishes, and an
/// animation that never finishes has two awkward consequences. The framework
/// never goes idle, so `pumpAndSettle` in a widget test spins until it times
/// out no matter what the test was actually about; and a phone left on a table
/// keeps compositing frames all evening for a decoration nobody is looking at.
///
/// [ReduceMotion] already covers the accessibility case. This covers the other
/// one: a caller that wants the screen *composed* but not *breathing*. Tests
/// exercising a flow wrap the app in `AmbientMotion(enabled: false, ...)` so
/// they settle; nothing in the shipping app does, so the drift runs.
///
/// It deliberately does not switch off transitions, flips, or progress rings.
/// Those are bounded, they settle on their own, and several of them are load
/// bearing for Article I's timing guarantees — silencing them from a test would
/// hide exactly the leaks the golden suite exists to catch.
class AmbientMotion extends InheritedWidget {
  final bool enabled;

  const AmbientMotion({
    super.key,
    required this.enabled,
    required super.child,
  });

  /// Defaults to `true`: a screen with no scope above it animates. The opt-out
  /// has to be deliberate, so a new surface cannot lose its atmosphere by
  /// forgetting to plumb something through.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AmbientMotion>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(AmbientMotion oldWidget) =>
      oldWidget.enabled != enabled;
}
