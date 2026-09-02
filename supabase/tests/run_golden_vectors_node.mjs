/**
 * Runs the golden-vector contract under Node instead of Deno.
 *
 * ```
 * node supabase/tests/run_golden_vectors_node.mjs
 * ```
 *
 * ## Why this exists next to the Deno test
 *
 * `golden_vectors.test.ts` is the real one — it runs in the same runtime the
 * Edge Functions do, which is the only place a Deno-specific difference could
 * show up. But Deno is not installed everywhere, and a parity check that only
 * runs on a machine somebody has set up is a parity check that does not run.
 *
 * Node ≥22.6 strips TypeScript types natively, and the shared modules use
 * nothing but erasable syntax — `interface`, `type`, `as const` — so the exact
 * same source files load here unmodified. Both runners read the same vectors
 * and hold the same code to them. Run whichever you have; run Deno before a
 * release.
 */

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));

// `new URL(..., import.meta.url)` rather than a bare path: on Windows an
// absolute path starts `D:\`, and Node's ESM loader reads the drive letter as
// a URL scheme it does not recognise.
const { selectTrace } = await import(
  new URL("../functions/_shared/trace.ts", import.meta.url).href
);
const { selectConfrontation } = await import(
  new URL("../functions/_shared/confrontation.ts", import.meta.url).href
);

const vectors = JSON.parse(
  readFileSync(join(here, "golden_vectors.json"), "utf8"),
);

let failures = 0;

function check(label, actual, expected) {
  if (actual !== expected) {
    failures++;
    console.error(`  FAIL ${label}: got ${actual}, expected ${expected}`);
  }
}

for (const v of vectors.traces) {
  const result = selectTrace({
    night: v.night,
    history: v.history,
    alive: v.alive,
    nightNumber: v.nightNumber,
    matchSeed: v.matchSeed,
  });
  check(`trace "${v.name}" type`, result.type, v.expected.type);
  check(`trace "${v.name}" subject`, result.subjectSeat, v.expected.subjectSeat);
  check(`trace "${v.name}" target`, result.targetSeat, v.expected.targetSeat);
  check(`trace "${v.name}" count`, result.count, v.expected.count);
}

for (const v of vectors.confrontations) {
  const result = selectConfrontation({
    history: { nights: v.nights, days: v.days, alive: v.alive },
    dayNumber: v.dayNumber,
    matchSeed: v.matchSeed,
    settings: v.settings,
  });
  if (v.expected === null) {
    check(`confrontation "${v.name}"`, result, null);
    continue;
  }
  if (result === null) {
    failures++;
    console.error(`  FAIL confrontation "${v.name}": got null`);
    continue;
  }
  check(`confrontation "${v.name}" type`, result.type, v.expected.type);
  check(`confrontation "${v.name}" target`, result.targetSeat, v.expected.targetSeat);
  check(`confrontation "${v.name}" evidence`, result.evidenceSeat, v.expected.evidenceSeat);
  check(`confrontation "${v.name}" evidence2`, result.evidenceSeat2, v.expected.evidenceSeat2);
  check(`confrontation "${v.name}" evidenceDay`, result.evidenceDay, v.expected.evidenceDay);
  check(`confrontation "${v.name}" count`, result.count, v.expected.count);
}

// The held-back types must not appear even in the *stored* answers: the vector
// file is also the record of what the server is permitted to publish.
for (const v of vectors.confrontations) {
  if (v.expected && ["c2", "c3", "c9", "c10"].includes(v.expected.type)) {
    failures++;
    console.error(
      `  FAIL "${v.name}" publishes ${v.expected.type}, which names a living ` +
        `player's night suspicion`,
    );
  }
}

const cases = vectors.traces.length + vectors.confrontations.length;
if (failures > 0) {
  console.error(`\ngolden vectors: ${failures} mismatch(es) over ${cases} cases`);
  process.exit(1);
}
console.log(`golden vectors: ${cases} cases, Dart and TypeScript agree`);
