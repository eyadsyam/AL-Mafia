# Continuation prompt — Mafia Master (AL Mafia), handoff from Claude Code

Copy everything below this line into the new assistant session.

---

You are taking over an in-progress engineering session on the Flutter + Supabase project **Mafia Master** at `D:\Flutter Data\Projects\AL Mafia` (Windows 11, PowerShell primary, Git Bash available). The previous assistant (Claude Code) finished handoff section A and about 80% of section B. Your job is to finish section B, then C, D, E, F, exactly as specified, with real verification, and never commit or push.

**Communicate with the user in Egyptian Arabic.** Technical identifiers stay in English.

## 0. Read these first, in this order (read only what you need — grep, then read ranges)

1. `docs/PROGRESS.md` — read the **last two blocks** (`## PHASE 62` and anything after it). Do not read the whole file (2,900+ lines).
2. `docs/CLAUDE-CODE-HANDOFF.md` — the continuation map. Sections A–F under "Exact remaining implementation and verification work". Section A is DONE. Section B is IN PROGRESS.
3. `CLAUDE.md` and `AGENTS.md` at the repo root — the working agreement and phase protocol.
4. The original specification (phases 0–12 + the final report format with sections PASS / PARTIAL / FAIL / NOT VERIFIED):
   `C:\Users\LENOVO\.codex\attachments\f5cf6f17-f724-4104-8e9a-135db8fabf26\pasted-text.txt`
5. `docs/05-zero-leakage-spec.md` (root copy `05-zero-leakage-spec.md` is the binding one) before touching any UI or phase flow.

## 1. Non-negotiables (violating any of these is a failure)

- Work ONLY in the current working tree. It holds ~156 uncommitted modified/new files of real work. **Never** run `git reset`, `git checkout -- <file>`, `git restore`, `git clean`, `git stash`, broad deletions, `git commit`, or `git push`. Do not "tidy" the tree.
- One engine, two transports. Never create `OnlineGameEngine`. No `if (isOnline)` in widgets except voice controls and the connection banner.
- `lib/engine/**` is pure: no Flutter imports, no `DateTime.now()`, no unseeded `Random()`.
- Zero-leakage spec wins every argument. Never expose roles, private night results, or private targets to any client that should not see them. If a change would let a player infer another player's role — stop and report; never amend the spec.
- The app never invents a fact (no eligible trace/confrontation → output nothing).
- Voice is never load-bearing; an online match must complete with voice fully broken. Preserve the Metered `SignallingClient → VoiceLink → VoiceController → WebRtcVoiceEngine` architecture (`micPolicyFor`, `setAudiblePeers`).
- Design tokens only (`lib/ui/theme/design_tokens.dart` — note: this is the actual path, not `lib/core/theme/`). Arabic line-height 1.6, zero letter-spacing, text scale locked at 1.0.
- **Never print secret values or tokens** (the anon key in `dart_defines.json`, any service key, Metered credentials). Never rotate credentials. Never embed server secrets in client code. If you must show a config file, redact the key.
- Do not weaken tests to get green. Do not fabricate runtime evidence. Synthetic audio/RTP tests are never labelled "human verified".
- `tool/build_web.ps1 -Publish` is **FORBIDDEN** (it force-pushes gh-pages).
- No subagents, no narration ("Now I'll…"), grep before read, truncate command output (`| tail -40`).

## 2. Authorization already granted (do not re-ask)

- The user explicitly approved deploying Edge Function source and applying migrations to Supabase project **AL MAFIA**, ref `hezjbrnveajypfqmjfnh`, via the Supabase MCP tools (`execute_sql`, `apply_migration`, `deploy_edge_function`, `list_edge_functions`, `get_edge_function`, `list_migrations`). No Supabase CLI or `psql` is installed locally; the MCP is the only path to the hosted project.
- Deploy convention used so far: `deploy_edge_function` with files `functions/<fn>/index.ts` plus every `functions/_shared/*.ts` it imports, entrypoint `functions/<fn>/index.ts`. `verify_jwt: false` for `create_room`, `join_room`, `resolve_vote`, `resolve_night`, `generate_confrontation`; `true` for all others. Shared files were uploaded with doc comments stripped (code identical) — local copies keep comments.
- SQL tests in `supabase/tests/*.sql` are written as `begin; do $$ … $$; select 'PASS …'; rollback;` and are run on the hosted DB through `execute_sql` (they roll back).

## 3. Phase protocol (AGENTS.md) — mandatory

Do one phase → append to `docs/PROGRESS.md`:

```
## PHASE n — done | blocked
Built:      <one line>
Files:      <paths touched>
Verified:   <what was actually run, with numbers>
Gate:       PASS | FAIL
Open:       <anything unresolved>
```

→ report the same block in chat (Egyptian Arabic wrapper, block content as-is) → **STOP and wait for the user**. Never start the next phase unprompted. The user's "كمل" means "continue to the next section".

Phase numbering: section A = PHASE 62 (done). Section B = **PHASE 63** (in progress, not yet appended). Then C = 64, D = 65, E = 66, F = 67 (or as the user directs).

## 4. Exact tool commands that work on this machine

The Flutter SDK path contains a space; use these exact forms (PowerShell):

```powershell
$dart = 'D:\Flutter Data\Futter\flutter\bin\cache\dart-sdk\bin\dart.exe'
$ft   = 'D:\Flutter Data\Futter\flutter\bin\cache\flutter_tools.snapshot'
& $dart $ft test --no-pub                                   # full suite (~1000 tests)
& $dart $ft test --no-pub test/online test/widget           # targeted
& $dart $ft analyze --no-pub 2>&1 | Select-Object -Last 30
& $dart $ft gen-l10n                                        # NO --no-pub here; l10n.yaml governs
& $dart $ft build apk --release                             # section F
& $dart $ft build web --release                             # section F
```

Python harnesses (Python 3 is `python` in PATH). They need env vars taken from `dart_defines.json` (keys `SUPABASE_URL`, `SUPABASE_KEY` → export as `SUPABASE_URL` and `SUPABASE_ANON_KEY`). Never echo the key:

```powershell
$d = Get-Content dart_defines.json | ConvertFrom-Json
$env:SUPABASE_URL = $d.SUPABASE_URL; $env:SUPABASE_ANON_KEY = $d.SUPABASE_KEY
python supabase/tests/e2e_match.py          2>&1 | Tee-Object build/phaseNN-e2e.log        | Select-Object -Last 15
python supabase/tests/concurrency_match.py  2>&1 | Tee-Object build/phaseNN-concurrency.log| Select-Object -Last 15
python supabase/tests/recovery_match.py     2>&1 | Tee-Object build/phaseNN-recovery.log   | Select-Object -Last 15
```

Bash heredocs with embedded Python failed repeatedly on this machine (quote parsing). Write scripts to a file, then run them.

Emulator for visual checks: `Pixel 9 pro (2)` (`adb devices`). Downscale screenshots before viewing.

## 5. Current state (verified at handoff time)

### Done and recorded — PHASE 62 (section A)
See the `## PHASE 62` block in `docs/PROGRESS.md`. Hosted receipts: migrations `atomic_phase_open`, `action_epoch`, `single_seat`, `result_after_outcome` applied; functions resolve_night v11, resolve_vote v10, open_phase v11, advance_phase v8, generate_confrontation v9, submit_accusation v7, submit_night_action v9, submit_vote v8. Evidence: `build/phase62-{e2e,concurrency,flutter-tests,analyze}.log` (e2e 93/93, concurrency 46/46, Flutter 999 passed / 1 skipped / 0 failed, analyze 75 infos 0 errors 0 warnings).

### In progress — PHASE 63 (section B: persistence and recovery)

**Client work implemented and passing (do not redo):**

- `lib/data/online_session_store.dart`, `lib/data/online_match_history.dart`: `@visibleForTesting static Future<bool> Function(String key, String value)? writeOverride;` used by `save()`; a `false` write throws `StateError`.
- `lib/data/player_profile.dart`: `load()`, `introSeen`, `markIntroSeen` wrapped in try/catch (a refusing device returns null / false instead of crashing).
- `lib/ui/screens/online/online_session.dart`:
  - `OnlineSessionState.storageWarning` (bool, in `copyWith`), `dismissStorageWarning()`.
  - `join()` drops the stored resume pointer when the refusal code is in `{'ROOM_NOT_FOUND','ROOM_FINISHED','NOT_A_MEMBER','PHASE_CLOSED'}` **and** the stored code equals the code just tried; kept for `ROOM_FULL` or a different code.
  - `discardResume(OnlineRoomResume)`: calls `leave_room` (errors swallowed) then `OnlineSessionStore.clear()`.
  - `_teardown()` at the top of `_enter`: cancels the history subscription, drops lifecycle observer, disposes the previous transport, nulls the backend, resets state (keeps `busy` and `storageWarning`). Entering a second room disposes the first transport (test proves the old `watch()` stream completes).
  - Resume-pointer save failure → `storageWarning = true`, room still entered. History save failure → `saved = true` (idempotent), pointer still cleared, `storageWarning = true`.
  - `leave()` wraps `transport?.setPresence('left')` in try/catch; `leave()` with no room is a no-op.
  - `_enter` generic `catch (_)` → `busy: false, errorCode: 'BAD_RESPONSE'` (malformed `create_room` body no longer spins forever).
- `lib/ui/widgets/storage_warning_note.dart` (new): dismissable one-line note (icon `Icons.sd_storage_outlined`, text `l10n.onlineStorageWarning`). Imports `../theme/mafia_theme.dart` for `context.colors/spacing/typography`.
- `lib/ui/screens/online/online_entry_screen.dart`: keys `resumeButton('online_resume')`, `discardButton('online_discard_resume')`, `storageWarning('online_storage_warning')`; Resume + "Forget room" row; `_loadResume()` re-run after every `_enter`; error text + `StorageWarningNote` in a Column.
- `lib/ui/screens/online/lobby_screen.dart`: `LobbyScreen.storageWarning` key; note rendered under `ConnectionBanner` when `session.storageWarning`.
- `lib/ui/screens/online/online_table_flow.dart`: `viewerKicked` and `roomClosed` post-frame callbacks are `async`, `await ref.read(onlineSessionProvider.notifier).leave(); if (mounted) widget.onExit();` (a kicked player no longer keeps transport/voice/pointer).
- `lib/ui/screens/match_flow.dart`: result screen `onHome` awaits `leave()` then `widget.onExit()` (no-op offline).
- l10n: `onlineDiscardResume` ("انسى الأوضة" / "Forget room"), `onlineStorageWarning` (ar/en) added to `lib/app/l10n/app_ar.arb`, `app_en.arb`; `app_localizations*.dart` regenerated with `gen-l10n`.
- Tests: `test/online/online_session_recovery_test.dart` (new, 12 tests, `TestWidgetsFlutterBinding.ensureInitialized()`), `test/widget/online_entry_test.dart` (+3). Last targeted run of `test/online` + `test/widget` before the final malformed-response test was added: 321 passed, 0 failed. **Re-run them first thing** to confirm the last-added test also passes.

**Server work implemented and deployed (do not redo):**

- `supabase/migrations/20260914000500_atomic_kick.sql` — APPLIED on hosted. `kick_member(p_room uuid, p_host uuid, p_seat int) returns uuid`: locks the room by host (`NOT_HOST`), refuses empty seat / self (`BAD_REQUEST`), appends the ban idempotently, marks the row `status='left', connected=false, kicked=true`. Revoked from public/anon/authenticated, granted to service_role.
- `supabase/functions/kick_player/index.ts` — deployed **v6**, calls `db.rpc("kick_member")` and maps the two error messages.
- `supabase/functions/heartbeat/index.ts` — deployed **v8**; `claim_host/index.ts` — deployed **v7**: their update errors are now checked and thrown instead of silently returning success.
- `supabase/tests/atomic_kick.sql` — hosted PASS (rolled back). Note: array-membership checks inside `do $$` must be `exists(select 1 from rooms where id=r and a = any(banned_user_ids))`.
- `supabase/tests/recovery_match.py` (new; imports from `concurrency_match.py` / `e2e_match.py`): lobby refresh same seat; kick in lobby; freed seat joinable; mid-match refresh; leave/return mid-match; stranger refused; kick mid-match; `close_room` → `ROOM_FINISHED`; full match to result → `ROOM_FINISHED` with standings readable.

### THE OPEN BUG you must fix first (recovery harness is 31 passed / 6 failed — `build/phase63-recovery.log`)

`start_match` fails with **"roles must sum to the roster"** after a player is kicked **in the lobby**, and everything after it cascades (match never starts). Root cause: `kick_member` keeps the kicked `room_players` row (`kicked=true, status='left'`), but three places count every row:

1. `supabase/functions/start_match/index.ts` ~line 43: `db.from("room_players").select("user_id, seat").eq("room_id", roomId).order("seat")` — no `kicked` filter, and the read error is not checked (`players ?? []`).
2. `public.apply_match_deal(...)` (defined in `supabase/migrations/20260910000100_atomic_match_start.sql`, redefined in `20260910000300_reveal_deadline.sql` ~lines 48–58): `select count(*) … from room_players where room_id=…` and the deal `row_number() over (order by seat)` include the kicked row.
3. `public.join_room_atomic` (in `20260914000300_single_seat.sql` ~line 66): capacity `select count(*) into n from public.room_players where room_id=r.id` counts kicked rows, so a kicked seat still consumes capacity.

Also note `lib/transport/room_codec.dart` builds public `players` from every roster row (no kicked filter — a kicked lobby seat shows as a ghost), while the voice roster in `lib/transport/online_transport.dart` already filters `status != 'left' && !kicked`. `viewerKicked` (room_codec ~line 291) is derived from the viewer's own row having `kicked=true`, so the client's "you were removed" path **depends on the row existing** (a deleted row would only trigger a resync).

**Decision to make (pick one, state it, then do it):**

- **Option B (recommended by the previous assistant):** keep the row; new migration `supabase/migrations/20260914000600_kicked_seats.sql` that (a) replaces `apply_match_deal` to count and deal only `not kicked` rows (keep the existing signature and every other check exactly as they are — read the current definition from the hosted DB with `execute_sql` on `pg_get_functiondef` before rewriting), (b) replaces `join_room_atomic` so capacity counts `not kicked` rows only (and confirm the seat-number assignment does not collide with a kicked row's seat — either reuse the freed seat number or keep increasing; whichever you choose must be reflected in `recovery_match.py`'s "freed seat is open to somebody else" expectation), and optionally (c) makes the public roster in `room_codec.dart` skip kicked rows **for the lobby only** (never mid-match — a kicked mid-match seat is a dead seat that standings still list; check `05-zero-leakage-spec.md` and `docs/10-online-architecture.md` before deciding). Then edit `start_match/index.ts` to `.eq("kicked", false)` and to check the read error (throw / `fail("BAD_RESPONSE", …)` like the other rewritten functions do), redeploy `start_match` (verify_jwt true), and confirm with `list_edge_functions` that it is ACTIVE with a new version.
- **Option A:** in the lobby, delete the row (like `leave_room` does) and re-pack seats. Simpler server-side but breaks the client `viewerKicked` detection in the lobby unless you add a client path for "own row vanished + ban" → that path does not exist today; only choose this if you also implement and test that path.

Then:
1. Add `supabase/tests/kicked_seats.sql` (rollback test: kicked lobby row does not count toward roster size, deal, or capacity; kicked user still refused with `NOT_A_MEMBER`). Dry-run the migration + test inside one rolled-back transaction on the hosted DB first, then `apply_migration`, then re-run the test on its own.
2. Re-run `python supabase/tests/recovery_match.py` → target **37 passed / 0 failed** (save as `build/phase63-recovery.log`). Also re-run `e2e_match.py` (93/93) and `concurrency_match.py` (46/46) since `apply_match_deal`/`join_room_atomic` changed; save logs as `build/phase63-e2e.log`, `build/phase63-concurrency.log`.
3. Re-run all hosted SQL tests that touch these functions: `atomic_room_entry.sql`, `single_seat.sql`, `atomic_kick.sql`, `atomic_match_start`-related tests (grep `supabase/tests/*.sql` for `apply_match_deal` and `join_room_atomic`).
4. Flutter: `test/online test/widget` targeted, then the **full suite** (expect ≥ 1000 passed, 0 failed) → `build/phase63-flutter-tests.log`; `analyze` → `build/phase63-analyze.log` (0 errors, 0 warnings; infos ≈ 75 are pre-existing).
5. If `room_codec.dart` changed, extend `test/transport/` codec tests accordingly (kicked lobby row hidden, kicked mid-match row still present with `alive=false`/whatever the snapshot says — never invent).
6. Append `## PHASE 63 — done` to `docs/PROGRESS.md` in the exact format, with hosted deployment receipts (function names + versions, migration names), test numbers, and log paths. In `Open:` record at minimum: no launch-time online resume prompt on Home (Resume / Forget-room live on the online entry screen, two taps away); web refresh / tab-close / reopen was **not** verified in a real browser yet (belongs to section E/F browser pass); temporary-offline UX is the existing connection banner + resync (state what tests cover it or mark NOT VERIFIED).
7. Report the block in chat and STOP.

## 6. Remaining sections after B (each one only when the user says continue)

Follow `docs/CLAUDE-CODE-HANDOFF.md` sections C, D, E, F **verbatim**; the summary below is not a substitute for reading them.

- **C (PHASE 64) — complete online flow and error matrix.** Every flow in the original attachment, not just the happy path: entry/settings, public list refresh, private code join, capacity/invalid settings, lobby readiness, atomic deal, reveal acknowledgement retry, every night role, morning, information/confrontation, discussion/floor, voting/revote, verdict, result, history, leave, host migration, rematch (note: there is no server-side rematch; a rematch is a new room — recorded in PHASE 62 Open). Authorization, membership, liveness, role/host permissions, server deadlines, duplicate taps, request timeouts, stale Realtime ordering, coalesced resync, cross-room/cross-match events, closed-room behaviour. Existing harnesses to extend: `supabase/tests/e2e_match.py`, `concurrency_match.py`, `recovery_match.py`; Flutter fakes in `test/support/fake_backend.dart`, `test/support/stores.dart`. Every new client string goes through l10n (ar + en) and must not reveal secret state.
- **D (PHASE 65) — real voice verification.** Full attachment voice matrix: mic capture, sender attachment, offer/answer, early/late ICE, TURN config and observed candidate types, remote tracks, actual audibility, mute/unmute, reconnect, background/resume, browser gesture/autoplay. Two real clients A→B and B→A (Android emulator `Pixel 9 pro (2)` + Chrome, or two Chrome profiles). Day audibility and night privacy (no audio from forbidden peers — `micPolicyFor` / `setAudiblePeers`). Anything not observed by a human stays **NOT VERIFIED** — say so. Break voice entirely (e.g. bad TURN / no mic permission) and prove a match still finishes. Repair only demonstrated faults.
- **E (PHASE 66) — web/mobile visual and media.** Real mobile browsers, slow-network startup, cache hit/miss, offline replay, orientation changes, repeated resize, skip/navigation, resource cleanup, audio/video sync of the intro video (`assets/video/onboarding.mp4`). Review the full online screens at mobile and desktop widths: onboarding/profile, online entry/public list, create settings, lobby, reveal, table, vote, result. Avatar transparency (`assets/images/online/avatar_*.webp`) in the actual UI. This is where the web refresh / tab-close / reopen resume check from section B belongs. Chrome MCP / Playwright MCP tools may be available for browser checks; the emulator for Android. One downscaled screenshot per screen.
- **F (PHASE 67) — verification, builds, publication.** Dependency/localization checks, analyze, full Flutter suite, backend configuration/golden vectors, SQL transaction/privacy tests, full Supabase E2E after the last fix. Build one CURRENT universal release APK (the existing APK predates phase 61's font registration), verify package/signing/ABI contents. Build the final web release, verify assets/service-worker version, absence of the old beta site, publish through a **permitted** route only (never `tool/build_web.ps1 -Publish`; if no permitted route is documented, build and report NOT PUBLISHED and ask), then check the production root, bundle, favicon, manifest, and beta-path behaviour (a generic SPA fallback 200 is not a beta page). No commit, no push.

## 7. Final deliverable

When all sections are done (or the user asks for it), produce the final report in the **exact section format of the original attachment**: `PASS`, `PARTIAL`, `FAIL`, `NOT VERIFIED`, each item with the concrete evidence (log path, test counts, function versions, screenshot paths, which two-client combinations were actually observed). Nothing goes under PASS without evidence you produced or read in this session. Human audibility and real-device observations that you did not perform go under NOT VERIFIED.

## 8. Reference — key file map

- Client session: `lib/ui/screens/online/online_session.dart` (Riverpod `onlineSessionProvider`), transport `lib/transport/online_transport.dart`, `room_codec.dart`, `supabase_backend.dart`, `online_backend.dart` (`BackendException(code, message)`), `voice_link.dart`; voice `lib/platform/voice/*`.
- Persistence: `lib/data/online_session_store.dart` (pointer: roomId + code only), `online_match_history.dart` (summary: roomId, names, winner, days — never roles), `player_profile.dart`.
- Screens: `lib/ui/screens/online/{online_entry_screen,lobby_screen,online_table_flow}.dart`, `lib/ui/screens/match_flow.dart`, `lib/ui/screens/postgame/history_screen.dart`.
- Server: `supabase/functions/<fn>/index.ts` + `_shared/{api,phases,history,…}.ts`; migrations `supabase/migrations/2026091*.sql`; tests `supabase/tests/*.sql`, `*.py`.
- Audits/docs: `docs/ONLINE-RELIABILITY-AUDIT.md` (annotated with proven repairs), `docs/10-online-architecture.md`, `docs/11-edge-cases-and-tests.md`.
- Evidence dir: `build/phaseNN-*.log`.

Start now: re-run `test/online` + `test/widget`, confirm green, then fix the kicked-row bug as described in §5, verify, append PHASE 63, report, stop.
