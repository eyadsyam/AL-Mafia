/**
 * Layer 2 — the Confrontation. The TypeScript half of
 * `lib/engine/information/confrontation_generator.dart`.
 *
 * Same finders, same order, same filters, same fairness partition, same
 * tie-break. `supabase/tests/golden_vectors.test.ts` proves it.
 *
 * `c2`, `c3`, `c9` and `c10` are absent from the shipped catalogue for the
 * reasons written down in `records.ts` — three of them would tell the table
 * that a named living player is a Citizen.
 */

import { deriveSeed, SeedSalt, tieBreakIndex } from "./seed.ts";
import {
  allWhispers,
  CONFRONTATION_ORDER,
  CONFRONTATION_SEVERITY,
  type ConfrontationRecord,
  type ConfrontationType,
  confrontationCountFor,
  dayAt,
  everSuspected,
  type GameHistory,
  type GeneratorSettings,
  HELD_BACK,
  recordedSuspicions,
  resolvedNights,
  skippedSeats,
  totalSpeakingSeconds,
} from "./records.ts";

interface Candidate {
  confrontation: ConfrontationRecord;
  score: number;
}

function make(
  c: Partial<ConfrontationRecord> & {
    type: ConfrontationType;
    targetSeat: number;
  },
): Candidate {
  return {
    confrontation: {
      type: c.type,
      targetSeat: c.targetSeat,
      evidenceSeat: c.evidenceSeat ?? null,
      evidenceSeat2: c.evidenceSeat2 ?? null,
      evidenceDay: c.evidenceDay ?? null,
      count: c.count ?? null,
    },
    score: 0,
  };
}

/** Mirrors `ConfrontationCatalogue.shipped`. */
export function shippedTypes(): ConfrontationType[] {
  return CONFRONTATION_ORDER.filter((t) => !HELD_BACK.includes(t));
}

/** Mirrors `ConfrontationCatalogue.enabledFor`. */
export function enabledTypes(
  settings: GeneratorSettings,
): ConfrontationType[] {
  return shippedTypes().filter((t) => {
    if (t === "c11" && !settings.survivorConfrontationEnabled) return false;
    if (t === "c8" && !settings.whisperEnabled) return false;
    return true;
  });
}

/** Mirrors `recencyBoost`. */
export function recencyBoost(
  evidenceDay: number | null,
  dayNumber: number,
): number {
  if (evidenceDay === null) return 1.0;
  const age = dayNumber - evidenceDay;
  if (age <= 1) return 1.0;
  const boost = 1.0 - 0.15 * (age - 1);
  return boost < 0.5 ? 0.5 : boost;
}

/** Mirrors `fairnessFactor`. */
export function fairnessFactor(history: GameHistory, seat: number): number {
  const count = confrontationCountFor(history, seat);
  if (count === 0) return 1.0;
  if (count === 1) return 0.5;
  return 0.25;
}

/** Mirrors `findConfrontations`. */
export function findConfrontations(
  type: ConfrontationType,
  history: GameHistory,
  alive: Set<number>,
  dayNumber: number,
): Candidate[] {
  switch (type) {
    // ── C1 تناقض التصويت ───────────────────────────────────────────────
    case "c1": {
      const out: Candidate[] = [];
      const opener = dayAt(history, 1)?.openingAccusations ?? {};
      for (const [seatKey, accused] of Object.entries(opener)) {
        const seat = Number(seatKey);
        if (!alive.has(seat)) continue;
        for (let d = dayNumber - 1; d >= 1; d--) {
          const voted = dayAt(history, d)?.votes[seat];
          if (voted === null || voted === undefined || voted === accused) {
            continue;
          }
          out.push(make({
            type: "c1",
            targetSeat: seat,
            evidenceSeat: accused,
            evidenceSeat2: voted,
            evidenceDay: d,
          }));
          break;
        }
      }
      return out;
    }

    // Needs a defence record; the game has no defence action.
    case "c2":
      return [];

    // ── C3 الثبات (held back) ──────────────────────────────────────────
    case "c3": {
      const out: Candidate[] = [];
      const nights = resolvedNights(history);
      if (nights.length < 3) return out;
      const last3 = nights.slice(nights.length - 3);
      for (const seat of alive) {
        const targets = last3.map((n) => recordedSuspicions(n)[seat]);
        if (targets.some((t) => t === undefined)) continue;
        if (new Set(targets).size !== 1) continue;
        out.push(make({
          type: "c3",
          targetSeat: seat,
          evidenceSeat: targets[0],
          evidenceDay: last3[last3.length - 1].nightNumber,
          count: 3,
        }));
      }
      return out;
    }

    // ── C4 الظل ────────────────────────────────────────────────────────
    case "c4": {
      if (dayNumber - 1 < 3) return [];
      const suspected = everSuspected(history);
      return [...alive]
        .filter((seat) => !suspected.has(seat))
        .map((seat) =>
          make({ type: "c4", targetSeat: seat, evidenceDay: dayNumber - 1 })
        );
    }

    // ── C5 التوأم ──────────────────────────────────────────────────────
    case "c5": {
      const out: Candidate[] = [];
      const pairs = new Map<string, number>();
      const lastAgreement = new Map<string, number>();
      for (let d = 1; d < dayNumber; d++) {
        const votes = dayAt(history, d)?.votes ?? {};
        for (const a of alive) {
          for (const b of alive) {
            if (b <= a) continue;
            const va = votes[a];
            const vb = votes[b];
            if (va === null || va === undefined) continue;
            if (vb === null || vb === undefined) continue;
            if (va !== vb) continue;
            const key = `${a}:${b}`;
            pairs.set(key, (pairs.get(key) ?? 0) + 1);
            lastAgreement.set(key, d);
          }
        }
      }
      for (const [key, count] of pairs) {
        if (count < 3) continue;
        const [a, b] = key.split(":").map(Number);
        for (const [self, other] of [[a, b], [b, a]]) {
          out.push(make({
            type: "c5",
            targetSeat: self,
            evidenceSeat: other,
            evidenceDay: lastAgreement.get(key) ?? null,
            count,
          }));
        }
      }
      return out;
    }

    // ── C6 الصامت ──────────────────────────────────────────────────────
    case "c6": {
      if (dayNumber - 1 < 2) return [];
      const totals = totalSpeakingSeconds(history);
      const full = new Map<number, number>();
      for (const seat of alive) full.set(seat, totals[seat] ?? 0);
      if (full.size === 0) return [];
      const lowest = Math.min(...full.values());
      const quietest = [...full.entries()].filter(([, v]) => v === lowest);
      // Only when there is a *single* quietest player: "you have talked least"
      // is not true of a three-way tie at zero.
      if (quietest.length !== 1) return [];
      return [
        make({
          type: "c6",
          targetSeat: quietest[0][0],
          evidenceDay: dayNumber - 1,
          count: lowest,
        }),
      ];
    }

    // ── C7 الميت يتكلم ─────────────────────────────────────────────────
    case "c7": {
      const nights = resolvedNights(history);
      if (nights.length === 0) return [];
      const last = nights[nights.length - 1];
      if (last.victim === null) return [];
      const named = recordedSuspicions(last)[last.victim];
      if (named === undefined || !alive.has(named)) return [];
      return [
        make({
          type: "c7",
          targetSeat: named,
          evidenceSeat: last.victim,
          evidenceDay: last.nightNumber,
        }),
      ];
    }

    // ── C8 الهمّاس ─────────────────────────────────────────────────────
    case "c8": {
      const out: Candidate[] = [];
      const byPair = new Map<string, number[]>();
      for (const w of allWhispers(history)) {
        if (!alive.has(w.fromSeat)) continue;
        const key = `${w.fromSeat}:${w.toSeat}`;
        const days = byPair.get(key) ?? [];
        days.push(w.day);
        byPair.set(key, days);
      }
      for (const [key, unsorted] of byPair) {
        const days = [...unsorted].sort((a, b) => a - b);
        let run = 1;
        let bestRun = 1;
        let bestEnd = days[0];
        for (let i = 1; i < days.length; i++) {
          if (days[i] === days[i - 1] + 1) {
            run++;
          } else if (days[i] !== days[i - 1]) {
            run = 1;
          }
          if (run > bestRun) {
            bestRun = run;
            bestEnd = days[i];
          }
        }
        if (bestRun < 2) continue;
        const [from, to] = key.split(":").map(Number);
        out.push(make({
          type: "c8",
          targetSeat: from,
          evidenceSeat: to,
          evidenceDay: bestEnd,
          count: bestRun,
        }));
      }
      return out;
    }

    // ── C9 التقلّب (held back) ─────────────────────────────────────────
    case "c9": {
      const out: Candidate[] = [];
      const nights = resolvedNights(history);
      if (nights.length < 4) return out;
      const window = nights.slice(nights.length - 4);
      for (const seat of alive) {
        let changes = 0;
        for (let i = 1; i < window.length; i++) {
          const before = recordedSuspicions(window[i - 1])[seat];
          const now = recordedSuspicions(window[i])[seat];
          if (before !== undefined && now !== undefined && before !== now) {
            changes++;
          }
        }
        if (changes < 3) continue;
        out.push(make({
          type: "c9",
          targetSeat: seat,
          evidenceDay: window[window.length - 1].nightNumber,
          count: changes,
        }));
      }
      return out;
    }

    // ── C10 الامتناع (held back) ───────────────────────────────────────
    case "c10": {
      const out: Candidate[] = [];
      const counts = new Map<number, number>();
      const lastNight = new Map<number, number>();
      for (const n of resolvedNights(history)) {
        for (const seat of skippedSeats(n)) {
          counts.set(seat, (counts.get(seat) ?? 0) + 1);
          lastNight.set(seat, n.nightNumber);
        }
      }
      for (const [seat, count] of counts) {
        if (count < 2 || !alive.has(seat)) continue;
        out.push(make({
          type: "c10",
          targetSeat: seat,
          evidenceDay: lastNight.get(seat) ?? null,
          count,
        }));
      }
      return out;
    }

    // ── C11 الناجي (opt-in) ────────────────────────────────────────────
    case "c11": {
      const out: Candidate[] = [];
      for (const n of resolvedNights(history)) {
        if (n.nightNumber >= dayNumber) continue;
        if (n.savedSeat === null || !alive.has(n.savedSeat)) continue;
        out.push(make({
          type: "c11",
          targetSeat: n.savedSeat,
          evidenceDay: n.nightNumber,
        }));
      }
      return out;
    }
  }
}

/** Mirrors `selectConfrontation`. Null is a normal outcome, not a failure. */
export function selectConfrontation(args: {
  history: GameHistory;
  dayNumber: number;
  matchSeed: number;
  settings: GeneratorSettings;
}): ConfrontationRecord | null {
  if (args.dayNumber <= 1) return null;

  const alive = new Set(args.history.alive);
  let candidates: Candidate[] = [];
  for (const type of enabledTypes(args.settings)) {
    candidates = candidates.concat(
      findConfrontations(type, args.history, alive, args.dayNumber),
    );
  }

  const lastPlayer = lastConfrontedPlayerOf(args.history);
  const lastType = lastConfrontationTypeOf(args.history);
  candidates = candidates.filter((c) =>
    alive.has(c.confrontation.targetSeat) &&
    c.confrontation.targetSeat !== lastPlayer &&
    c.confrontation.type !== lastType
  );

  if (candidates.length === 0) return null;

  const within = candidates.filter(
    (c) => confrontationCountFor(args.history, c.confrontation.targetSeat) < 2,
  );
  const pool = within.length > 0 ? within : candidates;

  for (const c of pool) {
    c.score = CONFRONTATION_SEVERITY[c.confrontation.type] *
      recencyBoost(c.confrontation.evidenceDay, args.dayNumber) *
      fairnessFactor(args.history, c.confrontation.targetSeat);
  }

  pool.sort((a, b) => {
    const byScore = b.score - a.score;
    if (byScore !== 0) return byScore;
    const byType = CONFRONTATION_ORDER.indexOf(a.confrontation.type) -
      CONFRONTATION_ORDER.indexOf(b.confrontation.type);
    if (byType !== 0) return byType;
    return a.confrontation.targetSeat - b.confrontation.targetSeat;
  });

  const best = pool[0].score;
  const top = pool.filter((c) => c.score >= best - 0.01);
  if (top.length === 1) return top[0].confrontation;

  const index = tieBreakIndex(
    deriveSeed(args.matchSeed, SeedSalt.confrontation, args.dayNumber),
    top.length,
  );
  return top[index].confrontation;
}

function lastConfrontedPlayerOf(history: GameHistory): number | null {
  for (let i = history.days.length - 1; i >= 0; i--) {
    const c = history.days[i].confrontation;
    if (c) return c.targetSeat;
  }
  return null;
}

function lastConfrontationTypeOf(
  history: GameHistory,
): ConfrontationType | null {
  for (let i = history.days.length - 1; i >= 0; i--) {
    const c = history.days[i].confrontation;
    if (c) return c.type;
  }
  return null;
}
