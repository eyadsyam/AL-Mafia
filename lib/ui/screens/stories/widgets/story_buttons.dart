import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import '../../../widgets/deck/deck_buttons.dart' show DeckPress;

/// «قصص وتحقيقات»' own buttons, so the stories never borrow Mafia's deck
/// pieces. Inside [StoryPalette] the theme is warm, so the fill and the label
/// follow it; the press is the shared, identity-neutral [DeckPress].

/// The one primary action on a stories surface.
class StoryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Shown under a disabled button: what the player still has to do.
  final String? disabledReason;

  const StoryButton({
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
      height: StoryDeckTokens.primaryHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundBuilder: (context, states, child) => child!,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? StoryDeckTokens.bonePressed
                : colors.accentGold,
          ),
          foregroundColor: WidgetStatePropertyAll(colors.surfaceBase),
          overlayColor: const WidgetStatePropertyAll(
            IdentityTokens.transparent,
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
            ? DeckPress(child: button)
            : Opacity(opacity: StoryDeckTokens.disabledAlpha, child: button),
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

/// The secondary action on a stories surface: a warm silver rim.
class StoryRimButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const StoryRimButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = StoryDeckTokens.rim,
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
          overlayColor: const WidgetStatePropertyAll(
            IdentityTokens.transparent,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(
              color: StoryDeckTokens.silverLight,
              width: StoryDeckTokens.rimBorder,
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
          style: DeckTokens.body(
            type,
          ).copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: StoryDeckTokens.disabledAlpha, child: button)
        : DeckPress(child: button);
  }
}
