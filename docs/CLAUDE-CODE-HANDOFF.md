# Claude Code — complete Mafia Master from the current working tree

You are taking over an existing Flutter + Supabase project. Continue the implementation, verification, and release work described below. Do not start over or replace the architecture. Communicate with the user in Egyptian Arabic and distinguish observed results from assumptions.

## Objective and scope

Make the existing game reliably playable from first launch and onboarding through profile setup, public/private room entry, a complete online match, result/history, and recovery after interruption. Improve web startup/rendering, responsive layouts, and intro video playback. Preserve all existing features, game rules, assets, and the custom voice architecture.

Project directory: `D:\Flutter Data\Projects\AL Mafia`.

Read `docs/PROGRESS.md` first, especially phases 57–61. Read the repository's actual `AGENTS.md` and follow its phase gates. The user wants completion, but do not bypass an applicable stop/report rule or claim unfinished work is release-ready.

Read the complete original user specification, in sections, from:
`C:\Users\LENOVO\.codex\attachments\f5cf6f17-f724-4104-8e9a-135db8fabf26\pasted-text.txt`

That attachment contains phases 0–12, the complete online/voice/error-case requirements, two-client validation, and the exact final report format. This handoff is a continuation map, not a replacement or a reduction of those requirements. If the attachment is unavailable, report the missing file; do not invent its contents.

Additional sources:
- `05-zero-leakage-spec.md` at the repository ROOT is binding. The `docs/05-zero-leakage-spec.md` path in the agreement is stale.
- `docs/09-information-engine.md`, `docs/10-online-architecture.md`, `docs/11-edge-cases-and-tests.md`, `docs/PROMPT-build-online-and-information-engine.md`, when relevant.
- `docs/ONLINE-RELIABILITY-AUDIT.md` is an OLD PARTIAL audit from phase 59. Several findings were repaired in phases 60–61; reconcile it with source, migrations, and progress rather than treating every item as still broken.
- `docs/ONLINE-WEB-RECOVERY-PLAN.md` and `audit-current.diff` are supporting context. The diff is a historical snapshot, not the current entire diff.

## Non-negotiable safeguards

- Work only in the current working tree. It contains extensive valuable uncommitted work from earlier sessions.
- No git reset, checkout-to-revert, git clean, broad deletion, architecture replacement, commit, or repository push. Preserve unrelated edits.
- Use one engine and two transports. Do not introduce OnlineGameEngine. Keep engine code pure and deterministic.
- Follow the zero-leakage spec. No role/private-target disclosure in public state, Realtime, logs, notifications, local persistence, or error bodies. If a new leakage path is found, follow the spec's stop/report rule; never rewrite the spec to excuse it.
- Preserve the information engine. Do not remove legitimate functionality as a privacy fix.
- Keep the existing Metered SignallingClient → VoiceLink → VoiceController → custom WebRtcVoiceEngine → per-peer RTCPeerConnection architecture, including micPolicyFor and setAudiblePeers. Do not migrate to MeteredPeer or introduce a second voice implementation.
- Voice failure must never block match progression. Preserve role-based audibility and existing fallback paths unless investigation proves a path should change.
- Use the project's design tokens, Arabic line height 1.6, zero letter spacing, and locked text scale 1.0.
- Never print secret values or tokens, rotate credentials, or embed server secrets in builds. Inspect secret names only when needed.
- Do not weaken tests, fabricate runtime evidence, or label synthetic audio as real human audio verification.

## Authorization and deployment target

The user EXPLICITLY approved uploading modified server function source to Supabase project `AL MAFIA`, project ref `hezjbrnveajypfqmjfnh`, after an earlier automated approval review requested destination-specific consent. This consent remains valid. The project was verified as the same project used by the application.

Do not request the same consent again unnecessarily. Verify the target before mutation. Apply DDL through migrations, pin search_path, grant narrowly, and deploy only necessary functions with the existing shared scaffolding. Verify ACTIVE status and versions after deployment. Never treat a local source file as deployed evidence.

The original request authorizes publishing the current Web release but forbids commits and repository code pushes. `tool/build_web.ps1 -Publish` force-pushes gh-pages: DO NOT use that option under this constraint. Inspect the configured hosting project and use an authorized direct artifact deployment route if available. Do not invent a domain or silently change hosting architecture. If an actual hosting credential/destination blocker remains, finish all independent work and report it precisely.

## Work already implemented — preserve and verify

1. Profiles after onboarding, public room browsing, pre-creation room settings, resume/history infrastructure, and much online/voice recovery already exist in the uncommitted tree. Audit rather than duplicate them. The user wants no conventional login screen and no repeated name/gender gate every time they enter online.
2. Reveal acknowledgement recovery was repaired earlier: a failed saw_role write must not dismiss the card, retry remains possible, and the server's reveal deadline prevents indefinite waiting. Preserve this behavior and its tests.
3. Video cache misses now stream rather than downloading the entire film before initialization. Cached blobs still support offline playback. Explicit LTR direction was added around the video.
4. Phase 60 moved Doctor saved-target history out of public room state into server-only night history, including compatibility sanitization and cleanup of older public copies. The information engine reads the private history.
5. Night/vote resolution and room create/join use transactional RPCs; stale resolution/revote drivers are rejected. Some other server transitions still need work, described below.
6. Stale roster events are ignored using last_seen ordering. Session lifecycle cleanup, result-only history saving, and clearing the completed-room pointer independently of history-save failure were improved.
7. Wide council geometry uses responsive seats/columns/rows, covered by bounds/overlap tests. Actual full online desktop layout review is not complete.
8. Existing male/female avatar WebPs were verified to have alpha transparency and reviewed visually without a baked checkerboard. Do not regenerate them without evidence of a remaining defect.
9. Android ABI restrictions were removed so the release APK includes arm64-v8a, armeabi-v7a, and x86_64.
10. Phase 61 fixed an observed blank startup while a Google-hosted default font timed out: pubspec.yaml registers the existing bundled IBM Plex Sans Arabic regular asset under the default Roboto family, and web/flutter_bootstrap.js sets local canvasKitBaseUrl. Existing explicitly styled fonts remain. Verify both the default-font alias and local renderer on final builds.
11. join_room maps only explicit allowlisted error codes to responses. Unknown errors go through shared generic handling. Its latest deployed version is v10.

## Known deployed backend state — recheck before further deployment

Applied migrations from this work:
- `20260913000100_private_night_history.sql`
- `20260913000200_atomic_resolution.sql`
- `20260913000300_atomic_room_entry.sql`
- `20260913000400_resolution_outcome.sql`

Recorded ACTIVE function versions: resolve_night v10, resolve_vote v9, generate_confrontation v8, create_room v9, join_room v10. Older progress also records earlier reveal/start deployments. Query current state; these are receipts, not a guarantee nobody has changed the project since.

Important: `_shared/api.ts` now logs a generic request failure instead of the raw exception. Only deployed consumers necessarily have that updated shared source. Audit which functions actually require redeployment; do not assume all functions automatically picked up a shared-file edit.

## Exact remaining implementation and verification work

### A. Finish the server atomicity and concurrency audit first

- `supabase/migrations/20260914000100_atomic_phase_open.sql` and the accompanying `supabase/functions/open_phase/index.ts` changes are LOCAL, UNTESTED, and NOT DEPLOYED. Review them before using them. The new commit_phase_open RPC locks room/state, compares phase/day/deadline, atomically applies public data and the phase transition, and finishes the room on result. The handler computes final standings without publishing them before the successful transition.
- Add meaningful transactional tests for stale callers, changed deadlines, double drivers, rollback, legal phase movement, and final standings visibility. Ensure standings cannot leak roles before result. Check grants and search_path. Then apply/deploy only after checks pass.
- Audit `advance_phase` and all other phase movers for writes before compare-and-set, unchecked write/read errors, and phase-independent updates. Cover same-phase deadline initialization, confront→discuss, discuss→vote, and any remaining branches.
- Night/vote results are computed outside their commit transaction. Prove that late real actions, defaults, simultaneous submission and resolution, and retries cannot change an already resolved decision or overwrite a player's real action. If not, fix the transaction/epoch boundary without changing the rules.
- In particular, audit default-action upserts in advance_phase, submit_night_action, submit_vote, submit_accusation, generate_confrontation, and start_match. An ignored database error must not become an empty successful result.
- Atomic join currently does not prove cross-room membership exclusion. Inspect the intended policy and make concurrent create/join/rejoin deterministic so a user cannot silently occupy conflicting active matches. Check left/kicked roster rows and capacity accounting, and same-user concurrent requests.
- Prove correct behavior using actual concurrent clients/requests, not only sequential stale-driver tests. Include host migration, host departure, last player leaving, disconnect during a write, late retries, and rematch epochs.

### B. Finish persistence and recovery

- Audit the attachment's persistence contract against actual database and client storage.
- Keep local resume data safe (room id/code and permitted metadata only). Do not persist another player's role, private information-engine facts, private night results, or live match snapshots containing secrets.
- Add/fix meaningful handling of storage failures; current entry/recovery paths still need visible recovery warnings and a way to discard an obsolete resume pointer.
- Verify result-only history saving when the first snapshot received is already result; check whether the transport stream replays the current snapshot. Preserve idempotent history saves and independent pointer cleanup.
- Verify refresh, tab close/reopen, app resume, expired/finished/deleted rooms, kick/ban, returning to the same seat, profile persistence, temporary offline state, and recovery from malformed responses. No silently lost player action.

### C. Complete every online flow and error matrix

- Work through ALL flows in the original attachment, not just a happy-path match: entry/settings, public list refresh, private code join, capacity/invalid settings, lobby readiness, atomic deal, reveal acknowledgement retry, every night role, morning, information/confrontation, discussion/floor, voting/revote, verdict, result, history, leave, host migration and rematch.
- Check authorization, membership, liveness, role/host permissions, server deadlines, duplicate taps, request timeouts, stale Realtime ordering, coalesced resync, cross-room/cross-match events, and closed-room behavior.
- Keep public UI feedback clear without revealing secret state or implementation details.

### D. Complete real voice verification and repair only demonstrated faults

- Follow the entire attachment voice matrix. Verify mic capture, audio sender attachment, offer/answer, early and late ICE, TURN configuration and observed candidate types, remote tracks, actual audibility, mute/unmute, reconnect, background/resume, and browser gesture/autoplay handling.
- Verify A→B and B→A with two actual clients, including the requested Android/Web combinations when devices are available. Confirm day audibility and night privacy, with no audio from forbidden peers.
- Synthetic RTP/media tests are useful but are not proof that humans hear each other. Report human audio NOT VERIFIED until actually observed.
- Disable/break voice and prove the entire match still finishes.

### E. Finish web/mobile visual and media checks

- The intro has been observed decoding/playing in fresh-profile headless Chrome after a real input gesture, with in-bounds aspect-correct video at 360×800, 390×844, 768×1024, 1280×800, and 1920×1080. Startup no longer requested external renderer/font assets in that run.
- Still verify actual mobile browsers, slow network startup, cache hit/miss, offline replay, orientation changes, repeated resize, skip/navigation, resource cleanup, and human audio/video synchronization. Bounds assertions do not prove all compositor behavior or audible synchronization.
- Review the actual full online screens at mobile and desktop widths: onboarding/profile, online entry/public list, create settings, lobby, reveal, table, vote and result. Geometry tests alone do not prove that the live council uses desktop space well.
- Verify avatar transparency in the actual UI. Preserve accessibility and tokens. Do not remove features to improve performance.

### F. Finish verification, current builds and publication

- Run the required dependency/localization checks, analyze, full Flutter suite, backend configuration/golden vectors, SQL transaction/privacy tests, and full Supabase E2E after final fixes. Do not lower assertions to get green output.
- Exercise the attachment's real two-client validation and document precisely which combinations were observed.
- Build one CURRENT universal release APK after all source/asset changes. Verify package/signing/ABI contents. The existing APK predates phase 61's font registration and is not the final current build.
- Build the final Web release, verify current assets/service-worker version and absence of an old beta site, publish through a permitted route, then check the actual production root, bundle, favicon, manifest, and beta-path behavior. Do not mistake a generic SPA fallback 200 for a real beta page.
- No commit or repository push. Do not delete artifacts without checking exact paths and need.

## Verification evidence already available

- `build/phase60-backend-final.log`: hosted match harness 93 passed / 0 failed. Admin/service-only host scenarios were NOT run in that invocation. Earlier runs had failures/timeouts; do not hide them or imply coverage the final run did not have.
- Hosted rollback tests passed for `supabase/tests/private_night_history.sql`, `atomic_resolution.sql`, and `atomic_room_entry.sql`.
- `supabase/tests/room_configuration.test.mjs` passed; `run_golden_vectors_node.mjs` passed 35 cross-language cases.
- `build/phase61-flutter-tests.log`: 991 passed, 1 skipped, 1 failed. Failure was the join_room error-surface source check. It was fixed, then `build/phase61-regression.log` reports all 16 affected server-surface/offline-web tests passing. The FULL suite has NOT been rerun after that last correction; do not label the earlier full run fully green.
- `build/phase61-analyze.log`: 73 infos, no errors or warnings. Do not claim zero diagnostics.
- `build/phase61-web-build.log`: release build passed.
- `build/phase61-web-final.log`: real Chrome local release smoke passed. `build/web-video-smoke.png` was visually reviewed; it shows the intro playing inside the portrait screen. Human synchronization not verified.
- `build/phase60-apk-build.log`: universal APK build passed, approximately 114.9 MB, at `build/app/outputs/flutter-apk/app-release.apk`; three ABI libflutter.so entries were checked. No actual Android app runtime was verified.

## Local tool/environment notes

- Shell: PowerShell. Quote paths with spaces carefully. Prefer rg, bounded reads, and concise logs. Do not expose environment or process command lines containing credentials.
- Flutter batch wrappers previously hung. This direct invocation worked:
  `& 'D:\Flutter Data\Futter\flutter\bin\cache\dart-sdk\bin\dart.exe' 'D:\Flutter Data\Futter\flutter\bin\cache\flutter_tools.snapshot' test --no-pub`
  The same runtime can invoke analyze/build/gen-l10n. Initial pub-get hung and was interrupted; earlier builds used installed dependencies with --no-pub. Resolve dependency verification for the final release rather than assuming pub-get succeeded.
- `tool/build_web.ps1` injects the local dart_defines.json and stamps sw.js. Build-only use is valid; its -Publish option is forbidden by the no-push requirement.
- Node: `D:\Programms\node.js\node.exe`; Python: `C:\Users\LENOVO\AppData\Local\Python\bin\python.exe`.
- Chrome: `C:\Program Files\Google\Chrome\Application\chrome.exe`. `tool/web_release_smoke.mjs` launches an isolated fresh profile and serves the release locally with media Range support. It does not test the published site or real mobile hardware.
- Android SDK: `C:\Users\LENOVO\AppData\Local\Android\Sdk`. Last inspection found no connected device and no usable listed AVD. The MafiaMaster_Test.avd directory had disk files but no config.ini/AVD registration. The requested Pixel 9 pro (2) was unavailable. Recheck availability; do not claim Android runtime evidence from the APK build.
- Paths and tool availability may change. Discover current capabilities and do not assume the previous assistant's MCP tools exist in Claude Code.

## Execution and handoff expectations

Start with a fresh status/progress check, reconcile the old audit, and make a concrete remaining-work checklist. Continue from the untested atomic phase transition work, preserving phase 61's verified startup fix. Work within phase gates in AGENTS.md, append actual Built/Files/Verified/Gate/Open evidence to docs/PROGRESS.md, and update the stale audit as findings are proven repaired.

Do not spend the task merely planning. Implement, test, and complete authorized work. If a device, human audio check, deployment credential, or explicit phase gate blocks part of the task, state the exact limitation without treating it as a reason to abandon unrelated executable work.

At completion, use the EXACT final report sections from the original attachment and mark each claim PASS / PARTIAL / FAIL / NOT VERIFIED with evidence. Include current artifact paths, deployment receipts, remaining blockers and risks. Only say the project is ready for release when the required gates have actually passed.
