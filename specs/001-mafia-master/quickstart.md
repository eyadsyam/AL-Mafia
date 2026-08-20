# Quickstart & Validation Guide: Mafia Master

A run/validation guide that proves the feature works end-to-end. Implementation detail lives in
`tasks.md`; this file is how you *check* the build.

## Prerequisites

- Flutter stable (3.24+), Dart 3.5+ (`flutter --version`)
- A connected Android/iOS device or emulator (portrait phone)
- No network required (the app runs fully offline)

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Isar + l10n codegen
flutter gen-l10n                                            # ARB → localizations
```

## Run

```bash
flutter run                      # launch on the connected device
flutter run -d chrome            # NOT supported target for MVP (mobile only)
```

## Automated validation (the leakage gates)

Run these before considering any screen "done" — they encode acceptance tests T1–T7:

```bash
flutter test test/engine                         # deterministic engine logic
flutter test test/widget                          # dwell gate, pass gate, back lock, tiles
flutter test test/golden                          # symmetry goldens ×4 roles (T3) + luminance (T4)
flutter test test/integration                     # full match, crash-resume (T7), wrong-pass (T6)
flutter test test/engine/engine_purity_test.dart  # Principle II guardrail
flutter test test/widget/token_discipline_test.dart # Principle IV guardrail

# Regenerate goldens intentionally after an approved visual change:
flutter test --update-goldens test/golden
```

Expected: **all green.** A red symmetry or luminance test is a leakage regression and blocks merge.

## Manual end-to-end scenario (maps to User Story 1 + 2)

1. Home → **New Match**.
2. Add 7 names in seating order (US4). Verify: "Next" stays disabled below 5 names; a duplicate
   name auto-suffixes.
3. Roles screen shows a balanced suggestion; try setting Mafia = 4 → start is blocked (FR-004).
   Reset to the suggestion.
4. Settings → keep defaults → **Start Role Distribution**.
5. Pass-the-phone reveal: each player long-presses their name, long-presses to flip, reads role,
   long-presses "Got it". Verify: the "Got it" delay feels identical whether the role is Citizen
   or Mafia (US2 / L-04).
6. **Start Night 1.** Pass the phone in seating order. For each player verify the screen structure
   is identical; Confirm is locked for 8s (L-07); no sound/vibration while holding (L-10/L-11).
   - Detective: after confirm, a four-valued result shows once, then blackout. Reopen the app —
     the result is gone (L-14).
7. **Morning**: a victim name (or "someone was attacked but survived", or "everyone survived"),
   with **no role** shown (FR-014).
8. Discussion timer runs on the table; then **Voting** (secret, pass-the-phone). Verify you cannot
   vote for yourself (FR-018).
9. Vote result reveals the eliminated player and their role; who-voted-whom is NOT shown (FR-019).
10. Repeat until a win. **Result** screen names the winner + full role reveal.
11. **Analytics**: timeline, per-player suspicion accuracy with reasons, suspicion map,
    achievements; who-voted-whom now appears (US5 / FR-032).

## Crash-safe resume check (T7 / US3)

1. Start a night and hand the phone to player 3.
2. Force-quit the app (swipe away).
3. Relaunch. Verify: it offers Resume; resuming lands on the **PassScreen for player 3**, never on
   the night action content.

## Offline check (SC-011)

1. Enable Airplane mode.
2. Play a full match. Verify no functionality degrades and no network-permission prompt appears.

---

## Validation run — 2026-07-28 (T077)

Environment: Flutter 3.44.4 stable, Dart 3.10, Windows host.

### Automated gates — all green

| Suite | Tests | Result |
|---|---|---|
| `test/engine` | 50 | pass |
| `test/widget` | 71 | pass |
| `test/golden` | 38 | pass |
| `test/integration` | 59 | pass |
| `test/platform` | 17 | pass |
| **Total** | **235** | **pass** |

`flutter analyze` reports zero errors and zero warnings across `lib/` and `test/`.

Acceptance-test coverage: T1–T5 via `test/golden` + `test/widget` (symmetry, luminance, dwell and
pass gates, haptics and audio call sites); T6 via `integration/wrong_pass_test`; T7 via
`integration/crash_resume_test`.

### Manual end-to-end

Steps 1–11 are driven automatically by `integration/match_flow_test` (a full 7-player match played
through the widget tree, tap by tap) and `integration/setup_flow_test` (Home → Players → Roles →
Settings → distribution, including the "Next is disabled below 5 names" and duplicate-suffix
checks). The crash-safe resume check is `widget/resume_prompt_test`, which relaunches over a
persisted store and asserts the app lands on the pass gate rather than on night content.

**Not yet run on a physical device.** Everything above is host-side. A device pass is still needed
for: perceived brightness parity under real ambient light, haptic silence confirmed by touch, and
the airplane-mode play-through.

### Offline check

Verified statically by `platform/offline_and_manifest_test`: the release Android manifest declares
no `INTERNET` permission, no source file references a networking API, and no networking package is
a dependency. The on-device airplane-mode play-through remains outstanding.

### Known environment constraint

`path_provider_foundation` is pinned to 2.4.1 in `pubspec.yaml`. Newer versions pull in
`objective_c`, whose native-asset build hook fails on an SDK path containing a space — which this
machine has. The same constraint is why audio playback is currently stubbed behind `AudioDirector`.
Both are lifted by moving the Flutter SDK to a space-free path.

---

## Reference

- Engine API & invariants → `contracts/game-engine.contract.md`
- Persistence contract → `contracts/match-repository.contract.md`
- Leakage assertions ↔ tests → `contracts/leakage-invariants.contract.md`
- Entities & state machine → `data-model.md`
