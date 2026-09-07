import 'package:flutter/widgets.dart';

import '../app/l10n/app_localizations.dart';
import '../engine/balance_guard.dart';
import '../engine/coaching.dart';
import '../engine/hints.dart';
import '../engine/models/enums.dart' show BulletKind, Role;
import '../engine/presets.dart';

/// Convenient, non-null access to the app's strings.
extension AppLocalizationsX on BuildContext {
  /// The localised strings for the current locale.
  ///
  /// Non-null by assertion rather than by `!`: a screen rendered without the
  /// delegates installed is a wiring bug, and a clear message beats a
  /// null-check crash three frames later.
  AppLocalizations get l10n {
    final strings = AppLocalizations.of(this);
    assert(
      strings != null,
      'No AppLocalizations found. Add AppLocalizations.delegate to the app, '
      'or wrap the widget under test with the localisation delegates.',
    );
    return strings!;
  }
}

/// Display text for the engine's stable codes.
///
/// ## Why this lives in the UI layer
///
/// `lib/engine` is pure Dart and language-agnostic: it reports *that* a setup
/// is unbalanced or *that* an achievement was earned, using a snake_case code,
/// and never how to phrase it (L-16, FR-034). This is the other half of that
/// arrangement — the single place those codes turn into words.
///
/// Every lookup falls back to the code itself rather than throwing. An
/// unrecognised code means someone added an engine rule without adding copy;
/// that should show up as an obviously-wrong label in review, not as a crash in
/// front of players.
abstract final class EngineCopy {
  /// A balance issue's message.
  static String balanceIssue(AppLocalizations l10n, BalanceIssue issue) =>
      switch (issue.code) {
        'player_count_too_low' => l10n.balancePlayerCountTooLow,
        'player_count_too_high' => l10n.balancePlayerCountTooHigh,
        'negative_role_count' => l10n.balanceNegativeRoleCount,
        'role_count_mismatch' => l10n.balanceRoleCountMismatch,
        'no_mafia' => l10n.balanceNoMafia,
        'mafia_too_many' => l10n.balanceMafiaTooMany,
        'recommend_three_mafia' => l10n.balanceRecommendThreeMafia,
        'two_detectives_low_player_count' =>
          l10n.balanceTwoDetectivesLowPlayerCount,
        _ => issue.code,
      };

  /// An achievement's title.
  static String achievementTitle(AppLocalizations l10n, String code) =>
      switch (code) {
        'sharpest_eye' => l10n.achievementSharpestEye,
        'untouchable' => l10n.achievementUntouchable,
        'guardian' => l10n.achievementGuardian,
        'first_blood' => l10n.achievementFirstBlood,
        'survivors' => l10n.achievementSurvivors,
        _ => code,
      };

  /// An achievement's one-line explanation.
  static String achievementDescription(AppLocalizations l10n, String code) =>
      switch (code) {
        'sharpest_eye' => l10n.achievementSharpestEyeDescription,
        'untouchable' => l10n.achievementUntouchableDescription,
        'guardian' => l10n.achievementGuardianDescription,
        'first_blood' => l10n.achievementFirstBloodDescription,
        'survivors' => l10n.achievementSurvivorsDescription,
        _ => code,
      };

  /// The name of a role's once-per-match ability, for the post-match note that
  /// says it went unused. Two roles have one; the other two hold nothing.
  static String bulletName(AppLocalizations l10n, BulletKind kind) =>
      switch (kind) {
        BulletKind.quietNight => l10n.bulletMafia,
        BulletKind.selfProtect => l10n.bulletDoctor,
      };

  /// The words on the last tile of the night grid (doc 14 §1.3).
  ///
  /// Only for the three roles whose special tile records no target. The
  /// Doctor's tile carries their own name instead, which the night screen
  /// already has and this layer does not.
  static String nightSpecial(AppLocalizations l10n, Role role) =>
      switch (role) {
        Role.mafia => l10n.nightSpecialMafia,
        Role.doctor => l10n.nightSpecialDoctor,
        Role.detective => l10n.nightSpecialDetective,
        Role.citizen => l10n.nightSpecialCitizen,
      };

  /// A play hint's sentence (doc 13 §4.3).
  static String playHint(AppLocalizations l10n, PlayHint hint) =>
      switch (hint.code) {
        'hint_talkers' => l10n.hintTalkers,
        'hint_quick_agreement' => l10n.hintQuickAgreement,
        'hint_silence' => l10n.hintSilence,
        'hint_changes_mind' => l10n.hintChangesMind,
        'hint_early_accuser' => l10n.hintEarlyAccuser,
        'hint_majority_comfort' => l10n.hintMajorityComfort,
        'hint_who_benefited' => l10n.hintWhoBenefited,
        'hint_mafia_suspicion_spreads' => l10n.hintMafiaSuspicionSpreads,
        'hint_mafia_quiet_night' => l10n.hintMafiaQuietNight,
        'hint_mafia_speak' => l10n.hintMafiaSpeak,
        'hint_doctor_no_repeat' => l10n.hintDoctorNoRepeat,
        'hint_doctor_self' => l10n.hintDoctorSelf,
        'hint_doctor_save_reveals' => l10n.hintDoctorSaveReveals,
        'hint_detective_investigate_loud' => l10n.hintDetectiveInvestigateLoud,
        'hint_citizen_suspicion_counts' => l10n.hintCitizenSuspicionCounts,
        _ => hint.code,
      };

  /// One «كان ممكن» note (doc 13 §4.4), with its own numbers in it.
  ///
  /// [nameOf] resolves the seats the note names. Passed in rather than looked
  /// up, because the engine deals in seats and only the caller holds a roster.
  static String coaching(
    AppLocalizations l10n,
    CoachingNote note,
    String Function(int seat) nameOf,
  ) =>
      switch (note.code) {
        CoachingCode.stuckOnInnocent => l10n.coachStuckOnInnocent(
            nameOf(note.seats.first), note.numbers.first),
        CoachingCode.conformity =>
          l10n.coachConformity(note.numbers[0], note.numbers[1]),
        CoachingCode.unusedBullet => l10n.coachUnusedBullet(
            bulletName(l10n, BulletKind.values[note.numbers.first])),
        CoachingCode.neverWhispered => l10n.coachNeverWhispered,
        CoachingCode.abandonedRead =>
          l10n.coachAbandonedRead(nameOf(note.seats.first)),
        CoachingCode.quiet => l10n.coachQuiet(note.numbers.first),
        CoachingCode.survivedAsMafia => l10n.coachSurvivedAsMafia,
        _ => note.code,
      };

  /// A preset's name (doc 13 §5).
  static String presetName(AppLocalizations l10n, MatchPreset? preset) =>
      switch (preset) {
        MatchPreset.fast => l10n.presetFast,
        MatchPreset.classic => l10n.presetClassic,
        MatchPreset.brutal => l10n.presetBrutal,
        null => l10n.presetCustom,
      };

  /// What a preset is for, in one line.
  static String presetHint(AppLocalizations l10n, MatchPreset preset) =>
      switch (preset) {
        MatchPreset.fast => l10n.presetFastHint,
        MatchPreset.classic => l10n.presetClassicHint,
        MatchPreset.brutal => l10n.presetBrutalHint,
      };

  /// The player-facing name of a role.
  ///
  /// Only for surfaces where the game has decided a role may be shown: the
  /// owner's own card, the day-vote reveal, and post-game analytics.
  static String roleName(AppLocalizations l10n, Role role) => switch (role) {
    Role.mafia => l10n.roleMafia,
    Role.doctor => l10n.roleDoctor,
    Role.detective => l10n.roleDetective,
    Role.citizen => l10n.roleCitizen,
  };

  /// A role's card description.
  static String roleDescription(AppLocalizations l10n, Role role) =>
      switch (role) {
        Role.mafia => l10n.roleMafiaDescription,
        Role.doctor => l10n.roleDoctorDescription,
        Role.detective => l10n.roleDetectiveDescription,
        Role.citizen => l10n.roleCitizenDescription,
      };

  /// The night question a role is asked.
  ///
  /// All four must render the same amount of ink and must not name any role;
  /// see `night_prompt_balance_test`.
  static String nightPrompt(AppLocalizations l10n, Role role) => switch (role) {
    Role.mafia => l10n.nightPromptMafia,
    Role.doctor => l10n.nightPromptDoctor,
    Role.detective => l10n.nightPromptDetective,
    Role.citizen => l10n.nightPromptCitizen,
  };
}
