import 'package:mafia_master/engine/analytics_builder.dart';
import 'package:mafia_master/engine/models/enums.dart';

/// The screen a resumed match must re-enter on.
///
/// Note what is *not* here: there is no variant carrying a role, a night
/// action, a ballot, or an investigation result. A resume can only ever land on
/// a neutral surface, which is what makes "force-quit mid-night" safe — the
/// interrupted player has to re-identify through the pass screen before any
/// content comes back (L-13, repository contract inv. 2).
enum ResumeScreen {
  /// No match to resume.
  home,

  /// Hand the phone to [ResumeTarget.seat] — used for every in-hand phase.
  pass,

  /// On-table night lobby.
  preNightLobby,

  /// On-table morning briefing.
  morning,

  /// On-table discussion.
  discussion,

  /// On-table vote reveal.
  voteReveal,

  /// Finished match.
  result,
}

/// Where a resumed match re-enters.
class ResumeTarget {
  final ResumeScreen screen;

  /// Seat the phone must be handed to. Non-null exactly when [screen] is
  /// [ResumeScreen.pass].
  final int? seat;

  /// Display name for that seat, so the pass screen needs no further lookup.
  final String? playerName;

  final int dayNumber;

  const ResumeTarget({
    required this.screen,
    this.seat,
    this.playerName,
    this.dayNumber = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResumeTarget &&
          runtimeType == other.runtimeType &&
          screen == other.screen &&
          seat == other.seat &&
          playerName == other.playerName &&
          dayNumber == other.dayNumber;

  @override
  int get hashCode => Object.hash(screen, seat, playerName, dayNumber);

  @override
  String toString() =>
      'ResumeTarget(screen=$screen, seat=$seat, playerName=$playerName, '
      'dayNumber=$dayNumber)';
}

/// A finished match as shown in History (S-16).
///
/// Carries no roles and no ballots — those live behind [MatchAnalytics], which
/// is the only role-exposing read in the repository (contract inv. 6).
class MatchSummary {
  final int id;
  final DateTime createdAt;
  final List<String> playerNames;
  final Alignment? winner;
  final int nights;

  const MatchSummary({
    required this.id,
    required this.createdAt,
    required this.playerNames,
    required this.winner,
    required this.nights,
  });

  int get playerCount => playerNames.length;

  @override
  String toString() =>
      'MatchSummary(id=$id, players=${playerNames.length}, winner=$winner, '
      'nights=$nights)';
}

/// Full post-game analytics for one stored match.
class MatchAnalytics {
  final int matchId;
  final Map<int, String> playerNames;
  final MatchAnalyticsData data;

  const MatchAnalytics({
    required this.matchId,
    required this.playerNames,
    required this.data,
  });

  @override
  String toString() => 'MatchAnalytics(matchId=$matchId, data=$data)';
}
