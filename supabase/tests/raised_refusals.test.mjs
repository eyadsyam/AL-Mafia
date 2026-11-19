// node --test supabase/tests/raised_refusals.test.mjs
// A refusal SQL raises by name is answered with its code, never a 500 (production
// 2026-11-18: record_speaking after the floor moved on came back 500, the client
// read «no connection» and retried four times).
import test from 'node:test';
import assert from 'node:assert/strict';
import { table, phase } from './edge_local_fixture.mjs';

test('a speaking report from a seat that does not hold the floor is a refusal, not a 500', async () => {
  const t = await table(7, { settings: { discussionMode: 'structured' } });
  try {
    await phase(t, 'discuss');
    const r = await t.h.call('record_speaking', 'u3', { roomId: t.roomId, seconds: 12 });
    assert.equal(r.status, 400, JSON.stringify(r.json));
    assert.equal(r.json.error, 'PHASE_CLOSED');
    assert.equal(r.json.message, 'refused', 'nothing from the exception is echoed');
  } finally { await t.close(); }
});

test('a speaking report after the clock ran out is a refusal, not a 500', async () => {
  const t = await table(7, { settings: { discussionMode: 'free' } });
  try {
    await phase(t, 'discuss');
    await t.h.sql("update room_state set phase_ends_at=now()-interval '1 second' where room_id=$1", [t.roomId]);
    const r = await t.h.call('record_speaking', 'u2', { roomId: t.roomId, seconds: 5 });
    assert.equal(r.status, 400, JSON.stringify(r.json));
    assert.equal(r.json.error, 'PHASE_CLOSED');
  } finally { await t.close(); }
});

test('only an exact token is a refusal; anything else stays a server failure', async () => {
  // After the harness has registered its loader (jsr: and npm: imports).
  const { raisedRefusal } = await import('../functions/_shared/api.ts');
  const answer = async (message) => { const r = raisedRefusal({ message })(); return [(await r.json()).error, r.status]; };
  assert.deepEqual(await answer('PHASE_CLOSED'), ['PHASE_CLOSED', 400]);
  assert.deepEqual(await answer('NOT_FLOOR_HOLDER'), ['PHASE_CLOSED', 400]);
  assert.deepEqual(await answer(' NOT_HOST '), ['NOT_HOST', 403]);
  assert.equal(raisedRefusal({ message: 'duplicate key value violates unique constraint "x_PHASE_CLOSED"' }), null);
  assert.equal(raisedRefusal({ message: 'ROLE_LEAK mafia seat 3' }), null);
  assert.equal(raisedRefusal(null), null);
  assert.equal(raisedRefusal(new Error('boom')), null);
});
