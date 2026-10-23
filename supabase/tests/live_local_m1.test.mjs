import test from 'node:test';
import assert from 'node:assert/strict';
import { table, phase, expire } from './edge_local_fixture.mjs';
import { floorSecondsFor } from '../functions/_shared/voice.ts';

// ── helpers shared by the M1 conversions ────────────────────────────────────
const as = p => `u${p.seat}`;
const isTeam = p => p.role === 'mafia' || p.role === 'silencer';
const roomState = async t => (await t.h.sql('select phase,phase_number,phase_ends_at,active_speaker,speaker_until,public_data from room_state where room_id=$1',[t.roomId])).rows[0];
const chargesOf = async (t,p,tool) => (await t.h.sql('select charges from player_tool_charges where user_id=$1 and tool_code=$2',[p.user_id,tool])).rows[0]?.charges ?? 0;
const useRows = async (t,p,tool) => (await t.h.sql('select id,phase,phase_number,target_seats,note,consumed_at from room_tool_uses where room_id=$1 and user_id=$2 and tool_code=$3 order by id',[t.roomId,p.user_id,tool])).rows;
const grant = (t,p,tool,n=1) => t.h.sql('insert into player_tool_charges(user_id,tool_code,charges) values($1,$2,$3) on conflict (user_id,tool_code) do update set charges=player_tool_charges.charges+excluded.charges',[p.user_id,tool,n]);
const use = (t,p,tool,{targets=[],note}={}) => t.h.call('economy',as(p),{action:'toolUse',roomId:t.roomId,tool,targets,...(note===undefined?{}:{note})});
async function buy(t,p,tool,opts) {
  await grant(t,p,tool);
  const r=await use(t,p,tool,opts);
  assert.equal(r.status,200,`${tool}: ${JSON.stringify(r.json)}`);
  assert.equal(await chargesOf(t,p,tool),0,`${tool} spent exactly its charge`);
  return r.json;
}
// The host of an all-access table spends no charge; every other seat spends exactly one.
async function buyAnySeat(t,p,tool,opts) {
  if(p.seat!==0) return buy(t,p,tool,opts);
  await grant(t,p,tool);
  const r=await use(t,p,tool,opts);
  assert.equal(r.status,200,`${tool}: ${JSON.stringify(r.json)}`);
  return r.json;
}
const vote = (t,p,seat,extra={}) => t.h.call('submit_vote',as(p),{roomId:t.roomId,targetSeat:seat,...extra});
const act = (t,p,action,seat,extra={}) => t.h.call('submit_night_action',as(p),{roomId:t.roomId,action,...(seat===undefined?{}:{targetSeat:seat}),...extra});
// What a reconnecting client reads: its own session, the table's grants, no role column.
async function asClient(t,p,read) {
  await t.h.sql('set role authenticated');
  try {
    await t.h.sql("select set_config('request.jwt.claim.sub',$1,false)",[p.user_id]);
    return await read();
  } finally {
    await t.h.sql('reset role');
    await t.h.sql("select set_config('request.jwt.claim.sub','',false)");
  }
}
const clientState = (t,p) => asClient(t,p,async () => (await t.h.sql('select phase,phase_number,public_data from room_state where room_id=$1',[t.roomId])).rows[0]);
// join_room caps a room at 15 (maxPlayers is one of 5/8/10/15); a 20-seat roster is
// reached by seating the last players directly, exactly as tools_gaps.sql seats them.
async function bigTable(total,{roles,settings={}}) {
  const seated=Math.min(total,15);
  const t=await table(seated,{start:false,allAccess:true,settings:{maxPlayers:15,...settings}});
  try {
    for(let i=seated;i<total;i++) {
      const id=await t.h.user(`u${i}`);
      await t.h.sql('insert into room_players(room_id,user_id,name,seat) values($1,$2,$3,$4)',[t.roomId,id,`Player ${i}`,i]);
    }
    const started=await t.h.call('start_match','u0',{roomId:t.roomId,roles});
    assert.equal(started.status,200,JSON.stringify(started.json));
    assert.equal((await t.roster()).length,total);
    return t;
  } catch(e) { await t.close(); throw e; }
}

test('M1 tool prerequisites: an ordinary ballot has a public tally without private roles', async () => {
  const t=await table();
  try {
    await t.h.sql("update room_state set phase='vote' where room_id=$1",[t.roomId]);
    const roster=await t.roster();
    const target=roster[1];
    const r=await t.h.call('submit_vote','u0',{roomId:t.roomId,targetSeat:target.seat});
    assert.equal(r.status,200,JSON.stringify(r.json));
    const vote=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(vote.status,200,JSON.stringify(vote.json));
    assert.equal(vote.json.tally[target.seat],1);
  } finally { await t.close(); }
});

test('M1-57: bought double vote combines with revealed Elder in both ballot rounds', async () => {
  const t=await table(7,{settings:{dayTieRule:'revote'}});
  try {
    const roster=await t.roster();
    const elder=roster[0], target=roster[1], other=roster[2];
    await t.h.sql("update room_players set role='elder' where room_id=$1 and user_id=$2",[t.roomId,elder.user_id]);
    await t.h.sql("update room_state set phase='discuss',public_data=jsonb_set(public_data,'{elderRevealedSeats}',$2::jsonb,true) where room_id=$1",[t.roomId,JSON.stringify([elder.seat])]);
    await t.h.sql("insert into player_tool_charges(user_id,tool_code,charges) values($1,'double_vote',1)",[elder.user_id]);
    const used=await t.h.call('economy','u0',{action:'toolUse',roomId:t.roomId,tool:'double_vote',targets:[]});
    assert.equal(used.status,200,JSON.stringify(used.json));
    assert.equal((await t.h.sql("select charges from player_tool_charges where user_id=$1 and tool_code='double_vote'",[elder.user_id])).rows[0].charges,0);
    await t.h.sql("update room_state set phase='vote' where room_id=$1",[t.roomId]);
    await t.h.sql("insert into player_tool_charges(user_id,tool_code,charges) values($1,'revote',1)",[elder.user_id]);
    const boughtRevote=await t.h.call('economy','u0',{action:'toolUse',roomId:t.roomId,tool:'revote',targets:[]});
    assert.equal(boughtRevote.status,200,JSON.stringify(boughtRevote.json));
    assert.equal((await t.h.call('submit_vote','u0',{roomId:t.roomId,targetSeat:target.seat})).status,200);
    // A bought revote needs at least two seats that drew votes.
    assert.equal((await t.h.call('submit_vote','u2',{roomId:t.roomId,targetSeat:roster[3].seat})).status,200);
    const first=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(first.status,200,JSON.stringify(first.json));
    assert.equal((await t.h.sql('select public_data from room_state where room_id=$1',[t.roomId])).rows[0].public_data.lastVote.tally[target.seat],6);
    assert.equal(first.json.round,2);
    assert.equal((await t.h.call('submit_vote','u0',{roomId:t.roomId,targetSeat:target.seat,round:2})).status,200);
    const second=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(second.status,200,JSON.stringify(second.json));
    assert.equal(second.json.tally[target.seat],6);
  } finally { await t.close(); }
});

test('M1-39: a last word names the chosen seat in the verdict a reconnecting client reads, also when the verdict ends the match', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    const owner=r.find(p=>p.role==='citizen' && p.seat!==0), chosen=r.find(p=>p.role==='detective'), decoy=r.find(p=>p.role==='doctor');
    await phase(t,'vote',1);
    await buy(t,owner,'last_word',{targets:[chosen.seat]});
    for(const p of r) assert.equal((await vote(t,p,p.seat===owner.seat?decoy.seat:owner.seat)).status,200);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.eliminatedSeat,owner.seat);
    assert.equal(verdict.json.outcome,null);
    assert.deepEqual(verdict.json.lastWord,{seat:owner.seat,target:chosen.seat});
    // Reconnect: any seat reading the table's state sees who was chosen, and only the public role of the one voted out.
    for(const reader of [chosen,decoy,r.find(p=>p.role==='mafia')]) {
      const s=await clientState(t,reader);
      assert.equal(s.phase,'verdict');
      assert.deepEqual(s.public_data.lastVote.lastWord,{seat:owner.seat,target:chosen.seat});
      assert.equal(s.public_data.lastVote.eliminatedRole,'citizen');
      assert.deepEqual(s.public_data.lastWordFloor,{seat:owner.seat,target:chosen.seat,day:1});
      assert.doesNotMatch(JSON.stringify(s.public_data),/mafia|doctor|detective/);
    }
    // The reconnecting host asking again changes nothing.
    assert.equal((await t.h.call('resolve_vote','u0',{roomId:t.roomId})).json.error,'PHASE_CLOSED');
    assert.deepEqual((await roomState(t)).public_data.lastVote.lastWord,{seat:owner.seat,target:chosen.seat});
  } finally { await t.close(); }

  const ending=await table();
  try {
    const r=await ending.roster(), mafia=r.filter(p=>p.role==='mafia');
    const owner=mafia[0], chosen=r.find(p=>p.role==='citizen');
    await ending.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2',[ending.roomId,mafia[1].user_id]);
    await phase(ending,'vote',1);
    await buy(ending,owner,'last_word',{targets:[chosen.seat]});
    for(const p of r.filter(q=>q.seat!==mafia[1].seat)) assert.equal((await vote(ending,p,p.seat===owner.seat?chosen.seat:owner.seat)).status,200);
    const verdict=await ending.h.call('resolve_vote','u0',{roomId:ending.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.outcome,'town');
    assert.equal(verdict.json.eliminatedSeat,owner.seat);
    assert.deepEqual(verdict.json.lastWord,{seat:owner.seat,target:chosen.seat});
    // A match that ends grants no floor tomorrow, but the table is still told who was chosen.
    const reread=await clientState(ending,chosen);
    assert.equal(reread.public_data.outcome,'town');
    assert.deepEqual(reread.public_data.lastVote.lastWord,{seat:owner.seat,target:chosen.seat});
    assert.equal(reread.public_data.lastWordFloor,undefined);
    assert.equal((await ending.h.call('open_phase','u0',{roomId:ending.roomId,phase:'result'})).status,200);
    const result=await clientState(ending,owner);
    assert.equal(result.phase,'result');
    assert.deepEqual(result.public_data.lastVote.lastWord,{seat:owner.seat,target:chosen.seat});
  } finally { await ending.close(); }
});

test('M1-59: a double ballot is weighted in the public tally and in both sides of an appeal', async () => {
  // Seven seats, appellant T, doubled voter V, five others. The ballots are identical in both
  // runs; only V's bought double vote differs.
  const run=async (boughtDouble) => {
    const t=await table(7,{settings:{abstainAllowed:true}});
    try {
      const r=await t.roster();
      const T=r.find(p=>p.role==='citizen'), V=r.find(p=>p.seat!==T.seat && p.role==='doctor');
      const [a,b,c,d,e]=r.filter(p=>p.seat!==T.seat && p.seat!==V.seat);
      await phase(t,'discuss',1);
      if(boughtDouble) await buy(t,V,'double_vote');
      await buy(t,T,'appeal');
      await phase(t,'vote',1);
      const ballots=[[V,T],[a,T],[b,T],[c,T],[d,a],[e,a],[T,V]];
      for(const [from,to] of ballots) assert.equal((await vote(t,from,to.seat)).status,200);
      const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
      assert.equal(verdict.status,200,JSON.stringify(verdict.json));
      return {verdict,T,V,a};
    } finally { await t.close(); }
  };
  const doubled=await run(true);
  // Public tally: V's ballot weighs 2 (T: V2 + a + b + c; a: d + e; V: T's own ballot).
  assert.deepEqual(doubled.verdict.json.tally,{[doubled.T.seat]:5,[doubled.a.seat]:2,[doubled.V.seat]:1});
  // Appeal: others' weighted ballots are 2+1+1+1+1+1 = 7 and 5 confirm; 5 * 3 > 7 * 2, so it is upheld.
  assert.equal(doubled.verdict.json.eliminatedSeat,doubled.T.seat);
  // Without the double vote the same ballots are 4 of 6, and 4 * 3 is not more than 6 * 2: the appeal holds.
  const single=await run(false);
  assert.deepEqual(single.verdict.json.tally,{[single.T.seat]:4,[single.a.seat]:2,[single.V.seat]:1});
  assert.equal(single.verdict.json.eliminatedSeat,null);

  // The denominator carries the weight of an abstention too: a revealed Elder with a double vote
  // (3 * 2) who abstains makes the other five confirmations 5 of 11, not 5 of 6.
  const t=await table(7,{settings:{abstainAllowed:true}});
  try {
    const r=await t.roster();
    const T=r.find(p=>p.role==='citizen'), E=r.find(p=>p.seat!==T.seat && p.role==='doctor');
    await t.h.sql("update room_players set role='elder' where room_id=$1 and user_id=$2",[t.roomId,E.user_id]);
    await phase(t,'discuss',1);
    await t.h.sql("update room_state set public_data=jsonb_set(public_data,'{elderRevealedSeats}',$2::jsonb,true) where room_id=$1",[t.roomId,JSON.stringify([E.seat])]);
    await buy(t,E,'double_vote');
    await buy(t,T,'appeal');
    await phase(t,'vote',1);
    assert.equal((await vote(t,E,null)).status,200);
    for(const p of r.filter(q=>q.seat!==T.seat && q.seat!==E.seat)) assert.equal((await vote(t,p,T.seat)).status,200);
    assert.equal((await vote(t,T,E.seat)).status,200);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.deepEqual(verdict.json.tally,{[T.seat]:5,[E.seat]:1});
    assert.equal(verdict.json.eliminatedSeat,null);
    const published=await clientState(t,E);
    assert.equal(published.public_data.lastVote.eliminatedSeat,null);
    assert.deepEqual(published.public_data.lastVote.tally,{[T.seat]:5,[E.seat]:1});
  } finally { await t.close(); }
});

test('M1-66: a real Detective meets a mask, a bought face and a door, and reads the same private answer again on reconnect', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    const detective=r.find(p=>p.role==='detective');
    const masked=r.find(p=>p.role==='citizen' && p.seat!==0);
    const faked=r.find(p=>p.role==='mafia' && p.seat!==0);
    const doored=r.find(p=>p.role==='doctor' && p.seat!==0) ?? r.find(p=>p.role==='citizen' && p.seat!==0 && p.seat!==masked.seat);
    const investigate=(seat,extra)=>act(t,detective,'investigate',seat,extra);

    // Night 2 is covered by what was bought in day 1: a mask on a Citizen.
    await phase(t,'discuss',1);
    const bought=await buy(t,masked,'camouflage');
    assert.equal(bought.secret,true);
    await phase(t,'night',2);
    const unclear=await investigate(masked.seat);
    assert.equal(unclear.status,200,JSON.stringify(unclear.json));
    assert.equal(unclear.json.revealedRole,'unclear');
    // Reconnect: the same request is answered with the same private answer, and a second target is refused.
    assert.equal((await investigate(masked.seat)).json.revealedRole,'unclear');
    assert.equal((await investigate(faked.seat)).json.error,'RATE_LIMITED');
    // Nobody else can ask the question, and the table's state never carries the answer or the owner.
    assert.equal((await act(t,faked,'investigate',masked.seat)).json.error,'WRONG_ROLE');
    const citizenAsk=await act(t,masked,'investigate',faked.seat);
    assert.deepEqual(citizenAsk.json.revealedRole,undefined);
    for(const reader of [detective,masked,faked]) {
      const s=await clientState(t,reader);
      assert.doesNotMatch(JSON.stringify(s.public_data),/unclear|unreachable|revealedRole/);
      const entry=s.public_data.toolLog.find(x=>x.tool==='camouflage');
      assert.deepEqual({seat:entry.seat,targets:entry.targets,note:entry.note},{seat:null,targets:[],note:null});
    }

    // Night 3: a Mafioso buys a Citizen's face; the Detective is told Citizen. The night after, without cover, the truth.
    await phase(t,'discuss',2);
    await buy(t,faked,'impersonate',{note:'citizen'});
    await phase(t,'night',3);
    const face=await investigate(faked.seat);
    assert.equal(face.json.revealedRole,'citizen');
    assert.equal((await investigate(faked.seat)).json.revealedRole,'citizen');
    await phase(t,'night',4);
    assert.equal((await investigate(faked.seat)).json.revealedRole,'mafia');

    // Night 5: a mask, a face and a half door together; the door is what the Detective meets.
    await phase(t,'discuss',4);
    await buy(t,doored,'camouflage');
    await buy(t,doored,'impersonate',{note:'mafia'});
    await buy(t,doored,'half_door');
    await phase(t,'night',5);
    assert.equal((await investigate(doored.seat)).json.revealedRole,'unreachable');
    assert.equal((await investigate(doored.seat)).json.revealedRole,'unreachable');
    const finalState=await clientState(t,detective);
    assert.doesNotMatch(JSON.stringify(finalState.public_data),/unclear|unreachable|revealedRole/);
    // The resolved night is told without the investigation.
    const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.doesNotMatch(JSON.stringify(morning.json),/unclear|unreachable|revealedRole/);
  } finally { await t.close(); }
});

test('M1-105: a bought lock door blocks the kill, the sniper shot and its penalty, the silence and the investigation for the next night only', async () => {
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true,sniperEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,sniper:1,citizen:2}});
  try {
    const r=await t.roster();
    const byRole=role=>r.find(p=>p.role===role);
    const mafioso=byRole('mafia'), silencer=byRole('silencer'), sniper=byRole('sniper'), detective=byRole('detective'), doctor=byRole('doctor');
    const owner=r.find(p=>p.role==='citizen' && p.seat!==0);
    const alive=async p=>(await t.h.sql('select alive from room_players where room_id=$1 and user_id=$2',[t.roomId,p.user_id])).rows[0].alive;

    // Day 1: the lock, plus a half door that the lock dominates.
    await phase(t,'discuss',1);
    await buy(t,owner,'lock_door');
    await buy(t,owner,'half_door');
    await phase(t,'night',2);
    assert.equal((await act(t,mafioso,'kill',owner.seat)).status,200);
    assert.equal((await act(t,sniper,'suspect',owner.seat,{useBullet:true})).status,200);
    assert.equal((await act(t,silencer,'silence',owner.seat)).status,200);
    const seen=await act(t,detective,'investigate',owner.seat);
    assert.equal(seen.status,200,JSON.stringify(seen.json));
    assert.equal(seen.json.revealedRole,'unreachable');
    assert.equal((await act(t,doctor,'protect',mafioso.seat)).status,200);
    const night2=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(night2.status,200,JSON.stringify(night2.json));
    assert.deepEqual(night2.json.victimSeats,[]);
    assert.equal(night2.json.silencedSeat,null);
    assert.equal(night2.json.outcome,null);
    assert.equal(await alive(owner),true);
    assert.equal(await alive(sniper),true,'a void shot carries no penalty for the sniper');
    const published=await clientState(t,detective);
    assert.deepEqual(published.public_data.morning.victimSeats,[]);
    assert.equal(published.public_data.morning.silencedSeat,null);

    // Night 3: the lock bought in day 1 has lapsed. The same kill lands and the same silence works.
    await phase(t,'night',3);
    assert.equal((await act(t,mafioso,'kill',owner.seat)).status,200);
    assert.equal((await act(t,silencer,'silence',doctor.seat)).status,200);
    assert.equal((await act(t,detective,'investigate',owner.seat)).json.revealedRole,'citizen');
    const night3=await t.h.call('resolve_night','u0',{roomId:t.roomId});
    assert.equal(night3.status,200,JSON.stringify(night3.json));
    assert.deepEqual(night3.json.victimSeats,[owner.seat]);
    assert.equal(night3.json.silencedSeat,doctor.seat);
    assert.equal(await alive(owner),false);
  } finally { await t.close(); }
});

// One night with a kill, a sniper shot and a silence, each aimed at its own half-door owner (or,
// in the control, at the same seats without a door). The door must let the kill and the shot
// through and stop only the silence.
async function halfDoorNight(t,{doors}) {
  const r=await t.roster();
  const mafioso=r.find(p=>p.role==='mafia'), silencer=r.find(p=>p.role==='silencer'), sniper=r.find(p=>p.role==='sniper');
  const pool=r.filter(p=>!isTeam(p) && p.role!=='sniper');
  const owners=[...pool.filter(p=>p.seat!==0),...pool.filter(p=>p.seat===0)].slice(0,3);
  const [killed,shot,silenced]=owners;
  await phase(t,'discuss',1);
  if(doors) for(const p of owners) await buyAnySeat(t,p,'half_door');
  await phase(t,'night',2);
  assert.equal((await act(t,mafioso,'kill',killed.seat)).status,200);
  assert.equal((await act(t,sniper,'suspect',shot.seat,{useBullet:true})).status,200);
  assert.equal((await act(t,silencer,'silence',silenced.seat)).status,200);
  const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
  assert.equal(morning.status,200,JSON.stringify(morning.json));
  const expectedDead=[killed.seat,shot.seat,sniper.seat].sort((a,b)=>a-b);
  assert.deepEqual([...morning.json.victimSeats].sort((a,b)=>a-b),expectedDead);
  const published=(await clientState(t,silenced)).public_data.morning;
  assert.deepEqual([...published.victimSeats].sort((a,b)=>a-b),expectedDead);
  assert.doesNotMatch(JSON.stringify(published),/"role"|mafia|silencer|sniper|doctor|detective|citizen/);
  assert.equal((await t.roster()).find(p=>p.seat===silenced.seat).alive,true);
  return morning.json.silencedSeat === silenced.seat ? 'silenced' : morning.json.silencedSeat === null ? 'blocked' : `other:${morning.json.silencedSeat}`;
}

test('M1-53: kill, sniper shot and silence on one real night: a half door lets the first two through and blocks only the silence (7, 15 and 20 seats, 4 alive)', async () => {
  const roles7={mafia:1,silencer:1,doctor:1,detective:1,sniper:1,citizen:2};
  const roles15={mafia:3,silencer:1,doctor:1,detective:1,sniper:1,citizen:8};
  const roles20={mafia:4,silencer:1,doctor:1,detective:1,sniper:1,citizen:12};
  // 15 is the largest room join_room admits; 20 is seated directly (see bigTable).
  for(const [total,roles] of [[7,roles7],[15,roles15],[20,roles20]]) {
    for(const doors of [true,false]) {
      const t=total===7
        ? await table(7,{allAccess:true,settings:{silencerEnabled:true,sniperEnabled:true},roles})
        : await bigTable(total,{roles,settings:{silencerEnabled:true,sniperEnabled:true}});
      try { assert.equal(await halfDoorNight(t,{doors}),doors?'blocked':'silenced',`${total} seats, doors=${doors}`); }
      finally { await t.close(); }
    }
  }

  // Four seats left alive. A Silencer beside a Mafioso would already be parity (2 of 4), so no
  // silence can be cast at four seats; what a half door must still allow there is the kill and the shot.
  const four=await table(7,{allAccess:true,settings:{sniperEnabled:true},roles:{mafia:2,doctor:1,detective:1,sniper:1,citizen:2}});
  try {
    const r=await four.roster();
    const mafioso=r.find(p=>p.role==='mafia'), sniper=r.find(p=>p.role==='sniper');
    const town=r.filter(p=>!isTeam(p) && p.role!=='sniper');
    const killed=town.find(p=>p.seat!==0), shot=town.find(p=>p.seat!==killed.seat);
    const keep=new Set([mafioso.seat,sniper.seat,killed.seat,shot.seat]);
    await four.h.sql('update room_players set alive=false where room_id=$1 and seat<>all($2::int[])',[four.roomId,[...keep]]);
    await phase(four,'discuss',1);
    for(const p of [killed,shot]) await buyAnySeat(four,p,'half_door');
    await phase(four,'night',2);
    assert.equal((await act(four,mafioso,'kill',killed.seat)).status,200);
    assert.equal((await act(four,sniper,'suspect',shot.seat,{useBullet:true})).status,200);
    const morning=await four.h.call('resolve_night','u0',{roomId:four.roomId});
    assert.equal(morning.status,200,JSON.stringify(morning.json));
    assert.deepEqual([...morning.json.victimSeats].sort((a,b)=>a-b),[killed.seat,shot.seat,sniper.seat].sort((a,b)=>a-b));
    assert.equal(morning.json.outcome,'mafia');
  } finally { await four.close(); }
});

test('M1-80: grave_vote is retired (20261022000100): a dead seat keeps its old charge, gets no ballot, and the living ballot counts alone', async () => {
  const four=await table();
  try {
    const r=await four.roster();
    const mafia=r.filter(p=>p.role==='mafia'), citizens=r.filter(p=>p.role==='citizen');
    const last=mafia[0], doctor=r.find(p=>p.role==='doctor'), detective=r.find(p=>p.role==='detective'), citizen=citizens[0], grave=citizens[1];
    const living=[last,doctor,detective,citizen];
    await four.h.sql('update room_players set alive=false where room_id=$1 and seat<>all($2::int[])',[four.roomId,living.map(p=>p.seat)]);
    await phase(four,'discuss',1);
    await grant(four,grave,'grave_vote');
    assert.equal((await use(four,grave,'grave_vote')).status,400);
    assert.equal(await chargesOf(four,grave,'grave_vote'),1,'a retired tool spends nothing');
    assert.equal((await useRows(four,grave,'grave_vote')).length,0);
    await phase(four,'vote',1);
    assert.equal((await vote(four,grave,last.seat)).json.error,'NOT_ALIVE');
    for(const [from,to] of [[last,doctor],[doctor,last],[detective,last],[citizen,detective]]) {
      assert.equal((await vote(four,from,to.seat)).status,200);
    }
    const resolver=[doctor,detective,citizen].find(p=>p.seat!==0);
    const verdict=await four.h.call('resolve_vote',as(resolver),{roomId:four.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.deepEqual(verdict.json.tally,{[last.seat]:2,[doctor.seat]:1,[detective.seat]:1});
    assert.equal(verdict.json.eliminatedSeat,last.seat);
    assert.equal((await four.h.sql('select count(*)::int as n from votes where room_id=$1 and voter_id=$2',[four.roomId,grave.user_id])).rows[0].n,0);
  } finally { await four.close(); }
});

// ── the race rows (M1-7, M1-13, M1-26, M1-46, M1-108) ───────────────────────
// The harness runs one PGlite connection, so these prove every serial schedule of each race
// (both orders, retries, expiry, removal, reconnect) through the real edge functions and a
// same-tick Promise.all. Row-lock behaviour under truly parallel connections is not exercised,
// so those five rows stay `needs-live` in the matrix.
const speakerLeft = async t => Number((await t.h.sql('select extract(epoch from (speaker_until-now())) as left from room_state where room_id=$1',[t.roomId])).rows[0].left);
test('M1-7 (serial schedules; row stays needs-live): one extra minute is consumed once across two contending users, a removed buyer and phase expiry', async () => {
  const t=await table(7,{settings:{discussionMode:'structured'}});
  try {
    const r=await t.roster();
    const [, A, B, C]=r;
    const base=floorSecondsFor('discuss',{});
    await phase(t,'discuss',1);
    await buy(t,A,'extra_minute');
    // A retried request (lost acknowledgement) spends nothing more.
    await grant(t,A,'extra_minute');
    assert.equal((await use(t,A,'extra_minute')).json.error,'LIMIT_PHASE');
    assert.equal(await chargesOf(t,A,'extra_minute'),1);
    assert.equal((await useRows(t,A,'extra_minute')).length,1);
    // B takes the floor first; A is refused while B holds it, and keeps the unspent bonus.
    assert.equal((await t.h.call('claim_floor',as(B),{roomId:t.roomId})).json.granted,true);
    assert.equal((await t.h.call('claim_floor',as(A),{roomId:t.roomId})).json.granted,false);
    assert.equal((await roomState(t)).active_speaker,B.user_id);
    assert.equal((await useRows(t,A,'extra_minute'))[0].consumed_at,null);
    // B's turn runs out; A's first granted claim carries the minute (45 s), once.
    await t.h.sql("update room_state set speaker_until=now()-interval '1 second' where room_id=$1",[t.roomId]);
    assert.equal((await t.h.call('claim_floor',as(A),{roomId:t.roomId})).json.granted,true);
    assert.ok(Math.abs(await speakerLeft(t)-(base+45))<3,`first claim ${await speakerLeft(t)}`);
    assert.notEqual((await useRows(t,A,'extra_minute'))[0].consumed_at,null);
    assert.equal((await t.h.call('release_floor',as(A),{roomId:t.roomId})).status,200);
    assert.equal((await t.h.call('claim_floor',as(A),{roomId:t.roomId})).json.granted,true);
    assert.ok(Math.abs(await speakerLeft(t)-base)<3,`second claim ${await speakerLeft(t)}`);
    // A reconnecting client reads who holds the floor and one toolLog entry for the purchase.
    const reread=await clientState(t,C);
    assert.equal(reread.public_data.toolLog.filter(x=>x.tool==='extra_minute').length,1);
    assert.equal((await roomState(t)).active_speaker,A.user_id);

    // A buyer who is removed afterwards cannot claim; nobody else spends or inherits the minute.
    await buy(t,C,'extra_minute');
    assert.equal((await t.h.call('kick_player','u0',{roomId:t.roomId,seat:C.seat})).status,200);
    assert.equal((await t.h.call('claim_floor',as(C),{roomId:t.roomId})).json.error,'NOT_A_MEMBER');
    await t.h.sql("update room_state set active_speaker=null,speaker_until=null where room_id=$1",[t.roomId]);
    assert.equal((await t.h.call('claim_floor',as(B),{roomId:t.roomId})).json.granted,true);
    assert.ok(Math.abs(await speakerLeft(t)-base)<3);
    assert.equal((await useRows(t,C,'extra_minute'))[0].consumed_at,null);

    // The discussion expires: the ballot opens, the floor is no longer granted and nothing more is consumed.
    await expire(t);
    const closed=await t.h.call('advance_phase',as(A),{roomId:t.roomId});
    assert.equal(closed.json.applied,'ballot-opened');
    assert.equal((await t.h.call('claim_floor',as(A),{roomId:t.roomId})).json.granted,false);
    assert.equal((await useRows(t,A,'extra_minute')).length,1);
    assert.equal((await t.h.sql("select count(*)::int as n from room_tool_uses where room_id=$1 and tool_code='extra_minute' and consumed_at is not null",[t.roomId])).rows[0].n,1);
  } finally { await t.close(); }
});

test('M1-13 (serial schedules; row stays needs-live): a note is posted once however it is retried or repeated in the same tick', async () => {
  const t=await table();
  try {
    const [, A, B]=await t.roster();
    const notes=async()=> (await roomState(t)).public_data.toolLog.filter(x=>x.tool==='anon_note');
    await phase(t,'discuss',1);
    await grant(t,A,'anon_note',2);
    const first=await use(t,A,'anon_note',{note:'someone is lying'});
    assert.equal(first.status,200,JSON.stringify(first.json));
    assert.equal(first.json.charges,1);
    // The same request again (response lost, client retried) and a different text in the same phase.
    assert.equal((await use(t,A,'anon_note',{note:'someone is lying'})).json.error,'LIMIT_PHASE');
    assert.equal((await use(t,A,'anon_note',{note:'another text'})).json.error,'LIMIT_PHASE');
    assert.equal(await chargesOf(t,A,'anon_note'),1);
    assert.deepEqual((await notes()).map(x=>[x.seat,x.note]),[[null,'someone is lying']]);
    // Two requests in the same tick: one posts, the other is refused, one charge leaves.
    await grant(t,B,'anon_note',2);
    const both=await Promise.all([use(t,B,'anon_note',{note:'first'}),use(t,B,'anon_note',{note:'second'})]);
    assert.deepEqual(both.map(x=>x.status).sort(),[200,409]);
    assert.equal(both.find(x=>x.status===409).json.error,'LIMIT_PHASE');
    assert.equal(await chargesOf(t,B,'anon_note'),1);
    assert.equal((await notes()).length,2);
    assert.equal((await useRows(t,B,'anon_note')).length,1);
    // The second note the tool allows needs a new phase; a third is over the per-match limit.
    await phase(t,'discuss',2);
    assert.equal((await use(t,A,'anon_note',{note:'tomorrow'})).status,200);
    assert.equal(await chargesOf(t,A,'anon_note'),0);
    await phase(t,'discuss',3);
    await grant(t,A,'anon_note');
    assert.equal((await use(t,A,'anon_note',{note:'again'})).json.error,'LIMIT_TOOL');
    assert.equal(await chargesOf(t,A,'anon_note'),1);
    // A reconnecting client reads the same three notes, none naming an author.
    const reread=(await clientState(t,B)).public_data.toolLog.filter(x=>x.tool==='anon_note');
    assert.deepEqual(reread.map(x=>x.seat),[null,null,null]);
    assert.equal(reread.length,3);
  } finally { await t.close(); }
});

test('M1-26 (serial schedules; row stays needs-live): spotlights follow their order, hold the floor for 20 seconds, then yield to the timer', async () => {
  const t=await table(7,{settings:{discussionMode:'structured'}});
  try {
    const [, A, B, X, T1, T2, D]=await t.roster();
    const claim=p=>t.h.call('claim_floor',as(p),{roomId:t.roomId}).then(x=>x.json.granted);
    const release=p=>t.h.call('release_floor',as(p),{roomId:t.roomId});
    const spent=async()=>(await t.h.sql("select count(*)::int as n from room_tool_uses where room_id=$1 and tool_code='spotlight' and consumed_at is not null",[t.roomId])).rows[0].n;
    await phase(t,'discuss',1);
    await t.h.sql("update room_state set updated_at=now() where room_id=$1",[t.roomId]);
    // Two buyers, each on their own seat; ids give the order.
    await buy(t,A,'spotlight',{targets:[T1.seat]});
    await buy(t,B,'spotlight',{targets:[T2.seat]});
    const rows=(await t.h.sql("select user_id,target_seats,consumed_at from room_tool_uses where room_id=$1 and tool_code='spotlight' order by id",[t.roomId])).rows;
    assert.deepEqual(rows.map(x=>x.target_seats[0]),[T1.seat,T2.seat]);
    // The free floor is held for the first target; neither the second target nor an outsider may take it.
    assert.equal(await claim(X),false);
    assert.equal(await claim(T2),false);
    assert.equal(await claim(T1),true);
    assert.equal(await spent(),1);
    // T1 finishes; now the second spotlight is the one in force.
    assert.equal((await release(T1)).status,200);
    assert.equal(await claim(X),false);
    assert.equal(await claim(T2),true);
    assert.equal(await spent(),2);
    assert.equal((await release(T2)).status,200);
    // With no spotlight left the floor is first come again.
    assert.equal(await claim(X),true);
    assert.equal((await release(X)).status,200);

    // A new spotlight whose target never claims: after 20 seconds the hold lapses, the outsider
    // takes the floor and the spotlight is spent without the target ever speaking.
    await phase(t,'discuss',2);
    await t.h.sql("update room_state set active_speaker=null,speaker_until=null,updated_at=now() where room_id=$1",[t.roomId]);
    await buy(t,D,'spotlight',{targets:[T1.seat]});
    assert.equal(await claim(X),false);
    await t.h.sql("update room_tool_uses set created_at=now()-interval '21 seconds' where room_id=$1 and phase_number=2",[t.roomId]);
    await t.h.sql("update room_state set updated_at=now()-interval '21 seconds' where room_id=$1",[t.roomId]);
    assert.equal(await claim(X),true);
    assert.equal((await t.h.sql("select consumed_at is not null as spent from room_tool_uses where room_id=$1 and phase_number=2 and tool_code='spotlight'",[t.roomId])).rows[0].spent,true);
    assert.equal((await release(X)).status,200);
    assert.equal(await claim(T1),true);

    // The phase timer wins over a hold still running: the discussion expires, the ballot opens, and no claim is granted.
    await phase(t,'discuss',3);
    await t.h.sql("update room_state set active_speaker=null,speaker_until=null,updated_at=now() where room_id=$1",[t.roomId]);
    await buy(t,A,'spotlight',{targets:[T2.seat]});
    assert.equal(await claim(X),false);
    await expire(t);
    assert.equal((await t.h.call('advance_phase',as(X),{roomId:t.roomId})).json.applied,'ballot-opened');
    assert.equal(await claim(T2),false);
    assert.equal(await claim(X),false);
    assert.equal((await roomState(t)).phase,'vote');
  } finally { await t.close(); }
});

// A day-phase tool bought against the closing of the discussion: it is either recorded (one
// use row, one charge, one public log entry, and the protection works that night) or refused
// before the charge (nothing recorded, nothing spent, no protection), and every seat reads the same.
async function closureRace(tool,schedule) {
  const t=await table(7,{allAccess:true,settings:{silencerEnabled:true},roles:{mafia:1,silencer:1,doctor:1,detective:1,citizen:3}});
  try {
    const r=await t.roster();
    const buyer=r.find(p=>p.role==='citizen' && p.seat!==0), driver=r.find(p=>p.seat!==buyer.seat && p.seat!==0);
    const mafioso=r.find(p=>p.role==='mafia'), silencer=r.find(p=>p.role==='silencer');
    await grant(t,buyer,tool);
    await phase(t,'discuss',1);
    await expire(t);
    const useIt=()=>use(t,buyer,tool);
    const close=()=>t.h.call('advance_phase',as(driver),{roomId:t.roomId});
    let used, closed;
    if(schedule==='use-first') { used=await useIt(); closed=await close(); }
    else if(schedule==='close-first') { closed=await close(); used=await useIt(); }
    else if(schedule==='same-tick-use-leads') [used,closed]=await Promise.all([useIt(),close()]);
    else [closed,used]=await Promise.all([close(),useIt()]);
    assert.equal(closed.status,200,JSON.stringify(closed.json));
    assert.equal(closed.json.applied,'ballot-opened');
    const rows=await useRows(t,buyer,tool), charges=await chargesOf(t,buyer,tool);
    const logged=((await roomState(t)).public_data.toolLog??[]).filter(x=>x.tool===tool);
    const accepted=used.status===200;
    if(accepted) {
      assert.equal(rows.length,1,'recorded once');
      assert.equal(rows[0].phase,'discuss');
      assert.equal(charges,0,'the charge left with the record');
      assert.deepEqual(logged.map(x=>x.seat),[buyer.seat]);
    } else {
      assert.equal(used.status,409,JSON.stringify(used.json));
      assert.equal(used.json.error,'WRONG_PHASE');
      assert.equal(rows.length,0,'nothing recorded');
      assert.equal(charges,1,'nothing spent');
      assert.equal(logged.length,0);
    }
    // Every seat that reconnects reads the same public log.
    const reads=[];
    for(const p of r) reads.push(JSON.stringify((await clientState(t,p)).public_data.toolLog??[]));
    assert.equal(new Set(reads).size,1,'all clients agree on the accepted protection');
    // And the night that follows honours exactly what was recorded.
    await phase(t,'night',2);
    if(tool==='vote_shield') {
      assert.equal((await act(t,silencer,'silence',buyer.seat)).status,200);
      const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
      assert.equal(morning.status,200,JSON.stringify(morning.json));
      assert.equal(morning.json.silencedSeat,accepted?null:buyer.seat);
    } else {
      assert.equal((await act(t,mafioso,'kill',buyer.seat)).status,200);
      const morning=await t.h.call('resolve_night','u0',{roomId:t.roomId});
      assert.equal(morning.status,200,JSON.stringify(morning.json));
      assert.deepEqual(morning.json.victimSeats,accepted?[]:[buyer.seat]);
    }
    return accepted;
  } finally { await t.close(); }
}

test('M1-46 and M1-108 (serial schedules and same-tick; rows stay needs-live): a shield or a lock bought against the closing day is either recorded and honoured, or refused without charge', async () => {
  for(const tool of ['vote_shield','lock_door']) {
    assert.equal(await closureRace(tool,'use-first'),true,`${tool}: bought before the close`);
    assert.equal(await closureRace(tool,'close-first'),false,`${tool}: bought after the close`);
    await closureRace(tool,'same-tick-use-leads');
    await closureRace(tool,'same-tick-close-leads');
  }
});
