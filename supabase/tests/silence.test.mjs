import test from 'node:test';
import assert from 'node:assert/strict';
import { silencedSeatOf } from '../functions/_shared/silence.ts';

test('an ordinary morning leaves seat zero eligible to vote and speak', () => {
  for (const data of [null, undefined, {}, { morning: null }, { morning: {} },
    { morning: { silencedSeat: null } }]) {
    assert.equal(silencedSeatOf(data), null);
    assert.notEqual(silencedSeatOf(data), 0);
    assert.deepEqual([0, 1, 2].filter(seat => seat !== silencedSeatOf(data)), [0, 1, 2]);
  }
});

test('actual silence includes seat zero and excludes only its target', () => {
  for (const target of [0, 1, 2]) {
    const data = { morning: { silencedSeat: target } };
    assert.equal(silencedSeatOf(data), target);
    assert.equal([0, 1, 2].filter(seat => seat !== silencedSeatOf(data)).length, 2);
  }
});

test('malformed targets never coerce to seat zero', () => {
  for (const seat of ['', '0', false, true, -1, 0.5, [], {}]) {
    assert.equal(silencedSeatOf({ morning: { silencedSeat: seat } }), null);
  }
});
