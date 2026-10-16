import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';

/// «قصص وتحقيقات»' own look: ink brown ground, warm panels, parchment text.
/// It starts once «قصص وتحقيقات» is tapped and ends on leaving it; Mafia
/// screens never wrap themselves in it (owner, 2026-10-16: the stories feel
/// like another game inside Mafia, tied to it only by coins and rewards).
///
/// Public surfaces only. Never wrap a match route: in-match colour is
/// budgeted so that no role reads differently (Doc 05).
class StoryPalette extends StatelessWidget {
  final Widget child;
  const StoryPalette({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final neutral = Theme.of(context);
    final warm = context.colors.copyWith(
      surfaceBase: StoryDeckTokens.ground,
      surfaceRaised: StoryDeckTokens.panel,
      surfaceOverlay: StoryDeckTokens.raised,
      borderSubtle: StoryDeckTokens.line,
      textPrimary: StoryDeckTokens.text,
      textSecondary: StoryDeckTokens.text2,
      textMuted: StoryDeckTokens.muted,
      accentGold: StoryDeckTokens.bone,
    );
    return Theme(
      data: neutral.copyWith(
        scaffoldBackgroundColor: StoryDeckTokens.ground,
        canvasColor: StoryDeckTokens.ground,
        bottomSheetTheme: neutral.bottomSheetTheme.copyWith(
          backgroundColor: StoryDeckTokens.ground,
          modalBackgroundColor: StoryDeckTokens.ground,
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
