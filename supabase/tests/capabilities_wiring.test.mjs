// node supabase/tests/capabilities_wiring.test.mjs [--update]
//
// Launch audit: every `economy_config.*_enabled` flag reaches the client.
// Builds the schema from the migrations (PGlite, like the SQL harness), then:
//  1. each flag, switched on over its prerequisites, changes the envelope
//     `economy_capabilities` returns — a flag that changes nothing is a
//     switch the operator flips for nothing (server-only flags are listed);
//  2. the envelope with every flag on is the fixture
//     test/fixtures/capabilities_all_on.json, which the Flutter test
//     test/unit/feature_wiring_audit_test.dart parses — so a key renamed on
//     one side fails on the other.
import assert from 'node:assert/strict';
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { PGlite } from '../../build/sql-probe/node_modules/@electric-sql/pglite/dist/index.js';

const harness = await readFile('tool/test_sql_without_docker.mjs', 'utf8');
const setup = harness.slice(harness.indexOf('await db.exec(`') + 15, harness.indexOf('`);'));
const db = new PGlite();
await db.exec(setup);
for (const f of (await readdir('supabase/migrations')).filter((f) => f.endsWith('.sql')).sort()) {
  await db.exec(await readFile(`supabase/migrations/${f}`, 'utf8'));
}
const user = '00000000-0000-4000-8000-00000000c0de';
await db.exec(`insert into auth.users(id,email) values('${user}','caps@test')`);
const flags = (await db.query(`select column_name from information_schema.columns
  where table_schema='public' and table_name='economy_config' and column_name like '%enabled%'
  order by column_name`)).rows.map((r) => r.column_name);

// Flags the client never needs to see: the server enforces them alone.
const serverOnly = new Set([
  'transfer_enabled_android', // the payment screens read `products`/transfer rows
  'transfer_enabled_web',
]);
// A flag that only matters when another is on.
const needs = {
  daily_ad_enabled: ['daily_enabled'],
  ad_extras_enabled: ['daily_enabled', 'ad_steps_enabled'],
  council_leaderboard_enabled: ['council_rank_enabled'],
  partner_enabled: ['character_bonds_enabled'],
  push_invites_enabled: ['friends_enabled'],
  founder_enabled: [],
};

const caps = async () => {
  const c = (await db.query(`select public.economy_capabilities('${user}') c`)).rows[0].c;
  delete c.accountTag;
  return c;
};
const flat = (o, p = '') => Object.entries(o ?? {}).flatMap(([k, v]) =>
  v && typeof v === 'object' && !Array.isArray(v) ? flat(v, `${p}${k}.`) : [[`${p}${k}`, JSON.stringify(v)]]);

await db.exec(`update public.economy_config set ${flags.map((f) => `${f}=false`).join(',')},
  founder_window_start=now()`);
for (const flag of flags) {
  if (serverOnly.has(flag)) continue;
  await db.exec('begin');
  const pre = needs[flag] ?? [];
  if (pre.length) await db.exec(`update public.economy_config set ${pre.map((f) => `${f}=true`).join(',')}`);
  const before = Object.fromEntries(flat(await caps()));
  await db.exec(`update public.economy_config set ${flag}=true`);
  const after = Object.fromEntries(flat(await caps()));
  await db.exec('rollback');
  const changed = Object.keys({ ...before, ...after }).filter((k) => before[k] !== after[k]);
  assert.ok(changed.length > 0, `${flag} reaches no capability`);
}

await db.exec(`update public.economy_config set ${flags.map((f) => `${f}=true`).join(',')}`);
const allOn = await caps();
await db.close();
const fixture = 'test/fixtures/capabilities_all_on.json';
const text = `${JSON.stringify(allOn, null, 2)}\n`;
if (process.argv.includes('--update')) {
  await writeFile(fixture, text);
  console.log(`wrote ${fixture}`);
} else {
  assert.deepEqual(JSON.parse(await readFile(fixture, 'utf8')), JSON.parse(text),
    `${fixture} is stale: node supabase/tests/capabilities_wiring.test.mjs --update`);
}
console.log(`capabilities wiring: PASS (${flags.length} flags)`);
