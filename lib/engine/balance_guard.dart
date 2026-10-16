/// Balance validation and recommendation engine for Mafia Master.
///
/// Reference: spec FR-003, FR-004; data-model.md §4 (MatchSettings)
///
/// Pure Dart module — no Flutter or dart:ui imports.
library engine.balance_guard;

import 'models/enums.dart';
import 'presets.dart';

/// A single balance issue found during validation.
class BalanceIssue {
  /// Stable snake_case identifier.
  ///
  /// The engine reports *what* is wrong, never how to say it. Display text
  /// lives in the localisation layer and is looked up from this code — which is
  /// what keeps `lib/engine` free of Flutter and of any one language (L-16,
  /// FR-034). It is also why the tests match on codes: a copy edit must never
  /// break a rule test.
  final String code;

  /// Whether this issue blocks match start.
  final bool blocking;

  /// A number the message needs (the Mafia count an advisory suggests).
  final int? value;

  const BalanceIssue({required this.code, required this.blocking, this.value});

  @override
  String toString() =>
      'BalanceIssue(code=$code, blocking=$blocking, value=$value)';
}

/// The result of balance validation.
class BalanceReport {
  /// True if no blocking issues exist.
  final bool valid;

  /// All issues, blocking first (sorted by blocking descending).
  final List<BalanceIssue> issues;

  const BalanceReport({required this.valid, required this.issues});

  @override
  String toString() => 'BalanceReport(valid=$valid, issues=${issues.length})';
}

/// Validates match configuration and provides role recommendations.
///
/// Reference: spec US4 (fast setup), FR-003/FR-004 (balance rules).
class BalanceGuard {
  /// Validates a configuration and returns a report.
  ///
  /// Checks:
  /// - Player count 5–20 (blocking: < 5 or > 20)
  /// - Role counts sum to player count (blocking)
  /// - Mafia count ≥ 1 (blocking)
  /// - Mafia count < half of players (blocking)
  /// - No negative counts (blocking)
  /// - At 9+ players: recommend 3 Mafia (advisory if != 3)
  /// - 2+ Detectives below 11 players (advisory warning)
  ///
  /// Returns issues sorted: blocking first, then advisory.
  static BalanceReport evaluate({
    required int playerCount,
    required Map<Role, int> roleCounts,
  }) {
    final issues = <BalanceIssue>[];

    // Blocking: player count out of range
    if (playerCount < 5) {
      issues.add(
        const BalanceIssue(code: 'player_count_too_low', blocking: true),
      );
    }
    if (playerCount > 20) {
      issues.add(
        const BalanceIssue(code: 'player_count_too_high', blocking: true),
      );
    }

    // Blocking: negative counts
    for (final entry in roleCounts.entries) {
      if (entry.value < 0) {
        issues.add(
          const BalanceIssue(code: 'negative_role_count', blocking: true),
        );
        break; // Report once
      }
    }

    // Blocking: counts don't sum to player count
    final roleSum = roleCounts.values.fold(0, (a, b) => a + b);
    if (roleSum != playerCount) {
      issues.add(
        const BalanceIssue(code: 'role_count_mismatch', blocking: true),
      );
    }

    final mafiaCount =
        (roleCounts[Role.mafia] ?? 0) + (roleCounts[Role.silencer] ?? 0);

    // Blocking: no mafia
    if (mafiaCount < 1) {
      issues.add(const BalanceIssue(code: 'no_mafia', blocking: true));
    }

    // Blocking: mafia >= half of players
    if (mafiaCount * 2 >= playerCount) {
      issues.add(const BalanceIssue(code: 'mafia_too_many', blocking: true));
    }

    // Advisory at 9+: the split the presets deal and the balance harness
    // measures, a quarter of the table (ruling RL11). The old flat «3 Mafia
    // from nine» contradicted the app's own default.
    final suggested = recommendedMafia(playerCount);
    if (playerCount >= 9 && mafiaCount != suggested) {
      issues.add(
        BalanceIssue(
          code: 'recommend_mafia_count',
          blocking: false,
          value: suggested,
        ),
      );
    }

    // Blocking: there is one Detective in a match, never more (owner,
    // 2026-10-01). The server's `start_match` refuses the same counts.
    final detectiveCount = roleCounts[Role.detective] ?? 0;
    if (detectiveCount > 1) {
      issues.add(
        const BalanceIssue(code: 'one_detective_only', blocking: true),
      );
    }

    final silencerCount = roleCounts[Role.silencer] ?? 0;
    if (silencerCount > 1) {
      issues.add(
        const BalanceIssue(code: 'one_silencer_only', blocking: true),
      );
    }
    if (silencerCount == 1 && mafiaCount < 2) {
      issues.add(
        const BalanceIssue(code: 'silencer_needs_two_mafia', blocking: true),
      );
    }
    // One of each sold role, as the roles screen deals them and
    // `MatchEngine.start` demands (audit M2-109).
    if ((roleCounts[Role.elder] ?? 0) > 1) {
      issues.add(const BalanceIssue(code: 'one_elder_only', blocking: true));
    }
    if ((roleCounts[Role.sniper] ?? 0) > 1) {
      issues.add(const BalanceIssue(code: 'one_sniper_only', blocking: true));
    }
    if ((roleCounts[Role.elder] ?? 0) > 0 && playerCount < 6) {
      issues.add(
        const BalanceIssue(code: 'elder_min_players', blocking: true),
      );
    }
    if ((roleCounts[Role.sniper] ?? 0) > 0 && playerCount < 7) {
      issues.add(
        const BalanceIssue(code: 'sniper_min_players', blocking: true),
      );
    }

    // Sort: blocking first (true > false)
    issues.sort((a, b) => (b.blocking ? 1 : 0).compareTo(a.blocking ? 1 : 0));

    final hasBlocking = issues.any((i) => i.blocking);
    return BalanceReport(valid: !hasBlocking, issues: issues);
  }

  /// The default split for [playerCount], offline and online alike: the
  /// classic preset's quarter of the table as Mafia, one Detective, one
  /// Doctor, the rest citizens (ruling RL11). Always valid.
  static Map<Role, int> recommended(int playerCount) =>
      MatchPreset.classic.roleCounts(playerCount);

  /// The Mafia count [recommended] deals at [playerCount].
  static int recommendedMafia(int playerCount) =>
      recommended(playerCount)[Role.mafia]!;
}
