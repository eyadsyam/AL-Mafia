import test from 'node:test';
import assert from 'node:assert/strict';
import { micPolicyFor, micPolicyForSeat, spotlightTarget } from '../functions/_shared/voice.ts';

// RL8 / D10 (server half): the seat the Silencer silenced has a closed mic for
// the whole day, in every discussion mode.
const silenced = { morning: { silencedSeat: 2 } };
const free = { discussionMode: 'free' };
const turns = { discussionMode: 'structured' };

test('phase policy is unchanged for everybody', () => {
  assert.equal(micPolicyFor('discuss', free), 'open');
  assert.equal(micPolicyFor('discuss', turns), 'activeSpeakerOnly');
  assert.equal(micPolicyFor('discuss', {}), 'activeSpeakerOnly', 'by turns is the default');
  assert.equal(micPolicyFor('night', free), 'muted');
});

test('free discussion: the silenced seat is muted, the others stay open', () => {
  assert.equal(micPolicyForSeat('discuss', free, silenced, 2), 'muted');
  assert.equal(micPolicyForSeat('discuss', free, silenced, 1), 'open');
  assert.equal(micPolicyForSeat('discuss', free, silenced, 0), 'open');
});

test('talk by turns: the silenced seat is muted, the others keep the floor rule', () => {
  assert.equal(micPolicyForSeat('discuss', turns, silenced, 2), 'muted');
  assert.equal(micPolicyForSeat('discuss', turns, silenced, 1), 'activeSpeakerOnly');
});

test('every day phase where people talk closes the silenced seat\'s mic', () => {
  for (const phase of ['opening', 'confront', 'discuss', 'defense']) {
    for (const settings of [free, turns, {}]) {
      assert.equal(micPolicyForSeat(phase, settings, silenced, 2), 'muted', `${phase}`);
      assert.equal(micPolicyForSeat(phase, settings, silenced, 3), micPolicyFor(phase, settings), `${phase} others`);
    }
  }
});

test('phases that are already muted stay muted; the lobby and the result are not "that day"', () => {
  for (const phase of ['reveal', 'night', 'morning', 'vote']) {
    assert.equal(micPolicyForSeat(phase, free, silenced, 2), 'muted');
    assert.equal(micPolicyForSeat(phase, free, silenced, 1), 'muted');
  }
  assert.equal(micPolicyForSeat('lobby', free, silenced, 2), 'open');
  assert.equal(micPolicyForSeat('result', free, silenced, 2), 'open');
});

test('no silence, seat zero and malformed data silence nobody', () => {
  for (const data of [null, undefined, {}, { morning: null }, { morning: {} }, { morning: { silencedSeat: null } },
    { morning: { silencedSeat: '2' } }, { morning: { silencedSeat: -1 } }]) {
    assert.equal(micPolicyForSeat('discuss', free, data, 0), 'open');
    assert.equal(micPolicyForSeat('discuss', free, data, 2), 'open');
  }
  assert.equal(micPolicyForSeat('discuss', free, { morning: { silencedSeat: 0 } }, 0), 'muted', 'seat zero can be silenced');
  assert.equal(micPolicyForSeat('discuss', free, { morning: { silencedSeat: 0 } }, 1), 'open');
});

test('spotlight priority: earliest unconsumed eligible use names the next speaker', () => {
  const uses = [
    { id: 3, tool_code: 'spotlight', phase_number: 2, target_seats: [3], consumed_at: null },
    { id: 1, tool_code: 'spotlight', phase_number: 2, target_seats: [1], consumed_at: 'used' },
    { id: 2, tool_code: 'spotlight', phase_number: 2, target_seats: [2], consumed_at: null },
  ];
  const living = new Set([0, 2, 3]);
  assert.equal(spotlightTarget(uses, 2, living, null), 2);
  assert.equal(spotlightTarget(uses, 2, living, 2), 3);
  assert.equal(spotlightTarget(uses, 1, living, null), null);
  assert.equal(spotlightTarget(uses, 2, new Set([0]), null), null);
});
