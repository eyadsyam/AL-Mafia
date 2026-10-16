# M2 — Roles and deal audit

Read-only audit of the checked-out source, 2026-10-17. Rule authority: `docs/specs/17-roles-and-tools.md` §4, §7, §12 (RL1–RL21), and `docs/specs/05-zero-leakage-spec.md`. `Test` identifies existing test source, not a test run. No test or live server was run. `none` means no test found that proves the whole stated case. Paired rows describe the same match situation in each transport. Online tools mentioned below are the RL20 online-only exception.

## Mafia

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-1 | OFFLINE normal kill, living non-team target | §4.1 | `lib/engine/match_engine.dart:439` | `test/engine/resolver_test.dart: mafia target dies without doctor protection` | unit | OK |
| M2-2 | ONLINE normal kill, living non-team target | §4.1 | `supabase/functions/submit_night_action/index.ts:150`; `supabase/functions/resolve_night/index.ts:99` | — | none | GAP |
| M2-3 | OFFLINE teammate, self or dead target rejected | §4.1; RL18 | `lib/engine/match_engine.dart:423` | `test/engine/rule_matrix_test.dart: C63: Mafia cannot vote for a Mafia teammate`; `RL18: a night move on a dead seat is refused by the engine` | unit | OK |
| M2-4 | ONLINE teammate, self or dead target rejected | §4.1 | `supabase/functions/submit_night_action/index.ts:159` | — | none | GAP |
| M2-5 | OFFLINE out-of-phase night action — `submitNightAction` checks current seat and target but never checks `match.phase`; a current actor can append a night move in another phase | §4.1; I2 | `lib/engine/match_engine.dart:390`; `lib/engine/match_engine.dart:410` | — | none | SUSPECT |
| M2-6 | ONLINE out-of-phase or dead actor rejected | §4.1; I2 | `supabase/functions/submit_night_action/index.ts:52` | — | none | GAP |
| M2-7 | OFFLINE split Mafia vote uses seeded seat-sorted tie | §4.1; RL21 | `lib/engine/resolver.dart:64` | `test/engine/rule_matrix_test.dart: F4: a split Mafia vote is drawn from the seats in seat order` | unit | OK |
| M2-8 | ONLINE split Mafia vote uses seeded seat-sorted tie | §4.1; RL21 | `supabase/functions/resolve_night/index.ts:104` | — | none | GAP |
| M2-9 | OFFLINE first Mafioso's quiet-night bullet cancels whole team kill, once per team | RL1 | `lib/engine/bullets.dart:52`; `lib/engine/resolver.dart:159` | `test/engine/rule_matrix_test.dart: C64: a team quiet night cancels another Mafia vote`; `C65: second Mafioso cannot spend the team bullet` | unit | OK |
| M2-10 | ONLINE first Mafioso's quiet-night bullet cancels whole team kill, once per team | RL1 | `supabase/functions/_shared/bullets.ts:101`; `supabase/functions/resolve_night/index.ts:152`; `supabase/migrations/20261016000200_team_quiet_night_bullet.sql:40` | `supabase/tests/night_rules.test.mjs: quiet night: a living Mafioso's spent bullet tonight silences the kill` | unit | GAP |
| M2-11 | OFFLINE invalid armed target or wrong move — bullet is appended before target and role validation; a thrown request leaves a spent bullet | §4.1; RL1; I2, I9 | `lib/engine/match_engine.dart:414`; `lib/engine/match_engine.dart:426`; `lib/engine/match_engine.dart:704` | — | none | SUSPECT |
| M2-12 | ONLINE invalid or racing armed request has no spend on refusal | RL1; I2, I9 | `supabase/functions/submit_night_action/index.ts:136`; `supabase/migrations/20261016000200_team_quiet_night_bullet.sql:40` | `supabase/tests/night_rules.test.mjs: team bullet: spent once any Mafioso other than the asker has spent it` | unit | GAP |
| M2-13 | OFFLINE Doctor saves Mafia target; Sniper can still kill it | §4.1, §4.3, §4.6; R2, RL17 | `lib/engine/resolver.dart:145`; `lib/engine/resolver.dart:164` | `test/engine/rule_matrix_test.dart: C10: protected Mafia target shot by sniper is not a save` | unit | OK |
| M2-14 | ONLINE Doctor saves Mafia target; Sniper can still kill it | §4.1, §4.3, §4.6; R2, RL17 | `supabase/functions/resolve_night/index.ts:142`; `supabase/functions/resolve_night/index.ts:160` | — | none | GAP |
| M2-15 | OFFLINE idle Mafia: no local clock; explicit skip or deterministic fallback | §4.1; §3 | `lib/engine/legal_moves.dart:367`; `lib/engine/legal_moves.dart:416` | — | none | GAP |
| M2-16 | ONLINE timer picks seeded living non-team target | §4.1; §3 | `supabase/functions/advance_phase/index.ts:85` | — | none | GAP |
| M2-17 | OFFLINE morning lists all deaths and conceals night roles except fast preset; death and parity checked after all deaths | §4.1, §7; RL10 | `lib/engine/resolver.dart:198`; `lib/engine/win_check.dart:42`; `lib/engine/presets.dart:71` | `test/engine/rule_matrix_test.dart: C107: night parity is decided after the morning` | unit | GAP |
| M2-18 | ONLINE morning lists all deaths, no night roles; parity checked after all deaths | §4.1, §7; RL10 | `supabase/functions/resolve_night/index.ts:204`; `lib/ui/screens/online/online_table_flow.dart:1577` | — | none | GAP |
| M2-19 | OFFLINE Mafia and Silencer see one another at deal | RL6; doc 05 permitted team knowledge | `lib/engine/match_engine.dart:229` | `test/engine/rule_matrix_test.dart: RL6: the Mafia and the Silencer know each other at the deal` | unit | OK |
| M2-20 | ONLINE Mafia and Silencer see one another at deal; other roles do not | RL6; doc 05 | `supabase/functions/my_team/index.ts:47`; `supabase/functions/my_team/index.ts:55` | — | none | GAP |

## Silencer

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-21 | OFFLINE living target, teammate or self can be silenced; target misses ballot but remains eligible to be voted out | §4.2; R1 | `lib/engine/legal_moves.dart:419`; `lib/engine/match_engine.dart:459`; `lib/engine/match_engine.dart:1206` | `test/engine/rule_matrix_test.dart: C33: silencer may silence itself and loses its vote`; `C34: silencer may silence a teammate` | unit | OK |
| M2-22 | ONLINE living target, teammate or self can be silenced; target misses ballot but remains eligible to be voted out | §4.2; R1 | `supabase/functions/submit_night_action/index.ts:161`; `supabase/functions/submit_vote/index.ts:39` | `supabase/tests/silence.test.mjs: actual silence includes seat zero and excludes only its target` | unit | GAP |
| M2-23 | OFFLINE dead target refused; dying target has no silence mark | §4.2; RL7 | `lib/engine/match_engine.dart:426`; `lib/engine/resolver.dart:188` | `test/engine/rule_matrix_test.dart: C30: a dead silence target has no silence mark` | unit | OK |
| M2-24 | ONLINE dead target refused; dying target has no silence mark | §4.2; RL7 | `supabase/functions/submit_night_action/index.ts:160`; `supabase/functions/resolve_night/index.ts:175` | — | none | GAP |
| M2-25 | OFFLINE last living ordinary Mafioso gone before action: Silencer inherits kill on living non-team target from next night | §4.2; R3 | `lib/engine/match_engine.dart:463`; `lib/engine/match_engine.dart:479` | `test/engine/rule_matrix_test.dart: C31: silencer inherits kill after last killer leaves`; `C32: silence persists when last killer is shot that night` | unit | OK |
| M2-26 | ONLINE last living ordinary Mafioso gone before action: Silencer inherits kill; earlier silence stays silence | §4.2; R3 | `supabase/functions/submit_night_action/index.ts:75`; `supabase/functions/resolve_night/index.ts:99` | — | none | GAP |
| M2-27 | OFFLINE inherited kill cannot hit self or Mafia team | §4.2; R3 | `lib/engine/legal_moves.dart:410`; `lib/engine/match_engine.dart:479` | — | none | GAP |
| M2-28 | ONLINE inherited kill cannot hit self or Mafia team | §4.2; R3 | `supabase/functions/submit_night_action/index.ts:161`; `supabase/functions/submit_night_action/index.ts:165` | — | none | GAP |
| M2-29 | OFFLINE no bullet; once per night by pass order, no repeat limit | §4.2 | `lib/engine/legal_moves.dart:383`; `lib/engine/match_engine.dart:583` | — | none | GAP |
| M2-30 | ONLINE no bullet; one row per night, repeat target allowed | §4.2 | `supabase/functions/_shared/bullets.ts:13`; `supabase/functions/submit_night_action/index.ts:217` | — | none | GAP |
| M2-31 | OFFLINE Doctor cannot clear silence; saved target stays silenced | §4.2, §4.3 | `lib/engine/resolver.dart:181` | `test/engine/rule_matrix_test.dart: F1: a saved seat that was silenced stays silenced` | unit | OK |
| M2-32 | ONLINE Doctor cannot clear silence; doors and vote shield can block it | §4.2; RL20 | `supabase/functions/resolve_night/index.ts:62`; `supabase/functions/resolve_night/index.ts:175` | — | none | GAP |
| M2-33 | OFFLINE morning names silenced seat; no offline voice; Silencer counts for parity | §4.2, §7; RL8 | `lib/engine/resolver.dart:230`; `lib/engine/win_check.dart:44` | `test/engine/rule_matrix_test.dart: C38: offline silence is a public mark with no talk turn` | unit | GAP |
| M2-34 | ONLINE morning names silenced seat, both voice modes mute them, parity counts Silencer | §4.2, §7; RL8 | `lib/ui/screens/online/online_table_flow.dart:1585`; `supabase/functions/claim_floor/index.ts:35`; `supabase/functions/_shared/teams.ts:9` | `supabase/tests/voice_policy.test.mjs: free discussion: the silenced seat is muted, the others stay open` | unit | GAP |
| M2-35 | OFFLINE out-of-phase or invalid armed request follows shared night-command defect — invalid actor can record a night action | §4.2; I2 | `lib/engine/match_engine.dart:390`; `lib/engine/match_engine.dart:459` | — | none | SUSPECT |
| M2-36 | ONLINE wrong phase/dead actor refused; expiry skips even when last killer | §4.2; §3 | `supabase/functions/submit_night_action/index.ts:52`; `supabase/functions/advance_phase/index.ts:105` | — | none | GAP |
| M2-37 | OFFLINE elimination reveals role, then Mafia win check includes Silencer | §4.2, §7 | `lib/engine/win_check.dart:44`; `lib/engine/match_engine.dart:1378` | — | none | GAP |
| M2-38 | ONLINE elimination reveals role, then Mafia win check includes Silencer | §4.2, §7 | `supabase/functions/resolve_vote/index.ts:203`; `supabase/functions/resolve_vote/index.ts:210` | — | none | GAP |

## Doctor

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-39 | OFFLINE protects a living other seat, including Mafia; repeats on consecutive nights refused | §4.3; RL3 | `lib/engine/match_engine.dart:496`; `lib/engine/match_engine.dart:506` | `test/engine/rule_matrix_test.dart: C5: doctor cannot cover the same player on consecutive nights` | unit | OK |
| M2-40 | ONLINE protects a living other seat, including Mafia; repeats on consecutive nights refused | §4.3; RL3 | `supabase/functions/submit_night_action/index.ts:150`; `supabase/functions/submit_night_action/index.ts:173` | `supabase/tests/night_rules.test.mjs: protect no-repeat: the same player twice is refused, self-protection is exempt` | unit | GAP |
| M2-41 | OFFLINE self-protect bullet once regardless of master bullets switch | §4.3; RL3 | `lib/engine/bullets.dart:27`; `lib/engine/match_engine.dart:421` | `test/engine/rule_matrix_test.dart: C3: doctor self bullet blocks a kill and is spent`; `C4: doctor cannot spend self bullet twice` | unit | OK |
| M2-42 | ONLINE self-protect bullet once regardless of master bullets switch | §4.3; RL3 | `supabase/functions/_shared/bullets.ts:38`; `supabase/functions/submit_night_action/index.ts:131` | `supabase/tests/night_rules.test.mjs: bullets: only a Mafioso holds the quiet night; the settings read as MatchSettings does` | unit | GAP |
| M2-43 | OFFLINE multiple Doctors protect only one seat; tie seeded; protection blocks Mafia kill only | §4.3; R2 | `lib/engine/resolver.dart:96`; `lib/engine/resolver.dart:145` | `test/engine/rule_matrix_test.dart: C8: tied doctor votes protect exactly one seat`; `C9: doctor cannot stop a town sniper shot` | unit | OK |
| M2-44 | ONLINE multiple Doctors protect only one seat; tie seeded; protection blocks Mafia kill only | §4.3; R2 | `supabase/functions/resolve_night/index.ts:122`; `supabase/functions/resolve_night/index.ts:142` | — | none | GAP |
| M2-45 | OFFLINE Doctor dies same night: protection stands; saved-then-shot victim is not a save | §4.3; RL17 | `lib/engine/resolver.dart:102`; `lib/engine/resolver.dart:196` | `test/engine/rule_matrix_test.dart: C11: doctor protection still resolves when doctor dies`; `RL17: a covered seat the Sniper takes is no save` | unit | OK |
| M2-46 | ONLINE Doctor dies same night: protection stands; saved-then-shot victim is not a save | §4.3; RL17 | `supabase/functions/resolve_night/index.ts:124`; `supabase/functions/resolve_night/index.ts:172` | `supabase/tests/night_rules.test.mjs: save told: a covered seat the Sniper took is no save (sets, arrays and ids)` | unit | GAP |
| M2-47 | OFFLINE quiet-night available hides save; fast/no-bullet preset tells surviving save | §4.3; RL2, RL17 | `lib/engine/resolver.dart:220`; `lib/engine/resolver.dart:231` | `test/engine/rule_matrix_test.dart: RL2: with no bullets (the fast preset) a save is told`; `RL2: with the quiet night on, a save reads as «nobody died»` | unit | OK |
| M2-48 | ONLINE surviving save with quiet night unavailable — server includes `someoneSavedUnnamed`, but morning UI never renders it; players only hear “nobody died” | §4.3; RL2; I5 | `supabase/functions/resolve_night/index.ts:217`; `lib/ui/screens/online/online_table_flow.dart:1593` | — | none | SUSPECT |
| M2-49 | OFFLINE dead target, repeat, wrong role or wrong phase — shared command lacks phase guard and an armed invalid move can burn self-protect bullet | §4.3; RL3; I2, I9 | `lib/engine/match_engine.dart:414`; `lib/engine/match_engine.dart:506` | — | none | SUSPECT |
| M2-50 | ONLINE dead target/wrong role/phase or ordinary skip rejected before action insert | §4.3; I2 | `supabase/functions/submit_night_action/index.ts:52`; `supabase/functions/submit_night_action/index.ts:68`; `supabase/functions/submit_night_action/index.ts:160` | — | none | GAP |
| M2-51 | OFFLINE no timer: plain skip defaults to first legal protection; no legal target at a continuing match needs review | §4.3; §3 | `lib/engine/match_engine.dart:613`; `lib/engine/match_engine.dart:618` | `test/engine/rule_matrix_test.dart: C7: doctor plain skip protects the first legal target` | unit | OK |
| M2-52 | ONLINE timer picks seeded legal other target excluding last night; no legal target leaves no action | §4.3; §3; RL3 | `supabase/functions/advance_phase/index.ts:85`; `supabase/functions/_shared/night_rules.ts:72` | `supabase/tests/night_rules.test.mjs: protect default: skips himself and last night's target, ordered by seat` | unit | GAP |
| M2-53 | OFFLINE death by vote reveals Doctor; living town count drives win | §4.3, §7 | `lib/engine/win_check.dart:42`; `lib/engine/match_engine.dart:1378` | — | none | GAP |
| M2-54 | ONLINE death by vote reveals Doctor; living town count drives win | §4.3, §7 | `supabase/functions/resolve_vote/index.ts:203`; `supabase/functions/resolve_vote/index.ts:208` | — | none | GAP |

## Detective

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-55 | OFFLINE one living other target per night reveals exact role privately, including Silencer/Elder | §4.4; RL5 | `lib/engine/match_engine.dart:529`; `lib/engine/match_engine.dart:543` | `test/engine/rule_matrix_test.dart: C44: detective sees the Silencer exact role`; `C45: detective sees the Elder exact role`; `C50: detective cannot investigate twice in one night` | unit | OK |
| M2-56 | ONLINE one living other target per night, same retry same answer; different target refused | §4.4; RL5 | `supabase/functions/submit_night_action/index.ts:188`; `supabase/functions/_shared/night_rules.ts:26`; `supabase/migrations/20261016000100_one_investigation_per_night.sql:29` | `supabase/tests/night_rules.test.mjs: investigation: the same target again is the same request, a different one is refused` | unit | GAP |
| M2-57 | OFFLINE dying Detective still learns the answer before night resolves; target not notified | §4.4 | `lib/engine/match_engine.dart:542`; `lib/engine/match_engine.dart:583` | `test/engine/rule_matrix_test.dart: C51: detective receives answer before dying that night` | unit | OK |
| M2-58 | ONLINE dying Detective gets private answer; target/public not notified | §4.4 | `supabase/functions/submit_night_action/index.ts:266`; `supabase/functions/submit_night_action/index.ts:282` | — | none | GAP |
| M2-59 | OFFLINE no tools: exact answer, even if same target protected or silenced | §4.4; RL20 | `lib/engine/match_engine.dart:543` | — | none | GAP |
| M2-60 | ONLINE half/locked door, impersonate, camouflage precedence changes private answer | §4.4; RL20 | `supabase/functions/submit_night_action/index.ts:266`; `supabase/functions/_shared/tools.ts:67` | — | none | GAP |
| M2-61 | OFFLINE dead/self target rejected; shared command can still investigate out of phase and expose a role | §4.4; I1, I2 | `lib/engine/match_engine.dart:390`; `lib/engine/match_engine.dart:542` | — | none | SUSPECT |
| M2-62 | ONLINE dead/self/out-of-phase rejected; two racing targets guarded in DB | §4.4; RL5 | `supabase/functions/submit_night_action/index.ts:52`; `supabase/functions/submit_night_action/index.ts:160`; `supabase/migrations/20261016000100_one_investigation_per_night.sql:29` | — | none | GAP |
| M2-63 | OFFLINE no timer; skip records no investigation | §4.4; §3 | `lib/engine/match_engine.dart:613`; `lib/engine/match_engine.dart:670` | — | none | GAP |
| M2-64 | ONLINE timer skips, no investigation; reconnect can retry same target | §4.4; §3; RL5 | `supabase/functions/advance_phase/index.ts:105`; `supabase/functions/_shared/night_rules.ts:33` | `supabase/tests/night_rules.test.mjs: investigation: a skipped night may still be used to look` | unit | GAP |
| M2-65 | OFFLINE Detective death counts town; vote reveals role, night death ordinarily does not | §4.4, §7; doc 05 | `lib/engine/win_check.dart:42`; `lib/ui/screens/night/morning_screen.dart:17` | — | none | GAP |
| M2-66 | ONLINE Detective death counts town; vote reveals role, night death does not | §4.4, §7; doc 05 | `supabase/functions/resolve_vote/index.ts:203`; `supabase/functions/resolve_night/index.ts:213` | — | none | GAP |

## Elder

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-67 | OFFLINE Elder may record suspicion at night; no bullet; town-aligned | §4.5; RL4 | `lib/engine/match_engine.dart:562`; `lib/engine/win_check.dart:42` | `test/engine/rule_matrix_test.dart: C61: offline Elder may record a night suspicion` | unit | OK |
| M2-68 | ONLINE Elder waits at night (explicit RL4 exception), no bullet; town-aligned | §4.5; RL4 | `supabase/functions/submit_night_action/index.ts:57`; `supabase/functions/advance_phase/index.ts:82` | — | none | GAP |
| M2-69 | OFFLINE reveal only alive in day window, once; silenced Elder may reveal but cannot vote | §4.5 | `lib/engine/match_engine.dart:1156`; `lib/engine/match_engine.dart:1170` | `test/engine/rule_matrix_test.dart: C35: silenced elder may reveal but cannot vote`; `C57: Elder cannot reveal at night` | unit | OK |
| M2-70 | ONLINE reveal only alive in day window, once; silenced Elder may reveal but cannot vote | §4.5; RL21 | `supabase/migrations/20261007000500_roles.sql:98`; `supabase/functions/submit_vote/index.ts:39` | — | none | GAP |
| M2-71 | OFFLINE revealed vote weighs three at tally, including a ballot cast before reveal; dead Elder cannot vote | §4.5 | `lib/engine/match_engine.dart:1187`; `lib/engine/match_engine.dart:1204` | `test/engine/rule_matrix_test.dart: C54: revealed Elder three votes beat two other votes`; `C55: reveal after casting weights that ballot retroactively` | unit | OK |
| M2-72 | ONLINE revealed vote weighs three at tally, combines with double-vote to six; dead Elder cannot vote except grave-vote tool | §4.5; RL20 | `supabase/functions/resolve_vote/index.ts:110`; `supabase/functions/resolve_vote/index.ts:120` | — | none | GAP |
| M2-73 | OFFLINE reveal is public; night death normally hides role; Sniper mistake against Elder kills both | §4.5, §4.6; doc 05 | `lib/engine/match_engine.dart:1174`; `lib/engine/resolver.dart:175` | `test/engine/rule_matrix_test.dart: C62: sniper treats Elder as town` | unit | GAP |
| M2-74 | ONLINE reveal is public; night death hides role; Sniper mistake against Elder kills both | §4.5, §4.6; doc 05 | `supabase/migrations/20261007000500_roles.sql:108`; `supabase/functions/resolve_night/index.ts:164` | — | none | GAP |
| M2-75 | OFFLINE wrong phase/dead reveal refused; night suspicion shares out-of-phase command defect | §4.5; I2 | `lib/engine/match_engine.dart:1166`; `lib/engine/match_engine.dart:562` | — | none | SUSPECT |
| M2-76 | ONLINE arbitrary forged night action by Elder — returns success before role/action validation, though it writes no move | §4.5; RL4; I2 | `supabase/functions/submit_night_action/index.ts:61`; `supabase/functions/submit_night_action/index.ts:67` | — | none | SUSPECT |
| M2-77 | OFFLINE no timer; explicit skip, Elder remains town body | §4.5; §3, §7 | `lib/engine/legal_moves.dart:416`; `lib/engine/win_check.dart:44` | — | none | GAP |
| M2-78 | ONLINE expiry writes skip for Elder; disconnect does not stall | §4.5; §3 | `supabase/functions/advance_phase/index.ts:82`; `supabase/functions/advance_phase/index.ts:105` | — | none | GAP |

## Sniper

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-79 | OFFLINE one shot per match even with general bullets off; living non-self target | §4.6; R2 | `lib/engine/bullets.dart:33`; `lib/engine/legal_moves.dart:426` | `test/engine/rule_matrix_test.dart: C20: second sniper bullet is refused`; `C27: disabling general bullets still permits sniper shot` | unit | OK |
| M2-80 | ONLINE one shot per match even with general bullets off; living non-self target | §4.6; R2 | `supabase/functions/_shared/bullets.ts:39`; `supabase/functions/submit_night_action/index.ts:145`; `supabase/functions/submit_night_action/index.ts:160` | `supabase/tests/night_rules.test.mjs: bullets: only a Mafioso holds the quiet night; the settings read as MatchSettings does` | unit | GAP |
| M2-81 | OFFLINE shot Mafia or Silencer: target dies, Sniper lives; shot town role: both die | §4.6; R2 | `lib/engine/resolver.dart:175` | `test/engine/rule_matrix_test.dart: C15: a mafia shot kills the mafioso and spares the sniper`; `C17: silencer is mafia-aligned for a sniper shot`; `C18: shooting elder or detective kills shooter too` | unit | OK |
| M2-82 | ONLINE shot Mafia or Silencer: target dies, Sniper lives; shot town role: both die | §4.6; R2 | `supabase/functions/resolve_night/index.ts:160`; `supabase/functions/resolve_night/index.ts:164` | — | none | GAP |
| M2-83 | OFFLINE Doctor cannot block shot; killed shooter still fires; overlap with Mafia kill deduplicated | §4.6; R2 | `lib/engine/resolver.dart:162`; `lib/engine/resolver.dart:175` | `test/engine/rule_matrix_test.dart: C19: a killed sniper still lands its mafia shot`; `C22: overlapping kill and town shot deduplicate the target` | unit | OK |
| M2-84 | ONLINE Doctor cannot block shot; killed shooter still fires; overlap deduplicated | §4.6; R2 | `supabase/functions/resolve_night/index.ts:155`; `supabase/functions/resolve_night/index.ts:160` | — | none | GAP |
| M2-85 | OFFLINE quiet night does not cancel shot; a wrong shot can cause Mafia parity and all deaths named | §4.6, §7; RL10 | `lib/engine/resolver.dart:159`; `lib/engine/win_check.dart:63` | `test/engine/rule_matrix_test.dart: C24: town shot that reaches parity awards mafia after morning`; `C26: Mafia quiet night does not cancel a sniper shot` | unit | OK |
| M2-86 | ONLINE quiet night does not cancel shot; wrong shot can cause Mafia parity and all deaths named | §4.6, §7; RL10 | `supabase/functions/resolve_night/index.ts:152`; `supabase/functions/resolve_night/index.ts:204`; `lib/ui/screens/online/online_table_flow.dart:1577` | — | none | GAP |
| M2-87 | OFFLINE no ordinary night shot without bullet; no timer, explicit skip | §4.6 | `lib/engine/match_engine.dart:562`; `lib/engine/legal_moves.dart:416` | `test/engine/rule_matrix_test.dart: C21: unarmed sniper suspicion does not kill` | unit | OK |
| M2-88 | ONLINE no ordinary night shot without bullet; expiry skips, no shot | §4.6; §3 | `supabase/functions/resolve_night/index.ts:160`; `supabase/functions/advance_phase/index.ts:105` | — | none | GAP |
| M2-89 | OFFLINE invalid armed move — shot bullet logged before wrong phase/dead target/role checks; rejection can consume the one paid-role power | §4.6; R2; I2, I3, I9 | `lib/engine/match_engine.dart:414`; `lib/engine/match_engine.dart:426`; `lib/engine/match_engine.dart:562` | — | none | SUSPECT |
| M2-90 | ONLINE invalid phase/dead target/wrong action rejected before spend; locked door cancels shot and recoil | §4.6; RL20 | `supabase/functions/submit_night_action/index.ts:54`; `supabase/functions/resolve_night/index.ts:162` | — | none | GAP |
| M2-91 | OFFLINE Sniper night death hidden except permitted fast preset; vote death reveals role | §4.6; doc 05 | `lib/ui/screens/night/morning_screen.dart:41`; `lib/engine/match_engine.dart:1378` | — | none | GAP |
| M2-92 | ONLINE Sniper night death hidden, vote death reveals role; witness exception applies after death | §4.6; doc 05 | `supabase/functions/resolve_night/index.ts:213`; `supabase/functions/resolve_vote/index.ts:203`; `supabase/functions/witness_view/index.ts:71` | — | none | GAP |

## Citizen

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-93 | OFFLINE living Citizen suspects another living seat or skips; no bullet; town body | §4.7; RL4 | `lib/engine/match_engine.dart:562`; `lib/engine/legal_moves.dart:416` | — | none | GAP |
| M2-94 | ONLINE Citizen waits at night, no move or bullet, never blocks night completion | §4.7; RL4 | `supabase/functions/submit_night_action/index.ts:57`; `supabase/functions/advance_phase/index.ts:82` | — | none | GAP |
| M2-95 | OFFLINE suspicion may feed eligible offline-only traces/confrontations; no invented fact | §4.7; RL4; I7 | `lib/engine/match_engine.dart:568` | — | none | GAP |
| M2-96 | ONLINE no Citizen suspicion trace; no action written | §4.7; RL4 | `supabase/functions/submit_night_action/index.ts:61` | — | none | GAP |
| M2-97 | OFFLINE dead/self target refused; common night method accepts out-of-phase suspicion | §4.7; I2 | `lib/engine/match_engine.dart:390`; `lib/engine/match_engine.dart:562` | — | none | SUSPECT |
| M2-98 | ONLINE arbitrary forged Citizen night action — returns success before action and target validation, though it writes no move | §4.7; RL4; I2 | `supabase/functions/submit_night_action/index.ts:61`; `supabase/functions/submit_night_action/index.ts:67` | — | none | SUSPECT |
| M2-99 | OFFLINE silence removes Citizen's ballot but not eligibility for elimination; death changes parity | §4.7, §7; R1 | `lib/engine/match_engine.dart:1206`; `lib/engine/win_check.dart:63` | `test/engine/rule_matrix_test.dart: C29: silenced seat may be voted out` | unit | GAP |
| M2-100 | ONLINE silence removes Citizen's ballot but not eligibility; voice stays closed in either mode | §4.7; R1, RL8 | `supabase/functions/submit_vote/index.ts:39`; `supabase/functions/claim_floor/index.ts:35` | `supabase/tests/voice_policy.test.mjs: free discussion: the silenced seat is muted, the others stay open` | unit | GAP |
| M2-101 | OFFLINE no timer, explicit skip; vote death reveals Citizen, night death ordinarily does not | §4.7; doc 05 | `lib/engine/match_engine.dart:670`; `lib/ui/screens/night/morning_screen.dart:17` | — | none | GAP |
| M2-102 | ONLINE expiry writes nothing for Citizen; vote death reveals role, night death does not | §4.7; §3; doc 05 | `supabase/functions/advance_phase/index.ts:82`; `supabase/functions/resolve_vote/index.ts:203` | — | none | GAP |

## Deal and balance

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M2-103 | OFFLINE 4-player table rejected; 5–20 accepted with valid counts | §2.1, §2.4 | `lib/engine/match_engine.dart:86`; `lib/engine/balance_guard.dart:72` | `test/engine/balance_guard_test.dart: blocks fewer than 5 players`; `blocks more than 20 players` | unit | OK |
| M2-104 | ONLINE 4-player table rejected; five-player minimum enforced | §2.1 | `supabase/functions/start_match/index.ts:56` | — | none | GAP |
| M2-105 | OFFLINE classic default is quarter table Mafia: 1 at five, 5 at twenty; one Doctor, one Detective | §2.2; RL11 | `lib/engine/presets.dart:145`; `lib/engine/presets.dart:147` | `test/engine/balance_guard_test.dart: returns valid distribution for 20 players (5 Mafia, a quarter)` | unit | OK |
| M2-106 | ONLINE lobby starts from the same recommended quarter split | §2.2; RL11 | `lib/ui/screens/online/lobby_deal.dart:17`; `lib/engine/balance_guard.dart:169` | `test/online/lobby_deal_test.dart: nothing switched on deals the plain recommended split` | unit | OK |
| M2-107 | OFFLINE bought Silencer needs two Mafia-side seats, Elder 6+, Sniper 7+; each replaces one base seat | §2.4–2.5; RL12 | `lib/ui/screens/setup/optional_roles.dart:35`; `lib/ui/screens/setup/optional_roles.dart:57` | — | none | GAP |
| M2-108 | ONLINE lobby filters impossible sold roles at table size, and server rechecks counts and ownership | §2.4–2.5; RL12; I3 | `lib/ui/screens/online/lobby_deal.dart:24`; `supabase/functions/start_match/index.ts:72`; `supabase/functions/start_match/index.ts:84` | `test/online/lobby_deal_test.dart: five players skip all three sold roles and say so` | unit | GAP |
| M2-109 | OFFLINE at most one Detective, one Silencer, one Elder and one Sniper; Mafia-side below half | §2.4, §7 | `lib/engine/balance_guard.dart:110`; `lib/engine/balance_guard.dart:130`; `lib/engine/match_engine.dart:112` | `test/engine/balance_guard_test.dart: blocks a second Detective at any player count` | unit | GAP |
| M2-110 | ONLINE server rejects second Detective, duplicate sold roles, zero Mafia, start parity, role-sum mismatch | §2.4, §7; I2 | `supabase/functions/start_match/index.ts:77`; `supabase/functions/start_match/index.ts:80`; `supabase/functions/start_match/index.ts:84` | — | none | GAP |
| M2-111 | OFFLINE deal is seeded; Mafia and Silencer privately see team; match cannot start with invalid role count | §2.4, §2.7; RL6; doc 05 | `lib/engine/match_engine.dart:90`; `lib/engine/match_engine.dart:153`; `lib/engine/match_engine.dart:229` | `test/engine/rule_matrix_test.dart: RL6: the Mafia and the Silencer know each other at the deal` | unit | GAP |
| M2-112 | ONLINE seeded deal is atomic under room lock; no roles returned publicly; reconnect reads own role/team | §2.7; RL6; I1, I9 | `supabase/functions/start_match/index.ts:100`; `supabase/migrations/20261009000100_deal_all_roles.sql:13`; `supabase/functions/start_match/index.ts:129`; `supabase/functions/my_team/index.ts:47` | — | none | GAP |
| M2-113 | OFFLINE sold role switches and dealt roles must match; unavailable role isn't dealt | §2.5; I3 | `lib/engine/match_engine.dart:116`; `lib/ui/screens/setup/optional_roles.dart:79` | — | none | GAP |
| M2-114 | ONLINE sold role switch and dealt count must match; unowned role rejected before deal | §2.5; I3 | `supabase/functions/start_match/index.ts:74`; `supabase/functions/start_match/index.ts:84` | — | none | GAP |
| M2-115 | OFFLINE 20-player split is available; if only one side survives, same living-seat parity rule | §2.1, §7 | `lib/engine/balance_guard.dart:77`; `lib/engine/win_check.dart:63` | `test/engine/balance_guard_test.dart: returns valid distribution for 20 players (5 Mafia, a quarter)` | unit | GAP |
| M2-116 | ONLINE 20-player split: rule book explicitly caps online rooms at 15 | §2.1 named mode exception | `supabase/functions/_shared/room_configuration.ts:30` | — | none | N/A (online cap is 15 by §2.1) |
| M2-117 | OFFLINE sold roles cost no per-action charge; tools absent by explicit exception | §2.5; RL20 | `lib/ui/screens/setup/optional_roles.dart:14`; `lib/engine/bullets.dart:61` | — | none | N/A (offline tools excluded by RL20) |
| M2-118 | ONLINE sold roles are owned before starting; online table tools have separate paid actions | §2.5; RL20 | `supabase/functions/start_match/index.ts:72`; `supabase/migrations/20261007000700_role_unlocks_store_v4.sql:15` | — | none | GAP |

## Findings

SUSPECT M2-61 [I1, I2]: Detective — offline night command can reveal another role out of phase — `lib/engine/match_engine.dart:390`.
SUSPECT M2-11 [I2, I9]: Mafia — rejected armed move can leave the team bullet spent — `lib/engine/match_engine.dart:414`.
SUSPECT M2-89 [I2, I3, I9]: Sniper — rejected armed shot can consume the only shot — `lib/engine/match_engine.dart:414`.
SUSPECT M2-49 [I2, I9]: Doctor — rejected armed protection can consume self-protection — `lib/engine/match_engine.dart:414`.
SUSPECT M2-5 [I2]: Mafia — offline night command does not check phase — `lib/engine/match_engine.dart:390`.
SUSPECT M2-35 [I2]: Silencer — offline night command does not check phase — `lib/engine/match_engine.dart:390`.
SUSPECT M2-75 [I2]: Elder — offline suspicion shares missing night phase guard — `lib/engine/match_engine.dart:562`.
SUSPECT M2-97 [I2]: Citizen — offline suspicion shares missing night phase guard — `lib/engine/match_engine.dart:562`.
SUSPECT M2-48 [I5]: Doctor — online morning omits a surviving save when RL2 requires telling it — `lib/ui/screens/online/online_table_flow.dart:1593`.
SUSPECT M2-76 [I2]: Elder — server acknowledges any forged night action as success — `supabase/functions/submit_night_action/index.ts:61`.
SUSPECT M2-98 [I2]: Citizen — server acknowledges any forged night action as success — `supabase/functions/submit_night_action/index.ts:61`.
GAP M2-2: Mafia — online normal kill lacks a proving test — `supabase/functions/resolve_night/index.ts:99`.
GAP M2-4: Mafia — online illegal target refusal lacks a proving test — `supabase/functions/submit_night_action/index.ts:159`.
GAP M2-6: Mafia — online wrong-phase/dead refusal lacks a proving test — `supabase/functions/submit_night_action/index.ts:52`.
GAP M2-8: Mafia — online split tally lacks a proving test — `supabase/functions/resolve_night/index.ts:104`.
GAP M2-10: Mafia — pure rule tested, integrated team bullet and real race unproved — `supabase/migrations/20261016000200_team_quiet_night_bullet.sql:40`.
GAP M2-12: Mafia — bullet refusal under real race unproved — `supabase/functions/submit_night_action/index.ts:136`.
GAP M2-14: Mafia — online Doctor/Sniper collision unproved — `supabase/functions/resolve_night/index.ts:142`.
GAP M2-15: Mafia — local expiry fallback unproved — `lib/engine/legal_moves.dart:367`.
GAP M2-16: Mafia — online expiry kill unproved — `supabase/functions/advance_phase/index.ts:85`.
GAP M2-17: Mafia — offline complete morning/role visibility unproved — `lib/engine/resolver.dart:198`.
GAP M2-18: Mafia — online complete morning/role visibility unproved — `lib/ui/screens/online/online_table_flow.dart:1577`.
GAP M2-20: Mafia — online private team delivery unproved — `supabase/functions/my_team/index.ts:47`.
GAP M2-22: Silencer — online silence through ballot unproved — `supabase/functions/submit_vote/index.ts:39`.
GAP M2-24: Silencer — online dead target and death cleanup unproved — `supabase/functions/resolve_night/index.ts:175`.
GAP M2-26: Silencer — online inherited kill timing unproved — `supabase/functions/submit_night_action/index.ts:75`.
GAP M2-27: Silencer — offline inherited kill invalid-target refusal unproved — `lib/engine/match_engine.dart:479`.
GAP M2-28: Silencer — online inherited kill invalid-target refusal unproved — `supabase/functions/submit_night_action/index.ts:165`.
GAP M2-29: Silencer — offline per-night/no-bullet behavior unproved — `lib/engine/match_engine.dart:583`.
GAP M2-30: Silencer — online repeat/no-bullet behavior unproved — `supabase/functions/submit_night_action/index.ts:217`.
GAP M2-32: Silencer — tool/protection interaction unproved — `supabase/functions/resolve_night/index.ts:62`.
GAP M2-33: Silencer — offline morning and parity together unproved — `lib/engine/resolver.dart:230`.
GAP M2-34: Silencer — online morning, voice and parity together unproved — `lib/ui/screens/online/online_table_flow.dart:1585`.
GAP M2-36: Silencer — online refusal and expiry skip unproved — `supabase/functions/advance_phase/index.ts:105`.
GAP M2-37: Silencer — offline vote death and parity unproved — `lib/engine/win_check.dart:44`.
GAP M2-38: Silencer — online vote death and parity unproved — `supabase/functions/resolve_vote/index.ts:210`.
GAP M2-40: Doctor — pure no-repeat rule tested, server path unproved — `supabase/functions/submit_night_action/index.ts:173`.
GAP M2-42: Doctor — online self-protect spend under retry unproved — `supabase/functions/submit_night_action/index.ts:131`.
GAP M2-44: Doctor — online multi-Doctor tie and shot unproved — `supabase/functions/resolve_night/index.ts:122`.
GAP M2-46: Doctor — online actor death and surviving save unproved — `supabase/functions/resolve_night/index.ts:124`.
GAP M2-50: Doctor — online refusal paths unproved — `supabase/functions/submit_night_action/index.ts:68`.
GAP M2-52: Doctor — pure expiry target filter tested, server expiry unproved — `supabase/functions/advance_phase/index.ts:85`.
GAP M2-53: Doctor — offline vote death/win unproved — `lib/engine/win_check.dart:42`.
GAP M2-54: Doctor — online vote death/win unproved — `supabase/functions/resolve_vote/index.ts:208`.
GAP M2-56: Detective — pure investigation retry rule tested, server race unproved — `supabase/migrations/20261016000100_one_investigation_per_night.sql:29`.
GAP M2-58: Detective — online answer privacy after death unproved — `supabase/functions/submit_night_action/index.ts:266`.
GAP M2-59: Detective — offline same-target role answer under protection/silence unproved — `lib/engine/match_engine.dart:543`.
GAP M2-60: Detective — online tool precedence unproved — `supabase/functions/_shared/tools.ts:67`.
GAP M2-62: Detective — online wrong-phase/dead/racing target path unproved — `supabase/functions/submit_night_action/index.ts:52`.
GAP M2-63: Detective — offline skip path unproved — `lib/engine/match_engine.dart:670`.
GAP M2-64: Detective — server expiry/reconnect behavior unproved — `supabase/functions/advance_phase/index.ts:105`.
GAP M2-65: Detective — offline death visibility/win unproved — `lib/ui/screens/night/morning_screen.dart:17`.
GAP M2-66: Detective — online death visibility/win unproved — `supabase/functions/resolve_night/index.ts:213`.
GAP M2-68: Elder — online waiting/no-move handling unproved — `supabase/functions/submit_night_action/index.ts:57`.
GAP M2-70: Elder — online reveal window, silence, idempotency unproved — `supabase/migrations/20261007000500_roles.sql:98`.
GAP M2-72: Elder — online triple/double/grave voting unproved — `supabase/functions/resolve_vote/index.ts:110`.
GAP M2-73: Elder — offline public reveal, night privacy, shot combination unproved — `lib/engine/match_engine.dart:1174`.
GAP M2-74: Elder — online public reveal, night privacy, shot combination unproved — `supabase/migrations/20261007000500_roles.sql:108`.
GAP M2-77: Elder — offline skip and parity unproved — `lib/engine/legal_moves.dart:416`.
GAP M2-78: Elder — online expiry/disconnect unproved — `supabase/functions/advance_phase/index.ts:105`.
GAP M2-80: Sniper — online once-per-match shot path unproved — `supabase/functions/submit_night_action/index.ts:145`.
GAP M2-82: Sniper — online hit/miss resolution unproved — `supabase/functions/resolve_night/index.ts:164`.
GAP M2-84: Sniper — online Doctor/shot/death overlap unproved — `supabase/functions/resolve_night/index.ts:155`.
GAP M2-86: Sniper — online quiet-night/parity/multi-death display unproved — `lib/ui/screens/online/online_table_flow.dart:1577`.
GAP M2-88: Sniper — online expiry skip unproved — `supabase/functions/advance_phase/index.ts:105`.
GAP M2-90: Sniper — online rejection and locked-door shot unproved — `supabase/functions/resolve_night/index.ts:162`.
GAP M2-91: Sniper — offline death visibility unproved — `lib/ui/screens/night/morning_screen.dart:41`.
GAP M2-92: Sniper — online death visibility/witness unproved — `supabase/functions/witness_view/index.ts:71`.
GAP M2-93: Citizen — offline suspicion/skip and alignment unproved — `lib/engine/match_engine.dart:562`.
GAP M2-94: Citizen — online waiting/no stall unproved — `supabase/functions/advance_phase/index.ts:82`.
GAP M2-95: Citizen — offline fact generation from suspicion unproved — `lib/engine/match_engine.dart:568`.
GAP M2-96: Citizen — online no-suspicion trace unproved — `supabase/functions/submit_night_action/index.ts:61`.
GAP M2-99: Citizen — offline silence/parity combination unproved — `lib/engine/win_check.dart:63`.
GAP M2-100: Citizen — online silence/voice combination unproved — `supabase/functions/claim_floor/index.ts:35`.
GAP M2-101: Citizen — offline skip/death visibility unproved — `lib/engine/match_engine.dart:670`.
GAP M2-102: Citizen — online expiry/death visibility unproved — `supabase/functions/advance_phase/index.ts:82`.
GAP M2-104: Deal and balance — online four-player start refusal has no proving test — `supabase/functions/start_match/index.ts:56`.
GAP M2-107: Deal and balance — offline sold-role thresholds together unproved — `lib/ui/screens/setup/optional_roles.dart:35`.
GAP M2-108: Deal and balance — online lobby/server/ownership combination unproved — `supabase/functions/start_match/index.ts:72`.
GAP M2-109: Deal and balance — offline complete role cap validation unproved — `lib/engine/balance_guard.dart:130`.
GAP M2-110: Deal and balance — online full role validation unproved — `supabase/functions/start_match/index.ts:77`.
GAP M2-111: Deal and balance — offline seeded deal and privacy together unproved — `lib/engine/match_engine.dart:153`.
GAP M2-112: Deal and balance — online atomic deal/reconnect and privacy unproved — `supabase/migrations/20261009000100_deal_all_roles.sql:13`.
GAP M2-113: Deal and balance — offline owned-role flag/deal combination unproved — `lib/ui/screens/setup/optional_roles.dart:79`.
GAP M2-114: Deal and balance — online ownership/flag/deal combination unproved — `supabase/functions/start_match/index.ts:74`.
GAP M2-115: Deal and balance — offline 20-player full match outcome unproved — `lib/engine/win_check.dart:63`.
GAP M2-118: Deal and balance — online paid-role ownership path unproved — `supabase/functions/start_match/index.ts:72`.
