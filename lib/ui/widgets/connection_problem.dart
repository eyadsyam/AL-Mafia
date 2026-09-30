import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// The state an online entry point shows when the server cannot be reached:
/// one plain Arabic sentence, what happens next, and a «جرّب تاني» that
/// works. Never an exception, never a code.
class ConnectionProblem extends StatelessWidget {
  /// The sentence the player reads. Callers pass `friendlyError` /
  /// `friendlyCode` output, or [AppLocalizations.errOffline].
  final String message;

  /// Optional second line (what the screen will do on its own).
  final String? hint;
  final Key? hintKey;
  final VoidCallback? onRetry;

  const ConnectionProblem({
    super.key,
    required this.message,
    this.hint,
    this.hintKey,
    required this.onRetry,
  });

  static const retryKey = ValueKey('connection_problem_retry');

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: ConnectionProblemTokens.iconSize,
            color: colors.textMuted,
          ),
          SizedBox(height: s.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.textPrimary),
          ),
          if (hint != null) ...[
            SizedBox(height: s.xs),
            Text(
              hint!,
              key: hintKey,
              textAlign: TextAlign.center,
              style: type.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
          SizedBox(height: s.sm),
          OutlinedButton.icon(
            key: retryKey,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.errRetry),
          ),
        ],
      ),
    );
  }
}
