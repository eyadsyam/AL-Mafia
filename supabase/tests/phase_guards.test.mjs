import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { nightComplete, voteComplete, discussionComplete, firstDayPhase } from '../functions/_shared/phase_guards.ts';

const players = [
  {user_id:'host', seat:0, alive:true, role:'mafia'},
  {user_id:'doctor', seat:1, alive:true, role:'doctor'},
  {user_id:'citizen', seat:2, alive:true, role:'citizen'},
  {user_id:'dead', seat:3, alive:false, role:'detective'},
];

assert.equal(nightComplete(players, [{actor_id:'host'}]), false,
  'the host cannot resolve while the doctor is acting');
assert.equal(nightComplete(players, [{actor_id:'host'},{actor_id:'doctor'}]), true);
assert.equal(voteComplete(players, [{voter_id:'host'}], null), false);
assert.equal(voteComplete(players, [{voter_id:'host'},{voter_id:'citizen'}], 1), true,
  'a silenced player owes no ballot');
assert.equal(discussionComplete(players.filter(p=>p.alive), {number:1,seats:[0,1]}, 1), false);
assert.equal(discussionComplete(players.filter(p=>p.alive), {number:1,seats:[0,1,2]}, 1), true);
assert.equal(discussionComplete(players.filter(p=>p.alive), {number:0,seats:[0,1,2]}, 1), false,
  'readiness from a previous day cannot open this ballot');
assert.equal(firstDayPhase({}), 'discuss');
assert.equal(firstDayPhase({openingRoundEnabled:false}), 'discuss');
assert.equal(firstDayPhase({openingRoundEnabled:true}), 'opening');
const source = (name) => readFileSync(new URL(`../functions/${name}/index.ts`, import.meta.url), 'utf8');
assert.match(source('resolve_night'), /!nightComplete\(roster, actions \?\? \[\]\)/);
assert.match(source('resolve_vote'), /!voteComplete\(roster, cast \?\? \[\], silencedSeat\)/);
assert.match(source('open_phase'), /!discussionComplete\(players\.data \?\? \[\], ready, me\.phaseNumber\)/);
assert.match(source('open_phase'), /firstDayPhase\(me\.settings\)/);
assert.match(source('advance_phase'), /firstDayPhase\(me\.settings\)/);
assert.match(source('ready_to_vote'), /p_require_all_seen: true/);
console.log('16 phase guard checks passed');
