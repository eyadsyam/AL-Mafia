import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolveNightCore } from '../functions/_shared/night_core.ts';

const { version, scenarios } = JSON.parse(readFileSync(
  new URL('./night_matrix.json', import.meta.url), 'utf8'));
assert.equal(version, 1);
assert.ok(scenarios.length >= 400);

const seat = (id) => id === null ? null : Number(id.slice(1));
function outcome(input, result) {
  return {
    deathSeats: result.deathIds.map(seat),
    savedSeat: seat(result.savedId),
    saveTold: result.saveTold,
    silencedSeat: seat(result.silencedId),
  };
}

// Independent rule calculation for a specified tied kill pick (doc 17 §4,
// RL1, RL2, RL7, RL17). This never calls resolveNightCore.
function ruleOutcome(input, pick) {
  const roster = new Map(input.roster.map((p) => [p.seat, p]));
  const alive = new Set(input.roster.filter((p) => p.alive).map((p) => p.seat));
  const locked = new Set(input.lockedSeatSet);
  const noSilence = new Set(input.noSilenceSeatSet);
  const actions = input.actions;
  const mafia = (s) => ['mafia', 'silencer'].includes(roster.get(s)?.role);
  const protects = new Map();
  for (const a of actions.filter((a) => a.action === 'protect')) {
    const target = seat(a.target_id);
    if (alive.has(seat(a.actor_id)) && alive.has(target))
      protects.set(target, (protects.get(target) ?? 0) + 1);
  }
  const most = Math.max(0, ...protects.values());
  const covered = [...protects].filter(([, n]) => n === most).map(([s]) => s);
  // Matrix has one Doctor at most. A protect tie is reserved for future
  // multiple-doctor rows; every possible selection is considered below.
  const candidates = covered.length ? covered : [null];
  const possible = [];
  for (const protect of candidates) {
    let victim = locked.has(pick) ? null : pick;
    let saved = victim !== null && victim === protect ? victim : null;
    if (saved !== null) victim = null;
    const quiet = actions.some((a) => a.used_bullet &&
      roster.get(seat(a.actor_id))?.role === 'mafia');
    if (quiet) victim = null;
    const deaths = new Set(victim === null ? [] : [victim]);
    for (const a of actions.filter((a) => a.action === 'suspect' && a.used_bullet)) {
      const actor = seat(a.actor_id), target = seat(a.target_id);
      if (!alive.has(actor) || !alive.has(target) || locked.has(target)) continue;
      deaths.add(target);
      if (!mafia(target)) deaths.add(actor);
    }
    if (deaths.has(saved)) saved = null;
    const silence = actions.find((a) => a.action === 'silence' &&
      alive.has(seat(a.actor_id)) && alive.has(seat(a.target_id)) &&
      !locked.has(seat(a.target_id)) && !noSilence.has(seat(a.target_id)) &&
      !deaths.has(seat(a.target_id)));
    possible.push({
      deathSeats: [...deaths].sort((a, b) => a - b),
      savedSeat: saved,
      saveTold: saved !== null &&
        (input.settings.bulletsEnabled === false ||
         input.settings.quietNightEnabled === false),
      silencedSeat: silence ? seat(silence.target_id) : null,
    });
  }
  return possible;
}

// The Mafia's choice(s) before any save, lock or quiet night: the top of the
// kill tally over living non-Mafia targets, or [null] for no kill vote.
function killPicks(input) {
  const roster = new Map(input.roster.map((p) => [p.seat, p]));
  const alive = new Set(input.roster.filter((p) => p.alive).map((p) => p.seat));
  const tally = new Map();
  for (const a of input.actions) {
    const actor = seat(a.actor_id), target = seat(a.target_id);
    if (a.action !== 'kill' || target === null || !alive.has(actor) || !alive.has(target)) continue;
    if (['mafia', 'silencer'].includes(roster.get(target)?.role)) continue;
    tally.set(target, (tally.get(target) ?? 0) + 1);
  }
  if (tally.size === 0) return [null];
  const top = Math.max(...tally.values());
  return [...tally].filter(([, n]) => n === top).map(([s]) => s);
}

// «قفل الباب» and the silence shields exist online only, so they have no Dart
// side to agree with: every case is replayed once per seat a move names, with
// that seat locked, and once with it shielded from silence, against the rules.
const variants = [];
for (const { name, input, knownDivergence } of scenarios) {
  if (knownDivergence) continue;
  const named = [...new Set(input.actions.map((a) => seat(a.target_id))
    .filter((s) => s !== null))].sort((a, b) => a - b);
  for (const s of named) {
    variants.push({ name: `${name} | locked ${s}`,
      input: { ...input, lockedSeatSet: [s] } });
    variants.push({ name: `${name} | unsilenceable ${s}`,
      input: { ...input, noSilenceSeatSet: [s] } });
  }
}
assert.ok(variants.length >= 2000);
for (const { name, input } of variants) {
  test(name, () => {
    const result = resolveNightCore({ ...input,
      lockedSeatSet: new Set(input.lockedSeatSet),
      noSilenceSeatSet: new Set(input.noSilenceSeatSet),
    });
    const actual = outcome(input, result);
    const allowed = killPicks(input).flatMap((pick) => ruleOutcome(input, pick));
    assert.ok(allowed.some((o) => JSON.stringify(o) === JSON.stringify(actual)),
      `rules allow ${JSON.stringify(allowed)}, server gave ${JSON.stringify(actual)}`);
  });
}

for (const scenario of scenarios) {
  const { name, input, expected, tiedSeats, knownDivergence } = scenario;
  const run = knownDivergence ? test.skip : test;
  run(`${name}${knownDivergence ? ` [${knownDivergence}]` : ''}`, () => {
    const result = resolveNightCore({ ...input,
      lockedSeatSet: new Set(input.lockedSeatSet),
      noSilenceSeatSet: new Set(input.noSilenceSeatSet),
    });
    const actual = outcome(input, result);
    if (!tiedSeats) {
      assert.deepEqual(actual, expected);
      return;
    }
    // D17: the two engines draw a tie with different generators, so the TS
    // outcome only has to be what the rules give for one of the tied seats
    // (the pick itself is hidden once a save, a lock or a quiet night voids it).
    const allowed = tiedSeats.flatMap((pick) => ruleOutcome(input, pick));
    assert.ok(allowed.some((o) => JSON.stringify(o) === JSON.stringify(actual)),
      `no tied pick explains ${JSON.stringify(actual)}; choices ${tiedSeats}`);
  });
}
