import 'package:mafia_master/data/memory_match_repository.dart';

/// A match store for a launch that is **not** a first run.
///
/// A bare [MemoryMatchStore] models a fresh install, which since the onboarding
/// deck landed means `OnboardingGate` redirects off Home on the first frame.
/// That is correct behaviour and it is what `onboarding_gate_test.dart`
/// asserts — but it is not what a test about the resume prompt, the setup flow
/// or the three-tap rematch budget is trying to exercise, and those tests
/// should not silently be measuring a tutorial.
///
/// Using this rather than setting the flag inline keeps the reason in one place:
/// if the gate ever gains a second condition, there is one file to change rather
/// than four.
MemoryMatchStore returningHostStore() =>
    MemoryMatchStore()..onboardingSeen = true;
