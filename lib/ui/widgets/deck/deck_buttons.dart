import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';

/// The deck's two everyday buttons (docs/design/DECK-SYSTEM.md).
///
/// Safe in a match: every colour comes from `context.colors`, so a private
/// surface draws them in its neutral palette, and nothing here varies with
/// who is holding the phone. The public-only pieces live in
/// `deck_public.dart`, which the hand-off purity test keeps out of the match.

/// The one primary action on a surface: home's «ابدأ اللعبة», pixel for
/// pixel — bone fill, ground-coloured label, the title style, the button
/// radius. Disabled, it fades and says why underneath.
class BoneButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Shown under a disabled button: what the player still has to do.
  final String? disabledReason;

  const BoneButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final enabled = onPressed != null;
    final button = SizedBox(
      height: DeckTokens.primaryHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          // A public theme may paint gold behind every FilledButton; bone
          // is bone wherever it stands.
          backgroundBuilder: (context, states, child) => child!,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? DeckTokens.bonePressed
                : colors.accentGold,
          ),
          foregroundColor: WidgetStatePropertyAll(colors.surfaceBase),
          overlayColor: const WidgetStatePropertyAll(IdentityTokens.transparent),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: context.spacing.md),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.radii.button),
            ),
          ),
        ),
        child: Text(
          label,
          style: type.title.copyWith(color: colors.surfaceBase),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    final reason = disabledReason;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        enabled
            ? button
            : Opacity(opacity: DeckTokens.disabledAlpha, child: button),
        if (!enabled && reason != null) ...[
          SizedBox(height: context.spacing.sm),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: DeckTokens.meta(type).copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

/// The secondary action: a silver rim, the label in the text colour.
class RimButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const RimButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = DeckTokens.rim,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final button = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundBuilder: (context, states, child) => child!,
          foregroundColor: WidgetStatePropertyAll(colors.textPrimary),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? colors.surfaceOverlay
                : IdentityTokens.transparent,
          ),
          overlayColor: const WidgetStatePropertyAll(IdentityTokens.transparent),
          side: const WidgetStatePropertyAll(
            BorderSide(
              color: DeckTokens.silverLight,
              width: DeckTokens.rimBorder,
            ),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: context.spacing.md),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.radii.button),
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DeckTokens.body(type).copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: DeckTokens.disabledAlpha, child: button)
        : button;
  }
}
