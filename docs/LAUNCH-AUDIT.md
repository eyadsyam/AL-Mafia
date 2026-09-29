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
| A4 | medium | Settings | «اكشف محتوى الهمسات بعد المباراة» was read by nothing: no screen and no server. | The switch is removed. The field stays in `MatchSettings` for old saves. Doc 14 still lists it, so the owner decides. | `test/widget/settings_presets_test.dart` |
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

## Not fixed (reason)

- **Season One.** Season Zero runs 28 days from when `20260930000300` is
  applied, and nothing seeds the next season. The operator must add Season One
  before then, or the Casebook goes empty again.
- **mp3 copies in the APK.** The web mp3 files are also bundled in the Android
  APK (about 5 MB). Flutter has no per-platform assets. Android still plays the
  ogg files.
- **The `adstest` build.** It has a different package name, so it gets no push.
  `google-services.json` lists only the release package.
- **Reveal whispers.** «اكشف محتوى الهمسات» (Doc 14) is not built. Building it
  would be a privacy change to whisper storage.
- **The APK.** It was not built here because there is no Android SDK. The steps
  are in `docs/PUSH-SETUP.md`.
