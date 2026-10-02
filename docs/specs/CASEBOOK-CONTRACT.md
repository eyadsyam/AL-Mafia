# Casebook edge contract

`economy` is the only client entry point. The verified session supplies the
user id; the client never supplies a user id, reward amount, progress, or XP.
All timestamps are UTC ISO-8601 strings and all periods are server periods.

## Actions

```json
{"action":"missionHub"}
{"action":"missionClaim","layer":"daily","period":"2026-09-28","slot":1}
{"action":"missionClaim","layer":"weekly","period":"2026-W40","slot":0}
{"action":"seasonClaim","season":"season_zero","level":2}
{"action":"achievementClaim","code":"first_case"}
```

`missionClaim.layer` is exactly `daily` or `weekly`. Daily periods are
`YYYY-MM-DD`; weekly periods are ISO `YYYY-Www`. Daily slots are 0–2 and the
single weekly mission is slot 0. Season and achievement codes contain only
lowercase ASCII letters, digits, and underscores.

## `missionHub`

When the capability is off, the complete response is:

```json
{"enabled":false}
```

When enabled, the response has this stable shape:

```json
{
  "enabled": true,
  "season": {
    "code": "season_zero",
    "startsAt": "2026-09-28T18:00:00Z",
    "endsAt": "2026-10-26T18:00:00Z",
    "level": 2,
    "xp": 475,
    "xpPerLevel": 200,
    "maxLevel": 20,
    "rewards": [
      {"level": 1, "coins": 0, "item": null, "title": null, "claimed": true, "claimable": false},
      {"level": 2, "coins": 25, "item": null, "title": null, "claimed": false, "claimable": true}
    ]
  },
  "daily": {
    "period": "2026-09-28",
    "missions": [
      {"slot": 0, "code": "finish_1", "metric": "finish", "voice": "citizen", "target": 1, "progress": 1, "coins": 5, "xp": 25, "claimed": false, "claimable": true}
    ],
    "bonus": {"coins": 10, "xp": 25, "claimed": false, "claimable": false}
  },
  "weekly": {
    "period": "2026-W40",
    "missions": [
      {"slot": 0, "code": "weekly_finish_10", "metric": "finish", "voice": "detective", "target": 10, "progress": 4, "coins": 75, "xp": 180, "claimed": false, "claimable": false}
    ]
  },
  "achievements": [
    {"code": "first_case", "metric": "finish", "target": 1, "progress": 1, "coins": 25, "xp": 50, "unlocked": true, "claimed": false, "claimable": true}
  ],
  "rank": {"level": 4, "xp": 520, "next": 660}
}
```

The server may return more reward or achievement rows, but never omits fields
from a returned row. `item` and `title` are nullable catalogue/localization
codes. `level` is the number of completed 200-XP levels (0–20).

## Claims

Every successful claim returns the refreshed hub so the UI replaces its state
atomically:

```json
{
  "ok": true,
  "coins": 35,
  "xp": 65,
  "balance": 810,
  "hub": {"enabled": true, "season": {}, "daily": {}, "weekly": {}, "achievements": [], "rank": {}}
}
```

`coins` and `xp` are amounts granted by this call. A third daily claim includes
the 10-coin/25-XP daily bonus. Retries do not grant again and return:

```json
{"ok":false,"code":"ALREADY_CLAIMED"}
```

Other refusal codes are `DISABLED`, `NOT_READY`, `PERIOD_CHANGED`,
`SEASON_CLOSED`, `NOT_FOUND`, and `BAD_REQUEST`. Refusals never include partial
rewards.

## Existing Council contract compatibility

Daily assignments are the existing `council_daily_contracts` rows joined to
`mission_catalog`; no second daily assignment is created. The shared
`claimed_at` column is the single claim marker. The legacy
`claim_council_contract` and `claim_council_weekly` RPCs delegate to the
Casebook claim functions, so an old Council surface and the Casebook can never
pay the same mission twice.

All progress comes from eligible, finished online-room records. No live-match
surface calls these actions and no response contains a role, team, ballot, or
other hidden match fact.
