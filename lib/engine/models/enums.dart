/// Enums for the Mafia Master game engine.
/// Reference: data-model.md §3, §9
library engine.models.enums;

/// Win alignment: either Mafia or Town.
enum Alignment { mafia, town }

/// A player's role determines their night action and win condition.
/// Reference: data-model.md §3
enum Role { mafia, doctor, detective, citizen }

extension RoleX on Role {
  /// Returns the alignment: mafia roles align with mafia; others with town.
  Alignment get alignment =>
      this == Role.mafia ? Alignment.mafia : Alignment.town;
}

/// A player's current vital status.
/// Reference: data-model.md §2
enum PlayerStatus { alive, dead }

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
enum DiscussionMode { structured, free }

/// Tie-breaking rule for day votes.
/// Reference: data-model.md §4
enum DayTieRule { revote, noElimination }

/// Type of night action a player may perform.
/// Reference: data-model.md §5
enum NightActionKind { mafiaVote, protect, investigate, suspect }

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

/// «الطلقة الواحدة» — the one irreversible thing each role is holding.
///
/// Doc 13 §2. Every role has exactly one, it is available from Night 1, it is
/// spent at most once in a whole match, and it cannot be taken back. That
/// symmetry is not decoration: doc 05 rule 6 wants one layout tree for all four
/// night screens, and a mechanic that only three roles had would need a fourth
/// screen shape to hide it in.
enum BulletKind {
  /// مافيا — «الليلة الهادية». Tonight there is no kill at all.
  ///
  /// The team's, not one Mafioso's: whoever spends it spends it for everybody,
  /// because the kill it cancels was always the team's single kill.
  quietNight,

  /// طبيب — «حماية النفس». The one night the Doctor may cover their own seat.
  selfProtect,
}

/// The once-per-match ability a role is holding, or null for the two roles
/// that hold none.
///
/// **It used to be total, and doc 14 is why it is not any more.** Four roles
/// with one ability each was a symmetry bought rather than found: the Detective
/// got «فتح الملف» and the Citizen «الشهادة» because the other two had
/// something, not because either was worth playing. Doc 14 §4.1 removes the
/// file outright and §4.2 defers the testimony, and the honest way to say that
/// is a null.
///
/// The symmetry the night screen actually needs survives without it, because it
/// was never this: every role's grid is *N* tiles with a special one in the
/// last position (doc 14 §1.3), and a role with no ability simply spends that
/// tile on "choose nobody".
extension RoleBullet on Role {
  BulletKind? get bullet => switch (this) {
    Role.mafia => BulletKind.quietNight,
    Role.doctor => BulletKind.selfProtect,
    Role.detective => null,
    Role.citizen => null,
  };
}
