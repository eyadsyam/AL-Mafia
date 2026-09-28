# Round 9 — online-core audit (Claude; Sol attacks in the next round)

Sol's audit run hit the Codex usage limit, which resets at 10:22. Roles swap
again: Claude audits and Sol attacks.

## 1. Evidence run (2026-09-28, this worktree)
| Suite | Result |
|---|---|
| `flutter test test/transport test/online test/leakage test/golden/leakage` ×3 | 434/434, 434/434, 434/434. No flakiness across three runs. |
| `node tool/test_sql_without_docker.mjs` | 47/47 files. Single-connection PGlite, so no real concurrency. |
| `supabase/tests/*.test.mjs` | 13/13 |

**Not done:** EXPLAIN plans, multi-connection concurrency, and hosted
fault-injection. Local PGlite cannot run them. They are listed in §5.

## 2. What the core already does right
Verified by reading the code, not assumed:

- **Phase moves are compare-and-set.** They go through `commit_phase_open` and
  `commit_resolution`, which check the expected phase, number and deadline.
  Night and vote resolution recompute a fingerprint of the moves and the roster
  under the room lock, then retry up to 3 times. Late moves are neither lost nor
  double-counted (`resolve_night/index.ts`).
- **Timeouts never stall a match.** Expired phases get deterministic seeded
  defaults via `advance_phase`, which anyone may call once the *server* clock
  has passed. Defaults use `ignoreDuplicates`, so they never overwrite a real
  move.
- **The secret `role` column stays out of Realtime.** `room_players` is
  published with a column list that excludes it
  (`20260902000600_replica_identity.sql`). Clients read `room_players_public`.
- **Realtime never guesses.** A channel error or timeout emits `disconnected`,
  and a subscribe emits `resync` (a full read). Deltas are decoded only from
  `room_state` (`supabase_backend.dart:392-487`).
- **Abandoned rooms are swept.** A room with nobody connected for 5 minutes
  moves to `finished` (`archive_abandoned_rooms`, cron every 5 minutes). A room
  that ends mid-match without an outcome earns nothing, because Council and the
  Casebook require `outcome in ('mafia','town')`.
- **The night's win check runs after deaths are applied (W8).** Morning never
  opens on a decided match.

## 3. Defect register
Severity: P0 blocks release · P1 must fix in 1.1 · P2 should fix · P3 later.

| ID | Sev | Where | Evidence | Blast radius | Fix | Owner |
|---|---|---|---|---|---|---|
| D1 | P1 | `lib/transport/account_auth.dart:166-187` | `linkIdentity` for guests is an OAuth *redirect*. An `identity_already_exists` error comes back in the callback URL, not as a thrown `AuthException`, so the `catch` fallback to `signInWithOAuth` never runs. Nothing listens for callback errors: `changes()` maps `onAuthStateChange` with no `onError`, and grep finds no handling. | A returning player on a new phone (guest) taps Google: they come back still a guest, with no message. Worst first impression for accounts. The stream error can also surface as `AsyncError` in `accountProfileProvider`. | Catch the auth-stream error for `identity_already_exists`. Show the sheet «الحساب ده موجود بالفعل · تدخل عليه؟ (تقدم الضيف ده مش هيتنقل)», then call `signInWithOAuth`. Map every callback error to the sheet's error line. Add a widget test with a fake stream error. | Claude |
| D2 | P1 | `supabase/functions/_shared/economy_actions.ts` casePuzzleSolve + `20260928000500_case_of_day.sql` | There is no request id. A retried wrong pick over flaky Wi-Fi is recorded as a second attempt. | The Daily Case can fail after 2 real tries. | `requestId`, unique `(user, day, requestId)`; a replay returns the stored verdict (agreed in the final spec). | Sol |
| D3 | P1 | Casebook migration `20260928000400` | Season Zero activates at migration time (`now()`), so a dark deploy burns the season. | The whole season. | Operator activation (final spec F1). | Sol |
| D4 | P1 | `lib/ui/missions/casebook_sheet.dart` | Shows level 0; the spec says display level ≥1. | Cosmetic, but a "broken" first impression. | Use `max(1, level)` for display only. | Claude |
| D5 | P2 | `lib/ui/social/friends.dart` | Invites are pulled only when the friends strip/sheet builds. There is no push. | An invite sits unseen until the invitee opens Online, so the lobby waits. | Subscribe to `room_invites` for the user (RLS: own rows) or poll only while the app is foregrounded on Home/Online. Show the Home rail card «فلان عازمك». | Sol (publication) + Claude |
| D6 | P2 | `rematch_room_atomic` | Allowed for any `finished` room, including abandoned rooms with no outcome. | Harmless today. With series, a no-outcome room must not count as a series game. | Require `public_data->>'outcome' is not null` for series continuity. Keep plain rematch as-is. | Sol |
| D7 | P2 | `lib/ui/economy/council_hub.dart` `CouncilResultStrip._load` | Fires `sync`, then `contracts_get` + `rank_get`, then the Casebook hub: 4 edge calls per result, from every player at once. | Load spike when a 10-seat room ends. | One `resultSummary` action returning council + casebook deltas. | Sol + Claude |
| D8 | P2 | `lib/ui/missions/case_of_day_sheet.dart` (uncommitted) | The client draft has no ARB strings yet and would not compile if imported. | None while unimported. | Finish in build step 7, as specced. | Claude |
| D9 | P3 | `supabase_backend.dart` `server_now` | Deltas stamp `server_now` with the *client* clock (`DateTime.now()`). | Deadline countdowns can drift on skewed clocks until the next full read. Authority stays server-side, so this is display only. | Keep the last full-read server offset and apply it to deltas. | Claude |

**Suspicions to verify.** Evidence is not yet conclusive; Sol checks them with
multi-connection SQL.
- **S1.** `commit_phase_open` and `commit_resolution` lock `rooms`, but
  `seatAssignment` / `join_room` near capacity under simultaneous joins has not
  been tested concurrently here.
- **S2.** Quick-match picks the fullest lobby. Two players at the same instant
  may both land in a lobby with 1 seat left. Is the loser re-routed, or given an
  error?
- **S3.** Host handoff racing with `start_match`: a host leaving at the exact
  start moment.
- **S4.** New 1.1 columns (e.g. `lobby_ready`) must be added to the
  `room_players` publication column list explicitly. Is there a test that fails
  if someone republishes without a column list?

## 4. Doc 05 exposure check (payloads that reach clients)
- **`room_state.public_data`** holds outcome, morning (victim seat, unnamed
  save flag, trace type), rematch `{roomId, code}` and openingSeat. No role
  before the result.
- **`room_players`** reaches clients through the publication column list,
  without `role`.
- **Casebook, Case of the Day, friends and council responses:** no role, team,
  vote or target. The Case of the Day is fiction.
- **Error bodies:** generic codes. `ROOM_UNAVAILABLE` for blocks is planned in
  Safety v11.
- **Gap:** no automated test asserts the *shape* of every edge-function error
  body. **Fix:** a table-driven test that calls each function's refusal path in
  the local simulation and asserts that `role`, `team` and `target` keys are
  absent. (Sol)

## 5. What this audit could not do (Sol, next round)
- EXPLAIN for `browse_rooms`, `quick_match`, presence (`heartbeat` /
  `set_presence`) and resume on a realistic row count, with index
  recommendations.
- Multi-connection race tests for S1–S3 (real Postgres via
  `supabase start`/Docker if available, or hosted staging only with owner
  approval).
- An observability gap list: correlation ids, structured refusal counts,
  latency percentiles per function, reconnect-success rate. No hidden data in
  logs.

## 6. Release blockers vs post-launch
- **1.1 blockers:** D1–D4, the S1–S3 verification, and the error-shape test.
- **Post-launch hardening:** D5–D7, D9, EXPLAIN-driven indexes (unless a plan
  shows a sequential scan on a hot path — that becomes a blocker).
