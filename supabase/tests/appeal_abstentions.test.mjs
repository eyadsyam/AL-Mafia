import test from 'node:test';
import assert from 'node:assert/strict';
import { appealCounts, appealUpheld } from '../functions/_shared/tools.ts';
import { ballotTargetAllowed } from '../functions/_shared/ballot_candidates.ts';

test('two confirming votes and two abstentions cannot uphold an appeal', () => {
  assert.equal(ballotTargetAllowed(2, [3], null), true);
  const counted = [
    { voter: 'a', target: null, weight: 1 }, // appellant is excluded
    { voter: 'b', target: 'a', weight: 1 },
    { voter: 'c', target: 'a', weight: 1 },
    { voter: 'd', target: null, weight: 1 },
    { voter: 'e', target: null, weight: 1 },
  ];
  const { confirm, voters } = appealCounts(counted, 'a');
  assert.deepEqual({ confirm, voters }, { confirm: 2, voters: 4 });
  assert.equal(appealUpheld(confirm, voters), false);
});

test('three of four eligible voters uphold an appeal despite an abstention', () => {
  const ballots = ['a', 'a', 'a', null].map((target, i) => ({ voter: String(i), target, weight: 1 }));
  assert.deepEqual(appealCounts(ballots, 'a'), { confirm: 3, voters: 4 });
  assert.equal(appealUpheld(3, 4), true);
});
