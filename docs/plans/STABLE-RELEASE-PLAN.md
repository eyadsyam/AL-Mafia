# Stable release plan: Mafia online, offline, vs computer

Status: STARTED 2026-10-17. Owner: «محتاجين نوصل لنسخة ثابتة ومستقرة… الاختبار المغلق خلص وفاضل بس مراجعة جوجل».
This file is the single place to resume from. Anyone (Claude, Codex, a person) picks up at the first unchecked line of §5.

## ملخص للمالك

- **الهدف:** نسخة ثابتة من لعبة المافيا، أونلاين وأوفلاين، وكل أداة في المتجر وكل شخصية شغالين صح في كل حالة.
- **الأدوات والشخصيات:** كل أداة وكل شخصية لها جدول حالات في `docs/plans/audit/`. كل حالة فيه يا متغطية باختبار، يا مكتوب قدامها إنها ناقصة، وبعدين تتصلح.
- **الرفع:** مفيش رفع من غير كلمتك. ده بيشمل السيرفر وقاعدة البيانات وجوجل بلاي.
- **إزاي نكمّل:** لو الشغل وقف في أي وقت، اللي بعده يكمّل من أول سطر مش متعلّم عليه في §5.

## 1. How to resume (read in this order)

1. This file, §5 (the queue).
2. `docs/PROGRESS.md` (last entries), `CLAUDE.md` (non-negotiables), `docs/specs/17-roles-and-tools.md` §9–§12 (rule book + rulings RL1–RL21, final).
3. Work model (owner, 2026-10-17): Claude plans, writes exact briefs, reviews, runs gates, commits. Codex executes briefs to the letter and decides nothing. Sonnet only if Codex cannot run.
4. Codex cannot run `flutter` in its workspace-write sandbox (SDK cache outside the tree): Dart briefs tell it so, and the orchestrator runs analyze/tests after. Do not use danger-full-access (it could reach the network).
5. Codex relay: from **PowerShell** (Git Bash times out on "workspace routing discovery"):
   `node C:\Users\LENOVO\.claude\skills\codex-delegate\scripts\relay.mjs --brief <file> --cd . --model gpt-6-sol --timeout 2h` (add `--read-only` for audits). Briefs live in `docs/plans/briefs/`.
6. Machine limits: about 2.6 GB free RAM; one `flutter test` or SQL-harness process at a time. Deno and Docker are not installed.

### Never
- Upload anything: no deploy (web, edge functions), no live migration, no live flag flip, no Play upload, no push. Owner: «اهم حاجه مترفعش اي حاجه».
- Change the name «سيد المافيا: Mafia Master», reduce ads, mention payments in docs or briefs, print secrets.

## 2. Gates (what "green" means)

| Gate | Command | Last result |
|---|---|---|
| Flutter tests | `flutter test` (whole suite, alone) | 2222 pass, 5 skip (2026-10-17) |
| Analyzer | `flutter analyze` | clean (2026-10-16) |
| SQL | `node tool/test_sql_without_docker.mjs` | 92/92 (2026-10-17) |
| Node | each `supabase/tests/*.test.mjs` with `node --test <file>` | 29/29 files (2026-10-17) |
| Parity | `node supabase/tests/run_golden_vectors_node.mjs` (35 agree) + night vectors `node --test supabase/tests/night_vectors.test.mjs` (48/48) + their Dart tests | PASS (2026-10-17) |
| Edge type-check | `deno check supabase/functions/*/index.ts` (Deno 2.9.6 via `npm i -g deno`) | PASS except one pre-existing strictness error in `_shared/coin_payments.ts:178` (newer TS lib, not a runtime fault) |
| Live suite | `supabase/tests/run_live_suite.py` against a server running THIS code | BLOCKED: needs deploy (owner) |
| Device | owner plays one offline and one online match on his phone | BLOCKED: owner |

Stable = every gate green, every audit matrix row in §4 either covered by a test or fixed, owner smoke test passed.

## 2b. Invariants (USEI-X §3–§6, module H multiplayer, module I voice)

Every audit row and every fix is judged against these. Breaking one is a release blocker.

| Id | Invariant |
|---|---|
| I1 | No player learns another player's role except through the rules (doc 05). Nothing added for one role is visible to another. |
| I2 | Online the server is the authority: a client cannot act out of phase, out of role, on a dead/illegal target, or twice (anti-cheat), and every refusal leaves no trace. |
| I3 | A paid tool or item does exactly what its description says; its charge is spent once and only when the effect applies; a refused use costs nothing. |
| I4 | Every match ends: timer defaults exist for every waiting seat, removals and disconnects cannot stall a phase, all-gone tables close. |
| I5 | Same inputs, same outcome offline and online (parity), except the exceptions the rule book names. All clients of one room agree on the outcome. |
| I6 | Voice is never load-bearing: a match completes with voice fully broken; a silenced or dead player is never heard by the living. |
| I7 | The app never states a fact that did not happen (saves, traces, confrontations, tool lines). |
| I8 | Rewards are paid once per finished match and voided when a kick or strike decided it. |
| I9 | A retried request never duplicates an irreversible effect (idempotent writes); a late response never overwrites newer state. |

## 2c. Evidence and readiness vocabulary (USEI-X §2, §13)

- Finding: CONFIRMED DEFECT (reproduced) / HYPOTHESIS (looks wrong, not reproduced) / DESIGN RISK / UNKNOWN.
- Evidence level of a passing check: `unit` (Dart or node, pure), `sql-sim` (PGlite, single connection: no real concurrency), `widget`, `live` (python live suite against a running server), `device` (a person on a phone). A `sql-sim` pass does not prove two real connections; an edge function checked only by node tests of its pure helpers is not proven end to end (Deno not installed).
- Release readiness: READY / CONDITIONALLY READY / NOT READY / INSUFFICIENT EVIDENCE. **Current: INSUFFICIENT EVIDENCE** — the new server code has never run on a real server and no device run has happened since the rulings.

## 3. Done so far

- Identity: whole app wears Mafia's look; Stories isolated (guard test `test/architecture/identity_isolation_test.dart`).
- Rule book + 21 rulings (`docs/specs/17`).
- Offline engine fixes F1–F5, RL2/RL6/RL17/RL18 (`test/engine/rule_matrix_test.dart`).
- Copy pass on gameplay lines and 14 tool descriptions.
- Online client: morning names every death + silenced; lobby deals like offline (`lobby_deal.dart`).
- Server rulings T1–T10 (commit 882951b): one investigation/night, doctor no-repeat, team quiet night (`my_team.teamBulletSpent`), save told only when true, abstain setting, bought revote reopens ties, spotlight/last word, floor tools refused in free talk, strike voids rewards, silenced floor muted. NOT deployed.

## 4. Audit matrices (the "every case" work)

Each matrix is a file in `docs/plans/audit/`, produced read-only by Codex from the code and tests, reviewed by Claude. Row format: case → expected (rule book) → where the code handles it (file:line) → test that proves it → verdict `OK` / `GAP` (no test) / `SUSPECT` (code looks wrong). Every GAP gets a test; every SUSPECT gets a fix + test.

| Matrix | Scope | Brief | File |
|---|---|---|---|
| M1 Tools | all 17 table tools online: extra_minute, anon_note, last_will, spotlight, objection, last_word, vote_shield, half_door, double_vote, camouflage, revote, grave_vote, sense, impersonate, narrator_whisper, lock_door, appeal. Per tool: when it can be used (phase, alive/dead, target rules), charge once and only on success, refused cases charge nothing, the effect really happens, what the table sees (doc 05: nothing reveals a role), interaction with the other tools and roles, match ending mid-effect, reconnect, offline availability (RL20: online only) | `briefs/audit_tools.txt` | `audit/M1-tools.md` |
| M2 Roles | mafia, silencer, doctor, detective, elder, sniper, citizen, offline AND online: night move, timer default, bullets, death/reveal, win counting, interaction with every other role, minimum player counts, lobby deal | `briefs/audit_roles.txt` | `audit/M2-roles.md` |
| M3 Online life | create/join/leave lobby, start, host leaves/handover, disconnect + reconnect in every phase, app killed, timer expiry defaults per role, kick, strike absent, all-mafia-disconnected, last player leaves, voice fully broken, retries/idempotency, two tabs same account, match end + rewards + receipts | `briefs/audit_online.txt` | `audit/M3-online.md` |
| M4 Store and economy | every store item does what it says in every mode (owner rule), grant → use → refund revokes, coins, rewards, ads cadence unchanged | `briefs/audit_store.txt` | `audit/M4-store.md` |
| M5 Vs computer | bot match: does every phase complete, do bots obey the rulings, rewards | after owner decision §6 | `audit/M5-bots.md` |

### 4b. Triage of M1 (tools) and M2 (roles), 2026-10-17

M1: 117 rows; 20 SUSPECT. M2: 118 rows (29 OK, 76 GAP, 11 SUSPECT). Decisions:

| Finding | Decision | Where |
|---|---|---|
| M1-73, M1-115 tool bought during resolution can be lost (I3/I9) | FIX: resolution fingerprint covers the day's tool uses | `briefs/server_tool_guards.txt` T1 |
| M1-71 revote charged in round 2 | FIX: refused (WRONG_PHASE) | T2 |
| M1-78 grave_vote charged outside a ballot window | FIX: same window as vote tools | T3 |
| M1-58, M1-79 silenced player pays for double/grave vote | FIX: refused (SILENCED) | T4 |
| M1-25 spotlight on a dead/silenced target or outside talk | FIX: refused | T5 |
| M1-18 last will written at night unread, lost if the match ends | FIX: refused at night | T6 |
| M1-87, M1-101 recovered sense/whisper answer from an older use | FIX: match same phase + targets | `briefs/client_rulings.txt` S7 |
| M2-48 online morning never tells a told save | FIX | client S6 |
| M2-5/35/61/75/97 offline night commands do not check phase | FIX: StateError out of phase | `briefs/engine_hardening.txt` E1 |
| M2-11/49/89 refused armed move spends the bullet | FIX: validate before spending | E2 |
| M2-76, M2-98 server acks a forged Elder/Citizen night move | ACCEPTED: deliberate (older clients); nothing stored, no effect | submit_night_action.ts:57 comment |
| M1-38/45/52/65/94/107/114 conditional tools (last word, vote shield, half door, camouflage, impersonate, lock door, appeal) charged although the condition may never come | ACCEPTED: insurance by description («لو…», «الليلة الجاية…»); the charge buys the cover, not the event | descriptions in app_ar.arb |
| M1-6, M1-32 extra minute / objection bought after the last turn of a discussion | ACCEPTED: the floor bonus waits for the holder's next turn (consumed_at), next day included | migration 20261009000600 |
| M1-72 revote when nobody voted | ACCEPTED (rare): nothing to reopen; revisit if players report it | — |
| All GAP rows | Q5: tests in batches, highest risk first (online roles, deal, tools that charge) | — |

## 5. Queue (do in order; tick when committed)

- [x] Q1 Server rulings T1–T10 (882951b).
- [x] Q2 Offline case matrix: 72 tests, all green, no engine defect found (9300cc6).
- [x] Q3 Online client half of the rulings + S6/S7 (537e3f0).
- [x] Q4 Audits M1, M2, M3 (9300cc6, 7c01244); triage §4b.
- [x] Q5a Every SUSPECT fixed or accepted: server tool guards 7c01244, engine hardening aed3e3a, decided outcome 5164053, client 537e3f0, one Elder/Sniper 537e3f0. M3-22 (one account on two devices) ACCEPTED as a design limit: one account plays on one device.
- [ ] Q5b GAP rows into tests, one brief each, run in this order (each edits its own matrix rows): `briefs/gaps_m2_offline.txt` (16 done, resume it), `briefs/gaps_m1_tools.txt`, `briefs/gaps_m2_online.txt`, `briefs/gaps_m3_online.txt`. Never two SQL-harness runs at once.
- [x] Q6 Parity of the night: `resolveNightCore` (TS) vs the Dart engine on 48 scenarios, both sides green.
- [x] Q7 Gendered lines: confrontation C1/C4/C5/C6/C7/C8 and «مينفعش تصوّتي» follow the addressed player's gender, offline and online (test/unit/addressed_gender_test.dart).
- [ ] Q8 M4 store audit done (1471b82). Triage: M4-50 returned bundle keeps its components → FIX (`briefs/server_bundle_revoke.txt`); M4-51 a pack already on a room survives its owner's return → ACCEPTED (deliberate: cosmetics never block a match, purchase_access.ts comment); M4-38 two overlapping tool packs, one returned → ACCEPTED (rare); M4-4/7/10 offline keeps a returned role until the next online refresh → ACCEPTED (offline cannot ask the server); M4-24 vote shield is cover bought in advance → ACCEPTED (as M1 conditional tools).
- [ ] Q11 Local edge harness (`briefs/local_edge_harness.txt`): run the real edge functions on PGlite in Node to prove the ~70 `needs-live` rows without deploying. Run after gaps_m3 (both edit M3).
- [ ] Q9 Full gates (§2), then a local look for the owner WITHOUT `flutter build` (owner rule 2026-10-08/16): `flutter run -d web-server --web-port <port>` in debug, opened in the app's browser pane. No release build, no deploy, until he says «ابني».
- [ ] Q10 Owner: approve deploy to a staging project or live; then live suite; then device smoke; then Play.

## 6. Owner decisions pending

1. Vs computer: DECIDED 2026-10-17 («خلاص ماشي»): its card is hidden for this release (`_offerBotMatch = false` in lib/app/router.dart); code kept, one flag brings it back. M5 audit only if it returns.
2. RL19 witness whisper flag (live value).
3. Deploy route for testing the new server code: a staging project/branch vs live.

## 7. Copy waiting to be applied (final Arabic, Claude)

Female variants (used when the addressed offline player's gender is female; otherwise the current line):
- silencedCannotVote → «إنتي متسكّتة النهارده — مينفعش تصوّتي»
- confrontationC1 → «قلتي إنك شاكّة في {x}، وصوّتي لـ{y}»
- confrontationC5 → «إنتي و{x} صوّتوا نفس التصويت {count} مرات»
- confrontationC6 → «إنتي أقل واحدة اتكلمت في الماتش. ردّك؟»
- confrontationC7 → «آخر واحد مات كان شاكك فيكي. ردّك؟»
- confrontationC4 → «محدش شك فيكي لحد دلوقتي»
- confrontationC8 → «بتهمسي لـ{x} كل يوم ليه؟»
