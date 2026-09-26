import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// One sentence, dismissable, for a device whose storage refused a write the
/// match does not depend on: the resume pointer or the finished-match summary.
///
/// Not an error state and not a blocker — the room is the server's and the
/// match goes on — but a player who closes the app expecting to be brought
/// back to the table by it deserves to know this device may not manage that.
class StorageWarningNote extends StatelessWidget {
  final VoidCallback onDismiss;

  const StorageWarningNote({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sd_storage_outlined, color: c.accentGold, size: s.lg),
          SizedBox(width: s.sm),
          Expanded(
            child: Text(
              context.l10n.onlineStorageWarning,
              style: context.typography.body.copyWith(color: c.textSecondary),
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
