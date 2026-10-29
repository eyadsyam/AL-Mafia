# Next update — ideas (draft, waiting for the owner's pick)

Data, 2026-10-29 (live Supabase):
- 895 accounts; 318 new in the last 7 days; 321 signed in during the last 7 days.
- Online: 48 matches ever, by 7 distinct accounts (23 matches in the last 7 days). Real players are not playing online.
- No product metrics: `economy_config.metrics_enabled = false`; the client records one event only (`attributed_first_open`). We cannot see offline play.
- Rewarded-ad callbacks: 14 ever, 2 in the last 7 days. AdMob app is still on limited serving (store not linked).

Fixed constraints: Doc 05 wins; rewards unchanged; never reduce ads; no family mode; Stories parked; one engine, two transports; mockups before code.

## Ideas, ranked

1. **Usage counts on.** Flip `metrics_enabled`, and add aggregate events: offline match started/finished (player-count bucket), online room created/joined/started/finished, rewarded offer shown/completed, banner shown. No names, roles, rooms or codes (the MetricsClient already accepts only event + one prop). Needs the owner's word (live flag) and a privacy-policy check.
2. **«العب مع ناس» — public quick-join.** One button: join an open public room that is filling, or open one and wait. Host can mark a room public. Needs: a public flag on rooms, a "find open room" RPC with fair ordering, moderation (report/kick already exist), a minimum to start, and bots never fill seats.
3. **Vs computer back as practice.** The code exists behind `_offerBotMatch` (lib/app/router.dart). Needs the M5 audit before it is offered. Gives a lone installer something to do in the first minute.
4. **WhatsApp invite link.** Link opens the room in the app, or the Play listing if not installed (install referrer `invite` already bucketed in metrics.dart).
5. **«السهرة» — a session of matches.** Same group, several offline matches in a row, a running scoreboard and a session title at the end. Interstitial cadence stays per match (no extra ads inside a match).
6. **Push when a friend opens a room.** push_outbox/push_tokens exist; add the friend-room notice with a per-friend rate limit.

## Open questions for the owner
- Which first? Recommendation: 1 now (it is a switch plus small events), then 2 + 4 together, then 3.

## After the owner's note (2026-10-29): «كل الاقتراحات تقريبا معمولة اصلا»
Codex review confirmed most already exist: public rooms + browse list, the share sheet with a room App Link, targeted friend invites with push, and the vs-computer mode (hidden). What is actually missing:
- **Usage counts.** The client records only `attributed_first_open`; the server allowlist (metrics_v11.sql:72-96) has no match/room/ad events; `metrics_enabled` is off.
- **One-tap quick match in the app.** The server RPC `quick_match_atomic` and the `quick_match` function exist (browse_quick_match_v2.sql:62-122), but lib/ never calls them; players browse or type a code.
- **Vs computer M5 audit** before the card returns.
Dropped: «السهرة» (conflicts with no per-player history, player_group.dart:23-29) and the auto friend-room push (targeted invites already push).