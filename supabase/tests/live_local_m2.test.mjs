import test from 'node:test';
import assert from 'node:assert/strict';
import { table, night, phase, expire } from './edge_local_fixture.mjs';
import { deriveSeed, SeedSalt, tieBreakIndex } from '../functions/_shared/seed.ts';

const asUser = p => `u${p.seat}`;
const actionRow = async (t,p,n=1) => (await t.h.sql('select action,target_id,used_bullet from night_actions where room_id=$1 and actor_id=$2 and night=$3',[t.roomId,p.user_id,n])).rows[0]??null;

test('M2-4 and M2-6: Mafia rejects teammate, self, dead target, dead actor and closed phase', async () => {
  const t=await table();
  try {
    const r=await t.roster(), mafia=r.filter(p=>p.role==='mafia'), town=r.find(p=>p.role==='citizen');
    const body=targetSeat=>({roomId:t.roomId,action:'kill',targetSeat});
    assert.equal((await t.h.call('submit_night_action',asUser(mafia[0]),body(town.seat))).json.error,'PHASE_CLOSED');
    await night(t);
    for(const p of [mafia[0],mafia[1]]) assert.equal((await t.h.call('submit_night_action',asUser(mafia[0]),body(p.seat))).json.error,'BAD_REQUEST');
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,town.user_id]);
    assert.equal((await t.h.call('submit_night_action',asUser(mafia[0]),body(town.seat))).json.error,'BAD_REQUEST');
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,mafia[0].user_id]);
    assert.equal((await t.h.call('submit_night_action',asUser(mafia[0]),body(r.find(p=>p.role==='doctor').seat))).json.error,'NOT_ALIVE');
    assert.equal(await actionRow(t,mafia[0]),null);
  } finally { await t.close(); }
});

test('M2-10: one armed Mafioso silences both team kills for the night and spends team bullet once', async () => {
  const t=await table();
  try {
    await night(t);
    const r=await t.roster(), mafia=r.filter(p=>p.role==='mafia'), victim=r.find(p=>p.role==='citizen');
    const one=await t.h.call('submit_night_action',asUser(mafia[0]),{roomId:t.roomId,action:'kill',targetSeat:victim.seat,useBullet:true});
    assert.equal(one.status,200,JSON.stringify(one.json));
    assert.equal(one.json.bulletSpent,true);
    assert.equal((await t.h.call('submit_night_action',asUser(mafia[1]),{roomId:t.roomId,action:'kill',targetSeat:victim.seat,useBullet:true})).json.error,'RATE_LIMITED');
    assert.equal((await t.h.call('submit_night_action',asUser(mafia[1]),{roomId:t.roomId,action:'kill',targetSeat:victim.seat})).status,200);
    const result=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(result.status,200,JSON.stringify(result.json));
    assert.deepEqual(result.json.victimSeats,[]);
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and used_bullet',[t.roomId])).rows[0].n,1);
  } finally { await t.close(); }
});

test('M2-16: expiry assigns each missing Mafioso a living non-team target', async () => {
  const t=await table();
  try {
    await night(t); await expire(t);
    const applied=await t.h.call('advance_phase','u1',{roomId:t.roomId});
    assert.equal(applied.status,200,JSON.stringify(applied.json));
    const r=await t.roster();
    const seed=(await t.h.sql('select match_seed from rooms where id=$1',[t.roomId])).rows[0].match_seed;
    for(const p of r.filter(p=>p.role==='mafia')) {
      const move=await actionRow(t,p);
      assert.equal(move.action,'kill');
      assert.ok(r.some(q=>q.user_id===move.target_id && q.alive && q.role!=='mafia'));
      const targets=r.filter(q=>q.alive && q.role!=='mafia').sort((a,b)=>a.seat-b.seat);
      const expected=targets[tieBreakIndex(deriveSeed(seed,SeedSalt.timerDefault,100+p.seat),targets.length)];
      assert.equal(move.target_id,expected.user_id);
    }
    const before=(await t.h.sql('select actor_id,target_id from night_actions where room_id=$1 order by actor_id',[t.roomId])).rows;
    assert.equal((await t.h.call('advance_phase','u2',{roomId:t.roomId})).status,200);
    assert.deepEqual((await t.h.sql('select actor_id,target_id from night_actions where room_id=$1 order by actor_id',[t.roomId])).rows,before);
  } finally { await t.close(); }
});

test('M2-56 and M2-64: Detective retry is stable, another target refused, timer skip can be replaced', async () => {
  const t=await table();
  try {
    await night(t);
    const r=await t.roster(), detective=r.find(p=>p.role==='detective'), targets=r.filter(p=>p.seat!==detective.seat);
    const body=targetSeat=>({roomId:t.roomId,action:'investigate',targetSeat});
    const first=await t.h.call('submit_night_action',asUser(detective),body(targets[0].seat));
    assert.equal(first.status,200,JSON.stringify(first.json));
    const again=await t.h.call('submit_night_action',asUser(detective),body(targets[0].seat));
    assert.equal(again.status,200,JSON.stringify(again.json));
    assert.equal(again.json.revealedRole,first.json.revealedRole);
    assert.equal((await t.h.call('submit_night_action',asUser(detective),body(targets[1].seat))).json.error,'RATE_LIMITED');
    assert.equal((await actionRow(t,detective)).target_id,targets[0].user_id);
    await phase(t,'night',2); await expire(t);
    assert.equal((await t.h.call('advance_phase','u1',{roomId:t.roomId})).status,200);
    assert.equal((await actionRow(t,detective,2)).action,'skip');
    const after=await t.h.call('submit_night_action',asUser(detective),body(targets[0].seat));
    assert.equal(after.status,200,JSON.stringify(after.json));
    assert.equal(after.json.revealedRole,first.json.revealedRole);
    assert.equal((await actionRow(t,detective,2)).action,'investigate');
  } finally { await t.close(); }
});

test('M2-40 and M2-50: Doctor may cover Mafia, but consecutive target and invalid moves are refused', async () => {
  const t=await table();
  try {
    const r=await t.roster(), doctor=r.find(p=>p.role==='doctor'), mafia=r.find(p=>p.role==='mafia'), citizen=r.find(p=>p.role==='citizen');
    const protect=targetSeat=>({roomId:t.roomId,action:'protect',targetSeat});
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),protect(mafia.seat))).json.error,'PHASE_CLOSED');
    await night(t);
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),{roomId:t.roomId,action:'skip'})).json.error,'BAD_REQUEST');
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),{roomId:t.roomId,action:'kill',targetSeat:mafia.seat})).json.error,'WRONG_ROLE');
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),protect(mafia.seat))).status,200);
    await phase(t,'night',2);
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),protect(mafia.seat))).json.error,'SAME_PROTECT');
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),protect(citizen.seat))).status,200);
    await phase(t,'night',3);
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,mafia.user_id]);
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),protect(mafia.seat))).json.error,'BAD_REQUEST');
    assert.equal(await actionRow(t,doctor,3),null);
  } finally { await t.close(); }
});

test('M2-42: Doctor self-protection is one-use even with master bullets off', async () => {
  const t=await table(7,{settings:{bulletsEnabled:false}});
  try {
    await night(t);
    const doctor=(await t.roster()).find(p=>p.role==='doctor');
    const body={roomId:t.roomId,action:'protect',targetSeat:doctor.seat,useBullet:true};
    const first=await t.h.call('submit_night_action',asUser(doctor),body);
    assert.equal(first.status,200,JSON.stringify(first.json));
    assert.equal(first.json.bulletSpent,true);
    await phase(t,'night',2);
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),body)).json.error,'RATE_LIMITED');
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2 and used_bullet',[t.roomId,doctor.user_id])).rows[0].n,1);
  } finally { await t.close(); }
});

test('M2-52: Doctor expiry target excludes self and previous cover; no legal target writes nothing', async () => {
  const t=await table();
  try {
    await night(t);
    const r=await t.roster(), doctor=r.find(p=>p.role==='doctor'), previous=r.find(p=>p.role==='citizen');
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),{roomId:t.roomId,action:'protect',targetSeat:previous.seat})).status,200);
    await phase(t,'night',2); await expire(t);
    assert.equal((await t.h.call('advance_phase','u1',{roomId:t.roomId})).status,200);
    const picked=await actionRow(t,doctor,2);
    assert.equal(picked.action,'protect');
    assert.notEqual(picked.target_id,doctor.user_id);
    assert.notEqual(picked.target_id,previous.user_id);
    assert.ok(r.some(q=>q.user_id===picked.target_id && q.alive));
    const seed=(await t.h.sql('select match_seed from rooms where id=$1',[t.roomId])).rows[0].match_seed;
    const eligible=r.filter(q=>q.alive && q.user_id!==doctor.user_id && q.user_id!==previous.user_id).sort((a,b)=>a.seat-b.seat);
    assert.equal(picked.target_id,eligible[tieBreakIndex(deriveSeed(seed,SeedSalt.timerDefault,200+doctor.seat),eligible.length)].user_id);
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id<>all($2::uuid[])',[t.roomId,`{${doctor.user_id},${picked.target_id}}`]);
    await phase(t,'night',3); await expire(t);
    assert.equal((await t.h.call('advance_phase','u1',{roomId:t.roomId})).status,200);
    assert.equal(await actionRow(t,doctor,3),null);
  } finally { await t.close(); }
});

test('M2-22: Silencer may name self and teammate; surviving victim loses ballot but can be voted out', async () => {
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,citizen:3}});
  try {
    await night(t);
    const r=await t.roster(), silencer=r.find(p=>p.role==='silencer'), mafia=r.find(p=>p.role==='mafia'), citizen=r.find(p=>p.role==='citizen');
    const silence=targetSeat=>({roomId:t.roomId,action:'silence',targetSeat});
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),silence(silencer.seat))).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),silence(mafia.seat))).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),silence(citizen.seat))).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(mafia),{roomId:t.roomId,action:'skip'})).status,200);
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.equal(morning.json.silencedSeat,citizen.seat);
    await phase(t,'vote');
    assert.equal((await t.h.call('submit_vote',asUser(citizen),{roomId:t.roomId,targetSeat:mafia.seat})).json.error,'WRONG_ROLE');
    const voter=r.find(p=>p.seat!==citizen.seat && p.seat!==mafia.seat);
    assert.equal((await t.h.call('submit_vote',asUser(voter),{roomId:t.roomId,targetSeat:citizen.seat})).status,200);
  } finally { await t.close(); }
});

test('M2-24 and M2-30: dead silence target refused; dying target has no mark; no Silencer bullet', async () => {
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,citizen:3}});
  try {
    await night(t);
    const r=await t.roster(), silencer=r.find(p=>p.role==='silencer'), mafia=r.find(p=>p.role==='mafia'), dying=r.find(p=>p.role==='citizen'), other=r.find(p=>p.role==='citizen' && p.seat!==dying.seat);
    const body=targetSeat=>({roomId:t.roomId,action:'silence',targetSeat});
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),{...body(dying.seat),useBullet:true})).json.error,'WRONG_ROLE');
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(other.seat))).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(dying.seat))).status,200);
    assert.equal((await actionRow(t,silencer)).target_id,dying.user_id);
    assert.equal((await t.h.call('submit_night_action',asUser(mafia),{roomId:t.roomId,action:'kill',targetSeat:dying.seat})).status,200);
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.ok(morning.json.victimSeats.includes(dying.seat));
    assert.equal(morning.json.silencedSeat,null);
    await phase(t,'night',2);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(dying.seat))).json.error,'BAD_REQUEST');
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(other.seat))).status,200);
    await phase(t,'night',3);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(other.seat))).status,200);
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2',[t.roomId,silencer.user_id])).rows[0].n,3);
  } finally { await t.close(); }
});

test('M2-26, M2-28 and M2-36: lone Silencer inherits kill, cannot hit team/self; prior silence stays silence; expiry skips', async () => {
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,citizen:3}});
  try {
    const r=await t.roster(), silencer=r.find(p=>p.role==='silencer'), mafia=r.find(p=>p.role==='mafia'), citizen=r.find(p=>p.role==='citizen');
    const body=targetSeat=>({roomId:t.roomId,action:'silence',targetSeat});
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(citizen.seat))).json.error,'PHASE_CLOSED');
    await night(t);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(citizen.seat))).status,200);
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,mafia.user_id]);
    assert.equal((await actionRow(t,silencer)).action,'silence');
    await phase(t,'night',2);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(silencer.seat))).json.error,'BAD_REQUEST');
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(mafia.seat))).json.error,'BAD_REQUEST');
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(citizen.seat))).status,200);
    assert.equal((await actionRow(t,silencer,1)).action,'silence');
    assert.equal((await actionRow(t,silencer,2)).action,'kill');
    await phase(t,'night',3); await expire(t);
    assert.equal((await t.h.call('advance_phase','u1',{roomId:t.roomId})).status,200);
    assert.equal((await actionRow(t,silencer,3)).action,'skip');
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,silencer.user_id]);
    assert.equal((await t.h.call('submit_night_action',asUser(silencer),body(citizen.seat))).json.error,'NOT_ALIVE');
  } finally { await t.close(); }
});

test('M2-68 and M2-78: Elder waits at night without a bullet, then expiry writes a skip without stalling', async () => {
  const t=await table(7,{allAccess:true,settings:{elderEnabled:true},roles:{mafia:2,doctor:1,detective:1,elder:1,citizen:2}});
  try {
    await night(t);
    const r=await t.roster(), elder=r.find(p=>p.role==='elder'), target=r.find(p=>p.role==='mafia');
    const ack=await t.h.call('submit_night_action',asUser(elder),{roomId:t.roomId,action:'suspect',targetSeat:target.seat,useBullet:true});
    assert.equal(ack.status,200,JSON.stringify(ack.json));
    assert.equal(ack.json.bulletSpent,false);
    assert.equal(await actionRow(t,elder),null);
    await t.h.sql("update room_players set alive=false where room_id=$1 and role in ('doctor','detective')",[t.roomId]);
    await expire(t);
    const moved=await t.h.call('advance_phase','u1',{roomId:t.roomId});
    assert.equal(moved.status,200,JSON.stringify(moved.json));
    assert.equal((await actionRow(t,elder)).action,'skip');
    for(const mafia of r.filter(p=>p.role==='mafia')) {
      assert.equal((await t.h.call('submit_night_action',asUser(mafia),{roomId:t.roomId,action:'skip'})).status,200);
    }
    const nightResult=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(nightResult.status,200,JSON.stringify(nightResult.json));
    assert.equal(nightResult.json.outcome,null);
  } finally { await t.close(); }
});

test('M2-70: Elder reveals only alive in a day window, once in public state; silence blocks ballot', async () => {
  const t=await table(7,{allAccess:true,settings:{elderEnabled:true},roles:{mafia:2,doctor:1,detective:1,elder:1,citizen:2}});
  try {
    const r=await t.roster(), elder=r.find(p=>p.role==='elder'), target=r.find(p=>p.role==='mafia');
    assert.equal((await t.h.call('reveal_elder',asUser(elder),{roomId:t.roomId})).json.error,'PHASE_CLOSED');
    await phase(t,'discuss');
    const first=await t.h.call('reveal_elder',asUser(elder),{roomId:t.roomId});
    assert.equal(first.status,200,JSON.stringify(first.json));
    assert.equal((await t.h.call('reveal_elder',asUser(elder),{roomId:t.roomId})).status,200);
    let publicData=(await t.h.sql('select public_data from room_state where room_id=$1',[t.roomId])).rows[0].public_data;
    assert.deepEqual(publicData.elderRevealedSeats,[elder.seat]);
    await t.h.sql("update room_state set public_data=jsonb_set(public_data,'{morning}',$2::jsonb,true) where room_id=$1",[t.roomId,JSON.stringify({silencedSeat:elder.seat})]);
    await phase(t,'vote');
    assert.equal((await t.h.call('submit_vote',asUser(elder),{roomId:t.roomId,targetSeat:target.seat})).json.error,'WRONG_ROLE');
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,elder.user_id]);
    assert.equal((await t.h.call('reveal_elder',asUser(elder),{roomId:t.roomId})).json.error,'NOT_ALIVE');
    publicData=(await t.h.sql('select public_data from room_state where room_id=$1',[t.roomId])).rows[0].public_data;
    assert.deepEqual(publicData.elderRevealedSeats,[elder.seat]);
  } finally { await t.close(); }
});

test('M2-114 and M2-118: bought roles must match switches; unowned role cannot enter a deal', async () => {
  const t=await table(7,{start:false});
  try {
    const valid={mafia:1,silencer:1,doctor:1,detective:1,citizen:3};
    const unowned=await t.h.call('start_match','u0',{roomId:t.roomId,roles:valid,settings:{silencerEnabled:true}});
    assert.equal(unowned.json.error,'PURCHASE_REQUIRED');
    const off=await t.h.call('start_match','u0',{roomId:t.roomId,roles:valid});
    assert.equal(off.json.error,'BAD_REQUEST');
    const roles=(await t.h.sql('select count(*)::int as n from room_players where room_id=$1 and role is not null',[t.roomId])).rows[0].n;
    assert.equal(roles,0);
    const host=(await t.roster())[0];
    await t.h.sql("insert into all_access_grants(user_id,reason,granted_by) values($1,'edge-local','service_role')",[host.user_id]);
    const started=await t.h.call('start_match','u0',{roomId:t.roomId,roles:valid,settings:{silencerEnabled:true}});
    assert.equal(started.status,200,JSON.stringify(started.json));
    assert.equal((await t.roster()).filter(p=>p.role==='silencer').length,1);
    assert.doesNotMatch(JSON.stringify(started.json),/silencer|mafia|role/i);
  } finally { await t.close(); }
});

test('M2-112: complete deal returns no roles and private reconnect retrieves own role and team', async () => {
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,citizen:3}});
  try {
    const r=await t.roster();
    assert.equal(r.filter(p=>p.role!==null).length,7);
    const state=(await t.h.sql('select phase,public_data from room_state where room_id=$1',[t.roomId])).rows[0];
    assert.equal(state.phase,'reveal');
    assert.doesNotMatch(JSON.stringify(state.public_data),/mafia|silencer|doctor|detective|citizen/);
    for(const p of r) {
      const privateData=await t.h.call('my_team',asUser(p),{roomId:t.roomId});
      assert.equal(privateData.status,200);
      assert.equal(privateData.json.role,p.role);
      assert.equal((await t.h.call('my_team',asUser(p),{roomId:t.roomId})).json.role,p.role);
    }
  } finally { await t.close(); }
});

test('M2-58: Detective receives a private answer on a night that kills them', async () => {
  const t=await table();
  try {
    await night(t);
    const r=await t.roster(), detective=r.find(p=>p.role==='detective'), mafia=r.filter(p=>p.role==='mafia');
    for(const p of mafia) assert.equal((await t.h.call('submit_night_action',asUser(p),{roomId:t.roomId,action:'kill',targetSeat:detective.seat})).status,200);
    const answer=await t.h.call('submit_night_action',asUser(detective),{roomId:t.roomId,action:'investigate',targetSeat:mafia[0].seat});
    assert.equal(answer.status,200,JSON.stringify(answer.json));
    assert.equal(answer.json.revealedRole,'mafia');
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.ok(morning.json.victimSeats.includes(detective.seat));
    const publicData=(await t.h.sql('select public_data from room_state where room_id=$1',[t.roomId])).rows[0].public_data;
    assert.doesNotMatch(JSON.stringify(publicData),/detective|revealedRole|investigate/);
  } finally { await t.close(); }
});

test('M2-80 and M2-88: Sniper fires once despite master bullets off; unarmed move and expiry cannot shoot', async () => {
  const t=await table(7,{allAccess:true,settings:{sniperEnabled:true,bulletsEnabled:false},roles:{mafia:2,doctor:1,detective:1,sniper:1,citizen:2}});
  try {
    await night(t);
    const r=await t.roster(), sniper=r.find(p=>p.role==='sniper'), target=r.find(p=>p.role==='mafia');
    const body={roomId:t.roomId,action:'suspect',targetSeat:target.seat};
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),body)).status,200);
    assert.equal((await actionRow(t,sniper)).used_bullet,false);
    const unarmed=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(unarmed.status,200,JSON.stringify(unarmed.json));
    assert.deepEqual(unarmed.json.victimSeats,[]);
    await phase(t,'night',2);
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{...body,useBullet:true})).status,200);
    assert.equal((await actionRow(t,sniper,2)).used_bullet,true);
    await phase(t,'night',3);
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{...body,useBullet:true})).json.error,'RATE_LIMITED');
    await expire(t);
    assert.equal((await t.h.call('advance_phase','u1',{roomId:t.roomId})).status,200);
    assert.equal((await actionRow(t,sniper,3)).action,'skip');
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2 and used_bullet',[t.roomId,sniper.user_id])).rows[0].n,1);
  } finally { await t.close(); }
});

test('M2-18: three night deaths are all named without roles and parity is decided after all deaths', async () => {
  const t=await table(7,{allAccess:true,settings:{sniperEnabled:true},roles:{mafia:2,doctor:1,detective:1,sniper:1,citizen:2}});
  try {
    await night(t);
    const r=await t.roster(), mafia=r.filter(p=>p.role==='mafia'), sniper=r.find(p=>p.role==='sniper'), doctor=r.find(p=>p.role==='doctor'), citizens=r.filter(p=>p.role==='citizen');
    for(const p of mafia) assert.equal((await t.h.call('submit_night_action',asUser(p),{roomId:t.roomId,action:'kill',targetSeat:citizens[0].seat})).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{roomId:t.roomId,action:'suspect',targetSeat:citizens[1].seat,useBullet:true})).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),{roomId:t.roomId,action:'protect',targetSeat:mafia[0].seat})).status,200);
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.deepEqual([...morning.json.victimSeats].sort((a,b)=>a-b),[citizens[0].seat,citizens[1].seat,sniper.seat].sort((a,b)=>a-b));
    assert.equal(morning.json.outcome,'mafia');
    assert.doesNotMatch(JSON.stringify(morning.json.victimSeats),/mafia|citizen|sniper|role/);
    assert.equal(morning.json.eliminatedRole,undefined);
    const publicData=(await t.h.sql('select public_data from room_state where room_id=$1',[t.roomId])).rows[0].public_data;
    assert.equal(publicData.morning.victimSeats.length,3);
    assert.equal(publicData.morning.eliminatedRole,undefined);
  } finally { await t.close(); }
});

test('M2-54 and M2-66: Doctor and Detective vote deaths reveal role and count as town for parity', async () => {
  for(const role of ['doctor','detective']) {
    const t=await table();
    try {
      const r=await t.roster(), victim=r.find(p=>p.role===role), citizen=r.find(p=>p.role==='citizen'), mafia=r.filter(p=>p.role==='mafia');
      await t.h.sql('update room_players set alive=false where room_id=$1 and user_id<>all($2::uuid[])',[t.roomId,`{${victim.user_id},${citizen.user_id},${mafia.map(p=>p.user_id).join(',')}}`]);
      await phase(t,'vote');
      for(const p of [citizen,...mafia]) assert.equal((await t.h.call('submit_vote',asUser(p),{roomId:t.roomId,targetSeat:victim.seat})).status,200);
      const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
      assert.equal(verdict.status,200,JSON.stringify({role,verdict}));
      assert.equal(verdict.json.eliminatedRole,role);
      assert.equal(verdict.json.outcome,'mafia');
      const state=(await t.h.sql('select public_data from room_state where room_id=$1',[t.roomId])).rows[0].public_data;
      assert.equal(state.lastVote.eliminatedRole,role);
    } finally { await t.close(); }
  }
});

test('M2-102: Citizen expiry writes nothing, night death hides role, vote death reveals role', async () => {
  const t=await table();
  try {
    await night(t);
    const r=await t.roster(), citizen=r.find(p=>p.role==='citizen'), mafia=r.filter(p=>p.role==='mafia'), doctor=r.find(p=>p.role==='doctor');
    await expire(t);
    assert.equal((await t.h.call('advance_phase','u1',{roomId:t.roomId})).status,200);
    assert.equal(await actionRow(t,citizen),null);
    for(const p of mafia) assert.equal((await t.h.call('submit_night_action',asUser(p),{roomId:t.roomId,action:'kill',targetSeat:citizen.seat})).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(doctor),{roomId:t.roomId,action:'protect',targetSeat:mafia[0].seat})).status,200);
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.ok(morning.json.victimSeats.includes(citizen.seat));
    assert.equal(morning.json.eliminatedRole,undefined);
    await t.h.sql('update room_players set alive=true where room_id=$1 and user_id=$2',[t.roomId,citizen.user_id]);
    await phase(t,'vote');
    for(const p of r.filter(p=>p.seat!==citizen.seat)) assert.equal((await t.h.call('submit_vote',asUser(p),{roomId:t.roomId,targetSeat:citizen.seat})).status,200);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.eliminatedRole,'citizen');
  } finally { await t.close(); }
});

test('M2-38: eliminating a town seat reveals its role and Silencer counts toward Mafia parity', async () => {
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,citizen:3}});
  try {
    const r=await t.roster(), team=r.filter(p=>['mafia','silencer'].includes(p.role)), town=r.filter(p=>p.role==='citizen');
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id<>all($2::uuid[])',[t.roomId,`{${[...team,...town.slice(0,2)].map(p=>p.user_id).join(',')}}`]);
    await phase(t,'vote');
    for(const p of [team[0],team[1],town[1]]) assert.equal((await t.h.call('submit_vote',asUser(p),{roomId:t.roomId,targetSeat:town[0].seat})).status,200);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.eliminatedRole,'citizen');
    assert.equal(verdict.json.outcome,'mafia');
  } finally { await t.close(); }
});

test('M2-72: revealed Elder with double vote counts six; a dead Elder casts no ballot (grave_vote retired)', async () => {
  const t=await table(7,{allAccess:true,settings:{elderEnabled:true},roles:{mafia:2,doctor:1,detective:1,elder:1,citizen:2}});
  try {
    const r=await t.roster(), elder=r.find(p=>p.role==='elder'), target=r.find(p=>p.role==='citizen'), graveTarget=r.find(p=>p.role==='mafia');
    await phase(t,'discuss');
    assert.equal((await t.h.call('reveal_elder',asUser(elder),{roomId:t.roomId})).status,200);
    await t.h.sql("insert into player_tool_charges(user_id,tool_code,charges) values($1,'double_vote',1),($1,'grave_vote',1)",[elder.user_id]);
    assert.equal((await t.h.call('economy',asUser(elder),{action:'toolUse',roomId:t.roomId,tool:'double_vote',targets:[]})).status,200);
    await phase(t,'vote');
    assert.equal((await t.h.call('submit_vote',asUser(elder),{roomId:t.roomId,targetSeat:target.seat})).status,200);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.tally[target.seat],6);
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,elder.user_id]);
    await phase(t,'vote',2);
    assert.equal((await t.h.call('submit_vote',asUser(elder),{roomId:t.roomId,targetSeat:target.seat})).json.error,'NOT_ALIVE');
    const grave=await t.h.call('economy',asUser(elder),{action:'toolUse',roomId:t.roomId,tool:'grave_vote',targets:[]});
    assert.equal(grave.status,400,JSON.stringify(grave.json));
    assert.equal((await t.h.call('submit_vote',asUser(elder),{roomId:t.roomId,targetSeat:graveTarget.seat})).json.error,'NOT_ALIVE');
  } finally { await t.close(); }
});

test('M2-74: Elder reveal is public; a mistaken Sniper shot kills both without a night role field', async () => {
  const t=await table(7,{allAccess:true,settings:{elderEnabled:true,sniperEnabled:true},roles:{mafia:2,doctor:1,elder:1,sniper:1,citizen:2}});
  try {
    const r=await t.roster(), elder=r.find(p=>p.role==='elder'), sniper=r.find(p=>p.role==='sniper');
    await phase(t,'discuss');
    assert.equal((await t.h.call('reveal_elder',asUser(elder),{roomId:t.roomId})).status,200);
    assert.ok((await t.h.sql('select public_data from room_state where room_id=$1',[t.roomId])).rows[0].public_data.elderRevealedSeats.includes(elder.seat));
    await phase(t,'night',2);
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{roomId:t.roomId,action:'suspect',targetSeat:elder.seat,useBullet:true})).status,200);
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.deepEqual([...morning.json.victimSeats].sort((a,b)=>a-b),[elder.seat,sniper.seat].sort((a,b)=>a-b));
    assert.equal(morning.json.eliminatedRole,undefined);
  } finally { await t.close(); }
});

test('M2-86: quiet Mafia night leaves mistaken Sniper shot active; deaths and parity are public', async () => {
  const t=await table(7,{allAccess:true,settings:{sniperEnabled:true},roles:{mafia:2,doctor:1,detective:1,sniper:1,citizen:2}});
  try {
    await night(t);
    const r=await t.roster(), mafia=r.filter(p=>p.role==='mafia'), sniper=r.find(p=>p.role==='sniper'), citizens=r.filter(p=>p.role==='citizen');
    await t.h.sql("update room_players set alive=false where room_id=$1 and role in ('doctor','detective')",[t.roomId]);
    assert.equal((await t.h.call('submit_night_action',asUser(mafia[0]),{roomId:t.roomId,action:'kill',targetSeat:citizens[0].seat,useBullet:true})).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(mafia[1]),{roomId:t.roomId,action:'kill',targetSeat:citizens[0].seat})).status,200);
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{roomId:t.roomId,action:'suspect',targetSeat:citizens[1].seat,useBullet:true})).status,200);
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.deepEqual([...morning.json.victimSeats].sort((a,b)=>a-b),[citizens[1].seat,sniper.seat].sort((a,b)=>a-b));
    assert.equal(morning.json.outcome,'mafia');
  } finally { await t.close(); }
});

test('M2-90: refused Sniper actions spend nothing; a charged locked door cancels shot and recoil', async () => {
  const t=await table(7,{allAccess:true,settings:{sniperEnabled:true},roles:{mafia:2,doctor:1,detective:1,sniper:1,citizen:2}});
  try {
    const r=await t.roster(), sniper=r.find(p=>p.role==='sniper'), citizen=r.find(p=>p.role==='citizen');
    const shot={roomId:t.roomId,action:'suspect',targetSeat:citizen.seat,useBullet:true};
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),shot)).json.error,'PHASE_CLOSED');
    await phase(t,'discuss');
    await t.h.sql("insert into player_tool_charges(user_id,tool_code,charges) values($1,'lock_door',1)",[citizen.user_id]);
    const door=await t.h.call('economy',asUser(citizen),{action:'toolUse',roomId:t.roomId,tool:'lock_door',targets:[]});
    assert.equal(door.status,200,JSON.stringify(door.json));
    assert.equal((await t.h.sql("select count(*)::int as n from room_tool_uses where room_id=$1 and user_id=$2 and tool_code='lock_door'",[t.roomId,citizen.user_id])).rows[0].n,1);
    await phase(t,'night',2);
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{...shot,action:'kill'})).json.error,'WRONG_ROLE');
    const dead=r.find(p=>p.role==='doctor');
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[t.roomId,dead.user_id]);
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{...shot,targetSeat:dead.seat})).json.error,'BAD_REQUEST');
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),shot)).status,200);
    assert.equal((await t.h.call('resolve_night','u0',{roomId:t.roomId})).status,200);
    const after=await t.roster();
    assert.equal(after.find(p=>p.user_id===citizen.user_id).alive,true);
    assert.equal(after.find(p=>p.user_id===sniper.user_id).alive,true);
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2 and used_bullet',[t.roomId,sniper.user_id])).rows[0].n,1);
  } finally { await t.close(); }
});

test('M2-92: Sniper night death hides role; a dead witness reads roles while living players cannot', async () => {
  const t=await table(7,{allAccess:true,settings:{sniperEnabled:true},roles:{mafia:2,doctor:1,detective:1,sniper:1,citizen:2}});
  try {
    await night(t);
    const r=await t.roster(), sniper=r.find(p=>p.role==='sniper'), citizen=r.find(p=>p.role==='citizen');
    assert.equal((await t.h.call('submit_night_action',asUser(sniper),{roomId:t.roomId,action:'suspect',targetSeat:citizen.seat,useBullet:true})).status,200);
    const result=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(result.status,200,JSON.stringify(result.json));
    assert.ok(result.json.victimSeats.includes(sniper.seat));
    assert.equal(result.json.eliminatedRole,undefined);
    const living=r.find(p=>p.role==='mafia');
    assert.equal((await t.h.call('witness_view',asUser(living),{roomId:t.roomId})).json.error,'WITNESS_ONLY');
    const witness=await t.h.call('witness_view',asUser(sniper),{roomId:t.roomId});
    assert.equal(witness.status,200,JSON.stringify(witness.json));
    assert.equal(witness.json.roles.find(p=>p.seat===citizen.seat).role,'citizen');
    await phase(t,'vote');
    const target=r.find(p=>p.role==='detective');
    assert.equal((await t.h.call('submit_vote',asUser(living),{roomId:t.roomId,targetSeat:target.seat})).status,200);
    const vote=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(vote.status,200,JSON.stringify(vote.json));
    assert.equal(vote.json.eliminatedRole,'detective');
  } finally { await t.close(); }
});

test('M2-108: five-seat server refuses impossible sold roles and seven-seat server rechecks ownership', async () => {
  const five=await table(5,{start:false,allAccess:true});
  try {
    const invalid=[
      [{mafia:1,elder:1,citizen:3},{elderEnabled:true}],
      [{mafia:1,sniper:1,citizen:3},{sniperEnabled:true}],
    ];
    for(const [roles,settings] of invalid) assert.equal((await five.h.call('start_match','u0',{roomId:five.roomId,roles,settings})).json.error,'BAD_REQUEST');
    assert.equal((await five.h.call('start_match','u0',{roomId:five.roomId,roles:{mafia:1,doctor:1,detective:1,citizen:2}})).status,200);
  } finally { await five.close(); }
  const seven=await table(7,{start:false});
  try {
    assert.equal((await seven.h.call('start_match','u0',{roomId:seven.roomId,roles:{mafia:1,elder:1,citizen:5},settings:{elderEnabled:true}})).json.error,'PURCHASE_REQUIRED');
  } finally { await seven.close(); }
});

test('M2-118: owned sold role deal and charged table tool remain separate actions', async () => {
  const t=await table(7,{allAccess:true,settings:{elderEnabled:true},roles:{mafia:2,elder:1,doctor:1,detective:1,citizen:2}});
  try {
    const r=await t.roster();
    assert.equal(r.filter(p=>p.role==='elder').length,1);
    await phase(t,'discuss');
    const buyer=r.find(p=>p.role==='elder');
    assert.equal((await t.h.sql('select count(*)::int as n from room_tool_uses where room_id=$1',[t.roomId])).rows[0].n,0);
    await t.h.sql("insert into player_tool_charges(user_id,tool_code,charges) values($1,'double_vote',1)",[buyer.user_id]);
    const use=await t.h.call('economy',asUser(buyer),{action:'toolUse',roomId:t.roomId,tool:'double_vote',targets:[]});
    assert.equal(use.status,200,JSON.stringify(use.json));
    assert.equal((await t.h.sql("select count(*)::int as n from room_tool_uses where room_id=$1 and user_id=$2 and tool_code='double_vote'",[t.roomId,buyer.user_id])).rows[0].n,1);
    assert.equal((await t.roster()).find(p=>p.user_id===buyer.user_id).role,'elder');
  } finally { await t.close(); }
});

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
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,citizen:3}});
  try {
    const roster=await t.roster();
    const mafia=roster.filter(p=>['mafia','silencer'].includes(p.role));
    for(const p of roster) {
      const r=await t.h.call('my_team',`u${p.seat}`,{roomId:t.roomId});
      assert.equal(r.status,200,JSON.stringify(r.json));
      assert.equal(r.json.role,p.role);
      assert.equal(r.json.teammates.length,['mafia','silencer'].includes(p.role)?1:0);
      if(['mafia','silencer'].includes(p.role)) assert.ok(r.json.teammates.includes(`Player ${mafia.find(q=>q.seat!==p.seat).seat}`) || r.json.teammates.includes('Host'));
    }
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
