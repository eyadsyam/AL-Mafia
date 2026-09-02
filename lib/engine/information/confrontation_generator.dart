/// Layer 2 — the Confrontation (doc 09 §2).
///
/// One player per day, named out loud, given one true observation about their
/// own behaviour and a timed window to answer it. **Exactly one per day, never
/// two** (§2.5): *"If the app interrupts constantly it stops being a Game
/// Master and becomes an interrogator."*
///
/// # Three of the eleven types are not shipped, and why
///
/// `C3` (الثبات), `C9` (التقلّب) and `C10` (الامتناع) all read a **living**
/// player's *night suspicion record* and quote it back to the table by name.
/// Only Citizens record suspicions in this game — the Mafia vote, the Doctor
/// protects, the Detective investigates — so any of those three firing on a
/// player announces that the player is a Citizen. That is the exact inference
/// `05-zero-leakage-spec.md` exists to prevent, and prime directive 1 says such
/// a change does not ship.
///
/// They are implemented and tested below, and excluded from
/// [ConfrontationCatalogue.shipped]. Flipping them on is a one-line change once
/// the wording is settled with the spec's author — see
/// [ConfrontationType.namesANightSuspicion].
///
/// `C7` («الميت يتكلم») reads a suspicion too, but the suspect is the *dead*
/// player, and doc 09 §1.4 already publishes exactly that fact as `T1`. It
/// ships.
///
/// `C2` (الانقلاب) needs a record of a player *defending* someone, and this game
/// has no defence action to record. Doc 09 §2.5 lists a "Defense round" in the
/// day structure that the app does not implement. Its finder returns nothing
/// and says so, rather than guessing that "did not vote for X" means "defended
/// X" — which would be the app inventing a fact.
library engine.information.confrontation_generator;

import '../models/enums.dart';
import '../models/information_enums.dart';
import '../models/match_settings.dart';
import '../models/player.dart';
import '../seed.dart';
import 'game_history.dart';
import 'records.dart';

/// Which types are eligible to be generated at all.
class ConfrontationCatalogue {
  const ConfrontationCatalogue._();

  /// Everything that may be published without telling the table somebody's
  /// role. See the library doc for the three that are held back.
  static List<ConfrontationType> get shipped => [
        for (final t in ConfrontationType.values)
          if (!t.namesANightSuspicion && t != ConfrontationType.c2) t,
      ];

  /// The shipped set, minus whatever this match's settings switch off.
  static List<ConfrontationType> enabledFor(MatchSettings settings) => [
        for (final t in shipped)
          if (!(t.isGated && !settings.survivorConfrontationEnabled) &&
              !(t.requiresWhispers && !settings.whisperEnabled))
            t,
      ];
}

extension ConfrontationLeakage on ConfrontationType {
  /// Whether publishing this type would tell the table that the named, living
  /// player recorded a night suspicion — and therefore that they are a Citizen.
  bool get namesANightSuspicion =>
      this == ConfrontationType.c3 ||
      this == ConfrontationType.c9 ||
      this == ConfrontationType.c10;
}

/// A candidate, with the numbers §2.4 multiplies together.
class ConfrontationCandidate {
  final Confrontation confrontation;

  ConfrontationCandidate(this.confrontation);

  double score = 0;

  ConfrontationType get type => confrontation.type;
  int get target => confrontation.targetSeat;
  int? get evidenceDay => confrontation.evidenceDay;
}

/// Chooses the day's one confrontation, or null for "nothing qualifies".
///
/// Returning null is a normal outcome, not a failure: C-E2 — *"Silently
/// skipped. Day proceeds to free discussion. **Never fabricate.**"*
Confrontation? selectConfrontation({
  required GameHistory history,
  required List<Player> players,
  required int dayNumber,
  required int matchSeed,
  required MatchSettings settings,
}) {
  // Day 1 runs the «اسم واحد» opener instead — there is no behavioural history
  // on day 1, so a confrontation could only be invented (C-E1, §2.2).
  if (dayNumber <= 1) return null;

  final alive = {
    for (final p in players)
      if (p.status == PlayerStatus.alive) p.seat,
  };

  final candidates = <ConfrontationCandidate>[];
  for (final type in ConfrontationCatalogue.enabledFor(settings)) {
    candidates.addAll(findConfrontations(
      type: type,
      history: history,
      alive: alive,
      dayNumber: dayNumber,
    ));
  }

  // Hard filters (§2.4).
  candidates.removeWhere((c) =>
      !alive.contains(c.target) ||
      c.target == history.lastConfrontedPlayer ||
      c.type == history.lastConfrontationType);

  if (candidates.isEmpty) return null;

  // The fairness cap, which §2.4 calls not optional: *"no player may be
  // confronted more than twice per match unless there are no other
  // candidates."* Expressed as a partition rather than as a multiplier,
  // because a multiplier only makes a third confrontation unlikely and the
  // spec asks for it to be impossible while an alternative exists.
  final within = candidates
      .where((c) => history.confrontationCountFor(c.target) < 2)
      .toList();
  final pool = within.isNotEmpty ? within : candidates;

  for (final c in pool) {
    c.score = c.type.severity *
        recencyBoost(c.evidenceDay, dayNumber) *
        fairnessFactor(history, c.target);
  }

  // Total order before the tie-break, for the reason given in
  // `trace_generator.dart`: Dart's sort is not stable, so equal scores left in
  // encounter order are in an arbitrary order, and the tie-break would then
  // draw from a set that differs between devices.
  pool.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    return a.target.compareTo(b.target);
  });

  final best = pool.first.score;
  final top = pool.where((c) => c.score >= best - 0.01).toList();
  if (top.length == 1) return top.first.confrontation;

  final index = tieBreakIndex(
    deriveSeed(matchSeed, SeedSalt.confrontation, dayNumber),
    top.length,
  );
  return top[index].confrontation;
}

/// Fresher evidence scores higher (§2.4).
///
/// Flat for anything from today or yesterday — a table remembers both equally
/// well — then falling by 0.15 a day to a floor of 0.5, so a five-day-old
/// contradiction can still win if nothing newer is as damning.
double recencyBoost(int? evidenceDay, int dayNumber) {
  if (evidenceDay == null) return 1.0;
  final age = dayNumber - evidenceDay;
  if (age <= 1) return 1.0;
  final boost = 1.0 - 0.15 * (age - 1);
  return boost < 0.5 ? 0.5 : boost;
}

/// 1.0 for a player who has not been confronted, 0.5 after once, 0.25 beyond.
///
/// The 0.25 tier is only ever reached when the cap partition in
/// [selectConfrontation] had to fall back — otherwise those candidates are not
/// in the pool at all.
double fairnessFactor(GameHistory history, int seat) {
  final count = history.confrontationCountFor(seat);
  if (count == 0) return 1.0;
  if (count == 1) return 0.5;
  return 0.25;
}

// ---------------------------------------------------------------------------
// The catalogue. One finder per type, each pure and each individually testable.
// ---------------------------------------------------------------------------

/// Every player [type] currently has evidence against. May be empty.
List<ConfrontationCandidate> findConfrontations({
  required ConfrontationType type,
  required GameHistory history,
  required Set<int> alive,
  required int dayNumber,
}) {
  switch (type) {
    // ─── C1 تناقض التصويت ───────────────────────────────────────────────
    // Named X out loud in the Day-1 opener, then put a ballot against Y.
    // Both halves are public: the opener was said to the table and the vote
    // was counted in front of it, so quoting either back reveals nothing that
    // was not already heard.
    case ConfrontationType.c1:
      final out = <ConfrontationCandidate>[];
      final opener = history.dayAt(1)?.openingAccusations ?? const {};
      for (final entry in opener.entries) {
        final seat = entry.key;
        final accused = entry.value;
        if (!alive.contains(seat)) continue;
        for (var d = dayNumber - 1; d >= 1; d--) {
          final voted = history.dayAt(d)?.votes[seat];
          if (voted == null || voted == accused) continue;
          out.add(ConfrontationCandidate(Confrontation(
            type: ConfrontationType.c1,
            targetSeat: seat,
            evidenceSeat: accused,
            evidenceSeat2: voted,
            evidenceDay: d,
          )));
          break; // Most recent contradiction only — one per player.
        }
      }
      return out;

    // ─── C2 الانقلاب ────────────────────────────────────────────────────
    // Needs a defence record. There is no defence action in this game, so
    // there is nothing true to say. See the library doc.
    case ConfrontationType.c2:
      return const [];

    // ─── C3 الثبات (held back — see the library doc) ─────────────────────
    case ConfrontationType.c3:
      final out = <ConfrontationCandidate>[];
      final nights = history.resolvedNights;
      if (nights.length < 3) return out;
      final last3 = nights.sublist(nights.length - 3);
      for (final seat in alive) {
        final targets = [
          for (final n in last3) n.recordedSuspicions[seat],
        ];
        if (targets.any((t) => t == null)) continue;
        if (targets.toSet().length != 1) continue;
        out.add(ConfrontationCandidate(Confrontation(
          type: ConfrontationType.c3,
          targetSeat: seat,
          evidenceSeat: targets.first,
          evidenceDay: last3.last.nightNumber,
          count: 3,
        )));
      }
      return out;

    // ─── C4 الظل ────────────────────────────────────────────────────────
    // Asserts a negative about the confronted player only — that nobody has
    // named them — and nothing about who did or did not name anyone else.
    case ConfrontationType.c4:
      if (dayNumber - 1 < 3) return const [];
      final suspected = history.everSuspected;
      return [
        for (final seat in alive)
          if (!suspected.contains(seat))
            ConfrontationCandidate(Confrontation(
              type: ConfrontationType.c4,
              targetSeat: seat,
              evidenceDay: dayNumber - 1,
            )),
      ];

    // ─── C5 التوأم ──────────────────────────────────────────────────────
    // Votes are public. Doc 10 §9.1 names this as the mechanic that makes
    // colluders visible without pretending collusion can be prevented.
    case ConfrontationType.c5:
      final out = <ConfrontationCandidate>[];
      final pairs = <String, int>{};
      var lastAgreement = <String, int>{};
      for (var d = 1; d < dayNumber; d++) {
        final votes = history.dayAt(d)?.votes ?? const <int, int?>{};
        for (final a in alive) {
          for (final b in alive) {
            if (b <= a) continue;
            final va = votes[a];
            final vb = votes[b];
            if (va == null || vb == null || va != vb) continue;
            final key = '$a:$b';
            pairs[key] = (pairs[key] ?? 0) + 1;
            lastAgreement[key] = d;
          }
        }
      }
      pairs.forEach((key, count) {
        if (count < 3) return;
        final parts = key.split(':');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        for (final (self, other) in [(a, b), (b, a)]) {
          out.add(ConfrontationCandidate(Confrontation(
            type: ConfrontationType.c5,
            targetSeat: self,
            evidenceSeat: other,
            evidenceDay: lastAgreement[key],
            count: count,
          )));
        }
      });
      return out;

    // ─── C6 الصامت ──────────────────────────────────────────────────────
    case ConfrontationType.c6:
      if (dayNumber - 1 < 2) return const [];
      final totals = history.totalSpeakingSeconds;
      // A player with no recorded floor time at all has spoken for zero
      // seconds, which is the strongest possible case for this type — so the
      // map is completed over the living rather than read as-is.
      final full = {for (final seat in alive) seat: totals[seat] ?? 0};
      if (full.isEmpty) return const [];
      final lowest = full.values.reduce((a, b) => a < b ? a : b);
      // Only fires when there is a *single* quietest player. "You are the one
      // who has talked least" is not true of a three-way tie at zero, and the
      // app does not say things that are not true.
      final quietest = full.entries.where((e) => e.value == lowest).toList();
      if (quietest.length != 1) return const [];
      return [
        ConfrontationCandidate(Confrontation(
          type: ConfrontationType.c6,
          targetSeat: quietest.first.key,
          evidenceDay: dayNumber - 1,
          count: lowest,
        )),
      ];

    // ─── C7 الميت يتكلم ─────────────────────────────────────────────────
    // The same fact `T1` published this morning, put to the person it names.
    // About a dead player's note, which doc 09 §1.4 has already decided is
    // publishable.
    case ConfrontationType.c7:
      final nights = history.resolvedNights;
      if (nights.isEmpty) return const [];
      final last = nights.last;
      final victim = last.victim;
      if (victim == null) return const [];
      final named = last.recordedSuspicions[victim];
      if (named == null || !alive.contains(named)) return const [];
      return [
        ConfrontationCandidate(Confrontation(
          type: ConfrontationType.c7,
          targetSeat: named,
          evidenceSeat: victim,
          evidenceDay: last.nightNumber,
        )),
      ];

    // ─── C8 الهمّاس ─────────────────────────────────────────────────────
    // The whisper *graph* is public by design (doc 09 §3.1). The body is not,
    // and nothing here reads one.
    case ConfrontationType.c8:
      final out = <ConfrontationCandidate>[];
      final byPair = <String, List<int>>{};
      for (final w in history.allWhispers) {
        if (!alive.contains(w.fromSeat)) continue;
        (byPair['${w.fromSeat}:${w.toSeat}'] ??= []).add(w.day);
      }
      byPair.forEach((key, days) {
        days.sort();
        var run = 1;
        var bestRun = 1;
        var bestEnd = days.first;
        for (var i = 1; i < days.length; i++) {
          if (days[i] == days[i - 1] + 1) {
            run++;
          } else if (days[i] != days[i - 1]) {
            run = 1;
          }
          if (run > bestRun) {
            bestRun = run;
            bestEnd = days[i];
          }
        }
        if (bestRun < 2) return;
        final parts = key.split(':');
        out.add(ConfrontationCandidate(Confrontation(
          type: ConfrontationType.c8,
          targetSeat: int.parse(parts[0]),
          evidenceSeat: int.parse(parts[1]),
          evidenceDay: bestEnd,
          count: bestRun,
        )));
      });
      return out;

    // ─── C9 التقلّب (held back — see the library doc) ────────────────────
    case ConfrontationType.c9:
      final out = <ConfrontationCandidate>[];
      final nights = history.resolvedNights;
      if (nights.length < 4) return out;
      final window = nights.sublist(nights.length - 4);
      for (final seat in alive) {
        var changes = 0;
        for (var i = 1; i < window.length; i++) {
          final before = window[i - 1].recordedSuspicions[seat];
          final now = window[i].recordedSuspicions[seat];
          if (before != null && now != null && before != now) changes++;
        }
        if (changes < 3) continue;
        out.add(ConfrontationCandidate(Confrontation(
          type: ConfrontationType.c9,
          targetSeat: seat,
          evidenceDay: window.last.nightNumber,
          count: changes,
        )));
      }
      return out;

    // ─── C10 الامتناع (held back — see the library doc) ──────────────────
    case ConfrontationType.c10:
      final out = <ConfrontationCandidate>[];
      final counts = <int, int>{};
      var lastNight = <int, int>{};
      for (final n in history.resolvedNights) {
        for (final seat in n.skipped) {
          counts[seat] = (counts[seat] ?? 0) + 1;
          lastNight[seat] = n.nightNumber;
        }
      }
      counts.forEach((seat, count) {
        if (count < 2 || !alive.contains(seat)) return;
        out.add(ConfrontationCandidate(Confrontation(
          type: ConfrontationType.c10,
          targetSeat: seat,
          evidenceDay: lastNight[seat],
          count: count,
        )));
      });
      return out;

    // ─── C11 الناجي (opt-in, off by default) ────────────────────────────
    // Gated in [ConfrontationCatalogue.enabledFor], so reaching this branch at
    // all means the host deliberately switched it on.
    case ConfrontationType.c11:
      final out = <ConfrontationCandidate>[];
      for (final n in history.resolvedNights) {
        // «≥1 day later» — the save must not be this morning's news.
        if (n.nightNumber >= dayNumber) continue;
        final saved = n.savedSeat;
        if (saved == null || !alive.contains(saved)) continue;
        out.add(ConfrontationCandidate(Confrontation(
          type: ConfrontationType.c11,
          targetSeat: saved,
          evidenceDay: n.nightNumber,
        )));
      }
      return out;
  }
}
