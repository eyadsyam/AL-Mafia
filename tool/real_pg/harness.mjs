// Local-only real PostgreSQL for the races PGlite cannot run (one connection).
// Uses the developer's local Supabase database container (docker, already on
// this machine). Each run creates a throwaway database, applies every
// migration unmodified, and drops it at the end. No network, no hosted project.
import { spawn } from 'node:child_process';
import { readdir, readFile } from 'node:fs/promises';

const CONTAINER = process.env.REAL_PG_CONTAINER ?? 'supabase_db_AL_Mafia';

function psql(db, sql, { tuples = true } = {}) {
  return new Promise((resolve) => {
    const args = ['exec', '-i', CONTAINER, 'psql', '-U', 'postgres', '-d', db,
      '-v', 'ON_ERROR_STOP=1', '-q', '-X'];
    if (tuples) args.push('-At');
    const child = spawn('docker', args, { stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => { out += d; });
    child.stderr.on('data', (d) => { err += d; });
    child.on('close', (code) => resolve({ ok: code === 0, out: out.trim(), err: err.trim() }));
    child.stdin.end(sql);
  });
}

// The same managed-platform stand-ins as tool/test_sql_without_docker.mjs;
// the roles already exist cluster-wide in the Supabase image.
const BOOTSTRAP = `
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
    select exists(select 1 from gone) $$;
`;

const NET_STUB = `create schema if not exists net;
  create or replace function net.http_post(url text, body jsonb default null,
    params jsonb default null, headers jsonb default null, timeout_milliseconds int default null)
    returns bigint language sql as $$ select 0::bigint $$;`;

/** Creates a fresh database with every migration applied; returns helpers. */
export async function freshDatabase() {
  const name = `race_${Date.now().toString(36)}`;
  const created = await psql('postgres', `create database ${name};`);
  if (!created.ok) throw new Error(`create database: ${created.err}`);
  const boot = await psql(name, BOOTSTRAP);
  if (!boot.ok) throw new Error(`bootstrap: ${boot.err}`);
  const files = (await readdir('supabase/migrations')).filter((f) => f.endsWith('.sql')).sort();
  for (const file of files) {
    // pg_cron lives only in the cluster's own database: the cron stub above
    // records the schedules instead, exactly as in the PGlite harness.
    const sql = (await readFile(`supabase/migrations/${file}`, 'utf8'))
      .replace(/create extension if not exists pg_net[^;]*;/i, () => NET_STUB)
      .replace(/create extension if not exists pg_cron[^;]*;/gi, 'null;');
    const applied = await psql(name, sql);
    if (!applied.ok) {
      await psql('postgres', `drop database ${name} with (force);`);
      throw new Error(`MIGRATION ${file}: ${applied.err}`);
    }
  }
  return {
    name,
    migrations: files.length,
    /** One session; resolves with {ok,out,err}. */
    sql: (text) => psql(name, text),
    /** Starts every session at once; resolves when all have finished. */
    concurrently: (...texts) => Promise.all(texts.map((t) => psql(name, t))),
    drop: () => psql('postgres', `drop database ${name} with (force);`),
  };
}

/** Wraps [text] so the session holds its locks for [seconds] before commit. */
export function holding(text, seconds = 1.5) {
  return `begin;\n${text}\nselect pg_sleep(${seconds});\ncommit;`;
}

/** Waits [ms] then runs [text], so it lands while another session holds locks. */
export function after(ms, db, text) {
  return new Promise((r) => setTimeout(r, ms)).then(() => db.sql(text));
}
