/// The Information Engine's record model (doc 09 §5).
///
/// ## These are a projection, not a second source of truth
///
/// Doc 09 §5 presents `NightRecord`, `DayRecord` and `GameHistory` as stored
/// classes. They are **derived** here instead, by `buildHistory` in
/// `game_history.dart`, from the event log the engine already keeps.
///
/// The reason is the one the repository contract already turns on: the event
/// log is append-only, is what persists, and is what a resumed match is rebuilt
/// from. A parallel set of record rows would have to be written in the same
/// transaction as the events, kept in step with them through every command, and
/// migrated whenever either shape changed — three chances to drift, in exchange
/// for nothing the projection does not give. A `GameHistory` built from the log
/// cannot disagree with the log.
///
/// The one thing that genuinely *is* stored separately is a whisper's body, and
/// for the opposite reason: it must never enter the log at all. See [Whisper].
library engine.information.records;

import '../models/information_enums.dart';

/// Everything that happened on one night, as the generators need to read it.
class NightRecord {
  final int nightNumber;

  /// Who each Citizen suspected. A key with a null value means that seat took
  /// its turn and deliberately recorded nobody — which is a different fact from
  /// having no key at all (that seat is not a Citizen, or is dead), and `T6`
  /// and `C10` depend on the difference.
  final Map<int, int?> suspicions;

  /// Optional ≤40-character notes, keyed the same way as [suspicions].
  final Map<int, String?> reasons;

  /// The Mafia's agreed target, after their internal tie-break.
  final int? mafiaTarget;

  /// Who the Doctor covered.
  final int? doctorProtect;

  /// Who the Detective looked at. The *result* is deliberately absent: it is
  /// the one fact in the game that is never written down (doc 05 rule 10).
  final int? detectiveCheck;

  /// Who actually died. Null when nobody did.
  final int? victim;

  /// Whether a kill was blocked.
  final bool saveOccurred;

  /// Who was saved.
  ///
  /// **Only `C11` may read this, and `C11` is off by default.** `T2` announces
  /// that a save happened and is forbidden from naming anyone (doc 09 §1.4:
  /// *"Names? ❌ never"*), because the saved seat plus the night's talk is most
  /// of the Doctor's aim. It is on the record because `C11` cannot be expressed
  /// without it and because the post-game autopsy is entitled to it once the
  /// match is over — not because anything mid-match may show it.
  final int? savedSeat;

  /// The seat the Mafia settled on, whether or not the kill landed.
  ///
  /// Equal to [victim] when the kill went through and to [savedSeat] when it
  /// was blocked; null when the Mafia agreed on nobody at all.
  int? get mafiaTargetSeat => victim ?? savedSeat ?? mafiaTarget;

  /// What was published the next morning, or null if the night has not been
  /// resolved yet.
  final TraceType? revealedTrace;

  /// Whether this night has been resolved. The current night appears in the
  /// history while it is still being played, so that a generator asked to run
  /// mid-night reads a half-filled record rather than no record.
  final bool resolved;

  const NightRecord({
    required this.nightNumber,
    required this.suspicions,
    required this.reasons,
    this.mafiaTarget,
    this.doctorProtect,
    this.detectiveCheck,
    this.victim,
    this.saveOccurred = false,
    this.savedSeat,
    this.revealedTrace,
    this.resolved = false,
  });

  /// Seats that took a night turn and chose nobody.
  Iterable<int> get skipped =>
      suspicions.entries.where((e) => e.value == null).map((e) => e.key);

  /// Seat → suspected seat, skips excluded.
  Map<int, int> get recordedSuspicions => {
    for (final e in suspicions.entries)
      if (e.value != null) e.key: e.value!,
  };

  @override
  String toString() =>
      'NightRecord(n=$nightNumber, suspicions=$suspicions, victim=$victim, '
      'saveOccurred=$saveOccurred, revealedTrace=$revealedTrace)';
}

/// Everything that happened on one day.
class DayRecord {
  final int dayNumber;

  /// The Day-1 «اسم واحد» round: who each living player named aloud.
  ///
  /// Empty on every other day, and empty on Day 1 too when the round is turned
  /// off. This is the only *public* accusation record in the game, which is why
  /// `C1` can quote it back at a player and a night suspicion never could.
  final Map<int, int> openingAccusations;

  /// The one confrontation put to the table today, if any.
  final Confrontation? confrontation;

  /// Whether the confronted player let the window pass without speaking.
  final bool confrontationSilent;

  /// Ballots from the final round of the day. Null means abstain.
  final Map<int, int?> votes;

  /// Every ballot of every round, for the days that went to a revote.
  final Map<int, Map<int, int?>> votesByRound;

  /// Who the table voted out, or null.
  final int? eliminated;

  /// Floor time per seat. Absent seats spoke for zero seconds.
  final Map<int, int> speakingSeconds;

  /// The whisper graph for this day — never the bodies.
  final List<WhisperMeta> whispers;

  const DayRecord({
    required this.dayNumber,
    this.openingAccusations = const {},
    this.confrontation,
    this.confrontationSilent = false,
    this.votes = const {},
    this.votesByRound = const {},
    this.eliminated,
    this.speakingSeconds = const {},
    this.whispers = const [],
  });

  @override
  String toString() =>
      'DayRecord(d=$dayNumber, opening=$openingAccusations, '
      'confrontation=$confrontation, votes=$votes, eliminated=$eliminated, '
      'whispers=${whispers.length})';
}

/// A confrontation, as chosen by the generator and as recorded in the log.
class Confrontation {
  final ConfrontationType type;

  /// The player being asked to explain themselves.
  final int targetSeat;

  /// The other player the observation refers to, when there is one.
  final int? evidenceSeat;

  /// A second player, for the one type whose sentence names two — `C1`, where
  /// the whole observation is that the player accused one person and then voted
  /// for another. Two seats, or the contradiction cannot be stated.
  final int? evidenceSeat2;

  /// The day the behaviour happened on. Feeds the recency factor.
  final int? evidenceDay;

  /// The number in «صوّتوا نفس التصويت ٣ مرات» and its siblings.
  final int? count;

  const Confrontation({
    required this.type,
    required this.targetSeat,
    this.evidenceSeat,
    this.evidenceSeat2,
    this.evidenceDay,
    this.count,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Confrontation &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          targetSeat == other.targetSeat &&
          evidenceSeat == other.evidenceSeat &&
          evidenceSeat2 == other.evidenceSeat2 &&
          evidenceDay == other.evidenceDay &&
          count == other.count;

  @override
  int get hashCode => Object.hash(
    type,
    targetSeat,
    evidenceSeat,
    evidenceSeat2,
    evidenceDay,
    count,
  );

  @override
  String toString() =>
      'Confrontation(${type.name}, target=$targetSeat, '
      'evidence=$evidenceSeat/$evidenceSeat2@$evidenceDay, count=$count)';
}

/// The published half of a whisper: who wrote to whom, and when.
///
/// This is table-visible. Doc 09 §3.1: *"The existence and the recipient are
/// public. The content is private."*
class WhisperMeta {
  /// `w:<day>:<from>:<to>`. Deterministic, so the graph and the body store can
  /// be joined without a generated id surviving a round trip.
  final String id;
  final int day;
  final int fromSeat;
  final int toSeat;

  /// The recipient died before opening it. The sender is told «الهمسة ماوصلتش».
  final bool voided;

  /// The recipient has read it.
  final bool delivered;

  const WhisperMeta({
    required this.id,
    required this.day,
    required this.fromSeat,
    required this.toSeat,
    this.voided = false,
    this.delivered = false,
  });

  static String idFor({
    required int day,
    required int fromSeat,
    required int toSeat,
  }) => 'w:$day:$fromSeat:$toSeat';

  WhisperMeta copyWith({bool? voided, bool? delivered}) => WhisperMeta(
    id: id,
    day: day,
    fromSeat: fromSeat,
    toSeat: toSeat,
    voided: voided ?? this.voided,
    delivered: delivered ?? this.delivered,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhisperMeta &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          day == other.day &&
          fromSeat == other.fromSeat &&
          toSeat == other.toSeat &&
          voided == other.voided &&
          delivered == other.delivered;

  @override
  int get hashCode => Object.hash(id, day, fromSeat, toSeat, voided, delivered);

  @override
  String toString() =>
      'WhisperMeta($id, day=$day, $fromSeat->$toSeat, voided=$voided, delivered=$delivered)';
}

/// A whisper with its body attached.
///
/// **Never appears in the event log and never in `Match`.** It is assembled at
/// the moment of delivery by joining a [WhisperMeta] from the log to a body
/// held in the whisper store — `WhisperContentRecord` offline, the
/// `whisper_content` table (RLS: the two parties only) online. Keeping the two
/// apart is what makes "the graph is public, the body is not" a property of
/// where the bytes live rather than of who remembered to filter them.
class Whisper {
  final WhisperMeta meta;
  final String body;

  const Whisper({required this.meta, required this.body});

  int get fromSeat => meta.fromSeat;
  int get toSeat => meta.toSeat;
  int get day => meta.day;

  @override
  String toString() => 'Whisper(${meta.id}, ${body.length} chars)';
}

/// The rules a whisper has to satisfy, in one place so the client, the offline
/// engine and the Edge Function cannot disagree about them (doc 09 §3.3).
class WhisperLimits {
  const WhisperLimits._();

  /// Doc 09 §3.3. Enforced client-side *and* server-side; never truncated
  /// silently (H-E6).
  static const int maxLength = 120;

  /// One per living player per day, non-cumulative.
  static const int perPlayerPerDay = 1;
}
