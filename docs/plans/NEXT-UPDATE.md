# Next update (after 1.7.0 build 23)

Live from 2026-11-19: 1.7.0 (23) sent to Play production at 100%; web on
saidalmafia.com (stamp 20261119-083028); the server half (13 migrations,
9 functions) live the same morning. Force update: `pending_min_build_android`
is 23, so the minimum follows as soon as Play publishes build 23
(play_release_watch raises `latest_build_android`).

Small follow-ups ride with the next planned update (no extra version).

## Open from the 1.7.0 review

| Item | Note |
|---|---|
| Queue room whose host never opens the app | No server-side start yet; the room waits until someone in it opens the lobby (review #3) |
| Elder night chip | Its on/off state is lost on reconnect; the server keeps the choice (review #10) |
| Friend profile numbers | Cover only what council_match_records keeps (about 21 days) |
| Device check | 1.7.0 not yet seen on the emulator (low RAM); check the queue, Game Night line, friends tabs and Elder reveal on a phone |
| public_room_pace.sql on live | Not run on live (its fixture inserts a second system room); PGlite PASS |

## After rollout

1. Read Crashlytics for the first crashes of 1.7.0.
2. Usage page: queue joins, queue_ready pushes, Game Night opens, friend
   requests / accepts / pings / group invites.
3. Confirm `min_build_android` became 23 once Play shows 1.7.0 as published.
4. Play Console: the trader-status declaration banner is the owner's to answer.
