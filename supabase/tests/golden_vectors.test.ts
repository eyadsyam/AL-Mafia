/**
 * The TypeScript half of the golden-vector contract (doc 10 §5.1).
 *
 * ```
 * deno test --allow-read supabase/tests/golden_vectors.test.ts
 * ```
 *
 * Reads exactly the same `golden_vectors.json` as
 * `test/engine/golden_vectors_test.dart`, and asserts the port reproduces every
 * stored answer. Neither implementation can pass by agreeing with itself.
 *
 * **If this fails, do not regenerate the vectors.** The file is the record of
 * what the Dart reference decided; a divergence here means the port is wrong,
 * or that a deliberate change to the Dart was made without bringing the port
 * along. Fix the port, or make both changes and regenerate in one commit.
 */

import { assertEquals } from "jsr:@std/assert@1";
import { selectTrace } from "../functions/_shared/trace.ts";
import { selectConfrontation } from "../functions/_shared/confrontation.ts";
import type {
  ConfrontationType,
  DayRecord,
  GameHistory,
  NightRecord,
  TraceType,
} from "../functions/_shared/records.ts";

interface TraceVector {
  name: string;
  matchSeed: number;
  nightNumber: number;
  alive: number[];
  night: NightRecord;
  history: NightRecord[];
  expected: {
    type: TraceType;
    subjectSeat: number | null;
    targetSeat: number | null;
    count: number | null;
  };
}

interface ConfrontationVector {
  name: string;
  matchSeed: number;
  dayNumber: number;
  alive: number[];
  nights: NightRecord[];
  days: DayRecord[];
  settings: {
    whisperEnabled: boolean;
    survivorConfrontationEnabled: boolean;
  };
  expected: {
    type: ConfrontationType;
    targetSeat: number;
    evidenceSeat: number | null;
    evidenceSeat2: number | null;
    evidenceDay: number | null;
    count: number | null;
  } | null;
}

interface Vectors {
  version: number;
  traces: TraceVector[];
  confrontations: ConfrontationVector[];
}

const vectors: Vectors = JSON.parse(
  await Deno.readTextFile(
    new URL("./golden_vectors.json", import.meta.url),
  ),
);

/**
 * The Dart encoder writes map keys as strings, because JSON has no other kind.
 * `Object.entries` therefore hands back string keys, and every lookup in the
 * port does `Number(key)`. The records arrive shaped correctly for that, so
 * nothing needs converting here — this is stated because "it works by accident"
 * and "it works because both sides agreed on the wire shape" look identical
 * until the day they do not.
 */
Deno.test("the vector file loaded", () => {
  assertEquals(vectors.version, 1);
  if (vectors.traces.length < 10) throw new Error("too few trace vectors");
  if (vectors.confrontations.length < 10) {
    throw new Error("too few confrontation vectors");
  }
});

Deno.test("traces match the Dart reference", () => {
  for (const v of vectors.traces) {
    const result = selectTrace({
      night: v.night,
      history: v.history,
      alive: v.alive,
      nightNumber: v.nightNumber,
      matchSeed: v.matchSeed,
    });
    assertEquals(result.type, v.expected.type, `trace "${v.name}" type`);
    assertEquals(
      result.subjectSeat,
      v.expected.subjectSeat,
      `trace "${v.name}" subject`,
    );
    assertEquals(
      result.targetSeat,
      v.expected.targetSeat,
      `trace "${v.name}" target`,
    );
    assertEquals(result.count, v.expected.count, `trace "${v.name}" count`);
  }
});

Deno.test("confrontations match the Dart reference", () => {
  for (const v of vectors.confrontations) {
    const history: GameHistory = {
      nights: v.nights,
      days: v.days,
      alive: v.alive,
    };
    const result = selectConfrontation({
      history,
      dayNumber: v.dayNumber,
      matchSeed: v.matchSeed,
      settings: v.settings,
    });
    if (v.expected === null) {
      assertEquals(result, null, `confrontation "${v.name}" should be null`);
      continue;
    }
    if (result === null) {
      throw new Error(`confrontation "${v.name}" produced null`);
    }
    assertEquals(result.type, v.expected.type, `"${v.name}" type`);
    assertEquals(
      result.targetSeat,
      v.expected.targetSeat,
      `"${v.name}" target`,
    );
    assertEquals(
      result.evidenceSeat,
      v.expected.evidenceSeat,
      `"${v.name}" evidence`,
    );
    assertEquals(
      result.evidenceSeat2,
      v.expected.evidenceSeat2,
      `"${v.name}" evidence2`,
    );
    assertEquals(
      result.evidenceDay,
      v.expected.evidenceDay,
      `"${v.name}" evidenceDay`,
    );
    assertEquals(result.count, v.expected.count, `"${v.name}" count`);
  }
});

Deno.test("no held-back confrontation type is ever published", () => {
  for (const v of vectors.confrontations) {
    if (v.expected === null) continue;
    if (["c2", "c3", "c9", "c10"].includes(v.expected.type)) {
      throw new Error(
        `case "${v.name}" published ${v.expected.type}, which names a living ` +
          `player's night suspicion`,
      );
    }
  }
});
