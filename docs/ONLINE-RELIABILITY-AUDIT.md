# Online reliability audit — attachment Phase 0, partial

Date: 2026-09-13. Current working tree preserved; HEAD 2cfc8cd. No source edits, commit, push, deployment, or live-backend mutation in this audit.

> **Reconciled 2026-09-14 (phase 62).** Every finding below is annotated with
> its current status. "Repaired" means: source changed, a hosted SQL/E2E
> test proves it, and the fix is deployed to `hezjbrnveajypfqmjfnh`. Evidence
> lives in `docs/PROGRESS.md` phases 60–62 and `build/phase6{0,1,2}-*.log`.

## Blocking privacy finding (source-proven; hosted runtime NOT VERIFIED)

`supabase/functions/resolve_night/index.ts:127-136` stores `resolvedNights[night].savedSeat` through `set_public_path`. This is the Doctor-protected player when a save succeeds, and therefore discloses a private night target.

`supabase/migrations/20260902000100_opening_phase.sql:60-80` implements that helper by writing `room_state.public_data`. `20260902000700_client_surface.sql:100-101` permits room members to read that row. `20260901000800_rls_policies.sql:215` grants SELECT; the later anon-role narrowing retains authenticated member access. `20260901000900_realtime_and_purge.sql:33` publishes room_state. `lib/transport/supabase_backend.dart:172` fetches the complete row. A UI that ignores the archived field does not protect it.

The history consumer at `supabase/functions/_shared/history.ts:110-116` uses this private field. The repair must move private resolution history to server-only storage and preserve the information engine's legitimate history inputs, not remove information-engine behavior or amend Doc 05. Previously persisted public copies must also be addressed through a reviewed migration. Hosted exposure has not been tested in this audit.

Stopped under the working agreement's zero-leakage stop-and-report rule. Canonical Doc 05 is at repository root (`05-zero-leakage-spec.md`), not docs/.

**Status: repaired (phase 60).** `night_resolution_private` holds the saved seat server-side; `record_night_resolution` writes it; `buildHistory` reads it; older public copies were sanitised by migration `private_night_history`. Hosted `supabase/tests/private_night_history.sql` passes and the E2E asserts "public night history never contains the saved target" and "a citizen cannot read private resolution history".

## Other concrete gaps found before the stop

- Room creation: create_room ignores the host-membership and room-state insert results and has no transaction across its three inserts. It can report success for an incomplete room.
  **Repaired (phase 60):** `create_room_atomic` — one transaction, rollback proven by `atomic_room_entry.sql`.
- Join/start race: join_room reads lobby state and inserts separately; apply_match_deal locks rooms but the join path has no shared status recheck under that lock. A concurrent join needs transaction-level validation; an FK lock alone does not revalidate lobby state after waiting.
  **Repaired (phase 60, extended phase 62):** `join_room_atomic` locks the room row and re-checks status/capacity under it; phase 62 adds the per-user advisory lock and `vacate_other_rooms` so a user holds one seat across rooms (`single_seat.sql`; `concurrency_match.py` "the wanderer holds exactly one seat").
- Phase resolution: resolve_night writes deaths, private/public archives and the next phase independently; its final update filters only room_id. resolve_vote performs side effects before a phase-filtered update and does not check affected row count. These are not atomic multi-driver transitions.
  **Repaired (phase 60, hardened phase 62):** `commit_resolution` commits everything under the room lock with phase/day/round CAS; phase 62 adds the move fingerprint and the `night_actions`/`votes` phase-guard triggers so a move landing between tally and commit is re-counted, never dropped or filed on a resolved phase (`action_epoch.sql`; `concurrency_match.py` "late move: acknowledged iff it is in the table for night 1").
  **Also repaired (phase 62):** `open_phase`, `advance_phase`, `generate_confrontation` and `submit_accusation` wrote payload before a phase-filtered update, or updated with no phase filter at all. All four now go through `commit_phase_open` / `commit_confrontation` / `commit_accusation` (`atomic_phase_open.sql`; concurrency harness: x5/x3/x2 simultaneous drivers, exactly one moves). `generate_confrontation` also required the host even after the morning expired, which stalled day ≥2 with a sleeping host; it now follows the same expiry rule as `open_phase`.
- Presence: OnlineTransport._onPush replaces the existing roster row without comparing last_seen timestamps. A stale event can overwrite newer presence.
  **Repaired (phase 60):** stale roster events are ignored by `last_seen` ordering (`test/transport/online_transport_test.dart`).
- Recovery: local pointer contains only roomId/code as required, but save errors are silently swallowed. Entry offers resume with no discard action found. History save and pointer clear are in the same try block, so history failure prevents clearing the completed-room pointer.
  **Partly repaired (phase 60):** history save and pointer clear are independent. **Still open:** a visible storage-failure warning and a discard action for an obsolete resume pointer (handoff section B).
- Resync coalescing and assured saw_role acknowledgement already exist. Their presence is source evidence, not a runtime pass for this audit.
  **Runtime-proven (phase 57 and E2E):** reveal gate, saw_role retry and expiry are exercised by `e2e_match.py` (93/93) and `online_reveal_recovery_test.dart`.

## Voice classification (provisional, inspection incomplete)

KEEP: MeteredVoiceLink with SignallingClient; VoiceController; custom WebRtcVoiceEngine; per-peer control; micPolicyFor; setAudiblePeers; envelope isolation. No migration to MeteredPeer.

KEEP pending deeper verification: BackendVoiceLink currently delegates floor control and provides Postgres signalling fallback. Do not remove this blindly as duplicate architecture.

MIGRATE / REPLACE / REMOVE: no change justified yet. Full voice, all-function and all-migration audits are unfinished because the privacy blocker was found first.

## Verification and continuation

Ran git status --short, git diff --stat, git diff -- lib supabase test tool (saved in audit-current.diff), git log -5 --oneline; inspected targeted source and policy ranges. The full diff has been captured but not fully reviewed. No tests or runtime checks run in this audit; previous Phase 58 results are not evidence for backend reliability.

Next: resolve the privacy blocker within the existing architecture, with a regression demonstrating that a non-Doctor cannot read the saved target through room_state or Realtime. Then complete Phase 0 inventory/audit and proceed through the attachment's persistence, atomicity, complete-flow, voice, responsive, avatar, edge-case, verification and release gates. Prior video runtime verification remains open.
