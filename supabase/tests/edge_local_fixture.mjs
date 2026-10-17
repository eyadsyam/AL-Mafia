import assert from 'node:assert/strict';
import { harness } from '../../tool/edge_harness/index.mjs';

export async function table(count=7,{start=true,roles={mafia:2,doctor:1,detective:1,citizen:count-4},settings={}}={}) {
  const h=await harness();
  try {
    for(let i=0;i<count;i++) await h.user(`u${i}`);
    const created=await h.call('create_room','u0',{name:'Host',settings});
    assert.equal(created.status,200,JSON.stringify(created.json));
    const {roomId,code}=created.json;
    for(let i=1;i<count;i++) {
      const joined=await h.call('join_room',`u${i}`,{code,name:`Player ${i}`});
      assert.equal(joined.status,200,JSON.stringify(joined.json));
    }
    if(start) {
      const started=await h.call('start_match','u0',{roomId,roles});
      assert.equal(started.status,200,JSON.stringify(started.json));
    }
    const roster=()=>h.sql('select user_id,seat,role,alive from room_players where room_id=$1 order by seat',[roomId]).then(r=>r.rows);
    return {h,roomId,code,roster,close:()=>h.close()};
  } catch(e) { await h.close(); throw e; }
}

export async function night(t) {
  const {h,roomId}=t;
  for(const p of await t.roster()) assert.equal((await h.call('saw_role',`u${p.seat}`,{roomId})).status,200);
  const opened=await h.call('open_phase','u0',{roomId,phase:'night'});
  assert.equal(opened.status,200,JSON.stringify(opened.json));
}
