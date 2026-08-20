# Contract: Leakage Invariants (machine-checkable)

This is the executable face of Constitution Principle I and acceptance tests T1–T7. Every item
maps to an automated test. A screen that cannot satisfy its applicable rows MUST NOT merge.

## Structural symmetry (T3 — golden)

| ID | Assertion | Test |
|---|---|---|
| L-01 | Night action screen renders an identical widget tree for mafia/doctor/detective/citizen; only `questionText` and bound target data differ. | `golden/night_action_symmetry_test` renders ×4 roles, asserts identical structure/dimensions |
| L-02 | The Mafia teammate-vote indicator occupies a reserved slot that exists (empty) for all roles; tile dimensions are role-invariant. | golden diff of `PlayerTile` empty vs filled slot has identical bounds |
| L-03 | Voting screen is structurally identical for every voter. | `golden/voting_symmetry_test` |
| L-04 | Role reveal card back face and dismiss control geometry are identical across roles. | `golden/reveal_symmetry_test` |

## Luminance budget (T4)

| ID | Assertion | Test |
|---|---|---|
| L-05 | Average pixel luminance of each night screen is within ±2% of the night-screen mean. | `golden/leakage/luminance_budget_test` computes luminance from rendered images |
| L-06 | No warm/red color token is used on any night/in-hand screen. | `token usage` static test over `ui/screens/night/**` + pass/vote |

## Timing parity (T2)

| ID | Assertion | Test |
|---|---|---|
| L-07 | Confirm on any night screen is disabled until an 8.0s dwell elapses, identically per role. | `widget/dwell_gate_test` with a stubbed clock |
| L-08 | Second/terminal screens honor their fixed minimum duration for every role. | `widget/second_step_min_duration_test` |
| L-09 | Route transition durations are identical across roles (token-driven, no per-role override). | `widget/transition_parity_test` |

## Sensory neutrality (T5)

| ID | Assertion | Test |
|---|---|---|
| L-10 | No haptic call originates from any in-hand screen except the shared select/confirm helper. | `platform/haptics_call_site_test` (static scan) |
| L-11 | `AudioDirector` cannot emit while `PhoneLocation == inHand`; emitting throws in tests. | `platform/audio_gate_test` |

## Handoff & memory (T6, T7, FR-028)

| ID | Assertion | Test |
|---|---|---|
| L-12 | Reaching an in-hand phase always routes through `PassScreen`; the wrong-person path exposes zero game content. | `integration/wrong_pass_test` (T6) |
| L-13 | Force-quit mid-night then relaunch resumes on the PassScreen for `currentActorSeat`. | `integration/crash_resume_test` (T7) |
| L-14 | The Detective result is not retrievable from any query/screen after the turn ends (only via post-game analytics). | `engine/detective_result_ephemeral_test` |
| L-15 | In-night hardware/gesture back is suppressed; only "End match" exits. | `widget/night_back_lock_test` |

## Purity & discipline (Principles II & IV)

| ID | Assertion | Test |
|---|---|---|
| L-16 | `lib/engine/**` imports no `package:flutter` / `dart:ui`. | `engine_purity_test` |
| L-17 | `lib/ui/**` uses no hardcoded color/size/duration literals outside token files. | `token_discipline_test` |

> Observability note: because the app is offline with **no telemetry** (FR-029), these tests ARE
> the observability layer — leakage regressions are caught in CI, not in production logs.
