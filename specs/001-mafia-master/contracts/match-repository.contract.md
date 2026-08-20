# Contract: MatchRepository (persistence)

Abstracts all local storage so the engine/UI never import Isar directly (research R-002).
Backed by `isar_community` in the MVP.

```dart
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
  Future<MatchAnalytics> loadAnalytics(Id matchId);

  /// Delete a stored match (History swipe-to-delete, with confirm at UI).
  Future<void> deleteMatch(Id matchId);

  /// Persisted default settings for the next match.
  Future<MatchSettings> loadDefaultSettings();
  Future<void> saveDefaultSettings(MatchSettings settings);
}
```

## Invariants (integration-tested)

1. `persistStep` is atomic: an interrupted write never yields a half-written match (T7).
2. After `persistStep` then process kill then `loadActiveMatch` + `resolveResume`, the returned
   target is the PassScreen for `currentActorSeat`; secret action content is unreachable (T7).
3. `loadActiveMatch` returns null once a match reaches `result` (finished matches go to history).
4. No network call is made by any implementation (offline guarantee, FR-029).
5. Round-trip fidelity: `loadActiveMatch()` reconstructs a `Match` equal to the last persisted one
   (including seed, eventLog order, player status).
6. `loadAnalytics` is the only repository method that exposes roles/votes/investigate-results, and
   only for finished matches.
