import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Main theme for Mafia Master.
class MafiaTheme {
  static ThemeData get dark {
    const colors = MafiaColors.dark;
    const spacing = MafiaSpacing.defaults;
    const radii = MafiaRadii.defaults;
    const motion = MafiaMotion.defaults;
    const timing = MafiaTiming.defaults;
    final elevation = MafiaElevation.from(colors.shadow);
    const typography = MafiaTypography.defaults;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      // Kept in step with MafiaColors.dark by hand. Material only reaches for
      // these on widgets the design system does not style itself (text
      // selection handles, the default cursor), so a drift here shows up as one
      // stray blue affordance rather than a broken screen — which is exactly
      // why it is easy to miss.
      colorScheme: ColorScheme.dark(
        surface: colors.surfaceBase,
        primary: colors.accentGold,
        error: colors.accentCrimson,
        onPrimary: colors.surfaceBase,
        onError: colors.textPrimary,
        secondary: colors.accentSage,
      ),
      scaffoldBackgroundColor: colors.surfaceBase,
      // ---------------------------------------------------------------------
      // The button state matrix.
      //
      // Every button in the app is a stock `FilledButton`, `OutlinedButton` or
      // `TextButton` — there is no custom button widget, and there should not
      // be one, because the accessibility work (48dp targets, focus rings,
      // Dynamic Type, semantics) is already correct in the Material ones and
      // would have to be rebuilt to the same standard by hand.
      //
      // What was missing was the *resting and disabled* halves of the matrix.
      // Enabled buttons picked up `colorScheme.primary` and looked right;
      // disabled ones fell through to Material's stock `onSurface at 38%`,
      // which on this near-black ground is an unreadable smear rather than a
      // legible "not yet". Defining it here rather than per call site means the
      // twenty-odd existing buttons are fixed at once and the next one is right
      // before it is written.
      //
      // `minimumSize` is pinned to 48dp because `accessibility_test.dart`
      // requires it of every interactive control in a turn, and inheriting it
      // is more reliable than remembering it.
      // ---------------------------------------------------------------------
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.surfaceRaised;
            }
            if (states.contains(WidgetState.pressed)) {
              return colors.accentGoldPressed;
            }
            return colors.accentGold;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            // Disabled text sits on surfaceRaised, so it needs a *lighter*
            // colour to stay readable — the opposite of the dark-on-gold the
            // enabled button uses. Material's single "disabled" colour cannot
            // express that, which is why it looks wrong out of the box.
            if (states.contains(WidgetState.disabled)) return colors.textMuted;
            return colors.surfaceBase;
          }),
          overlayColor: WidgetStateProperty.all(colors.surfaceOverlay),
          minimumSize: WidgetStateProperty.all(const Size(64, 48)),
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.sm),
          ),
          textStyle: WidgetStateProperty.all(typography.body),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radii.button),
            ),
          ),
          elevation: WidgetStateProperty.all(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return colors.textMuted;
            return colors.textPrimary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: colors.surfaceRaised);
            }
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: colors.textSecondary);
            }
            return BorderSide(color: colors.borderSubtle);
          }),
          overlayColor: WidgetStateProperty.all(colors.surfaceOverlay),
          minimumSize: WidgetStateProperty.all(const Size(64, 48)),
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.sm),
          ),
          textStyle: WidgetStateProperty.all(typography.body),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radii.button),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return colors.textMuted;
            if (states.contains(WidgetState.pressed)) return colors.textPrimary;
            return colors.textSecondary;
          }),
          overlayColor: WidgetStateProperty.all(colors.surfaceOverlay),
          minimumSize: WidgetStateProperty.all(const Size(48, 48)),
          textStyle: WidgetStateProperty.all(typography.body),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radii.button),
            ),
          ),
        ),
      ),
      // Material's stock Switch is the loudest off-palette thing in the app: an
      // *off* switch draws a pure-white thumb on a grey track with a visible
      // outline, which on this near-black ground reads as the brightest element
      // on the Settings screen. Call sites were overriding the two active
      // colours and leaving the resting state stock, so the toggle looked
      // correct only while it was on.
      //
      // Styling it here rather than at each call site means a Switch added later
      // is right by default.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.textMuted;
          if (states.contains(WidgetState.selected)) return colors.accentGold;
          return colors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return colors.surfaceBase;
          if (states.contains(WidgetState.selected)) {
            return colors.accentGoldPressed;
          }
          return colors.surfaceRaised;
        }),
        // The outline is what makes an unlit track legible at all against
        // surfaceBase; on the lit track it would only fight the fill.
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colors.borderSubtle;
        }),
        overlayColor: WidgetStateProperty.all(colors.surfaceOverlay),
      ),
      extensions: [colors, spacing, radii, motion, timing, typography, elevation],
    );
  }
}

/// Convenient extensions on [BuildContext] to access theme tokens.
extension MafiaThemeX on BuildContext {
  /// The shadow ladder. One light source; see [MafiaElevation].
  MafiaElevation get elevation =>
      Theme.of(this).extension<MafiaElevation>()!;

  MafiaColors get colors => Theme.of(this).extension<MafiaColors>()!;
  MafiaSpacing get spacing => Theme.of(this).extension<MafiaSpacing>()!;
  MafiaRadii get radii => Theme.of(this).extension<MafiaRadii>()!;
  MafiaMotion get motion => Theme.of(this).extension<MafiaMotion>()!;
  MafiaTiming get timing => Theme.of(this).extension<MafiaTiming>()!;
  MafiaTypography get typography =>
      Theme.of(this).extension<MafiaTypography>()!;
}
