import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repository_provider.dart';
import 'router.dart';

/// Shows the onboarding deck once, on the first launch of an install.
///
/// ## Why a gate rather than a check inside Home
///
/// Same shape as `ResumeGate`, and for the same reason: mounting it from
/// `MaterialApp.builder` means the question is asked once per launch, not on
/// every visit to Home. A host who backs out of setup should not be handed the
/// tutorial again.
///
/// ## An unfinished match outranks it
///
/// If storage holds a match that never ended, this gate stands down and lets
/// `ResumeGate` have the launch. A table that is mid-game and has just relaunched
/// the app is not a table that wants a tutorial — and stacking a route change
/// under a modal resume prompt would put the prompt over the wrong screen. The
/// deck is not lost: `hasSeenOnboarding` is still false, so it appears on the
/// next clean launch.
///
/// ## Failure is silent, and lands on "show it"
///
/// Every storage read here is allowed to fail. A first launch is the worst
/// possible moment for a database problem to become a crash, and the two
/// failure modes are not symmetric: showing the deck to someone who has seen it
/// is an annoyance they can skip in one tap, while suppressing it hides the only
/// explanation of the pass rules a new table will ever be offered.
class OnboardingGate extends ConsumerStatefulWidget {
  final Widget child;

  /// The router's navigator. This widget sits above it — see `ResumeGate` for
  /// why that means a captured context is not usable.
  final GlobalKey<NavigatorState> navigatorKey;

  const OnboardingGate({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked || !mounted) return;
    _checked = true;

    final repository = ref.read(matchRepositoryProvider);
    try {
      if (await repository.hasSeenOnboarding()) return;
      // Resume outranks onboarding. Deliberately checked here rather than
      // coordinated with `ResumeGate`: both gates read the same storage, so
      // asking it directly is what keeps them from having to know about each
      // other or run in a particular order.
      if (await repository.loadActiveMatch() != null) return;
    } catch (_) {
      // Unreadable storage falls through to showing the deck.
    }
    if (!mounted) return;

    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;
    GoRouter.of(navigatorContext).go(Routes.onboarding);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
