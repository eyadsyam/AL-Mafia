# Parallel review — real browser, two clients, recovery (2026-09-14)

Run while Codex repaired the kicked-seat server path. Nothing shared was
edited during the review itself; the fixes recorded under "Acted on" were
made after Codex handed back (see `docs/PROGRESS.md`, PHASE 63).

## Method

- Bundle: `build/web` release built 2026-09-14 11:35 (predates section B's
  client changes: no "forget room" button, no storage note, no deep-link
  redirect). Served by a local static server with range support and the
  same SPA fallback the production host uses.
- Browser: real Chrome 2026 (`chrome.exe --headless=new`), one profile per
  client (separate user-data-dir, so no BroadcastChannel auth sharing),
  driven over CDP. Viewports 390×844 (mobile), 360×800, 844×390 (phone
  landscape), 768×1024, 1280×800, 1920×1080. Flutter semantics enabled for
  navigation; screenshots downscaled to ≤640 px in `build/review/`.
- Microphones: Chrome's fake device (`--use-fake-device-for-media-stream`).
  **Synthetic audio. No human listened. Audibility is NOT VERIFIED.**
- Server: the hosted project, through the deployed functions (rooms
  `JPNR8J`, `XGEZ72` created and left).

## 1. Intro video and screens

| Check | Result | Evidence |
|---|---|---|
| Intro decodes at first paint (readyState 4, 720×1280, 4 frames buffered) | PASS | harness log |
| Autoplay is blocked until a real gesture; a CDP mouse press on the player starts playback (86 frames at 3.2 s, 0 dropped) | PASS | `m-02-playing-390.jpg` |
| Playback survives resize through 360×800 → 768×1024 → 1280×800 → 1920×1080 → 844×390 → 390×844; the element stays in bounds, aspect 9:16 kept, 251 frames, 0 dropped | PASS | `m-03-video-*.jpg`, `m-03-strip.jpg` |
| Skip mid-video leaves the film and lands on «إزاي نلعب»; the `<video>` element is gone from the DOM afterwards | PASS | `m-04-after-skip.jpg` |
| Profile → Home → mode → online entry → create sheet → lobby at 390 wide: no clipping, no horizontal scroll (`scrollWidth` = viewport) | PASS | `m-05..m-13`, `m-strip2.jpg`, `m-strip3.jpg` |
| Lobby at 360×800 | PASS | `v2-08-lobby-360.jpg` |
| Public list refresh shows a room created by another client; joining from the list seats the guest | PASS | `v2-03-public-list-with-room.jpg`, `v2-04-lobby-guest.jpg` |
| Human audio/video sync of the intro | NOT VERIFIED | needs a person |
| Real mobile browsers (Android Chrome / iOS Safari), slow network, cache miss/hit, offline replay | NOT VERIFIED | not exercised in this pass |

### Defects found

**E-1 (high) — Web refresh on `/online/lobby` painted an empty lobby.**
Reload in the lobby kept the URL; the app booted with no session and the
`LobbyScreen` rendered on nothing: no code, 0/10 seats, «مستني المسؤول»
shown to the host itself, no way back except the leave icon. The resume
pointer was in `localStorage` and unused. No `join_room` call was made.
Repro: create a room at 390×844, press F5. Evidence:
`m-14-after-reload.jpg`, `m-15-after-reload-8s.jpg` (8 s later, unchanged),
`m-16-reload2.jpg`. `/match` has the same shape (an empty `MatchFlow` with a
close button). **Acted on:** `lib/app/router.dart` now redirects `/online/lobby`
without a session to `/online` (where Resume / Forget live) and `/match`
without a match to `/online` when a pointer exists, else Home;
`test/widget/deep_link_without_session_test.dart` (4 tests). Resume itself
works: from the entry screen «كمل» rejoined the room on the same seat
(`join_room` 200, `rejoined`), `m-17-entry-with-resume.jpg`,
`m-18-resumed-lobby.jpg`.

**E-2 (medium) — Lobby count includes a seat the lobby hides.** After the
guest's tab was closed, the host's lobby read «2 / 5 لاعبين» over a single
ring, and the public list said «2 لاعب»; the row had aged to `left` and was
still a seat at the door (capacity) for up to a day. Evidence:
`v1-07-guest-tab-closed.jpg`. **Acted on:** migration `lobby_departures`
(presence ageing gives a silent lobby seat up through `leave_room`, so the
seat frees, the count and the list agree; removed rows untouched).

**E-3 (medium) — Phone landscape lobby is unusable.** At 844×390 the seat
ring shrinks to ~10 px dots, names overlap, and the «N / M» line is gone.
Evidence: `v2-09-lobby-landscape-844x390.jpg`. **Acted on (phase 64):** the
wide council packed chairs across by width alone and stacked the rest, so a
~130px band took two rows sixteen pixels wide; `CouncilGeometry.layout` now
tries every row count and keeps the one that gives the largest chair
(`council_geometry.dart`, test `council_geometry_responsive_test.dart`
"a phone held sideways…").

**E-4 (medium) — Desktop entry screen has no column.** At 1280×800 the
title sits at the far right, the refresh icon at the far left, and «العب
أوفلاين» floats mid-screen; the lobby's bottom button spans 1240 px.
Evidence: `v1-01-entry-desktop.jpg`, `v1-05-lobby-desktop.jpg`. **Acted on
(phase 64):** the entry screen's scroll view and the lobby's code/start
column sit in the `maxContentWidth` reading column (480, the token every
other screen uses); the council band itself stays as wide as the room (doc
15's wide council).

**E-5 (low) — On-state switches have no visible thumb.** In the create
sheet the "on" switches (voice, mute at night, trace, confrontation,
whispers) render as a plain beige pill; only the "off" one shows a thumb.
The state is right (`aria-checked`), the affordance is weak. Evidence:
`m-strip3.jpg`. **Acted on (phase 64):** the panel painted the lit track
`accentGold` at the call site — the same colour the theme gives the lit
thumb; the override is gone and the theme's pressed-gold track shows the
thumb.

**E-6 (low) — Gender chips are 32×24 px** on the profile screen (below a
48 px target). Evidence: semantics dump, `m-07-profile-filled.jpg`. **Acted
on (phase 64):** `GenderPicker` marks are `spacing.xxl` (48) square.

**E-7 (info) — `join_chime.ogg` fails to load at startup in headless
Chrome** (`AudioPlayers Exception … DEMUXER_ERROR_COULD_NOT_OPEN`,
"NotSupportedError: The element has no supported sources"), every launch,
only that file; the same bytes decode fine through `decodeAudioData`
(0.417 s) and `canPlayType('audio/ogg; codecs=vorbis')` = "probably". All
16 assets are Ogg Vorbis. Likely the first `<audio>` element created before
any user activation in headless; needs a check in a headed browser. Not
fixed; not load-bearing (the chime is a courtesy). **Headed check (phase
64):** almafia.vercel.app opened in a headed Chrome through the extension —
no console error at launch, no `join_chime.ogg` request at all before the
lobby; the warm-up already tolerates a preload failure (`audio_backend.dart`
falls back to opening the cue on play). Lobby playback in a headed browser
NOT VERIFIED (would spend an anonymous sign-in the harnesses needed).

**E-8 (info) — One uncaught JS error** in the host page after the «مشاركة»
(share) tap in headless Chrome (`navigator.share` unavailable there);
minified frame `main.dart.js:3990`. Not reproduced elsewhere; needs a
headed check. **Acted on (phase 64):** the share button copies to the
clipboard (no `navigator.share`); `Clipboard.setData` throws in a browser
tab without the permission and the throw escaped the tap. `AppClipboard.copy`
now returns whether it landed and the lobby only announces «اتنسخ» when it
did.

Not a defect: every Supabase request appears twice in the CDP request log
because the service worker proxies fetches (page → SW → network); the
server saw one call each (`join_room` once per resume).

## 2. Voice between two clients

Two Chrome profiles in one lobby (`XGEZ72`), fake microphones, host at
1280×800, guest at 390×844, `RTCPeerConnection` and `getUserMedia` hooked
before the app loaded.

| Check | Result | Evidence |
|---|---|---|
| Mic permission: `getUserMedia` resolves with one live audio track on both clients; the lobby mic button reads «اقفل المايك» (open) | PASS (fake device) | harness log |
| Offer/answer/ICE: one peer connection per side, `connectionState` connected, `iceConnectionState` connected, `signalingState` stable | PASS | log |
| Media flows both ways: host inbound 188 packets / 11.3 kB, outbound 188 / 8.0 kB; guest the mirror; 0 lost, 0 concealed; `totalAudioEnergy` rising on both | PASS (RTP level) | log |
| Selected candidate pair: host↔host UDP (same machine). TURN/relay path | NOT VERIFIED | no cross-network client |
| Mute: guest «اقفل المايك» → sender track `enabled=false`; host's inbound audio energy stops rising (1.83948 → 1.83953 over 8 s); button flips to «افتح المايك» | PASS | `v2-05-muted.jpg` |
| Unmute: energy rises again (+0.054 over 3 s) | PASS | log |
| Reconnect after reload: both clients reloaded and resumed; old PCs closed, new PCs connected, media flowing | PASS | log |
| Reconnect after tab close/reopen: guest killed, profile reopened at `/`, resumed via entry «كمل»; host's stale PC closed, fresh PC connected both ways | PASS | `v2-07-resumed-after-reopen.jpg` |
| **A hears B, B hears A** | **NOT VERIFIED** | synthetic tone, no listener |
| Night privacy (no audio from forbidden peers), day audibility, background/resume on a phone, Android↔Web | NOT VERIFIED | lobby only; no device, no person |
| Match completes with voice broken | covered by the hosted harnesses (no voice at all), not by this browser pass |

## 3. Onboarding, profile, list, settings, resume

- Onboarding: film → skip → rules → Home → profile prompt; the profile
  (name, gender) persisted to `localStorage` (`flutter.mafia.playerProfile.v1`)
  and survived reload and tab close/reopen (the reopened guest landed on Home
  with its name). PASS.
- Public list: empty state text, refresh icon, room row with count, join
  from row. PASS. Room title typed in the create sheet did not reach the
  request in the automated run (the row read «أوضة من غير اسم»); typing into
  the lobby settings panel did reach the field. Automation-typing artefact
  most likely (the profile name typed the same way was saved); NOT VERIFIED
  by hand.
- Create settings: visibility, capacity, voice, mute at night, speech /
  discussion durations, discussion mode, open voting, trace, confrontation,
  whispers — all present and toggling (semantics state changed). PASS.
- Resume after refresh: pointer written on entry (`roomId`, `code` only —
  no role, no token), offered on the entry screen, rejoin lands on the same
  seat. PASS. Refresh on the lobby URL itself: E-1 (fixed after handback).
- No launch-time online resume prompt on Home (known; Resume/Forget are two
  taps away at the online entry).

## Logs

`build/review/harness.log`, screenshots `build/review/*.jpg`; the CDP
harness lives in the session scratchpad (`harness.mjs`, `helpers.mjs`), not
in the repo.
