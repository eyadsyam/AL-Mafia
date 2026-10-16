import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolveNightCore } from '../functions/_shared/night_core.ts';

const path = new URL('./night_vectors.json', import.meta.url);
const { version, scenarios } = JSON.parse(readFileSync(path, 'utf8'));
assert.equal(version, 1);
assert.ok(scenarios.length >= 40);

for (const { name, input, expected } of scenarios) {
  test(name, () => {
    const seatOf = new Map(input.roster.map((p) => [p.user_id, p.seat]));
    const result = resolveNightCore({
      ...input,
      lockedSeatSet: new Set(input.lockedSeatSet),
      noSilenceSeatSet: new Set(input.noSilenceSeatSet),
    });
    assert.deepEqual({
      deathSeats: result.deathIds.map((id) => seatOf.get(id)),
      savedSeat: result.savedId === null ? null : seatOf.get(result.savedId),
      saveTold: result.saveTold,
      silencedSeat: result.silencedId === null ? null : seatOf.get(result.silencedId),
    }, expected);
  });
}
