import 'package:flutter/material.dart';

import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';

/// A bare icon control for navigation chrome.
///
/// ## The no-icons rule, and the bounded exception this is
///
/// The app's pictorial language is the four painted role emblems, and doc 05
/// keeps game meaning in words: role actions, confirm, player tiles, delete and
/// reorder are all text, and stay text. An icon that carries game meaning fails
/// a first-time player under social pressure, and can become a role tell.
///
/// Navigation chrome is the exception, and it is exactly that — an exception,
/// not a repeal. Settings, history, help and back are universally understood,
/// appear only on public screens, and are *never* role-informative: they render
/// identically whatever anyone drew. Recorded as a scoped exception in
/// `05-zero-leakage-spec.md`.
///
/// ## Why these are Material icons and not Phosphor
///
/// The brief asked for Phosphor Regular. `phosphor_flutter` is in `pubspec.yaml`
/// and cannot be used: its `PhosphorIconData extends IconData`, and `IconData`
/// is a `final class` in this Flutter version, so importing the package fails
/// the build outright. 2.1.0 is the newest release and it has not been fixed.
///
/// Material's icons ship with the framework, need no dependency, and — the part
/// that actually matters here — declare `matchTextDirection`, which is what
/// makes the back arrow point the right way in Arabic without a manual
/// transform. Nothing is being "mixed": these four are the only icons in the
/// app, and the emblems are paintings rather than an icon set.
///
/// ## Why the touch target is bigger than the glyph
///
/// The glyph is 24dp and the target is 48dp, per Article VII. These sit in
/// screen corners where a thumb is least accurate, and the box that used to
/// make them look tappable is gone — so the target has to carry that on its own
/// even though nothing is drawn at its edge.
class NavIconButton extends StatelessWidget {
  final IconData icon;

  /// Spoken by a screen reader. Required, and in Arabic: removing the visible
  /// word is only acceptable if the word is still there for anyone who needs
  /// it.
  final String semanticLabel;

  final VoidCallback onPressed;

  const NavIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  /// Glyph size. One value for every control in the app's navigation chrome.
  static const double glyphSize = 24;

  /// Article VII's minimum touch target.
  static const double touchTarget = 48;

  /// Resting opacity. Full opacity on press, which is the whole of the press
  /// feedback now that there is no box to fill.
  static const double restingOpacity = 0.8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: glyphSize),
        // The label is on the `Semantics` above; a second one here would make a
        // screen reader announce it twice.
        tooltip: null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: touchTarget,
          minHeight: touchTarget,
        ),
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.pressed)
                  ? colors.accentGold
                  : colors.accentGold.withValues(alpha: restingOpacity)),
          // No ripple. The press feedback is the glyph going to full opacity;
          // a Material splash on a bare icon over painted artwork reads as a
          // smudge rather than as a press.
          overlayColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
        ),
      ),
    );
  }
}

/// The way out of a screen.
///
/// ## Why every screen outside the night has one
///
/// A host taps "ابدأ اللعبة", realises they meant to change a setting, and has
/// nowhere to go. Force-quitting the app is not a back button. Every screen a
/// player can reach before the match starts — and every post-game screen — gets
/// one of these, and they all go somewhere obvious rather than popping a
/// navigation stack that may be one entry deep.
///
/// ## The exception, which is not negotiable
///
/// Nothing inside the night has one. Back navigation during a turn is banned
/// outright (doc 05 rule 5): a player who could step backwards out of their own
/// action screen could re-enter someone else's, and a resume that lands on
/// secret content is itself a leak. The only exit from a match is the explicit
/// end-match control, which confirms first. [MatchRoute] owns that, and it is
/// deliberately not built from this widget — sharing one would make the two
/// look like the same affordance, and they are opposites.
///
/// ## An arrow, and which way it points
///
/// This was a word in a box. It is now an arrow, under the scoped navigation
/// exception described on [NavIconButton] — back is the one control in the app
/// that every phone on earth has already taught its user.
///
/// **The arrow points right, because the app is RTL.** Getting that is subtler
/// than picking an arrow that points right: `Icons.arrow_back` is declared with
/// `matchTextDirection: true`, so Flutter mirrors it itself under an RTL
/// `Directionality`. Naming `Icons.arrow_forward` — which also mirrors — would
/// render an arrow pointing *left*, the exact bug this is meant to avoid.
/// `arrow_back` is the correct name: it means "backwards" and the framework
/// resolves which way that points.
///
/// Verified on the emulator rather than reasoned about, because a mirrored icon
/// is invisible in code review and obvious on a screen.
class BackAction extends StatelessWidget {
  final VoidCallback onPressed;

  /// Overrides the screen-reader label. Defaults to "رجوع".
  final String? label;

  const BackAction({super.key, required this.onPressed, this.label});

  static const Key button = ValueKey('back_action');

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: button,
      child: NavIconButton(
        icon: Icons.arrow_back,
        semanticLabel: label ?? context.l10n.back,
        onPressed: onPressed,
      ),
    );
  }
}

/// A screen title with its back control on the leading edge.
///
/// One row, one height, so the setup screens line up with each other when a
/// host is stepping back and forth between them.
class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  /// Optional trailing control, e.g. a step counter.
  final Widget? trailing;

  const ScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  /// Width reserved either side of the title, so the title stays optically
  /// centred whether or not there is a back control or a trailing widget.
  ///
  /// Matches the icon control's touch target. It was 88 — sized for a word in a
  /// box — and that reservation is most of why the titles had no room.
  static const double _sideSlot = NavIconButton.touchTarget;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          if (onBack != null)
            BackAction(onPressed: onBack!)
          else
            // Keeps the title in the same place whether or not there is a way
            // back, so stepping through setup does not make the heading jump.
            const SizedBox(width: _sideSlot),
          Expanded(
            // # Why this is a FittedBox and not just an ellipsis
            //
            // It was an ellipsis, and the players screen shipped reading
            // "أضف اللاع…". The gutters take 88dp a side out of a 390dp screen,
            // which left about 158dp for a 32dp headline — not enough, at any
            // OS font setting, for a title that is simply long.
            //
            // Truncating a *screen title* is the one place an ellipsis is
            // never acceptable: it is the label that tells someone which screen
            // they are on. `scaleDown` shrinks the type only when it has to and
            // never enlarges it, so short titles are untouched and long ones
            // stay whole. The narrower icon back control gives back most of the
            // room that caused this, and this is what guarantees it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: type.headline.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ),
          SizedBox(width: _sideSlot, child: trailing),
        ],
      ),
    );
  }
}
