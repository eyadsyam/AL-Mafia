import '../../../../app/asset_constants.dart';
import '../../../../engine/models/enums.dart' show GamePhase;

/// What the table *is* during a phase (doc 12 §2.2).
///
/// ## The one rule this type exists to make structural
///
/// Doc 12 §2.3, binding: *"during the night phase, every seat renders
/// identically — no speaking indicators, no connection dots, no action-complete
/// ticks, no typing states."*
///
/// That rule is easy to write and easy to lose. It gets lost the day somebody
/// adds a "typing…" dot to the whisper feature and does not think about the
/// night, because the dot lives in a seat widget and the night lives in a
/// screen. So the rule is not in a seat widget and not in a screen: it is
/// [showsPerSeatStatus], one boolean, on a table keyed by phase, and every
/// per-seat affordance in the whole online surface reads it.
///
/// ## And the one this type exists to make impossible
///
/// [TableMood.of] takes a [GamePhase] and nothing else. There is no [Role]
/// parameter, no seat, no viewer. Backdrop, dimming and every visual property
/// below are therefore **role-blind by construction** rather than by review: a
/// future change cannot make the table look different for a Mafia without first
/// changing this signature, which is a thing a reviewer notices.
///
/// That is what makes doc 12 §7's backdrops safe. A still behind the table is
/// forbidden by doc 05 on an in-hand surface *whose content varies by role* —
/// the pass screen, the role card, the night action panel. A backdrop chosen
/// only by phase varies with the time of day, which the whole room already
/// knows.
enum TableMoodKind {
  /// Before the match. The only phase where per-seat presence is unambiguously
  /// safe, because no role exists yet (doc 10 §6.3).
  lobby,

  /// Cards being looked at, each on its owner's own device.
  reveal,

  /// The table is near-black and every seat is a silhouette.
  night,

  /// Light returns; somebody's card tears.
  morning,

  /// One player is spotlit and everybody else is an audience.
  confrontation,

  /// Open floor. The speaking seat breathes.
  discussion,

  /// Cards face the centre and lines of intent accumulate.
  vote,

  /// Every card flips at once.
  result,
}

/// The table's state during one phase.
class TableMood {
  final TableMoodKind kind;

  /// Backdrop still, drawn behind the table at [backdropOpacity].
  ///
  /// Null means the bare ground. Never role-derived — see the class comment.
  final String? backdrop;

  /// An ambient loop to use instead of [backdrop] when motion is allowed.
  ///
  /// Same contract as `AppBackdrop.loop`: Reduce Motion renders [backdrop], and
  /// the phase holds for exactly as long either way.
  final String? backdropLoop;

  /// How strongly the whole table is darkened, 0 (untouched) to 1 (black).
  final double dim;

  /// Whether **any** per-seat status may be drawn this phase.
  ///
  /// False for every phase in which somebody, somewhere, is looking at
  /// something private. See the class comment; this is the binding rule.
  final bool showsPerSeatStatus;

  /// Whether the day's whisper graph is drawn as faint lines (doc 12 §3.7).
  final bool showsWhisperGraph;

  /// Whether ballots are drawn as lines from voter to target (doc 12 §3.6).
  final bool showsVoteLines;

  /// Whether the seats have turned to face the centre.
  final bool facesCentre;

  const TableMood({
    required this.kind,
    required this.backdrop,
    required this.backdropLoop,
    required this.dim,
    required this.showsPerSeatStatus,
    required this.showsWhisperGraph,
    required this.showsVoteLines,
    required this.facesCentre,
  });

  /// Opacity every backdrop is drawn at (doc 12 §7: 15–20%).
  ///
  /// One number, not a range, and not per-phase. A backdrop whose opacity moved
  /// with the phase would be a brightness channel, and brightness that changes
  /// with state is the thing the luminance budget exists to stop.
  static const double backdropOpacity = 0.18;

  /// The table's state for [phase].
  ///
  /// Total over [GamePhase] on purpose — no default arm. A phase added to the
  /// engine fails to compile here until somebody decides what the table looks
  /// like during it, which is the only reliable way this file stays complete.
  static TableMood of(GamePhase phase) => switch (phase) {
    GamePhase.setup || GamePhase.rolesConfigured => const TableMood(
      kind: TableMoodKind.lobby,
      backdrop: AppImages.bgHome,
      backdropLoop: AppVideo.bgHomeLoop,
      dim: 0.0,
      // Before roles exist. Doc 10 §6.3 names this as the one screen
      // where presence is unambiguously safe, and the lobby needs it:
      // the room has to be able to see why nothing is happening.
      showsPerSeatStatus: true,
      showsWhisperGraph: false,
      showsVoteLines: false,
      facesCentre: false,
    ),
    // Roles are in hands from here until the morning. Nothing per-seat.
    GamePhase.distributing => const TableMood(
      kind: TableMoodKind.reveal,
      backdrop: AppImages.bgNight,
      backdropLoop: null,
      dim: 0.85,
      showsPerSeatStatus: false,
      showsWhisperGraph: false,
      showsVoteLines: false,
      facesCentre: false,
    ),
    // The waiting room between "I have seen my card" and the night. A
    // completion count here would say who is still reading, and how long a
    // role's card takes to read is a property of the role (doc 12 §3.3).
    GamePhase.preNightLobby => const TableMood(
      kind: TableMoodKind.reveal,
      backdrop: AppImages.bgNight,
      backdropLoop: null,
      dim: 0.7,
      showsPerSeatStatus: false,
      showsWhisperGraph: false,
      showsVoteLines: false,
      facesCentre: false,
    ),
    GamePhase.night || GamePhase.nightResolving => const TableMood(
      kind: TableMoodKind.night,
      backdrop: AppImages.bgNight,
      backdropLoop: AppVideo.bgNightLoop,
      dim: 0.9,
      showsPerSeatStatus: false,
      showsWhisperGraph: false,
      showsVoteLines: false,
      facesCentre: false,
    ),
    GamePhase.morning => const TableMood(
      kind: TableMoodKind.morning,
      backdrop: AppImages.bgDay,
      backdropLoop: null,
      dim: 0.0,
      showsPerSeatStatus: true,
      showsWhisperGraph: false,
      showsVoteLines: false,
      facesCentre: false,
    ),
    GamePhase.openingRound || GamePhase.discussion => const TableMood(
      kind: TableMoodKind.discussion,
      backdrop: AppImages.bgDay,
      backdropLoop: null,
      dim: 0.0,
      showsPerSeatStatus: true,
      showsWhisperGraph: true,
      showsVoteLines: false,
      facesCentre: false,
    ),
    GamePhase.confrontation => const TableMood(
      kind: TableMoodKind.confrontation,
      backdrop: AppImages.bgVote,
      backdropLoop: null,
      // The spotlight does the darkening, per seat. A flat dim on top of
      // it would flatten the cone that is the whole point.
      dim: 0.0,
      showsPerSeatStatus: true,
      showsWhisperGraph: true,
      showsVoteLines: false,
      facesCentre: false,
    ),
    GamePhase.voting || GamePhase.voteResolving => const TableMood(
      kind: TableMoodKind.vote,
      backdrop: AppImages.bgVote,
      backdropLoop: AppVideo.bgVoteLoop,
      dim: 0.0,
      showsPerSeatStatus: true,
      showsWhisperGraph: true,
      showsVoteLines: true,
      facesCentre: true,
    ),
    // The elimination reveal. Still the ballot's table — the lines are what
    // converge on the seat that is about to tear.
    GamePhase.reveal || GamePhase.winCheck => const TableMood(
      kind: TableMoodKind.vote,
      backdrop: AppImages.bgVote,
      backdropLoop: null,
      dim: 0.0,
      showsPerSeatStatus: true,
      showsWhisperGraph: false,
      showsVoteLines: true,
      facesCentre: true,
    ),
    GamePhase.result || GamePhase.analytics => const TableMood(
      kind: TableMoodKind.result,
      backdrop: null,
      backdropLoop: null,
      dim: 0.0,
      showsPerSeatStatus: false,
      showsWhisperGraph: false,
      showsVoteLines: false,
      facesCentre: true,
    ),
  };

  /// Every backdrop the table can ever draw.
  ///
  /// Used by the payload test in doc 12 §10 — the budget is a claim about a set
  /// of files, so the set has to be enumerable without rendering anything.
  static const List<String> backdrops = <String>[
    AppImages.bgHome,
    AppImages.bgNight,
    AppImages.bgDay,
    AppImages.bgVote,
    AppVideo.bgHomeLoop,
    AppVideo.bgNightLoop,
    AppVideo.bgVoteLoop,
  ];
}
