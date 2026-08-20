import 'package:flutter/widgets.dart';

import '../app/l10n/app_localizations.dart';
import '../engine/balance_guard.dart';
import '../engine/models/enums.dart' show Role;

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
