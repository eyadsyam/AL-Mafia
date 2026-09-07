# Mafia Master — Claude Code handoff (2026-09-06, Cairo)

## Read this first

This file records the exact state at the moment the user stopped the Codex session and asked Claude Code to continue. It supersedes `docs/CLOSURE-HANDOFF.md` for current state. Keep every existing working-tree change. Do not reset, clean, reformat, or recreate the project.

The repository is deliberately very dirty: `git status --short` reported **266 entries** and `git diff --stat` reported **169 tracked files changed**. This includes substantial earlier product work, generated localization files, assets, tests, store material, and the changes below. There was no final commit or push in this session.

Read only the tail of `docs/PROGRESS.md`, then the relevant section of `docs/CLOSURE-EXECUTION-PLAN.md`. Follow `AGENTS.md`, especially zero role leakage and the rule that `lib/engine/**` stays pure.

## What the user asked for

The user wants the final beta, with these specific changes:

1. Put `assets/video/onboarding.mp4` inside a visible, slightly inset frame.
2. Make master mute and music settings actually stop their audio.
3. Replace the online onboarding deck with one screen that explains the complete online flow and the online/offline differences.
4. Play a real online match on an emulator or website and capture every online screen.
5. The Doctor must protect someone every night. Self-protection is available once, then remains visible, dimmed, locked, and unusable.
6. Intro/onboarding must finish at the Home page.
7. The final victory video must be the first thing that announces the winner. Normal night/day elimination information remains visible between rounds.
8. Every player name must have an explicit male/female icon choice, persisted and used for Arabic grammar.
9. Preserve the user's copy edits.
10. Update the public website and deliver a newly built APK. Never relabel or provide an old APK.

## Implemented in the working tree

### Intro and onboarding

- Removed the old multi-screen onboarding implementation.
- `lib/ui/screens/onboarding/onboarding_video_screen.dart` plays the supplied MP4 inside `PaperPanel`, inset from the screen, with `BoxFit.contain` so it is framed and uncropped.
- The video obeys master mute before playback.
- The intro goes to the improved How to Play screen, whose final button routes to `Routes.home` and is labelled `الرئيسية`.
- `lib/app/router.dart`, `lib/ui/screens/setup/how_to_play_screen.dart`, localization files, and onboarding tests were updated.
- Device evidence exists:
  - `build/closure-device/latest-onboarding.png`
  - `build/closure-device/latest-how-to-play.png`
  - `build/closure-device/latest-home.png`
- A fresh-device run showed intro → How to Play → Home. An earlier screenshot landed on Mode because an automated tap hit the Home CTA immediately after the route changed; later isolated steps confirmed Home itself.

### Audio

- `lib/platform/audio_director.dart`: setting master mute stops active cues and re-syncs score/music.
- `lib/platform/audio_backend.dart`: generation counters prevent an audio request that was pending during stop/mute from starting afterward.
- `lib/app/app.dart`: the running app listens to saved settings and synchronizes mute, music/score, and narration.
- `lib/ui/screens/setup/settings_screen.dart`: settings preview immediately; cancel restores the previous mix.
- `onboarding_video_screen.dart`: video volume follows master mute.
- Automated audio/settings/onboarding coverage passed. Physical listening on a device was not completed.

### Doctor

- `lib/engine/bullets.dart`: Doctor self-protection is enabled regardless of the retired settings switch.
- `lib/engine/legal_moves.dart`: the Doctor no longer gets an ordinary skip move.
- `lib/engine/match_engine.dart`: a legacy/expiry Doctor skip is converted to a deterministic legal protection target so the engine does not record a Doctor doing nothing.
- `lib/ui/widgets/night_grid.dart`: a spent special tile stays rendered, dimmed, locked, and inert.
- `lib/ui/screens/online/online_table_flow.dart`: Doctor confirmation is ignored until a target is selected; the Doctor's own seat is selectable only while self-protection is still available.
- `supabase/functions/submit_night_action/index.ts`: rejects Doctor skip and accepts one self-protect.
- `supabase/functions/advance_phase/index.ts`: Doctor expiry selects a deterministic living non-self target.

One UI detail still needs correction before release: in `lib/ui/screens/night/night_action_screen.dart` around line 130, the Doctor special tile currently uses the player's own name before use and `nightSpecialDoctor` after use:

```dart
label: spent ? l10n.nightSpecialDoctor : players[actorSeat].name,
```

The user's requested behavior is an explicit `احمي نفسك` option before and after use, with the spent state communicated by dimming and the lock. Make the label consistently `l10n.nightSpecialDoctor`, then run the night-grid/leakage tests. Do not change the tile count or geometry.

### Player gender and Arabic grammar

- Added `PlayerGender { unspecified, male, female }` in `lib/engine/models/player.dart`.
- Added gender to `Player`, `PublicPlayer`, setup draft, local match codec, saved player groups, room codec, online backend payloads, analytics data, and relevant fake backends.
- Added `lib/ui/widgets/gender_picker.dart` with simple male/female icon choices.
- Offline add-player rows and online entry both require/show the explicit choice.
- Analytics/timeline copy selects female Arabic verbs where implemented.
- Added `supabase/migrations/20260906000100_player_gender.sql` and updated `create_room` / `join_room` functions.

The production Supabase migration/functions were **not deployed**. An automatic approval review rejected applying the production schema and grants because the production target/access scope had not been explicitly approved. Do not claim online gender persistence is live. Ask the user for explicit production Supabase deployment approval before applying the migration/functions. The current deployed backend ignores extra gender input, and the client falls back to `unspecified` when reading old rows.

### Online onboarding

- `lib/ui/screens/online/online_intro.dart` is one scrollable screen rather than a deck.
- It shows the private-device flow, simultaneous night, optional voice, private messages, eliminated-player behavior, victory rule, and how these differ from offline play.
- Device evidence:
  - `build/closure-device/online-01-guide.png`
  - `build/closure-device/online-02-entry.png`
  - `build/closure-device/online-03-lobby-five.png`

### Victory reveal

- `lib/ui/widgets/victory_reveal.dart` overlays the winning side on the victory media itself.
- `test/integration/match_flow_test.dart` currently checks that winner copy is absent before `VictoryReveal`, then appears after the reveal duration.
- The intended ordering is: no spoiler → victory media names the winner → result screen details.
- This was covered in the focused suite, but the final result video was not captured on a device after the latest changes.

### Website source and build scripts

- `web/beta/index.html` was changed from the retired split/arm64 wording to a universal APK filename and all-ABI wording.
- `tool/build_web.ps1` was updated to use `app-release.apk` and was later guarded so an APK over 95 MB is not copied into the Pages commit.
- Flutter Web release built successfully into `build/web` with 105 files and current source.

The public website was **not updated**. `gh auth status` reported that the saved `eyadsyam` token is invalid and requires `gh auth login -h github.com`. Both publish attempts stalled and were stopped. The live site remains the prior deployment:

`https://eyadsyam.github.io/AL-Mafia/`

There is also a link mismatch to resolve before publishing: the current universal APK is about 147 MB, so `build_web.ps1` correctly excludes it from GitHub Pages' commit, while `web/beta/index.html` still links to that filename. Publishing in the current state would leave a missing APK link. Preferred fix: build a fresh arm64 split APK (about 38.5 MB), embed that in Pages, and describe it clearly as arm64; keep the universal APK as a local/direct artifact. An alternative is a GitHub Release asset, but that also needs restored GitHub authentication.

## Verification actually completed after the latest product changes

- Focused Flutter suite: **264 tests passed**, including engine, doc 11/doc 13 leakage checks, night prompt balance, online intro, onboarding, audio preview/backend, transport and schema migration coverage.
- Fuzz harness inside that run: **10,000 matches passed**.
- Analyzer ran and reported 83 info-level lint findings. No error or warning was seen, but run a final targeted/full analyzer after the remaining fixes; do not treat the info-lint exit code as a clean final gate without checking severity.
- Flutter Web release build completed successfully.
- A new signed universal release APK was built successfully.

An older full-suite gate in `docs/PROGRESS.md` recorded 809 tests passing before the newest Doctor/gender/online-guide changes. A full suite has **not** been run after all current changes. Do that before release.

## New APK already built in this session

This APK is newer than the previously delivered beta and contains the implemented Doctor, gender, online-guide, onboarding-frame, audio, and victory-reveal changes as they stood before the newly discovered online role-reveal fix:

- Path: `D:\Flutter Data\Projects\AL Mafia\build\share\Mafia-Master-Beta-1.0.0-Latest.apk`
- Built: 2026-09-06 21:54:45 Cairo
- Size: 154,502,407 bytes (147.3 MB)
- SHA-256: `077E64DEAF76B1B21DCC9DBFEA449DEF7038D884C0302EBE861CC06DA368C5C9`
- Signature: APK Signature Scheme v2 verified; one signer; RSA 4096 Mafia Master certificate.
- Certificate SHA-256: `082C07A46EF50B63F6F1ACF440806C16C614762D8DCE3B4E9BC3D41F07A19E11`

Do **not** ship this as the final APK yet. It predates the role-reveal fix described below and the final full-suite/device gate. Rebuild after fixing and use a new filename/hash/timestamp.

## Real online match attempt and the bug it found

A real production-backed room was created and populated with five separate authenticated players: one Android emulator plus four Python clients. The five-player lobby and microphone-denied path were exercised. The voice permission was deliberately denied to validate that voice is optional.

The match reached the server's `reveal` phase, but the Android UI showed the table backs and `مستني المسؤول` instead of the private role card. Inspection found a concrete client bug:

- `MatchController.revealCurrentRole()` exists in `lib/ui/screens/match_controller.dart`.
- No production call site invokes it.
- `OnlineTableFlow` only draws `_reveal(...)` when the phase is `GamePhase.distributing` **and** `state.reveal != null`.

Fix it in `lib/ui/screens/online/online_table_flow.dart`, inside `_syncPhase`, when entering `GamePhase.distributing`. Schedule the controller call after the frame to avoid updating Riverpod state during build, for example:

```dart
if (snapshot.phase == GamePhase.distributing &&
    previous != GamePhase.distributing) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) unawaited(_controller.revealCurrentRole());
  });
}
```

`dart:async` is already imported. Add a widget/transport regression test that proves the online role card appears and reveals only the viewer's own role. Then rebuild and rerun the real match.

The file `tool/online_demo_driver.py` was added as a temporary but useful real-server driver. It creates four anonymous clients, creates a room, maintains the Python host heartbeat in a daemon thread, waits for the phone as player five, starts a 1 Mafia / 1 Doctor / 1 Detective / 2 Citizen match, and accepts commands on stdin:

`night`, `morning`, `discussion`, `vote`, `result`, `state`, `quit`

It loads credentials only from environment variables and does not print keys. Start it by reading `dart_defines.json` into `SUPABASE_URL` and `SUPABASE_ANON_KEY`; never print the JSON values. The last temporary room code was `JYQJMG`, but the driver was stopped and all emulators were killed, so create a new room next time. The full online match was **not completed** and must not be claimed complete.

`build/closure-device/online-04-role-reveal.png` is misleadingly named: it captures the table backs that exposed the bug, not a successful role reveal. Keep it as defect evidence or rename it.

## Emulator state at stop

- Both emulators used by this session (`emulator-5556` and isolated `emulator-5558`) were shut down.
- The Python online demo driver was interrupted and stopped.
- A second isolated AVD was created at `build/closure-avd-fresh` with name `MafiaClosure_Fresh` because the first emulator kept restoring an old app session through Android backup.
- Automatic approval review rejected globally disabling Android Backup and also rejected wiping the app's backup. Those actions were not performed. The safer isolated AVD was used instead.
- On the isolated emulator, the session stopped on the online join-code form before entering `JYQJMG`.

## Exact remaining work, in order

1. Patch online role reveal as described and add a focused regression test.
2. Make the Doctor self-protect tile label consistently explicit (`احمي نفسك`) while preserving its constant geometry, dim state, and lock after use. Add/adjust the focused Doctor UI/engine test.
3. Add or confirm focused persistence tests for gender round-trip and old-data fallback to `unspecified`.
4. Run formatting only on touched Dart files, then targeted analyzer/tests.
5. Run the complete Flutter test suite and inspect the actual result. Run analyzer and distinguish errors/warnings from existing info lints.
6. Rebuild a new universal signed APK and a fresh arm64 split APK. Verify signatures, timestamps, size, and SHA-256. Never reuse the existing filename as proof of a new build without changing/checking its hash.
7. Install the rebuilt APK on `MafiaClosure_Fresh`, complete a real five-player online match using `tool/online_demo_driver.py`, deny microphone permission, and capture one screenshot per distinct screen: guide, entry/gender, lobby, private role reveal, night choice, Doctor once-only self-save if possible, morning, discussion, vote, elimination/reveal, victory video with winner text, and final result.
8. Update `web/beta/index.html` to the actual downloadable artifact strategy. Rebuild `build/web`.
9. Restore GitHub CLI authentication with `gh auth login -h github.com`, publish the current site, and verify the public beta URL and APK download from a separate HTTP client. Do not claim publication until the live content changes.
10. After explicit user approval for the production Supabase schema target/access, deploy `20260906000100_player_gender.sql` and the changed Edge Functions, then rerun the live gender and Doctor checks.
11. Append the actual final gate to `docs/PROGRESS.md`, including failures and remaining limitations. Then give the user the final public site URL, final APK path, SHA-256, and screenshot folder.

## Known non-blocking product limits from earlier phases

- Universal APK is large because `assets/video/onboarding.mp4` is about 51 MB and Flutter WebRTC adds about 11.7 MB per ABI. Earlier measured arm64 APK was about 38.5 MB; without voice the floor was about 26.7 MB. Voice vs. a 30 MB APK is a product choice.
- Voice has no TURN credentials and may fail behind symmetric NAT, but voice is designed to be optional and never load-bearing.
- The production site and APK download are currently stale/unpublished, despite local source/build changes.

## Files most relevant to continue

- `docs/PROGRESS.md`
- `docs/CLOSURE-EXECUTION-PLAN.md`
- `docs/FINAL-POLISH-PHASES.md`
- `lib/ui/screens/online/online_table_flow.dart`
- `lib/ui/screens/match_controller.dart`
- `lib/ui/screens/night/night_action_screen.dart`
- `lib/ui/widgets/night_grid.dart`
- `lib/ui/widgets/victory_reveal.dart`
- `lib/ui/screens/onboarding/onboarding_video_screen.dart`
- `lib/ui/screens/online/online_intro.dart`
- `lib/platform/audio_director.dart`
- `lib/platform/audio_backend.dart`
- `supabase/migrations/20260906000100_player_gender.sql`
- `tool/online_demo_driver.py`
- `tool/build_apk.ps1`
- `tool/build_web.ps1`
- `web/beta/index.html`

## Truthful status at handoff

- Requested code changes: mostly implemented, with two identified UI fixes remaining.
- Focused automated verification: passed (264 tests; 10,000-match fuzz included).
- Full latest suite: not run.
- Real online lobby: passed and screenshot captured.
- Real online full match: failed/incomplete due the discovered missing role-reveal call.
- Latest existing APK: newly built and signed, but not final because it predates that fix.
- Local web build: passed.
- Public website update: not published because GitHub authentication is invalid.
- Production gender schema/functions: not deployed; explicit approval still required.

