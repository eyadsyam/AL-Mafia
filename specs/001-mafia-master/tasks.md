# Tasks: Mafia Master

**Feature**: `001-mafia-master` | **Input**: design docs in `specs/001-mafia-master/`

**Tests**: MANDATORY. Constitution Principle III requires TDD + golden symmetry tests; the
leakage-invariants contract (L-01…L-17) maps 1:1 to tests below. Tests precede implementation.

**Model routing note**: Planning/design authored on Opus 4.8. Implementation tasks (Phase 3+) are
delegated to Haiku 4.5 subagents; each task is scoped to be completable from the cited contract +
data-model rows without extra context.

**Path convention**: single Flutter project — `lib/…`, `test/…` at repo root (see plan.md).

---

## Phase 1: Setup

- [X] T001 Initialize Flutter app at repo root (`flutter create . --org com.mafiamaster --platforms android,ios`), set app name, portrait-only, min SDK Android 26 / iOS 14 in `android/` + `ios/` configs.
- [X] T002 Add dependencies to `pubspec.yaml`: `flutter_riverpod`, `go_router`, `isar_community` + `isar_community_flutter_libs` + `isar_community_generator`, `google_fonts`, `phosphor_flutter`, `just_audio`, `intl`, `flutter_localizations`; dev: `build_runner`, `alchemist`, `mocktail`, `flutter_lints`.
- [X] T003 [P] Configure `l10n.yaml` and create empty `lib/app/l10n/app_en.arb` + `app_ar.arb` with `@@locale` headers; enable `generate: true` in `pubspec.yaml`.
- [X] T004 [P] Add bundled fonts config or `google_fonts` caching for Cairo, IBM Plex Sans Arabic, IBM Plex Mono; place any offline font assets under `assets/fonts/` and declare in `pubspec.yaml` (offline requirement FR-029).
- [X] T005 [P] Configure `analysis_options.yaml` with `flutter_lints` and directory guards; create the folder skeleton from plan.md (`lib/{app,engine,data,ui,platform}`, `test/{engine,widget,golden,integration}`).

---

## Phase 2: Foundational (blocking — no user story is testable without this)

**Engine domain (pure Dart, no Flutter imports)**

- [X] T006 [P] Create engine enums/value types in `lib/engine/models/enums.dart` (`Role`, `PlayerStatus`, `GamePhase`, `DiscussionMode`, `DayTieRule`, `NightActionKind`) per data-model §3,§9.
- [X] T007 [P] Create `Player` and `PublicPlayer` immutable models in `lib/engine/models/player.dart` (seat, name, role[secret], status, eliminatedOn) per data-model §2; `PublicPlayer` has NO role field.
- [X] T008 [P] Create `MatchSettings` in `lib/engine/models/match_settings.dart` per data-model §4 (speechSeconds, discussionMode, dayTieRule, narrationEnabled, abstainAllowed).
- [X] T009 [P] Create event-log types in `lib/engine/models/timeline_event.dart` (sealed `TimelineEvent` variants) + `NightAction`, `Vote`, `InvestigateResult` per data-model §5,§6,§7.
- [X] T010 Create `Match` aggregate in `lib/engine/models/match.dart` (id, seed, players, settings, phase, dayNumber, currentActorSeat, eventLog, outcome) with immutable `copyWith`, per data-model §1.
- [X] T011 [P] Write `test/engine/engine_purity_test.dart` — scans `lib/engine/**` for `package:flutter`/`dart:ui` imports, fails if any (L-16). MUST fail-then-pass as engine grows.

**Persistence + guardrails**

- [X] T012 [P] Define `MatchRepository` interface in `lib/data/match_repository.dart` exactly per contracts/match-repository.contract.md.
- [X] T013 [P] Write `test/widget/token_discipline_test.dart` — scans `lib/ui/**` for hardcoded `Color(0x…)`/hex/raw `EdgeInsets`/`Duration` numeric literals outside token files (L-17).

**Design system (tokens first — Principle IV) — this is the `/design-sync` handoff point**

- [X] T014 Create `lib/ui/theme/design_tokens.dart` as `ThemeExtension`s (`MafiaColors`, `MafiaTypography`, `MafiaSpacing`, `MafiaRadii`, `MafiaMotion`) with EXACT hex/sizes/durations from `01-design-system.md`.
- [X] T015 Create `lib/ui/theme/mafia_theme.dart` — custom dark `ColorScheme` + text theme wired to tokens (never Material defaults); expose `MafiaTheme.dark`.
- [X] T016 [P] Create `lib/platform/haptics.dart` (single select/confirm helper) and `lib/platform/reduce_motion.dart` (reads OS setting) — the ONLY sanctioned haptic call sites (L-10).
- [X] T017 [P] Create `lib/platform/audio_director.dart` with a `PhoneLocation` gate that throws if asked to play while `inHand` (L-11, FR-026).

**App shell**

- [X] T018 Create `lib/app/router.dart` (`go_router`) with route table; night/vote/reveal routes wrapped in `PopScope(canPop:false)` (L-15, FR-027); and `lib/app/app.dart` + `lib/main.dart` wiring Riverpod `ProviderScope`, theme, and RTL-first localization.

**Checkpoint**: engine models compile, purity + token-discipline tests run, theme + shell boot to a blank Home. All user stories can now build on this.

---

## Phase 3: User Story 1 — Full moderator-free match loop (Priority: P1) 🎯 MVP

**Goal**: a group can play a complete match to a correct win result using only the app.
**Independent test**: run a 7-player match through night→morning→discussion→vote→win to the Result screen (quickstart §"Manual end-to-end").

### Tests (write first, must fail)

- [X] T019 [P] [US1] `test/engine/state_machine_test.dart` — asserts the full phase FSM transitions (data-model §9) incl. actor loops and winCheck routing.
- [X] T020 [P] [US1] `test/engine/resolver_test.dart` — Mafia target − Doctor protection; seeded Mafia-tie uniform draw reproducibility (contract inv. 4, FR-013); Doctor no-repeat rejection (inv. 5).
- [X] T021 [P] [US1] `test/engine/win_check_test.dart` — town iff mafia==0; mafia iff mafia≥town; else continue (inv. 7).
- [X] T021a [P] [US1] `test/engine/day_tie_revote_test.dart` — day-vote tie → defense → revote among tied players only; `noElimination` rule path; dead players excluded from the revote (FR-020, FR-017). *(Added per analyze C2.)*
- [X] T022 [P] [US1] `test/engine/detective_result_ephemeral_test.dart` — investigate returns four-valued result once; not in any `PublicMatchView`; second-in-turn call rejected (L-14, inv. 3).
- [X] T023 [P] [US1] `test/integration/full_match_test.dart` — drives a scripted 7-player match to a win via engine commands only.

### Engine implementation

- [X] T024 [US1] Implement `lib/engine/state_machine.dart` (`MatchEngine` exposing commands from game-engine.contract.md: startMatch, reveal, night loop, resolveNight, discussion, voting, resolveDayVote, winCheck, removePlayer) → make T019/T023 pass.
- [X] T025 [US1] Implement `lib/engine/resolver.dart` (seeded RNG from `Match.seed`, tie draw, Doctor protection & no-repeat) → T020.
- [X] T026 [US1] Implement `lib/engine/win_check.dart` → T021; wire into engine after each elimination.
- [X] T027 [US1] Implement `ActorTurnView`/`PublicMatchView` builders in `lib/engine/views.dart` (roles never in public view) → T022.

### UI wiring (thin; structure hardened in US2)

- [X] T028 [US1] Create `MatchController` (`Notifier`) in `lib/ui/screens/match_controller.dart` bridging engine ↔ Riverpod; provider overridable with a seeded engine for tests.
- [X] T029 [P] [US1] Build role reveal flow: `lib/ui/screens/distribution/role_reveal_screen.dart` + `RoleCard` widget (long-press flip, fixed post-delay "Got it") — S-06/FR-007/FR-008/FR-009.
- [X] T030 [P] [US1] Build `lib/ui/screens/distribution/pre_night_lobby_screen.dart` (S-07) → triggers narrator via AudioDirector (on-table).
- [X] T031 [US1] Build `lib/ui/screens/night/night_action_screen.dart` — SINGLE widget tree; role changes `questionText` + bound tiles + reserved indicator slot only (S-08) → basis for US2 goldens.
- [X] T032 [P] [US1] Build `lib/ui/widgets/player_tile.dart` with reserved indicator slot (empty for non-Mafia), Default/Selected/Dead/Disabled states (design §5.2).
- [X] T033 [P] [US1] Build the post-action step (S-09, uniform minimum duration) and `morning_screen.dart` (S-10; victim name / saved-unnamed / all-survived, NO role — FR-014/FR-015). *Implemented as `TurnShell`'s `confirmed` state rather than a separate `post_action_screen.dart`: the uniform post-action dwell is the same turn-floor clock that gates the pass control, and splitting it into a second screen would have meant a second timing path — exactly what L-08/L-09 forbid.*
- [X] T034 [P] [US1] Build discussion screens `lib/ui/screens/day/discussion_screen.dart` (structured rounds + free mode, `PhaseTimer`, turn chime) — S-11/FR-016/FR-017.
- [X] T035 [US1] Build voting flow `lib/ui/screens/day/voting_screen.dart` (secret, living-only, no self-vote, optional abstain) + `vote_result_screen.dart` with `VoteBar` + role reveal (S-12/S-13, FR-018/FR-019/FR-020).
- [X] T036 [US1] Build `lib/ui/screens/postgame/result_screen.dart` (S-14; winner + full role reveal + when-left) — FR-022.

**Checkpoint**: US1 fully playable end-to-end with a fixed/dev setup. MVP demoable.

---

## Phase 4: User Story 2 — Guaranteed zero-leakage (Priority: P1)

**Goal**: no player can infer another's role from the device.
**Independent test**: golden symmetry ×4 roles pass; luminance ≤±2%; no in-hand audio/haptic; 8s dwell (quickstart automated gates).

### Tests (write first)

- [X] T037 [P] [US2] `test/golden/night_action_symmetry_test.dart` — render `NightActionScreen` ×4 roles, assert identical structure/dimensions (L-01, T3).
- [X] T038 [P] [US2] `test/golden/voting_symmetry_test.dart` + `reveal_symmetry_test.dart` (L-03/L-04).
- [X] T039 [P] [US2] `test/golden/leakage/luminance_budget_test.dart` — average luminance of night screens within ±2% (L-05, T4).
- [X] T040 [P] [US2] `test/widget/dwell_gate_test.dart` — Confirm disabled until 8.0s via stubbed clock, identical per role (L-07, T2).
- [X] T041 [P] [US2] `test/widget/second_step_min_duration_test.dart` + `transition_parity_test.dart` (L-08/L-09).
- [X] T042 [P] [US2] `test/platform/haptics_call_site_test.dart` + `audio_gate_test.dart` (L-10/L-11, T5).
- [X] T043 [P] [US2] `test/golden/leakage/night_color_token_test.dart` — no warm/red token used on night/in-hand screens (L-06).

### Implementation

- [X] T044 [US2] Build `lib/ui/widgets/dwell_gate.dart` (8s activation, injectable clock) and integrate into `NightActionScreen` confirm — T040.
- [X] T045 [US2] Enforce reserved-slot symmetry in `PlayerTile` + `NightActionScreen` so mafia indicator changes data only; make T037/T038 pass.
- [X] T046 [US2] Apply luminance-budget review to all night/in-hand screens (token audit; remove any warm color) — T039/T043.
- [X] T047 [US2] Route all in-night haptics through `platform/haptics.dart` select/confirm only; ensure AudioDirector never reachable in-hand — T042.
- [X] T048 [US2] Add `motion` token-driven transitions to router so per-role durations are impossible to diverge — T041.

**Checkpoint**: US1 screens are now leak-hardened and gated by CI. T1/T2/T3/T4/T5 covered.

---

## Phase 5: User Story 3 — Safe handoff, wrong-hands, crash-safe resume (Priority: P1)

**Goal**: safe pass-the-phone; wrong person exposes nothing; interrupted match resumes on pass screen.
**Independent test**: wrong-pass exposes zero content (T6); force-quit mid-night resumes on PassScreen (T7).

### Tests (write first)

- [X] T049 [P] [US3] `test/integration/wrong_pass_test.dart` — identity gate + "Not X?" reroute exposes no game content (L-12, T6).
- [X] T050 [P] [US3] `test/integration/crash_resume_test.dart` — persistStep→kill→loadActiveMatch→resolveResume returns PassScreen for currentActor (L-13, T7).
- [X] T051 [P] [US3] `test/widget/night_back_lock_test.dart` — hardware/gesture back suppressed in night; only End match exits (L-15).
- [X] T052 [P] [US3] `test/integration/repository_roundtrip_test.dart` — Match round-trips identically incl. seed + eventLog order (repo inv. 5).

### Implementation

- [X] T053 [US3] Build `lib/ui/widgets/pass_screen.dart` (S-05: names target, 600ms long-press ring, no sound/haptic on open, "Not X?" reroute) — T049.
- [X] T054 [US3] Implement Isar layer in `lib/data/isar/` (`MatchRecord`/`PlayerRecord`/`EventRecord` collections + generator) and `IsarMatchRepository` implementing the interface; atomic `persistStep` — T052.
- [X] T055 [US3] Implement `lib/data/resume_resolver.dart` mapping persisted state → PassScreen target; call `persistStep` after every confirmed engine step — T050.
- [X] T056 [US3] Wire `PopScope` End-match confirm dialog (S-17) into night/vote routes — T051.

**Checkpoint**: all three P1 stories complete → the app is safe and resilient. This is the true shippable MVP.

---

## Phase 6: User Story 4 — Fast, balanced setup (Priority: P2)

**Goal**: 5–20 names + balanced roles + settings in under 2 minutes.
**Independent test**: enter 7 names & start distribution < 2 min; invalid configs blocked.

### Tests (write first)

- [X] T057 [P] [US4] `test/engine/balance_guard_test.dart` — min 5, Mafia<half, roles sum=count; 3-Mafia recommendation ≥9; two-Detective warning <11 (FR-004).
- [X] T058 [P] [US4] `test/widget/add_players_test.dart` — Next disabled <5, duplicate auto-suffix, drag-reorder = seating (S-02).

### Implementation

- [X] T059 [US4] Implement `lib/engine/balance_guard.dart` (validity + recommendations/warnings) — T057.
- [X] T060 [P] [US4] Build `lib/ui/screens/setup/home_screen.dart` (S-01) and `add_players_screen.dart` (S-02: quick-add, reorder, name suggestions, dup handling) — T058.
- [X] T061 [P] [US4] Build `lib/ui/screens/setup/roles_screen.dart` (S-03: steppers, auto Citizens, live balance status text) wired to BalanceGuard.
- [X] T062 [P] [US4] Build `lib/ui/screens/setup/settings_screen.dart` (S-04: speech time, discussion mode, tie rule, narration) persisting defaults via `MatchRepository.saveDefaultSettings` (FR-005).
- [X] T063 [US4] Replace the US1 dev-setup harness with the real setup flow → engine `startMatch`.

**Checkpoint**: full real setup UX; the game is now self-serve from Home.

---

## Phase 7: User Story 5 — Post-game analytics (Priority: P2)

**Goal**: timeline, suspicion accuracy, suspicion map, achievements; secrets revealed only now.
**Independent test**: finish a match, open analytics; all four tabs reflect captured data; ballots/suspicions hidden until now.

### Tests (write first)

- [X] T064 [P] [US5] `test/engine/analytics_builder_test.dart` — timeline order, suspicion accuracy (correct iff target alignment mafia), suspicion matrix, ≥1 achievement, from a scripted event log (FR-032).
- [X] T065 [P] [US5] `test/integration/secrecy_until_end_test.dart` — who-voted-whom & suspicions absent from any in-play view; present post-game (FR-019/FR-031).

### Implementation

- [X] T066 [US5] Implement `lib/engine/analytics_builder.dart` (pure projection of eventLog: `MatchSummary`, `SuspicionAccuracy`, `SuspicionMatrix`, `Achievement`) — T064.
- [X] T067 [P] [US5] Build `lib/ui/screens/postgame/analytics_screen.dart` with 4 tabs (Timeline, Player card, Suspicion map, Achievements) — S-15; `TimelineRow`, `AchievementBadge` widgets.
- [X] T068 [US5] Wire Result → Analytics; ensure `loadAnalytics` is the only role/vote-exposing path — T065.

---

## Phase 8: User Story 6 — Resume prompt & history (Priority: P3)

**Goal**: resume unfinished match; browse & reopen finished matches.
**Independent test**: reopen app mid-match → Resume/End; finished match appears in History and reopens analytics.

### Tests (write first)

- [X] T069 [P] [US6] `test/integration/history_test.dart` — finished match listed with players/winner/nights; reopens analytics; swipe-delete with confirm (FR-033).
- [X] T070 [P] [US6] `test/widget/resume_prompt_test.dart` — on launch with active match, Resume/End offered (S-17).

### Implementation

- [X] T071 [US6] Build `lib/ui/screens/postgame/history_screen.dart` (S-16 list, swipe-delete confirm) via `listHistory`/`deleteMatch` — T069.
- [X] T072 [US6] Add launch-time active-match check → Resume/End dialog routing to `resolveResume` — T070.

---

## Phase 9: Polish & Cross-Cutting

- [X] T073 [P] Fill `app_ar.arb` + `app_en.arb` for every user-facing string; verify RTL layout on all screens (FR-034) and mono numerals width-stable.
- [X] T074 [P] Accessibility pass: run `flutter-accessibility-audit`; contrast ≥7:1/4.5:1, touch ≥48dp, Dynamic Type 130%, Semantics that do not encode role (FR-035, Principle VII).
- [X] T075 [P] Reduce Motion pass: verify all `motion-dramatic` animations shorten/remove without changing structure/timing parity (FR-036).
- [X] T076 [P] Audio pass: narration/ambient/drum cues wired only to on-table phases per `01-design-system §8`.
- [X] T077 Run full `quickstart.md` validation (all gates green, manual E2E, crash-resume, offline/airplane-mode) and record results.
- [X] T078 [P] Add app icons/splash (≤1.5s), verify no network permission is declared in Android/iOS manifests (FR-029).

---

## Dependencies & Execution Order

- **Setup (P1..T005)** → **Foundational (T006..T018)** block everything.
- **US1 (P1)** depends only on Foundational → the MVP.
- **US2 (P1)** hardens US1 screens → depends on US1's `NightActionScreen`/`PlayerTile` existing (T031/T032).
- **US3 (P1)** depends on Foundational + the pass/night routes from US1; repository (T054) unblocks resume.
- **US4 (P2)** depends on Foundational (BalanceGuard) + engine `startMatch`; replaces US1 dev harness.
- **US5 (P2)** depends on the event log produced during US1 play.
- **US6 (P3)** depends on US3 repository + US5 analytics.
- **Polish (P9)** last.

## Parallel Opportunities

- All of Phase 1 T003/T004/T005 in parallel.
- Foundational models T006–T009 + purity/discipline tests T011/T013 in parallel (different files).
- Within each story, all `[P]` test tasks run in parallel first (TDD), then implementation.
- US2 golden tests T037–T043 are all `[P]`.

## Implementation Strategy

- **MVP = US1 + US2 + US3** (all three are P1: a playable match that provably doesn't leak and is
  crash-safe). Ship-gate on the leakage test suite.
- Then US4 (self-serve setup), US5 (retention via analytics), US6 (history), then Polish.
- Delegate Phase 3+ tasks to Haiku 4.5 subagents, each fed the relevant contract + data-model rows;
  the guardrail tests (T011/T013) and leakage suite (Phase 4) keep cheap-model output honest.

---

**Total tasks**: 79 · **US1**: 19 · **US2**: 12 · **US3**: 8 · **US4**: 7 · **US5**: 5 · **US6**: 4 · Setup/Foundational: 18 · Polish: 6.

---

## Completion notes (2026-07-28)

All 79 tasks are implemented; 235 tests pass and `flutter analyze` is clean. See
`quickstart.md` § "Validation run" for the gate-by-gate results.

Where the implementation departed from the plan, and why:

- **T033** — the post-action step is a state of `TurnShell`, not its own screen. See the task.
- **T054** — the Isar layer is thin by design. All the logic that could get round-tripping or
  resume wrong lives in `data/match_codec.dart` and `data/resume_resolver.dart`, which are pure
  Dart and directly tested; `IsarMatchRepository` only manages transactions. A
  `MemoryMatchRepository` over an injectable store implements the same interface and is what the
  persistence suites run against — throwing the repository away and rebuilding it over the same
  store reproduces a process kill exactly, without needing Isar's native library in CI.
- **T073** — the engine no longer carries display copy at all. `BalanceIssue` and `Achievement`
  now expose only a stable snake_case `code`, and `ui/l10n_ext.dart` turns codes into words. That
  was a prerequisite for localisation (`lib/engine` is pure Dart and must stay language-agnostic,
  L-16) and is enforced by `widget/l10n_coverage_test`.

Defects found and fixed while completing these phases:

1. **Day revote counted the ballot that tied.** `resolveDayVote` re-tallied every `VoteCast` for
   the day, so a revote was added on top of round one, and the revote ballot was not restricted to
   the tied seats (FR-020). Fixed by adding a round number to `VoteCast` and a `DayRevoteCalled`
   event, both derived from the log so a revote survives a force-quit.
2. **`Match` and `DayResolved` used identity equality for their lists and maps**, so a match
   reloaded from storage could never compare equal to the one written — the round-trip fidelity the
   repository contract requires (inv. 5) was untestable.
3. **The night prompts were not luminance-balanced.** The four questions differed in length by up
   to seven glyphs, moving average screen brightness by 3.3% between roles — over the ±2% budget
   (L-05). The copy was rewritten to a fixed ink length, now enforced by
   `widget/night_prompt_balance_test`.
4. **The Mafia prompt named the Mafia.** A screen reader would have announced the holder's role to
   the whole table (Constitution VII). Rewritten to avoid every role word.
5. **iOS allowed landscape** despite the portrait-only requirement, and the Android launcher label
   was the package name.
6. **The settings radio rows overflowed** by 4px on a 390dp screen, and would overflow on every row
   at 130% Dynamic Type.
7. **History's swipe-to-delete asserted** after deletion, because the list was rebuilt from storage
   rather than from local state.
8. **Resuming into the night rendered a blank screen** — the actor's turn was never re-opened after
   `adoptMatch`.
9. **The resume prompt could not open**, because `MaterialApp.builder` sits above the Navigator.

Outstanding, and deliberately so: the on-device pass (real-ambient-light brightness parity, haptic
silence by touch, airplane-mode play-through) has not been run — everything to date is host-side.
Audio playback is still stubbed behind `AudioDirector`; the gate and the cue wiring are real and
tested, only the sound output is missing, pending the SDK-path fix noted in `pubspec.yaml`.
