<!--
SYNC IMPACT REPORT
==================
Version change: (unversioned template) → 1.0.0
Bump rationale: Initial ratification of the Mafia Master constitution. First concrete
  adoption, so MAJOR baseline 1.0.0 (no prior versioned governance to break).

Modified principles: none (all newly authored)
Added principles:
  I.   Zero Information Leakage (NON-NEGOTIABLE)
  II.  Structural Symmetry / Single Layout Tree
  III. Test-First with Golden Symmetry Tests (NON-NEGOTIABLE)
  IV.  Design Token Discipline
  V.   Offline-First & Crash-Safe State
  VI.  Uniform Timing & Sensory Neutrality
  VII. Accessibility & Internationalization
Added sections:
  - Technology & Platform Constraints
  - Development Workflow & Quality Gates
Removed sections: none

Templates requiring updates:
  ✅ .specify/templates/plan-template.md    (Constitution Check gate references these principles)
  ✅ .specify/templates/spec-template.md    (no mandatory-section change required; aligned)
  ✅ .specify/templates/tasks-template.md   (golden/leakage task categories aligned)
  ✅ README.md                              (design package already consistent; no change)

Follow-up TODOs: none — RATIFICATION_DATE set to first adoption date 2026-07-25.
-->

# Mafia Master Constitution

> Mafia Master is an offline, no-moderator board-game companion that runs a full match of
> Mafia on a single shared phone. Its entire reason to exist is that **no player can learn
> another player's secret role from the device**. Every rule below exists to protect that
> promise. This constitution supersedes convenience, velocity, and personal preference.

## Core Principles

### I. Zero Information Leakage (NON-NEGOTIABLE)

The device MUST NOT expose any signal — visual, temporal, acoustic, haptic, or structural —
that lets an observer distinguish one player's role from another's during play. The Ten
Binding Rules of `05-zero-leakage-spec.md` are law:

- Two steps per role at night; no role has one step or three.
- No sound and no haptic fires while an individual player holds the phone.
- All night screens share one Luminance Budget (±2% average brightness); warm/red colors
  are forbidden at night.
- Identical tap count and identical route transitions (same millisecond durations) for
  every role.
- Back navigation inside the night is disabled; the only exit is "End match".
- Zero memory: secret results (e.g. the Detective's finding) are shown once and are never
  stored or retrievable.

**Rationale**: Players watch each other. A single asymmetric pixel, tone, or millisecond is
a role tell. Leakage is not a bug severity — it is a product failure.

### II. Structural Symmetry / Single Layout Tree

Every role MUST render from the same widget tree with identical dimensions and positions.
Any `if (role == ...)` inside the widget layer MAY change **text content or bound data
only** — never the tree shape, never element dimensions, never presence/absence of a slot.
Role-specific content (e.g. the Mafia vote indicator) lives in a reserved slot that exists
for all roles and stays empty for the others.

**Rationale**: Symmetry is the mechanism that makes Principle I verifiable and enforceable.

### III. Test-First with Golden Symmetry Tests (NON-NEGOTIABLE)

TDD is mandatory: write the failing test → confirm it fails → implement → green → refactor.
In addition, every night/vote screen MUST ship golden (screenshot) tests rendered for all
four roles that assert **pixel-perfect structural and dimensional equality** (acceptance
tests T1–T7). A screen without passing golden symmetry tests MUST NOT merge.

**Rationale**: Anti-leakage guarantees that are not machine-verified will silently rot,
especially when cheaper models or future contributors touch the UI.

### IV. Design Token Discipline

All colors, spacing, typography, radii, and motion durations MUST come from a single
`design_tokens.dart` (surfaced as Material 3 `ThemeExtension`s). Hardcoded literal style
values in screens/widgets are forbidden. The theme is the custom dark `ColorScheme`
defined in `01-design-system.md`, never Material defaults.

**Rationale**: A single source of truth keeps the Luminance Budget provable and the visual
identity consistent, and it lets `/design-sync` drive tokens end-to-end.

### V. Offline-First & Crash-Safe State

The app MUST function with zero network access; no analytics, telemetry, or remote calls.
Full match state MUST persist locally (Isar) after every confirmed step. On relaunch or
interruption (crash, phone call) mid-night, the app MUST resume on the **pass screen** for
the current player and MUST NEVER restore directly into secret action content (test T7).

**Rationale**: The game is played face-to-face with no internet; a resume that reveals
action content is itself a leak.

### VI. Uniform Timing & Sensory Neutrality

The Confirm action on any night screen MUST NOT activate before an 8-second dwell; second
screens MUST NOT close before their fixed minimum — identically for every role. Haptics are
limited to a single light impact on selection/confirm, identical across roles. Narrator
audio plays only while the phone rests on the table, never in-hand. The OS "Reduce Motion"
setting MUST be respected.

**Rationale**: Timing and sensory differences are the easiest leaks to exploit and the
hardest to notice in review.

### VII. Accessibility & Internationalization

The app is RTL-first with full LTR support and ships in Arabic and English. Primary text
contrast MUST be ≥ 7:1 (secondary ≥ 4.5:1); all touch targets ≥ 48×48dp; Dynamic Type up
to 130% MUST NOT break layout; state MUST NEVER be conveyed by color alone (border + icon +
text). Accessibility semantics MUST NOT leak role information.

**Rationale**: The audience is adult, mixed-language, and seated in dim light; inclusive
design is a baseline, and accessibility affordances must obey Principle I like everything else.

## Technology & Platform Constraints

- **Platform**: Flutter (stable channel), Material 3, targeting Android and iOS phones.
- **State**: an explicit game-engine state machine, decoupled from the UI layer, unit-tested
  independently of widgets.
- **Persistence**: Isar (local, offline). No cloud, no account, no login.
- **Fonts**: Cairo + IBM Plex Sans Arabic + IBM Plex Mono via `google_fonts`.
- **Icons**: Phosphor Icons; role glyphs appear only in reveal/analytics surfaces.
- **Theme**: dark theme only in MVP.
- **No network permission** is requested by the MVP build.

## Development Workflow & Quality Gates

Before any feature or screen merges, it MUST pass the New-Feature Checklist of
`05-zero-leakage-spec.md` §6:

1. Does it add a step/screen for one role but not the others? → mirror or reject.
2. Does it emit sound/haptics while one player holds the phone? → reject.
3. Does it change brightness or introduce a warm color at night? → reject.
4. Does it alter the widget tree based on role? → reject.
5. Does it display historical secret-action info during play? → reject.
6. Does it pass acceptance tests T1–T7? → required.

Additional gates: engine logic covered by unit tests; every leakage-sensitive screen covered
by golden symmetry tests (Principle III); design values traced to tokens (Principle IV);
`speckit-analyze` consistency pass before implementation; `speckit-plan` Constitution Check
passes before Phase 0 and again after design.

## Governance

This constitution supersedes all other development practices for Mafia Master. Any code
review or plan review MUST verify compliance with Principles I–VII and the Quality Gates.
A feature that fails any anti-leakage item does not ship, regardless of deadline.

**Amendment procedure**: proposed changes are documented with rationale, version-bumped per
policy below, and propagated to dependent templates (`plan-template.md`, `spec-template.md`,
`tasks-template.md`) and guidance docs in the same change. Amendments that weaken an
anti-leakage guarantee require an explicit trade-off entry in `05-zero-leakage-spec.md` §5.

**Versioning policy** (semantic):
- MAJOR: backward-incompatible governance change or removal/redefinition of a principle.
- MINOR: a new principle/section or materially expanded guidance.
- PATCH: clarifications, wording, and non-semantic refinements.

**Compliance review**: `speckit-analyze` and code review are the enforcement points; the
golden symmetry test suite is the automated backstop.

**Version**: 1.0.0 | **Ratified**: 2026-07-25 | **Last Amended**: 2026-07-25
