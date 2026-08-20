import '../../../app/l10n/app_localizations.dart';

/// What onboarding says, as data.
///
/// ## Why this is a list and not six widgets
///
/// The deck is a rendering concern; the curriculum is not. Keeping the six
/// chapters as records means the whole of what a new host is told fits on one
/// screen of one file, in order, and can be read by someone deciding whether it
/// is too long — which is the question this feature will actually be judged on.
/// It also means the deck widget has nothing to know about the content: it
/// deals `chapters.length` cards and asks each one for a title and a body.
///
/// ## Why the copy is reached through a getter rather than stored
///
/// [AppLocalizations] is resolved from a [BuildContext], and this list is
/// `const`. Holding the *lookup* rather than the string is what lets the list be
/// const and still be correct in both locales — the same arrangement
/// `EngineCopy` uses for the engine's codes.
enum OnboardingChapter {
  /// What this game is. Nothing about the app at all — a host who stops reading
  /// after one card should still know what they have sat down to play.
  story(),

  /// The four roles. The only chapter with its own artwork, and the only one
  /// that is interactive: the cards are on the table and you turn them over.
  roles(interactive: true),

  /// The night, which is the half of the game the app actually runs.
  night(),

  /// The day: the announcement, the timer, the vote.
  day(),

  /// The etiquette of the pass.
  ///
  /// This is the chapter that justifies the feature. Everything else here is
  /// also in `HowToPlayScreen`; this is not, because it is not a *rule* — it is
  /// the handful of physical habits without which a pass-the-phone game leaks
  /// through its players instead of through its pixels. A table that has never
  /// played this way has no reason to guess any of it.
  pass(),

  /// How each side wins, and the way out into a real match.
  win(finish: true);

  /// Whether the card carries something to touch besides the deal control.
  final bool interactive;

  /// Whether this is the last card, which is the one that offers to start a
  /// match instead of dealing another.
  final bool finish;

  const OnboardingChapter({this.interactive = false, this.finish = false});

  /// The chapter's heading.
  String title(AppLocalizations l10n) => switch (this) {
        OnboardingChapter.story => l10n.onboardingStoryTitle,
        OnboardingChapter.roles => l10n.onboardingRolesTitle,
        OnboardingChapter.night => l10n.onboardingNightTitle,
        OnboardingChapter.day => l10n.onboardingDayTitle,
        OnboardingChapter.pass => l10n.onboardingPassTitle,
        OnboardingChapter.win => l10n.onboardingWinTitle,
      };

  /// The chapter's body, two to five short lines.
  String body(AppLocalizations l10n) => switch (this) {
        OnboardingChapter.story => l10n.onboardingStoryBody,
        OnboardingChapter.roles => l10n.onboardingRolesBody,
        OnboardingChapter.night => l10n.onboardingNightBody,
        OnboardingChapter.day => l10n.onboardingDayBody,
        OnboardingChapter.pass => l10n.onboardingPassBody,
        OnboardingChapter.win => l10n.onboardingWinBody,
      };

  /// The numeral printed on the card, as it is printed: 1-based, Western
  /// digits.
  ///
  /// Western rather than Arabic-Indic because the app already sets its Arabic
  /// copy that way — `rulesDayBody` numbers its steps 1, 2, 3 — and because the
  /// display face is Bebas Neue, which has no Arabic-Indic glyphs and would
  /// silently fall back to Cairo for the one element on the card that is meant
  /// to be set in the display face.
  String get numeral => '${index + 1}';
}
