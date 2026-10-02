// node supabase/tests/update101_contracts.test.mjs
// Pure edge-function contracts for 1.0.1: SSV routing, economy surface and
// Play purchase evaluation. No network, keys or database.
import assert from 'node:assert/strict';
import { routeReward, unitNumber, isUuid, COMMIT_RPC } from '../functions/_shared/ad_rewards.ts';
import { economyCall, refusalOf } from '../functions/_shared/economy_actions.ts';
import { evaluateProductPurchase, followUps } from '../functions/_shared/play_verify.ts';

const claim = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
const env = (values) => (name) => values[name];
const both = env({
  ADMOB_REWARDED_ANDROID_ID: 'ca-app-pub-9179063936085117/8711609352',
  ADMOB_REWARDED_V2_ANDROID_ID: 'ca-app-pub-9179063936085117/1111111111',
});
const primaryOnly = env({ ADMOB_REWARDED_ANDROID_ID: 'ca-app-pub-1/8711609352' });

// --- SSV routing ------------------------------------------------------------
assert.equal(unitNumber('ca-app-pub-1/8711609352'), '8711609352');
assert.equal(unitNumber(''), null);
assert.equal(unitNumber('ca-app-pub-1/abc'), null);

assert.deepEqual(routeReward(claim, '8711609352', both), { ok: true, scheme: 'v1', claimId: claim });
assert.deepEqual(routeReward(`s2:${claim}`, '1111111111', both), { ok: true, scheme: 'step', claimId: claim });
assert.deepEqual(routeReward(`d1:${claim}`, '8711609352', both), { ok: true, scheme: 'daily', claimId: claim });
// 1.0.0 claims only ever came from the primary unit.
assert.equal(routeReward(claim, '1111111111', both).ok, false);
// A prefix alone never routes: the unit must be accepted, the id well formed.
assert.equal(routeReward(`s2:${claim}`, '9999999999', both).reason, 'unit_not_accepted');
assert.equal(routeReward('s2:not-a-uuid', '1111111111', both).reason, 'bad_claim');
assert.equal(routeReward(`x9:${claim}`, '8711609352', both).reason, 'bad_claim');
assert.equal(routeReward(`s2:${claim}`, '8711609352', primaryOnly).ok, true, 'v2 falls back to primary');
assert.equal(routeReward(claim, '8711609352', env({})).reason, 'not_configured');
assert.equal(routeReward(`s2:${claim}`, null, both).ok, false);
assert.equal(COMMIT_RPC.step, 'commit_ad_step_v2');
assert.equal(isUuid('u-1'), false);
assert.equal(isUuid(claim), true);

// --- Economy surface ----------------------------------------------------------
const me = '00000000-0000-4000-8000-000000000001';
assert.deepEqual(economyCall({ action: 'capabilities' }, me), { rpc: 'economy_capabilities', args: { p_user: me } });
// The user always comes from the session, never the body.
assert.equal(economyCall({ action: 'capabilities', p_user: 'someone' }, me).args.p_user, me);
assert.deepEqual(economyCall({ action: 'ad_step_claim_v2', roomId: claim, step: 2 }, me).args,
  { p_user: me, p_room: claim, p_step: 2 });
assert.equal(economyCall({ action: 'ad_step_claim_v2', roomId: claim, step: 3 }, me), null);
assert.equal(economyCall({ action: 'ad_step_claim_v2', roomId: 'x', step: 1 }, me), null);
assert.equal(economyCall({ action: 'daily_spin', day: '2026-09-25' }, me).rpc, 'spin_daily_wheel');
assert.equal(economyCall({ action: 'daily_spin' }, me), null, 'day is required');
assert.equal(economyCall({ action: 'daily_coffer' }, me), null);
assert.equal(economyCall({ action: 'daily_ad_claim', day: null }, me), null);
assert.equal(economyCall({ action: 'daily_spin', day: '25/09/2026' }, me), null);
assert.equal(economyCall({ action: 'daily_coffer', day: '2026-09-25', amount: 999 }, me).args.amount, undefined,
  'the client cannot send amounts');
// 1.0.0 actions are unchanged.
assert.equal(economyCall({ action: 'create_ad_claim', roomId: claim }, me).rpc, 'create_ad_reward_claim');
assert.equal(economyCall({ action: 'ad_status', roomId: claim }, me).rpc, 'ad_reward_status');
assert.equal(economyCall({ action: 'buy', item: 'frame_gilded' }, me).rpc, 'buy_reward_item');
assert.equal(economyCall({ action: 'grant_coins' }, me), null);
assert.equal(refusalOf('DAY_CHANGED'), 'DAY_CHANGED');
assert.equal(refusalOf('duplicate key value'), null);

// --- Play purchase evaluation ---------------------------------------------------
const good = {
  purchaseState: 0, consumptionState: 0, acknowledgementState: 0, orderId: 'GPA.1',
  purchaseTimeMillis: '1758800000000', obfuscatedExternalAccountId: 'a'.repeat(64),
  productId: 'mm_coins_500',
};
let e = evaluateProductPurchase(good, 'mm_coins_500');
assert.equal(e.ok, true);
assert.equal(e.facts.state, 'active');
assert.equal(e.facts.quantity, 1);
assert.equal(e.facts.accountTag, 'a'.repeat(64));
assert.equal(evaluateProductPurchase(good, 'mm_coins_2500').reason, 'product_mismatch');
assert.equal(evaluateProductPurchase({ ...good, quantity: 0 }, 'mm_coins_500').reason, 'quantity');
assert.equal(evaluateProductPurchase({ ...good, quantity: 11 }, 'mm_coins_500').reason, 'quantity');
assert.equal(evaluateProductPurchase({ ...good, purchaseState: 2 }, 'mm_coins_500').facts.state, 'pending');
assert.equal(evaluateProductPurchase({ ...good, purchaseState: 1 }, 'mm_coins_500').facts.state, 'revoked');
assert.equal(evaluateProductPurchase(null, 'mm_coins_500').ok, false);

// Consume only after a durable credit; never for a pending purchase.
e = evaluateProductPurchase(good, 'mm_coins_500');
assert.deepEqual(followUps(e.facts, { needsConsume: true }), { acknowledge: false, consume: true, alreadyConsumed: false });
assert.deepEqual(followUps(e.facts, { needsConsume: false }), { acknowledge: false, consume: false, alreadyConsumed: false });
const pending = evaluateProductPurchase({ ...good, purchaseState: 2 }, 'mm_coins_500').facts;
assert.equal(followUps(pending, { needsConsume: true }).consume, false);
const consumed = evaluateProductPurchase({ ...good, consumptionState: 1 }, 'mm_coins_500').facts;
assert.deepEqual(followUps(consumed, { needsConsume: true }), { acknowledge: false, consume: false, alreadyConsumed: true });
const pass = evaluateProductPurchase({ ...good, productId: 'mm_remove_interruptions' }, 'mm_remove_interruptions').facts;
assert.equal(followUps(pass, { needsAcknowledge: true }).acknowledge, true);
assert.equal(followUps({ ...pass, acknowledged: true }, { needsAcknowledge: true }).acknowledge, false);

console.log('PASS update101 contracts: SSV routing, economy surface, Play purchase evaluation');
