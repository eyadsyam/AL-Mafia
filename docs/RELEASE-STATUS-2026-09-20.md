# Release status — 2026-09-20

## Delivered

- Hosted `atomic_whisper` migration applied; `send_whisper` ACTIVE v9.
  Public graph and private body commit together under the room lock. Failed
  body writes roll back the graph. Current phase/day, living membership,
  removed recipients, daily allowance and service-only execution are checked.
- Rollback SQL test passed before migration and after deployment.
- Latest release APK and AAB built with the existing release signing key.
  APK: `build/app/outputs/flutter-apk/app-release.apk` (~115 MiB).
  AAB: `build/app/outputs/bundle/release/app-release.aab` (~96.3 MiB).
  Android package `com.mafiamaster.mafia_master`, version 1.0.0 (1), min SDK 26,
  target SDK 36, APK arm64-v8a/armeabi-v7a/x86_64. Signer SHA-256 matches the
  established assetlinks certificate. APK installed and launched on
  Pixel_9_Pro_2; home screenshot inspected (`build/release-android-start.jpg`).
- Web release built in `build/web`; `sw.js` stamped `20260920-122823`.
  Artifact SHA-256 values are in `build/release-hashes.json`.

## Verification

| Check | Result |
|---|---|
| All 31 hosted function bundles versus local before whisper change | PASS |
| Flutter full suite | 1027 passed / 1 skipped / 0 failed |
| Last analyze, unchanged Flutter sources | 0 errors / 0 warnings / 76 infos |
| Hosted e2e | 93/93 |
| Hosted recovery | 40/40 |
| Hosted roster/settings | 48/48 |
| Hosted concurrency | 46/46 |
| Atomic whisper rollback/guards/grants | PASS |
| Chrome video playback and bounds at five viewports | PASS |
| Two isolated browser clients, hosted signalling, strict autoplay, synthetic mic, RTP and mute | PASS |
| Forced TURN-only media path, nominated relay pairs on BOTH clients | PASS |
| Real human audio quality / Android-to-web audio | NOT VERIFIED |
| Complete match through Android and browser UIs | User-owned; NOT VERIFIED |
| New production web publication | BLOCKED: Vercel returned Not authorized |

The kick-flow run reached the result but reported 58 passes / 2 failures: its
fixed doctor/detective voter list assumed the doctor survived the random deal.
The actual removal can eliminate the doctor when the host is a citizen; the
server correctly refused the dead voter's action and dead target. The harness
now obtains the actual living town seats and requires exactly two before
voting. Python compilation passed. That full scenario was NOT rerun after the
user took ownership of full-match testing. Do not label this rerun PASS.

Early relay-probe attempts did not prove TURN (first direct candidates, then
one missing connection-event diagnostic). The runner now enables its
document hook before navigation and captures nominated pair types during RTP
stats sampling. Final forced-relay run PASS with both endpoints `relay`.
Synthetic media proves transport; it does not prove human audibility.

## Remaining publication action

UPDATE — Phase 67: Vercel authentication restored. The new presentation build
was deployed READY on 2026-09-20 at
https://almafia-p4wlozuio-claudeacount124-9959s-projects.vercel.app and is served
by https://almafia.vercel.app. Production main.dart.js SHA-256 matches local
build/web. Root, sw.js, manifest, favicon, assetlinks and /online/lobby return
HTTP 200. The authentication blocker below is historical and resolved.
APK/AAB listed above predate Phase 67 presentation changes.

Refresh Vercel authentication, then deploy the already-built `build/web` using
the existing `almafia` project. Verify deployment READY, compare deployed
`main.dart.js` with the local hash, and verify root, deep links, manifest,
favicon and assetlinks. Never use `tool/build_web.ps1 -Publish`.
The failed deployment does not establish that production has the new web
bundle. No Play Store submission was performed; AAB is a prepared artifact.
No commit or push was made.

## User's manual acceptance

Play from room creation through final result, including a disconnected guest,
host recovery, one removed player, and a match with voice disabled. Listen
between Android and web: day speech, mute/unmute, night silence, background
and resume. Report any issue with the screen/phase and what happened.

## Separate presentation work

`docs/ONLINE-EXPERIENCE-NEXT.md` records the requested shared offline/online
videos, additional visual/audio assets, transitions and UX/UI improvements.
No new presentation assets are claimed as implemented in this release.
