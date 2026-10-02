# Mafia Master — Online Architecture

> Target: remote play for friends who are apart, at **effectively zero infrastructure cost**, with **100% playability** — no logic errors, no dead ends, and graceful degradation when anything fails.

---

# 1. The three decisions that shape everything

## 1.1 Offline-first stays the foundation

**Decision: local storage is the source of truth for everything except a live online match.**

| Data | Home |
|---|---|
| Offline matches (live + history) | **Isar, local. Zero network. Works on a plane.** |
| Online match (while in progress) | **Supabase — must be authoritative for anti-cheat** |
| Online match (after it ends) | Written to local Isar as a normal match record |
| Match history & analytics | **Always local.** Reading your own history never needs a network |
| Saved player groups | Local |
| Settings | Local |

**Why:** it keeps offline mode genuinely offline, keeps cost near zero (Supabase only carries live matches, which are short and few), and means analytics and history work with no signal. It also means a Supabase outage cannot break offline play at all.

## 1.2 Voice is never load-bearing

**Decision: an online match must be 100% playable with voice completely broken.**

Voice is an *enhancement layer*. If WebRTC fails — bad NAT, no TURN budget, denied mic permission, poor network — the match continues with structured text. The player is told once, calmly, and play proceeds.

This is the single most important rule for the "100% playable" requirement. Every online Mafia app that makes voice mandatory has matches that die when one person's connection is bad.

## 1.3 Server-authoritative, always

**Decision: the client never decides anything secret and never learns anything it should not.**

```
Client sends:  { action: "vote", target: "p07" }
Client NEVER sends:  { myRole: "detective", ... }
Client NEVER receives:  the full role table
```

Roles are assigned in an Edge Function. Each client receives only its own role. Night results are computed server-side. This is not optional — a client-authoritative online Mafia is trivially cheatable by reading network traffic.

---

# 2. Stack

| Concern | Choice | Cost |
|---|---|---|
| Game state, live sync | **Supabase** (Postgres + Realtime) | Free tier |
| Server logic | **Supabase Edge Functions** (Deno) | Free tier |
| Auth | **Supabase anonymous auth** | Free tier |
| Voice | **WebRTC mesh, single active speaker** (`flutter_webrtc`) | Free |
| STUN | Google public STUN | Free |
| TURN (fallback) | Open Relay / Cloudflare free tier | Free tier |
| Local storage | **Isar** (already in the project) | Free |

## 2.1 Why Supabase and not Firebase

| | Firebase | Supabase |
|---|---|---|
| Server-side logic on the free plan | ⚠️ Cloud Functions require the **Blaze** plan — **credit card required** | ✅ Edge Functions on Free — 500K invocations/month, **no card** |
| Concurrent realtime connections (free) | 100 | **200** |
| Row-level security | Rules language | Postgres **RLS** — stronger and easier to audit for "client must not read others' roles" |
| Relational queries for analytics | Awkward | Native SQL |

The credit-card requirement alone disqualifies Firebase for a stated zero-cost project. **Use Supabase.**

Sources: [Firebase pricing plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans) · [Supabase free tier limits](https://uibakery.io/blog/supabase-pricing)

---

# 3. Cost model — the actual numbers

Per 10-player online match, measured conservatively:

| Resource | Per match | Free tier | Matches/month |
|---|---|---|---|
| Realtime messages | ~600 | 2,000,000 / mo | **~3,300** |
| Edge function calls | ~60 | 500,000 / mo | **~8,300** |
| DB rows written | ~250 | 500 MB total | effectively unlimited (rows are purged) |
| DB egress | ~200 KB | 5 GB / mo | **~25,000** |
| Concurrent connections | 10 | 200 | **20 simultaneous matches** |

**Binding constraint: realtime messages → roughly 3,300 online matches per month, free.**

That is well past the point where the product has proven itself. If you exceed it, you have a real user base and a $25/month Pro plan is a rounding error.

## 3.1 Cost-control rules (build these in from day one)

1. **Purge finished matches after 24 hours.** A nightly `pg_cron` job deletes `matches` where `status='finished'` and `ended_at < now() - interval '24 hours'`. The full record already lives on each player's device.
2. **Never sync per-keystroke or per-frame.** Sync on discrete events only: action submitted, phase changed, vote cast.
3. **Never poll.** Realtime subscriptions only.
4. **Batch the phase snapshot.** One broadcast per phase change, not one per field.
5. **No presence heartbeat faster than 10s.**
6. **Cap room size at 15.** Beyond that both mesh voice and message volume degrade.

## 3.2 The pause trap

Supabase Free projects **pause after 7 days of inactivity**. Any real usage prevents this, but during development add a trivial weekly cron ping, and handle "project paused" in the client with a clear message rather than a spinner.

---

# 4. Database schema

```sql
-- ─── rooms ───────────────────────────────────────────────
create table rooms (
  id           uuid primary key default gen_random_uuid(),
  code         text unique not null,          -- 6 chars, no ambiguous glyphs
  host_id      uuid not null,
  status       text not null default 'lobby', -- lobby|playing|finished
  settings     jsonb not null default '{}',
  match_seed   bigint not null,               -- drives ALL determinism
  created_at   timestamptz default now(),
  ended_at     timestamptz
);

-- ─── players ─────────────────────────────────────────────
create table room_players (
  room_id    uuid references rooms on delete cascade,
  user_id    uuid not null,
  name       text not null,
  seat       int  not null,                   -- ordering = "seating order"
  role       text,                            -- SECRET. never selectable by others
  alive      boolean not null default true,
  connected  boolean not null default true,
  last_seen  timestamptz default now(),
  primary key (room_id, user_id)
);

-- ─── phase ───────────────────────────────────────────────
create table room_state (
  room_id      uuid primary key references rooms on delete cascade,
  phase        text not null,                 -- lobby|reveal|night|morning|confront|discuss|defense|vote|result
  phase_number int  not null default 0,
  phase_ends_at timestamptz,                  -- server clock, never client
  active_speaker uuid,
  public_data  jsonb not null default '{}'    -- trace text, confrontation, vote tallies
);

-- ─── actions (secret) ────────────────────────────────────
create table night_actions (
  room_id   uuid references rooms on delete cascade,
  night     int not null,
  actor_id  uuid not null,
  action    text not null,                    -- kill|protect|investigate|suspect
  target_id uuid,
  note      text,                             -- ≤40 chars
  created_at timestamptz default now(),
  primary key (room_id, night, actor_id)
);

-- ─── votes ───────────────────────────────────────────────
create table votes (
  room_id   uuid references rooms on delete cascade,
  day       int not null,
  voter_id  uuid not null,
  target_id uuid,                             -- null = abstain
  round     int not null default 1,           -- revote rounds
  primary key (room_id, day, voter_id, round)
);

-- ─── whispers: metadata is public, content is not ────────
create table whisper_meta (
  id        uuid primary key default gen_random_uuid(),
  room_id   uuid references rooms on delete cascade,
  day       int not null,
  from_id   uuid not null,
  to_id     uuid not null,
  voided    boolean default false
);

create table whisper_content (
  whisper_id uuid primary key references whisper_meta on delete cascade,
  body       text not null check (char_length(body) <= 120),
  read       boolean default false
);

-- ─── voice signalling (ephemeral) ────────────────────────
create table signals (
  id       bigserial primary key,
  room_id  uuid references rooms on delete cascade,
  from_id  uuid not null,
  to_id    uuid not null,
  payload  jsonb not null,                    -- SDP offer/answer/ICE
  created_at timestamptz default now()
);
```

## 4.1 RLS — the anti-cheat boundary

```sql
alter table room_players   enable row level security;
alter table night_actions  enable row level security;
alter table whisper_content enable row level security;

-- A player sees everyone's public fields, but ONLY their own role.
-- Enforced by exposing a view, never the base table, to clients.
create view room_players_public as
  select room_id, user_id, name, seat, alive, connected,
         case when user_id = auth.uid() then role else null end as role
  from room_players;

-- Night actions: you may read only your own, ever.
create policy own_actions on night_actions
  for select using (actor_id = auth.uid());

-- Night actions are written by Edge Functions only (service role).
create policy no_client_writes on night_actions
  for insert with check (false);

-- Whisper content: sender and recipient only.
create policy whisper_parties on whisper_content
  for select using (
    exists (select 1 from whisper_meta m
            where m.id = whisper_id
              and (m.from_id = auth.uid() or m.to_id = auth.uid()))
  );
```

⚠️ **Run `get_advisors` (Supabase MCP) with `type: "security"` after every migration.** It catches missing RLS and exposed tables. Treat any finding as a release blocker — a leaked role table destroys the entire product premise.

---

# 5. Edge Functions (the trusted logic)

Every one of these validates that the caller is a living member of the room and that the current phase permits the action.

| Function | Purpose | Returns to caller |
|---|---|---|
| `create_room` | Generate code + `match_seed` | room code |
| `join_room` | Seat assignment, name uniqueness | room snapshot |
| `start_match` | **Assign roles** using `match_seed` | *nothing* — each client fetches its own role via the view |
| `submit_night_action` | Validate role may perform this action, store | ack only |
| `resolve_night` | Apply kill − protect, compute victim, **run `selectTrace`**, advance phase | public morning payload |
| `submit_vote` | Validate, store | ack |
| `resolve_vote` | Tally, handle ties, eliminate, **check win** | public result payload |
| `generate_confrontation` | Run `selectConfrontation` over server-held history | public confrontation payload |
| `send_whisper` | Rate-limit 1/day, length check, store split | ack |
| `heartbeat` | Update `last_seen` | — |
| `advance_phase` | Timer expiry, applies defaults for non-actors | new phase |

## 5.1 Sharing the engine between Dart and Deno

The information engine (`selectTrace`, `selectConfrontation`) must produce **identical output** on client and server. Two options:

| Option | Verdict |
|---|---|
| Port the generators to TypeScript and keep two implementations in sync | ❌ Two implementations always drift. Rejected |
| **Server runs the generator; client only renders the result** | ✅ **Chosen.** One implementation of the *decision*, in the Edge Function. The Dart engine is used for offline mode and as the reference implementation |

To guarantee they agree, both are driven by the same `match_seed` and the same pure algorithm, and there is a **golden-vector test**: a fixed set of inputs with expected outputs, run against both the Dart and the TypeScript implementation in CI. If they diverge, the build fails.

---

# 6. Voice

## 6.1 The design insight that makes it free

The game already enforces **one speaker at a time** during structured phases. So voice does not need a mesh where everyone publishes.

```
Structured phases (statements, confrontation, defense):
    active speaker  ──publishes──▶  all others (receive-only)
    Upload cost: 1 stream × N listeners     ← cheap, works to 15 players

Free discussion (optional, short):
    everyone publishes  ← full mesh, gate to ≤8 players, else stay push-to-talk
```

This is a networking problem solved by game design. **Enforce single-speaker in software** — the server sets `active_speaker`, and every client hard-mutes its own mic unless it holds the token. Never trust the client to mute itself politely.

## 6.2 Connection strategy

```
1. Try STUN only (Google public)          → ~80–85% of pairs connect
2. Fall back to TURN (free tier)          → ~+13%
3. Fail → text mode for that player       → always works
```

Never block the match on a voice connection. Voice connects in the background during the lobby; the match starts regardless.

## 6.3 Voice + zero-leakage (mandatory)

| Phase | Mic policy |
|---|---|
| Lobby | Open |
| Role reveal | **Hard muted, server-enforced** |
| **Night** | **Hard muted for everyone, no exceptions** |
| Morning / Trace | Muted (app is speaking) |
| Confrontation | **Only the confronted player** |
| Structured discussion | **Only the active speaker** |
| Free discussion | Open (if enabled) |
| Voting | **Hard muted** |
| Result | Open |

**No private Mafia voice channel in v1.** Reasons: the Mafia already coordinate through the collaborative target-selection UI; a private channel adds a moderation surface, an abuse surface, and a large class of desync bugs; and it makes the Mafia's coordination *invisible to the design*, which removes the pressure that makes the role interesting.

**Critical leak to prevent:** during the night, the app must not show connection quality, speaking indicators, or "typing" states. A player lagging while performing a role action is a tell. Freeze all per-player status indicators for the whole night phase.

---

# 7. Transport abstraction — one engine, two modes

```
lib/engine/
  game_engine.dart              ← pure. no I/O, no Flutter, no async
  information/
    trace_generator.dart
    confrontation_generator.dart
    whisper_rules.dart
  models/

lib/transport/
  game_transport.dart           ← abstract interface
  local_transport.dart          ← Isar. resolves everything on-device
  online_transport.dart         ← Supabase. delegates resolution to Edge Functions
```

```dart
abstract class GameTransport {
  Stream<GameSnapshot> watch();

  Future<void> submitNightAction(NightAction a);
  Future<void> submitVote(PlayerId? target);
  Future<void> sendWhisper(PlayerId to, String body);
  Future<void> advancePhase();          // host/local only

  Future<Role> myRole();
  bool get isAuthoritative;             // true offline, false online
}
```

**Rule: the UI layer must never know which transport is active.** Every screen takes a `GameSnapshot` and calls the interface. If a widget contains `if (isOnline)`, that is a design failure — the only permitted exceptions are the voice controls and the connection banner.

This is what makes the two modes stay in sync as the game evolves. One engine, one set of screens, two transports.

---

# 8. Resilience — the "100% playable" requirements

## 8.1 Disconnection policy

| When | Behaviour |
|---|---|
| Player drops during **lobby** | Removed after 30s. Seats re-pack |
| Player drops during **night** | Their action auto-resolves at timer expiry (see 8.2). Match continues |
| Player drops during **day** | Marked «غير متصل». Timer continues. Match continues |
| Player drops during **vote** | Counted as abstain at timer expiry |
| Player returns | Full state resync. They see the current phase, never a missed secret |
| Player gone > 3 minutes | Host may mark them «خرج» — treated as a neutral elimination, then a win check |
| **Host** drops | **Automatic host migration** to the lowest-seat connected player. Never end the match |

## 8.2 Timer expiry defaults — never block

Every phase has a hard timer. When it expires the server applies a deterministic default so the match can *never* stall:

| Phase | Default on expiry |
|---|---|
| Night — Mafia | Random living non-Mafia, seeded from `match_seed` |
| Night — Doctor | No protection |
| Night — Detective | No investigation |
| Night — Citizen suspicion | Recorded as skipped (feeds `T6`/`C10`) |
| Confrontation | Silence — the app moves on. Silence is itself information |
| Vote | Abstain |
| Whisper | Not sent |

**The timer is server-side (`phase_ends_at`), never client-side.** Clients render a countdown against the server timestamp with clock-skew correction. A client with a wrong clock must never be able to act early or block the phase.

## 8.3 Idempotency

Every action carries a client-generated `action_id`. Edge Functions upsert on `(room_id, phase, actor, action_id)`. A retried request on a flaky network must never double-vote or double-kill.

## 8.4 Reconnect and resync

On reconnect the client requests a full snapshot rather than replaying deltas. Deltas are for the happy path only; snapshots are the recovery path. This eliminates an entire class of desync bugs.

---

# 9. Online vs offline — what actually differs

| | Offline | Online |
|---|---|---|
| Devices | One, passed | One per player |
| Secrecy model | Pass-screen + timing/step parity (doc 05) | Each player only ever receives their own data |
| Doc 05 relevance | **Fully binding** | Rules 1–8 mostly moot; **rule 4 (silence) and the night-status freeze remain critical** |
| Trace | ✅ identical | ✅ identical |
| Confrontation | ✅ identical | ✅ identical, mic auto-routed |
| Whisper | ✅ delayed to next turn | ✅ instant |
| Voice | Real voices in the room | WebRTC, optional |
| Authority | The device | Edge Functions |
| Anti-cheat | Physical + UI parity | RLS + server authority + *social* (see 9.1) |

## 9.1 The honest limit of online anti-cheat

Two players on a call together, or screen-sharing, cannot be detected. **No app can solve this.** Accept it and mitigate:

- Private room codes only; **no public matchmaking in v1** — you play with people you know
- The Information Engine makes colluders *visible*: identical vote patterns trigger `C5`, repeated whispers trigger `C8`, and a colluding pair's behaviour is legible in the post-game analytics
- Post-game analytics expose suspiciously perfect play

The strategy is not prevention — it is **making cheating boring and detectable by the table.**

---

# 10. Security checklist

- [ ] RLS enabled on every table; clients read `room_players_public`, never `room_players`
- [ ] `night_actions` and `votes` are insert-only via Edge Functions (service role)
- [ ] No client can query another player's `role`, verified by an automated test that attempts it and asserts failure
- [ ] `whisper_content` readable only by the two parties
- [ ] Room codes: 6 chars from an unambiguous alphabet, rate-limited join attempts
- [ ] Anonymous auth; **no PII collected** — display names only, no email required
- [ ] `get_advisors(type: "security")` clean before every release
- [ ] Edge Functions validate phase and role on every call — never trust the client's claim about the current phase
- [ ] `match_seed` is never sent to clients in online mode (it would let them predict tie-breaks)
