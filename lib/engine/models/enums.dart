/// Enums for the Mafia Master game engine.
/// Reference: data-model.md §3, §9
library engine.models.enums;

/// Win alignment: either Mafia or Town.
enum Alignment {
  mafia,
  town,
}

/// A player's role determines their night action and win condition.
/// Reference: data-model.md §3
enum Role {
  mafia,
  doctor,
  detective,
  citizen,
}

extension RoleX on Role {
  /// Returns the alignment: mafia roles align with mafia; others with town.
  Alignment get alignment => this == Role.mafia ? Alignment.mafia : Alignment.town;
}

/// A player's current vital status.
/// Reference: data-model.md §2
enum PlayerStatus {
  alive,
  dead,
}

/// The game's finite state machine phases.
/// Reference: data-model.md §9
enum GamePhase {
  setup,
  rolesConfigured,
  distributing,
  preNightLobby,
  night,
  nightResolving,
  morning,
  discussion,
  voting,
  voteResolving,
  reveal,
  winCheck,
  result,
  analytics,
}

/// Configuration for discussion phase behavior.
/// Reference: data-model.md §4
enum DiscussionMode {
  structured,
  free,
}

/// Tie-breaking rule for day votes.
/// Reference: data-model.md §4
enum DayTieRule {
  revote,
  noElimination,
}

/// Type of night action a player may perform.
/// Reference: data-model.md §5
enum NightActionKind {
  mafiaVote,
  protect,
  investigate,
  suspect,
}
