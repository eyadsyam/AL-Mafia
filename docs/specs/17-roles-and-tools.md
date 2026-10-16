# 17 — Roles and Tools: the rule book, as the code plays it

> **Status: DRAFT from code, 2026-10-16; to be reviewed by Claude and ruled on by the owner.**
> Nothing here is a design decision. Every rule is read from the code as it is today, with `file:line`.
> Where the code could not be found or is ambiguous the text says **NOT FOUND**, **NOT VERIFIED** or goes to section 11.
> Nothing was run: no tests, no build. All claims are from reading source.

**Path shorthand used for evidence**

| Short | Means |
|---|---|
| `eng/` | `lib/engine/` (pure Dart, offline engine) |
| `fn/` | `supabase/functions/` (TypeScript edge functions, online) |
| `mig/` | `supabase/migrations/` (SQL, online) |
| `ui/` | `lib/ui/screens/` |
| `ARB:n` | `lib/app/l10n/app_ar.arb`, line `n` |
| **Dart** | the offline engine (pass-and-play and bots) |
| **TS/SQL** | the online server (edge functions + migrations) |

**The two implementations.** The rules run twice. Offline (pass-and-play, and "play against the computer") runs one match on one phone through `eng/match_engine.dart`, `eng/resolver.dart`, `eng/win_check.dart`, `eng/legal_moves.dart`. Online, the server (`fn/resolve_night`, `fn/resolve_vote`, `fn/submit_*`, `fn/_shared/*`, and the SQL in `mig/`) is the only authority and the client only renders. Both are supposed to be the same game (CLAUDE.md non-negotiable 2), but they are separate code. Where they disagree is section 9. The table tools (section 5) exist **online only**: no call to them exists in the offline code (`lib/` has no `use_table_tool` caller; the only server entry is `fn/_shared/economy_actions.ts:319`). Owner ruling R6 (store items should work in every mode) is recorded here as a fact about the present state, with no fix proposed.

**Owner rulings carried in this document**

| # | Ruling | Where checked |
|---|---|---|
| R1 | A silenced player cannot talk or vote the next day, but can still be voted out | 4.2, D9, D10 |
| R2 | The sniper has one bullet per match; the doctor cannot block the sniper's shot | 4.6, C9-C10 |
| R3 | The silencer only kills once the other killers are gone (then it inherits the kill) | 4.2, C31-C32 |
| R4 | Dead players see everything, including whispers (witness view) | 8, D36 |
| R5 | A Play refund revokes the bought item; a match decided by a kick voids rewards | 5.0, D37 |
| R6 | Store items (sold roles, tools) should work in every mode. Tools are online-only today | header, 5.0 |

---

## 2. Setup

### 2.1 Player counts and entry points

| Mode | Players | Evidence |
|---|---|---|
| Offline pass-and-play | 5 to 20 | `eng/match_engine.dart:86-88` (throws outside 5-20); `eng/balance_guard.dart:67-76` |
| Offline vs bots | 5 to 12, default 8; seat 0 is the human, seats 1..N-1 are bots | `ui/setup/bot_match_sheet.dart:30-31,62`; `lib/app/router.dart:287` |
| Online room | lobby cap one of 5, 8, 10, 15; `start_match` needs at least 5 players and does not re-check the cap | `fn/_shared/room_configuration.ts:30`; `fn/start_match/index.ts:56` |

### 2.2 Role composition: what each entry point deals

Three different sources produce the split. They agree only in places (see D13).

| Source | Used by | Rule | Evidence |
|---|---|---|---|
| `MatchPreset.classic` («كلاسيكية»; button «عادي» on the roles screen, `ARB:2640`) | pass-and-play default, bot default | Mafia = `clamp((n+1)~/4, 1, (n-1)~/2)`; 1 detective; 1 doctor; rest citizens | `eng/presets.dart:136-150`; `ui/setup/roles_screen.dart:268` |
| `MatchPreset.brutal` («قاسية»; button «صعب», `ARB:2641`) | offered from 8 players | Mafia = `n~/3` capped `(n-1)~/2`, min 1; 1 detective; **no doctor**; rest citizens | `eng/presets.dart:52,154-163`; `ui/setup/roles_screen.dart:269` |
| `MatchPreset.fast` («سريعة») | bot sheet and settings screen only (not a chip on the roles screen) | same split as classic | `eng/presets.dart:136-150`; `ui/setup/bot_match_sheet.dart:292` |
| «على مزاجك» custom (`ARB:2642`) | roles screen | host edits steppers; Mafia 1..(n/2 exclusive), Detective 0..1, Doctor 0..n, citizens = remainder | `ui/setup/roles_screen.dart:270,290-340` |
| `BalanceGuard.recommended(n)` | **online lobby** `_start` | Mafia 1 (5-6), 2 (7-8), 3 (9+); 1 detective; 1 doctor; rest citizens | `eng/balance_guard.dart:163-186`; `ui/online/lobby_screen.dart:287` |

**Split per player count** (base roles only, before any bought role is swapped in; derived by hand from the formulas above):

| n | Classic/fast: Mafia / Det / Doc / Cit | Brutal: Mafia / Det / Doc / Cit | Online `recommended`: Mafia / Det / Doc / Cit |
|---|---|---|---|
| 5 | 1 / 1 / 1 / 2 | not offered | 1 / 1 / 1 / 2 |
| 6 | 1 / 1 / 1 / 3 | not offered | 1 / 1 / 1 / 3 |
| 7 | 2 / 1 / 1 / 3 | not offered | 2 / 1 / 1 / 3 |
| 8 | 2 / 1 / 1 / 4 | 2 / 1 / 0 / 5 | 2 / 1 / 1 / 4 |
| 9 | 2 / 1 / 1 / 5 | 3 / 1 / 0 / 5 | 3 / 1 / 1 / 4 |
| 10 | 2 / 1 / 1 / 6 | 3 / 1 / 0 / 6 | 3 / 1 / 1 / 5 |
| 11 | 3 / 1 / 1 / 6 | 3 / 1 / 0 / 7 | 3 / 1 / 1 / 6 |
| 12 | 3 / 1 / 1 / 7 | 4 / 1 / 0 / 7 | 3 / 1 / 1 / 7 |
| 13 | 3 / 1 / 1 / 8 | 4 / 1 / 0 / 8 | 3 / 1 / 1 / 8 |
| 14 | 3 / 1 / 1 / 9 | 4 / 1 / 0 / 9 | 3 / 1 / 1 / 9 |
| 15 | 4 / 1 / 1 / 9 | 5 / 1 / 0 / 9 | 3 / 1 / 1 / 10 |
| 16-20 (offline only) | 16: 4/1/1/10 · 17: 4/1/1/11 · 18: 4/1/1/12 · 19: 5/1/1/12 · 20: 5/1/1/13 | 16: 5/1/0/10 · 17: 5/1/0/11 · 18: 6/1/0/11 · 19: 6/1/0/12 · 20: 6/1/0/13 | not reachable (room cap 15) |

The server accepts **any** counts that satisfy its invariants (section 2.4), not just these (`fn/start_match/index.ts:57-98`). The host client in practice sends the `recommended` split (`ui/online/lobby_screen.dart:287-300`).

### 2.3 Preset settings (what each preset changes besides the split)

| Setting | fast | classic | brutal | Evidence |
|---|---|---|---|---|
| speechSeconds / discussionSeconds | 30 / 180 | 45 / 300 | 30 / 120 | `eng/presets.dart:64-96` |
| traceEnabled | on | on | on | same |
| whisperEnabled | on | on | **off** | same |
| bulletsEnabled | **off** | on | on | same |
| midDiscussionConfrontation | off | off | **on** | same |
| revealNightVictimRole | **on** | off | off | same |
| pressureCurveEnabled | off | on | on | same |
| optional roles (silencer, elder, sniper) | forced off by `applyTo`, then switched on per owned role | same | same | `eng/presets.dart:119-121`; `ui/setup/optional_roles.dart:72-77` |

Defaults when no preset is applied: `eng/models/match_settings.dart:209-240` (e.g. `dayTieRule` noElimination, `abstainAllowed` false, `whisperEnabled` false, `openingRoundEnabled` false, `bulletsEnabled`/`quietNightEnabled`/`selfProtectEnabled` true, all three sold roles false, `revealNightVictimRole` false).

Online room settings the server accepts: `maxPlayers`, `speechSeconds` 30/45/60, `discussionSeconds` 180/300/420, `confrontationSeconds` 30/45/60, booleans (`voice`, `muteAllAtNight`, `openVoting`, `traceEnabled`, `confrontationEnabled`, `whisperEnabled`, `abstainAllowed`, `openingRoundEnabled`, `survivorConfrontationEnabled`, `bulletsEnabled`, `quietNightEnabled`, `selfProtectEnabled`, `silencerEnabled`, `elderEnabled`, `sniperEnabled`, `revealWhisperContent`), `discussionMode` structured/free, `dayTieRule` noElimination/revote, `scenarioCode` classic/shadows (`fn/_shared/room_configuration.ts:30-65`). Online has no presets: **NOT FOUND** (no preset code under `fn/`).

### 2.4 Balance guard and server checks

| Rule | Dart | TS/SQL |
|---|---|---|
| Players 5-20 | blocking `player_count_too_low/high` `eng/balance_guard.dart:67-76`; engine throws `eng/match_engine.dart:86-88` | at least 5 only `fn/start_match/index.ts:56` |
| Counts sum to players | blocking `eng/balance_guard.dart:89-94`; engine `eng/match_engine.dart:91-99` | `fn/start_match/index.ts:77-78` |
| At least 1 mafia-side seat; mafia-side below half | blocking `eng/balance_guard.dart:100-107`; engine `eng/match_engine.dart:102-111` | `fn/start_match/index.ts:81-83` |
| Advisory "3 Mafia from 9 players" | non-blocking `recommend_three_mafia` `eng/balance_guard.dart:110-114`; ARB `balanceRecommendThreeMafia` `ARB:81` «الأفضل تختار 3 مافيا لما تكونوا 9 لاعبين أو أكتر» | none |
| One detective at most | blocking `one_detective_only` `eng/balance_guard.dart:118-122` (the engine's own `start` does not check it) | `fn/start_match/index.ts:80` |
| Silencer: unique, needs 2 mafia-side seats, count must equal its switch | guard `eng/balance_guard.dart:125-135`; engine `eng/match_engine.dart:112-118` | `fn/start_match/index.ts:84-88` |
| Elder: at most 1, equals its switch, 6+ players | guard `eng/balance_guard.dart:136-140`; engine `eng/match_engine.dart:119-122` | `fn/start_match/index.ts:89-93` |
| Sniper: at most 1, equals its switch, 7+ players | guard `eng/balance_guard.dart:141-145`; engine `eng/match_engine.dart:123-126` | `fn/start_match/index.ts:94-98` |
| Doctors | no cap in either; several doctors protect **one** seat between them (tie drawn on seed) | no cap |
| Role names accepted | enum | the seven names `fn/start_match/index.ts:59` |

Guard copy (ARB): `balancePlayerCountTooLow` `ARB:75`, `balanceMafiaTooMany` `ARB:80` «عدد المافيا لازم يكون أقل من نص اللاعبين», `balanceOneDetectiveOnly` `ARB:83` «المحقق واحد بس في اللعبة», `balanceSilencerNeedsTwoMafia` `ARB:85`, `balanceElderMinPlayers` `ARB:86` «شيخ الصالحين محتاج ٦ لاعبين على الأقل», `balanceSniperMinPlayers` `ARB:87`. `balanceTwoDetectivesLowPlayerCount` `ARB:82` is still mapped (`lib/ui/l10n_ext.dart:52`) but the guard no longer produces that code (see D40).

### 2.5 How the sold roles are gated

| Mode | Gate | Evidence |
|---|---|---|
| Store items | `role_silencer` 7000 coins, `role_elder` 5000, `role_sniper` 6000, kind `role`, bought once | `mig/20261007000700_role_unlocks_store_v4.sql:15-17` |
| Offline | UI only. `OptionalRole` (silencer min 5, elder 6, sniper 7) offers a toggle; `_next` drops any role the wallet does not own. A silencer takes a **Mafia** seat; elder and sniper each take a **citizen** seat. The engine itself checks the settings switch, never ownership | `ui/setup/optional_roles.dart:9-69`; `ui/setup/roles_screen.dart:132-148`; `eng/match_engine.dart:112-126` |
| Offline lock copy | `roleLockedHint` `ARB:2548` «الدور ده بيتفتح لما تشتريه من المتجر، قسم الأدوات.»; `roleLockedPill` `ARB:2549` «مقفول» | |
| Online | the **host** must own the role for its flag to be on; checked in `start_match` (`ensureRoleAccess`). Players in the room do not need to own it. The role is still dealt at random | `fn/_shared/purchase_access.ts:21-44`; `fn/start_match/index.ts:72-76` |
| Online host lobby math | `silencerEnabled` takes one Mafia, `elderEnabled`/`sniperEnabled` one citizen each, with no check of minimum players | `ui/online/lobby_screen.dart:288-300` (D14) |
| Refund | a refunded or charged-back pack revokes later-bought roles and unused tool charges, newest first (R5) | `mig/20261009001500_refund_revokes_items.sql:21-59` |

### 2.6 How bots are seated and how they play

* Seat 0 is the human, seats 1..N-1 are bots (`lib/app/router.dart:287`). Names come from `kBotNames`. Roles are shuffled by the seed, so the human can be any role (`eng/match_engine.dart:153-159`).
* Bot-match settings: the picked preset on top of the player's saved defaults, with `whisperEnabled:false` and `discussionMode: free` forced (`lib/app/router.dart:280-285`).
* Bot levels easy/normal/hard are a read bias toward the true Mafia of 15/60/140 on a 0-1000 scale (`eng/bots/bot_brain.dart:29-33`).
* A bot reads public acts only plus one private impression of each seat; Mafia bots know their family (`eng/bots/bot_brain.dart:1-9`).
* Bot night logic by role (`eng/bots/bot_brain.dart:174-250`): Mafia arms the quiet night from day 2 when "heat" is on the Mafia; Silencer picks like a Mafia kill target; Doctor may arm self-protection under heat; Sniper fires only when the last T1 trace target and its own read agree. The Detective-arm branch and the Citizen/Elder-arm branch are dead code in practice: the engine offers no armed move to them (`eng/bullets.dart:66-72`, `eng/models/enums.dart:122-127`).
* Bots never use tools (no tool code offline).

### 2.7 How the online deal is made

`start_match` shuffles the deck with xorshift32 seeded by the raw `match_seed` (`fn/start_match/index.ts:15-29,104`), then `apply_match_deal` writes roles by seat order, sets the room to `playing`, phase `reveal` number 1 (`mig/20261009000100_deal_all_roles.sql:164-177`). Dart shuffles with `Random(deriveSeed(seed, roleShuffle, 0))` (`eng/match_engine.dart:153-159`). The TS comment says it "mirrors" Dart (`fn/start_match/index.ts:15`); it does not (D17).

---

## 3. Phase order

### 3.1 Offline (`GamePhase`, `eng/models/enums.dart:26-54`)

```
distributing -> preNightLobby -> night -> nightResolving -> morning
   morning -> [concludeAfterNight -> result]            if a win is already decided
   morning -> beginDay -> openingRound                  day 1 and openingRoundEnabled
                       -> confrontation                 day > 1, confrontationEnabled, generator found one
                       -> discussion                    otherwise
   openingRound / confrontation -> discussion
   discussion -> voting -> voteResolving -> voting      (one revote, DayTieRule.revote only)
                                          -> reveal -> winCheck() -> result
                                                              or dayNumber+1 -> preNightLobby -> night
```

Evidence: `confirmRevealed` `eng/match_engine.dart:239-258`; `beginNight` `:261-300`; night actor loop `:713-724`; `resolveNight` `:727-781`; `beginDay` `:904-928`; opening `:937-981`; confrontation `:988-1051`; `concludeAfterNight` `:1091-1110`; `beginVoting` `:1113-1123`; `submitVote` loop `:1224-1234`; `resolveDayVote` `:1258-1394`; `winCheck` `:1397-1431`. Night N is followed by day N; `dayNumber` increments only in `winCheck` (`:1427`). No offline phase timers (`eng/legal_moves.dart:13-17`).

### 3.2 Online (`fn/_shared/phases.ts`)

```
lobby -> reveal (90 s) -> night (120 s) -> morning (45 s)
   morning -> opening (10 s per seat) | discuss | confront (generate_confrontation) | result
   opening / confront -> discuss (settings.discussionSeconds, default 300)
   discuss -> vote (60 s)         [revote stays in phase "vote", round 2]
   vote -> verdict (20 s) -> night (phase_number + 1) | result
```

Evidence: `TRANSITIONS` `fn/_shared/phases.ts:12-27`; durations `:40-72`; `resolve_night` ends in `morning` (`fn/resolve_night/index.ts:206-213`); `resolve_vote` ends in `verdict` (`fn/resolve_vote/index.ts:208-235`); the day number moves only in `open_phase` verdict->night (`fn/open_phase/index.ts:171-174`); the confrontation door is `generate_confrontation` (`fn/generate_confrontation/index.ts:28,48`). Any expired phase can be advanced by any member (`fn/open_phase/index.ts:63-68`); defaults on expiry in `fn/advance_phase/index.ts`.

### 3.3 Where they differ

| Point | Offline | Online | Evidence |
|---|---|---|---|
| Resolving beats | `nightResolving`, `voteResolving`, `winCheck` are real phases | server commit; no such phase | `eng/models/enums.dart:30,50-51` |
| After the vote | `reveal` (role shown), then `winCheck` | `verdict` for 20 s | `fn/_shared/phases.ts:65-66` |
| Timers | none | every phase has one | `fn/_shared/phases.ts:40-72` |
| Ballot | pass the phone, seat order, secret | simultaneous; `openVoting` can show intentions; closes early when every living, non-silenced player has voted | `eng/match_engine.dart:1224-1233`; `fn/submit_vote/index.ts:120-157` |
| `defense` phase | does not exist | listed in `TRANSITIONS`, tool windows, voice policy, but **no function ever sets it** | `fn/_shared/phases.ts:20`; `fn/_shared/voice.ts:28,62` (D33) |
| Night victim role | optional (`revealNightVictimRole`) | never | `eng/models/match_settings.dart:184`; `ui/night/morning_screen.dart:132-136` |
| Day-1 opening round | `openingRoundEnabled` (default off) | host opens `opening` from `morning`; which setting gates it: NOT VERIFIED | `eng/match_engine.dart:915`; `fn/_shared/phases.ts:17` |

---

## 4. Roles

Seven roles (`eng/models/enums.dart:10`). Arabic names in the app: `roleMafia` «مافيا» `ARB:113`, `roleSilencer` «مافيا التسكيت» `ARB:114`, `roleDoctor` «دكتور» `ARB:115`, `roleDetective` «محقق» `ARB:116`, `roleElder` «شيخ الصالحين» `ARB:117`, `roleSniper` «القناص» `ARB:118`, `roleCitizen` «مواطن» `ARB:119`. Group names on the setup screen: «المافيا», «المحقق», «الدكتور», «المواطن» (`ARB:70-73`).

**Night resolution order (the one order everything below uses).**

| Step | Dart `eng/resolver.dart` | TS `fn/resolve_night/index.ts` |
|---|---|---|
| 0 | only tonight's events count (`:52-54`) | tool rows loaded: locked / half-door / vote-shield seats (`:59-64`) |
| 1 | Mafia vote tally; tie drawn on seed (`:57-91`) | `kill` actions by living actors on living non-mafia-team targets; tie drawn on seed (`:95-115`) |
| 2 | Doctor protect tally; **one** protected seat; tie drawn on seed (`:99-122`) | same (`:121-136`) |
| 3 | - | a locked seat winning step 1 cancels the kill (`:138`) |
| 4 | victim protected -> no death, `savedSeat` set (`:141-145`) | same (`:140-144`) |
| 5 | quiet night spent tonight -> victim cleared (`:156-157`) | **no equivalent** (D1) |
| 6 | sniper shots added, outside protection (`:161-176`) | sniper shots added, skipped if target locked (`:146-156`) |
| 7 | silence = last `SilenceCast` of the night (`:178-181`) | first `silence` action; not on a locked, half-door, shielded or **dying** seat (`:160-163`) |
| 8 | morning report; trace chosen afterwards (`:206-215`; `eng/match_engine.dart:795-830`) | morning payload, trace, win check, one atomic commit (`:185-213`) |

Detective investigation is **not** part of the resolution: the answer is given immediately when the Detective acts (`eng/match_engine.dart:529-534`; `fn/submit_night_action/index.ts:237-253`).

---

### 4.1 Mafia («مافيا»)

| Field | Rule | Evidence |
|---|---|---|
| Team / win | Mafia. Wins at parity (`mafia >= non-mafia`) | `eng/models/enums.dart:14-17`; `eng/win_check.dart:63` |
| Night action | `mafiaVote` / `kill` | `eng/models/enums.dart:75`; `fn/_shared/api.ts:296-297` |
| When | every night, one action per night | |
| Valid targets | living, not self, **not a mafia-side seat** (silencer included). Repeat target allowed | Dart `eng/match_engine.dart:430`, `eng/legal_moves.dart:426-433`; TS `fn/submit_night_action/index.ts:181` and again at tally `fn/resolve_night/index.ts:100`. Dart's engine does not check "alive" or "not self" (only the move list does); TS checks both `:176-179` |
| Group decision | one kill per night: seat with most Mafia votes; tie drawn on the night seed | `eng/resolver.dart:57-91`; `fn/resolve_night/index.ts:103-115` |
| Once per match | «الليلة الهادية» (quiet night): Dart is **the team's** single bullet; TS is **per player** and has no effect on the kill (D1) | `eng/bullets.dart:51-55`; `mig/20260904000100_bullets_online.sql:52-54`; `fn/resolve_night/index.ts:97-102` |
| Offline skip tile | "choose nobody" as Mafia arms the quiet night automatically when the bullet is still unspent | `ui/night/night_action_screen.dart:198` |
| Resolution vs others | Doctor save beats the kill; quiet night beats everything the Mafia chose (Dart); sniper shot, if on the same seat, kills regardless of Doctor; lock-door (TS) cancels the kill with no redirect | `eng/resolver.dart:141-176`; `fn/resolve_night/index.ts:138-156` |
| Timer default (online) | a seeded random living non-mafia-team seat, for any Mafia who did not act | `fn/advance_phase/index.ts:74-88` |

What each seat sees:

| Who | Dart | TS/SQL |
|---|---|---|
| Role card (private) | `roleMafiaDescription` `ARB:120` «كل ليلة بتتفقوا على واحد يتقتل، ومينفعش تختاروا حد منكم». Teammate names shown at the deal only for other `Role.mafia` (silencer not listed) `eng/match_engine.dart:228-233`; later card checks list all mafia-aligned `lib/transport/local_transport.dart:205-211` | `my_team` returns both `mafia` and `silencer` names to both `fn/my_team/index.ts:46-59` |
| Actor, at the action | prompt `nightPromptMafia` `ARB:162` «مين عايز تقتله الليلة؟»; sees teammates' votes `eng/match_engine.dart:329-338`; fellow Mafia tiles drawn but blocked `:347-356`; special tile `nightSpecialMafia` `ARB:909` «مش هقتل الليلة»; bullet label `bulletMafia` `ARB:775` «الليلة الهادية» | same prompts (client); acts through `submit_night_action` |
| Target | nothing at night; dies at resolution | same |
| Public (morning) | death: headline `notEveryoneSurvived` `ARB:169` «فيه لاعبين خرجوا», body `lostPlayerLastNight` `ARB:170` «{name} اتقتل بالليل»; no death: `quietNight` `ARB:178` «محدش مات», plus `someoneSavedBody` `ARB:179` «حد نجا من محاولة قتل» only when `quietNightEnabled` is off `ui/night/morning_screen.dart:75-86`, `eng/resolver.dart:204` | headline names the first victim only (`ui/online/online_table_flow.dart:1572-1578`); `quietNight` when none |
| Dead / witness | offline: no witness view (`lib/transport/local_transport.dart:88` returns null) | `witness_view` returns every non-skip action as seats, including `kill` `fn/witness_view/index.ts:54-60` |

Offline evidence: `eng/match_engine.dart:426-444` (vote), `:600-671` (skip/bullet), `eng/resolver.dart:57-91,156-157`, `eng/bullets.dart:51-55,75-80`. Online evidence: `fn/submit_night_action/index.ts:96-205`, `fn/resolve_night/index.ts:95-115`, `fn/advance_phase/index.ts:74-105`.

**Dart vs TS:** differs. Quiet night (D1), save announcement (D2), teammate list at the deal (D7), tie-break algorithm and ordering (D17), multi-death morning line (D12).

---

### 4.2 Silencer («مافيا التسكيت»)

| Field | Rule | Evidence |
|---|---|---|
| Team / win | Mafia (counts for parity, wins with them, never a kill target for them) | `eng/models/enums.dart:14-17`; `fn/_shared/teams.ts:1-10`; `mig/20261009000300_silencer_is_mafia_team.sql:7-9` |
| Availability | sold role; needs 2 mafia-side seats and a switch; unique; takes a Mafia seat | 2.4, 2.5 |
| Night action | `silence` (kind `silence`); stored `silence` | `eng/models/enums.dart:76`; `fn/submit_night_action/index.ts:102-112` |
| Effect of a silence | the target, for the **next day**: cannot vote (R1), cannot take the floor online in structured mode; **can still be voted out** | Dart `eng/match_engine.dart:1190-1192,1126-1133`, `eng/legal_moves.dart:515-519`; TS `fn/submit_vote/index.ts:34-40`, `mig/20261009000600_atomic_floor_bonus.sql:13`, `fn/claim_floor/index.ts:31-33`. Not excluded as a vote target in either |
| Valid targets | any other living player (a teammate is allowed), **or itself** (special tile «سكّت نفسك بكرة») | Dart `eng/legal_moves.dart:419-444`; TS `fn/submit_night_action/index.ts:177` (self allowed when action is `silence`) |
| Limits | one per night, no per-match limit, no no-repeat rule | |
| R3: inherits the kill | at the moment it acts, if **no living `mafia`** (silencers excluded), `silence` becomes a kill vote, and the target must not be mafia-side | Dart `eng/match_engine.dart:450-480`, `eng/legal_moves.dart:410-413,430-432`; TS `fn/submit_night_action/index.ts:103-112,181` |
| Bullet | none (`Role.silencer.bullet == null`) | `eng/models/enums.dart:122` |
| Resolution vs others | silence is independent of the kill. Doctor cannot undo it. Dart reports the silence even if the target also dies that night (D8); TS drops it | `eng/resolver.dart:178-181`; `fn/resolve_night/index.ts:160-163` |
| Online tool interaction | `vote_shield`, `half_door`, `lock_door` on the target drop the silence silently | `fn/_shared/tools.ts:85-89`; `fn/resolve_night/index.ts:61,160-163` |
| Timer default (online) | `skip` (not a kill) even when it is the only killer | `fn/advance_phase/index.ts:72-91` |

What each seat sees:

| Who | Dart | TS/SQL |
|---|---|---|
| Role card | `roleSilencerDescription` `ARB:121` «كل ليلة بتسكّت لاعب لبكرة. لو مافيا القتل خرجوا كلهم، بتورث القتل من الليلة الجاية»; settings hint `settingSilencerHint` `ARB:931` | same text; teammates: see D7 |
| Actor | prompt `nightPromptSilencer` `ARB:165` «مين عايز تسكته الليلة؟»; special tile `nightSpecialSilencer` `ARB:910` «سكّت نفسك بكرة»; as the lone killer it gets the Mafia grid with fellow Mafia blocked `eng/match_engine.dart:347-356` | same prompts |
| Silenced player | `silencedCannotVote` `ARB:917` «إنت متسكّت النهارده — مينفعش تصوّت»; `SkipSilencedVote` moves their ballot turn `eng/legal_moves.dart:519` | `viewerSilenced` shows `silencedCannotVote` (`lib/transport/game_snapshot.dart:564-567`; `ui/online/online_table_flow.dart:1652,1876-1880`) |
| Public | morning line `silencedAnnouncement` `ARB:919` «{name} متسكّت النهارده» (`ui/night/morning_screen.dart:139-146`); ballot mark `silencedMark` `ARB:2559` «متسكّت» (`ui/day/voting_screen.dart:163-164`) | **NOT FOUND**: no public line or mark online (D9); `morning.silencedSeat` is in the public payload only |
| Dead / witness | offline: none | witness sees the `silence` action as seats `fn/witness_view/index.ts:54-60` |

Offline evidence: `eng/match_engine.dart:446-481,1126-1133,1190,1239-1255`; `eng/legal_moves.dart:407-424,515-519`. Online evidence: `fn/submit_night_action/index.ts:102-112,177`, `fn/resolve_night/index.ts:160-163`, `fn/submit_vote/index.ts:34-40`, `fn/claim_floor/index.ts:31-33`.

**Dart vs TS:** same core rule (R1 vote, R3 inherit). Differs on: dying silenced seat (D8), public announcement (D9), talk enforcement in free discussion (D10), timer default (D16).

---

### 4.3 Doctor («دكتور»)

| Field | Rule | Evidence |
|---|---|---|
| Team / win | Town. Alive count only; role-blind win check | `eng/win_check.dart:63`; role-blind note `:67-70` |
| Night action | `protect` | `eng/models/enums.dart:77` |
| When | every night; Dart UI requires a choice | `eng/legal_moves.dart:416` (no plain skip offered) |
| Valid targets | any other living player, mafia included. **Dart:** not the same seat as the previous night. **TS:** no such rule (D4) | Dart `eng/resolver.dart:231-257`, `eng/match_engine.dart:493-502`; TS none (`fn/submit_night_action/index.ts` has no repeat check) |
| Self-protect | once per match, via the bullet «حماية النفس مرة». The setting `selfProtectEnabled` is never read (D15) | `eng/bullets.dart:32`; `eng/resolver.dart:226-228`; `fn/submit_night_action/index.ts:68,150-153` |
| Several doctors | one protected seat in total: most-chosen; tie drawn on seed | `eng/resolver.dart:99-122`; `fn/resolve_night/index.ts:121-136` |
| What it blocks | **only the Mafia kill**. Not the sniper's shot (R2), not a silence, not a day elimination | `eng/resolver.dart:141-145,161-176`; `fn/resolve_night/index.ts:140-156` |
| Resolution vs others | save recorded as `savedSeat` even if the same seat then dies to the sniper or the quiet night cancels | `eng/resolver.dart:141-157` |
| Skip | Dart engine turns a plain skip into "protect the first legal target" (`eng/match_engine.dart:601-620`); TS refuses a doctor skip (`fn/submit_night_action/index.ts:96-98`) | |
| Timer default (online) | a seeded random living other seat (the file header table says "no protection") | `fn/advance_phase/index.ts:11,74-88` (D16) |

What each seat sees:

| Who | Dart | TS/SQL |
|---|---|---|
| Role card | `roleDoctorDescription` `ARB:122` «كل ليلة بتحمي لاعب، ولو انتوا أكتر من دكتور بتحموا واحد بس. حماية نفسك مرة واحدة في الماتش» | same |
| Actor | prompt `nightPromptDoctor` `ARB:163` «مين عايز تحميه الليلة؟»; special tile `nightSpecialDoctor` `ARB:911` «احمي نفسك حالا»; label `bulletDoctor` `ARB:776` «حماية النفس مرة»; last night's tile disabled (Dart only) | same prompts; no disabled tile |
| Target | nothing | nothing |
| Public | save: `someoneSavedBody` `ARB:179` «حد نجا من محاولة قتل» (only if `quietNightEnabled` off); trace T2 `traceSomeoneSurvived` `ARB:566` «حد اتحمى الليلة دي… ونجا» (only if allowed) | `someoneSavedUnnamed` always true on a save (`fn/resolve_night/index.ts:202`); T2 eligible (`fn/_shared/trace.ts:98-100`) |
| Dead / witness | none | witness sees `protect` with seats |

**Dart vs TS:** differs (D2, D3, D4, D15, D16).

---

### 4.4 Detective («محقق»)

| Field | Rule | Evidence |
|---|---|---|
| Team / win | Town | `eng/models/enums.dart:14-17` |
| Count | exactly one at most, by guard and by server | `eng/balance_guard.dart:118-122`; `fn/start_match/index.ts:80` |
| Night action | `investigate`: learn the target's **exact role** | `eng/match_engine.dart:529-534`; `fn/submit_night_action/index.ts:237-253` |
| Limits | **Dart: one per night**, second throws. **TS: not enforced**; a re-submission overwrites the row and returns a new answer (D6) | `eng/match_engine.dart:522-525`, `eng/legal_moves.dart:393-396`; `fn/submit_night_action/index.ts:196-205,237-253` |
| Valid targets | any other living player (Dart's engine does not check, the move list does; TS checks `:176-179`) | `eng/legal_moves.dart:426-433` |
| Resolution | immediate, before the night resolves. Dying the same night does not cancel the answer | |
| Tools (online) | the answer is replaced by: `unreachable` (half or locked door), `citizen`/`mafia` (impersonate), `unclear` (camouflage), in that priority | `fn/_shared/tools.ts:67-78` |
| Timer default (online) | `skip` | `fn/advance_phase/index.ts:89-91` |

What each seat sees:

| Who | Dart | TS/SQL |
|---|---|---|
| Role card | `roleDetectiveDescription` `ARB:123` «المحقق واحد بس في اللعبة. كل ليلة بتكشف شخصية لاعب واحد» | same |
| Actor | prompt `nightPromptDetective` `ARB:164` «مين عايز تفحصه الليلة؟»; special tile `nightSpecialDetective` `ARB:912` «مش هحقق الليلة»; result shown as the role name, or `investigateUnclear` `ARB:2544` «مش واضح» / `investigateUnreachable` `ARB:2545` «بابه مقفول» (`ui/night/night_action_screen.dart:186-190`) | same screen; value from the server response only |
| Target | nothing | nothing |
| Public | nothing | nothing (the answer is "the one fact never written down", `fn/submit_night_action/index.ts:227-236`) |
| Dead / witness | none | witness sees `investigate` actions as seat to seat; not the answer |

**Dart vs TS:** differs on the per-night limit (D6) and on obscuring tools (online only).

---

### 4.5 Elder («شيخ الصالحين»)

| Field | Rule | Evidence |
|---|---|---|
| Team / win | Town (citizen-aligned) | `eng/models/enums.dart:14-17` |
| Availability | sold role; 6+ players; takes a citizen seat | 2.4, 2.5 |
| Night action | Dart: `suspect` (a private suspicion, same as a citizen). TS: **none**: returns ok, stores nothing | `eng/models/enums.dart:79`; `fn/submit_night_action/index.ts:89-91` |
| Day ability | reveal publicly «اكشف للترابيزة»; from then on the Elder's ballot weighs **3** for the rest of the match | `eng/match_engine.dart:1140-1171`; `mig/20261007000500_roles.sql:90-114`; `fn/resolve_vote/index.ts:107-110` |
| Reveal window | Dart: morning, openingRound, confrontation, discussion, voting, voteResolving, reveal. TS: morning, opening, confront, discuss, vote, verdict. Not at night in either | `eng/match_engine.dart:1141-1152`; `mig/20261007000500_roles.sql:99` |
| Limits | once (idempotent). A silenced Elder can still reveal | `eng/match_engine.dart:1157`; no silence check in either |
| Weight timing | evaluated **at tally**, so a reveal before the tally also lifts a ballot already cast | `eng/match_engine.dart:1273-1274`; `fn/resolve_vote/index.ts:80-83,108-110` |
| Stacking | online `double_vote` multiplies: 3 x 2 = 6 | `fn/resolve_vote/index.ts:108-110` |
| Dies | the reveal stays in the log; a dead Elder casts no ballot (unless `grave_vote`, where the weight still applies) | `fn/resolve_vote/index.ts:118-119` |
| Timer default (online) | `advance_phase` writes a `skip` row for an Elder although the submit path ignores it | `fn/advance_phase/index.ts:71-72,89-91` (D5) |

What each seat sees:

| Who | Dart | TS/SQL |
|---|---|---|
| Role card | `roleElderDescription` `ARB:124` «تكشف كارتك في أي وقت بالنهار، ومن ساعتها صوتك يتحسب بثلاثة»; `settingElderHint` `ARB:933` | same |
| Actor | button `elderRevealAction` `ARB:927` «اكشف للترابيزة», after: `elderRevealedMark` `ARB:928` «شيخ مكشوف · صوته ×٣» (`ui/day/day_card_check.dart:110-114`); night prompt `nightPromptElder` `ARB:166` «مين مش مصدقه الليلة دي؟», tile `nightSpecialElder` `ARB:913` | online night: no move; which waiting screen an Elder gets (the Citizen one is `nightCitizenRest` `ARB:1348`): NOT VERIFIED |
| Public | ballot mark `elderVoteMark` `ARB:2558` «×٣» (`ui/day/voting_screen.dart:162`) | `elderRevealedSeats` in the public payload (`lib/transport/room_codec.dart:316`); where it is drawn: NOT VERIFIED |
| Dead / witness | none | witness sees all roles |

**Dart vs TS:** differs on the night move (D5) and reveal windows (D34). Same weight rule.

---

### 4.6 Sniper («القناص»)

| Field | Rule | Evidence |
|---|---|---|
| Team / win | Town (citizen-aligned) | `eng/models/enums.dart:14-17` |
| Availability | sold role; 7+ players; takes a citizen seat | 2.4, 2.5 |
| Night action | `suspect` normally; with the bullet armed it is a **shot** at the chosen target | `eng/models/enums.dart:79,126`; `fn/submit_night_action/index.ts:161-163` |
| Once per match (R2) | one bullet. Offered whenever `sniperEnabled` is on, **regardless of `bulletsEnabled`** | `eng/bullets.dart:33,66-72`; `fn/submit_night_action/index.ts:69,118-144`; online uniqueness `mig/20260904000100_bullets_online.sql:52-54` |
| Valid targets | any other living player (Dart's engine does not enforce it; TS does) | `eng/legal_moves.dart:426-433`; `fn/submit_night_action/index.ts:167-179` |
| No skip-with-bullet | a shot needs a target | `eng/legal_moves.dart:417-418`; `fn/submit_night_action/index.ts:161-163` |
| Result of the shot | the target dies. If the target is **not mafia-side** the Sniper dies too | `eng/resolver.dart:165-176`; `fn/resolve_night/index.ts:148-156` |
| Resolution vs Doctor (R2) | the Doctor cannot block it; protection is resolved only against the Mafia kill | `eng/resolver.dart:161-164`; `fn/resolve_night/index.ts:140-156` |
| Resolution vs the Sniper being killed the same night | the shot still lands (no check of the shooter's survival beyond "alive at tally start") | `eng/resolver.dart:165-176`; `fn/resolve_night/index.ts:151-153` |
| Online tools | `lock_door` on the target cancels the shot and the Sniper's death with it; bullet is still spent | `fn/resolve_night/index.ts:153` |
| Timer default | `skip` (never fires) | `fn/advance_phase/index.ts:89-91` |

What each seat sees:

| Who | Dart | TS/SQL |
|---|---|---|
| Role card | `roleSniperDescription` `ARB:125` «معاك طلقة واحدة. لو ضربت مافيا يموت، ولو أخطأت تموتوا إنتوا الاتنين»; `settingSniperHint` `ARB:935` | same |
| Actor | prompt `nightPromptSniper` `ARB:167` «مين بيكدب عليك الليلة؟»; tile `nightSpecialSniper` `ARB:914` «مش هضرب الليلة»; label `bulletSniper` `ARB:916` «طلقة القناص» | same |
| Target | dies; nothing earlier | dies; nothing earlier |
| Public | deaths in the morning: offline lists every victim (`ui/night/morning_screen.dart:75-80`); online headline names the first seat only (D12). The shot is **not** announced as a shot | as left |
| Dead / witness | none | witness sees `suspect` as seat to seat; the bullet bit is not exposed |

**Dart vs TS:** same core (R2). Differs on the lock-door (online only) and on how the morning names two victims (D12).

---

### 4.7 Citizen («مواطن»)

| Field | Rule | Evidence |
|---|---|---|
| Team / win | Town | `eng/models/enums.dart:14-17` |
| Night action | Dart: a private suspicion (`suspect`), or "choose nobody" (recorded as skipped). TS: **no night move**: returns ok, stores nothing, the night does not wait for them | `eng/match_engine.dart:549-567,600-671`; `fn/submit_night_action/index.ts:85-91`, `closeNightIfEveryoneActed` `:280-322` |
| Limits / bullet | none, none | `eng/models/enums.dart:127` |
| Why it matters | offline suspicions feed traces T1/T3/T4/T5/T6/T7/T8 and several confrontations; online there are none to read | `fn/_shared/history.ts:114-118` (D5) |
| Timer default (online) | nothing written for a Citizen | `fn/advance_phase/index.ts:70-71` |

What each seat sees:

| Who | Dart | TS/SQL |
|---|---|---|
| Role card | `roleCitizenDescription` `ARB:126` «ملكش ميزة خاصة، سلاحك عينك وكلامك. في الأونلاين بتستنى بالليل» | same |
| Actor | prompt `nightPromptCitizen` `ARB:168` «مين شاكك فيه الليلة دي؟»; tile `nightSpecialCitizen` `ARB:915` «مش شاكك الليلة» | rest screen `nightCitizenRest` `ARB:1348` «انت مواطن», `nightCitizenRestSupport` `ARB:1349` «مفيش عليك حاجة بالليل. استنى لحد ما الباقي يخلصوا، والنهار هيطلع.» |
| Public / dead | nothing / none | nothing / witness |

---

## 5. Table tools («أدوات القعدة»), online only

### 5.0 Rules common to every tool

| Rule | Value | Evidence |
|---|---|---|
| Where | online only. No offline code path (R6) | `fn/_shared/economy_actions.ts:319` is the single entry |
| Purchase | coins; packs of 1, 3, 7; 3-pack = `round(price*2.8/10)*10`, 7-pack = `round(price*6.3/10)*10`. A request id makes a repeat a no-op | `mig/20261007000200_table_tools.sql:76-83`; `mig/20261009000400_table_tools_fixes.sql:136-163` |
| Charges | one charge per use, decremented in the same transaction. **All-access holders do not spend charges** | `mig/20261015000100_all_access_grants.sql:291-295` (inside `use_table_tool`, def. at `:227-325`) |
| Per match | 4 tools in total, 2 heavy; counted from `rooms.started_at` so a rematch resets | `mig/20261015000100_all_access_grants.sql:277-284`; snapshot limits `:193` |
| Per tool | `per_match` 1 or 2 (table below); only one use of the same tool per `phase_number` | `...all_access_grants.sql:284-288` |
| Who | any living member (not kicked) for day/night tools; any dead member for `dead` tools. No role or team restriction | `...all_access_grants.sql:242-259` |
| Targets | distinct, living, not self, exactly `targets` many | `...all_access_grants.sql:261-268` |
| Phase windows | `discuss` tools: `discuss, opening, confront, defense, morning`. `vote` tools: `vote, discuss, defense`. `night` tools: `night` only. `dead` tools: any phase while dead | `...all_access_grants.sql:250-258` |
| Day-bought protections | `lock_door`, `half_door`, `impersonate`, `camouflage` are moved to the `discuss` window and cover the **next** night (N+1) | `mig/20261007000400_table_tools_day_protections.sql:4-5`; `fn/_shared/tools.ts:45-48` |
| Public log | every use writes `toolLog` into the public payload: tool code, seat (null when secret), targets (hidden for secret, `sense`, `narrator_whisper`), note (only `anon_note`, `last_will`) | `...all_access_grants.sql:310-317` |
| Secret | `camouflage`, `impersonate`, `anon_note` | `mig/20261007000200_table_tools.sql:34,38`; `mig/20261009000500_live_tool_atomicity.sql:2` |
| Errors | `NOT_ALIVE`, `ALIVE`, `WRONG_PHASE`, `BAD_TARGETS`, `BAD_NOTE`, `LIMIT_MATCH`, `LIMIT_HEAVY`, `LIMIT_TOOL`, `LIMIT_PHASE`, `NO_CHARGES`, `NOT_PLAYING`, `NOT_A_MEMBER` | same function |
| Kick / disconnect | the charge is already spent and is **not refunded**; the use row stays and its effect (keyed on the seat) still applies unless the effect needs the user to act (a ballot, a floor claim). A kicked user is no longer a member, so they cannot use another tool | see per-tool rows; `fn/_shared/api.ts:248` |
| Refund (R5) | a coin refund takes back the unused part of later tool packs | `mig/20261009001500_refund_revokes_items.sql:36-53` |

Intro copy: `toolsIntro` `ARB:2416` «أدوات بتفرق جوّه الماتش الأونلاين. لحد ٤ أدوات في الماتش، منهم ٢ تقيلة.»; tiers `toolTierLight/Medium/Heavy` `ARB:2417-2419`.

### 5.1 The seventeen tools (the list matches the brief)

All seventeen codes in `mig/20261007000200_table_tools.sql:24-41` are exactly the brief's list. Prices below; the 3-pack and 7-pack columns are computed by me from the pack formula, not read from a table.

| Code | Arabic (ARB) | Tier | 1 / 3 / 7 pack | per match | Window | Targets | Secret |
|---|---|---|---|---|---|---|---|
| `extra_minute` | دقيقة زيادة `ARB:2381` | light | 150 / 420 / 950 | 2 | discuss | 0 | no |
| `anon_note` | ورقة من غير اسم `ARB:2383` | light | 180 / 500 / 1130 | 2 | discuss | 0 | yes |
| `last_will` | وصيّة `ARB:2385` | light | 180 / 500 / 1130 | 1 | dead | 0 | no |
| `spotlight` | كشّاف `ARB:2387` | light | 200 / 560 / 1260 | 2 | discuss | 1 | no |
| `objection` | اعتراض `ARB:2389` | light | 200 / 560 / 1260 | 2 | discuss | 0 | no |
| `last_word` | كلمة أخيرة `ARB:2391` | light | 220 / 620 / 1390 | 1 | vote | 1 | no |
| `vote_shield` | درع الصوت `ARB:2393` | medium | 500 / 1400 / 3150 | 1 | discuss | 0 | no |
| `half_door` | باب موارب `ARB:2395` | medium | 600 / 1680 / 3780 | 1 | discuss (moved) | 0 | no |
| `double_vote` | صوت مضاعف `ARB:2397` | medium | 700 / 1960 / 4410 | 1 | discuss | 0 | no |
| `camouflage` | تمويه `ARB:2399` | medium | 750 / 2100 / 4730 | 1 | discuss (moved) | 0 | yes |
| `revote` | إعادة التصويت `ARB:2401` | medium | 800 / 2240 / 5040 | 1 | vote | 0 | no |
| `grave_vote` | صوت من القبر `ARB:2403` | medium | 850 / 2380 / 5360 | 1 | dead | 0 (was 1; `mig/20261009000400_table_tools_fixes.sql:13`) | no |
| `sense` | إحساس `ARB:2405` | medium | 900 / 2520 / 5670 | 1 | night | 3 | no |
| `impersonate` | انتحال شخصية `ARB:2407` | heavy | 1800 / 5040 / 11340 | 1 | discuss (moved) | 0 | yes |
| `narrator_whisper` | همسة الراوي `ARB:2409` | heavy | 2400 / 6720 / 15120 | 1 | night | 2 | no |
| `lock_door` | قفل الباب `ARB:2411` | heavy | 2800 / 7840 / 17640 | 1 | discuss (moved) | 0 | no |
| `appeal` | استئناف `ARB:2413` | heavy | 3000 / 8400 / 18900 | 1 | vote | 0 | no |

(Prices and flags: `mig/20261007000200_table_tools.sql:24-41`; moved windows `mig/20261007000400_table_tools_day_protections.sql:4`; secret anon_note `mig/20261009000500_live_tool_atomicity.sql:2`.)

Descriptions in the app (`ARB` line = name line + 1): extra_minute «٤٥ ثانية زيادة على وقت كلامك.»; anon_note «رسالة قصيرة للترابيزة كلها من غير اسمك.»; last_will «لو مُت، تسيب رسالة قصيرة الكل يقراها الصبح.»; spotlight «تختار لاعب، ولازم يتكلم دلوقتي ويرد عليك.»; objection «لما يتّهموك، تاخد ٣٠ ثانية دفاع مضمونة.»; last_word «لو اتطلّعت، تختار لاعب لازم يدافع عن نفسه أول واحد بكرة.»; vote_shield «محدش يقدر يسكّتك اليوم ده وصوتك مايتلغيش.»; half_door «ليلة واحدة: لا تسكيت ولا كشف يوصلك (القتل لأ).»; double_vote «صوتك بـ ٢ اليوم ده، والكل شايف.»; camouflage «لو المحقق كشفك الليلة، يطلعله «مش واضح».»; revote «التصويت يتعاد مرة بعد ما النتيجة تظهر.»; grave_vote «لو مُت، تصوّت مرة في النهار اللي بعدها.»; sense «تختار ٣ لاعيبة، والراوي يهمسلك: فيه مافيا بينهم ولا لأ.»; impersonate «المحقق يشوفك «مواطن» أو «مافيا» على حسب ما تختار.»; narrator_whisper «تختار لاعبين، والراوي يقولك أنت بس: فيه مافيا بينهم؟»; lock_door «ليلة كاملة محدش يوصلك: لا قتل ولا تسكيت ولا طلقة ولا كشف.»; appeal «لو اتطلّعت، تصويت أخير عليك أنت بس ولازم أغلبية واضحة.» (`ARB:2382-2414`).

### 5.2 Per-tool rules

Format per tool: **Effect (code)**, **who/when**, **public line**, **private line**, **conflicts**, **kick/disconnect**, **evidence**. Offline evidence for every tool: NONE (online only).

#### `extra_minute`
* Effect: +45 s on the user's **first granted floor claim** in the same `phase_number`; one-shot, then `consumed_at` is set. Only structured discussion uses floor claims, so in free discussion the bonus is never consumed.
* Who/when: living, `discuss` window.
* Public: `toolFeedUsed` `ARB:2506` «{who} استخدم: {tool}».
* Private: none.
* Conflicts: stacks with `objection` (+75 s total on the first claim).
* Kick/disconnect: unclaimed bonus lapses; charge gone.
* Evidence: `fn/_shared/tools.ts:105-131`; `mig/20261009000600_atomic_floor_bonus.sql:23-32`; `fn/claim_floor/index.ts:60-70`; `fn/_shared/voice.ts:39-76` (free = open mic, no claims).

#### `anon_note`
* Effect: a note of 1-140 chars published to the whole table with no seat.
* Who/when: living, `discuss` window; secret.
* Public: `toolFeedAnonNote` `ARB:2526` «ورقة من غير اسم: {text}»; `toolFeedSecret` `ARB:2517` «حد استخدم أداة سرّية».
* Private: none. The server row keeps the author's seat (not exposed).
* Conflicts: none.
* Kick/disconnect: note stays.
* Evidence: `mig/20261015000100_all_access_grants.sql:269-272,310-317`; `mig/20261009000500_live_tool_atomicity.sql:2`.

#### `last_will`
* Effect: a note of 1-140 chars published **at the moment of use**; only a **dead** player can use it.
* Who/when: dead only, any phase.
* Public: `toolFeedLastWill` `ARB:2534` «وصيّة: {text}».
* Private: none.
* Conflicts: none. Copy says "if you die... read in the morning" but the tool cannot be armed before death (D22).
* Kick/disconnect: a kicked player cannot use it (not a member).
* Evidence: `mig/20261015000100_all_access_grants.sql:250-251,269-272`.

#### `spotlight`
* Effect: **NOT FOUND**. The use is logged with its target in `toolLog`; no function reads it to force speech (D21).
* Who/when: living, `discuss` window, 1 living target.
* Public: `toolFeedTargets` `ARB:2518` «على: {names}».
* Evidence: absence in `fn/` (no helper in `fn/_shared/tools.ts`; `fn/claim_floor/index.ts` does not read it).

#### `objection`
* Effect: +30 s on the user's first granted floor claim in that `phase_number`. Not tied to being accused.
* Who/when: living, `discuss` window.
* Conflicts: stacks with `extra_minute`. Useless in free discussion.
* Evidence: `fn/_shared/tools.ts:128`; `mig/20261009000600_atomic_floor_bonus.sql:23-32` (D24).

#### `last_word`
* Effect: **NOT FOUND**. Logged with a target; no forced defence (D21).
* Who/when: living, `vote` window (`vote, discuss, defense`), 1 living target.
* Evidence: absence in `fn/` and `mig/` beyond the seed row.

#### `vote_shield`
* Effect: the user's seat cannot be the silence target on night N+1 (bought in day N). Silent drop, the Silencer is not told.
* Who/when: living, `discuss` window.
* Conflicts: redundant with `half_door` and `lock_door` on the same night.
* Kick/disconnect: seat is dead, no practical effect.
* Evidence: `fn/_shared/tools.ts:80-89`; `fn/resolve_night/index.ts:61,160-163`. Copy vs code: D20.

#### `half_door`
* Effect: on night N+1 no silence **and no investigation** reaches the seat; the kill and the shot still do. The Detective is told `unreachable`.
* Evidence: `fn/_shared/tools.ts:56-60,73`; `fn/resolve_night/index.ts:60-61`.

#### `double_vote`
* Effect: the user's ballot on the day it was bought weighs 2 (x3 more for a revealed Elder). The log makes it public.
* Who/when: living, `discuss` window. Applies in the revote round too (same day).
* Conflicts: none with `vote_shield` (both can be used the same day). Counts in appeal denominators at weight 2.
* Evidence: `fn/_shared/tools.ts:95-97`; `fn/resolve_vote/index.ts:108-110`.

#### `camouflage`
* Effect: if the Detective investigates the user on night N+1 the answer is `unclear` (shown «مش واضح»). Lower priority than doors and than `impersonate`.
* Secret. Evidence: `fn/_shared/tools.ts:67-78`; `ARB:2544`.

#### `revote`
* Effect: if round 1 has a clear winner, the elimination is **not** applied; a second round opens among the seats that drew at least one ballot. Round 2 never re-triggers. If round 1 tied: no extra effect (revote rule: ordinary revote; noElimination rule: nobody out, tool wasted).
* Who/when: living, `vote` window.
* Conflicts: with `appeal`: round 1 winner -> revote (appeal not evaluated yet); round 2 winner -> appeal evaluated. With `dayTieRule revote`: redundant.
* Evidence: `fn/resolve_vote/index.ts:138-160`; `fn/_shared/tools.ts:134-136`. Copy vs code: D19.

#### `grave_vote`
* Effect: a dead user casts one ballot in the **opening round** of the day whose `phase_number` equals the use. Counted with their own weight (an Elder who revealed keeps x3). Not waited for when the ballot closes early.
* Who/when: dead, any phase.
* Conflicts: refused in round 2; refused if the user already has a ballot that day (`RATE_LIMITED`). The silence check at `submit_vote` also applies to a grave voter.
* Kick/disconnect: a kicked user cannot ballot.
* Evidence: `fn/_shared/tools.ts:99-102`; `fn/submit_vote/index.ts:20-33,72-74`; `fn/resolve_vote/index.ts:87,117-119`. Copy: D25.

#### `sense`
* Effect: a private answer, computed **at the moment of use** from true roles: yes if any of the 3 chosen living seats is mafia-side (silencer counts). Not affected by doors, camouflage or impersonate.
* Who/when: living, `night` window (the only window for the two narrator tools).
* Public: log shows the use with **no targets**.
* Private: `toolAnswerYes` `ARB:2503` «الراوي بيهمسلك: أيوه، فيه مافيا بينهم.» / `toolAnswerNo` `ARB:2504` «الراوي بيهمسلك: لأ، مفيش مافيا بينهم.»; readable again through `my_tool_answers`.
* Evidence: `mig/20261015000100_all_access_grants.sql:299-302`; `mig/20261009000400_table_tools_fixes.sql:111-120`; `fn/_shared/tools.ts:170-181`.

#### `impersonate`
* Effect: on night N+1 the Detective is told `citizen` or `mafia` (the face chosen, `note`). The face never reaches the public log. Priority: door > impersonate > camouflage.
* Secret. Heavy.
* Conflicts: does not alter `sense` / `narrator_whisper`.
* Evidence: `mig/20261015000100_all_access_grants.sql:273-275` (note must be `citizen` or `mafia`); `fn/_shared/tools.ts:73-77`.

#### `narrator_whisper`
* Effect: same private answer as `sense` for 2 chosen seats; heavy.
* Who/when: living, `night` window.
* Evidence: as `sense`.

#### `lock_door`
* Effect: on night N+1 nothing reaches the seat: if the seat wins the Mafia tally the kill is cancelled (not redirected, and no save is recorded), a sniper shot at it is cancelled **together with the sniper's death**, no silence, `unreachable` for the Detective.
* Who/when: living, `discuss` window; heavy.
* Conflicts: wins over `half_door`, `impersonate`, `camouflage`; does not change `sense`/`narrator_whisper` answers.
* Kick/disconnect: seat dead, no effect.
* Evidence: `fn/_shared/tools.ts:51-53`; `fn/resolve_night/index.ts:60-62,138,153,162`.

#### `appeal`
* Effect: if the user is eliminated on that day's ballot, the elimination stands only if **more than two thirds** of the weighted counted ballots from everyone else (the user's own excluded, abstentions in the denominator, grave voters included) named the user: `confirm*3 > voters*2`. Otherwise nobody goes out that day. It is a recount, not a new vote.
* Who/when: living, `vote` window; heavy. The effect applies in whichever round eliminates.
* Evidence: `fn/_shared/tools.ts:139-168`; `fn/resolve_vote/index.ts:162-167`. Copy: D23.

---

## 6. Day rules

| Topic | Dart | TS/SQL | Evidence |
|---|---|---|---|
| Discussion modes | `structured` (default) or `free`; no offline timers | same two; online `discuss` runs `discussionSeconds` (default 300); structured uses floor claims, free = open mic | `eng/models/enums.dart:58`; `fn/_shared/phases.ts:69-70`; `fn/_shared/voice.ts:65-66` |
| Who may vote | every living, non-silenced player, once, in seat order; self and dead targets excluded | same by seat id; dead voters only through `grave_vote` | `eng/match_engine.dart:1179-1208`; `fn/submit_vote/index.ts:20-55` |
| Silenced | no ballot at all (`SkipSilencedVote`); may be voted for (R1) | ballot refused; may be voted for; the early-close check ignores them; the expiry default still writes an abstention row | `eng/legal_moves.dart:515-519`; `fn/submit_vote/index.ts:34-40,139-143`; `fn/advance_phase/index.ts:126-138` |
| Abstention | an option only when `abstainAllowed` (default off), but the engine accepts a null target without checking | always accepted, setting not read (D11) | `eng/legal_moves.dart:533-535`; `eng/match_engine.dart:1194-1208`; `fn/submit_vote/index.ts:43-55` |
| Count | plurality of weighted ballots, **no quorum**: one ballot beats any number of abstentions | same | `eng/match_engine.dart:1265-1277`; `fn/resolve_vote/index.ts:115-129` |
| Weights | revealed Elder 3 | revealed Elder 3, `double_vote` x2, grave voters | 4.5, 5.2 |
| Tie, `noElimination` (default) | nobody out | nobody out | `eng/match_engine.dart:1324`; `fn/resolve_vote/index.ts:146-149` |
| Tie, `revote` | one revote among exactly the tied seats; a second tie stands, nobody out | same, `revote.round` 2 | `eng/match_engine.dart:1321-1355`; `fn/resolve_vote/index.ts:147-149,169-186` |
| Revote candidates | the tied set | the tied set; the `revote` tool uses every seat that drew a ballot | `eng/legal_moves.dart:571-579`; `fn/resolve_vote/index.ts:154-158` |
| No ballots / all abstain | nobody out, go to `reveal` | `tally.size == 0` -> nobody out | `eng/match_engine.dart:1281-1286`; `fn/resolve_vote/index.ts:138` |
| Elimination reveal | `eliminatedHeadline` `ARB:212` «خرج {name}», `wasRole` `ARB:223` «كان {role}»; tie: `tieRevoteHeadline` `ARB:220` «تعادل هنصوت تاني», `tieNoEliminationHeadline` `ARB:221` «تعادل ومحدش خرج», `nobodyEliminated` `ARB:222` «محدش خرج»; round 2 button `revote` `ARB:231` «صوتوا تاني» | role always in `lastVote.eliminatedRole`; verdict phase 20 s | `fn/resolve_vote/index.ts:190-196,213-222` |
| Night victim role | only if `revealNightVictimRole`: `victimWasRole` `ARB:898` «{name} كان {role}.» | never | `ui/night/morning_screen.dart:132-136` |
| Elder reveal | 4.5 | 4.5 | |
| Whispers | `whisperEnabled`, one per living player per day, 120 chars, recipient living; void if the recipient dies | default on online; one per day (unique index), 120 chars | `eng/match_engine.dart:1485-1553`; `fn/send_whisper/index.ts:16-34` |
| Day tie default | `noElimination` | `noElimination` | `eng/models/match_settings.dart:28,212`; `fn/resolve_vote/index.ts:146` |

---

## 7. Win conditions

One rule, both sides: **on living players only**, `mafiaAlive == 0` -> town; `mafiaAlive >= nonMafiaAlive` -> mafia; otherwise play on. Mafia-side = `mafia` + `silencer`.

| End state | Dart | TS/SQL | Evidence |
|---|---|---|---|
| Last mafia-side seat leaves (vote, sniper, kick, strike) | town wins | `outcome: "town"` | `eng/win_check.dart:62`; `fn/resolve_night/index.ts:192-193`; `fn/resolve_vote/index.ts:205`; `mig/20261009000300_silencer_is_mafia_team.sql:37-40` |
| Parity or better | mafia wins (parity, not majority) | `outcome: "mafia"` | `eng/win_check.dart:63`; `fn/resolve_night/index.ts:194-195` |
| Zero alive | returns **town**, does not throw; spec 11 W6 says `DRAW` (D30). Judged unreachable by role mechanics alone | `mafia === 0` -> town | `eng/win_check.dart:49-60`; `docs/specs/11-edge-cases-and-tests.md:109` |
| Last mafia shot by the sniper at night | town wins at the morning | same | `eng/match_engine.dart:885-886` |
| Night brings parity | morning is shown, then result; `beginDay` refuses | `morning` then `result` | `eng/match_engine.dart:904-912`; `fn/_shared/phases.ts:20` |
| Day vote brings parity or clears the mafia | `reveal`, then `winCheck` | `verdict`, then `result` | `eng/match_engine.dart:1397-1424`; `fn/_shared/phases.ts:25` |
| Same night: sniper + target die and the mafia kill also lands | evaluated after **all** deaths | evaluated after all deaths (W8) | `eng/match_engine.dart:727-781`; `fn/resolve_night/index.ts:185-196` |
| Host removes a player offline | `removePlayer` marks dead then calls `winCheck()`, which **throws** unless the phase is `reveal`/`winCheck` (D35); no UI caller was found | n/a | `eng/match_engine.dart:1434-1470` |
| Online kick (host) | n/a (no kick offline) | marks the seat dead, sets `outcome` in the public data; rewards voided if the kick decided the match (R5) | `mig/20261009000300_silencer_is_mafia_team.sql:13-48`; `mig/20261009002200_receipt_participation_and_kick.sql:8-45` |
| Online absence strike (host, after 3 min of silence) | n/a | marks the seat dead, sets `outcome`; rewards **not** voided (D37) | `fn/remove_player/index.ts:41-55`; `mig/20261009000300_silencer_is_mafia_team.sql:50-85` |
| Copy | `phaseMafiaWins` `ARB:421` «المافيا خلصت على البلد», `phaseTownWins` `ARB:422` «الشعب انتصر», `mafiaWins` «المافيا كسبت», `townWins` «الشعب كسب» (`ARB:232-234`); `onboardingWinBody` explains parity | same keys | |

Draw states: none exist in either implementation. `Alignment` has no draw value (`eng/models/enums.dart:6`; comment in `eng/win_check.dart:49-60`).

---

## 8. Information engine, in one page (full spec: `docs/specs/09-information-engine.md`)

| Layer | Produces | Who sees it | Offline | Online |
|---|---|---|---|---|
| Trace (الأثر) T0-T8 | one true observation each morning. T1 is the only one that names players (victim's last suspicion) | the whole table, after the death line | chosen in `resolveNight` and logged `eng/match_engine.dart:795-830`; T2 allowed only when `quietNightEnabled` is off `:814`; `eng/information/trace_generator.dart:98,122` | `fn/_shared/trace.ts`; T2 always allowed; **no suspicions are recorded online**, so T1/T3-T8 starve (`fn/_shared/history.ts:114-118`, D5) |
| Confrontation C1-C11 | day 2+: one named player gets a timed window (45 s default) | whole table | `eng/match_engine.dart:1013-1051` | `fn/generate_confrontation/index.ts`; silence recorded (`confrontationSilent`) |
| Whisper | one private message per living player per day | the recipient; the graph (who to whom) is public | `eng/match_engine.dart:1485-1553`; off by default offline | `fn/send_whisper/index.ts`; default on |
| Opening round | «اسم واحد»: each living player names one suspect on day 1 | whole table | `eng/match_engine.dart:937-981` | `fn/submit_accusation` (NOT READ in detail) |
| Witness (R4) | the dead see all roles, every non-skip night action as seats, and (if flags allow) every delivered whisper body | dead, non-kicked members only | **none** (`lib/transport/local_transport.dart:88`) | `fn/witness_view/index.ts:41-60`; whisper bodies need both the global flag `witness_whispers_enabled` (default **false**, `mig/20260928001300_witness_whispers.sql:18-26`) and the room setting `witnessKnowledge` (default on) |

Trace copy (`ARB:564-572`): T0 «الليلة دي ماسابتش أي أثر»; T1 «آخر حاجة سجّلها {victim}: كان شاكك في «{target}»»; T2 «حد اتحمى الليلة دي… ونجا»; T3 «{count} لاعبين شكّوا في نفس الشخص الليلة دي»; T4 «{count} غيّر شكّه الليلة دي»; T5 «فيه لاعب لسه محدش شك فيه ولا مرة»; T6 «فيه لاعب رفض يسجّل شكّه الليلة دي»; T7 «اتنين شاكّين في بعض»; T8 «أغلب الطاولة شكّت في نفس الشخص». Confrontation copy: `confrontationC1/C4/C5/C6/C7/C8/C11` `ARB:579-585`; the other confrontation keys (C2, C3, C9, C10): NOT FOUND under that naming.

---

## 9. DISAGREEMENTS

Format: **what Dart does** (file:line) | **what TS/SQL does** (file:line) | **Arabic copy** | **ruling** | **severity guess**. "Player-visible" = a table would notice. "Rare edge" = needs an unusual setup. "Cosmetic" = no effect on play.

**D1. Quiet night «الليلة الهادية» means different things.**
Dart: the Mafia's bullet is the **team's** one bullet (`eng/bullets.dart:51-55`), and once spent that night **every** Mafia vote is ignored (`eng/resolver.dart:156-157`); the offline Mafia "choose nobody" tile arms it (`ui/night/night_action_screen.dart:198`).
TS/SQL: the bullet is **per player** (`mig/20260904000100_bullets_online.sql:52-54`: unique on `(room, actor)` where `used_bullet`); `resolve_night` tallies only `kill` actions (`fn/resolve_night/index.ts:97-102`) and reads `used_bullet` only for the sniper (`:151`). So bullet+skip is a plain skip by one Mafioso, bullet+kill still kills, other Mafia still kill, and every Mafioso has their own bullet.
Copy: `bulletMafia` `ARB:775` «الليلة الهادية», `nightSpecialMafia` `ARB:909` «مش هقتل الليلة». Ruling: none (doc 13). Severity: **player-visible**.

**D2. A doctor save is announced online, hidden offline.**
Dart: `announceSave = !quietNightEnabled` (`eng/resolver.dart:204`) and T2 is dropped when quiet night is on (`eng/match_engine.dart:814`; `eng/information/trace_generator.dart:122`). With the default (`quietNightEnabled` true) a save reads «محدش مات» only.
TS: `someoneSavedUnnamed: savedId !== null` (`fn/resolve_night/index.ts:202`), `selectTrace` has no such flag and T2 is always eligible (`fn/_shared/trace.ts:98-100`). The online morning headline shows `quietNight` only (`ui/online/online_table_flow.dart:1575-1578`), but T2 «حد اتحمى الليلة دي… ونجا» (`ARB:566`) can be published.
Ruling: none. Severity: **player-visible**.

**D3. «سريعة» (fast) preset hides saves though no quiet night is possible.**
Dart: the preset sets `bulletsEnabled:false` (`eng/presets.dart:64-76`) but leaves `quietNightEnabled` true, so `Bullets.enabled(quietNight)` is false (`eng/bullets.dart:34-36`) while `announceSave` is still false (`eng/resolver.dart:204`) and T2 suppressed. The resolver comment promises "reads precisely as before doc 13" when the setting is off (`:197-203`).
TS: n/a. Copy: `presetFastHint` «وقت أقل وقواعد أبسط» (`ARB:885`). Severity: **player-visible** (offline fast only).

**D4. Doctor may not repeat last night's target: offline only.**
Dart: `eng/resolver.dart:231-257`, `eng/match_engine.dart:493-502`, tile removed `eng/legal_moves.dart:437-444`.
TS: **NOT FOUND**; `fn/submit_night_action/index.ts` has no such check, `advance_phase` default ignores it (`fn/advance_phase/index.ts:78-80`).
Copy: `roleDoctorDescription` `ARB:122` does not mention it; spec 11 N4 says blocked by default. Severity: **player-visible**.

**D5. Citizens and the Elder record nothing online; the information engine runs on air.**
Dart: `suspect` for citizen/elder/sniper (`eng/models/enums.dart:79-80`; `eng/match_engine.dart:549-567`), skip recorded (`:657-667`).
TS: `submit_night_action` returns ok and stores nothing (`fn/submit_night_action/index.ts:89-91`); `advance_phase` skips citizens (`:71`) but writes a `skip` row for an Elder (`:89-90`); `buildHistory` leaves `suspicions` empty on purpose (`fn/_shared/history.ts:114-118`), so T1, T3-T8 and the suspicion-based confrontations cannot fire.
Copy: `roleCitizenDescription` `ARB:126` admits "في الأونلاين بتستنى بالليل"; spec 09 §1.2 and spec 11 T-E9 claim identical behaviour. Severity: **player-visible**.

**D6. Detective: one investigation per night offline; unlimited re-asks online.**
Dart: `eng/match_engine.dart:522-525`; `eng/legal_moves.dart:393-396`.
TS: row key is `(room, night, actor)` and every upsert returns a fresh `revealedRole` (`fn/submit_night_action/index.ts:196-205,237-253`); no investigate-specific limit found in `mig/` (grep of `investigate` in migrations: only the action constraint).
Ruling: none. Severity: **player-visible** (also an information leak vector for a modified client).

**D7. Who the Mafia team knows at the deal.**
Dart: `revealFor` lists only other `Role.mafia` for a `Role.mafia` (`eng/match_engine.dart:228-233`); a silencer sees nobody, Mafia do not see the silencer; the later day-time card check lists all mafia-aligned (`lib/transport/local_transport.dart:205-211`).
TS: `my_team` gives `mafia` and `silencer` the full team list (`fn/my_team/index.ts:46-59`).
Severity: **player-visible**.

**D8. A silenced player who also dies that night.**
Dart: silence recorded regardless (`eng/resolver.dart:178-181`); the morning shows the death **and** «{name} متسكّت النهارده» (`ARB:919`; `ui/night/morning_screen.dart:139-146`).
TS: `!deaths.has(a.target_id)` drops it (`fn/resolve_night/index.ts:160-163`). Ruling R1. Severity: rare edge.

**D9. Public announcement of the silence.**
Dart: morning line and ballot mark (`ARB:919`, `ARB:2559`).
TS/UI: none; only the silenced viewer sees `silencedCannotVote` (`ui/online/online_table_flow.dart:1652,1876-1880`); no widget under `ui/online` reads `silencedSeat` (grep). Ruling R1. Severity: **player-visible**.

**D10. Silenced player's voice.**
Dart: no engine rule about talking; UI mark only.
TS: floor claim refused (`mig/20261009000600_atomic_floor_bonus.sql:13`; `fn/claim_floor/index.ts:31-33`) but in `free` discussion the mic policy is `open` (`fn/_shared/voice.ts:65-66`) and the client only subtracts host-muted seats (`lib/platform/voice/voice_controller.dart:813-816`), so the Silencer's silence does not mute anyone. Ruling R1 ("cannot talk"). Severity: **player-visible**.

**D11. `abstainAllowed` online.**
Dart: option offered only when on (default off) (`eng/legal_moves.dart:533-535`; `eng/models/match_settings.dart:214`); the engine itself still accepts null (`eng/match_engine.dart:1194`).
TS: `submit_vote` accepts a null target always (`fn/submit_vote/index.ts:43-55`); the setting is stored (`fn/_shared/room_configuration.ts:39`) and never read by a vote function. Copy: `settingAbstainHint` `ARB:946`. Severity: **player-visible**.

**D12. Morning with two deaths.**
Dart: every victim named, joined by " · " (`ui/night/morning_screen.dart:75-80`).
Online UI: headline uses `snapshot.morning?.victimSeat` (the first) only (`ui/online/online_table_flow.dart:1572-1578`) although the codec carries `victimSeats` (`lib/transport/room_codec.dart:137-147`). Needs a sniper hit on a town seat. Severity: **player-visible**, rare.

**D13. Default role split differs by mode, and the guard flags its own preset.**
Dart: classic gives 2 Mafia at 9 and 10 players and 4 at 15-18 (`eng/presets.dart:145`), but `BalanceGuard` raises `recommend_three_mafia` (non-blocking) for any 9+ table with Mafia != 3 (`eng/balance_guard.dart:110-114`), so the default split shows the advisory «الأفضل تختار 3 مافيا…» (`ARB:81`). The comment in the preset file calls that heuristic wrong (`eng/presets.dart:137-144`).
Online lobby uses the old heuristic (3 Mafia from 9 up) (`ui/online/lobby_screen.dart:287`; `eng/balance_guard.dart:163-186`). So 10 players = 2 Mafia offline, 3 online; 15 players = 4 vs 3. Spec 11 S2 (5 players) also disagrees (D31). Severity: **player-visible**.

**D14. Online host enabling a sold role below its minimum.**
`lobby_screen._start` subtracts a Mafia/citizen without checking (`ui/online/lobby_screen.dart:288-300`); e.g. 5-6 players with the silencer leaves 0 normal Mafia and the server refuses with "invalid silencer setup" (`fn/start_match/index.ts:84-88`); elder under 6 and sniper under 7 are refused too (`:89-98`). Offline blocks these in the UI (`ui/setup/optional_roles.dart:35-53`). Whether the room settings screen prevents it earlier: NOT VERIFIED. Severity: rare edge (failed start).

**D15. `selfProtectEnabled` and `bulletsEnabled` do not switch off self-protection.**
`Bullets.enabled` returns true for `selfProtect` before looking at any setting (`eng/bullets.dart:32`); same in TS (`fn/submit_night_action/index.ts:68`). The settings are stored (`fn/_shared/room_configuration.ts:39`) and documented as master switches (`eng/models/match_settings.dart:152-165`). Ruling: none. Severity: rare edge.

**D16. Timer-expiry defaults.**
Doctor: file header says "no protection" (`fn/advance_phase/index.ts:11`), code picks a random living other seat (`:74-88`). Lone-killer Silencer: `skip` (`:72-91`), whereas an idle Mafioso kills a seeded random target (N9). Elder: gets a `skip` row (`:89-90`). Dart: a seeded random legal move (`eng/legal_moves.dart:367-373`). Severity: rare edge.

**D17. Seeded choices differ in algorithm and order.**
Dart night tie: `Random(deriveSeed(...)).nextInt` over targets in event order (`eng/resolver.dart:68-89`), doctor tie over sorted seats (`:109-120`); TS: `tieBreakIndex` (splitmix32) over seat-sorted ids (`fn/resolve_night/index.ts:106-114,128-135`). `eng/seed.dart:100-118` says this is deliberate; `fn/resolve_night/index.ts:120` says "Mirrors NightResolver". Role shuffle likewise (`fn/start_match/index.ts:15-29` vs `eng/match_engine.dart:153-159`). Spec 10 §5.1 wants byte-identical output. Severity: cosmetic (no match runs on both).

**D18. Dart's engine does not validate night targets.**
`submitNightAction` checks only the seat range (`eng/match_engine.dart:403-405`): self, dead or (for silence) teammate targets are blocked only by the move list (`eng/legal_moves.dart:426-433`). TS checks alive and not-self (`fn/submit_night_action/index.ts:167-179`). Severity: cosmetic.

**D19. `revote` tool vs what it says.**
Code: acts only when round 1 has a clear winner (`fn/resolve_vote/index.ts:154-159`); on a tie with `noElimination` nothing happens and the charge is gone; the tool is bought **before** the result. Copy: `toolRevoteDesc` `ARB:2402` «التصويت يتعاد مرة بعد ما النتيجة تظهر.» Severity: **player-visible**.

**D20. `vote_shield` protects tomorrow, copy says today.**
Code: bought on day N, covers the silence of night N+1 (`fn/_shared/tools.ts:80-89`), so it does nothing against the silence already applied to day N. Copy: `toolVoteShieldDesc` `ARB:2394` «محدش يقدر يسكّتك اليوم ده وصوتك مايتلغيش.» Severity: **player-visible**.

**D21. `spotlight` and `last_word` have no effect.**
Both only log (`mig/20261015000100_all_access_grants.sql:310-317`); no function reads their rows (grep of `fn/`). Copy: `toolSpotlightDesc` `ARB:2388` «تختار لاعب، ولازم يتكلم دلوقتي ويرد عليك.»; `toolLastWordDesc` `ARB:2392` «لو اتطلّعت، تختار لاعب لازم يدافع عن نفسه أول واحد بكرة.» Severity: **player-visible** (paid items).

**D22. `last_will` cannot be armed before death.**
Only a dead player can use it and it is published immediately (`mig/20261015000100_all_access_grants.sql:250-251`). Copy `toolLastWillDesc` `ARB:2386`: "لو مُت... الصبح". Severity: player-visible.

**D23. `appeal` is a recount, not a last vote.**
`fn/resolve_vote/index.ts:162-167`, `fn/_shared/tools.ts:148-168`. Copy `toolAppealDesc` `ARB:2414` «تصويت أخير عليك أنت بس ولازم أغلبية واضحة.» The 2/3 threshold is not stated. Severity: player-visible.

**D24. `objection` / `extra_minute` only matter in structured discussion; `objection` is not tied to accusation.**
`mig/20261009000600_atomic_floor_bonus.sql:23-32`; `fn/_shared/voice.ts:65-66`. Copy `toolObjectionDesc` `ARB:2390` «لما يتّهموك…». Severity: player-visible.

**D25. `grave_vote` day.**
The ballot belongs to the day whose `phase_number` equals the use (`fn/_shared/tools.ts:99-102`), round 1 only (`fn/submit_vote/index.ts:72-74`). Copy `toolGraveVoteDesc` `ARB:2404` «تصوّت مرة في النهار اللي بعدها». Severity: rare edge.

**D26-D32. Spec 11 / spec 09 statements the code contradicts.**
* **D26** (spec 11 line 60, N1) "Mafia targets another Mafia: allowed" vs blocked in both (`eng/match_engine.dart:430`; `fn/submit_night_action/index.ts:181`).
* **D27** (spec 11 lines 62-63, N3/N4) "Doctor self-protect only if the setting permits and not on consecutive nights" vs once per match, always on (D15); the "blocked on consecutive nights" half (N4) holds offline only (D4).
* **D28** (spec 11 line 69, N10) "Citizen skip recorded as null" vs online no record (D5).
* **D29** (spec 11 line 87, D3) "max 2 revote rounds" vs one revote (`eng/match_engine.dart:1323-1324`; `fn/resolve_vote/index.ts:149`; header `:4-7`).
* **D30** (spec 11 line 109, W6) "0 alive -> DRAW" vs returns town (`eng/win_check.dart:60`; `fn/resolve_night/index.ts:192`).
* **D31** (spec 11 line 44, S2) 5 players "1 Mafia, 1 Doctor, 0 Detective, 3 Citizens" vs 1/1/1/2 (`eng/presets.dart:145-150`; `eng/balance_guard.dart:176-185`).
* **D32** (spec 11 line 131, T-E9; spec 09 lines 1-5) "byte-identical online and offline" vs D2 and D5.
Severity: documentation.

**D33. `defense` phase is unreachable.** It appears in `TRANSITIONS` (`fn/_shared/phases.ts:20`), tool windows (`mig/20261015000100_all_access_grants.sql:250-258`), voice policy (`fn/_shared/voice.ts:62`), but no function sets it and `reveal_elder_role` does not list it (`mig/20261007000500_roles.sql:99`). Severity: cosmetic.

**D34. Elder reveal windows.** Dart allows `voteResolving` and `reveal` (`eng/match_engine.dart:1141-1149`); TS allows `verdict`, not `defense` (`mig/20261007000500_roles.sql:99`). Severity: cosmetic.

**D35. Offline `removePlayer` is a latent crash.** It mutates the roster then calls `winCheck()`, which throws outside `reveal`/`winCheck` (`eng/match_engine.dart:1434-1470`, `:1398-1400`). The only caller is `match_controller.removePlayer` (`ui/match_controller.dart:728`) which no screen calls. Severity: rare edge (dead code).

**D36. Witness (R4).** Offline: none (`lib/transport/local_transport.dart:88`). Online: roles and actions yes; whisper bodies require the global flag `witness_whispers_enabled` default false (`mig/20260928001300_witness_whispers.sql:18-26`) **and** the room setting. Whether the flag is on in production: NOT FOUND in code. Copy: `witnessTitle` `ARB:741`, `witnessEliminated` `ARB:742` «خرجت من المباراة». Ruling R4. Severity: **player-visible** if the flag is off.

**D37. Rewards void (R5).** `kick_member` voids rewards when the kick decided the match (`mig/20261009002200_receipt_participation_and_kick.sql:8-45`). `strike_absent_member` (host marks a player gone after 3 minutes) has no equivalent (`fn/remove_player/index.ts`; `mig/20261009000300_silencer_is_mafia_team.sql:50-85`). Refund: revokes roles/tool charges only up to the coin amount covered (`mig/20261009001500_refund_revokes_items.sql:27-58`). Severity: rare edge.

**D38. T2 can claim a survival that did not happen.** If the Doctor blocks the Mafia kill on seat X and the Sniper shoots X, X dies but `savedSeat` is still recorded (`eng/resolver.dart:141-145,165-176`), so T2 «حد اتحمى… ونجا» may publish (Dart only when `quietNightEnabled` is off; TS always). CLAUDE.md rule 4 (never invent a fact). Severity: rare edge.

**D39. Sold-role ownership is enforced by UI offline and by `start_match` online.** The engine never checks ownership (`eng/match_engine.dart:112-126`); online only the host is checked, and only at start (`fn/start_match/index.ts:72-76`). Whether `create_room`/`room_settings` also check: NOT VERIFIED. Severity: cosmetic until a refund test.

**D40. Dead copy.** `balanceTwoDetectivesLowPlayerCount` `ARB:82` «محققين مع أقل من 11 لاعب بيقووا فريق المواطنين» is still mapped (`lib/ui/l10n_ext.dart:52`) but `BalanceGuard` no longer produces `two_detectives_low_player_count`; a second detective is now blocked by `one_detective_only` (`eng/balance_guard.dart:118-122`). Severity: cosmetic.

**D41. Role-name copy forms.** `roleMafia` «مافيا» `ARB:113` vs group `roleGroupMafia` «المافيا» `ARB:70`; same for doctor/detective/citizen. Severity: cosmetic.

---

## 10. CANDIDATE CASES

Notation: **M** mafia, **S** silencer, **Dr** doctor, **Det** detective, **E** elder, **Sn** sniper, **C** citizen. "n" = players. Where Dart and TS agree the outcome is stated once.

### 10.1 Doctor, save, protection

* **C1.** 7p: M,M,Dr,Det,C,C,C. Mafia vote X; Dr protects X. Outcome: nobody dies, `savedSeat=X`. Dart morning with defaults: «محدش مات» only (`eng/resolver.dart:204`); with `quietNightEnabled` off: + «حد نجا من محاولة قتل». TS: `someoneSavedUnnamed:true`, T2 eligible.
* **C2.** As C1 but Mafia split 1-1 on X,Y and Dr protects X: tie drawn on seed. Dart `Random` vs TS `mix32`, so the same seed may kill different seats (D17).
* **C3.** Dr protects self with the bullet on night 1; Mafia kill Dr. Outcome: Dr saved. Bullet spent.
* **C4.** Dr uses the self-protect bullet on night 1, tries again on night 3. Dart: refused (`eng/match_engine.dart:685-690`). TS: `RATE_LIMITED` (`fn/submit_night_action/index.ts:158-160`).
* **C5.** Dr protects Y night 1 and Y night 2. Dart: refused. TS: accepted (D4).
* **C6.** Dr protects Y night 1, self (bullet) night 2, Y night 3. Both accept (previous night's target was self).
* **C7.** Dr chooses "nobody" without the bullet. Dart: the engine protects the first legal target (`eng/match_engine.dart:601-620`); the UI never offers it. TS: refused (`fn/submit_night_action/index.ts:96-98`).
* **C8.** Two doctors protect X and Y, Mafia kills X. One protected seat, drawn on seed: 50% save by seed (algorithm differs, D17).
* **C9.** Dr protects T; Sn shoots T (town). T dies and Sn dies; Dr irrelevant (R2). Both.
* **C10.** Dr protects X; Mafia kill X; Sn shoots X (town). Mafia kill blocked, shot kills X and Sn. `savedSeat=X` is still recorded; T2 may publish (D38).
* **C11.** Mafia kill Dr; Dr (acting the same night) protects X, which the Mafia did not target. Dr dies; protection for X still counted (no alive check at resolution in either).
* **C12.** Dr protects a Mafioso who is the Sn's target. Mafioso dies anyway.
* **C13.** Dr is the last doctor and dies. No protection afterwards, no crash (spec 11 N12).
* **C14.** «سريعة» preset, Dr saves X. Dart: save never announced although quiet night is unavailable (D3).

### 10.2 Sniper

* **C15.** 7p, Sn shoots M. M dies, Sn lives (unless killed that night). Town gets a Mafioso.
* **C16.** Sn shoots a citizen. Citizen and Sn die. Dart morning lists both; online headline names the lower seat only (D12).
* **C17.** Sn shoots S (silencer). S dies, Sn lives (silencer is mafia-aligned: `eng/resolver.dart:173`; `isMafiaTeam` TS `:155`).
* **C18.** Sn shoots E or Det. Town victim: both die.
* **C19.** Sn shoots M and M's team kills Sn the same night. M dies and Sn dies (shot not cancelled by the shooter's death, `eng/resolver.dart:165-176`; `fn/resolve_night/index.ts:151-153`).
* **C20.** Sn's second shot. Dart refused (`eng/bullets.dart:66-72`); TS `RATE_LIMITED` plus unique index.
* **C21.** Sn does not arm: stored as a plain suspicion; no effect.
* **C22.** Mafia kills X and Sn shoots X (unprotected town). Single death for X (set dedup) plus Sn: two deaths.
* **C23.** Sn shoots the last Mafioso. Town wins at the morning.
* **C24.** Sn shoots a citizen, leaving parity. Mafia win at the morning, after the death line.
* **C25.** Sn shoots a seat locked by `lock_door`. TS: no deaths, bullet spent, Sn survives (`fn/resolve_night/index.ts:153`). Dart: n/a.
* **C26.** Mafia quiet night and Sn shot the same night. Dart: kill cancelled, shot lands (`eng/resolver.dart:156-176`). TS: no quiet-night logic (D1).
* **C27.** `bulletsEnabled:false` and `sniperEnabled:true`. Sniper still has a shot (`eng/bullets.dart:33`).

### 10.3 Silencer and silence

* **C28.** 7p with S. S silences X. X cannot vote that day (both); X can be voted out (R1).
* **C29.** X silenced and voted out the same day. Allowed, X dies (R1).
* **C30.** X silenced is also the night's victim. Dart: death plus «{name} متسكّت النهارده». TS: death only (D8).
* **C31.** The last `mafia` (not the silencer) is voted out on day 2. Night 3: S's `silence` is stored as `kill`, and S may not target a Mafioso (R3). Both.
* **C32.** The last `mafia` is shot by Sn on night 2 while S silenced Y on night 2. Y's silence stands (killer alive when S acted); S kills from night 3.
* **C33.** S silences itself (tile «سكّت نفسك بكرة»). S cannot vote next day; offline the morning announces it.
* **C34.** S silences a Mafia teammate. Allowed in both.
* **C35.** Silenced E: cannot vote, can still reveal; their x3 is lost for that day.
* **C36.** Silenced player in structured discussion online: floor claim refused (`reason: silenced`).
* **C37.** Silenced player in `free` discussion online: mic still open (D10).
* **C38.** Silenced player offline: engine has no talk rule; only the mark shows.
* **C39.** Lone-killer S times out online: `skip`, no kill (`fn/advance_phase/index.ts:72-91`).
* **C40.** Online `vote_shield` on the silence target: silence dropped, S is not told, no morning line.
* **C41.** Online `half_door` or `lock_door` on the target: same drop.
* **C42.** Silenced voter and the early-close check: ballot closes when all other living players have voted (`fn/submit_vote/index.ts:139-143`); the expiry default still writes an abstention row for the silenced seat.
* **C43.** Offline the silencer's deal: S and M do not see each other on the role card (D7).

### 10.4 Detective

* **C44.** Det checks S: sees «مافيا التسكيت» (exact role). Both.
* **C45.** Det checks E: sees «شيخ الصالحين».
* **C46.** Det checks a seat with `camouflage`: online «مش واضح».
* **C47.** Det checks a seat with `half_door` or `lock_door`: «بابه مقفول».
* **C48.** Det checks a Mafioso who used `impersonate` "citizen": sees «مواطن».
* **C49.** Seat has `impersonate` and `camouflage`: impersonate wins (`fn/_shared/tools.ts:74-76`).
* **C50.** Det checks twice in one night. Dart: second throws. TS: second answer returned, row overwritten (D6).
* **C51.** Det is killed the same night after asking: the answer was already delivered.
* **C52.** Two detectives configured: Dart guard blocks (engine start does not), TS refuses.

### 10.5 Elder

* **C53.** E reveals during discussion and is killed that night. Dead E casts no ballot; the reveal persists.
* **C54.** 6 alive: revealed E votes A; two others vote B. A=3, B=2: A out.
* **C55.** E reveals after casting a ballot, before the tally: ballot weighs 3 retroactively (`eng/match_engine.dart:1273-1274`; `fn/resolve_vote/index.ts:80-83,108-110`).
* **C56.** E reveals during `voteResolving` (Dart only): allowed.
* **C57.** E reveals at night: refused in both.
* **C58.** Revealed E with `double_vote`: weight 6.
* **C59.** Revealed E votes in the revote round: still 3.
* **C60.** Revealed E uses `grave_vote` after death: ballot of weight 3 in round 1.
* **C61.** E online at night: no move; offline: a suspicion. Timer: a `skip` row online.
* **C62.** E is the Sn's or Det's target: treated as town.

### 10.6 Mafia and the group kill

* **C63.** Mafia votes a teammate: refused in both.
* **C64.** Mafia quiet night with 2 Mafia, other votes a victim. Dart: nobody dies. TS: victim dies (D1).
* **C65.** Second Mafioso tries a quiet night after the first spent it. Dart: refused (team). TS: allowed (own bullet).
* **C66.** Offline Mafia taps "choose nobody": quiet night is armed (once per match).
* **C67.** Mafia idle online: seeded random living non-mafia-team seat is killed at expiry.
* **C68.** Mafia target wins the tally but is under `lock_door`: no kill, no redirect, no save recorded.

### 10.7 Tool pairs and limits (online)

* **C69.** `vote_shield` + `double_vote`, same user, same day: both recorded; ballot weight 2 today; shield covers night N+1's silence.
* **C70.** `revote`, clear round-1 winner, rule `noElimination`: round 2 among seats that drew a ballot; a tie in round 2 = nobody out.
* **C71.** `revote`, round-1 tie, rule `noElimination`: no revote, no elimination, charge lost.
* **C72.** `revote`, round-1 tie, rule `revote`: the ordinary revote; tool adds nothing.
* **C73.** `revote` + `appeal` same day, appellant leads round 1: revote opens, appeal not evaluated; if the appellant is eliminated in round 2 the appeal is evaluated.
* **C74.** `appeal`: eliminated with 5 other weighted ballots, 3 for the appellant: 9 > 10 false: not upheld, nobody out. 4 of 5: 12 > 10 true: eliminated.
* **C75.** `appeal` with 2 abstentions among 6 others, 4 for the appellant: 12 > 12 false: not upheld.
* **C76.** `appeal` by a player who is not eliminated: no effect, charge spent.
* **C77.** `lock_door` + `narrator_whisper`/`sense` naming the locked seat: the answer still uses the true role (`mig/...all_access_grants.sql:299-302`).
* **C78.** `impersonate` + `sense`: sense ignores the face.
* **C79.** `camouflage` + `half_door` on one seat: Detective sees «بابه مقفول».
* **C80.** `half_door` and `vote_shield` same night: redundant for silence.
* **C81.** `lock_door` + `half_door` same seat: lock dominates.
* **C82.** `half_door` against a kill and a shot: both still land.
* **C83.** `lock_door` on a Mafioso: immune to the Sn.
* **C84.** `grave_vote` by a dead player in round 1: counted at that player's weight; target must be alive and not themselves.
* **C85.** `grave_vote` in round 2: refused (`PHASE_CLOSED`, `fn/submit_vote/index.ts:72-74`).
* **C86.** `grave_vote` bought and never cast: charge lost.
* **C87.** `last_will` by an alive player: `ALIVE`. By a dead player: published at once.
* **C88.** `anon_note`: log has no seat; text shown.
* **C89.** `spotlight` / `last_word`: log only, no effect (D21).
* **C90.** `extra_minute` in free discussion: never consumed.
* **C91.** `extra_minute` + `objection`, same phase number: +75 s on the first claim, second claim gets nothing.
* **C92.** `extra_minute` used twice (limit 2) then a third: `LIMIT_TOOL`.
* **C93.** Fifth tool in a match: `LIMIT_MATCH`. Third heavy: `LIMIT_HEAVY`.
* **C94.** Same tool twice in one `phase_number` (morning and discuss of the same day share the number): `LIMIT_PHASE`.
* **C95.** All-access user uses a tool with 0 charges: allowed, limits still apply.
* **C96.** Tool user kicked after `lock_door`: charge not refunded; seat dead, no effect.
* **C97.** Tool user kicked after `revote`: the revote still triggers (rows are read regardless of membership).
* **C98.** Tool user disconnects after `double_vote` and never votes: expiry writes an abstention; weight only matters for appeal denominators.
* **C99.** Coin refund after a role or tool was bought: role entitlement and unused charges revoked (R5); a host who no longer owns the role cannot start with its flag (`fn/start_match/index.ts:72-76`).

### 10.8 Day, vote, win, setup

* **C100.** Tie 2-2, default rule: nobody out. With `revote`: second ballot among tied seats; tie again: nobody out.
* **C101.** One ballot for X, rest abstain: X is eliminated (no quorum).
* **C102.** All abstain: nobody out, not a stall.
* **C103.** Vote for a silenced player: allowed.
* **C104.** Online abstain with `abstainAllowed` off: accepted (D11).
* **C105.** Last Mafioso voted out: role shown, town wins.
* **C106.** Elimination reaches parity: mafia wins after the reveal.
* **C107.** Night leaves 1 Mafia vs 1 town: result after the morning (no day).
* **C108.** Host kicks a town player online and parity is reached: mafia outcome and rewards voided.
* **C109.** Host strikes an absent player and that decides the match: outcome set, rewards not voided (D37).
* **C110.** Online lobby, 6 players, silencer on: start fails (D14).
* **C111.** 10 players: offline classic deals 2 Mafia, online 3 (D13).
* **C112.** Fast preset at 8 players: classic split, bullets off, victim role revealed.

---

## 11. Open questions (the code is ambiguous, dead or silent)

1. **Quiet night online**: is the intent the team-wide cancel (Dart) or the current per-player skip-and-burn (TS)? Both can be argued from `mig/20260904000100_bullets_online.sql` ("a skip already produces a quiet night"). Answer needed before any test is written.
2. **Self-silence**: is silencing yourself («سكّت نفسك بكرة») an intended bluff? Both modes allow it; it costs the Silencer its own ballot.
3. **Narrator tools versus protections**: should `sense`/`narrator_whisper` honour doors, camouflage and impersonate? Today they never do.
4. **`lock_door` and the Mafia tally**: a locked seat that wins the tally cancels the kill instead of redirecting it, and the Doctor's save is then not recorded. Intended?
5. **T2 after a sniper kill** (D38): should a saved-then-shot seat still count as a save?
6. **Whisper bodies for the dead (R4)**: is `witness_whispers_enabled` on in production? NOT FOUND in code.
7. **Absence strike and rewards (R5)**: should a strike that decides the match void rewards like a kick?
8. **Offline Elder reveal windows** (`voteResolving`, `reveal`) have no online counterpart; intended or leftover?
9. **`defense` phase**: remove or implement? It is referenced by tool windows and voice policy but never entered.
10. **Offline tools (R6)**: no code path exists; recorded as a fact only.
11. **Doctor timer default**: header says "no protection", code protects a random seat. Which is the rule?
12. **Spec 11 and spec 09** still describe behaviour the code does not have (D26-D32). Which side moves?
13. **`selfProtectEnabled` / `bulletsEnabled`**: should they switch self-protection off (D15)?
14. **`revealNightVictimRole`** has no online equivalent; intended?
15. **Opening round online**: which room setting gates `morning -> opening`? NOT VERIFIED (`openingRoundEnabled` is accepted at `fn/_shared/room_configuration.ts:39`; no reader found in the functions read).
16. **Confrontation on day 1 online**: whether the TS generator excludes day 1 (spec 11 C-E1): NOT VERIFIED.
17. **Where `social` offline flow reads `selectConfrontation` mid-discussion** (`midDiscussionConfrontation`): NOT READ.
18. **Pressure curve** (`eng/pressure.dart`): NOT READ; it shortens discussion as the table shrinks and is relevant to day rules.

---

## 12. Rulings (2026-10-16)

The owner handed the calls to Claude for this audit («اتعامل كأنك الرئيس و طبق»). Three principles decide every case: **the app never says what did not happen**; **a paid item does what its card says**; **offline and online are the same game** (the online-only exceptions are named). Every ruling below is implemented and tested in this branch unless marked otherwise; nothing is deployed (owner: «مترفعش اي حاجه»).

| # | Disagreement | Ruling |
|---|---|---|
| RL1 | D1 | The quiet night is the **Mafia team's** one bullet, as doc 13 and offline: the first Mafioso who arms «مش هقتل الليلة» spends it for the team for the match, and that night the Mafia kill nobody. Online follows: a team-wide spend, refused for a second Mafioso, and no kill on that night. |
| RL2 | D2, D3 | A Doctor save is told only when the match has no quiet night to hide behind (bullets on **and** quiet night on ⇒ the morning says only «محدش مات» and T2 stays silent). The fast preset, which has no bullets, tells the save again. Online follows. |
| RL3 | D4 | The Doctor may not cover the same player two nights running, in both modes. Self-protection stays the Doctor's bullet, once a match, always offered (D15: `selfProtectEnabled` is a legacy flag no screen sets). |
| RL4 | D5 | Online, citizens and the Elder wait at night (the copy says so); traces T1, T3–T8 and the suspicion confrontations are offline features. Specs 09 and 11 are corrected. |
| RL5 | D6 | One investigation a night online, as offline: the same target again returns the same answer; a different target is refused, at the function and at the table. |
| RL6 | D7 | The Mafia team (Mafia and Silencer) know each other at the deal in both modes. |
| RL7 | D8 | A seat that dies that night is not silenced (done, F1). |
| RL8 | D9, D10 | Online, the morning names the silenced player for everyone, his mic stays closed for that day in every discussion mode, and he can still be voted out (R1). |
| RL9 | D11 | Online abstention follows the room's setting. |
| RL10 | D12 | Online, the morning names every player who died. |
| RL11 | D13 | One recommended split everywhere: a quarter of the table, `(n + 1) ~/ 4` Mafia (the preset the balance harness measures). `BalanceGuard.recommended` returns it, the online lobby deals it, and the advisory names that number instead of «3». |
| RL12 | D14 | The online lobby offers a sold role only at the player count the server accepts (Elder 6+, Sniper 7+, Silencer with two or more Mafia), as offline. |
| RL13 | D19 | A bought revote also reopens a tied ballot: under «محدش يخرج», a tie with a revote bought goes to a second round among the tied seats. |
| RL14 | D20, D22, D23, D24, D25 | The tool cards say exactly what the tool does (vote shield = the next night; last will = after you are out, read at once; appeal = more than two thirds; extra minute and objection = talk by turns; grave vote = the next ballot). Extra minute and objection are refused in a free-discussion room, so nobody pays for nothing. |
| RL15 | D21 | Spotlight and last word get real effects. Spotlight: in talk by turns, the chosen player speaks next; in free talk the public line calls them out. Last word: when its owner is voted out, the chosen player speaks first the next day (talk by turns), and the table is told. |
| RL16 | D37 | A host's strike of an absent player that decides the match voids the rewards, as a kick does (R5). |
| RL17 | D38 | A save is recorded and may be told only when the covered player is alive in the morning (the Sniper's shot can still take him). |
| RL18 | D18, D35, D40, D16, D33 | Housekeeping: the engine validates night targets itself; the dead `removePlayer` path cannot crash; dead copy goes; the timer-expiry comment matches the code; `defense` is documented as unused. |
| RL19 | D36 | Whisper bodies for the dead depend on the production flag `witness_whispers_enabled` (off by default). Turning it on is a live change: **owner's word**. |
| RL20 | R6 / Q1 | Table tools stay online-only: a shared phone has no player identity to charge, and the store card says «جوه الماتش الأونلاين». Revisit for bot matches later. |
| RL21 | D17, D34, D39, D41 | No change (cosmetic, or both sides equivalent). |
