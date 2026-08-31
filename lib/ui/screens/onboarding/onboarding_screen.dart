import 'package:flutter/material.dart';

import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/onboarding_card.dart';
import '../../widgets/onboarding_deck.dart';
import '../../widgets/onboarding_role_grid.dart';
import '../../widgets/textured_surface.dart';
import 'onboarding_chapters.dart';

/// The first-run deck (S-19): seven cards that teach the game, the phone and
/// what the app itself will not tell anyone.
///
/// ## Why this exists next to the rules screen rather than instead of it
///
/// `HowToPlayScreen` is a *reference*: six headings a host skims to settle an
/// argument mid-match. This is a *first read*, in the order the game happens,
/// one idea at a time, ending in a match. They are different jobs and they fail
/// differently — a reference that has to be paged through is useless in an
/// argument, and a first read that opens as seven stacked walls of text does
/// not get read at all. The last card links to the reference, so the deck is
/// also how a new host finds it.
///
/// The two chapters that justify the whole feature are the fifth and the sixth,
/// and they are a pair. Everything else here is also in the rules. The etiquette
/// of the pass is not, because it is not a rule — it is the handful of physical
/// habits without which this game leaks through its players rather than through
/// its pixels, and a table that has never played pass-the-phone has no way to
/// guess them. What the *device* withholds is not in the rules either, and is
/// harder still to discover: every one of those guarantees is invisible while
/// it is working. See `OnboardingChapter.secrecy`.
///
/// ## Why nothing here is Article I's business
///
/// Onboarding is on-table by definition: no roles have been dealt, nobody is
/// holding a secret, and the whole table is looking at one screen. That is the
/// same reasoning that lets Home show all four paintings at once. It is also
/// why the roles chapter may use the full-colour gallery art —
/// `handoff_purity_test.dart` derives the ban on that art from the import
/// graph, so this screen staying out of any in-hand surface is checked rather
/// than promised.
///
/// ## Ownership
///
/// This widget knows nothing about storage or routing. It takes three
/// callbacks, and the caller is responsible for recording that onboarding
/// happened — all three exits count as "seen", including [onSkip]. A host who
/// dismissed the deck has told us they do not want it, and re-offering it next
/// launch would be the app arguing with them.
class OnboardingScreen extends StatefulWidget {
  /// Leave without finishing. Reached from the header on the first card, and
  /// from the skip control on every card but the last.
  final VoidCallback onSkip;

  /// The last card's primary action: go and set a match up.
  final VoidCallback onStartMatch;

  /// The last card's secondary action: the full rules reference.
  final VoidCallback onRules;

  /// Fired when one of the roles chapter's four cards is turned over.
  ///
  /// A callback like the other three, so this screen stays free of Riverpod —
  /// the deck is pumped by widget tests and a preview, and none of them wants
  /// an audio stack.
  final VoidCallback? onCardFlip;

  const OnboardingScreen({
    super.key,
    required this.onSkip,
    required this.onStartMatch,
    required this.onRules,
    this.onCardFlip,
  });

  static const Key deck = ValueKey('onboarding_deck');
  static const Key skipButton = ValueKey('onboarding_skip');
  static const Key nextButton = ValueKey('onboarding_next');
  static const Key startButton = ValueKey('onboarding_start');
  static const Key rulesButton = ValueKey('onboarding_rules');

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _chapters = OnboardingChapter.values;

  int _index = 0;

  OnboardingChapter get _chapter => _chapters[_index];

  /// Moves by [delta] if there is anywhere to move to.
  ///
  /// Silently ignoring an out-of-range step is deliberate: it is what makes a
  /// swipe past the last card do nothing rather than bounce, and it is the only
  /// place the deck's bounds are enforced, so the deck widget does not have to
  /// know them.
  void _step(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _chapters.length) return;
    setState(() => _index = next);
  }

  /// The header's way out: back a card, or off the screen from the first.
  void _back() => _index == 0 ? widget.onSkip() : _step(-1);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: spacing.maxContentWidth),
              child: Column(
                children: [
                  ScreenHeader(title: l10n.onboardingTitle, onBack: _back),
                  Expanded(
                    child: Padding(
                      // Room at the top for the two cards peeking out of the
                      // pile, which are drawn above the active card's box.
                      padding: EdgeInsets.fromLTRB(
                        spacing.screenMargin,
                        spacing.lg,
                        spacing.screenMargin,
                        spacing.md,
                      ),
                      child: OnboardingDeck(
                        key: OnboardingScreen.deck,
                        index: _index,
                        length: _chapters.length,
                        onStep: _step,
                        builder: _card,
                      ),
                    ),
                  ),
                  _Pips(current: _index, total: _chapters.length),
                  SizedBox(height: spacing.md),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.screenMargin,
                      0,
                      spacing.screenMargin,
                      spacing.lg,
                    ),
                    child: _actions(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, int index) {
    final chapter = _chapters[index];
    final l10n = context.l10n;

    return OnboardingCard(
      numeral: chapter.numeral,
      title: chapter.title(l10n),
      body: chapter.body(l10n),
      image: chapter.image,
      child: chapter.interactive
          ? OnboardingRoleGrid(onFlip: widget.onCardFlip)
          : null,
    );
  }

  /// Skip beside Next, until the last card turns them into Rules beside Start.
  ///
  /// Both rows are the same shape — a quiet word on the leading side, the
  /// weighted action on the trailing side — so the control the thumb has been
  /// using does not move when it changes meaning.
  Widget _actions(BuildContext context) {
    final l10n = context.l10n;
    final last = _chapter.finish;

    return Row(
      children: [
        Expanded(
          child: _SecondaryAction(
            actionKey:
                last ? OnboardingScreen.rulesButton : OnboardingScreen.skipButton,
            label: last ? l10n.onboardingReadRules : l10n.skip,
            onPressed: last ? widget.onRules : widget.onSkip,
          ),
        ),
        SizedBox(width: context.spacing.md),
        Expanded(
          child: _PrimaryAction(
            actionKey:
                last ? OnboardingScreen.startButton : OnboardingScreen.nextButton,
            label: last ? l10n.onboardingStart : l10n.onboardingNext,
            onPressed: last ? widget.onStartMatch : () => _step(1),
          ),
        ),
      ],
    );
  }
}

/// One dot per card, the current one lit.
///
/// This is what carries the count exactly — the pile behind the card tops out
/// at two, so "how much is left" is this row's job. It is a single semantics
/// node reading "card 3 of 7" rather than seven unlabelled dots.
class _Pips extends StatelessWidget {
  final int current;
  final int total;

  const _Pips({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Semantics(
      label: context.l10n.onboardingProgress(current + 1, total),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xs / 2),
              child: AnimatedContainer(
                duration: context.motion.quick,
                curve: context.motion.quickCurve,
                width: spacing.xs,
                height: spacing.xs,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == current ? colors.accentGold : colors.borderSubtle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The weighted action. Same treatment as Home's start control, so "the gold
/// one is the one that moves you forward" holds across the app.
class _PrimaryAction extends StatelessWidget {
  final Key actionKey;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryAction({
    required this.actionKey,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return FilledButton(
      key: actionKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.accentGold,
        foregroundColor: colors.surfaceBase,
        padding: EdgeInsets.symmetric(vertical: spacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.radii.button),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: type.title),
      ),
    );
  }
}

/// The quiet one. A word, not a box — the app's secondary actions are words.
class _SecondaryAction extends StatelessWidget {
  final Key actionKey;
  final String label;
  final VoidCallback onPressed;

  const _SecondaryAction({
    required this.actionKey,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;

    return TextButton(
      key: actionKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.textSecondary,
        padding: EdgeInsets.symmetric(vertical: spacing.md),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: type.body),
      ),
    );
  }
}
