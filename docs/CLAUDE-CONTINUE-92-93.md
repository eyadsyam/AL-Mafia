# Claude continuation — STOPPED at owner request (2026-09-23)

> LATEST: read docs/CLAUDE-FINAL-TAKEOVER.md FIRST. It supersedes the subsequent split-ownership note below and incorporates the completed independent review. Claude owns all remaining work; Codex has stopped.

> RESUMED: the owner subsequently requested shared work by Codex and Claude. Read `docs/PARALLEL-93.md` first for active ownership; do not execute this full-takeover handoff concurrently with Codex.

## 0. Authoritative workspace

Work only in:
`D:/Flutter Data/Projects/AL Mafia/.claude/worktrees/crash-fixes-and-testing-b6c2f5`

The main checkout is older. DO NOT start from main, discard changes, reset the worktree, overwrite earlier deliverables, or assume the 353 dirty/untracked entries are all Codex changes. Most are earlier Claude work. No commit, push, deployment, account changes, live migration, or purchase activation was performed by Codex in this turn.

Owner explicitly asked Codex to stop immediately and prepare this handoff. The running full test suite was interrupted accordingly. Continue implementation and verification from this state; do not claim completion from partial test output.

## 1. Read in this order (targeted ranges)

1. AGENTS.md and latest tail of docs/PROGRESS.md (91b, 92, 93).
2. This file.
3. docs/EXPERIENCE-92-93.md for implemented design and proposed gameplay discussion.
4. Root `05-zero-leakage-spec.md` BEFORE touching UI/phase flow. This worktree's file is at root, not docs. Read relevant sections of docs/10-online-architecture.md and docs/11-edge-cases-and-tests.md for transport/tests.
5. docs/CODEX-PUBLISH-HANDOFF.md §9 for the prior deployment/payment state, only when needed. 91b supersedes the older 89f claim that 1.1.0 deliverables contain the realtime bug.

Owner's latest scope: review online foundation, then a cohesive strong UI/UX campaign in the EXISTING charcoal/ivory/antique-gold/burgundy identity, multiple onboarding pages, original assets, restrained animations. Do not silently change game rules. Preserve all useful features. Owner will perform the final human match. No Docker required.

Agent preference: any further Codex subagent must be GPT-6 Luna HIGH. One art agent was already active before the preference arrived; it finished generation and was stopped. No further agent is needed for these assets. Avoid unnecessary parallel agents or full-suite reruns.

## 2. What Claude previously completed (reviewed, not newly claimed)

- Hosted contract migrations through 20260924000400_revote_candidates; all 38 functions deployed.
- coin_orders function exists but migration20260924000500_coin_orders NOT applied; real coin sales remain OFF/inert.
- Realtime bug fix: room_state pushes omit joined rooms metadata; RoomPush.stateDelta + RoomState.withRoomFieldsFrom preserve host/settings/code instead of blanking them. This prevents host controls disappearing while guests hold the floor and rules resetting midphase.
- Phase91b rebuilt 1.1.0+3 after that fix, historical full suite1120 passed/1skip, local SQL30/30.
- Historical hosted e2e93/93, recovery40/40, roster48/48, concurrency46/46, kick_flow61/61, kick_timing45/45. Do not relabel those as tests you reran.

## 3. What Codex changed now

### Online correctness — phase92

Found another asynchronous display bug: `_refreshBallots()` could complete after leaving voting, or after a same-day revote started, and reintroduce obsolete open votes.

`lib/transport/online_transport.dart` now:
- Tracks `_ballotEpoch` as (phaseNumber, ballotRound) only while open voting is active.
- Clears old ballots and restarts the timer/read when the epoch changes, including a same-phase revote.
- Tracks `_ballotRequest` so an obsolete reply cannot overwrite a newer request or another epoch.
- Does not alter vote rules/server state or reveal private votes.

`test/support/fake_backend.dart`: optional delayed `readBallots` hook.
`test/transport/open_ballot_epoch_test.dart`: two regression tests, including fresh revote reply arriving BEFORE the obsolete previous-round reply.

### Public UI / onboarding — phase93 (implementation present, final verification pending)

- `lib/ui/screens/onboarding/first_run_screen.dart`: FOUR chapters:
  1 language + welcome; 2 name/avatar/gender; 3 sound/music/reduced motion; 4 adult confirmation/explicit terms checkbox + privacy link.
- Sticky next/continue, progress bars with step semantics, system/UI back through steps, same controller preserves text, scrolling for short screens, decorative hero hidden while keyboard up, crossfade honors reduced-motion selection/platform setting.
- Existing compact terms-only upgrade gate preserved. Accept happens last. Failed-save recovery and original deep-link destination preserved. Terms do not recur on entering rooms after valid acceptance.
- `lib/ui/widgets/experience_surface.dart`: quiet public gradient and bounded decorative hero, fallback if artwork fails. New `ExperienceArt` paths.
- `lib/ui/theme/design_tokens.dart`: ExperienceTokens for image ratios/max heights/glow. No new random colors/durations outside theme.
- `lib/ui/screens/setup/mode_screen.dart`: online first/gold emphasis, both options still visible, scrollable centered layout instead of Spacers, council hero. Unconfigured online still explains why.
- `lib/ui/screens/online/online_entry_screen.dart`: quiet surface, new council hero only on empty browse; existing room refresh/filter/create/join/resume behavior preserved.
- `lib/ui/screens/online/lobby_screen.dart`: quiet public surface; existing seat/cosmetic logic intact.
- Public setup pages use same surface: home_screen, add_players_screen, group_picker_screen, how_to_play_screen, profile_screen, roles_screen, settings_screen.
- Home keeps interactive role cards, card sounds, falling icons, controls; removes underlying wallpaper/video clutter.
- how_to_play keeps `textured_surface.dart show PaperPanel` because that helper is still used.
- New AR/EN copy in lib/app/l10n/app_{ar,en}.arb + generated Dart: arrivalIdentityTitle/Hint, arrivalWelcomeHint, arrivalPactTitle, arrivalStep, arrivalSaving, councilInvitation.
- pubspec now **1.1.1+4**, assets/images/experience_v2 registered. NO 1.1.1 binaries have been built yet.
- Tests adapted: first_run_test.dart, profile_flow_test.dart, mode_screen_test.dart. Added portrait390×844/landscape740×360 in AR/EN, required identity, system-back retention, legal acceptance and completion.

### Original artwork — DONE, do not regenerate

Runtime, actual files already copied/encoded:
- assets/images/experience_v2/invitation.webp — 24934 bytes
- assets/images/experience_v2/council.webp — 47286 bytes
- assets/images/experience_v2/pact.webp — 33586 bytes
Total105806 bytes, 960×640.

Original1536×1024 PNGs: raw_assets/experience-v2/{invitation,council,pact}.png
Provenance: raw_assets/experience-v2/PROVENANCE.md
Generated with imagegen. No third-party pictures, text, role cues or weapons. Council shows equally anonymous masked adults. Keep originals and use lightweight WebP at runtime.

## 4. ACTUAL verification this turn

PASS:
- `build/phase92-core-tests.log`: 78/78, online_action_retry_test + online_transport_test, confirming Claude host/rules fix.
- `build/phase92-hosted-revote.log`: real hosted revote harness **38 passed/0failed**. Previous overly strict harness assertion is now resolved. Also tests concurrent claiming of a system waiting room. No schema/function deployment was needed.
- `build/phase92-review-tests.log`: **22 passed/0failed**, first_run + mode + new ballot epoch tests, including Arabic/English portrait/landscape and back/recovery.
- Earlier targeted run had first_run/profile_flow pass after adapting scroll behavior; do not quote its overall green because its old mode tap helper initially failed (later fixed with ensureVisible).

INCOMPLETE / MUST FINISH:
- Full suite `build/phase92-full-tests.log`: owner interrupted at **951 passed /1skipped /0failures so far**. Not a full pass. It was explicitly stopped with Ctrl+C; no active test/build expected.
- `build/phase92-analyze.log` is STALE: reported 3 missing PaperPanel references and unused Home asset import, since fixed; had88 diagnostics including existing infos. RERUN analyze before claiming clean.
- First full-suite attempt was stopped after missing PaperPanel import; fixed. Latest full suite reached951 without failures.
- No new emulator run, browser run, APK/AAB/web build or performance measurement has been done for1.1.1.
- No complete live human match/two-device voice/bad-network proof. Do not promise zero bugs.

## 5. Important screenshot detail (finish this before showing owner)

`test/widget/first_run_test.dart` supports `--dart-define=CAPTURE_ARRIVAL=true`.
It writes 4 actual widget-render PNGs into build/experience-review/.
The existing PNGs/“-small.jpg” are an EARLY CAPTURE with missing display/icon fonts (tofu squares). This is the capture harness, not verified production behavior. DO NOT send them as finished UI.

After that capture, Codex added Cairo, Bebas Neue and MaterialIcons font loading in the capture branch, plus disabled the test debug banner. That last capture-only change has NOT been rerun. Rerun capture, inspect fresh downscaled images, fix any actual layout issue. For production confidence open the actual built app as well.

Portrait/landscape tests without capture passed before this capture-font update. Font loading is conditional, so normal suite does not load screenshot fonts.

## 6. Finish in this order

A. Rerun formatter on touched Dart. Run analyze. Fix only actual introduced errors/warnings; existing informational lints are not release bugs. Check unused imports and comments after shared-surface migration.
B. Rerun focused UI/capture tests with font fix. Check four pages visually, both languages, keyboard/small-height behavior. Progress/next must remain usable. Inspect mode selection on a phone-sized viewport. Do not claim widget captures are device screenshots.
C. Rerun full Flutter suite once (concurrency2 for memory). If it fails fix the root cause, retain meaningful assertions. Regression tests must keep stale ballot responses from appearing after phase/round changes. Re-run appropriate tests only after changes.
D. Final visual polish only where evidence warrants it. Current campaign improves public surfaces and onboarding; it is not a complete in-match UI rewrite. Private role/turn shells must retain doc05 parity. Avoid adding wallpaper clutter or extra steps.
E. Build new signed1.1.1+4 online-configured APK and, if all release checks pass, AAB/web candidates into NEW build/deliverables-1.1.1/. Keep1.1.0 artifacts untouched. Use same signing key. Run existing R8 regression and16KB validators. Preserve existing real/test ad flags; do not enable payments/ads without account configuration.
F. Install new APK as upgrade on Pixel_9_Pro_2 (currently emulator-5554 online) and verify startup, public online browser, language/profile flow and mode back navigation; take downscaled screenshots. Do not clear existing emulator app data blindly. Use isolated test state or backup for fresh onboarding if needed.
G. Update PROGRESS phase93 with accurate verification, new hashes/artifact paths and limitations, plus CODEX-PUBLISH-HANDOFF cross-reference. No production publish/account mutation/coin migration in this handoff. Never use build_web.ps1 -Publish (force push).
H. Give owner the new testable APK and concise remaining human checks. Do not call it publish-ready while device or verification gates remain open.

No need to rerun every hosted harness just for cosmetic changes. Hosted38/38 was newly established; client guard was unit-tested. If server changes become necessary, first inspect the actual current deployment and existing authorization rather than assuming an old manifest.

## 7. Commands / safe credentials

PowerShell cwd MUST be the worktree above.
Flutter: `D:/Flutter Data/Futter/flutter/bin/flutter.bat`
Dart: `D:/Flutter Data/Futter/flutter/bin/dart.bat`
ADB: `C:/Users/LENOVO/AppData/Local/Android/Sdk/platform-tools/adb.exe`
ffmpeg: `C:/Users/LENOVO/AppData/Local/Microsoft/WinGet/Links/ffmpeg.exe`

- flutter test test/widget/first_run_test.dart test/widget/mode_screen_test.dart test/transport/open_ballot_epoch_test.dart --no-pub --dart-define=CAPTURE_ARRIVAL=true --reporter expanded
- flutter analyze --no-pub
- flutter test --no-pub --concurrency=2 --reporter expanded
- tool/build_apk.ps1 (APK); tool/build_apk.ps1 -Bundle (AAB). Put Flutter bin on process PATH for these scripts. Scripts enforce definitions and R8 checks.
- tool/build_web.ps1 build only. Never -Publish. Decide CoinSales build flag consistently with prior handoff; it does not enable server sales.
- python tool/check_android_native.py <new apk/aab>
- python tool/check_android_r8.py
- Docker-free SQL exists: node tool/test_sql_without_docker.mjs, dependencies already under build/sql-probe. SQL unchanged this turn; historical76 migrations/30 tests. Do not mistake PGlite for hosted concurrency/realtime validation.

Never print dart_defines.json values or admin credentials. That file's key is named SUPABASE_KEY (NOT SUPABASE_ANON_KEY); Python harness expects environment SUPABASE_ANON_KEY. When rerunning, read JSON privately and map keys in memory. Windows Python stdout requires UTF-8 (sys.stdout.reconfigure) for Arabic harness logs. Initial attempts failed before the successful38/38 run due key-name and output encoding, not server errors.

## 8. Owner's gameplay question — discuss after finishing, do not implement silently

Owner feels Among Us has compelling events between discussions while Mafia may lack that. Honest response: social deduction is the core, but players need personal experiences to discuss; more visual polish cannot alone create them. Existing whispers/accusations/night outcomes can be evaluated first in a real group. Proposed optional future “neighbourhood round” gives everyone a meaningful short choice creating truthful ambiguous events. Must be specified through the information engine, preserve role-indistinguishable timing/UI, and avoid invented clues or paid advantages. No such mechanic is shipped. See EXPERIENCE-92-93.md.
