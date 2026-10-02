import 'package:flutter/widgets.dart';

/// Whether the first-launch gate is still deciding if this launch owes the
/// player the introduction.
///
/// ## Why an inherited widget and not a provider
///
/// It has to be true *before the first frame is built*, and a provider cannot
/// be written to from a widget life-cycle — Riverpod refuses, and the end of
/// frame one is already too late: the profile's storage read is one hop deep
/// and the gate's decision is three, so the profile resolves first and a
/// brand-new player is asked for their name over a screen that is about to be
/// replaced by the film.
///
/// As an inherited widget the answer is simply in place: [OnboardingGate] sits
/// above the navigator, so the value is there the first time any route asks.
///
/// Absent means "nobody is gating this tree" — every widget test that pumps a
/// screen on its own, and any route reached later in a run. That default is
/// what keeps a screen mounted without the gate from waiting on a decision no
/// one is making.
class IntroGate extends InheritedWidget {
  final bool pending;

  const IntroGate({super.key, required this.pending, required super.child});

  static bool pendingOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IntroGate>()?.pending ?? false;

  @override
  bool updateShouldNotify(IntroGate old) => old.pending != pending;
}
