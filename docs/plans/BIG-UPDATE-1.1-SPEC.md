# 1.1 — Frozen spec (Sol, planning round 2; amended by later rounds)

# Frozen Specification — Update 1.1

Everything below is agreed except the economy switch, which still requires the owner’s explicit choice. All new flags default `false`; nothing is deployed, enabled, uploaded, or published during implementation.

## 1. Answers to contested points

### 1. Economy recommendation

I recommend a middle option, not either extreme.

Raising prices 4× while leaving faucets untouched is dangerous:

- It punishes casual/non-ad players.
- It devalues existing balances.
- Earned Season and chapter cosmetics are not coin sinks.
- The finite catalogue would still be exhausted by highly engaged players.

Cutting ads to twice/day would contradict the owner’s “ads per match” design.

Recommended option C:

| Reward | Final value |
|---|---:|
| Match completion | 25 coins |
| Win bonus | 10 coins |
| Rewarded step 1 | +25 coins |
| Rewarded step 2 | +25 coins |
| Maximum coin-eligible finished matches | 6/user/UTC day |
| Match 7+ | Season/Council progress only; no coin ad offer |
| Existing catalogue prices | Unchanged |
| Existing balances | Never reduced |

A fully rewarded win therefore pays 85 coins; a loss pays 75. The cheapest item still takes roughly two rewarded matches, while a 2,300-coin bundle takes about 28–31 strong matches.

At six matches/day for 28 days, a 50% winner earns approximately:

- Completion: 4,200
- Wins: 840
- Rewarded ads: 8,400
- Casebook/Daily/Daily Case/Council: approximately 5,500–6,500
- Total: approximately 19,000–20,000, rather than 60,000

This preserves per-match monetization, keeps ads meaningful, aligns the coin cap with Casebook’s existing six-match eligibility cap, and avoids making every price look hostile.

This must be presented as an owner decision. It is not authorized to implement silently.

### 2. Table-first additions

**House Rules Library: IN**, merged into F6.

It gives groups ownership over “their Mafia,” which is a core board-game strength. Shared rules contain only validated settings and role counts, never user-authored public descriptions.

**Scenario Draft: IN**, merged into F7.

Before the first deal, the table votes among three valid canonical presets. It creates conversation before the match without touching hidden information.

**Proverb Bluff: LATER.**

It is culturally strong, but it is a separate content game requiring:

- A large, carefully reviewed Arabic proverb catalogue.
- Regional wording validation.
- Local scoring and round flow.
- Protection against the mode feeling like a cheap trivia widget.

It should become a polished local warm-up pack later, not a rushed button inside this update.

### 3. Image tool and exact workflow

A Terra agent can call image generation only if its session inherits the `image_gen.imagegen` tool. Model selection does not itself provide image generation. In this orchestrated environment, subagents normally inherit the parent’s tools, so a Terra subagent should have it—but the session must verify that before production.

The current Windows shell has no `codex` executable on `PATH`, so I cannot truthfully promise that an external command such as `codex exec -m gpt-5.6-terra` will have the same tools. Preferred launch method: create a separate Terra agent session through the orchestrator and confirm `image_gen.imagegen` is callable.

Generated PNGs are automatically persisted here:

`C:\Users\LENOVO\.codex\generated_images\<thread-id>\exec-<uuid>.png`

After every accepted generation, copy the exact source immediately to a named path under `raw_assets/update11/`. Do not rely on UUID ordering later.

Production sessions:

| Session | Assets | Method |
|---|---|---|
| S0 | Four non-shipping style proofs | Use existing gallery portraits as visual references; lock palette, brushwork and faces |
| S1 | Six opaque heroes/backdrops | Individual generations |
| S2 | `n01`–`n12` suspects | Three 2×2 chroma/alpha sheets |
| S3 | `n13`–`n24` suspects plus rejected-face replacements | Three 2×2 sheets, then individual corrections |
| S4 | Chapter covers, seals, frames, Doctor guide | Covers individually; seals/frames in sheets |
| S5 | Academy and Scenario cards | Individual or 2×2 sheets by matching aspect ratio |
| S6 | Share templates, series pieces, Thursday stamp | Individual hero templates; transparent pieces in sheet |

Pipeline:

1. Copy raw PNG to its manifest path.
2. Slice sheets with `tool/slice_art_sheet.py`.
3. Normalize with `tool/normalise_art.py`.
4. Convert final assets to WebP/PNG as the manifest requires.
5. Run alpha checks: transparent corners, non-empty bounding box, minimum 32 px padding, no clipped hair/hands, no green fringe.
6. Generate a 420 px contact sheet and visually check all faces.
7. Reject duplicate silhouettes, repeated faces, malformed hands, baked writing and accidental frames.
8. Run dimension/file-size audit.
9. Only then register assets in `pubspec.yaml` and generated constants.

Expected output: 12–20 approved assets per session. The 24 suspects require two dedicated sessions.

### 4. Copy ownership

Agreed. Claude writes all Arabic and English chapter, drill, taunt and title copy; Codex reviews tone and safety.

Copy rules:

- Egyptian-flavoured Modern Arabic, not exaggerated dialect.
- Avoid repeated «يا معلم», fake gangster language and translated-English phrasing.
- No moral judgment of players.
- Avoid gendered direct address where natural.
- Detective: dry and observant.
- Doctor: warm but not parental.
- Mafia: controlled, never cartoonishly criminal.
- Citizen: grounded, social, quietly funny.
- Short UI lines ≤90 characters where practical.
- Arabic line-height 1.6, zero letter-spacing.

### 5. Privacy-safe analytics

No SDK and no advertising identifier.

Tables:

```text
product_metric_daily
  day, event_code, platform, locale, variant,
  count, value_sum, bucket_0..bucket_4
  PK(day,event_code,platform,locale,variant)

product_metric_receipts
  day, event_code, rotating_subject_hash, variant, created_at
  PK(day,event_code,rotating_subject_hash,variant)
```

`rotating_subject_hash = HMAC(ANALYTICS_SALT, user_id || UTC-day || event_code)`. It cannot correlate a player across days and is purged after 48 hours. Daily aggregates contain no UUID, room ID, name, voice data, free text or device identifier.

Edge action:

```json
{"action":"metricRecord","event":"case_open","variant":"difficulty_2","value":1}
```

Response:

```json
{"ok":true,"counted":true}
```

Only allowlisted events/variants are accepted. Server-owned events—claims, solves, series results—are counted directly inside authoritative transactions. Client signals are used only for opens, starts and successful exports.

D1/D7/D28 retention is aggregated at app-open time from account age. No durable analytics identity is needed.

---

# 2. Feature contracts

All RPCs are `security definer`, service-role-only, and explicitly revoked from `public`, `anon`, and `authenticated`. Edge functions derive `user_id` from the verified session.

## F1 — Casebook and Season Zero

### Schema changes

- `mission_seasons`: Season Zero becomes inactive until operator activation.
- Enforce at most one active season with a partial unique index.
- `season_reward_catalog`: level 20 receives `frame_season_zero`.
- `season_milestones(season_id, level, scene_code, voice)`.
- `season_milestone_views(user_id, season_id, level, seen_at)`.
- Reward-only catalogue item `frame_season_zero`, unavailable for purchase.
- Display level is `max(1, completed_xp_levels)`; unlocking still uses actual XP thresholds.

Milestones:

| Level | Voice | Purpose |
|---:|---|---|
| 5 | Citizen | Recognises that the player is becoming part of the table |
| 10 | Detective | Grants title «عين المجلس» |
| 15 | Mafia | A guarded acknowledgement of persistence |
| 20 | Doctor | Grants `frame_season_zero` and title «حافظ الأسرار» |

### RPC/actions

- Operator RPC `mission_season_activate(code, starts_at)` atomically sets `ends_at = starts_at + 28 days` and activates the row.
- Existing `missionHub`, `missionClaim`, `seasonClaim`, `achievementClaim`.
- New action:

```json
{"action":"seasonSceneSeen","season":"season_zero","level":10}
```

Response:

```json
{"ok":true,"hub":{ "...":"full missionHub shape" }}
```

`missionHub.season` adds:

```json
{
  "displayLevel": 1,
  "milestones": [
    {"level":5,"scene":"season_zero_05","voice":"citizen",
     "unlocked":true,"seen":false}
  ]
}
```

### Invariants

- Existing eligibility remains: finished public outcome, ≥5 humans, not kicked, six matches/day, three same-group/day, host once/day.
- Claims remain unique by user/source.
- Season activation cannot backdate before the current operator timestamp.
- No milestone changes XP.

### Flag

`missions_enabled`, default OFF.

### Screens

Casebook Tonight, Season Trail, milestone scene sheet, Legacy.

### Rewards

Existing Casebook values remain unchanged: 1,680 recurring maximum per 28 days, 400 track coins, two titles and the exclusive frame.

### Tests

- Inactive season grants no seasonal progress.
- Operator activation is exactly 28 days and cannot overlap another active season.
- Display begins at level 1 without granting level-1 rewards.
- Level-20 frame is claimable once.
- Milestone view receipt is idempotent.
- Existing double-claim, replay, six/day and same-group gates remain green.

## F2 — Case of the Day

### Contract changes

Existing tables and actions remain. Puzzle response adds:

```json
{"template":"crossed_shortlist","coverVoice":"detective|mafia"}
```

`coverVoice:"mafia"` is permitted Friday only and affects the cover note, never clue semantics.

No room, match, role or player table may be queried by the generator or puzzle RPC.

### Six templates

Suspects below are in clockwise seat order.

#### T1 — Direct clearance, difficulty 1

Suspects: `s0=n01, s1=n02, s2=n03, s3=n04, s4=n05`

Clues:

1. `not_mafia(s0)`
2. `not_mafia(s1)`
3. `not_mafia(s2)`
4. `not_mafia(s3)`

Answer: `s4`.

Chain: c1 eliminates s0; c2 s1; c3 s2; c4 s3.

Purpose: teaches exact clue semantics without inference tricks.

#### T2 — Crossed shortlist, difficulty 1

Suspects: `s0=n06 … s4=n10`

Clues:

1. `one_of(s1,s3)`
2. `not_mafia(s1)`

Answer: `s3`.

Chain: c1 eliminates s0/s2/s4; c2 eliminates s1.

Purpose: one intersection step.

#### T3 — Overlapping circles, difficulty 2

Suspects: `s0=n11 … s5=n16`

Clues:

1. `in_group([s0,s2,s4])`
2. `in_group([s1,s2,s5])`

Answer: `s2`.

Chain: c1 eliminates s1/s3/s5; c2 eliminates s0/s4.

Purpose: set intersection with no direct clearance.

#### T4 — Cleared side of the table, difficulty 2

Suspects: `s0=n17 … s5=n22`

Clues:

1. `outside_group([s0,s1,s2])`
2. `next_to(s0)`

Answer: `s5`.

Chain: c1 eliminates s0/s1/s2; c2 eliminates s3/s4.

Purpose: combine group and circular seating.

#### T5 — Distance triangulation, difficulty 3

Suspects: `s0=n01 … s6=n07`

Clues:

1. `distance(s0,2)`
2. `not_next_to(s3)`

Answer: `s5`.

Chain: c1 leaves s2/s5; c2 eliminates s2.

Purpose: mentally model circular distance.

#### T6 — Three-way lattice, difficulty 3

Suspects: `s0=n08 … s6=n14`

Clues:

1. `in_group([s3,s4,s5])`
2. `in_group([s3,s4,s6])`
3. `in_group([s3,s5,s6])`

Answer: `s3`.

Chain: c1 eliminates s0/s1/s2/s6; c2 eliminates s5; c3 eliminates s4.

Every clue is necessary: removing any one leaves two candidates.

### Schedule

- Sunday–Tuesday: T1/T2 deterministic variants.
- Wednesday–Thursday: T3/T4.
- Friday: T5 with Mafia cover note.
- Saturday: T5/T6.
- Generator must distribute every allowed template across a 365-day sample.

### Actions

Existing:

```json
{"action":"casePuzzle"}
{"action":"casePuzzleSolve","day":"YYYY-MM-DD","pick":"s3"}
```

Existing response contract remains authoritative. Reward stays 5 coins/20 XP.

### Flag

`case_of_day_enabled`, default OFF.

### Screens

Home/Casebook card, puzzle table, accusation state, clue-chain reveal, text share sheet.

### Tests

- Determinism and uniqueness over ten calendar years.
- Every template appears.
- Every clue eliminates at least one currently possible suspect.
- Removing every required clue leaves multiple solutions.
- No answer/reveal before solve or third failure.
- Stable name-to-portrait mapping.
- Friday voice never modifies clues or reward.
- Three-attempt and reward idempotency tests.

## F3 — Character Chapters

### Schema

```text
character_chapter_catalog
  code PK, role, reward_xp=100, item_code, title_code, active

character_chapter_objectives
  chapter_code, objective_code, metric, target
  PK(chapter_code,objective_code)

character_chapter_progress
  user_id, chapter_code,
  incident_seen_at,
  objective_code, objective_chosen_at,
  deduction_attempts, deduction_solved_at,
  completed_at, letter_opened_at,
  season_xp_season_id
  PK(user_id,chapter_code)
```

Objective selection is immutable. Only events after `objective_chosen_at` count.

If no season is active when a one-time chapter completes, its 100 XP remains pending and is applied once to the next activated season. It cannot be accumulated repeatedly.

### Chapters

| Character | Premise | Scene 1: incident | Scene 2: objective choice | Scene 3: deduction | Final letter beat |
|---|---|---|---|---|---|
| Detective | The final page vanished from an old evidence file | Establish archive stamp, sealed courier envelope and visitor timing | Solve 5 Daily Cases **or** build a 3-day solve streak | Archive clerk / courier / visitor; archive ink matches the torn stub, courier envelope is unopened, visitor arrived after disappearance → archive clerk | Respects patience and verification more than clever guesses |
| Doctor | Three sealed vials were left after a crowded night at the clinic | Establish arrival order, seal colours and which cabinet was opened | Finish 5 eligible matches **or** complete 2 reunion matches | Choose the vial belonging to the morning patient by eliminating impossible arrival/seal combinations | Trust means staying when the room becomes difficult |
| Mafia | Someone copied the black seal and sent an invitation in their name | Establish wax temperature, cup position and door timing | Win 3 eligible matches **or** host 2 eligible matches | Café owner / messenger / late guest; only the owner had warm wax before the back door opened → café owner | Guarded acknowledgement: the player notices what others overlook |
| Citizen | A street lantern returned with different glass | Establish neighbour sightings, repair time and market receipt | Finish 3 public-room matches **or** complete 2 reunion matches | Watchman / glass seller / neighbour; receipt and timing exclude the first two → neighbour | Belonging is built by the people who keep returning |

All deduction characters are fictional and unrelated to users.

### Actions

```json
{"action":"chapterHub"}
{"action":"chapterIncidentSeen","chapter":"detective"}
{"action":"chapterChoose","chapter":"detective","objective":"puzzle_5"}
{"action":"chapterDeduce","chapter":"detective","answer":"archive"}
{"action":"chapterLetterOpen","chapter":"detective"}
```

Hub shape:

```json
{
  "enabled":true,
  "chapters":[{
    "code":"detective",
    "voice":"detective",
    "state":"objective",
    "incidentSeen":true,
    "objectives":[
      {"code":"puzzle_5","metric":"puzzle_solve","target":5},
      {"code":"puzzle_streak_3","metric":"puzzle_streak","target":3}
    ],
    "chosen":{"code":"puzzle_5","progress":2,"target":5},
    "deduction":{"code":"detective_archive","attempts":0,"solved":false,
                 "options":["archive","courier","visitor"]},
    "reward":{"coins":0,"xp":100,
              "item":"frame_detective","title":"sahib_al_dalil"},
    "letterUnlocked":false,
    "letterOpened":false
  }]
}
```

Every mutation returns `{ok:true, hub:...}` or `{ok:false,code:...}`.

### Flag

`character_chapters_enabled`, capability `chapters`, default OFF.

### Doc 05

Only completed Casebook records, puzzle results, reunion/public/host facts and static fictional deductions are used. No objective references the player’s role or any live room.

### Screens

Legacy chapter shelf, chapter cover, incident scene, objective choice, progress scene, deduction, final letter, frame/title equip shortcut.

### Tests

Objective immutability, post-choice-only progress, one reward, pending XP, wrong deductions, no role metric, no private/live imports, four chapter completion paths.

## F4 — Investigation Desk

### Schema

```text
academy_lesson_catalog
  code, version, sort_order, coins, xp, step_count, active

academy_attempts
  id UUID PK, user_id, lesson_code, version, seed,
  step, wrong_answers, started_at, completed_at

academy_completions
  user_id, lesson_code, version, coins_claimed_at,
  season_xp_season_id
  PK(user_id,lesson_code,version)
```

The server issues the attempt and validates answer/action codes. The client renders the deterministic fictional fixture through pure engine structures. No bot chooses actions dynamically.

### Drills

1. **What the table knows**

   Interaction: drag eight fact cards into “public” or “mine only.”

   Examples include public morning outcome, public eliminated role, private investigation, private whisper body.

   Pass: all eight classified correctly. Wrong cards return; no permanent failure.

2. **The night resolves once**

   Interaction: as a fictional Doctor, select a legal protection; scripted Mafia and Detective actions then resolve. Arrange four event tiles into legal resolution order.

   Pass: accepted engine command plus correct event order. The morning card must contain only the generated public output.

3. **The ballot**

   Interaction: choose a living target, resolve a scripted tie, then choose whether the rule means revote or no elimination.

   Pass: legal ballot and correct configured tie consequence. The drill explicitly teaches that a vote does not reveal a role until the public reveal.

4. **Read the morning**

   Interaction: select every statement justified by a fictional public log and reject invented conclusions.

   Pass: exact supported set; selecting “the Doctor saved X” when only “nobody died” is public fails.

5. **Graduation case**

   Interaction: five deterministic steps—view own fictional role, perform one legal night action, read morning facts, select a supported argument, cast a legal vote.

   Pass: all commands legal and both final fact-interpretation questions correct. Winning is irrelevant.

### Actions

```json
{"action":"academyHub"}
{"action":"academyStart","lesson":"public_facts"}
{"action":"academyAnswer","attempt":"uuid","step":2,"answer":"public"}
```

Start response:

```json
{"ok":true,"attempt":"uuid","lesson":"public_facts","version":1,
 "seed":"opaque-fixture-id","step":0,"payload":{"fixture":"public_facts_03"}}
```

Answer response:

```json
{"ok":true,"correct":true,"complete":false,"next":{"step":1,"payload":{}}}
```

Final response adds:

```json
{"complete":true,"grant":{"coins":10,"xp":20},"hub":{}}
```

Rewards:

- Drills 1–4: 10 coins and 20 XP each.
- Graduation: 25 coins and 50 XP.
- Total: 65 coins/130 XP once per account/version.

### Flag

`academy_enabled`, default OFF.

### Doc 05

All people, roles and events are synthetic fixtures. The route cannot read current-room providers, histories or player seats. Academy imports are forbidden from real reveal/night/pass surfaces.

### Tests

Pure fixture determinism, legal engine actions, exact public/private classifications, invented-fact rejection, replayed answer idempotency, completion once/version, pending XP, import closure.

## F5 — Verdict Share Card

No gameplay tables or reward RPC.

Capability: `verdict_share_enabled`, root key `verdictShare`, default OFF.

Exports:

- `story`: 1080×1920.
- `feed`: 1080×1350.

Defaults:

- Room title OFF.
- Other player names OFF.
- Own display name optional.
- Winner side, day count, public awards, equipped title and Season level allowed.
- One deterministic narrator selected from public outcome/award state.
- Wordmark rendered in Flutter.
- No hidden logs, whisper bodies or private actions.

Screens: result share button, privacy/options sheet, generated preview, system share.

Tests: exact pixel dimensions; names/title absent by default; no export before public result; AR/EN long text; failed file/share handling; reduced motion.

## F6 — Scenario Deck and House Rules

### Canonical presets

| Code | Players | Duration | Core changes |
|---|---:|---:|---|
| `quick` | 5–8 | 15–25m | Existing Fast preset: 30s speech, 180s discussion, bullets off, victim role shown, pressure curve off |
| `classic` | 5–10 | 30–45m | Existing Classic preset |
| `big_table` | 10–15 | 45–70m | Classic rules, 30s speech, 300s discussion, pressure curve on |
| `no_mercy` | 8–12 | 25–40m | Existing Brutal shape: 30s speech, 120s discussion, no Doctor, no whispers, mid-discussion confrontation |

Whisper is shown as a separate modifier wherever the chosen preset permits it.

### Schema

```text
scenario_catalog
  code PK, version, min_players, max_players,
  estimated_min, estimated_max,
  settings JSONB, role_policy JSONB, active

house_rules
  id UUID PK, owner_id, share_code UNIQUE,
  version, settings JSONB, role_counts JSONB,
  fingerprint, created_at, revoked_at

house_rule_saves
  user_id, house_rule_id, saved_at
  PK(user_id,house_rule_id)
```

No server-side custom name or description. Users may keep a local-only label.

Rules:

- Maximum 10 active/saved rules per user.
- Maximum 10 creations/day.
- Resolve limit 30/hour/user.
- Settings payload ≤2 KB.
- Server allowlist and clamps win over client data.
- Mafia must be below half; total roles must equal capacity.
- Sharing never grants paid scenarios, cosmetics or presentation packs.
- Rules cannot change after a room starts.

### Edge actions/RPCs

Endpoint: `table_meta`.

```json
{"action":"scenarioCatalog","players":8}
```

```json
{"enabled":true,"presets":[{
 "code":"classic","version":1,"minPlayers":5,"maxPlayers":10,
 "duration":{"min":30,"max":45},
 "changes":["trace","whisper","bullets","pressure"],
 "settings":{},"rolePolicy":"quarter"
}]}
```

```json
{"action":"houseRuleCreate","settings":{},"roleCounts":{}}
```

Returns:

```json
{"ok":true,"id":"uuid","code":"7-char-code","fingerprint":"hex"}
```

Other actions:

```json
{"action":"houseRuleResolve","code":"ABCDEFG"}
{"action":"houseRuleSave","code":"ABCDEFG"}
{"action":"houseRuleDelete","id":"uuid"}
```

### Flags

- `scenario_deck_enabled`
- `house_rules_enabled`

Both default OFF.

### Doc 05

Selection and sharing happen before any deal. Settings are public to the full lobby and immutable after start. No role assignment or private state is read.

### Screens

Create-room scenario deck, modifier sheet, settings preview, House Rules library, share-code sheet, import preview, use-once/save choice.

### Tests

Preset parity between Dart and server fixture, every player-count boundary, hostile JSON, illegal role split, purchase bypass, share-code collision, owner deletion, import cap, post-start refusal, offline fallback.

## F7 — Series and Scenario Draft

### Schema

```text
match_series
  id UUID PK, code UNIQUE, host_id,
  mode(best_of_3|first_to_3), target_wins,
  status(draft|active|finished|abandoned|expired),
  selected_scenario, current_room_id,
  town_wins, mafia_wins,
  created_at, started_at, finished_at, expires_at

series_members
  series_id, user_id, joined_at, original_member
  PK(series_id,user_id)

series_draft_candidates
  series_id, scenario_code, sort_order
  PK(series_id,scenario_code)

series_draft_votes
  series_id, user_id, scenario_code, voted_at
  PK(series_id,user_id)

series_games
  series_id, ordinal, room_id UNIQUE,
  outcome(town|mafia), started_at, ended_at
  PK(series_id,ordinal)
```

### Rules

- Best-of-3: first to 2, maximum 3 games.
- First-to-3: maximum 5 games.
- Ends immediately when a side reaches target.
- Series expires after 8 hours.
- One active series/user.
- Maximum 10 series creations/day.
- Original roster locks when game 1 starts.
- Replacements may join later but are visibly marked; they do not rewrite prior receipts.
- At least five original members must remain to start a later game.
- Draft candidates are three canonical presets valid for the current player count.
- All joined original members may vote.
- Host can lock after everyone votes or after a 30-second lobby countdown.
- Tie-break: deterministic HMAC of `series_id + scenario_code`.
- Chosen scenario applies for the entire series.

### Actions

Endpoint: `series`.

```json
{"action":"seriesCreate","mode":"best_of_3","roomId":"uuid"}
{"action":"seriesState","series":"uuid"}
{"action":"seriesVote","series":"uuid","scenario":"classic"}
{"action":"seriesLockDraft","series":"uuid"}
{"action":"seriesNextRoom","series":"uuid","oldRoom":"uuid",
 "name":"...","gender":"..."}
{"action":"seriesAbandon","series":"uuid"}
```

State shape:

```json
{
 "enabled":true,
 "series":{"id":"uuid","code":"ABC123","mode":"best_of_3",
   "targetWins":2,"status":"active","town":1,"mafia":0,
   "game":2,"maxGames":3,"scenario":"classic","expiresAt":"..."},
 "draft":{"locked":true,"candidates":[
   {"code":"quick","votes":2},{"code":"classic","votes":4},
   {"code":"no_mercy","votes":1}
 ]},
 "games":[{"ordinal":1,"roomId":"uuid","outcome":"town"}]
}
```

Finished-room recording inserts `series_games` once by unique `room_id` and recomputes score transactionally.

### Flags

- `series_enabled`
- `scenario_draft_enabled`

Default OFF.

### Rewards

None beyond each constituent match.

### Doc 05

The draft closes before roles exist. The series stores only public final outcome, timestamps and membership. Score is shown only in lobby/result/menu surfaces.

### Screens

Series selector, lobby draft, vote state, lobby/result plaque, next-game action, series finale/share card.

### Tests

Concurrent votes, deterministic tie, duplicate result, rematch race, early finish, maximum games, expired series, host transfer, replacement marking, continuity minimum, no role/private columns, no live-score surface import.

## F9 — Thursday Night

### Schema

```text
weekly_events
  id, code, timezone='Africa/Cairo',
  weekday=4, start_local=20:00, end_local=01:00,
  scenario_code, xp_per_match=20, match_cap=2,
  starts_on, ends_on, active

event_match_receipts
  user_id, event_id, week, room_id,
  xp, created_at
  PK(user_id,event_id,week,room_id)

event_participation
  user_id, event_id, week, eligible_matches, stamp_unlocked_at
  PK(user_id,event_id,week)

event_global_progress
  event_id, week, eligible_matches
  PK(event_id,week)
```

### Rules

- Feature scenario visible throughout local Thursday.
- Bonus window is Thursday 20:00 through Friday 01:00 Cairo.
- Eligibility uses `rooms.started_at`, so a match begun before 01:00 remains eligible if it finishes correctly later.
- Requires the featured scenario.
- Reuses all Casebook eligibility/group caps.
- First two eligible matches grant 20 XP each.
- Maximum 40 XP/week.
- Second match unlocks the non-economic Thursday stamp.
- Community marker has five visual stages; no additional reward.

### Action

```json
{"action":"thursdayEvent"}
```

Response:

```json
{
 "enabled":true,
 "event":{"code":"thursday_night","featured":true,"bonusOpen":true,
   "scenario":"classic","startsAt":"...","endsAt":"..."},
 "mine":{"matches":1,"cap":2,"xpEarned":20,"stampUnlocked":false},
 "community":{"stage":3,"stages":5}
}
```

Progress is recorded automatically from the finished-result path.

### Flag

`thursday_event_enabled`, default OFF.

### Doc 05

Only server start time, final public outcome and scenario code are consumed. Nothing appears within a live match.

### Tests

Cairo DST boundaries, Thursday-to-Friday crossing, start-before/end-after window, wrong scenario, third-match cap, replayed room, same-group cap, inactive event, community increment once.

## Titles and showcase

### Schema

```text
title_catalog
  code PK, source, active, sort_order

player_titles
  user_id, title_code, unlocked_at
  PK(user_id,title_code)

player_showcase
  user_id PK, equipped_title_code, updated_at
```

Unlocks come transactionally from Season, chapters and achievements.

Actions:

```json
{"action":"titleHub"}
{"action":"titleEquip","code":"ayn_al_majlis"}
{"action":"titleEquip","code":null}
```

Response:

```json
{"enabled":true,"equipped":"ayn_al_majlis",
 "titles":[{"code":"ayn_al_majlis","source":"season_zero"}]}
```

Flag: `titles_enabled`, default OFF.

Surfaces: Casebook Legacy, Profile and pre-match lobby plate only. Explicitly absent from pass, role reveal, night, vote, live seats and private handoffs.

---

# 3. Success metrics and kill criteria

| Feature | Primary metrics | Healthy threshold after sufficient traffic | Review/kill signal |
|---|---|---|---|
| Overall | D1/D7/D28 return, crash-free sessions, first-open p95 | No regression from pre-1.1 baseline; crash-free ≥99.5% | >5% relative retention drop or launch p95 +20% |
| Casebook | Weekly open rate, ≥1 mission claim, level distribution | ≥35% of online actives open; ≥60% of openers claim | <15% open after 3 weeks |
| Season | Level 5/10/15/20 reach | Level 20: 10–30% of active participants | >40% means too fast; <5% means too slow |
| Daily Case | Open rate, solve rate, attempts, failure | ≥20% eligible DAU open; 55–85% solve | <45% solve: too hard; >90%: too trivial |
| Chapters | Start, objective split, completion | ≥35% start-to-finish; neither choice below 20% | <15% completion or one choice below 10% |
| Academy | Start/pass/retry/graduation | ≥65% drill completion; ≥40% graduation | >50% abandon inside drill 1 |
| Share | Export success and exports/finished match | ≥98% technical success; ≥3% export | <1% export after good exposure |
| Scenarios | Preset use, house rule creation/import/use | ≥25% created rooms use deck; ≥20% imports become rooms | Invalid-room rate >0.5% |
| Series | Start after rematch intent, completion, game-to-game loss | ≥20% adoption; ≥60% completion | >40% drop between games |
| Thursday | Eligible-user participation, first/second match | ≥10% of Thursday actives participate | Farming/group-cap anomalies or <3% after 4 weeks |
| Titles | Equip among owners | ≥30% equip at least one | No kill; simplify if <10% |

Events are allowlisted: `eligible_app_open`, `case_open`, `case_attempt`, `case_solved`, `case_failed`, `mission_hub_open`, `mission_claim`, `season_level_reached`, `chapter_started`, `chapter_completed`, `academy_started`, `academy_passed`, `share_exported`, `scenario_selected`, `house_rule_created`, `house_rule_imported`, `series_started`, `series_completed`, `series_dropped`, `thursday_match`, `title_equipped`.

---

# 4. Final asset manifest

Common style prefix:

> Premium hand-painted Egyptian noir mobile-game illustration; timeless contemporary Cairo; gouache and oil texture; near-black, oxblood and antique-gold palette; warm tungsten chiaroscuro; cinematic premium composition; no text, letters, numbers, logo, watermark or UI border.

Transparent figures add:

> Isolated on true transparent background, complete unframed silhouette, generous padding, soft irregular painted edge for feathering.

| Session | IDs | Size | Alpha | Prompt suffix |
|---|---|---:|---|---|
| S1 | `casebook_hero` | 1080×600 | No | Evidence wall, desk lamp, maps, red thread and sealed files; unreadable papers; dark lower fade |
| S1 | `season_zero_key` | 1080×1350 | No | Cairo rooftops at midnight; four canonical character silhouettes surrounding one illuminated table |
| S1 | `case_room_backdrop` | 1080² | No | Overhead circular interrogation table, seven empty chairs, single lamp, evidence shadows |
| S1 | `academy_hero` | 1080×600 | No | Investigation desk, face-down role cards, evidence tokens, blank chalk forms |
| S1 | `thursday_banner` | 1080×480 | No | Cairo coffee-house terrace on Thursday night, empty chairs around a glowing table |
| S1 | `chapter_letter_paper` | 1080×1350 | No | Blank aged folded letter under warm light, torn fibres, subtle stains |
| S2–S3 | `suspect_n01`–`suspect_n24` | 512² each | Yes | Distinct Egyptian/Arab adults, balanced genders/tones, ages 18–55, unique modern clothing and silhouette, neutral suspicious expression |
| S4 | `chapter_cover_detective` | 1080×1350 | No | Detective in cramped rainy office, incomplete file on desk |
| S4 | `chapter_cover_doctor` | 1080×1350 | No | Doctor at quiet clinic doorway before dawn, three sealed vials |
| S4 | `chapter_cover_mafia` | 1080×1350 | No | Mafia figure in café back room, forged black seal, overturned coffee |
| S4 | `chapter_cover_citizen` | 1080×1350 | No | Citizen beneath repaired street lantern, Cairo neighbours in distant silhouette |
| S4 | `chapter_seal_detective/doctor/mafia/citizen` | 384² | Yes | Wax seals: magnifier, medical lamp, black rose, street lantern |
| S4 | `frame_detective/doctor/mafia/citizen` | 1024² | Yes | Empty ornate portrait frames derived from each seal; no figure |
| S4 | `frame_season_zero` | 1024² | Yes | Empty oxblood wax-and-brass frame, restrained rooftop/council motifs |
| S4 | `academy_doctor_guide` | 768×1024 | Yes | Canonical Doctor standing calmly beside an unseen board, open teaching gesture |
| S5 | `academy_drill_public/night/vote/morning/graduation` | 720×480 | No | Respectively: separated fact cards; moonlit action tokens; ballot box; dawn evidence; sealed graduation file |
| S5 | `scenario_quick` | 720×960 | No | Pocket watch, short candle and compact empty table |
| S5 | `scenario_classic` | 720×960 | No | Balanced council chamber, four role motifs as objects |
| S5 | `scenario_big_table` | 720×960 | No | Long crowded-but-empty Cairo table under hanging lamps |
| S5 | `scenario_no_mercy` | 720×960 | No | Extinguished clinic lamp, cracked seal and severe council table |
| S6 | `case_share_story/feed` | 1080×1920 / 1080×1350 | No | Abstract evidence board with large empty result zone |
| S6 | `verdict_story/feed` | 1080×1920 / 1080×1350 | No | Torn case file with empty winner, award and narrator zones |
| S6 | `series_plaque` | 1024×512 | Yes | Empty antique brass score plaque with two balanced side fields |
| S6 | `series_trophy` | 512² | Yes | Council cup made from opposing neutral masks |
| S6 | `thursday_stamp` | 512² | Yes | Coffee-ring and crescent-night wax stamp; no religious calligraphy |

Reuse existing gallery portraits, council contract icons/rank tiers, coin art, outcome paintings, award badges, online spotlights/seat rings, victory emblems, onboarding art, role cards and `welcome_back_card.webp`.

---

# 5. Sound and motion

New synthesized cues:

- `casebook_wax_press`
- `casebook_paper_slide`
- `casebook_string_pluck`
- `casebook_level_sting`
- `case_accuse_gavel`
- `case_wrong_crack`
- `case_reveal_swell`
- `chapter_envelope_open`
- `chapter_seal_press`
- `academy_token_place`
- `academy_wrong_return`
- `academy_graduation`
- `share_paper_eject`
- `scenario_token_drop`
- `series_score_peg`
- `series_final_sting`
- `thursday_sting`
- `title_equip`

Reuse existing card flip for scenario fan and existing restrained win cue where appropriate. No speech.

Tokenized motion:

| Feature | Motion |
|---|---|
| Casebook | Page parallax, 180 ms wax press, 320 ms thread draw, milestone scene dissolve |
| Daily Case | 240 ms spotlight, 180 ms suspect fade, 280 ms clue-chain step |
| Chapters | 360 ms file opening, 180 ms seal press, 420 ms letter unfold |
| Academy | 220 ms token settle, 180 ms incorrect return, 600 ms graduation reveal |
| Share | 450 ms layered paper assembly; export itself static |
| Scenario | 320 ms card fan, 180 ms selected-card rise |
| Series | 220 ms score peg, 650 ms finale plaque |
| Thursday | 420 ms café-light reveal, 180 ms stamp |
| Titles | 180 ms seal rotation into place |

Reduced motion uses opacity-only transitions of approximately 120 ms, with no travel, rotation, scale burst, particle field or parallax.

---

# 6. Build order, ownership and gates

| Order | Work | Codex | Claude | Gate |
|---:|---|---:|---:|---|
| 0 | Owner economy decision; contracts and manifest freeze | 120m | 60m | Written approval; no implementation ambiguity |
| 1 | Art sessions S0–S6 | separate Terra/image session, 900m+ | review 120m | Dimensions, alpha, contact sheets, style approval |
| 2 | F2 generator/templates | 180m | 180m | 10-year uniqueness; SQL/edge; AR/EN widget and device |
| 3 | F1 activation/frame/milestones | 90m | 150m | Full Casebook SQL; claims; level-1 and level-20 UI |
| 4 | Economy adjustment, if approved | 120m | 60m | Replay/cap/concurrency/ad-step tests |
| 5 | F6 scenarios/House Rules | 240m | 300m | Settings parity; hostile payloads; offline and online room |
| 6 | F7 series/draft | 360m | 360m | Two-client series; concurrent voting/rematch; expiry |
| 7 | F3 chapters | 300m | 480m incl. copy | Four paths; purity; Arabic tone review; device |
| 8 | F4 Academy | 300m | 420m | Pure engine fixtures; server claims; all five drills |
| 9 | F5 share cards | — | 240m | Pixel sizes, privacy defaults, real Android share |
| 10 | F9 Thursday | 120m | 180m | Cairo DST/window tests; automatic finished-result record |
| 11 | Titles/showcase | 90m | 150m | Unlock/equip/idempotency; forbidden-surface import test |
| 12 | Aggregated metrics | 150m | 60m | No raw IDs/free text; receipt purge; allowlist |
| 13 | Final integration/performance/release candidate | 240m | 360m | SQL all; Node/Deno all; analyze; full Flutter suite; two devices; screenshots; offline/failure matrix |

Ownership:

- **Codex:** `supabase/migrations/**`, `supabase/functions/**`, `supabase/tests/**`, backend contracts, TS generators.
- **Claude:** `lib/**`, Dart `test/**`, ARBs/generated localization, `design_tokens.dart`, routing, `pubspec.yaml`, asset constants.
- **Image session:** `raw_assets/update11/**`, `assets/images/update11/**` only until acceptance.
- **Audio production:** `tool/generate_audio.py` and new `assets/audio/**`, scheduled so it cannot collide with Claude.
- Only Claude registers accepted assets in `pubspec.yaml`.

Every feature must pass its targeted gates before the next feature is merged; the final release additionally requires full suite, emulator/device screenshots, Arabic/English 360 px layouts, reduced motion, first-open performance, offline behaviour and all flags verified OFF.

## Remaining disputes

1. **Economy remains the only product decision requiring the owner.** I recommend option C above.
2. **Terra/imagegen availability is session-dependent.** The production session must verify the tool before work; the current external `codex exec` route is not available on this machine’s `PATH`.
3. **Server-side aggregate analytics cannot provide arbitrary user-level funnels.** The specified rotating daily HMAC gives deduplicated daily metrics without durable tracking; that privacy tradeoff is intentional.
4. **Proverb Bluff stays out of 1.1.** I would not trade Academy, Chapters, Series, or Scenario quality for it.

---

# Amendments — planning round 3 (agreed)

# Round 3 verdicts

## 1. Daily Case heuristics — AGREE, with stronger constraints

T1 becomes Sunday-only and never appears on consecutive days. It is a tutorial reset, not normal difficulty.

Generator acceptance constraints:

1. Exactly one logical solution.
2. Every clue eliminates at least one candidate still possible at that point.
3. Every clue is necessary: removing it leaves at least two solutions.
4. Define mention count as every suspect occurrence in `a`, `b`, `group`, or as a spatial anchor.
5. In every rolling 28-day window, the answer may be the unique most-mentioned suspect in at most 8 puzzles—28.6%, below the requested 30%.
6. In T3/T6, the answer must never be the unique most-mentioned suspect.
7. No suspect may exceed the answer’s mention count solely through meaningless redundant clues; decoy mentions must belong to necessary clues.
8. Circular templates are randomly rotated and reflected after construction.
9. Across each 84-day test window and table size, answer-seat frequencies differ by at most two.
10. Spatial anchors and answer direction must occur on both clockwise and anticlockwise sides.
11. Clue ordering may vary only when the progressive elimination chain remains valid.

Updated T3:

- Suspects: `s0=n11 … s5=n16`
- `in_group([s0,s2,s4])`
- `in_group([s1,s2,s4,s5])`
- `not_mafia(s4)`
- Answer: `s2`
- Chain: c1 removes s1/s3/s5; c2 removes s0; c3 removes s4.
- Mentions: answer s2=2; decoy s4=3.
- Removing any clue leaves multiple candidates.

Updated T6:

- Suspects: `s0=n08 … s6=n14`
- `in_group([s0,s1,s3,s4])`
- `in_group([s0,s2,s3,s4])`
- `in_group([s1,s2,s3,s4])`
- `not_mafia(s4)`
- Answer: `s3`
- Chain: c1 removes s2/s5/s6; c2 removes s1; c3 removes s0; c4 removes s4.
- Mentions: answer s3=3; decoy s4=4.
- Removing any clue leaves the answer plus one other candidate.

Schedule delta:

- Sunday: T1.
- Monday–Tuesday: T2 variants.
- Wednesday–Thursday: T3/T4.
- Friday: T5 with Mafia cover note.
- Saturday: T6.

## 2. Academy authority — CONCEDE

Client-side pure-engine drills are the better architecture. They work offline, respond instantly and do not justify an attempt protocol for 65 lifetime coins.

Revised server schema:

```text
academy_completions
  user_id, lesson_code, version,
  claimed_at, season_xp_season_id
  PK(user_id,lesson_code,version)
```

Actions:

```json
{"action":"academyStatus"}
{"action":"academyClaim","lesson":"public_facts","version":1}
```

Response:

```json
{"ok":true,"grant":{"coins":10,"xp":20},"status":{...}}
```

The two-minute account-age rule is only a bulk-account speed bump, not meaningful proof. Accept it, but completion remains saved locally and the claim is queued rather than showing failure. A legitimate new player never loses completion.

Local progress uses versioned SharedPreferences JSON. Server claims remain unique by lesson/version. Graduation pays 25/50; the other four pay 10/20.

Backend estimate falls from approximately 300 to 60 minutes.

## 3. Chapter deductions — AGREE

- Three distinct attempts.
- Correct answer completes normally.
- Third wrong answer completes as `assisted`, reveals the reasoning and unlocks the alternate “second look” letter line.
- Same cosmetic and 100 XP either way. Knowledge, not punishment, is the goal.
- No hard lock and no reduced reward.

Add:

```text
character_chapter_progress
  objective_changes smallint default 0 check <= 1
  deduction_outcome null|solved|assisted

chapter_deduction_attempts
  user_id, chapter_code, request_id UUID,
  answer_code, correct, created_at
  PK(user_id,chapter_code,request_id)
```

One objective change is allowed before deduction completion. Changing:

- Requires confirmation.
- Increments `objective_changes`.
- Replaces `objective_chosen_at`.
- Resets progress because progress is derived only from events after the new timestamp.
- Cannot be reversed again.

## 4. Information architecture — CHANGE slightly

The proposed hierarchy is strong. The main dangers are terminology collision and excessive nested sheets.

### Frozen IA

**Home**

- Pass-and-play remains the visual hero.
- One «الليلة» rail, maximum three cards:
  - «قضية اليوم»
  - «ملف القضايا» with ready count
  - «ليلة الخميس» only while relevant
- No Chapters, Academy, titles, store, series or notification cards added to Home.

**Online entry**

1. Friends strip—but hidden entirely when empty.
2. Large Create and Join actions.
3. Public rooms.
4. Compact Casebook line.
5. Create defaults to one-tap Classic. «اختار شكل الليلة» reveals Scenario Deck and series options.

Do not put Scenario Deck and series controls in front of a first-time player before Classic Create.

**Profile**

Titles, Four Dossiers, stats, account.

**Casebook Legacy**

Chapters, achievements, title collection/equipping and Thursday stamps.

**Academy**

- One dismissible offer after onboarding, not during it.
- Offer copy should mean “Try a training case,” not “You need lessons.”
- Permanent mode-screen entry: «اتعلّم في مكتب التحقيق».

### Sheet rule

Use modal sheets for secondary entry and short actions. Do not nest chains of sheets.

Chapters, Academy graduation, Scenario editing and multi-step deductions should use one full-height routed sheet with a stable header and internal pages. Otherwise Android back behaviour, keyboards and accessibility become confusing.

Likely first-time confusion:

- «قضية اليوم» and «ملف القضايا» sound nearly identical. Each needs a distinct visual verb/subtitle:
  - Daily Case: «حل لغز النهارده»
  - Casebook: «مهماتك وموسمك»
- “Series” should be «سهرة من 3» / «أول فريق يكسب 3», not untranslated competition language.
- House Rules must be behind «احفظ إعدادات القعدة», not presented as configuration jargon.
- An empty friends strip must not advertise that the player has no friends.

## 5. Guest progress — AGREE

For anonymous accounts only, show one contextual save-progress sheet when either:

- Season display level 3 is first reached, or
- The first chapter letter opens.

Whichever happens first consumes the once-per-season prompt.

Rules:

- Never interrupt the reward/letter animation.
- Show after returning to the Casebook hub.
- No banner, badge or repeated warning.
- Hide permanently for linked accounts.
- Persist `saveProgressPrompt:<seasonCode>` locally.
- Buttons: «احفظ التقدم» and «مش دلوقتي».
- Honest copy: «احفظ ملف قضاياك لو غيرت الموبايل أو مسحت اللعبة.»
- Never imply that linking is required to play.

## 6. Local notifications — RECOMMEND, owner decision #2

Recommend `flutter_local_notifications`, subject to owner approval.

Product rule:

- OFF by default.
- Offer once only after the player solves three Daily Cases on three separate days.
- User explicitly chooses an hour.
- Suggested time: 8:00 PM device-local time.
- Android notification permission is requested only after that opt-in.
- Maximum one notification/day.
- Cancel today’s notification immediately when the case is solved.
- Cancel all when the flag is disabled, the user opts out, or the account signs out.
- Recalculate on timezone/DST change.
- Never display while the app knows the player is inside a match.
- Tap opens the Daily Case through the normal Home/auth route.

Copy rules:

- No guilt, countdown, streak-loss threat or fake urgency.
- No coin amount.
- No suspect/player name.
- No live-match wording.
- One short Detective-authored line, rotated deterministically.

Examples:

- AR: «المحقق سايب لك قضية جديدة على المكتب.»
- AR: «قضية النهارده مستنياك… والدليل مش واضح زي ما باين.»
- EN: “The Detective left today’s case on your desk.”
- EN: “Today’s evidence is not as simple as it looks.”

Flag: `daily_case_reminders_enabled`, default OFF. This is a client capability plus local preference; no server push infrastructure.

## 7. Thursday independence — AGREE

Thursday must depend on canonical scenario resolution, not Scenario Deck UI.

Add to the event row:

```text
scenario_code
scenario_version
settings_fingerprint
```

At room start, store the normalized immutable settings fingerprint. Eligibility requires:

- `thursday_event_enabled`
- Match began inside the Cairo bonus window.
- Public finished result.
- Stored fingerprint equals the event’s canonical fingerprint.
- Normal Casebook eligibility.

The room qualifies whether launched through:

- Thursday banner,
- Scenario Deck,
- House Rule that normalizes identically,
- Manual settings that normalize identically.

When `scenario_deck_enabled=false`, the Thursday banner calls:

```json
{"action":"eventCreateRoom","event":"thursday_night", ...}
```

The server applies the canonical preset directly. The deck remains hidden; the event still works. Preset resolution is infrastructure, not UI capability.

## 8. Lobby titles — CONFIRMED

Title plate exists only in:

- Pre-deal online lobby.
- Profile/Casebook.
- Public post-result/finale surfaces.

It does not exist in distributing, handoff, role reveal, night, morning, opening, confrontation, discussion, vote, verdict transition or live seat widgets.

Proof requires three layers:

1. `LobbyPlayerPlate` lives in its own file and may import title state.
2. `LiveSeat` and all private-phase closures are forbidden from importing title/showcase providers.
3. A phase-matrix widget test pumps an equipped title through every phase and asserts `titlePlateKey` appears only in lobby/result.

Add golden equivalence tests: role-reveal and night screenshots with an equipped title must be pixel-identical to the same screens without one.

## 9. S0 image proof — ADD acceptance gates

Use these references:

- All four `gallery/gallery_*.webp` portraits.
- `home_backdrop.webp`.
- `council/leaderboard_header.webp` or `council_hub_tab.webp`.
- `canvas_texture.webp`.
- A generated flat palette swatch from design tokens: oxblood, antique gold, near-black, parchment and muted teal-neutral if present.

S0 should be one non-shipping 2×2 calibration board:

- Detective bust.
- Doctor bust.
- Café interior.
- Evidence desk.

Acceptance:

- Painterly gouache/oil texture—not photoreal, 3D-rendered, anime or comic-vector.
- Canonical Detective/Doctor remain recognisable beside gallery references.
- Face shape, age, hair, costume family and value pattern remain consistent.
- No cyan/magenta cast outside intentional tiny accents.
- Warm light and near-black remain readable at a 96 px thumbnail.
- No text-like marks, borders, frames or logos.
- Hands/anatomy valid.
- Environment perspective coherent.
- Featherable subject edges.
- Side-by-side grayscale and colour contact review.
- Human approval before S1; no “close enough” bulk generation.

## 10. Economy refinements

### Ads without reward — NEVER

Confirmed. A rewarded ad is never shown for zero coins or a non-economic placeholder.

After the sixth coin-eligible match that UTC day:

- Rewarded coin controls are absent.
- No SSV claim is created.
- No ad is loaded for that placement.
- UI may state once, outside the match result, that today’s match coin limit is reached—but should not repeatedly nag.

### First-match-of-day bonus — KEEP

Add +25 coins to the first eligible online finished match per UTC day.

Reasons:

- Helps casual players more than grinders.
- Gives one satisfying daily play reward.
- Maximum cost is 700 coins/28 days.
- It does not require an ad.
- It does not distort pass-and-play or invite farming.

Rules:

- Same ≥5-human, public-result, not-kicked eligibility.
- Unique ledger source `first_match_daily:<UTC-day>`.
- Wallet lock first.
- No pass-and-play grant.
- Not advertised as a streak.
- Result screen may show «أول قضية النهارده +25».

Revised committed ceiling rises by at most 700/month and remains acceptable under option C.

## 11. Top three remaining weaknesses

### 1. Trust and safety is still behind the social ambition

Friends, public rooms and voice can grow faster than moderation. Before broad marketing, the product still needs a clearly tested report/block flow, enforcement operations, evidence retention policy, Arabic moderation handling and an owner response procedure.

### 2. Content operations are migration-heavy

Seasons, chapter copy, Thursday schedules, Academy versions and puzzle templates need versioned catalogues and rollback—not emergency code releases. The update needs an operator runbook covering activation order, content correction, season extension, event cancellation and reward reconciliation.

### 3. “Preload everything” may hurt the exact devices we need

Loading all new portraits and heroes eagerly can increase first-open latency and memory pressure on low-end Android phones. Preload must mean staged warming:

1. Home-critical assets.
2. Current rail/card assets.
3. Next likely screen.
4. Remaining chapters/suspects while idle.

Set explicit compressed-size, decoded-memory and first-interaction budgets, then profile on a low-memory Android device and slow network. Never decode 24 suspect portraits at launch.

# Concrete frozen-spec deltas

- Add Daily Case anti-heuristic/property constraints and revised T3/T6.
- Replace Academy attempt backend with offline deterministic Dart fixtures plus idempotent claims.
- Add assisted chapter completion and one objective switch.
- Add the frozen IA above before implementing new screen entry points.
- Add anonymous-progress save prompt.
- Add optional local reminders as owner decision #2.
- Decouple Thursday’s canonical preset resolver from Scenario Deck visibility.
- Add lobby-title import-closure, phase-matrix and golden-equivalence tests.
- Add S0 calibration-board gate.
- Add first-match daily +25 and prohibit zero-reward ads.
- Add staged asset warming/performance budgets to the release gate.

# Updated build order

| Order | Work | Delta |
|---:|---|---|
| 0 | Owner decisions: economy option C; local notifications | Must precede economy/dependency edits |
| 1 | S0 calibration proof and asset manifest | Hard gate before S1–S6 |
| 2 | IA/navigation skeleton and capability surfaces | Moved ahead of feature UI; Claude +180m |
| 3 | F2 heuristic-safe generator and UI polish | Codex +60m for property generator/tests |
| 4 | F1 Season activation, frame and milestones | Unchanged |
| 5 | Economy rebalance + first-match bonus | Codex +30m |
| 6 | F6 canonical resolver, Scenario Deck, House Rules | Resolver explicitly independent of UI flag |
| 7 | F7 series and pre-deal Scenario Draft | Unchanged |
| 8 | F3 chapters | Codex +45m, Claude +30m for switch/assisted paths |
| 9 | F4 offline Academy | Codex −240m; Claude unchanged/slightly increased for local persistence |
| 10 | F5 private-by-default share cards | Unchanged |
| 11 | F9 Thursday event | Codex +30m for normalized fingerprint/event room creation |
| 12 | Titles plus strict surface-closure tests | Tests strengthened |
| 13 | Guest save-progress prompt | Claude +60m |
| 14 | Local reminders, if approved | Claude approximately 180m plus device permission tests |
| 15 | Metrics, staged preloading and full release gates | Add low-memory/slow-start profiling |

The plan is materially stronger after these deltas. The only unresolved decisions are economy authorization and whether local notifications—and their dependency—ship in 1.1.

---

# Amendments — planning round 4 (safety, operations, preload, table, launch)

## Round 4 verdict

The plan is now strong enough to build, but three launch blockers remain: block enforcement is incomplete outside friends, the current warm-up strategy does too much work before interaction, and the production rollout is incompatible with starting a fixed 28-day season early. The additions below close those gaps without creating a moderation empire or another game mode.

# A. Trust & Safety

## Existing foundation

KEEP:

- `player_blocks`, reports, deletion requests, RLS and service-role RPCs already exist in `20260920000200_player_safety.sql`.
- Reports require shared-room membership, are capped at 10/day, and resolve targets through room seats.
- `safety_center.dart` supports report, block, privacy and deletion.
- Voice is non-load-bearing; blocked voices and whispers are filtered.
- Friends already hide/refuse blocked relationships in `20260928000300_friends.sql`.
- Lobby and live-table safety entry points already exist.
- Lobby host handoff already exists in `20260914001100_lobby_departures.sql`.

## Must-close gaps

### 1. Blocks must be authoritative everywhere

Add a single security-definer helper:

```sql
safety_users_compatible(p_a uuid, p_b uuid) returns boolean
```

It returns false when either has blocked the other or either has an applicable online restriction.

Use it in:

- Friend requests and invitations.
- Direct room invitations and invite-link joins.
- Public-room listings.
- Quick-match selection.
- New public-room creation where relevant.
- Series membership and every next-room transition.
- Scenario-draft electorate construction.

Blocking also atomically removes:

- Existing friendship.
- Pending requests in both directions.
- Pending room invitations in both directions.

It must not identify who blocked whom. All join failures return `ROOM_UNAVAILABLE`.

A block created during an active match immediately mutes voice, reactions and whispers, but does not alter membership or expose the block. Future rooms and series rounds exclude the pair. Blocking in a pre-deal lobby offers the blocker a private “leave table” action; it must not prevent start in a way that tells the target they were blocked.

### 2. Server-side name rules

Create:

```text
safety_name_terms
- id
- locale_scope: ar | en | any
- normalized_term
- match_mode: exact | word | contains
- applies_to: player | room | both
- active
- created_at, updated_at
```

Normalize on the server: Unicode normalization, lowercase English, collapse spaces, remove Arabic diacritics/tatweel, and normalize `أإآ→ا`, `ى→ي`. Avoid aggressive transliteration that rejects innocent names.

Apply to display names and public room titles at every write path. Return only `NAME_NOT_ALLOWED`. The term list belongs in data, not Dart or edge-function code.

### 3. Contextual reporting

Add report entry points to:

- Lobby player menu.
- Public result roster.
- Friends sheet.

Categories:

```text
harassment, hate, sexual, threat, spam, cheating,
inappropriate_name, other
```

Extend reports with `context`, `status`, `public_snapshot`, `reviewed_at`, `reviewed_by`, `action_code`, and `action_note`.

Evidence may contain only public state: roster display names, room identifier, timestamp, public phase/result and public messages. Never store secret roles before public result, private actions, whispers, or voice recordings.

Limits:

- 10 reports/account/day.
- 2 reports against the same target/day.
- A duplicate reporter-target-room-context within 24 hours returns the existing receipt.
- 30 block operations/day and 500 active blocks.

Retention:

- Open/actioned report evidence: 180 days.
- Dismissed evidence: 90 days.
- Moderation audit metadata: 365 days, then anonymized aggregates.

### 4. Owner review that is actually usable

A SQL view alone is insufficient. Add a small Safety tab to the existing guarded admin surface:

- Queue filters: new, threat, name, repeated target.
- Public evidence preview.
- Actions: dismiss, warn/audit, restrict voice, restrict public rooms, suspend online.
- Durations: 1, 7 or 30 days; permanent only for online access.
- The owner never needs direct database editing for ordinary reports.

Tables/RPCs:

```text
player_restrictions
safety_admin_queue (view)
admin_safety_list(...)
admin_safety_resolve(report_id, action, duration, note, request_id)
purge_safety_evidence()
```

All admin actions require `commerce_admins`, are idempotent by `request_id`, and create immutable audit rows.

Tests must cover both-direction blocks across every surface, cleanup, generic errors, name normalization, report eligibility/limits, private-data exclusion, admin authorization, restriction expiry and evidence purge.

# B. Operator runbook

Create `docs/OPERATOR-RUNBOOK-1.1.md` with copy-pasteable verification, activation, incident and rollback commands. Every operation begins with a configuration snapshot and ends with capability/RPC smoke tests.

## Required operator RPCs

```text
operator_feature_snapshot()
operator_feature_set(flag, enabled, reason, request_id)
operator_season_activate(code, starts_at, request_id)
operator_season_extend(code, new_ends_at, reason, request_id)
operator_event_set(code, starts_at, ends_at, scenario_code, enabled, request_id)
operator_reward_reconcile_preview(source_kind, source_key, expected_amount)
operator_reward_reconcile_apply(..., reason, request_id)
```

All are service-role only, allowlist flags rather than dynamic column names, and write `operator_audit_log`.

Reward reconciliation:

- Locks wallets before ledger writes.
- Never touches purchased coins.
- Underpayment credits earned coins.
- Overpayment removes only currently available earned coins; spent excess is waived and audited, never converted into purchase debt.
- Existing source receipts remain immutable; reconciliation receives its own unique source key.

Puzzle salt is not stored in SQL. Use `CASE_PUZZLE_SALT_CURRENT`, `PREVIOUS`, and `EFFECTIVE_DAY`. Rotation must take effect on the next UTC day; today’s puzzle may never change mid-day.

## Launch activation order

After explicit owner approval only:

1. Deploy build, migrations and functions with every new capability OFF.
2. Verify backups, function versions, wallet totals and operator snapshot.
3. Enable `safety_v11_enabled` and server metrics.
4. Enable accounts/friends and character bonds.
5. Enable Council rank/contracts/leaderboard prerequisites.
6. Enable Scenario Deck and House Rules.
7. Enable Series, then Scenario Draft.
8. Enable Daily Case.
9. At 100% rollout, activate Season Zero, then enable Missions, Chapters, Titles and Academy.
10. Enable verdict sharing.
11. Rehearse Thursday privately; enable its event window only after verification.
12. Enable store products/daily economy.
13. Enable rewarded ads, then conservative interstitial/app-open/banner surfaces last.
14. Keep Android external-transfer payments OFF.

Each step waits at least 30 minutes or its minimum event sample before the next economy-affecting step.

Rollback is flag-first and non-destructive. Claims and ownership remain. Scenario/series shutdown refuses new creation; active games finish from their frozen settings. An emergency series pause preserves scores and expiry. Thursday receipts already earned remain valid.

Tests: service-role enforcement, request idempotency, illegal season shortening, bounded extension, event overlap, salt-day stability, reconciliation preview/apply parity, wallet locking, purchased-balance protection and audit immutability.

# C. Preload budgets

The current `AssetWarmup` reads essentially every asset and `WarmupGate` can block on it. Its signature hashes asset paths, not changed bytes. That is the wrong trade-off for low-memory phones.

## Revised stages

| Stage | Assets | Decoded budget | Timing |
|---|---|---:|---|
| 0 Core | launch backdrop/veil/mask, home backdrop, canvas texture | 12 MB | Blocking, hard stop at 1.2 s |
| 1 Home | current Home/Mode art, visible Tonight cards, current locale glyphs | +16 MB | Immediately after first frame |
| 2 Route | Either online lobby set, pass-and-play phase set, or Casebook set | +24 MB | Predicted route only |
| 3 Content | Puzzle suspects, chapters, scenario cards, store/share art | +12 MB per route | On demand |

Resident decoded image cache target: 48 MB. Stage 2 may evict unused Stage 1 art.

Performance gates on a 2–3 GB Android:

- First install: tappable Home p95 ≤2.5 seconds.
- Later launch: p95 ≤1.2 seconds.
- After update: p95 ≤1.8 seconds.
- Warm-up must never delay a tap beyond 1.5 seconds.
- Warm-up RSS increase ≤35 MB.

Behavior:

- First launch: block only for Stage 0; continue compressed reads in small background batches while idle.
- Later launch: no overlay; warm current Home and predicted route after first frame.
- Update: signature includes build number plus generated asset-content manifest hash. Rewarm only changed groups.
- Pause background reads when a match begins, the app backgrounds, thermal pressure rises, or memory pressure fires.

Daily Case decodes only today’s 5–7 portraits at 256 px—about 1.75 MB—not all 24. The selected portrait may upgrade for reveal. The chapter shelf loads four thumbnails; opening a chapter precaches its full cover plus the previous/next cover.

Web:

- Precache only the app shell and ≤8 MB compressed core art.
- Lazy-cache feature packs with versioned CacheStorage.
- Do not background-prefetch portraits, audio or store packs when `saveData` is on or the connection is slow.
- Audio loads metadata only until user interaction because of browser autoplay rules.

“Preload everything” should mean everything needed for the likely next interaction, not decode the entire catalogue. Full eager decoding would make the first launch worse and can trigger Android process eviction.

# D. The table

## 1. Lobby ready-up — KEEP, M

Add public, pre-deal-only readiness:

```text
room_players.lobby_ready
set_lobby_ready(room_id, ready)
```

Every seated connected player must be ready and at least five players must be present. The host then starts a three-second public countdown. Rule, preset, series or roster changes clear readiness; cosmetic/avatar changes do not. Away players cannot remain ready.

No readiness field exists after dealing. Test import closure plus snapshot schemas to prove it never reaches role reveal or live-seat state.

## 2. Host handoff — KEEP EXISTING, S hardening

The backend already hands the lobby to a connected, non-kicked player. Add a clear public lobby announcement and verify that room configuration and readiness survive. Do not rebuild the mechanism.

## 3. Reconnect experience — CHANGE, S/M

Keep the existing last-safe-snapshot and retry logic. Improve presentation:

- At 0–6 seconds: compact neutral connection strip.
- After 6 seconds: persistent generic reconnect surface.
- After 15 seconds: manual retry appears.
- Disable duplicate submissions while reconnecting.
- Never change wording or visual urgency by role or private phase.
- Never automatically abandon the table.

## 4. “One more?” vote — KEEP, M

At the public result only:

```text
room_rematch_votes(room_id, user_id, wants_rematch, updated_at)
```

Show only the yes count; no-votes remain private. For 30 seconds, eligibility is the connected non-kicked result roster. Threshold is `max(3, ceil(eligible × 0.6))`. On threshold, one atomic receipt creates the next room; the lowest-seat yes voter becomes host if the old host is gone. Scenario and series continuity are preserved. No rewards attach to voting.

## Other candidates

- Seat/avatar choice: LATER—weak value, extra concurrency and social jockeying.
- Ten-second character intro: CUT—repeated compulsory delay with no gameplay.
- Merge occupied quick-match rooms: CUT—current quick match already chooses the fullest compatible lobby; merging occupied rooms is disruptive. Add block compatibility and telemetry only.
- Public chronicle: LATER—safe after result if derived only from public facts, but authored deterministic storytelling deserves its own quality pass.

# E. Launch package

## Play “What’s new”

**Arabic**

> أكبر تحديث للمافيا حتى الآن: حل «قضية اليوم»، وتقدّم في ملف القضايا وموسم الصفر، وافتح حكايات الشخصيات الأربع. العب سهرات من عدة جولات، اختار السيناريو مع الترابيزة، واحفظ قواعد قعدتكم وشاركها. أضف أصحابك، ارجع للمباراة بسهولة، وتعلّم في مكتب التحقيق. تصميمات وصوتيات جديدة وتحسينات كبيرة للسرعة والأمان.

**English**

> Our biggest Mafia update yet. Solve the Case of the Day, progress through the Casebook and Season Zero, and uncover four character stories. Play multi-round table series, vote on scenarios, save and share House Rules, add friends, reconnect smoothly, and train in the Investigation Office. Includes new artwork, sound, performance and safety improvements.

## Eight screenshots

1. Home/table hero — “لمّ القعدة وابدأ القضية”
2. Online entry and friends — “ترابيزة مستنياك”
3. Painted lobby, ready-up and scenario — “الكل جاهز؟”
4. Daily Case suspect board — “قضية جديدة كل يوم”
5. Casebook season map — “كل سهرة تسيب أثر”
6. Character chapter and dossier — “الأربع شخصيات فاكرينك”
7. Series scoreboard/draft — “سهرة مش جولة واحدة”
8. Thursday event — “ليلة الخميس للمجلس”

Capture at 1080×1920. Captions stay outside UI-safe areas; no fabricated balances, players or unlocked rewards.

## Twenty-second trailer

- 0–2s: Cairo-night silhouette, wordmark, case-stamp hit.
- 2–5s: friends joining the painted table.
- 5–8s: rapid safe role-card montage.
- 8–11s: Daily Case clues and suspect selection.
- 11–14s: Casebook path and a character chapter reveal.
- 14–17s: Scenario Draft into series scoreboard.
- 17–19s: Thursday stamp and verdict share.
- 19–20s: “القضية بدأت” and store badge.

No speech; music, paper, stamp, card and table sounds only.

Share hooks are Daily Case completion, series finale, Season milestones, unlocked frame/title, Thursday stamp and verdict card. Chapter letters themselves are not shared because they are spoilers. Sharing is always explicit with a privacy-preview step.

## Staged rollout

Nothing begins until the owner explicitly authorizes publication.

- Internal, 48 hours: 20 complete sessions, zero leakage, zero wallet mismatches, all operator rollbacks rehearsed.
- Closed alpha, 3–5 days: ≥100 online matches and ≥10 completed series; crash-free ≥99.5%, ANR <0.5%, edge failures <1%.
- 10%, ≥48 hours/500 sessions: no P0/P1, first-interaction p95 ≤2.5s on low-end devices, match completion no worse than baseline by 5%, reward discrepancy zero.
- 50%, ≥72 hours/2,000 sessions: report queue within SLA, share success ≥98%, series completion ≥50%, Daily Case solve rate 45–90%, no abnormal faucet growth.
- 100%: only after at least seven stable production days so D7 and moderation load are visible.

Season Zero must start at 100%, not 10%. Earlier cohorts can test non-season features, but a global 28-day season cannot fairly lose several days for later rollout cohorts.

Launch-week community night: 5–10 Egyptian micro-creators and board-game communities, Thursday 20:30 Cairo, three hosted tables, two moderators, safety briefing, invite-link kit and a no-pay-to-win Daily Case/series challenge. No rewards for positive reviews.

# F. What was still wrong

1. Starting Season Zero during staged rollout was fundamentally unfair. It now starts only at 100%.
2. “All secondary flows are bottom sheets” remains too rigid. Multi-page chapters, Academy drills, safety review and complex Scenario Deck editing need full-screen routes; sheets are for entry, selection and confirmation.
3. Success metrics need minimum sample sizes. No feature is cut or retuned from tiny alpha data; retention decisions require at least 1,000 eligible users or two full weeks, whichever is later.

## Updated build order

| Order | Work | Codex | Claude |
|---:|---|---:|---:|
| 1 | Safety schema, compatibility checks, restrictions, reports, admin contract | 300m | 180m admin/client |
| 2 | Operator RPCs, audit and runbook | 240m | 45m capability/admin wiring |
| 3 | Staged warm-up, content signatures, performance instrumentation | 60m backend metrics | 300m client/web |
| 4 | Ready-up, rematch vote, host-handoff tests | 210m | 240m |
| 5 | Reconnect UX and table polish | — | 120m |
| 6 | Scenario Deck, House Rules, Series and Draft | 300m | 420m |
| 7 | Daily Case, Casebook/Season and economy activation | existing backend + 90m hardening | 360m |
| 8 | Chapters, Academy, titles, Thursday and sharing | 240m claims/events | 600m |
| 9 | Final art/audio integration and asset QA | image sessions | 300m integration |
| 10 | Full gates, device matrix, store media and rollout rehearsal | 180m | 300m |

Every stage gates on SQL/edge tests, Flutter analyze/full tests, Arabic 360 px widgets, low-end performance, server-surface permissions and the Doc 05 import-closure/leakage suite.
