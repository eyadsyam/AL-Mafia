// node tool/race_on_postgres.mjs  (needs a throwaway container: docker run -d --name mm-pg
//   --memory=512m -e POSTGRES_HOST_AUTH_METHOD=trust postgres:15-alpine)
// Real parallel transactions on real Postgres, which the PGlite suites cannot do:
// each statement below runs on its own connection at the same moment.
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import assert from 'node:assert/strict';

const C = process.env.RACE_CONTAINER ?? 'mm-pg';
const docker = (args, input) => execFileSync('docker', args, { input, encoding: 'utf8', maxBuffer: 1 << 26, stdio: ['pipe', 'pipe', 'pipe'] });
const psqlFile = (sql) => docker(['exec', '-i', C, 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-q', '-f', '-'], sql);
const one = (sql) => docker(['exec', '-i', C, 'psql', '-U', 'postgres', '-tA', '-f', '-'], sql).trim();
/** Every statement on its own connection, released together. */
function par(sqls) {
  const quoted = sqls.map((s) => `(psql -U postgres -tA -c '${s.replaceAll("'", "'\\''")}' 2>&1 | sed 's/^/>/') &`).join('\n');
  return docker(['exec', '-i', C, 'sh'], `${quoted}\nwait\n`).split('\n').filter(Boolean).map((l) => l.slice(1));
}
const noDeadlock = (out, name) => assert.ok(!out.some((l) => /deadlock/i.test(l)), `${name}: ${out.find((l) => /deadlock/i.test(l))}`);

function boot() {
  one('drop database if exists race'); // Reset between runs, then rebuilt below on the default db.
  psqlFile(`drop schema if exists public cascade; create schema public;
    drop schema if exists auth cascade; drop schema if exists extensions cascade;
    drop schema if exists cron cascade; drop schema if exists net cascade; drop schema if exists private cascade;
    drop publication if exists supabase_realtime;
    do $$ begin
      if not exists(select 1 from pg_roles where rolname='anon') then create role anon; end if;
      if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
      if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role bypassrls; end if;
    end $$;
    create schema auth; create schema extensions;
    create table auth.users(id uuid primary key, email text, created_at timestamptz not null default now(),
      email_confirmed_at timestamptz, is_anonymous boolean not null default false);
    create function auth.uid() returns uuid language sql stable as $$
      select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
        nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid $$;
    grant usage on schema public,auth to anon,authenticated,service_role;
    grant execute on function auth.uid() to anon,authenticated,service_role;
    alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
    alter default privileges in schema public grant all on sequences to anon,authenticated,service_role;
    create publication supabase_realtime;
    create schema cron;
    create table cron.job(jobid bigint generated always as identity, jobname text unique, schedule text, command text);
    create function cron.schedule(text,text,text) returns bigint language sql as $$
      insert into cron.job(jobname,schedule,command) values($1,$2,$3)
      on conflict(jobname) do update set schedule=$2,command=$3 returning jobid $$;
    create function cron.unschedule(text) returns boolean language sql as $$
      with gone as (delete from cron.job where jobname=$1 returning 1)
      select exists(select 1 from gone) $$;`);
  for (const file of readdirSync('supabase/migrations').filter((f) => f.endsWith('.sql')).sort()) {
    const sql = readFileSync(`supabase/migrations/${file}`, 'utf8').replace(
      /create extension if not exists pg_net[^;]*;/i,
      () => `create schema if not exists net;
       create or replace function net.http_post(url text, body jsonb default null,
         params jsonb default null, headers jsonb default null, timeout_milliseconds int default null)
         returns bigint language sql as $$ select 0::bigint $$;`);
    try { psqlFile(sql); } catch (e) { throw new Error(`MIGRATION ${file}: ${String(e.stderr ?? e.message).slice(0, 400)}`); }
  }
}

let codeN = 0;
const code = () => { const a = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; codeN++; return `R${a[Math.floor(codeN / 576) % 24]}${a[Math.floor(codeN / 24) % 24]}${a[codeN % 24]}QP`; };
function room({ status = 'playing', phase = 'vote', number = 1, seats = 7, ends = "now()+interval '2 minutes'", lobbyReady = true } = {}) {
  const r = randomUUID(); const u = Array.from({ length: seats }, () => randomUUID());
  const roles = ['mafia', 'mafia', 'detective', 'doctor', 'citizen', 'citizen', 'citizen', 'citizen', 'citizen'];
  psqlFile(`insert into auth.users(id) values ${u.map((x) => `('${x}')`).join(',')};
    insert into public.rooms(id,code,host_id,match_seed,status) values('${r}','${code()}','${u[0]}',1,'${status}');
    insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,status,last_seen,lobby_ready) values
      ${u.map((x, i) => `('${r}','${x}','p${i}',${i},${status === 'lobby' ? 'null' : `'${roles[i]}'`},true,true,'connected',now(),${lobbyReady})`).join(',')};
    insert into public.room_state(room_id,phase,phase_number,phase_ends_at,public_data) values('${r}','${phase}',${number},${ends},'{}')
      on conflict(room_id) do update set phase=excluded.phase,phase_number=excluded.phase_number,phase_ends_at=excluded.phase_ends_at;`);
  return { r, u };
}
const results = [];
function race(name, rounds, fn) {
  for (let i = 0; i < rounds; i++) fn(i);
  results.push(name);
  console.log(`PASS ${name} (${rounds} rounds)`);
}

boot();
console.log('PASS every migration applied on real Postgres');
// Readiness has its own tests; off here so a dealt race is only about the deal.
psqlFile('update public.economy_config set lobby_ready_enabled=false;');

race('one ballot sent eight times is one row', 8, () => {
  const { r, u } = room();
  const out = par(Array(8).fill(`insert into public.votes(room_id,day,voter_id,target_id,round) values('${r}',1,'${u[2]}','${u[1]}',1)`));
  noDeadlock(out, 'ballot');
  assert.equal(one(`select count(*) from public.votes where room_id='${r}'`), '1');
});

race('one phase opened by eight seats moves once', 8, () => {
  const { r } = room({ phase: 'morning', ends: "'2030-01-01'" });
  const out = par(Array(8).fill(`select public.commit_phase_open('${r}','morning',1,'2030-01-01'::timestamptz,'discuss',1,now()+interval '5 minutes','{}'::jsonb,false)`));
  noDeadlock(out, 'open');
  assert.equal(out.filter((l) => l === 't').length, 1, out.join('|'));
  assert.equal(one(`select phase||phase_number from public.room_state where room_id='${r}'`), 'discuss1');
});

race('one match started by six taps deals once', 6, () => {
  const { r, u } = room({ status: 'lobby', phase: 'lobby', ends: 'null', seats: 5 });
  const roles = "array['mafia','detective','citizen','citizen','citizen']";
  const out = par(Array(6).fill(`select public.apply_match_deal('${r}','${u[0]}',${roles},'{}'::jsonb,now()+interval '1 minute')`));
  noDeadlock(out, 'deal');
  assert.equal(out.filter((l) => l === 't').length, 1, out.join('|'));
  assert.equal(one(`select count(*) from public.room_players where room_id='${r}' and role is not null`), '5');
});

race('six presence sweeps strike each gone seat once, the same win check', 8, () => {
  const { r, u } = room({ phase: 'discuss' });
  psqlFile(`update public.room_players set last_seen=now()-interval '2 minutes' where room_id='${r}' and seat in (4,5);`);
  const out = par(Array(6).fill('select public.age_presence()'));
  noDeadlock(out, 'sweep');
  assert.equal(one(`select count(*) from public.room_players where room_id='${r}' and alive`), '5');
  assert.equal(one(`select count(*) from jsonb_object_keys((select public_data->'eliminations' from public.room_state where room_id='${r}'))`), '2');
  assert.equal(one(`select status from public.rooms where id='${r}'`), 'playing');
  assert.equal(u.length, 7);
});

race('the host leaving against ballots and a sweep ends closed, with no lock-up', 10, () => {
  const { r, u } = room();
  const out = par([
    `select public.leave_room('${r}','${u[0]}')`,
    ...[1, 2, 3, 4].map((i) => `insert into public.votes(room_id,day,voter_id,target_id,round) values('${r}',1,'${u[i]}','${u[5]}',1)`),
    'select public.age_presence()',
    `select public.leave_room('${r}','${u[6]}')`,
  ]);
  noDeadlock(out, 'host leaves');
  assert.equal(one(`select status from public.rooms where id='${r}'`), 'finished');
  assert.equal(one(`select host_id from public.rooms where id='${r}'`), u[0]);
  assert.equal(one(`select coalesce(public_data->>'outcome','none') from public.room_state where room_id='${r}'`), 'none');
  // Nothing lands once it is closed.
  assert.throws(() => psqlFile(`insert into public.votes(room_id,day,voter_id,target_id,round) values('${r}',1,'${u[5]}','${u[1]}',1);`));
});

race('the host leaving against the phase moving ends closed either way', 10, () => {
  const { r, u } = room({ phase: 'morning', ends: "'2030-01-01'" });
  const out = par([
    `select public.leave_room('${r}','${u[0]}')`,
    `select public.commit_phase_open('${r}','morning',1,'2030-01-01'::timestamptz,'discuss',1,now()+interval '5 minutes','{}'::jsonb,false)`,
    `select public.commit_phase_open('${r}','morning',1,'2030-01-01'::timestamptz,'discuss',1,now()+interval '5 minutes','{}'::jsonb,false)`,
  ]);
  noDeadlock(out, 'host vs phase');
  assert.equal(one(`select status from public.rooms where id='${r}'`), 'finished');
});

race('the host silent against a sweep and a guest leaving closes once', 10, () => {
  const { r, u } = room({ status: 'playing', phase: 'night' });
  psqlFile(`update public.room_players set last_seen=now()-interval '2 minutes' where room_id='${r}' and seat in (0,3);`);
  const out = par([...Array(4).fill('select public.age_presence()'), `select public.leave_room('${r}','${u[1]}')`]);
  noDeadlock(out, 'silent host');
  assert.equal(one(`select status from public.rooms where id='${r}'`), 'finished');
  assert.equal(one(`select coalesce(public_data->>'outcome','none') from public.room_state where room_id='${r}'`), 'none');
});

race('a full lobby takes no more than its seats', 6, () => {
  const { r } = room({ status: 'lobby', phase: 'lobby', ends: 'null', seats: 4, lobbyReady: false });
  psqlFile(`update public.rooms set settings=jsonb_build_object('maxPlayers',5) where id='${r}';`);
  const c = one(`select code from public.rooms where id='${r}'`);
  const joiners = Array.from({ length: 6 }, () => randomUUID());
  psqlFile(`insert into auth.users(id) values ${joiners.map((x) => `('${x}')`).join(',')};`);
  const out = par(joiners.map((j, i) => `select public.join_room_atomic('${c}','${j}','j${i}','male')`));
  noDeadlock(out, 'join');
  const seats = one(`select count(*) from public.room_players where room_id='${r}' and not kicked`);
  assert.ok(Number(seats) <= 5, `seats ${seats}: ${out.join('|').slice(0, 200)}`);
  assert.equal(one(`select count(distinct seat)=count(*) from public.room_players where room_id='${r}'`), 't');
});

console.log(`${results.length} races passed on real Postgres`);
