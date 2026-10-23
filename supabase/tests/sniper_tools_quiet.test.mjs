import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolveNightCore } from '../functions/_shared/night_core.ts';
import {
  detectiveSees, halfDoorSeats, lockedSeats, unsilenceable, whisperAnswer,
} from '../functions/_shared/tools.ts';
import { nightDefaultFor } from '../functions/_shared/night_rules.ts';
import { selectTrace, TRACE_NONE } from '../functions/_shared/trace.ts';
import { selectConfrontation } from '../functions/_shared/confrontation.ts';

const player = (seat, role) => ({ user_id: `u${seat}`, seat, role, alive: true });
const action = (actor, kind, target, bullet = null) => ({
  actor_id: `u${actor}`, action: kind,
  target_id: target === null ? null : `u${target}`, used_bullet: bullet,
});
const use = (seat, tool_code, note = null) => ({
  user_id: `u${seat}`, seat, tool_code, phase: 'discuss', phase_number: 1,
  target_seats: [], note,
});
const night = (roster, actions, uses = []) => resolveNightCore({
  roster, actions, matchSeed: 17, night: 2, settings: {},
  lockedSeatSet: lockedSeats(uses, 2),
  noSilenceSeatSet: unsilenceable(uses, 2),
});
const seats = (ids) => ids.map((id) => Number(id.slice(1)));

// N57/N58: every town role takes the Sniper with it.
for (const role of ['citizen', 'doctor', 'detective', 'elder', 'sniper']) {
  test(`N57/N58: Sniper shooting ${role} produces both deaths`, () => {
    const roster = [player(0, 'mafia'), player(1, 'sniper'), player(2, role),
      player(3, 'citizen'), player(4, 'citizen')];
    const result = night(roster, [action(1, 'suspect', 2, true)]);
    assert.deepEqual(seats(result.deathIds), [1, 2]);
    assert.equal(result.victimId, null);
    assert.equal(result.savedId, null);
    assert.equal(result.silencedId, null);

    // The full public morning payload has both names and no explanation.
    const publicPayload = {
      morning: {
        victimSeat: seats(result.deathIds)[0],
        victimSeats: seats(result.deathIds),
        silencedSeat: null, someoneSavedUnnamed: false, trace: null,
      },
      outcome: null,
    };
    const publicText = JSON.stringify(publicPayload);
    assert.deepEqual(publicPayload.morning.victimSeats, [1, 2]);
    assert.doesNotMatch(publicText,
      /citizen|doctor|detective|elder|sniper|mafia|suspect|shot|miss|bullet|tool|half_door|lock_door/i);
    assert.doesNotMatch(publicText, /\b(?:3|4)\b/);
  });
}

test('W6: parity is decided after both Sniper-town deaths', () => {
  const roster = [player(0, 'mafia'), player(1, 'sniper'), player(2, 'citizen'),
    player(3, 'citizen')];
  const result = night(roster, [action(1, 'suspect', 2, true)]);
  const living = roster.filter((p) => !result.deathIds.includes(p.user_id));
  assert.deepEqual(seats(result.deathIds), [1, 2]);
  const afterTargetOnly = roster.filter((p) => p.seat !== 2);
  assert.equal(afterTargetOnly.filter((p) => p.role === 'mafia').length >=
    afterTargetOnly.filter((p) => p.role !== 'mafia').length, false);
  assert.deepEqual(living.map((p) => p.role), ['mafia', 'citizen']);
  assert.equal(living.filter((p) => p.role === 'mafia').length >=
    living.filter((p) => p.role !== 'mafia').length, true);
});

test('T8: half door blocks silence, but kill and Sniper shot still land', () => {
  const roster = [player(0, 'mafia'), player(1, 'sniper'), player(2, 'citizen'),
    player(3, 'silencer')];
  const half = [use(2, 'half_door')];
  assert.deepEqual(seats(night(roster, [action(3, 'silence', 2)], half).deathIds), []);
  assert.equal(night(roster, [action(3, 'silence', 2)], half).silencedId, null);
  assert.deepEqual(seats(night(roster, [action(0, 'kill', 2)], half).deathIds), [2]);
  assert.deepEqual(seats(night(roster, [action(1, 'suspect', 2, true)], half).deathIds), [1, 2]);
  const joined = night(roster, [action(0, 'kill', 2), action(1, 'suspect', 2, true),
    action(3, 'silence', 2)], half);
  assert.deepEqual(seats(joined.deathIds), [1, 2]);
  assert.equal(joined.silencedId, null);
});

test('T25: lock dominates half door for a simultaneous kill, shot and silence', () => {
  const roster = [player(0, 'mafia'), player(1, 'sniper'), player(2, 'citizen'),
    player(3, 'silencer')];
  const uses = [use(2, 'half_door'), use(2, 'lock_door')];
  assert.deepEqual([...lockedSeats(uses, 2)], [2]);
  assert.deepEqual([...halfDoorSeats(uses, 2)], [2]);
  const result = night(roster, [action(0, 'kill', 2),
    action(1, 'suspect', 2, true), action(3, 'silence', 2)], uses);
  assert.deepEqual(result.deathIds, []);
  assert.equal(result.silencedId, null);
});

// T12-T14/T25: all tool pairs and triples use one true Mafia seat.
const codes = ['lock_door', 'half_door', 'camouflage', 'impersonate'];
for (let mask = 1; mask < 1 << codes.length; mask++) {
  const chosen = codes.filter((_, i) => mask & (1 << i));
  if (chosen.length < 2 || chosen.length > 3) continue;
  test(`T12-T14/T25: ${chosen.join(' + ')} keeps private truth`, () => {
    const uses = chosen.map((code) => use(2, code, code === 'impersonate' ? 'citizen' : null));
    const door = chosen.includes('half_door') || chosen.includes('lock_door');
    const expectedFace = door ? 'unreachable' : chosen.includes('impersonate')
      ? 'citizen' : 'unclear';
    assert.equal(detectiveSees(uses, 2, 2, 'mafia'), expectedFace);
    for (const tool_code of ['sense', 'narrator_whisper']) {
      const privateUse = { ...use(4, tool_code), phase: 'night', phase_number: 2,
        target_seats: tool_code === 'sense' ? [1, 2, 3] : [1, 2] };
      const roles = { 1: 'citizen', 2: 'mafia', 3: 'doctor' };
      assert.equal(whisperAnswer(privateUse, (seat) => roles[seat] ?? null), true);
      const allTown = { 1: 'citizen', 2: 'elder', 3: 'doctor' };
      assert.equal(whisperAnswer(privateUse, (seat) => allTown[seat] ?? null), false);
    }
  });
}

test('N53/N54: online Citizen has no default row; Elder gets a skip row', () => {
  const roster = [player(0, 'citizen'), player(1, 'elder'), player(2, 'mafia')];
  assert.equal(nightDefaultFor(roster[0], roster, new Set()), 'skip');
  assert.equal(nightDefaultFor(roster[1], roster, new Set()), 'skip');
  const source = readFileSync(new URL('../functions/advance_phase/index.ts', import.meta.url), 'utf8');
  assert.match(source, /if \(player\.role === "citizen"\) continue;/);
  assert.doesNotMatch(source, /if \(player\.role === "elder"\) continue;/);
});

const emptyNight = {
  nightNumber: 2, suspicions: {}, victim: null, saveOccurred: false,
  savedSeat: null, revealedTrace: null, resolved: true,
};

test('T-E1 / doc 09 T0: no eligible trace yields the T0 fallback, never invents one', () => {
  const trace = selectTrace({ night: emptyNight, history: [], alive: [0, 1, 2],
    nightNumber: 2, matchSeed: 17 });
  assert.deepEqual(trace, TRACE_NONE, `expected TRACE_NONE; actual ${JSON.stringify(trace)}`);
});

test('D3: no eligible confrontation produces no public line', () => {
  const confrontation = selectConfrontation({
    history: { nights: [emptyNight], days: [], alive: [0, 1, 2] },
    dayNumber: 2, matchSeed: 17,
    settings: { whisperEnabled: true, survivorConfrontationEnabled: true },
  });
  assert.equal(confrontation, null);
  assert.deepEqual({ confrontation }, { confrontation: null });
});
