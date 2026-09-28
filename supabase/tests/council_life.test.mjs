// node supabase/tests/council_life.test.mjs
// Phase 107 edge contract: Council Life actions route to the right RPC with
// validated input, the caller always from the session. No network or keys.
import assert from 'node:assert/strict';
import { economyCall, refusalOf } from '../functions/_shared/economy_actions.ts';

const me = '00000000-0000-4000-8000-000000000001';
const other = '00000000-0000-4000-8000-000000000002';

for (const [action, rpc] of [
  ['contracts_get', 'council_contracts'], ['rank_get', 'council_rank'],
  ['leaderboard_get', 'council_leaderboard'], ['invite_get', 'council_invite'],
]) {
  // A user id in the body is ignored.
  assert.deepEqual(economyCall({ action, userId: other, p_user: other }, me),
    { rpc, args: { p_user: me } });
}

assert.deepEqual(economyCall({ action: 'contract_claim', day: '2026-09-25', slot: 2 }, me),
  { rpc: 'claim_council_contract', args: { p_user: me, p_day: '2026-09-25', p_slot: 2 } });
assert.equal(economyCall({ action: 'contract_claim', slot: 0 }, me), null, 'day required');
assert.equal(economyCall({ action: 'contract_claim', day: '25-09-2026', slot: 0 }, me), null);
assert.equal(economyCall({ action: 'contract_claim', day: '2026-09-25', slot: 3 }, me), null);
assert.equal(economyCall({ action: 'contract_claim', day: '2026-09-25', slot: '0' }, me), null);
assert.equal(economyCall({ action: 'contract_claim', day: '2026-09-25' }, me), null);

assert.deepEqual(economyCall({ action: 'weekly_claim', week: '2026-W39' }, me),
  { rpc: 'claim_council_weekly', args: { p_user: me, p_week: '2026-W39' } });
assert.equal(economyCall({ action: 'weekly_claim' }, me), null, 'week required');
assert.equal(economyCall({ action: 'weekly_claim', week: '2026-39' }, me), null);

assert.deepEqual(economyCall({ action: 'invite_redeem', code: ' abcdefg ' }, me),
  { rpc: 'redeem_council_invite', args: { p_user: me, p_code: 'ABCDEFG' } });
assert.equal(economyCall({ action: 'invite_redeem', code: 'ABCDEF' }, me), null, 'short');
assert.equal(economyCall({ action: 'invite_redeem', code: 'ABCDEF0' }, me), null, 'ambiguous 0');
assert.equal(economyCall({ action: 'invite_redeem', code: 'ABCDEFGH' }, me), null, 'long');
assert.equal(economyCall({ action: 'invite_redeem', code: 7 }, me), null);
assert.equal(economyCall({ action: 'invite_redeem' }, me), null);

for (const code of ['CONTRACT_INCOMPLETE', 'WEEK_CHANGED', 'WEEK_REQUIRED', 'INVITE_SELF',
  'INVITE_EXPIRED', 'INVITE_NOT_NEW', 'INVITE_ALREADY', 'INVITE_LOOP', 'INVITE_LIMIT',
  'INVITE_RATE_LIMIT', 'DAY_CHANGED', 'FEATURE_OFF']) {
  assert.equal(refusalOf(`P0001: ${code}`), code, code);
}

assert.deepEqual(economyCall({ action: 'leaderboard_visibility', visible: false }, me),
  { rpc: 'set_council_leaderboard_visible', args: { p_user: me, p_visible: false } });
assert.equal(economyCall({ action: 'leaderboard_visibility', visible: 'no' }, me), null);
assert.equal(economyCall({ action: 'leaderboard_visibility' }, me), null);

// Row 6: invite notice acknowledgement takes 1..50 positive integer ids.
assert.deepEqual(economyCall({ action: 'invite_ack', ids: [3, 9] }, me),
  { rpc: 'invite_notices_ack', args: { p_user: me, p_ids: [3, 9] } });
assert.equal(economyCall({ action: 'invite_ack', ids: [] }, me), null, 'empty');
assert.equal(economyCall({ action: 'invite_ack', ids: [0] }, me), null, 'zero');
assert.equal(economyCall({ action: 'invite_ack', ids: ['1'] }, me), null, 'string id');
assert.equal(economyCall({ action: 'invite_ack', ids: [1.5] }, me), null, 'fraction');
assert.equal(economyCall({ action: 'invite_ack', ids: Array.from({ length: 51 }, (_, i) => i + 1) }, me),
  null, 'more than 50');
assert.equal(economyCall({ action: 'invite_ack', ids: 7, userId: other }, me), null, 'not a list');

// D7: resultSummary{roomId,requestId} is the room summary; without a
// request id it stays the older one; a malformed id or missing room refuses.
const rid = '00000000-0000-4000-8000-0000000000aa';
const req = '00000000-0000-4000-8000-0000000000BB';
assert.deepEqual(economyCall({ action: 'resultSummary', roomId: rid, requestId: req }, me),
  { rpc: 'result_summary_room', args: { p_user: me, p_room: rid, p_request: req.toLowerCase() } });
assert.deepEqual(economyCall({ action: 'resultSummary', roomId: rid }, me),
  { rpc: 'result_summary', args: { p_user: me } });
assert.equal(economyCall({ action: 'resultSummary', requestId: req }, me), null, 'no room');
assert.equal(economyCall({ action: 'resultSummary', roomId: rid, requestId: 'x' }, me), null, 'bad id');

// Old actions are unchanged.
assert.deepEqual(economyCall({ action: 'daily_status' }, me), { rpc: 'daily_status', args: { p_user: me } });
console.log('council_life contracts: PASS');
