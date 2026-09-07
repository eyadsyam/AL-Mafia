# Immediate execution handoff — GPT-5.6 Sol / High — 2026-09-06

User explicitly selected Sol with High reasoning to continue immediately and conserve tokens. Execute the current closure phase; do not produce another plan or spawn agents. Read this first, then relevant portions of CLOSURE-HANDOFF.md for earlier implementation context. This file supersedes that handoff's runtime/status claims. Follow the user's phase gate: record evidence in PROGRESS.md, report the gate and stop before another phase.

## Scope and safeguards

Full brief: C:/Users/LENOVO/.codex/attachments/ca22cdcd-ac8a-48d2-b31b-89dbc03f33e5/pasted-text.txt. Locate relevant headings before reading ranges. It covers product/gameplay/UX closure, real device verification, release APK/AAB, eight real store screenshots, existing website updates, reviewed commit and normal push. No feature creep. Voice stays; ~38.5 MiB accepted; TURN can remain documented.

Read docs/PROGRESS.md tail first, but its Phase 17 pass describes OLD source. Root 05-zero-leakage-spec.md wins privacy decisions. Read relevant sections before UI changes; engine remains pure, one engine/two transports. Never weaken role privacy, private-turn timing/tree/audio/luminance or tests to get green. Preserve Arabic typography and design tokens. Existing tree was heavily dirty before this task: inspect diff, never reset or blindly stage. Do not expose dart_defines.json, key.properties, keys or credentials.

## Already implemented — inspect only what you need to fix

- HoldPad cancels an owning finger leaving bounds; reveal uses shared 2-second token offline and online. Legacy identityHoldSeconds remains for save compatibility, hidden from settings.
- Pre-night screen removed; legacy engine phase auto-advances. Shared VictoryReveal precedes result text, plays animated WebP (still for reduced motion), begins duration after first frame. Recent lifecycle change pauses its Stopwatch/Timer in background; unverified.
- Social/coaching/filler hints removed; ~190 Arabic strings made Egyptian; settings grouped and meaningful narration labeled morning sound. English needs alignment. Removed blank takeYourTime and settingTieRuleHint keys from both ARBs; generated l10n.
- Startup loads persisted settings into initialMatchSettingsProvider; corrupt defaults safely fall back. Added test/data/startup_settings_test.dart for MemoryMatchStore/provider reuse, not actual device persistence proof.
- Doc14 part1 revised; remaining outdated acceptance references need review.
- Release Gradle no longer falls back to debug signing; preReleaseBuild checks key.properties. This new guard has not been tested; preserve the established signing key. tool/build_apk.ps1 may still have an obsolete fallback comment.

## Execute in this order

### 1. Restore reliable focused tests and online retry behavior

Latest closure-focus-tests.log: 51 passed, 4 failed. Three failures are ACTION_NOT_SAVED from OnlineTransport.submitVote at line736:
1. O7 / PHASE_CLOSED resyncs instead of raising.
2. O10 / the last snapshot stays and the banner goes up.
3. O10 / a reachable server puts the banner down again.

Root cause: _send returns null for BOTH a stale phase resync and unavailable acknowledgement. New submitNightAction/submitVote/submitOpeningAccusation throw ACTION_NOT_SAVED for every null. Distinguish a legitimate phase transition from a failed save. Keep stale-phase resync behavior, preserve snapshot/banner, expose failed save so UI can retry. Update outage tests only where the intentionally changed contract requires catching the failure; keep all their state assertions.

The new transport test `an unacknowledged night action remains retryable` reproduced the old bug red before patch. OnlineTableFlow now uses _attempt, _actionFailed, _attemptNumber, phase/day guards and a re-keyed night HoldPad. MatchController skipNightAction/submitVote/submitOpeningAccusation now await transport after immediate publish. Review ignored futures and error paths; add meaningful UI retry/duplicate-submission regression coverage for night and voting. BackendException alone is caught currently. actionNotSaved is localized.

Fourth failure: test/integration/match_flow_test.dart full widget match times out after TEN MINUTES. test/support/artwork.dart recently gained includeMotion and the full match calls loadArtwork(includeMotion:true). Suspect animated-image cache/first-frame waits under fake clock; not proven. Earlier late precacheImage/runAsync also hung. Isolate with bounded diagnostics, fix deterministic widget media readiness without weakening match assertions, verify real animation on device. Do not keep increasing timeout. Confirm pause/resume test in test/widget/day_screens_test.dart uses actual `متابعة` text (one replacement was corrected; other occurrences need context).

### 2. Finish actual offline device proof

integration_test/closure_offline_test.dart and test_driver/closure_driver.dart were added. Flutter integration_test dev dependency added. Driver saves screenshots to build/closure-device.

IMPORTANT latest evidence corrects the earlier assumption of build failure: closure-device-run.log shows build and device test DID RUN. Test failed at line60 looking for `حفظ` (zero widgets), after ~30 seconds. Locate that setup flow and use actual screen/action labels or stable keys. Do not diagnose this as infrastructure failure. Flutter drive automatically UNINSTALLED com.mafiamaster.mafia_master at teardown; avoid unintended data loss in future runs (inspect drive's supported retention option).

Test intends seven players, one mafia, doctor, detective, four citizens, two nights and a town win with screenshots. It currently mutates roleCounts AFTER entering Roles screen: local screen state may ignore it. Set before entry or use real role controls. Handle onboarding/group/resume state without deleting user data. Check hold timing, capture before auto-conceal, and living victim selection. Run full offline match with networking actually disabled, restore original connectivity afterward. Verify settings mute/timers survive kill/reopen and safe mid-night resume. Capture real role face/night/morning with trace/confrontation/result/analytics/settings as applicable; satisfy the brief's actual eight screenshot list including online lobby.

Device facts: MafiaMaster_Test previously booted on emulator-5556, memory2048; debug installed with --no-streaming -r and HOME screenshot visually inspected at build/closure-screen.jpg. No full match passed. Latest process listing had no dart/flutter/emulator processes; check adb devices. Pixel_9_Pro_2 was storage-starved; don't wipe it. C now has58.4GB free and D22.8GB: old disk-relocation plan is obsolete. Put TEMP/TMP in build/closure-temp per process if useful. Downscale screenshots to420px before viewing; preserve originals for delivery.

### 3. Complete online and final product gates

Use existing Supabase and harnesses; project hezjbrnveajypfqmjfnh is healthy. Existing live Python e2e_match.py previously passed47/47 using five anonymous clients, but host migration was skipped without service key. This is NOT device evidence. Complete online match voice disabled, host force-quit mid-night, phase-boundary disconnect/reconnect, safe kill/reopen, action retry. Prefer existing harnesses/test clients over adding architecture. Voice must never block progression. No new MCP installation needed.

Finish concise AR/EN copy and doc14/legacy UI cleanup only where the brief requires it. Verify victory starts before winner text, privacy-safe fixed timing, reduced motion and background resume. Run focused checks after fixes; once green run one full suite/analyzer and existing purity/fuzz/security gates. Do not repeatedly rerun unrelated passing suites.

Then build final signed APK and AAB, verify certificates/permissions and actual artifact sizes. Generate the required store assets from current real captures, update existing website/privacy/beta/download links, review diff for secrets and unrelated changes, commit/push only authorized reviewed work. Read brief sections for exact release/site requirements before those actions. Never call the project ready while device/test gates fail.

## Evidence ledger (do not overclaim)

- OLD baseline:809 tests passed; OLD analyzer:0 errors/warnings,68 infos.
- Current full suite has NOT passed. closure-current-tests.log contains many copy failures; closure-fixed-tests.log reached107 pass1 fail then hung; closure-focus-tests.log ends51 pass4 fail.
- Earlier analyzer had3 unused imports fixed afterward; final analyzer outstanding.
- Earlier debug APK build succeeded (~225MB). Final releases not rebuilt after these edits.
- Real HOME visually inspected only. Driver ran but failed setup before match; no completed device gate.
- Live backend47/47 passed except skipped migration branch. Existing security advisor anonymous policy warnings expected; no new schema changes this task.
- No closure commit/push/site publication completed in this work.

## Runtime and efficiency

Repo D:/Flutter Data/Projects/AL Mafia. Flutter D:/Flutter Data/Futter/flutter/bin/flutter.bat. Android tools C:/Users/LENOVO/AppData/Local/Android/Sdk/{platform-tools/adb.exe,emulator/emulator.exe}. Bundled Python C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe (Pillow available).

Use rg before reads, ranges for large files, narrow log excerpts, independent checks batched. No full context rediscovery, no agents, no model switches. Use existing relevant skills/tools only. Report succinctly in Egyptian Arabic at phase gate with Built/Files/Verified/Gate/Open and append the same evidence to PROGRESS.md. Stop at that gate per user instructions; distinguish any unresolved external prerequisites precisely.
