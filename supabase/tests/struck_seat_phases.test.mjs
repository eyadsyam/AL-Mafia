// node supabase/tests/struck_seat_phases.test.mjs
// A seat gone past the presence limit is struck by age_presence in whatever phase
// the match is in (20261030006900). The match must not stall, and what the seat
// did or was named for before it went must not decide anything.
import test from 'node:test';
import assert from 'node:assert/strict';
import { table, phase, expire, night } from './edge_local_fixture.mjs';

async function strike(t, seat) {
  await t.h.sql("update room_players set status='left',connected=false,last_seen=now()-interval '2 minutes' where room_id=$1 and seat=$2",[t.roomId,seat]);
  await t.h.sql('select public.age_presence()');
  const row=(await t.h.sql('select alive from room_players where room_id=$1 and seat=$2',[t.roomId,seat])).rows[0];
  assert.equal(row.alive,false,'the seat was not struck');
}
const state=(t)=>t.h.sql('select phase,public_data from room_state where room_id=$1',[t.roomId]).then(r=>r.rows[0]);
const fresh=(t)=>t.h.sql("update room_players set last_seen=now(),connected=true,status='connected' where room_id=$1",[t.roomId]);

test('a seat everybody voted for, struck before the count, is not eliminated a second time', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    const named=r.find(p=>p.role==='citizen'&&p.seat!==0);
    await phase(t,'vote',1);
    for(const p of r) {
      if(p.seat===named.seat) continue;
      const v=await t.h.call('submit_vote',`u${p.seat}`,{roomId:t.roomId,targetSeat:named.seat});
      assert.equal(v.status,200,JSON.stringify(v.json));
    }
    await fresh(t);
    await strike(t,named.seat);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.notEqual(verdict.json.eliminatedSeat,named.seat,'a seat already out was voted out');
    assert.equal(verdict.json.eliminatedRole??null,null,'a struck seat had its role said');
    assert.doesNotMatch(JSON.stringify((await state(t)).public_data.lastVote??{}),/"eliminatedRole":"(citizen|doctor|detective|mafia)"/);
  } finally { await t.close(); }
});

test('the ballot of a struck seat does not count', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    const voter=r.find(p=>p.seat!==0&&p.role==='citizen');
    const named=r.find(p=>p.seat!==0&&p.seat!==voter.seat&&p.role==='doctor');
    await phase(t,'vote',1);
    assert.equal((await t.h.call('submit_vote',`u${voter.seat}`,{roomId:t.roomId,targetSeat:named.seat})).status,200);
    await fresh(t);
    await strike(t,voter.seat);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.eliminatedSeat??null,null,'one gone ballot decided the vote');
  } finally { await t.close(); }
});

test('a struck Mafioso\'s kill does not land, and the night still resolves', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    const mafia=r.filter(p=>p.role==='mafia');
    const gone=mafia.find(p=>p.seat!==0)??mafia[0];
    const victim=r.find(p=>p.role==='citizen');
    await night(t);
    assert.equal((await t.h.call('submit_night_action',`u${gone.seat}`,{roomId:t.roomId,action:'kill',targetSeat:victim.seat})).status,200);
    await fresh(t);
    await strike(t,gone.seat);
    const resolved=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(resolved.status,200,JSON.stringify(resolved.json));
    assert.ok(!(resolved.json.victimSeats??[]).includes(victim.seat),'a gone seat killed');
    assert.equal((await state(t)).phase,'morning');
  } finally { await t.close(); }
});

test('a struck seat holding the opening floor does not hold the table', async () => {
  const t=await table(7,{settings:{openingRoundEnabled:true}});
  try {
    await phase(t,'opening');
    await t.h.sql("update room_state set public_data=jsonb_set(public_data,'{openingSeat}','1'::jsonb,true) where room_id=$1",[t.roomId]);
    await strike(t,1);
    await expire(t);
    const moved=await t.h.call('advance_phase','u2',{roomId:t.roomId});
    assert.equal(moved.status,200,JSON.stringify(moved.json));
    assert.notEqual((await state(t)).public_data.openingSeat,1,'the floor stayed with a seat that is gone');
  } finally { await t.close(); }
});

test('a seat struck during the deal does not hold the night back past its clock', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    for(const p of r) if(p.seat!==1) assert.equal((await t.h.call('saw_role',`u${p.seat}`,{roomId:t.roomId})).status,200);
    await strike(t,1);
    await expire(t);
    const opened=await t.h.call('open_phase','u2',{roomId:t.roomId,phase:'night'});
    assert.equal(opened.status,200,JSON.stringify(opened.json));
  } finally { await t.close(); }
});

test('the last of the Mafia gone in the night ends it for the town, and nothing is paid', async () => {
  const t=await table(6,{roles:{mafia:1,doctor:1,detective:1,citizen:3}});
  try {
    const r=await t.roster();
    const mafia=r.find(p=>p.role==='mafia');
    if(mafia.seat===0) return; // A host going closes the room instead (no_seat_outlives_its_player.sql).
    await night(t);
    await fresh(t);
    await strike(t,mafia.seat);
    const s=await state(t);
    assert.equal(s.public_data.outcome,'town');
    assert.equal((await t.h.sql('select count(*)::int n from economy_void_rooms where room_id=$1',[t.roomId])).rows[0].n,1);
  } finally { await t.close(); }
});
