# Mafia Master 1.1 — Final specification

This is the only current document. It replaces the amendment stack:
BRAINSTORM, MASTER-PLAN, SPEC (rounds 1–4) and ROUND5 (rounds 5–6) are kept
as history only. Where they disagree with this file, this file wins.

Authors: Claude (client, copy, integration) and Sol/Codex (backend, generators,
contracts). Owner approvals on record: local notifications dependency; economy
option C; "decide on merit, not taste".

Hard rules: Doc 05 wins every argument. Every new flag ships OFF. Nothing is
deployed, uploaded, published or enabled until the owner says so. Every feature
ships complete with its art, sound and motion, or it does not ship.

---

## 1. Product shape

| Pillar | Player feeling | 1.1 features |
|---|---|---|
| The Table | "a real night with my people" | Scenario Deck, House Rules, Series + Draft, ready-up, «ماتش كمان؟» vote, reconnect UX, Thursday Night |
| The Casebook | "a career as an investigator" | Missions (daily/weekly), Season Zero trail, achievements, titles |
| The Four | "they know me" | Four Dossiers (built), Character Chapters, season milestone scenes |
| The Daily Case | "one clever minute a day" | Case of the Day, share text, reminders |
| Learning | "I get it now" | «مكتب التحقيق» (Investigation Desk) |
| Trust | "I'm safe here" | Safety v11, name rules, owner review queue |

### Information architecture
- **Home:** pass-and-play is the hero. Below it, one «الليلة» rail with at most
  3 cards: «قضية اليوم» (subtitle «حل لغز النهارده»), «ملف القضايا»
  («مهماتك وموسمك», plus a ready count), and «ليلة الخميس» (only while
  relevant). Only cards whose data loaded appear. Offline, the rail disappears.
- **Online entry:** friends strip (hidden when empty), then large Create / Join,
  then public rooms, then a compact Casebook line. Create defaults to one-tap
  Classic. «اختار شكل الليلة» opens the Scenario Deck and series options.
- **Pass-and-play setup:** the same four canonical presets as painted cards,
  local only.
- **Profile:** titles, Four Dossiers, stats, account.
- **Casebook Legacy page:** chapters shelf, achievements, title collection and
  equip, Thursday stamps.
- **Academy:** one dismissible offer on a later Home return (never during the
  first session), plus a permanent entry on the mode screen
  («اتعلّم في مكتب التحقيق»).
- **Navigation rule:** sheets for entry, selection, preview and confirmation.
  Full-screen routes, with a painted rise transition and a persistent
  back/close header, for multi-page flows: chapters, Academy drills, scenario
  and house-rule editing, series draft, safety admin. No chains of sheets.
- **Words:** «سهرة من 3» / «أول فريق يكسب 3» (never "series"). «احفظ
  إعدادات القعدة» (never "house rules config").

---

## 2. Economy (option C) — authoritative

Switch: `economy_v11_enabled`, exposed as `economy.version=3`. The switch
changes match rewards, eligibility, ads and result copy **atomically**. Pending
ad claims settle at the amount stored when they were created. Balances,
purchases, inventory and Council XP are never altered or recalculated.

### Coin-eligible match
Finished room, public outcome, non-kicked seat, ≥5 humans. The first **6** per
user per UTC day. At most **3** per day with the identical 5+-player group
fingerprint. The same receipt governs coins, Season XP, Council XP, ads and
invites.

### Faucets
| Faucet | Coins | Season XP | Council XP | Limit |
|---|---:|---:|---:|---|
| Eligible match completion | 25 | 5 | 30 | 6/day; 3/same group |
| Win | 10 | +5 | +20 | same |
| First eligible match of the day | 25 | — | — | 1/day |
| Match ad step 1 / 2 | 25 / 25 | — | — | coin-eligible matches only |
| Daily mission `finish_1` | 5 | 25 | — | once |
| Daily mission `finish_3` | 10 | 40 | — | once |
| Other daily mission | 10 | 40 | — | once |
| All-three bonus | 10 | 25 | — | 1/day |
| Weekly mission | 75 | 180 | — | 1/week |
| Season track | 400 total | — | — | once/season |
| Case of the Day | 5 | 20 | — | 1/day |
| Chapter complete (×4) | 0 | 100 | — | once each (versioned) |
| Academy drill 1–4 / graduation | 10 / 25 | 20 / 50 | — | once per account/version |
| Thursday window | 0 | 20 | — | 2 matches/week |
| Achievements (6) | 25/50/100/75/75/50 | 50/100/200/150/150/100 | — | lifetime |
| Daily coffer; every 7th claim | 20; 60 | — | — | daily |
| Wheel (10/20/35/60/100 at 40/30/20/8/2%) | EV 23.8 | — | — | daily |
| Daily rewarded ad | 25 | — | — | daily |
| Extra wheel ad / extra coffer ad | wheel / +20 | — | — | daily |
| Contract-swap ad | 0 | — | — | daily |
| Council level | 25; every 5th 100; level 50 = 300 | — | — | 2,175 lifetime |
| Invitee | 50 | — | — | after first eligible match; once/account |
| Inviter | 100 | — | — | 5/season, 20 lifetime; conditions below |
| Match awards | **0** (flavour only) | — | — | — |
| Pass-and-play | 0 | 0 | 0 | bonds/dossiers only |

Committed recurring ceiling ≈ **19,500 coins / 28 days** (matches 5,740, ads
8,400, Casebook 1,820, Daily Case 140, daily system 3,393). Store prices are
unchanged (150–2,300).

### Anti-abuse
- Rewarded ads: 16/account/day and 20/install/day. The install id is random,
  stored as an HMAC and used only as a rate hint. No ad is ever shown without a
  reward. After the 6th coin-eligible match: no coin controls, no SSV claim, no
  ad load, and one line on that result only: «خلصت كوينز ماتشات النهارده ·
  التقدم لسه شغال». Rewarded ads are unavailable on web.
- Invites: the inviter's 100 settles only after the invitee has 3 eligible
  public matches over ≥2 UTC days, at least 1 without the inviter, 5 distinct
  non-inviter co-players, and an account age ≥48 h.
- New accounts (<24 h): may accept links, join invited rooms and invite
  accepted friends. They may not send unsolicited friend requests, appear in
  public discovery, or mass-create invitations.
- Council XP uses the same 6/day and 3/same-group caps (it was 20/day).

### Returning players
A one-time vault note, only for accounts with pre-1.1 match history:
«المكافآت اتظبطت عشان المتجر يفضل له قيمة؛ رصيدك زي ما هو». Achievements
unlocked on day one from old history grant their Season XP. The first Casebook
open says so once («إنجازاتك القديمة اتحسبت»).

---

## 3. Features

Every RPC is `security definer`, service-role only, and revoked by name from
`public, anon, authenticated`. Edge functions take the user from the verified
session. Every mutation is idempotent (unique source key or request id).
Responses are `{ok:true,…}` or `{ok:false,code}`.

### F1 Casebook + Season Zero (built; amendments)
- **Built:** `20260928000400_casebook.sql`, the economy actions, `lib/ui/missions/casebook_*`.
- **Amend:**
  - Season Zero is inactive until `operator_season_activate(code, starts_at)`
    sets `ends_at = starts_at + 28d`. A partial unique index enforces one active
    season. Activation happens only at 100% rollout.
  - Display level = `max(1, completed levels)`.
  - Match Season XP: 5 for completion, +5 for a win.
  - Level 20 grants `frame_season_zero` (reward-only item) and the title
    «حافظ الأسرار»; level 10 grants «عين المجلس».
  - Milestone scenes at levels 5 (Citizen), 10 (Detective), 15 (Mafia) and
    20 (Doctor): `season_milestones` and `season_milestone_views`, plus the
    action `seasonSceneSeen`.
  - **Season close:** progress freezes at `ends_at`. The next sync
    auto-grants every unlocked, unclaimed track reward (idempotent). The closed
    trail stays viewable 7 days. With no active season, the Season page shows
    the last season's Legacy and «الموسم الجاي قريب».
- **Season One:** not in 1.1. Its production brief is due by day 14 of Season
  Zero and its content pack by day 21 (live ops).
- **Tests:** inactive season grants nothing; activation is 28 days with no
  overlap and no backdating; display level; frame claimable once; auto-grant at
  close; milestone receipt idempotent; existing replay, cap and double-claim
  tests stay green.

### F2 Case of the Day (backend built; rework)
- **Generator — six templates:**
  - Sunday: T1 direct clearance, never on consecutive days.
  - Monday–Tuesday: T2 crossed shortlist.
  - Wednesday–Thursday: T3 overlapping circles / T4 cleared side.
  - Friday: T5 distance triangulation, with the Mafia's taunting cover note
    (`coverVoice:"mafia"`; flavour only, never a clue).
  - Saturday: T6 three-way lattice.
  - Worked examples are in SPEC round 2, with T3/T6 as revised in round 3.
- **Acceptance constraints:**
  - Exactly one solution. Every clue eliminates ≥1 candidate still possible,
    and every clue is necessary.
  - The answer is the unique most-mentioned suspect in ≤8 of any 28 days, and
    never in T3/T6. Decoy mentions come only from necessary clues.
  - Circular layouts are randomly rotated and reflected. Answer-seat frequency
    spreads to within 2 per 84 days. Anchors appear on both sides.
- **Solve idempotency:** `casePuzzleSolve {day, pick, requestId}`, unique on
  `(user, day, requestId)`. A replay returns the stored verdict.
- **Reward:** 5 coins / 20 XP every day. Three attempts. The reveal (answer +
  chain) comes only after a solve or the third failure.
- **Suspects:** 24 stable portraits (`n01…n24`). Only today's 5–7 are decoded,
  at 256 px.
- **Share:** text only, e.g. «قضية اليوم #N 🔍 ✅ في محاولتين 🔥5» plus an
  attempt grid. Web Share API with a copy fallback.
- **Reminders** (`daily_case_reminders_enabled`, Android only):
  - Offered once, after 3 solves on 3 separate days. Off by default. The user
    picks the hour (default suggestion 20:00 local).
  - The permission is requested only after opting in. A refusal suppresses the
    offer until the user reopens it from Settings.
  - ≤1 per day; today's is cancelled on solve; all are cancelled on opt-out,
    sign-out or kill switch. Rescheduled on timezone/DST change. Never shown
    while a match is active.
  - Copy is one Detective line, rotated. No guilt, no streak threat, no coins.
- **Tests:**
  - 10-year determinism and uniqueness; every template appears.
  - The constraint audits above; no reveal before solve or third failure.
  - Request-id replay; Friday voice never alters clues or reward; stable
    portrait mapping.
  - Reminder scheduling and cancellation.

### F3 Character Chapters (`character_chapters_enabled`, cap `chapters`)
- **Shape:** four authored chapters × 3 scenes: an incident, then a choice of
  two safe objectives, then a fictional deduction, then a final letter.
  Premises are in SPEC round 2 (Detective archive, Doctor vials, Mafia forged
  seal, Citizen lantern).
- **Objectives:** public metrics only: `puzzle_solve`, `puzzle_streak`,
  `finish`, `reunion`, `win`, `host`, `public_room`. No role metric, ever.
  - One objective change is allowed before the deduction. It needs
    confirmation, and progress restarts from the new choice time.
- **Deduction:** 3 attempts. A third miss completes as `assisted` with an
  explanation and an alternate «نظرة تانية» letter line. Same reward either
  way.
- **Reward:** 100 Season XP (pending if no season is active; applied once to
  the next season), the character frame and a chapter title. No coins.
- **Tables:**
  - `character_chapter_catalog`, `character_chapter_objectives`.
  - `character_chapter_progress`, including `objective_changes ≤ 1` and
    `deduction_outcome`.
  - `chapter_deduction_attempts`, keyed by request id.
- **Actions:** `chapterHub`, `chapterIncidentSeen`, `chapterChoose`,
  `chapterDeduce{requestId}`, `chapterLetterOpen`.
- **Copy:** Claude writes; Sol reviews. Detective dry, Doctor warm (not
  parental), Mafia controlled, Citizen grounded and quietly funny. No «يا
  معلم» clichés, no moral judgment of players.
- **Tests:** four completion paths, assisted path, objective switch, post-choice
  progress only, pending XP, and the purity/import closure.

### F4 Investigation Desk «مكتب التحقيق» (`academy_enabled`)
- **Drills:** four drills and a graduation case. Deterministic fictional
  fixtures run on the pure engine in Dart and work fully offline. Progress is
  stored in versioned local JSON.
  1. Public vs private facts: 8 cards to sort.
  2. Night resolution order.
  3. The ballot and the tie rule.
  4. Read the morning: pick the supported statements, reject invented ones.
  5. Graduation mini-case in 5 steps.
- **Accessibility:** tap-to-place as the alternative to drag.
- **Server:** `academyStatus`, and `academyClaim{lesson,version}`, idempotent
  per user/lesson/version. The account must be ≥2 min old. Claims queue while
  offline; completion is never lost.
- **Tests:** fixture determinism, legal engine commands, classification
  exactness, invented-fact rejection, claim idempotency, import closure (no
  live-room providers).

### F5 Verdict share card (`verdict_share_enabled`)
- **Formats:** story 1080×1920 and feed 1080×1350, rendered in Flutter
  (wordmark included).
- **Content:**
  - Always: winner side, days, public awards, the player's equipped title and
    season level, one deterministic narrator.
  - Off by default, per share: room title and table names («أسماء
    الترابيزة»).
  - Never: hidden logs, whispers or private actions.
- **Flow:** result screen, then options, then preview, then system share.
  Available only after the public result.
- **Tests:** pixel sizes, privacy defaults, AR/EN long text, failure handling,
  reduced motion.

### F6 Scenario Deck + House Rules (`scenario_deck_enabled`, `house_rules_enabled`)
- **Canonical presets:** `quick`, `classic`, `big_table`, `no_mercy` (table in
  SPEC round 2). Whisper is a separate modifier. Each preset shows player
  count, duration and a "what changes" preview. Shown in online create and in
  pass-and-play setup (local).
- **Resolver:** `scenario_catalog` plus a canonical resolver that normalizes
  settings to a fingerprint. It is infrastructure, independent of the UI flag.
- **House Rules:** `house_rules`, `house_rule_saves`. No server-side free-text
  name; a label is local only.
  - Limits: ≤10 saved/active, 10 creates/day, 30 resolves/hour, payload ≤2 KB.
  - Server clamps; Mafia below half; role sum equals capacity.
  - Sharing never grants paid content. Immutable after start.
- **Share link:** `…/rules/CODE`. The app route opens an import preview; import
  works without auth and saves locally until the user hosts. Android App Link
  plus web fallback.
- **Actions** (endpoint `table_meta`): `scenarioCatalog`, `houseRuleCreate`,
  `houseRuleResolve`, `houseRuleSave`, `houseRuleDelete`.
- **Tests:** Dart/server preset parity, player-count boundaries, hostile JSON,
  illegal splits, purchase bypass, code collision, caps, post-start refusal,
  offline fallback, link matrix.

### F7 Series «سهرة» + Scenario Draft (`series_enabled`, `scenario_draft_enabled`)
- **Modes:** best-of-3 (first to 2, ≤3 games) and first-to-3 (≤5 games).
  Ends early once decided.
- **Limits:** expires after 8 h; one active series per user; 10 creations/day.
- **Roster:** locks at game 1. Replacements are marked. Continuity needs ≥5
  originals.
- **Draft:** before the first deal, 3 canonical presets valid for the player
  count. Original members vote. The host locks after all votes or a 30 s
  countdown. Tie-break is an HMAC of `series_id + scenario_code`.
- **Tables:** `match_series`, `series_members`, `series_draft_candidates`,
  `series_draft_votes`, `series_games` (unique `room_id`, score recomputed
  transactionally).
- **Actions** (endpoint `series`): `seriesCreate`, `seriesState`,
  `seriesVote`, `seriesLockDraft`, `seriesNextRoom`, `seriesAbandon`.
- **Link:** `…/series/CODE`. The destination survives auth restoration,
  expires cleanly, passes block checks, and link previews carry no roster or
  title. A full, expired or blocked series offers Join public / Create, never
  a dead end.
- **Rewards:** none beyond constituent matches.
- **Doc 05:** only public outcomes, timestamps and membership are stored. The
  score is shown only in lobby, result and menu.
- **Tests:** two-client runs, concurrent votes, deterministic tie, duplicate
  result, rematch race, early finish, max games, expiry, host transfer,
  replacement marking, no live-surface import.

### F8 The Table — ready-up, «ماتش كمان؟» vote, reconnect
- **Ready-up** (`lobby_ready_enabled`):
  - `room_players.lobby_ready`, pre-deal only. Every seated connected player
    must be ready, with ≥5 present. The host starts a public 3 s countdown.
  - Rule, preset, series or roster changes create a new configuration
    revision and clear readiness.
  - Once ≥5 are ready, each unready seat gets **one** 45 s deadline per
    revision; toggling never restarts it. On expiry the seat returns to the
    room list with a neutral message.
  - The host starts explicitly; never auto-start.
  - Snapshot-schema and import-closure tests prove readiness never reaches a
    dealt state.
- **«ماتش كمان؟» vote** (`rematch_vote_enabled`):
  - `room_rematch_votes`, public result only. Only the yes count is shown.
  - The eligible roster is fixed for 30 s. The threshold is
    `max(3, ceil(eligible×0.6))`.
  - One atomic receipt, shared with the host's immediate rematch button, so
    nothing double-creates. If the old host is gone, the lowest-seat yes voter
    hosts. Scenario and series continuity are preserved.
- **Reconnect UX** (behaviour, no flag):
  - 0–6 s: compact neutral strip. After 6 s: persistent surface. After 15 s:
    manual retry.
  - Duplicate submissions are disabled while reconnecting.
  - Wording and urgency never vary by role or phase. Never auto-abandon.
- **Host handoff:** the existing mechanism, plus a public lobby line and tests
  that configuration survives.

### F9 Thursday Night «ليلة الخميس» (`thursday_event_enabled`)
- **Window:** `Africa/Cairo` with DST. The featured scenario is available all
  Thursday. Bonus window: Thursday 20:00 to Friday 01:00 Cairo, judged by
  `rooms.started_at`.
- **Eligibility:** the stored settings fingerprint equals the event's canonical
  fingerprint (whether reached via banner, deck, house rule or manual
  settings). All Casebook eligibility caps apply. First 2 eligible matches +20
  Season XP each (max 40/week), no coins. The 2nd unlocks the Thursday stamp.
  A community marker has 5 stages.
- **Non-featured rules in the window:** one lobby line «ليلة الخميس محسوبة على
  سيناريو الليلة بس» with the action «استخدم سيناريو الليلة».
- **Local time:** clients show countdowns in local time with "Cairo event"
  context; the server stays authoritative in Cairo time.
- **Flag off for the deck:** the banner calls `eventCreateRoom`.
- **Tables:** `weekly_events`, `event_match_receipts`, `event_participation`,
  `event_global_progress`. **Action:** `thursdayEvent`.
- **Tests:** DST boundaries, Thursday→Friday crossing, start-before/end-after,
  wrong scenario, cap, replay, group cap, community increment once.

### F10 Titles + showcase (`titles_enabled`)
- **Tables:** `title_catalog`, `player_titles`, `player_showcase`.
  **Actions:** `titleHub`, `titleEquip{code|null}`. Unlocks are transactional
  from season, chapters and achievements.
- **Where titles show:** only the pre-deal lobby plate (`LobbyPlayerPlate`, its
  own file), profile, Casebook, and the public result/finale.
- **Proof:** an import ban on live-seat and private-phase closures, a
  phase-matrix test, and golden equivalence (role reveal and night must be
  pixel-identical with and without an equipped title).
- **Art:** reuse the council seals; no generic ribbons.

### F11 Safety v11 (`safety_v11_enabled`; fails closed for public matchmaking)
- **Blocks everywhere:** `safety_users_compatible(a,b)` gates friends,
  invites, invite links, public listing, quick match, room creation, series
  membership and next room, and the draft electorate.
  - Blocking atomically removes friendship, pending requests and pending
    invites both ways.
  - Join failures are always `ROOM_UNAVAILABLE`, so a block is never revealed.
  - A block mid-match mutes voice, reactions and whispers only.
- **Names:** a `safety_name_terms` table (data, not code) with server-side
  Arabic/English normalization. It applies to display names and room titles
  and returns `NAME_NOT_ALLOWED`.
- **Reports:**
  - Entry from lobby, result and the friends sheet. Categories: harassment,
    hate, sexual, threat, spam, cheating, inappropriate_name, other.
  - The evidence snapshot is public state only.
  - Limits: 10/day, 2 per target/day, 24 h dedup.
  - Retention: 180/90 days; audit 365 days.
- **Owner queue:** a Safety tab in the guarded admin surface.
  - Filters: new, threat, name, repeated target.
  - Actions: dismiss, warn, restrict voice, restrict public rooms, suspend
    online (1/7/30 days; permanent only for online).
  - Idempotent by request id, with immutable audit rows.
- **Tests:** both-direction blocks on every surface, cleanup, generic errors,
  normalization, limits, private-data exclusion, admin auth, expiry, purge.

### F12 Operations
- **Operator RPCs (service role, allowlisted, audited):**
  `operator_feature_snapshot`, `operator_feature_set`,
  `operator_season_activate`, `operator_season_extend`, `operator_event_set`,
  `operator_reward_reconcile_preview` / `_apply`.
- **Reconciliation:** locks the wallet first and never touches purchased
  coins. Overpayment removes only available earned coins; the rest is waived
  and audited.
- **Puzzle salt:** `CASE_PUZZLE_SALT_CURRENT` / `_PREVIOUS` /
  `_EFFECTIVE_DAY`; a rotation takes effect from the next UTC day.
- **Runbook:** `docs/OPERATOR-RUNBOOK-1.1.md` with activation order, incident
  steps and per-feature rollback. Rollback is flag-first and non-destructive.

### F13 Metrics (`metrics_enabled`, server-only)
- **Tables:** `product_metric_daily` (aggregates) and `product_metric_receipts`
  (rotating daily HMAC subject, purged after 48 h). No UUID, name, room, voice
  or free text.
- **Collection:** allowlisted events via `metricRecord`. Server-owned events
  are counted inside their transactions.
- **Decisions:** thresholds and kill signals as in SPEC round 2 §3. No
  feature is retuned before 1,000 eligible users or two full weeks.

### F14 Performance — staged warm-up (behaviour)
- **Stages:**
  - Stage 0, blocking, ≤1.2 s: launch and Home core art (12 MB decoded).
  - Stage 1 after the first frame: Home and visible rail cards (+16 MB).
  - Stage 2: the predicted route (+24 MB).
  - Stage 3 on demand: suspects, chapters, scenario cards, share art (+12 MB
    per route).
  - Resident decoded cache ≤48 MB.
- **Pausing:** on match start, background, thermal or memory pressure.
- **Update signature:** build number plus an asset content hash; only changed
  groups are re-warmed.
- **Server warm-up:** real auth restore, capabilities and Home bootstrap in
  parallel with a non-blocking timeout. No fake warm-up traffic.
- **Web:**
  - Service worker precaches the shell plus ≤8 MB of core art.
  - After first interaction, a background pack fill of ≤25 MB per session up
    to 60 MB, then `StorageManager.estimate()` before continuing. Skipped on
    `saveData` or slow connections.
  - Safari quota/eviction is caught silently.
- **Gates on a 2–3 GB Android:** first install ≤2.5 s, later launch ≤1.2 s,
  after update ≤1.8 s, a tap never delayed >1.5 s, warm-up RSS ≤+35 MB.

### Guest progress
For anonymous accounts: one save-progress sheet per season, at display level 3
or the first chapter letter, whichever comes first. It appears after returning
to the hub and never interrupts a reward. Buttons: «احفظ التقدم» / «مش
دلوقتي». Copy: «احفظ ملف قضاياك لو غيرت الموبايل أو مسحت اللعبة».

### Links (owner ask: links open the app)
Routes `/join/`, `/invite/`, `/rules/`, `/series/` and the notification route
are covered by Android App Links and `assetlinks`. The web fallback preserves
the destination across auth. iOS/Safari always uses the web. An end-to-end
link matrix test is required.

---

## 4. Flags (complete)

**New in 1.1** (all OFF):
- Trust and data: `safety_v11_enabled` (cap `safety`), `metrics_enabled`
  (server-only), `economy_v11_enabled` (`economy.version=3`).
- Table: `lobby_ready_enabled`, `rematch_vote_enabled`,
  `scenario_deck_enabled`, `house_rules_enabled`, `series_enabled`,
  `scenario_draft_enabled`.
- Daily Case: `case_of_day_enabled`, `daily_case_reminders_enabled` (remote
  kill switch plus local opt-in).
- Casebook and friends: `missions_enabled` (plus operator season activation),
  `character_chapters_enabled`, `titles_enabled`.
- Others: `academy_enabled`, `verdict_share_enabled`, `thursday_event_enabled`
  (needs missions, an active season and the canonical resolver).

**Existing, still owner-controlled:** `friends_enabled`,
`character_bonds_enabled`, `ad_steps_enabled`, `daily_enabled`,
`daily_ad_enabled`, `ad_extras_enabled`, `interstitial_enabled`,
`pre_match_interstitial_enabled`, `pass_and_play_interstitial_enabled`,
`session_interstitial_enabled`, `app_open_enabled`, `banner_enabled`,
`council_contracts_enabled`, `council_rank_enabled`,
`council_leaderboard_enabled`, `council_invites_enabled`,
`starter_bundle_enabled`, `awards_enabled`, `reactions_enabled`,
`founder_enabled` (+ window), `transfer_enabled_web` (held until a real
transfer test), `transfer_enabled_android` (stays OFF), and each
`play_products.active`.

### Launch activation order (owner-approved day only)
1. Deploy with everything OFF; snapshot; verify backups and wallet totals.
2. Safety v11 + metrics.
3. Accounts/friends + bonds.
4. Council prerequisites.
5. Deck + House Rules.
6. Series, then Draft.
7. Case of the Day (+ reminders).
8. At 100% rollout only: activate Season Zero, then missions, chapters, titles,
   Academy.
9. Verdict share.
10. Thursday, rehearsed privately first.
11. Store products and the daily economy.
12. `economy_v11_enabled` together with rewarded ads.
13. Other ad surfaces, last and conservative.

Each step waits ≥30 min or its minimum sample.

---

## 5. Art, sound, motion

- **Style prefix (every image):** "Premium hand-painted Egyptian noir
  mobile-game illustration; timeless contemporary Cairo; gouache and oil
  texture; near-black, oxblood and antique-gold palette; warm tungsten
  chiaroscuro; cinematic premium composition; no text, letters, numbers, logo,
  watermark or UI border."
- **Transparent assets add:** "isolated on true transparent background,
  complete unframed silhouette, generous padding, soft irregular painted edge
  for feathering."
- **Tool:** a dedicated Codex session (`-m gpt-5.6-terra`, built-in
  `imagegen`); verified on 2026-09-28 with a `casebook_hero` proof. Outputs
  land in `~/.codex/generated_images/<thread>/`; each is copied immediately to
  `raw_assets/update11/<id>.png`.
- **Pipeline:** slice, then `tool/normalise_art.py`, then alpha/QA checks,
  then a 420 px contact sheet, then human approval. Only then does Claude
  register the files in `pubspec.yaml` and the constants.
- **Gate:** S0 is a calibration board (Detective bust, Doctor bust, café
  interior, evidence desk) with the round-3 acceptance criteria. Owner/Claude
  approval is required before S1.
- **Batches (each run just before its feature's UI):**

| Batch | Assets |
|---|---|
| S1 | `casebook_hero`, `season_zero_key`, `case_room_backdrop`, `academy_hero`, `thursday_banner`, `chapter_letter_paper` |
| S2–S3 | `suspect_n01…n24` (512², alpha; 2×2 sheets, then corrections) |
| S4 | 4 chapter covers, 4 seals, 4 character frames, `frame_season_zero`, `academy_doctor_guide`, 4 milestone scene inserts (`season_zero_05/10/15/20`) |
| S5 | 5 Academy drill covers, 4 scenario cards |
| S6 | `case_share_story/feed`, `verdict_story/feed`, `series_plaque`, `series_trophy`, `thursday_stamp` |

- **Reuse:** gallery portraits, council icons/ranks/seals, coin art, outcome
  paintings, award badges, seat rings/spotlight, victory emblems, onboarding
  art, `welcome_back_card.webp`.
- **Sounds** (synthesized with `tool/generate_audio.py`, no speech):
  `casebook_wax_press`, `casebook_paper_slide`, `casebook_string_pluck`,
  `casebook_level_sting`, `case_accuse_gavel`, `case_wrong_crack`,
  `case_reveal_swell`, `chapter_envelope_open`, `chapter_seal_press`,
  `academy_token_place`, `academy_wrong_return`, `academy_graduation`,
  `share_paper_eject`, `scenario_token_drop`, `series_score_peg`,
  `series_final_sting`, `thursday_sting`, `title_equip`, `lobby_ready_tick`.
- **Motion:** durations per SPEC round 2 §5. Reduced motion means
  opacity-only transitions of about 120 ms. Nothing varies by live role.

---

## 6. Build order (one list)
1. This contract frozen; reward simulation script; flag matrix.
2. Safety v11, operator RPCs, runbook, rollback rehearsal.
3. Link/auth foundation: `/rules`, `/series`, invite and notification routes.
4. IA skeleton, staged warm-up, metrics.
5. Economy C, ad/device caps, Council cap alignment, invite hardening, awards
   set to zero.
6. Title/frame inventory and equip.
7. Casebook amendments; Daily Case rework, UI and reminders.
8. Ready-up, rematch vote, reconnect.
9. Scenario Deck / House Rules, then Series / Draft.
10. Chapters, then Academy.
11. Share cards, then Thursday.
12. Art batches run just before each feature's UI (S0 gate first); audio
    alongside.
13. Full gates: SQL, edge, analyze, full Flutter suite, AR/EN at 360 px,
    reduced motion, device + Safari, safety, economy simulation, store media,
    rollout rehearsal.

**Ownership:**
- Codex: `supabase/**`, TS generators, contracts.
- Claude: `lib/**`, Dart tests, ARB/l10n, tokens, routing, `pubspec`, asset
  constants, copy.
- Art session: `raw_assets/update11/**` only.

## 7. Staged rollout (owner-triggered)
Internal (48 h) → closed alpha (3–5 d) → 10% → 50% → 100%, with the metric
gates from SPEC round 4 §E. Season Zero starts only at 100%.
