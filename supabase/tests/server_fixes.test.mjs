// node supabase/tests/server_fixes.test.mjs
// 2026-10-09 server fixes: pure helpers and the edge contracts. No network, keys or database.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  appealCounts, appealUpheld, floorBonusSeconds, graveVoters, pendingFloorBonuses,
  unsilenceable, whisperAnswer,
} from '../functions/_shared/tools.ts';
import { isMafiaTeam, MAFIA_TEAM_ROLES } from '../functions/_shared/teams.ts';
import { ensureRoleAccess } from '../functions/_shared/purchase_access.ts';
import { economyCall } from '../functions/_shared/economy_actions.ts';

const use = (seat, tool_code, phase_number, extra = {}) => ({
  id: seat * 100 + phase_number, user_id: `u${seat}`, seat, tool_code, phase: 'discuss',
  phase_number, target_seats: [], note: null, consumed_at: null, ...extra,
});

// 3. one team helper.
assert.deepEqual([...MAFIA_TEAM_ROLES], ['mafia', 'silencer']);
assert.ok(isMafiaTeam('silencer') && isMafiaTeam('mafia'));
assert.ok(!isMafiaTeam('citizen') && !isMafiaTeam(null) && !isMafiaTeam('sniper'));
assert.equal(whisperAnswer(use(0, 'sense', 1, { target_seats: [3] }), () => 'silencer'), true);
for (const file of ['resolve_night', 'resolve_vote', 'my_team', 'advance_phase', 'submit_night_action']) {
  const src = readFileSync(new URL(`../functions/${file}/index.ts`, import.meta.url), 'utf8');
  assert.ok(!/\["mafia", "silencer"\]/.test(src), `${file} still carries its own team list`);
}

// 4. start_match refuses a role switched on through the body by a non-owner.
{
  const calls = [];
  const db = { rpc: async (name, args) => { calls.push([name, args]); return { data: false, error: null }; } };
  assert.equal(await ensureRoleAccess(db, 'u1', { silencerEnabled: true }), false);
  assert.equal(calls[0][1].p_item, 'role_silencer');
  assert.equal(await ensureRoleAccess(db, 'u1', { silencerEnabled: false }), true);
  const src = readFileSync(new URL('../functions/start_match/index.ts', import.meta.url), 'utf8');
  assert.match(src, /ensureRoleAccess\(db, userId, effectiveSettings\)/);
}

// 5. vote_shield bought on day N covers night N + 1 only.
assert.ok(unsilenceable([use(4, 'vote_shield', 3)], 4).has(4));
assert.ok(!unsilenceable([use(4, 'vote_shield', 3)], 3).has(4));
assert.ok(!unsilenceable([use(4, 'vote_shield', 3)], 5).has(4));

// 6. a grave vote counts on the day it was bought, not the day after.
assert.ok(graveVoters([use(2, 'grave_vote', 3)], 3).has(2));
assert.ok(!graveVoters([use(2, 'grave_vote', 3)], 4).has(2));
assert.ok(!graveVoters([use(2, 'grave_vote', 3)], 2).has(2));

// 7. the floor bonus is spent by the first granted claim.
{
  const uses = [use(5, 'extra_minute', 2), use(5, 'objection', 2)];
  assert.equal(floorBonusSeconds(uses, 2, 5), 75);
  assert.equal(pendingFloorBonuses(uses, 2, 5).length, 2);
  const spent = uses.map((u) => ({ ...u, consumed_at: '2026-10-09T00:00:00Z' }));
  assert.equal(floorBonusSeconds(spent, 2, 5), 0, 'a second claim must not get the bonus');
  assert.equal(floorBonusSeconds([uses[0], { ...uses[1], consumed_at: 'x' }], 2, 5), 45);
  assert.equal(floorBonusSeconds(uses, 2, 6), 0);
}

// 8. appeal: numerator and denominator come from the same counted ballots.
{
  const ballots = [
    ...['v1', 'v2', 'v3', 'v4'].map((voter) => ({ voter, target: 'a', weight: 1 })),
    { voter: 'v5', target: 'b', weight: 1 },
    { voter: 'a', target: 'b', weight: 1 }, // the appellant's own ballot is ignored
  ];
  const { confirm, voters } = appealCounts(ballots, 'a');
  assert.deepEqual({ confirm, voters }, { confirm: 4, voters: 5 });
  assert.equal(appealUpheld(confirm, voters), true);
  const weighted = [{ voter: 'g', target: 'a', weight: 2 }, { voter: 'h', target: 'b', weight: 1 }];
  assert.deepEqual(appealCounts(weighted, 'a'), { confirm: 2, voters: 3 });
  assert.equal(appealUpheld(2, 3), false);
  assert.deepEqual(appealCounts([], 'a'), { confirm: 0, voters: 0 });
}

// 11. a silence cannot land on a seat that died the same night.
{
  const src = readFileSync(new URL('../functions/_shared/night_core.ts', import.meta.url), 'utf8');
  assert.match(src, /!deaths\.has\(a\.target_id\)/);
}

// 13. toolBuy forwards an optional idempotency key.
{
  const key = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
  const me = '11111111-1111-4111-8111-111111111111';
  assert.equal(economyCall({ action: 'toolBuy', tool: 'sense', pack: 1, requestId: key }, me).args.p_request, key);
  assert.equal(economyCall({ action: 'toolBuy', tool: 'sense', pack: 1 }, me).args.p_request, null);
}
console.log('server_fixes.test.mjs ok');
