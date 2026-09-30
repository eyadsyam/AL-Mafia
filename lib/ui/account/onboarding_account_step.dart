import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/account_auth.dart' show AccountProfile;
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/mafia_theme.dart';
import 'account_sheet.dart';

/// Whether this build has accounts to offer at all (the first-launch choice
/// and the profile card).
///
/// Only a build that can reach the server has anything to sign in to; an
/// offline-only build (no Supabase keys) keeps the four original chapters.
/// A provider so a test can switch it on without dart-defines.
final accountsAvailableProvider = Provider<bool>(
  (ref) => SupabaseConfig.isConfigured,
);

/// First launch, the account chapter: sign in (Google or email, the same
/// sheet the profile opens) or carry on as the guest this install already is.
///
/// Guest is not a lesser path: the anonymous identity is kept as it is and the
/// profile can link Google or an email to it later without moving a coin.
/// The chapter's primary button (owned by `FirstRunScreen`) is the guest
/// choice; this body holds the other one.
class OnboardingAccountChoice extends ConsumerWidget {
  const OnboardingAccountChoice({super.key});

  static const signInKey = ValueKey('onboarding_account_sign_in');
  static const signedInKey = ValueKey('onboarding_account_signed_in');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final profile =
        ref.watch(accountProfileProvider).valueOrNull ?? AccountProfile.guest;
    if (profile.signedIn) {
      final email = profile.email;
      return Row(
        key: signedInKey,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_rounded, color: colors.accentGold),
          SizedBox(width: s.sm),
          Flexible(
            child: Text(
              email == null || email.isEmpty
                  ? l.onboardAccountSignedInPlain
                  : l.onboardAccountSignedIn(email),
              style: context.typography.body.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      key: signInKey,
      onPressed: () => showAccountSheet(context),
      icon: const Icon(Icons.login_rounded),
      label: Text(l.onboardAccountSignIn),
    );
  }
}
