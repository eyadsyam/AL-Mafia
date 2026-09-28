// node supabase/tests/launch_events.test.mjs
// Row 12 edge routing: the schedule read takes the server's clock, the result
// stamp takes the session's user and a valid room id.
import assert from 'node:assert/strict';
import { economyCall } from '../functions/_shared/economy_actions.ts';

const me = '00000000-0000-4000-8000-000000000001';
const room = '00000000-0000-4000-8000-0000000000cd';
const before = Date.now();
const read = economyCall({ action: 'launchEvents', p_at: '1999-01-01T00:00:00Z' }, me);
assert.equal(read.rpc, 'launch_event_state');
const at = Date.parse(read.args.p_at);
assert.ok(at >= before && at <= Date.now() + 1000, 'the server clock, never the body');
assert.deepEqual(Object.keys(read.args), ['p_at'], 'no user id on a public schedule read');
assert.deepEqual(economyCall({ action: 'eventResult', roomId: room }, me),
  { rpc: 'launch_event_result', args: { p_user: me, p_room: room } });
assert.equal(economyCall({ action: 'eventResult', roomId: 'x' }, me), null);
assert.equal(economyCall({ action: 'eventResult' }, me), null);
console.log('launch events routing: PASS');
