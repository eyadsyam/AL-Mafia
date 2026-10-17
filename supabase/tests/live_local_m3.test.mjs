import test from 'node:test';
import assert from 'node:assert/strict';
import { table, night } from './edge_local_fixture.mjs';

test('M3-33: expired discussion opens vote in free and by-turns rooms', async () => {
  for(const discussionMode of ['free','structured']) {
    const t=await table(7,{settings:{discussionMode}});
    try {
      await night(t);
      await t.h.sql("update room_state set phase='discuss',phase_ends_at=now()-interval '1 second' where room_id=$1",[t.roomId]);
      const r=await t.h.call('advance_phase','u1',{roomId:t.roomId});
      assert.equal(r.status,200,JSON.stringify({discussionMode,r}));
      assert.equal(r.json.applied,'ballot-opened');
      assert.equal((await t.h.sql('select phase from room_state where room_id=$1',[t.roomId])).rows[0].phase,'vote');
    } finally { await t.close(); }
  }
});
