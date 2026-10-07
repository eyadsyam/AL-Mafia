import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../docs/monetization-plan/', import.meta.url);
const read = name => JSON.parse(readFileSync(new URL(name, root), 'utf8').replace(/^\uFEFF/, ''));
const evidence = read('created-admob-units.json');
const candidate = read('runtime-candidate.json');
assert.equal(evidence.created.length, 21);
assert.equal(candidate.placements.length, 24);
assert.equal(candidate.enabled, false);
assert.equal(new Set(evidence.created.map(p => p.unitId)).size, 21);
assert.equal(new Set(candidate.placements.map(p => p.id)).size, 24);
for (const p of candidate.placements) {
  assert.equal(p.enabled, false, `Premature activation: ${p.id}`);
  assert.equal(p.platform, 'android');
  const consoleRow = evidence.created.find(row => row.id === p.id);
  assert.equal(p.unitId, consoleRow?.unitId ?? null, `Unverified unit: ${p.id}`);
  if (p.unitId !== null) assert.match(p.unitId, /^ca-app-pub-9179063936085117\/\d{10}$/);
}
assert.deepEqual(candidate.placements.filter(p => p.unitId === null).map(p => p.id).sort(), [...evidence.pending].sort());
console.log('PASS: 21 verified IDs, 24 unique placements, 3 pending, all activation flags off');
