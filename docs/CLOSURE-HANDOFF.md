# Final closure handoff — 2026-09-05

> Superseded status: read CLOSURE-EXECUTION-PLAN.md first. User now selected GPT-5.6 Sol / High; it contains subsequent edits, exact failing tests and corrected device-run evidence.

Work is IN PROGRESS, not release ready. User requested the cheapest model to
continue immediately, then requested a status explanation before continuing.
That explanation has been delivered in Egyptian Arabic. Continue executing the
whole closure, not an audit or a plan. Do not ask permission for already-authorized
work. No subagents were used and no new plugins were installed.

## Authority and brief

- Full user brief: `C:/Users/LENOVO/.codex/attachments/ca22cdcd-ac8a-48d2-b31b-89dbc03f33e5/pasted-text.txt` (about 1740 physical lines).
- Read its numbered sections in ranges. It authorizes code/tests/docs/backend
  fixes, real emulator checks, APK/AAB builds, existing website updates, and a
  final reviewed commit to main plus normal push if authenticated.
- It supersedes older product rules: remove useless/social hints and coaching;
  Egyptian Arabic; remove pre-night screen/interaction; reveal exactly 2 seconds;
  victory media before winner text; voice stays, ~38.5 MiB accepted; TURN may remain
  a documented infrastructure limitation; complete 8 store screenshots and device gates.
- `AGENTS.md`, `docs/PROGRESS.md` read. Doc 05 is at repository ROOT:
  `05-zero-leakage-spec.md`, not docs/. Read sections 1–4 before UI changes.
- `docs/11-edge-cases-and-tests.md` sections 8–10 read. Preserve private-turn
  timing/tree/luminance/audio invariants and one engine/two transports.
- Progress ends at Phase 17. Older notes contain important emulator history at
  lines ~1101–1120 and current release gaps at ~2114 onward. Do not mistake old
  verification for current verification.

## Existing dirty tree

At entry the tree ALREADY had very extensive unstaged edits, untracked source,
tests, docs, optimized images/audio, release signing and store work. Do not reset
or overwrite these or assume they were all made in this turn. No commit made.
Do not blindly stage `.agents`, `.codex`, `.playwright-mcp`, temporary logs, or
private configuration. `dart_defines.json`, keystores and key.properties ignored.

## Changes actually made in this closure

1. `lib/ui/widgets/hold_pad.dart`: added owning-pointer movement check against
   pad bounds. Leaving cancels; coming back without a new down cannot resume.
   Test reproduced failure before fix. Existing up/cancel/second-pointer logic retained.
2. `lib/ui/theme/design_tokens.dart`: default holdToReveal changed 600ms -> 2s;
   added `MafiaTiming.victoryReveal` = 5s (existing victory WebPs have 60 frames / 12fps).
3. Both distribution RoleRevealScreen and OnlineTableFlow now use the timing
   token, instead of settings.identityHoldSeconds (previous real reveal default
   was FIVE seconds; 600ms was the other identity surfaces). Removed duration knob
   from SettingsScreen. Legacy model/codec identityHoldSeconds still exists with
   old defaults; reconcile/document it without breaking historical match decoding.
4. Deleted `lib/ui/screens/distribution/pre_night_lobby_screen.dart`. MatchFlow
   maps legacy GamePhase.preNightLobby to `_AutoAdvance(onReady: _beginNight)`.
   `_beginNight` directly opens night/actor and commits; no social narration or
   extra start button. Engine retains compatibility boundary; online server
   already drives reveal -> night. Verify automatic restore/progression.
5. Added `lib/ui/widgets/victory_reveal.dart`: shared media gate BEFORE the
   online/offline split in MatchFlow when phase=result. No winner text. Starts
   5s timer after image first frame, win cue once, dispose cancels timer, Reduce
   Motion uses still. Afterward `_victorySeen` lets existing result render.
   Removed `_Moment.nightFalls`, mafiaWins/townWins and their old announcements.
   Verify both winners/modes, rebuilds, lifecycle, and full media duration.
6. Lobby: removed headphones warning, ghost social rule and PlayHintLine plus
   unused hint imports/seed function. Some stale comments/static keys remain.
7. Settings: removed playHints/coaching switches, duration knob; changed section
   headings to title style and added row dividers. Narration label now means
   morning cue (there are no recorded narrator lines), removed placeholder subtitle.
   Removed result coaching call in MatchFlow, but ResultScreen and engine legacy
   coaching implementation still exist; remove genuinely dead baggage as warranted.
8. Removed strategy-tips panel from HowToPlayScreen, filler subtitle from ModeScreen.
9. Revised ~190 Arabic entries in app_ar.arb. Important: corrected Citizen night
   instructions; removed physical-seating/advice from onboarding; short actionable
   text. English only hold strings changed so far; align materially changed English
   rules/copy. Some unused hint strings/diacritics/stale docs remain.
   Several test literals still assume older Arabic! Fix expectations for deliberate
   copy changes, not valid gameplay assertions. Night luminance still must be measured.
10. Settings persisted to Isar already, but startup didn't rehydrate SetupDraft.
    Added `initialMatchSettingsProvider` in setup_draft.dart; notifier initializes
    from it. main.dart loads stores.matches.loadDefaultSettings before runApp and
    overrides provider. Last edit: Isar loadDefaultSettings wrapped in try/catch
    returning defaults for damaged/unreadable row. Need regression tests and format.

## Verification performed (do not overclaim)

- BEFORE changes: `flutter test` 809 passed, log `closure-baseline-tests.log`.
- Hold movement regression first FAILED as expected; fix applied.
- First targeted run after early edits: 35 pass/3 fail, log
  `closure-targeted-tests.log`. Failures were stale headphones expectation, an
  overly broad test replacement changing morning audio expectation, and victory
  image not decoded in fake test time. Corrections applied, NOT yet confirmed:
  * morning expected onTable restored;
  * headphones/ghost expected absent;
  * full widget match test precaches VictoryReveal Image in tester.runAsync,
    pumps first frame and full 5 seconds, checks no winner beforehand.
- Full later test attempt `closure-current-tests.log` reached ~260 passes in
  reveal goldens and then stopped progressing under disk/resource pressure.
  Interrupted its exec session 2713 with Ctrl-C. It is NOT a completed test run.
- Earlier analyzer: 71 issues = 68 existing info lints + 3 new unused imports.
  All 3 imports subsequently removed, not rerun. Log `closure-analyze.log`.
- Debug build succeeded, log `closure-debug-build.log`; it predates latest startup
  persistence and some copy changes. No updated app installed successfully yet.
- Existing live `supabase/tests/e2e_match.py`: **47 passed, 0 failed**, log
  `closure-live-backend.log`. Five anonymous clients, full match to town victory,
  action/role refusal, floor, stale action/ballot cases. It skips the optional host
  migration branch unless SERVICE_KEY set; do not claim real-device gates from it.

## Environment / immediate blocker to resolve

- Windows PowerShell; Flutter `D:/Flutter Data/Futter/flutter/bin/flutter.bat`.
- Android SDK `C:/Users/LENOVO/AppData/Local/Android/Sdk`.
- adb/emulator executables require `exec_command sandbox_permissions=require_escalated`.
  Approved calls worked. This is not an auto-review rejection.
- C: only ~0.4 GB free, D: ~21.9 GB. Flutter temp files default to C:. For future
  runs create a task-specific TEMP/TMP directory under `build/closure-temp` on D:
  and set those process environment variables. Do not repurpose HOME/CODEX_HOME.
- `Pixel_9_Pro_2` booted as emulator-5554; Android /data 5.8G, 333M free.
  Installing debug APK failed INSUFFICIENT_STORAGE. Do NOT wipe user data.
  Closed that emulator with adb emu kill after inspecting it; no data erased.
- Existing `MafiaMaster_Test` AVD has 16GB data and was previously documented for
  release testing; starting it with port5556 failed because HOST C: lacks space.
  Logs `build/closure-emulator.log`, `build/closure-emulator-error.log`.
- Its directory `C:/Users/LENOVO/.android/avd/MafiaMaster_Test.avd` contains:
  userdata-qemu.img.qcow2 ~2.91GB, cache.img.qcow2 .27GB, base userdata .01GB;
  also directories data/modem_simulator/snapshots/tmpAdbCmds. No copying done yet.
- Confirmed via emulator `-help-datadir`: `-datadir <dir>` selects directory for
  writable disk images. NEXT: safely COPY test AVD data to an ignored directory
  on D: (verify size and backing-image paths), run with data directory override,
  logs and hidden window. Do not move/delete original AVD, wipe anything, or delete
  unrelated user caches. May use explicit -data/-cache if documented by local help.
- Debug APK may have signing mismatch with old release installation. Prefer fresh
  isolated AVD COPY or signed release build; do not uninstall saved app data casually.
- For screenshots use adb PNG -> thumbnail <=420x420 with Pillow before view_image;
  save full real screenshots separately for store. No screenshots of updated app yet.
- Bundled Python:
  `C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`
  (Pillow available). Bundled Node analogous `dependencies/node/bin/node.exe`.

## Backend facts / available tools

- Supabase MCP already connected. Discover metadata through ALL_TOOLS as needed.
- AL MAFIA project id `hezjbrnveajypfqmjfnh`, ACTIVE_HEALTHY.
- get_advisors security: anonymous-access warnings for intended anonymous-player
  policies plus cron and leaked-password protection. No password auth in app.
- Actual SQL privilege check: authenticated cannot read room_players.role or
  rooms.match_seed; cron schema USAGE=false though cron.job SELECT=true.
- Cron active: archive-abandoned-rooms, keep-alive, purge-finished-rooms,
  purge-stale-anonymous-users, purge-stale-signals. Need verify final retention
  details/privacy and anti-cheat SQL against final state if backend changes made.
- No backend mutations deployed in this turn besides test matches/users through
  existing test harness. No service key printed or used.
- Live harness executed by loading public SUPABASE_URL/KEY from dart_defines.json
  into process env SUPABASE_URL/SUPABASE_ANON_KEY then running existing Python.
- SupabaseBackend uses Supabase.initialize and persistent auth; OnlineSession itself
  is in memory and currently has no saved room restore. Rejoin by code reuses same
  seat/auth. Investigate actual kill/reopen behavior and complete recovery as needed.

## Remaining work, ordered for continuation

1. Resolve environment safely; finish targeted regressions/format while emulator boots.
2. Add settings startup/corrupt preferences regressions. Audit all settings runtime
   consumers, save awaiting/persistence. Existing router writes defaults but does
   not await before navigating; avoid false claims about restart races.
3. Play and inspect REAL app. All normal bugs must be fixed, not listed as blockers.
   Review selection/night/vote/result/settings at 360px and large player counts.
4. Real offline full match without network; night kill/resume, every phase boundary;
   full online voice-disabled match, host force-stop migration, reconnect and process
   relaunch. A backend Python match is NOT device proof.
5. Finish Arabic human pass, stale English instructions, obsolete comments/docs,
   hints/coaching baggage. Do not blindly strip punctuation or modify valid privacy
   tests. Verify all leakage goldens after copy changes.
6. Update doc14 canonical flow and explicit old/new flow comparison; update timing
   and store instructions. `store/README.md` says 7/8 requested screenshots missing:
   role face, night grid, morning+trace, confrontation, result, analytics, online lobby.
   Existing 01–07 files are older different screens; do not count them as requested 8.
7. Final analyze/tests (baseline suite includes 10k fuzz), engine purity and TS/Dart
   golden harness. Capture evidence. Clean relevant warnings, no weakened tests.
8. Final signed release AAB + arm64 APK via `tool/build_apk.ps1 -Bundle/-Split`,
   public dart defines included, voice retained. Inspect signing cert/permissions/
   targetSDK from artifacts. Existing Gradle release fallback to DEBUG signing is
   dangerous; safe build should refuse missing key for a real release. Do not expose
   key.properties or generate a replacement key. Existing keys reportedly available.
9. Update store set 8/8, listing/privacy, existing GitHub Pages/beta mechanism at
   https://eyadsyam.github.io/AL-Mafia/ using existing workflow. Verify current Play
   target requirements from official sources when needed.
10. Review dirty tree and secrets, commit final completed source to main, normal
    push if authorized credentials work. No commit until stable. Exclude temp logs.
11. Append actual phase gate evidence to docs/PROGRESS.md. User brief section53
    requests final RELEASE READY or BLOCKED report with individual device gates,
    automated results, paths/sizes/signing, screenshot count, site, git and only
    truly external remaining actions. Remind keystore backup in TWO external places.

Do not say release ready while device gates remain unverified. Do not stop at a
plan. Send short meaningful updates during sustained work as required by system.
