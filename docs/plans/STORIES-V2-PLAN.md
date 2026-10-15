# Stories V2 — «قصص وتحقيقات» for a real table

Status: **PROPOSED, 2026-10-15.** Nothing is implemented. Owner decisions in §12 come first, then the HTML mockups (§11 P2), then code.
Branch: `claude/epic-roentgen-094f21`. Applies to **all 24 stories** (owner: «دا لكلوا حرفيا مش قصة وحده»).

Read with: `CLAUDE.md` (non-negotiables), `docs/specs/05-zero-leakage-spec.md` (private pages),
`lib/stories/*`, `lib/ui/screens/stories/*`, the draft identity in
`../mafia-game-design-system-fca2a6/design-system/stories/IDENTITY.md` (not signed off).

---

## 0. What the owner asked (2026-10-15, after a real table of friends)

1. A story details screen before play: what happened, the victim, the place, **every character introduced**.
2. Players type their names; the app introduces the characters, deals one to each player, and each player privately learns his role.
3. A clear goal for a group: solo = you are the investigator. Group = some players are suspects and some are not; every player knows his role; **the killer knows he is the killer**.
4. A how-to-play screen for the group mode. Nobody at the table understood what to do.
5. The secret file must say what is read aloud and what stays private. Every name and object in it must have been introduced.
6. The narrator in every mode, with full control: pause, scrub, back/forward, restart, stops by itself at the end. Rule: **a feature exists in every mode or in none.**
7. Stories is a separate game. Its brown case-file look and Ruqaa leaked into Mafia screens; Home's colours are the app's (Mafia) identity.
8. The owner's personal account gets everything unlocked: store, roles, characters, stories.
9. Many first-time players are coming. Assume nobody knows the game.

## 1. Confirmed defects (evidence)

| # | Defect | Evidence |
|---|---|---|
| D1 | The culprit's player is never told; the dossier is the same for everyone and names no role | `lib/stories/story_session.dart` (no role field), `StoryDossier` in `lib/ui/screens/stories/story_case_widgets.dart:1360` |
| D2 | Seats take the **first N characters**; culprit ids vary (n01…n09), so at 4 players the culprit is sometimes seated (unaware) and sometimes absent | `_seatingFor` in `story_session.dart`; culprits per story: 1:n02+n01, 2:n06, 3:n05, 10:n09, 13:n08 … |
| D3 | The checker proves solvability only if **every** private clue is shared truthfully, so a hiding culprit can break it | `lib/stories/story_checker.dart:95` |
| D4 | The culprit can hold clues that name him (n02 holds `motive_voice_note`) | `assets/stories/qahwet_el_moallem.json` |
| D5 | No story details screen and no cast introduction before the deal; the group cast screen shows «اللاعب ١…» with question marks | `_cast` in `lib/ui/screens/stories/story_flow_screen.dart:560` |
| D6 | No player names in Stories | `StorySession` has `playerCount` only |
| D7 | No group how-to | no stories entry in `how_to_sheet.dart` |
| D8 | Narration has no real player: fire-and-forget `playAccent`, local fake «playing» state, no seek/pause/position | `router.dart:490`, `StoryNarratorBar` `story_case_widgets.dart:719` |
| D9 | The group cast screen has no narrator control at all | `_cast` vs `_solo` in `story_flow_screen.dart` |
| D10 | The reenactment replays the **opening** audio; no truth narration exists | `storiesNarratorActs` bar uses `story.narrationAudio` (`story_flow_screen.dart:1007`) |
| D11 | Clue text is riddle-like and names people never introduced («برنامج الثمانية ونص باين في انعكاس المراية… ٧٤ ثانية هو سامح») | clue `culprit_coal` |
| D12 | The `proves` line («يعني إيه») exists in data but the group dossier never shows it | `StoryDossier` |
| D13 | Stories tokens in Mafia files: CaseFileTokens/CaseFilePaper/StoryTokens.ruqaa in `postgame/result_screen.dart`, `postgame/match_file.dart`, `missions/casebook_sheet.dart`, `setup/profile_screen.dart`, `setup/store_shop.dart`, `setup/coin_store.dart`, `setup/mode_screen.dart`, `setup/how_to_sheet.dart`, `onboarding/first_run_screen.dart`, `widgets/deck/deck_public.dart` | grep `CaseFileTokens\|StoryTokens\|CaseFilePaper` outside `screens/stories` |
| D15 | Home paints `AppColors.groundBase` #0F0F0F, but `DeckTokens.ground` is aliased to the brown `IdentityTokens.ink` #140F0C, so every public deck screen sits on brown: store, seat cards, first run, mode, roles, settings, how-to | `design_tokens.dart:117`, `core/theme/app_colors.dart:90` |
| D14 | Stories borrows Mafia deck tokens (`DeckTokens.bone/text2/silver`, `BoneButton`, `HoldPad`) | `story_flow_screen.dart` |

## 2. Game design V2

### 2.1 Three modes, picked by table size

| Players | Mode | Who is who |
|---|---|---|
| 1 | «لوحدك» | You are the investigator. Today's solo loop (moves budget, searches, accuse who/why/how). |
| 2–4 | «محققين مع بعض» | Everyone is an investigator. Nobody plays a character; the culprit is a story character. One shared board, the table discusses and decides each move, one shared accusation. |
| 5–10 | «القاتل بينا» | Social deduction. 5–7: one «المحقق» + the rest play characters. 8–10: two «محققين». Exactly one character seat is **the killer, and he knows it**. |

Five is the floor for «القاتل بينا» (Codex R1-C): at four, one detective faces two innocent witnesses and the killer, and one hidden clue or disputed alibi leaves a coin flip. (Owner decision Q2.)

### 2.2 Seats in «القاتل بينا»

- **المحقق** (public): not a character, provably innocent. Chooses the table's search each round after hearing the table (his choice is final), reads found evidence aloud, and his vote breaks a tie. With two detectives, they agree; if they disagree the app alternates who decides (round 1 = detective A).
- **مشتبه فيه بريء** (secret): plays a character. Must state his testimony accurately when asked. May keep his small personal secret, which by construction is never part of the solution (§3).
- **القاتل** (secret): the primary culprit's character is always dealt to a player. His file says «انت القاتل», gives his true evening timeline and a cover story. He may hide and twist; he is the only one allowed to.
- **الشريك** (secret, two-culprit stories 1, 4, 12, 14, 21, only at 8–10 players): knows the killer, the killer knows him; they win and lose together. Below 8 players the accomplice is a non-played character whose acts appear in evidence. Story 15 (five involved characters) is audited on its own before it gets a mode.
- The public deal shows «أحمد = سامح، ابن أخو المعلم» for every character seat and «مريم = المحققة» for detectives. Guilt is never on a public screen.

### 2.3 The round loop (passes cut from 4N to 3N)

1. **Deal pass** (private, once): identity + role + where you were + testimony 1.
2. **Round 1**: timed discussion with a prompt («كل واحد يقول كان فين الساعة ٨:٤٥») → detective picks search 1 → evidence read aloud.
3. **Short pass** (private): testimony 2 only, two lines, same page for every seat.
4. **Round 2**: discussion → search 2.
5. **Round 3**: discussion → search 3 → «آخر كلام» (each suspect one sentence).
6. **Vote pass** (private): culprit (any story character), motive, method. Everyone votes, the killer included.
7. **Reveal**: narrated truth, then the result.

Old clues are never repeated on a private page (Codex R1-P12).

### 2.4 Winning

- Verdict = the character with most culprit votes; tie → the detectives' votes decide; still tied → the killer escapes.
- Verdict = primary culprit → detectives and innocents win; otherwise the killer (and accomplice) win.
- Per-player points: culprit / motive / method correct; the killer scores for every vote that missed him.
- Personal secrets carry no points (they are colour, and the app can't judge "exposed").
- Story coins (`claim_story_reward`) as today: the phone's account, first solve, when the table's majority culprit, motive and method are all right.

### 2.5 What is public and what is private

| Information | Where |
|---|---|
| Story intro, victim, places, every character's photo, name, tag and public bio | Public screens and the «الشخصيات» sheet |
| Who plays which character; who the detectives are | Public deal screen |
| Found evidence from searches | Public, read aloud |
| Your role (بريء / القاتل / الشريك), your real timeline, cover story, personal secret | Private file only |
| Your testimony | Private file, labelled «قوله لما يسألوك» |

Every private block carries one plain label: «سرّك — ليك انت بس» or «قوله لما يسألوك». The public bio is never repeated on the private page, so the old question «أقوله ولا لأ؟» cannot come up.

### 2.6 Zero leakage on private pages

Killer, accomplice and innocent pages use one template: same blocks in the same order, same heights (fixed text boxes sized to the longest authored text of the story), no scrolling, same tap path, same hold and hide timings, same luminance. Detectives get a page of the same shape («انت المحقق… مفيش سر عندك») so a detective's pass looks like everyone's. Doc 05 observation tests cover it (§9).

### 2.7 Interruptions

Backgrounding on any private page covers it and returns to that seat's hand-off; a half-made ballot is dropped (today's `coverForInterruption`, kept). Leaving mid-story asks first; the session is not resumable in V2.

## 3. Content V2 (all 24 stories)

**Pilot first** (Codex R1-A): «قهوة المعلم» is rewritten, checked and played by a real table at 5 and 10 players, including first-timers and a lying killer, before the other 23 are touched.

### 3.1 New and changed fields

- `victim` {name, tag}; `dateline`; `intro` (the narrated opening text, 60–90 s); `revealNarration` (the truth, told as a scene).
- Character: `tag` (≤6 words, «ابن أخو المعلم»), `publicBio` (1–2 lines), `castOrder`, and private: `where` {time, place, text}, `secret`, `testimony` [2].
- Culprits: `truthTimeline` (own acts), `coverStory`, `partner`.
- Clue: rewritten `body`, a new authored `meaning` («يعني إيه؟», never the raw `proves`, which can say more than the clue warrants).

### 3.2 Writing rules (Egyptian Arabic, `arabic-natural-writing`)

- Every name in any text is a cast member or the victim. The UI makes names tappable to the character card.
- No riddles. One fact per sentence, times as «٨:٤٣». A clue states what was seen and by whom.
- The café clue becomes, for example: «فيديو موبايل كان بيصوّر الدومنة الساعة ٨:٤٣، ومراية القهوة الطويلة باينة فيه. ساعة ما الحجر اتجهز: رضا في حوش الفحم، شعبان في التاكسي، ونورا قدام الدفتر. الوحيد اللي اختفى من المراية ٧٤ ثانية: سامح.» Meaning: «يبقى رضا وشعبان ونورا ماجهّزوش الحجر.»
- Each innocent's `where` is checked against `truth.timeline`.
- The secret is small and human (owes money, met someone in secret), never a solution fact.

### 3.3 Checker V2 (`lib/stories/story_checker.dart`)

For every story, table size 5–10 and detective count:
1. The culprit (and, at 8–10, the accomplice) is in the seated set; the seated set = culprits + the first innocents of `castOrder`.
2. **Fair:** for every reachable choice of three searches, innocent testimony + found evidence leaves exactly one culprit (motive and method likewise).
3. **Robust:** removing any one innocent's testimony still leaves one culprit.
4. **Catchable:** the cover story contradicts at least one innocent testimony or searchable clue (authored `contradictedBy`).
5. Secrets and the culprit's own testimony are never needed for 2–3.
6. Private page text fits its fixed boxes; lengths across seats stay within the template's band.

The app promises a fair case when innocents tell what they saw. It does not promise deduction against unlimited lies (Codex R1-P5).

The solo and co-op proofs stay as they are.

**Linter** (`tool/stories/check.dart`): unknown names, raw `proves` text in a clue, Latin letters, over-length text, missing tags, timeline mismatches.

## 4. Screens and flow

All in the Stories identity. «جديد» = new screen.

| # | Screen | Public/private | Notes |
|---|---|---|---|
| S1 | Stories hub | public | restyled; each case shows players range and duration |
| S2 | «ملف القضية» (جديد) | public | cover, dateline, victim, places, narrator player, «اللي حصل», character gallery (tap → card), «العب لوحدك» / «العب مع صحابك» |
| S3 | «كام واحد؟ واكتبوا أساميكم» (جديد) | public | count picker shows the mode name per count; name fields; last table's names prefilled |
| S4 | «إزاي نلعب» (جديد) | public | 5–6 cards per mode, one worked example round, optional narration; required the first time per mode, a «عرفنا» skip after |
| S5 | «مين هيلعب مين» (جديد) | public | names → characters; detectives marked |
| S6 | Hand-off | public | uses the player's name |
| S7 | «ملفك» | private | §2.5–2.6 template |
| S8 | Discussion | public | round prompt, timer, found evidence, «الشخصيات», «اسمع البداية تاني» |
| S9 | Search | public | «الدور على مريم (المحققة) تختار»; evidence read aloud |
| S10 | «شهادة جديدة» (جديد) | private | round-2 short pass |
| S11 | Secret vote | private | names, then culprit/motive/method |
| S12 | Reveal | public | new reveal narration + timeline |
| S13 | Result (جديد layout) | public | each player: name, character, role now revealed, vote, team result, points |

- «الشخصيات» sheet: on every public screen, never on S6/S7/S10/S11.
- Solo and co-op get S2, S4 (their own cards), the narrator player, the «الشخصيات» sheet, the `meaning` line and the reveal narration.

**Feature parity rule** (owner): narrator, cast sheet, how-to, meaning lines, reveal narration and rewards exist in all three modes. Ads keep today's placements (before and after a story; the extra-step rewarded ad extends to co-op because it shares the solo board); never during play.

## 5. Narrator player (every mode)

- One `NarrationController` in `lib/platform/` with its own `AudioPlayer` (audioplayers 6.8, already a dependency), separate from the SFX pool and the ambient loop. It exposes `state` (idle/loading/playing/paused/ended/error), `position`, `duration`, and `play(asset)`, `pause()`, `resume()`, `seek(d)`, `skip(±10 s)`, `restart()`, `stop()`.
- Reaching the end sets `ended`: the bar shows «اسمعها تاني», never loops, never restarts by itself.
- It stops on: any private page (hand-off, dossier, ballot), leaving the story, app backgrounding, and starting another track.
- One `StoryNarratorPlayer` widget (stories identity): play/pause, a scrub bar with elapsed/total, ±10 s, restart. Same widget on the story file screen, the solo board, the group discussion and the reveal. Its UI state comes from the controller, never from a local flag.
- Fake controller for widget tests; a contract test for the audioplayers adapter (seek, complete, stop).
- Web: the same controller over audioplayers' web backend; the first play still needs a user tap (browser rule), so the story file screen shows the play button instead of autoplaying.
- New audio per story: the reveal narration (`revealNarration`), plus one how-to narration. ElevenLabs with an approved voice (owner picks, §12). The opening tracks stay.

## 6. Identity isolation

- **App identity = Mafia = Home.** Every screen outside Stories uses the Home deck tokens. Stories' identity begins after «قصص وتحقيقات» is tapped and ends on leaving it.
- Tokens stay in the one token file (`lib/ui/theme/design_tokens.dart`, the working agreement's single location), split into a Stories group (`StoriesTokens`, from the draft `design-system/stories/tokens.json` once signed off) that only Stories code may use. Stories widgets move to `lib/ui/screens/stories/widgets/`; `CaseFilePaper` and `WarmPalette` leave `lib/ui/widgets/`.
- The 10 Mafia files in D13 get Mafia components instead (deck paper, Cairo/Plex). Ruqaa leaves Mafia completely.
- Stories stops borrowing Mafia components (D14): its own primary button, hold pad and paper, built on its own tokens, keeping the zero-leakage properties of the hold pad.
- **Guard test** `test/architecture/identity_isolation_test.dart`: fails when a file outside the stories folders references a stories token/widget/font, or a stories file references Mafia-only tokens. Identity-neutral pieces (spacing, radii, motion, Semantics helpers) stay shared and are allow-listed.
- Before restyling: a screenshot audit of every Mafia screen beside Home (the existing `test/preview` render harness plus the emulator), listing each brown or Ruqaa element. Each changed screen gets an HTML mockup first (owner rule).

## 7. Owner account: everything open

- Server table `all_access_grants(user_id uuid primary key, reason text, granted_at, revoked_at)`, RLS on, no client grants. Granted once by service-role SQL that looks the owner's email up in `auth.users`. The email is never compared on the client and never ships in the app.
- `has_all_access(p_user uuid)` (security definer, `search_path` pinned) is OR'ed into **every** purchase and ownership path, each one listed and tested: `buy_reward_item`, `catalog_charge`, table-tool buy/use (charges never run out; per-match limits stay, they are game rules), role enabling, equipment and inventory views, frames, narrators, room packs, characters, story category gates.
- The grant binds to the owner's recoverable account (Google sign-in), never an anonymous identity; tests cover revocation and switching accounts on the same phone.
- Client: `my_entitlements()` returns `{allAccess: bool}`; the store shows items as owned; the Stories hub opens every category.
- Coins, receipts and leaderboards are unchanged: all-access does not mint coins.
- Ads stay as they are unless the owner says otherwise (standing rule: never reduce ads). If he wants them off on his own account, that is the existing `creator_entitlements` grant, not a new path (Q5).
- SQL tests: a granted user owns everything; a normal user owns nothing extra; `authenticated` cannot insert a grant or call the grant path; revoking closes it again.
- Applying the migration to the live project needs the owner's OK in the moment.

## 8. Backend and servers

- Story rewards stay as they are (`claim_story_reward`, first solve per user per story, answer verified against `story_solutions`). The truth of all 24 stories (culprit/motive/method) does not change, so `story_solutions` does not change.
- New: §7's table and function, and their ownership hooks in the existing store RPCs.
- No new online mode for Stories in V2 (one phone only). Nothing in V2 blocks an online version later: the session stays a pure, seeded engine.

## 9. Verification

| Layer | Check |
|---|---|
| Engine | Unit tests: dealing (culprit always seated, accomplice rule, detective seats), phases, vote tally, ties, scoring, interruption cover |
| Content | Checker V2 for every story × table size × detective count; clarity linter; dossier length parity |
| Narration | Controller tests with a fake player; adapter contract test |
| Screens | Widget tests for every new screen; RTL, text scale 1.0, 360×640 and 412×915 |
| Leakage | Killer and innocent pages: same widget tree shape, same block count, same height band, same hold timings |
| Identity | `identity_isolation_test.dart`; screenshot audit before/after |
| Server | SQL tests for all-access (positive and negative) through `node tool/test_sql_without_docker.mjs` |
| Journeys | Headless full playthrough of all 24 stories at 1, 2, 3, 4, 6, 8 and 10 players |
| Device | Emulator `Pixel 9 pro (2)`: one screenshot per screen at the end of each phase |
| People | A real table: the owner and friends, including two people who never played, using only the in-app how-to |

## 10. Skills and tools

Installed and used here: `superpowers:brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`; `tdd`, `diagnosing-bugs`; `engineering-skills:senior-qa`, `tdd-guide`, `senior-security`, `adversarial-reviewer`; `engineering-advanced-skills:skill-security-auditor`, `ship-gate`; `flutter-accessibility-audit`, `flutter-fix-layout-issues`, `flutter-build-responsive-layout`; `ui-ux-pro-max`, `impeccable`, `design-taste-frontend`, `product-skills:ux-researcher-designer`, `ui-design-system`; `supabase`, `supabase-postgres-best-practices`; `arabic-natural-writing`; `codex-delegate`, `grilling`.

Proposed additions (owner approves the download; each is read and run through `skill-security-auditor` first):
- `madteacher/mad-agents-skills` → `flutter-testing` (unit, widget, golden, integration, flaky tests).
- `board-game-designer` (claudskills.com) → playtest plan for the group mode.

## 11. Phases

Each phase ends with the CLAUDE.md report block and a stop. Builds and deploys only on the owner's word.

| Phase | Work | Who | Gate |
|---|---|---|---|
| P0 | Owner answers §12 | owner | answers recorded here |
| P1 | Owner all-access (§7): migration, hooks in every path, client flag, SQL tests | Claude (security review: `senior-security`, `adversarial-reviewer`) | SQL tests pass locally; live apply after owner OK |
| P2 | Pilot content: «قهوة المعلم» rewritten to §3; checker V2 + linter | Codex writes the text, Sonnet the checker; Claude reviews | checker and linter green; owner reads the pilot file |
| P3 | HTML mockups of S1–S13 and the Mafia screens losing brown; polish pass | Claude (`ui-ux-pro-max`, `impeccable`, `design-taste-frontend`) | owner approves every screen |
| P4 | Engine V2 + narrator controller + the screens, pilot story only | Sonnet medium; Opus reviews the private pages (Doc 05) | tests; emulator screenshots; **a real table of 5 and of 10 with first-timers** |
| P5 | The other 23 stories, batches of four | Codex writes; checker gate; Claude reads | 24/24 green; owner spot-reads two |
| P6 | Reveal and how-to narration audio | Claude (ElevenLabs, after owner OK) | STT pronunciation check |
| P7 | Identity isolation: screenshot audit, restyle the Mafia screens, guard test | Sonnet; Claude reviews against Home | guard test; before/after screenshots |
| P8 | Full verification sweep (§9) | Claude + Codex | all checks recorded in PROGRESS |
| P9 | Build / release | only when the owner says | — |

P1 and P7 don't depend on the pilot and can start right after P0.

## 12. Owner decisions

| Q | Decision | Recommendation |
|---|---|---|
| Q1 | Seats in «القاتل بينا» | one detective at 5–7, two at 8–10; the rest play characters; one killer who knows |
| Q2 | Smallest table for «القاتل بينا»; what 2–4 play | 5; 2–4 play «محققين مع بعض» |
| Q3 | Who may lie | only the killer (and his partner); innocents tell their testimony and may keep their small secret |
| Q4 | New audio: 24 reveal tracks + how-to, ElevenLabs credits | yes, same voice as the openings (Adam) |
| Q5 | Owner account: which email, ads on it, coins | the Google account the owner signs in with; ads stay on; no coins minted |
| Q6 | Stories identity base for the mockups | the draft lamp-and-manila identity (`design-system/stories`) |
| Q7 | Download two skills (§10) | yes, vetted first |
| Q8 | Pilot story and table test | «قهوة المعلم»; the owner's friends incl. two first-timers |

## 13. Debate log

- R1 (2026-10-15): Claude's twelve proposals → Codex (gpt-6-sol, medium, read-only), thread `01a13e6f-b67c-7c71-b248-d7066a52f84c`.
  - P1–P11: MODIFY. Folded in: «القاتل بينا» starts at 5; exact search and tie rules; accomplice rules and story 15 audit; innocents must state their testimony and the secret is never a solution fact; reachable-play, robustness and contradiction checks instead of the all-clues assumption; full Doc 05 page parity; authored `meaning` instead of raw `proves`; interruption and cast-sheet boundaries; tokens stay in the single token file; every purchase path covered.
  - P12: KILL. Old clues are no longer repeated; passes go from 4N to 3N.
  - A: the biggest risk is the conversion itself, so one pilot story is played by a real table before the other 23.
