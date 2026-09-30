import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import '../widgets/legal_documents.dart';
import 'delete_account_sheet.dart';

/// The foot of the account sheet: the terms and privacy (read in place) and
/// the way out. Shown to guests and accounts alike: a guest has data too.
class AccountFooter extends StatelessWidget {
  const AccountFooter({super.key});

  static const deleteKey = ValueKey('account_delete');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: colors.borderSubtle, height: s.xl),
        Text(
          l.accountLegalTitle,
          textAlign: TextAlign.center,
          style: context.typography.caption.copyWith(color: colors.textMuted),
        ),
        const LegalDocuments(),
        SizedBox(height: s.sm),
        TextButton(
          key: deleteKey,
          onPressed: () => showDeleteAccountSheet(context),
          child: Text(
            l.deleteAccountRow,
            style: TextStyle(color: colors.accentCrimson),
          ),
        ),
      ],
    );
  }
}
