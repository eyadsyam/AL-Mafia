import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repository_provider.dart';
import '../data/player_profile.dart';
import '../ui/theme/mafia_theme.dart';
import 'intro_gate.dart';
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
  bool _pending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked || !mounted) return;
    _checked = true;
    var navigated = false;
    try {
      navigated = await _decide();
    } catch (_) {
      // Every read inside is already guarded; this is the belt on the braces.
    }
    if (!mounted) return;
    // The page being left is on screen for the length of the transition, and a
    // page on its way out has no business asking a question. Without this wait
    // the flag drops in the same turn as the `go`, the outgoing route rebuilds
    // as the profile form, and the player watches a name field they were never
    // asked to fill slide away.
    if (navigated) await Future<void>.delayed(context.motion.standard);
    if (mounted) setState(() => _pending = false);
  }

  /// Returns whether it sent this launch somewhere.
  Future<bool> _decide() async {
    final repository = ref.read(matchRepositoryProvider);
    try {
      if (await ref.read(profileStoreProvider).introSeen) return false;
    } catch (_) {
      /* Storage failure must not skip the existing resume check. */
    }
    try {
      if (await repository.hasSeenOnboarding()) return false;
      // Resume outranks onboarding. Deliberately checked here rather than
      // coordinated with `ResumeGate`: both gates read the same storage, so
      // asking it directly is what keeps them from having to know about each
      // other or run in a particular order.
      if (await repository.loadActiveMatch() != null) return false;
    } catch (_) {
      // Unreadable storage falls through to showing the deck.
    }
    if (!mounted) return false;

    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return false;
    final router = GoRouter.of(navigatorContext);
    final next = router.routeInformationProvider.value.uri.toString();
    router.go(
      Uri(path: Routes.onboarding, queryParameters: {'next': next}).toString(),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) =>
      IntroGate(pending: _pending, child: widget.child);
}
