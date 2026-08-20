import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/match.dart';

import 'repository_types.dart';

/// Abstract interface for match persistence.
/// Reference: contracts/match-repository.contract.md
abstract interface class MatchRepository {
  /// Persist the full match state after a confirmed step. Must be atomic.
  Future<void> persistStep(Match match);

  /// The single unfinished match, if any (for the Resume/End prompt).
  Future<Match?> loadActiveMatch();

  /// Resolve where a resumed match must re-enter. MUST return a PassScreen
  /// target for currentActorSeat during in-hand phases — never action content.
  Future<ResumeTarget> resolveResume(Match match);

  /// Finished matches for History, newest first.
  Future<List<MatchSummary>> listHistory();

  /// Full analytics for a stored match (post-game only).
  Future<MatchAnalytics> loadAnalytics(int matchId);

  /// Delete a stored match (History swipe-to-delete, with confirm at UI).
  Future<void> deleteMatch(int matchId);

  /// Persisted default settings for the next match.
  Future<MatchSettings> loadDefaultSettings();

  /// Save default settings for the next match.
  Future<void> saveDefaultSettings(MatchSettings settings);
}
