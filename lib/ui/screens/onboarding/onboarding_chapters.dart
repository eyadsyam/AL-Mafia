import '../../../app/asset_constants.dart';
import '../../../app/l10n/app_localizations.dart';

/// What onboarding says, as data.
///
/// ## Why this is a list and not seven widgets
///
/// The deck is a rendering concern; the curriculum is not. Keeping the seven
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

  /// What the *app* refuses to give away, which is the other half of [pass].
  ///
  /// [pass] is what the humans must not leak. This is what the device does not,
  /// and it is here because it is the thing a first-time table has no way to
  /// find out by playing: every guarantee it lists is invisible when it is
  /// working. Nobody notices that four role cards were matched to within 2% of
  /// each other's brightness, or that the citizen's night turn is held at the
  /// same eight-second dwell as the mafia's so a short turn cannot be counted
  /// from across the table. They would notice the absence of all of it
  /// immediately, in the form of a game that stops being worth playing.
  ///
  /// Which is why this is a card and not a line in the settings screen. The
  /// secrecy *is* the product — the reason to hand a phone round a table
  /// instead of dealing paper cards — and a host who does not know it is there
  /// cannot tell their table why they should trust it.
  ///
  /// Every claim on the card is one the suite actually holds: the luminance
  /// budget (L-05), the dwell gate (L-07), the in-hand audio gate, the
  /// auto-conceal, and the deliberate absence of any per-player role field in
  /// `PlayerGroup`. If one of them ever stops being true, this copy is a lie
  /// and not merely stale — change the code back rather than the card.
  secrecy(),

  /// How each side wins, and the way out into a real match.
  win(finish: true);

  /// Whether the card carries something to touch besides the deal control.
  final bool interactive;

  /// The chapter's painting, or null to print the numeral alone.
  ///
  /// Null for two chapters, for two different reasons. [roles] already deals
  /// the four gallery paintings through `OnboardingRoleGrid`, and a band of art
  /// above them would be a fifth picture competing with the four the card is
  /// about. [secrecy] has no painting because none was ever generated for it —
  /// it is the newest chapter and there is no source art (see HANDOFF §6), so
  /// it prints its numeral like the deck did before any of this art existed.
  /// Naming an `onboarding_secrecy` slot here is the whole job once one exists.
  String? get image => switch (this) {
        OnboardingChapter.story => AppImages.onboardingStory,
        OnboardingChapter.roles => null,
        OnboardingChapter.night => AppImages.onboardingNight,
        OnboardingChapter.day => AppImages.onboardingDay,
        OnboardingChapter.pass => AppImages.onboardingPass,
        OnboardingChapter.secrecy => null,
        OnboardingChapter.win => AppImages.onboardingWin,
      };

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
        OnboardingChapter.secrecy => l10n.onboardingSecrecyTitle,
        OnboardingChapter.win => l10n.onboardingWinTitle,
      };

  /// The chapter's body, two to five short lines.
  String body(AppLocalizations l10n) => switch (this) {
        OnboardingChapter.story => l10n.onboardingStoryBody,
        OnboardingChapter.roles => l10n.onboardingRolesBody,
        OnboardingChapter.night => l10n.onboardingNightBody,
        OnboardingChapter.day => l10n.onboardingDayBody,
        OnboardingChapter.pass => l10n.onboardingPassBody,
        OnboardingChapter.secrecy => l10n.onboardingSecrecyBody,
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
