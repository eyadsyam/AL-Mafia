/// The append-only history both generators read from (doc 09 §5).
///
/// Built by [buildHistory] as a **pure projection of `Match.eventLog`**. See
/// the header of `records.dart` for why it is derived rather than stored.
///
/// One consequence worth stating plainly: `buildHistory` is O(events), and it
/// runs once per morning and once per day — twice per full cycle, on a log that
/// tops out in the low hundreds of events for a long match. Caching it would
/// buy nothing measurable and would reintroduce exactly the staleness the
/// projection exists to make impossible.
library engine.information.game_history;

import '../models/enums.dart';
import '../models/information_enums.dart';
import '../models/match.dart';
import '../models/timeline_event.dart';
import 'records.dart';

/// Everything the Trace and Confrontation generators are allowed to know.
class GameHistory {
  /// One entry per night that has begun, in order. Index `n - 1` is night `n`.
  final List<NightRecord> nights;

  /// One entry per day that has begun, in order.
  final List<DayRecord> days;

  /// Seat → name, for rendering. Carries no role.
  final Map<int, String> names;

  /// Seats still alive.
  final Set<int> alive;

  const GameHistory({
    required this.nights,
    required this.days,
    required this.names,
    required this.alive,
  });

  static const GameHistory empty = GameHistory(
    nights: [],
    days: [],
    names: {},
    alive: {},
  );

  NightRecord? nightAt(int number) =>
      number >= 1 && number <= nights.length ? nights[number - 1] : null;

  DayRecord? dayAt(int number) =>
      number >= 1 && number <= days.length ? days[number - 1] : null;

  /// Nights that have been resolved, oldest first. The night currently being
  /// played is excluded, because half its actions have not happened yet.
  List<NightRecord> get resolvedNights =>
      nights.where((n) => n.resolved).toList();

  /// Who was confronted most recently, or null. The generator's back-to-back
  /// filter reads this (doc 09 §2.4).
  int? get lastConfrontedPlayer {
    for (final day in days.reversed) {
      final c = day.confrontation;
      if (c != null) return c.targetSeat;
    }
    return null;
  }

  /// The most recent confrontation's type, for the same filter.
  ConfrontationType? get lastConfrontationType {
    for (final day in days.reversed) {
      final c = day.confrontation;
      if (c != null) return c.type;
    }
    return null;
  }

  /// How many times [seat] has already been made to explain themselves.
  ///
  /// The fairness cap reads this, and it is not optional: *"Without it, one
  /// unlucky player gets confronted every single day and stops enjoying the
  /// game"* (doc 09 §2.4).
  int confrontationCountFor(int seat) => days
      .where((d) => d.confrontation?.targetSeat == seat)
      .length;

  /// Every seat that anyone has ever suspected at night, across the match.
  ///
  /// Feeds `T5` and `C4` («محدش شك فيك ولا مرة»). Public accusations from the
  /// Day-1 opener count too — being named out loud is at least as much "having
  /// been suspected" as a private note is, and a player who was accused to
  /// their face on Day 1 is plainly not the table's blind spot.
  Set<int> get everSuspected => {
        for (final night in nights) ...night.recordedSuspicions.values,
        for (final day in days) ...day.openingAccusations.values,
      };

  /// Total floor time per seat across the whole match.
  Map<int, int> get totalSpeakingSeconds {
    final totals = <int, int>{};
    for (final day in days) {
      day.speakingSeconds.forEach((seat, seconds) {
        totals[seat] = (totals[seat] ?? 0) + seconds;
      });
    }
    return totals;
  }

  /// Every whisper edge in the match, oldest first.
  List<WhisperMeta> get allWhispers =>
      [for (final day in days) ...day.whispers];

  @override
  String toString() =>
      'GameHistory(nights=${nights.length}, days=${days.length}, alive=${alive.length})';
}

/// Projects [match] into the record model. Pure, total, and never throws.
GameHistory buildHistory(Match match) {
  final log = match.eventLog;

  // ---------------------------------------------------------------------------
  // Nights
  // ---------------------------------------------------------------------------
  final nightNumbers = <int>{};
  for (final e in log) {
    if (e is NightOpened) nightNumbers.add(e.phaseRef.number);
  }

  final nights = <NightRecord>[];
  for (final n in nightNumbers.toList()..sort()) {
    final suspicions = <int, int?>{};
    final reasons = <int, String?>{};
    int? doctorProtect;
    int? detectiveCheck;
    int? mafiaTarget;
    int? victim;
    int? savedSeat;
    var resolved = false;
    TraceType? trace;

    for (final e in log) {
      if (e.phaseRef.number != n) continue;
      switch (e) {
        case SuspectCast():
          if (e.phaseRef.phase != GamePhase.night) break;
          suspicions[e.actorSeat] = e.targetSeat;
          reasons[e.actorSeat] = e.reason;
        case NightActionSkipped():
          if (e.phaseRef.phase != GamePhase.night) break;
          if (e.kind == NightActionKind.suspect) {
            suspicions[e.actorSeat] = null;
            reasons[e.actorSeat] = null;
          }
        case ProtectCast():
          doctorProtect = e.targetSeat;
        case InvestigateCast():
          detectiveCheck = e.targetSeat;
        case MafiaVoteCast():
          // Not the agreed target — one vote among possibly several. The
          // agreement is what `NightResolved` records, and `mafiaTargetSeat`
          // reads it from there. Kept only so that a night interrupted before
          // resolution still shows *a* target rather than nothing.
          mafiaTarget ??= e.targetSeat;
        case NightResolved():
          victim = e.victimSeat;
          savedSeat = e.savedSeat;
          resolved = true;
        case TracePublished():
          trace = e.type;
        default:
          break;
      }
    }

    nights.add(NightRecord(
      nightNumber: n,
      suspicions: suspicions,
      reasons: reasons,
      mafiaTarget: mafiaTarget,
      doctorProtect: doctorProtect,
      detectiveCheck: detectiveCheck,
      victim: victim,
      saveOccurred: savedSeat != null,
      savedSeat: savedSeat,
      revealedTrace: trace,
      resolved: resolved,
    ));
  }

  // ---------------------------------------------------------------------------
  // Days
  //
  // A day exists from the moment its morning is announced. That matters for the
  // confrontation generator, which runs *inside* the day it is building a
  // record for and must not find itself missing.
  // ---------------------------------------------------------------------------
  final dayNumbers = <int>{};
  for (final e in log) {
    if (e is MorningAnnounced ||
        e is OpeningAccusationCast ||
        e is ConfrontationIssued ||
        e is DiscussionRound ||
        e is SpeakingRecorded ||
        e is WhisperSent ||
        e is VoteCast) {
      dayNumbers.add(e.phaseRef.number);
    }
  }

  final days = <DayRecord>[];
  for (final d in dayNumbers.toList()..sort()) {
    final opening = <int, int>{};
    final byRound = <int, Map<int, int?>>{};
    final speaking = <int, int>{};
    final whispers = <String, WhisperMeta>{};
    Confrontation? confrontation;
    var silent = false;
    int? eliminated;

    for (final e in log) {
      if (e.phaseRef.number != d) continue;
      switch (e) {
        case OpeningAccusationCast():
          opening[e.actorSeat] = e.targetSeat;
        case ConfrontationIssued():
          confrontation = Confrontation(
            type: e.type,
            targetSeat: e.targetSeat,
            evidenceSeat: e.evidenceSeat,
            evidenceDay: e.evidenceDay,
            count: e.count,
          );
        case ConfrontationAnswered():
          silent = e.silent;
        case SpeakingRecorded():
          speaking[e.seat] = (speaking[e.seat] ?? 0) + e.seconds;
        case VoteCast():
          (byRound[e.round] ??= <int, int?>{})[e.voterSeat] = e.targetSeat;
        case DayResolved():
          eliminated = e.eliminatedSeat;
        case WhisperSent():
          whispers[e.id] = WhisperMeta(
            id: e.id,
            day: d,
            fromSeat: e.fromSeat,
            toSeat: e.toSeat,
          );
        case WhisperDelivered():
          final existing = whispers[e.id];
          if (existing != null) {
            whispers[e.id] = existing.copyWith(delivered: true);
          }
        case WhisperVoided():
          final existing = whispers[e.id];
          if (existing != null) {
            whispers[e.id] = existing.copyWith(voided: true);
          }
        default:
          break;
      }
    }

    final lastRound = byRound.keys.isEmpty
        ? 0
        : byRound.keys.reduce((a, b) => a > b ? a : b);

    days.add(DayRecord(
      dayNumber: d,
      openingAccusations: opening,
      confrontation: confrontation,
      confrontationSilent: silent,
      votes: byRound[lastRound] ?? const {},
      votesByRound: byRound,
      eliminated: eliminated,
      speakingSeconds: speaking,
      whispers: whispers.values.toList(),
    ));
  }

  return GameHistory(
    nights: nights,
    days: days,
    names: {for (final p in match.players) p.seat: p.name},
    alive: {
      for (final p in match.players)
        if (p.status == PlayerStatus.alive) p.seat,
    },
  );
}
