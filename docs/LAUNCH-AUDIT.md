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

## Pass B — coins, rewards and store

Scope: `lib/ui/economy/**`, `lib/platform/monetization/**`, `supabase/functions/**`
and `supabase/migrations/**` for the wallet, daily coffer and wheel, rewarded
ads (SSV), referral and invite rewards, Council, Casebook and season rewards,
store items. Method: read every coin-granting function at its latest
definition, every Edge action that reaches one, and the client paths that call
them.

### Findings

| ID | Severity | Where | Failure scenario | Status |
|---|---|---|---|---|
| B1 | medium | `lib/ui/screens/setup/coin_store.dart` (`matchesFor`, info dialog), `app_ar.arb` `coinsEarnHint` | With `economy_v11_enabled` on (the planned launch rule) a match pays 25, +10 for a win, +25 first of the day. The store still said "100 coins a match, +25 to winners" and quoted "950 coins = about 10 matches" for what is about 38. `economyV3` was read by nothing in the UI. | **Fixed**: `coinsEarnHintV3` (AR/EN) and a per-match figure chosen from `economy.version`; widget test in `coin_store_test.dart`. |
| B2 | medium | `20260925000600_awards_reactions.sql` `match_awards_get` | Awards paid 5 coins per award and 15 for MVP to any member of any finished room, outside the v3 receipt rules (5+ humans, 6 a day, 3 per roster). The 1.1 faucet table says awards are flavour only. | **Fixed**: `20260930000900_awards_no_coins_v3.sql` (zero coins, zero ledger rows, zero advertised coins under v3; unchanged with the switch off). Test `supabase/tests/launch_audit_b.sql` fails without the migration. |
| B3 | low | `lib/ui/economy/wallet.dart` `_act` | A purchase whose answer was lost (timeout after the server committed) left the store showing the old balance and "failed"; the player retried blind or believed coins were lost. | **Fixed**: best-effort `summary` read after an unknown failure (refusals are not re-read). `test/unit/wallet_reconcile_test.dart`. |
| B4 | medium | `lib/ui/economy/play_offers.dart:85-120,237` | Play purchase events are listened to only after the store's Play tab has been opened. A payment that completes while the app is closed (pending payments) is verified, credited and consumed only on the next store visit; Play refunds unacknowledged purchases after 3 days. No coin is lost, but a player can pay and be refunded without ever seeing coins. | **Report only.** Fix is to call `playOffersProvider.notifier.start()` once capabilities are loaded (for example in `_calmHome`); not done this late because it opens the billing connection for every Android user. |
| B5 | medium (operational) | `20260921000500_coin_economy.sql` `sync_player_rewards` (v1 path) | With `economy_v11_enabled` off, every finished match pays 100 (+25) per seat with no daily or roster cap; five anonymous accounts can farm it. | **Report only.** Turn `economy_v11_enabled` on at launch (caps are in `economy_v3.sql`). |
| B6 | low | `supabase/functions/economy/index.ts:89` | `CASE_PUZZLE_SALT` falls back to a salt that is in the repository. Unset on the host, the daily case answer is computable by anyone who has the source. Worth 5 coins and 20 XP a day. | **Report only.** Set the secret on deploy. |
| B7 | low | `20260930000500_referral_caps.sql` | The per-season cap counts payments since the active season's start; with no active season it counts none (the lifetime cap of 40 still holds). | **Report only.** |
| B8 | low | `20260927000200_payments_v2.sql:406` | The owner seed adds an admin by email without checking the email is confirmed. Only an attacker who registered that address before the owner could use it. | **Report only.** Once the owner's row is verified, make `is_commerce_admin` require a confirmed, non-anonymous email (test admins already are). Not changed here: a wrong guess locks the owner out. |
| B9 | low | `lib/ui/economy/daily_rewards.dart:352` | After an earned daily ad whose callback has not landed yet, the button is enabled again; a second ad is watched and wasted (the server pays once). | **Report only.** |

### Checked and sound

- Rewarded ads: signed SSV (`admob_ssv/verify.ts`), unit allow-list per scheme,
  one transaction pays one claim across all four schemes
  (`register_ad_transaction`), claims immutable once awarded, step 2 needs
  step 1, and the ledger keys make every credit once-only. The client never
  credits; it polls the server.
- No amount comes from a client (`economy_actions.ts`); the caller id is the
  session. Every grant goes through `credit_earned` under the wallet lock with a
  unique ledger key, so double taps, retries after a timeout and day rollovers
  are idempotent (coffer, wheel, extras, missions, season levels, achievements,
  awards, puzzle, invite stages).
- Play coins: token bound to the account tag, credited once, consumed after the
  credit, refunds reverse only unspent purchased coins and leave the rest as
  debt against future purchases. Transfer orders never move a balance from a
  client call; admin approval is once per order and per transfer.
- Negative balances: table checks (`balance>=0`, purchased within balance).
- Surface: all 291 public functions have a named revoke from `public`, `anon`
  and `authenticated`; every table is RLS-on or privilege-revoked.
- Store: all 17 catalog codes are known to `Cosmetics.items`; every narrator
  pack has clips for both ogg (phones) and mp3 (web) and is registered in
  `pubspec.yaml`; presentation packs, frames and plates draw through shared
  painters (`docs/STORE-TRUTH.md`).

### Deploy notes

- Apply `20260930000900_awards_no_coins_v3.sql` after `…0800`. No function
  redeploy is needed for it; the client change ships with the app/web build.
- Secrets that must exist on the host: `ADMOB_REWARDED_ANDROID_ID` (without it
  every SSV callback is answered 400 and AdMob does not retry),
  `CASE_PUZZLE_SALT`, `PLAY_SYNC_SECRET`.

## Pass C — Doc 05 and failure paths

Scope: what a player, a modified client or an observer can learn about another
player's role from the wire, the database, sounds, haptics, notifications and
timing; and what happens when things fail mid-match.

### Findings

| ID | Severity | Where | Scenario | Status |
|---|---|---|---|---|
| C1 | medium (Doc 05 §3.1) | `lib/ui/screens/online/online_table_flow.dart:1511`, `room_codec.dart:396` | During the deal the headline names the seats still holding their role card, live. A Mafia card carries a teammate list, so lingering on it is a visible, per-seat, timestamped signal; the code comment argues "every seat has a card", which covers content but not dwell time. | **Report only** (owner decision): show a count, or names only after every seat passed the minimum dwell. |
| C2 | low | `supabase/functions/advance_phase/index.ts:88` vs doc 10 §8.2 | The table says an absent Doctor's default is "no protection"; the code protects a seeded-random other living player (`skip` is refused for doctors). Not a role leak (the outcome is public), but rules and code disagree. | **Report only.** |
| C3 | low | `migrate_host` (30 s), `online_transport.dart:772` | A host who leaves the app for more than about 30 s (sharing the room link, web tab frozen on mobile) loses the room to the lowest connected seat once someone else is in it. Safe for the game, surprising in the lobby. | **Report only.** Not testable here (no device). |
| C4 | info | `witness_view`, `voice_controller.dart:804` | The wall between the dead (who see every role) and the living is enforced by the dead device not sending and the living device not playing their audio. A modified client can break it. Inherent to a peer-to-peer mesh. | **Report only.** |
| C5 | info | `room_players.status` / `connected` in the Realtime allow-list | Presence changes are published during the night; the UI freezes them, a modified client can read them. Not role-linked. | **Report only.** |

### Checked and sound

- Realtime allow-list pinned by `publication_allowlist.sql` (no `role`, target,
  vote, action or seed); `role` and `match_seed` have no client column grant at
  all; a player learns their role only from `my_team`, and teammates only if
  Mafia (same answer shape for everyone else).
- Whisper text: parties only by RLS; revealed after the match only when the host
  switched it on in the lobby, only at the public end, never voided, blocked
  senders masked. Room titles are withheld while playing; reactions are refused
  in every match phase; awards compute only at the result.
- The Detective's answer is in the response to their own request only; night
  submissions are readable by their author only; the ballot is hidden until
  resolved unless the room chose open voting.
- Logs carry function, result class and latency bucket only. Push payloads carry
  the inviter's display name and a lobby room code, nothing about a match.
- Sounds and haptics in a match: only the public cues (same moment on every
  phone), selection feedback that every role has, and the morning victim's own
  phone at the public death announcement. Invite knocks and vibration wait for a
  non-private moment in both flows.
- Failure paths covered by existing tests and re-read: phase expiry defaults
  (`advance_phase`), idempotent night and vote rows, closed-phase refusals,
  atomic kick/strike, host migration, process death (`process_death_resume_test`),
  voice not load-bearing (`voice_not_load_bearing_test`).

### Gate note

`flutter test` has one failure that already exists on the base commit:
`council_life_test.dart` "an unread notice carries its own small emblem". The
image is wrapped in `ResizeImage` by the in-progress art wiring and the test
still matches `AssetImage`. It is in Codex's art lane and was left alone.
