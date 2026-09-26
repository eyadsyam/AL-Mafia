// Local-only PostgreSQL/WASM contracts. No keys, network or production writes.
// Setup: npm install --prefix build/sql-probe --save-exact --ignore-scripts --no-audit --no-fund @electric-sql/pglite@0.5.8
import { PGlite } from '../build/sql-probe/node_modules/@electric-sql/pglite/dist/index.js';
import { readdir, readFile } from 'node:fs/promises';
const db = new PGlite();
let failures = 0;
try {
  // Minimal managed-platform contracts. This does not emulate Auth, Realtime,
  // cron execution, concurrent connections, Edge Functions or hosted RLS wiring.
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema extensions;
    create table auth.users(id uuid primary key, email text,
      email_confirmed_at timestamptz, is_anonymous boolean not null default false);
    create function auth.uid() returns uuid language sql stable as $$
      select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
        nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid $$;
    grant usage on schema public,auth to anon,authenticated,service_role;
    grant execute on function auth.uid() to anon,authenticated,service_role;
    alter default privileges in schema public grant all on tables to anon,authenticated,service_role;
    alter default privileges in schema public grant all on sequences to anon,authenticated,service_role;
    create publication supabase_realtime;
    -- Record cron registrations, never execute background jobs in this harness.
    create schema cron;
    create table cron.job(jobid bigint generated always as identity, jobname text unique, schedule text, command text);
    create function cron.schedule(text,text,text) returns bigint language sql as $$
      insert into cron.job(jobname,schedule,command) values($1,$2,$3)
      on conflict(jobname) do update set schedule=$2,command=$3 returning jobid $$;
    create function cron.unschedule(text) returns boolean language sql as $$
      with gone as (delete from cron.job where jobname=$1 returning 1)
      select exists(select 1 from gone) $$;
  `);
  const migrations = (await readdir('supabase/migrations')).filter(f=>f.endsWith('.sql')).sort();
  for (const file of migrations) {
    try { await db.exec(await readFile(`supabase/migrations/${file}`, 'utf8')); }
    catch (error) { throw new Error(`MIGRATION ${file}: ${error.message}`); }
  }
  console.log(`PASS ${migrations.length} migrations executed unmodified`);
  const specified = process.argv.slice(2);
  const tests = specified.length ? specified : (await readdir('supabase/tests')).filter(f=>f.endsWith('.sql')).sort();
  for (const file of tests) {
    try {
      await db.exec(await readFile(`supabase/tests/${file}`, 'utf8'));
      console.log(`PASS ${file}`);
    } catch (error) {
      failures++;
      console.log(`FAIL ${file}: ${error.message}`);
    } finally { await db.exec('rollback'); }
  }
  console.log(`${tests.length-failures}/${tests.length} SQL files passed; single-connection local simulation only`);
} catch (error) {
  failures++;
  console.error(error.message);
} finally { await db.close(); }
if (failures) process.exitCode = 1;
