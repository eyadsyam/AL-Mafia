I found no blockers in the three areas. There is one real defect worth fixing, one real race, and one test gap. This was read-only: I didn't run any tests, builds or devices, and I wrote no files, including `docs/CLAUDE-REVIEW-93.md`.

## Actual defects

**1. Medium — any mid-phase `room_state` push resets clock-skew correction**
- `lib/transport/supabase_backend.dart:418` sets `server_now` to the device clock (`DateTime.now()`) on every realtime row.
- `lib/transport/online_transport.dart:495` then recalculates `_skew` from that value, so it drops to about zero.
- **Scenario:** the device clock is 20s fast. The full read sets `_skew ≈ -20s`. Within the same phase, a speaker/floor/`openingSeat` change arrives as a `stateDelta`, and `_skew` becomes about 0. Until the next phase change, the countdown is 20s off, and `_armDeadlineAlarm`/`_driveDueAt` fire 20s early (the host's call is refused) or late (grace for guests is shifted).
- This predates the `withRoomFieldsFrom` fix.
- The tests miss it because `test/support/fake_backend.dart:115` forwards the real `serverNow`.
- **Minimum fix:** `if (!push.partial) _skew = …;` at line 495. Make the fake send `DateTime.now()` so a regression test can assert the countdown survives a delta.

**2. Low–medium (real race; how often it happens is unknown) — an older full read can overwrite a newer within-phase delta**
- `online_transport.dart:506-508` (`_publish` for same-phase deltas) versus `:541-548` (`_performResync` replaces `_state` wholesale).
- **Scenario:** a phase-change push starts `resync()`. Before `fetchRows` returns, a same-phase delta arrives (for example `activeSpeaker`/`openingSeat` set straight after the phase opens) and gets published. Then `fetchRows` returns data read *before* that update and puts the old speaker back. Nothing requests another read, so the UI stays stale until the next push.
- **Minimum fix:** in the same-phase branch, `if (_resyncInFlight != null) _resyncAgain = true;` before `_publish()`. The existing drain loop already re-reads.

## Your question 1 — ballot epoch: I agree the logic holds
- **Late reply across a phase or revote:** the reply is dropped because the captured `epoch` no longer matches `_ballotEpoch` (`:403`). Epoch is `(phaseNumber, round)`, so a same-day revote (same phase, round 2) changes it.
- **Epoch A → null → A (the same epoch coming back):** also safe. The transition sets `_ballotApplied = ++_ballotRequest` (`:369-370`), so every older request fails `request <= _ballotApplied`.
- **Starvation:** comparing against the last applied reply lets out-of-order older replies be dropped without hiding a newer reply that has already landed. The slow-network test (`open_ballot_epoch_test.dart:21-59`) exercises exactly 1→3→2.
- **Cleanup:** `dispose` cancels `_ballotPoll` (`:1221`) and `_controller.isClosed` blocks late replies (`:402`).
- **Reconnect:** `_degrade` leaves polling running, and swallowed failures are harmless.

**Test gap (actionable):** the revote/next-phase tests use `backend.setState` (a full push). Production revotes arrive as `pushStateDelta`, where `openVoting` only survives because of `withRoomFieldsFrom`. Add a `pushStateDelta(ballotState(round: 2))` variant so that dependency is pinned.

## Your question 2 — partial row / host and settings
With the merge in place, I see no path where a partial row erases host, settings, visibility or title:
- `withRoomFieldsFrom` always takes the `rooms` fields from the last full state (`online_backend.dart:164-177`).
- A partial push with no previous state triggers a resync (`:489`).
- Any `rooms` UPDATE triggers a resync (`supabase_backend.dart:437`).
- A phase change triggers a full read before publishing, so a partial row can't mix phase-private state (the own seat is only ever replaced by `fetchRows`).

The remaining issues on this path are defects 1 and 2.

## Your question 3 — onboarding: no defect found
- **Profile saved, terms fail:** saving the profile rebuilds `SetupRequired` as `termsOnly` under the same `screenKey`, so the state (ticks, `_failed`) is kept. That is tested at `first_run_test.dart:155-180`. The copy ("Before you continue") is neutral for a new player.
- **Preferences:** `reduceMotionPreferenceProvider.set` catches its own errors (`motion_preference.dart:27-38`), so preferences can't block the door.
- **Deep link and language switch:** both have dedicated tests (`:268`, `:309`).
- **Keyboard:** the hero hides while the keyboard is up (`:261-263`).
- **Reduced motion:** honours both the app preference and the OS setting (`:253-256`).

## Speculative improvements (not defects)
- **Ballot reads can pile up:** `Timer.periodic` starts a new read every 2s whatever is still in flight, so 10s latency means about 5 concurrent reads per client. You could skip a tick while two are pending; the applied-reply check means this won't bring back starvation.
- **Server-side revote race:** a read issued just after the server starts a revote, but before this client gets the push, is applied under the round-1 view. It is then cleared when the push arrives. Whether it shows anything depends on how the `ballots()` RLS filters rounds. Not a regression.
- **Back button after a failed terms save:** once the form narrows, `canPop` flips to true, so system back pops the route instead of going to step 2. That's acceptable since the profile is already saved, but it's worth confirming on a `/join/CODE` deep link.
