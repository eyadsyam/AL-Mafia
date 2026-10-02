# Game big round 2 — Claude's integrated proposals, wave-2 ideas and pre-mortem; Sol criticises and closes

## 1. Answers to Q1–Q10

1. **Q1 — Agree.** Spoken narration launches only for pass-and-play public-table beats; online narration waits for a proven synchronized/ducked design.

2. **Q2 — Agree.** Add this constitutional rule: “During a match, narration may not invent an event, cause, location, object, time, trace or action. Atmospheric fiction exists only after the public result.”

3. **Q3 — Agree, with discipline.** The 115–130-hour ceiling is credible only after the agreed removals; 130 hours must remain a ceiling, not become the next estimate to overrun.

4. **Q4 — Disagree on keeping streak-save at L.** It is not genuinely S: it needs missed-day eligibility, a 24-hour window, once-per-seven-days enforcement, UTC boundaries, reward-completion recovery, idempotency, Android/web divergence, cap interaction, copy and metrics. More importantly, “the only D7 protection” is unproven—the Daily Case itself, reminders, Thursday and Casebook are already D7 mechanisms. Ship the clean streak first, measure missed-day churn, then add rescue in 1.1.x. If the owner insists on L, it must never threaten loss, grant currency or consume an attempt, and failed completion must not spend eligibility.

5. **Q5 — Agree.** Last words occur before role revelation and before dead/witness state. The floor closes and voice publication updates atomically before witness access exists.

6. **Q6 — Agree.** Thursday is the only scheduled queue at first. Additional days require repeated 12–15-person windows and ≥80% match entry, not one successful night.

7. **Q7 — Agree.** The authored rehearsal precedes general bots and must be explicitly presented as a rehearsal, not a simulated human table.

8. **Q8 — Agree.** Kill gates must include minimum samples, percentile latency and mode-specific denominators; averages alone will hide failure.

9. **Q9 — Agree.** «قعدة من غير تمرير» is the 1.2 table headline. W6 can validate demand earlier, but it cannot impersonate the dedicated-display experience.

10. **Q10 — Modify.** Twelve listeners and 9/12 approval are appropriate, but “natural” and “not cringe” must be separate questions. Require no demographic subgroup below 2/3 approval, blind comparison against the current text/SFX experience, intelligibility in a noisy room, and an explicit “would you keep this enabled after ten matches?” result.

## 2. Wave-2 verdicts

| Idea | Verdict | Doc 05 / product correction | Size | Release |
|---|---|---|---:|---|
| **W1 Vote timeline** | **KEEP, move from L** | Online ballots are not all public while voting: secret ballots reveal only after resolution, while open ballots may be visible live. The post-result service may read settled ballots, but the normal snapshot should not gain historical votes. Build a dedicated result-only projection. Show abstentions and revotes honestly. | M, 1–2 days | **1.1.4** with chronicle/sharing |
| **W2 Family mode** | **KEEP, modify** | Make it an immutable room/session setting selected before the deal, not a per-role or mid-match toggle. It disables reaper motion, harsh cues and horror copy for everyone. Do not claim the entire online environment is child-safe merely because effects are softer. | S–M, 1 day | **L** |
| **W3 Post-result reactions** | **KEEP** | Result-only, one reaction per player with a short cooldown. No free text. Avoid lines suggesting privileged knowledge; after the result they are flavour, but they should not rewrite the chronology. | S, <1 day | **1.1.x** |
| **W4 Painted local avatars** | **MODIFY** | The Daily Case portraits represent recurring fictional suspects. Reusing them as player identities could confuse Case imagery and table identity. Use carefully selected neutral crops or a subset presented as “table faces”; names remain primary. Selection is pre-deal and role-independent. Never alter the portrait by current role. | M, 1–2 days | **1.1.x**, after portrait QA |
| **W5 Narrated how-to-play** | **MODIFY** | Do not force a passive 60-second film. Create three skippable 15–20-second scenes: deal/privacy, night/public morning, discussion/vote. The Gang demonstrates; G1 narrates. Offer the first scene contextually and keep the complete guide in Learn. | S–M, 1 day | **L** |
| **W6 Same-room v0** | **KEEP, modify strongly** | The code confirms the online night is a private phase on every player’s phone, including the host. The current presentation layer deliberately keeps night sound silent. Therefore the host device must not narrate night entry or any private night beat. V0 is: voice off, QR/web join, same-room label, and one elected audio device for **morning, discussion, voting and result only**. If that device backgrounds or enters an overlay, narration fails silently; gameplay continues. | M–L, 2–4 days | **1.1.3**, not before online reliability |
| **W7 Witness-knowledge setting** | **KEEP, modify** | Immutable after the deal and visible in the lobby summary. Default ON preserves the owner’s decision. OFF must prevent role/night-action publication at the server, not merely hide the panel. Ghost chat can remain, but receives public state only. Settings cannot change during a series round. | M, 1–2 days | **1.1.x** |
| **W8 Tabletop narration layout** | **KEEP** | Public-table phases only. Use large design-token typography, high contrast and a distance-tested timer. Never let the layout persist into hand-off, role reveal or private night. Test at 1 m and 2 m, not only at 360 px in hand. | M, 1–2 days | **L** |

W6 is worthwhile before v1 because it tests a real proposition: will co-located groups use multiple phones to remove hand-offs? But its honest promise is “everyone joins on their phone,” not “the host phone becomes a complete narrator.” The dedicated public display remains the full 1.2 experience.

## 3. Pre-mortem

### Ranked failure register

| Rank | Failure | Attack on current mitigation | Corrected gate |
|---:|---|---|---|
| **1** | **PM10 — Scope produces a late, inconsistent release** | “Every row passes or moves” is a principle, not an enforcement mechanism. Teams rationalize almost-finished work at the deadline. | Feature freeze ≥14 days before RC; ≥20% schedule reserved for integration; no launch copy/art for a feature before its end-to-end gate passes; unfinished rows are removed, not left visibly disabled. |
| **2** | **PM1 — Public rooms remain empty** | Median wait hides abandoned players and bad hours. Thursday and invites do not guarantee simultaneous liquidity. | At ≥100 queue sessions: p50 wait ≤3 min, p90 ≤6 min, ≥70% enter a match, ≤20% abandon before placement, and no 1–4-person orphan group created by sharding. If failed, keep public queue secondary to invites. |
| **3** | **PM2 — First large القعدة is slow/confusing** | A four-minute night does not measure role distribution, accidental exposure or total setup fatigue. | At 10 and 15 players: median hand-off ≤6 s, p95 ≤12 s; full assignment ≤100 s; night p90 ≤4 min; zero observer role guesses above chance in recorded tests; ≥30% start another local match initially. |
| **4** | **PM5 — Leakage defect or credible leakage rumour** | “Zero confirmed leaks” depends on reports and detects failure too late. Some rumours will concern legal UI differences rather than real leaks. | Automated private-payload allowlists; import-closure tests; per-role visual/timing recordings; 20 observer trials with guesses at chance; incident classification within 4 hours; any confirmed exploit pauses the affected mode immediately. |
| **5** | **PM6 — Low-end jank/OOM** | Asset warming alone does not constrain decoded memory or phase-transition stalls. | On two representative 2–3 GB devices: crash-free ≥99.5%, ANR <0.5%, stage-0 p95 ≤1.2 s, no private-phase frame >250 ms caused by asset decode, bounded RSS per FINAL, and five consecutive matches without monotonic memory growth. |
| **6** | **PM3 — Voice technically connects but is unusable** | “Connect ≥90%” allows one in ten users to fail and says nothing about setup time, dropout or intelligibility. | Initial connection ≥95%, p95 setup ≤8 s, mid-match unrecovered drop <5% of matches, recovery ≤15 s when possible, and equal match-completion rate within five points when voice is disabled/broken. |
| **7** | **PM8 — Toxic public rooms** | Block rate is ambiguous: a rising rate may mean better tool discovery or worse abuse. An SLA without encounter prevention is insufficient. | Reports per 1,000 public matches, median review time <24 h during rollout, zero rematching/inviting/friend requests across a block, repeat-offender rate tracked, and severe reports triaged before broader rollout. |
| **8** | **PM4 — Lone installers do nothing meaningful** | D1 ≥25% alone cannot diagnose whether Case, Partner or online failed. It can also be distorted by invited installs. | For organic lone installs with ≥1,000-device sample: ≥60% complete one meaningful action on D0; report Case completion, lobby entry and invite separately; D1 target ≥25% remains an assumption until cohort data exists. |
| **9** | **PM7 — Monetization pressure damages play** | Review text is sparse, delayed and selection-biased. Cohort comparisons can also be confounded by engagement. | Track result-exit abandonment, next-match rate, session length and D1/D7 by actual ad exposure; no automatic ad before the existing grace conditions; investigate if exposed D7 is >3 points below matched unexposed cohorts. |
| **10** | **PM11 — The Four become a decorative menu** | Dossier opens do not prove attachment; players may open only for a badge or notification. Fifteen-case progression may exhaust quickly for heavy players. | ≥30% of D7 players open a dossier, ≥20% voluntarily switch or revisit Partner content, repeat line rate remains bounded, chapter-start conversion is measured, and no character has fewer than four weeks of non-repeating eligible lines at launch cadence. |
| **11** | **PM9 — Art is technically polished but emotionally wrong** | Owner approval and a contact sheet detect craft inconsistency, not audience reaction or cultural uncanniness. | Blind test with 12–20 target players: ≥75% identify the intended mood, no recurring anatomy/cultural complaint, all crops pass 360 px and store formats, and every recurring face passes side-by-side consistency review. |
| **12** | **PM12 — Dead-to-living collusion damages competitive rooms** | Reviews/reports severely undercount private external messaging. W7 mitigates knowledge, not communication itself. | Server test proves OFF publishes no other roles/night actions; setting is immutable; adoption is measured; competitive-room complaints are tagged separately. External communication remains an explicitly accepted residual risk. |

### Missing failure modes

#### PM13 — Matches become too long to finish

New rituals, confrontation, last words, revotes and generous family pacing can turn a 20-minute game into an hour.

- **Mitigation:** publish time budgets per preset; only one defence ritual; last words fixed at 15 seconds; family mode has hard caps.
- **Gate:** by player-count band, p50/p90 total duration, phase duration and quit rate; p90 ≤35 minutes for the standard 8-player preset and <5% voluntary mid-match departure unrelated to network loss.

#### PM14 — A host/network failure leaves an unrecoverable room

A beautiful meta-game cannot recover confidence after one lost night action or contradictory result.

- **Mitigation:** existing host handoff, receipts, reconnect and process-death work remain before every new online feature.
- **Gate:** scripted chaos suite across every phase: host termination, process death, duplicated action, lost response and reconnect. Zero divergent outcomes; ≥95% resume success; no acknowledged action silently disappears.

#### PM15 — The narrator is embarrassing or exhausting

G1 could be the strongest improvement or the fastest route to players muting the game.

- **Mitigation:** owner and listener gate, multiple takes, restrained writing, independent narration volume.
- **Gate:** ≥9/12 natural and ≥9/12 not-cringe; no subgroup below 2/3; ≥75% intelligibility in the noisy-room test; fewer than 20% disable it after three local matches; tenth-match approval ≥8/12.

#### PM16 — Too many room options fracture comprehension and matchmaking

Ready rules, witness settings, family mode, presets, series and same-room mode can create a settings product rather than a party game.

- **Mitigation:** four canonical presets; advanced rules behind Scenario Deck; safe defaults.
- **Gate:** a new host creates a valid room in ≤45 seconds without help; ≥80% use a preset unchanged initially; no more than three primary choices on any entry screen; incompatible combinations rejected before room creation.

#### PM17 — Same-room multi-phone mode excludes the groups it claims to improve

Some gatherings have weak connectivity, limited devices or relatives unwilling to join on their phones.

- **Mitigation:** it remains optional; one-phone pass-and-play stays the Home hero; web join avoids installation friction.
- **Gate:** measure lobby created → five joined → match started. If <50% of same-room lobbies reach a match or median setup exceeds three minutes, do not promote it over pass-and-play.

## 4. Final launch list

The following is a **129-hour ceiling**, not a target to fill.

| Order | Launch work | Hours | Gate |
|---:|---|---:|---|
| 1 | Online-core release blockers and Doc 05 payload/error hardening | 8 | Targeted online/leakage suites ×3; chaos cases; publication allowlist |
| 2 | Safety v11 and owner review queue | 8 | Block across every social surface; report retention/rate limits; review drill |
| 3 | Operator controls, metrics, warm-up and low-end performance | 11 | Audit/idempotency tests; metric allowlist; F14 low-end/web budgets |
| 4 | Economy, invite hardening, launch catalogue and entitlement provenance | 8 | Full simulation; concurrency and exact-once tests; disabled-by-default proof |
| 5 | Casebook, Season Zero, titles and core Partner | 10 | Inactive-season behavior; level/reward math; Partner import closure |
| 6 | Daily Case core, launch case, reminder and `/case/today` | 9 | Generator uniqueness; attempts/reveal; web route; reminder opt-in; **no streak-save at L** |
| 7 | Ready-up, reconnect, host continuity and hand-off reliability | 6 | Two-client races; process death; private/public ready behavior; existing rematch retained |
| 8 | Thursday, pass-and-play result inventory and launch events | 6 | Cairo boundaries; eligibility; public-result-only placement |
| 9 | Required launch art and non-voice sound | 5 | Alpha/crop/size/contact sheets; reduced motion; no private-role cue |
| 10 | G21 big-table optimization + W2/W5/W8 | 13 | 10/15-player timed tests; family-mode parity; 2 m legibility; tutorial completion |
| 11 | G1 free spoken narrator | 24 | Licensing/provenance record; 12-listener gate; noisy-room and tenth-match tests; private-phase silence |
| 12 | G6/G20/G19/G16 signature presentation | 7 | Result-only reveal; live import closure; asset-memory gate; sonic parity |
| 13 | Honest listing, captures and trailer | 5 | Every depicted feature enabled in RC; no private or fabricated state |
| 14 | Full RC and device matrix | 9 | SQL/edge/analyze/full Flutter; two Android classes; Safari; offline; five-match soak |
|  | **Total** | **129 h** | |

Removed from L: rematch voting, creator/viewer codes, founder milestone automation, extra clue and streak-save. The basic founder seal stays. Existing rematch stays.

### Ordered roadmap

**1.1.1 — Characters and competitive choice**

- Four authored Chapters and chapter seals.
- G17 Thursday Partner letter.
- W7 witness-knowledge setting.
- G4 last words if its atomic voice/witness transition gate passes.

**1.1.2 — Learning and cast integration**

- Investigation Desk.
- G18 Gang as authored Academy/example characters.
- Daily Case streak-save only if missed-day cohort data justifies it.
- Additional narrator personality only after G1 fatigue data.

**1.1.3 — Better tables**

- Scenario Deck, House Rules, Series and Draft.
- G15 family-pace preset.
- W6 same-room v0: voice off, QR/web join, elected public-beat audio device, no night narration.
- W4 table-face portraits after suspect-art consistency testing.

**1.1.4 — The argument after the game**

- Verdict sharing.
- G7 factual chronicle plus clearly separated «من حكايات الراوي».
- W1 settled vote timeline.
- W3 post-result reactions.
- G8 session-scoped local evening score.
- Season One content build.

**Later 1.1.x**

- G10 additional scheduled nights only after density gates.
- Creator/viewer systems if evidence supports them.
- Founder milestone automation.
- Additional narrator packs.
- Voice resilience improvements that do not require architectural work.

**1.2 — «قعدة من غير تمرير»**

- Dedicated public-display Table Link v1.
- Authored «بروفة مع الشلة».
- Partner content set 2.
- Proverb Bluff and safe party modifiers.
- Voice reliability work.
- No full bots until simulation benchmarks pass.

**1.3 — Bigger public table**

- Public-snapshot big-screen mode.
- Delayed creator spectator pilot without chat.
- Creator room tooling and capacity controls.
- Broader platform expansion already defined in FINAL.

Full bots and experimental roles remain later than 1.3.

## 5. Owner decisions

1. **Streak-save at L or 1.1.x**  
   Recommendation: **1.1.x after cohort evidence**. It is not the only D7 protection and is larger than it appears.

2. **W7 witness setting**  
   Recommendation: **ship it in 1.1.1**, default ON, immutable after deal, clearly displayed in the lobby. OFF must be enforced server-side.

3. **W2 Family mode default**  
   Recommendation: standard presentation remains default; Family mode is a one-tap room/session preset remembered locally for that host.

4. **W6 v0 positioning**  
   Recommendation: call it “same-room phones” rather than the full «قعدة من غير تمرير». Promise QR entry and no hand-offs; do not promise complete spoken night narration.

5. **G1 voice acceptance**  
   Recommendation: approve only if it passes separate naturalness, cringe, intelligibility and fatigue gates. A failed voice stays out even if technically complete.

6. **Launch ceiling**  
   Recommendation: freeze **129 hours** with a 14-day feature freeze. Any overrun cuts the lowest unfinished feature; it does not move RC.

## 6. Sign-off

**GAME PLAN CLOSED.**

The owner decisions above have explicit recommended defaults and require no further design round. The implementation plan is complete once the owner accepts or overrides those defaults.