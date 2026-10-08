import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// The owner's palette for the new surfaces (stories, the bots sheet): ink
/// brown ground, warm panels, parchment text and lamp gold, the look of the
/// voice review pages. Headings on these surfaces are set in Ruqaa through
/// [StoryTokens.ruqaa].
///
/// Public surfaces only. Never wrap a match route: in-match colour is
/// budgeted so that no role reads differently (Doc 05).
class WarmPalette extends StatelessWidget {
  final Widget child;
  const WarmPalette({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final neutral = Theme.of(context);
    final warm = context.colors.copyWith(
      surfaceBase: IdentityTokens.ink,
      surfaceRaised: IdentityTokens.panel,
      surfaceOverlay: IdentityTokens.panelOverlay,
      borderSubtle: IdentityTokens.line,
      textPrimary: IdentityTokens.text,
      textSecondary: DeckTokens.text2,
      textMuted: DeckTokens.muted,
      accentGold: DeckTokens.bone,
    );
    return Theme(
      data: neutral.copyWith(
        scaffoldBackgroundColor: IdentityTokens.ink,
        canvasColor: IdentityTokens.ink,
        bottomSheetTheme: neutral.bottomSheetTheme.copyWith(
          backgroundColor: IdentityTokens.ink,
          modalBackgroundColor: IdentityTokens.ink,
        ),
        extensions: [
          for (final e in neutral.extensions.values)
            if (e is! MafiaColors) e,
          warm,
        ],
      ),
      child: child,
    );
  }
}
