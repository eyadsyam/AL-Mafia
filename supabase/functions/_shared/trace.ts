/**
 * Layer 1 — the Trace. The TypeScript half of
 * `lib/engine/information/trace_generator.dart`.
 *
 * The two files are line-for-line comparable on purpose: same order of
 * eligibility checks, same numbers, same total sort, same tie-break. The
 * golden-vector suite drives both over the same inputs and fails the build if
 * one character of behaviour differs.
 *
 * Doc 10 §5.1 chose "server runs the generator, client only renders the
 * result", and then asked for a golden-vector test *between the Dart and the
 * TypeScript implementation* — which only makes sense if both exist. Both do:
 * the Dart one is what offline mode plays on and is the reference; this one is
 * what an online match actually publishes. The vectors are the contract that
 * keeps them from drifting, which is the outcome §5.1 was reaching for.
 */

import { deriveSeed, SeedSalt, tieBreakIndex } from "./seed.ts";
import {
  type GameHistory,
  type NightRecord,
  recordedSuspicions,
  skippedSeats,
  TRACE_DRAMA,
  TRACE_ORDER,
  type TraceType,
} from "./records.ts";

export interface TraceResult {
  type: TraceType;
  subjectSeat: number | null;
  targetSeat: number | null;
  count: number | null;
}

export const TRACE_NONE: TraceResult = {
  type: "t0",
  subjectSeat: null,
  targetSeat: null,
  count: null,
};

interface Candidate {
  result: TraceResult;
  informationValue: number;
  score: number;
}

function candidate(
  result: Partial<TraceResult> & { type: TraceType },
  informationValue = 1.0,
): Candidate {
  return {
    result: {
      type: result.type,
      subjectSeat: result.subjectSeat ?? null,
      targetSeat: result.targetSeat ?? null,
      count: result.count ?? null,
    },
    informationValue,
    score: 0,
  };
}

/** Mirrors `noveltyFactor`. */
export function noveltyFactor(
  history: NightRecord[],
  type: TraceType,
): number {
  const used = history.filter((n) => n.revealedTrace === type).length;
  const factor = 1.0 - 0.15 * used;
  return factor < 0.4 ? 0.4 : factor;
}

/** Mirrors `evaluateTrace`. Returns null for "not eligible". */
export function evaluateTrace(
  type: TraceType,
  night: NightRecord,
  history: NightRecord[],
  alive: Set<number>,
  nightNumber: number,
): Candidate | null {
  const recorded = recordedSuspicions(night);

  switch (type) {
    case "t0":
      return null;

    case "t1": {
      const victim = night.victim;
      if (victim === null) return null;
      const target = night.suspicions[victim];
      if (target === null || target === undefined) return null;
      if (!alive.has(target)) return null;
      return candidate({ type: "t1", subjectSeat: victim, targetSeat: target });
    }

    case "t2":
      if (!night.saveOccurred) return null;
      return candidate({ type: "t2" });

    case "t3": {
      const top = maxCount(suspicionCounts(recorded, alive));
      if (top < 2) return null;
      return candidate({ type: "t3", count: top }, 1.0 + (top - 2) * 0.25);
    }

    case "t4": {
      if (history.length === 0) return null;
      const previous = recordedSuspicions(history[history.length - 1]);
      let changed = 0;
      for (const [seatKey, target] of Object.entries(recorded)) {
        const seat = Number(seatKey);
        if (!alive.has(seat)) continue;
        const before = previous[seat];
        if (before !== undefined && before !== target) changed++;
      }
      if (changed < 1) return null;
      return candidate({ type: "t4", count: changed }, 1.0 + (changed - 1) * 0.25);
    }

    case "t5": {
      if (nightNumber < 2) return null;
      const seen = new Set<number>();
      for (const n of history) {
        for (const target of Object.values(recordedSuspicions(n))) {
          seen.add(target);
        }
      }
      for (const target of Object.values(recorded)) seen.add(target);
      const shadows = [...alive].filter((s) => !seen.has(s)).length;
      if (shadows < 1) return null;
      return candidate({ type: "t5" });
    }

    case "t6": {
      const skipped = skippedSeats(night).filter((s) => alive.has(s)).length;
      if (skipped < 1) return null;
      return candidate({ type: "t6", count: skipped });
    }

    case "t7": {
      for (const [aKey, b] of Object.entries(recorded)) {
        const a = Number(aKey);
        if (!alive.has(a) || !alive.has(b)) continue;
        if (recorded[b] === a) return candidate({ type: "t7" });
      }
      return null;
    }

    case "t8": {
      if (alive.size === 0) return null;
      const top = maxCount(suspicionCounts(recorded, alive));
      if (top < 2) return null;
      if (top / alive.size < 0.6) return null;
      return candidate(
        { type: "t8", count: top },
        1.0 + (top / alive.size - 0.6),
      );
    }
  }
}

/** Mirrors `selectTrace`. */
export function selectTrace(args: {
  night: NightRecord;
  history: NightRecord[];
  alive: number[];
  nightNumber: number;
  matchSeed: number;
}): TraceResult {
  const alive = new Set(args.alive);
  const lastPublished = args.history.length === 0
    ? null
    : args.history[args.history.length - 1].revealedTrace;

  let eligible: Candidate[] = [];
  for (const type of TRACE_ORDER) {
    if (type === "t0") continue;
    if (type === lastPublished) continue;
    const c = evaluateTrace(
      type,
      args.night,
      args.history,
      alive,
      args.nightNumber,
    );
    if (c) eligible.push(c);
  }

  if (eligible.length === 0) return TRACE_NONE;

  // T8 and T3 are the same observation at two strengths, and T8's bar is
  // strictly higher — so whenever T8 fires, T3 is the weaker way of saying the
  // same true thing. Left to compete, T3's headcount-driven information value
  // outruns T8's single extra point of drama weight and the table gets told the
  // lesser sentence. Mirrors the Dart.
  if (eligible.some((c) => c.result.type === "t8")) {
    eligible = eligible.filter((c) => c.result.type !== "t3");
  }

  // Doc 09 §1.4: T1 is always preferred when eligible. A rule, not a weight —
  // T3's information value can otherwise outrun T1's drama weight on a table
  // where six of seven agreed, and an aggregate outranking the dead player's
  // last words is precisely backwards.
  const t1 = eligible.find((c) => c.result.type === "t1");
  if (t1) return t1.result;

  for (const c of eligible) {
    c.score = TRACE_DRAMA[c.result.type] *
      noveltyFactor(args.history, c.result.type) *
      c.informationValue;
  }

  // Total order before the tie-break, so the *set* handed to it is the same on
  // every device even before the seed is drawn.
  eligible.sort((a, b) => {
    const byScore = b.score - a.score;
    if (byScore !== 0) return byScore;
    return TRACE_ORDER.indexOf(a.result.type) -
      TRACE_ORDER.indexOf(b.result.type);
  });

  const best = eligible[0].score;
  const top = eligible.filter((c) => c.score >= best - 0.01);
  if (top.length === 1) return top[0].result;

  const index = tieBreakIndex(
    deriveSeed(args.matchSeed, SeedSalt.trace, args.nightNumber),
    top.length,
  );
  return top[index].result;
}

/** Convenience wrapper for callers holding a whole history. */
export function selectTraceFor(
  history: GameHistory,
  nightNumber: number,
  matchSeed: number,
): TraceResult {
  const night = history.nights.find((n) => n.nightNumber === nightNumber);
  if (!night) return TRACE_NONE;
  return selectTrace({
    night,
    history: history.nights.filter(
      (n) => n.resolved && n.nightNumber < nightNumber,
    ),
    alive: history.alive,
    nightNumber,
    matchSeed,
  });
}

function suspicionCounts(
  recorded: Record<number, number>,
  alive: Set<number>,
): Map<number, number> {
  const counts = new Map<number, number>();
  for (const [seatKey, target] of Object.entries(recorded)) {
    if (!alive.has(Number(seatKey))) continue;
    counts.set(target, (counts.get(target) ?? 0) + 1);
  }
  return counts;
}

function maxCount(counts: Map<number, number>): number {
  let top = 0;
  for (const value of counts.values()) if (value > top) top = value;
  return top;
}
