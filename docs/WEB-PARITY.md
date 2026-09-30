# Web = mobile parity (release 1.1)

Owner's rule: the web game is the mobile game. Same screens, features, narrator
voices, sounds, store items, invites, Casebook, Council. The only allowed gap is
native AdMob (the web has its own ad path, owned by the ads work).

This file lists every place the code behaves differently on the web, found by
searching `lib/` for `kIsWeb`, `dart:io`, `Platform.`, `defaultTargetPlatform`,
`dart.library.*` conditional imports and the plugin list in `pubspec.yaml`.

Status words: **fixed** (was a gap, now equal), **equal** (different code path,
same result), **allowed** (a real difference the browser or the owner's rule
requires), **owned elsewhere** (another work stream).

## Gaps found and fixed in this pass

| # | Difference | Status | What changed |
|---|---|---|---|
| 1 | The web ran on in-memory stores (`local_stores_web.dart` returned null). A reload or a closed tab lost the unfinished pass-and-play match (no resume prompt), saved groups, default match settings, seen hints and the tutorial flag. The phone keeps all of them in Isar. | fixed | `lib/data/prefs_stores.dart`: the same repositories with a write-through to `localStorage` (shared_preferences), history capped at 40 matches, every write best effort, corrupt storage opens as a fresh install. Tests: `test/data/prefs_stores_test.dart` (reload = opening a second set over the same preferences). Doc 05: nothing new is stored, `loadAnalytics` still refuses an unfinished match after a reload (tested). |
| 2 | The score loop is started on load. A browser blocks sound before a user gesture, so after a resumed match or a deep link the web had no score, and nothing retried. | fixed | `AudioBackend.unlock()` is offered on every tap (a `Listener` at the app root). It restarts the loop only on the web, only when the loop is blocked or not playing, so it never adds a seam. Test: `audio_backend_isolation_test.dart`. |
| 3 | Haptics were silent on the web (`HapticFeedback` does nothing in a browser). | fixed | `Haptics` uses `navigator.vibrate` (Android Chrome) for taps and for the long invite pattern; other browsers stay a quiet no-op. Role-blind, same two calls as before (L-10 guard test still green). Durations live in `InviteTokens`. |
| 4 | The Council invite «شارك» called the share plugin raw: a browser without the Web Share API opened a mail link, or threw unhandled. | fixed | It now goes through `InviteSharer` like the lobby (system sheet or Web Share from the tap, else copy, else an honest message). Test: `council_life_test.dart`. |
| 5 | The result-card share (PNG) had no catch: a browser that cannot share files surfaced an unhandled error. | fixed | The error is caught and the result sentence is copied, with a snackbar. |

## Differences that remain, by area

### Audio and narration

| Difference | Status | Notes |
|---|---|---|
| Web plays the `.mp3` twin of every `.ogg` (`webAudioAssetKey`, warmup reads only the copy each platform plays). | equal | Safari cannot decode Ogg. Every one of the 89 `.ogg` files (effects, Kratos, three narrator packs) has an `.mp3` twin; a test already checks both are registered. Online narration goes through the same `AudioDirector` path (`narrator_test`, `online_narrator_test`). |
| Brand motif is not played on load on the web (`app.dart`). | allowed | Browsers refuse it before a gesture. The score itself is now retried on the first tap (fix 2). |
| Onboarding film needs a tap to start on the web; it is streamed/cached through `video_download`. | allowed | Autoplay policy. A phone autoplays. |
| Kill-jumpscare and ambient loops use `video_player` and WebP on both. | equal | |

### Storage, identity, device

| Difference | Status | Notes |
|---|---|---|
| Isar on the phone, `localStorage` on the web. | fixed (1) | |
| Time zone: `Intl` browser time zone on the web, a platform channel on Android. | equal | `time_zone_web.dart`. |
| `launcher_label.dart` renames the Android launcher entry. | allowed | No launcher on the web. |
| `metrics.dart` frame metrics and the Play install referrer. | allowed | Android-only diagnostics. A web player's referral arrives through the `?ref=` room link and `/invite/:code`. |
| `tilt_source.dart`: sensor parallax. | allowed | Decorative. The web gets a level source (desktop browsers have no accelerometer, and iOS needs a permission prompt). |
| `in_app_review`. | allowed | A store prompt; `isAvailable()` is false in a browser and nothing shows. |

### Sharing, links, push

| Difference | Status | Notes |
|---|---|---|
| Invite share: Android chooser, web Web Share API, else copy. | equal | `InviteSharer`. |
| Push invites on the web: Firebase messaging through `web/firebase-messaging-sw.js` (own scope, separate from the offline worker), permission asked in context (`PushPrompt`), the token registered with `platform: 'web'`. | equal | Needs the web config in `web/firebase-config.js` (present) and the server secret. The notification click opens `/join/<CODE>`. A browser without notifications keeps the in-app invite banner. |
| Deep links `/join/<CODE>`, `/invite/<code>` (go_router path strategy; the host rewrites unknown paths to `index.html`). | owned elsewhere | Share-link origin, domain and deep-link aliases (for example `/room/<code>`) are being changed by the links work. This pass did not touch them. |
| `shareResultText` and the result-card footer name a fixed host. | owned elsewhere | Same work stream. |

### Payments, ads (intentional)

| Difference | Status | Notes |
|---|---|---|
| Google Play Billing (`play_billing*`, `purchase_store*`) exists only where `dart.library.io` is. The web sells the same packs by the manual-transfer path (`payment_capabilities.dart`, `coin_packs.dart`, `payment_proof.dart`). | allowed | Owner's payment decision. The same server price table backs both. Off limits for this pass. |
| Rewarded, interstitial, app-open and banner ads: stubs on the web (`rewarded_ads_stub`, `WaitingBanner` returns nothing). | allowed | The one gap the owner allows (native AdMob). The web's own ads are owned elsewhere. |
| `/admin` screens render only on the web (`web` flag). | allowed | Operator tools. |

### Voice

| Difference | Status | Notes |
|---|---|---|
| `WebRtcVoiceEngine` picks audio routing per platform; the web plays remote audio through `web_playout_browser.dart` with an explicit play button (autoplay policy). `VoiceControls` and `VoiceMicButton` have a web branch. | allowed | The one place the widget rules allow a platform `if`. Voice is never load-bearing: a match completes with voice fully broken. |

### Chrome around the page

| Difference | Status | Notes |
|---|---|---|
| Page transitions: one `NoirPageTransitionsBuilder` for every platform. | equal | |
| `usePathUrlStrategy()` on the web only. | equal | Gives `/join/CODE` real paths. |
| Web first-run warmup reads every asset over the network; a phone reads its own package. | equal | Gives up after 25 s and lets the table through. |
| Account sign-in: OAuth redirect is left to the Supabase default on the web and is the app scheme on Android. | equal | The sign-in work is owned elsewhere. |

## How to re-check

```
grep -rnE "kIsWeb|dart:io|Platform\.|defaultTargetPlatform|dart\.library" lib
flutter test test/data/prefs_stores_test.dart test/platform test/widget/council_life_test.dart
flutter build web --release --base-href /     # PowerShell; Git Bash rewrites the bare "/"
```

Not verified here: a real phone browser (autoplay unlock, vibration, Web Share),
because this machine has no device. Those three are written to degrade to silent
or to copy, and each has a unit test on the fallback.
