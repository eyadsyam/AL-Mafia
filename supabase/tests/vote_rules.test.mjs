import test from 'node:test';
import assert from 'node:assert/strict';
import { abstentionRefused, ballotVerdict } from '../functions/_shared/vote_rules.ts';
import { lastWordOf, revoteRequested } from '../functions/_shared/tools.ts';
import { refusalOf } from '../functions/_shared/economy_actions.ts';

// ── RL9: abstention follows the room's setting ────────────────────────────
test('abstention: a null target is refused unless the room allows it', () => {
  assert.equal(abstentionRefused(null, {}), true, 'default is off');
  assert.equal(abstentionRefused(undefined, {}), true);
  assert.equal(abstentionRefused(null, { abstainAllowed: false }), true);
  assert.equal(abstentionRefused(null, { abstainAllowed: 'true' }), true, 'only a real true counts');
  assert.equal(abstentionRefused(null, { abstainAllowed: true }), false);
});

test('abstention: a vote for a seat (seat zero included) is never an abstention', () => {
  assert.equal(abstentionRefused(0, {}), false);
  assert.equal(abstentionRefused(3, { abstainAllowed: false }), false);
});

// ── RL13: a bought revote also reopens a tie ──────────────────────────────
const verdict = (over) => ballotVerdict({ round: 1, topSeats: 1, dayTieRule: 'noElimination', revoteBought: false, ...over });

test('ballot: a clear winner goes out; a bought revote reopens it in round one only', () => {
  assert.equal(verdict({}), 'eliminate');
  assert.equal(verdict({ revoteBought: true }), 'revote');
  assert.equal(verdict({ round: 2, revoteBought: true }), 'eliminate', 'round two never re-triggers');
  assert.equal(verdict({ dayTieRule: 'revote' }), 'eliminate', 'the room rule only concerns ties');
});

test('ballot: a tie under «محدش يخرج» stands, unless a revote was bought', () => {
  assert.equal(verdict({ topSeats: 2 }), 'stand');
  assert.equal(verdict({ topSeats: 3 }), 'stand');
  assert.equal(verdict({ topSeats: 2, revoteBought: true }), 'revote');
  assert.equal(verdict({ topSeats: 2, dayTieRule: undefined }), 'stand', 'an absent rule is noElimination');
});

test('ballot: a tie under the revote rule reopens with or without a purchase', () => {
  assert.equal(verdict({ topSeats: 2, dayTieRule: 'revote' }), 'revote');
  assert.equal(verdict({ topSeats: 2, dayTieRule: 'revote', revoteBought: true }), 'revote');
});

test('ballot: the second round never reopens; a second tie stands', () => {
  assert.equal(verdict({ round: 2, topSeats: 2, dayTieRule: 'revote', revoteBought: true }), 'stand');
  assert.equal(verdict({ round: 2, topSeats: 2 }), 'stand');
  assert.equal(verdict({ round: 2, topSeats: 1 }), 'eliminate');
});

test('ballot: no votes at all is nothing to decide', () => {
  assert.equal(verdict({ topSeats: 0 }), 'stand');
  assert.equal(verdict({ topSeats: 0, revoteBought: true }), 'stand');
});

test('ballot: the bought revote the verdict reads is the tool\'s own helper', () => {
  const uses = [{ tool_code: 'revote', phase_number: 2, user_id: 'u', seat: 1, phase: 'vote', target_seats: [], note: null }];
  assert.equal(revoteRequested(uses, 2), true);
  assert.equal(revoteRequested(uses, 3), false);
  assert.equal(verdict({ topSeats: 2, revoteBought: revoteRequested(uses, 2) }), 'revote');
  assert.equal(verdict({ topSeats: 2, revoteBought: revoteRequested(uses, 3) }), 'stand');
});

// ── RL15: the last word of the player voted out ───────────────────────────
const lastWordUse = (over) => ({
  tool_code: 'last_word', phase_number: 2, user_id: 'u3', seat: 3, phase: 'vote', target_seats: [1], note: null, ...over,
});

test('last word: the eliminated seat\'s own last word names who speaks first', () => {
  assert.deepEqual(lastWordOf([lastWordUse({})], 2, 3), { seat: 3, target: 1 });
  assert.deepEqual(lastWordOf([lastWordUse({ target_seats: [0] })], 2, 3), { seat: 3, target: 0 }, 'seat zero is a seat');
});

test('last word: nothing when nobody was eliminated, or somebody else was', () => {
  assert.equal(lastWordOf([lastWordUse({})], 2, null), null);
  assert.equal(lastWordOf([lastWordUse({})], 2, 4), null);
});

test('last word: only the day it was bought and only that tool', () => {
  assert.equal(lastWordOf([lastWordUse({})], 3, 3), null);
  assert.equal(lastWordOf([lastWordUse({ tool_code: 'spotlight' })], 2, 3), null);
  assert.equal(lastWordOf([], 2, 3), null);
});

test('last word: a malformed target names nobody', () => {
  assert.equal(lastWordOf([lastWordUse({ target_seats: [] })], 2, 3), null);
  assert.equal(lastWordOf([lastWordUse({ target_seats: null })], 2, 3), null);
});

// ── RL14: the refusal the client can act on ───────────────────────────────
test('floor tools in free talk: the refusal code reaches the client', () => {
  assert.equal(refusalOf('NOT_THIS_ROOM'), 'NOT_THIS_ROOM');
  assert.equal(refusalOf('P0001: NOT_THIS_ROOM'), 'NOT_THIS_ROOM');
  assert.equal(refusalOf('NOT_PLAYING'), 'NOT_PLAYING', 'neighbours keep their own code');
});
