// node supabase/tests/ads_v2.test.mjs
// Phase 108 edge contracts: the `x1:` SSV route for the voluntary extras and
// the economy actions that create them. v1 / step / daily routing is asserted
// unchanged. No network, keys or database.
import assert from 'node:assert/strict';
import { routeReward, COMMIT_RPC } from '../functions/_shared/ad_rewards.ts';
import { economyCall, refusalOf } from '../functions/_shared/economy_actions.ts';

const claim = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
const env = (values) => (name) => values[name];
const both = env({
  ADMOB_REWARDED_ANDROID_ID: 'ca-app-pub-9179063936085117/8711609352',
  ADMOB_REWARDED_V2_ANDROID_ID: 'ca-app-pub-9179063936085117/1111111111',
});
const primaryOnly = env({ ADMOB_REWARDED_ANDROID_ID: 'ca-app-pub-1/8711609352' });

// --- x1: extras ---------------------------------------------------------------
assert.deepEqual(routeReward(`x1:${claim}`, '1111111111', both),
  { ok: true, scheme: 'extra', claimId: claim });
assert.deepEqual(routeReward(`x1:${claim}`, '8711609352', both),
  { ok: true, scheme: 'extra', claimId: claim }, 'primary unit also accepted');
assert.equal(routeReward(`x1:${claim}`, '8711609352', primaryOnly).ok, true, 'falls back to primary');
assert.equal(routeReward(`x1:${claim}`, '9999999999', both).reason, 'unit_not_accepted');
assert.equal(routeReward(`x1:${claim}`, null, both).ok, false);
assert.equal(routeReward('x1:not-a-uuid', '1111111111', both).reason, 'bad_claim');
assert.equal(routeReward('x1:', '1111111111', both).reason, 'bad_claim');
assert.equal(routeReward(`x1:${claim}`, '1111111111', env({})).reason, 'not_configured');
assert.equal(routeReward(`x1:${claim.toUpperCase()}`, '1111111111', both).claimId, claim);
assert.equal(COMMIT_RPC.extra, 'commit_ad_extra');

// --- earlier schemes byte-identical ------------------------------------------
assert.deepEqual(routeReward(claim, '8711609352', both), { ok: true, scheme: 'v1', claimId: claim });
assert.equal(routeReward(claim, '1111111111', both).ok, false, 'v1 only on the primary unit');
assert.deepEqual(routeReward(`s2:${claim}`, '1111111111', both), { ok: true, scheme: 'step', claimId: claim });
assert.deepEqual(routeReward(`d1:${claim}`, '8711609352', both), { ok: true, scheme: 'daily', claimId: claim });
assert.equal(routeReward(`x2:${claim}`, '8711609352', both).reason, 'bad_claim');
assert.deepEqual(COMMIT_RPC, {
  v1: 'commit_ad_reward', step: 'commit_ad_step_v2', daily: 'commit_daily_ad', extra: 'commit_ad_extra',
});

// --- economy surface -----------------------------------------------------------
const me = '00000000-0000-4000-8000-000000000001';
const d = '2026-09-26';
assert.deepEqual(economyCall({ action: 'extras_status' }, me), { rpc: 'ad_extras_status', args: { p_user: me } });
assert.deepEqual(economyCall({ action: 'extra_claim', day: d, kind: 'spin' }, me),
  { rpc: 'create_ad_extra_claim', args: { p_user: me, p_day: d, p_kind: 'spin', p_slot: null } });
assert.deepEqual(economyCall({ action: 'extra_claim', day: d, kind: 'coffer', slot: 2 }, me).args,
  { p_user: me, p_day: d, p_kind: 'coffer', p_slot: null }, 'slot ignored for coffer');
assert.deepEqual(economyCall({ action: 'extra_claim', day: d, kind: 'swap', slot: 1 }, me).args,
  { p_user: me, p_day: d, p_kind: 'swap', p_slot: 1 });
assert.equal(economyCall({ action: 'extra_claim', day: d, kind: 'swap' }, me), null, 'swap needs a slot');
assert.equal(economyCall({ action: 'extra_claim', day: d, kind: 'swap', slot: 3 }, me), null);
assert.equal(economyCall({ action: 'extra_claim', day: d, kind: 'jackpot' }, me), null);
assert.equal(economyCall({ action: 'extra_claim', kind: 'spin' }, me), null, 'day required');
assert.equal(economyCall({ action: 'extra_claim', day: 'today', kind: 'spin' }, me), null);
assert.equal(economyCall({ action: 'extra_claim', day: d, kind: 'spin', p_user: 'x' }, me).args.p_user, me);
assert.equal(economyCall({ action: 'extra_claim', day: d, kind: 'coffer', amount: 999 }, me).args.amount, undefined);
assert.equal(refusalOf('EXTRA_NOT_READY'), 'EXTRA_NOT_READY');
assert.equal(refusalOf('IN_MATCH'), 'IN_MATCH');

console.log('PASS ads_v2 contracts: x1 SSV route, extras surface, earlier schemes unchanged');
