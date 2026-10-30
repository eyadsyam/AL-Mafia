// node supabase/tests/match_edges.test.mjs
// A real table on the real Edge Functions: ties, two requests at once, a seat
// coming back in each phase, and what a struck seat can no longer do.
import test from 'node:test';
import assert from 'node:assert/strict';
import { table, phase, expire, night } from './edge_local_fixture.mjs';

const state=(t)=>t.h.sql('select phase,phase_number,public_data from room_state where room_id=$1',[t.roomId]).then(r=>r.rows[0]);
const vote=(t,seat,target)=>t.h.call('submit_vote',`u${seat}`,{roomId:t.roomId,targetSeat:target});
const alive=(t)=>t.h.sql('select count(*)::int n from room_players where room_id=$1 and alive',[t.roomId]).then(r=>r.rows[0].n);
async function strike(t,seat) {
  await t.h.sql("update room_players set last_seen=now(),connected=true,status='connected' where room_id=$1",[t.roomId]);
  await t.h.sql("update room_players set status='left',connected=false,last_seen=now()-interval '2 minutes' where room_id=$1 and seat=$2",[t.roomId,seat]);
  await t.h.sql('select public.age_presence()');
}

test('a tie under «محدش يخرج» eliminates nobody and says no role', async () => {
  const t=await table(7,{settings:{dayTieRule:'noElimination'}});
  try {
    await phase(t,'vote',1);
    for(const [voter,target] of [[0,1],[1,0],[2,1],[3,0]]) {
      const v=await vote(t,voter,target);
      assert.equal(v.status,200,JSON.stringify(v.json));
    }
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.status,200,JSON.stringify(verdict.json));
    assert.equal(verdict.json.eliminatedSeat??null,null);
    assert.equal(verdict.json.eliminatedRole??null,null);
    assert.equal(await alive(t),7);
    assert.deepEqual([...(await state(t)).public_data.lastVote.tiedSeats].sort(),[0,1]);
  } finally { await t.close(); }
});

test('a tie under the revote rule narrows to the tied, refuses anyone else, and a second tie stands', async () => {
  const t=await table(7,{settings:{dayTieRule:'revote'}});
  try {
    await phase(t,'vote',1);
    for(const [voter,target] of [[0,1],[1,0],[2,1],[3,0]]) assert.equal((await vote(t,voter,target)).status,200);
    assert.equal((await t.h.call('resolve_vote','u0',{roomId:t.roomId})).status,200);
    const open=await state(t);
    assert.equal(open.phase,'vote');
    assert.equal(open.public_data.revote.round,2);
    const outsider=await vote(t,2,3);
    assert.notEqual(outsider.status,200,'a seat outside the tie took a vote');
    for(const [voter,target] of [[0,1],[1,0],[2,1],[3,0]]) assert.equal((await vote(t,voter,target)).status,200);
    const second=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(second.status,200,JSON.stringify(second.json));
    assert.equal(second.json.eliminatedSeat??null,null);
    assert.equal((await state(t)).phase,'verdict');
    assert.equal(await alive(t),7);
  } finally { await t.close(); }
});

test('two seats ending the same ballot at once eliminate once', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    const named=r.find(p=>p.role==='citizen'&&p.seat!==0);
    await phase(t,'vote',1);
    for(const p of r) if(p.seat!==named.seat) assert.equal((await vote(t,p.seat,named.seat)).status,200);
    const both=await Promise.all([
      t.h.call('resolve_vote','u0',{roomId:t.roomId}),
      t.h.call('resolve_vote','u1',{roomId:t.roomId}),
    ]);
    assert.equal(both.filter(x=>x.status===200).length>=1,true,JSON.stringify(both.map(x=>x.json)));
    assert.equal(await alive(t),6,'one vote took two seats');
    assert.equal(Object.keys((await state(t)).public_data.eliminations).length,1);
  } finally { await t.close(); }
});

test('two seats ending the same night at once kill once', async () => {
  const t=await table();
  try {
    const r=await t.roster();
    const victim=r.find(p=>p.role==='citizen');
    await night(t);
    for(const p of r) {
      if(p.role!=='mafia') continue;
      assert.equal((await t.h.call('submit_night_action',`u${p.seat}`,{roomId:t.roomId,action:'kill',targetSeat:victim.seat})).status,200);
    }
    await Promise.all([
      t.h.call('resolve_night','u0',{roomId:t.roomId}),
      t.h.call('resolve_night','u1',{roomId:t.roomId}),
    ]);
    assert.equal(await alive(t),6);
    assert.equal((await state(t)).phase,'morning');
  } finally { await t.close(); }
});

test('a repeated ballot counts once', async () => {
  const t=await table();
  try {
    await phase(t,'vote',1);
    await Promise.all([vote(t,2,1),vote(t,2,1)]);
    const rows=(await t.h.sql('select count(*)::int n from votes where room_id=$1',[t.roomId])).rows[0].n;
    assert.equal(rows,1);
    const verdict=await t.h.call('resolve_vote','u0',{roomId:t.roomId});
    assert.equal(verdict.json.lastVote?.tally?.['1']??(await state(t)).public_data.lastVote.tally['1'],1);
  } finally { await t.close(); }
});

for(const name of ['reveal','night','morning','opening','discuss','vote','verdict']) {
  test(`a seat back after a blip in ${name} keeps its seat, its role and its life, and nothing is said of it`, async () => {
    const t=await table();
    try {
      const before=(await t.roster()).find(p=>p.seat===3);
      await phase(t,name,1);
      await t.h.sql("update room_players set connected=false,status='away',last_seen=now()-interval '60 seconds' where room_id=$1 and seat=3",[t.roomId]);
      await t.h.sql('select public.age_presence()');
      const code=(await t.h.sql('select code from rooms where id=$1',[t.roomId])).rows[0].code;
      const back=await t.h.call('join_room','u3',{code,name:'Player 3'});
      assert.equal(back.status,200,JSON.stringify(back.json));
      assert.doesNotMatch(JSON.stringify(back.json),/"(mafia|doctor|detective|citizen|silencer|elder|sniper)"/);
      const after=(await t.roster()).find(p=>p.seat===3);
      assert.equal(after.role,before.role);
      assert.equal(after.alive,true);
      assert.equal(after.user_id,before.user_id);
      assert.equal((await state(t)).phase,name,'coming back moved the phase');
    } finally { await t.close(); }
  });
}

test('a struck seat coming back stays out: no vote, no night move, no whisper, and nobody can whisper it', async () => {
  const t=await table(7,{settings:{whisperEnabled:true}});
  try {
    await phase(t,'discuss',1);
    await strike(t,3);
    const code=(await t.h.sql('select code from rooms where id=$1',[t.roomId])).rows[0].code;
    const back=await t.h.call('join_room','u3',{code,name:'Player 3'});
    assert.equal(back.status,200,JSON.stringify(back.json));
    assert.equal((await t.roster()).find(p=>p.seat===3).alive,false,'coming back undid the removal');
    assert.notEqual((await t.h.call('send_whisper','u3',{roomId:t.roomId,toSeat:2,body:'hi'})).status,200,'a struck seat whispered');
    assert.notEqual((await t.h.call('send_whisper','u2',{roomId:t.roomId,toSeat:3,body:'hi'})).status,200,'a whisper went to a struck seat');
    await phase(t,'vote',1);
    assert.notEqual((await vote(t,3,2)).status,200,'a struck seat voted');
    assert.notEqual((await vote(t,2,3)).status,200,'a struck seat was voted for');
    await phase(t,'night',2);
    const r=(await t.roster()).find(p=>p.seat===3);
    const move=await t.h.call('submit_night_action','u3',{roomId:t.roomId,action:r.role==='mafia'?'kill':'suspect',targetSeat:2});
    assert.notEqual(move.status,200,'a struck seat moved in the night');
  } finally { await t.close(); }
});

test('a whisper in flight to a seat struck before it opens is voided', async () => {
  const t=await table(7,{settings:{whisperEnabled:true}});
  try {
    await phase(t,'discuss',1);
    const sent=await t.h.call('send_whisper','u2',{roomId:t.roomId,toSeat:3,body:'hi'});
    assert.equal(sent.status,200,JSON.stringify(sent.json));
    await strike(t,3);
    const row=(await t.h.sql('select voided from whisper_meta where room_id=$1',[t.roomId])).rows[0];
    assert.equal(row.voided,true);
  } finally { await t.close(); }
});

test('an expired phase asked to move by two seats at once moves once', async () => {
  const t=await table();
  try {
    await phase(t,'morning',1);
    await expire(t);
    const both=await Promise.all([
      t.h.call('open_phase','u1',{roomId:t.roomId,phase:'discuss'}),
      t.h.call('open_phase','u2',{roomId:t.roomId,phase:'discuss'}),
    ]);
    assert.ok(both.some(x=>x.status===200),JSON.stringify(both.map(x=>x.json)));
    const s=await state(t);
    assert.equal(s.phase,'discuss');
    assert.equal(s.phase_number,1);
  } finally { await t.close(); }
});
