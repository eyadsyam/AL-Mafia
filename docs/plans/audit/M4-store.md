# M4 — Store and economy audit

Original static inspection: 2026-10-17. Subsequent local test evidence is recorded in the matrix and the verification note below. An OK verdict is limited to its stated evidence level, not live or device certification. Later migrations override earlier SQL function definitions. Store v4 leaves three sold roles, three ordinary frames and three narrator packs active; tool charges are a separate catalog. The seal and invite frames are grants, not coin-store listings. Refs to §12 mean the rulings in `docs/specs/17-roles-and-tools.md`.

## Silencer role (`role_silencer`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-1 | Buy once; host may enable; 5+ seats and at least two Mafia | §2.5; §4.2; RL12; `roleSilencerDescription` | `supabase/migrations/20261007000700_role_unlocks_store_v4.sql:12`; `supabase/functions/_shared/purchase_access.ts:21`; `lib/ui/screens/setup/optional_roles.dart:10` | `test/widget/store_roles_everywhere_test.dart:94` owned roles switched on reach MatchSettings | widget | OK |
| M4-2 | Unowned or refunded host flag is refused at room create, update and start | §2.5; R5 | `supabase/functions/create_room/index.ts:23`; `supabase/functions/room_settings/index.ts:56`; `supabase/functions/start_match/index.ts:74` | supabase/tests/store_gaps_edge.test.mjs: unowned/refunded host flag at create, update and start | edge-local | OK |
| M4-3 | Silence tomorrow; inherits kill after Mafia leave; dead target does not get a false silence announcement | §4.2; RL7–RL8; `roleSilencerDescription` | `lib/engine/resolver.dart:181`; `supabase/functions/submit_night_action/index.ts:75` | supabase/tests/store_gaps_edge.test.mjs: Silencer silence, dead target and fallback kill | edge-local | OK |
| M4-4 | Refund during offline restart — cached role survives until a wallet answer and can still be offered offline | R5; §2.5; I3 | `lib/ui/economy/my_cosmetics.dart:117`; `lib/ui/economy/my_cosmetics.dart:149`; `lib/ui/screens/setup/roles_screen.dart:158` | not found | none | ACCEPTED — offline keeps a returned role until the next online refresh; offline cannot ask the server |

## Elder role (`role_elder`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-5 | Buy, gate at 6+ seats, reveal by day and triple ballot | §4.5; RL12; `roleElderDescription` | `supabase/migrations/20261007000700_role_unlocks_store_v4.sql:13`; `lib/engine/match_engine.dart:119`; `supabase/migrations/20261007000500_roles.sql:90` | supabase/tests/store_gaps.sql: sold-role purchase and Elder reveal | sql-sim | OK |
| M4-6 | Wrong phase, dead or repeated reveal refused without charge; no role hint before voluntary reveal | §4.5; doc 05 | `supabase/migrations/20261007000500_roles.sql:102`; `lib/engine/match_engine.dart:1172` | supabase/tests/store_gaps.sql: Elder reveal once, living and by day | sql-sim | OK |
| M4-7 | Refunded Elder fails new online start; offline cached entitlement can persist through restart — server revocation cannot enforce local play | R5; §2.5 | `supabase/functions/start_match/index.ts:74`; `lib/ui/economy/my_cosmetics.dart:149` | not found | none | ACCEPTED — offline keeps a returned role until the next online refresh; offline cannot ask the server |

## Sniper role (`role_sniper`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-8 | Buy, gate at 7+ seats; one shot, Mafia target dies or a miss kills both | §4.6; RL12; `roleSniperDescription` | `supabase/migrations/20261007000700_role_unlocks_store_v4.sql:14`; `lib/engine/match_engine.dart:123`; `lib/engine/resolver.dart:164` | supabase/tests/store_gaps_edge.test.mjs: Sniper hit or miss | edge-local | OK |
| M4-9 | Dead, wrong phase, second shot, 4/20-seat limits and match ending during shot | §4.6; §2.1; I2/I4 | `supabase/functions/submit_night_action/index.ts:145`; `lib/engine/match_engine.dart:123` | supabase/tests/store_gaps_edge.test.mjs: Sniper phase, life, repeat and seat limits | edge-local | OK |
| M4-10 | Refunded Sniper is refused online at start; offline persisted ownership can still enable it without a wallet refresh | R5; §2.5 | `supabase/functions/start_match/index.ts:74`; `lib/ui/economy/my_cosmetics.dart:149` | not found | none | ACCEPTED — offline keeps a returned role until the next online refresh; offline cannot ask the server |

## Gilded frame (`frame_gilded`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-11 | Card promises a visible gold frame; equip requires ownership and public seats display the chosen frame, never on a private handoff | `cosmeticFrameGildedDesc`; doc 05 §3 | `lib/ui/economy/cosmetics.dart:177`; `supabase/migrations/20261015000100_all_access_grants.sql:132`; `supabase/migrations/20260924000300_cosmetic_catalog.sql:189` | `test/widget/store_truth_test.dart:130` identity badge; `test/online/cosmetics_table_test.dart:62` no night colour | widget | OK |

## Crimson frame (`frame_crimson`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-12 | Card's crimson frame appears in offline public table and online public seat; stranger can see a cosmetic, without a role hint | `cosmeticFrameCrimsonDesc`; doc 05 §3 | `lib/ui/economy/cosmetics.dart:184`; `lib/ui/economy/pass_table_dress.dart:111`; `supabase/migrations/20260924000300_cosmetic_catalog.sql:189` | `test/widget/store_truth_test.dart:247` public phases; `test/online/cosmetics_table_test.dart:44` frames and plates | widget | OK |

## Moonlit frame (`frame_moonlit`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-13 | Card's moonlit frame is owned and equipped before use; public identity only | `cosmeticFrameMoonlitDesc`; doc 05 §3 | `lib/ui/economy/cosmetics.dart:191`; `supabase/migrations/20260924000300_cosmetic_catalog.sql:27`; `supabase/migrations/20261015000100_all_access_grants.sql:132` | `test/widget/store_truth_test.dart:130` identity badge | widget | OK |

## Storyteller narrator (`narrator_storyteller`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-14 | Recorded narrator for every public beat; text remains when muted; no private facts | `cosmeticNarratorStorytellerDesc`; doc 05 §3 | `lib/ui/economy/cosmetics.dart:257`; `lib/ui/screens/online/table/room_presentation.dart:174`; `lib/ui/screens/online/online_table_flow.dart:664` | test/online/narrator_packs_beats_test.dart: narrator_storyteller (4/20 seats): public beats show safe text and request its clips; actual playback not verified | widget | OK |
| M4-15 | Offline host can wear pack; online host must own before room setting, and all clients use room choice | `cosmeticNarratorStorytellerDesc`; §2.5 | `lib/ui/economy/pass_table_dress.dart:139`; `supabase/functions/room_settings/index.ts:59`; `lib/ui/screens/online/online_table_flow.dart:386` | `test/widget/store_truth_test.dart:395` offline beat; `test/online/cosmetics_table_test.dart:233` online text | widget | OK |

## Keeper narrator (`narrator_keeper`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-16 | Recorded Keeper voice and matching text at every public beat, same for every client | `cosmeticNarratorKeeperDesc`; doc 05 §3 | `lib/ui/economy/cosmetics.dart:264`; `lib/platform/narrator_bank.dart:29`; `lib/ui/screens/online/online_table_flow.dart:664` | test/online/narrator_packs_beats_test.dart: narrator_keeper (4/20 seats): public beats show safe text and request its clips; actual playback and multi-client consistency not verified | widget | GAP |

## Noir narrator (`narrator_noir`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-17 | Recorded Noir voice and matching text at every public beat, including free/by-turns and 4/20 seats where offered | `cosmeticNarratorNoirDesc`; doc 05 §3 | `lib/ui/economy/cosmetics.dart:271`; `lib/platform/narrator_bank.dart:30`; `lib/ui/screens/online/table/room_presentation.dart:174` | test/online/narrator_packs_beats_test.dart: narrator_noir (4/20 seats): public beats show safe text and request its clips; actual playback not verified | widget | OK |

## Tool pack: `extra_minute`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-18 | 1/3/7 charges buy 45 seconds on next floor; free talk refuses without spending | §5.1; RL14; `toolExtraMinuteDesc` | `supabase/migrations/20261007000200_table_tools.sql:25`; `supabase/functions/_shared/tools.ts:128`; `supabase/migrations/20261017000100_tool_guards.sql:36` | `supabase/tests/floor_tools_free_room.sql` free-room refusal | sql-sim | OK |

## Tool pack: `anon_note`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-19 | Public short anonymous message; no role hint; wrong phase, empty/long note rejected before charge | §5.1; `toolAnonNoteDesc`; doc 05 | `supabase/migrations/20261007000200_table_tools.sql:26`; `supabase/migrations/20261017000100_tool_guards.sql:80` | supabase/tests/store_gaps.sql: anon_note public and no-charge refusals | sql-sim | OK |

## Tool pack: `last_will`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-20 | Message read at once after exit; rejected at night without spending | §5.1; RL14; `toolLastWillDesc` | `supabase/migrations/20261017000100_tool_guards.sql:70`; `supabase/migrations/20261017000100_tool_guards.sql:125` | supabase/tests/store_gaps.sql: last_will after exit and night refusal | sql-sim | OK |

## Tool pack: `spotlight`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-21 | Chosen live player speaks next by turns; public callout in free talk | §5.1; RL15; `toolSpotlightDesc` | `supabase/migrations/20261017000100_tool_guards.sql:62`; `supabase/functions/_shared/tools.ts:104` | `supabase/tests/floor_priority.sql` spotlight priority | sql-sim | OK |

## Tool pack: `objection`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-22 | 30 seconds on next floor; refused in free talk | §5.1; RL14; `toolObjectionDesc` | `supabase/functions/_shared/tools.ts:128`; `supabase/migrations/20261017000100_tool_guards.sql:36` | `supabase/tests/floor_tools_free_room.sql` free-room refusal | sql-sim | OK |

## Tool pack: `last_word`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-23 | If voted out, table is told chosen player starts next structured day | §5.1; RL15; `toolLastWordDesc` | `supabase/functions/_shared/tools.ts:139`; `supabase/functions/resolve_vote/index.ts:244` | supabase/tests/store_gaps.test.mjs: last word for voted-out seat | unit | OK |

## Tool pack: `vote_shield`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-24 | Next-night silence blocked; shield cannot guarantee a ballot if owner dies or is kicked — card says “your vote tomorrow is protected” | §5.1; RL14; `toolVoteShieldDesc`; I3/I7 | `supabase/functions/_shared/tools.ts:81`; `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:16` | not found | none | ACCEPTED — the vote shield is cover bought in advance, like the M1 conditional tools |

## Tool pack: `half_door`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-25 | Next night blocks silence/investigation, allows kill; combined lock-door precedence | §5.1; `toolHalfDoorDesc` | `supabase/functions/_shared/tools.ts:57` | supabase/tests/store_gaps.test.mjs: half door blocks silence/investigation, not kill | unit | OK |

## Tool pack: `double_vote`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-26 | Today's valid ballot counts twice and is visible; silenced/dead owner cannot buy a useless ballot | §5.1; `toolDoubleVoteDesc`; RL8 | `supabase/functions/_shared/tools.ts:92`; `supabase/migrations/20261017000100_tool_guards.sql:58` | supabase/tests/store_gaps.sql: double_vote silenced/dead refusal; supabase/tests/store_gaps.test.mjs: corresponding role/tool interaction | sql-sim + unit | OK |

## Tool pack: `camouflage`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-27 | Next investigation returns unclear; impersonate takes precedence; no role hint in public use | §5.1; `toolCamouflageDesc`; doc 05 | `supabase/functions/_shared/tools.ts:74` | supabase/tests/store_gaps.sql: camouflage secret on public line; supabase/tests/store_gaps.test.mjs: corresponding role/tool interaction | sql-sim + unit | OK |

## Tool pack: `revote`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-28 | Second ballot for tied or voted seats; never a third | §5.1; RL13; `toolRevoteDesc` | `supabase/functions/resolve_vote/index.ts:145`; `supabase/migrations/20261017000100_tool_guards.sql:54` | supabase/tests/store_gaps.sql: revote opening ballot only; supabase/tests/store_gaps.test.mjs: corresponding role/tool interaction | sql-sim + unit | OK |

## Tool pack: `grave_vote`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-29 | Dead owner gets first next ballot once; no purchase when no future ballot exists | §5.1; RL14; `toolGraveVoteDesc` | `supabase/functions/_shared/tools.ts:101`; `supabase/migrations/20261017000100_tool_guards.sql:42` | supabase/tests/store_gaps.sql: grave_vote dead seat and future ballot; supabase/tests/store_gaps.test.mjs: corresponding role/tool interaction | sql-sim + unit | OK |

## Tool pack: `sense`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-30 | Three distinct legal targets; private true answer, never leak target list to table | §5.1; `toolSenseDesc`; doc 05 | `supabase/migrations/20261017000100_tool_guards.sql:110`; `supabase/migrations/20261017000100_tool_guards.sql:125` | supabase/tests/store_gaps.sql: sense distinct legal targets | sql-sim | OK |

## Tool pack: `impersonate`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-31 | Chosen citizen/Mafia face on next investigation; invalid face refuses, private | §5.1; `toolImpersonateDesc`; doc 05 | `supabase/functions/_shared/tools.ts:64`; `supabase/migrations/20261017000100_tool_guards.sql:84` | supabase/tests/store_gaps.sql: impersonate two faces, private; supabase/tests/store_gaps.test.mjs: corresponding role/tool interaction | sql-sim + unit | OK |

## Tool pack: `narrator_whisper`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-32 | Two distinct legal targets; private true Mafia-presence answer, no public target list | §5.1; `toolNarratorWhisperDesc`; doc 05 | `supabase/migrations/20261017000100_tool_guards.sql:110`; `supabase/migrations/20261017000100_tool_guards.sql:125` | supabase/tests/store_gaps.sql: narrator_whisper distinct legal targets | sql-sim | OK |

## Tool pack: `lock_door`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-33 | Next night blocks kill, silence, sniper shot and investigation; no replay after reconnect | §5.1; `toolLockDoorDesc` | `supabase/functions/_shared/tools.ts:52` | supabase/tests/store_gaps.test.mjs: lock cancels night actions | unit | OK |

## Tool pack: `appeal`

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-34 | Elimination stands only above two thirds; weighted double vote, tie/revote interaction | §5.1; RL14; `toolAppealDesc` | `supabase/functions/_shared/tools.ts:181`; `supabase/functions/resolve_vote/index.ts:167` | supabase/tests/store_gaps.test.mjs: appeal above two thirds of weighted ballots | unit | OK |

## Tool pack purchase and use lifecycle

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-35 | Every active tool offers 1/3/7 charges with server prices; offline never offers tools | §5.0; RL20; `storeToolHint` | `supabase/migrations/20261007000200_table_tools.sql:24`; `supabase/functions/_shared/economy_actions.ts:305`; `lib/ui/screens/setup/store_shop.dart:197` | `test/widget/store_shop_test.dart:159` bought by pack | widget | OK |
| M4-36 | Concurrent pack buys, no negative balance; same request ID grants once — needs-live (concurrency) | §5.0; I3/I9 | `supabase/migrations/20261015000100_all_access_grants.sql:202`; `supabase/migrations/20261015000100_all_access_grants.sql:206`; `supabase/migrations/20261015000100_all_access_grants.sql:213` | supabase/tests/store_gaps.sql: serial pack request ID grants once | sql-sim | GAP |
| M4-37 | Invalid pack, inactive tool or insufficient balance leaves no charge/ledger | §5.0; I2/I3 | `supabase/migrations/20261015000100_all_access_grants.sql:201`; `supabase/migrations/20261015000100_all_access_grants.sql:203`; `supabase/migrations/20261015000100_all_access_grants.sql:217` | supabase/tests/store_gaps.sql: invalid pack/tool/balance refuses charge | sql-sim | OK |
| M4-38 | Used charge never refunded; unused charges from later pack are revoked once; two overlapping packs need correct attribution — revoker subtracts aggregate charges from each ledger row without purchase-level allocation | R5; §5.0; I3/I9 | `supabase/migrations/20261009001500_refund_revokes_items.sql:40`; `supabase/migrations/20261009001500_refund_revokes_items.sql:50` | `supabase/tests/refund_revokes_items.sql:34` one single-charge pack | sql-sim | ACCEPTED (rare) — two overlapping tool packs with one returned |
| M4-39 | Wrong phase/role, dead/kicked/disconnected, silenced, target gone, duplicate use, race with timer or ending match must refuse without trace — needs-live (concurrency) | §5.0; I2/I3/I9 | `supabase/migrations/20261017000100_tool_guards.sql:9`; `supabase/migrations/20261017000100_tool_guards.sql:110` | supabase/tests/store_gaps.sql: serial tool refusals; real race needs live | sql-sim | GAP |
| M4-40 | Spent effect survives reconnect; seat effect remains after disconnect/kick unless acting is required | §5.0 | `supabase/migrations/20261007000200_table_tools.sql:54`; `supabase/functions/_shared/tools.ts:10` | supabase/tests/store_gaps.sql: bought tool survives disconnect/kick | sql-sim | OK |

## Coins: match earnings and voids

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-41 | Eligible finished match earns 25 completion, 10 win, 25 first-day; five participating humans, three minutes, caps; no reward for a 4-player table | §2.1; R5; I8 | `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:94`; `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:119`; `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:134` | `supabase/tests/economy_v3.sql` receipt/cap cases | sql-sim | OK |
| M4-42 | Kick or strike that decides match voids rewards, even if disconnect preceded removal | RL16; R5; I8 | `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:17`; `supabase/migrations/20261016000500_strike_voids_rewards.sql:45` | `supabase/tests/strike_voids_rewards.sql` strike void; `supabase/tests/economy_hardening_receipts.sql:57` kick void | sql-sim | OK |
| M4-43 | Same match receipt/credit once across refresh and retry; simultaneous real-server settlement — needs-live (concurrency) | §2.5; I8/I9 | `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:87`; `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:90` | supabase/tests/store_gaps.sql: serial receipt settlement; live concurrency pending | sql-sim | GAP |

## Coins: ads

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-44 | Optional rewarded ad: claim, verified completion, one credit; late server confirmation survives app reopen | I7/I9; existing ad cadence unchanged | `lib/ui/economy/ad_reward_flow.dart:114`; `lib/ui/economy/ad_reward_flow.dart:222`; `supabase/migrations/20260925000100_update101_economy.sql:265` | supabase/tests/store_gaps.sql: late rewarded-ad confirmation | sql-sim | OK |
| M4-45 | Failed/closed ad or repeat callback gives no invented reward, no duplicate ledger credit | I7/I9 | `supabase/migrations/20260925000100_update101_economy.sql:273`; `supabase/migrations/20260925000100_update101_economy.sql:285` | supabase/tests/store_gaps.sql: repeat or failed ad callback no credit | sql-sim | OK |

## Coins: spending, receipts, debt and refunds

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-46 | Catalog purchase serializes two taps, owns once and keeps balance nonnegative — needs-live (concurrency) | §2.5; I3/I9 | `supabase/migrations/20261015000100_all_access_grants.sql:99`; `supabase/migrations/20261015000100_all_access_grants.sql:103`; `supabase/migrations/20261015000100_all_access_grants.sql:108` | supabase/tests/store_gaps.sql: serial catalog taps own once | sql-sim | GAP |
| M4-47 | Insufficient funds and inactive item leave no spend; successful charge has catalog ledger entry | §2.5; I3 | `supabase/migrations/20261015000100_all_access_grants.sql:101`; `supabase/migrations/20261015000100_all_access_grants.sql:111`; `supabase/migrations/20261015000100_all_access_grants.sql:113` | `supabase/tests/coin_economy.sql` purchase checks | sql-sim | OK |
| M4-48 | Purchased-coins debt offsets future grants; purchase and reversal receipts are idempotent | R5; I3/I9 | `supabase/migrations/20261009001500_refund_revokes_items.sql:63`; `supabase/migrations/20261009001500_refund_revokes_items.sql:69`; `supabase/migrations/20261009001500_refund_revokes_items.sql:80` | supabase/tests/store_gaps.sql: coin debt and receipt idempotency | sql-sim | OK |
| M4-49 | Refund a direct cosmetic/role purchase: remove inventory and equipped slot, but cover only later eligible spend | R5; I3 | `supabase/migrations/20261009001500_refund_revokes_items.sql:27`; `supabase/migrations/20261009001500_refund_revokes_items.sql:37`; `supabase/migrations/20260924000300_cosmetic_catalog.sql:77` | supabase/tests/store_gaps.sql: refund revokes eligible direct spend | sql-sim | OK |
| M4-50 | Refunded earlier retired bundle — revoker deletes bundle row only; component grants remain owned and usable | R5; I3 | `supabase/migrations/20260924000300_cosmetic_catalog.sql:144`; `supabase/migrations/20261009001500_refund_revokes_items.sql:37` | `supabase/tests/bundle_revoke_components.sql` | sql-sim | OK |
| M4-51 | Already configured room pack after owner refund — start checks roles but does not recheck presentation/narrator ownership; revoked pack can still play in later match | R5; I3 | `supabase/functions/_shared/purchase_access.ts:15`; `supabase/functions/start_match/index.ts:69`; `supabase/functions/start_match/index.ts:74` | not found | none | ACCEPTED — cosmetics never block a match; a pack already on a room survives its owner's return (purchase_access.ts comment) |

## Retired nameplates (`plate_noir`, `plate_gilded`, `plate_ember`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-52 | v4 stops sale but existing owners retain use, offline and online public identity only | Store v4; `cosmeticPlate*Desc`; doc 05 | `supabase/migrations/20261007000700_role_unlocks_store_v4.sql:18`; `supabase/migrations/20261015000100_all_access_grants.sql:132`; `lib/ui/economy/cosmetics.dart:214` | `supabase/tests/cosmetic_catalog.sql:12` inactive; `test/widget/store_economy_fixes_test.dart:183` owned retired shelf | widget | OK |

## Retired room packs (`pack_midnight_manor`, `pack_old_town`, `pack_moonlit_archive`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-53 | v4 stops sale; owner can still equip/use room scene, transition and caption in offline and online public phases | Store v4; `cosmeticPack*Desc`; doc 05 | `supabase/migrations/20261007000700_role_unlocks_store_v4.sql:18`; `lib/ui/economy/cosmetics.dart:365`; `supabase/functions/_shared/purchase_access.ts:46` | `test/widget/store_truth_test.dart:247` public backdrop; `test/online/cosmetics_table_test.dart:189` opening line | widget | OK |

## Retired bundles (`bundle_council`, `bundle_identity`, `bundle_nocturne`)

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-54 | v4 stops sale but bought components remain usable; catalog snapshot hides inactive bundle while owned shelf retains it | Store v4; `cosmeticBundle*Desc` | `supabase/migrations/20261007000700_role_unlocks_store_v4.sql:18`; `supabase/migrations/20261015000100_all_access_grants.sql:156`; `lib/ui/screens/setup/store_shop.dart:243` | `test/widget/store_economy_fixes_test.dart:183` owned retired shelf | widget | OK |

## Other retired or grant-only items

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M4-55 | Mastermind guide is free in Help, unavailable for new sale, previous buyer gets one catalog refund | Store catalog retirement; I3 | `supabase/migrations/20260924000300_cosmetic_catalog.sql:45`; `supabase/migrations/20260924000300_cosmetic_catalog.sql:51` | `supabase/tests/cosmetic_catalog.sql:83` once; `test/widget/coin_store_test.dart:375` Help | sql-sim | OK |
| M4-56 | Starter seal and invite frame are grant-only; neither appears for coin sale; granted owner can equip | `cosmeticFrameSealDesc`; `cosmeticFrameInviteDesc`; I3 | `supabase/migrations/20260925000300_council_life.sql:764`; `supabase/migrations/20260930000400_referral_first_match_reward.sql:7`; `supabase/migrations/20261015000100_all_access_grants.sql:132` | supabase/tests/store_gaps.sql: seal/invite grant only and equip | sql-sim | OK |

## Findings (original audit; consult current matrix and verification note)

SUSPECT M4-50 [I3]: Retired bundles — refund removes bundle marker but leaves its component entitlements — `supabase/migrations/20261009001500_refund_revokes_items.sql:37`.
SUSPECT M4-51 [I3]: Room packs/narrators — refunded host's already configured room can start another match with revoked pack — `supabase/functions/_shared/purchase_access.ts:15`.
SUSPECT M4-38 [I3/I9]: Tool packs — refund revokes aggregate unused charges per ledger row without purchase-level attribution across overlapping packs — `supabase/migrations/20261009001500_refund_revokes_items.sql:50`.
SUSPECT M4-4 [I3/I5]: Silencer — offline cached entitlement remains usable after refund until server refresh — `lib/ui/economy/my_cosmetics.dart:149`.
SUSPECT M4-7 [I3/I5]: Elder — offline cached entitlement remains usable after refund until server refresh — `lib/ui/economy/my_cosmetics.dart:149`.
SUSPECT M4-10 [I3/I5]: Sniper — offline cached entitlement remains usable after refund until server refresh — `lib/ui/economy/my_cosmetics.dart:149`.
SUSPECT M4-24 [I3/I7]: Vote shield — card promises tomorrow's vote is protected although death or kick can prevent that ballot — `supabase/functions/_shared/tools.ts:81`.
GAP M4-2: Silencer — no server test of unowned/refunded create, update and start gates.
GAP M4-3: Silencer — no located end-to-end test tying the paid card promise to both transports.
GAP M4-5: Elder — setup test does not prove reveal and triple ballot in both modes.
GAP M4-6: Elder — no located refusal and visibility test for reveal boundaries.
GAP M4-8: Sniper — no located cross-transport paid-card shot test.
GAP M4-9: Sniper — no located lifecycle test across death, timers and match end.
GAP M4-14: Storyteller — text/mute test does not prove recorded speech at every public beat.
GAP M4-16: Keeper — no located recorded-voice playback test.
GAP M4-17: Noir — no located recorded-voice and full-beat test.
GAP M4-19: Anonymous note — generic refusal test does not prove message delivery and anonymity.
GAP M4-20: Last will — no located immediate-delivery test after elimination.
GAP M4-23: Last word — priority test does not prove voted-out announcement through next day.
GAP M4-25: Half door — no located live pair test with lock door.
GAP M4-26: Double vote — no located full ballot test for silenced/dead owner.
GAP M4-27: Camouflage — no located paired investigation test with impersonate.
GAP M4-28: Revote — no located full tied-ballot and second-round test for this purchase.
GAP M4-29: Grave vote — no located last-ballot/end-of-match test.
GAP M4-30: Sense — target guard test does not prove private truthful answer.
GAP M4-31: Impersonate — no located investigation and secrecy test.
GAP M4-32: Narrator whisper — target guard test does not prove private truthful answer.
GAP M4-33: Lock door — no located full night interaction/reconnect test.
GAP M4-34: Appeal — no located weighted/tied/revote full interaction test.
GAP M4-36: Tool packs — request-id widget test cannot prove two real concurrent purchases.
GAP M4-37: Tool packs — client refusal test cannot prove ledger and balance atomicity at server.
GAP M4-39: Tool use — SQL simulation cannot prove two-client races with timer or match end.
GAP M4-40: Tool use — live test exists but was not run here; persistence/reconnect remains unverified.
GAP M4-43: Match rewards — one-connection harness cannot prove real concurrent settlement.
GAP M4-44: Ads — widget recovery test cannot prove real verified-ad credit.
GAP M4-45: Ads — local SQL test cannot prove real callback duplication behavior.
GAP M4-46: Catalog — double-tap widget test cannot prove real concurrent balance serialization.
GAP M4-48: Debt/receipts — local SQL does not prove concurrent grant/reversal ordering.
GAP M4-49: Refund — direct-item test does not prove every equipped role/cosmetic revocation path.
GAP M4-56: Grant-only frames — no located grant-through-equip test for either frame.

## تحقق محلي — ٢٠٢٦-١٠-١٨

- اختبارات الراوي والحزم المرتبطة: ٣٦ ناجح، منها ٦ حالات للحزم التلاتة عند ٤ و٢٠ لاعب؛ أوضاع الكلام الحر وبالدور، المراحل العامة، وظهور النص مع الكتم ومن غيره.
- الاختبار بيلاحظ طلب التسجيل من مدير الصوت وبيتأكد إن الملف موجود؛ مش بيشغّل صوت مسموع على جهاز. نص نتيجة التصويت متجرب من مسار العرض المحلي، واختيار تسجيلها من مسار الأونلاين. سلامة النص هنا تخص جملة الراوي، مش كل محتوى الشاشة.
- الحالة `M4-16` فضلت `GAP`: التطابق بين عملاء حقيقيين لسه مش متحقق. `M4-14` و`M4-17` ناجحين في حدود اختبار الواجهة واختيار التسجيل بس؛ تجربة التشغيل الفعلي لسه مطلوبة.
- الحالات `M4-36/39/43/46` لسه محتاجة اختبار تزامن حقيقي. نتائج المحاكاة المحلية متثبتش ترتيب العمليات المتزامنة على السيرفر.
- اختبارات المتجر المحفوظة في `601f2ba` سبق تشغيلها: ملف قاعدة البيانات ناجح، ٢٢ اختبار مساعد و٤ اختبارات دوال محلية ناجحين؛ النتائج دي من المرحلة السابقة وماتعادتش هنا.
