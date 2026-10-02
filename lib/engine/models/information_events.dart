// The Information Engine's events.
//
// A `part` of `timeline_event.dart` rather than a library of its own, because
// [TimelineEvent] is sealed: the exhaustive switch in `MatchCodec` is what
// makes "adding an event without teaching storage about it" a compile error,
// and a sealed hierarchy can only be extended from inside its own library.
//
// Everything the three layers need is derived from this log — there is no
// second store of game facts to keep in step with it. `GameHistory` is a pure
// projection of these events, which is what makes a resumed match produce the
// same traces and confrontations as the match that was interrupted.
//
// One thing is deliberately absent: whisper *bodies*. The log is the public
// record of the match and is written to history in full, so a body in here
// would be readable by anyone who opened the analytics screen. Only the graph
// lives here (doc 09 §5, "storage split").

part of 'timeline_event.dart';

/// An actor took their night turn and chose nobody.
///
/// The Citizen case is the one the spec names (N10, «رفض يسجّل شكه»), and it is
/// load-bearing: it feeds `T6` and `C10`. The other three roles reach it only
/// through a timer expiry online (doc 10 §8.2 — "no protection", "no
/// investigation"), which is why [kind] is recorded rather than assumed.
class NightActionSkipped extends TimelineEvent {
  final int actorSeat;
  final NightActionKind kind;

  const NightActionSkipped({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.actorSeat,
    required this.kind,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NightActionSkipped &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          actorSeat == other.actorSeat &&
          kind == other.kind;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ actorSeat.hashCode ^ kind.hashCode;

  @override
  String toString() =>
      'NightActionSkipped(at=$at, phaseRef=$phaseRef, actorSeat=$actorSeat, kind=$kind)';
}

/// The trace that was published on a given morning.
///
/// Recorded rather than recomputed. `selectTrace` reads the history *up to*
/// that night, and the history grows; a match reopened from storage three days
/// later and asked "what did we publish on morning 2" must get back the
/// sentence the table actually read, not the sentence the generator would
/// choose today. It is also what the no-repeat rule and the novelty factor
/// read, so both survive a force-quit.
///
/// [subjectSeat] and [targetSeat] are set for `T1` only — the one trace the
/// spec permits to name anyone. [count] carries the number in `T3`/`T4`.
class TracePublished extends TimelineEvent {
  final TraceType type;
  final int? subjectSeat;
  final int? targetSeat;
  final int? count;

  const TracePublished({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.type,
    this.subjectSeat,
    this.targetSeat,
    this.count,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TracePublished &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          type == other.type &&
          subjectSeat == other.subjectSeat &&
          targetSeat == other.targetSeat &&
          count == other.count;

  @override
  int get hashCode =>
      Object.hash(at, phaseRef, type, subjectSeat, targetSeat, count);

  @override
  String toString() =>
      'TracePublished(at=$at, phaseRef=$phaseRef, type=$type, subjectSeat=$subjectSeat, '
      'targetSeat=$targetSeat, count=$count)';
}

/// One public accusation from the Day-1 «اسم واحد» round.
///
/// Public by construction — it is said out loud to the table — which is what
/// makes it usable as evidence by `C1` («قلت إنك شاكك في…، وصوّت لـ…»). A night
/// suspicion could never be used that way: nobody heard it.
class OpeningAccusationCast extends TimelineEvent {
  final int actorSeat;
  final int targetSeat;

  const OpeningAccusationCast({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.actorSeat,
    required this.targetSeat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpeningAccusationCast &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          actorSeat == other.actorSeat &&
          targetSeat == other.targetSeat;

  @override
  int get hashCode =>
      at.hashCode ^
      phaseRef.hashCode ^
      actorSeat.hashCode ^
      targetSeat.hashCode;

  @override
  String toString() =>
      'OpeningAccusationCast(at=$at, phaseRef=$phaseRef, actorSeat=$actorSeat, '
      'targetSeat=$targetSeat)';
}

/// The day's one confrontation was put to a player.
///
/// [evidenceSeat] is the other player the observation refers to — the `{x}` in
/// «انت و{x} صوّتوا نفس التصويت» — and null for the types that name only the
/// confronted player. [evidenceDay] is the day the behaviour happened on,
/// which is what the recency factor reads.
class ConfrontationIssued extends TimelineEvent {
  final int targetSeat;
  final ConfrontationType type;
  final int? evidenceSeat;
  final int? evidenceSeat2;
  final int? evidenceDay;
  final int? count;

  const ConfrontationIssued({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.targetSeat,
    required this.type,
    this.evidenceSeat,
    this.evidenceSeat2,
    this.evidenceDay,
    this.count,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfrontationIssued &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          targetSeat == other.targetSeat &&
          type == other.type &&
          evidenceSeat == other.evidenceSeat &&
          evidenceSeat2 == other.evidenceSeat2 &&
          evidenceDay == other.evidenceDay &&
          count == other.count;

  @override
  int get hashCode => Object.hash(
    at,
    phaseRef,
    targetSeat,
    type,
    evidenceSeat,
    evidenceSeat2,
    evidenceDay,
    count,
  );

  @override
  String toString() =>
      'ConfrontationIssued(at=$at, phaseRef=$phaseRef, targetSeat=$targetSeat, type=$type, '
      'evidenceSeat=$evidenceSeat, evidenceSeat2=$evidenceSeat2, '
      'evidenceDay=$evidenceDay, count=$count)';
}

/// The confronted player's window closed.
///
/// [silent] records that they said nothing at all — a disconnect online, or a
/// player who let the timer run out at the table. Doc 11 C-E5: *"Silence is
/// recorded and is itself information."*
class ConfrontationAnswered extends TimelineEvent {
  final int targetSeat;
  final bool silent;

  const ConfrontationAnswered({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.targetSeat,
    required this.silent,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfrontationAnswered &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          targetSeat == other.targetSeat &&
          silent == other.silent;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ targetSeat.hashCode ^ silent.hashCode;

  @override
  String toString() =>
      'ConfrontationAnswered(at=$at, phaseRef=$phaseRef, targetSeat=$targetSeat, silent=$silent)';
}

/// How long a player held the floor on a given day.
///
/// The only source for `C6` («انت أقل واحد اتكلم»). Written once per speaker
/// per day by the discussion screen; a player who never got the floor has no
/// event and counts as zero.
class SpeakingRecorded extends TimelineEvent {
  final int seat;
  final int seconds;

  const SpeakingRecorded({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.seat,
    required this.seconds,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeakingRecorded &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          seat == other.seat &&
          seconds == other.seconds;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ seat.hashCode ^ seconds.hashCode;

  @override
  String toString() =>
      'SpeakingRecorded(at=$at, phaseRef=$phaseRef, seat=$seat, seconds=$seconds)';
}

/// A whisper was sent. **The graph, never the body.**
///
/// [id] is the handle the body is stored under, in a store this log cannot
/// reach. Deterministic — `w:<day>:<from>:<to>` — so the pairing survives a
/// round trip through storage without a generated id, and so the one-per-day
/// rule makes a duplicate impossible by construction.
class WhisperSent extends TimelineEvent {
  final String id;
  final int fromSeat;
  final int toSeat;

  const WhisperSent({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.id,
    required this.fromSeat,
    required this.toSeat,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhisperSent &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          id == other.id &&
          fromSeat == other.fromSeat &&
          toSeat == other.toSeat;

  @override
  int get hashCode => Object.hash(at, phaseRef, id, fromSeat, toSeat);

  @override
  String toString() =>
      'WhisperSent(at=$at, phaseRef=$phaseRef, id=$id, fromSeat=$fromSeat, toSeat=$toSeat)';
}

/// The recipient opened a whisper on their own turn.
class WhisperDelivered extends TimelineEvent {
  final String id;

  const WhisperDelivered({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.id,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhisperDelivered &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          id == other.id;

  @override
  int get hashCode => at.hashCode ^ phaseRef.hashCode ^ id.hashCode;

  @override
  String toString() => 'WhisperDelivered(at=$at, phaseRef=$phaseRef, id=$id)';
}

/// The recipient died before reading. The sender is told «الهمسة ماوصلتش».
class WhisperVoided extends TimelineEvent {
  final String id;

  const WhisperVoided({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.id,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhisperVoided &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          id == other.id;

  @override
  int get hashCode => at.hashCode ^ phaseRef.hashCode ^ id.hashCode;

  @override
  String toString() => 'WhisperVoided(at=$at, phaseRef=$phaseRef, id=$id)';
}

/// A player spent «الطلقة الواحدة» (doc 13 §2).
///
/// Logged the moment it is armed, during that player's own night turn, and
/// never again — the whole mechanic is that there is no second one. Everything
/// downstream reads it back from here rather than from a field on [Player]:
/// a match rebuilt from storage after a force-quit has to know the bullet is
/// gone, and the log is the only thing that survives.
///
/// [kind] is recorded rather than derived from the actor's role. The two agree
/// today by construction, but the log is the public record of the match and a
/// reader of it is not entitled to look up the actor's role to find out what
/// they did — and after the match, when the roles *are* public, an explicit
/// field is what lets the timeline say «فتح الملف» rather than reconstruct it.
///
/// ## Why this is not a leak in the log
///
/// It plainly is one, read literally: `BulletSpent(actorSeat: 3, kind: openFile)`
/// says seat 3 is the Detective. That is fine, and it is fine for the same
/// reason the event exists — every bullet in doc 13 is *public by design*. The
/// quiet night publishes an absence the whole table sees, the opened file is a
/// public attributed announcement, the testimony carries the player's own name,
/// and the self-protection is the only one that is private, which is why the
/// morning never mentions it and no reader of the log gets to see it before the
/// match ends. Nothing renders this event mid-match except the announcements
/// the player themselves chose to make.
class BulletSpent extends TimelineEvent {
  final int actorSeat;
  final BulletKind kind;

  const BulletSpent({
    required DateTime at,
    required PhaseRef phaseRef,
    required this.actorSeat,
    required this.kind,
  }) : super(at: at, phaseRef: phaseRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BulletSpent &&
          runtimeType == other.runtimeType &&
          at == other.at &&
          phaseRef == other.phaseRef &&
          actorSeat == other.actorSeat &&
          kind == other.kind;

  @override
  int get hashCode =>
      at.hashCode ^ phaseRef.hashCode ^ actorSeat.hashCode ^ kind.hashCode;

  @override
  String toString() =>
      'BulletSpent(at=$at, phaseRef=$phaseRef, actorSeat=$actorSeat, kind=$kind)';
}
