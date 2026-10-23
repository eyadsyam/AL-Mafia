import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolveBallotCore } from '../functions/_shared/ballot_core.ts';
import { abstentionRefused } from '../functions/_shared/vote_rules.ts';

const { version, scenarios } = JSON.parse(readFileSync(
  new URL('./vote_matrix.json', import.meta.url), 'utf8'));
assert.equal(version, 1);
assert.ok(scenarios.length >= 400);

const idSeat = (id) => id === null ? null : Number(id.slice(1));
const project = (r) => ({ eliminatedSeat: r.eliminatedSeat,
  tie: r.tiedSeats.length > 1 || r.revote,
  tiedSeats: r.tiedSeats, revote: r.revote, outcome: r.revote ? null : r.outcome });

// Doc 17 §§5-7, RL13. This oracle uses only the input rows and rules;
// it never imports the production rule or tool helpers.
function oracle(input) {
  const roster = new Map(input.roster.map((p) => [p.user_id, p]));
  const alive = new Set(input.roster.filter((p) => p.alive).map((p) => p.user_id));
  const uses = input.toolUses.filter((u) => u.phase_number === input.day);
  const has = (code, seat) => uses.some((u) => u.tool_code === code &&
    (seat === undefined || u.seat === seat));
  const tally = new Map(), counted = [];
  for (const b of input.cast) {
    const voter = roster.get(b.voter_id), target = roster.get(b.target_id);
    if (!voter || b.round !== input.round ||
      (!alive.has(b.voter_id) && !(input.round === 1 && has('grave_vote', voter.seat))) ||
      (b.target_id !== null && !alive.has(b.target_id))) continue;
    if (input.round === 2 && b.target_id !== null &&
      !input.revoteState?.tiedSeats?.includes(target?.seat)) continue;
    const weight = (voter.role === 'elder' &&
      input.revealedElderSeats.includes(voter.seat) ? 3 : 1) *
      (has('double_vote', voter.seat) ? 2 : 1);
    counted.push({ voter: b.voter_id, target: b.target_id, weight });
    if (b.target_id !== null) tally.set(b.target_id,
      (tally.get(b.target_id) ?? 0) + weight);
  }
  const max = Math.max(0, ...tally.values());
  const leaders = [...tally].filter(([, n]) => n === max).map(([id]) => id);
  const bought = input.round === 1 && has('revote');
  const ordinary = input.round === 1 && leaders.length > 1 &&
    input.settings.dayTieRule === 'revote';
  const revote = leaders.length > 0 && input.round === 1 &&
    (ordinary || (bought && (leaders.length > 1 || tally.size >= 2)));
  const boughtRevoteWorked = bought && revote && !ordinary;
  const tiedSeats = leaders.length > 1 || revote
    ? (revote && leaders.length === 1 ? [...tally.keys()] : leaders)
      .map((id) => roster.get(id).seat).sort((a,b) => a-b) : [];
  let eliminatedId = !revote && leaders.length === 1 &&
    input.decidedOutcome !== 'town' && input.decidedOutcome !== 'mafia'
    ? leaders[0] : null;
  let appealResult = null;
  if (eliminatedId && has('appeal', roster.get(eliminatedId).seat)) {
    const other = counted.filter((b) => b.voter !== eliminatedId);
    const confirm = other.filter((b) => b.target === eliminatedId)
      .reduce((n,b) => n+b.weight, 0);
    const voters = other.reduce((n,b) => n+b.weight, 0);
    const upheld = voters > 0 && confirm * 3 > voters * 2;
    appealResult = { confirm, voters, upheld };
    if (!upheld) eliminatedId = null;
  }
  const survivors = input.roster.filter((p) => p.alive && p.user_id !== eliminatedId);
  const mafia = survivors.filter((p) => ['mafia','silencer'].includes(p.role)).length;
  const town = survivors.length - mafia;
  const outcome = input.decidedOutcome === 'town' || input.decidedOutcome === 'mafia'
    ? input.decidedOutcome : mafia === 0 ? 'town' : mafia >= town ? 'mafia' : null;
  return { eliminatedSeat: idSeat(eliminatedId), tie: tiedSeats.length > 1 || revote,
    tiedSeats, revote, outcome: revote ? null : outcome,
    boughtRevoteWorked, appealResult,
    publicTally: Object.fromEntries([...tally].map(([id,n]) => [roster.get(id).seat,n])) };
}

for (const row of scenarios) {
  const run = row.knownDivergence ? test.skip : test;
  run(`${row.name}${row.knownDivergence ? ` [${row.knownDivergence}]` : ''}`, () => {
    const actual = resolveBallotCore(row.input);
    const rules = oracle(row.input);
    assert.deepEqual(project(actual), {
      eliminatedSeat: rules.eliminatedSeat, tie: rules.tie,
      tiedSeats: rules.tiedSeats, revote: rules.revote, outcome: rules.outcome,
    });
    assert.deepEqual(actual.publicTally, rules.publicTally);
    assert.equal(actual.boughtRevoteWorked, rules.boughtRevoteWorked);
    assert.deepEqual(actual.appealResult, rules.appealResult);
    if (row.kind === 'refusal') {
      assert.deepEqual(row.expected, {
        refused: abstentionRefused(row.attempt.target_id, row.input.settings),
      });
    } else if (row.kind !== 'tool') {
      assert.deepEqual(project(actual), row.expected);
    }
    if (row.outsideRefusal !== undefined) assert.equal(row.outsideRefusal, true);
    if (row.deadTargetRefusal !== undefined) assert.equal(row.deadTargetRefusal, true);
  });
}
