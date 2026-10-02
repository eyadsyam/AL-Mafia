# Round 5 — roles swapped: Claude stress-tests, Sol attacks

The owner (2026-09-28): approves every request we make (local notifications,
economy option C), and ordered us to decide on merit — "not because I like
something; choose the most suitable, best solution; put feelings aside."

## 0. Decisions taken on merit

| Question | Decision | Why |
|---|---|---|
| Sheets vs routes | **Sheets** for entry, selection, confirmation and any single-page flow. **Full-screen routes** (painted rise transition) for multi-page flows: Chapters, Academy drills, Scenario/House-Rule editing, Series draft, safety admin. | A modal sheet with a nested Navigator is doable, but a swipe-down can throw away a half-done deduction or drill, back/keyboard/a11y get fragile, and deep links can't land inside it. Sol was right. |
| Preload | **Native:** stage-0 blocking ≤1.2 s, staged decode, server warm. No bulk read of bundled assets (they are already on the device; reading them warms nothing lasting). **Web:** service worker precaches shell + ≤8 MB core; after first interaction, a background CacheStorage fill of every feature pack unless `saveData`/slow network. | The owner's goal is smoothness. On native, the lag is decode + server cold start, not disk. On web, the lag is network, so "load all packs" is right there. |
| Notifications | **In 1.1.** `flutter_local_notifications`, Sol's rules (off by default, offered after 3 solves on 3 days, user-chosen hour, ≤1/day, cancelled on solve). | Owner approved the dependency; the Daily Case needs a habit trigger. |
| Economy | **Option C** (25 + 10 win, ads +25 ×2, 6 coin-eligible matches/day, first match of the day +25, never an ad without a reward). | Owner approved. Numbers are in §3. |

## 1. Journeys — findings and fixes

### P1 «سلمى», 17, pass-and-play at a family gathering, no account, weak or no internet
| Moment | Finding | Fix |
|---|---|---|
| First open, offline | The «الليلة» rail shows Daily Case / Casebook, which need the server. Offline they are dead cards. | The rail shows only cards whose data loaded. Offline, the rail is empty and disappears. No error cards on Home. |
| After onboarding | The Academy offer is the right thing for her. | Keep. The Academy runs fully offline (round 3). |
| Setting up the table | The Scenario Deck lives only in the online create flow (round 3 IA). Her group is exactly who presets serve. | The same four canonical presets also appear as painted cards in pass-and-play settings, replacing today's text preset row (local, no server). |
| Casebook | She never plays online, so every daily case is impossible → the Casebook tells her she is failing. | Add `puzzle_solve` as a daily-case metric. At most one of the three daily slots may be a puzzle case, so a non-online player can progress. The other two slots stay online. |
| Returns 5 days later | The welcome-back card exists. The Daily Case streak is gone. | No streak-loss copy anywhere. The streak shows only while alive. |

### P2 «كريم», 22, online alone at night, 3 GB Android, weak Wi-Fi, guest
| Moment | Finding | Fix |
|---|---|---|
| Quick match → lobby with ready-up | One AFK player blocks the start forever. | After everyone else is ready, a 45 s grace starts, then the host gets «ابدأ بالجاهزين». Non-ready players leave to the list with a neutral message. Still ≥5 players. |
| Daily Case on flaky Wi-Fi | `casePuzzleSolve` has no request id. A retried *wrong* pick could burn two attempts. | Add `requestId` (uuid) to the solve. The server stores it, and a replay returns the stored verdict. |
| 10 matches a day | Matches 7–10 show no coin/ad controls (correct). He needs to know once. | One line on the 7th result: «خلصت كوينز ماتشات النهارده · التقدم لسه شغال». Once a day, never repeated. |
| Day 28, the season ends | **Gap: nothing is planned after Season Zero.** The trail goes empty. | (a) A 7-day claim grace after `ends_at`: unclaimed track rewards stay claimable and the trail is shown "closed". (b) Season One content rows (track, 2 titles, a frame variant, key art) are part of 1.1's asset and content work, activated by the operator. (c) If no next season is active, the Season page shows the Legacy of the last season plus «الموسم الجاي قريب», not an empty trail. |
| Guest | The save prompt at level 3 is correct. | Keep. |

### P3 «أبو يوسف», 35, hosts 8 friends every Thursday, shares on WhatsApp
| Moment | Finding | Fix |
|---|---|---|
| Sharing House Rules | A 7-character code is clumsy on WhatsApp. | Share a link `…/rules/CODE`. The app route opens the import preview. The Android App Link path and `assetlinks` coverage are added, with web fallback (owner ask: links open the app). |
| Thursday with his own rules | His rules don't match the canonical fingerprint → no Thursday XP, and he doesn't know why. | When a lobby uses non-featured rules during the window, one lobby line: «ليلة الخميس محسوبة على سيناريو الليلة بس». Honest, once. |
| Series, one friend leaves after game 1 | Continuity ≥5 originals is fine. | Keep. The replacement is marked. |
| Verdict card on WhatsApp | Names are off by default. His group wants them. | A per-share toggle «أسماء الترابيزة» (default off). The preview shows exactly what is shared. |
| Sharing a series link | Same deep-link concern. | `…/series/CODE` → app route to the lobby join, with web fallback. |

### P4 A returning 1.0 alpha tester, 12,000 coins, council rank
| Finding | Fix |
|---|---|
| Option C lowers per-match coins. They notice. | Balances are never touched. A one-time vault note: «المكافآت اتظبطت عشان المتجر يفضل له قيمة؛ رصيدك زي ما هو». Plus a What's New line. |
| With 12,000 they can buy most of the catalogue at once. | Fine: 1.1's new prestige items (season frame, chapter frames, titles) are earned, not bought. Goals remain. |
| Council rank vs Season level: two levels? | The Council rank is lifetime prestige in Legacy (agreed). Explain it by placement, not text: rank on Legacy, season on the trail. |

### P5 A troll with 4 alt accounts
| Attack | Finding | Fix |
|---|---|---|
| Harass one player | Blocks are now global (round 4). Alts dodge blocks. | Reports carry a public snapshot. Restrictions apply to the account. The owner's queue shows "repeated target" (round 4). Also: a new account (<24 h) can't send friend requests or direct invites. |
| Farm coins with a 5-account room | Casebook XP has a same-group cap (3/day), but **coins under option C do not.** | Coin eligibility shares the same-group cap: the 4th+ match per day with the identical 5-player fingerprint pays 0 coins and shows no ad. |
| Farm invite rewards with alts | The invite faucet (~2,050) is alt-farmable. | An invite pays only when the invitee finishes 3 eligible matches on 3 different UTC days with ≥3 distinct non-inviter tablemates. Cap: 5 paid invites per inviter per season. |
| Ad fraud via alts on one device | **AdMob invalid traffic can get the owner's account suspended** — an existential risk. | A per-device (install id) cap of 12 rewarded ads/day across accounts, and a server-side per-account cap. SSV is already server-verified. |

## 2. Contradictions across rounds (resolved)
1. The implemented Casebook migration starts Season Zero at `now()` → **operator activation** (round 2) wins. The migration gets amended before release.
2. The implemented UI shows level 0 → **display level ≥1** (round 2).
3. Friday Daily Case ×2 (my draft) → **5/20 every day** (round 1).
4. Academy: server attempts (round 2) → **offline drills + idempotent claims** (round 3).
5. Sheets: "one routed sheet" (round 3) vs "full-screen routes" (round 4) → **§0 decision**.
6. Titles: lobby+profile (round 2) vs +result/finale (round 3) → **round 3** (post-public-result is safe).
7. Three build orders (rounds 2, 3, 4) → **§6 single order**.
8. The Case of the Day backend is already committed without templates or the anti-heuristic → **rework task** in §6.
9. Host-only rematch (built) vs everyone's «ماتش كمان؟» vote (round 4) → **both**: the host button starts immediately, and the vote starts it when the host is absent or hesitant. One atomic receipt, so they never double-create.
10. Owner "preload all packs" vs staged → **§0 decision**.
11. Invite faucet unchanged under C → **§1 P5 fix**.

## 3. FINAL reward table (after 1.1, option C)
| Source | Coins | Season XP | Caps / conditions |
|---|---:|---:|---|
| Online match finished (eligible) | 25 | 20 | First 6 eligible/day; same 5-player group max 3/day (coins too) |
| Win bonus | 10 | 10 | Same as above |
| First eligible match of the day | 25 | — | Once/UTC day |
| Rewarded ad step 1 / step 2 | 25 / 25 | — | Only on coin-eligible matches; device cap 12/day |
| Daily cases (3) | 5 / 10 / 10 | 25 / 40 / 40 | One slot may be `puzzle_solve` |
| All three bonus | 10 | 25 | Daily |
| Weekly case | 75 | 180 | Weekly |
| Season track (20 levels) | 400 total | — | Plus frame at 20, titles at 10 and 20 |
| Daily Case solved | 5 | 20 | Daily; 3 attempts |
| Chapter complete (×4) | 0 | 100 | Once each; plus frame and title |
| Academy drills 1–4 / graduation | 10 / 25 | 20 / 50 | Once per account/version |
| Thursday window | 0 | 20 | First 2 eligible matches, max 40/week |
| Achievements (6) | 375 total | — | Once each |
| Invites | existing per-invite value | — | §1 P5 conditions, 5/season |
| Daily coffer, wheel, 7-day card, daily ad, ad extras | existing | — | Sol to restate the numbers under C (see §7) |
| Council levels | existing | — | Lifetime |
| Pass-and-play | 0 | 0 | Bonds, dossiers and puzzle path only |

## 4. FINAL flag table (all default OFF)
| # | Flag | Capability key | Depends on |
|---:|---|---|---|
| 1 | `safety_v11_enabled` | `safety` | — |
| 2 | `metrics_enabled` | — | — |
| 3 | `friends_enabled` | `social.friends` | 1 |
| 4 | `character_bonds_enabled` | `fun.characterBonds` | — |
| 5 | `lobby_ready_enabled` | `table.ready` | — |
| 6 | `rematch_vote_enabled` | `table.rematchVote` | — |
| 7 | `scenario_deck_enabled` | `scenarioDeck` | — |
| 8 | `house_rules_enabled` | `houseRules` | 7 |
| 9 | `series_enabled` | `series` | — |
| 10 | `scenario_draft_enabled` | `scenarioDraft` | 7, 9 |
| 11 | `case_of_day_enabled` | `caseOfDay` | — |
| 12 | `daily_case_reminders_enabled` | `caseReminders` | 11 |
| 13 | `missions_enabled` (+ season activation at 100% rollout) | `missions` | — |
| 14 | `character_chapters_enabled` | `chapters` | 13 |
| 15 | `titles_enabled` | `titles` | 13 |
| 16 | `academy_enabled` | `academy` | — |
| 17 | `verdict_share_enabled` | `verdictShare` | — |
| 18 | `thursday_event_enabled` | `thursday` | 13 |
| 19 | `economy_v11_enabled` (option C switch) | — | — |

## 5. Risk register
| # | Risk | L | I | Mitigation | Owner |
|---:|---|:-:|:-:|---|---|
| 1 | AdMob invalid-traffic suspension from alt/ad farming | M | Critical | Device + account caps, SSV, reward only on eligible matches | Sol |
| 2 | Empty public rooms → online features feel dead | H | High | Series/Thursday concentrate play at one time; creator night; quick match fills the fullest lobby | Owner + Claude |
| 3 | Doc 05 leak via a new surface (titles, series score, ready flag) | L | Critical | Import-closure, phase-matrix and golden-equivalence tests | Claude |
| 4 | Season ends with nothing next | H | High | Season One content in 1.1, claim grace, runbook | Both |
| 5 | Daily Case becomes solvable by heuristic | M | Med | Anti-heuristic constraints, 28-day audits | Sol |
| 6 | Low-end phones lag with the new art | M | High | Staged decode, budgets, device profiling | Claude |
| 7 | Moderation load exceeds the owner | M | High | Queue filters, generic errors, restrictions, new-account limits | Sol + owner |
| 8 | Art inconsistency across 60+ images | M | High | S0 calibration gate, contact sheets, human approval | Art session + Claude |
| 9 | Scope overrun | H | Med | Single build order; each feature ships only complete; flags OFF | Both |
| 10 | Arabic copy feels translated or cringe | M | Med | Claude writes, Sol reviews, owner spot-check | Claude |

## 6. Single build order
0. Contracts and manifests frozen (this doc + SPEC + Sol's round 6 answers).
1. Safety v11 + operator RPCs + runbook.
2. IA skeleton + staged warm-up + metrics.
3. Casebook amendments (operator activation, display level, claim grace, frame, milestones, `puzzle_solve` slot) + economy option C + invite hardening + ad caps.
4. Daily Case rework (templates, anti-heuristic, requestId) + UI + reminders.
5. Table: ready-up, rematch vote, reconnect UX.
6. Scenario Deck (online + pass-and-play) + House Rules + `/rules/` links.
7. Series + Draft + `/series/` links.
8. Chapters. 9. Academy. 10. Verdict share. 11. Thursday. 12. Titles.
13. Season One content rows + art.
14. Art sessions S0→S6 run in parallel from step 1 (S0 gate first); audio cues alongside.
15. Full gates, device matrix, store media, rollout rehearsal.

## 7. Questions for Sol — attack this document
Break it. For each section, say what's wrong, missing or weaker than it could be. Specifically:
a. Is the `puzzle_solve` daily slot a good idea, or does it cheapen the Casebook for online players?
b. The ready-up grace flow — any abuse (a griefer un-readying repeatedly)?
c. Invite hardening numbers — too strict for honest players?
d. Device-level ad cap: is an install id enough; what about web?
e. Season One in 1.1 — worth it, or do the claim grace plus an "off-season" page suffice?
f. Restate the existing daily coffer, wheel, 7-day card, ad-extras and council-level numbers under option C, and flag any that break the ~19–20k/28-day committed ceiling.
g. Anything in my journeys you think I got wrong. Add a sixth persona if one is missing.

---

# Round 6 — Sol's adversarial review of ROUND5.md

# Round 6 adversarial verdict

Not yet “best possible.” Round 5 is directionally strong, but its reward model is incomplete, one proposed accessibility fix damages the Casebook, and several anti-abuse rules conflict with honest acquisition. Three material changes remain at the end.

## §0 — Decisions on merit

### Sheets versus routes

KEEP Claude’s decision. A nested Navigator inside a dismissible 0.94-height sheet is technically possible but inferior for Chapters, Academy and editors:

- Deep links cannot reliably restore an internal sheet page.
- Predictive Android back, keyboard resizing, focus restoration and accessibility traversal become fragile.
- Accidental dismissal can destroy authored progress.

Use full-screen routes with a painted rise transition, persistent close/back header and the underlying visual identity. Sheets remain correct for entry, selection, preview and confirmation. Safety admin must be a route.

### Preload

KEEP native behavior; REFINE web behavior.

Reading every bundled native asset does not create a durable useful cache. Decode and server startup are the real costs. On web, however, “cache every pack” needs limits:

- Core shell: ≤8 MB compressed.
- Background pack fill: ≤25 MB per foreground session, resumable.
- Persistent target: ≤60 MB before checking `StorageManager.estimate()`.
- Continue toward all packs only on non-slow, non-`saveData` connections with sufficient quota.
- Catch Safari quota/eviction failures silently; cached content is an optimization, never required state.
- Never issue fake server warm-up traffic. Run real auth restore, capabilities and Home bootstrap concurrently with a non-blocking timeout.

### Notifications

KEEP for Android. The offer remains after three solved days, off by default. Web receives no fake parity promise; Safari/PWA notifications are not reliable enough for this release. Notification permission refusal must permanently suppress the prompt until explicitly reopened from Settings.

### Economy

KEEP Option C, but activation must be atomic. `economy_v11_enabled` changes match rewards, eligibility, ads and result copy together. Pending pre-switch ad claims settle at the amount stored when created; they must never be repriced.

---

# §1 — Player journeys

## P1 Salma

Claude’s `puzzle_solve` daily mission is the wrong fix.

Salma is offline and has no account, so she cannot claim server coins or Season XP anyway. When online, solving one Daily Case would pay twice: its native 5/20 reward plus a mission reward. It also weakens the online-focused Casebook.

Better version:

- CUT `puzzle_solve` from daily mission assignments.
- Hide the entire Tonight rail offline when no cards have valid data.
- Pass-and-play provides local presets, Four Dossiers and post-result character moments.
- Do not interrupt her first family session with Academy. Offer it on a later Home return or after she abandons setup—not immediately after onboarding.
- Day five should visibly advance the local character dossiers from completed public results. That relationship payoff was missing from Claude’s journey.

## P2 Karim

The retry receipt is essential. Add `(user_id, day, request_id)` uniqueness and return the original result without consuming another attempt.

Ready-up needs a non-resettable deadline:

- Once ≥5 players are ready, each unready seat gets one 45-second deadline per lobby configuration revision.
- Toggling ready then unready does not restart it.
- On expiry, the unready seat returns to the room list; no kick/report implication.
- Rule changes create a new revision and clear readiness.
- After removal, the host explicitly starts; never surprise-start automatically.

Season close needs stronger behavior than manual claim grace. At `ends_at`, progress freezes. The next server sync automatically grants every unlocked, unclaimed track reward idempotently. The closed trail remains viewable for seven days. Nobody loses a frame because they missed a button.

## P3 Abu Youssef

House-rule links are correct, but the import must work without authentication and only save locally until the user deliberately hosts.

Thursday mismatch needs an action, not just text:

> “Only tonight’s featured scenario earns Thursday progress”  
> `Use featured scenario`

`/series/CODE` must preserve its destination across auth restoration, expire cleanly, pass block checks, and never expose roster/title metadata in WhatsApp previews.

## P4 Returning player

The message is honest, but migration rules are missing:

- Keep 12,000 coins exactly.
- Preserve Council XP, level, inventory and purchases.
- Never retroactively recalculate old match rewards.
- Finish pending ad claims at their recorded value.
- Show the economy note only to accounts with pre-1.1 match history, once.
- Returning players may immediately unlock lifetime achievements. If those still grant Season XP, say so explicitly; otherwise day-one “mystery levels” will look like a bug.

## P5 Troll with alts

The `<24h cannot send direct invites` rule is too broad: it damages the exact friend-link acquisition loop being marketed.

Better:

- New accounts may accept links, join invited rooms and invite existing accepted friends.
- For 24 hours they cannot send unsolicited friend requests, appear in public discovery, or mass-create invitations.
- Blocks suppress all future matching, but never reveal the blocker.
- Coin, ad and invite eligibility share the same authoritative finished-match receipt and group/device limits.

---

# §2 — Contradiction audit

Claude found 11, but these remain:

12. `character_chapter_progress` says objective selection is immutable; Round 3 allows one change. **One change wins.**

13. F4 still specifies server attempts and answer RPCs; Round 3 replaced these with offline Dart fixtures and `academyClaim`. **Delete the obsolete schema/actions.**

14. Casebook says recurring maximum is 1,680 coins. Actual catalogue permits `finish_3=10`; daily maximum is 40, making the 28-day maximum **1,820**: 1,120 daily + 300 weekly + 400 track.

15. Achievements are shown as zero XP in Round 5, but the migration grants **750 Season XP** total.

16. Council Rank currently counts up to 20 matches/day while Option C and Casebook use six. That enables prestige farming. **Set Council XP eligibility to the same six/day and three/same-group cap.**

17. Match Awards are omitted from the final faucet table. Their current stacked 5/15-coin grants can materially exceed the 20k estimate.

18. A 12-ad device cap conflicts with a single honest account’s maximum: 12 match ads + one daily ad + three extras = 16.

19. “Five invite rewards per season” conflicts with the existing 20 lifetime cap unless both limits are explicitly retained.

20. “Season One ships inside 1.1” contradicts the scope-control argument and doubles content obligations.

21. “Pass-and-play puzzle path” is misleading. Daily Case is server content available to guests with connectivity; it is not a local match reward path.

22. The supposedly final flag table omits most existing economy, advertising, Council, awards and payment flags.

The final sign-off document must replace superseded sections rather than append another amendment.

---

# §3 — Correct final faucet model

First, change Match Awards to flavour-only: `award_coins=0`, `award_mvp_coins=0`. Stacking behavioral awards creates inflation and encourages players to optimize for badges instead of winning.

| Faucet | Coins | Season XP | Council XP | Limit |
|---|---:|---:|---:|---|
| Eligible online completion | 25 | **5 proposed** | 30 | 6/day; 3/same group |
| Win | 10 | **+5 proposed** | +20 | Same |
| First eligible match/day | 25 | — | — | 1/day |
| Match ad step 1/2 | 25/25 | — | — | Coin-eligible matches only |
| Daily mission `finish_1` | 5 | 25 | — | Assigned/claimed once |
| Daily mission `finish_3` | 10 | 40 | — | Same |
| Other daily missions | 10 | 40 | — | Same |
| All-three bonus | 10 | 25 | — | 1/day |
| Weekly mission | 75 | 180 | — | 1/week |
| Season track | 400 total | — | — | Once/season |
| Daily Case | 5 | 20 | — | 1/day |
| Chapters | 0 | 100 each | — | Four lifetime/versioned |
| Academy | 10/20 each; graduation 25/50 | As preceding: 20/50 | — | 65 coins, 130 XP total |
| Thursday | 0 | 20/match | — | Two/week |
| Achievements | 25/50/100/75/75/50 | 50/100/200/150/150/100 | — | 375 coins, 750 XP lifetime |
| Daily coffer | 20 | — | — | Daily |
| Every seventh coffer claim | 60 | — | — | Every 7 claims, not streak |
| Wheel | 10/20/35/60/100 at 40/30/20/8/2% | — | — | Daily; EV 23.8 |
| Daily rewarded ad | 25 | — | — | Daily |
| Extra wheel ad | Same wheel | — | — | Daily; EV 23.8 |
| Extra coffer ad | +20 | — | — | Daily |
| Contract-swap ad | 0 directly | — | — | Daily |
| Council level | 25; every fifth 100; level 50 = 300 | — | — | 2,175 lifetime total |
| Invitee | 50 | — | — | Once/account |
| Inviter | 100 | — | — | 5/season and 20 lifetime |
| Match Awards | **0** | — | — | Flavour only |
| Pass-and-play | 0 | 0 | 0 | Bonds only |

Paid 500/1,200/2,500 packs and the 600-coin Starter Bundle are purchases, not faucets.

At 50% wins, maximum daily mission payout, and expected wheel outcomes, recurring 28-day coins are approximately **19,493**:

- Matches/wins/first-match: 5,740
- Match ads: 8,400
- Casebook: 1,820
- Daily Case: 140
- Daily system and extras: 3,393

Lifetime achievements, Academy and Council levels are not recurring. Referrals add up to 550 for a user acting as both invitee and maximum seasonal inviter.

The old 20/10 Season XP per match is too generous: six matches/day already produce 4,200 XP at 50% wins, completing the entire season without the “huge missions system.” Reduce it to 5/+5 so missions remain the primary season loop.

---

# §4 — Flags

Round 5’s table is not final. It must also include:

- `ad_steps_enabled` → `adSteps`
- `daily_enabled` → `daily`
- `daily_ad_enabled` → `dailyAd`, depends on daily
- `interstitial_enabled`
- `pre_match_interstitial_enabled`
- `pass_and_play_interstitial_enabled`
- `session_interstitial_enabled`
- `app_open_enabled`
- `banner_enabled`
- `ad_extras_enabled`, depends on daily
- `council_contracts_enabled`
- `council_rank_enabled`
- `council_leaderboard_enabled`, depends on rank
- `council_invites_enabled`
- `starter_bundle_enabled`, depends on active product
- `awards_enabled`
- `reactions_enabled`
- `founder_enabled` plus configured window
- `transfer_enabled_web`
- `transfer_enabled_android`—remain OFF
- every `play_products.active` row—separate operator switches

Corrections to new flags:

- `economy_v11_enabled` must expose `economy.version=3`.
- `metrics_enabled` is server-only.
- `daily_case_reminders_enabled` is a remote kill switch plus local opt-in.
- `thursday_event_enabled` depends on Missions, an active season and canonical scenario resolution—not Scenario Deck UI.
- Safety should fail closed for public matchmaking if its configuration cannot load.
- Reconnect presentation and preload are implementation behavior, not feature flags.

---

# §5 — Risk register

The current register underrates scope and omits deployment failure.

| Risk | L/I | Better mitigation | Owner |
|---|---|---|---|
| Empty public rooms | H/H | Concentrated Thursday event, fullest-lobby matching, creator schedule | Product |
| Scope/quality collapse | H/H | Vertical feature gates; cut Season One from 1.1 | Both |
| Ad fraud/suspension | M/Critical | SSV, 16/account, 20/install, anomaly monitoring | Backend |
| Doc 05 regression | L/Critical | Closure, phase matrix, golden equivalence | Client |
| Migration/flag mistake | M/Critical | Snapshot, dry-run, operator RPCs, rehearsed rollback | Backend/operator |
| Moderation evasion | M/High | Global compatibility checks, queue, restrictions | Backend/owner |
| Economy inflation | M/High | Faucet simulation, awards at zero, weekly ledger audit | Backend/product |
| Low-end/web performance | H/High | Stage budgets, Safari quota handling, device gates | Client |
| Supabase outage/cold start | M/High | Cached safe UI, retries, no duplicate mutations | Both |
| Links/auth/PWA state loss | M/High | Resume tokens, web fallback, end-to-end link matrix | Client/backend |

---

# §6 — Build order

The current order places title infrastructure after features that grant titles, and deep links after their consumers.

Correct order:

1. Consolidated contract, reward simulation and flag matrix.
2. Safety, operator controls and rollback rehearsal.
3. Auth/deep-link foundation for `/rules`, `/series`, invite and notification routes.
4. IA, preload and metrics.
5. Economy C, ad/device caps, Council cap alignment, invite hardening.
6. Title/frame inventory and equip infrastructure.
7. Casebook amendments and Daily Case rework/reminders.
8. Ready-up, rematch vote and reconnect.
9. Scenario Deck/House Rules, then Series/Draft.
10. Chapters and Academy.
11. Share cards and Thursday.
12. Feature art batches immediately before their UI, not as one late integration wave.
13. Full device/web/safety/economy gates, store media and rollout rehearsal.

Season One is not part of 1.1. Create its production brief by day 14 and ship its content pack by day 21. The closed-season page is the operational fallback.

---

# §7 — Direct answers

**a. Puzzle daily slot:** CUT. It double-rewards the same puzzle, cannot help an offline player, and dilutes an online Casebook.

**b. Ready-up abuse:** Real. Use one deadline per player per configuration revision; ready/unready toggling never restarts it.

**c. Invite hardening:** Three separate days is too strict. Require three eligible public matches over two UTC days, at least one without the inviter, five distinct non-inviter co-players, and account age ≥48 hours before the inviter’s 100 coins settle. Give the invitee 50 after their first eligible match. Keep five inviter payouts/season and 20 lifetime.

**d. Device cap:** Install ID is only a rate-limit hint; reinstall, cloning and cleared web storage defeat it. Use 16/account/day and 20/install/day. Store only an HMAC of the random install ID. A rotating IP-prefix hash may trigger review, never hard-block families. Rewarded ads remain unavailable on web until a supported signed provider exists.

**e. Season One:** CUT from 1.1. Build the pipeline and off-season state now; produce Season One as scheduled live-ops content before day 21.

**f. Existing values:** Restated exactly in §3. The critical problems are Match Awards, the omitted 750 achievement XP, the actual 1,820 Casebook maximum, and Council’s 20-match XP cap. Awards must become non-economic and Council must use six eligible matches.

**g. Journey errors:** The puzzle mission, new-account direct-invite ban, 12-device-ad cap and Season One inclusion are wrong. Automatic settlement is safer than merely offering a seven-day claim grace.

# Sixth persona: Nour, 26, iPhone Safari in Dubai

Nour receives a Thursday series link on WhatsApp. There is no iOS app, so the Universal Link must deliberately fall back to web—not show a broken “open app” prompt. The intended series destination must survive Google authentication and Safari tab reloads.

Dubai is two hours ahead of Cairo during the relevant schedule. At 01:30 Dubai, the UI must show the event as live because it is 23:30 Cairo; all eligibility remains server-authoritative in `Africa/Cairo`, while the countdown is rendered in her local time with “Cairo event” context.

Safari may evict CacheStorage, block autoplay, deny microphone permission or run in private mode. Therefore:

- Every route works with lazy asset recovery.
- Voice failure never blocks joining.
- Service-worker cache loss never loses progression.
- Share uses Web Share API with download fallback.
- Notifications are unavailable without pretending otherwise.
- If the series is full/expired/blocked, she gets Join Public/Create—not a dead error page.
- Web transfer is the only external payment surface; Android transfer policy is irrelevant.
- Guest progress produces the same save-account prompt as Android.

## Final verdict

The plan is not yet best possible. The final three changes are:

1. Protect the missions fantasy by cutting `puzzle_solve` missions and reducing direct match Season XP to 5/+5.
2. Finalize one coherent anti-abuse economy: awards non-economic, 16/account and 20/install ad caps, six-match Council cap, acquisition-safe invite rules.
3. Replace the amendment stack with one normalized specification containing only current schemas, RPCs, rewards, flags and rollout rules.

With those incorporated, I would support final sign-off.
