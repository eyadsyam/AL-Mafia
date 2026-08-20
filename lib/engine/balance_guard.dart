/// Balance validation and recommendation engine for Mafia Master.
///
/// Reference: spec FR-003, FR-004; data-model.md §4 (MatchSettings)
///
/// Pure Dart module — no Flutter or dart:ui imports.
library engine.balance_guard;

import 'models/enums.dart';

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

  const BalanceIssue({
    required this.code,
    required this.blocking,
  });

  @override
  String toString() => 'BalanceIssue(code=$code, blocking=$blocking)';
}

/// The result of balance validation.
class BalanceReport {
  /// True if no blocking issues exist.
  final bool valid;

  /// All issues, blocking first (sorted by blocking descending).
  final List<BalanceIssue> issues;

  const BalanceReport({
    required this.valid,
    required this.issues,
  });

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
      issues.add(const BalanceIssue(
        code: 'player_count_too_low',
        blocking: true,
      ));
    }
    if (playerCount > 20) {
      issues.add(const BalanceIssue(
        code: 'player_count_too_high',
        blocking: true,
      ));
    }

    // Blocking: negative counts
    for (final entry in roleCounts.entries) {
      if (entry.value < 0) {
        issues.add(const BalanceIssue(
          code: 'negative_role_count',
          blocking: true,
        ));
        break; // Report once
      }
    }

    // Blocking: counts don't sum to player count
    final roleSum = roleCounts.values.fold(0, (a, b) => a + b);
    if (roleSum != playerCount) {
      issues.add(const BalanceIssue(
        code: 'role_count_mismatch',
        blocking: true,
      ));
    }

    final mafiaCount = roleCounts[Role.mafia] ?? 0;

    // Blocking: no mafia
    if (mafiaCount < 1) {
      issues.add(const BalanceIssue(
        code: 'no_mafia',
        blocking: true,
      ));
    }

    // Blocking: mafia >= half of players
    if (mafiaCount * 2 >= playerCount) {
      issues.add(const BalanceIssue(
        code: 'mafia_too_many',
        blocking: true,
      ));
    }

    // Advisory: recommend 3 Mafia at 9+
    if (playerCount >= 9 && mafiaCount != 3) {
      issues.add(const BalanceIssue(
        code: 'recommend_three_mafia',
        blocking: false,
      ));
    }

    // Advisory: 2+ detectives below 11 players
    final detectiveCount = roleCounts[Role.detective] ?? 0;
    if (detectiveCount >= 2 && playerCount < 11) {
      issues.add(const BalanceIssue(
        code: 'two_detectives_low_player_count',
        blocking: false,
      ));
    }

    // Sort: blocking first (true > false)
    issues.sort((a, b) => (b.blocking ? 1 : 0).compareTo(a.blocking ? 1 : 0));

    final hasBlocking = issues.any((i) => i.blocking);
    return BalanceReport(
      valid: !hasBlocking,
      issues: issues,
    );
  }

  /// Returns a sensible default role distribution for the given player count.
  ///
  /// Strategy:
  /// - Mafia: 1 (5–6), 2 (7–8), 3 (9+); never ≥ half
  /// - Detective: 1
  /// - Doctor: 1
  /// - Citizen: remainder
  ///
  /// Result is always valid (use [evaluate] to check).
  static Map<Role, int> recommended(int playerCount) {
    if (playerCount < 5) playerCount = 5; // Clamp to minimum
    if (playerCount > 20) playerCount = 20; // Clamp to maximum

    late final int mafia;
    if (playerCount <= 6) {
      mafia = 1;
    } else if (playerCount <= 8) {
      mafia = 2;
    } else {
      mafia = 3;
    }

    const detective = 1;
    const doctor = 1;
    final citizen = playerCount - mafia - detective - doctor;

    return {
      Role.mafia: mafia,
      Role.detective: detective,
      Role.doctor: doctor,
      Role.citizen: citizen.clamp(0, playerCount),
    };
  }
}
