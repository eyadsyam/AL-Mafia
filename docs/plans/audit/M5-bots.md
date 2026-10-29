# M5 — Vs-computer match audit

Static audit of the current worktree. Tests below were read, not run; `Evidence` names the test's level, not an execution result. Rule references use `docs/specs/17-roles-and-tools.md` §12 (including its later RL22) and `docs/specs/05-zero-leakage-spec.md` (05). `—` in Test means no test was found for that specific claim.

## Flow: entry, deal, phases, termination

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M5-1 | Entry stays hidden until the owner enables it | Release gate remains closed until safe (§2.1) | `lib/app/router.dart:224`, `lib/app/router.dart:507` | — | none | GAP |
| M5-2 | Sheet bounds seats to 5–12 and returns preset and level | Bot table 5–12 (§2.1, §2.6) | `lib/ui/screens/setup/bot_match_sheet.dart:30`, `lib/ui/screens/setup/bot_match_sheet.dart:62` | `test/widget/bot_sheet_test.dart:122` the stepper fans seats in and stops at its bounds; `:149` the start button hands back size, level and preset | widget | OK |
| M5-3 | Owned optional roles fit the count; unavailable roles drop | RL12, RL22 | `lib/ui/screens/setup/bot_match_sheet.dart:37`, `lib/ui/screens/setup/optional_roles.dart:79` | `test/widget/bot_sheet_test.dart:185` owned roles reach the pick and become a legal split; `:209` a role left on at a table that cannot take it is dropped | widget | OK |
| M5-4 | Seat 0 may receive any role — no human-per-role match test | Same shuffled deal for any seat (§2.6) | `lib/app/router.dart:293`, `lib/engine/match_engine.dart:153` | — | none | GAP |
| M5-5 | Deal skips bot cards and stops at the human card | No bot secret shown (05 §2; §2.6) | `lib/transport/local_transport.dart:109`, `lib/transport/local_transport.dart:295` | `test/integration/bot_match_test.dart:51` a match against bots reaches a result (seed $seed) | widget | OK |
| M5-6 | Night advances through bot turns to morning, including a human night turn | Every night resolves (§3.1; I4) | `lib/transport/local_transport.dart:109`, `lib/ui/screens/match_flow.dart:704` | `test/integration/bot_match_test.dart:51` a match against bots reaches a result (seed $seed) | widget | OK |
| M5-7 | Opening and confrontation branches close — no branch-specific bot test | Both lead to discussion (§3.1) | `lib/ui/screens/match_flow.dart:790`, `lib/ui/screens/match_flow.dart:805` | — | none | GAP |
| M5-8 | Free discussion completes and bot lines appear | Bot match forces free talk (§2.6; §6) | `lib/app/router.dart:297`, `lib/ui/screens/match_flow.dart:878` | `test/integration/bot_match_test.dart:51` a match against bots reaches a result (seed $seed) | widget | OK |
| M5-9 | Voting, tie and one revote — bot UI path not specifically exercised for a tie | One revote only, among tied seats (§6) | `lib/ui/screens/match_flow.dart:581`, `lib/engine/match_engine.dart:1347` | `test/engine/day_tie_revote_test.dart:150` revote ballot is restricted to the tied seats only | unit | GAP |
| M5-10 | Every preset and 5–12 seat all-bot table reaches a winner | Every match ends (§3.1; §7) | `lib/engine/bots/bot_brain.dart:103`, `lib/engine/win_check.dart:63` | `test/engine/bot_brain_test.dart:83` bots finish every preset at every table size | unit | OK |
| M5-11 | Human in every role, at both 5 and 12 seats — not covered | Human participation cannot stall (§2.6; I4) | `lib/app/router.dart:299`, `lib/ui/screens/match_flow.dart:568` | `test/integration/bot_match_test.dart:50` six seeds, one 7-seat table only | widget | GAP |
| M5-12 | Human dies early; remaining bots must finish — no specific test | Dead seats leave the turn loop (§3.1; §7) | `lib/transport/local_transport.dart:109`, `lib/engine/legal_moves.dart:383` | — | none | GAP |
| M5-13 | Resume mid-bot-match — bot controller is lost on restore, so bot seats require human turns | Match must continue after restart (§3.1; I4/I9) | `lib/ui/screens/match_controller.dart:366`, `lib/app/resume_gate.dart:76` | — | none | SUSPECT |
| M5-14 | Four-seat and twenty-seat bot tables | N/A: bot offering is explicitly 5–12 (§2.1) | `lib/ui/screens/setup/bot_match_sheet.dart:30` | `test/widget/bot_sheet_test.dart:122` the stepper fans seats in and stops at its bounds | widget | N/A |
| M5-15 | By-turns bot discussion | N/A: router forces free talk (§2.6) | `lib/app/router.dart:297` | — | none | N/A |
| M5-16 | Kicked or disconnected bot target / two human racers | N/A: one local device, no online seats or kick (§2.6) | `lib/app/router.dart:299`, `lib/transport/local_transport.dart:171` | — | none | N/A |
| M5-17 | Server phase timer expiry in a bot match | N/A: local bot matches have no server timer (§3.3) | `lib/transport/local_transport.dart:419` | — | none | N/A |

## Bot decisions and knowledge

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M5-18 | Bot picks from legal moves and applies them through the engine | No illegal or double action (§4, §6) | `lib/engine/bots/bot_brain.dart:104`, `lib/transport/local_transport.dart:113` | `test/engine/bot_brain_test.dart:83` bots finish every preset at every table size | unit | OK |
| M5-19 | Dead bot, dead/self target and wrong phase cannot be chosen — no targeted bot test | Living actor and target, legal phase (§4; RL18) | `lib/engine/legal_moves.dart:383`, `lib/engine/legal_moves.dart:426` | — | none | GAP |
| M5-20 | One Mafia team quiet night, including another Mafioso's kill vote | RL1, §4.1 | `lib/engine/bots/bot_brain.dart:185`, `lib/engine/bullets.dart:51` | `test/engine/rule_matrix_test.dart:1093` C64: a team quiet night cancels another Mafia vote; `:1109` C65: second Mafioso cannot spend the team bullet | unit | OK |
| M5-21 | Doctor no-repeat and one self-protection | RL3; roleDoctorDescription | `lib/engine/legal_moves.dart:435`, `lib/engine/bullets.dart:66` | `test/engine/rule_matrix_test.dart:472` C5: doctor cannot cover the same player on consecutive nights; `:454` C4: doctor cannot spend self bullet twice | unit | OK |
| M5-22 | Detective gets one investigation per night; only its own answer informs it | RL5; roleDetectiveDescription | `lib/engine/match_engine.dart:538`, `lib/engine/bots/bot_brain.dart:94` | `test/engine/detective_result_ephemeral_test.dart:63` second investigate in same turn throws StateError | unit | OK |
| M5-23 | Silencer inherits kill when no living Mafioso — bot-specific choice not asserted | §4.2, RL6 | `lib/engine/legal_moves.dart:407`, `lib/engine/bots/bot_brain.dart:184` | `test/engine/rule_matrix_test.dart:792` C31: silencer inherits kill after last killer leaves | unit | GAP |
| M5-24 | Sniper bot fires once only on its public trace and own read — no bot-shot test | §4.6; roleSniperDescription | `lib/engine/bots/bot_brain.dart:223`, `lib/engine/bullets.dart:66` | — | none | GAP |
| M5-25 | Citizen and Elder bot suspicion is an offline-only move — no bot-specific observation test | RL4 (§4.5, §4.7) | `lib/engine/bots/bot_brain.dart:236`, `lib/engine/legal_moves.dart:386` | — | none | GAP |
| M5-26 | Silenced bot skips ballot and remains a valid elimination target | RL7–RL8; §6 | `lib/engine/bots/bot_brain.dart:166`, `lib/engine/legal_moves.dart:515` | `test/engine/rule_matrix_test.dart:750` C28: silenced seat cannot cast a ballot; `:765` C29: silenced seat may be voted out | unit | OK |
| M5-27 | Abstention setting permits null ballot, but bot always scores it below every target — no bot abstention test | RL9; §6 | `lib/engine/legal_moves.dart:533`, `lib/engine/bots/bot_brain.dart:273` | — | none | GAP |
| M5-28 | Town bot reads are biased toward the actual Mafia before any public evidence — hidden-role oracle | Town bots know no roles (§2.6; 05 §1; I1) | `lib/engine/bots/bot_brain.dart:58`, `lib/engine/bots/bot_brain.dart:73` | — | none | SUSPECT |
| M5-29 | Bots use individual private VoteCast ballots as public suspicion and heat | Ballots are secret until result (§3.3; 05 §1; I1) | `lib/engine/bots/bot_brain.dart:301`, `lib/engine/bots/bot_brain.dart:329` | — | none | SUSPECT |
| M5-30 | Two bots act at the same instant | N/A: `_driveBots` applies one synchronous move at a time (§2.6) | `lib/transport/local_transport.dart:112` | — | none | N/A |
| M5-31 | All combinations of sold roles at 9–12 seats terminate | RL12; §2.5, §7 | `lib/engine/bots/bot_brain.dart:174`, `lib/engine/win_check.dart:63` | `test/engine/bot_brain_test.dart:67` bots finish a match with ${roles.map((r) => r.name).join('+')} | unit | OK |

## Zero leakage: phone, sound, copy

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M5-32 | Day card picker opens any living bot's exact role after a hold — free direct leak | Only the human's role may be checked (05 §2–§4; I1) | `lib/ui/screens/match_flow.dart:526`, `lib/transport/local_transport.dart:200`, `lib/ui/screens/day/day_card_check.dart:89` | — | none | SUSPECT |
| M5-33 | Rewarded hint names whether a selected bot is Mafia — explicit role-alignment reveal | No role inference except ruled mechanics (05 §1; I1) | `lib/ui/screens/match_flow.dart:900`, `lib/ui/screens/match_flow.dart:937`, `lib/app/l10n/app_ar.arb:2674` | — | none | SUSPECT |
| M5-34 | Bot turns are auto-applied immediately; equal timing and tap path across bot roles unmeasured | Equal paths, 8-second/3-second gates (05 §2 rules 1–7) | `lib/transport/local_transport.dart:109`, `lib/ui/screens/match_flow.dart:704` | — | none | GAP |
| M5-35 | Bot turns' shape, light, sound and haptics have no per-role privacy test | Equal geometry and silence in hand (05 §2, §4 T1–T5) | `lib/ui/screens/match_flow.dart:301`, `lib/ui/screens/match_flow.dart:436` | — | none | GAP |
| M5-36 | Human outcome must stay off screen until result; bot-specific early-outcome test absent | No early outcome hint (05 §3–§4) | `lib/transport/local_transport.dart:152`, `lib/ui/screens/match_flow.dart:364` | — | none | GAP |
| M5-37 | Dead bots leave spoken discussion lines; no targeted bot-death UI test | Dead seats outside flow (05 §2 rule 9) | `lib/ui/screens/match_controller.dart:350` | — | none | GAP |
| M5-38 | Full standings only at result, but no bot-role reveal golden test | No live role roster (05 §3.5) | `lib/transport/local_transport.dart:158` | — | none | GAP |

## Rewards, economy, and ads

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M5-39 | Forge botWin after waiting one minute without finishing or winning — server has no result proof | Reward only an eligible finished win (I8/I9) | `supabase/migrations/20261009002100_bot_match_sessions.sql:27`, `supabase/functions/_shared/economy_actions.ts:296` | `supabase/tests/economy_hardening_story_bot.sql:24` valid session pays without a match | sql-sim | SUSPECT |
| M5-40 | Real sub-minute finished win is refused by the time floor | Eligible finished win receives reward (I8) | `supabase/migrations/20261009002100_bot_match_sessions.sql:30` | `supabase/tests/economy_hardening_story_bot.sql:21` one minute floor | sql-sim | SUSPECT |
| M5-41 | Replay same consumed session pays zero; old session invalid after a new start | Reward once per match (I8/I9) | `supabase/migrations/20261009002100_bot_match_sessions.sql:16`, `supabase/migrations/20261009002100_bot_match_sessions.sql:35` | `supabase/tests/economy_hardening_story_bot.sql:19` starting a new match invalidates the old session; `:25` session consumed once | sql-sim | OK |
| M5-42 | 25 coins, at most five grants per UTC day | Amount unchanged and daily cap (§2.6; I8) | `supabase/migrations/20261009002100_bot_match_sessions.sql:23`, `supabase/migrations/20261009002100_bot_match_sessions.sql:36` | `supabase/tests/economy_hardening_story_bot.sql:27` daily cap remains five | sql-sim | OK |
| M5-43 | Concurrent claims for one user serialize, but harness has one connection and no live race test | Retry/race never double credits (I9) | `supabase/migrations/20261009002100_bot_match_sessions.sql:26`, `supabase/migrations/20261009002100_bot_match_sessions.sql:28` | `supabase/tests/economy_hardening_story_bot.sql:25` session consumed once (sequential) | sql-sim | GAP |
| M5-44 | Network failure clears client session before claim; no retry after an uncertain response | Retry cannot lose or duplicate an earned effect (I9) | `lib/ui/economy/bot_rewards.dart:30`, `lib/ui/economy/bot_rewards.dart:43` | — | none | SUSPECT |
| M5-45 | App restart loses in-memory reward session; a restored finished win cannot be claimed | Finished win remains claimable after restart (I8/I9) | `lib/ui/economy/bot_rewards.dart:6`, `lib/app/resume_gate.dart:76` | — | none | SUSPECT |
| M5-46 | Old claim completes after Play Again and can set the new match's coin row | Late response must not overwrite newer match state (I9) | `lib/ui/screens/match_flow.dart:988`, `lib/ui/screens/match_flow.dart:1116` | — | none | SUSPECT |
| M5-47 | Client checks seat-0 winning side before a claim; no bot winner/loser claim test | Reward only human win (§7; I8) | `lib/ui/screens/match_controller.dart:329`, `lib/ui/screens/match_flow.dart:985` | — | none | GAP |
| M5-48 | Bot rematch asks for a fresh reward session; no full rematch claim test | New match, new reward identity (I8/I9) | `lib/ui/screens/match_flow.dart:1114`, `lib/ui/screens/match_flow.dart:1115` | — | none | GAP |
| M5-49 | First bot deal calls the same pre-deal ad gate; bot-route cadence not tested | Preserve pre-deal cadence (§2.6) | `lib/app/router.dart:274`, `lib/ui/economy/interstitial_coordinator.dart:211` | `test/unit/ads_v3_policy_test.dart:344` pre-match: skipped the first time after launch, then shown (policy only) | unit | GAP |
| M5-50 | Play Again bypasses `beforeDeal`, invoking only the prior result ad | Preserve pre-deal cadence on each deal (I5) | `lib/ui/screens/match_flow.dart:1109`, `lib/ui/screens/match_flow.dart:1114` | — | none | SUSPECT |

## Rule parity and factual output

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M5-51 | Online table tools in a bot match | N/A: tools are online-only by RL20 | `lib/app/router.dart:292`, `lib/transport/local_transport.dart:105` | — | none | N/A |
| M5-52 | Bot preset uses RL22 split at 5–12 seats | Same recommended split (§12 RL22) | `lib/ui/screens/setup/bot_match_sheet.dart:47`, `lib/engine/presets.dart:143` | `test/widget/bot_sheet_test.dart:149` start button hands back size, level and preset | widget | GAP |
| M5-53 | Fast save is announced, classic quiet-night save stays ambiguous, only surviving covered seat counts | RL2, RL17; I7 | `lib/engine/resolver.dart:220`, `lib/engine/resolver.dart:231` | `test/engine/rule_matrix_test.dart:152` RL17: a covered seat the Sniper takes is no save; `:176` RL2: with no bullets a save is told; `:199` RL2: with the quiet night on a save reads as nobody died | unit | OK |
| M5-54 | Kill, shot, silence and parity resolve after all night effects | RL7, RL10; §7 | `lib/engine/resolver.dart:170`, `lib/engine/resolver.dart:188` | `test/engine/rule_matrix_test.dart:99` F1: a seat killed the same night is not announced as silenced; `:693` C23: last mafioso shot ends in town win after morning | unit | OK |
| M5-55 | No eligible trace still renders T0 copy — rule says output nothing | No invented fact or filler (I7; project rule 4) | `lib/engine/match_engine.dart:813`, `lib/ui/information_text.dart:39` | `test/engine/trace_generator_test.dart:64` a night with no actions at all yields T0, and does not throw | unit | SUSPECT |
| M5-56 | Shared night, ballot and winner rules are implemented in the local engine, but bot-to-online parity has no paired assertion | Offline equals online except RL4/RL20 (§12; I5) | `lib/engine/legal_moves.dart:267`, `lib/app/router.dart:295` | — | none | GAP |

## Findings

SUSPECT M5-32 [I1]: Day card — any living bot's role can be opened through the public picker — `lib/ui/screens/match_flow.dart:526`.
SUSPECT M5-39 [I8/I9]: Reward claim — a timed session pays without proof of a finished human win — `supabase/migrations/20261009002100_bot_match_sessions.sql:27`.
SUSPECT M5-13 [I4/I9]: Resume — restored matches lose `BotBrain`, leaving bot turns for the human — `lib/ui/screens/match_controller.dart:366`.
SUSPECT M5-28 [I1]: Bot knowledge — town reads use actual Mafia roles before evidence — `lib/engine/bots/bot_brain.dart:58`.
SUSPECT M5-29 [I1]: Bot knowledge — private individual ballots are treated as public information — `lib/engine/bots/bot_brain.dart:301`.
SUSPECT M5-33 [I1]: Rewarded hint — reveals a living bot's Mafia alignment during play — `lib/ui/screens/match_flow.dart:937`.
SUSPECT M5-45 [I8/I9]: Reward restart — in-memory session disappears when the app restarts — `lib/ui/economy/bot_rewards.dart:6`.
SUSPECT M5-44 [I9]: Reward retry — session is cleared before an uncertain network result — `lib/ui/economy/bot_rewards.dart:31`.
SUSPECT M5-46 [I9]: Reward response — prior match's late claim can update later match coin state — `lib/ui/screens/match_flow.dart:989`.
SUSPECT M5-40 [I8]: Fast win — one-minute floor rejects an otherwise eligible finished win — `supabase/migrations/20261009002100_bot_match_sessions.sql:30`.
SUSPECT M5-50 [I5]: Rematch ads — Play Again skips the next deal's `beforeDeal` gate — `lib/ui/screens/match_flow.dart:1114`.
SUSPECT M5-55 [I7]: Trace output — T0 filler is displayed when no trace is eligible — `lib/ui/information_text.dart:39`.
GAP M5-1: Entry gate — no test keeps the bot offer hidden until reviewed — `lib/app/router.dart:224`.
GAP M5-4: Deal — no human-per-role coverage of shuffled seat 0 — `lib/engine/match_engine.dart:153`.
GAP M5-7: Opening/confrontation — bot-specific branches have no targeted completion test — `lib/ui/screens/match_flow.dart:805`.
GAP M5-9: Tie/revote — engine test does not prove the bot UI transition — `lib/ui/screens/match_flow.dart:581`.
GAP M5-11: Human roles/sizes — widget journey covers six seeds at one 7-seat table — `lib/app/router.dart:299`.
GAP M5-12: Human death — no test proves remaining bots complete the match — `lib/transport/local_transport.dart:109`.
GAP M5-19: Illegal/dead targets — no targeted bot test for phase and target refusal — `lib/engine/legal_moves.dart:383`.
GAP M5-23: Silencer inheritance — engine rule is tested, bot choice is not — `lib/engine/bots/bot_brain.dart:184`.
GAP M5-24: Sniper — no test proves bot shot choice and spending — `lib/engine/bots/bot_brain.dart:223`.
GAP M5-25: Citizen/Elder — no bot-specific suspicion observation test — `lib/engine/bots/bot_brain.dart:236`.
GAP M5-27: Abstention — bot never selects null despite allowed setting; no bot test — `lib/engine/bots/bot_brain.dart:273`.
GAP M5-34: Timing — auto-play has no per-role timing/tap-path measurement — `lib/transport/local_transport.dart:109`.
GAP M5-35: Presentation — no per-role bot shape, light, sound or haptic comparison — `lib/ui/screens/match_flow.dart:301`.
GAP M5-36: Early outcome — no bot-specific privacy test before result — `lib/transport/local_transport.dart:152`.
GAP M5-37: Dead bot speech — no targeted UI check removes its discussion line — `lib/ui/screens/match_controller.dart:350`.
GAP M5-38: Standings — no bot-role reveal golden test at the result boundary — `lib/transport/local_transport.dart:158`.
GAP M5-43: Concurrent claims — SQL simulation cannot prove a real server race — `supabase/migrations/20261009002100_bot_match_sessions.sql:26`.
GAP M5-47: Winner gate — no test checks both human win and loss against claims — `lib/ui/screens/match_controller.dart:329`.
GAP M5-48: Rematch reward — no full second-match claim test — `lib/ui/screens/match_flow.dart:1115`.
GAP M5-49: Initial deal ad — policy test does not exercise the bot entry route — `lib/app/router.dart:274`.
GAP M5-52: RL22 split — sheet test checks count, not exact 5–12 role composition — `lib/engine/presets.dart:143`.
GAP M5-56: Rule parity — no paired bot/offline-online outcome assertion — `lib/engine/legal_moves.dart:267`.
