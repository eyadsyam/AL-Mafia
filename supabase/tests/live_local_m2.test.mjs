import test from 'node:test';
import assert from 'node:assert/strict';
import { table, night } from './edge_local_fixture.mjs';

test('M2-104: four seats cannot start a match', async () => {
  const t=await table(4,{start:false});
  try {
    const r=await t.h.call('start_match','u0',{roomId:t.roomId,roles:{mafia:1,citizen:3}});
    assert.equal(r.json.error,'BAD_REQUEST');
    assert.match(r.json.message,/at least five/);
    assert.equal((await t.h.sql('select status from rooms where id=$1',[t.roomId])).rows[0].status,'lobby');
  } finally { await t.close(); }
});

test('M2-110: invalid deal counts and Mafia balance are refused before any role is written', async () => {
  const t=await table(7,{start:false});
  try {
    const invalid=[
      {mafia:1,detective:2,citizen:4},
      {mafia:1,silencer:2,citizen:4},
      {mafia:0,citizen:7},
      {mafia:4,citizen:3},
      {mafia:1,citizen:5},
    ];
    for(const roles of invalid) {
      const r=await t.h.call('start_match','u0',{roomId:t.roomId,roles});
      assert.equal(r.json.error,'BAD_REQUEST',JSON.stringify({roles,r}));
      assert.equal((await t.h.sql('select count(*)::int as n from room_players where room_id=$1 and role is not null',[t.roomId])).rows[0].n,0);
      assert.equal((await t.h.sql('select phase from room_state where room_id=$1',[t.roomId])).rows[0].phase,'lobby');
    }
  } finally { await t.close(); }
});

test('M2-20: only Mafia team members see teammate names at deal', async () => {
  const t=await table();
  try {
    const roster=await t.roster();
    const mafia=roster.filter(p=>p.role==='mafia');
    for(const p of roster) {
      const r=await t.h.call('my_team',`u${p.seat}`,{roomId:t.roomId});
      assert.equal(r.status,200,JSON.stringify(r.json));
      assert.equal(r.json.role,p.role);
      assert.equal(r.json.teammates.length,p.role==='mafia'?1:0);
      if(p.role==='mafia') assert.ok(r.json.teammates.includes(`Player ${mafia.find(q=>q.seat!==p.seat).seat}`) || r.json.teammates.includes('Host'));
    }
    // Put the paid Silencer in the dealt Mafia seat to exercise the private
    // team endpoint without granting a purchase in this fixture.
    await t.h.sql("update room_players set role='silencer' where room_id=$1 and user_id=$2",[t.roomId,mafia[0].user_id]);
    for(const p of mafia) {
      const r=await t.h.call('my_team',`u${p.seat}`,{roomId:t.roomId});
      assert.equal(r.status,200);
      assert.equal(r.json.teammates.length,1);
    }
    const outsider=roster.find(p=>p.role==='citizen');
    assert.deepEqual((await t.h.call('my_team',`u${outsider.seat}`,{roomId:t.roomId})).json.teammates,[]);
  } finally { await t.close(); }
});

test('M2-94 and M2-96: Citizen night request writes no action and cannot hold completion', async () => {
  const t=await table();
  try {
    await night(t);
    const roster=await t.roster();
    const citizen=roster.find(p=>p.role==='citizen');
    const ack=await t.h.call('submit_night_action',`u${citizen.seat}`,{roomId:t.roomId,action:'suspect',targetSeat:roster.find(p=>p.seat!==citizen.seat).seat,note:'suspect'});
    assert.equal(ack.status,200,JSON.stringify(ack.json));
    assert.equal(ack.json.bulletSpent,false);
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2',[t.roomId,citizen.user_id])).rows[0].n,0);
    for(const p of roster.filter(p=>!['citizen','elder'].includes(p.role))) {
      const action=p.role==='mafia'?'kill':p.role==='doctor'?'protect':'investigate';
      const target=roster.find(q=>q.seat!==p.seat && (action!=='kill'||q.role!=='mafia'));
      const r=await t.h.call('submit_night_action',`u${p.seat}`,{roomId:t.roomId,action,targetSeat:target.seat});
      assert.equal(r.status,200,JSON.stringify(r.json));
    }
    const deadline=(await t.h.sql('select phase_ends_at from room_state where room_id=$1',[t.roomId])).rows[0].phase_ends_at;
    assert.ok(new Date(deadline)<=new Date());
  } finally { await t.close(); }
});
