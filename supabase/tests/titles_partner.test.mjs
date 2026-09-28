// node supabase/tests/titles_partner.test.mjs
// F10 edge routing: titleHub/titleEquip/roomTitles/partnerGet/partnerSet take
// the caller from the session, validate every field, and require request ids
// on mutations.
import assert from 'node:assert/strict';
import { economyCall } from '../functions/_shared/economy_actions.ts';

const me = '00000000-0000-4000-8000-000000000001';
const attacker = '00000000-0000-4000-8000-000000000002';
const req = '00000000-0000-4000-8000-0000000000AB';
const room = '00000000-0000-4000-8000-0000000000CD';

assert.deepEqual(economyCall({ action: 'titleHub', p_user: attacker }, me),
  { rpc: 'title_hub', args: { p_user: me } });
assert.deepEqual(economyCall({ action: 'titleEquip', code: 'kabir_elshella', requestId: req }, me),
  { rpc: 'title_equip', args: { p_user: me, p_code: 'kabir_elshella', p_request: req.toLowerCase() } });
assert.deepEqual(economyCall({ action: 'titleEquip', code: null, requestId: req }, me),
  { rpc: 'title_equip', args: { p_user: me, p_code: null, p_request: req.toLowerCase() } }, 'unequip');
assert.equal(economyCall({ action: 'titleEquip', code: 'kabir_elshella' }, me), null, 'no request id');
assert.equal(economyCall({ action: 'titleEquip', requestId: req }, me), null, 'code missing (not null)');
assert.equal(economyCall({ action: 'titleEquip', code: 'Bad Code', requestId: req }, me), null);
assert.equal(economyCall({ action: 'titleEquip', code: 'x'.repeat(61), requestId: req }, me), null);

assert.deepEqual(economyCall({ action: 'roomTitles', roomId: room }, me),
  { rpc: 'room_titles', args: { p_user: me, p_room: room } });
assert.equal(economyCall({ action: 'roomTitles', roomId: 'nope' }, me), null);

assert.deepEqual(economyCall({ action: 'partnerGet' }, me), { rpc: 'partner_get', args: { p_user: me } });
for (const side of ['detective', 'doctor', 'mafia', 'citizen']) {
  assert.deepEqual(economyCall({ action: 'partnerSet', side, requestId: req }, me),
    { rpc: 'partner_set', args: { p_user: me, p_side: side, p_request: req.toLowerCase() } });
}
assert.equal(economyCall({ action: 'partnerSet', side: 'jester', requestId: req }, me), null);
assert.equal(economyCall({ action: 'partnerSet', side: 'doctor' }, me), null, 'no request id');
assert.equal(economyCall({ action: 'partnerSet', side: 'doctor', requestId: 'x' }, me), null);
console.log('titles/partner routing: PASS');
