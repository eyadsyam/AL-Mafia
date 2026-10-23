import test from 'node:test';
import assert from 'node:assert/strict';
import { table, night, phase, expire } from './edge_local_fixture.mjs';

test('decided outcome survives both resolutions without another death, and result opens directly', async () => {
  for (const current of ['vote', 'night', 'discuss']) {
    const t = await table();
    try {
      await phase(t, current);
      await t.h.sql("update room_state set public_data=jsonb_set(public_data,'{outcome}','\"town\"'::jsonb,true) where room_id=$1", [t.roomId]);
      const before = (await t.h.sql('select count(*)::int as n from room_players where room_id=$1 and alive', [t.roomId])).rows[0].n;
      if (current !== 'discuss') {
        const fn = current === 'vote' ? 'resolve_vote' : 'resolve_night';
        const result = await t.h.call(fn, 'u0', { roomId: t.roomId });
        assert.equal(result.status, 200, JSON.stringify(result.json));
        assert.equal(result.json.outcome, 'town');
        const state = (await t.h.sql('select phase,public_data from room_state where room_id=$1', [t.roomId])).rows[0];
        assert.equal(state.phase, current === 'vote' ? 'verdict' : 'morning');
        assert.equal(state.public_data.outcome, 'town');
      }
      assert.equal((await t.h.sql('select count(*)::int as n from room_players where room_id=$1 and alive', [t.roomId])).rows[0].n, before);
      const opened = await t.h.call('open_phase', 'u0', { roomId: t.roomId, phase: 'result' });
      assert.equal(opened.status, 200, JSON.stringify(opened.json));
    } finally { await t.close(); }
  }
});

test('M3-9: start refuses four seats and an unready five-seat roster', async () => {
  const four=await table(4,{start:false});
  try { assert.equal((await four.h.call('start_match','u0',{roomId:four.roomId,roles:{mafia:1,doctor:1,detective:1,citizen:1}})).json.error,'BAD_REQUEST'); }
  finally { await four.close(); }
  const five=await table(5,{start:false,ready:true});
  try {
    const r=await five.roster();
    await five.h.sql('update room_players set lobby_ready=false where room_id=$1 and user_id=$2',[five.roomId,r[1].user_id]);
    const roles={mafia:1,doctor:1,detective:1,citizen:2};
    assert.equal((await five.h.call('start_match','u0',{roomId:five.roomId,roles})).json.error,'NOT_READY');
    const revision=(await five.h.sql('select lobby_revision from rooms where id=$1',[five.roomId])).rows[0].lobby_revision;
    assert.equal((await five.h.call('lobby_ready','u1',{roomId:five.roomId,ready:true,revision})).status,200);
    assert.equal((await five.h.call('start_match','u0',{roomId:five.roomId,roles})).status,200);
  } finally { await five.close(); }
});

test('M3-10: five seats deal legal roles and refuse Elder or Sniper below their minimum', async () => {
  const t=await table(5,{start:false,allAccess:true});
  try {
    for(const [role,flag] of [['elder','elderEnabled'],['sniper','sniperEnabled']]) {
      assert.equal((await t.h.call('start_match','u0',{roomId:t.roomId,roles:{mafia:1,[role]:1,citizen:3},settings:{[flag]:true}})).json.error,'BAD_REQUEST');
    }
    assert.equal((await t.h.call('start_match','u0',{roomId:t.roomId,roles:{mafia:1,doctor:1,detective:1,citizen:2}})).status,200);
    assert.equal((await t.roster()).filter(p=>p.role!==null).length,5);
  } finally { await t.close(); }
});

test('M3-30: expired morning opens optional first-day opening or ordinary discussion; decided morning opens result', async () => {
  for(const [settings,next] of [[{openingRoundEnabled:true},'opening'],[{openingRoundEnabled:false},'discuss']]) {
    const t=await table(7,{settings});
    try {
      await phase(t,'morning'); await expire(t);
      const opened=await t.h.call('open_phase','u1',{roomId:t.roomId,phase:next});
      assert.equal(opened.status,200,JSON.stringify(opened.json));
      assert.equal((await t.h.sql('select phase from room_state where room_id=$1',[t.roomId])).rows[0].phase,next);
    } finally { await t.close(); }
  }
  const done=await table();
  try {
    await phase(done,'morning'); await expire(done);
    await done.h.sql("update room_state set public_data=jsonb_set(public_data,'{outcome}','\"town\"'::jsonb,true) where room_id=$1",[done.roomId]);
    assert.equal((await done.h.call('open_phase','u1',{roomId:done.roomId,phase:'result'})).status,200);
  } finally { await done.close(); }
});

test('M3-35: expired verdict opens a numbered night if undecided or result if won', async () => {
  for(const decided of [false,true]) {
    const t=await table();
    try {
      await phase(t,'verdict'); await expire(t);
      if(decided) await t.h.sql("update room_state set public_data=jsonb_set(public_data,'{outcome}','\"town\"'::jsonb,true) where room_id=$1",[t.roomId]);
      const next=decided?'result':'night';
      assert.equal((await t.h.call('open_phase','u1',{roomId:t.roomId,phase:next})).status,200);
      const state=(await t.h.sql('select phase,phase_number,public_data from room_state where room_id=$1',[t.roomId])).rows[0];
      assert.equal(state.phase,next);
      if(decided) assert.equal(state.public_data.standings.length,7);
      else assert.equal(state.phase_number,2);
    } finally { await t.close(); }
  }
});

test('M3-15: host claim waits for stale presence and gives the lowest connected seat one host', async () => {
  const t=await table(5,{start:false});
  try {
    const roster=await t.roster(), host=roster[0], first=roster[1];
    const early=await t.h.call('claim_host','u1',{roomId:t.roomId});
    assert.equal(early.status,200,JSON.stringify(early.json));
    assert.equal(early.json.claimed,false);
    await t.h.sql("update room_players set last_seen=now()-interval '31 seconds' where room_id=$1 and user_id=$2",[t.roomId,host.user_id]);
    const late=await t.h.call('claim_host','u1',{roomId:t.roomId});
    assert.equal(late.status,200,JSON.stringify(late.json));
    assert.equal(late.json.hostId,first.user_id);
    assert.equal((await t.h.call('claim_host','u2',{roomId:t.roomId})).json.hostId,first.user_id);
    assert.equal((await t.h.sql('select host_id from rooms where id=$1',[t.roomId])).rows[0].host_id,first.user_id);
  } finally { await t.close(); }
});

test('M3-48: named floor owner alone claims; repeated release never clears the next speaker', async () => {
  const t=await table(7,{settings:{discussionMode:'structured'}});
  try {
    await phase(t,'opening');
    await t.h.sql("update room_state set public_data=jsonb_set(public_data,'{openingSeat}','0'::jsonb,true) where room_id=$1",[t.roomId]);
    assert.equal((await t.h.call('claim_floor','u1',{roomId:t.roomId})).json.granted,false);
    assert.equal((await t.h.call('claim_floor','u0',{roomId:t.roomId})).json.granted,true);
    assert.equal((await t.h.call('release_floor','u0',{roomId:t.roomId})).status,200);
    await phase(t,'discuss');
    assert.equal((await t.h.call('claim_floor','u1',{roomId:t.roomId})).json.granted,true);
    assert.equal((await t.h.call('release_floor','u0',{roomId:t.roomId})).status,200);
    assert.equal((await t.h.sql('select active_speaker from room_state where room_id=$1',[t.roomId])).rows[0].active_speaker,(await t.roster())[1].user_id);
  } finally { await t.close(); }
});

test('M3-56: eligible finished player gets one receipt on repeated sync; deciding kick voids reward', async () => {
  const t=await table(5,{roles:{mafia:1,doctor:1,detective:1,citizen:2}});
  try {
    await t.h.sql('update economy_config set economy_v11_enabled=true where id=true');
    await t.h.sql("update rooms set started_at=now()-interval '4 minutes' where id=$1",[t.roomId]);
    await phase(t,'vote');
    const r=await t.roster(), mafia=r.find(p=>p.role==='mafia');
    for(const p of r) assert.equal((await t.h.call('submit_vote',`u${p.seat}`,{roomId:t.roomId,targetSeat:p.seat===mafia.seat?r.find(q=>q.role==='citizen').seat:mafia.seat,actionId:crypto.randomUUID()})).status,200);
    assert.equal((await t.h.call('resolve_vote','u0',{roomId:t.roomId})).status,200);
    assert.equal((await t.h.call('open_phase','u0',{roomId:t.roomId,phase:'result'})).status,200);
    for(let i=0;i<2;i++) assert.equal((await t.h.call('economy','u0',{action:'sync'})).status,200);
    assert.equal((await t.h.sql('select count(*)::int as n from match_receipts where user_id=$1 and room_id=$2',[r[0].user_id,t.roomId])).rows[0].n,1);
  } finally { await t.close(); }
  const removed=await table(5,{roles:{mafia:1,doctor:1,detective:1,citizen:2}});
  try {
    await removed.h.sql('update economy_config set economy_v11_enabled=true where id=true');
    await removed.h.sql("update rooms set started_at=now()-interval '4 minutes' where id=$1",[removed.roomId]);
    const r=await removed.roster(), mafia=r.find(p=>p.role==='mafia'), host=r[0];
    if(mafia.seat===host.seat) {
      const citizen=r.find(p=>p.role==='citizen');
      await removed.h.sql("update room_players set role=case when user_id=$2 then 'citizen' when user_id=$3 then 'mafia' else role end where room_id=$1",[removed.roomId,mafia.user_id,citizen.user_id]);
    }
    const target=(await removed.roster()).find(p=>p.role==='mafia');
    await phase(removed,'vote');
    for(const p of await removed.roster()) assert.equal((await removed.h.call('submit_vote',`u${p.seat}`,{roomId:removed.roomId,targetSeat:p.seat===target.seat?r.find(q=>q.seat!==target.seat).seat:target.seat,actionId:crypto.randomUUID()})).status,200);
    assert.equal((await removed.h.call('kick_player','u0',{roomId:removed.roomId,seat:target.seat})).status,200);
    await removed.h.sql("update rooms set status='finished',ended_at=now() where id=$1",[removed.roomId]);
    await removed.h.sql("update room_state set phase='result',public_data=jsonb_set(public_data,'{outcome}','\"town\"'::jsonb,true) where room_id=$1",[removed.roomId]);
    assert.equal((await removed.h.call('economy','u0',{action:'sync'})).status,200);
    assert.equal((await removed.h.sql('select count(*)::int as n from match_receipts where room_id=$1',[removed.roomId])).rows[0].n,0);
  } finally { await removed.close(); }
});

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
