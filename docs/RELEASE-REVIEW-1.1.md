# Release review 1.1 (reviewer pass on 0bb313c)

Scope: the 1.1 delta (no tags exist; reviewed against `main`, 179 commits). Method: read server functions and migrations that changed, the router, gates, deep links, manifest, web shell, push, payments and deletion paths; ran the SQL harness, analyzer, envelope test and the full Flutter suite. Family mode ignored. Ads code (`web_ad*`) not touched. No device or emulator was available, so Android and browser behaviour is traced from code, not observed.

## Findings

| # | Severity | Where | Scenario | Status |
|---|---|---|---|---|
| 1 | medium (Doc 05 §3.1) | `online_table_flow.dart:1511`, `room_codec.dart:396` (audit C1) | During the deal the headline names the seats still holding their card, live. A Mafia card carries the teammate list, so dwell time is a per-seat role signal. Still open. | **fixed** (5ece902): the deal headline is a count («لسه N بيشوفوا كروتهم»), never names; test `test/online/deal_waiting_count_test.dart` |
| 2 | medium | `lib/app/update_gate.dart:64` | `UpdateGate` calls `ensureSession()` at every launch, so every fresh install and every web visit (bots included) creates an anonymous Supabase user before the player chose anything. On shared Egyptian carrier NAT the per-IP anonymous sign-in limit can be hit, leaving real first-time players without a guest session. `app_config` is readable only by `authenticated` (by design of the server-surface test). Failure is safe (no block), but the session is what gets throttled. | **fixed**: migration `20261001000100_app_config_anon_read.sql` (anon select on `app_config` only), `UpdateGate` no longer signs in; tests in update_gate_test, server_surface_test, min_app_build.sql |
| 3 | medium (operational) | `economy/index.ts:89` (audit B6) | `CASE_PUZZLE_SALT` unset falls back to a salt in the repository. | report-only: confirm the secret is set on the host |
| 4 | medium (operational) | `20260921000500` v1 payout path (audit B5) | With `economy_v11_enabled` off matches pay uncapped. | report-only: confirm the flag is on in production |
| 5 | low | `supabase/tests/usage_metering.sql:11` | Test asked for the month in the session time zone while the report buckets by UTC day; failed for the first hours of each month (it failed during this review, 1 Oct Cairo = 30 Sep UTC). SQL harness was 74/75. | fixed (c7389af), harness 75/75 |
| 6 | low | `router.dart` (`/history/:id`) | `int.parse` on a non-numeric id (typed or stale URL on web) threw. | fixed (8d97a7d) + test |
| 7 | low | `router.dart` | No `onException`: an unknown address (typed web URL, half-shared link) showed go_router's English "Page Not Found". Now Home. | fixed (8d97a7d) + test |
| 8 | low | `AndroidManifest.xml` | `POST_NOTIFICATIONS` (Android 13+) relied on a library's merged manifest, yet `requestNotificationsPermission()` is the invite-push prompt. Declared explicitly. | fixed (8d97a7d) + manifest test |
| 9 | low | `coin_orders/index.ts` `admin_refund` | Order id not UUID-checked (malformed id became a generic 500) and note length unbounded. Admin-only. | fixed (8d97a7d); no Deno runner here, envelope test passes |
| 10 | low | `CLAUDE.md` rule 7 vs code | Text scale is not locked at 1.0 (`accessibility_test` runs at 1.3; only `turn_shell` clamps). Rule and code disagree; large system font sizes are the 360 dp overflow risk. | report-only (owner call) |
| 11 | low | `web/firebase-messaging-sw.js` notificationclick | Clicking an invite notification calls `tab.navigate(url)` on an existing tab, reloading a tab that may be mid-match. The seat is recoverable from the resume pointer, but the reload is abrupt. | report-only |
| 12 | low | `coin_packs.dart` `_pick` / `payment_proof.dart` | A picked file the image decoder cannot read (for example HEIC on a desktop browser) returns null and is indistinguishable from "backed out": no message. | report-only |
| 13 | low | `daily_rewards.dart:352` (audit B9), `migrate_host` 30 s (C2/C3) | Already documented; unchanged. | report-only |
| 14 | info | `android/app/google-services.json` tracked in git | Client config, not a secret; keep the API key restricted to the package and SHA-1 in Google Cloud. | note |
| 15 | info | migrations | Plain `create table`/`create function` (for example `app_config`, `delete_my_account`) are not re-runnable; they are applied once, in order. `complete_data_deletion` is renamed then recreated, so a second apply fails loudly rather than corrupting. | note |

Checked and sound: every 1.1 security-definer function has `search_path` and is revoked from public/anon/authenticated (script over migrations 0926 to 0930; the only hits are `create or replace` of earlier functions that keep their grants); `delete_account` takes the id from the JWT only and refuses with fixed codes; `coin_orders` and `play_purchase` never credit from client input, errors are fixed sentences (envelope test: 285 refusals across 67 files); `friends` routing validates every field and uses the session caller; push payloads carry only code, sender name, handle, invite id; Android intent filters and `assetlinks.json` cover both hosts (two fingerprints); `mafiamaster://login-callback` lands on Home; versionCode 10 is above the documented previous codes; no `dart:io`/`Platform` use in shared code; controllers and timers are disposed (scan); analyzer has 103 infos and no warnings or errors.

## Flow verdicts

Legend: complete = code path traced end to end and covered by tests; half = works with a stated gap; nothing is marked broken after the fixes above.

| Flow | Verdict | Notes |
|---|---|---|
| First launch, onboarding deck | complete | Room link survives onboarding via `next`; resume outranks the deck. |
| Sign in Google / email / guest, guest links later | complete, caveats | Identity is linked, not replaced. Web Google leaves the page, so the welcome chapters restart (documented). Google button answers `PROVIDER_OFF` if the provider is not configured (no capability flag). Finding 2 applies to the guest session. |
| Profile, username/handle | complete | Handle rules in SQL and edge validation agree. |
| Home, daily coffer strip and wheel | complete | Audit B9 (second ad before the callback lands) is wasted-ad only; server pays once. |
| Pass-and-play setup to result | complete | Engine purity and Doc 05 guarded by tests; redirects protect `/roles` and `/match`. |
| Online: create, join by code | complete | Offline state with retry; friendly errors per code; seated-elsewhere prompt. |
| Join by link (both domains, /join, /room, /invite) | complete | `/room` redirects to `/join`, `/invite` is the Council code (7 chars). Android filters cover both hosts and root. Web root on Android tries the app first, falling back with `?web=1`. |
| Lobby, ready-up, full online match, rematch | complete | Covered by tests; finding 1 is the open Doc 05 item. |
| Leave, rejoin, host leaves | complete | Resume pointer and host continuity tests; 30 s host migration surprise in lobby is documented (C3). |
| Invites, friends, username search, push tap-to-join | complete (push unverified on device) | Push is inert until Firebase config and `push_invites_enabled`; tap path covered by widget tests; finding 11 for web tabs. |
| Whispers and reveal after match | complete | Host switch, lobby notice, result list, server gated on public end. |
| Narrator default and three store packs, offline and online | complete | `classic` no longer silences the default voice; manifests and both ogg/mp3 twins tested. |
| Store: coins, cosmetics, narrator packs | complete | Wallet re-reads after a lost answer. |
| Play purchase | complete, unverified on device | Listener starts at launch; server verifies, acknowledges/consumes; needs a closed-track install to prove. |
| InstaPay / Vodafone Cash order, admin approval, arrival | complete | Proof stored privately, approval credits once, push plus foreground and review polling. Finding 12 for unreadable images. |
| Council, Casebook, season | complete | Season rollover migration covers end of Season Zero. |
| Referral code in room links | complete | Remembered on open, redeemed after first seat, caps fixed in 0500. |
| Account deletion | complete | Sweep is catalog-driven and tested; refuses in a live room or with a payment under review; local history stays (said in the sheet). |
| Force-update gate | complete | Fails open; Android opens Play via in_app_review, unverified on device. |
| Offline state | half | Online door has retry; vault, Council, friends have Arabic failure lines but not all a retry button (documented). |
| Privacy, terms, delete-data links | complete | Web pages exist and are rewritten on both hosts; the app copies the link on Android. |

## Deploy
Migration to apply: `20261001000100_app_config_anon_read.sql` (before the new build ships; older builds keep working). Changed server file: `supabase/functions/coin_orders/index.ts` (finding 9, optional). App and web builds need a rebuild for findings 6 to 8.
