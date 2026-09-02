/**
 * The record model the generators read — the TypeScript half of
 * `lib/engine/information/records.dart` and `game_history.dart`.
 *
 * Only the fields the two generators actually consult are here. This is not a
 * general-purpose port of the engine: the server does not need to *play* a
 * match, it needs to make two decisions about one, and the smaller this
 * surface is the fewer places the two implementations can drift.
 */

export type TraceType =
  | "t0" | "t1" | "t2" | "t3" | "t4" | "t5" | "t6" | "t7" | "t8";

export type ConfrontationType =
  | "c1" | "c2" | "c3" | "c4" | "c5"
  | "c6" | "c7" | "c8" | "c9" | "c10" | "c11";

/** Mirrors `TraceType.dramaWeight` (doc 09 §1.5). */
export const TRACE_DRAMA: Record<TraceType, number> = {
  t0: 0.0,
  t1: 10.0,
  t2: 4.0,
  t3: 5.0,
  t4: 3.0,
  t5: 3.5,
  t6: 2.5,
  t7: 4.5,
  t8: 6.0,
};

/** Enum declaration order, which the total sort below depends on. */
export const TRACE_ORDER: TraceType[] =
  ["t0", "t1", "t2", "t3", "t4", "t5", "t6", "t7", "t8"];

/** Mirrors `ConfrontationType.severity`. */
export const CONFRONTATION_SEVERITY: Record<ConfrontationType, number> = {
  c1: 10.0,
  c2: 9.0,
  c3: 6.0,
  c4: 4.0,
  c5: 7.0,
  c6: 3.5,
  c7: 8.5,
  c8: 5.0,
  c9: 5.5,
  c10: 4.5,
  c11: 3.0,
};

export const CONFRONTATION_ORDER: ConfrontationType[] =
  ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10", "c11"];

/**
 * The three types held back for announcing a living player's role.
 *
 * `c3`, `c9` and `c10` all read a living player's *night suspicion record* and
 * quote it back by name. Only Citizens record suspicions, so any of them firing
 * says the named player is a Citizen — the exact inference
 * `05-zero-leakage-spec.md` exists to prevent.
 *
 * `c2` needs a record of a player defending someone, and the game has no
 * defence action to record.
 *
 * Kept identical to `ConfrontationCatalogue.shipped` in the Dart. The golden
 * vectors would catch a divergence, but this comment is here so nobody has to
 * discover it that way.
 */
export const HELD_BACK: ConfrontationType[] = ["c2", "c3", "c9", "c10"];

export interface NightRecord {
  nightNumber: number;
  /** seat -> suspected seat, or null for "took the turn and chose nobody". */
  suspicions: Record<number, number | null>;
  victim: number | null;
  saveOccurred: boolean;
  savedSeat: number | null;
  /** What was published the next morning, or null. */
  revealedTrace: TraceType | null;
  resolved: boolean;
}

export interface ConfrontationRecord {
  type: ConfrontationType;
  targetSeat: number;
  evidenceSeat: number | null;
  evidenceSeat2: number | null;
  evidenceDay: number | null;
  count: number | null;
}

export interface WhisperEdge {
  day: number;
  fromSeat: number;
  toSeat: number;
}

export interface DayRecord {
  dayNumber: number;
  /** The Day-1 «اسم واحد» round. */
  openingAccusations: Record<number, number>;
  confrontation: ConfrontationRecord | null;
  /** Final round only. Null is an abstention. */
  votes: Record<number, number | null>;
  speakingSeconds: Record<number, number>;
  whispers: WhisperEdge[];
}

export interface GameHistory {
  nights: NightRecord[];
  days: DayRecord[];
  alive: number[];
}

export interface GeneratorSettings {
  whisperEnabled: boolean;
  survivorConfrontationEnabled: boolean;
}

/** seat -> suspected seat, skips dropped. Mirrors `recordedSuspicions`. */
export function recordedSuspicions(
  night: NightRecord,
): Record<number, number> {
  const out: Record<number, number> = {};
  for (const [seat, target] of Object.entries(night.suspicions)) {
    if (target !== null && target !== undefined) out[Number(seat)] = target;
  }
  return out;
}

/** Seats that took a turn and chose nobody. Mirrors `skipped`. */
export function skippedSeats(night: NightRecord): number[] {
  return Object.entries(night.suspicions)
    .filter(([, target]) => target === null)
    .map(([seat]) => Number(seat));
}

export function nightAt(
  history: GameHistory,
  n: number,
): NightRecord | null {
  return history.nights.find((x) => x.nightNumber === n) ?? null;
}

export function dayAt(history: GameHistory, d: number): DayRecord | null {
  return history.days.find((x) => x.dayNumber === d) ?? null;
}

export function resolvedNights(history: GameHistory): NightRecord[] {
  return history.nights.filter((n) => n.resolved);
}

/** Mirrors `GameHistory.lastConfrontedPlayer`. */
export function lastConfrontedPlayer(history: GameHistory): number | null {
  for (let i = history.days.length - 1; i >= 0; i--) {
    const c = history.days[i].confrontation;
    if (c) return c.targetSeat;
  }
  return null;
}

/** Mirrors `GameHistory.lastConfrontationType`. */
export function lastConfrontationType(
  history: GameHistory,
): ConfrontationType | null {
  for (let i = history.days.length - 1; i >= 0; i--) {
    const c = history.days[i].confrontation;
    if (c) return c.type;
  }
  return null;
}

/** Mirrors `GameHistory.confrontationCountFor`. */
export function confrontationCountFor(
  history: GameHistory,
  seat: number,
): number {
  return history.days.filter((d) => d.confrontation?.targetSeat === seat)
    .length;
}

/** Mirrors `GameHistory.everSuspected`. */
export function everSuspected(history: GameHistory): Set<number> {
  const out = new Set<number>();
  for (const night of history.nights) {
    for (const target of Object.values(recordedSuspicions(night))) {
      out.add(target);
    }
  }
  for (const day of history.days) {
    for (const target of Object.values(day.openingAccusations)) {
      out.add(target);
    }
  }
  return out;
}

/** Mirrors `GameHistory.totalSpeakingSeconds`. */
export function totalSpeakingSeconds(
  history: GameHistory,
): Record<number, number> {
  const out: Record<number, number> = {};
  for (const day of history.days) {
    for (const [seat, seconds] of Object.entries(day.speakingSeconds)) {
      out[Number(seat)] = (out[Number(seat)] ?? 0) + seconds;
    }
  }
  return out;
}

/** Mirrors `GameHistory.allWhispers`. */
export function allWhispers(history: GameHistory): WhisperEdge[] {
  return history.days.flatMap((d) => d.whispers);
}
