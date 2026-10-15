# Mafia core audit — every role, every tool, offline and online

Status: **PLANNED, 2026-10-15.** Not started. Runs as its own track beside Stories V2 (owner: «حطها في تسكاية بس انت المفروض تعملها»).
Owner's words: study every case that can happen in the Mafia game — doctor, detective, mafia, silencer, elder, every role, every tool, offline and online; check that the tools really work, that roles compose correctly offline, that each role's action really works, and that **the text shown is right**. «ده حرفيا الكور بتاع الابلكيشن كله.»

Branch: `claude/epic-roentgen-094f21`. Read with `CLAUDE.md`, `docs/specs/05-zero-leakage-spec.md`, `docs/specs/09-information-engine.md`, `docs/specs/10-online-architecture.md`, `docs/specs/11-edge-cases-and-tests.md`.

## 1. Scope

| Area | Items |
|---|---|
| Roles | المافيا (`mafia`), مافيا التسكيت (`silencer`), الدكتور (`doctor`), المحقق (`detective`), شيخ الصالحين (`elder`), القناص (`sniper`), المواطن (`citizen`) — `lib/engine/models/enums.dart:10` |
| Setup | role composition per player count, `balance_guard.dart`, presets عادي/صعب/على مزاجك (`presets.dart`), sold roles gated by ownership (`optional_roles.dart`) |
| Night | kills, saves, investigations, silencing, the sniper's bullet, tie-breaks, the silencer inheriting the kill |
| Day | discussion, votes, ties and revotes, the elder's reveal and triple vote, silenced players, elimination |
| Win | every end state (`win_check.dart`) |
| Information engine | traces, confrontations, witness, whispers (`lib/engine/information/*`) |
| Tools (online) | 17 table tools: extra_minute, anon_note, last_will, spotlight, objection, last_word, vote_shield, half_door, double_vote, camouflage, revote, grave_vote, sense, impersonate, narrator_whisper, lock_door, appeal (`supabase/functions/_shared/tools.ts`, `supabase/migrations/20261007000200_table_tools.sql`) |
| Modes | offline pass-and-play, bots (`lib/engine/bots/bot_brain.dart`), online (edge functions) |
| Text | every line a player sees for every event: public announcements, private night feedback, verdicts, end screen (`lib/app/l10n/app_ar.arb`) |

## 2. What the code already says (evidence)

- **The rules live twice.** Offline runs the pure Dart engine (`match_engine.dart`, `resolver.dart`, `win_check.dart`). Online runs a TypeScript port in edge functions: `resolve_night/index.ts` («Mirrors `NightResolver.resolveNight`»), `resolve_vote/index.ts`, `_shared/{trace,confrontation,seed,silence,tools,teams}.ts`. Any drift between the two is a bug the player sees as "online plays differently".
- **Parity is checked only for traces and confrontations** (`supabase/tests/golden_vectors.test.ts` ↔ `test/engine/golden_vectors_test.dart`). Night resolution, votes, ties, the new roles, tools and win checks have no Dart↔TS parity test.
- **`docs/specs/11-edge-cases-and-tests.md` predates the new roles and the tools** (no mention of silencer, elder, sniper or any tool).
- Offline already has a fuzz harness (`test/engine/fuzz_harness_test.dart`, `fuzz_coverage_test.dart`) and new-role tests (`test/engine/new_roles_test.dart`).
- Online has 18 live Python harnesses (`supabase/tests/*.py`, entry `run_live_suite.py`); the last live runs passed (revote 39/39, kick 62/62, roles/tools 235/0), but an earlier phase recorded a **"known live role leak"** in the confrontation and dead-night suites (`docs/PROGRESS.md`, PHASE live-online-simulation). Its status must be confirmed first.
- Tools exist **online only**; nothing in `lib/engine` uses them. The owner's rule says store items work in every mode, so this needs his ruling (§6 Q1).

## 3. Method

### A. One rule book
`docs/specs/17-roles-and-tools.md`: for every role and tool — ability, phase, valid targets, limits, priority in resolution, interactions, and exactly what each player sees (public line, private line, nothing). Built from the Dart engine, the TS port, the Arabic copy and the owner's rulings (silenced player can't talk or vote but can be voted; one sniper bullet per match, the doctor can't block it; the silencer kills only once the killers are gone; a Play refund revokes the item; a kick-decided match voids rewards). Where Dart, TS, copy or a ruling disagree, the case goes to the owner; nothing is "fixed" silently.

### B. The case matrix
Every role × role × event and tool × tool pair, as numbered cases with an expected outcome. Examples:
- doctor saves the mafia's target; doctor saves himself (rule?); doctor and sniper on the same player;
- sniper hits mafia / hits a town player (both die) / hits the silencer / is killed the same night;
- silencer's target is also killed; silenced player is voted out; last killer dies → the silencer inherits the kill the next night;
- detective checks the silencer, the elder, a camouflaged player;
- elder reveals then is killed; elder's triple vote decides a tie;
- vote_shield vs double_vote; revote vs appeal; lock_door vs narrator_whisper; impersonate vs sense; grave_vote by a dead player; tools at the per-match limit; a tool used by a player who is then kicked or disconnects.

### C. Offline engine
One deterministic scenario test per matrix case (seeded), the four invariants of spec 11 §0 after every mutation, plus new invariants (a silenced player has no vote; the bullet fires once; the triple vote only after reveal). Extend the fuzz harness with the new roles and every legal action.

### D. Text catalogue
A test that plays scripted and fuzzed matches and records **every user-visible line per seat** (public and private) into a readable catalogue. Checks: right names, right gender forms, no role name leaking where it shouldn't (Doc 05), no stale wording, Arabic copy rules (line-height and letter-spacing are UI; the catalogue checks words). The owner reads a short Arabic summary of it.

### E. Dart ↔ TypeScript parity
Extend the golden-vector contract from traces/confrontations to night resolution, votes and ties, win checks, silence, the sniper and every tool effect. A Dart tool generates thousands of random scenarios with expected outputs; a Deno test runs the TS cores on the same inputs and must match exactly. Where a handler mixes I/O and rules, the rule core is extracted into `_shared/` first (no behaviour change, its own test).

### F. Online live
Run `run_live_suite.py` against the hosted project after confirming the deployed functions match the repo (the role-leak note above). Add live cases for any matrix row only the server can show (disconnects, timers, races). Anonymous sign-up limits apply (mint sessions first; see the hosted-verification memory).

### G. Store items in every mode
Sold roles in offline, bots and online; tools online (and offline if the owner rules so); equipped cosmetics shown everywhere; the owner's all-access account included.

### H. Device and people
Emulator `Pixel 9 pro (2)`: offline matches with each composition, one screenshot per announcement type. Then the long-pending **real multi-phone online match** with the owner and friends.

## 4. Who does what

Codex (gpt-6-sol) writes the rule-book draft from the code, the scenario tests and the parity harness in briefs Claude writes; Claude reviews every diff, reruns the gates and commits. Claude writes the matrix and the text review. Skills: `superpowers:test-driven-development`, `systematic-debugging`, `verification-before-completion`, `flutter-testing`, `engineering-skills:senior-qa`, `adversarial-reviewer`, `tdd-guide`, `supabase`, `arabic-natural-writing`.

## 5. Phases and gates

| Phase | Work | Gate |
|---|---|---|
| A0 | Baseline: full `flutter test`, SQL harness, Deno tests, golden vectors; record pre-existing failures | numbers in PROGRESS |
| A1 | Rule book + case matrix; Codex critique; owner rulings on every conflict | owner answers |
| A2 | Offline scenario tests + fuzz extension | all cases green or logged as defects |
| A3 | Text catalogue + review | owner reads the summary |
| A4 | Dart↔TS parity harness | zero mismatches or logged defects |
| A5 | Live online suite (deploy pending functions only on the owner's word) | live suite green |
| A6 | Emulator pass + real online table | screenshots + owner's table |
| A7 | Fixes, each with a regression test; rules changes only with the owner's OK | report |

Every defect is recorded as CONFIRMED / HYPOTHESIS with its evidence (USEI-X §2). No build, deploy or live flag flip without the owner's word.

## 6. Owner questions (asked when A1 starts)

- Q1. Tools offline: should table tools work in pass-and-play and bot matches too, or stay online-only?
- Q2. Every rule conflict A1 finds.
