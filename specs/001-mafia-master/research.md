# Phase 0 Research: Mafia Master

All Technical Context unknowns resolved below. Each decision is scoped to serve the constitution
(especially Principle I: Zero Information Leakage).

## R-001 — State management: Riverpod vs Bloc vs setState

- **Decision**: `flutter_riverpod` for UI state; the game engine itself is framework-agnostic
  plain Dart driven through a single `MatchController` (a Riverpod `Notifier`).
- **Rationale**: The engine must be unit-testable with **no Flutter/BuildContext dependency**
  (Principle III). Riverpod lets the UI observe an engine that has no idea Flutter exists, and its
  providers are trivially overridable in tests (inject a seeded engine). Bloc adds event-class
  ceremony without benefit here; raw `setState` cannot isolate leakage logic from widgets.
- **Alternatives considered**: Bloc (more boilerplate, same testability); `provider` (weaker
  compile-time safety); GetX (rejected — global state and implicit magic hurt auditability, which
  is exactly what an anti-leakage codebase cannot afford).

## R-002 — Local persistence: which Isar

- **Decision**: `isar_community` (the community-maintained drop-in fork tracking the Isar 3.1
  API), consumed **only** through a `MatchRepository` interface in `lib/data/`.
- **Rationale**: The spec/design mandate Isar for its fast, offline, ACID, typed collections. The
  original `isar` package (pub `/isar/isar`) stalled — its v4 line was abandoned and v3 lacks
  active maintenance for current Flutter/Dart. `isar_community` keeps the same API and codegen
  while receiving fixes. Wrapping it behind `MatchRepository` means a future swap to `isar_plus`
  or ObjectBox costs one file, and the engine/UI never import Isar directly.
- **Alternatives considered**: `isar_plus` (promising, adds web/IndexedDB we don't need for MVP —
  kept as the documented fallback); Drift/SQLite (relational overhead for a document-shaped match
  record); Hive (no queries/indexes, weaker for history); plain JSON files (no ACID, risky for the
  crash-safe resume requirement FR-030).
- **Risk & mitigation**: fork drift → pin version, isolate behind interface, integration test for
  round-trip persistence + resume (T7).

## R-003 — Golden / symmetry testing approach (Principle III, tests T3/T4)

- **Decision**: `alchemist` for golden tests, with a dedicated `SymmetryGolden` helper that
  renders the same screen four times (one per role) and asserts byte-identical structure, plus a
  `LuminanceBudget` test that computes average pixel luminance per night screen and asserts ≤ ±2%
  deviation.
- **Rationale**: `alchemist` produces deterministic, font-stable goldens across machines/CI
  (native `flutter test` goldens are notoriously host-dependent). Determinism is mandatory because
  a flaky symmetry test is worse than none. The luminance test is custom because no package ships
  an anti-leakage assertion.
- **Alternatives considered**: `golden_toolkit` (now largely superseded by alchemist);
  hand-rolled `matchesGoldenFile` (host-font drift causes false diffs).
- **Test-design note**: goldens run with a fixed seed, fixed clock (dwell timer stubbed), and a
  fixed test font so that role A and role B differ only where text content legitimately differs.

## R-004 — Deterministic randomness for night resolution (FR-013)

- **Decision**: A single `Random` seeded per match (seed stored in the match record). The Mafia
  tie-break draws uniformly from tied targets via this RNG; the seed makes every night reproducible
  in tests and in the analytics timeline.
- **Rationale**: FR-013 requires uniform random tie resolution with no extra phone pass; Principle
  III requires determinism. A stored seed satisfies both — production gets real randomness at match
  start, tests inject a known seed for exact assertions.
- **Alternatives considered**: `Random.secure()` (non-reproducible, breaks golden/unit
  determinism); last-voter-wins (rejected by clarification); no-kill-on-tie (rejected).

## R-005 — Audio without leakage (Principle VI, FR-026)

- **Decision**: `just_audio` with an `AudioDirector` gated by an explicit `PhoneLocation`
  (`onTable` | `inHand`) state. Narration/ambient/drum cues fire **only** in `onTable` phases
  (pre-night lobby, morning, discussion, results). No audio API is reachable from in-hand
  (pass/night-action/vote) screens.
- **Rationale**: Structurally preventing in-hand audio is safer than remembering to mute it.
  Making it impossible to call from the wrong screen is a Principle-I-grade guarantee.
- **Alternatives considered**: `audioplayers` (fine, but `just_audio` has cleaner gapless/ducking
  control for the ambient rise); system sound APIs (too coarse).

## R-006 — Enforcing "no Flutter in engine" and "no hardcoded style" (Principles II & IV)

- **Decision**: Two custom tests: (a) `engine_purity_test.dart` scans `lib/engine/**` for any
  `package:flutter` / `dart:ui` import and fails if found; (b) `token_discipline_test.dart` scans
  `lib/ui/screens/**` and `lib/ui/widgets/**` for literal `Color(0x…)`, hex strings, and raw
  `EdgeInsets`/`Duration` numeric literals outside the token files, failing on violations.
- **Rationale**: Cheap, deterministic guardrails that keep the two hardest-to-review principles
  machine-enforced — essential because implementation is delegated to a cheaper model.
- **Alternatives considered**: custom `analyzer` lint plugin (more power, much more setup); code
  review only (not durable, violates Principle III's "must be machine-verified" stance).

## R-007 — Internationalization & RTL (Principle VII, FR-034)

- **Decision**: `flutter_localizations` + generated ARB (`app_ar.arb`, `app_en.arb`), Arabic as
  the first/default locale, `Directionality` derived from locale, mono font (IBM Plex Mono) for
  all numerals/timers so digit width is locale-stable (a timing/structure parity concern).
- **Rationale**: RTL-first is a hard requirement; tabular mono numerals keep timer width identical
  regardless of value or locale, preserving structural symmetry.
- **Alternatives considered**: `easy_localization` (runtime key lookup, weaker compile-time
  safety); hardcoded strings (rejected — blocks Arabic MVP).

## R-008 — Navigation that forbids in-night back (FR-027)

- **Decision**: `go_router` with night/vote/reveal routes wrapped in `PopScope(canPop: false)`;
  the only in-night exit is an explicit "End match" action routed through a confirm dialog.
- **Rationale**: Declarative routes make the "no back inside night" invariant reviewable in one
  place; `PopScope` intercepts hardware/gesture back uniformly on Android/iOS.
- **Alternatives considered**: imperative `Navigator` (back-suppression scattered per screen,
  easy to miss — a leakage risk).

## Summary of resolved unknowns

| Unknown | Resolution |
|---|---|
| State mgmt | Riverpod + framework-agnostic engine |
| Persistence | `isar_community` behind `MatchRepository` |
| Golden strategy | `alchemist` + custom symmetry & luminance tests |
| Randomness | Seeded `Random` stored per match |
| Audio safety | `just_audio` gated by `PhoneLocation` |
| Principle enforcement | engine-purity + token-discipline tests |
| i18n/RTL | ARB Arabic-first, mono numerals |
| Navigation | `go_router` + `PopScope` night lock |

No `NEEDS CLARIFICATION` markers remain.
