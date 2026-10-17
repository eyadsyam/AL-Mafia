import test from 'node:test';
import assert from 'node:assert/strict';
import { harness } from '../../tool/edge_harness/index.mjs';

test('seven players complete a night and a ballot with public role secrecy', async () => {
  const h=await harness();
  try {
    for(let i=0;i<7;i++) await h.user(`u${i}`);
    const created=await h.call('create_room','u0',{name:'Host'});
    assert.equal(created.status,200,JSON.stringify(created.json));
    const {roomId,code}=created.json;
    for(let i=1;i<7;i++) {
      const joined=await h.call('join_room',`u${i}`,{code,name:`Player ${i}`});
      assert.equal(joined.status,200,JSON.stringify(joined.json));
    }
    const started=await h.call('start_match','u0',{roomId,roles:{mafia:2,doctor:1,detective:1,citizen:3}});
    assert.equal(started.status,200,JSON.stringify(started.json));
    assert.doesNotMatch(JSON.stringify(started.json),/"role"|"mafia"|"doctor"/);
    for(let i=0;i<7;i++) assert.equal((await h.call('saw_role',`u${i}`,{roomId})).status,200);
    const opened=await h.call('open_phase','u0',{roomId,phase:'night'});
    assert.equal(opened.status,200,JSON.stringify(opened.json));
    const roster=(await h.sql('select user_id,seat,role from room_players where room_id=$1 order by seat',[roomId])).rows;
    const target=roster.find(p=>p.role==='citizen');
    for(const p of roster) {
      const action=p.role==='mafia'?'kill':p.role==='doctor'?'protect':p.role==='detective'?'investigate':null;
      if(!action) continue;
      const seat=action==='kill'?target.seat:roster.find(q=>q.seat!==p.seat && q.seat!==target.seat).seat;
      const response=await h.call('submit_night_action',`u${p.seat}`,{roomId,action,targetSeat:seat});
      assert.equal(response.status,200,JSON.stringify({role:p.role,response}));
    }
    const night=await h.call('resolve_night','u0',{roomId});
    assert.equal(night.status,200,JSON.stringify(night.json));
    assert.ok(night.json.victimSeats.includes(target.seat),JSON.stringify(night.json));
    assert.doesNotMatch(JSON.stringify(night.json),/"role"|"mafia"|"doctor"|"detective"/);
    const morning=(await h.sql('select public_data from room_state where room_id=$1',[roomId])).rows[0].public_data;
    assert.ok(morning.morning.victimSeats.includes(target.seat));
    assert.doesNotMatch(JSON.stringify(morning),/"role"|"mafia"|"doctor"|"detective"/);
    assert.equal((await h.call('open_phase','u0',{roomId,phase:'discuss'})).status,200);
    assert.equal((await h.call('open_phase','u0',{roomId,phase:'vote'})).status,200);
    const living=roster.filter(p=>p.seat!==target.seat);
    const ballotTarget=living.find(p=>p.role==='mafia');
    for(const p of living) {
      if(p.seat===ballotTarget.seat) continue;
      const vote=await h.call('submit_vote',`u${p.seat}`,{roomId,targetSeat:ballotTarget.seat});
      assert.equal(vote.status,200,JSON.stringify(vote.json));
    }
    const verdict=await h.call('resolve_vote','u0',{roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.eliminatedSeat,ballotTarget.seat);
    assert.equal(verdict.json.eliminatedRole,'mafia');
  } finally { await h.close(); }
});
