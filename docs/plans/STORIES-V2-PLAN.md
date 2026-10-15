# Stories V2 — «قصص وتحقيقات» for a real table

Status: **DESIGN V3, 2026-10-15.** Nothing is implemented except P1 (owner all-access), in progress locally. After the owner reads this version: HTML mockups (P3), then the pilot.
Branch: `claude/epic-roentgen-094f21`. Applies to **all 24 stories** (owner: «دا لكلوا حرفيا مش قصة وحده»).

Read with: `CLAUDE.md` (non-negotiables), `docs/specs/05-zero-leakage-spec.md` (private pages),
`lib/stories/*`, `lib/ui/screens/stories/*`, `.claude/skills/stories-case-writing/SKILL.md` (how the words are written),
and the draft identity in `../mafia-game-design-system-fca2a6/design-system/stories/IDENTITY.md` (not signed off).

---

## 0. What the owner asked

**First message (after a real table of friends):**
1. A story details screen before play; every character introduced.
2. Typed names; the app deals characters; each player learns his role.
3. Solo = you are the investigator. Group = some suspects, some not; each knows his role; the killer knows he is the killer.
4. A how-to-play screen.
5. The file must say what is read aloud and what is private; every name introduced.
6. Narrator in every mode with full control. **A feature exists in every mode or in none.**
7. Stories is a separate game; its brown and Ruqaa leaked into Mafia; Home's colours are the app's identity.
8. His own account gets everything unlocked.
9. Many first-time players are coming.

**Second message (answers to round 1):**
- a. Solo stays; make it simpler and quick to understand.
- b. **2–4 players:** everyone plays a character; one of them is the culprit, but **nobody knows their role, not even the culprit**; no detective; everyone suspects everyone.
- c. **5–10 players:** one player is the detective. Detective, innocents, killer and accomplice are **all characters of the story**; nobody from outside. Some stories have an accomplice.
- d. Private = only innocent or not (and the partner). Everything else each player **reads aloud**: who he is, what he does, what he saw.
- e. The detective holds the phone after the deal, reads the case facts and evidence aloud, leads the table, decides what to search, and **decides at the end. No vote.** Someone should be able to make him doubt.
- f. **No discussion timer, no prompts.** People talk freely.
- g. Rewrite all story details (the narrator's opening may stay). The opening makes everyone suspect each other. **No minutes or seconds**; natural relative time («من فترة»، «امبارح»، «قبلها بساعة»، «قبلها بشوية»).
- h. **The case changes with the player count, 1 to 10, and replays differ**: three today and four tomorrow get a different culprit, different innocents, everything. Keep the 24 stories and generate per-count versions from them.
- i. Narrator: **±5 s**, tap anywhere on the bar to seek, pause, restart, stops at the end.
- j. A general explanation of the Stories section the moment it is opened.
- k. Download all the skills; find good script-writing skills (stars, quality, no AI slop).

## 1. Confirmed defects (evidence)

| # | Defect | Evidence |
|---|---|---|
| D1 | The culprit's player is never told; the dossier is the same for everyone and names no role | `lib/stories/story_session.dart` (no role field), `StoryDossier` in `lib/ui/screens/stories/story_case_widgets.dart:1360` |
| D2 | Seats take the **first N characters**; culprit ids vary (n01…n09), so at 4 players the culprit is sometimes seated (unaware) and sometimes absent | `_seatingFor` in `story_session.dart`; culprits per story: 1:n02+n01, 2:n06, 3:n05, 10:n09, 13:n08 … |
| D3 | The checker proves solvability only if **every** private clue is shared truthfully | `lib/stories/story_checker.dart:95` |
| D4 | The culprit can hold clues that name him (n02 holds `motive_voice_note`) | `assets/stories/qahwet_el_moallem.json` |
| D5 | No story details screen and no cast introduction before the deal | `_cast` in `lib/ui/screens/stories/story_flow_screen.dart:560` |
| D6 | No player names in Stories | `StorySession` has `playerCount` only |
| D7 | No how-to for Stories | no stories entry in `how_to_sheet.dart` |
| D8 | Narration has no real player: fire-and-forget `playAccent`, fake local «playing» state, no seek/pause/position | `router.dart:490`, `StoryNarratorBar` `story_case_widgets.dart:719` |
| D9 | The group cast screen has no narrator control | `_cast` vs `_solo` in `story_flow_screen.dart` |
| D10 | The reenactment replays the **opening** audio | `story_flow_screen.dart:983–1014` |
| D11 | Riddle-like clue text with clock times and unintroduced names | clue `culprit_coal` |
| D12 | One fixed truth per story, so a replay is spoiled; `story_solutions` holds one triple per story | `supabase/migrations/20261009002000_story_solution_verification.sql:3–57` |
| D13 | Stories tokens in Mafia files: `postgame/result_screen.dart`, `postgame/match_file.dart`, `missions/casebook_sheet.dart`, `setup/profile_screen.dart`, `setup/store_shop.dart`, `setup/coin_store.dart`, `setup/mode_screen.dart`, `setup/how_to_sheet.dart`, `onboarding/first_run_screen.dart`, `widgets/deck/deck_public.dart` | grep `CaseFileTokens\|StoryTokens\|CaseFilePaper` outside `screens/stories` |
| D14 | Stories borrows Mafia deck tokens (`DeckTokens.bone/text2/silver`, `BoneButton`, `HoldPad`) | `story_flow_screen.dart` |
| D15 | Home paints `AppColors.groundBase` #0F0F0F, but `DeckTokens.ground` is aliased to the brown `IdentityTokens.ink` #140F0C, so every public deck screen sits on brown | `design_tokens.dart:117`, `core/theme/app_colors.dart:90` |
| D16 | Some openings name the method (قهوة المعلم: «حجر الشيشة وصل له متجهز»), which a variant with another method would contradict | `synopsis` + `assets/voice/stories/*.ogg` |

## 2. Game design V3

### 2.1 Three modes, one content model

| Players | Mode | Who is who | Who decides |
|---|---|---|---|
| 1 | «لوحدك» | You play the story's **detective character**. 4 suspects on the table. | you |
| 2–4 | «كلنا مشتبه فيهم» | Every player is a suspect character, and only they are suspects (owner: no extra suspect at 2). One of them is the culprit; **nobody knows, not even him**. | the table agrees on one accusation |
| 5–10 | «المحقق بينا» | One player is the story's detective (public, known innocent). The rest are suspects; one is the **killer and knows it**; in accomplice stories one more is the **partner** at any size from 5 (owner: no 7-player floor) and both know each other. | the detective, alone. No vote |

All three use the same loop: **case facts → the suspects' cards read aloud → 3 searches → accusation (who + why + how) → the reveal on screen → result.** What differs is who reads, what is private, and who decides.

### 2.2 Cards are never lies (Codex R2-A)

Every public card is **true but incomplete**. The culprit's card leaves out what he did; searches find what it left out. So:
- in 2–4, the culprit's player reads a truthful card without knowing it hides anything. The reveal («طلعت انت!») is the payoff;
- in 5–10, the killer reads a truthful card, then may lie as much as he likes **out loud**. That is how he makes the detective doubt (owner e).

### 2.3 Variety by player count and by replay (owner h)

- A story is a **world**: victim, 4–5 places, the narrated opening, one in-story detective, 10 suspects.
- Each suspect has a public card (who, relation to the victim, a public goal, a suspicion hook true in every version) and **two authored modules**: innocent (what he really did, one clearing trace) and guilty (motive, method, what his card leaves out, 2+ exposing traces in different places, a reveal scene).
- A play = (story, player count, seed, this phone's history). The engine draws the seated suspects for the count, then the culprit **from the played characters only**, preferring one this phone has not seen as culprit in this story (falls back when the pool is exhausted, Codex R2-Q2).
- Three today and four tomorrow: different seated cast, different culprit, different traces in the places, a different reveal.
- The app writes nothing. It selects and assembles hand-written modules (non-negotiable 4).
- Accomplice versions exist only where authored, in the 5–10 mode at any size; versions with and without a played partner are both authored and checked (Codex R2-Q7).

### 2.4 Time language (owner g)

No clock times, minutes or seconds anywhere. Periods only: «من فترة» · «امبارح» · «امبارح بالليل» · «النهارده الصبح» · «قبلها بساعة» · «قبلها بشوية» · «ساعتها» · «بعدها على طول». The linter rejects digits next to دقيقة/ثانية/ساعة and any `h:mm`.

### 2.5 What is public and what is private

| Information | Where |
|---|---|
| Opening, victim, places, every card (photo, name, tag, relation, goal, what he says he did) | Public; each player reads his own card aloud |
| Who plays whom | Public deal screen |
| Case facts and found traces | The detective's screen (5–10) or the shared screen (1–4); read aloud |
| «انت بريء» / «انت القاتل · شريكك: …» / «انت الشريك · القاتل: …» | Private, 5–10 only, one line behind a hold |
| Nothing | Private in 1–4 (there is no private page) |

### 2.6 The 5–10 table, step by step

1. Story file (public): opening narration, victim, places, the 11 characters.
2. Names → public deal: «أحمد = سامح، ابن أخو المعلم» … «مريم = الرائد عادل، المحقق».
3. **One pass.** Hand-off by name → the player's card fills the screen; he reads it aloud → «دوس مطوّل وشوف سرّك» → one role line → hide → next. The detective's pass has the same shape («انت المحقق — مفيش سر»). Same layout, length band, taps and hold time for every role (Doc 05). Backgrounding covers the page and returns to that player's hand-off.
4. The detective takes the phone: case facts (read aloud; they give every seated suspect a reason to be suspected), the suspects board (he can mark «مشكوك / مستبعد»), and 3 searches. No timer, no prompts.
5. «قراري»: who, why, how.
6. Reveal (read on screen), then the result: every player's name, character and role; detective right → detective and innocents win; wrong → killer (and partner) win; points for who/why/how.

### 2.7 The 2–4 table

Story file → names → public deal → each player reads his card aloud from a public «اتعرّفوا» screen (no pass at all) → the phone sits in the middle: case facts, 3 searches the table chooses together, free talk → «اتفقنا»: one shared accusation → reveal («الجاني طلع: كريم، اللي كان بيلعب سامح») → result. At two players the culprit is one of the two; the traces carry the game.

### 2.8 Solo

You are the detective character. Read the opening and four suspects' cards, pick 3 of 5 places, accuse who/why/how. No move budget and no costs. The optional rewarded ad gives a 4th search (the ad placement stays; owner rule: never reduce ads). The fairness guarantee is computed on 3 searches, so the ad is never the only way to solve (Codex R2-Q4).

### 2.9 Fairness, honestly (Codex R2-Q3)

With 3 searches out of 5 places, not every path can prove everything. The checker reports, for each assembled version, which 3-search paths lead to one justified culprit. A version ships only if most paths solve it (pilot sets the number; start at 6 of 10) and no path leaves more than two candidates. The result screen never calls an unsolvable path a player failure; it shows what the unsearched places held.

### 2.10 Deferred (Codex R2-Q6)

A hidden "killer wipes a trace" move: killed for V1 (a suggestion count would expose the killer, and a silently changed search confuses first-timers). The killer makes the detective doubt by talking. Revisit only if the pilot shows the killer has too little to do.

## 3. Content V3 (all 24 stories)

- Written with `.claude/skills/stories-case-writing` plus `humanizer`, `sepia`, `genre-craft` (fair play), `writing-principles`, `character-management`, `voice-style`, `line-editing`, `reader-sim`, `arabic-natural-writing`.
- Per story: victim, places, a new in-story detective, 10 suspects × (card + innocent module + guilty module), base facts, the opening (kept where it gives nothing away; D16 sentences trimmed and re-recorded in the chosen voice).
- Structured facts beside the prose: `at(who, place, period)`, `has(who, item)`, `saw(a, b, place, period)`.
- **Checker V3** enumerates every allowed (count, seated cast, culprit, partner) assembly and proves: consistency with base facts and between modules; the culprit's card omits something a trace exposes; every innocent has a suspicion hook and a clearing trace; the 3-search path report of §2.9. Human review reads complete assembled versions, because a linter can't tell whether «قبلها بشوية» has a clear referent (Codex R2-Q3).
- **Linter:** unknown names, clock times, Latin letters, over-length cards (a card read aloud < 20 s), missing tags.
- **Pilot first:** «قهوة المعلم» as a full world, played at **1, 2, 3, 5, 7 (with partner) and 10** before any other story is touched (Codex R2-Q10).

## 4. Screens and flow

All in the Stories identity. «جديد» = new.

| # | Screen | Public/private | Notes |
|---|---|---|---|
| S0 | «يعني إيه قصص وتحقيقات؟» (جديد) | public | general explanation on first entry (owner j), the three modes, «كل مرة القصة بتتغير»; reachable later from the hub |
| S1 | Stories hub | public | restyled; each case shows players range and length |
| S2 | «ملف القضية» (جديد) | public | cover, victim, places, narrator player, the 11 characters (tap → card), «العب لوحدك» / «العب مع صحابك» |
| S3 | «كام واحد؟ واكتبوا أساميكم» (جديد) | public | count picker names the mode per count; last table's names prefilled |
| S4 | «إزاي نلعب» (جديد) | public | per mode, 4–5 cards with one worked example; required the first time per mode |
| S5 | «مين هيلعب مين» (جديد) | public | names → characters; the detective marked |
| S6 | Hand-off (5–10) | public | by name |
| S7 | Card + role (5–10) | card public, role private | §2.6 step 3 |
| S8 | «اتعرّفوا» (1–4, جديد) | public | each card in turn, read aloud |
| S9 | Detective desk / shared table (جديد) | public | case facts, board with marks, 3 searches, found traces, «اسمع البداية تاني» |
| S10 | «قراري» / «اتفقنا» (جديد) | public | who, why, how from short lists |
| S11 | Reveal | public | the version's reveal scene, read on screen (no narration: owner) |
| S12 | Result (جديد) | public | names, characters, roles, outcome, points, what the unsearched places held |

Removed: the discussion timer, round prompts, private clue passes, secret ballots (`story_flow_screen.dart:805–831, 942–949`).
«الشخصيات» sheet on every public screen, never on S7's private half.
**Feature parity rule:** narrator, cards sheet, how-to, reveal scene and rewards exist in all three modes.

## 5. Narrator player (every mode)

- One `NarrationController` in `lib/platform/` with its own `AudioPlayer` (audioplayers 6.8, already a dependency), separate from the SFX pool and the ambient loop: `state` (idle/loading/playing/paused/ended/error), `position`, `duration`, `play(asset)`, `pause()`, `resume()`, `seek(d)`, `skip(±5 s)`, `restart()`, `stop()`.
- One `StoryNarratorPlayer` widget: play/pause, a bar you can **tap or drag anywhere** to seek, elapsed/total, ±5 s, restart. State comes from the controller, never a local flag.
- The end sets `ended`: the bar shows «اسمعها تاني»; never loops, never restarts by itself.
- Stops on any private page, leaving the story, backgrounding, and starting another track.
- **The narrator only tells the story** (owner, 2026-10-15): the opening on S2 and «اسمع البداية تاني» on S9, in all modes. No reveal narration, no how-to narration.
- Fake controller for widget tests; an adapter contract test (seek, complete, stop).
- Web: the first play needs a tap (browser rule), so S2 shows the play button instead of autoplaying.
- Voice: **زياد** (`5REPlS2Ja1VZ7zNA0ykn`, eleven_v4), chosen by the owner after two sample takes of the café opening (`build/voice-samples/`, calm and tense). Openings are re-recorded in his voice, pilot first; an opening stays word for word when every version of its story agrees with it.

## 6. Identity isolation

- **App identity = Mafia = Home.** Every screen outside Stories uses the Home deck tokens. Stories' identity begins after «قصص وتحقيقات» is tapped and ends on leaving it.
- First fix D15: `DeckTokens.ground` follows `AppColors.groundBase`, so every public deck screen matches Home.
- Tokens stay in the one token file (`lib/ui/theme/design_tokens.dart`), with a Stories group only Stories code may use. Stories widgets move to `lib/ui/screens/stories/widgets/`; `CaseFilePaper` and `WarmPalette` leave `lib/ui/widgets/`.
- The 10 Mafia files in D13 get Mafia components (deck paper, Cairo/Plex). Ruqaa leaves Mafia.
- Stories stops borrowing Mafia components (D14) and gets its own button, hold pad and paper, keeping the hold pad's zero-leakage properties.
- **Guard test** `test/architecture/identity_isolation_test.dart` fails on a cross-identity reference; identity-neutral pieces (spacing, radii, motion, Semantics helpers) are allow-listed.
- Before restyling: a screenshot audit of every Mafia screen beside Home; each changed screen gets an HTML mockup first.

## 7. Owner account: everything open (P1, in progress)

- `all_access_grants` table (RLS on, no client writes), `has_all_access(user)` OR'ed into every purchase and ownership path, `my_entitlements()` for the client, service-role `grant_all_access_by_email` / `revoke_all_access`. The email is never in the app or the repo.
- Covers store items, equipment, sold roles, table tools (charges never run out; per-match limits stay), characters, story categories.
- No coins minted; receipts, leaderboards, story rewards and ads unchanged.
- Bound to a confirmed, non-anonymous account. Tests: positive, negative, revocation, account switch.
- Live apply only on the owner's word.

## 8. Backend and servers

- **Story sessions (Codex R2-Q9).** `start_story_session(story, players)` picks the culprit (and partner) server-side from a published eligibility table, using this account's history; it returns `{session, seed, culprit, partner}` and the client assembles the version around them. `claim_story_reward(session, who, why, how)` checks the accusation against that session. One paid first solve per story per account stays. Offline play works with a local pick and no coins.
- `story_solutions` becomes one row per (story, guilty module): culprit, motive, method, partner.
- P1's tables and functions.
- No online multiplayer for Stories in V2 (one phone). The engine stays pure and seeded, so an online version stays possible.

## 9. Verification

| Layer | Check |
|---|---|
| Engine | Unit tests: drawing the cast and culprit (played only, history preference and fallback), partner rules, the three mode flows, decisions, scoring, interruption cover |
| Content | Checker V3 over every assembly; 3-search path report; linter; humans read complete assembled versions |
| Narration | Controller tests with a fake player (tap-seek, ±5 s, end, stop on private); adapter contract test |
| Screens | Widget tests for every new screen; RTL, text scale 1.0, 360×640 and 412×915 |
| Leakage | The 5–10 pass: same widget tree shape, height band, taps, hold timings and luminance for every role |
| Identity | `identity_isolation_test.dart`; before/after screenshots |
| Server | SQL tests for all-access and story sessions, positive and negative |
| Journeys | Headless playthroughs of every story at 1–10 players over many seeds |
| Device | Emulator `Pixel 9 pro (2)`: one screenshot per screen per phase |
| People | Pilot tables at 1, 2, 3, 5, 7 and 10, with first-timers, using only the in-app explanation |

## 10. Skills and tools

Installed 2026-10-15 for this work (vetted: no network or destructive code; source list in `~/.claude/skills/INSTALLED-FROM.md`):
- Writing: `humanizer` (blader, ~57k★), `sepia` + `-review/-refactor/-write/-recreate` (~3.2k★), `creative-writing-craft`, `writing-principles`, `llm-writing`, `character-sim`, `reader-sim`, `story-review`, `story-planning` (haowjy, ~512★), `genre-craft`, `plot-structure`, `character-management`, `interactive-fiction`, `line-editing`, `voice-style`, `reader-panel`, `scene-craft` (danjdewhurst, ~311★).
- Testing: `flutter-testing` (MADTeacher, ~110★).
- Project skill: `.claude/skills/stories-case-writing`.

Already installed and used: `superpowers:*` (brainstorming, writing-plans, TDD, systematic-debugging, verification-before-completion), `tdd`, `diagnosing-bugs`, `engineering-skills:senior-qa`, `tdd-guide`, `senior-security`, `adversarial-reviewer`, `engineering-advanced-skills:skill-security-auditor`, `ship-gate`, `flutter-accessibility-audit`, `flutter-fix-layout-issues`, `flutter-build-responsive-layout`, `ui-ux-pro-max`, `impeccable`, `design-taste-frontend`, `product-skills:ux-researcher-designer`, `supabase`, `supabase-postgres-best-practices`, `arabic-natural-writing`, `codex-delegate`, `grilling`.

## 11. Phases

Each phase ends with the CLAUDE.md report block and a stop. Builds and deploys only on the owner's word.

| Phase | Work | Who | Gate |
|---|---|---|---|
| P1 | Owner all-access (§7) | Codex implements, Claude reviews (`senior-security`, `adversarial-reviewer`) | SQL + Dart tests; live apply on the owner's word |
| P2 | Pilot world «قهوة المعلم» + Checker V3 + linter | Codex writes with the writing skills; Sonnet builds the checker; Claude edits | checker green; the owner reads complete versions |
| P3 | HTML mockups S0–S12 and the Mafia screens losing brown; polish | Claude (`impeccable`, `ui-ux-pro-max`, `design-taste-frontend`) | the owner approves every screen |
| P4 | Engine V3, narrator, screens, story sessions — pilot story only | Sonnet medium; Opus reviews the private pass | tests; emulator; **pilot tables** |
| P5 | The other 23 worlds, four at a time | Codex writes; checker; Claude reads | all green; the owner spot-reads two |
| P6 | Openings re-recorded in the chosen voice (زياد if approved) | Claude (ElevenLabs) | STT check |
| P7 | Identity isolation (D13–D15) | Sonnet; Claude reviews against Home | guard test; before/after screenshots |
| P8 | Full verification sweep (§9) | Claude + Codex | recorded in PROGRESS |
| P9 | Build / release | only when the owner says | — |

P7 doesn't depend on the pilot and can start after the mockups are approved.

## 12. Owner decisions

| Q | Decision | State |
|---|---|---|
| Q1 | Seats | **Answered:** 2–4 nobody knows; 5–10 one in-story detective; everyone is a character |
| Q2 | Smallest detective table | **Answered:** 5 |
| Q3 | Who may lie | **Answered by design:** cards never lie; in 5–10 the killer may lie out loud |
| Q4 | Audio | **Answered:** the narrator tells the story only, in زياد's voice (owner, 2026-10-15) |
| Q5 | Owner account email and ads | **Answered:** the Google account eyadsyam124@gmail.com; ads stay on |
| Q6 | Stories look for the mockups | **Answered:** look 1 «الأباجورة» (lamp-dark ground, manila paper, amber action, Ruqaa titles) from the three-look board, 2026-10-15 |
| Q7 | Skills | **Answered:** downloaded and installed |
| Q8 | Pilot | **Answered:** «قهوة المعلم» at 1, 2, 3, 5, 7 and 10 |
| Q9 | Extra suspect at 2 players | **Answered:** no |
| Q10 | Partner floor | **Answered:** no 7-player floor; any size from 5 where the story has a partner |

## 13. Debate log

- R1 (2026-10-15), thread `01a13e6f-b67c-7c71-b248-d7066a52f84c`: twelve proposals; P1–P11 MODIFY, P12 KILL (passes cut). Main point kept: one pilot story played by a real table before the other 23.
- R2 (2026-10-15), same thread, on the owner's answers: Q1, Q2, Q4, Q5, Q7, Q8, Q10 MODIFY; Q3 (proof), Q6 (wipe a trace), Q9 (one solution per story) KILL. Folded in: cards are true but incomplete, so nobody reads a lie he didn't choose; the culprit is always a played character; recent-culprit history is a preference with a fallback; fairness is a 3-search path report, not an all-clues proof; the ad never gates fairness; the killer's hidden move waits for the pilot; partner versions are authored with and without a played partner; reveal audio follows the real versions; story coins verify the session actually played; the pilot covers solo, two players and a partner table. Biggest risk named: keeping 10 × 2 modules coherent across every assembly, so every assembly is generated, checked and read by people before scaling.
