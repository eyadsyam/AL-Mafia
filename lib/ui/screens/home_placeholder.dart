import 'package:flutter/material.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// Home screen placeholder for Mafia Master.
/// Displays app title in both Arabic and English using theme tokens.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Mafia Master',
              style: context.typography.display.copyWith(
                color: context.colors.textPrimary,
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.appTitle,
              style: context.typography.display.copyWith(
                color: context.colors.accentGold,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }
}
