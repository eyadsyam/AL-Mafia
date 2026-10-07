import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_sheet.dart' show showAccountSheet;
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'account_status.dart';

export 'account_status.dart';

/// Store and admin gates share the same full-screen Google/email sign-in.
///
/// The legacy class name and keys stay stable for existing callers and tests;
/// the user-facing action is simply “Sign in”.
class AccountProtectionCard extends ConsumerWidget {
  /// Retained for source compatibility with the web admin surface. The shared
  /// account flow owns its callback URL through the shared auth transport.
  final String? recoveryRedirect;

  const AccountProtectionCard({super.key, this.recoveryRedirect});

  static const linkButton = ValueKey('account_link');
  static const recoverButton = ValueKey('account_recover');
  static const emailField = ValueKey('account_email');
  static const codeField = ValueKey('account_code');
  static const sendButton = ValueKey('account_send');
  static const confirmButton = ValueKey('account_confirm');
  static const errorText = ValueKey('account_error');
  static const linkOpenedButton = ValueKey('account_link_opened');
  static const recoverLinkNote = ValueKey('account_recover_link_note');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = context.spacing;
    final status = ref.watch(accountStatusProvider).valueOrNull;
    if (status?.recoverable == true) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          Icons.verified_user_outlined,
          color: context.colors.accentGold,
        ),
        title: Text(l.accountTitle),
        subtitle: Text(l.accountProtected(status!.email ?? '')),
      );
    }
    return Card(
      child: Padding(
        padding: EdgeInsets.all(s.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.accountTitle, style: context.typography.title),
            SizedBox(height: s.xs),
            Text(l.accountAnonymousHint, style: context.typography.bodySmall),
            SizedBox(height: s.sm),
            FilledButton.icon(
              key: linkButton,
              onPressed: () => showAccountSheet(context),
              icon: const Icon(Icons.login_rounded),
              label: Text(l.accountLink),
            ),
          ],
        ),
      ),
    );
  }
}
