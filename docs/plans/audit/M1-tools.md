# M1 — Online table tools

Static audit only; tests named below were inspected, not run. A `live` label denotes a real-server test file, not a passing run. Packs can be bought and held on the account without entering a match; activation requires an online room (RL20). The shared use transaction checks membership, phase, targets, limits, and charge before writing a use and public log; `sql-sim` cannot prove concurrent calls.

## extra_minute

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-1 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 extra_minute; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (extra_minute; 4/20 seats) | sql-sim | OK |
| M1-2 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 extra_minute; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-3 | Public feed names user and tool; no role is implied because any living role can buy it | §5.2 extra_minute; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-4 | Structured floor claim adds 45 seconds once; stacks with objection to 75 | §5.2 extra_minute; C91 | supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:100 | supabase/tests/live_tools_regressions.sql: bonus added exactly once | sql-sim | OK |
| M1-5 | Free discussion refuses before decrement | RL14 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:34 | supabase/tests/floor_tools_free_room.sql: refuses before charge | sql-sim | OK |
| M1-6 | Bought after own last floor or silenced, then timer expires — charge is spent though no floor bonus can apply | §5.2 extra_minute; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — the floor bonus waits for the holder's next turn (consumed_at), next day included |
| M1-7 | Two users race for floor, disconnected/kicked buyer, reconnect and phase expiry; one grant should consume once — needs-live | §5.2 extra_minute; I3/I9 | supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:36 | supabase/tests/live_tools_regressions.sql: same-holder retry changed deadline | sql-sim | GAP |

## anon_note

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-8 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 anon_note; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (anon_note; 4/20 seats) | sql-sim | OK |
| M1-9 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 anon_note; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-10 | Public note text without author; feed does not identify a role | §5.2 anon_note; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-11 | 1–140 nonblank characters posted immediately; bad note rejected without charge | §5.2 anon_note; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:59 | supabase/tests/live_tools_regressions.sql: anonymous note exposes its author / lost its text | sql-sim | OK |
| M1-12 | Secret log stores tool code with null seat; all clients see note, no role-only capability | §5.2 anon_note; doc 05 | supabase/functions/_shared/tools.ts:33 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-13 | Simultaneous uses and lost-response retry must not duplicate a note — needs-live | §5.0; I9 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:75 | none | none | GAP |

## last_will

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-14 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 last_will; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (last_will; 4/20 seats) | sql-sim | OK |
| M1-15 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 last_will; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-16 | Public will text; no role fact supplied by app | §5.2 last_will; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-17 | Dead user posts a short will at once; living user refused | RL14; §5.2 last_will | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: dead will posted immediately; living refused | sql-sim | OK |
| M1-18 | Used at night — feed is hidden until day, or forever if match ends that night | RL14; toolLastWillDesc; I3/I7 | lib/ui/screens/online/table/tool_feed.dart:11 | `supabase/tests/tool_guards.sql: T6 a will recorded during night is not immediately public` | sql-sim | FIXED 7c01244 — no last will at night |
| M1-19 | Kicked dead player and ended match cannot post; no charge on refusal | §5.0 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:26 | supabase/tests/tools_gaps.sql: kicked and ended will refusal preserves charge | sql-sim | OK |

## spotlight

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-20 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 spotlight; RL15; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (spotlight; 4/20 seats) | sql-sim | OK |
| M1-21 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 spotlight; RL15; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-22 | Public feed names buyer and target; free talk calls target out without role data | §5.2 spotlight; RL15; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-23 | Structured discussion gives target the next floor; last word precedes it | RL15 | supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:61 | supabase/tests/floor_priority.sql: spotlight and last word priority | sql-sim | OK |
| M1-24 | Dead or silenced target, expiry, free discussion, and other phases do not hold the floor | RL15 | supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:73 | supabase/tests/floor_priority.sql: dead / silenced / free / other phases | sql-sim | OK |
| M1-25 | Buyer can select an alive but already silenced target, or buy after discussion; effect cannot grant speech, charge spent | RL15; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:53 | `supabase/tests/tool_guards.sql: T5 spotlight requires an alive, speaking target and a talk phase` | sql-sim | FIXED 7c01244 — spotlight needs a living unsilenced target in a talk phase |
| M1-26 | Two users buy concurrently; floor claimant and phase timer race with priority hold — needs-live | RL15; I9 | supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:83 | none | none | GAP |

## objection

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-27 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 objection; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (objection; 4/20 seats) | sql-sim | OK |
| M1-28 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 objection; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-29 | Public feed names user and tool; no role inference | §5.2 objection; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-30 | Structured first floor claim adds 30 seconds, stacking with extra minute | RL14; C91 | supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:100 | supabase/tests/server_fixes.test.mjs: floor bonus is spent by first granted claim | unit | OK |
| M1-31 | Free discussion refused without charge or public trace | RL14 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:34 | supabase/tests/floor_tools_free_room.sql: refuses before charge | sql-sim | OK |
| M1-32 | Bought when silenced or after final possible turn — charge spent without a 30-second defense | toolObjectionDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — the floor bonus waits for the holder's next turn (consumed_at), next day included |

## last_word

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-33 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 last_word; RL15; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (last_word; 4/20 seats) | sql-sim | OK |
| M1-34 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 last_word; RL15; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-35 | Public feed names buyer and target; if eliminated, verdict also names chosen seat | §5.2 last_word; RL15; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-36 | Only eliminated owner gets next-day first speaker; public verdict even if match ends | RL15 | supabase/functions/resolve_vote/index.ts:216 | supabase/tests/vote_rules.test.mjs: last word: eliminated seat's own last word names who speaks first | unit | OK |
| M1-37 | Priority lapses after 20 seconds or if target dead/silenced; spotlight follows | RL15 | supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:61 | supabase/tests/floor_priority.sql: last word before spotlight / lapse | sql-sim | OK |
| M1-38 | Owner survives, target dies overnight, or match ends — charge spent though speech never occurs | toolLastWordDesc; RL15; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |
| M1-39 | Reconnect after verdict should show who was chosen, including match-ending verdict | RL15; I5 | supabase/functions/resolve_vote/index.ts:235 | `supabase/tests/live_local_m1.test.mjs: M1-39: a last word names the chosen seat in the verdict a reconnecting client reads, also when the verdict ends the match` | edge-local | OK |

## vote_shield

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-40 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 vote_shield; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (vote_shield; 4/20 seats) | sql-sim | OK |
| M1-41 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 vote_shield; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-42 | Public feed names owner and shield; any role can buy, so no role inference | §5.2 vote_shield; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-43 | Day N shield blocks N+1 night silence; half/lock door redundancy | RL14; C69/C80 | supabase/functions/_shared/tools.ts:85 | supabase/tests/server_fixes.test.mjs: vote_shield bought on day N covers night N + 1 only | unit | OK |
| M1-44 | Silencer target blocked, but cannot be silenced if dead same night | §5.2 vote_shield; RL7 | supabase/functions/resolve_night/index.ts:175 | supabase/tests/server_fixes.test.mjs: silence cannot land on seat that died same night | unit | OK |
| M1-45 | Bought before elimination, kick, or match-ending vote — charge spent though next-night shield never activates | toolVoteShieldDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |
| M1-46 | Day-phase closure racing shield use must either record the shield or refuse without charge — needs-live | I2/I9 | supabase/functions/resolve_night/index.ts:60 | none | none | GAP |

## half_door

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-47 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 half_door; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (half_door; 4/20 seats) | sql-sim | OK |
| M1-48 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 half_door; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-49 | Public feed names owner and half door; no role inference | §5.2 half_door; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-50 | Next night blocks silence and investigation; kill/shot still land; lock dominates | §5.2 half_door; C79–C82 | supabase/functions/_shared/tools.ts:55 | supabase/tests/table_tools.test.ts: detective faces: impersonate, camouflage, door | unit | OK |
| M1-51 | Detective sees unreachable on covered seat | §5.2 half_door | supabase/functions/_shared/tools.ts:73 | supabase/tests/table_tools.test.ts: detective faces: impersonate, camouflage, door | unit | OK |
| M1-52 | Target (owner) eliminated/kicked before next night; paid effect lapses | toolHalfDoorDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |
| M1-53 | Actual kill plus shot plus silence combination on real server, including 4/20 seats | §5.2 half_door; C82 | supabase/functions/resolve_night/index.ts:139 | `supabase/tests/live_local_m1.test.mjs: M1-53: kill, sniper shot and silence on one real night: a half door lets the first two through and blocks only the silence (7, 15 and 20 seats, 4 alive)` | edge-local | OK |

## double_vote

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-54 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 double_vote; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (double_vote; 4/20 seats) | sql-sim | OK |
| M1-55 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 double_vote; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-56 | Public feed names owner and doubled ballot; no role inference | §5.2 double_vote; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-57 | Own ballot counts twice today and in revote; revealed Elder multiplier makes six | §5.2 double_vote; C69 | supabase/functions/resolve_vote/index.ts:109 | `supabase/tests/live_local_m1.test.mjs: M1-57: bought double vote combines with revealed Elder in both ballot rounds` | edge-local | OK |
| M1-58 | Silenced buyer cannot cast; disconnected buyer may abstain; eliminated buyer never votes, but charge already spent | toolDoubleVoteDesc; I3 | supabase/functions/submit_vote/index.ts:35 | `supabase/tests/tool_guards.sql: T4 silence blocks both ways of buying ballot weight` | sql-sim | FIXED 7c01244 — a silenced player is refused before any charge |
| M1-59 | Weighted ballot appears in public tally and appeal denominator | §5.2 double_vote; C74 | supabase/functions/resolve_vote/index.ts:126 | `supabase/tests/live_local_m1.test.mjs: M1-59: a double ballot is weighted in the public tally and in both sides of an appeal` | edge-local | OK |

## camouflage

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-60 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 camouflage; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (camouflage; 4/20 seats) | sql-sim | OK |
| M1-61 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 camouflage; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-62 | Feed says only secret tool used; role and face are not displayed | §5.2 camouflage; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-63 | Next night Detective sees unclear; half/lock door and impersonate take precedence | §5.2 camouflage; C79 | supabase/functions/_shared/tools.ts:73 | supabase/tests/table_tools.test.ts: detective faces: impersonate, camouflage, door | unit | OK |
| M1-64 | Secret public payload still contains tool code, though seat and targets are null/empty; no direct role identified | §5.0; doc 05 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:102 | supabase/tests/tools_gaps.sql: camouflage raw public payload | sql-sim | OK |
| M1-65 | Owner dies/kicked before next night or no Detective investigates; charged with no mask encounter | toolCamouflageDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |
| M1-66 | Real Detective versus face and door, reconnecting to private answer | §5.2 camouflage; I5 | supabase/functions/submit_night_action/index.ts:276 | `supabase/tests/live_local_m1.test.mjs: M1-66: a real Detective meets a mask, a bought face and a door, and reads the same private answer again on reconnect` | edge-local | OK |

## revote

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-67 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 revote; RL13/RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (revote; 4/20 seats) | sql-sim | OK |
| M1-68 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 revote; RL13/RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-69 | Public feed names buyer and tool; no role inference | §5.2 revote; RL13/RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-70 | Round-one winner or tie opens one restricted second ballot under either tie setting | RL13; C70–C72 | supabase/functions/resolve_vote/index.ts:147 | supabase/tests/vote_rules.test.mjs: tie under no-elimination stands unless bought / second round never reopens | unit | OK |
| M1-71 | Can buy in round two; tool cannot trigger a third round, yet charge is spent | toolRevoteDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:47 | `supabase/tests/tool_guards.sql: T2 a bought revote has no effect after the opening ballot` | sql-sim | FIXED 7c01244 — revote refused in round 2 |
| M1-72 | No votes/timer expiry or owner kicked after use; use row remains, but effect depends on countable round-one ballot | §5.2 revote; C97 | supabase/functions/resolve_vote/index.ts:140 | supabase/tests/vote_rules.test.mjs: no votes at all is nothing to decide | unit | ACCEPTED (rare) — a revote with no ballots has nothing to reopen |
| M1-73 | Concurrent use as vote resolver commits must not lose bought revote | I2/I9 | supabase/functions/resolve_vote/index.ts:88 | `supabase/tests/tool_guards.sql: T1 the commit rejects a tally made before a vote tool was bought; supabase/tests/vote_fingerprint.test.mjs` | sql-sim | FIXED 7c01244 — the resolution fingerprint covers the day's tool uses |

## grave_vote

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-74 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 grave_vote; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (grave_vote; 4/20 seats) | sql-sim | OK |
| M1-75 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 grave_vote; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-76 | Public feed names dead buyer and tool; dead status is already public, no role inference | §5.2 grave_vote; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-77 | Dead user casts one opening ballot that day; cannot vote in round two or twice | §5.2 grave_vote; C84/C85 | supabase/functions/submit_vote/index.ts:23 | supabase/tests/new_roles_tools_match.py: grave first ballot / once per day | live | OK |
| M1-78 | Dead user can buy after ballot has closed or during last night; no later opening ballot, charge spent | toolGraveVoteDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | `supabase/tests/tool_guards.sql: T3 the dead seat cannot buy a ballot after this vote window` | sql-sim | FIXED 7c01244 — grave vote only inside a ballot window |
| M1-79 | Silenced dead voter is rejected; bought charge remains | §5.2 grave_vote; RL8 | supabase/functions/submit_vote/index.ts:35 | `supabase/tests/tool_guards.sql: T4 silence blocks both ways of buying ballot weight` | sql-sim | FIXED 7c01244 — a silenced player is refused before any charge |
| M1-80 | 4-seat final ballot and 20-seat early closure must count grave voter if cast; reconnect must not duplicate | §5.2 grave_vote; I5/I9 | supabase/functions/resolve_vote/index.ts:119 | `supabase/tests/live_local_m1.test.mjs: M1-80: a grave ballot is counted once at a four-seat final ballot and after the early closure of a 15- and a 20-seat ballot, and a reconnect does not repeat it` | edge-local | OK |

## sense

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-81 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 sense; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (sense; 4/20 seats) | sql-sim | OK |
| M1-82 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 sense; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-83 | Public feed names user but hides all three targets; any role can buy, no role inference | §5.2 sense; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-84 | Immediate private yes/no uses true Mafia team including Silencer; doors/faces ignored | §5.2 sense; C77/C78 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:87 | supabase/tests/server_fixes_20261009.sql: Silencer answer and owner-only readback | sql-sim | OK |
| M1-85 | Three distinct living other seats required; 4-player table initially has exactly three, late table below four cannot use | §5.0; §5.2 sense | supabase/migrations/20261016000400_floor_tools_need_turns.sql:51 | supabase/tests/new_roles_tools_match.py: bad targets sense | live | OK |
| M1-86 | Owner-only answer survives reconnect; another player cannot read it | §5.2 sense; doc 05 | supabase/migrations/20261009000400_table_tools_fixes.sql:114 | supabase/tests/server_fixes_20261009.sql: owner-only answers | sql-sim | OK |
| M1-87 | Ambiguous retry after an earlier successful use — fallback matches only tool code, so a lost refusal can look like a new answer | I7/I9 | lib/ui/economy/table_tools.dart:201 | `test/ui/economy/tool_answer_match_test.dart: recovered answer belongs to the phase and targets of this use` | unit | FIXED 537e3f0 — a recovered answer must match phase and targets |

## impersonate

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-88 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 impersonate; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (impersonate; 4/20 seats) | sql-sim | OK |
| M1-89 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 impersonate; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-90 | Feed says only secret tool; chosen citizen/mafia face remains private | §5.2 impersonate; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-91 | Face must be citizen/mafia; next-night Detective sees it unless door overrides | §5.2 impersonate; C78 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:63 | supabase/tests/table_tools.test.ts: detective faces: impersonate, camouflage, door | unit | OK |
| M1-92 | Sense/whisper still report true Mafia team despite face | §5.2 impersonate; C78 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:89 | supabase/tests/server_fixes_20261009.sql: true Silencer answer | sql-sim | OK |
| M1-93 | Raw public log contains tool code despite secret UI; no explicit role leak, but public shape differs | doc 05; §5.0 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:102 | supabase/tests/tools_gaps.sql: impersonate raw public payload | sql-sim | OK |
| M1-94 | Owner eliminated before next night or no Detective targets owner; paid chosen face never shown | toolImpersonateDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |

## narrator_whisper

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-95 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 narrator_whisper; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (narrator_whisper; 4/20 seats) | sql-sim | OK |
| M1-96 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 narrator_whisper; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-97 | Feed names user but hides both targets and private answer; no role inference | §5.2 narrator_whisper; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-98 | Immediate private answer from true Mafia roles; same truth with doors and impersonation | §5.2 narrator_whisper; C77/C78 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:87 | supabase/tests/server_fixes_20261009.sql: private yes/no answer | sql-sim | OK |
| M1-99 | Distinct two living others; late 4-player table with fewer than three alive cannot buy/use | §5.0; §5.2 narrator_whisper | supabase/migrations/20261016000400_floor_tools_need_turns.sql:51 | supabase/tests/new_roles_tools_match.py: bad targets narrator_whisper | live | OK |
| M1-100 | Only owner can reread on reconnect; private response should match this use | §5.2 narrator_whisper | supabase/migrations/20261009000400_table_tools_fixes.sql:114 | supabase/tests/server_fixes_20261009.sql: owner-only answers | sql-sim | OK |
| M1-101 | Ambiguous retry after an earlier successful use — fallback does not match an attempt ID | I7/I9 | lib/ui/economy/table_tools.dart:206 | `test/ui/economy/tool_answer_match_test.dart: recovered answer belongs to the phase and targets of this use` | unit | FIXED 537e3f0 — a recovered answer must match phase and targets |

## lock_door

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-102 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 lock_door; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (lock_door; 4/20 seats) | sql-sim | OK |
| M1-103 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 lock_door; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-104 | Public feed names buyer and door; no role inference | §5.2 lock_door; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-105 | Next night blocks kill, sniper shot and sniper penalty, silence, investigation; half door dominated | §5.2 lock_door; C77/C81/C83 | supabase/functions/resolve_night/index.ts:139 | `supabase/tests/live_local_m1.test.mjs: M1-105: a bought lock door blocks the kill, the sniper shot and its penalty, the silence and the investigation for the next night only` | edge-local | OK |
| M1-106 | Detective sees unreachable; sense/whisper still truth | §5.2 lock_door; C77 | supabase/functions/_shared/tools.ts:73 | supabase/tests/table_tools.test.ts: detective faces: impersonate, camouflage, door | unit | OK |
| M1-107 | Buyer eliminated/kicked before next night; charge spent with no possible protection | toolLockDoorDesc; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | none | none | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |
| M1-108 | Day-phase closure races a lock-door use; all clients must agree on accepted protection — needs-live | I2/I5/I9 | supabase/functions/resolve_night/index.ts:60 | none | none | GAP |

## appeal

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M1-109 | Authorized use, wrong phase, dead/alive gate, invalid or duplicate target, repeated use, 4-tool/2-heavy cap; 4- and 20-seat tables | §5.2 appeal; RL14; §5.0; I2 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:40 | supabase/tests/tools_gaps.sql: per-tool guard matrix (appeal; 4/20 seats) | sql-sim | OK |
| M1-110 | Bought/held on account; offline activation is inapplicable (RL20 online-only) | §5.2 appeal; RL14; RL20 | lib/ui/economy/table_tools.dart:114 | test/widget/store_shop_test.dart: tool purchase forwards to economy | widget | N/A |
| M1-111 | Public feed names buyer and appeal; no role inference | §5.2 appeal; RL14; §5.0; doc 05 I1/I7 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:100 | test/widget/tool_feed_test.dart: renders max 3 newest-first in Arabic without overflow | widget | OK |
| M1-112 | If buyer would be eliminated, require more than 2/3 of others' weighted counted ballots; abstentions count | RL14; C74/C75 | supabase/functions/_shared/tools.ts:166 | supabase/tests/appeal_abstentions.test.mjs: two confirming votes and two abstentions cannot uphold an appeal | unit | OK |
| M1-113 | Bought revote takes precedence; appeal evaluated on final eliminating round | §5.2 appeal; C73 | supabase/functions/resolve_vote/index.ts:170 | supabase/tests/remaining_conflicts_match.py: appeal blocks a weak majority after revote | live | OK |
| M1-114 | Buyer not eliminated or vote has no ballots: charge spent, no appeal effect | toolAppealDesc; C76; I3 | supabase/migrations/20261016000400_floor_tools_need_turns.sql:81 | supabase/tests/server_fixes.test.mjs: appeal numerator and denominator | unit | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |
| M1-115 | Concurrent appeal use versus resolver read/commit; retry must not lose paid protection | I2/I9 | supabase/functions/resolve_vote/index.ts:88 | `supabase/tests/tool_guards.sql: T1 the commit rejects a tally made before a vote tool was bought; supabase/tests/vote_fingerprint.test.mjs` | sql-sim | FIXED 7c01244 — the resolution fingerprint covers the day's tool uses |

## Findings

SUSPECT M1-73 [I2,I3,I9]: revote — resolution fingerprint omits tool-use rows; read/commit race can discard paid revote — supabase/functions/resolve_vote/index.ts:88

SUSPECT M1-115 [I2,I3,I9]: appeal — resolution fingerprint omits tool-use rows, so late appeal can be missed — supabase/functions/resolve_vote/index.ts:88

SUSPECT M1-18 [I3,I7]: last_will — will charged and logged at night while everyone’s feed hides it — lib/ui/screens/online/table/tool_feed.dart:11

SUSPECT M1-71 [I3]: revote — round-two use is charged although second round never reopens — supabase/migrations/20261016000400_floor_tools_need_turns.sql:47

SUSPECT M1-78 [I3]: grave_vote — dead-only use has no ballot-window guard and can charge after final ballot — supabase/migrations/20261016000400_floor_tools_need_turns.sql:40

SUSPECT M1-79 [I3]: grave_vote — silenced grave voter may pay but cannot cast the promised vote — supabase/functions/submit_vote/index.ts:35

SUSPECT M1-58 [I3]: double_vote — tool accepted for silenced or pre-vote-eliminated user with no doubled ballot — supabase/functions/submit_vote/index.ts:35

SUSPECT M1-25 [I3]: spotlight — silenced target or passed discussion accepted despite no speech effect — supabase/migrations/20261016000400_floor_tools_need_turns.sql:53

SUSPECT M1-6 [I3]: extra_minute — accepted after last possible floor; charge spent without seconds — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-32 [I3]: objection — accepted when no further eligible floor claim can occur — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-72 [I3]: revote — can charge with no ballots, so described revote never occurs — supabase/functions/resolve_vote/index.ts:140

SUSPECT M1-87 [I7,I9]: sense — fallback can present the earlier answer as a successful new attempt — lib/ui/economy/table_tools.dart:201

SUSPECT M1-101 [I7,I9]: narrator_whisper — fallback can present an earlier answer as a successful new attempt — lib/ui/economy/table_tools.dart:206

SUSPECT M1-38 [I3]: last_word — conditional next-day speech can never occur after charge — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-45 [I3]: vote_shield — prepaid next-night protection can become unreachable on same-day elimination — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-52 [I3]: half_door — next-night effect charged even if player leaves before that night — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-65 [I3]: camouflage — conditional detective mask can never occur after pre-night death — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-94 [I3]: impersonate — charged face can become impossible before next-night investigation — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-107 [I3]: lock_door — prepaid full-night door can never activate after same-day elimination — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81

SUSPECT M1-114 [I3]: appeal — conditional appeal is charged even when buyer never faces elimination — supabase/migrations/20261016000400_floor_tools_need_turns.sql:81



































































### Needs live

GAP M1-7 [I3,I9]: extra_minute — single-connection test cannot prove cross-user floor race — supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:36

GAP M1-13 [I9]: anon_note — concurrent/lost-response note use has no real-server idempotency proof — supabase/migrations/20261016000400_floor_tools_need_turns.sql:75

GAP M1-26 [I9]: spotlight — real competing floor claims and timer expiry lack live proof — supabase/migrations/20261016000300_floor_priority_spotlight_last_word.sql:83

GAP M1-39 [I5]: last_word — client verdict UI has no direct last-word announcement test — supabase/functions/resolve_vote/index.ts:235

GAP M1-46 [I2,I9]: vote_shield — no live test of shield use versus day-phase closure — supabase/functions/resolve_night/index.ts:60

GAP M1-53 [I5]: half_door — combined server outcome lacks live match proof — supabase/functions/resolve_night/index.ts:139

GAP M1-57 [I3,I5]: double_vote — pure weight test does not prove real vote tally and Elder combination — supabase/functions/resolve_vote/index.ts:109

GAP M1-59 [I5]: double_vote — no live test of double vote in public tally/appeal — supabase/functions/resolve_vote/index.ts:126

GAP M1-66 [I5]: camouflage — no live mask plus Detective readback test — supabase/functions/submit_night_action/index.ts:276

GAP M1-80 [I5,I9]: grave_vote — no live early-close/large-table grave ballot proof — supabase/functions/resolve_vote/index.ts:119

GAP M1-105 [I3,I5]: lock_door — pure next-night set test does not prove all real kill/shot interactions — supabase/functions/resolve_night/index.ts:139

GAP M1-108 [I2,I5,I9]: lock_door — no live use versus day-phase closure test — supabase/functions/resolve_night/index.ts:60

## Resolution (2026-10-17, orchestrator)

| SUSPECT | Outcome |
|---|---|
| M1-73, M1-115 | FIXED 7c01244 — the vote fingerprint covers the day's vote tools (supabase/tests/vote_fingerprint.test.mjs, tool_guards.sql) |
| M1-71 | FIXED 7c01244 — revote refused in round 2 (tool_guards.sql) |
| M1-78 | FIXED 7c01244 — grave vote only in discuss/defense/vote (tool_guards.sql) |
| M1-58, M1-79 | FIXED 7c01244 — SILENCED refusal (tool_guards.sql); client line 537e3f0 |
| M1-25 | FIXED 7c01244 — spotlight needs a living unsilenced target in a talk phase |
| M1-18 | FIXED 7c01244 — no last will at night |
| M1-87, M1-101 | FIXED 537e3f0 — recovered answer must match phase and targets (test/ui/economy/tool_answer_match_test.dart) |
| M1-38, M1-45, M1-52, M1-65, M1-94, M1-107, M1-114 | ACCEPTED — conditional tools are cover bought in advance; their descriptions state the condition |
| M1-6, M1-32 | ACCEPTED — the floor bonus waits for the holder's next turn (consumed_at), next day included |
| M1-72 | ACCEPTED (rare) — a revote with no ballots has nothing to reopen |
