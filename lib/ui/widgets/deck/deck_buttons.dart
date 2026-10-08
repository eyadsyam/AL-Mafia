import 'package:flutter/gestures.dart' show kTouchSlop;
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
            ? DeckPress(child: button)
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
        : DeckPress(child: button);
  }
}

/// A press you can feel: whatever is under the finger sinks a little and
/// springs back on release. Only a scale moves — no layout, no colour — so it
/// costs one composited layer and reads the same for every player, in a match
/// or out of one. Dragging past the touch slop (a scroll) lets go at once;
/// with animations switched off it is the plain child.
class DeckPress extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const DeckPress({super.key, required this.child, this.enabled = true});

  @override
  State<DeckPress> createState() => _DeckPressState();
}

class _DeckPressState extends State<DeckPress> {
  Offset? _origin;
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!widget.enabled || still) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _origin = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        final origin = _origin;
        if (origin != null && (e.position - origin).distance > kTouchSlop) {
          _origin = null;
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? DeckTokens.pressScale : 1,
        duration: DeckTokens.press,
        curve: _down ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
