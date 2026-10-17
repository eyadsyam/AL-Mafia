import assert from 'node:assert/strict';
import { harness } from '../../tool/edge_harness/index.mjs';

export async function table(count=7,{start=true,roles={mafia:2,doctor:1,detective:1,citizen:count-4},settings={},allAccess=false,ready=false}={}) {
  const h=await harness();
  try {
    const ids=[];
    for(let i=0;i<count;i++) ids.push(await h.user(`u${i}`));
    if(allAccess) {
      await h.sql("insert into all_access_grants(user_id,reason,granted_by) values($1,'edge-local','service_role')",[ids[0]]);
    }
    const created=await h.call('create_room','u0',{name:'Host',settings});
    assert.equal(created.status,200,JSON.stringify(created.json));
    const {roomId,code}=created.json;
    for(let i=1;i<count;i++) {
      const joined=await h.call('join_room',`u${i}`,{code,name:`Player ${i}`});
      assert.equal(joined.status,200,JSON.stringify(joined.json));
    }
    if(ready) {
      await h.sql('update economy_config set lobby_ready_enabled=true where id=true');
      const revision=(await h.sql('select lobby_revision from rooms where id=$1',[roomId])).rows[0].lobby_revision;
      for(let i=0;i<count;i++) {
        const r=await h.call('lobby_ready',`u${i}`,{roomId,ready:true,revision});
        assert.equal(r.status,200,JSON.stringify(r.json));
      }
    }
    if(start) {
      const started=await h.call('start_match','u0',{roomId,roles});
      assert.equal(started.status,200,JSON.stringify(started.json));
    }
    const roster=()=>h.sql('select user_id,seat,role,alive from room_players where room_id=$1 order by seat',[roomId]).then(r=>r.rows);
    return {h,roomId,code,roster,close:()=>h.close()};
  } catch(e) { await h.close(); throw e; }
}

export async function phase(t,name,number=1) {
  await t.h.sql('update room_state set phase=$2,phase_number=$3,phase_ends_at=now()+interval \'120 seconds\' where room_id=$1',[t.roomId,name,number]);
}

export async function expire(t) {
  await t.h.sql("update room_state set phase_ends_at=now()-interval '1 second' where room_id=$1",[t.roomId]);
}

export async function night(t) {
  const {h,roomId}=t;
  for(const p of await t.roster()) assert.equal((await h.call('saw_role',`u${p.seat}`,{roomId})).status,200);
  const opened=await h.call('open_phase','u0',{roomId,phase:'night'});
  assert.equal(opened.status,200,JSON.stringify(opened.json));
}
