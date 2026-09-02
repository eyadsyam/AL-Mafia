/// Layer 1 — the Trace (doc 09 §1).
///
/// Every morning, one true forensic observation about the night that just
/// passed. Pure, deterministic, and bound by the design law at the top of doc
/// 09: **the app never invents a fact.** Every branch below reads something a
/// player actually did; when none of them can, the answer is [TraceType.t0] and
/// the app says so rather than reaching for filler.
///
/// # Only T1 names anybody
///
/// Doc 09 §1.4's naming rule: *"only `T1` names players, and only because the
/// victim is already dead and the target is publicly forced to respond. Every
/// other trace is aggregate. Naming more would collapse the deduction into
/// arithmetic."* [TraceResult.targetSeat] is therefore null for every type but
/// `T1`, and the rendering layer has nothing to name even if it wanted to.
library engine.information.trace_generator;

import '../models/enums.dart';
import '../models/information_enums.dart';
import '../models/player.dart';
import '../seed.dart';
import 'records.dart';

/// What the morning screen publishes.
class TraceResult {
  final TraceType type;

  /// `T1` only: the player who died and whose note is being read out.
  final int? subjectSeat;

  /// `T1` only: who that note named.
  final int? targetSeat;

  /// The «٣ لاعبين» in `T3`, the «٢ غيّر شكه» in `T4`, and so on. Null for the
  /// types whose sentence carries no number.
  final int? count;

  const TraceResult({
    required this.type,
    this.subjectSeat,
    this.targetSeat,
    this.count,
  });

  /// «الليلة دي ماسابتش أي أثر» — nothing was eligible.
  static const TraceResult none = TraceResult(type: TraceType.t0);

  bool get isNone => type == TraceType.t0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TraceResult &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          subjectSeat == other.subjectSeat &&
          targetSeat == other.targetSeat &&
          count == other.count;

  @override
  int get hashCode => Object.hash(type, subjectSeat, targetSeat, count);

  @override
  String toString() =>
      'TraceResult(${type.name}, subject=$subjectSeat, target=$targetSeat, count=$count)';
}

/// One eligible trace, with the numbers that decide whether it gets published.
class TraceCandidate {
  final TraceResult result;

  /// Doc 09 §1.5: *"e.g. `T3` with n=4 > `T3` with n=2"*. 1.0 is the baseline;
  /// a trace that covers more of the table scores above it.
  final double informationValue;

  double score = 0;

  TraceCandidate(this.result, {this.informationValue = 1.0});

  TraceType get type => result.type;
}

/// Chooses the morning's trace. Pure; same inputs, same output, every device.
///
/// [night] is the night just resolved. [history] is every **earlier** night,
/// oldest first — the current night must not appear in it, or `T4`'s
/// "changed since last night" would compare a night with itself and the
/// novelty factor would count today's trace before it exists.
///
/// [players] is the roster **after** the night's death has been applied, which
/// is what makes `T1`'s "the target is still alive" clause mean what it says.
TraceResult selectTrace({
  required NightRecord night,
  required List<NightRecord> history,
  required List<Player> players,
  required int nightNumber,
  required int matchSeed,
}) {
  final alive = {
    for (final p in players)
      if (p.status == PlayerStatus.alive) p.seat,
  };

  final lastPublished = history.isEmpty ? null : history.last.revealedTrace;

  final eligible = <TraceCandidate>[];
  for (final type in TraceType.candidates) {
    // Never repeat back-to-back. Checked before evaluating rather than after,
    // because a type that fired yesterday is not a candidate today whatever it
    // would have scored.
    if (type == lastPublished) continue;

    final candidate = evaluateTrace(
      type: type,
      night: night,
      history: history,
      alive: alive,
      nightNumber: nightNumber,
    );
    if (candidate == null) continue;
    eligible.add(candidate);
  }

  if (eligible.isEmpty) return TraceResult.none;

  // `T8` and `T3` are the same observation at two strengths — "most of the
  // table suspected one person" and "n players suspected one person" — and
  // `T8`'s bar is strictly higher, so whenever it fires `T3` is also true and
  // is the weaker way of saying it.
  //
  // Left to compete they never resolve the way the drama weights imply. §1.5
  // asks for `T3`'s information value to grow with the headcount ("T3 with n=4
  // > T3 with n=2"), and that growth outruns the single point of drama weight
  // separating them almost immediately: five of seven agreeing scores T3 at
  // 8.75 against T8's 6.69, so the table would be told «٥ لاعبين شكّوا في نفس
  // الشخص» on a night when «أغلب الطاولة شكّت في نفس الشخص» was available and
  // stronger. Suppressing the weaker statement is the only reading on which
  // T8's higher weight means anything at all.
  if (eligible.any((c) => c.type == TraceType.t8)) {
    eligible.removeWhere((c) => c.type == TraceType.t3);
  }

  // Doc 09 §1.4, first line: *"`T1` is the highest-value trace and is always
  // preferred when eligible."* Stated as a rule, so it is implemented as one
  // rather than approximated by weights.
  //
  // Weights alone cannot deliver it. `T3`'s information value grows with the
  // number of players who agreed — which §1.5 explicitly asks for ("T3 with
  // n=4 > T3 with n=2") — so on a table where six of seven suspected the same
  // person, T3 outscores T1's drama weight of 10 and the dead player's last
  // words get bumped by an aggregate. That is precisely backwards.
  //
  // The back-to-back rule still applies above: a `T1` published yesterday is
  // not in `eligible` today and cannot be preferred.
  for (final c in eligible) {
    if (c.type == TraceType.t1) return c.result;
  }

  for (final c in eligible) {
    c.score = c.type.dramaWeight *
        noveltyFactor(history, c.type) *
        c.informationValue;
  }

  // Sort by score, then by type index — a total order, so the *set* handed to
  // the tie-break is the same on every device even before the seed is drawn.
  // `List.sort` is not stable in Dart, so leaving equal scores in encounter
  // order would be leaving them in an arbitrary one.
  eligible.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.type.index.compareTo(b.type.index);
  });

  final best = eligible.first.score;
  final top = eligible.where((c) => c.score >= best - 0.01).toList();
  if (top.length == 1) return top.first.result;

  final index = tieBreakIndex(
    deriveSeed(matchSeed, SeedSalt.trace, nightNumber),
    top.length,
  );
  return top[index].result;
}

/// How worn out a trace type is. 1.0 the first time, 0.4 once it is furniture.
///
/// Doc 09 §1.5 gives the endpoints and not the curve. This is linear at 0.15
/// per previous use, so a type has to have been published five times before it
/// bottoms out — long enough that a long match still varies, short enough that
/// a table does not hear «اتنين شاكّين في بعض» four mornings running.
double noveltyFactor(List<NightRecord> history, TraceType type) {
  final used = history.where((n) => n.revealedTrace == type).length;
  final factor = 1.0 - 0.15 * used;
  return factor < 0.4 ? 0.4 : factor;
}

/// Whether [type] fires on this night, and how much it is worth if it does.
///
/// Public and total so that every eligibility branch can be tested on its own,
/// which doc 11 §10 requires (*"Trace and Confrontation generators: every
/// eligibility branch covered"*). Returns null for "not eligible".
TraceCandidate? evaluateTrace({
  required TraceType type,
  required NightRecord night,
  required List<NightRecord> history,
  required Set<int> alive,
  required int nightNumber,
}) {
  final recorded = night.recordedSuspicions;

  switch (type) {
    case TraceType.t0:
      // Not a candidate. It is what you get when there are none.
      return null;

    // ─── T1 آخر شك للضحية ───────────────────────────────────────────────
    // Someone died, they had recorded a suspicion, and the person they named
    // is alive to answer for it. All three clauses matter: a target who is
    // already dead cannot respond, so the trace would be a history lesson
    // rather than an opening (T-E2), and a victim who skipped left nothing to
    // read out (T-E3).
    case TraceType.t1:
      final victim = night.victim;
      if (victim == null) return null;
      final target = night.suspicions[victim];
      if (target == null) return null;
      if (!alive.contains(target)) return null;
      return TraceCandidate(
        TraceResult(
          type: TraceType.t1,
          subjectSeat: victim,
          targetSeat: target,
        ),
      );

    // ─── T2 نجاة ────────────────────────────────────────────────────────
    // A kill was blocked. Never names the saved player and never implies who
    // did the saving — doc 09 §1.6 checks exactly this and finds it safe.
    case TraceType.t2:
      if (!night.saveOccurred) return null;
      return TraceCandidate(const TraceResult(type: TraceType.t2));

    // ─── T3 تطابق ───────────────────────────────────────────────────────
    // Two or more *living* players landed on the same name. The dead victim's
    // own suspicion is excluded: it is already the subject of T1, and counting
    // it here would let the table subtract and recover it.
    case TraceType.t3:
      final counts = _suspicionCounts(recorded, alive);
      final top = _maxCount(counts);
      if (top < 2) return null;
      return TraceCandidate(
        TraceResult(type: TraceType.t3, count: top),
        // n=2 is the floor; every additional agreeing player is worth half a
        // step, so T3(4) outscores T3(2) as §1.5 asks without ever outscoring
        // T1's drama weight on its own.
        informationValue: 1.0 + (top - 2) * 0.25,
      );

    // ─── T4 تحوّل ───────────────────────────────────────────────────────
    case TraceType.t4:
      if (history.isEmpty) return null;
      final previous = history.last.recordedSuspicions;
      var changed = 0;
      recorded.forEach((seat, target) {
        if (!alive.contains(seat)) return;
        final before = previous[seat];
        if (before != null && before != target) changed++;
      });
      if (changed < 1) return null;
      return TraceCandidate(
        TraceResult(type: TraceType.t4, count: changed),
        informationValue: 1.0 + (changed - 1) * 0.25,
      );

    // ─── T5 الظل ────────────────────────────────────────────────────────
    // Requires two nights to have passed (T-E8): on night 1 almost everyone is
    // unsuspected, so the observation would be true and worthless.
    case TraceType.t5:
      if (nightNumber < 2) return null;
      final everSuspected = <int>{
        for (final n in history) ...n.recordedSuspicions.values,
        ...recorded.values,
      };
      final shadows = alive.where((s) => !everSuspected.contains(s)).length;
      if (shadows < 1) return null;
      return TraceCandidate(const TraceResult(type: TraceType.t5));

    // ─── T6 الصمت ───────────────────────────────────────────────────────
    case TraceType.t6:
      final skipped = night.skipped.where(alive.contains).length;
      if (skipped < 1) return null;
      return TraceCandidate(
        TraceResult(type: TraceType.t6, count: skipped),
      );

    // ─── T7 الدائرة ─────────────────────────────────────────────────────
    case TraceType.t7:
      for (final entry in recorded.entries) {
        final a = entry.key;
        final b = entry.value;
        if (!alive.contains(a) || !alive.contains(b)) continue;
        if (recorded[b] == a) {
          return TraceCandidate(const TraceResult(type: TraceType.t7));
        }
      }
      return null;

    // ─── T8 الإجماع ─────────────────────────────────────────────────────
    case TraceType.t8:
      if (alive.isEmpty) return null;
      final counts = _suspicionCounts(recorded, alive);
      final top = _maxCount(counts);
      if (top < 2) return null;
      if (top / alive.length < 0.6) return null;
      return TraceCandidate(
        TraceResult(type: TraceType.t8, count: top),
        informationValue: 1.0 + (top / alive.length - 0.6),
      );
  }
}

/// Suspected seat → how many living players named them.
Map<int, int> _suspicionCounts(Map<int, int> recorded, Set<int> alive) {
  final counts = <int, int>{};
  recorded.forEach((seat, target) {
    if (!alive.contains(seat)) return;
    counts[target] = (counts[target] ?? 0) + 1;
  });
  return counts;
}

int _maxCount(Map<int, int> counts) =>
    counts.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);
