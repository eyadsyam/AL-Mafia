import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_localizations.dart';
import '../../../platform/audio_director.dart';
import '../../../platform/tilt_source.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/card_spread.dart';
import '../../widgets/falling_icons.dart';
import '../../widgets/room_atmosphere.dart';
import '../../widgets/textured_surface.dart';

/// Home screen (S-01) — the spread.
///
/// ## The deck is the screen
///
/// There is no illustration behind this menu; the four role cards *are* the
/// background, dealt across the table and slowly breathing. Tapping one turns
/// it over to say what that role does, which is why there is no separate roles
/// reference — the answer is already on the thing you are pointing at.
///
/// This is the one screen in the app where all four faces may appear together.
/// Everything the leakage suite protects is about what one player learns about
/// *another*; here nothing has been dealt, nobody is holding anything, and the
/// whole table is looking at the same picture. Showing the deck openly before
/// the game is what makes the four identical backs during it mean nothing.
///
/// ## Layering, bottom to top
///
/// 1. the textured backdrop and its warm ambient art;
/// 2. the drifting corner icons, at the same 4–8% they use everywhere;
/// 3. the spread, which owns the deal, the float, the parallax and the flip;
/// 4. haze along the bottom edge, so the cards sit on something;
/// 5. the title, the primary action and the corner controls.
///
/// The whole stack is wrapped in [BulbFlicker], which wanders the brightness by
/// 3% on a period long enough not to read as a pulse.
class HomeScreen extends ConsumerWidget {
  /// Callback when the primary action is tapped.
  final VoidCallback onNewMatch;

  /// Callback when the history control is tapped.
  final VoidCallback onHistory;

  /// Callback when the settings control is tapped.
  final VoidCallback onSettings;

  /// Callback when the rules control is tapped.
  final VoidCallback onHowToPlay;

  /// Where the parallax gets its readings. Overridden in tests, and in any
  /// environment with no accelerometer this is what it falls back to.
  final TiltSource tiltSource;

  const HomeScreen({
    super.key,
    required this.onNewMatch,
    required this.onHistory,
    required this.onSettings,
    required this.onHowToPlay,
    this.tiltSource = defaultTiltSource,
  });

  /// The real accelerometer. A `const` field rather than an inline default,
  /// because a default value has to be a compile-time constant and naming it
  /// also gives tests one obvious thing to substitute.
  static const TiltSource defaultTiltSource = SensorTiltSource();

  static const Key startButton = ValueKey('home_start');
  static const Key historyButton = ValueKey('home_history');
  static const Key settingsButton = ValueKey('home_settings');
  static const Key howToPlayButton = ValueKey('home_how_to_play');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: BulbFlicker(
        // The app's default ground, same as every other public screen. Home
        // used to carry its own backdrop image; with the warm register in
        // `AppBackdrop` it does not need one, and one fewer full-screen bitmap
        // to decode on the slowest frame of the app's life is worth having.
        child: AppBackdrop(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const FallingIcons(),
              CardSpread(
                tiltSource: tiltSource,
                // The deal is on-table by definition — this screen is the one
                // moment nobody is holding anything private — so a sound here
                // is safe in a way one during a turn never is.
                onDealStarted: () => _dealSound(ref),
              ),
              const BottomHaze(),
              SafeArea(
                child: Stack(
                  children: [
                    _corner(context, l10n),
                    _titleAndAction(
                      context,
                      colors: colors,
                      spacing: spacing,
                      radii: radii,
                      type: type,
                      l10n: l10n,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dealSound(WidgetRef ref) {
    final audio = ref.read(audioDirectorProvider);
    try {
      audio.play(AudioCue.cardFlip);
    } on StateError {
      // The gate throws if the director still thinks the phone is in a hand —
      // possible for one frame when returning here from an abandoned match.
      // A missing sound effect is not worth a crash on the home screen.
    }
  }

  /// Secondary actions, small, in the top corner, out of the spread's way.
  Widget _corner(BuildContext context, AppLocalizations l10n) {
    final spacing = context.spacing;

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CornerButton(
              buttonKey: HomeScreen.howToPlayButton,
              // A question mark inside a circle, which is the shape the brief
              // asks for and the one every phone already uses for "help".
              icon: Icons.help_outline,
              label: l10n.howToPlay,
              onPressed: onHowToPlay,
            ),
            _CornerButton(
              buttonKey: HomeScreen.historyButton,
              // Reads as a scroll — a sheet with ruled lines — rather than a
              // clock, which would suggest a timer on a screen that has one.
              icon: Icons.receipt_long,
              label: l10n.history,
              onPressed: onHistory,
            ),
            _CornerButton(
              buttonKey: HomeScreen.settingsButton,
              icon: Icons.settings,
              label: l10n.settings,
              onPressed: onSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleAndAction(
    BuildContext context, {
    required MafiaColors colors,
    required MafiaSpacing spacing,
    required MafiaRadii radii,
    required MafiaTypography type,
    required AppLocalizations l10n,
  }) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.screenMargin,
            0,
            spacing.screenMargin,
            spacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.appTitle,
                style: type.display.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.xs),
              Text(
                l10n.tapCardHint,
                style: type.caption.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.lg),
              FilledButton(
                key: HomeScreen.startButton,
                onPressed: onNewMatch,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentGold,
                  foregroundColor: colors.surfaceBase,
                  padding: EdgeInsets.symmetric(vertical: spacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radii.button),
                  ),
                ),
                child: Text(l10n.startGame, style: type.title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three corner controls: help, history, settings.
///
/// These were words in boxes. They are now bare icons, under the scoped
/// navigation exception documented on [NavIconButton] — standard chrome on a
/// public screen, never role-informative, and a row of three bordered boxes was
/// competing with the deck that is supposed to *be* this screen.
///
/// The Arabic word survives as the screen-reader label, so nothing is lost for
/// anyone who was relying on reading it.
class _CornerButton extends StatelessWidget {
  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CornerButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: buttonKey,
      child: NavIconButton(
        icon: icon,
        semanticLabel: label,
        onPressed: onPressed,
      ),
    );
  }
}
