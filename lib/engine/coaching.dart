/// «كان ممكن» — doc 13 §4.4, the post-match coaching tier.
///
/// ## Why this tier is safe when the other two are not
///
/// The match is over. Every role is public on the result screen already, so
/// there is no fact left to leak and no dwell left to compare — which is why
/// this is the one tier that may be conditioned on a player's own role, their
/// own suspicions, and their own votes, in both modes.
///
/// ## Real data only
///
/// Doc 13 §9: *"Post-match coaching generates from real data only; no generic
/// filler."* So every note here is a statement about something that happened,
/// carrying the numbers it was derived from, and when nothing crosses a
/// threshold a player gets **no notes** rather than a platitude. An empty
/// result is a correct result. Doc 09's first law does not stop applying
/// because the match ended.
///
/// ## Tone
///
/// Doc 13: *"an observation, never a scold. It states what happened and offers
/// one alternative. No score, no grade, no stars."* Nothing here computes a
/// rating, and the codes are named for the observation rather than for the
/// mistake.
library engine.coaching;

import 'bullets.dart';
import 'information/game_history.dart';
import 'models/enums.dart';
import 'models/match.dart';

/// One thing worth saying to one player about the match they just played.
///
/// [code] is stable and language-free, exactly like a trace type or an
/// achievement code: the engine has no copy in it and the l10n layer turns
/// this into a sentence. [numbers] and [seats] carry the placeholders that
/// sentence needs.
class CoachingNote {
  final int seat;
  final String code;

  /// Placeholder values, in the order the sentence uses them.
  final List<int> numbers;

  /// Seats the sentence names, in the order it names them.
  final List<int> seats;

  const CoachingNote({
    required this.seat,
    required this.code,
    this.numbers = const [],
    this.seats = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoachingNote &&
          runtimeType == other.runtimeType &&
          seat == other.seat &&
          code == other.code &&
          _eq(numbers, other.numbers) &&
          _eq(seats, other.seats);

  static bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(seat, code, Object.hashAll(numbers), Object.hashAll(seats));

  @override
  String toString() =>
      'CoachingNote(seat=$seat, code=$code, numbers=$numbers, seats=$seats)';
}

/// Every code [Coach] can emit. The l10n coverage test reads this, so a note
/// added without a sentence fails the suite rather than showing a raw code.
abstract final class CoachingCode {
  /// Suspected the same innocent on three or more nights.
  static const stuckOnInnocent = 'coach_stuck_on_innocent';

  /// Voted with the majority at least 80% of the time.
  static const conformity = 'coach_conformity';

  /// Never spent their bullet.
  static const unusedBullet = 'coach_unused_bullet';

  /// Never sent a whisper, in a match where whispers were on.
  static const neverWhispered = 'coach_never_whispered';

  /// Suspected a real Mafioso early and then stopped.
  static const abandonedRead = 'coach_abandoned_read';

  /// Bottom quartile of floor time.
  static const quiet = 'coach_quiet';

  /// Mafia who survived to the end.
  static const survivedAsMafia = 'coach_survived_as_mafia';

  static const List<String> all = [
    stuckOnInnocent,
    conformity,
    unusedBullet,
    neverWhispered,
    abandonedRead,
    quiet,
    survivedAsMafia,
  ];
}

/// Builds doc 13 §4.4's notes from the match that just finished.
abstract final class Coach {
  /// Every note for [seat], or an empty list when this player did nothing
  /// worth remarking on.
  ///
  /// Ordered by how much the observation is likely to change how somebody
  /// plays next time, sharpest first — doc 13 calls conformity *"the sharpest
  /// metric here"* and it leads for that reason.
  static List<CoachingNote> notesFor(Match match, int seat) {
    if (!match.settings.postMatchCoachingEnabled) return const [];
    if (seat < 0 || seat >= match.players.length) return const [];

    final history = buildHistory(match);
    final notes = <CoachingNote>[
      ?_conformity(match, history, seat),
      ?_stuckOnInnocent(match, history, seat),
      ?_abandonedRead(match, history, seat),
      ?_unusedBullet(match, seat),
      ?_survivedAsMafia(match, seat),
      ?_neverWhispered(match, history, seat),
      ?_quiet(match, history, seat),
    ];
    return notes;
  }

  /// Notes for every seat, keyed by seat. Seats with nothing to say are absent
  /// rather than present-and-empty.
  static Map<int, List<CoachingNote>> notesForAll(Match match) => {
        for (final p in match.players)
          if (notesFor(match, p.seat).isNotEmpty)
            p.seat: notesFor(match, p.seat),
      };

  // ── the notes ──────────────────────────────────────────────────────────

  /// «صوّت مع الأغلبية ٤ من ٤».
  ///
  /// Doc 13: *"A high rate means you are not thinking, and almost nobody
  /// realises it about themselves. Surface it as a number."* So it carries
  /// both numbers rather than a percentage — "4 of 4" is a thing a person
  /// remembers and "100%" is a thing they argue with.
  ///
  /// Abstentions are not counted either way: a player who abstained did not
  /// follow the crowd and did not stand against it.
  static CoachingNote? _conformity(Match match, GameHistory history, int seat) {
    var cast = 0;
    var withMajority = 0;

    for (final day in history.days) {
      final mine = day.votes[seat];
      if (mine == null) continue;
      cast++;

      final counts = <int, int>{};
      for (final v in day.votes.values) {
        if (v != null) counts[v] = (counts[v] ?? 0) + 1;
      }
      if (counts.isEmpty) continue;
      final top = counts.values.reduce((a, b) => a > b ? a : b);
      // "With the majority" means "on the seat the most people were on",
      // including when that was a tie — a tie is still the crowd.
      if (counts[mine] == top) withMajority++;
    }

    // Two ballots is not a habit. Three is the least that can be one.
    if (cast < 3) return null;
    if (withMajority * 5 < cast * 4) return null;

    return CoachingNote(
      seat: seat,
      code: CoachingCode.conformity,
      numbers: [withMajority, cast],
    );
  }

  /// «شكيت في يوسف ٣ ليالي وهو مواطن».
  static CoachingNote? _stuckOnInnocent(
      Match match, GameHistory history, int seat) {
    final counts = <int, int>{};
    for (final night in history.nights) {
      final target = night.suspicions[seat];
      if (target != null) counts[target] = (counts[target] ?? 0) + 1;
    }

    int? worst;
    var worstCount = 0;
    for (final entry in counts.entries) {
      if (match.players[entry.key].role.alignment == Alignment.mafia) continue;
      if (entry.value > worstCount) {
        worst = entry.key;
        worstCount = entry.value;
      }
    }

    if (worst == null || worstCount < 3) return null;
    return CoachingNote(
      seat: seat,
      code: CoachingCode.stuckOnInnocent,
      numbers: [worstCount],
      seats: [worst],
    );
  }

  /// «كنت شاكك في عمر من الليلة الأولى وهو كان مافيا — وبعدين سبته».
  ///
  /// The rarest note and the most useful one. Requires all three: an early
  /// read, that the read was right, and that they walked away from it.
  static CoachingNote? _abandonedRead(
      Match match, GameHistory history, int seat) {
    for (final night in history.nights) {
      final target = night.suspicions[seat];
      if (target == null) continue;
      if (match.players[target].role.alignment != Alignment.mafia) continue;

      // Only the first two nights count as "early" — a read formed on night
      // four is not one somebody had to trust against the room.
      if (night.nightNumber > 2) break;

      final later = history.nights
          .where((n) => n.nightNumber > night.nightNumber)
          .toList();
      if (later.isEmpty) return null;
      final stayed = later.any((n) => n.suspicions[seat] == target);
      if (stayed) return null;
      // And they have to have gone on to suspect *somebody* — a player who
      // died the next night did not abandon anything.
      final movedOn = later.any((n) => n.suspicions[seat] != null);
      if (!movedOn) return null;

      return CoachingNote(
        seat: seat,
        code: CoachingCode.abandonedRead,
        seats: [target],
      );
    }
    return null;
  }

  /// «ماستخدمتش القدرة اللي معاك».
  ///
  /// Only the two roles that still hold one can earn this — doc 14 §4.1 took
  /// the Detective's file away and §4.2 deferred the Citizen's testimony, and a
  /// note scolding a player for not using an ability the game no longer gives
  /// them would be the app inventing a fact about the match.
  static CoachingNote? _unusedBullet(Match match, int seat) {
    final kind = match.players[seat].role.bullet;
    if (kind == null) return null;
    if (!Bullets.enabled(match.settings, kind)) return null;
    if (Bullets.isSpentFor(match, seat)) return null;

    return CoachingNote(
      seat: seat,
      code: CoachingCode.unusedBullet,
      numbers: [kind.index],
    );
  }

  /// «عشت للآخر».
  static CoachingNote? _survivedAsMafia(Match match, int seat) {
    if (match.players[seat].role != Role.mafia) return null;
    if (match.players[seat].status != PlayerStatus.alive) return null;
    if (match.outcome == null) return null;
    return CoachingNote(seat: seat, code: CoachingCode.survivedAsMafia);
  }

  /// «ماهمستش ولا مرة».
  static CoachingNote? _neverWhispered(
      Match match, GameHistory history, int seat) {
    if (!match.settings.whisperEnabled) return null;
    // A player who was out after day one never had the days to use it.
    if (history.days.length < 2) return null;
    final sent = history.days
        .any((d) => d.whispers.any((w) => w.fromSeat == seat));
    if (sent) return null;
    return CoachingNote(seat: seat, code: CoachingCode.neverWhispered);
  }

  /// «انت من أقل اللي اتكلموا».
  ///
  /// Bottom quartile of floor time among players who were alive for the same
  /// discussions — comparing a seat that died on night one against one that
  /// lived to the end would be measuring the elimination, not the person.
  static CoachingNote? _quiet(Match match, GameHistory history, int seat) {
    final totals = <int, int>{};
    for (final day in history.days) {
      for (final entry in day.speakingSeconds.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    // Every living player is on the board even at zero seconds, because zero
    // is exactly the score this note is looking for.
    for (final p in match.players) {
      totals.putIfAbsent(p.seat, () => 0);
    }
    if (totals.length < 4) return null;

    final mine = totals[seat] ?? 0;
    final ordered = totals.values.toList()..sort();
    final cutoff = ordered[(ordered.length - 1) ~/ 4];
    if (mine > cutoff) return null;

    // Only worth saying when there was a table to be quiet at.
    final spoke = ordered.where((s) => s > 0).length;
    if (spoke < 3) return null;

    return CoachingNote(seat: seat, code: CoachingCode.quiet, numbers: [mine]);
  }
}
