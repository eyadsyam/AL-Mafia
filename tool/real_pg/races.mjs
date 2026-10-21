// Races on a real PostgreSQL (local docker only): node --test tool/real_pg/races.mjs
// Each case opens two sessions at once; the first holds its locks for a moment
// so the second lands inside the window a real double tap or retry would hit.
import test, { after as afterAll, before } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { freshDatabase, holding, after } from './harness.mjs';

let db;
before(async () => { db = await freshDatabase(); });
afterAll(async () => { if (db) await db.drop(); });

const one = async (text) => {
  const r = await db.sql(text);
  assert.ok(r.ok, r.err);
  return r.out;
};

test('M4-46: two taps on one catalog item own it once and charge once', async () => {
  const user = await one(`insert into auth.users(id) values(gen_random_uuid()) returning id;`);
  const item = await one(`select code from public.reward_catalog
    where active and released and kind<>'bundle' and coin_price>0 order by coin_price, code limit 1;`);
  const charge = await one(`select public.catalog_charge('${user}','${item}');`);
  await one(`insert into public.wallet_accounts(user_id,balance,lifetime_earned)
    values('${user}',${charge},${charge});`);
  const call = `select public.buy_reward_item('${user}','${item}');`;
  const [a, b] = await Promise.all([db.sql(holding(call)), after(300, db, call)]);
  assert.ok(a.ok, a.err);
  assert.ok(b.ok, b.err);
  assert.equal(await one(`select count(*) from public.player_inventory where user_id='${user}' and item_code='${item}';`), '1');
  assert.equal(await one(`select count(*) from public.wallet_ledger where user_id='${user}' and kind='catalog_spend';`), '1');
  assert.equal(await one(`select balance from public.wallet_accounts where user_id='${user}';`), '0');
});

test('M4-46: two different items racing for coins enough for one keep the balance at zero or above', async () => {
  const user = await one(`insert into auth.users(id) values(gen_random_uuid()) returning id;`);
  const items = (await one(`select code from public.reward_catalog
    where active and released and kind<>'bundle' and coin_price>0 order by coin_price, code limit 2;`)).split('\n');
  assert.equal(items.length, 2);
  const charge = await one(`select greatest(public.catalog_charge('${user}','${items[0]}'),
    public.catalog_charge('${user}','${items[1]}'));`);
  await one(`insert into public.wallet_accounts(user_id,balance,lifetime_earned)
    values('${user}',${charge},${charge});`);
  const [a, b] = await Promise.all([
    db.sql(holding(`select public.buy_reward_item('${user}','${items[0]}');`)),
    after(300, db, `select public.buy_reward_item('${user}','${items[1]}');`),
  ]);
  const refused = [a, b].filter((r) => !r.ok);
  assert.ok(refused.every((r) => r.err.includes('INSUFFICIENT_COINS')), refused.map((r) => r.err).join('; '));
  assert.ok(Number(await one(`select balance from public.wallet_accounts where user_id='${user}';`)) >= 0);
  const owned = Number(await one(`select count(*) from public.player_inventory where user_id='${user}';`));
  const spends = Number(await one(`select count(*) from public.wallet_ledger where user_id='${user}' and kind='catalog_spend';`));
  assert.equal(owned, spends, 'every owned item was paid for exactly once');
});

// ---------------------------------------------------------------------------
// The audit rows that said "needs-live (concurrency)" (docs/plans/audit/
// M1-tools.md, M2-roles.md, M4-store.md). Every test commits its own setup in
// plain sessions, then races the SQL the edge function named in the test sends
// (the db.rpc(...) call or the upsert), then reads the end state back with
// plain queries. `race` keeps the first session's locks for HOLD seconds and
// starts the second DELAY ms later; `waited` is how long the second session
// ran minus that delay (a session that never waits is done in about 400 ms:
// docker exec + psql start-up), so a race that did not overlap fails loudly.

const HOLD = 2;
const DELAY = 500;
const MIN_WAIT = 1000;
const ENDS = '2031-01-01T00:00:00+00';

const race = async (first, second) => {
  const [a, b] = await Promise.all([
    db.sql(holding(first, HOLD)),
    (async () => {
      const t0 = Date.now();
      const r = await after(DELAY, db, second);
      return { ...r, waited: Date.now() - t0 - DELAY };
    })(),
  ]);
  return { first: a, second: b };
};

const firstLine = (r) => r.out.split('\n')[0];

// [overlap] is false only where the FIRST session is refused at once (a refused
// call rolls back and releases every lock, so the second has nothing to wait
// for); the test says so and the diagnostic still shows the measured time.
const waitedAtLeast = (t, label, r, { overlap = true } = {}) => {
  t.diagnostic(`${label}: the second session waited ${r.waited} ms and ${r.ok
    ? `answered ${firstLine(r).slice(0, 60) || 'ok'}` : `was refused: ${r.err.split('\n')[0]}`}`);
  if (overlap) {
    assert.ok(r.waited >= MIN_WAIT,
      `${label}: the second session did not wait (${r.waited} ms), so the two did not overlap`);
  }
};

const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const roomCode = () => Array.from({ length: 6 },
  () => CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)]).join('');
const jsonSql = (value) => JSON.stringify(value).replace(/'/g, "''");
const newUsers = async (n) => (await one(`insert into auth.users(id)
  select gen_random_uuid() from generate_series(1,${n}) returning id;`)).split('\n');

// seat 0 and 1 mafia, 2 detective, 3 doctor, 4 and 5 citizens
const ROLES = ['mafia', 'mafia', 'detective', 'doctor', 'citizen', 'citizen'];

/** Fresh users, a room, its seats (seat i is users[i]) and its state row. */
async function makeRoom({ phase, number = 1, status = 'playing', publicData = {}, settings = {},
  roles = ROLES, dead = [], endsAt = null, startedAt = `now()-interval '10 minutes'` }) {
  const users = await newUsers(roles.length);
  const room = randomUUID();
  const seats = users.map((u, i) => `('${room}','${u}',${i},'Seat${i}',${roles[i] ? `'${roles[i]}'` : 'null'},${!dead.includes(i)},'connected')`).join(',');
  await one(`
    insert into public.rooms(id,code,host_id,status,match_seed,started_at,settings)
      values('${room}','${roomCode()}','${users[0]}','${status}',7,${startedAt},'${jsonSql(settings)}');
    insert into public.room_players(room_id,user_id,seat,name,role,alive,status) values ${seats};
    insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data)
      values('${room}','${phase}',${number},${endsAt ? `'${endsAt}'` : 'null'},'${jsonSql(publicData)}');`);
  return { room, users };
}

const fund = (user, coins) => one(`insert into public.wallet_accounts(user_id,balance,lifetime_earned)
  values('${user}',${coins},${coins});`);
const giveCharges = (user, tool, n) => one(`insert into public.player_tool_charges(user_id,tool_code,charges)
  values('${user}','${tool}',${n}) on conflict (user_id,tool_code) do update set charges=excluded.charges;`);
const useCall = (room, user, tool, { targets = '{}', note = null } = {}) =>
  `select public.use_table_tool('${user}','${room}','${tool}','${targets}'::int[],${note === null ? 'null' : `'${note}'`});`;
const useNow = (room, user, tool, opts) => one(useCall(room, user, tool, opts));

// The write submit_night_action does (supabase/functions/submit_night_action/
// index.ts, db.from("night_actions").upsert(...)): PostgREST sends it as an
// insert ... on conflict (room_id,night,actor_id) do update over the payload.
const nightMove = (room, night, actor, action, target, { bullet = false } = {}) =>
  `insert into public.night_actions(room_id,night,actor_id,action,target_id,note,action_id,used_bullet)
   values('${room}',${night},'${actor}','${action}',${target ? `'${target}'` : 'null'},null,'${randomUUID()}',${bullet})
   on conflict (room_id,night,actor_id) do update set room_id=excluded.room_id,night=excluded.night,
     actor_id=excluded.actor_id,action=excluded.action,target_id=excluded.target_id,note=excluded.note,
     action_id=excluded.action_id,used_bullet=excluded.used_bullet;`;

// --- M4-36: buy_table_tool (economy_actions.ts toolBuy -> db.rpc) ----------

const packPrice = async (tool, pack) => Number(await one(
  `select public.tool_pack_price(coin_price,${pack}) from public.table_tools where code='${tool}';`));

test('M4-36: the same buy request sent twice at once grants the pack once and charges once', async (t) => {
  const [user] = await newUsers(1);
  const price = await packPrice('extra_minute', 1);
  await fund(user, price * 3);
  const request = randomUUID();
  const call = `select public.buy_table_tool('${user}','extra_minute',1,'${request}');`;
  const { first, second } = await race(call, call);
  assert.ok(first.ok, first.err);
  assert.ok(second.ok, second.err);
  waitedAtLeast(t, 'M4-36 same request', second);
  assert.equal(await one(`select charges from public.player_tool_charges where user_id='${user}' and tool_code='extra_minute';`), '1', 'granted once');
  assert.equal(await one(`select count(*) from public.wallet_ledger where user_id='${user}' and kind='tool_spend';`), '1', 'charged once');
  assert.equal(await one(`select balance from public.wallet_accounts where user_id='${user}';`), String(price * 2));
  assert.equal(await one(`select count(*) from public.tool_purchase_requests where user_id='${user}' and request_id='${request}';`), '1');
});

test('M4-36: two different buy requests with coins for one pack: one is granted, the other gets INSUFFICIENT_COINS', async (t) => {
  const [user] = await newUsers(1);
  const price = await packPrice('extra_minute', 1);
  await fund(user, price);
  const [r1, r2] = [randomUUID(), randomUUID()];
  const { first, second } = await race(
    `select public.buy_table_tool('${user}','extra_minute',1,'${r1}');`,
    `select public.buy_table_tool('${user}','extra_minute',1,'${r2}');`);
  assert.ok(first.ok, first.err);
  assert.ok(!second.ok && second.err.includes('INSUFFICIENT_COINS'), second.err);
  waitedAtLeast(t, 'M4-36 two requests', second);
  assert.equal(await one(`select balance from public.wallet_accounts where user_id='${user}';`), '0');
  assert.equal(await one(`select charges from public.player_tool_charges where user_id='${user}' and tool_code='extra_minute';`), '1');
  assert.equal(await one(`select count(*) from public.wallet_ledger where user_id='${user}' and kind='tool_spend';`), '1');
  // The refused request left no trace, so it can be sent again once coins arrive.
  assert.equal(await one(`select string_agg(request_id::text,',') from public.tool_purchase_requests where user_id='${user}';`), r1);
});

// --- M4-43: economy_v3_issue_receipt (called by economy_v3_settle_receipt) --

test('M4-43: the same receipt asked for from two sessions at once is issued once, with the same values', async (t) => {
  const users = await newUsers(6);
  const room = randomUUID();
  const roles = ['citizen', 'mafia', 'citizen', 'citizen', 'citizen', 'citizen'];
  const seats = users.map((u, i) => `('${room}','${u}',${i},'Seat${i}','${roles[i]}','connected')`).join(',');
  const ids = users.map((u) => `'${u}'`).join(',');
  await one(`
    update public.economy_config set economy_v11_enabled=true;
    insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
      values('${room}','${roomCode()}','${users[0]}','finished',1,now()-interval '10 minutes',now());
    insert into public.room_players(room_id,user_id,seat,name,role,status) values ${seats};
    insert into public.room_state(room_id,phase,public_data) values('${room}','result','{"outcome":"town"}');
    begin;
    alter table public.votes disable trigger vote_phase_guard;
    insert into public.votes(room_id,day,voter_id,action_id)
      select '${room}',1,v,gen_random_uuid() from unnest(array[${ids}]::uuid[]) v;
    alter table public.votes enable trigger vote_phase_guard;
    commit;`);
  const call = `select row_to_json(r) from public.economy_v3_issue_receipt('${users[0]}','${room}') r;`;
  const { first, second } = await race(call, call);
  assert.ok(first.ok, first.err);
  assert.ok(second.ok, second.err);
  waitedAtLeast(t, 'M4-43', second);
  const [a, b] = [JSON.parse(firstLine(first)), JSON.parse(firstLine(second))];
  assert.equal(a.user_id, users[0], 'an eligible participant got no receipt');
  assert.deepEqual(b, a, 'the second ask got different values');
  assert.equal(await one(`select count(*) from public.match_receipts where user_id='${users[0]}' and room_id='${room}';`), '1');
  assert.equal(await one(`select day_ordinal from public.match_receipts where user_id='${users[0]}' and room_id='${room}';`), '1');
});

// --- M2-62 and M2-12: submit_night_action's upsert into night_actions ------

test('M2-62: two different investigations sent at once store exactly one; the loser is ALREADY_INVESTIGATED', async (t) => {
  const { room, users } = await makeRoom({ phase: 'night', number: 1 });
  const [detective, mafioso, citizen] = [users[2], users[0], users[4]];
  const { first, second } = await race(
    nightMove(room, 1, detective, 'investigate', mafioso),
    nightMove(room, 1, detective, 'investigate', citizen));
  assert.ok(first.ok, first.err);
  assert.ok(!second.ok && /ALREADY_INVESTIGATED|duplicate key/.test(second.err), second.err);
  waitedAtLeast(t, 'M2-62 fresh night', second);
  assert.equal(await one(`select count(*) from public.night_actions where room_id='${room}';`), '1', 'nothing else was stored');
  assert.equal(await one(`select action||':'||target_id from public.night_actions where room_id='${room}' and actor_id='${detective}';`),
    `investigate:${mafioso}`);
});

test('M2-62: a Detective who skipped and then asks two different questions at once keeps only the first', async (t) => {
  const { room, users } = await makeRoom({ phase: 'night', number: 1 });
  const [detective, mafioso, citizen] = [users[2], users[0], users[4]];
  await one(nightMove(room, 1, detective, 'skip', null));
  const { first, second } = await race(
    nightMove(room, 1, detective, 'investigate', mafioso),
    nightMove(room, 1, detective, 'investigate', citizen));
  assert.ok(first.ok, first.err);
  assert.ok(!second.ok && second.err.includes('ALREADY_INVESTIGATED'), second.err);
  waitedAtLeast(t, 'M2-62 after a skip', second);
  assert.equal(await one(`select count(*) from public.night_actions where room_id='${room}';`), '1');
  assert.equal(await one(`select action||':'||target_id from public.night_actions where room_id='${room}' and actor_id='${detective}';`),
    `investigate:${mafioso}`);
});

test('M2-12: two Mafiosi sending the armed (team bullet) action at once: one bullet, the other BULLET_SPENT', async (t) => {
  const { room, users } = await makeRoom({ phase: 'night', number: 1 });
  const [m1, m2, citizen] = [users[0], users[1], users[4]];
  const { first, second } = await race(
    nightMove(room, 1, m1, 'kill', citizen, { bullet: true }),
    nightMove(room, 1, m2, 'kill', citizen, { bullet: true }));
  assert.ok(first.ok, first.err);
  assert.ok(!second.ok && second.err.includes('BULLET_SPENT'), second.err);
  waitedAtLeast(t, 'M2-12 first arming', second);
  assert.equal(await one(`select count(*) from public.night_actions where room_id='${room}' and used_bullet;`), '1', 'one bullet spent');
  assert.equal(await one(`select actor_id from public.night_actions where room_id='${room}' and used_bullet;`), m1);
  assert.equal(await one(`select count(*) from public.night_actions where room_id='${room}';`), '1', 'the refused move left no row');
});

test('M2-12: two Mafiosi who already acted both arm the bullet at once: one keeps it, the other row is unchanged', async (t) => {
  const { room, users } = await makeRoom({ phase: 'night', number: 1 });
  const [m1, m2, citizen] = [users[0], users[1], users[4]];
  await one(nightMove(room, 1, m1, 'kill', citizen) + nightMove(room, 1, m2, 'kill', citizen));
  const { first, second } = await race(
    nightMove(room, 1, m1, 'kill', citizen, { bullet: true }),
    nightMove(room, 1, m2, 'kill', citizen, { bullet: true }));
  assert.ok(first.ok, first.err);
  assert.ok(!second.ok && second.err.includes('BULLET_SPENT'), second.err);
  waitedAtLeast(t, 'M2-12 second arming', second);
  assert.equal(await one(`select count(*) from public.night_actions where room_id='${room}' and used_bullet;`), '1');
  assert.equal(await one(`select used_bullet::text||':'||action from public.night_actions where room_id='${room}' and actor_id='${m2}';`),
    'false:kill', 'the refused Mafioso kept his earlier, unarmed move');
});

// --- M2-112: start_match -> apply_match_deal -------------------------------

test('M2-112: the same lobby dealt twice at once is dealt once: every seat has one role and the second call is a no-op', async (t) => {
  const { room, users } = await makeRoom({ phase: 'lobby', number: 0, status: 'lobby',
    roles: Array(6).fill(null), startedAt: 'null' });
  const dealA = ['mafia', 'mafia', 'doctor', 'detective', 'citizen', 'citizen'];
  const dealB = ['citizen', 'detective', 'citizen', 'doctor', 'mafia', 'mafia'];
  const deal = (roles) => `select public.apply_match_deal('${room}','${users[0]}','{${roles.join(',')}}'::text[],'{}'::jsonb,now()+interval '60 seconds');`;
  const { first, second } = await race(deal(dealA), deal(dealB));
  assert.ok(first.ok, first.err);
  assert.ok(second.ok, second.err);
  assert.equal(firstLine(first), 't');
  assert.equal(firstLine(second), 'f', 'the second deal was not refused');
  waitedAtLeast(t, 'M2-112', second);
  assert.equal(await one(`select string_agg(role,',' order by seat) from public.room_players where room_id='${room}';`), dealA.join(','),
    'the seats hold the first deal, not a mix');
  assert.equal(await one(`select count(*) from public.room_players where room_id='${room}' and role is not null;`), '6');
  assert.equal(await one(`select status from public.rooms where id='${room}';`), 'playing');
  assert.equal(await one(`select phase||':'||phase_number||':'||(public_data->>'playerCount') from public.room_state where room_id='${room}';`), 'reveal:1:6');
});

// --- M1-7 and M1-26: claim_floor -> claim_floor_with_tools -----------------

const claim = (room, user, number = 2) =>
  `select public.claim_floor_with_tools('${room}','${user}',60,'discuss',${number});`;

test('M1-7: two players claim the floor at once: one holder, and only the holder\'s extra minute is consumed', async (t) => {
  const { room, users } = await makeRoom({ phase: 'discuss', number: 2 });
  const [a, b] = [users[4], users[5]];
  for (const u of [a, b]) {
    await giveCharges(u, 'extra_minute', 1);
    await useNow(room, u, 'extra_minute');
  }
  const { first, second } = await race(claim(room, a), claim(room, b));
  assert.ok(first.ok, first.err);
  assert.ok(second.ok, second.err);
  assert.equal(firstLine(first), 't');
  assert.equal(firstLine(second), 'f', 'a second player was granted the same floor');
  waitedAtLeast(t, 'M1-7 two players', second);
  assert.equal(await one(`select active_speaker from public.room_state where room_id='${room}';`), a);
  assert.equal(await one(`select count(*) from public.room_tool_uses where room_id='${room}' and consumed_at is not null;`), '1');
  assert.equal(await one(`select (consumed_at is not null)::text from public.room_tool_uses where room_id='${room}' and user_id='${a}';`), 'true');
  assert.equal(await one(`select (consumed_at is null)::text from public.room_tool_uses where room_id='${room}' and user_id='${b}';`), 'true',
    'the player who did not get the floor lost his minute');
  assert.equal(await one(`select extract(epoch from speaker_until-updated_at)::int from public.room_state where room_id='${room}';`), '105',
    'the grant is 60 seconds plus one extra minute (45), not two');
});

test('M1-7: one player\'s claim sent twice at once (double tap) is granted once and the extra minute is spent once', async (t) => {
  const { room, users } = await makeRoom({ phase: 'discuss', number: 2 });
  const a = users[4];
  await giveCharges(a, 'extra_minute', 2);
  await useNow(room, a, 'extra_minute');
  const { first, second } = await race(claim(room, a), claim(room, a));
  assert.ok(first.ok, first.err);
  assert.ok(second.ok, second.err);
  assert.equal(firstLine(first), 't');
  assert.equal(firstLine(second), 't', 'the holder asking again keeps the floor');
  waitedAtLeast(t, 'M1-7 double tap', second);
  assert.equal(await one(`select count(*) from public.room_tool_uses where room_id='${room}' and user_id='${a}' and consumed_at is not null;`), '1');
  assert.equal(await one(`select extract(epoch from speaker_until-updated_at)::int from public.room_state where room_id='${room}';`), '105',
    'the second claim did not add a second extra minute');
});

test('M1-26: a spotlight held floor: the named player gets it, the other claimant is refused, the spotlight is consumed once', async (t) => {
  for (const order of ['other-first', 'named-first']) {
    const { room, users } = await makeRoom({ phase: 'discuss', number: 2 });
    const [buyer, named, other] = [users[3], users[2], users[4]];
    await giveCharges(buyer, 'spotlight', 1);
    await useNow(room, buyer, 'spotlight', { targets: '{2}' });
    const [x, y] = order === 'other-first' ? [other, named] : [named, other];
    const { first, second } = await race(claim(room, x), claim(room, y));
    assert.ok(first.ok, first.err);
    assert.ok(second.ok, second.err);
    waitedAtLeast(t, `M1-26 ${order}`, second);
    const results = order === 'other-first' ? { other: firstLine(first), named: firstLine(second) }
      : { named: firstLine(first), other: firstLine(second) };
    assert.deepEqual(results, { other: 'f', named: 't' }, order);
    assert.equal(await one(`select active_speaker from public.room_state where room_id='${room}';`), named);
    assert.equal(await one(`select count(*) from public.room_tool_uses where room_id='${room}' and tool_code='spotlight' and consumed_at is not null;`), '1');
  }
});

test('M1-26: a floor claim racing the phase timer: the extra minute is consumed exactly when the claim was granted', async (t) => {
  for (const order of ['claim-first', 'timer-first']) {
    const { room, users } = await makeRoom({ phase: 'discuss', number: 2, endsAt: ENDS });
    const a = users[4];
    await giveCharges(a, 'extra_minute', 1);
    await useNow(room, a, 'extra_minute');
    const timer = `select public.commit_phase_open('${room}','discuss',2,'${ENDS}'::timestamptz,'vote',2,now()+interval '60 seconds','{}'::jsonb,false);`;
    const claiming = claim(room, a);
    const { first, second } = order === 'claim-first' ? await race(claiming, timer) : await race(timer, claiming);
    assert.ok(first.ok, first.err);
    assert.ok(second.ok, second.err);
    waitedAtLeast(t, `M1-26 ${order}`, second);
    const [claimed, moved] = order === 'claim-first' ? [firstLine(first), firstLine(second)] : [firstLine(second), firstLine(first)];
    assert.equal(moved, 't', 'the phase timer did not move the room');
    assert.equal(await one(`select phase from public.room_state where room_id='${room}';`), 'vote');
    const consumed = await one(`select (consumed_at is not null)::text from public.room_tool_uses where room_id='${room}' and user_id='${a}';`);
    assert.equal(consumed === 'true', claimed === 't', `${order}: the minute was ${consumed === 'true' ? 'consumed' : 'kept'} but the claim answered ${claimed}`);
    assert.equal(claimed, order === 'claim-first' ? 't' : 'f');
  }
});

// --- M1-13: use_table_tool('anon_note') ------------------------------------

test('M1-13: the same anonymous note sent twice at once is stored once, announced once and charged once', async (t) => {
  const { room, users } = await makeRoom({ phase: 'discuss', number: 2 });
  const user = users[4];
  await giveCharges(user, 'anon_note', 2);
  const call = useCall(room, user, 'anon_note', { note: 'one note only' });
  const { first, second } = await race(call, call);
  assert.ok(first.ok, first.err);
  assert.ok(!second.ok && second.err.includes('LIMIT_PHASE'), second.err);
  waitedAtLeast(t, 'M1-13', second);
  assert.equal(await one(`select count(*) from public.room_tool_uses where room_id='${room}' and user_id='${user}' and tool_code='anon_note';`), '1');
  assert.equal(await one(`select jsonb_array_length(public_data->'toolLog') from public.room_state where room_id='${room}';`), '1');
  assert.equal(await one(`select charges from public.player_tool_charges where user_id='${user}' and tool_code='anon_note';`), '1',
    'one of the two charges was spent, not both');
});

// --- M1-46, M1-108, M4-39: use_table_tool racing the commit that closes a phase

/**
 * Buys one charge of [tool] for a living (or, with [seat], chosen) seat, then
 * races the use against [closure] (the commit the resolver / advance_phase
 * sends) in both orders. Reads back what is stored.
 */
async function useVsClosure({ tool, phase, number, order, closure, seat = 4, dead = [], use = {} }) {
  const { room, users } = await makeRoom({ phase, number, endsAt: ENDS, dead });
  const user = users[seat];
  await giveCharges(user, tool, 1);
  const closing = await closure(room, number);
  const using = useCall(room, user, tool, use);
  const { first, second } = order === 'use-first' ? await race(using, closing) : await race(closing, using);
  const [useRes, closeRes] = order === 'use-first' ? [first, second] : [second, first];
  return {
    room, user, use: useRes, close: closeRes, second,
    charges: Number(await one(`select charges from public.player_tool_charges where user_id='${user}' and tool_code='${tool}';`)),
    uses: JSON.parse(await one(`select coalesce(json_agg(json_build_object('phase',phase,'number',phase_number,'at',created_at)),'[]')
      from public.room_tool_uses where room_id='${room}' and user_id='${user}' and tool_code='${tool}';`)),
    toolLog: Number(await one(`select coalesce(jsonb_array_length(public_data->'toolLog'),0) from public.room_state where room_id='${room}';`)),
    state: await one(`select phase||':'||phase_number from public.room_state where room_id='${room}';`),
  };
}

/** Never charged-and-ignored: a charge is spent exactly when a use is recorded. */
function assertUseOrRefusal(t, label, res, { recorded, refusal, overlap = true }) {
  waitedAtLeast(t, `${label} (second: ${res.second === res.use ? 'the tool use' : 'the closing commit'})`, res.second, { overlap });
  const spent = 1 - res.charges;
  assert.equal(spent, res.uses.length, `${label}: ${spent} charge(s) spent for ${res.uses.length} recorded use(s)`);
  assert.equal(res.toolLog, res.uses.length, `${label}: the table log and the use rows disagree`);
  if (recorded) {
    assert.ok(res.use.ok, `${label}: ${res.use.err}`);
    assert.equal(res.uses.length, 1, label);
  } else {
    assert.equal(res.uses.length, 0, `${label}: a refused use left a row`);
    assert.ok(!res.use.ok && res.use.err.includes(refusal), `${label}: ${res.use.err}`);
    assert.equal(res.charges, 1, `${label}: a refused use charged`);
  }
}

// The day closing (advance_phase / open_phase -> commit_phase_open, discuss -> vote).
const dayCloses = async (room, n) =>
  `select public.commit_phase_open('${room}','discuss',${n},'${ENDS}'::timestamptz,'vote',${n},now()+interval '60 seconds','{}'::jsonb,false);`;

// The night resolution (resolve_night -> commit_night_roles_resolution, night -> morning),
// with the fingerprint of the moves the resolver tallied before the use.
const nightCommits = (patch = {}) => async (room, n) => {
  const fingerprint = await one(`select public.night_fingerprint('${room}',${n});`);
  return `select public.commit_night_roles_resolution('${room}',${n},'{}'::uuid[],null,'{}'::jsonb,'${jsonSql(patch)}'::jsonb,'morning',now()+interval '60 seconds','${fingerprint}');`;
};

for (const [row, tool] of [['M1-46', 'vote_shield'], ['M1-108', 'lock_door']]) {
  test(`${row}: a ${tool} racing the day closing is recorded before it (and the next night reads it) or refused without a charge`, async (t) => {
    const useFirst = await useVsClosure({ tool, phase: 'discuss', number: 2, order: 'use-first', closure: dayCloses });
    assertUseOrRefusal(t, `${row} use first`, useFirst, { recorded: true });
    // What resolve_night reads for night 3 (tools.ts coversNight): this day's number, not a night phase.
    assert.deepEqual([useFirst.uses[0].number, useFirst.uses[0].phase], [2, 'discuss']);
    assert.equal(firstLine(useFirst.close), 't');
    assert.equal(useFirst.state, 'vote:2');

    const closeFirst = await useVsClosure({ tool, phase: 'discuss', number: 2, order: 'closure-first', closure: dayCloses });
    assertUseOrRefusal(t, `${row} closing first`, closeFirst, { recorded: false, refusal: 'WRONG_PHASE' });
    assert.equal(firstLine(closeFirst.close), 't');
    assert.equal(closeFirst.state, 'vote:2');
  });

  test(`${row}: a ${tool} racing the night resolution commit is refused without a charge, or recorded in the morning the next night reads`, async (t) => {
    // The use meets the night itself: refused at once, so it holds nothing and
    // the commit behind it has nothing to wait for (no overlap in this order).
    const useFirst = await useVsClosure({ tool, phase: 'night', number: 2, order: 'use-first', closure: nightCommits() });
    assertUseOrRefusal(t, `${row} use first`, useFirst, { recorded: false, refusal: 'WRONG_PHASE', overlap: false });
    assert.equal(firstLine(useFirst.close), 't');
    assert.equal(useFirst.state, 'morning:2');

    const closeFirst = await useVsClosure({ tool, phase: 'night', number: 2, order: 'closure-first', closure: nightCommits() });
    assertUseOrRefusal(t, `${row} night first`, closeFirst, { recorded: true });
    assert.deepEqual([closeFirst.uses[0].number, closeFirst.uses[0].phase], [2, 'morning']);
    assert.equal(firstLine(closeFirst.close), 't');
  });
}

test('M1-46: a vote tool bought while the ballot commits changes the tally the commit checks, or is refused without a charge', async (t) => {
  // resolve_vote tallies, then commit_resolution recomputes vote_fingerprint
  // under the room lock (tool_guards.sql T1): a tally made before a revote was
  // bought must not commit.
  let stale;
  const ballotCommits = async (room, n) => {
    stale = await one(`select public.vote_fingerprint('${room}',${n},1);`);
    return `select public.commit_resolution('${room}','vote',${n},1,null,null,'{}'::jsonb,'{}'::jsonb,'verdict',now()+interval '30 seconds','${stale}');`;
  };
  const useFirst = await useVsClosure({ tool: 'revote', phase: 'vote', number: 2, order: 'use-first', closure: ballotCommits });
  assertUseOrRefusal(t, 'M1-46 revote first', useFirst, { recorded: true });
  assert.equal(firstLine(useFirst.close), 'f', 'a tally made before the revote was bought committed');
  assert.equal(useFirst.state, 'vote:2', 'the ballot moved on a stale tally');
  assert.notEqual(await one(`select public.vote_fingerprint('${useFirst.room}',2,1);`), stale,
    'the recorded revote is not in the fingerprint a fresh tally commits with');

  const closeFirst = await useVsClosure({ tool: 'revote', phase: 'vote', number: 2, order: 'closure-first', closure: ballotCommits });
  assertUseOrRefusal(t, 'M1-46 ballot first', closeFirst, { recorded: false, refusal: 'WRONG_PHASE' });
  assert.equal(firstLine(closeFirst.close), 't');
  assert.equal(closeFirst.state, 'verdict:2');
});

test('M4-39: a tool use racing the night that ends the match is recorded before the end or refused without a trace', async (t) => {
  const ending = nightCommits({ outcome: 'mafia' });
  const useFirst = await useVsClosure({ tool: 'sense', phase: 'night', number: 2, order: 'use-first', closure: ending,
    use: { targets: '{0,1,3}' } });
  assertUseOrRefusal(t, 'M4-39 night, use first', useFirst, { recorded: true });
  assert.equal(firstLine(useFirst.close), 't');
  assert.equal(await one(`select (u.created_at <= r.ended_at)::text from public.room_tool_uses u join public.rooms r on r.id=u.room_id where u.room_id='${useFirst.room}';`), 'true',
    'the use is dated after the end');

  const endFirst = await useVsClosure({ tool: 'sense', phase: 'night', number: 2, order: 'closure-first', closure: ending,
    use: { targets: '{0,1,3}' } });
  assertUseOrRefusal(t, 'M4-39 night, end first', endFirst, { recorded: false, refusal: 'NOT_PLAYING' });
  assert.equal(firstLine(endFirst.close), 't');
  assert.equal(await one(`select status from public.rooms where id='${endFirst.room}';`), 'finished');
});

test('M4-39: a dead player\'s last will racing the ballot that ends the match is recorded before the end or refused without a trace', async (t) => {
  const ballotEnds = async (room, n) => {
    const fingerprint = await one(`select public.vote_fingerprint('${room}',${n},1);`);
    return `select public.commit_resolution('${room}','vote',${n},1,null,null,'{}'::jsonb,'{"outcome":"town"}'::jsonb,'verdict',now()+interval '30 seconds','${fingerprint}');`;
  };
  const args = { tool: 'last_will', phase: 'vote', number: 2, closure: ballotEnds, seat: 5, dead: [5], use: { note: 'goodbye' } };
  const useFirst = await useVsClosure({ ...args, order: 'use-first' });
  assertUseOrRefusal(t, 'M4-39 ballot, use first', useFirst, { recorded: true });
  assert.equal(firstLine(useFirst.close), 't');
  assert.equal(await one(`select (u.created_at <= r.ended_at)::text from public.room_tool_uses u join public.rooms r on r.id=u.room_id where u.room_id='${useFirst.room}';`), 'true');

  const endFirst = await useVsClosure({ ...args, order: 'closure-first' });
  assertUseOrRefusal(t, 'M4-39 ballot, end first', endFirst, { recorded: false, refusal: 'NOT_PLAYING' });
  assert.equal(firstLine(endFirst.close), 't');
  assert.equal(await one(`select status from public.rooms where id='${endFirst.room}';`), 'finished');
});
