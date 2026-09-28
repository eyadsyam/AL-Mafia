// node supabase/tests/casebook.test.mjs
// Casebook edge routing: validated identifiers/periods, session-owned user id.
import assert from 'node:assert/strict';
import { economyCall, refusalOf } from '../functions/_shared/economy_actions.ts';

const me = '00000000-0000-4000-8000-000000000001';
const attacker = '00000000-0000-4000-8000-000000000002';

assert.deepEqual(economyCall({ action: 'missionHub', p_user: attacker }, me),
  { rpc: 'mission_hub', args: { p_user: me } });

assert.deepEqual(economyCall({
  action: 'missionClaim', layer: 'daily', period: '2026-09-28', slot: 2, userId: attacker,
}, me), {
  rpc: 'claim_mission',
  args: { p_user: me, p_layer: 'daily', p_period: '2026-09-28', p_slot: 2 },
});
assert.deepEqual(economyCall({
  action: 'missionClaim', layer: 'weekly', period: '2026-W40', slot: 0,
}, me), {
  rpc: 'claim_mission',
  args: { p_user: me, p_layer: 'weekly', p_period: '2026-W40', p_slot: 0 },
});

for (const body of [
  { action: 'missionClaim', layer: 'daily', period: '2026-W40', slot: 0 },
  { action: 'missionClaim', layer: 'weekly', period: '2026-09-28', slot: 0 },
  { action: 'missionClaim', layer: 'weekly', period: '2026-W40', slot: 1 },
  { action: 'missionClaim', layer: 'daily', period: '2026-09-28', slot: '0' },
  { action: 'missionClaim', layer: 'season', period: '2026-W40', slot: 0 },
]) assert.equal(economyCall(body, me), null, JSON.stringify(body));

assert.deepEqual(economyCall({ action: 'seasonClaim', season: 'season_zero', level: 20 }, me), {
  rpc: 'claim_season_reward',
  args: { p_user: me, p_season: 'season_zero', p_level: 20 },
});
for (const level of [0, 21, 2.5, '2', null]) {
  assert.equal(economyCall({ action: 'seasonClaim', season: 'season_zero', level }, me), null);
}
assert.equal(economyCall({ action: 'seasonClaim', season: '../zero', level: 2 }, me), null);

assert.deepEqual(economyCall({ action: 'achievementClaim', code: 'first_case' }, me), {
  rpc: 'claim_achievement', args: { p_user: me, p_code: 'first_case' },
});
assert.equal(economyCall({ action: 'achievementClaim', code: 'FIRST CASE' }, me), null);
assert.equal(economyCall({ action: 'achievementClaim', code: 1 }, me), null);

for (const code of ['DISABLED', 'NOT_READY', 'PERIOD_CHANGED', 'SEASON_CLOSED',
  'NOT_FOUND', 'ALREADY_CLAIMED', 'BAD_REQUEST']) {
  assert.equal(refusalOf(`P0001: ${code}`), code, code);
}

console.log('PASS casebook edge contracts');
