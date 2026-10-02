import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/data/terms_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
MemoryMatchStore returningHostStore() {
  seedReturningProfile();
  return MemoryMatchStore()..onboardingSeen = true;
}

void seedReturningProfile() => SharedPreferences.setMockInitialValues({
  'community_rules_2026_09': true,
  ProfileStore.profileKey: '{"name":"A","gender":"male"}',
  ...acceptedTermsPrefs,
});

/// A current acceptance of the terms, as setup leaves it.
const acceptedTermsPrefs = <String, Object>{
  TermsStore.versionKey: currentTermsVersion,
  TermsStore.acceptedAtKey: '2026-09-23T10:00:00.000Z',
  TermsStore.adultKey: true,
  TermsStore.syncedKey: true,
};
