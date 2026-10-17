import test from 'node:test';
import assert from 'node:assert/strict';
import { table } from './edge_local_fixture.mjs';

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
