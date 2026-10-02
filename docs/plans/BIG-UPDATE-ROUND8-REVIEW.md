--- codex final report ---
# Round 8 verdict

Round 8 has good instincts but overloads 1.1, duplicates progression systems, and occasionally mistakes “more content” for deeper entertainment. The strongest correction is: ship a lean Partner in 1.1, defer Group Book and anniversaries, and make the future party headline a complete hosted evening rather than a pile of disconnected modes.

## B. Ads per match

### Honest model

Planning assumptions—not forecasts:

- Daily match distribution per 100 DAU: 50 play 1 match, 25 play 2, 12 play 3, 7 play 4, 4 play 5, 2 play 6. Average: 1.91 matches.
- Two rewarded offers per match; 35% completion per offer: 134 rewarded impressions/100 DAU.
- Rewarded eCPM: $2.00; automatic fullscreen eCPM: $0.90.
- 80% automatic load/show success.
- Banner, app-open, IAP, and country-mix effects excluded.

| Model | Automatic opportunities/100 DAU | Shown | Ad ARPDAU | 10k DAU/month |
|---|---:|---:|---:|---:|
| 1. Cap 2/day | 150 | 120 | $0.00376 | ~$1,128 |
| 2. Every match after first two | 46 | 37 | $0.00301 | ~$903 |

Model 2 earns less overall because most players never reach match three. It earns more from a six-match player: approximately $0.0113/day versus $0.0098, but that is only about $0.0014 extra while repeatedly interrupting the cohort most likely to return, host series, and buy cosmetics.

No defensible public study gives a universal “three interstitials cause X% D7 loss.” Anyone supplying that precision is bluffing. What is known:

- Google says interstitials belong at natural transitions, warns that too many drive users away, and notes some ads delay closing by 5–30 seconds. [AdMob guidance](https://support.google.com/admob/answer/6066980?hl=en)
- Google prohibits overwhelming repetition, unexpected launches, and ads that obstruct navigation. It provides no universal daily cap; compliance depends on flow. [Disallowed implementations](https://support.google.com/admob/answer/6201362?hl=en)
- Industry research reports a 4:1 preference for rewarded ads over interstitials. Its retention correlations are selection-biased—engaged users are more likely to watch rewards—but still support player choice over forced exposure. [Unity/ironSource analysis](https://unity.com/blog/understanding-the-impact-of-rewarded-ads-on-iap-retention-and-engagement)

A post-result transition is policy-suitable only if the player explicitly taps an in-app continuation and the preloaded ad appears before navigation completes. Never trigger it from OS exit/back or after Home has appeared.

### Recommendation

Model 1 wins on merit:

- Two optional rewarded offers continue scaling with every eligible match.
- Maximum two automatic fullscreen impressions per UTC day, globally shared with app-open.
- First two lifetime online matches and the first eligible match each day are automatic-ad-free.
- Twenty-minute fullscreen gap; current post-reward suppression remains.
- Never interrupt an active best-of series between rounds.
- Result-exit only, after every reward and public story has been seen.
- Quiet Pass/Membership removes automatic ads, but rewarded offers remain voluntary.
- Never display an ad offer when its reward is unavailable.

Later test one additional automatic impression after match four, not “every match.” Require D7 degradation under 1.5 percentage points, D30 under 1 point, series continuation within 5%, and no meaningful rise in ad-related reports/reviews. The owner’s revenue intent is respected by unlimited per-match rewarded opportunities; forced frequency is the wrong place to scale.

## C. Attack on Round 8

### A1 — Group Book: CHANGE and move out of 1.1

It partly duplicates painted match history, saved groups, series history, dossiers, and Legacy. It is not worth another screen in an already enormous release.

The proposed safety test—“schema has no role field”—is inadequate. A generic event payload, seat outcome, elimination list, or player-to-winning-side join can recreate role history without a column named `role`.

If built in 1.1.x/1.2, allow only:

```text
group_id, roster_revision, receipt_id, ended_at,
winner_alignment, day_count, host_key, local_timezone
```

Ban seat-level outcomes, votes, targets, deaths, survivor identities, player/alignment joins, and generic JSON event storage. Remove “days survived as a group”; it is undefined and invites survivor-derived data. “Nights” must mean completed matches, not engine night phases. Receipts are idempotent by match ID.

Roster edits create a new `roster_revision`; otherwise statistics silently mix different tables. Titles may aggregate completed results across revisions, but the UI must say so.

Mafia/town totals and streaks are Doc-05-safe after public results, but never produce correlations such as “when Ahmed hosts, Mafia wins.”

### A2 — Party modifiers: CHANGE

The catalogue currently contains one unenforceable social rule, one timer setting, one renamed existing mechanic, and one preset. That is not a coherent feature.

For 1.2, split them into:

- Engine-backed modifiers: timer curve, defence phase, runoff structure.
- Host-enforced party challenges: gesture discussion, one-word defence, rotating spokesperson.

Label the second category honestly; the app times it but cannot enforce it. Every modifier needs accessibility compatibility, a conflict matrix, and a preview of exactly what changes. “No Doctor” remains a Scenario Deck preset, not a modifier.

### A3 — Proverb Bluff: KEEP for 1.2

This is culturally strong, inherently social, and meaningfully different from Mafia. But the one-phone flow needs specification:

1. One player privately reads the real ending.
2. Everyone else privately enters a fake ending through sequential handoffs.
3. Anonymous endings are revealed together.
4. Each player votes privately.
5. The real proverb and bluff authors are revealed.

The catalogue needs Egyptian, Gulf, Levant, family-safe, and mature-content tags; dialect review; duplicate normalization; source/provenance review; and a “report wording” function. Do not charge for the culturally essential base game. Sell a themed expansion only after the free 300-proverb pack proves repeat play.

### A4 — Coffeehouse League: CUT in its current form

Mafia assigns teams randomly; an individual bracket pretends the result measures skill. That produces arguments, not meaningful competition.

Replace it with a communal “season of the table”: completed evenings, scenario diversity, series finishes, and shared group milestones. No player rating and no economy. Series already supplies the competitive structure.

### A5 — Big-screen: KEEP for 1.3, online-only initially

A TV must consume the exact server-produced public snapshot, never derive a filtered view from a private snapshot.

Do not support pass-and-play by mirroring the host screen; one private role frame reaching the television is catastrophic. A later local-table implementation requires a separate public-state publisher and second-device access code. Until then, `/tv/<code>` is online-only, revocable, spectator-safe, and optionally delayed.

### A6 — Storyteller: REMOVE from the committed roadmap

Clocktower’s storyteller works because a rich role system requires adjudication. With four roles, Mafia Master would add host labor without equivalent depth. A soundboard is not a mode.

Keep it as research beyond 1.4. Preconditions:

- At least eight well-tested roles/modifiers.
- A separate narrator device or rigorously isolated console.
- Complete Doc-05 threat model.
- Evidence that hosts want adjudication rather than automation.

### B1 — Partner: KEEP in 1.1, radically simplify

The relationship is important; the proposed implementation is bloated.

- Reuse the four existing gallery portraits.
- Load only the selected portrait with a decode-size bound; evict the previous one after switching.
- No 12 pose assets. On a 3 GB device, twelve large transparent portraits can consume tens of decoded megabytes for almost no emotional gain.
- The Season Pass unlocks exactly four partner outfits, one per character at levels 5/12/15/17. A second outfit set may be sold in 1.2.
- Allow switching freely outside a live match. A weekly lock creates regret without stopping abuse—there is nothing to abuse.
- Do not create a second affinity grind. Existing dossier cases, tiers, chapters, and letters are the relationship progression.
- Persist the preference locally for guests and sync it as an account preference later; premium ownership remains server-authoritative.

The partner may voice a Casebook header, but must not replace each mission’s issuing character. In the Daily Case, the Detective remains the authority; another partner may provide a cover line only.

No partner state may enter role reveal, pass, night, live seats, or active lobby state. Post-result reactions use only public outcome facts and never the device player’s former role or private action.

### B2 — Fifth letter: KEEP, rename

Call it the “chapter seal,” not tier 5. A fifth tier contradicts the established 1/3/7/15 four-tier progression. Chapter completion unlocks the final letter and seal independently.

### B3 — Anniversaries: CUT from 1.1

Almost nobody will have a one-year bond ledger at launch; “100 nights” is ambiguous; and “your first win” may be invented for a pass-and-play host who did not personally hold a role. This is low-value complexity.

Revisit in 1.2 with exact receipts such as first completed case date, 50 completed cases, and chapter anniversary. Never infer a personal victory from a table result.

### B4 — Lobby reactions: KEEP in 1.2 with restrictions

The line must be derived solely from the selected scenario and partner preference, be identical regardless of any assigned role, and disappear before dealing begins. It must not delay ready-up or start.

### B5 — Fifth character: CHANGE and delay

Do not promise a role before prototypes exist. The Guard overlaps the Doctor and creates another private target/information channel. The proposed Mayor’s permanent doubled vote is too strong and makes public confirmation strategically dominant.

The better candidate is a limited Mayor:

- May publicly declare once per match.
- Can resolve one tied public vote.
- Gains no hidden information.
- Declaration intentionally reveals the Mayor under an explicit engine rule.

It is culturally legible and theatrically strong, but still needs simulation and Doc 09/11 treatment. Put role discovery in 1.4, not production in 1.3.

### Revenue additions

The table is stale:

- Partner outfit set 1 ships in the 1.1 Season Pass, not 1.2.
- It contains four outfits, not “two per character.”
- Outfit set 2 may be direct-sale in 1.2.
- Group Book covers wait until Group Book retention is proven.
- Proverb expansion is acceptable, but it is a digital product and must use Play Billing on Android.
- TV themes and narrator soundboards remain tied to their deferred features.

### Roadmap correction

| Release | Better scope |
|---|---|
| 1.1 | Agreed core, commerce, Season Pass, and lean Partner. No Group Book or anniversaries. |
| 1.1.x | Season One content, puzzle audits, live-ops tuning, optionally Group Book beta after core stability. |
| 1.2 | “Party Night”: Proverb Bluff, safe modifiers, Group Book, second partner outfits, lobby flavour, voice reliability work. |
| 1.3 | “The Table Everywhere”: iOS if owner prerequisites exist, online spectator/TV, creator tools, complete-evening director. |
| 1.4 | Fifth-role prototypes, community/crews only if moderation and density support them; storyteller remains conditional. |
| 2.0 | Expanded roles/scenarios, mature tournaments, regional copy packs, and deeper creator systems. |

Moving iOS from 2.0 to 1.3 matters commercially, especially for Gulf audiences. Voice reliability also cannot wait until 2.0 while online social growth is the strategy.

### Offline↔online bridge

A local saved group contains names, not account identities. “Continue online” therefore cannot silently create a populated series. It should create an empty online lobby and share a link; invitees claim their own seats.

Do not bury the “offline gives bonds, online gives economy” distinction in Academy. Put a concise eligibility explanation beside the first visible reward, once. Academy is for learning the game, not defending monetization rules.

## Answers to Claude’s six questions

1. The unsafe Group Book fields are survivor identities, player/alignment joins, seat-level outcome history, votes, targets, deaths, or generic event payloads. Aggregate winner and day count are safe. Remove “days survived.”

2. Weekly partner switching is annoying. Switching should be free outside matches; dossier progression remains intact. Commitment comes from writing and remembered milestones, not a timer lock.

3. Pass-and-play TV is unsafe until it has an independently generated public snapshot. Ship online-only.

4. Neither current role is ready. Prototype the limited, public tie-breaking Mayor before the Guard; commit neither until simulations and leakage tests pass.

5. The roadmap is too front-loaded and postpones iOS/voice too far. Use the corrected roadmap above.

6. The missing killer tool is **«سهرة جاهزة» / The Night Director**: choose 30/60/90 minutes, player count, and family/friends tone; the app conducts a complete evening—warm-up, scenario draft, a short series, intermission, finale, and shareable chronicle. It composes existing systems into one effortless experience. That can beat fragmented party-game apps because the host presses once and the app becomes the evening’s MC. All transitions are public; private information remains solely inside the existing match flow.

## D. Round 9 online-core audit plan

I will audit these layers:

1. **Client state and lifecycle**
   - `lib/transport/online_transport.dart`
   - `supabase_backend.dart`, `online_backend.dart`, `room_codec.dart`, `game_snapshot.dart`
   - `online_session.dart`, `online_table_flow.dart`, `lobby_screen.dart`
   - `online_session_store.dart`, router/resume/deep-link paths

2. **Server mutation surface**
   - Every room/match edge function: create, join, leave, quick-match, settings, start, host claim/handoff, kick, phase open/advance, voting, night actions, resolution, presence, rematch.
   - Foundational room/state migrations plus atomic entry/start/settings/resolution, presence, abandonment, public-room, quick-match, rematch, friends, and safety migrations.

3. **Failure and race matrix**
   - Double taps and retries.
   - Duplicate/out-of-order/missed realtime events.
   - Stale epoch/phase actions.
   - Concurrent join/start/kick/host-leave.
   - Reconnect or process death in every phase.
   - Auth refresh, room expiry, clock skew, weak network, and edge timeout.
   - Quick-match double allocation.
   - Rematch/series split-brain.
   - Voice failure with gameplay completion.
   - Block/report/friend changes racing with invitations and room entry.

4. **Security and Doc 05**
   - RLS, function privileges, realtime filters, public snapshots, error bodies, logs, witness data, voice metadata, and reconnect payloads.
   - Prove no private role/action data reaches an unauthorized seat—even transiently.

5. **Performance and operations**
   - Payload size, subscription/channel count, polling/heartbeat amplification, indexes, slow RPCs, cold-start behavior, abandoned-room cleanup, and capacity assumptions.

Evidence delivered in R9:

- A line-referenced defect register with severity, reproduction, blast radius, and proposed fix.
- A state-transition/race matrix showing the authority and idempotency key for every mutation.
- Results from existing Dart transport/online/voice tests, SQL suites, Python concurrency/recovery scripts, and Node edge tests.
- Targeted repeated/fault-injection runs where available—not “tests exist,” but pass counts and failures.
- SQL `EXPLAIN` evidence for critical room-listing, quick-match, presence, and resume queries.
- An observability gap list: correlation IDs, structured refusal codes, latency/error aggregates, reconnect health, and strict prohibition on logging hidden roles.
- A release-blocker list separated from post-launch hardening.
--- end report ---
