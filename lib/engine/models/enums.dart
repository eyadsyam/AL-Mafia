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

  /// Day 1's «اسم واحد» round — every living player names one suspect aloud,
  /// in seating order, ten seconds each (doc 09 §2.2).
  ///
  /// A phase of its own rather than a mode of [discussion] because it has a
  /// current actor and [discussion] does not: the phone points at one seat at
  /// a time, which is exactly the distinction `currentActorSeat` draws.
  openingRound,

  /// Day 2+'s single confrontation (doc 09 §2). One player is named and given
  /// a timed window; nobody else may speak.
  confrontation,

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

/// The night action every role performs, as a total function of the role.
///
/// One place, so that a caller who needs "what does this seat do tonight" —
/// the fuzz driver, the online timer-expiry defaults, the whisper card — cannot
/// answer it differently from the engine.
extension RoleNightAction on Role {
  NightActionKind get nightAction => switch (this) {
        Role.mafia => NightActionKind.mafiaVote,
        Role.doctor => NightActionKind.protect,
        Role.detective => NightActionKind.investigate,
        Role.citizen => NightActionKind.suspect,
      };
}
