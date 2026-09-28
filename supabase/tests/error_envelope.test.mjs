// node supabase/tests/error_envelope.test.mjs
//
// S4 — every refusal an Edge Function can send is a fixed sentence.
//
// A refusal body reaches every caller, whatever their seat. If one were ever
// built from a variable — a role, a target, a seed, a name, an exception — it
// would carry that value to a client that must not see it. So this reads every
// function and requires each `fail(...)` to be (literal code, literal message,
// optional literal status), the code to be one the shared union declares, and
// no `ok(...)` body to carry an exception. It fails on any new call that breaks
// the rule. The fix is a fixed sentence. The only exceptions are the REVIEWED
// calls below, whose code and message are picked from a closed list inside the
// function. They are keyed by their exact argument text, so any edit to one
// fails here until it is reviewed again.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = 'supabase/functions';
const files = [];
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path);
    else if (path.endsWith('.ts')) files.push(path);
  }
})(root);

/** Every `name(...)` call in [src], with its raw argument text and line. */
function calls(src, name) {
  const found = [];
  const re = new RegExp(`(?<![\\w.])${name}\\(`, 'g');
  let m;
  while ((m = re.exec(src))) {
    let i = m.index + m[0].length;
    const start = i;
    let depth = 1;
    let quote = null;
    for (; i < src.length && depth > 0; i++) {
      const c = src[i];
      if (quote) {
        if (c === '\\') i++;
        else if (c === quote) quote = null;
        continue;
      }
      if (c === '"' || c === "'" || c === '`') quote = c;
      else if (c === '(') depth++;
      else if (c === ')') depth--;
    }
    found.push({ args: src.slice(start, i - 1), line: src.slice(0, m.index).split('\n').length });
  }
  return found;
}

/** Top-level comma split that respects strings and brackets. */
function split(args) {
  const parts = [];
  let depth = 0;
  let quote = null;
  let cur = '';
  for (let i = 0; i < args.length; i++) {
    const c = args[i];
    if (quote) {
      cur += c;
      if (c === '\\') cur += args[++i];
      else if (c === quote) quote = null;
      continue;
    }
    if (c === '"' || c === "'" || c === '`') { quote = c; cur += c; continue; }
    if ('([{'.includes(c)) depth++;
    if (')]}'.includes(c)) depth--;
    if (c === ',' && depth === 0) { parts.push(cur.trim()); cur = ''; continue; }
    cur += c;
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}

const literal = /^("([^"\\]|\\.)*"|'([^'\\]|\\.)*')$/;
const api = readFileSync(join(root, '_shared', 'api.ts'), 'utf8');
const union = api.match(/type ErrorCode\s*=([\s\S]*?);/);
assert.ok(union, 'ErrorCode union not found in _shared/api.ts');
const codes = new Set([...union[1].matchAll(/"([A-Z_]+)"/g)].map((m) => m[1]));

// The envelope itself: exactly {error, message, requestId}, nothing else
// serialised. The request id is minted per request (request_envelope.test.mjs
// proves it at runtime).
const failBody = api.match(/export function fail\([\s\S]*?JSON\.stringify\(([^)]*)\)/);
assert.ok(failBody, 'fail() not found');
assert.equal(failBody[1].replace(/\s+/g, ' ').trim(), '{ error: code, message, requestId }',
  'fail() must serialise exactly { error, message, requestId }');
// The catch-all never echoes the exception, and a database error is a 500.
assert.match(api, /response = fail\("BAD_REQUEST", "request could not be completed", 500\)/);

// file (forward slashes) → exact argument text → why it cannot carry private data.
const REVIEWED = {
  'supabase/functions/coin_orders/index.ts': {
    'known[0] as never, reason.toLowerCase(), known[1]': 'code and status come from the closed KNOWN map; the message is that code',
    'parsed.ok ? "invalid platform" : parsed.error': 'parser errors are fixed validation sentences about the request body',
    'submitRefusal(parsed.error) as never, parsed.error': 'closed refusal map over fixed parser sentences',
    'parsed.error': 'fixed parser sentences about the request body',
  },
  'supabase/functions/economy/index.ts': {
    'refusal as never, refusal.toLowerCase()': 'refusalOf() returns only codes from its closed list',
  },
  'supabase/functions/friends/index.ts': {
    'known[hit][0], hit, known[hit][1]': 'hit is a key of the closed known map',
  },
  'supabase/functions/join_room/index.ts': {
    'refusal, "room entry refused", refusal === "ROOM_NOT_FOUND" ? 404 : 400': 'refusal is from the closed join refusal list',
  },
  'supabase/functions/rematch_room/index.ts': {
    'code, "rematch refused", code === "ROOM_NOT_FOUND" ? 404 : code === "NEW_ROOMS_PAUSED" ? 503 : 400': 'code is from the closed rematch refusal list',
  },
};
const violations = [];
let refusals = 0;
for (const file of files) {
  const src = readFileSync(file, 'utf8');
  for (const call of calls(src, 'fail')) {
    if (file.endsWith(join('_shared', 'api.ts')) && call.args.startsWith('code')) continue;
    refusals++;
    const reviewed = REVIEWED[file.replaceAll('\\', '/')] ?? {};
    const text = call.args.replace(/\s+/g, ' ').trim();
    const key = Object.keys(reviewed).find((k) => text === k || text.endsWith(`, ${k}`) || text.startsWith(`${k},`));
    if (key) continue;
    const [code, message, status, ...rest] = split(call.args);
    const at = `${file}:${call.line}`;
    if (!literal.test(code ?? '')) violations.push(`${at} code is not a literal: ${code}`);
    else if (!codes.has(code.slice(1, -1))) violations.push(`${at} unknown code ${code}`);
    if (!literal.test(message ?? '')) violations.push(`${at} message is not a literal: ${message}`);
    if (status !== undefined && !/^\d{3}$/.test(status)) violations.push(`${at} status is not a literal: ${status}`);
    if (rest.length) violations.push(`${at} extra arguments`);
  }
  for (const call of calls(src, 'ok')) {
    if (/\.message\b|\bstack\b|String\(\s*(e|err|error)\b|JSON\.stringify\(\s*(e|err|error)\b/.test(call.args)) {
      violations.push(`${file}:${call.line} ok() carries an exception`);
    }
  }
}

assert.ok(refusals > 50, `only ${refusals} refusals found; the scanner is not reading the functions`);
assert.deepEqual(violations, [], `refusals built from variables:\n${violations.join('\n')}`);
console.log(`PASS error envelope: ${refusals} refusals across ${files.length} files are fixed sentences`);
