# 1.1 launch wiring audit (cloud prompt 4)

Each feature was traced from its entry point, through the provider and the
Edge function or SQL, to the visible result.

Two scripts support the audit:

- `supabase/tests/capabilities_wiring.test.mjs` proves that each of the 34
  `economy_config.*_enabled` flags changes the capability envelope. Its
  all-on envelope is saved as `test/fixtures/capabilities_all_on.json`.
- `test/unit/feature_wiring_audit_test.dart` proves that the client turns
  every one of those keys on.

A quick scan also found that every client `backend.call` names an existing
function, and every Edge `rpc` names an existing SQL function.

## Findings

| ID | Severity | Feature | What was broken | Fix | Test |
|---|---|---|---|---|---|
| A1 | high | Referral reward | 20260930000400 pays the inviter's 100 at the friend's first match. However, the 10/season and 40/lifetime caps still counted only the later settlements, so throwaway one-match accounts could be paid 100 each without limit. | Migration `20260930000500_referral_caps.sql`: the caps now also count first-match payments. | `supabase/tests/economy_v3.sql`: the 11th payment is refused, the 10th is paid exactly once. The test fails without the migration. |
| A2 | high | Referral in room links | See the four problems listed below this table. | `lib/ui/economy/room_referral.dart`. Opening the link remembers the code. The first room entered redeems it without blocking. A code the server answered is forgotten; an unreachable one waits for the next room. The sheet reuses the lobby share and offer line. `RoomInvite.shareText` sits in one place. | `test/widget/online_entry_test.dart` (3 new), `test/widget/invite_share_test.dart` (host share carries `?ref=` and the offer), `test/widget/invites_push_test.dart`, `test/online/room_invite_test.dart` |
| A3 | medium | Founder badge | `founder_enabled` is on, but `founder_window_start` was never set: there is no operator function and no migration for it. As a result `fun_on('founder')` was false and nobody was ever granted the badge. | Migration `20260930000600_founder_window.sql`: `founder_window_open()` opens the window once, only when the flag is on and the start is null. | `supabase/tests/founder_window.sql` |
| A4 | medium | Reveal whispers (Doc 09 §7) | «اكشف محتوى الهمسات بعد المباراة» was an online-only switch on the pass-and-play settings screen, read by nothing: no screen and no server. | **Built.** The host sets it in the lobby room settings (default off, locked at the deal). Every seat sees it in the lobby and on the whisper composer. After the public end, every seated member can read the delivered whispers with their text from the result screen; voided whispers stay hidden, blocked senders are masked, and there is nothing before the end. The pass-and-play switch is gone. Migration `20260930000800_reveal_whispers.sql`, economy action `matchWhispers`, room setting `revealWhisperContent`. | `supabase/tests/reveal_whispers.sql`, `room_configuration.test.mjs`, `titles_partner.test.mjs`, `test/online/revealed_whispers_test.dart`, lobby notice in `invite_share_test.dart`, `settings_presets_test.dart` |
| A5 | medium | Narrator voice | A room or host narrator of «classic» (meaning "no pack") selected an empty bank, which silenced the default Kratos voice. | `AudioDirector.activeVoice` treats «classic» as the default voice. | `test/platform/narrator_test.dart` |
| A6 | low | Web and screenshots | ⏱ ▸ ◈ ← → ≈ are in none of the bundled fonts and drew as empty boxes wherever the system had no fallback. | They are replaced with an icon or covered punctuation. | `test/platform/glyph_coverage_test.dart` scans lib and both ARBs. |
| A7 | low | Low-end mode | `DeviceClass` read the raw dispatcher, so no test could reach it. | It reads the binding's view. | `test/platform/device_class_test.dart` |
| A8 | low | Play screenshots | The harness had three problems, listed below this table. | The harness is fixed. | `test/screenshots/store_listing_screenshots.dart` renders 8 PNGs at 1080×1920. |
| A9 | low | Partner | The picker was plain chips (`TODO(art)`). | It shows the Four Dossiers' gallery portraits. | `test/widget/titles_partner_test.dart` |
| A10 | low | Docs | STORE-TRUTH still said the narrator packs had no voice. | Updated. | none |
| A11 | info | Capabilities | All 34 flags reach the client. The only server-only flags are `transfer_enabled_*`. | none | `capabilities_wiring.test.mjs` + `feature_wiring_audit_test.dart` |

### A2: what was broken in referral links

- The redeem call held the player at the door while it ran.
- It went through an unwatched autoDispose provider.
- The code was lost when the first join was refused.
- The invite sheet's own share did the following:
  - it asked the invite provider even with referrals off;
  - it showed no "link copied" feedback;
  - it could promise +100/+50 with no code attached.

### A8: what was broken in the Play screenshot harness

- It used the wrong server phase name, so the online discussion showed «كود الأوضة».
- The witness shot was a bare panel instead of the dead player's view.
- Entrance animations were caught mid-way.

## Follow-up (“work on all of them”)

- **Season One (fixed).** Migration `20260930000700_season_rollover.sql`:
  `season_roll()` starts `season_01`, `season_02`, … back to back when a season
  ends. It runs hourly from pg_cron and on every Casebook open, copies the coin
  track (title levels become 50 coins), and never wakes a Casebook that was
  never started. Test: `supabase/tests/season_rollover.sql`.
- **mp3 copies (fixed).**
  - Gradle leaves `*.mp3` out of the APK. It is set reflectively, so an older
    plugin still builds; check it with the command in `docs/PUSH-SETUP.md`.
  - The first-run warmup reads only the copy each platform plays: ogg on
    phones, mp3 on the web. Before, both were read. Test:
    `warmup_gate_test.dart`.
- **The `adstest` build (fixed in code).** Gradle picks the Firebase app that
  matches the installed package, including `.adstest`. The owner still has to
  register that package in Firebase once; the steps are in `PUSH-SETUP.md`.
- **Reveal whispers (built).** See A4 above.
- **The APK (still not built).** This environment's network refuses
  `dl.google.com`, so the Android SDK cannot be installed. The local steps are
  in `docs/PUSH-SETUP.md`.

## Pass A — new player (web and Android)

Walked by reading the code paths a first-time player takes (first launch, name
and avatar, Home, pass-and-play setup, a match to the result, online create and
join by link and by code, invites, store, daily coffer, Council, Casebook,
settings), by running the release web build in a browser at 1440 wide with empty
storage, and by scanning the strings. Web parity has its own table in
`docs/WEB-PARITY.md`.

| ID | Severity | Where | What was wrong | Fix | Test |
|---|---|---|---|---|---|
| P1 | high | First launch, web and Android release builds | A new player who opened a room link (`/join/CODE`, an Android App Link, or a pasted URL) was sent to Home after the intro, and the room link was lost. `WarmupGate` returned its child bare and then a `Stack` the moment the first-launch preparation veil came up, so everything below it (resume gate, onboarding gate) was re-created. The onboarding gate ran again and wrapped its own `/onboarding?next=…` inside `next`, which `_safeReturn` then rejects. Seen live as `/onboarding?next=/onboarding?next=%2Fjoin%2FABC123`. Debug builds never show the veil (`warmupEnabledProvider` is release-only), so no test saw it. | `WarmupGate` always returns one `Stack`, so the table keeps its place; the onboarding gate also refuses to nest its own link. After the fix the same load gives `/onboarding?next=/join/ABC123`. | `warmup_gate_test.dart` counts table creations through a first launch (3 before, 1 after). |
| P2 | medium | Settings, Reduce Motion | `_MotionPreference` returned its child bare with the setting off and a `MediaQuery` with it on, so flipping the switch re-created the whole app under it and every open screen lost its state. | One stable `MediaQuery` wrapper. | `reduce_motion_test`, `app_boots_test` still green. |
| P3 | medium | Web, reload or closed tab | Pass-and-play state was memory only: the unfinished match was not offered for resume, saved groups, default settings, seen hints and the tutorial flag were gone. | `lib/data/prefs_stores.dart` (see WEB-PARITY 1). | `prefs_stores_test.dart` |
| P4 | medium | Web, score | A score started before the first tap (resumed match, link into a room) stayed silent for good. | Retried on the first tap (WEB-PARITY 2). | `audio_backend_isolation_test.dart` |
| P5 | medium | Council invite, result card | Share threw or opened a mail link where the platform has no share sheet. | Copy fallback with a message (WEB-PARITY 4, 5). | `council_life_test.dart` |
| P6 | low | Strings | Searched every `Text`, `tooltip`, `label`, `hintText`, `title` literal in `lib/ui` and `lib/app`: no untranslated user-facing text. Arabic ARB has no Latin words except brand and address names (Google Play, AdMob, UTC, the support address). English and Arabic keys match one to one. The only English surface is the voice diagnostics dialog, which is deliberately English and only opened from the voice menu. | none | `l10n_coverage_test` already guards key parity. |
| P7 | low | Dead controls | Searched for empty `onPressed`/`onTap`, `TODO`, `UnimplementedError`, «قريبا»: none. | none | none |

### Checked and found sound

- Width: the first-run, profile and Home columns stay a centred phone-width
  column on a 1440 px browser (screenshots at 1440 x 900). The Council hub, the
  lobby and the first-run arrival already have 320/360/430 dp tests in both
  locales.
- Doc 05: nothing in this pass stores or shows a role anywhere new. The web
  store holds exactly what the Isar row holds, `loadAnalytics` still refuses an
  unfinished match after a reload, and the haptic and unlock changes are
  role-blind (the L-10 call-site guard passes).

### Not verified here

- A real Android device or a real phone browser (no device on this machine):
  autoplay unlock, vibration and the Web Share sheet are covered by fallback
  tests only.
- Online create/join by code and the invite push end to end: they need the hosted
  backend, which this pass did not touch.
- `council_life_test` "an unread notice carries its own small emblem" failed on
  the base commit: the wired art is now wrapped in `ResizeImage`, which the test
  did not unwrap. The test is fixed; the app was right.
