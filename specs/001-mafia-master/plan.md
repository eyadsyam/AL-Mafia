# Implementation Plan: Mafia Master

**Branch**: `001-mafia-master` | **Date**: 2026-07-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-mafia-master/spec.md`

## Summary

Mafia Master is an offline, single-device, moderator-free companion for the party game Mafia,
whose overriding requirement is **zero information leakage** across visual, timing, audio,
haptic, and structural channels. The technical approach: a **pure-Dart game engine** (a
deterministic, seed-driven finite-state machine with no Flutter dependency) drives a **thin
Material 3 UI** built entirely from design tokens. Every leakage-sensitive screen renders from a
**single widget tree** whose role differences are text/data only, guarded by an 8-second timing
floor, a shared luminance budget, and **golden symmetry tests** that assert pixel-identical
structure across all four roles. State persists locally (offline, no network) after each
confirmed step and resumes onto the pass screen, never onto secret content.

## Technical Context

**Language/Version**: Dart 3.5+ / Flutter stable (3.24+)

**Primary Dependencies**:
- State management: `flutter_riverpod` (explicit, testable, no BuildContext coupling for engine).
- Persistence: `isar_community` (drop-in maintained fork of Isar 3.1) behind a `MatchRepository`
  abstraction — see research.md R-002.
- Fonts: `google_fonts` (Cairo, IBM Plex Sans Arabic, IBM Plex Mono).
- Icons: `phosphor_flutter`.
- Audio: `just_audio` (narration played only while phone is on the table).
- i18n: `flutter_localizations` + `intl` (ARB files, Arabic + English, RTL-first).
- Testing: `flutter_test` golden tests via `alchemist` (deterministic, CI-safe goldens) +
  `mocktail`.

**Storage**: Local embedded NoSQL (Isar community fork). No cloud, no account, no network.

**Testing**: `flutter test` (unit for engine, widget + golden for UI, integration for flows).
Engine has 100% deterministic unit coverage; every night/vote screen has a 4-role golden.

**Target Platform**: Android 8+ and iOS 14+ phones (portrait, single shared device).

**Project Type**: Mobile application (Flutter single-project, layered).

**Performance Goals**: 60 fps on mid-tier phones; cold start ≤ 1.5s to Home; screen transitions
use fixed token durations (parity matters more than raw speed).

**Constraints**: Fully offline (no network permission in MVP); night-screen average luminance
deviation ≤ ±2%; night confirm dwell ≥ 8s; single widget tree per role; RTL-first; contrast
≥ 7:1 primary; touch targets ≥ 48dp; Reduce Motion honored.

**Scale/Scope**: 5–20 players per match; ~17 screens (S-01…S-17); 4 roles; local match history.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Plan compliance | Gate |
|---|-----------|-----------------|------|
| I | Zero Information Leakage | Engine is UI-agnostic; night UI is one widget tree; 8s dwell, luminance budget, and on-table-only audio are enforced in shared widgets + token layer. | ✅ PASS |
| II | Structural Symmetry / Single Layout Tree | `NightActionScreen` composes one tree; role varies only `questionText` + bound tiles + a reserved indicator slot. No `if(role)` alters structure. | ✅ PASS |
| III | Test-First + Golden Symmetry | TDD ordering baked into tasks; `alchemist` goldens per night/vote screen ×4 roles assert pixel-identical structure (T3); engine unit tests precede engine code. | ✅ PASS |
| IV | Design Token Discipline | `design_tokens.dart` as `ThemeExtension`s; lint/custom test forbids hardcoded colors/sizes in `lib/ui/**`. | ✅ PASS |
| V | Offline-First & Crash-Safe | `isar_community`, no network dep; `MatchRepository.persistStep()` after each confirm; resume resolver returns pass screen for current actor. | ✅ PASS |
| VI | Uniform Timing & Sensory Neutrality | Shared `DwellGate` (8s) + `PhaseTimer`; haptics centralized in one `Haptics` helper (select/confirm only); audio gated on the `PhoneLocation` state (`onTable`/`inHand`). | ✅ PASS |
| VII | Accessibility & i18n | ARB Arabic+English, `Directionality` RTL-first; semantic labels reviewed to not encode role; contrast tokens meet AA/AAA. | ✅ PASS |

**Result**: Initial Constitution Check **PASS** — no violations, Complexity Tracking not required.

*(Post-design re-check at end of Phase 1 — see "Post-Design Constitution Re-Check".)*

## Project Structure

### Documentation (this feature)

```text
specs/001-mafia-master/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── game-engine.contract.md      # Engine public API + invariants
│   ├── match-repository.contract.md # Persistence contract
│   └── leakage-invariants.contract.md # Machine-checkable anti-leakage assertions
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

A layered Flutter project. The engine is a pure-Dart package with **zero Flutter imports**, so
leakage logic is unit-testable in isolation and cannot accidentally depend on widgets.

```text
lib/
├── main.dart
├── app/                      # App shell, routing, localization wiring
│   ├── app.dart
│   ├── router.dart           # Route table; night routes disable back navigation
│   └── l10n/                 # ARB files (app_en.arb, app_ar.arb)
├── engine/                   # PURE DART — no flutter imports (enforced by test)
│   ├── models/               # Match, Player, Role, NightAction, Vote, ...
│   ├── state_machine.dart    # Phase FSM: setup→reveal→night→morning→day→vote→result
│   ├── resolver.dart         # Night resolution (Mafia target − Doctor protection), seeded RNG
│   ├── win_check.dart
│   ├── balance_guard.dart    # Role validity + recommendations/warnings
│   └── analytics_builder.dart# Post-game timeline/accuracy/map/achievements from event log
├── data/                     # Persistence layer
│   ├── match_repository.dart # Abstraction (interface)
│   ├── isar/                 # isar_community implementation + collection schemas
│   └── resume_resolver.dart  # Maps persisted state → safe resume target (pass screen)
├── ui/
│   ├── theme/
│   │   ├── design_tokens.dart# ThemeExtensions: MafiaColors, MafiaSpacing, MafiaMotion, ...
│   │   └── mafia_theme.dart  # Custom dark ColorScheme + text theme
│   ├── widgets/              # PrimaryButton, PlayerTile, PassScreen, PhaseTimer,
│   │   │                     #   DwellGate, RoleCard, SuspicionNote, VoteBar, ...
│   └── screens/              # S-01…S-17, one folder per phase
│       ├── setup/            # home, players, roles, settings
│       ├── distribution/     # pass, role reveal, pre-night lobby
│       ├── night/            # night action (single tree), post-action, morning
│       ├── day/              # discussion, voting, vote result
│       └── postgame/         # result, analytics (4 tabs), history
└── platform/
    ├── haptics.dart          # single source of haptic events
    ├── audio_director.dart   # narration; only fires when phone is on table
    └── reduce_motion.dart

test/
├── engine/                   # unit: state machine, resolver, win check, balance, analytics
├── widget/                   # widget behavior (dwell gate, pass gate, tile states)
├── golden/                   # symmetry goldens: night & vote screens × 4 roles (T3)
│   └── leakage/              # luminance-budget test (T4), tap/timing parity harness
└── integration/             # full-match flow, crash-resume (T7), wrong-pass (T6)
```

**Structure Decision**: Single Flutter project with a **pure-Dart `engine/` layer** isolated
from Flutter (enforced by a test that greps engine sources for `package:flutter`). This directly
serves Constitution Principles I–III: leakage-critical logic is deterministic and testable
without a widget tree, and the UI layer stays thin enough that golden symmetry tests are the
authoritative gate. Chosen over a multi-package monorepo (unnecessary ceremony for one app) and
over an MVC-in-widgets approach (would couple leakage logic to BuildContext, defeating T-tests).

## Complexity Tracking

> No Constitution violations — this section intentionally left empty.

## Post-Design Constitution Re-Check

After Phase 1 (data-model, contracts, quickstart) the design was re-evaluated:

- **Data model** stores secret results (Detective finding) only as immutable event-log entries
  consumed by `analytics_builder` **after match end**; no in-match read path exists → Principle I/§FR-028 preserved.
- **Engine contract** exposes only `PublicMatchView` to the UI (no role of other players), so the
  UI physically cannot render another player's secret → Principle I structurally enforced.
- **Leakage-invariants contract** enumerates machine-checkable assertions (single-tree, 8s dwell,
  luminance ±2%, no in-hand audio/haptic) that map 1:1 to golden/integration tests → Principle III.
- Seeded RNG in the resolver keeps golden/unit tests deterministic → Principle III testability.

**Result**: Post-Design Constitution Check **PASS**. No new violations introduced.
