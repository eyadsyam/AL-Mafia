# Game big round 1 — Claude proposes G1–G22, Sol criticises

## 1. Verdict

- The three biggest improvements to how the game feels are **G1 spoken narration**, **G21 fast large-table play**, and **G4 last words**. They strengthen the actual social ritual rather than adding another meta-system.
- **G6/G20** is the strongest visual upgrade: the character-behind-you reveal should become the product’s signature image.
- **G10 scheduled tables** has the greatest plausible effect on month-one active devices because it concentrates a small audience instead of pretending matchmaking is liquid all day.
- **G9 full bot Mafia is not a 1.1.x-sized feature**. A weak version would make the game feel fake and damage trust.
- **G3 cannot ship during a live match as proposed**. Calling invented murder details “fiction” does not neutralize Doc 05 or the rule that the app never invents facts.
- Adding every attractive KEEP to launch would nearly double the 94-hour path. Launch should absorb only the highest-impact table improvements and move promotional/meta machinery out.

## 2. G1–G22 verdicts

| Idea | Verdict | Risk and required change | Correct size | Release |
|---|---|---|---:|---|
| **G1 Spoken narrator** | **MODIFY** | Launch for **pass-and-play public table beats only**. Never play while someone holds the phone. Online playback on every device would produce echo, drift and voice-chat collisions. Keep text authoritative and provide voice/SFX volume controls. | L, 4–6 days including recording QA | **L** |
| **G2 Narrator personalities** | **MODIFY** | The product is authored performances, not merely different synthetic voices. Comedy must come from strong writing and direction; a caricatured “street” voice will feel cheap. Preserve identical public information and beat duration across packs. | L per complete pack, 3–5 days | First additional pack **1.1.x** |
| **G3 Death story** | **REJECT live version; merge a safer version into G7** | A sentence describing where or how a public victim died is an invented fact inside an information game. It can accidentally overlap with trace vocabulary or be treated as a clue. Permit atmospheric fiction only **after the public result**, clearly separated from the evidentiary chronology. | M, 2–3 days with copy QA | **1.1.x**, post-result only |
| **G4 Last words** | **KEEP, modified** | Online: 15 seconds immediately after vote elimination but **before** the player is transitioned into the dead/witness entitlement. The floor closes atomically before witness data is granted. Pass-and-play uses a public timer. Night victims receive none. | M, 2 days | **1.1.x** |
| **G5 Trial** | **KILL** | It duplicates the existing confrontation, opening accusation, discussion and voting systems. A confirm vote prolongs games and creates a second opportunity to pressure one player. Improve confrontation clarity instead. | — | — |
| **G6 Character reveal** | **KEEP** | Strictly after the public result. Use the existing art with feathered compositing; no role-specific loading, sound or animation before result publication. | S, 0.5–1 day | **L** |
| **G7 Match chronicle** | **KEEP, modified** | Deterministic authored templates from public deaths, public votes, days and final revealed roles. Do not export investigations, protection targets, whispers or other private actions—even after the match. Text first; image later. | M, 2–3 days | Text **1.1.x**; image with sharing |
| **G8 Local evening score** | **MODIFY** | Make it session-scoped: matches, town/mafia tally, public awards and an optional reset. Do not build a persistent person→role history or crown someone merely for favorable role distribution. | M, 2 days | **1.1.x** |
| **G9 Gang bot match** | **MODIFY radically** | Full general-purpose Mafia bots are XL. Start with an authored “Gang rehearsal”: fixed scenes, constrained legal actions and explicit tutorial framing. It must not count as an ordinary match, grant economy progress or inflate dossier victories. | XL for true bots; L for authored rehearsal | Rehearsal **1.2**; full bots later |
| **G10 Scheduled nightly table** | **MODIFY** | Begin with selected nights, not seven empty promises. Use a 20:45–21:15 Cairo queue, honest fresh-presence counts and orphan-free sharding. Activate only when concurrency supports it. | L, 4–7 days | **1.1.x** after density proof |
| **G11 Lone-installer sequence** | **MODIFY** | Five mandatory steps are onboarding exhaustion. Use: optional Partner pick → 60–90-second authored first-night scene → one clear choice among Daily Case, tonight’s table or invite. Never force the case. | M, 2–3 days once content exists | **1.1.x** |
| **G12 Creator spectators** | **MODIFY / defer** | A safe spectator receives only a delayed public projection—never a room snapshot object that also supports witness/private variants. Two hundred viewers require fan-out, abuse and capacity work. No spectator chat initially. | XL, 2–4 weeks | **1.3 pilot**, as FINAL says |
| **G13 Voice resilience** | **KEEP, split** | Lobby mic/output self-test and a clear text-only fallback belong at launch. Automatic bitrate adaptation requires real-network tests and must never block phase progress. | M for self-test; L for adaptation | Self-test **L**; adaptive voice **1.2** |
| **G14 Jester** | **KILL for 1.2** | Jester rewards disruptive play, produces kingmaking and changes the meaning of every vote. It needs full engine, information, outcome, tutorial and balance treatment. It is not automatically fun merely because other games use it. | XL | **1.4+ experiment** |
| **G15 Quiet-night modifier** | **MODIFY** | Do not allow an unlimited host-controlled phase. Use a “family pace” preset with generous hard caps and an everyone-ready early advance. Same timers and controls for every role. | M, 1–2 days | **1.1.3** |
| **G16 Partner at the table** | **KEEP, constrained** | Lobby, result and chronicle only. Partner assets must be unloaded/absent from the live-match import closure, not merely hidden. Their lobby presence communicates taste, never current role. | S, 1 day | **L** |
| **G17 Thursday letter** | **MODIFY** | Use only completed public-week aggregates. Build a sufficiently broad authored bank, cap at one pull/week and never shame inactivity. A repetitive weekly template will weaken attachment. | M, 2 days | **1.1.x** |
| **G18 Gang inside app** | **KEEP without G9 dependency** | Put them in Academy fixtures, examples and onboarding first. They can later become bot personalities after the simulation is worthy of them. | S–M | **1.1.x** with Academy |
| **G19 Sonic identity** | **KEEP** | One short master motif, but no sound while a player privately holds the device. On web, play only after user interaction. Do not attach variants to roles. | S, 0.5–1 day | **L** |
| **G20 Character-behind-you motif** | **KEEP** | Make it the non-live visual signature. Never reuse it in role reveal, hand-off, night seats or any phase where an observer could correlate art/loading with role. | M, 1–2 days | **L** |
| **G21 Big-table performance** | **KEEP, strengthen** | “Ready” cannot replace the privacy barrier. Retain hold-to-reveal, automatic conceal and a confirmed hidden state. Targets: median hand-off ≤6 seconds, full 15-player assignment ≤100 seconds, 15-player night ≤4 minutes. | M, 2–3 days plus device testing | **L** |
| **G22 First-match quality bar** | **MODIFY** | Instrument it, but do not block launch on an arbitrary 60%. Separate “pressed play again,” “started another match,” pass-and-play and online. Initial health thresholds should be evidence-based. | S, 0.5 day | **L metrics** |

## 3. Deep attacks

### G3 — Fiction versus “the app never invents a fact”

The proposed implementation violates more than a narrow leakage rule. Mafia Master teaches players that text shown during the morning may contain information. The information engine is deliberately conservative: no eligible trace means no trace, and the app never fabricates evidence. A decorative label reading «حكاية» will not reliably override that learned contract, especially for younger players, first-time players and people hearing the sentence aloud rather than inspecting its typography.

The specific danger is semantic collision. “The cup was still warm,” “the window was open,” “mud was beside the chair,” or “a knife remained in his hand” all sound like evidence. Even if the selection is statistically independent of roles and actions, players will infer intent from it. Two hundred authored lines also make accidental overlap with present or future trace categories nearly inevitable. Once one coincidence occurs, the table starts reverse-engineering the fiction bank. That damages the information engine even when it reveals nothing.

“No vignette when nobody died” is not itself a secret leak after the public outcome is announced, but it strengthens the perception that vignettes explain mechanical outcomes. The wrong lesson becomes: narration is evidence.

The safe version belongs after result publication, inside G7, under an unmistakable heading such as «من حكايات الراوي» and physically below the factual chronology. It may poetically summarize the evening, but it must not introduce locations, weapons, witnesses, times, physical traces or causal claims. During the match, the morning narrator should announce only the public outcome. This is a case where restraint makes the real evidence more exciting.

### G9 — Bot fun, cost and cannibalisation

The proposal underestimates what makes Mafia enjoyable. Night actions and voting are the mechanical skeleton; persuasion, inconsistent stories, social memory, alliances and human overconfidence are the game. A bot that chooses legal actions and emits one canned line per day can produce a valid state transition while still producing a lifeless match. Worse, personality catchphrases will become predictable. If Hamada always panics and Nada always sounds certain, players solve personalities rather than deductions.

A competent bot needs at least four distinct layers:

1. An access-filtered knowledge model containing only facts its role legally knows.
2. A belief model updated from public votes, claims, deaths and contradictions.
3. A strategic policy that can lie when Mafia, protect claims, coordinate without omniscience and vary by difficulty.
4. A dialogue planner whose statements remain consistent across days.

Every layer needs deterministic seeds, replay tests and proof that hidden engine state never leaks into innocent bots. Giving bots a whole engine snapshot and asking the policy to “ignore” forbidden fields is unacceptable. Their API must make illicit knowledge unavailable.

Cannibalisation is not the main risk. A good solo mode would teach and retain players; it would not replace a funny human table. The real risks are expectation and contamination: calling a shallow scripted experience “play Mafia” may teach bad strategy and make the core game look simplistic.

Therefore, build an authored **Gang rehearsal**, not general bots: perhaps five fixed characters, two or three scenes, a controlled player role and bounded choices with clear fictional dialogue. Treat it as learning content, grant no ordinary match rewards and do not write its outcomes into real match history or dossier victories. Only pursue full bots after offline simulation benchmarks show strategic diversity, consistency and replay value. That is a 1.2 research project at minimum, probably closer to XL than L.

### G1/G2 — Voice rights, size and comic delivery

Bundled pre-rendered voice is the correct architecture: it works offline, has no runtime latency and keeps narration non-load-bearing. Microsoft’s current guidance supports constrained gaming narration with prebuilt neural voices, while making the developer responsible for input rights, applicable disclosure and compliance. That means the project should archive the exact voice ID, generation date, applicable terms, authored scripts and disclosure decision for every production batch rather than relying on an informal assumption. [Microsoft’s TTS transparency guidance](https://learn.microsoft.com/en-us/azure/foundry/responsible-ai/speech-service/text-to-speech/transparency-note)

The proposed 2–4 MB estimate may be low once variation is real. Six or more beats, three takes, multiple victory outcomes and natural pauses can easily produce 30–60 clips per pack. Properly compressed mono speech is still manageable, but the real cost is not storage. It is Arabic pronunciation QA, loudness normalization, silence trimming, ducking against SFX, interrupted playback, resume behavior and ensuring the phone never speaks during private hand-off.

Online should not automatically play narration from every participant’s device. Slight synchronization differences create an unpleasant chorus, microphones can retransmit the line, and people may hear it twice through speakers. Launch G1 for pass-and-play. Online can use text and stings until a tested host-broadcast or synchronized/ducked design exists.

For G2, humour must live in authored lines, timing and callbacks. Merely selecting a “comic” neural voice will sound like advertising or caricature. «ابن البلد» also needs cultural restraint: contemporary and observant, not a pile of slang. «المذيع» should evoke match commentary without imitating a recognizable living commentator. Produce the calm free voice first, then one pack only after blind listening tests answer: Is it funny on the tenth match? Are lines intelligible over a noisy table? Does it sound respectful to Egyptian listeners from different regions and ages?

### G10 — Will a scheduled table actually fill?

Scheduling is the right response to low concurrency, but a clock does not create liquidity. It concentrates whatever liquidity already exists. If 12 eligible people arrive, the system can create a strong 12-person table. If three arrive, a giant “tonight’s table” promise produces a more memorable failure than an ordinary empty browser.

The product therefore needs a queue contract, not merely a countdown. Use a 20:45–21:15 Cairo window. Count only distinct, authenticated, recently heartbeating devices that explicitly joined the queue. Never display cumulative opens as “waiting.” At five people, a match can form. From 5–15, form one room. Above 15, choose partitions that avoid orphan groups: 16 becomes 8+8, 19 becomes 10+9, 21 becomes 11+10, 29 becomes 15+14. Do not create a full table and leave four people stranded if a balanced split is possible.

At three people when the window closes, do not dump them into an empty lobby. Offer three honest continuations: keep a private lobby and invite friends, play the Daily Case, or receive the next scheduled-table reminder. Preserve no fake queue position.

Daily scheduling is premature. Launch already has Thursday concentration. Add perhaps Saturday or Tuesday only after measured concurrent demand. A reasonable activation requirement is repeated evidence of at least 12–15 queue arrivals during the same window, with a path to ≥80% of joiners entering a match. Daily expansion can follow when the system can usually form two healthy rooms without long waits.

This could materially improve D7 because successful online sessions make the game feel alive. But activating it too early would advertise emptiness. It needs flags by day, honest counts, wait-time metrics, orphan-rate metrics and an automatic operator fallback to Thursday-only.

## 4. Scope reality

The additions labeled L above are approximately:

| Launch addition | Incremental effort |
|---|---:|
| G1 free pass-and-play narrator, including production QA | 24–36 h |
| G6/G20 reveal and visual motif | 12–16 h |
| G13 lobby voice self-test | 8–12 h |
| G16 lobby/result Partner treatment | 4–6 h |
| G19 sonic signature | 4–6 h |
| G21 large-table optimization and device tests | 16–24 h |
| G22 segmented quality instrumentation | 3–5 h |
| **Total** | **71–105 h** |

Putting all of that on top of FINAL creates a **165–199 hour launch path**, before rollout. That is not credible. Some visual work can overlap existing art integration, but the launch still becomes roughly 150 hours unless scope moves.

### L priority by `(feel × devices) ÷ cost`

1. Online blockers, reconnect and Doc 05 gates — non-negotiable.
2. Safety and error recovery — no social game survives without them.
3. **G21 large-table speed/privacy** — affects the primary mode directly.
4. Daily Case and `/case/today` — the proven lone-player loop.
5. Invite/web join — converts groups with the least friction.
6. **G1 one free spoken narrator** — largest perceptual improvement to القعدة.
7. Asset warm-up and low-end performance.
8. **G6/G20 character-behind-you result treatment**.
9. Ready-up and host continuity.
10. **G13 voice self-test**.
11. Casebook/Season/Partner core.
12. **G19 sonic identity**.
13. Thursday event.
14. Launch catalogue and revenue-critical surfaces.
15. **G16 Partner lobby presence**.
16. Founder milestone campaign machinery.
17. Daily Case streak repair and extra-clue extensions.
18. Creator/viewer-code system.
19. Rematch voting—the simpler existing rematch already works.
20. G4 last words.
21. G7 chronicle.
22. G8 evening scoreboard.

### What should leave L

To make room without shipping unfinished work:

- Move **creator entitlement/viewer codes** to 1.1.x.
- Keep the basic founder seal if required for pre-registration, but move **milestone campaign automation** to 1.1.x.
- Move **streak-save and extra-clue extensions**; retain the complete core Daily Case.
- Move the **new rematch vote**; retain the existing rematch.
- Keep G4, G7 and G8 in 1.1.x.
- Do not begin G9, G10 expansion, G12, G14 or G17 before the launch gates pass.

Even after those swaps, the honest launch path is likely **115–130 hours**, not 94. If 94 hours is an absolute ceiling, G1 and G21 should enter L, while G13 self-test, G6/G20 and G19 should be absorbed only where they overlap existing work. Anything else moves.

## 5. One missing game-level idea

### «قعدة من غير تمرير» — Same-Room Table Link

The unresolved weakness of pass-and-play is the physical hand-off itself, especially with 10–15 players. Offer an optional hybrid mode:

- One host device shows only public narration, timers and outcomes.
- Everyone else scans one QR or opens a short link on their own phone.
- Each player receives their private role and actions on their own device.
- Voice is disabled because everyone is physically together.
- The existing online transport and engine remain authoritative; this is not a third engine.
- The host screen never receives private roles or night actions.

This preserves the real room, eye contact and discussion while eliminating 15 serial hand-offs. It also lets iPhone/web guests participate without installing. Doc 05 requires strict public-display credentials, role-safe reconnect, synchronized phase boundaries and tests proving that the host projection can never subscribe to private payloads.

This is **L-sized and belongs in 1.2**, not launch, but it addresses a concrete limitation none of G1–G22 fully solves. If executed well, it is a stronger competitive distinction than adding another role.

## 6. Questions for Round 2

1. Do we freeze G1 as **pass-and-play only at launch**, with online spoken narration deferred until echo and synchronization are proven?
2. Do we formally prohibit invented mid-match death scenes and merge atmospheric fiction into the post-result chronicle?
3. Is the revised launch ceiling 115–130 hours acceptable, or must the scope return to 94 hours?
4. Which moves first: founder milestone automation, creator codes, puzzle assists and rematch voting?
5. Should last words occur before or after public role revelation? I recommend before revelation and before witness entitlement.
6. Does G10 launch Thursday-only, then expand only after measured queue density?
7. For solo play, do we agree that 1.2 begins with an authored Gang rehearsal rather than pretending shallow bots are a full Mafia match?
8. Should the Round 2 pre-mortem include explicit kill gates for narration quality, scheduled-table fill rate, first-match continuation and 15-player hand-off time?
9. Does «قعدة من غير تمرير» enter the 1.2 roadmap as the table headline, ahead of any new role?
10. Who approves final Egyptian voice tone and pronunciation, and what blind-listening sample size is required before a narrator pack ships?