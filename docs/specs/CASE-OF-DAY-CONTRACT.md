# Case of the Day edge contract

`economy` owns both actions. The verified session supplies the user id. The
client never supplies correctness, rewards, attempts, the answer, or the
server day. Days are UTC calendar dates.

## Name keys

Suspect names are localization keys, never server-authored display text:

`n01`, `n02`, `n03`, `n04`, `n05`, `n06`, `n07`, `n08`, `n09`, `n10`,
`n11`, `n12`, `n13`, `n14`, `n15`, `n16`, `n17`, `n18`, `n19`, `n20`,
`n21`, `n22`, `n23`, `n24`.

## Read today's case

Request:

```json
{"action":"casePuzzle"}
```

The only response while the feature is off is `{"enabled":false}`. Otherwise:

```json
{
  "enabled": true,
  "day": "2026-09-28",
  "attempts": 1,
  "maxAttempts": 3,
  "solved": false,
  "failed": false,
  "streak": 0,
  "bestStreak": 4,
  "reward": {"coins": 5, "xp": 20},
  "puzzle": {
    "suspects": [
      {"id":"s0","name":"n07"},
      {"id":"s1","name":"n14"},
      {"id":"s2","name":"n03"},
      {"id":"s3","name":"n21"},
      {"id":"s4","name":"n11"}
    ],
    "seats": true,
    "clues": [
      {"id":"c1","kind":"one_of","a":"s1","b":"s3"},
      {"id":"c2","kind":"not_mafia","a":"s1"}
    ],
    "difficulty": 2
  }
}
```

`suspects` is in clockwise seat order. Suspect ids are stable only inside that
day's puzzle. `difficulty` is 1–3 and rises across the UTC week: Sunday–Tuesday
1, Wednesday–Thursday 2, Friday–Saturday 3.

After the case is solved or all three attempts are spent, the same object also
contains:

```json
"reveal": {
  "answer": "s3",
  "chain": [
    {"clue":"c1","eliminates":["s0","s2","s4"]},
    {"clue":"c2","eliminates":["s1"]}
  ]
}
```

The chain is evaluated in clue order. Each row lists only suspects newly
eliminated by that clue; together the rows leave exactly the answer.

## Submit a pick

Request:

```json
{"action":"casePuzzleSolve","day":"2026-09-28","pick":"s3"}
```

Correct, first rewarded solve:

```json
{
  "ok": true,
  "correct": true,
  "grant": {"coins":5,"xp":20},
  "state": {
    "enabled":true,
    "day":"2026-09-28",
    "attempts":2,
    "maxAttempts":3,
    "solved":true,
    "failed":false,
    "streak":1,
    "bestStreak":4,
    "reward":{"coins":5,"xp":20},
    "puzzle":{
      "suspects":[
        {"id":"s0","name":"n07"},{"id":"s1","name":"n14"},
        {"id":"s2","name":"n03"},{"id":"s3","name":"n21"},
        {"id":"s4","name":"n11"}
      ],
      "seats":true,
      "clues":[
        {"id":"c1","kind":"one_of","a":"s1","b":"s3"},
        {"id":"c2","kind":"not_mafia","a":"s1"}
      ],
      "difficulty":2
    },
    "reveal":{
      "answer":"s3",
      "chain":[
        {"clue":"c1","eliminates":["s0","s2","s4"]},
        {"clue":"c2","eliminates":["s1"]}
      ]
    }
  }
}
```

An incorrect pick returns `ok:true`, `correct:false`, `grant:null`, and the
fresh state. The third wrong pick marks that state `failed:true` and includes
the reveal. A retried correct request never pays twice.

Domain refusals are HTTP-success JSON so the client can replace stale state:

```json
{"ok":false,"code":"DAY_CHANGED"}
```

Codes are `DISABLED`, `DAY_CHANGED`, `NO_ATTEMPTS`, `ALREADY_SOLVED`, and
`BAD_REQUEST`.

## Clue kinds and exact semantics

There is exactly one Mafia suspect. Let `M` be that suspect. Seats form a
clockwise circle; seat 0 neighbours seats 1 and `n-1`.

| Kind | Fields | True exactly when | Natural reading example |
|---|---|---|---|
| `not_mafia` | `a` | `M != a` | “Nour is not the Mafia.” |
| `one_of` | `a`, `b` | `M == a OR M == b` | “The Mafia is Nour or Karim.” |
| `in_group` | `group` | `M` is in `group` | “The Mafia is among these three.” |
| `outside_group` | `group` | `M` is not in `group` | “Everyone in this group is innocent.” |
| `next_to` | `a` | `M` occupies either seat neighbouring `a` | “The Mafia sat next to Nour.” |
| `not_next_to` | `a` | `M` occupies neither neighbouring seat | “The Mafia did not sit next to Nour.” |
| `distance` | `a`, `k` | minimum circular seat distance from `M` to `a` equals `k` | “The Mafia sat two seats away from Nour.” |

`group` contains unique suspect ids and `k` is a positive integer no greater
than half the table size. No clue depends on a real match, room, player, role,
vote, or history.

## Authority and privacy

The edge function generates the puzzle from UTC day plus `CASE_PUZZLE_SALT`,
computes correctness, and sends only a correctness boolean and salted answer
hash to the service-role-only RPC. Postgres owns attempts, streaks, coins, and
Season XP. Before solved/failed, neither the answer nor explanation is returned.
