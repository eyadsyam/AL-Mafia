# Claude continuation after Codex's phase 63 repair

User split the work to conserve Codex tokens: Codex fixed the blocking server/roster problem; Claude handles broader verification and remaining sections. Preserve all uncommitted changes. No commit, push, secret output, or `tool/build_web.ps1 -Publish`.

## Completed and deployed

- `20260914000600_kicked_seats.sql` APPLIED to `hezjbrnveajypfqmjfnh`.
- `20260914000700_public_room_active_count.sql` APPLIED.
- `start_match` ACTIVE v11, `open_phase` ACTIVE v12, both retain verify_jwt=true.
- The current server definitions were inspected before replacement.

The fix goes beyond excluding kicked rows from the count:
1. Admission capacity and dealing count only non-kicked rows. Replacement seats use max(existing seat)+1, retaining unique identities without collisions with the notification row. Do not assume the replacement seat equals the removed seat.
2. Atomic deal leaves the removed row in place (the removed client still needs its notification), gives it no role, and marks it not alive. It publishes `public_data.rosterSeats`, the fixed, PUBLIC list of actual dealt participants. No private roles are included.
3. `room_codec.dart` hides kicked rows in the lobby and uses rosterSeats once dealt. It still derives viewerKicked from the full incoming roster, so hiding a seat does not swallow the removal message. An in-match kicked player remains in the participant list. Older matches without rosterSeats retain their old roster.
4. Both the open_phase read and its transactional reveal gate ignore kicked rows; a removed player cannot hold the reveal gate.
5. Result standings exclude null-role rows, which were never dealt. Actual participants kicked after the deal retain their real role/history for results.
6. Public room browsing excludes kicked rows from the displayed population.
7. start_match now checks both database read errors instead of treating failed reads as empty successful results.

Important: `kick_member` behavior DURING a match was preserved. It bans/marks left but does not itself set alive=false. Do not claim it performs neutral elimination; assess kick vs remove_player semantics against the spec in section C. Pre-deal removed rows are marked not alive by apply_match_deal, not by a newly changed kick function.

## Evidence produced in this Codex session

- `build/phase63-codex-recovery.log`: real hosted recovery_match.py, **37 passed / 0 failed**. This is the formerly failing 31/37 scenario, now passing through start and night.
- Fixed an existing harness mistake: its mid-match kick now targets `players[4]['seat']`, not hardcoded 4 (which referred to the previously removed person). This strengthens the intended test rather than skipping it.
- `build/phase63-codex-targeted.log`: **174 passed**, test/transport + online_session_recovery_test.dart + online_entry_test.dart. Includes new four-case kicked_roster_test.dart, plus Claude's storage/discard/transport-cleanup tests.
- Initial narrower run also passed 16 tests in `build/phase63-focused.log`.
- Hosted rollback SQL PASS after applying: kicked_seats.sql, atomic_room_entry.sql, single_seat.sql, atomic_kick.sql, atomic_phase_open.sql. The final kicked_seats.sql includes public-list population and was rerun after the second migration.
- Migrations were first dry-run in rolled-back transactions with focused tests. An initial client-side SQL string-construction attempt had a syntax error and applied nothing; corrected dry run passed.
- No browser/device/human-audio result was produced in this session. No full suite/E2E/concurrency rerun, release build, or Web publication was performed; do those next.

## Exact next work

1. Run e2e_match.py (previous baseline 93), concurrency_match.py (46), full Flutter suite, analyze, and remaining SQL deal/rollback/anticheat tests. Resolve real failures; do not assume earlier results cover current changes.
2. Extend the post-kick full-match regression through night/vote/result to prove the pre-deal removed row does not appear in standings or influence victory, and that a kicked actual participant does remain in final history. The current recovery harness starts its kick scenario but its final result scenario uses a separate fresh room.
3. Add/execute repeated lobby kick/join cycles, join/start/kick races, and sparse-seat client flows. Confirm public count, lobby count, dealt count, living population and actual result participants agree.
4. Complete original handoff sections C–F and the original attachment error/voice/device matrices. Use the parallel visual/audio findings, if present in docs/CLAUDE-PARALLEL-REVIEW.md.
5. Rebuild and publish the client by a permitted route: deployed older Web clients do not yet consume rosterSeats, so current source fixes are not equivalent to production UI verification. Build a current APK too.

## Additional review finding, NOT fixed or runtime-tested here

`supabase/functions/room_settings/index.ts` reads status/settings without checking the read error, checks population, then updates rooms by id alone. A start or join can race those checks; it can mutate a started room's settings or apply a capacity below concurrently admitted population. Fix with a host/status/capacity check under the shared room lock and a transaction; keep roomConfiguration allowlisting. This is a specific section C atomicity gap, not a claim the entire server audit is complete.

Do not mark all of section B or the complete online release PASS merely because this blocking repair is done. Final section B closure still needs the broader requested checks. Update PROGRESS with actual evidence and retain all remaining limitations (real refresh/device/audio verification, no automatic Home resume prompt, build/publication status).
