import test from 'node:test';
import assert from 'node:assert/strict';
import { resolveNightCore } from '../functions/_shared/night_core.ts';
import { detectiveSees, unsilenceable } from '../functions/_shared/tools.ts';

const roster = [
  { user_id: 'm', seat: 0, role: 'mafia', alive: true },
  { user_id: 's', seat: 1, role: 'silencer', alive: true },
  { user_id: 'd', seat: 2, role: 'doctor', alive: true },
  { user_id: 'n', seat: 3, role: 'sniper', alive: true },
  { user_id: 'a', seat: 4, role: 'citizen', alive: true },
  { user_id: 'b', seat: 5, role: 'citizen', alive: true },
];
const move = (actor_id, action, target_id, used_bullet = false) =>
  ({ actor_id, action, target_id, used_bullet });
const night = (actions, overrides = {}) => resolveNightCore({
  roster, actions, matchSeed: 31415, night: 1, settings: {},
  lockedSeatSet: new Set(), noSilenceSeatSet: new Set(), ...overrides,
});

test('M2-2: living non-team Mafia target dies', () => {
  assert.deepEqual(night([move('m', 'kill', 'a')]).deathIds, ['a']);
});

test('M2-8: split Mafia vote is seeded and independent of action order', () => {
  const twoMafia = roster.map((p) => p.user_id === 's' ? { ...p, role: 'mafia' } : p);
  const first = night([move('m', 'kill', 'b'), move('s', 'kill', 'a')], { roster: twoMafia });
  const reversed = night([move('s', 'kill', 'a'), move('m', 'kill', 'b')], { roster: twoMafia });
  assert.ok(['a', 'b'].includes(first.victimId));
  assert.equal(first.victimId, reversed.victimId);
  assert.deepEqual(first.deathIds, reversed.deathIds);
});

test('M2-14: Doctor blocks Mafia kill but cannot block a Sniper shot', () => {
  const actions = [move('m', 'kill', 'a'), move('d', 'protect', 'a')];
  assert.deepEqual(night(actions).deathIds, []);
  const shot = night([...actions, move('n', 'suspect', 'a', true)]);
  assert.deepEqual(shot.deathIds, ['n', 'a']);
  assert.equal(shot.savedId, null);
});

test('M2-32: protection does not clear silence; doors and shield block it', () => {
  const actions = [move('d', 'protect', 'a'), move('s', 'silence', 'a')];
  assert.equal(night(actions).silencedId, 'a');
  const use = (tool_code) => ({ user_id: 'a', seat: 4, tool_code,
    phase: 'day', phase_number: 0, target_seats: [], note: null });
  for (const code of ['lock_door', 'half_door', 'vote_shield']) {
    assert.ok(unsilenceable([use(code)], 1).has(4), code);
    assert.equal(night(actions, { noSilenceSeatSet: unsilenceable([use(code)], 1) }).silencedId, null, code);
  }
});

test('M2-44: tied Doctors cover one seeded seat and only stop Mafia kill', () => {
  const twoDoctors = roster.map((p) => p.user_id === 'b' ? { ...p, role: 'doctor' } : p);
  const covers = [move('d', 'protect', 'a'), move('b', 'protect', 'n')];
  const saveA = night([move('m', 'kill', 'a'), ...covers], { roster: twoDoctors });
  const saveN = night([move('m', 'kill', 'n'), ...covers], { roster: twoDoctors });
  assert.equal(Number(saveA.savedId === 'a') + Number(saveN.savedId === 'n'), 1);
  const shot = night([...covers, move('n', 'suspect', 'a', true)], { roster: twoDoctors });
  assert.ok(shot.deathIds.includes('a'));
});

test('M2-46: dead Doctor protection stands; shot victim is not a save', () => {
  const actions = [move('m', 'kill', 'a'), move('d', 'protect', 'a'), move('n', 'suspect', 'd', true)];
  const result = night(actions);
  assert.deepEqual(result.deathIds, ['d', 'n']);
  assert.equal(result.savedId, 'a');
  const shotSaved = night([move('m', 'kill', 'a'), move('d', 'protect', 'a'), move('n', 'suspect', 'a', true)]);
  assert.equal(shotSaved.savedId, null);
  assert.equal(shotSaved.saveTold, false);
});

test('M2-60: door, impersonation, camouflage precedence changes private answer', () => {
  const use = (tool_code, note = null) => ({ user_id: 'm', seat: 0, tool_code,
    phase: 'day', phase_number: 0, target_seats: [], note });
  assert.equal(detectiveSees([], 1, 0, 'mafia'), 'mafia');
  assert.equal(detectiveSees([use('camouflage')], 1, 0, 'mafia'), 'unclear');
  assert.equal(detectiveSees([use('camouflage'), use('impersonate', 'citizen')], 1, 0, 'mafia'), 'citizen');
  for (const door of ['half_door', 'lock_door']) {
    assert.equal(detectiveSees([use(door), use('impersonate', 'citizen')], 1, 0, 'mafia'), 'unreachable');
  }
});

test('M2-82: shooting Mafia team kills target only; shooting town also kills Sniper', () => {
  for (const target of ['m', 's']) assert.deepEqual(night([move('n', 'suspect', target, true)]).deathIds, [target]);
  assert.deepEqual(night([move('n', 'suspect', 'a', true)]).deathIds, ['n', 'a']);
});

test('M2-84: shot survives Doctor cover and dead shooter; overlapping deaths deduplicate', () => {
  const result = night([move('m', 'kill', 'n'), move('d', 'protect', 'a'), move('n', 'suspect', 'a', true)]);
  assert.deepEqual(result.deathIds, ['n', 'a']);
  const overlap = night([move('m', 'kill', 'a'), move('n', 'suspect', 'a', true)]);
  assert.deepEqual(overlap.deathIds, ['n', 'a']);
});
