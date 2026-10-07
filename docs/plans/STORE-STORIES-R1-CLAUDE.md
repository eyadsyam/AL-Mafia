# Store v4 + New roles + Stories mode — Round 1 (Claude proposes)

Owner brief (2026-10-03, paraphrased faithfully):
- Beta testers ignored the store. Nobody wanted cosmetics. Only the narrator voice and the frames landed. Drop "decorative stuff"; coins must buy things that **help the player inside the match** and set them apart from the table.
- Tools are **consumable** (pieces / charges), not permanent. Bigger quantity → pays more.
- Narrator: the owner will record his own voice; we build filters/effects/cleanup for it. Keep frames.
- New roles, sold for a lot of coins, card art identical in style to existing cards (Codex paints):
  - **مافيا التسكيت** (Silencer Mafia). With 2+ mafia: one is «مافيا القتل» (kills as today), the other is the Silencer: each night silences any one player (himself included) for the next day only. A silenced player can still be voted out.
  - **شيخ الصالحين** (The Elder): a citizen; the moment he reveals his card to the table his day vote counts ×3.
  - **القناص** (Sniper): a citizen with one bullet, used at night on a suspect; if the target is not mafia, both leave the game.
  - More roles will come; doctor and detective stay single (no sub-roles for now).
- Stories mode («قصص»): a game inside the game. Solo detective cases, and offline play with 2–10 friends where each player holds a role inside the story and can suspect the others. Every story scales from 1 to 10 players (clues and scenario change with the count). 20+ stories, all hard, long/medium, categories, 5 "near impossible", no two alike, no AI slop. Uses the characters Codex already painted (raw_assets/update11 S0/S2/S9). Mode picker: «مافيا» (online/offline inside) vs «قصص» (offline for now).

Binding constraints: CLAUDE.md non-negotiables; Doc 05 (docs/specs/05-zero-leakage-spec.md §2 ten rules); engine purity; no real-money content in docs (coins only).

---

## A. Store v4 — "أدوات القعدة" (table tools)

### A1. Principle
A tool must (1) change what a player can *do* in a match, (2) never reveal or let anyone infer a hidden role (Doc 05), (3) be visible to the whole table when used (public power, not secret power — that is what makes the buyer *stand out*), (4) be capped at **one tool use per player per day phase** and **one of each kind per match**, so no wallet wins a match, (5) be server-authoritative in online (edge function spends the charge; client never decides).

Tools are **online-only** at launch (offline pass-and-play has no accounts at the table; Phase 2 could allow the host's own tools offline).

### A2. Tool list (proposal)
| Tool | Arabic | Effect | Why it's not pay-to-win |
|---|---|---|---|
| Extra minute | «دقيقة زيادة» | +30s to your own speaking turn, announced | Talking longer ≠ being right |
| Objection | «اعتراض» | After you are accused, a guaranteed 20s rebuttal before votes lock | Defence, not info |
| Re-vote | «إعادة تصويت» | Once per match, force the day vote to be re-cast once (after the result is shown, before execution) | Big — costliest tool; table sees who used it (that itself is a social signal) |
| Vote shield | «درع الصوت» | Your vote can't be silenced/changed by any effect that day (counters Silencer) | Pure counter |
| Spotlight | «كشاف» | Pin one player: they must answer your question first in their turn | Social pressure only |
| Anonymous note | «ورقة من غير اسم» | One short public message posted without your name during the day | Mafia & town both benefit; no role info |
| Second chance at the wheel… | — | (exclude: economy, not match) | — |

Explicitly **rejected**: anything that reveals a role, a night result, a vote of someone else, or protects from night kill (would let a wallet beat the mafia).

### A3. Charges and pricing (coins only)
Packs of 1 / 3 / 7 / 15 charges. Price per charge *rises* with quantity for premium tools? Owner literally said "the more uses, the more he pays" — I read it as: bigger packs cost more in total (obviously) AND we do not give bulk discounts on strong tools, to keep them scarce. Proposal: light tools (extra minute, spotlight, note) get a mild bulk discount; heavy tools (re-vote, objection) get none. Also a daily cap of purchases per tool to slow hoarding.

### A4. Narrator studio (owner's voice)
- Owner records lines (list generated from the narrator script keys).
- tool/voice/process.py (ffmpeg + RNNoise/afftdn): high-pass 80Hz, denoise, de-ess, EQ presence, compression, loudness-normalise to −16 LUFS, then 3–4 selectable "characters": «راوي القعدة» (dry, warm), «صوت الليل» (low-pitched −2 st + dark room reverb), «الراديو القديم» (band-pass + crackle), «القاعة» (hall reverb). Each preset becomes a sellable narrator pack (permanent — voice and frames remain permanent items, the only non-consumables).
- AI narrator packs leave the store once owner recordings exist.

### A5. Frames stay; other cosmetics go
Nameplates, presentation packs, bundles: hidden from sale (owned items keep working).

### A6. Roles as store items
Owner: roles are paid with many coins. Doc 05 problem: if *a player* owns the Sniper and the Sniper is "his", the table knows who it is. So a purchased role is a **room unlock**: the owner of the role may add it to rooms he hosts (online) or tables he runs (offline). Assignment stays random and secret. Everyone in that room gets to experience it → free advertising for the role. Price tiers (coins): Elder 3000, Sniper 4000, Silencer 5000 (rough, to debate against faucet ~19.5k/28 days for a very active player).

## B. New roles — rules + Doc 05 checks

### B1. Silencer Mafia «مافيا التسكيت»
- Exists only when mafia count ≥ 2 (host toggle). Exactly one silencer; the rest are killers.
- Night: two-step screen like everyone (Rule 1/5/6). Picks one living player (self allowed). Mafia team's kill vote is cast by killers only? Proposal: silencer also takes part in the kill vote (keeps "mafia team" coherent) AND picks a silence target in the same night flow — but that adds a step only for him (Rule 5 violation). Fix: silence pick lives in the **reserved slot** of the same selection screen (Rule 6), and every role's screen has an equal second picker slot (empty for others, or a decoy "who do you suspect most?" picker for everyone — already precedent? check information engine prediction).
- Day: silenced player shown with a muted badge; cannot speak (online: mic hard-muted server side; offline: narrator announces). Can vote and can be voted. Announcement doesn't say who silenced.
- Leak check: self-silence lets mafia fake innocence — intended.

### B2. Elder «شيخ الصالحين»
- Citizen. During any day, he may "reveal": the app shows his card to the whole table (verified by app; mafia cannot fake a claim through the app — but can claim verbally; that's fine). From then his vote ×3, permanently.
- Consequence: mafia will kill him that night → doctor's choice becomes obvious. Good drama, it's the design.
- Doc 05: reveal is a deliberate public action, not a leak.

### B3. Sniper «القناص»
- Citizen, one bullet (re-use lib/engine/bullets.dart event-log derivation — there's already a «الطلقة الواحدة» concept for doc 13, check overlap).
- Night: in his normal two-step screen he may choose "shoot" target or hold. If target is mafia → target dies. If not → both die. Doctor protection: does the doctor save the shot target? Proposal: no (a bullet isn't the mafia's knife) — debate.
- Morning announcement must not reveal that a Sniper fired unless deaths make it obvious: two deaths in one morning already tells the table something happened. Accept: "two bodies" is public information, like pass count rule 9.

## C. Stories mode «قصص»

### C1. Shape
Home → mode choice: «مافيا» (online / offline inside) and «قصص». Stories = offline, 1–10 players, one phone (pass-and-play) for now.

### C2. The scalable story model (the core design problem)
Each story is authored as a **truth + clue graph**:
- Truth: victim, culprit(s), motive, method, timeline, and red herrings.
- Clues: atomic facts, each tagged with what it proves/excludes, and a minimum player count bucket.
- Characters: 10 suspects/witnesses (portraits from update11 S2 suspects + S9 gang + new).

Player count changes the game:
- **1 player (solo detective)**: you have N "actions" (interrogate a character, search a location, examine evidence, request a lab result). Each action reveals clue cards. Limited actions (e.g. 12) → you must choose; final accusation + motive + method; score by correctness and actions left.
- **2–10 players (social)**: each player is dealt a *story character* privately (secret card on pass): their personal background, 2–3 private clues only they know, and a personal goal. One or two players secretly **are involved** (culprit / accomplice / a liar protecting someone innocent). Rounds: share/lie, investigate (group spends shared actions), discuss, final group accusation. Culprit wins if not identified; liars with side goals score separately.
- Clue distribution scales: total clue pool fixed per story; with more players, more clues sit in private hands (must be extracted socially), fewer in the public action deck. Counts 1, 2, 3–4, 5–7, 8–10 are buckets authored explicitly, not generated at runtime.

### C3. Content plan
24 stories in 6 categories × 4: «قتل في الحارة» (classic murder), «سرقة» (heist / theft), «اختفاء» (missing person), «نصب» (fraud/con), «قضايا قديمة» (cold case, 1950s Cairo), «مستحيلة» (locked-room / impossible). Difficulty: all hard; the 5 "near impossible" sit across categories. Length: medium (25–40 min) and long (60+). Each story authored as structured data (JSON/YAML in assets/stories/), with a **solvability checker** tool (pure Dart): proves the culprit is uniquely deducible from the clue set available in every player bucket, and that no single clue gives it away. That checker is our anti-slop guard plus human editorial (owner reads, Claude & Codex co-write).

### C4. Rewards
Stories give Season XP and a small coin reward on first solve (feeds the store). Some stories premium (coin unlock) — debate.

## D. Assets
- Codex: 3 role cards (same frame/style as assets/images/card_face_*.webp), role night icons, 24 story covers, location plates, evidence objects, missing suspects.
- Claude: animations (Flutter-native: card reveal, silence badge, bullet tracer, elder ×3 seal), sound design (silence "hush", gunshot muffled, gavel ×3, page-turn, clue chime) — synthesized/processed with ffmpeg + licensed CC0 sources; owner voice pipeline.

## E. Open questions I want you (Codex) to attack
1. Is "consumable public tools" actually desirable for an Egyptian social group, or will it feel pay-to-win and kill online rooms?
2. Rule 5/6 handling for Silencer and Sniper night steps.
3. Role-as-room-unlock vs owner's literal "buy the character".
4. Story scaling model: can the same truth really be fun at 1 and at 10? Is a pass-and-play phone workable for 10 people with private clues?
5. Can we author 24 non-slop stories with a solvability checker in reasonable time?
6. What's missing.
