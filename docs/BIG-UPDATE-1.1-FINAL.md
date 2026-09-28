# Mafia Master 1.1 — authoritative product and release specification

Status: **frozen**. The owner answered every open decision on 2026-09-28 (§12), and the launch recut round closed the same day (Sol: "LAUNCH RECUT CLOSED").

This is the sole implementation and release contract for 1.1. Older brainstorm, round, audit and economics documents are historical evidence only; they cannot supply missing requirements or override this file.

## 0. Release constitution

Status: **frozen**.

- Doc 05 wins every disagreement. Nothing may reveal, imply or vary with another living player's hidden role, action or private information.
- One pure engine serves pass-and-play and online. Voice is never load-bearing. The app never invents a fact.
- Every new capability, campaign and catalogue row ships OFF/inactive. Nothing is deployed, published, uploaded or enabled until the owner explicitly authorizes it.
- A feature ships with final Arabic/English copy, approved art, sound, motion, accessibility, reduced-motion behavior, tests, observability and rollback—or it is cut from that build.
- Arabic uses 1.6 line height, zero letter spacing and text scale 1.0. Colors, dimensions and durations are tokens.
- During a match, narration never invents an event, cause, location, object, time, trace or action. Atmospheric fiction exists only after the public result, under «من حكايات الراوي», separate from the factual chronology.
- Paid entitlements are cosmetic or convenience-only. No power, hidden information, better odds, extra vote, extra attempt, matchmaking priority or role advantage is sold.
- Android and web expose the same rules and account progress. Platform-specific ad utilities may be absent on web without changing rewards earned by play.
- **Roles (owner, 2026-09-28):** Claude implements everything: client, SQL, edge functions, generators, tests, copy and asset registration. Sol critiques plans and generates images through its Codex session with a low-cost image model. Every plan is closed before any build starts.
- **The dead see everything (owner, 2026-09-23 and 2026-09-28).** Dead online players see every role, every night action (kill, protect, investigate, suspect) and, from L, every whisper with sender, recipient and full text (Witness v2). Living players never receive any of it. **Owner-accepted risk:** external messaging can carry that information from dead to living players. This is the owner's explicit grant of private knowledge to the dead; it changes nothing for the living, so Doc 05 still governs every living client.

1.1 is the **first public release**, not an update: listing, trailer and copy never say "update".

Release name: **The Night Has a Home / الليلة بقى لها بيت**. Public launch target is **Thursday 2026-10-29** (fallback **Thursday 2026-11-05**) at 16:00 Africa/Cairo; the launch-case finale is 20:00 and «ليلة الخميس» begins at 21:00. These are operator-set timestamps, never build-time assumptions.

## 1. Product shape and information architecture

Status: **frozen**.

| Pillar | Promise | 1.1 delivery |
|---|---|---|
| The Table | «قعدة بجد، مش مجرد ماتش» | reliable online core, ready-up, reconnect, rematch vote, Thursday Night |
| The Casebook | «كل سهرة بتسيب أثر» | daily/weekly missions, Season Zero, achievements, ranks, titles |
| The Four | «الشخصيات فاكراك» | dossiers, free Partner choice, chapters in 1.1.x, milestone scenes |
| Daily Case | «لغز ذكي حتى لو الشلة مش موجودة» | one global UTC puzzle, launch case, streak and share loop |
| Learning | «اتعلم باللعب» | Investigation Desk in 1.1.x |
| Trust | «ادخل روم من غير قلق» | blocks everywhere, reports, name rules and owner queue |

### Navigation

- **Home:** pass-and-play remains the hero. Beneath it is one «الليلة» rail with at most three painted cards: «قضية اليوم», «ملف القضايا» with ready count, and «ليلة الخميس» only while relevant. No instructional tips. If data is unavailable, the card disappears rather than becoming a dead end.
- **First open:** «شريكك إيه؟» is one tap among Detective, Doctor, Mafia and Citizen. It never blocks a pending invite/deep link; in that case it appears after the first public result.
- **Online:** friends strip, Create, Join, public rooms, then a compact Casebook line. Create defaults to one-tap Classic.
- **Profile:** equipped title, Four Dossiers, statistics and account.
- **Casebook:** Tonight, Season and Legacy. Legacy holds achievements, chapters, titles, dossiers and Thursday stamps.
- **Academy:** permanent «اتعلّم في مكتب التحقيق» mode entry. Its one-time invitation appears on a later Home return, is dismissible forever and never interrupts first-session play.
- **Secondary flows:** a 0.94-height sheet owns a nested Navigator, stable header, keyboard/focus handling and Android back behavior: pop inner page first, close sheet second. Safety administration alone is a full route.
- **Terminology:** «سهرة من 3», «أول فريق يكسب 3», «احفظ إعدادات القعدة»; never expose engineering words such as series/config.

### Empty and failure states

- Guest/offline users can always start pass-and-play. Online cards fail independently.
- No active season: show the last season for seven days and «الموسم الجاي قريب».
- Empty public rooms: «افتح أوضة وابعت للشلة» with Create and Share.
- Expired/full/blocked links: generic «الأوضة مش متاحة» plus Create/Join alternatives; never reveal a block.
- Every claim becomes a receipt state immediately; retries reuse its request ID.

## 2. Scope and launch-critical path

Status: **frozen**.

### Must exist at public launch L

The launch path is a **129-hour ceiling**, not a target to fill (launch recut, 2026-09-28).

**Date rule.** L is the first Thursday ≥ 7 days after Play production access **and** after every P0 gate passes: target **Oct 29**, fallback **Nov 5**. "Never move the date" applies only to removable features; online integrity, Doc 05, safety, RC stability or a store-access delay move L.

**The real critical path is Play, not code.** A personal account created after Nov 2023 keeps Production **and** Pre-registration locked until ≥ 12 testers stay opted in to the closed test for 14 continuous days, followed by Google's review of the production-access application. The 12 testers were not opted in on 2026-09-28. Closed-test builds may carry features while the clock runs; tester continuity must never be interrupted. Pre-registration therefore exists for only about one week before L.

**Merge rule.** Features merge only with their gates green until **Oct 19**; Oct 19–22 is integration only; the RC reaches the closed track by **Oct 22**. If Oct 19 arrives with incomplete non-P0 work, cut **F17 family mode first**, then the **Partner lobby embellishment** (the result signature stays). Never cut online integrity, Doc 05, safety, low-end stability or RC time.

| Order | Launch work | Hours | Gate |
|---:|---|---:|---|
| 1 | Online-core release blockers (§7) and Doc 05 payload/error hardening | 8 | targeted online/leakage suites ×3; chaos cases; publication allowlist |
| 2 | Safety v11 and owner review queue | 8 | block across every social surface; report retention/limits; review drill |
| 3 | F16 spoken narrator — the owner's «Kratos» voice | 18 | provenance + commercial-use record; silence in private phases; listener gate (≥ 9/12 natural and not cringe); noisy-room and tenth-match tests |
| 4 | Ready-up, reconnect, host continuity, hand-off reliability (existing rematch kept) | 6 | two-client races; process death; phase resume |
| 5 | Operator controls, metrics, warm-up, low-end performance, Install Referrer, Play in-app review | 13 | cold-start regression < 150 ms p95; raw referrer discarded; review remote-killable; low-end/web budgets |
| 6 | Economy v3, invite hardening, launch catalogue, entitlement provenance, **creator entitlement** | 10 | creator gets no automatic ads; rewarded stays opt-in; revoke and ordinary-user regression tests |
| 7 | Daily Case core, «القضية الأولى», reminder, `/case/today` | 9 | generator uniqueness; attempts/reveal; web route; opt-in reminder |
| 8 | F19 signature presentation (reveal, sonic mark, Partner in lobby/result) | 7 | result-only reveal; private/live import closure; asset-memory gate |
| 9 | Casebook, Season Zero, titles, core Partner | 10 | inactive-season behaviour; reward math; exact-once claims; Partner import closure |
| 10 | F15 big-table speed + F17 family mode + F16 tabletop layout | 9 | 10/15-player timed tests; immutable family setting; 2 m legibility |
| 11 | Witness v2: whisper contents for the dead | 6 | dead-only authorization; room isolation; masking/report tests (F21a) |
| 12 | Thursday, pass-and-play result inventory (P6), launch events | 6 | Cairo boundaries; eligibility; public-result-only placement |
| 13 | Required launch art and non-voice sound | 5 | alpha/crop/size/contact sheets; reduced motion; no private-role cue |
| 14 | Honest listing, captures, trailer | 5 | every depicted feature enabled in RC; no private or fabricated state |
| 15 | Full RC and device matrix | 9 | SQL/edge/analyze/full Flutter; two Android classes; Safari; offline; five-match soak |
|  | **Total** | **129** | |

Out of L (they keep their contracts below and ship later): F18 narrated how-to scenes (1.1.1), the rematch vote (the existing rematch stays), founder milestone automation, Daily Case streak-save and extra clue. The basic founder seal stays at L. **Viewer codes are deleted (owner, 2026-09-28), not parked.**

### Roadmap after L

Every row stays OFF until its full gates pass. A cut feature is absent from launch copy and screenshots; it is never shipped half-finished.

- **1.1.1 — Characters and competitive choice:** F18 narrated how-to scenes; Character Chapters + four chapter seals (no later than Season Zero day 21); F20 Thursday Partner letter; F21 witness-knowledge setting; F22 last words (if its atomic voice/witness gate passes); the lobby voice self-test.
- **1.1.2 — Learning and cast:** Investigation Desk; the Gang as Academy/example characters; streak-save only if missed-day cohort data justifies it; an extra narrator personality only after F16 fatigue data.
- **1.1.3 — Better tables:** Scenario Deck + House Rules, Series + Draft; family-pace preset; F23 same-room phones v0; table-face portraits after suspect-art consistency tests.
- **1.1.4 — The argument after the game:** verdict sharing; F24 match chronicle + «من حكايات الراوي»; F25 settled vote timeline; post-result reactions; session-scoped local evening score; Season One content.
- **Later 1.1.x:** additional scheduled nights (F26) only after density gates; founder milestone automation; the extra clue; the rematch vote; additional narrator packs; direct premium cosmetics (`mm_reaction_plate_pack_01`, `mm_table_scene_01`, `mm_dossier_set_01`, `mm_council_bundle_01`) with their art. Purchases are ≈$13.5/month per 1,000 active devices at middle, against a large art, catalogue and QA load.
- **1.2 — «قعدة من غير تمرير»:** the dedicated public-display Table Link v1; the authored «بروفة مع الشلة»; Partner content set 2; Proverb Bluff and safe party modifiers; voice reliability. No full bots until simulation benchmarks pass.
- **1.3 — Bigger public table:** public-snapshot big-screen; a delayed creator spectator pilot without chat; creator tooling; platform expansion.
- Full bots and experimental roles come later than 1.3. The Jester and a trial phase are rejected.

## 3. Economy, entitlements, ads and planning totals

Status: **frozen**.

### Economy v3 authority

`economy_v11_enabled` exposes `economy.version=3` and atomically changes reward amounts, eligibility, Council XP caps and result copy. Existing balances, inventory, entitlements and Council rank are preserved. Pending claims settle at the amount recorded when offered.

An eligible match is a finished online room with a public outcome, a non-kicked seat and at least five eligible humans. The cap is six/account/UTC day; at most three may share the same **normalized full eligible-human roster fingerprint** (sorted stable identifiers for every eligible human, then HMACed). One immutable match receipt drives coins, Season XP, Council XP, missions, Thursday and invites.

### Complete faucet table

| Source | Coins | Season XP | Council XP | Cap/condition |
|---|---:|---:|---:|---|
| Eligible completion | 25 | 5 | 30 | 6/day; 3/full-roster fingerprint |
| Win | 10 | +5 | +20 | same receipt/caps |
| First eligible match/day | 25 | — | — | once/day |
| Match rewarded step 1 / 2 | 25 / 25 | — | — | first 6 eligible matches |
| Daily `finish_1` | 5 | 25 | — | once/day |
| Daily `finish_3` | 10 | 40 | — | once/day |
| Third daily mission | 10 | 40 | — | once/day |
| All-three bonus | 10 | 25 | — | once/day |
| Weekly mission | 75 | 180 | — | once/week |
| Season free track | 400 total | — | — | levels 2/5/8/11/14/17/19/20 = 25/50/50/50/75/50/50/50 |
| Daily Case | 5 | 20 | — | first solve/day; assisted same |
| Character chapter | 0 | 100 | — | four lifetime/versioned |
| Academy drills 1–4 | 10 each | 20 each | — | once/account/version |
| Academy graduation | 25 | 50 | — | once/account/version |
| Thursday | 0 | 20 | — | first 2 eligible/week |
| Six achievements | 25/50/100/75/75/50 | 50/100/200/150/150/100 | — | lifetime |
| Daily coffer | 20; every 7th 60 | — | — | claim count, not streak |
| Wheel | 10/20/35/60/100 at 40/30/20/8/2% | — | — | once/day; EV 23.8 |
| Daily rewarded ad | 25 | — | — | once/day |
| Extra wheel / coffer | wheel / 20 | — | — | once each/day |
| Contract swap | 0 | — | — | once/day |
| Council level | 25; every 5th 100; level 50 = 300 | — | — | 2,175 lifetime |
| Invitee | 50 | — | — | first eligible match; once/account |
| Inviter stage 1 / settlement | 25 / 75 | — | — | conditions below |
| Awards | 0 | — | — | flavour only |
| Pass-and-play match | 0 | 0 | 0 | dossiers only |

Expected earnings for a highly active 50%-win player is about **19,500 coins/28 days**. The prior hard recurring maximum was about 24,600; the higher invite cap raises it to about **25,100**, excluding lifetime rewards and one-time founder grants. The 500-coin difference is acquisition-only and requires ten fully settled invitees.

### Invite settlement

- Invitee receives 50 after the first eligible match.
- Inviter receives 25 then, and 75 after the invitee completes three eligible matches across at least two UTC days, at least one without the inviter, five distinct non-inviter co-players, and account age ≥48h.
- Cap ten settled/season and forty/lifetime. Three unlock «كبير الشلة»; ten unlock the invite frame.
- Finish locks invite progress and wallet, uses unique source keys, and emits «{name} لعب أول ماتش — خدت ٢٥ عملة» plus «صاحبك لعب ١ من ٣».

### Ad policy

- Rewarded cap: 16/account/day and 20/install/day. The 16 are 12 match offers, daily ad, extra wheel, extra coffer and contract swap. Puzzle streak-save/extra-clue ads also consume 16; using one can displace a coin-bearing offer.
- Automatic full-screen: two/day shared with app-open, 20-minute gap, ≥5 minutes after rewarded. First two lifetime online matches and first eligible match/day are free. App-open ≤1/day after eight hours away.
- Automatic ads occur only after leaving a fully revealed public result; pass-and-play ≤1/session. Never before roles carousel, between series rounds, during hand-off/reveal/live play/reconnect, inside puzzle/chapter/Academy, or over purchase flow.
- Online pre-match and pass-and-play pre-deal remain OFF. No lobby/table banner; banners only on room list, history, profile and vault waiting surfaces.
- After eligible match six, hide match rewarded offers. Never show an ad without promised reward/utility.
- Quiet Pass, EGP 199.99, permanently removes automatic ads; optional rewarded remain.
- Rewrite the privacy and ad disclosures to match exactly what 1.1 does.

### Catalogue and entitlements

| Product ID | Price | Entitlement/content | Availability |
|---|---:|---|---|
| `mm_coins_3000` | EGP 49.99 | 3,000 coins | launch |
| `mm_coins_7500` | EGP 99.99 | 7,500 coins | launch |
| `mm_coins_16000` | EGP 180.00 | 16,000 coins | launch |
| `mm_starter_bundle_v11` | EGP 29.99 | 2,000 coins, Council Seal frame, candle/table accent, three reactions | once/account |
| `mm_remove_interruptions` | EGP 199.99 | permanent Quiet Pass | launch |
| `mm_season_pass_s0_launch` | EGP 59.99 | Season Zero premium track | L through L+14 |
| `mm_season_pass_s0` | EGP 79.99 | same Season Zero entitlement | after L+14 |
| `mm_reaction_plate_pack_01` | EGP 19.99 | reactions + nameplate | 1.1.x |
| `mm_table_scene_01` | EGP 39.99 | shared public table scene | 1.1.x |
| `mm_dossier_set_01` | EGP 49.99 | four dossier/profile treatments | 1.1.x |
| `mm_council_bundle_01` | EGP 119.99 | premium Council cosmetic set | 1.1.x |

Starter appears after three eligible matches or deliberate store open, without countdown. Old item prices remain. New earnable sinks: reactions 600–1,200; nameplates 1,000–2,500; table ambience 2,500–5,000; narrator presentation 4,000–8,000; bundles 7,500–12,000. No second premium currency, randomized paid item, cash-out, trading, paid streak repair or paid puzzle attempt.

Season Pass grants no currency, XP or level. Premium levels: 1 nameplate; 3 four reactions; 5 Detective outfit; 7 table scene; 10 title+seal; 12 Doctor outfit; 15 Mafia outfit; 17 Citizen outfit; 20 premium frame+public-result flourish. Late purchase retro-unlocks earned levels. Revocation removes only pass-sourced cosmetics, safely unequips, preserves free rewards and never creates coin debt. Ownership is source-provenanced and exact-once.

### Egypt-only planning bands

Unit: **active devices/day**, not people. Base composition: 60% local-table devices, 25% online-only, 15% mixed; replace after two weeks. eCPM planning: rewarded $0.8/$1.5/$2.4, automatic $0.35/$0.75/$1.3, banner $0.03/$0.08/$0.10; realized fill 50%/70%/85%. Ramadan is upside sensitivity only.

| Active devices/day | Ads/month low / middle / high (EGP) | In-app purchases expected low / middle / high (EGP) | Tiny-cohort median |
|---:|---:|---:|---:|
| 10 | 6 / 29 / 78 | 0 / 7 / 23 | 0 purchases |
| 100 | 56 / 290 / 777 | 0 / 68 / 225 | usually 0–1 |
| 1,000 | 557 / 2,895 / 7,765 | 0 / 675 / 2,250 | cohort-dependent |
| 10,000 | 5,570 / 28,950 / 77,650 | 0 / 6,750 / 22,500 | measurable |

The month-one objective is **income from the game ≥ $100 (ads + in-app purchases, as totals)**. It is a target, not a forecast. At middle, 1,000 active devices/day give ≈$58 in ads + ≈$13.5 in purchases, so the target needs ≈1,400 active devices/day. **Ads alone ≥ $100** is the stretch line: ≈1,730 devices/day at middle, ≈9,000 at low. Any Gulf uplift is reported as a separate, labelled line and is never folded into the Egypt baseline. “Minimum infrastructure coverage” is the label for the earlier 600–700-device estimate; full operating break-even is higher due to support, moderation, creative work, observability and voice/egress. The 12-month model is monthly totals ×12 with no assumed growth; report ads and in-app purchases separately, expected and actual. Membership remains 1.2 and needs three finished months of content before launch.

## 4. Feature contracts

Status: **frozen**.

Common: privileged RPCs are `security definer`, service-role only and revoked from `public`, `anon`, `authenticated`. Edge derives account from verified session. Mutations accept `requestId`; receipts replay original response. Errors are `{ok:false,code,requestId}` without database text or secrets.

Canonical response envelopes are exact and additive-only within 1.1:

```json
{"ok":true,"requestId":"uuid","grant":{"coins":0,"xp":0},"state":{}}
{"ok":false,"requestId":"uuid","code":"DISABLED|NOT_READY|ALREADY_CLAIMED|BAD_REQUEST|RATE_LIMITED|ROOM_UNAVAILABLE"}
```

Hub/read actions return `{enabled:false}` on a disabled/failed capability and otherwise these feature roots: `missionHub → {enabled,season,daily,weekly,achievements,rank}`; `casePuzzle → {enabled,day,attempts,maxAttempts,solved,failed,streak,bestStreak,reward,puzzle,reveal?}`; `chapterHub → {enabled,chapters[]}`; `academyStatus → {enabled,lessons[]}`; `titleHub → {enabled,equipped,titles[]}`; `seriesState → {enabled,series,draft,games[]}`; `thursdayEvent → {enabled,event,progress,community}`. Mutation success returns the same fresh root under `state` so the client never performs a second read. Unknown fields are ignored by old clients; required fields are never renamed inside 1.1.

### F1 — «ملف القضايا» / Casebook and Season Zero

**Tables:** existing `mission_seasons`, `mission_catalog(voice)`, Council daily contracts, `season_xp_events`, reward catalog/claims and achievements; add `season_milestones(season_id,level,scene_code,voice)` and `season_milestone_views(user_id,season_id,level,seen_at)`. Season Zero seeds inactive; at most one active.

**Actions:** `missionHub`; `missionClaim{layer,period,slot,requestId}`; `seasonClaim{season,level,requestId}`; `achievementClaim{code,requestId}`; `seasonSceneSeen{season,level,requestId}`. Hub returns season dates/XP/displayLevel/rewards/milestones, daily/weekly missions, achievements and rank. Claims return grant + fresh hub.

**Rules:** explicit operator start, exactly 28 days. Display starts at level 1 without level-1 grant. Level 10 «عين المجلس»; level 20 `frame_season_zero` + «حافظ الأسرار». Scenes: 5 Citizen, 10 Detective, 15 Mafia, 20 Doctor. End freezes and auto-grants unlocked track rewards on next sync, exact-once; trail remains seven days. Season One is a content-build release: brief day 14, finished pack day 21.

**Gate:** inactive/overlap/backdate/28-day/XP/display/claim/replay/close/milestone/cap tests; SQL+edge+360px AR/EN+device.

### F2 — «قضية اليوم» / Daily Case

One deterministic UTC puzzle from day + secret salt only. It never reads rooms, matches, roles or players. Five–seven suspects use stable keys `n01…n24`; exactly one fictional Mafia. Detective is authority; Friday Mafia cover is flavour only.

**Semantics:** `not_mafia(a)` excludes a; `one_of(a,b)` confines the sole Mafia to a/b; `in_group(G)` confines to G; `outside_group(G)` excludes G; `next_to(a)` means either circular neighbor; `not_next_to(a)` excludes both; `distance(a,k)` means exactly k circular edges.

**Six worked templates:**

1. **T1 Direct clearance, difficulty 1, Sunday only.** `s0=n01…s4=n05`; `not_mafia(s0)`, `(s1)`, `(s2)`, `(s3)`; answer `s4`; chain removes s0/s1/s2/s3. Never consecutive.
2. **T2 Crossed shortlist, difficulty 1, Mon–Tue.** `s0=n06…s4=n10`; `one_of(s1,s3)`, `not_mafia(s1)`; answer `s3`; chain removes s0/s2/s4 then s1.
3. **T3 Overlapping circles, difficulty 2, Wed–Thu.** `s0=n11…s5=n16`; `in_group([s0,s2,s4])`; `in_group([s1,s2,s4,s5])`; `not_mafia(s4)`; answer `s2`. Chain removes s1/s3/s5, then s0, then s4. Answer two mentions; decoy s4 three; every clue necessary.
4. **T4 Cleared side, difficulty 2, Wed–Thu.** `s0=n17…s5=n22`; `outside_group([s0,s1,s2])`; `next_to(s0)`; answer `s5`; chain removes s0/s1/s2 then s3/s4.
5. **T5 Distance triangulation, difficulty 3, Friday.** `s0=n01…s6=n07`; `distance(s0,2)`; `not_next_to(s3)`; answer `s5`; first leaves s2/s5, second removes s2. Mafia cover never affects clues.
6. **T6 Three-way lattice, difficulty 3, Saturday.** `s0=n08…s6=n14`; `in_group([s0,s1,s3,s4])`; `in_group([s0,s2,s3,s4])`; `in_group([s1,s2,s3,s4])`; `not_mafia(s4)`; answer `s3`. Chain removes s2/s5/s6, then s1, then s0, then s4. Answer three mentions; decoy s4 four; removing any clue leaves ≥2.

**Constraints:** unique solution; each clue eliminates a still-possible suspect and is necessary; answer uniquely most-mentioned ≤8/28 days and never T3/T6; decoys arise only from necessary clues; circular boards rotate/reflect; answer-seat spread within two over 84 days/table size; anchors on both sides; ordering forms a progressive chain.

**Tables/actions:** attempt receipt unique `(user,day,request_id)`. `casePuzzle{}` returns day, attempts, streak, reward, template, difficulty, suspects/clues; reveal only after solve/third fail. `casePuzzleSolve{day,pick,requestId}` returns verdict, grant and state. Three attempts; 5 coins +20 XP once.

**Launch case:** `case_special_days(day,code,available_from,reveal_at,template_seed,active)`. Expose nothing before `available_from`; normal personal reveal after solve/fail; campaign finale at `reveal_at`. Solve rate only at ≥50 solves, rounded to 5%. Founder lore never changes solvability.

**Assists:** `case_puzzle_assists(user,day,kind,granted_at,source_receipt)` unique day/kind. `caseStreakSave{day,requestId}` restores one missed day within 24h, once/rolling 7 days. `caseExtraClue{day,requestId}` after first wrong deterministically eliminates a non-answer, once/day. Both need completed rewarded receipt, consume global cap, are absent on web and grant no currency. Assisted metrics separate; share marks 🟨. Reminder offered after first solve: opt-in then permission, default 20:00 local, ≤1/day, cancel on solve/opt-out/sign-out/kill, reschedule DST/timezone, never live-match; copy «المحقق سايب لك ملف على المكتب.»

**Gate:** ten-year uniqueness/determinism/necessity/anti-heuristics, templates, reveal/request/day/assist/ad caps, no room imports, reminder lifecycle, `/case/today` Android/web, 24 portraits, device/Safari.

### F3 — Four Character Chapters (1.1.1)

Tables: chapter catalog/objectives/progress (chosen time, one change, outcome) and request-keyed deduction attempts. Only post-choice events count. One change resets progress. Three deduction attempts; third miss completes `assisted`, same reward, changed line. Inactive-season 100 XP waits once for next season.

| Character | Premise + scene 1 | Scene 2 objectives | Scene 3 deduction | Final letter beat |
|---|---|---|---|---|
| Detective | Last page vanished from archive; establish stamp, sealed courier envelope, visitor timing. | Solve 5 Daily Cases **or** 3-day solve streak. | Clerk/courier/visitor: archive ink matches torn stub; envelope sealed; visitor late → clerk. | Patience/verification over guesses; assisted line honors a second look. |
| Doctor | Three sealed vials after crowded clinic; arrival order, seal colors, opened cabinet. | Finish 5 eligible **or** 2 reunion matches. | Only one vial fits morning patient arrival/seal/cabinet access. | Trust is staying when the room is difficult; help is responsible, not lesser. |
| Mafia | Copied black seal sent an invitation; wax heat, cup position, back-door timing. | Win 3 eligible **or** host 2 eligible. | Owner/messenger/late guest: only owner had warm wax before door opened → owner. | Guarded respect for noticing the overlooked; persistence on assisted path. |
| Citizen | Lantern returned with different glass; sightings, repair time, receipt. | Finish 3 public-room **or** 2 reunion matches. | Receipt/timing exclude watchman and seller → neighbor. | Belonging comes from returning; assisted line values asking together. |

Actions: `chapterHub`, `chapterIncidentSeen{chapter,requestId}`, `chapterChoose{chapter,objective,replace,requestId}`, `chapterDeduce{chapter,answer,requestId}`, `chapterLetterOpen{chapter,requestId}`. Reward: frame, title, 100 XP, zero coins. Completion adds «ختم الفصل», not a fifth bond tier. Metrics limited to puzzle solve/streak, finish, reunion, win, host, public-room; never personal role/live room. Gate all objectives, change/reset, assisted, pending XP, exact-once, import closure, tone.

### F4 — «مكتب التحقيق» / Investigation Desk (1.1.2)

Deterministic Dart fixtures use the pure engine and work offline. Local versioned progress queues `academyClaim{lesson,version,requestId}`; `academyStatus{}`. Server stores catalog/completions only; account age ≥2 minutes.

1. Sort 8 cards Public/Mine Only; all correct, tap alternative.
2. Pick legal fictional Doctor protection and order scripted resolution tiles; legal command + exact order.
3. Pick living ballot target, resolve scripted tie and configured consequence; legal/correct.
4. Select exactly supported morning statements; «Doctor saved X» fails if only «nobody died» is public.
5. Graduation: own fictional role, legal night action, read morning, supported argument, legal vote; all legal and both inference answers correct.

Rewards: drills 10 coins/20 XP each; graduation 25/50. Gate fixtures, legality, invented-fact rejection, offline queue, replay, no live imports.

### F5 — Verdict sharing (1.1.4)

`verdict_share_enabled` gates story 1080×1920 and feed 1080×1350. Public result only: winner, days, enabled public awards, title, Season level, deterministic narrator. Room title/other names default OFF per share. Hidden logs, whispers/private actions are impossible inputs. Flutter wordmark. Gate timing, pixels, privacy, AR/EN, failure, reduced motion.

### F6 — Scenario Deck and House Rules (1.1.3)

| Code | Players | Duration | Canonical changes |
|---|---:|---:|---|
| `quick` | 5–8 | 15–25m | speech30, discussion180, bullets off, victim role shown, pressure off |
| `classic` | 5–10 | 30–45m | current Classic |
| `big_table` | 10–15 | 45–70m | Classic, speech30, discussion300, pressure on |
| `no_mercy` | 8–12 | 25–40m | speech30, discussion120, no Doctor/whispers, mid-discussion confrontation |

Whisper is separate. `scenario_catalog`; `house_rules(id,owner,share_code,version,settings,role_counts,fingerprint,revoked_at)` and saves: 10/user, 10 creates/day, 30 resolves/hour, 2KB. Server clamps; Mafia below half; roles=capacity; immutable after start; sharing grants no owned content. `table_meta`: `scenarioCatalog{players}`, `houseRuleCreate{settings,roleCounts,requestId}`, `houseRuleResolve{code}`, `houseRuleSave{code,requestId}`, `houseRuleDelete{id,requestId}`. `/rules/CODE`: preview, Use once / «احفظ إعدادات القعدة». Gate parity, bounds, hostile JSON, collision/caps/bypass/frozen start/offline.

### F7 — «سهرة» Series and Draft (1.1.3)

Tables: series, members, candidates, votes, games. Best-of-3 first 2; first-to-3 max 5; early finish; 8h expiry; one active/user; 10 creates/day. Game-one roster is original; replacements marked; later game needs five originals. Three valid presets before deal. After all votes or 30s, any member may finalize; HMAC series+scenario breaks ties, one receipt wins. Public-outcome rooms insert once and recompute score. No extra economy.

`series`: `seriesCreate{mode,roomId,requestId}`, `seriesState{series}`, `seriesVote{series,scenario,requestId}`, `seriesLockDraft{series,requestId}`, `seriesNextRoom{series,oldRoom,name,gender,requestId}`, `seriesAbandon{series,requestId}`. `/series/CODE` survives auth. Score only lobby/result/menu. Gate two clients, concurrent vote/finalize/next-room, duplicate/no-outcome, expiry, replacements, handoff.

### F8 — The online table

- **Ready:** `room_players.lobby_ready`, pre-deal only. All connected + ≥5 before host starts 3s countdown. Roster/rules/preset/series changes increment revision and clear readiness; cosmetics do not. Away cannot remain ready. At five ready, each unready public-matchmaking seat gets one 45s deadline/revision; expiry removes only there. Private/invite marks expired for host action.
- **Host handoff:** existing atomic handoff; public line; configuration/readiness survive.
- **Reconnect:** 0–6s neutral strip; >6s persistent generic surface; >15s manual retry. Freeze duplicate submissions, preserve last safe snapshot, same urgency every role/phase, no auto-abandon.
- **Rematch vote (later 1.1.x; the existing host rematch ships at L):** result-only `room_rematch_votes`. Show yes count only. Fixed connected/non-kicked roster 30s; threshold `max(3,ceil(roster×0.6))`; one receipt creates next room; lowest-seat yes voter hosts if needed; scenario/series survives.

Gate publication/phase allowlists, revision, public/private expiry, simultaneous start/leave/kick, handoff, reconnect every private phase/process death, rematch race.

### F9 — «ليلة الخميس»

Africa/Cairo DST. Featured scenario all Thursday; bonus Thursday 20:00–Friday 01:00 by `rooms.started_at`. Stored fingerprint must match canonical preset even if Deck OFF. First 2 eligible grant +20 XP each; second stamp; no coins. Tables: weekly events, receipts, participation, aggregate. `thursdayEvent{}` and `eventCreateRoom{event,requestId}`. Gate DST/bounds/crossing/wrong fingerprint/replay/caps/community once.

### F10 — Titles and Partner

`title_catalog`, `player_titles`, `player_showcase`; `titleHub{}`, `titleEquip{code|null,requestId}`. Titles only Profile, Casebook, pre-deal lobby plate, result/finale. Reveal/night/live seats pixel-identical.

Partner uses four gallery portraits, free switch outside live match, no second affinity grind. Account `player_partner`; guests local versioned. `partnerGet{}` / `partnerSet{side,requestId}`. Partner voices Home Case line, Casebook header and post-result line, never a clue/live role. Four pass outfits only Home/dossier/Casebook/result. Import closure bans Partner/bonds from hand-off, reveal, night and live-seat.

### F11 — Safety v11

`safety_users_compatible(a,b)` gates friends, invitations/links, public list, quick match, public creation, series/next room/draft. Blocking either way removes friendship and pending requests/invites. Mid-match mutes voice/reactions/whispers without changing membership. Failure `ROOM_UNAVAILABLE`.

`safety_name_terms(locale_scope,normalized_term,match_mode,applies_to,active)` is data. Server removes Arabic diacritics/tatweel, normalizes أ/إ/آ→ا and ى→ي, lowercases English, collapses spaces. Apply every name/title write; return `NAME_NOT_ALLOWED`.

Reports from lobby/result/friends: harassment, hate, sexual, threat, spam, cheating, inappropriate_name, other. Evidence public-only, never live roles/actions, whispers or voice. Limits 10/day, 2/target/day, 24h dedup, 30 blocks/day, 500 active. Retain open/actioned 180d, dismissed 90d, audit 365d then aggregate.

Owner route: `admin_safety_list{status,category,cursor}`, `admin_safety_resolve{reportId,action,durationDays,note,requestId}`, `purge_safety_evidence{requestId}`. Actions dismiss, warn, restrict voice/public rooms, suspend online 1/7/30d/permanent. Gate all bidirectional surfaces, cleanup, generic errors, normalization, limits, evidence whitelist, admin, expiry/purge.

### F12 — Operations

Service-role-only, allowlisted, request-idempotent, immutable audit:

- `operator_feature_snapshot{requestId}` → flags/products/seasons/events/versions/counts, no personal data.
- `operator_feature_set{flag,enabled,reason,requestId}` → before/after; no dynamic column.
- `operator_season_activate{code,startsAt,requestId}` → 28d; no backdate/overlap.
- `operator_season_extend{code,newEndsAt,reason,requestId}` → later only, bounded/announced.
- `operator_event_set{code,startsAt,endsAt,scenarioCode,enabled,requestId}` → Cairo window/fingerprint.
- `operator_reward_reconcile_preview{sourceKind,sourceKey,expectedAmount,requestId}` → delta.
- `_apply{sourceKind,sourceKey,expectedAmount,reason,requestId}` → wallet lock; add under-credit; remove only available earned over-credit; waive spent excess; original receipt immutable.
- `operator_campaign_grant{campaign,milestone,eligibleBatch,requestId}`.
- `operator_creator_code_mint{code,expiresAt,cap,creatorId,requestId}` / `_revoke{code,reason,requestId}`.

Puzzle salt CURRENT/PREVIOUS/EFFECTIVE_DAY changes next UTC day only. Operator runbook must contain snapshot, dark deploy, activation, Season/event, salt, correction, incident pause, creator/founder and rollback. Rollback flag-first, non-destructive.

### F13 — Privacy-safe metrics and decision rules

`product_metric_daily` aggregates; receipts use rotating daily HMAC subject and purge after 48h. No UUID/name/code/role/target/message/voice/free text. `metricRecord{event,properties,requestId}` exact allowlist; server events share transaction.

Allowed: eligible_app_open; case_open/attempt/solved/failed; mission_hub_open/claim; season_level_reached; chapter_started/completed; academy_started/passed; share_exported; scenario_selected; house_rule_created/imported; series_started/completed/dropped; thursday_match; title_equipped; store_open; product_view; purchase_started/succeeded/revoked; ad_offer/started/completed/no_fill; pass_view/pass_purchase; invite_share{trigger}; invite_landing_open; invite_web_join; invite_first_match; case_share; case_link_open; founder_grant; partner_pick{side}; code_redeem; attributed_first_open{side_detective|side_doctor|side_mafia|side_citizen|creator|case|invite|organic}. Reject other properties. Privacy copy mentions anonymous aggregate feature/use measurement.

| Area | Success | Kill/rework |
|---|---|---|
| Overall | no D1/D7/D28 regression; crash-free ≥99.5%; p95 gate | >5% relative retention loss or p95 +20% |
| Casebook | ≥35% online actives open; ≥60% openers claim | <15% after 3 weeks |
| Season | 10–30% reach level 20 | >40% too fast; <5% too slow |
| Daily Case | ≥20% eligible devices open; solve 55–85% | <45% hard; >90% trivial |
| Chapters | ≥35% finish; each choice ≥20% | <15% finish or choice <10% |
| Academy | ≥65% drill; ≥40% graduation | >50% abandon drill 1 |
| Share | success ≥98%; export ≥3% | technical success <99% after fix window |
| Scenarios | ≥25% created use deck; ≥20% imports become rooms | invalid >0.5% |
| Series | ≥20% adoption; ≥60% completion | drop >40% |
| Thursday | ≥10% actives | <3% after 4 weeks or farming |
| Titles | ≥30% equip | <10% simplify |
| Commerce | complete funnel; zero entitlement mismatch | any mismatch or pass coin debt |
| Invites | landing→join and join→first improve | abuse >1% or block/report spike |

No retention retune before 1,000 eligible users or two full weeks. Security, leakage, economy mismatch and crash gates act immediately.

### F14 — First-open and asset warm-up

| Stage | Content | Decoded budget | Timing |
|---|---|---:|---|
| 0 | launch veil/mask, Home backdrop, canvas, locale glyphs | 12MB | blocking hard stop ≤1.2s |
| 1 | Home/Mode, visible rail, selected Partner | +16MB | after first frame |
| 2 | online lobby **or** pass phase **or** Casebook | +24MB | idle, one predicted route |
| 3 | today's suspects, chapter neighbors, scenarios/store/share | +12MB/route | on demand |

Decoded resident ≤48MB. First launch only: idle pass reads compressed bytes for **every pack** in 1–2MB chunks, yields ≥50ms, ≤8MB transient, pauses on input/match/background/thermal/memory; never decodes. Later skip; update uses build+content hash and changed groups only. Daily Case decodes 5–7 portraits at 256px (~1.75MB); chapter shelf thumbnails, open+neighbor prefetch. Web precaches shell+≤8MB core; after interaction CacheStorage fills all compressed packs only without saveData/slow connection, ≤25MB/session after quota check; Safari eviction recovers.

Gates on 2–3GB Android: first tappable p95 ≤2.5s; later ≤1.2s; update ≤1.8s; no tap delay >1.5s; warm RSS +≤35MB. Auth/capabilities/Home bootstrap parallel with non-blocking timeout.

### F15 — Big-table speed for القعدة (L)

The privacy barrier stays: hold-to-reveal, automatic conceal and a confirmed hidden state. «جاهز؟» never replaces it. Targets at 10 and 15 players: median hand-off ≤ 6 s, p95 ≤ 12 s; full 15-player assignment ≤ 100 s; night p90 ≤ 4 min; observer role guesses at chance in recorded trials. Gate: timed device tests at 10/15 players.

### F16 — «صوت الراوي»: spoken narrator and tabletop layout (L)

- **Scope:** pass-and-play public-table beats only (night falls, morning, discussion, vote open, vote result, win). Never while a player holds the phone privately; never during hand-off, reveal or night actions. Online narration waits for a proven host-broadcast/ducked design.
- **Voice (owner, 2026-09-28):** the owner's own ElevenLabs voice «Kratos», voice ID `R1hq8f4mfX3N88Om3Nb7`; tone reference `assets/voiceovers/night_approaching_kratos.mp3`. Before any generated line ships or any Kratos-led video is published: (1) the owner confirms the voice was designed, not cloned from a real person; (2) a commercial-use authorization for the generated audio is on record; (3) the listener gate passes. The line bank is `tool/voice/kratos_lines.json`; the generator is `tool/voice/generate_kratos.mjs` and reads its key only from the environment.
- **Content:** one free voice at L. Several takes per beat, never the same line twice in a row. Text stays authoritative; independent voice/SFX volume. It is the same Narrator as the marketing videos.
- **Production:** pre-rendered offline audio. Archive per batch the voice ID, generation date, applicable terms, authored scripts and the disclosure decision. Loudness normalisation, silence trims, ducking against SFX, interruption/resume behaviour.
- **Listener gate:** 12 Egyptian listeners (ages 15–60, Cairo + ≥ 1 other governorate), blind and anonymous. The closed testers may form the panel, but ≥ 4 listeners must be uninvolved in development, and the voice is never identified as the owner's before rating. Rated separately as natural (≥ 9/12) and not cringe (≥ 9/12). No subgroup below 2/3. ≥ 75% intelligibility in a noisy room. "Would you keep this on after ten matches?" ≥ 8/12. After launch: < 20% disable it after three local matches. A voice that fails stays out, even if technically complete. The owner approves tone and pronunciation.
- **Tabletop layout:** public-table phases only. Large design-token type (system text scale stays locked), high contrast, a timer ring readable at 1–2 m. Never persists into hand-off, reveal or night.
- **Personalities** (later 1.1.x): authored performances. Humour lives in writing and timing, not a caricatured voice; «المذيع» never imitates a real commentator. Each pack passes the same gate.

### F17 — «وضع العيلة» (L)

An immutable room/session preset chosen before the deal, remembered locally per host. It disables the reaper motion, harsh cues and horror copy for everyone at the table. It is never per-role or mid-match. It does not claim the online environment is child-safe.

### F18 — Narrated how-to scenes (1.1.1)

Three skippable 15–20 s scenes: deal/privacy, night and public morning, discussion and vote. The Gang demonstrates; F16 narrates. The first scene is offered in context; the full guide stays in Learn. Never a forced film.

### F19 — Signature presentation (L)

- **Reveal:** after the public result only, each player's painted role figure rises behind their name/portrait (existing portraits + `FeatheredArt`). No role-specific loading, sound or animation before the result is published.
- **Motif:** "the character behind you" is the non-live visual signature. It is used in the reveal, Profile, the Partner pick, share images and store screenshots. It is never used in role reveal, hand-off, night seats or any phase where art or loading could correlate with a role.
- **Sonic mark:** one short master motif (a lamp click + card flip), shared with the marketing videos. No sound while a player privately holds the device. On web, only after user interaction. No role variants.
- **Partner at the table:** lobby plate and post-result only. Partner assets are absent from the live-match import closure, not merely hidden.

### F20 — Thursday Partner letter (1.1.1)

Completed public-week aggregates only (cases solved, matches finished, titles earned). One pull a week from Home, a broad authored bank, and never shaming inactivity.

### F21 — Witness-knowledge room setting (1.1.1)

«الميتين يشوفوا الأدوار؟» defaults to ON (the owner's decision). It is immutable after the deal and shown in the lobby summary. OFF is enforced at the server: `witness_view` publishes no roles or night actions, and the ghost chat receives public state only. It cannot change during a series round.

### F21a — Witness v2: whisper contents for the dead (L)

Owner decision 2026-09-28: the dead see the whole game, including who whispered what to whom.

- **Server rule:** `witness_view` returns `whispers[]` (`id`, day/night index, `from_seat`, `to_seat`, `text`) only when the authenticated caller is a current member of the requested room **and** the authoritative `room_players.alive = false` **and** witness mode is enabled for that immutable room configuration. Clients never assert their own death.
- Whisper content never enters the ordinary snapshot, Realtime publication, error bodies, analytics, client logs or a cache that survives sign-out. Direct table reads stay denied; `witness_view` is the only path.
- **Disclosure:** one identical line for every player, in the lobby rule summary and at the whisper composer, «اللي خرجوا من اللعبة بيشوفوا الهمسات». Recipients see the same notice.
- **Safety:** reported whispers are preserved as evidence, not removed. A sender blocked by the dead viewer has their text masked server-side for that viewer only. A dead viewer can report a witnessed whisper by its immutable ID without resubmitting the text.
- The dead still have no in-game channel to the living; ghost chat is dead-only.
- **Tests:** living member → `403 WITNESS_ONLY` with no roles, actions or `whispers` field; non-member and other-room member → the same non-revealing refusal; dead member receives every committed whisper up to the authoritative read point, including whispers between other players; uncommitted/failed whispers never appear; F21 OFF → public state only (no roles, actions, whisper metadata or text); blocked-sender masking; report-by-ID; Unicode, maximum length and hostile markup render inert; nothing in logs/telemetry/cache after sign-out; death/read races use committed membership only.

### F22 — «الوصية» (1.1.1)

A player eliminated by vote gets 15 s of public last words, BEFORE any public role reveal and before the dead/witness state. Online, the floor closes and voice publication updates atomically before witness access exists. Pass-and-play uses a public timer. Players may pass. Night victims get none.

### F23 — Same-room phones v0 (1.1.3)

Voice off, QR/web join and a same-room label. One elected audio device plays F16 for **morning, discussion, voting and result only**, never night entry or any private beat. If that device backgrounds or opens an overlay, narration fails silently and play continues. It is called «موبايلات في نفس المكان»; the full «قعدة من غير تمرير» with a dedicated display is 1.2.

### F24 — Match chronicle (1.1.4)

Deterministic authored templates from public deaths, public votes, days and the final revealed roles. Investigations, protection targets, whispers and every other private action are never exported, even after the match. «من حكايات الراوي» follows below the factual part: atmospheric only, with no locations, weapons, witnesses, times, traces or causes. Text first; the image comes with verdict sharing.

### F25 — «مين صوّت على مين» (1.1.4)

A dedicated result-only projection of settled ballots per day, honest about abstentions and revotes. The normal snapshot gains no historical votes. Secret ballots stay secret until their own resolution.

### F26 — Scheduled public tables (Thursday first)

A 20:45–21:15 Cairo queue. The count shown is only distinct, authenticated, recently heartbeating devices that joined. Rooms form at ≥ 5; 5–15 → one room; above 15, balanced partitions (16 → 8+8, 19 → 10+9, 29 → 15+14) and never a 1–4 orphan group. At < 5 when the window closes, three honest options: a private lobby + invite, the Daily Case, or a reminder for the next table. Other nights open only after repeated windows with 12–15 arrivals and ≥ 80% match entry. Per-day flags; an automatic operator fallback to Thursday-only.

## 5. Acquisition and launch loops P1–P12

Status: **frozen**, except dependencies in §12.

### P1 Founder seal — CHANGE, then freeze

Founder-only deductive help would make the universal launch case unequal. The sealed Partner letter therefore contains **lore pointing to the case theme, never eliminating a suspect or changing attempts**. Eligible pre-registered accounts receive «من الأوائل» and founder frame. Cumulative milestones (**automation in later 1.1.x; the basic seal ships at L**): 500 → 100 coins; 2,000 → reaction pack; 5,000 → nameplate; 10,000 → frame variant. Tables: campaigns, eligibility, grants. A platform-verified founder assertion exchanges once; operator releases milestone batches. `founderGrant{assertion,requestId}` never trusts a client boolean. Reuse badge/letter paper.

### P2 «القضية الأولى» — KEEP with privacy floor

Server timestamps authoritative; nothing about seed/suspects/clue count/art reaches clients before L. Normal personal reveal after solve/fail; campaign finale at 20:00. Solve rate is k-anonymous ≥50 and rounded to 5%. Same attempts/reward.

### P3 Daily Case retention — KEEP with separate denominators

Streak-save and extra clue follow F2 but are **not at L**. Streak-save arrives in 1.1.2 only if missed-day cohort data justifies it; the extra clue arrives in later 1.1.x. Assisted and unassisted solve rates stay separate. Reminder has no deadline, loss, streak or currency threat.

### P4 First-launch Partner — KEEP; rename attribution

Use `/p/<character>`, not `/p/<side>`, so Mafia choice cannot resemble preferred match alignment. Deep links win over onboarding. Partner adds one line on Daily Case card but never forces it.

### P5 «ابعت للشلة» — KEEP

Triggers: lobby <5, public result, Daily Case solve, founder letter. WhatsApp first, system share fallback, `wa.me` web. Editable first-person text: «فاتح أوضة مافيا دلوقتي وناقصنا ناس، ادخل 👇». `/join/CODE`: «{name} عازمك على أوضة مافيا», primary «ادخل من المتصفح», secondary «عندي التطبيق»; preview no title/roster. After web match: «نزّل التطبيق عشان تكمل مع الشلة». §3 rewards/caps. Cap increase adds at most 500/season and requires real diversity.

### P6 Ads reachable in «القعدة» — KEEP, no faucet

After roles carousel, pass result may surface unclaimed existing daily ad and wheel/coffer extras, then ≤1 automatic result-exit/session inside global two/day. Never before role reveal, handoff, pre-deal or between result/carousel.

### P7 Creator entitlement — L; viewer codes deleted (owner, 2026-09-28)

`creator_entitlements(user,campaign,status,starts,ends)` is granted server-side by the owner to verified creator accounts: no automatic ads (interstitial/banner/result-exit) while active; rewarded ads stay opt-in and unchanged; revocable, non-transferable, audited. Followers and viewers get the ordinary ad model. `viewer_codes`, redemptions and `creatorCodeRedeem` are not built.

### P8 Loop counters — KEEP

Use F13 enums only. First-open attribution stores one bucket, never raw referrer/campaign text.

### P9 In-app review — CHANGE

Do not select only winners. Eligible after third clean completed match with no reconnect/report/error **or** third solved case. ≤1/90d, never live/after loss/reward-coupled. Platform decides whether prompt appears. Dependency approved by the owner (2026-09-28); remote-killable.

### P10 Season Pass launch price — KEEP

Separate launch ID maps to same entitlement, active L→L+14; then retire and activate regular ID. No crossed-out price unless products/dates authoritative.

### P11 Parked — KEEP

WhatsApp stickers and ad mediation are 1.1.x/later. Test mediation only around 100,000 monthly impressions, one partner at a time.

### P12 Launch readiness — KEEP, blocking

Before publication: AdMob listing link/review request complete; EEA/UK consent messaging verified; `/case/today` playable on web after L; privacy/ad disclosures exact; all flags/products OFF in release candidate; operator rehearsal. Failure blocks L.

## 6. Flags and activation order

Status: **frozen**. Every row defaults OFF/inactive.

| Switch/catalogue row | Capability | Dependency | Step |
|---|---|---|---:|
| `safety_v11_enabled` | `safety.v11` | owner queue ready | 2 |
| `metrics_enabled` | server-only | privacy copy | 2 |
| `friends_enabled` | `friends` | safety | 3 |
| `character_bonds_enabled` | `characterBonds` | — | 3 |
| `partner_enabled` | `partner` | bonds | 3 |
| `council_rank_enabled` | `council.rank` | v3 receipts | 4 |
| `council_contracts_enabled` | `council.contracts` | mission mapping | 4 |
| `council_leaderboard_enabled` | `council.leaderboard` | rank+safety | 4 |
| `council_invites_enabled` | `council.invites` | friends+safety | 4 |
| `lobby_ready_enabled` | `table.ready` | safe publication | 5 |
| `rematch_vote_enabled` | `table.rematchVote` | public result | 1.1.x |
| `case_of_day_enabled` | `caseOfDay` | request receipts | 6 |
| `launch_case_enabled` | `caseOfDay.launch` | case+timestamps | 6 |
| `case_streak_save_enabled` | `caseOfDay.streakSave` | case+rewarded | 1.1.x |
| `case_extra_clue_enabled` | `caseOfDay.extraClue` | case+rewarded | 1.1.x |
| `daily_case_reminders_enabled` | `caseOfDay.reminders` | local opt-in | 6 |
| `founder_enabled` + window | `founder` | verified eligibility | 7 |
| `creator_entitlement_enabled` | `creatorEntitlement` | entitlement provenance | 6 |
| `witness_whispers_enabled` | `witness.whispers` | Safety v11 + F21a tests | 11 |
| Season Zero operator active | `season.active` | explicit L timestamp | 8 |
| `missions_enabled` | `missions` | active season+contracts | 8, same operation |
| `titles_enabled` | `titles` | inventory | 8 |
| `thursday_event_enabled` | `thursday` | season+resolver | 9 |
| `awards_enabled` | `fun.awards` | zero coins | 9 |
| `reactions_enabled` | `fun.reactions` | safety+limits | 9 |
| `daily_enabled` | `daily` | economy v3 | 10 |
| `daily_ad_enabled` | `dailyAd` | daily+ad verification | 10 |
| `ad_extras_enabled` | `adExtras` | daily+ad verification | 10 |
| `ad_steps_enabled` | `adSteps` | v3+eligible receipt | 10 |
| `economy_v11_enabled` | `economy.version=3` | simulation | 10, atomic |
| `season_pass_enabled` | `seasonPass` | season+provenance | 10 |
| `starter_bundle_enabled` | `starterBundle` | active row | 10 |
| `pass_and_play_interstitial_enabled` | `interstitial.passAndPlay` | global policy | 11 |
| `interstitial_enabled` | `interstitial` | global policy | 11 |
| `app_open_enabled` | `ads.appOpen` | consent+policy | 11 |
| `banner_enabled` | `ads.banner` | approved surfaces | 11 |
| `pre_match_interstitial_enabled` | `interstitial.preMatch` | — | stays OFF |
| `session_interstitial_enabled` | `interstitial.session` | — | stays OFF at L |
| `review_prompt_enabled` | local/remote kill | §12 dependency | 12 |
| `spoken_narrator_enabled` | `narration.voice` | listener gate passed | 9 |
| `family_mode_enabled` | `table.familyMode` | parity tests | 9 |
| `witness_setting_enabled` | `table.witnessSetting` | server enforcement | 1.1.1 |
| `last_words_enabled` | `table.lastWords` | atomic floor/witness | 1.1.1 |
| `same_room_enabled` | `table.sameRoom` | online reliability | 1.1.3 |
| `scheduled_tables_enabled` (per day) | `table.scheduled` | density gate | later 1.1.x |
| `character_chapters_enabled` | `chapters` | missions+titles | 1.1.1 |
| `academy_enabled` | `academy` | claim service | 1.1.2 |
| `scenario_deck_enabled` | `scenarioDeck` | resolver | 1.1.3 |
| `house_rules_enabled` | `houseRules` | deck | 1.1.3 |
| `series_enabled` | `series` | table+safety | 1.1.3 |
| `scenario_draft_enabled` | `scenarioDraft` | series+deck | 1.1.3 |
| `verdict_share_enabled` | `verdictShare` | result allowlist | 1.1.4 |
| `mm_coins_3000.active` | product row | economy/store | 10 |
| `mm_coins_7500.active` | product row | economy/store | 10 |
| `mm_coins_16000.active` | product row | economy/store | 10 |
| `mm_starter_bundle_v11.active` | product row | starter flag | 10 |
| `mm_remove_interruptions.active` | product row | ad policy | 10 |
| `mm_season_pass_s0_launch.active` | product row | pass flag+L | 10 |
| `mm_season_pass_s0.active` | product row | pass flag+L+14 | initially OFF |
| `mm_reaction_plate_pack_01.active` | product row | inventory | 1.1.x |
| `mm_table_scene_01.active` | product row | scene safety | 1.1.x |
| `mm_dossier_set_01.active` | product row | dossier surfaces | 1.1.x |
| `mm_council_bundle_01.active` | product row | inventory | 1.1.x |
| `transfer_enabled_web` | — | unchanged by 1.1; outside this document | unchanged |
| `transfer_enabled_android` | — | unchanged by 1.1; outside this document | unchanged |

Activation: (1) dark deploy/snapshot/smoke; (2) safety+metrics; (3) accounts/friends/bonds/Partner; (4) Council; (5) table reliability; (6) Daily Case; (7) founder/creator; (8) at 100% rollout activate Season Zero+missions+titles atomically; (9) Thursday/awards/reactions; (10) economy/products/rewarded; (11) conservative automatic ads; (12) optional review prompt. Wait ≥30 minutes or stated sample between economy changes. Roll back reverse-order and flag-first.

## 7. Online-core hardening (release blockers)

Status: **frozen**.

| Order | ID | Evidence | Required fix | Owner | Min |
|---:|---|---|---|---|---:|
| 1 | D1 P1 | auth stream lacks callback error handling | map callback errors; existing-account choice; fake-stream test | Claude | 30 |
| 2 | M2 P1 | raw `FunctionsFetchException` escapes guard | normalize `BackendUnreachable`; enter/start/action/heartbeat/resume tests | Claude | 25 |
| 3 | D2 P1 | puzzle retry can consume another attempt | stable request receipt/replay | Claude | 45 |
| 4 | M5 P1 | Only the Mafia (quiet night) and Doctor (self-protect) hold bullets. A committed bullet move whose response is lost is retried; `alreadySpent` matches this night's own row → `RATE_LIMITED` although the move stands, and a later no-bullet resubmit rewrites `used_bullet=false`, silently refunding it | `alreadySpent` counts only earlier nights; same-night upsert keeps `used_bullet = existing OR requested`; retry/race tests | Claude | 25 |
| 5 | M4 P1 | `/join/:code` can tear down active transport pre-admission | active-session guard; preserve old transport until explicit decision | Claude | 45 |
| 6 | M3 P1 | 10s heartbeat creates ~12k delivered roster events in 10-seat/20m | unpublished presence; publish connected/away/left only | Claude | 105 |
| 7 | D7 P1 | result bursts ~5 calls/player, ~50 for 10 seats | `resultSummary{roomId,requestId}` with Council+Casebook deltas | Claude | 100 |
| 8 | D3 P1 + D4 P3 | migration-time season start; display level 0 | operator start; `max(1,level)` display | Claude | 35 |
| 9 | S4 P1 gap | no final publication-column invariant | exact safe-column allowlist + exhaustive error-body harness | Claude | 70 |
| 10 | M6 P2 | a committed whisper whose response is lost is retried → `RATE_LIMITED` | on 23505, return the original id when today's whisper from the sender has the same recipient and the exact stored body; otherwise keep the refusal. No schema change. Tests: concurrent identical, different recipient | Claude | 20 |

D6 acceptance: series records only finished rooms with non-null public outcome. Post-launch: M7 browse/quick-match rewrite plus partial active-seat index (45m); D5 foreground invite subscription (65m); D9 server-clock display offset (20m); minimum observability (120m). All Claude.

Known-safe races: join uses per-user advisory + room lock + unique seat; quick match uses pool advisory then candidate lock; start/leave lock room and recheck. Global quick-match lock is safe but later bottlenecks.

Required observability: request ID in each response/header; function/result/latency bucket, CAS retries, reconnect outcome, room-fill time, abandoned rooms, resync reason; alerts for p95 join/start/action, failures, CAS exhaustion, reconnect and no-outcome. Logs exclude names, codes, roles, targets, notes, whisper text, tokens and raw bodies; hashed room correlation only.

Error harness invokes every refusal and asserts exact `{error,message,requestId}` (or common mutation envelope), rejects unexpected keys and recursively rejects role/team/target/seed/action/note, UUIDs and names; repeats all caller roles. Database errors become generic 500. Publication test asserts exact safe columns and rejects additions.

## 8. Art production and complete asset manifest

Status: **frozen**.

Common prefix: **“Premium hand-painted Egyptian noir mobile-game illustration; timeless contemporary Cairo; gouache and oil texture; near-black, oxblood and antique-gold palette; warm tungsten chiaroscuro; cinematic premium composition; no text, letters, numbers, logo, watermark or UI border.”** Alpha addition: **“isolated on true transparent background; complete unframed silhouette; generous padding; soft irregular painted edge for feathering.”** Figures use `FeatheredArt`; no boxed portraits. `PNG→WebP` retains source in `raw_assets/update11/` and ships normalized WebP.

| ID | Feature | Dimensions/format | Alpha/feather | Kind | Prompt suffix | Batch | Max |
|---|---|---|---|---|---|---|---:|
| `casebook_hero` | F1 | 1080×600 PNG→WebP | no/hero | new | evidence wall, lamp, maps, red thread, sealed files, unreadable papers, dark lower fade | S1 | 220KB |
| `season_zero_key` | F1 | 1080×1350 PNG→WebP | no/backdrop | new | Cairo rooftops midnight; four canonical silhouettes around illuminated table | S1 | 300KB |
| `case_room_backdrop` | F2 | 1080² PNG→WebP | no/backdrop | new | overhead interrogation table, seven empty chairs, single lamp, evidence shadows | S1 | 260KB |
| `academy_hero` | F4 | 1080×600 PNG→WebP | no/hero | new | investigation desk, face-down cards, evidence tokens, blank chalk forms | S1 | 220KB |
| `thursday_banner` | F9 | 1080×480 PNG→WebP | no/banner | new | Cairo coffee-house terrace Thursday night, empty chairs, glowing table | S1 | 200KB |
| `chapter_letter_paper` | F3/P1 | 1080×1350 PNG→WebP | no/backdrop | new | blank aged folded letter, warm light, torn fibers, subtle stains | S1 | 260KB |
| `launch_case_cover` | P2 | 1080×600 PNG→WebP | no/hero | new | sealed crimson case file, Cairo desk, clock near four, unreadable papers | S1 | 220KB |
| `season_pass_hero` | Pass | 1080×600 PNG→WebP | no/hero | new | moonlit evidence trail, twenty brass markers, four folded garments, empty text area | S1 | 220KB |
| `suspect_n01` | F2 | 512² PNG→WebP | yes/portrait | new | young Egyptian woman, navy headscarf, architect plans, direct gaze | S2 | 90KB |
| `suspect_n02` | F2 | 512² PNG→WebP | yes/portrait | new | young Egyptian man, denim overshirt, courier strap, wary | S2 | 90KB |
| `suspect_n03` | F2 | 512² PNG→WebP | yes/portrait | new | middle-aged Egyptian woman, burgundy blouse, pharmacist pin | S2 | 90KB |
| `suspect_n04` | F2 | 512² PNG→WebP | yes/portrait | new | older Egyptian man, linen galabeya and vest, neutral beads | S2 | 90KB |
| `suspect_n05` | F2 | 512² PNG→WebP | yes/portrait | new | young Nubian Egyptian man, mustard jacket, camera strap | S2 | 90KB |
| `suspect_n06` | F2 | 512² PNG→WebP | yes/portrait | new | Egyptian woman, charcoal suit, short curls, folded receipt | S2 | 90KB |
| `suspect_n07` | F2 | 512² PNG→WebP | yes/portrait | new | Egyptian man, café apron, copper tray, guarded half-smile | S2 | 90KB |
| `suspect_n08` | F2 | 512² PNG→WebP | yes/portrait | new | university woman, green cardigan, notebook, skeptical | S2 | 90KB |
| `suspect_n09` | F2 | 512² PNG→WebP | yes/portrait | new | mechanic, blue coveralls, clean wrench silhouette, thoughtful | S2 | 90KB |
| `suspect_n10` | F2 | 512² PNG→WebP | yes/portrait | new | older woman, patterned shawl, market basket, steady gaze | S2 | 90KB |
| `suspect_n11` | F2 | 512² PNG→WebP | yes/portrait | new | young musician, black shirt, oud-case strap, restrained | S2 | 90KB |
| `suspect_n12` | F2 | 512² PNG→WebP | yes/portrait | new | doctor off duty, beige coat, glasses, tired calm | S2 | 90KB |
| `suspect_n13` | F2 | 512² PNG→WebP | yes/portrait | new | woman baker, flour apron, sealed paper bag | S3 | 90KB |
| `suspect_n14` | F2 | 512² PNG→WebP | yes/portrait | new | railway uniform, pocket watch, upright | S3 | 90KB |
| `suspect_n15` | F2 | 512² PNG→WebP | yes/portrait | new | young woman, red leather jacket, scooter helmet, defiant | S3 | 90KB |
| `suspect_n16` | F2 | 512² PNG→WebP | yes/portrait | new | elderly bookbinder, inked fingers, round spectacles | S3 | 90KB |
| `suspect_n17` | F2 | 512² PNG→WebP | yes/portrait | new | fisherman, weathered teal sweater, coiled rope | S3 | 90KB |
| `suspect_n18` | F2 | 512² PNG→WebP | yes/portrait | new | woman lawyer, cream blazer, closed case folder | S3 | 90KB |
| `suspect_n19` | F2 | 512² PNG→WebP | yes/portrait | new | young barber, patterned shirt, comb pocket | S3 | 90KB |
| `suspect_n20` | F2 | 512² PNG→WebP | yes/portrait | new | woman florist, dark apron, jasmine sprig | S3 | 90KB |
| `suspect_n21` | F2 | 512² PNG→WebP | yes/portrait | new | taxi driver, brown jacket, old key ring, impatient | S3 | 90KB |
| `suspect_n22` | F2 | 512² PNG→WebP | yes/portrait | new | male teacher, rolled sleeves, chalk mark, measured | S3 | 90KB |
| `suspect_n23` | F2 | 512² PNG→WebP | yes/portrait | new | woman jeweler, black tunic, loupe chain, unreadable | S3 | 90KB |
| `suspect_n24` | F2 | 512² PNG→WebP | yes/portrait | new | young man, logo-free football scarf, folded newspaper | S3 | 90KB |
| `chapter_cover_detective` | F3 | 1080×1350 PNG→WebP | no/cover | new | Detective, cramped rainy office, incomplete file | S4 | 300KB |
| `chapter_cover_doctor` | F3 | 1080×1350 PNG→WebP | no/cover | new | Doctor, quiet clinic doorway before dawn, three sealed vials | S4 | 300KB |
| `chapter_cover_mafia` | F3 | 1080×1350 PNG→WebP | no/cover | new | Mafia figure, café back room, forged black seal, overturned coffee | S4 | 300KB |
| `chapter_cover_citizen` | F3 | 1080×1350 PNG→WebP | no/cover | new | Citizen under repaired street lantern, distant neighbors | S4 | 300KB |
| `chapter_seal_detective` | F3 | 384² PNG→WebP | yes/icon | new | wax seal, magnifier motif | S4 | 55KB |
| `chapter_seal_doctor` | F3 | 384² PNG→WebP | yes/icon | new | wax seal, medical-lamp motif | S4 | 55KB |
| `chapter_seal_mafia` | F3 | 384² PNG→WebP | yes/icon | new | black wax seal, rose motif | S4 | 55KB |
| `chapter_seal_citizen` | F3 | 384² PNG→WebP | yes/icon | new | wax seal, street-lantern motif | S4 | 55KB |
| `frame_detective` | F3 | 1024² PNG→WebP | yes/portrait | new | empty ornate brass frame from magnifier seal | S4 | 170KB |
| `frame_doctor` | F3 | 1024² PNG→WebP | yes/portrait | new | empty ivory/brass frame from clinic lamp | S4 | 170KB |
| `frame_mafia` | F3 | 1024² PNG→WebP | yes/portrait | new | empty black/oxblood frame from rose seal | S4 | 170KB |
| `frame_citizen` | F3 | 1024² PNG→WebP | yes/portrait | new | empty copper frame from lantern seal | S4 | 170KB |
| `frame_season_zero` | F1 | 1024² PNG→WebP | yes/portrait | new | empty oxblood wax-and-brass frame, rooftop/council motifs | S4 | 170KB |
| `season_zero_05` | F1 | 1080×720 PNG→WebP | no/scene | new | Citizen at the table recognizing a new empty place among familiar chairs | S4 | 240KB |
| `season_zero_10` | F1 | 1080×720 PNG→WebP | no/scene | Detective placing a verified file into the player's side of evidence desk | S4 | 240KB |
| `season_zero_15` | F1 | 1080×720 PNG→WebP | no/scene | Mafia figure acknowledging persistence across café table, guarded posture | S4 | 240KB |
| `season_zero_20` | F1 | 1080×720 PNG→WebP | no/scene | Doctor opening council chamber at dawn, completed trail behind | S4 | 240KB |
| `partner_outfit_detective` | Pass | 1024² PNG→WebP | yes/portrait | new | canonical Detective, midnight formal coat, same face/pose family | S4 | 170KB |
| `partner_outfit_doctor` | Pass | 1024² PNG→WebP | yes/portrait | new | canonical Doctor, elegant dawn clinic coat, same face/pose family | S4 | 170KB |
| `partner_outfit_mafia` | Pass | 1024² PNG→WebP | yes/portrait | new | canonical Mafia, restrained oxblood suit, same face/pose family | S4 | 170KB |
| `partner_outfit_citizen` | Pass | 1024² PNG→WebP | yes/portrait | new | canonical Citizen, warm Cairo-night jacket, same face/pose family | S4 | 170KB |
| `academy_doctor_guide` | F4 | 768×1024 PNG→WebP | yes/portrait | new | canonical Doctor beside unseen board, teaching gesture | S5 | 150KB |
| `academy_drill_public` | F4 | 720×480 PNG→WebP | no/card | new | separated fact cards, unreadable marks | S5 | 150KB |
| `academy_drill_night` | F4 | 720×480 PNG→WebP | no/card | new | moonlit action tokens in order | S5 | 150KB |
| `academy_drill_vote` | F4 | 720×480 PNG→WebP | no/card | new | brass ballot box, tied blank tokens | S5 | 150KB |
| `academy_drill_morning` | F4 | 720×480 PNG→WebP | no/card | new | dawn evidence, supported/false blank notes | S5 | 150KB |
| `academy_drill_graduation` | F4 | 720×480 PNG→WebP | no/card | new | sealed graduation file, five evidence markers | S5 | 150KB |
| `scenario_quick` | F6 | 720×960 PNG→WebP | no/card | new | pocket watch, short candle, compact empty table | S6 | 220KB |
| `scenario_classic` | F6 | 720×960 PNG→WebP | no/card | new | balanced council chamber, four role motifs as objects | S6 | 220KB |
| `scenario_big_table` | F6 | 720×960 PNG→WebP | no/card | new | long empty Cairo table, hanging lamps | S6 | 220KB |
| `scenario_no_mercy` | F6 | 720×960 PNG→WebP | no/card | new | extinguished clinic lamp, cracked seal, severe table | S6 | 220KB |
| `case_share_story` | F2 | 1080×1920 PNG→WebP | no/backdrop | new | evidence board, large empty result zone | S7 | 320KB |
| `case_share_feed` | F2 | 1080×1350 PNG→WebP | no/backdrop | new | matching evidence board for feed crop | S7 | 280KB |
| `verdict_story` | F5 | 1080×1920 PNG→WebP | no/backdrop | new | torn case file, empty winner/award/narrator zones | S7 | 320KB |
| `verdict_feed` | F5 | 1080×1350 PNG→WebP | no/backdrop | new | matching verdict file for feed crop | S7 | 280KB |
| `series_plaque` | F7 | 1024×512 PNG→WebP | yes/object | new | empty antique brass score plaque, two side fields | S7 | 140KB |
| `series_trophy` | F7 | 512² PNG→WebP | yes/object | new | Council cup from opposing neutral masks | S7 | 90KB |
| `thursday_stamp` | F9 | 512² PNG→WebP | yes/icon | new | coffee-ring and crescent-night wax stamp, no calligraphy | S7 | 80KB |
| `founder_frame_variant` | P1 | 1024² PNG→WebP | yes/portrait | new | empty first-page founder frame, brass rays | S8 | 170KB |
| `founder_nameplate` | P1 | 1024×320 PNG→WebP | yes/object | new | empty wide founder plate, quiet center, first-page seal ends | S8 | 100KB |
| `founder_reaction_pack` | P1 | 1024² sprite PNG→WebP | yes/icon | new | four restrained first-page wax reactions, clearly separated, no faces/text | S8 | 180KB |
| `invite_frame` | P5 | 1024² PNG→WebP | yes/portrait | new | empty social-circle frame, five linked brass marks | S8 | 170KB |
| `pass_nameplate` | Pass | 1024×320 PNG→WebP | yes/object | new | empty oxblood Season Zero plate, brass trail | S8 | 100KB |
| `pass_reaction_pack` | Pass | 1024² sprite PNG→WebP | yes/icon | new | four separate restrained noir reaction seals, no faces/text | S8 | 180KB |
| `pass_table_scene` | Pass | 1920×1080 PNG→WebP | no/backdrop | new | moonlit council room, neutral evidence, readable empty center | S8 | 420KB |
| `pass_premium_frame` | Pass | 1024² PNG→WebP | yes/portrait | new | empty premium frame, layered brass trail, no baked particles | S8 | 180KB |
| `gang_hamada` | F18 | 768×1024 PNG→WebP | yes/portrait | new | canonical Gang member حمادة: young Egyptian man, anxious half-smile, casual shirt; the same face in every future use | S9 | 150KB |
| `gang_karim` | F18 | 768×1024 PNG→WebP | yes/portrait | new | canonical Gang member كريم: suspicious easy smile, dark jacket | S9 | 150KB |
| `gang_nada` | F18 | 768×1024 PNG→WebP | yes/portrait | new | canonical Gang member ندى: confident, notebook, «متأكدة ١٠٠٪» posture | S9 | 150KB |
| `gang_sayed` | F18 | 768×1024 PNG→WebP | yes/portrait | new | canonical Gang member الدكتور سيد: cautious, glasses, cardigan | S9 | 150KB |
| `gang_reda` | F18 | 768×1024 PNG→WebP | yes/portrait | new | canonical Gang member عم رضا: older man, silent, calm hands around a tea glass | S9 | 150KB |

The Gang sheets (S9) are the canonical reference for both the app and the marketing videos: marketing animates these stills, so the characters are one world.

Reuse without regeneration: four gallery portraits; `badge_founder`; Council ranks/contracts/seals; coins; outcome paintings; awards/reactions; seat rings/spotlights; victory emblems; onboarding; `welcome_back_card.webp`; unchanged store covers.

**S0 and production:** calibration board (Detective bust, Doctor bust, café, evidence desk) attaches gallery portraits and `casebook_hero` proof. Accept only same faces at thumbnail/full size, no Western-police cliché, consistent palette, clean true alpha/no halo, correct hands/eyes, empty safe areas, 360px crop, no baked glyph. S2–S3 use 2×2 contact sheets then individual corrections. Realistic session: 4–8 final assets after QA. Normalize, alpha scan, dimensions/size and 420px contact sheet before registration.

## 9. Sound and motion

Status: **frozen**.

Synthesize with `tool/generate_audio.py`; no speech: `casebook_wax_press`, `casebook_paper_slide`, `casebook_string_pluck`, `casebook_level_sting`, `case_accuse_gavel`, `case_wrong_crack`, `case_reveal_swell`, `chapter_envelope_open`, `chapter_seal_press`, `academy_token_place`, `academy_wrong_return`, `academy_graduation`, `share_paper_eject`, `scenario_token_drop`, `series_score_peg`, `series_final_sting`, `thursday_sting`, `title_equip`, `lobby_ready_tick`, `founder_letter_open`, `partner_pick`, `invite_seal`, `season_pass_unlock`, and the `brand_motif` sonic mark (F19). No cue varies by live role.

**Spoken narrator (F16):** pre-rendered offline speech, one free voice at L, ~30–60 mono clips per pack (the beats × takes × outcomes), loudness-normalised and trimmed, stored under `assets/voice/<pack>/`. Provenance per batch: voice ID, date, terms, scripts, disclosure decision. Family mode (F17) uses its own softer takes for the harsh beats.

| Feature | Motion |
|---|---|
| Casebook | page parallax; wax 180ms; thread 320ms; milestone dissolve 420ms |
| Daily/launch case | spotlight 240ms; suspect fade 180ms; chain 280ms; solve stamp 180ms |
| Chapters/founder | file 360ms; seal 180ms; letter 420ms |
| Academy | settle 220ms; wrong return 180ms; graduation 600ms |
| Partner | portrait cross-dissolve 240ms; no Home idle loop |
| Share/invite | paper assembly 450ms; export static |
| Scenario | fan 320ms; selected rise 180ms |
| Series | peg 220ms; finale 650ms |
| Thursday | café light 420ms; stamp 180ms |
| Titles/pass | seal 180ms; track 320ms; outfit 240ms |
| Ready/reconnect | ready 180ms; state fade 180ms, phase-identical |

Reduced motion is opacity-only 120ms: no travel, rotation, burst, particles or parallax. Sound, vibration, brightness and duration never encode bond state or live role.

## 10. Build order, ownership, estimates and gates

Status: **frozen**.

| # | Deliverable | Claude (min) | Gate |
|---:|---|---:|---|
| 1 | Online blockers (§7 rows 1–10) | 500 | targeted online ×3; error/publication; SQL/edge; reconnect device |
| 2 | Safety v11 + owner queue | 480 | every block surface; evidence; admin/purge |
| 3 | Operator RPCs/runbook | 285 | idempotency/audit/wallet/dark snapshot/rollback |
| 4 | Metrics + warm-up/sweep | 390 | allowlist/privacy; low-end p95/RSS; web slow/saveData |
| 5 | Economy/ad/invites/catalogue (L products only)/provenance | 540 | 28-day simulation; concurrency; restore/revoke; disclosures |
| 6 | S0/S1/S8 art + launch sounds (images by Sol) | 240 | alpha/crops/360px/size/reduced motion |
| 7 | Casebook + Season Pass | 480 | inactive/close/retro/revoke/reward math/device |
| 8 | Daily Case + P2/P3 + route | 540 | 10-year generator; assists/reminders; Android/web |
| 9 | Founder+Partner+invite+creator | 510 | attribution/replay/caps; deep-link; share fallbacks |
| 10 | Ready/rematch/reconnect/handoff | 450 | two-client races; process death; private/public ready |
| 11 | Thursday+titles+pass ad reach | 390 | Cairo DST; phase matrix; device never-list |
| 12 | Listing, captures, trailer, consent/listing | 330 | honest media/copy; P0 checklist; switches OFF |
| 13 | Full RC | 480 | SQL/edge/analyze/full Flutter; 360px; two Android classes; Safari/offline |
| 14 | 1.1.1 Chapters + S4 | 660 | four paths; assisted; purity; tone/device |
| 15 | 1.1.2 Academy + S5 | 480 | pure fixtures; offline queue; five drills |
| 16 | 1.1.3 Deck/Rules+Series/Draft+S6/S7 | 1,110 | parity/hostile/two-client/link matrix |
| 17 | 1.1.4 Verdict + Season One | 360 | pixels/privacy/share/content-expiry rehearsal |
| 18 | 1.1.x Direct premium cosmetics + art | 300 | inventory/provenance/surfaces; no live-seat change |

These are per-feature estimates. The binding launch ceiling is the §2 table: 129 hours, including the game-round additions F15–F19. It spans several working sessions.

Claude owns every file: `supabase/**`, generators, edge contracts and backend tests, `lib/**`, Dart tests, ARBs/l10n, tokens, routes, `pubspec`, asset constants and final Arabic. Sol critiques each plan before it is built and generates images through its Codex session with a low-cost image model. Art lands in `raw_assets/update11/**` until approval, and Claude alone registers accepted assets. Audio is isolated. Each row passes its gate before merge. No concurrent `flutter test`.

## 11. Launch package, rollout, risks and roadmap

Status: **frozen**.

### Store listing (first release; strength-first)

The listing sells what the game does, never offers. Rewards are not the headline of any listing element.

- **Title (≤ 30):** «سيد المافيا - لعبة المافيا» (26). English: "Mafia Master: Online Mafia".
- **Short description (≤ 80):** «لعبة المافيا أونلاين بالصوت مع صحابك، أو قعدة والموبايل هو الراوي».
- **Full description (Arabic):**

> «سيد المافيا» هي لعبة المافيا اللي تعرفها من القعدات، بس المرة دي الموبايل هو الراوي. مفيش حد يقعد برا اللعب، ولا حد ينسى خطوة.
>
> العبها قعدة على موبايل واحد: كل واحد يشوف كارته لوحده، والموبايل يدير الليل والنهار والتصويت. أو العبها أونلاين بالصوت: ابعت رابط الأوضة للشلة على واتساب، ويدخلوا من التطبيق أو من المتصفح على طول، حتى لو كل واحد في محافظة.
>
> أربع أدوار: المافيا بتختار ضحيتها بالليل، الدكتور بينقذ، المحقق بيكشف، والمواطنين لازم يعرفوا مين القاتل قبل ما يفوت الأوان. لعبة جماعية ولعبة صحاب، فيها تحقيق وغموض.
>
> • الموبايل ما يفضحش دورك: التسليم له نفس المدة والإضاءة لكل الأدوار.
> • بعد خروجك، تتابع الحقيقة من غير ما تأثر على الأحياء.
> • «قضية اليوم»: لغز مافيا جديد كل يوم، ليه حل واحد بس.
> • الأربعة فاكرينك: ملفات الشخصيات بتكبر مع كل سهرة، ورسايل مختومة مستنياك.
> • ليلة الخميس: سهرة المافيا الأسبوعية.
> • رسومات مصرية مرسومة باليد، وكل كارت لوحة.
> • مفيش حاجة في المتجر بتديك أفضلية في اللعب.
>
> لو بتحب ألعاب زي المستذئب، دي لعبة المافيا بتاعتك، بالعربي ومن مصر.

- **English description:** the same structure and claims, translated; no keyword lists.
- **Keywords:** the title and short description carry relevance. The description uses each phrase naturally once. Spelling variants are kept only for future measured listing experiments. «المستذئب» appears once, naturally. No competitor names, "best" or "#1".
- **Pre-registration custom listing** (user-state targeting): the same strengths, plus «سجّل وهتوصلك أول ما تنزل».

### Eight screenshots

1. Pass-and-play hand-off — «الموبايل هو الراوي».
2. Online voice room — «العب بالصوت مع صحابك من أي مكان».
3. The hold pad — «الموبايل ما يفضحش دورك».
4. Daily Case — «قضية جديدة كل يوم».
5. Partner/dossier — «الأربعة فاكرينك».
6. Web join — «ادخل من المتصفح في ثواني».
7. Thursday — «ليلة الخميس».
8. Witness table — «بعد خروجك… تتابع الحقيقة».

These are honest 1080×1920 captures, with no fabricated balance, roster or unlock. 1.1.x screens appear only after they ship.

### Trailer and share hooks

20 s, no speech, no reward shots:
- 0–3s the phone becomes the narrator;
- 3–6s friends in different cities join by voice;
- 6–9s the hand-off looks the same for every role;
- 9–12s the reaper scare;
- 12–15s the Daily Case clues;
- 15–18s the Four's dossier;
- 18–20s «القضية بدأت».

Share hooks: lobby shortage, public result, case grid, founder letter, Thursday stamp. Never chapter spoilers or private match data.

### Rollout

- **Internal 48h:** 20 full sessions; zero leakage/wallet mismatch; operator/rollback/season/ad/entitlement drills; switches OFF.
- **Closed alpha 3–5d:** ≥100 online matches, ≥20 Daily Cases, ≥10 rematches; crash-free ≥99.5%, ANR <0.5%, edge failure <1%, no lost receipt.
- **10%, ≥48h/500 sessions:** no P0/P1; low-end p95 ≤2.5s; match completion within 5% baseline; reward discrepancy zero; ad no-fill/consent/invalid-traffic reviewed.
- **50%, ≥72h/2,000 sessions:** safety SLA; invite/share success ≥98%; case solve 45–90%; reconnect ≥95%; no abnormal faucet; Season Pass purchase/restore/revoke exact.
- **100%:** ≥7 stable production days, D7 visible, moderation sustainable, owner approval. Only then activate Season Zero globally.

Launch-week night: 5–10 Egyptian micro-creators/board-game communities, Thursday 21:00 Cairo (inside «ليلة الخميس»), playing the game rather than presenting offers, three tables, two moderators, safety briefing, invite kit, no reward for positive reviews.

### Pre-mortem and kill gates

"It is L+30 and the game has failed." Ranked by likelihood × impact. Every gate needs a minimum sample and a mode-specific denominator; percentiles, not averages.

| Rank | Failure | Gate |
|---:|---|---|
| 1 | Scope produces a late, inconsistent release | feature freeze ≥ 14 days before RC; ≥ 20% integration reserve; no launch copy/art before a feature's end-to-end gate; unfinished rows removed, not left visibly disabled |
| 2 | Public rooms stay empty | at ≥ 100 queue sessions: p50 wait ≤ 3 min, p90 ≤ 6 min, ≥ 70% enter a match, ≤ 20% abandon before placement, no 1–4 orphan groups; if failed, the public queue stays secondary to invites |
| 3 | The first large القعدة is slow or confusing | F15 targets; ≥ 30% start another local match initially |
| 4 | A leakage defect or a credible rumour | private-payload allowlists; import-closure tests; per-role visual/timing recordings; 20 observer trials at chance; incident classification ≤ 4 h; a confirmed exploit pauses the mode |
| 5 | Low-end jank or OOM | on two 2–3 GB devices: crash-free ≥ 99.5%, ANR < 0.5%, stage-0 p95 ≤ 1.2 s, no private-phase frame > 250 ms from asset decode, five matches without monotonic memory growth |
| 6 | Voice connects but is unusable | connection ≥ 95%; p95 setup ≤ 8 s; unrecovered mid-match drop < 5% of matches; recovery ≤ 15 s; completion within 5 points with voice broken |
| 7 | Toxic public rooms | reports per 1,000 public matches; median review < 24 h during rollout; zero rematch/invite/friend across a block; repeat-offender rate; severe reports triaged before wider rollout |
| 8 | Lone installers do nothing meaningful | organic lone installs (≥ 1,000 devices): ≥ 60% complete one meaningful action on D0; Case, lobby and invite reported separately; D1 ≥ 25% is an assumption until cohorts exist |
| 9 | Monetization pressure damages play | result-exit abandonment, next-match rate, session length and D1/D7 by actual ad exposure; investigate if exposed D7 is > 3 points below matched unexposed cohorts |
| 10 | The Four become a decorative menu | ≥ 30% of D7 players open a dossier; ≥ 20% revisit Partner content; ≥ 4 weeks of non-repeating lines per character at launch cadence |
| 11 | Art is polished but emotionally wrong | blind test with 12–20 target players: ≥ 75% name the intended mood; no recurring anatomy/cultural complaint; every recurring face passes side-by-side consistency |
| 12 | Dead-to-living collusion in competitive rooms (now including whisper text) | F21/F21a server tests; setting adoption measured once F21 ships; competitive complaints tagged; whisper-related reports per 1,000 public matches; external communication is an accepted residual risk |
| 13 | Matches become too long | p90 ≤ 35 min for the standard 8-player preset; < 5% voluntary mid-match departure unrelated to network; one defence ritual only; last words fixed at 15 s |
| 14 | A host/network failure leaves an unrecoverable room | chaos suite across every phase (host kill, process death, duplicate action, lost response, reconnect): zero divergent outcomes, ≥ 95% resume, no acknowledged action lost |
| 15 | The narrator is embarrassing or exhausting | the F16 listener gate; < 20% disable after three local matches |
| 16 | Too many options fracture comprehension | a new host makes a valid room in ≤ 45 s without help; ≥ 80% use a preset unchanged; ≤ 3 primary choices per entry screen; incompatible combinations rejected before creation |
| 17 | Same-room mode excludes the groups it should help | lobby → five joined → match started ≥ 50%, and median setup ≤ 3 min, or it is not promoted over pass-and-play |

Operational risks carried from earlier rounds: weak-network receipts (Claude), reward abuse via caps/simulation/alerts (Claude), entitlement mismatch via provenance and drills (Claude), a season content gap via the day-14 brief / day-21 build (Claude; Sol critiques).

### Roadmap

The ordered roadmap lives in §2 "Roadmap after L". Beyond it: 1.4, role research (a limited Mayor prototype under Doc 09/11; Storyteller research only); 2.0, community at scale (moderated crews, tournaments, regional copy packs, mature live ops). No Group Book or anniversaries in 1.1, no Coffeehouse league, no fifth role before 1.4 proof.

## 12. Owner decisions — answered 2026-09-28

1. **Install Referrer and Play in-app review:** approved («ضيف كل اللي انت عايزه»). Row 5 of §2; the < 150 ms cold-start and no-raw-referrer gates still apply.
2. **Viewer codes:** deleted. Creators get the creator entitlement (no automatic ads; rewarded stays opt-in) at L; everyone else gets the normal ad model.
3. **Content:** pre-launch and post-launch; every video hooks in its first second (docs/marketing).
4. **The dead see everything:** every role, every night action and every whisper with its text (F21a at L). F21's host toggle stays 1.1.1, default ON.
5. **Voice:** the owner's ElevenLabs «Kratos» voice replaces the Azure idea. Provenance, commercial-use authorization and the listener gate remain release blockers (F16).
6. **Creators:** Claude prepares the Egypt + Gulf list and messages; the owner sends.
7. **Date:** "two weeks to a month". Play's 12-tester/14-day rule makes two weeks impossible; target Thu Oct 29, fallback Thu Nov 5 (§2).
8. **Carried defaults** (no objection raised): streak-save 1.1.2 with evidence; family mode is a one-tap preset, not the default; same-room v0 is «موبايلات في نفس المكان»; the 129 h ceiling with the §2 merge rule.

Frozen, not open: local notifications, economy option C, Season Pass, Quiet Pass, P1–P12 as amended, ad model 1, the total-income target, the strength-first listing, the §2 launch list and the roadmap. Game rounds 1–2 (Sol: "GAME PLAN CLOSED") closed this file.
