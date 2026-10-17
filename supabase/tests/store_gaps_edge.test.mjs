import test from 'node:test';
import assert from 'node:assert/strict';
import { table, phase } from './edge_local_fixture.mjs';

// Evidence `edge-local`: the real edge functions run against PGlite through
// tool/edge_harness. Single connection: every schedule here is serial (or a
// same-tick Promise.all that PGlite still runs one after another), so the rows
// that name a real race keep `needs-live` in docs/plans/audit/M4-store.md.

const as = p => `u${p.seat}`;
const isTeam = p => p.role === 'mafia' || p.role === 'silencer';
const chargesOf = async (t, p, tool) => (await t.h.sql('select charges from player_tool_charges where user_id=$1 and tool_code=$2', [p.user_id, tool])).rows[0]?.charges ?? 0;
const grant = (t, p, tool, n = 1) => t.h.sql('insert into player_tool_charges(user_id,tool_code,charges) values($1,$2,$3) on conflict (user_id,tool_code) do update set charges=excluded.charges', [p.user_id, tool, n]);
const use = (t, p, tool, { targets = [], note } = {}) => t.h.call('economy', as(p), { action: 'toolUse', roomId: t.roomId, tool, targets, ...(note === undefined ? {} : { note }) });
// A purchase as the table sees it: one charge bought, the tool used, the charge gone.
async function buy(t, p, tool, opts) {
  await grant(t, p, tool, 1);
  const r = await use(t, p, tool, opts);
  assert.equal(r.status, 200, `${tool}: ${JSON.stringify(r.json)}`);
  assert.equal(await chargesOf(t, p, tool), 0, `${tool} spent exactly its charge`);
  return r.json;
}
const vote = (t, p, seat, extra = {}) => t.h.call('submit_vote', as(p), { roomId: t.roomId, targetSeat: seat, ...extra });
const act = (t, p, action, seat, extra = {}) => t.h.call('submit_night_action', as(p), { roomId: t.roomId, action, ...(seat === undefined ? {} : { targetSeat: seat }), ...extra });
const alive = async (t, p) => (await t.h.sql('select alive from room_players where room_id=$1 and user_id=$2', [t.roomId, p.user_id])).rows[0].alive;
const publicData = async t => (await t.h.sql('select public_data from room_state where room_id=$1', [t.roomId])).rows[0].public_data;
// What a reconnecting client reads: its own session, the table's grants, no role column.
async function asClient(t, p, read) {
  await t.h.sql('set role authenticated');
  try {
    await t.h.sql("select set_config('request.jwt.claim.sub',$1,false)", [p.user_id]);
    return await read();
  } finally {
    await t.h.sql('reset role');
    await t.h.sql("select set_config('request.jwt.claim.sub','',false)");
  }
}
const clientState = (t, p) => asClient(t, p, async () => (await t.h.sql('select phase,phase_number,public_data from room_state where room_id=$1', [t.roomId])).rows[0]);
const sorted = list => [...list].sort((a, b) => a - b);
// join_room admits 15 at most; larger rooms are seated directly, as the M1 and M3 files do.
async function bigTable(total, { roles, settings = {} }) {
  const seated = Math.min(total, 15);
  const t = await table(seated, { start: false, allAccess: true, settings: { maxPlayers: 15, ...settings } });
  try {
    for (let i = seated; i < total; i++) {
      const id = await t.h.user(`u${i}`);
      await t.h.sql('insert into room_players(room_id,user_id,name,seat) values($1,$2,$3,$4)', [t.roomId, id, `Player ${i}`, i]);
    }
    const started = await t.h.call('start_match', 'u0', { roomId: t.roomId, roles });
    assert.equal(started.status, 200, JSON.stringify(started.json));
    assert.equal((await t.roster()).length, total);
    return t;
  } catch (e) { await t.close(); throw e; }
}
async function openNight(t, number) {
  for (const p of await t.roster()) assert.equal((await t.h.call('saw_role', as(p), { roomId: t.roomId })).status, 200);
  const opened = await t.h.call('open_phase', 'u0', { roomId: t.roomId, phase: 'night' });
  assert.equal(opened.status, 200, JSON.stringify(opened.json));
  if (number !== undefined && number !== 1) await phase(t, 'night', number);
}
// A coin purchase the way the store records it, then the same purchase taken back.
const coinPack = (t, user, token, order) => t.h.sql(
  "select public.commit_play_product($1::uuid,$2,'mm_coins_500',$3,'active',now(),1,public.account_tag($1::uuid)) as r", [user, token, order]);
const refundPack = (t, order) => t.h.sql('select public.revoke_voided_play_purchases(null,array[$1]::text[]) as n', [order]);
const topUp = (t, user, coins) => t.h.sql(
  'insert into wallet_accounts(user_id,balance,lifetime_earned) values($1,$2,$2) on conflict (user_id) do update set balance=wallet_accounts.balance+$2, lifetime_earned=wallet_accounts.lifetime_earned+$2', [user, coins]);

// ── M4-2 ────────────────────────────────────────────────────────────────────
test('M4-2: an unowned or refunded sold role is refused at room create, room update and start; an owned one passes all three', async () => {
  const t = await table(7, { start: false });
  try {
    const { h, roomId } = t;
    const host = (await t.roster())[0];
    const outsider = await h.user('x1');
    const flags = ['silencerEnabled', 'elderEnabled', 'sniperEnabled'];
    const refused = r => { assert.equal(r.status, 403, JSON.stringify(r.json)); assert.equal(r.json.error, 'PURCHASE_REQUIRED'); };
    const settingsOf = async () => (await h.sql('select settings from rooms where id=$1', [roomId])).rows[0].settings;

    // Nothing owned: create, update and start all say no, and write nothing.
    for (const flag of flags) {
      refused(await h.call('create_room', 'x1', { name: 'Host', settings: { [flag]: true } }));
      refused(await h.call('room_settings', 'u0', { roomId, settings: { [flag]: true } }));
      assert.notEqual((await settingsOf())[flag], true, `${flag} reached the stored settings`);
    }
    assert.equal((await h.sql('select count(*)::int as n from rooms where host_id=$1', [outsider])).rows[0].n, 0, 'a refused create left a room');
    const valid = { mafia: 1, silencer: 1, doctor: 1, detective: 1, citizen: 3 };
    refused(await h.call('start_match', 'u0', { roomId, roles: valid, settings: { silencerEnabled: true } }));
    await h.sql(`update rooms set settings=settings||'{"silencerEnabled":true}'::jsonb where id=$1`, [roomId]);
    refused(await h.call('start_match', 'u0', { roomId, roles: valid }));
    await h.sql(`update rooms set settings=settings-'silencerEnabled' where id=$1`, [roomId]);
    assert.equal((await h.sql('select count(*)::int as n from room_players where room_id=$1 and role is not null', [roomId])).rows[0].n, 0, 'a refused start dealt roles');
    assert.equal((await h.sql('select status from rooms where id=$1', [roomId])).rows[0].status, 'lobby');

    // Bought through the store: the three gates open.
    await topUp(t, outsider, 7000);
    assert.equal((await h.call('economy', 'x1', { action: 'buy', item: 'role_silencer' })).status, 200);
    const created = await h.call('create_room', 'x1', { name: 'Host', settings: { silencerEnabled: true } });
    assert.equal(created.status, 200, JSON.stringify(created.json));
    assert.equal((await h.sql('select settings from rooms where id=$1', [created.json.roomId])).rows[0].settings.silencerEnabled, true);
    // Taken back with the coins that bought it: the same create is refused again.
    const outsiderPack = await coinPack(t, outsider, 'edge-pack-token-01', 'GPA.EDGE1');
    assert.equal(outsiderPack.rows[0].r.granted, true);
    await topUp(t, outsider, 5000);
    assert.equal((await h.call('economy', 'x1', { action: 'buy', item: 'role_elder' })).status, 200);
    assert.equal((await refundPack(t, 'GPA.EDGE1')).rows[0].n, 1);
    assert.equal((await h.sql('select public.user_owns_item($1,$2) as owned', [outsider, 'role_elder'])).rows[0].owned, false);
    refused(await h.call('create_room', 'x1', { name: 'Host', settings: { elderEnabled: true } }));

    // The host's own purchase, update, then a refund before the start: the stored flag no longer starts a match.
    await topUp(t, host.user_id, 6000);
    assert.equal((await h.call('economy', 'u0', { action: 'buy', item: 'role_sniper' })).status, 200);
    const sniperTable = { mafia: 2, sniper: 1, doctor: 1, detective: 1, citizen: 2 };
    const updated = await h.call('room_settings', 'u0', { roomId, settings: { sniperEnabled: true } });
    assert.equal(updated.status, 200, JSON.stringify(updated.json));
    assert.equal((await settingsOf()).sniperEnabled, true);
    assert.equal((await coinPack(t, host.user_id, 'edge-pack-token-02', 'GPA.EDGE2')).rows[0].r.granted, true);
    // The pack was granted after the role: the role is not what the refund takes back.
    assert.equal((await refundPack(t, 'GPA.EDGE2')).rows[0].n, 1);
    assert.equal((await h.sql('select public.user_owns_item($1,$2) as owned', [host.user_id, 'role_sniper'])).rows[0].owned, true, 'a role bought before the pack is not taken');
    // A role bought after a pack is taken back with it.
    assert.equal((await coinPack(t, host.user_id, 'edge-pack-token-03', 'GPA.EDGE3')).rows[0].r.granted, true);
    await topUp(t, host.user_id, 5000);
    assert.equal((await h.call('economy', 'u0', { action: 'buy', item: 'role_elder' })).status, 200);
    assert.equal((await refundPack(t, 'GPA.EDGE3')).rows[0].n, 1);
    assert.equal((await h.sql('select public.user_owns_item($1,$2) as owned', [host.user_id, 'role_elder'])).rows[0].owned, false);
    refused(await h.call('room_settings', 'u0', { roomId, settings: { elderEnabled: true } }));
    await h.sql(`update rooms set settings=settings||'{"elderEnabled":true}'::jsonb where id=$1`, [roomId]);
    refused(await h.call('start_match', 'u0', { roomId, roles: { mafia: 1, elder: 1, doctor: 1, detective: 1, citizen: 3 } }));
    await h.sql(`update rooms set settings=settings-'elderEnabled' where id=$1`, [roomId]);
    // The owned sniper starts a match and is dealt exactly once.
    const started = await h.call('start_match', 'u0', { roomId, roles: sniperTable });
    assert.equal(started.status, 200, JSON.stringify(started.json));
    assert.equal((await t.roster()).filter(p => p.role === 'sniper').length, 1);
  } finally { await t.close(); }
});

// ── M4-3 Silencer, online ───────────────────────────────────────────────────
test('M4-3: the Silencer\'s silence lands for the next day; a seat that dies that night is not named; with the Mafia gone the move becomes the kill', async () => {
  const roles = { mafia: 1, silencer: 1, doctor: 1, detective: 1, citizen: 3 };
  const settings = { silencerEnabled: true };
  const pick = async t => {
    const r = await t.roster();
    const citizens = r.filter(p => p.role === 'citizen');
    return { r, mafioso: r.find(p => p.role === 'mafia'), silencer: r.find(p => p.role === 'silencer'), doctor: r.find(p => p.role === 'doctor'), citizens };
  };
  // A. silence one citizen, kill another: both are told in the morning; the silenced seat cannot vote, can be voted out.
  const a = await table(7, { allAccess: true, settings, roles });
  try {
    const { mafioso, silencer, doctor, citizens } = await pick(a);
    const [silenced, victim] = citizens;
    await openNight(a);
    assert.equal((await act(a, silencer, 'silence', silenced.seat)).status, 200);
    assert.equal((await act(a, mafioso, 'kill', victim.seat)).status, 200);
    assert.equal((await act(a, doctor, 'protect', silenced.seat)).status, 200, 'a Doctor cover does not undo a silence');
    const morning = await a.h.call('resolve_night', 'u0', { roomId: a.roomId });
    assert.equal(morning.status, 200, JSON.stringify(morning.json));
    assert.deepEqual(morning.json.victimSeats, [victim.seat]);
    assert.equal(morning.json.silencedSeat, silenced.seat);
    assert.equal((await clientState(a, doctor)).public_data.morning.silencedSeat, silenced.seat, 'everybody reads the silenced seat');
    await phase(a, 'vote', 1);
    assert.equal((await vote(a, silenced, mafioso.seat)).status, 403, 'the silenced seat cannot vote');
    // He can still be voted out: every living seat but himself names him.
    const others = (await a.roster()).filter(p => p.alive && p.seat !== silenced.seat);
    for (const p of others) assert.equal((await vote(a, p, silenced.seat)).status, 200);
    const verdict = await a.h.call('resolve_vote', 'u0', { roomId: a.roomId });
    assert.equal(verdict.status, 200, JSON.stringify(verdict.json));
    assert.equal(verdict.json.eliminatedSeat, silenced.seat);
  } finally { await a.close(); }

  // B. the silenced seat dies the same night: no false silence is announced.
  const b = await table(7, { allAccess: true, settings, roles });
  try {
    const { mafioso, silencer, citizens } = await pick(b);
    await openNight(b);
    assert.equal((await act(b, mafioso, 'kill', citizens[0].seat)).status, 200);
    assert.equal((await act(b, silencer, 'silence', citizens[0].seat)).status, 200);
    const morning = await b.h.call('resolve_night', 'u0', { roomId: b.roomId });
    assert.equal(morning.status, 200, JSON.stringify(morning.json));
    assert.deepEqual(morning.json.victimSeats, [citizens[0].seat]);
    assert.equal(morning.json.silencedSeat, null, 'a dead seat was announced as silenced');
    assert.equal((await clientState(b, citizens[1])).public_data.morning.silencedSeat, null);
  } finally { await b.close(); }

  // C. the Mafia are all out: the Silencer\'s move is stored and counted as the kill.
  const c = await table(7, { allAccess: true, settings, roles });
  try {
    const { mafioso, silencer, citizens } = await pick(c);
    await c.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2', [c.roomId, mafioso.user_id]);
    await openNight(c);
    assert.equal((await act(c, silencer, 'silence', mafioso.seat)).json.error, 'BAD_REQUEST', 'a dead teammate is no target');
    assert.equal((await act(c, silencer, 'silence', silencer.seat)).json.error, 'BAD_REQUEST', 'the inherited kill cannot name its own seat');
    assert.equal((await act(c, silencer, 'silence', citizens[0].seat)).status, 200);
    assert.equal((await c.h.sql('select action from night_actions where room_id=$1 and actor_id=$2', [c.roomId, silencer.user_id])).rows[0].action, 'kill');
    const morning = await c.h.call('resolve_night', 'u0', { roomId: c.roomId });
    assert.equal(morning.status, 200, JSON.stringify(morning.json));
    assert.deepEqual(morning.json.victimSeats, [citizens[0].seat]);
    assert.equal(morning.json.silencedSeat, null);
  } finally { await c.close(); }
});

// ── M4-8 and M4-9 Sniper, online ────────────────────────────────────────────
test('M4-8: the Sniper\'s one shot kills a Mafia seat alone; a miss kills the target and the Sniper', async () => {
  const roles = { mafia: 2, sniper: 1, doctor: 1, detective: 1, citizen: 2 };
  const settings = { sniperEnabled: true };
  const hit = await table(7, { allAccess: true, settings, roles });
  try {
    const r = await hit.roster();
    const sniper = r.find(p => p.role === 'sniper'), doctor = r.find(p => p.role === 'doctor');
    const [m1] = r.filter(p => p.role === 'mafia');
    await openNight(hit);
    assert.equal((await act(hit, doctor, 'protect', m1.seat)).status, 200);
    const shot = await act(hit, sniper, 'suspect', m1.seat, { useBullet: true });
    assert.equal(shot.status, 200, JSON.stringify(shot.json));
    assert.equal(shot.json.bulletSpent, true);
    const morning = await hit.h.call('resolve_night', 'u0', { roomId: hit.roomId });
    assert.equal(morning.status, 200, JSON.stringify(morning.json));
    assert.deepEqual(morning.json.victimSeats, [m1.seat], 'a Doctor cover does not stop the shot and the Sniper lives');
    assert.equal(await alive(hit, sniper), true);
    // The bullet is gone for good: the next night\'s shot is refused, not repeated.
    await phase(hit, 'night', 2);
    const other = r.find(p => p.role === 'mafia' && p.seat !== m1.seat);
    const again = await act(hit, sniper, 'suspect', other.seat, { useBullet: true });
    assert.equal(again.json.error, 'RATE_LIMITED');
    assert.equal((await hit.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2 and used_bullet', [hit.roomId, sniper.user_id])).rows[0].n, 1);
  } finally { await hit.close(); }

  const miss = await table(7, { allAccess: true, settings, roles });
  try {
    const r = await miss.roster();
    const sniper = r.find(p => p.role === 'sniper'), citizen = r.find(p => p.role === 'citizen');
    await openNight(miss);
    assert.equal((await act(miss, sniper, 'suspect', citizen.seat, { useBullet: true })).status, 200);
    const morning = await miss.h.call('resolve_night', 'u0', { roomId: miss.roomId });
    assert.equal(morning.status, 200, JSON.stringify(morning.json));
    assert.deepEqual(sorted(morning.json.victimSeats), sorted([citizen.seat, sniper.seat]));
    assert.doesNotMatch(JSON.stringify(await clientState(miss, r.find(p => p.role === 'doctor'))), /"role"|sniper/);
  } finally { await miss.close(); }

  // A suspicion without the bullet armed kills nobody.
  const quiet = await table(7, { allAccess: true, settings, roles });
  try {
    const r = await quiet.roster();
    const sniper = r.find(p => p.role === 'sniper'), citizen = r.find(p => p.role === 'citizen');
    await openNight(quiet);
    const plain = await act(quiet, sniper, 'suspect', citizen.seat);
    assert.equal(plain.status, 200);
    assert.equal(plain.json.bulletSpent, false);
    const morning = await quiet.h.call('resolve_night', 'u0', { roomId: quiet.roomId });
    assert.deepEqual(morning.json.victimSeats, []);
  } finally { await quiet.close(); }
});

test('M4-9: a dead Sniper, a closed phase, a second shot and the 4, 5, 6, 7 and 20 seat limits; a shot may end the match', async () => {
  const roles = { mafia: 2, sniper: 1, doctor: 1, detective: 1, citizen: 2 };
  const t = await table(7, { allAccess: true, settings: { sniperEnabled: true }, roles });
  try {
    const r = await t.roster();
    const sniper = r.find(p => p.role === 'sniper'), mafia = r.filter(p => p.role === 'mafia'), citizen = r.find(p => p.role === 'citizen');
    // Phase closed: the deal has not been followed by a night.
    assert.equal((await act(t, sniper, 'suspect', mafia[0].seat, { useBullet: true })).json.error, 'PHASE_CLOSED');
    await openNight(t);
    // Not the Sniper's bullet to spend: a Citizen holds none; a bad target is refused before the bullet is touched.
    assert.equal((await act(t, citizen, 'suspect', mafia[0].seat, { useBullet: true })).status, 200, 'a citizen night move is ignored');
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2', [t.roomId, citizen.user_id])).rows[0].n, 0);
    assert.equal((await act(t, sniper, 'suspect', sniper.seat, { useBullet: true })).json.error, 'BAD_REQUEST');
    assert.equal((await act(t, sniper, 'skip', undefined, { useBullet: true })).json.error, 'BAD_REQUEST', 'a shot needs a target');
    assert.equal((await t.h.sql('select count(*)::int as n from night_actions where room_id=$1 and actor_id=$2 and used_bullet', [t.roomId, sniper.user_id])).rows[0].n, 0, 'a refused shot spent the bullet');
    // Dead: refused.
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2', [t.roomId, sniper.user_id]);
    const dead = await act(t, sniper, 'suspect', mafia[0].seat, { useBullet: true });
    assert.equal(dead.status, 403);
    assert.equal(dead.json.error, 'NOT_ALIVE');
    await t.h.sql('update room_players set alive=true where room_id=$1 and user_id=$2', [t.roomId, sniper.user_id]);
    // The shot ends the match: the last Mafia seat dies, town wins in the same resolution.
    await t.h.sql('update room_players set alive=false where room_id=$1 and user_id=$2', [t.roomId, mafia[1].user_id]);
    assert.equal((await act(t, sniper, 'suspect', mafia[0].seat, { useBullet: true })).status, 200);
    const morning = await t.h.call('resolve_night', 'u0', { roomId: t.roomId });
    assert.equal(morning.status, 200, JSON.stringify(morning.json));
    assert.deepEqual(morning.json.victimSeats, [mafia[0].seat]);
    assert.equal(morning.json.outcome, 'town');
    assert.equal((await act(t, sniper, 'suspect', citizen.seat, { useBullet: true })).json.error, 'PHASE_CLOSED', 'no move after the match is decided');
  } finally { await t.close(); }

  // Seat limits at the deal.
  for (const seats of [4, 5, 6]) {
    const small = await table(seats, { start: false, allAccess: true, settings: { sniperEnabled: true } });
    try {
      const deal = seats === 4 ? { mafia: 1, sniper: 1, citizen: 2 } : { mafia: 1, sniper: 1, doctor: 1, citizen: seats - 3 };
      const refused = await small.h.call('start_match', 'u0', { roomId: small.roomId, roles: deal });
      assert.equal(refused.json.error, 'BAD_REQUEST', `${seats} seats`);
      assert.equal((await small.h.sql('select count(*)::int as n from room_players where room_id=$1 and role is not null', [small.roomId])).rows[0].n, 0);
    } finally { await small.close(); }
  }
  const seven = await table(7, { allAccess: true, settings: { sniperEnabled: true }, roles });
  try { assert.equal((await seven.roster()).filter(p => p.role === 'sniper').length, 1); } finally { await seven.close(); }
  const twenty = await bigTable(20, { roles: { mafia: 4, sniper: 1, doctor: 1, detective: 1, citizen: 13 }, settings: { sniperEnabled: true } });
  try {
    const r = await twenty.roster();
    const sniper = r.find(p => p.role === 'sniper'), mafioso = r.find(p => p.role === 'mafia');
    await openNight(twenty);
    assert.equal((await act(twenty, sniper, 'suspect', mafioso.seat, { useBullet: true })).status, 200);
    const morning = await twenty.h.call('resolve_night', 'u0', { roomId: twenty.roomId });
    assert.equal(morning.status, 200, JSON.stringify(morning.json));
    assert.deepEqual(morning.json.victimSeats, [mafioso.seat]);
    assert.equal(morning.json.outcome, null);
  } finally { await twenty.close(); }
});
