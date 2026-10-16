import assert from 'node:assert/strict';
import { voteFingerprint } from '../functions/_shared/vote_fingerprint.ts';
import { refusalOf } from '../functions/_shared/economy_actions.ts';

const roster = [{ user_id: 'a', seat: 0, alive: true }];
const cast = [{ voter_id: 'a', target_id: null }];
const use = (id, tool_code = 'double_vote', phase_number = 1) =>
  ({ id, user_id: 'a', seat: 0, tool_code, phase: 'vote', phase_number, target_seats: [], note: null });
const original = voteFingerprint(cast, roster, [use(1)], 1);
assert.notEqual(voteFingerprint(cast, roster, [use(1), use(2)], 1), original);
assert.equal(voteFingerprint(cast, roster, [use(2), use(1)], 1),
  voteFingerprint(cast, roster, [use(1), use(2)], 1));
assert.equal(voteFingerprint(cast, roster, [use(1), use(2, 'narrator_whisper')], 1), original);
assert.equal(voteFingerprint(cast, roster, [use(1), use(2, 'appeal', 2)], 1), original);
assert.equal(voteFingerprint(cast, roster, [], 1), 'a|-#roster:a|0|1');
assert.equal(refusalOf('SILENCED'), 'SILENCED');
