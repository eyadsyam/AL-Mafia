// node supabase/tests/awards_reactions.test.mjs
// Phase 109 edge contracts: the economy actions for awards, reactions and the
// Founder badge. No network, keys or database.
import assert from 'node:assert/strict';
import { economyCall, refusalOf } from '../functions/_shared/economy_actions.ts';

const me = '11111111-1111-4111-8111-111111111111';
const room = '7c9e6679-7425-40de-944b-e07fc1f90ae7';

assert.deepEqual(economyCall({ action: 'awards_get', roomId: room }, me),
  { rpc: 'match_awards_get', args: { p_user: me, p_room: room } });
assert.equal(economyCall({ action: 'awards_get' }, me), null, 'room required');
assert.equal(economyCall({ action: 'awards_get', roomId: 'nope' }, me), null, 'uuid only');

for (const kind of ['laugh', 'shock', 'suspicious', 'applause', 'rose', 'skull', 'coffee', 'crown']) {
  assert.deepEqual(economyCall({ action: 'react', roomId: room, kind }, me),
    { rpc: 'send_room_reaction', args: { p_user: me, p_room: room, p_kind: kind } });
}
assert.equal(economyCall({ action: 'react', roomId: room, kind: 'fireworks' }, me), null);
assert.equal(economyCall({ action: 'react', roomId: room }, me), null, 'kind required');
assert.equal(economyCall({ action: 'react', kind: 'laugh' }, me), null, 'room required');
// The caller always comes from the session, never the body.
assert.equal(economyCall({ action: 'react', roomId: room, kind: 'rose', p_user: 'x' }, me).args.p_user, me);

assert.deepEqual(economyCall({ action: 'fun_profile' }, me),
  { rpc: 'fun_profile', args: { p_user: me } });

for (const code of ['REACTION_RATE_LIMIT', 'REACTION_CLOSED', 'REACTION_UNKNOWN', 'NOT_MEMBER']) {
  assert.equal(refusalOf(`ERROR: ${code}`), code);
}
console.log('PASS awards_reactions edge contracts');
