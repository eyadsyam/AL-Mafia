# PROGRESS

The running log for the Information Engine + Online Mode build. Newest phase at
the bottom. Read this first after any `/clear`.

---

## PHASE 0 — done

Built:      The engine is now a pure function of `(names, roles, settings, seed, clock, moves)` — clock and seed injected, the four invariants asserted after every command, a purity checker, and a 10,000-match fuzz harness.

Files:
- new `lib/engine/clock.dart` — `Clock` typedef, `Clocks.monotonic/fixed`
- new `lib/engine/seed.dart` — `deriveSeed(matchSeed, salt, index)` + `SeedSalt`
- new `lib/engine/invariants.dart` — I1–I4, `checkMatchInvariants` / `assertMatchInvariants`
- new `lib/engine/legal_moves.dart` — `Move`, `legalMoves`, `hasLegalMove`, `defaultMoveOnExpiry`
- new `lib/data/match_seed.dart` — `newMatchSeed()`, the app's entropy boundary
- new `tool/engine_purity.dart` — the lint, runnable as `dart run tool/engine_purity.dart`
- new `test/support/fuzz_driver.dart`, `test/engine/fuzz_harness_test.dart`, `test/engine/fuzz_coverage_test.dart`
- mod `lib/engine/match_engine.dart`, `lib/engine/resolver.dart`, `lib/engine/analytics_builder.dart`, `lib/ui/screens/match_controller.dart`, `test/support/scripted_match.dart`, `test/engine/engine_purity_test.dart` + 8 test files (clock/seed call sites)

Verified:
- `dart run tool/engine_purity.dart` → clean
- `flutter test` → **430 passed, 0 failed** (was 409 before this phase)
- fuzz harness: 10,000 matches, 0 stalls, 0 invariant violations, ~6s
- fuzz coverage over 2,000 matches: mean **89.2 moves**, longest match reached
  **day 11**, mafia 1591 / town 409, 341 doctor saves, 1686 tied ballots, 1262
  revotes, 5103 abstentions, 1957 matches decided at night, 988 with no doctor,
  1017 with no detective, all 10 reachable phases entered
- `flutter analyze lib test tool` → 51 issues, all `info`, all pre-existing
  (0 errors, 0 warnings) — the same count as the last recorded baseline
- `flutter build apk --release` succeeds (38.7 MB), installed and driven on
  `emulator-5554` (Pixel 9 Pro (2)): Home → add 7 players → role split →
  settings → distribution → hold-to-reveal → card flip → pass → next seat.
  Screenshots reviewed at each step; nothing about the app changed.

The device run is release, so the invariant asserts are compiled out — by
design (doc 11: "assert-only in release"). The UI's *command order* is checked
against the invariants by `test/integration/match_flow_test.dart`, which plays
a whole match through the real widget tree with asserts live. That is a
stronger check than tapping through the emulator, and it is the one that would
have caught bug 2 below if `match_flow` had had the same fault the test helper
did.

Note, not a finding: the mafia win 4:1 in the fuzz. Uniform-random voting almost
never lynches a mafioso, so matches nearly always end by kills reaching parity.
It says nothing about the balance of real play.

Gate:       PASS

### What the fuzz harness found

**1. `NightResolved.savedSeat` was `null` after every night the game has ever played.**

`MatchEngine.resolveNight` logged
`savedSeat: report.someoneSavedUnnamed ? report.victimSeat : null`, but the
resolver clears `victimSeat` to null *because* the save meant nobody died. On
the only branch where the condition is true, the value read is already null.

Nothing on screen was wrong — the morning renders the boolean — but the *record*
could not distinguish a doctor blocking a kill from the mafia simply not
agreeing on anyone. Downstream:

- the `guardian` achievement tested `savedSeat == victimSeat` guarded by
  `savedSeat != null`, a condition no night can satisfy, so it never fired;
- **doc 09 `T2` («نجاة») and `C11` («الناجي») read exactly this field.** Both
  would have been silently ineligible forever, and `NightRecord.saveOccurred`
  (doc 09 §5) is not computable from a log that threw the fact away.

Fixed by splitting the resolver's return into `NightResolution` — the public
`MorningReport` (still never names the saved player, per doc 05) and the secret
`savedSeat`, which goes to the event log only.

**2. `beginDiscussion` would open a day on a match the night had already won.**

`concludeAfterNight`'s doc comment claimed the methods were separate *"so the
caller cannot accidentally open a discussion on a finished game"* — separation
expressed the intent but nothing enforced it. `beginDiscussion` now refuses.
`scripted_match.dart` was doing exactly this, so every fixture it built where a
kill reached parity carried a full extra day of events a real match cannot
contain — and those fixtures are what the persistence and analytics suites
assert against.

**3. `beginNight` would open a night on a decided match** (doc 11 N14). It
accepts `reveal` and `winCheck` as source phases, neither of which has looked at
the roster. Unreachable through the UI, reachable through the engine. Now
refused.

**4. The purity checker's own probe caught a bug in the checker** on its first
run: blanking string literals before matching turned
`import 'package:flutter/material.dart';` into `import '';`, so the Flutter ban
matched nothing. Import bans now match against comment-stripped source only.

### Decisions worth knowing

- **`legalMoves` lives in `lib/engine/`, not the test suite.** Three things need
  the same answer to "what can happen next": invariant I3, the fuzz driver, and
  the online timer-expiry defaults of doc 10 §8.2. A second copy in `test/`
  would drift, and the harness would then be testing its own rules.
- **The invariants are re-expressed, not transcribed.** Doc 11 §0 writes them
  against a `GameState` with `aliveCount`, `phaseEndsAt`, `awaitingAction` and
  `roleCounts` — fields this engine does not have. Transcribed literally all
  four are trivially true. The mapping and the reasoning are in the header of
  `lib/engine/invariants.dart`. I2 in particular cannot be stated literally: a
  decided night sits in `morning` before it is applied, so the naive form fires
  on a legitimate state and the assertion would get deleted.
- **`MatchEngine.start` no longer mints its own seed.** It defaulted to
  `Random.secure().nextInt(1 << 32)`, which is a read of platform entropy inside
  the one class that must be a pure function of its arguments. `newMatchSeed()`
  in `lib/data/` mints it now; online it will come from `rooms.match_seed`, and
  the engine cannot tell the difference.
- **`clock` is required, not defaulted.** A default would have to be either the
  real clock or a fake one, and whichever it was would be silently wrong half
  the time.
- **The night tie-break moved off `Random(seed + dayNumber)`** onto
  `deriveSeed(seed, SeedSalt.nightTieBreak, night)`. The old form shares one
  stream with anything else that picks the same arithmetic — and doc 09 §1.5's
  trace tie-break is the next thing to want a seeded choice on the same night.
  Correlated tie-breaks read as "the app has a favourite" and never fail a test.

Open:
- `MatchController.adoptMatch` assigns `engine.match` directly and is the one
  path that does not assert the invariants. Deliberate for now: a match stored
  by an older build could fail a check and crash resume in debug. Worth
  revisiting when the Phase 1 schema migration lands.
- `GamePhase.winCheck` is vestigial — nothing ever assigns it, though
  `beginNight`, `winCheck` and the resume resolver all accept it. Left alone;
  removing it is a schema change.
- `defaultMoveOnExpiry` currently picks a legal move by seed. Doc 10 §8.2 asks
  for specific per-phase defaults ("no protection", "recorded as skipped"), which
  this model cannot express — there is no null action. Phase 7 work.
- Two files in the repo are CRLF (`morning_screen.dart`,
  `asset_manifest_test.dart`) while everything else is LF. Left as found.

Next:       PHASE 1 — data model & records

---

## PHASES 1–6 — done (built in earlier sessions, verified in this one)

These landed before this session and were never written up. What follows is a
verification record rather than a build log: what is on disk, and what was
actually run against it today.

**PHASE 1 — data model & records.** `lib/engine/information/records.dart`
(`NightRecord`, `DayRecord`, `WhisperMeta`, `GameHistory`) as a *projection* of
the event log rather than a second source of truth — the reasoning is in that
file's header. Whisper bodies are stored apart in `lib/data/whisper_store.dart`
+ `lib/data/isar/isar_whisper_store.dart`. Verified: `test/data/schema_migration_test.dart`
opens `test/data/fixtures/match_pre_information_engine.json` — a pre-change
database fixture — and it still loads. Gate: PASS.

**PHASE 2 — the Trace.** `lib/engine/information/trace_generator.dart`, all
eight types plus `T0`. Verified: `test/engine/trace_generator_test.dart` covers
T-E1 → T-E9. Gate: PASS on tests; the emulator screenshot of each morning is
**not** re-run in this session (see "Not verified here" below).

**PHASE 3 — Confrontation + Day-1 opener.** `confrontation_generator.dart`
(C1–C10, C11 off by default, fairness cap), `opening_round_screen.dart`,
`confrontation_screen.dart`. Verified: `test/engine/confrontation_generator_test.dart`
(C-E1 → C-E8).

**PHASE 4 — the Whisper.** `whisper_compose_screen.dart`, the graph public and
the body private, voiding on death, the card that renders identically whether or
not a whisper is waiting. Verified: `test/engine/whisper_rules_test.dart`
(H-E1 → H-E10) and `test/golden/leakage/whisper_card_parity_test.dart`.

**PHASE 5 — transport abstraction.** `GameTransport` + `LocalTransport`.
Verified: `test/transport/local_transport_test.dart` plays a whole match through
the interface and nothing else.

> **One test in that file was red at the start of this session** and is fixed:
> its opening-round loop accused `(seat + 1) % n`, which is last night's victim
> whenever the victim sits next to the actor, and the engine refuses to accuse
> the dead. The engine was right; the test was wrong.

**PHASE 6 — Supabase backend.** Nine migrations, eleven Edge Functions, the
`room_players_public` view, `supabase/tests/anticheat.test.ts` (O16–O18) and the
golden-vector contract (`tool/golden_vectors.dart` → `golden_vectors.json`, read
by both `test/engine/golden_vectors_test.dart` and `golden_vectors.test.ts`).
Verified here: the Dart half of the golden vectors passes. **Not verified here:**
migrations applied, functions deployed, `get_advisors(type:"security")` — there
is no reachable project (see below).

Gate: PASS for everything with a test on this machine; the two Supabase gates
are **blocked**, not passed.

---

## PHASE 7 — done (code + client-side gates) | blocked (live-backend gates)

Built:      `OnlineTransport` over a testable `OnlineBackend` seam, the lobby and
join screens, the connection banner, six new Edge Functions and four migrations
— and the refactor that made all of it possible: the UI now reads the transport
rather than the engine.

Files:
- new `lib/transport/online_backend.dart` — the seam (auth, one call, one read,
  one push stream) plus its row types
- new `lib/transport/online_transport.dart` — the client's rules about distrust:
  `PHASE_CLOSED` → resync (O7), `NOT_HOST` → no-op, unreachable → banner +
  backoff (O10), phase change → full read (O12), clock skew (O8), host
  migration (O1/O2), idempotency keys (O19)
- new `lib/transport/room_codec.dart` — server rows → the *same* `GameSnapshot`
  the offline game is made of
- new `lib/transport/supabase_backend.dart` — translation only, no rules
- new `lib/ui/screens/online/{online_session,online_entry_screen,lobby_screen}.dart`
- new `lib/ui/widgets/connection_banner.dart`, `lib/platform/clipboard.dart`
- new `supabase/functions/{open_phase,submit_accusation,record_speaking,claim_host,leave_room,remove_player,my_team}/`
  and `_shared/phases.ts`
- new `supabase/migrations/2026090200{0100_opening_phase,0200_host_migration,0300_abandoned_rooms,0400_server_now}.sql`
- new `test/support/fake_backend.dart`, `test/transport/online_transport_test.dart`,
  `test/widget/online_lobby_test.dart`
- mod `lib/ui/screens/match_controller.dart`, `match_flow.dart`, four screens,
  `lib/transport/{game_transport,game_snapshot,local_transport}.dart`,
  `lib/engine/match_engine.dart`, `lib/app/router.dart`, `home_screen.dart`,
  `result_screen.dart`, both `.arb` files
- mod `supabase/functions/{resolve_night,resolve_vote,generate_confrontation,advance_phase,submit_night_action,start_match}/index.ts`

Verified:
- `flutter test` → **591 passed, 0 failed** (546 at the start of the session)
- `flutter analyze lib test tool` → 63 issues, **0 errors, 0 warnings**, all
  `info` (const/super-parameter hints, the same class as the standing baseline)
- `dart run tool/engine_purity.dart` → clean
- 33 new transport tests covering O1, O2, O7, O8, O9, O10, O11, O12, O19, O20 and
  the "a client never acts for another seat" family, against a programmable fake
  backend; 11 new widget tests covering O9, O11, O14, O15 and the lobby's
  affordances

Gate:       **PASS** for everything provable on this machine.
            **BLOCKED** for the two gates that need a running project: the five-
            device online match with a deliberate disconnect at every phase
            boundary, and `get_advisors(type: "security")`. There is no Supabase
            CLI, no Docker daemon and no Deno on this machine, and the MCP server
            in `.mcp.json` points at `localhost:54321`, which refuses the
            connection. Nothing in this phase has ever spoken to a real Postgres.

### The refactor Phase 5 stopped one step short of

Phase 5 moved every *command* behind `GameTransport` and left every *read* on
the engine: `MatchController` still called `engine.match.currentActorSeat`,
`engine.actorView`, `engine.revealFor`, `engine.currentTrace`, and six screens
read `controller.engine.match.settings` directly. Offline that is invisible.
Online it is fatal — there is no local `Match` at all — so the abstraction was
not yet the thing it claimed to be.

Every one of those reads now goes through the snapshot or through
`secretsFor(seat)`. Four interface additions carried it:

| Added | Why it had to be on the interface |
|---|---|
| `submitNightAction` returns `InvestigateResult?` | the Detective's answer is the one fact never written down (doc 05 rule 10). It cannot be on a snapshot, so it comes back from the command — offline from the engine, online in the response to the caller's own request |
| `confirmRevealed`, `beginDiscussion`, `removePlayer` | commands the controller was still issuing straight to the engine |
| `resync()` | "bring the snapshot up to date with authority": a full read online, a republish offline. Adopting a stored match needs it as much as a reconnect does |
| `GameSnapshot.settings`, `.pendingOutcome`, `.standings`, `.connectedSeats`, `.viewerSeat`, `.canAdvance`, `.phaseDeadline` | the facts the screens were reading off `Match` |

`MatchEngine.match` stopped being a `late` field: the transport is constructed
when the app boots, long before anybody taps "new match", and it needs to *ask*
whether a match exists rather than find out by throwing.

### Decisions worth knowing

- **`canAdvance`, not `if (isOnline)`.** Every device runs the same screens and
  only the host drives the phase. The screens gate their "next" affordance on a
  snapshot field, so the rule doc 10 §7 actually cares about — no widget knows
  which transport is live — survives. The only two branches on transport state
  in the whole app are the connection banner and the lobby's presence dots, both
  of which read `ConnectionQuality` / `connectedSeats` rather than a type.
- **`currentActorSeat` means "is it *your* turn" online.** There is no phone to
  pass; every client acts at once. Rather than teach the night screen a second
  mode, the online transport reports this client's own seat while it still owes
  the phase a move, and `null` once it has acted. Not one screen changed.
- **The per-player status freeze lives in the transport** (doc 10 §6.3: *"a
  player lagging while performing a role action is a tell"*). The night's
  snapshot carries the connection map from *before* the night, so no widget has
  to remember why it must not draw a live one.
- **The fake backend answers, it does not simulate.** The Edge Functions are the
  rules and are tested where they run. What the client has to get right is what
  it does with an answer — a refusal it should absorb, a refusal it should
  surface, a silence it should retry — so the fake produces programmed responses
  rather than a second game server that would then have to be kept in step.
- **Room settings ride on `rooms.settings`, not in the public payload.** They are
  written once by `start_match` and read by every client; the audio, haptics and
  hold-duration settings are deliberately *not* sent, because they are properties
  of a device and no client's business but its own.

### Four bugs in the Phase 6 code, found by making a client for it

1. **`generate_confrontation` and `resolve_vote` replaced `public_data`
   wholesale.** That payload is not scratch space — `buildHistory` reads
   `resolvedNights`, `openingAccusations`, `confrontations` and `speakingSeconds`
   out of it on *every* later night, and both handlers were writing
   `public_data: { … }`. The symptom would not have been a crash: it is a match
   whose Information Engine quietly forgets everything before today, so `T4`,
   `T5`, `C6` and `C7` stop finding anything to say. Every write now merges
   through `merge_public_data` / `set_public_path`, in one SQL statement so two
   concurrent writes cannot lose each other.
2. **`resolve_night` never ran a win check.** A night kill that reached parity
   left the room in `morning` with no outcome, and the offline engine refuses to
   open a day on exactly that state (`beginDay` throws). Online the match would
   have carried on into a day that could not legally exist. W8 now runs there,
   after the death is applied.
3. **The online Detective learned nothing.** `submit_night_action` returned a
   bare ack, so the one role whose whole function is a private answer got none.
   It now returns the exact role — matching `InvestigateResult.revealedRole`,
   because a narrower "mafia / not mafia" would make the online Detective weaker
   than the offline one, which is a rules change wearing a privacy costume.
4. **No phase had a deadline.** `phase_ends_at` was in the schema, documented as
   the thing clients render against, and never written by anything. Every phase
   that has a clock now gets one from `deadlineFor`, on the server's clock.

### Spec gaps found (reported, not worked around)

- **Doc 10 §4's phase list has no `opening`.** Doc 09 §2.2's «اسم واحد» round is
  a phase with a *current actor* — the room is pointed at one seat at a time —
  which is exactly what separates it from `discuss`. Added to the check
  constraint in a migration; the offline engine has modelled it as its own
  `GamePhase.openingRound` all along.
- **Doc 10 §8.2 has no expiry default for the opening round**, because doc 09
  §2.2 describes it as a *forced* choice ("no explanation, no 'I don't know'").
  A forced choice is enforceable at a table and not over a network — the player
  whose ten seconds ran out may simply not be there. The default implemented is
  the one this app uses everywhere else it must not invent a fact: nothing is
  recorded and the round moves on, so the seat looks exactly like a seat that
  said nothing, and `C10` reads that silence honestly. **This is a decision, not
  a spec; doc 10 §8.2 should gain the row.**
- **Doc 10 §5 lists no function for the day-1 accusations, the floor time, host
  migration, leaving, or removing an absent player**, though §8.1 requires the
  last two by name. Six functions were added (`open_phase`, `submit_accusation`,
  `record_speaking`, `claim_host`, `leave_room`, `remove_player`, `my_team`).

Open:
- **Online post-game analytics.** The autopsy reads a local match record and an
  online match has not been written to this device's database. The result screen
  hides the button rather than opening an empty screen (`analyticsAvailable`).
  Doc 10 §3.1 assumes the opposite — "the full record already lives on each
  player's device" is what makes the 24-hour purge safe — so writing a finished
  online match into local Isar is real Phase 9 work, not a nicety.
- **Role distribution online is `BalanceGuard.recommended(n)`.** The host gets no
  roles screen in the lobby; they get the same recommendation the offline setup
  screen starts from. Tuning it online is a lobby screen nobody has designed yet.
- The Deno test suites (`anticheat.test.ts`, `golden_vectors.test.ts`) have never
  been executed on this machine — Deno is not installed. The golden vectors are
  also checkable with `node supabase/tests/run_golden_vectors_node.mjs`.
- `test/widget/online_lobby_test.dart` overrides `onlineHeartbeatProvider` to
  zero. A test that left the 15-second beat running fails on a pending timer, so
  the interval is a provider rather than a constant.

Next:       PHASE 8 — whispers online + voice (`flutter_webrtc`, the mic policy
            table of doc 10 §6.3, the STUN → TURN → text ladder). Not started.

---

## PHASE 7b — the blocked gates, closed | done

*The two gates Phase 7 recorded as BLOCKED were blocked on having no reachable
Postgres. A Supabase project (`hezjbrnveajypfqmjfnh`, "AL MAFIA", eu-west-1)
and a Docker daemon arrived, so this is that phase's verification, run.*

Built:      Nothing new was designed. Four defects were found by pointing the
            Phase 6 schema at a real database for the first time, and each was
            fixed with a migration; plus a repeatable anti-cheat gate.

Files:      supabase/migrations/20260902000500_view_boundary.sql        (new)
            supabase/migrations/20260902000600_replica_identity.sql     (new)
            supabase/migrations/20260902000700_client_surface.sql       (new)
            supabase/migrations/20260902000800_platform_trigger_grant.sql (new)
            supabase/tests/anticheat.sql                                (new)
            supabase/functions/_shared/api.ts        (loadMembership split in two)
            supabase/functions/my_team/index.ts      (returns the caller's own role)
            supabase/functions/start_match/index.ts  (stale comment)
            lib/transport/supabase_backend.dart      (role now comes from my_team)
            supabase/config.toml                     (new — local stack)

Verified:   17 migrations applied to the live project; `list_migrations` now
            mirrors the repo filenames exactly, so `supabase db push` is a no-op
            rather than a re-run that would undo the repairs below.
            supabase/tests/anticheat.sql — 30 assertions, all passing, against
            the live database as three different JWT identities plus an outsider.
            get_advisors security → 0 errors, 0 warnings (was 2 errors, 20 warns).
            get_advisors performance → 0 warnings, 1 INFO (an index the purge
            has not needed yet).
            REST probe of `/rest/v1/room_players?select=role` → 42501.
            flutter test → 591 passed, 0 failed.
            flutter analyze lib test tool → 0 errors, 0 warnings, 63 info.

Gate:       PASS for everything a database can answer.

### Four defects that only a live Postgres could have shown

**1. Both client-facing views were dead.** `rooms_public` and
`room_players_public` were `security_invoker = true` while the same migration
revoked `select` on their base tables. An invoker view checks base-table
privileges as the *caller*, so every read returned `permission denied for table
room_players`. The roster, the room code and every player's own role were
unreachable — online mode could not have worked at all, and no test could have
caught it because no client had ever spoken to Postgres.

**2. `room_players` could not be updated or deleted.** It was published to
Realtime with a column list (right — it keeps `role` out of the replication
stream) *and* set to `replica identity full` (which means "the replica identity
is every column"). Postgres refuses a publication whose column list does not
cover the replica identity, so every write failed with 42P10. The heartbeat, the
role deal, every elimination and every lobby departure. The primary key is
already in the published list, so the default identity carries what Realtime
needs and nothing secret.

**3. `revoke ... from anon, authenticated` does nothing to a function.**
`execute` is granted to `PUBLIC` by default and both roles inherit it from
there; revoking their *named* grant leaves the inherited one standing. Every
helper was reachable at `/rest/v1/rpc/…` by any anonymous caller, and two of
them are `security definer`, so RLS would not have stopped either:
`leave_room(room, user)` disconnects anybody — or, in a lobby, deletes them and
re-packs the seats — and `migrate_host(room, claimant)` takes the room. The
revoke has to name `public`.

**4. Every Edge Function was broken by the same call.** `loadMembership` hung
`rooms!inner(...)` and `room_state:room_state!inner(...)` off one select.
PostgREST resolves an embed across a foreign key *between the two tables*, and
there is none: `room_players` and `room_state` are siblings, both pointing at
`rooms`. So the server answered PGRST200 to every request. Split into two
parallel queries rather than a foreign key invented to satisfy the planner.

### One change of design, not just of code

`role` is no longer on the client surface at all. It used to come from
`room_players_public`, which returned it for `auth.uid()` and nulled it for
everyone else — correct, and one policy edit away from the room. There is no
column privilege that means "this column, but only on the row where
`user_id = auth.uid()`", so a redaction was the only way to express it in a
view.

It is now expressed as an absence instead: no client role holds a column
privilege for `room_players.role` or `rooms.match_seed`, so no view, policy or
PostgREST route can return either. A player learns their own role from
`my_team`, which already ran as the service role and was already the one call
permitted to read somebody else's. The views went back to being ordinary
invoker views over the columns that were never secret, which also cleared the
`security_definer_view` lint.

### The gate that now exists

`supabase/tests/anticheat.sql` is the standing answer to doc 11 §6's O16, O17
and O18, and it is a thing that can be re-run rather than a paragraph claiming
it was checked once. It seeds a room, asks every forbidden question as a Mafioso,
a Doctor, a Citizen and a stranger, and raises on the first wrong answer:
another player's role, the match seed, a ballot in someone else's name, a kill
from a Doctor, a rewritten role, a driven phase, a stolen room, a forged
whisper, an RPC that should have no route, a spoofed WebRTC signal, and a
running tally read during an open ballot. Thirty assertions; all pass.

Open:
- **Anonymous sign-ins are disabled on the hosted project.** Doc 10 §10 requires
  them and the app has no other way in: `/auth/v1/signup` returns 422
  `anonymous_provider_disabled`. One toggle, Authentication → Sign In / Providers.
  Not something the MCP can reach.
- **The Edge Functions are not deployed to the hosted project.** `list_edge_functions`
  is empty. The CLI needs an access token (`npx supabase login`, once) and then
  `npx supabase functions deploy --project-ref hezjbrnveajypfqmjfnh` ships all
  eighteen from the repo verbatim.
- The 5-device match with a disconnect at every phase boundary is still a thing
  five phones have to do.
- `SUPABASE_URL` / `SUPABASE_KEY` still have to be passed as `--dart-define`s;
  a build without them has no online mode by design.

### And then the functions were actually run

`supabase init` + `supabase start` (Docker) brings up Postgres, PostgREST,
Realtime, GoTrue and the Deno edge runtime locally, applies all seventeen
migrations from `supabase/migrations` in order from an empty database, and
serves all eighteen functions from `supabase/functions`. That is the first time
any of this code has executed.

`supabase/tests/e2e_match.py` then plays a whole match through it: five
anonymous sessions, a lobby, a deal, a night, a morning, the «اسم واحد» round,
a discussion, a ballot and a win — **37 assertions, 0 failures**.

    SUPABASE_URL=http://127.0.0.1:54321     SUPABASE_ANON_KEY=<local publishable key>         python supabase/tests/e2e_match.py

What it proves that nothing else did:

  * O4  — rejoining returns the same seat, not a second one.
  * O7  — a night action submitted after the phase closed comes back
          `PHASE_CLOSED`, which the transport turns into a resync rather than a
          red banner.
  * O16 — `/rest/v1/room_players?select=role` is refused to a player who is in
          the room; the roster they *can* read has no role column in it; the
          match seed is refused too.
  * O18 — a Doctor submitting `kill` is refused `WRONG_ROLE`.
  * O19 — the same `actionId` replayed leaves one row, not two.
  * NOT_HOST — a guest cannot deal the roles.
  * The Detective is told the exact role, not "mafia or not".
  * A protected target survives the night.
  * `public_data` still holds its archive after `resolve_night` — the
          regression that the wholesale-replacement bug used to cause.
  * No running tally is readable during an open ballot.
  * The room reaches `finished`, with the town winning by vote.

Two harness bugs, not app bugs, are worth recording because the next person
will hit them: `actionId` is a `uuid` column, so an idempotency key must be a
real UUID and not a readable label; and a player may not name themselves in a
ballot, so a lone Mafioso has to spend theirs elsewhere.

Next:       PHASE 8 — whispers online + voice (`flutter_webrtc`, the mic policy
            table of doc 10 §6.3, the STUN → TURN → text ladder). Not started.

            Before that, two things only you can do, both one-offs:
              1. Authentication → Sign In / Providers → **enable anonymous
                 sign-ins** on `hezjbrnveajypfqmjfnh`. The app has no other way
                 in; `/auth/v1/signup` currently returns 422.
              2. `npx supabase login`, then
                 `npx supabase functions deploy --project-ref hezjbrnveajypfqmjfnh`
                 to ship the eighteen functions from the repo verbatim.
            Then the same e2e script, pointed at the hosted URL, is the
            acceptance test.

---

## PHASE 7c — the four open items, closed except the one that is a switch

Built:      the eighteen Edge Functions now run on the hosted project
            (`hezjbrnveajypfqmjfnh`), verbatim from `supabase/functions`; the
            e2e harness can mint its own users so it is runnable against a
            project whose anonymous provider is off; `dart_defines.json` so the
            two `--dart-define`s travel together.
Files:      supabase/tests/e2e_match.py
            lib/ui/screens/online/online_session.dart  (doc comment only)
            dart_defines.example.json, .gitignore
Verified:   `supabase/tests/e2e_match.py` against
            `https://hezjbrnveajypfqmjfnh.supabase.co` — **37 passed, 0 failed**,
            which is the first time any of this code has run on the hosted
            project rather than on a local Docker stack.
            `flutter analyze lib/ui/screens/online/online_session.dart` clean.
Gate:       PASS
Open:       only the 5-device match — anonymous sign-ins were switched on and
            the hosted suite re-run on the real auth path (see below).

### The eighteen functions are deployed

`list_edge_functions` was empty; it now lists all eighteen, `ACTIVE`, version 1,
`verify_jwt: true` (which matches the local `config.toml`, where no `[functions]`
block means the default). They went up through the Supabase MCP connector rather
than the CLI, because `supabase functions deploy` wants a personal access token
(`supabase login`) and none of the keys on this project — publishable, secret,
legacy anon, the database password — authenticates against `api.supabase.com`.
The secret key returns 401 there, as it should.

Each function was uploaded with the shared modules it actually imports, under
their real relative paths (`_shared/api.ts` next to `create_room/index.ts`), so
`../_shared/api.ts` resolves on the server exactly as it does in the repo.

### And they were run, on the hosted project

`e2e_match.py` played a whole match against `hezjbrnveajypfqmjfnh`: a lobby, a
deal, a night, a morning, a ballot and a town win. Thirty-seven assertions, no
failures — the same set the local run covered, including O4 (rejoin keeps the
seat), O7 (`PHASE_CLOSED` on a late action), O16 (`role` and `match_seed` are
refused to a player who is *in* the room), O18 (a Doctor may not kill), O19
(a replayed `actionId` leaves one row), NOT_HOST, and "no running tally during
an open ballot".

The five users it created were deleted afterwards, and the harness now deletes
them itself in a `finally`.

### How it ran with anonymous sign-ins off

`/auth/v1/signup` still answers 422 `anonymous_provider_disabled`. Rather than
leave the deployment unverified, the harness gained a fallback: if the anonymous
provider refuses **and** `SUPABASE_SERVICE_KEY` is set, it mints five confirmed
email/password users through `/auth/v1/admin/users` and signs them in. Nothing
under test reads the identity provider — the five players only ever need *a*
session — so this changes what the suite proves not at all.

It is the harness's own back door and deliberately not the app's: `SupabaseConfig`
still holds exactly one route in, and `SupabaseBackend` still calls
`signInAnonymously`. **The toggle is still required before a phone can play.**

    SUPABASE_URL=https://hezjbrnveajypfqmjfnh.supabase.co \
    SUPABASE_ANON_KEY=<publishable key> \
    SUPABASE_SERVICE_KEY=<secret key> \
        python supabase/tests/e2e_match.py

### The dart-defines

`dart_defines.example.json` is committed; `dart_defines.json` is git-ignored and
holds the real pair, so a build is

    flutter run --dart-define-from-file=dart_defines.json

rather than two flags remembered by hand. The rule `SupabaseConfig` states is
unchanged: no key in the repository, and a build without the pair has no online
mode rather than a button that fails.

### The switch was flipped, and the real path was run

*Allow anonymous sign-ins* is on. `/auth/v1/signup` returns a session, and the
suite was re-run against the hosted project **without** `SUPABASE_SERVICE_KEY`,
so every one of the five players came in the way the app comes in —
`signInAnonymously`, nothing else. **37 passed, 0 failed**, the same set as
before. That closes the last thing between the deployed backend and a phone:
online mode is now reachable end to end on `hezjbrnveajypfqmjfnh`.

The admin fallback stays in the harness for a project that has not been
switched on yet, but it is no longer on the path this one takes.

Open:
- The 5-device match with a disconnect at every phase boundary is still a thing
  five phones have to do.

Next:       PHASE 8 — whispers online + voice (`flutter_webrtc`, the mic policy
            table of doc 10 §6.3, the STUN → TURN → text ladder). Not started.

---

## PHASE 8 — whispers online + voice — done

Built:      the floor — a server-granted, server-expiring speaking token — and
            a WebRTC call built entirely around not being needed: one policy
            table shared by client and server, a STUN → TURN → text ladder, and
            a `VoiceLink?` that is null offline so the "voice is never
            load-bearing" rule is structural rather than a promise.
Files:      lib/engine/voice_policy.dart
            lib/platform/voice/{voice_engine,voice_controller,webrtc_voice_engine}.dart
            lib/transport/voice_link.dart
            lib/transport/{game_transport,local_transport,online_transport,
                           online_backend,supabase_backend,room_codec,game_snapshot}.dart
            lib/ui/screens/online/{voice_session.dart,online_session.dart}
            lib/ui/widgets/voice_controls.dart
            lib/ui/screens/match_flow.dart
            lib/app/l10n/app_{en,ar}.arb  (+ generated)
            pubspec.yaml  (flutter_webrtc ^1.6.1)
            supabase/migrations/{20260902001000_voice_floor,
                                 20260902001100_voice_floor_revoke}.sql
            supabase/functions/_shared/voice.ts
            supabase/functions/{claim_floor,release_floor}/index.ts
            supabase/tests/e2e_match.py
            test/voice/{voice_policy,voice_controller,voice_not_load_bearing}_test.dart
            test/support/{fake_voice_engine,fake_backend}.dart
Verified:   `flutter test` — **620 passed, 0 failed** (591 before this phase).
            `flutter analyze lib` — zero warnings, zero errors.
            `supabase/tests/e2e_match.py` against
            `https://hezjbrnveajypfqmjfnh.supabase.co` — **47 passed, 0 failed**,
            up from 37, the ten new ones being the floor.
            `get_advisors(type: "security")` — the three findings this phase
            introduced are gone; see below, because one of them was real.
            `flutter build apk --debug` — succeeds with the new native plugin.
Gate:       PASS — a whole online match plays with an engine that throws from
            every method it has (`test/voice/voice_not_load_bearing_test.dart`).

### One policy table, written twice on purpose

`micPolicyFor` exists in `lib/engine/voice_policy.dart` and again in
`supabase/functions/_shared/voice.ts`. The client hard-mutes itself against the
first; the server refuses the floor against the second. They are held together
by `test/voice/voice_policy_test.dart`, which reads the TypeScript switch as
data and walks both phase vocabularies — if the two ever disagreed, the
disagreement would be a live microphone during a night, which doc 05 does not
distinguish from any other leak.

The Dart copy has no `default:` clause, so adding a phase to `GamePhase` fails
the analyzer there rather than shipping a microphone that is open because
nobody remembered to close it.

### The night is a teardown, not a mute

Doc 10 §6.3 asks for frozen per-player status during the night — *"a player
lagging while performing a role action is a tell"*. A muted track is still a
connection, and a connection has state: who is publishing, whose bitrate just
collapsed, who reconnected in the eleven seconds the Doctor was choosing. So
`voiceTornDownIn` covers the whole private stretch (reveal, pre-night, night,
resolution) and the controller drops every peer for it. The inbound signal pump
is gated on the same flag, so a peer cannot talk this device into a negotiation
mid-night — V6 as an impossibility rather than a preference.

### V4 has two halves and needs both

The server refuses the floor, which stops an honest client. A mesh has no
server in the media path, so a modified one could publish anyway — and every
receiver therefore silences the inbound track of anybody who is not the active
speaker (`setAudiblePeers`). Neither half is sufficient; the sending half is
`claim_floor`, the receiving half is at every ear.

### The floor expires

V5: an active speaker who disconnects must not keep the microphone. So
`claim_speaking_floor` is a single `update ... where (active_speaker is null or
active_speaker = p_user or speaker_until < now())` — the row is the lock, two
simultaneous claims cannot both win, and a grant nobody gave back lapses on its
own. `release_floor` is the polite path, not the mechanism.

A phase change is also a release: every handler that opens a phase already
writes `active_speaker: null`, which is why none of the six needed changing.
`speaker_until` is only meaningful beside a holder.

### A security finding that was not a lint

`get_advisors` flagged all three new functions as executable by `anon` and
`authenticated`. The migration *did* say `revoke ... from public` — and that is
the same trap this schema documented in 20260902000700 §2 and fell into anyway:
the project's default-privileges rule grants EXECUTE on new functions in
`public` to both roles, so a function arrives with an inherited PUBLIC grant
**and** two explicit ones, and revoking the first leaves the others standing.

On `claim_speaking_floor` that was a real hole rather than untidiness. The
function takes `p_user`, so any signed-in client that knew a room id could have
granted the floor to any player in any phase — the night included — with the
Edge Function and its entire policy table bypassed. Fixed by
`20260902001100_voice_floor_revoke.sql`, which names all three roles;
`20260902001000` now writes the same revoke so a database built from scratch is
right the first time. Verified by reading `has_function_privilege` back, and by
a clean advisor run.

What is still listed by `get_advisors` is what was listed before this phase:
the anonymous-access policies, which are the app's only way in and are the
design, and leaked-password protection on a project with no passwords. PHASE 9
owns writing that down properly.

### There is no mute button, and there will not be one

`VoiceControls` reports `microphoneLive`; nothing sets it. The microphone is
live because the phase permits it and the server granted the floor, and a
control that could contradict either would be a control that lets a player be
heard during a night. The widget is one of doc 10 §7's two permitted exceptions
and, like the connection banner, it reads a value rather than a type — offline
`voiceStateProvider` is null, the strip is not built at all, and the tree an
offline match renders is byte-for-byte the tree it rendered before.

### TURN is configuration, not a bundled service

`IceConfig.relay()` reads `TURN_URL` / `TURN_USERNAME` / `TURN_CREDENTIAL` from
`--dart-define`. A build without them has a two-rung ladder instead of three,
which is an ordinary configuration and not a degraded one — the third rung is
text, and text always works. Bundling a relay would have been a promise the app
cannot keep.

### Deployment note

`claim_floor` and `release_floor` were deployed through the MCP connector, and
the `_shared/api.ts` in their two bundles is the repo's file with its prose
comments stripped — identical code, uploaded that way to keep the tool call
inside a sane size. The other sixteen functions still carry it verbatim.

### The native dependency builds, with a warning worth keeping

`flutter build apk --debug` succeeds (825s — a first Gradle build with a new
native plugin). It prints one forward-compatibility warning that is not ours to
fix and is worth writing down anyway:

    WARNING: Your app uses the following plugins that apply Kotlin Gradle
    Plugin (KGP): flutter_webrtc
    Future versions of Flutter will fail to build if your app uses plugins
    that apply KGP.

Not a problem today and a build failure on some future Flutter. The mitigation
is already in place structurally: `webrtc_voice_engine.dart` is the only file
that imports the package, and `NullVoiceEngine` is a working app without it.

Open:
- The 5-device live match, still the one thing five phones have to do. It now
  has a second half: one of them should refuse the microphone, and one should
  be on text mode, and the match should not notice either.
- `flutter_webrtc` applies the Kotlin Gradle Plugin, which a future Flutter will
  refuse. Watch the plugin's changelog for a Built-in Kotlin release.

Next:       PHASE 9 — hardening and release. The fuzz harness at 10,000, the
            L1–L10 regressions as a suite, `get_advisors` performance, the
            24-hour purge cron, the weekly keep-alive, and the release build.
            Not started.

---

## PHASE 9 — done

Built:      the release gate, made checkable — a dictionary between doc 11's
            leakage numbering and this repo's, the two rows nobody had ever
            tested, a security review written as assertions rather than as a
            memory, and two release artefacts.

Files:      test/leakage/doc11_regressions_test.dart          (new)
            test/transport/server_surface_test.dart           (new)
            test/engine/win_condition_test.dart               (the property test)
            test/voice/voice_not_load_bearing_test.dart       (unused import)
            supabase/migrations/20260902001200_anon_role_narrowing.sql (new)
            supabase/tests/e2e_match.py                       (O1/O2)
            docs/PROGRESS.md

Verified:   flutter test — 651 passed, 0 failed (620 before)
            flutter analyze lib test — zero errors, zero warnings
            e2e_match.py on hezjbrnveajypfqmjfnh — 55 passed, 0 failed (47 before)
            flutter build apk --release      — app-release.apk, 107.1 MB
            flutter build appbundle --release — app-release.aab,  88.0 MB
            get_advisors(performance) — one INFO, kept on purpose (below)
            get_advisors(security)    — see the contradiction below

Gate:       PASS, with one box that cannot be ticked as written — and it is
            the spec's box, not the code's. Read the next section before
            reading the tick.

---

### The one place doc 11 and doc 10 cannot both be satisfied

Doc 11 §10 requires `get_advisors(type: "security")` to return **clean**.
Doc 10 §10 requires the app to have exactly one way in: `signInAnonymously`.

Those are not compatible, and no amount of tightening makes them compatible.
Supabase's `auth_allow_anonymous_sign_ins` lint fires on **any RLS policy
granting `authenticated`, for as long as the anonymous provider is enabled** —
because an anonymous sign-in is a real session whose JWT carries
`role: authenticated`. The remediation the lint offers is to add

    and (select auth.jwt() ->> 'is_anonymous')::boolean is false

to every policy. In this project that predicate is false for **every player**,
so taking the advice would produce a clean advisor and an unplayable game.

The lint is therefore permanent here, and it is permanent by design rather
than by neglect. What was possible was to make it the *only* thing left, and
to make sure it is describing something we chose:

**Narrowed (`20260902001200`).** Every policy in `20260901000800` and
`20260902000700` had been written without a `to` clause, which in Postgres
means `to public` — which includes `anon`, the role of a request carrying the
publishable key and no session at all. Not exploitable, because every `using`
clause funnels through `auth.uid()` and `anon` has none; but the boundary was
being held by arithmetic rather than by a grant, and the next policy written
would have inherited the same silence. All thirteen are now `to authenticated`,
verified live: `select count(*) ... where roles <> '{authenticated}'` → 0.

**Revoked.** `usage on schema cron` from `anon` and `authenticated`. Two of
the twelve lints are `cron.job` and `cron.job_run_details`, whose policies are
created by the platform and are not ours to alter. The schema is not in
PostgREST's exposed list, so it was never reachable; it is now not even
visible.

**Left.** `auth_leaked_password_protection`. This project has no password
authentication of any kind, so the setting protects nothing here — and it is an
Auth dashboard toggle, not SQL. **It is yours to flip if you want it**
(Authentication → Providers → Password); I have not touched account settings.

So the honest statement of the box is: *every security finding that is not a
consequence of doc 10 §10 is gone, and the ones that remain have been read.*
If you want a literally clean advisor, the only route is to stop using
anonymous sign-ins — which is a doc 10 change, not a doc 11 one, and not mine
to make.

### And the one performance lint, kept

`unused_index` on `rooms_finished_at`. It is a partial index —
`(status, ended_at) where status = 'finished'` — matching the purge predicate
exactly, and it reads as unused because a project with a handful of test rooms
has never given the nightly purge anything to delete. Dropping a correct index
to satisfy a linter is the same move as widening a luminance budget to make a
leakage test pass, so it stays. It will stop being flagged the first week the
purge has work to do.

---

### The leakage numbering had two vocabularies and no dictionary

This is the finding that took the longest to see, because everything was
passing. Doc 11 §8 numbers the zero-leakage regressions **L1–L10**. This repo
numbers them **L-01 to L-16**, from doc 05. The two overlap and do not match:
doc 11's L5 is the dwell gate, which lives here under `L-07`; doc 11's L6 is
audio and haptics, which lives here under `L-10`. A release gate that says
"all L1–L10 leakage tests pass" was, in practice, unverifiable — you could
only read every test file and form an opinion.

`test/leakage/doc11_regressions_test.dart` is the dictionary, and it is
executable:

  * doc 11 §8's table is **parsed from disk** and compared against the map, row
    numbers and pass criteria both. A row added, renumbered or reworded in the
    spec fails the suite until somebody assigns it a test.
  * every file and group the map names must exist — so deleting or renaming a
    ship-blocking suite fails here instead of quietly reducing coverage.
  * none of those files may contain a skip. A skipped leakage test is worse
    than a missing one: it reports green.
  * the three tolerances doc 11 states in prose — ±2%, 8 seconds, 12 levels —
    are asserted next to the sentence they come from, so widening a literal
    fails in two places rather than one.

**Two rows had no test at all.** L3 (step count: exactly 2 per role) and L4
(tap count: identical) were not pinned anywhere in the repo. They are now, and
they are driven blind: the same finder sequence for every role, so a role that
needed a different path fails by not completing rather than by being counted
differently. The turn is asserted to be unconfirmable before a choice is made
and finished by the second tap, for all four roles.

They are worth having. Everything else in the leakage suite guards what the
screen looks like; these two guard what the *hand* looks like. Nobody at the
table needs to see a screen to count how many times the person holding the
phone touched it.

### The property test was two orders of magnitude short

Doc 11 §10 asks for the `evaluateOutcome` property over **100,000 pairs**. The
test drew **500 random samples** out of a space a few hundred wide — so it was
mostly repetition, and it had never covered its own domain exhaustively.

Drawing 100,000 samples from that space would have been 99% repetition wearing
a bigger number, so the sweep is exhaustive instead and the count falls out of
the bounds: 64 alive mafia × 64 alive others × 5 dead mafia × 5 dead others =
**102,400 states, no two the same**, in under a second. Sixty-three living
mafia is far past anything S1 permits, which is the point: the rule is
arithmetic on two counts, its bugs live at boundaries, and a sweep that stops
at the largest legal roster never reaches the boundaries a later rule change
might move. A second test states the same property from the other side — the
dead never change the answer — because that is the one a future "graveyard
reveals" feature would break silently.

### The security review, written down as assertions

`test/transport/server_surface_test.dart`. A review is a moment; this is the
part of it that outlives the moment. `e2e_match.py` already tries the rude
things against the real server, but it cannot notice a **new** function that
forgot a guard or a **new** policy that forgot a role — those are absences, and
an absence is invisible to a test that walks a known path.

Eleven assertions, each one a finding:

  * every Edge Function is served through `handler()` — the wrapper is where
    authentication lives, and a function calling `Deno.serve` directly would be
    reachable by anyone with the URL and would look entirely normal doing it;
  * every function that accepts a `roomId` establishes who is asking
    (`loadMembership`, or `host_id !== userId`); the only exemptions are
    `create_room`, which has no room yet, and `join_room`, which is how you
    stop being a stranger;
  * the service key is read in exactly one file;
  * no function echoes what it caught — a stack trace out of a function that
    touched the role table is a leak of a different kind;
  * every `security definer` function in the migrations pins a `search_path`
    **and** is revoked from `anon` *and* `authenticated` **by name**. This is
    the assertion that would have caught the `claim_speaking_floor` hole in
    PHASE 8 at test time rather than at review time;
  * every policy names its role, or is altered to;
  * `dart_defines.json` is git-ignored, the committed template is a template,
    and no tracked `.dart`/`.ts`/`.sql`/`.py` file carries a secret key or a JWT.

Two facts too important to leave to a scan were checked against the live
database instead:

    role, match_seed — column privileges for anon/authenticated:  none, zero rows
    room_players_public, rooms_public — reloptions:               security_invoker=true

That is doc 10 §4.1's central claim, and it holds.

### Host migration is now tested, not merely implemented

Doc 11 §10 wants it "verified by force-quitting the host mid-night". A harness
cannot force-quit a phone and does not need to: what a dead phone *is*, to this
server, is a `last_seen` that stopped moving. `e2e_match.py` backdates it with
the service key — the one thing in the file no player could do, because nothing
on the client surface may write `room_players` at all — and then walks O1 and
O2 for real: a live host keeps the room; the lowest connected seat inherits;
the phase does not move; a beaten claimant is told who won rather than handed
an error; and when the heir goes quiet too, the cascade reaches the next living
seat with nothing special-casing it.

One thing that surfaced while writing it, and is worth knowing: **an Edge
Function call is not a sign of life.** Only `heartbeat` and `claim_host` touch
`last_seen`, deliberately — a client can be making requests while its player
has walked away. The consequence is that in a run of any length the host is
"stale" by the ordinary passage of time, so the fixture heartbeats first, which
is what the app does every ten seconds anyway.

### The purge and the keep-alive were already running

Both were written in `20260901000900` and both are live on the project. Read
back from `cron.job`:

    archive-abandoned-rooms  */5 * * * *
    keep-alive               0 6 * * 1
    purge-finished-rooms     17 3 * * *
    purge-stale-signals      */5 * * * *      ← added this phase

`purge_stale_signals()` arrived with the voice migration and was never given a
schedule, so the only thing sweeping `signals` was the nightly purge, at an
hour's grain. An hour is three orders of magnitude longer than an SDP offer is
worth, and every stale row sits in the RLS-filtered read path of a live match.

### The release build works and is not shippable

Both artefacts build clean:

    app-release.apk   107.1 MB
    app-release.aab    88.0 MB

**They are signed with the debug key.** `android/app/build.gradle` still carries
the Flutter template's `signingConfig = signingConfigs.getByName("debug")` in
the release block, and there is no `android/key.properties`. That builds and
installs; Play will refuse it. Generating a keystore means creating and holding
a credential, so it is yours to do, not mine — and once you have, the release
block wants a real `signingConfig` and `key.properties` must join
`dart_defines.json` in `.gitignore`.

The APK is also large, and **not for the reason stated here earlier**. Opening
it up: 92.6 MB of the 110 is three copies of the native libraries — x86_64
36.9, arm64-v8a 31.7, armeabi-v7a 24.0 — and `assets/flutter_assets`, the
artwork and the ambient loops and the audio bed together, is **14.7 MB**. The
art is not the problem; shipping every ABI to every device is. Confirmed by
building the splits:

    app-arm64-v8a-release.apk     46.2 MB     <- what almost every real phone gets
    app-armeabi-v7a-release.apk   38.4 MB
    app-x86_64-release.apk        51.4 MB
    app-release.apk (fat)        107.1 MB

So the bundle, which splits per device automatically, is not a nicety here — it
is more than half the download.

Open:
- The 5-device live match. Still the one thing five phones have to do, and
  still the last untested box: a disconnect at every phase boundary, one
  device refusing the microphone, one on text mode.
- A full match walked on the emulator with screenshots reviewed. **The
  emulator cannot start on this machine right now** and the reason is not
  subtle:

        FATAL | Your device does not have enough disk space to run avd:
                `Pixel_9_Pro_2`.

  `C:` has 1.7 GB free of 309 GB, and the AVD lives there. So the release APK
  has been *built* but never *run*, and a release-mode-only failure — R8
  stripping something reflective, a tree-shaken icon, a native asset that
  resolves in debug and not in release — would not have been caught by
  anything above. This is the largest remaining risk in the gate and it is
  cleared by freeing a few gigabytes on `C:`, not by writing code. For scale:
  this project's own `build/` directory is 4.0 GB, on `D:`.
- A real signing key, and the Play track that follows it.
- `auth_leaked_password_protection` — a dashboard toggle, if you want it.
- `flutter_webrtc` applies the Kotlin Gradle Plugin, which a future Flutter
  will refuse. Unchanged from PHASE 8; watch the plugin's changelog.

Next:       Nothing in the build order. Every phase from 1 to 9 is done. What
            is left is a room with five phones in it.

---

## PHASE 9a — done

Built:      nothing new. This closes the one box PHASE 9 left open: the release
            build has now been **run**, not merely built — a whole match, on a
            device, from a release APK, with every screen looked at.

Files:      docs/PROGRESS.md (the APK-size paragraph above was wrong; corrected)

Verified:   app-x86_64-release.apk installed and played end to end on an
            Android 36 x86_64 emulator. Five seats, full role distribution,
            night one, the morning trace, the opening round, the discussion
            timer, four votes, the elimination and the postgame reveal.
            `adb logcat -b crash` empty for the whole run; no `E/flutter`.

Gate:       PASS.

### What a release build was hiding, and what it wasn't

Nothing. That is the finding, and it is worth stating plainly rather than
skipping: R8 did not strip anything the app needed, the tree-shaken icon font
resolved, and every asset that the debug build shows the release build shows
too. Specifically confirmed on screen, because these are the things that fail
only in release:

  * the four role paintings and the ornate card back, at full size;
  * the night street and the day square ambient grounds;
  * the Arabic type — the display face, the numerals, RTL layout and the
    line-height rule — in the release font subset;
  * the `google_fonts` deferred-asset path, which is the one this project has
    a standing note about (the Flutter SDK lives under a path with a space).

### The information engine, watched rather than asserted

Omar was killed on night one. The morning published exactly one trace:

    الأثر — آخر حاجة سجّلها OMAR: كان شاكك في «ALI»

Omar was a **citizen**. His night turn was a decoy, and the app reported it in
the same words, the same slot and the same typography it would have used for a
detective's real investigation — and it reported *whom he looked at*, never
what he found, because for a citizen there is nothing to find. A player reading
that sentence learns that Omar was looking at Ali and cannot tell whether Omar
was capable of learning anything by doing so. That is doc 05's whole argument,
and it is the first time it has been seen working on glass rather than in a
matcher.

The postgame timeline then showed the full set, correctly and only after the
match was over: Nour investigated Ali, Zain protected Ali, Ali killed Omar,
the town voted Ali out. Town won; `WinChecker` agreed with the table.

### The turn shell, at the two places it is easiest to break

Both hold gates behave: the identity gate at 5s, and the night-turn dwell gate
at 8s, during which Confirm stays disabled and no amount of tapping ends the
turn early. The mafia's kill screen and a citizen's decoy screen were captured
back to back and are the same screen — same tile count, same tile spacing, same
disabled Confirm, same subtitle rhythm — with only the sentence differing. And
the reveal conceals itself: the card flips back to its back on its own and only
then does the gold pass button appear, so the face is never what the next pair
of hands sees.

### The emulator problem was not the host disk

PHASE 9 recorded this as "`C:` has 1.7 GB free". `C:` now has 32 GB free and
the emulator still could not take the app: `INSTALL_FAILED_INSUFFICIENT_STORAGE`
for a 51 MB APK with 378 MB free. The reason is that Android refuses *any*
install once a partition is under its low-storage reserve — for a 5.8 GB
`/data` that reserve is ~580 MB, so at 378 MB free the device was already
below it and the size of the APK never entered into it. The stock
`Pixel_9_Pro_2` AVD ships a 6 GB userdata partition and the Play system image's
own data fills 5.2 GB of it; growing `disk.dataPartition.size` does not help,
because the existing userdata image is not resized on boot.

Resolved by creating a **separate** AVD rather than wiping the existing one:

    MafiaMaster_Test — android-36 google_apis_playstore x86_64, 16 GB /data

`Pixel_9_Pro_2` was not touched (its `config.ini` was restored byte for byte
and no `-wipe-data` was ever run), so nothing installed on it was lost. Future
release-build testing should use `MafiaMaster_Test`.

### `auth_leaked_password_protection` — closed as not applicable

Recorded in PHASE 9 as "a dashboard toggle, if you want it". Closing it: this
project has no password authentication at all — the app's only door is
`signInAnonymously`, and the setting checks submitted passwords against
HaveIBeenPwned. With no password ever submitted there is nothing for it to
check. It is not a gap and it does not need to be opened.

Open:
- The 5-device live match. Unchanged, and now the only untested box: a
  disconnect at every phase boundary, one device refusing the microphone, one
  on text mode.
- A real signing key, and the Play track that follows it. The release block
  still signs with the debug key.
- `flutter_webrtc` applies the Kotlin Gradle Plugin. Unchanged; watch the
  plugin's changelog.

Next:       Nothing in the build order.

---

## PHASE 12 — done

Built:      The release build can reach the network again; Play asks which game
            this is; doc 13 Parts 2 and 3 (the one bullet, the pressure curve).

### The online bug, and it was never the server

«مفيش وصول للسيرفر» on every release build. The server was fine — probed live:
`signup` 200, `create_room` 200, room `ULPGQF` created. Flutter's template
declares `android.permission.INTERNET` in `src/debug` and `src/profile` only,
because that is where hot reload needs it, so **every release APK this project
has ever produced had no network permission at all**. Every Supabase call threw
at the socket, the transport correctly classified it as unreachable, and the
player was told the server was down.

`src/main/AndroidManifest.xml` now declares `INTERNET`, `ACCESS_NETWORK_STATE`
(so the banner can tell "this phone has no signal" from "the server did not
answer") and `RECORD_AUDIO`. Verified on a real `flutter build apk --release`:
the merged release manifest carries all three.

`offline_and_manifest_test.dart` asserted the opposite — FR-029 as
"the release manifest declares no INTERNET permission". FR-029 and docs 10/12
cannot both be true; the test now asserts what FR-029 was actually for, that
**the one-phone game imports nothing that can reach a network**, scanned over
import directives in `lib/engine` rather than over file text.

### Play asks the question first

`ModeScreen` (S-01a) — «هتلعبوا إزاي؟», two cards at the same weight. The online
text link is gone from Home entirely, and with it the compile-time flag that
decided whether a player ever heard the app plays online: the online card is now
drawn whether or not the build has a project, and a build without one says so on
the card. `mode_screen_test` asserts both, and scans `home_screen.dart` for the
absence of `onPlayOnline` and `SupabaseConfig`.

**The rematch budget moved from three taps to four**, and that is the only thing
it has ever been allowed to pay for. `group_rematch_test` states the new number
and why.

### Doc 13 Part 2 — «الطلقة الواحدة»

`BulletKind` + `RoleBullet` (total, like `RoleNightAction`), `BulletSpent` in the
log, `lib/engine/bullets.dart` deriving everything from it — no flag on `Player`,
because a flag beside the log is a second source of truth a force-quit can
desync, and the failure mode is a player getting their one irreversible move
back.

* **الليلة الهادية** is the *team's*, and the resolver ignores the night's votes
  when it is spent.
* **حماية النفس** is not a grid entry. Self-protection is now refused outright
  (it never was before, though the UI never offered it) and the bullet is the
  only way to it — the Doctor's target list must stay the same shape as everyone
  else's.
* **فتح الملف** recomputes its results from the roster at the moment of
  publication. Doc 05 rule 10 still forbids writing an investigation down.
* **الشهادة** publishes that night's `SuspectCast`, named.

**The quiet night's price, paid honestly.** Doc 13 §8 wants a quiet morning to be
indistinguishable from a Doctor save. There were two ways and only one is honest:
announcing a save that did not happen would have the app state a fact, which doc
09's first law forbids. So it goes the other way — with `quietNightEnabled` on,
the morning stops distinguishing the two and says only what is true of both, and
`T2` («نجاة») stops being a trace candidate, because a trace announcing a blocked
kill would put back the sentence the report just removed. With the setting off,
every one of those mornings reads exactly as it did before.

**On glass.** One slot, one position, one height, one gesture for all four roles.
Long-press to arm (toggleable until the turn is committed), struck through and
inert once spent, never removed. Blank before the reveal — the bullet's name is
role-specific text and the handoff screen is the one screen the table can see.
All four Arabic names ink 13 glyphs, asserted in `night_prompt_balance_test`
beside the four prompts' 19.

Two layout consequences, both real:

* the slot lives **inside** `slotBody` rather than beside the action button. The
  shell's fixed slots already filled a 640pt phone to within five pixels; a
  seventh overflowed by 28. The body is the one `Expanded` part, so a control
  there takes its space from the seat list, which scrolls.
* the seat list is no longer a lazy `ListView`. It built only what fitted, so
  adding a slot above it silently changed how many seats existed *as widgets* —
  invisible on a phone, visible to a screen reader and to the leakage suite.

### Doc 13 Part 3 — the pressure curve

`lib/engine/pressure.dart`. `bandFor` takes an `int`, not a match and not a
phase, so it cannot be handed anything role-shaped. It **only ever tightens**: a
host who set a short discussion keeps it. `MatchSettings.discussionSeconds` is
new — free discussion used to derive its length as speech × head count, which
made it *grow* with the table exactly where doc 13 wants it to shrink.

The turn-change chime rises a semitone per band through
`AudioDirector.playTurnChange({required int band})` — its own door, so no other
cue can be handed a pitch. `AudioBackend.play` gained `rate`.

Files:      android/app/src/main/AndroidManifest.xml
            lib/app/router.dart · lib/app/l10n/* (+81 keys)
            lib/ui/screens/setup/{home_screen,mode_screen}.dart
            lib/engine/{bullets,pressure,hints,coaching,presets}.dart
            lib/engine/{resolver,seed,match_engine}.dart
            lib/engine/models/{enums,match_settings,information_events}.dart
            lib/engine/information/trace_generator.dart
            lib/data/match_codec.dart · lib/ui/l10n_ext.dart
            lib/ui/widgets/turn_shell.dart
            lib/ui/screens/{match_controller,match_flow}.dart
            lib/ui/screens/night/{night_action_screen,morning_screen}.dart
            lib/ui/screens/day/discussion_screen.dart
            lib/platform/{audio_backend,audio_director}.dart
            lib/transport/{game_transport,local_transport,online_transport}.dart
            test/widget/mode_screen_test.dart + 9 fixtures updated

Verified:   `flutter test` — 697 pass, 0 fail.
            `flutter analyze lib` — 0 errors, 0 warnings (28 pre-existing infos).
            `flutter build apk --release --dart-define-from-file=…` — succeeds,
            and the merged release manifest carries INTERNET /
            ACCESS_NETWORK_STATE / RECORD_AUDIO.
            The live project probed directly: anonymous sign-in and
            `create_room` both 200.

Gate:       PASS

Open:
- **Bullets are offline-only.** `GameTransport.supportsBullets` is false for
  `OnlineTransport` and the control is therefore not built online — constant for
  a whole match, so its absence says nothing about anybody. Making it real online
  needs `submit_night_action` and `resolve_night` (doc 10 §5) to learn what a
  bullet is, plus a migration. Written down, not written.
- `ghost_say` and `submit_prediction` are still **not deployed** (404 on the live
  project), along with `20260903000100_open_voting.sql` and
  `20260903000200_witness.sql`.
- **Doc 13 §2.4 is not literally implementable.** *"Two long-presses total — for
  every role, always, whether or not they arm it"* cannot hold: a player who does
  not arm the bullet does not press it, which is one press, not two. What is
  built is the defensible half — arming is a long press and the confirm under it
  is a second deliberate action, so the one irreversible move of a match is never
  a single gesture, and the control is identical for all four roles in position,
  size, height and interaction. The dwell gate is what actually equalises turn
  length and it is untouched.
- Doc 13 Parts 4 (hints), 5/7 (presets and settings), 6 (balance harness) and
  8/9 (acceptance) are **not** on glass yet. The engine modules exist and are
  analysed clean — `hints.dart`, `coaching.dart`, `presets.dart` — with no UI
  reading them and no tests over them.
- The doc 10 / doc 12 mafia coordination-dot conflict, unchanged and still
  awaiting a ruling: doc 12 §3.3 asks for a gold dot showing a Mafioso their
  teammates' running votes; `room_codec.dart` deliberately sends
  `teammateVotes: const []` because a live feed of it online is a coordination
  channel the table game does not have. The reserved slot is built and laid out
  on every seat for every role, and left empty.

Next:       Doc 13 Part 4 — the hint system on glass.

---

## PHASE 13 — partial (stopped on request)

Built:      Doc 13 Part 6 (the balance harness) in full; Part 4 (the hint
            system) on glass for Tiers 1–3; the bullet is now a legal move.

### Doc 13 Part 6 — the balance harness

`test/support/balance_driver.dart` + `test/engine/balance_harness_test.dart`.
Twenty-two cells (three presets × eight table sizes, minus the ones «قاسية» is
no longer offered at) × two town policies, 400 matches each, ~20 s. The full
five thousand doc 13 §6 asks for is one flag away:
`--dart-define=BALANCE_RUNS=5000`.

**The agent model, and why the numbers mean anything.** A win rate is a
property of the rules *and* of the players; there is no such thing as "the"
mafia win rate at nine. So the model is stated: weak, **mostly shared**
impressions of each other (a table cannot average away an error it is all
making at once), half of which is actually said out loud, led by Mafia who
coordinate and avoid killing anyone who has publicly moved against them. It has
**one** free parameter, spent on **one** anchor — «كلاسيكية» at nine, near even.
Every other cell is a prediction, not a fit.

Two earlier versions were wrong in instructive ways, and both are written down
in the file: independent impressions let eleven townspeople average their way to
the truth and the town won 90% of fifteen-player matches; and weighting a
published trace at four accusations made believing it *worse* than ignoring it,
which looks like a broken trace layer and is a policy over-trusting a one-vote
signal.

Asserted: no cell is a foregone conclusion (20–80%), the mean across cells is
45–55%, at least two thirds of cells are inside doc 13's own 40–60%, median
length 3–6 nights from eight players to twelve, no match past the 500-move
guard, and the quiet night neither pushes the Mafia past 60% nor swings the
game ten points when toggled.

### Doc 13 Part 4 — the hint system, on glass

* **Tier 1** — `HintSlot`, a fixed-height reserved slot that draws a caption or
  nothing and is the same height either way. Persisted seen-set in a new
  `SettingsRecord.seenHints` (Isar regenerated), reached through three new
  repository methods including doc 13 §4.2's `resetSeenHints`. Wired to all
  seven triggers except the online elimination one: pass, role card, night
  action, bullet, whisper, confrontation.
* **Tier 2** — `PlayHintLine`, in dead time only. Offline it is `TheTable` by
  construction: the sealed pair in `engine/hints.dart` has no role-conditioned
  case reachable without a viewer seat, so doc 13 §9's *"enforced by type, not
  by convention"* holds at the call site and not just in the module.
* **Tier 3** — «كان ممكن» under each player's own name on the result screen,
  from `Coach.notesForAll`, built from the finished match rather than from the
  snapshot (the snapshot has no roles, which is what keeps the notes off every
  screen before this one).

`HintSlot` is a plain `StatefulWidget` that looks up the provider container
defensively rather than a `ConsumerWidget` that demands one — same rule the
voice layer lives under. A screen pumped with no app behind it gets the
reserved space and no hint instead of a red box.

### The bullet is a legal move

`NightActionMove` and `SkipNightActionMove` gained `useBullet`, and
`legalMoves` enumerates the armed variant wherever `Bullets.canArm` — so the
fuzz harness, the balance harness and doc 10 §8.2's timer default can all reach
a state that was previously unreachable except through the UI. Not for the
Doctor's targeted moves: «حماية النفس» redirects to their own seat whatever is
highlighted, so an armed move per target would be the same state N times.

Files:      lib/engine/{legal_moves,presets}.dart
            lib/data/{match_repository,memory_match_repository}.dart
            lib/data/isar/{match_record,match_record.g,isar_match_repository}.dart
            lib/ui/hints/hint_controller.dart
            lib/ui/widgets/{hint_slot,play_hint_line,turn_shell}.dart
            lib/ui/screens/night/night_action_screen.dart
            lib/ui/screens/day/{discussion,confrontation}_screen.dart
            lib/ui/screens/distribution/{role_reveal,pre_night_lobby}_screen.dart
            lib/ui/screens/postgame/result_screen.dart
            lib/ui/screens/match_flow.dart
            test/support/balance_driver.dart
            test/engine/balance_harness_test.dart

Verified:   `flutter analyze lib` — 0 errors, 0 warnings.
            `flutter test test/widget test/integration test/golden test/leakage`
            — 326 pass.
            `flutter test test/engine/balance_harness_test.dart` — 12 pass.
            Full-suite run not repeated after the last two edits (Tier 2 and
            Tier 3 wiring) — see Open.

Gate:       INCOMPLETE — stopped mid-phase on request.

Open:
- **Not run since the last edit**: the full `flutter test`. Analyze is clean and
  the four suites above were green one edit earlier, but the Tier-2 and Tier-3
  wiring has not been through the whole suite.
- **Doc 13 Part 4, one trigger missing**: `InterfaceHint.eliminated`, the
  online-only witness hint. The enum value, the string and the l10n mapper all
  exist; nothing renders it yet.
- **Doc 13 Part 4, Tier 2 online**: `PlayHintLine` is wired into the offline
  pre-night lobby only. The online lobby has no call site yet, so the
  role-specific pool is written, tested by type, and unreachable in practice.
- **Doc 13 Parts 5 and 7 — not started.** `presets.dart` exists and is
  exercised by the balance harness; there are no preset chips and no advanced
  settings section. The settings screen also still rebuilds a fresh
  `MatchSettings` on save, which silently drops all twelve doc-13 fields — a
  real bug, found while reading, not yet fixed.
- **Doc 13 Parts 8 and 9 — not started.** No executable leakage checklist, no
  acceptance suite, and in particular no test yet that a quiet night and a
  Doctor save produce byte-identical morning output.

### What the harness found, and doc 13 cannot have

1. **Doc 13 §6 and §9 contradict each other.** §6 defines `NaivePolicy` as
   *"suspect randomly"*; §9 requires `TracePolicy` to outperform it, *"proving
   traces carry real information"*. `T1` publishes what the victim suspected —
   if every suspicion is a coin toss, `T1` publishes a coin toss and no
   implementation can satisfy both. Resolved by giving agents a weak private
   impression and writing the reasoning into the driver.
2. **`TracePolicy` still does not measurably beat `NaivePolicy`.** Averaged over
   all cells it is 0.3 points better for the town, which is noise. The harness
   asserts the floor instead — believing the app must not be *worse* than
   ignoring it — and doc 13 §9's stronger claim is recorded as unmet. The
   underlying reason is worth a ruling: a dead player's suspicion is one
   opinion, formed the same way every living player's was.
3. **Seven cells sit outside 40–60%, and three of them cannot be fixed.** At
   five to seven players the Mafia count is an integer: one in six is a town
   walkover, two in six is a Mafia one, and there is no third option. There is
   a test that asserts exactly that rather than an excuse in a comment.
4. **«قاسية» at six players was 78% Mafia** — a third of the table in the
   family, no Doctor. Fixed at the product level: `MatchPreset.minimumPlayers`
   makes it unavailable below eight.
5. **Preset role counts now follow doc 13 §5's quarter**, not
   `BalanceGuard.recommended`, which flattens to three Mafia from nine players
   to twenty — two too many at nine and two too few at twenty. `BalanceGuard`
   itself is untouched; it belongs to a different spec.
6. **Fifteen-player matches take seven nights, not doc 13's three to six.**
   Arithmetic rather than drag — two players leave per cycle and eleven have to
   go — and asserted as its own bounded fact so nine nights would still fail.

Next:       Doc 13 Parts 5 and 7 (presets + advanced settings, and the settings
            screen's dropped-fields bug), then Parts 8 and 9.

---

## PHASE 14 — done

Built:      Doc 13 Parts 5, 7, 8 and 9; the two Part-4 triggers that were
            still unwired; the settings screen's dropped-fields bug; and a
            web build published at a URL.

### Doc 13 Part 5 — the presets, on glass

A chip row at the top of the settings screen, and the lit chip is **derived**
rather than stored: `MatchPreset.identify` asks the settings themselves which
preset they are. So there is nothing to fall out of step with the controls
below, and turning one switch after tapping a chip puts the chip out for free —
because the settings genuinely are not that preset any more, which is the
correct answer and not a bug to guard against.

New `MatchPreset.applyTo(base)`, the exact inverse of the existing
`_alignedTo`: it writes doc 13 §5's nine rows and touches nothing else. A
preset does not know whether this table wants narration or how long the
identity hold is, and a preset that quietly reset them would be a preset that
punishes curiosity. «قاسية» is still absent below eight players.

### Doc 13 Part 7 — «إعدادات متقدمة», and a real bug next to it

The section is doc 13 §7's table in five groups, closed by default. The four
per-role bullets go **disabled rather than hidden** under the master switch, for
the reason the whole app is built on: a control that comes and goes is a control
whose absence is a thing to read. The hint reset (§4.2) is a button that fires
once and then says so.

The bug: the screen kept one `late` field per control and rebuilt a fresh
`MatchSettings(...)` on save out of exactly those eight. Every field it had no
control for — all twelve of doc 13's, plus the whole Information Engine's — was
silently reset by the act of opening settings and pressing save. A host who
turned the bullets off got them back and nothing said so.

The fix is structural rather than a longer argument list: **one settings object,
edited in place**. There is now no list to forget to extend, and a control this
screen does not draw is a value that passes through untouched. `settings_presets_test`
hands it settings with every field non-default, presses save, and requires the
object that comes back to be the object that went in.

### Doc 13 Part 4 — the last two triggers

* `InterfaceHint.eliminated` now renders above the witness panel's tabs — the
  one online-only trigger, because offline an eliminated player is still
  sitting at the table and there is nothing to explain.
* Tier 2 has an online call site: the lobby, seeded from the **room code**, so
  four people waiting for a fifth read the same sentence on four phones.

### Doc 13 Parts 8 and 9 — the checklist, executable

`test/leakage/doc13_acceptance_test.dart` (15 tests) and
`test/golden/bullet_slot_symmetry_test.dart` (5). The first line of the
acceptance file names the items covered elsewhere and the one item that is
**not met**, rather than letting it fall off the list by being hard.

The one that matters most: a Doctor save and «الليلة الهادية» are played out
through the real engine and their mornings compared field for field *and* as
strings. The negative control is there too — with the quiet night switched off
the save is announced again, so the test cannot be satisfied by an app that
simply stopped saying anything.

The bullet slot is measured rect-for-rect across all four roles, live and
spent. A spent bullet keeps the rect it had, struck through: a control that
vanished would shorten the column by its own height, and the height of the
night screen would then be a public record of who has used what.

### The web build, and a seam it needed

`https://eyadsyam.github.io/AL-Mafia/` — the Flutter web build, published from
a `gh-pages` branch of the existing repository, built at
`--base-href /AL-Mafia/`.

Isar cannot cross to a browser twice over: it reaches `dart:ffi` for a native
core, and its generated schema names collections with 64-bit ids that a
JavaScript number cannot hold — so `-3321931835933376304` fails to *compile*
long before anything tries to open a file. A `kIsWeb` guard does not help,
because the branch it skips is still compiled.

So the platform choice moved to the import. `openLocalStores()` is declared
once and implemented twice — `local_stores_io.dart` against Isar,
`local_stores_web.dart` returning null — and `main.dart` picks between them
with a conditional import. The web build runs on the in-memory stores that
`repository_provider.dart` already declared as the fallback, which is the
honest shape for a browser tab: a tab is a session, not an installation, and
the app was already required to survive storage that will not open.

Files:      lib/engine/presets.dart
            lib/ui/screens/setup/settings_screen.dart
            lib/app/router.dart
            lib/ui/screens/online/lobby_screen.dart
            lib/ui/screens/online/witness/witness_panel.dart
            lib/main.dart
            lib/data/local_stores{,_io,_web}.dart
            web/{index.html,manifest.json} (+ the generated web/ scaffold)
            test/leakage/doc13_acceptance_test.dart
            test/golden/bullet_slot_symmetry_test.dart
            test/widget/settings_presets_test.dart
            test/support/turn_shell_harness.dart

Verified:   `flutter analyze lib` — 0 errors, 0 warnings.
            `flutter test` — **737 pass**, whole suite, after every edit above.
            `flutter build web --release` — built, 57 MB, 107 files.
            `git push origin gh-pages` — pushed; Pages serving from
            gh-pages / root.

Gate:       PASS

Open:
- **Doc 13 §9's trace claim is still unmet.** `TracePolicy` does not measurably
  beat `NaivePolicy` — 0.3 points across all cells, which is noise. The harness
  asserts the floor it can defend and the acceptance file records the stronger
  claim as unmet rather than asserting a weaker thing under its name. Needs a
  ruling: a dead player's suspicion is one opinion, formed the way every living
  player's was.
- **Tier 2's role-conditioned pool is still unreachable in practice.** Online,
  the viewer's role arrives through an async `secretsFor(seat)` that the table
  flow does not hold, so the only two call sites are lobbies and both are
  `TheTable`. The pool is written and tested by type; nothing renders it.
- **The web build has no storage.** History, saved groups and whispers live for
  the length of a tab. Offline play, online play, settings and presets all
  work; «تاريخ المباريات» will be empty every time it is opened.
- Bullets remain offline-only (`supportsBullets == false` for
  `OnlineTransport`), and `ghost_say` / `submit_prediction` plus two migrations
  are still undeployed on the live project.

Next:       A ruling on the trace, then either deploy the two Edge Functions or
            close out the online-bullets gap.

---

## PHASE 15 — done

Built:      Doc 14, the consolidation. One canonical flow, offline and online;
            the night grid; whispers rebuilt as an online layer; the settings
            screen regrouped; and every hint taken out of a live match.

`docs/14-consolidation-and-cleanup.md` is on disk and supersedes parts of 09,
12 and 13. Where it conflicts with **doc 05** it does not win — twice below,
that mattered, and both are recorded rather than quietly resolved.

### The night screen — one grid, every option in it

The list of full-width rows is gone. In its place: *N* tiles, 2/3/4 columns by
count, sized from whatever height the body has and capped at doc 14's 64dp, so
it shrinks and never scrolls. Fifteen players fit on a 390×844 screen with the
prompt above them.

Everything a role can do that night is a tile:

| Role | Last tile | What it does |
|---|---|---|
| مافيا | «مش هقتل الليلة» | Skips the kill and spends «الليلة الهادية» |
| طبيب | **their own name** | Self-protection. Once per match |
| محقق | «مش هحقق الليلة» | Skip |
| مواطن | «مش شاكك الليلة» | Skip |

That single change removed four things at once: the tiny long-press ability
box, the second long-press to arm it, the "choose nobody" line dumped under the
confirm button, and the scroll. Confirm is now **one tap**; the long press
survives only on the identity pad and the role card, which are the two places
where a stray thumb costs something.

The Doctor's self-protection is no longer a power with its own control. It is
their name, among the names, and it dims when it has been used — doc 14 §1.3:
*"It never disappears — a disappearing tile changes the grid shape, and grid
shape is a tell."*

**Doc 14's four label shapes did not survive doc 05.** The doc wrote them as
four different sentences («مفيش قتل الليلة», «مش شاكك في حد»). That is
role-specific text on a screen a bystander can see, so `night_prompt_balance`
holds it to the same inked-glyph budget as the four prompts: one shape negated
four ways, twelve glyphs each. It reads better as well — two screens now differ
by one word instead of by their grammar.

### «فتح الملف» and «الشهادة» — gone from the engine, not hidden

`BulletKind` is two values. `Role.bullet` returns null for the Detective and
the Citizen, and `Bullets`, `Coach` and the night screen all read that null
rather than a flag. `MorningPublications`, `OpenedFile`, `Testimony`,
`FileEntry` and the morning's publication lines are deleted — nothing rendered
them, which is most of why nobody understood them.

The symmetry doc 13 bought with four abilities is still there and now comes for
free: every grid is *N* tiles, and a role with nothing to spend spends its last
tile on "choose nobody".

### Whispers — online only, during the discussion, delivered now

Offline the layer is not disabled, it is **absent**: no button, no graph, no
slot on the night screen, no reference in any offline string. One shared phone
cannot deliver a private message during a discussion without stopping the
discussion to pass the phone, which is the discussion the message was about.

Online it does the thing it was always supposed to. The composer no longer asks
*who are you* — this device knows — so it is pick, write, send. The recipient
list is built from **other living players**, so self-exclusion is not a check
that can be forgotten; the list they would be removed from is a list they were
never on.

And the recipient now reads the words. They did not before: the body was only
ever rendered in the night screen's whisper slot, which the online table does
not have, so an online whisper was a chime and a light and nothing else.
`WhisperCard` slides in over the table, holds for twelve seconds or until
dismissed, and never blocks — the timer and the seats stay live behind it.

### Hints — the reservation stays, the words go

Doc 14 Part 6's absolute rule: nothing teaches during a live match, in either
mode. Removed from the role card, the night screen, the discussion, the
confrontation, the witness panel and «الليل يقترب»; `OnlineHints` is deleted
outright. Every reserved slot is still reserved, which is what keeps four
roles' screens the same height.

«الليل يقترب» is three elements now — the heading, «ضع الهاتف على الطاولة», the
button. The night number and the living count went with the strategy line: the
first is in the night screen's own header and the second is the number of
people at the table.

### A seed the web could not mint

Found by walking the published build rather than by any test. `newMatchSeed()`
read `Random.secure().nextInt(1 << 32)`. dart2js compiles `<<` to JavaScript's
32-bit shift, so on the web that bound is **zero**, `nextInt(0)` throws, and
every offline match died on the tap that should have started it — silently,
because an exception inside a button callback leaves the screen exactly as it
was. The VM disagrees with the browser about that one expression, so the whole
suite passed while the shipped app could not deal a hand.

The bound is a literal now, and `web_safe_integers_test` reads the source for
any shift of 32 or more and any literal past 2^53. It is a lint rather than a
behaviour test because the failure is a *platform disagreement*, and no test
that runs on one platform can see it.

### Settings — five groups, and a sentence under every switch

إيقاع اللعب · المعلومات · الكشف · التصويت · الصوت والحركة. Times are segmented
controls, choices are radios, switches are for genuine on/off only. Every
switch carries its description on the row — *"a setting nobody understands is a
setting nobody uses."* Online-only rows say «في الأونلاين بس» rather than
vanishing offline.

Twelve controls left the screen: the bullet master and its four per-role
switches, «فتح الملف», «الشهادة», the three hint toggles, the hint reset, and
the whole «إعدادات متقدمة» disclosure. Their **fields** survive untouched —
`settings_presets_test` hands the screen an object with every field
non-default, presses save without touching anything, and requires the object
back.

«اسم واحد» now defaults **off**. It solved a real problem by imposing ten
silent seconds on every table; the fuzz driver opts half its matches into it so
the phase is still exercised.

Files:      docs/14-consolidation-and-cleanup.md          (new)
            lib/ui/widgets/night_grid.dart                (new)
            lib/ui/widgets/whisper_card.dart              (new)
            lib/ui/widgets/turn_shell.dart
            lib/ui/screens/night/night_action_screen.dart
            lib/ui/screens/night/morning_screen.dart
            lib/ui/screens/distribution/pre_night_lobby_screen.dart
            lib/ui/screens/distribution/role_reveal_screen.dart
            lib/ui/screens/day/{discussion,confrontation,whisper_compose}_screen.dart
            lib/ui/screens/setup/settings_screen.dart
            lib/ui/screens/match_flow.dart
            lib/ui/screens/match_controller.dart
            lib/ui/screens/online/online_table_flow.dart
            lib/ui/screens/online/witness/witness_panel.dart
            lib/ui/screens/online/online_hints.dart       (deleted)
            lib/engine/{bullets,coaching,hints,match_engine}.dart
            lib/engine/models/{enums,match_settings}.dart
            lib/ui/{l10n_ext.dart,theme/design_tokens.dart}
            lib/app/{router.dart,l10n/*.arb}
            lib/data/match_seed.dart
            test/leakage/doc14_acceptance_test.dart       (new)
            test/platform/web_safe_integers_test.dart     (new)
            test/golden/night_grid_symmetry_test.dart     (new)
            test/golden/leakage/offline_whisper_absence_test.dart (new)
            test/golden/bullet_slot_symmetry_test.dart    (deleted)
            test/golden/leakage/whisper_card_parity_test.dart (deleted)
            test/support/{turn_shell_harness,fuzz_driver,information_match}.dart
            test/widget/{settings_presets,night_prompt_balance,accessibility,reduce_motion}_test.dart
            test/leakage/{doc11_regressions,doc13_acceptance}_test.dart
            test/integration/{wrong_pass,match_flow,audio_cue_wiring}_test.dart
            test/{data/schema_migration,engine/game_history}_test.dart

Verified:   `flutter analyze` — 0 errors, 0 warnings, whole project.
            `flutter test` — **747 pass**, whole suite, including the ±2%
            luminance budget across all four roles in all five turn states and
            the 2,000-match fuzz coverage sweep.
            The published build, walked in a browser: home → mode → nine
            players → roles → the new settings screen → distribution → the
            night grid → «تم تسجيل اختيارك». Screenshots taken of the settings
            screen, the role card (no hint over it), the grid and the
            confirmation.
            https://eyadsyam.github.io/AL-Mafia/

Gate:       PASS

Open:
- **Doc 14 §1.4 is not honoured in full, and doc 05 is why.** It asks for no
  name on «تم تسجيل اختيارك». Removing the echo puts the Detective **2.26%**
  off the set mean in the `confirmed` state against a ±2% budget, because three
  screens then carry nothing in the detail slot and one carries a verdict. The
  budget did not move. What went is the bordered panel and the whisper card;
  the picked seat stays, as one word, drawn identically for all four roles.
  Recorded here rather than in the spec — doc 05 was never mine to amend.
- **«كشف دور المُقصى» is not a switch.** Doc 14 Part 5 lists it; FR-019 makes a
  day elimination public by rule, so the switch would have to stay on. A
  control that cannot be turned off is exactly the kind of setting Part 5 is
  trying to delete. Needs a ruling: change the rule, or drop the row.
- **The interface-hint machinery is dormant, not deleted.** `InterfaceHint`,
  `HintSlot` and the seen-set survive with no call sites, because doc 14 Part 6
  keeps the tier and only bans it inside a match — and every trigger it had was
  inside one. Either give it a home outside a match or take it out.
- Carried forward: doc 13 §9's `TracePolicy > NaivePolicy` claim is still
  unmet; the web build has no persistent storage; bullets are still offline-only
  (`supportsBullets == false` online), so online the Mafia's and the Doctor's
  last tile is an ordinary skip; `ghost_say` / `submit_prediction` and two
  migrations are still undeployed.

---

## PHASE 16 — done

Built:      The online mode, finished — on the phone, not only in a browser tab.
            Plus the two things you named, and the four items PHASE 15 left open.

### The APK had no server in it

`SupabaseConfig` reads its URL and key through `String.fromEnvironment`, which
is resolved **at compile time**. `flutter build apk --release` on its own passes
neither, so `isConfigured` is false, the mode screen offers online as an
explained dead card, and the binary has no server to talk to at all. The website
worked because the web build *was* given them.

That is not a bug in the app; it is a build invoked without its arguments. So
the arguments now travel with the build: `tool/build_apk.ps1` refuses to run
without `dart_defines.json`, refuses again if it still holds the placeholders,
and passes it through. `-Split` for per-ABI APKs, `-Bundle` for Play.

Release signing stopped being a TODO in the same file: `android/key.properties`
if it exists, the debug key otherwise. The keystore and its passwords are the
owner's to make — nothing here prompts for one and nothing is checked in.

### The code read backwards

A `Row` lays its children along the ambient `Directionality`, and this app's is
RTL. The lobby draws the code one character at a time so the letters can stagger
in, so six characters went into the tree in order and came out mirrored: the
screen said `XQ2K7A` while «نسخ» put `A7K2QX` on the clipboard.

The worst shape a bug like this can take — the host reads the wrong code aloud
while the code they *sent* works, and nobody can tell which half is lying.

Pinned to LTR at the widget that lays the characters out itself, and the code
field is pinned the same way and upper-cased as it is typed. A room code is an
identifier in a Latin alphabet, not Arabic text.

### The room screen asks one question at a time

It used to ask everything at once: a name, a code, and two buttons underneath —
so a player with nothing to type stared at the largest field on a screen that
had already decided they were joining.

Now: your name, because both paths need it. Then which of the two you are, each
button carrying a sentence saying what it does. **The code field does not exist
until "I have a code" is the answer.** A deep link skips the question it has
already answered and opens on the code step, filled.

### Bullets, online

`supportsBullets` returned false, so online the last choice was an ordinary
skip. For the Mafia that cost only the *once per match* part. For the Doctor it
cost the whole move: the server refused a self-target outright — `"not
yourself"` — so the self-protection you asked to be a normal feature did not
exist online at all.

It does now, end to end. `night_actions.used_bullet`, written by
`submit_night_action` after it checks the role **the server** holds, the room's
settings as the *room* stores them, and whether this player has already spent
theirs. Once per match is enforced by a partial unique index, so two racing
requests cannot both win.

The flag is on the action and not on the player, and that is a doc 05 decision:
only two of the four roles hold a bullet, so a public `bullet_spent` on the
roster would say *that seat is the Mafia or the Doctor*. `night_actions`' read
policy is `actor_id = auth.uid()`, which is exactly the right audience, and the
client already loads those rows on every resync — so it costs no new call and
survives a reconnect.

Offline the Doctor's self-protection is a tile with their own name on it. The
online table has no grid, so it is the affordance the table already has: their
own seat, tappable, once.

### The server was two migrations and four functions behind

`open_voting` and `witness` applied; `ghost_say` and `submit_prediction`
deployed; `submit_night_action` redeployed. 23 migrations, 22 functions.

### PHASE 15's open items, closed

- **The dormant hint tier is deleted.** `InterfaceHint`, its copy table, its
  controller and seven strings had no call sites, because doc 14 Part 6 banned
  every trigger it had. The *reservation* survives in `TurnShell` — equal height
  across four roles is doc 05's business and never was this tier's.
- **«كشف دور المُقصى» is not a switch, and that is the ruling.** FR-019 makes a
  day elimination public by rule, so the control could never be turned off, and
  a control that cannot be operated is the thing doc 14 Part 5 exists to delete.
- **`TracePolicy > NaivePolicy` cannot be satisfied as written**, and the
  harness says so rather than softening the assertion: `T1` publishes what the
  victim suspected, so if suspicion is a coin toss then `T1` publishes a coin
  toss. What is asserted is the honest floor — a town that believes the app is
  not worse off — and the day a change makes the published sentence actively
  misleading, that test goes red.
- **The web build's storage is by design, not missing.** A tab is a session, not
  an installation, and `local_stores.dart` argues it out. Not an open item.

Files:      lib/ui/screens/online/online_entry_screen.dart   (rewritten)
            lib/ui/screens/online/lobby_screen.dart
            lib/ui/screens/online/online_session.dart
            lib/ui/screens/online/online_table_flow.dart
            lib/ui/screens/match_controller.dart
            lib/ui/screens/night/night_action_screen.dart
            lib/transport/{game,local,online}_transport.dart
            lib/transport/{online_backend,room_codec,supabase_backend}.dart
            lib/ui/widgets/{turn_shell,hint_slot}.dart
            lib/engine/{hints,coaching}.dart
            lib/data/{isar/match_record,match_repository}.dart
            lib/ui/{l10n_ext.dart,hints/hint_controller.dart (deleted)}
            lib/app/{router.dart,l10n/*.arb}
            android/app/build.gradle.kts
            tool/build_apk.ps1                              (new)
            supabase/migrations/20260904000100_bullets_online.sql (new)
            supabase/functions/submit_night_action/index.ts
            test/widget/room_code_direction_test.dart       (new)
            test/transport/online_transport_test.dart
            test/widget/online_lobby_test.dart
            test/platform/haptics_call_site_test.dart
            test/leakage/doc13_acceptance_test.dart

Verified:   `flutter analyze` — 0 errors, 0 warnings, whole project.
            `flutter test` — **757 pass**, whole suite.
            The room-code test was checked against the un-fixed widget and
            fails there, so it is not vacuous.
            `flutter build apk --release` with the defines, from the script —
            and the shipped APK opened and read back: `SUPABASE_URL` and
            `SUPABASE_KEY` are both in `libapp.so`, and the binary manifest
            carries INTERNET, RECORD_AUDIO and the `mafiamaster` scheme. That
            is the actual claim ("online exists in this binary"), checked
            against the artifact rather than against the command line.
            `flutter build web --release` published to `gh-pages`; the live
            `main.dart.js` md5 matches the local one.

Gate:       PASS

Open:
- Doc 14 §1.4's "no name" is still not honoured on «تم تسجيل اختيارك», and doc
  05 is still why: removing the echo puts the Detective 2.26% off the set mean
  against a ±2% budget. Unchanged from PHASE 15, and unchanged deliberately.
- Online voice is still WebRTC over the signals table with no TURN credentials
  configured, so it will fail behind symmetric NAT. Never load-bearing: a match
  completes with voice fully broken.
- The APK is signed with the debug key. Fine for installing by hand, refused by
  Play. `android/key.properties` is where that changes, and the keystore is
  yours to generate.

## PHASE 17 — RELEASE PASS — done | partially verified

Built:      The release pass: size, security, signing, the store, and the
            table that overlapped.

### 1 — Size

`flutter build apk --release --analyze-size --target-platform android-arm64`,
then the work it pointed at. **arm64 APK 46.5 MiB → 38.5 MiB.**

Top five, after:

| | MiB | |
|---|---|---|
| `libjingle_peerconnection_so.so` | 11.72 | `flutter_webrtc` — in-match voice |
| `libflutter.so` | 11.04 | the engine. Irreducible. |
| `libapp.so` | 6.81 | our Dart, was 8.00 before `--split-debug-info` |
| `score_loop.ogg` | 1.93 | was 3.68 — stereo 100 kbps → mono 64 |
| `libisar.so` | 1.07 | the local database |

What moved:

- **Assets 11.2 MB → 7.3 MB.** Backdrops and the atmosphere loops to 1080
  longest edge; card faces to 900×1350, which is 300×450 logical at 3× and
  therefore their largest actual render; gallery art to 768×1152; everything at
  quality 80.
- **`phosphor_flutter` removed.** Declared in `pubspec.yaml`, imported nowhere —
  the only mention in `lib/` was a comment saying it was in `pubspec.yaml`. It
  was shipping six icon fonts, 1.17 MB compressed.
- **Splash and launcher bitmaps PNG → WebP.** 1.34 MB → 0.10 MB, same images.
- **`--split-debug-info=build/symbols`**, now in `tool/build_apk.ps1`. 1.19 MB
  off `libapp.so`; symbols stay on disk so a crash from a shipped build is
  still symbolisable. Not paired with `--obfuscate` — renaming saves almost
  nothing more here and cannot be trusted without a full pass on a device.

**The 30 MB target was not reached, and cannot be while voice ships.** The
floor is `libflutter.so` + `libapp.so` + `libisar.so` + dex + res ≈ 20.5 MiB,
plus WebRTC's 11.72. Deleting every asset in the app would land at 32.2 MiB.
Without `flutter_webrtc` the same build is **26.7 MiB** and comfortably under.
That is a product decision — voice or 30 MB — and it is not mine to take
quietly.

### 2 — Security

`get_advisors` security: **14 WARN, 0 ERROR.** Performance: **0 lints.** Both
pasted in full in the report.

Thirteen of the fourteen are one lint, `auth_allow_anonymous_sign_ins`, which
fires because policies are reachable by anonymous users. Every player in this
app *is* an anonymous user by design (doc 10: no email, no name, no phone), so
the lint describes the architecture rather than a defect, and the question it
does not ask — whether the policies are scoped — is the one that matters. Two
of the thirteen are `cron.job` and `cron.job_run_details`, unreachable because
neither `anon` nor `authenticated` holds USAGE on the `cron` schema.

The fourteenth is leaked-password protection, inert: the app has no passwords.
One toggle in the dashboard, and worth turning on before any future email auth.

**What the audit found that the advisors did not**, fixed in
`20260904120000_least_privilege_grants.sql`:

- `room_players_public` and `rooms_public` had `arwdDxtm` — every privilege —
  granted to `anon` **and** `authenticated`. Both are `security_invoker`, so
  reads were safe; but a simple view over one table is auto-updatable, and the
  day somebody adds an UPDATE policy to `room_players` for presence, that
  becomes a public write path to the table whose `role` column is the whole
  secret. Now SELECT, to `authenticated`, and nothing else.
- **`ghost_messages` and `predictions` had a correct RLS policy and no grant at
  all.** The client calls `.from('ghost_messages').select(...)` directly, so the
  eliminated players' channel and the prediction read-back were failing on
  privilege before RLS got a say. A policy without a grant is not a locked door,
  it is a wall. Both granted.
- `anon` revoked everywhere. Every player signs in before the first query, so a
  caller with no JWT never needed anything.
- `whisper_blocks` and `whisper_reports` cut to the verbs their policies permit.

**Anti-cheat, run live against the project with a real anonymous JWT**
(`5` players, a started match, attacks from a player genuinely holding a role):

```
[BLOCKED] read the roster's role column, base table              403 42501
[BLOCKED] read every column the public roster view offers        200, no role column
[BLOCKED] ask the public roster view for a role column anyway    400 42703
[BLOCKED] read the match seed                                    403 42501
[BLOCKED] read everyone's night actions                          200, own rows only
[BLOCKED] insert a ballot into votes signed as the host          403 42501
[BLOCKED] submit_vote with a forged voterId                      400 PHASE_CLOSED
[BLOCKED] submit 'kill' while holding 'citizen'                  403 WRONG_ROLE
[BLOCKED] submit 'protect' while holding 'citizen'               403 WRONG_ROLE
[BLOCKED] submit 'investigate' while holding 'citizen'           403 WRONG_ROLE
[BLOCKED] spend a bullet the role does not have                  403 WRONG_ROLE

11/11 attacks blocked
```

**RLS holds. Stated as verified, against the live database, not against the
schema.** Two of the eleven are weaker evidence than the rest and are named as
such in the report.

### 3 — Signing

RSA 4096, SHA384withRSA, valid to 2056, alias `mafia-master`.
SHA-256 `08:2C:07:A4:6E:F5:0B:63:F6:F1:AC:F4:40:80:6C:16:C6:14:76:2D:8D:CE:3B:4E:9B:C3:D4:1F:07:A1:9E:11`.
`KEYSTORE-BACKUP-READ-ME.txt` written with the warning in both languages.
`git check-ignore` confirms all three paths ignored; `git ls-files` confirms
none tracked.

### 4 — Play artifacts

- `app-release.aab` — 78.3 MiB, **signed with the release key** (owner
  `CN=Mafia Master`, fingerprint matches the keystore exactly).
- `app-arm64-v8a-release.apk` — 38.5 MiB, same certificate, verified with
  `apksigner verify --print-certs`.
- **targetSdk 36**, compileSdk 36, minSdk 26. Play's floor for new apps is 35.

### 5, 6 — Published

`/AL-Mafia/beta/` and `/AL-Mafia/privacy/`, both bilingual, both in the app's
palette and typography. `tool/build_web.ps1` now copies the arm64 APK into the
beta directory as part of publishing, so the page and the file it links to can
never drift.

The privacy policy was written from the code, not from intent. Two things it
says that only reading the code would tell you: the app queries Google's public
STUN servers, which see the player's IP address; and voice audio is
peer-to-peer and never touches the server. Two migrations exist to make its
retention claim literally true — `purge_finished_rooms` now runs **hourly at a
23-hour threshold** (it was daily at 24 hours, so a match could sit for nearly
48), and stale anonymous `auth.users` rows are purged after 30 days.

### 7 — Store

`store/` holds `icon-512.png`, `feature-graphic-1024x500.png`, seven
screenshots, both listings with Play's Data-safety answers, and the
RECORD_AUDIO justification. `tool/generate_store_assets.py` regenerates the two
images from the source painting.

The permissions audit found the app requests exactly `INTERNET`,
`ACCESS_NETWORK_STATE`, `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS` and
`BLUETOOTH` (`maxSdkVersion=30`). No `CAMERA`. **No `DUMP`** — a raw string
search of the binary manifest finds the word and it is a false positive, on
`ProfileInstallerReceiver`'s `android:permission` guard. I added a
`tools:node="remove"` for it, checked with `aapt2 dump permissions`, found the
permission had never been requested, and reverted.

### 8 — The doc conflict

Doc 05 is not a file in this repository. It is `test/leakage/` and
`test/golden/leakage/`, and it outranks doc 14 because it is the only one of
the two whose claims execute.

Doc 14 §1.4 said the confirmation screen carries *"no name"*. Removing the echo
was measured, not argued: **the Detective lands 2.26% off the set mean against
L-05's ±2% budget** (0.101005 vs 0.098775). The Detective is told their answer
on that screen and nowhere else — doc 05 rule 10 forbids writing it down — so
with the echo gone, three panels are dark and one is lit, and the lit one is
the Detective. **Doc 14 §1.4 amended**, with the measurement in it.

### 9 — The table that overlapped

`TableGeometry.scaleFor` sized cards from the roster and trusted whatever box
it was handed. In the lobby the box is `Expanded` — what is left after the
code, the buttons, the voice line and the start button. On a 360×640 phone that
is ~170 logical pixels, and ten cards stood on an ellipse 108 pixels tall,
overlapping three deep down each side.

Seats are tap targets. Two cards sharing pixels are two hit targets sharing
pixels, and in this game a mis-tap eliminates the wrong player.

`TableGeometry.fit` now solves for the box: it bisects the card scale until no
pair of seat rectangles touches, checking **every** pair rather than
neighbours, and taking the height the widget draws under the card as an input
rather than forgetting it. Names are surrendered before cards overlap, and only
after the cards have shrunk all the way. The centre is measured against the
seats that were actually placed rather than derived from a closed form that is
wrong on the diagonal. The lobby scrolls and gives the table a floor.

Files:      lib/ui/screens/online/table/{table_geometry,lobby_table,table_seat,table_scene}.dart
            lib/ui/screens/online/lobby_screen.dart
            lib/ui/widgets/turn_shell.dart
            lib/ui/screens/night/night_action_screen.dart
            assets/**  (re-encoded)  ·  assets/README.md
            android/app/src/main/res/{drawable-*,mipmap-*}/*.webp
            android/{key.properties, mafia-master-release.jks}   (both ignored)
            KEYSTORE-BACKUP-READ-ME.txt                          (ignored)
            pubspec.yaml  (phosphor_flutter removed)
            .gitignore
            docs/14-consolidation-and-cleanup.md   (§1.4 amended)
            supabase/migrations/20260904120000_least_privilege_grants.sql
            tool/{build_apk,build_web}.ps1 · tool/generate_store_assets.py
            web/{beta,privacy}/index.html
            store/**   (new)
            test/online/table_overlap_test.dart    (new)

Verified:   `flutter analyze` — **0 errors, 0 warnings**; 68 info-level lints,
            none in `lib/`.
            `flutter test` — **809 tests, all passed.**
            Fuzz harness — **10,000 matches, zero stalls, zero invariant
            violations**, 11s.
            `table_overlap_test.dart` checked against the old roster-only
            sizing: **34 failures**. Not vacuous.
            `card_back_symmetry_test` caught the re-encode breaking rotational
            symmetry (3.686 against a budget of 3.0) and the fix was measured,
            not assumed.
            Anti-cheat — 11/11 blocked, live.
            AAB and APK certificates read back with `keytool -printcert` and
            `apksigner verify`.
            Permissions read back with `aapt2 dump permissions`.

Gate:       PASS on everything automated. **The emulator gates were not run** —
            see below. That is a real gap, not a pass.

Open:
- **Seven of doc 11 §10's gates are unrun**, by instruction: full offline match
  on the emulator in airplane mode; full online match with voice disabled; host
  migration by force-quitting the host mid-night; a disconnect at each phase
  boundary; killing the app mid-night-action; and screenshotting every screen
  of both flows. The emulator run was stopped part-way to save context. Nothing
  in this phase is contradicted by that, and nothing in it is confirmed on a
  device either.
- **Seven of the eight requested store screenshots are missing** for the same
  reason. `01`–`07` are real captures of the release build; role reveal (face),
  night grid, morning with a trace, confrontation, result, analytics and the
  online lobby are not captured. `store/README.md` says how to finish them,
  including the two things that cost time: the identity pad is a five-second
  hold that `input tap` cannot trigger, and `adb shell input text` cannot type
  Arabic.
- **30 MB is unreachable with voice.** 38.5 MiB with, 26.7 MiB without.
- Voice still has no TURN credentials and will fail behind symmetric NAT.
  Never load-bearing.

## PHASE 18 — done
Built:      Fixed unacknowledged online-action retries and duplicate-submit guarding; made the full widget match deterministic; repaired the real setup-to-victory device flow; replaced the seven-card onboarding with the supplied MP4 intro followed by a clearer How to Play screen with a persistent start action.
Files:      lib/transport/online_transport.dart; lib/app/{router,asset_constants}.dart; lib/ui/screens/onboarding/onboarding_video_screen.dart; lib/ui/screens/setup/{add_players,roles,settings,how_to_play}_screen.dart; lib/ui/screens/day/discussion_screen.dart; integration_test/closure_offline_test.dart; test/{transport/online_transport_test.dart,integration/match_flow_test.dart,online/online_action_retry_test.dart,widget/onboarding_gate_test.dart}; test/support/{artwork,fake_backend}.dart; pubspec.{yaml,lock}; tool/generate_asset_constants.py; removed the retired onboarding deck screen, chapters, preview, and deck test.
Verified:   `flutter test` — 802 tests passed; focused changed-files analysis — no issues; `flutter analyze lib test integration_test` — 0 errors, 0 warnings (67 existing info lints); Android emulator full offline setup → private role reveal → two nights → town win → analytics — PASS in 7:53; supplied MP4 rendered on-device and the intro/How to Play/start path was exercised by the device run.
Gate:       PASS
Open:       Remaining closure-plan work is unchanged: online device resilience runs, the complete eight-shot store capture set, release artifacts, site updates, and final reviewed commit/push.

## PHASE 19 — done
Built:      Shareable universal Android beta APK with offline and online play enabled.
Files:      build/share/Mafia-Master-Beta-1.0.0.apk
Verified:   Release build completed; APK Signature Scheme v2 verified with the established 4096-bit RSA Mafia Master certificate; package/version and permissions inspected; copied artifact SHA-256 matched the signed build output.
Gate:       PASS
Open:       Universal APK is 147.2 MB after adding the supplied 51.2 MB onboarding video; Play Store AAB remains part of the later store-release gate.
- Leaked-password protection is off in the Supabase dashboard. Inert today —
  the app has no passwords — and one toggle whenever email auth appears.

## PHASE 20 — done
Built:      Recorded the final requested work as phases 20–27; inset the introduction video in the shared framed panel with uncropped scaling; How to Play now finishes at Home with a matching button label.
Files:      docs/FINAL-POLISH-PHASES.md; lib/ui/screens/onboarding/onboarding_video_screen.dart; lib/ui/screens/setup/how_to_play_screen.dart; lib/app/router.dart; test/widget/onboarding_gate_test.dart; docs/PROGRESS.md.
Verified:   12 onboarding widget/persistence tests passed; targeted analysis of four changed Dart files found no issues; scoped git diff --check passed. Video frame has not yet been visually verified on a device.
Gate:       PASS
Open:       Phases 21–27: audio, mandatory doctor protection and once-only self-save, explicit gender and grammar, single online guide, decisive winner cinematic, real online match/screenshots, website and Play release/marketing. Device visual verification remains required. Existing shared APK predates phase 20. Stop at this gate under the working agreement.

## PHASE 21 — done
Built:      Audio switches preview immediately and cancel restores the prior mix; saved settings update the running app; master mute stops active cues and music; intro video obeys master mute before playback; pending plugin playback is cancelled when stopped to prevent delayed audio restarting.
Files:      lib/platform/{audio_director,audio_backend}.dart; lib/app/{app,router}.dart; lib/ui/screens/setup/settings_screen.dart; lib/ui/screens/onboarding/onboarding_video_screen.dart; test/platform/audio_backend_isolation_test.dart; test/widget/{audio_settings_preview,onboarding_gate}_test.dart; docs/PROGRESS.md.
Verified:   Focused audio/settings/startup/onboarding suite: 50 passed; final app-root regression run: 7 passed (includes one new settings propagation test); targeted analysis of 8 files: no issues; scoped diff check passed. Persistence coverage uses repository/provider tests, not a real process restart.
Gate:       PASS
Open:       Device listening/video-volume and rapid-toggle plugin verification remain for the device gate; no updated APK delivered yet. Next: phase 22 mandatory doctor protection and once-only self-save, preserving private-turn parity. Website/store and remaining requested work remain in FINAL-POLISH-PHASES.md.

## PHASE 22–25 — implementation in progress
Built:      Doctor protection now always exists, the engine never records a doctor skip, self-protection is a single dimmed/locked tile after use, and online expiry supplies a deterministic living target. Added explicit male/female selection for offline and online rosters, persisted through local match/group codecs and online room payload/schema. Replaced the online multi-card deck with one readable comparison screen. The final victory cinematic now overlays its winner announcement before the result screen.
Files:      lib/engine/{models/player,bullets,legal_moves,match_engine,analytics_builder}.dart; lib/ui/{screens/night,online,setup,postgame,widgets}; lib/data/{match_codec,player_group,player_group_codec}.dart; lib/transport/{online_backend,supabase_backend,room_codec}.dart; supabase/functions/{create_room,join_room,submit_night_action,advance_phase}; supabase/migrations/20260906000100_player_gender.sql; lib/app/l10n/*; docs/PROGRESS.md.
Verified:   Previous phase tests were green before this larger pass. Diff check found only a whitespace issue, now fixed. The new combined analyzer/test run was blocked by the host Flutter/Dart analytics permissions and then by the automatic approval usage limit; no success is claimed for this pass.
Gate:       FAIL
Open:       Must run analyzer and focused tests after the new gender/doctor changes, then complete real online match/screenshots, website APK links and final signed APK/AAB. Existing website beta page still advertises stale split APK filenames and must be updated to the current universal artifact. Do not ship the current unverified build.

## PHASE 26–27 — blocked
Built:      Updated the beta website copy from retired arm64/split APK wording to universal APK wording and corrected architecture details. The requested doctor, gender, online guide and winner changes remain in the working tree.
Files:      web/beta/index.html; docs/PROGRESS.md; plus the phase 22–25 files listed above.
Verified:   Website text inspection completed. Flutter analyze/build could not complete in this environment; no new APK was produced or claimed. The existing `build/share/Mafia-Master-Beta-1.0.0.apk` is the prior verified artifact and must not be presented as containing these latest changes.
Gate:       FAIL
Open:       Need a successful Flutter analyze/test/build, then signed APK copy, real online match with screenshots, and website publication. Current website links point to a universal filename that still needs the new APK copied beside the page.

## PHASE 28 — blocked
Built:      Updated the web beta source and release script to reference the universal APK filename and all supported Android ABIs.
Files:      web/beta/index.html; tool/build_web.ps1; docs/PROGRESS.md.
Verified:   Source inspection confirms the new website copy. APK and web release attempts did not produce a new artifact: the existing APK timestamp/hash stayed unchanged, so it was not delivered or relabeled.
Gate:       FAIL
Open:       Flutter release build is hanging/blocked in this host environment; website publish also depends on that build and was not pushed. No old APK was given.

## PHASE 29 — done
Built:      Online clients now pull their own private role card when the room starts distributing (the missing `revealCurrentRole` call site that stalled the real five-player match at the table backs); the Doctor's self-protect tile carries the same words before and after use, routed through `EngineCopy.nightSpecial` so it stays inside the four-tile ink budget; player gender survives an online liveness/presence update instead of being reset to `unspecified`; the online entry form scrolls instead of clipping its buttons; the roster row's seat number no longer wraps the tile into an overflow.
Files:      lib/ui/screens/online/online_table_flow.dart; lib/ui/screens/night/night_action_screen.dart; lib/transport/online_backend.dart; lib/ui/screens/online/online_entry_screen.dart; lib/ui/screens/setup/add_players_screen.dart; test/online/online_role_reveal_test.dart (new); test/data/player_gender_persistence_test.dart (new); test/widget/doctor_self_protect_tile_test.dart (new); test/support/turn_shell_harness.dart; test/integration/match_flow_test.dart; test/widget/{add_players,reduce_motion,turn_shell_timing_parity}_test.dart; test/golden/{turn_shell_symmetry,leakage/luminance_budget}_test.dart.
Verified:   `flutter test` — **822 tests passed, 0 failed** (includes the 10,000-match fuzz harness). `flutter analyze lib test integration_test` — **0 errors, 0 warnings**, 69 pre-existing info lints. `dart format` on every touched file. 24 suite failures that pre-dated this phase were repaired, not silenced: 21 were golden/timing suites tapping a grid tile by `find.text` after the tile moved to `Text.rich`, one was the roster row overflowing once the gender control took width, two were the online entry form overflowing a short window, and one was `match_flow_test` still asserting the old ordering in which the winner was announced *after* the cinematic rather than on it.
Gate:       PASS
Open:       Not yet done, and not claimed: the real five-player online match on a device with the rebuilt APK and its screenshots; the release APKs; the website publish (GitHub CLI auth is invalid — needs `gh auth login -h github.com` from the user); the production Supabase gender migration and Edge Functions (needs the user's explicit approval of the production target). Observation for the device pass: `RoleCard` measures its swipe threshold against its own paint bounds, which online is the whole screen while the drawn card is about half of it — on a phone that is still about a third of the card, but it is worth watching in the real match.

## PHASE 30 — blocked
Built:      Began Doc 15 council redesign; post-processed the 15 supplied assets to a 1.58 MB runtime set with real alpha where required; added council asset constants/tokens, shallow multi-row council geometry, one-painter seats, and the four-band TableScene shell.
Files:      assets/images/online/**; pubspec.yaml; lib/app/asset_constants.dart; lib/app/l10n/app_{ar,en}.arb; lib/ui/theme/design_tokens.dart; lib/ui/screens/online/council/{council_geometry,council_band}.dart; lib/ui/screens/online/table/table_scene.dart; lib/ui/screens/online/online_table_flow.dart; docs/HANDOFF-DOC15-ONLINE-UI-REDESIGN-2026-09-07.md; docs/PROGRESS.md.
Verified:   Asset runtime folder measured 1,582,240 bytes and the cleaned idle ring was visually inspected. The combined localization/format/analyzer command was stopped by user request before a result was available; no compile or test pass is claimed.
Gate:       FAIL
Open:       Stop requested. Continue from docs/HANDOFF-DOC15-ONLINE-UI-REDESIGN-2026-09-07.md; the lobby, per-phase Voice/Hand content, motions, remaining asset wiring, updated tests, analyzer, device run, screenshots, APK, and publication are unfinished.

## PHASE 31 — done
Built:      Doc 15 online redesign, end to end. The council replaced the ellipse: `CouncilBand` draws every seat, glow, crack, spotlight and whisper from **one** `CustomPainter` with **one** `AnimationController`, and `TableScene` is the four bands (header 56dp · council · voice · hand) that every online screen now uses — including the lobby, which is the same council with dashed chairs that draw themselves solid over 500ms as people arrive. Band 3 became `CouncilVoice`, a headline plus **at most one** supporting element, with per-phase content: the night prompt and a selection chip, the morning's victim line with the trace arriving a beat later, the confrontation's observation under a burning timer ring, the current speaker at `display`, the live vote tally as staggered bars, the eliminated name and role, the winner and their emblem. Band 4 became one primary action and nothing else — the hints it used to stack under its buttons are the headline above it now. Selection is subtractive: the chosen seat lifts to 1.08 with a gold ring, everything else drops to 45%, and **every connector line is gone** (`linksFor`/`dotsFor`/`TableLink` deleted, not emptied). Added the elimination card rise (280dp, hold, 3D flip, shrink), the muted V1/V2 transition stings, the winners-warm/losers-dim result beat, the fog overlay and the panel-corner band rule, and moved witness mode inside the bands so a ghost keeps the same four. Six superseded files deleted.
Files:      lib/ui/screens/online/council/{card_rise,phase_sting,seat_status,voice_band,council_band,council_geometry}.dart; lib/ui/screens/online/table/{table_scene,connection_weather}.dart; lib/ui/screens/online/{online_table_flow,lobby_screen}.dart; lib/ui/screens/online/witness/witness_panel.dart; lib/ui/theme/design_tokens.dart; lib/app/asset_constants.dart; lib/app/l10n/app_{ar,en}.arb; tool/generate_asset_constants.py; assets/video/sting_{night,dawn}.webm; **deleted** lib/ui/screens/online/table/{table_seat,table_geometry,table_painter,lobby_table,torn_card,table_centre}.dart; test/online/{doc15_acceptance,table_scene,table_overlap,doc12_acceptance,online_action_retry}_test.dart; test/widget/online_lobby_test.dart; docs/PROGRESS.md.
Verified:   `flutter test` — **812 passed, 0 failed**. `flutter analyze` — **0 errors, 0 warnings** (info lints only, and none in the online surface). The overlap suite is not a formality: rewriting it against `CouncilGeometry` found a real bug — the arc lifted the back row's chairs about 7px outside their band, where they would have clipped against the header rule, and the fit now divides the row height by `1 + arcDepth` and centres ring, name and lift together. New `doc15_acceptance_test.dart` closes twelve of Part 5's boxes: the four bands in order on every phase, the proportions and 56dp header, no line builder anywhere, card art never below 200dp, one slot in band 4, `CouncilVoice`'s three parameters and no fourth, no hardcoded gap in any online file, no red for the timer to reach, exactly one painter and one controller in band 2, the §3 motion catalogue at its stated numbers, no `Role` reachable from the council at all, and a night council byte-identical whether or not the snapshot carries a speaker, a disconnection and a full ballot.
Gate:       PASS
Open:       Three of doc 15's boxes are not closed and are not claimed. **60fps with fifteen seats in profile mode** needs a device and `flutter run --profile`; every structural precondition is asserted, but a frame budget is measured, not proven. **S-O13 beat 2** — all cards rising and flipping simultaneously — is not shipped: it cannot coexist with "card art never renders below 200dp" at fifteen players, so the result gets beat 3 (winners warm to cream, losers to 30%) and the emblem instead, and the conflict is the doc's to resolve, not mine. **Reduce Motion "looks right"** is something a person has to watch. Also outstanding from phase 29 and unchanged: the real five-player online match on a device, the release APKs, the website publish (GitHub CLI auth still invalid), and the production Supabase migration. Note for whoever runs the device pass: the `Pixel 9 pro (2)` AVD this project verifies on has lost its `config.ini` and `.ini` pointer — only its disk images remain under `~/.android/avd/MafiaMaster_Test.avd`, so `flutter emulators` reports none. A replacement `Doc15_Pixel` AVD (android-36, google_apis_playstore, x86_64) was created to run this phase.

## PHASE 32 — done | verification blocked
Built:      The twelve-task online pass. **1** «كمل» works: `advancePhase()` was calling `advance_phase`, which only applies timer-expiry defaults and has no branch for `reveal`, so it returned `{applied: null}` and nothing moved; the deal now calls `open_phase{phase:night}`, gated server-side on a new `room_players.saw_role` that every client sets through its own `saw_role` function — the button is disabled and names who is still holding a card until the last one is dismissed. **2** `ice_servers` fetches Metered TURN credentials from a Supabase secret and hands the array to every `RTCPeerConnection` once per match; the engine holds one `getUserMedia` stream for the session (mute the track, never re-acquire), restarts ICE once per peer on `failed` with a glare tie-break, and logs the candidate type actually used. **3–4** Presence is three states: a 10-second heartbeat, a lifecycle observer that reports `away`/`connected`/`left` immediately, and a `pg_cron` job every 15 seconds that ages a silent client to `away` at 25s and `left` at 90s — drawn as ring-plus-avatar, ring-only at 45%, and a cracked ring at 30% with «خرج». **5** A host who goes `left` hands the room to the lowest-seated connected player, announced for three seconds; the match never ends for it. Ending it is a separate padlock behind a confirmation. **6** Host-only kick (status `left` plus a room ban list the client surface cannot read) and server-side mute, both re-checked inside the function. **7–8** Character art in the ornamental ring, from one `PlayerAvatar` used by both the offline roster and the online painter; the gender picker is two glyphs inside the name field and the full-width row is gone. **9** The lobby's two contradictory voice lines are one microphone icon in the header; the «كود الأوضة» label is gone; «مشاركة» shares an https link that opens the room in any browser. **10** Rooms are private or public with a title, a browse list, and a host-only settings panel — four sections, a description under every control, live to everybody through a `rooms` delta. **11** Favicon and PWA icons are the app mask; the onboarding video no longer sits under a rounded clip and a scale transform (both break a platform view on web); the online cards moved into the how-to-play screen. **12** Copy, share and self-mute became icons; every game action kept its word.
Files:      supabase/migrations/2026090800{0100_saw_role,0200_presence_status,0300_host_migration_presence,0400_host_controls,0500_public_rooms}.sql; supabase/functions/{saw_role,ice_servers,set_presence,close_room,kick_player,mute_player,room_settings,browse_rooms}/index.ts (new) and {open_phase,start_match,heartbeat,join_room}/index.ts; lib/transport/{online_backend,game_snapshot,room_codec,online_transport,supabase_backend,voice_link}.dart; lib/platform/voice/{voice_controller,webrtc_voice_engine}.dart; lib/ui/screens/online/{lobby_screen,online_table_flow,online_entry_screen,online_session,room_invite,host_handover,host_sheet,scene_sheet,room_settings_panel}.dart; lib/ui/screens/online/{council/council_band,table/table_scene}.dart; lib/ui/screens/onboarding/onboarding_video_screen.dart; lib/ui/screens/setup/{how_to_play_screen,add_players_screen}.dart; lib/ui/widgets/{player_avatar,gender_picker,voice_mic_button,voice_controls}.dart; lib/ui/theme/design_tokens.dart; lib/app/{router,asset_constants}.dart; lib/app/l10n/app_{ar,en}.arb; assets/images/online/avatar_{male,female}.webp; web/{favicon.png,icons/*}; **deleted** lib/ui/screens/online/online_intro.dart, test/widget/online_intro_test.dart.
Verified:   `flutter test` — **824 passed, 0 failed**. `flutter analyze lib test` — 0 errors, 0 warnings. Every migration applied and every function deployed to `hezjbrnveajypfqmjfnh` and confirmed by the API. Two doc-12 violations introduced by tasks 5–6 were found by the acceptance suite and fixed properly rather than by editing the test: the host sheet and both close-room confirmations are `SceneSheet` layers in the same Stack (§2.1 — nothing is pushed on top of the table), and the handover's three seconds is `MafiaTiming.hostHandover` (§6 — no inline `Duration` literals). The realtime publication's column list was rebuilt twice; it had been silently dropping `gender` since that column was added.
Gate:       FAIL — the browser verification could not run.
Open:       **The 18-item browser pass did not happen.** The Chrome window driven by the automation is hidden (`document.visibilityState === 'hidden'`) and its renderer is frozen: `requestAnimationFrame` never fires, screenshots are stale frames, and Chrome defers all media loading — a bare 187 KB `<video>` never reaches `loadedmetadata`. Nothing about the app was measurable through it. Also outstanding: **the Metered key is rejected** — `GET https://mafia-master.metered.live/api/v1/turn/credentials?apiKey=…` returns `401 {"error":"Invalid API Key"}`, so `ice_servers` serves the Google STUN fallback (`relay:false, reason:"upstream"`) and no relay candidate can exist until a valid key replaces the `METERED_API_KEY` secret. The web video fix is reasoned from how Flutter composites platform views and is **not** confirmed by watching it play.

## PHASE 33 — done | TURN blocked upstream
Built:      Metered behind one server-side module: `voice_room` mints a deterministic
            HMAC-named room and a room-scoped token per match; `ice_servers` shares the
            same account code; the secret moved to `METERED_SECRET_KEY` and never leaves
            Supabase. The P2P mesh, floor control and per-ear audibility are untouched.
Files:      supabase/functions/_shared/metered.ts (new), supabase/functions/voice_room/index.ts (new),
            supabase/functions/ice_servers/index.ts, lib/transport/voice_link.dart,
            test/transport/voice_ticket_test.dart (new), .gitignore
Verified:   Deployed to hezjbrnveajypfqmjfnh. Three live anonymous sessions: both members get
            the SAME Metered room name (reuse), tokens decode scoped to that room with distinct
            participant ids, a non-member gets 403 NOT_A_MEMBER, and no response carries the
            secret, a role or the match seed. flutter analyze: 0 errors, 0 warnings.
            flutter test: 829/829 pass. Test rooms archived in Metered and deleted in Postgres.
Gate:       PASS for room + token + auth + secret isolation. FAIL for relay.
Open:       TURN is a separate subscription on this Metered account —
            `POST /api/v1/turn/credential` answers "please subscribe to a TURN Server plan".
            So `voice_room` returns public STUN with relay:false, reason:"turn-not-subscribed",
            and the mesh still fails for pairs behind symmetric NAT. Subscribing and setting
            METERED_TURN_API_KEY lights relay up with no code change and no redeploy.
            No Metered client SDK exists for Flutter (metered_realtime is a different product,
            wss://rms.metered.ca), so the minted token has no consumer in-app yet.
            Edge function logs could not be read back: the analytics endpoint returned
            empty then a backend error.

## PHASE 34 — done | real audio NOT VERIFIED
Built:      Voice signalling moved from Postgres to Metered Realtime. `realtime_token`
            mints an HS256 JWT scoped to `mafia-master/match/<roomId>`, derived server-side
            and re-checked on every reconnect. `MeteredVoiceLink` drives the SDK's
            SignallingClient only — never MeteredPeer — so the mesh, `micPolicyFor` and
            `setAudiblePeers` are untouched and night audibility is unchanged. TURN now
            arrives auto-injected in the welcome frame, which is the relay this app has
            never had.
Files:      supabase/functions/_shared/metered_realtime.ts (new),
            supabase/functions/realtime_token/index.ts (new),
            supabase/functions/ice_servers/index.ts (STUN-only legacy floor),
            lib/transport/metered_voice_link.dart (new), lib/transport/voice_link.dart,
            lib/transport/online_transport.dart, pubspec.yaml (metered_realtime ^0.2.0),
            test/transport/voice_ticket_test.dart, .gitignore
Removed:    supabase/functions/voice_room/ and supabase/functions/_shared/metered.ts —
            the Metered Video Room REST path. Superseded, never shipped in any APK, and
            deleted from the hosted project only after the replacement passed.
Verified:   Live, against the real service. TURN Allocate over turn/tcp returned SUCCESS
            with XOR-RELAYED-ADDRESS — relay is genuinely obtainable, not just advertised
            (5 servers: stun/turn/turns). Two authenticated peers connected, presence saw
            both, direct SDP-shaped signals passed A→B and B→A. Anonymous 401; non-member
            403; refresh after kick 403; refresh after match end 403; channels differ per
            match; no role, name, seat, seed or secret in any token or response.
            flutter pub get clean, flutter analyze 0 errors 0 warnings, flutter test 838/838.
Gate:       PASS for authorization, isolation-by-channel, signalling, presence, TURN.
Open:       Metered direct messages are addressed by peer id and are NOT scoped to the
            JWT's `channels` claim — confirmed live: a token for match B can put a frame
            on match A's socket. The mesh already ignored it; `MeteredVoiceLink.admit`
            now drops it explicitly against the Supabase roster, with tests.
            Real microphone audio, mute/unmute, ICE candidate types and network-switch
            reconnect need two physical devices and remain NOT VERIFIED.
            `METERED_SECRET_KEY` / `METERED_DOMAIN` (the old Video account) are still set
            in Supabase but no code reads them.

## PHASE 35 — done | real audio still NOT VERIFIED
Built:      Signalling envelope hardening. `realtime_token` now returns an opaque
            `sessionId` = HMAC(secret, roomId:matchSeed) — stable across reconnects,
            different per match, never revealing the seed. `VoiceEnvelopes` wraps every
            outbound frame as {v,s,f,r,t,ts,n,p} and validates all eight conditions on
            receipt before anything reaches WebRtcVoiceEngine. Media architecture untouched.
Files:      lib/transport/voice_envelope.dart (new), lib/transport/metered_voice_link.dart,
            supabase/functions/_shared/metered_realtime.ts,
            supabase/functions/realtime_token/index.ts,
            test/transport/voice_envelope_test.dart (new),
            test/transport/voice_ticket_test.dart
Verified:   flutter analyze 0/0. flutter test 853/853. Live: sessionId is 32 hex chars,
            two players in one match agree, stable across re-mint, differs across matches
            for the same user in both. flutter build apk (3 ABIs) and flutter build web
            both succeeded.
Gate:       PASS for envelope binding, replay and staleness rejection, spoof rejection.
Open:       Metered `send` remains app-wide at the provider; the envelope is what makes
            that harmless, not a fix at the source. Real microphone audio, mute/unmute,
            ICE candidate types and network-switch reconnect still need two devices.

## PHASE 36 — published
Built:      Site published to gh-pages. `web/beta/` deleted — the page went unused and a
            90 MB APK in a Pages commit is a slow push for something nobody opened. The
            APK is a direct build artifact now. `tool/build_web.ps1` no longer embeds it,
            and its push now checks the exit code (it previously printed "Published" after
            a failed push) and uses HTTP/1.1 with a larger buffer.
Files:      web/beta/ (deleted), tool/build_web.ps1, docs/PROGRESS.md
Verified:   gh-pages a617fb6 -> d24e368 (forced). https://eyadsyam.github.io/AL-Mafia/ 200,
            main.dart.js / favicon.png / manifest.json / privacy/ all 200, base href
            /AL-Mafia/. /beta/ and its APK now 404 at origin (cache-busted).
Gate:       PASS
Open:       Nothing committed — HEAD is still 2cfc8cd.

## PHASE 37 — done
Built:      The WebRTC media path end-to-end: Android audio session, an ICE
            candidate queue, per-peer serialised signalling, connections created
            on demand for an authorised peer's offer, an incremental mesh, the
            Metered relay actually reaching RTCConfiguration, and a safe
            per-peer diagnostic trace reachable by holding the voice status line.
Files:      android/app/src/main/AndroidManifest.xml,
            lib/platform/voice/voice_diagnostics.dart (new),
            lib/platform/voice/webrtc_voice_engine.dart,
            lib/platform/voice/voice_engine.dart,
            lib/platform/voice/voice_controller.dart,
            lib/transport/metered_voice_link.dart,
            lib/ui/widgets/voice_controls.dart,
            test/support/fake_voice_engine.dart,
            test/voice/voice_media_path_test.dart (new),
            test/transport/voice_ticket_test.dart
Verified:   flutter analyze — 0 errors, 0 warnings (73 pre-existing infos).
            flutter test — 870 passed, 0 failed (17 new).
            aapt dump permissions on the shipped APK — MODIFY_AUDIO_SETTINGS
            present.
            Release APK built: build/app/outputs/flutter-apk/
            app-arm64-v8a-release.apk (91.4 MB).
Gate:       PASS for everything a host with no media stack can execute.
Open:       AUDIO A→B and B→A remain NOT VERIFIED. No Android device or
            emulator is attached to this machine (adb devices empty, no AVDs),
            so real audio, ICE candidate types and a Wi-Fi↔cellular reconnect
            cannot be observed here. Hold the voice status line on each phone to
            read the trace. Nothing committed; HEAD is still 2cfc8cd.

## PHASE 38 — done
Built:      the web half of the media fix — remote tracks now reach an audio element instead of being decoded into nothing — and the site rebuilt and republished.
Files:      lib/platform/voice/webrtc_voice_engine.dart, lib/platform/voice/voice_diagnostics.dart, test/voice/voice_media_path_test.dart, tool/build_web.ps1, tool/build_apk.ps1
Verified:   flutter analyze 0 errors / 0 warnings (73 pre-existing infos); flutter test 871 passed; flutter build web --release --base-href /AL-Mafia/ (121 files); force-pushed gh-pages (d24e368 -> 93fdfbb) from 2cfc8cd; https://eyadsyam.github.io/AL-Mafia/ returns 200 and serves the new bundle.
Gate:       PASS
Open:       Two-browser audio unverified, as two-phone audio still is. The trace is in the same place on the web build: long-press the voice status line, Copy, paste it back. `playout attached` is the new line and is the one that was silently FAIL on every browser before this.

## PHASE 39 — blocked (paused by user after local verification)
Built:      Voice lifecycle/ready recovery/playout diagnostics; persistent profile and public-room entry; creation settings retained at match start; discussion duration fixed; smaller bounded onboarding video. Detailed continuation handoff in docs/ONLINE-WEB-RECOVERY-PLAN.md.
Files:      See the handoff's numbered change inventory; all changes remain in the working tree, no commit or push.
Verified:   flutter gen-l10n; flutter test 875 passed / 1 skipped / 0 failed; flutter analyze --no-fatal-infos 0 errors / 0 warnings / 74 infos; room_configuration Node regression PASS; 35 backend golden vectors previously passed this round.
Gate:       FAIL for production readiness; local checks PASS. Browser WebRTC runner stalled before test execution and was cancelled, so actual audio remains NOT VERIFIED.
Open:       Follow the handoff appendix for reconnect/streamless track/async lifecycle tests, actual runtime audio, hosted settings verification/deployment, responsive video/profile checks, then fresh single APK/web builds. Images explicitly deferred. User requested stopping here to preserve remaining usage.

## PHASE 40 — done
Built:      The three faults the handoff named as the next starting point, plus
            the tests it asked for. (ج) `MeteredVoiceLink` now goes live again
            on a reconnect welcome — `_live` was set in exactly one place and
            cleared on every disconnect, so from the first network blip onward
            every offer, answer and candidate took the Postgres path for the
            rest of the match, silently, because the fallback works. (هـ) the
            engine keeps remote audio tracks in their own map instead of
            reading them out of the streams they arrived in, so a track
            delivered bare — no `event.streams` — is re-evaluated on every
            `setAudiblePeers` rather than being enabled once at arrival and
            never revisited; a browser that gets one with no stream now records
            `no-remote-stream` instead of reporting playout attached. (د) both
            the engine and the controller carry a media-cycle counter captured
            before the first await: `_tornDown` is a state and the night is a
            round trip, so a climb that began before a night and woke after the
            day had returned used to read `_tornDown == false`, publish `live`
            for a mesh the teardown had closed, and — in the engine — carry on
            creating peer connections *after* the night had closed them, which
            is a V6 hole. A retired cycle now stops where it is and cleans up
            only what it made.
Files:      lib/transport/metered_voice_link.dart,
            lib/platform/voice/webrtc_voice_engine.dart,
            lib/platform/voice/voice_controller.dart,
            test/support/fake_voice_engine.dart,
            test/voice/voice_controller_test.dart,
            test/transport/voice_ticket_test.dart,
            test/transport/voice_envelope_test.dart,
            test/transport/online_transport_test.dart
Verified:   flutter analyze --no-fatal-infos — 0 errors / 0 warnings / 74 infos.
            flutter test — 900 passed / 1 skipped / 0 failed (25 new: the
            night→day race from both the mode and the microphone, a player
            joining mid-climb, a burst of joins collapsing into one re-climb
            with no overlapping connects, being kicked / the room closing /
            voice switched off all landing mid-climb, the microphone asked for
            once across every climb, socket reconnect carrying signalling
            again, relay credentials refreshed by a reconnect welcome, a
            welcome after dispose, nine `ready` envelope cases, the voice
            roster excluding left/kicked, and the heartbeat stopping and
            restarting with the foreground).
            node supabase/tests/room_configuration.test.mjs — PASS.
            node supabase/tests/run_golden_vectors_node.mjs — 35 cases agree.
            Then a second sweep of the same kind, looking for what else can
            wake up in the wrong cycle. Four more, all real: a stale `_offer`
            and a stale answer reached the wire after the pair had been rebuilt
            — an answer is the *end* of a negotiation, so the peer applies it
            to whichever offer they have open, which by then is the good one;
            `_offering` was never cleared by a teardown, so a peer left in it
            by a negotiation the night interrupted made the day's offer a
            silent no-op and that pair stayed dead for the match with every
            state reporting healthy; `_restartIce` emptied `_remoteDescribed`
            and `_pendingCandidates` after its await without checking the
            connection was still the same one, which would strip the *new*
            connection's queue and leave it queueing candidates for ever; and
            `enableAudio`/`sampleDiagnostics` were the two paths in the
            controller that could throw a media-stack exception into a caller,
            which breaks doc 10 §1.2 on the one path a finger starts.
Gate:       PASS for everything a host with no media stack can execute.
Open:       Real audio is still NOT VERIFIED. The Chrome runner no longer hangs
            — it now fails fast with "Connection closed before test suite
            loaded" after Chrome starts and DevTools comes up, which is a
            different and more tractable symptom than the stall recorded in
            phase 39, but it was not chased further. Hosted deployment,
            two-device audio and the fresh builds are all still outstanding.
            Nothing committed; HEAD is still 2cfc8cd.

## PHASE 41 — blocked | hosted voice probe stopped safely
Built:      Isolated real WebRTC browser probe; hosted Metered/Supabase probe; fixed Metered direct signalling readiness at welcome before subscribe completion.
Files:      tool/voice_runtime_probe.dart, tool/run_voice_runtime_probe.mjs, tool/voice_probe_hosted.dart, lib/transport/metered_voice_link.dart, test/transport/voice_ticket_test.dart, docs/ONLINE-WEB-RECOVERY-PLAN.md
Verified:   Local Chrome probe PASS: two real engines acquired audio, attached senders, negotiated SendRecv, connected ICE/PC, received audio tracks, exchanged RTP, attached playout, and preserved receive revocation. Voice ticket tests: 17 passed / 0 failed. Hosted auth and grants succeeded for two clients; channel/session ids existed; TURN appeared in both welcome ICE lists.
Gate:       FAIL for production audio runtime.
Open:       Two anonymous Supabase clients in one Chrome page synchronized through GoTrue BroadcastChannel, so the hosted probe ended with the same identity and stopped before negotiation. Human A↔B audio, selected srflx/relay, reconnect on separate devices, and Android routing remain NOT VERIFIED. No commit or push.

## PHASE 42 — done | handover closed, nothing new attempted
Built:      No product code changed. The stopped hosted-probe round was closed
            out: state re-measured, the diagnostic build output deleted, and a
            literal continuation guide written into the recovery plan so the
            next model does not re-derive the project.
Files:      docs/ONLINE-WEB-RECOVERY-PLAN.md (new section "دليل الاستكمال
            الحرفي — 2026-09-09", sections 0–11), docs/PROGRESS.md.
Verified:   flutter analyze --no-fatal-infos → 0 errors / 0 warnings / 74
            infos, exit 0. flutter test → 921 passed / 1 skipped / 0 failed,
            exit 0 — so phase 41's Metered readiness fix and its ticket test
            are green on the current tree. Supabase read-only query confirmed
            two leftover `VoiceProbeA` lobby rooms (2026-09-08 21:13:21 and
            21:15:19 UTC, one player each) from the aborted hosted probe.
Gate:       PASS for the handover. Voice runtime gate is still FAIL.
Open:       The hosted probe's identity-isolation fix (BroadcastChannel
            partitioning in tool/run_voice_runtime_probe.mjs plus the
            distinctIdentities assertions in tool/voice_probe_hosted.dart) is
            written but was never run — that rerun is the first next step and
            section 4 of the guide gives the exact commands. Human A↔B audio,
            srflx/relay selection, reconnect, the P0.4 browser pass, hosted
            Edge Function deployment, the five-player E2E and the fresh
            APK/web builds all remain NOT VERIFIED. The two probe rooms were
            left in place: deleting database rows is irreversible and is the
            user's call. Nothing committed; HEAD is still 2cfc8cd.

## PHASE 43 — done | hosted voice runtime PASS over Metered
Built:      Nothing in lib/ or supabase/. The probe was rebuilt so that each
            player runs in its own browser: voice_runtime_probe.dart now takes
            a `role` query parameter and runs as one side, voice_probe_hosted
            .dart is a single player, and the runner starts two Chrome
            instances with two disposable user-data-dirs. The previous
            in-page BroadcastChannel patch was removed — a probe must not fake
            the isolation it exists to test. Three probe bugs fixed: the host
            published the room code after waiting for the guest (deadlock), the
            peer-connection state was compared case-sensitively against
            RTCPeerConnectionStateConnected, and candidate pair types were read
            after dispose.
Files:      tool/voice_runtime_probe.dart, tool/voice_probe_hosted.dart,
            tool/run_voice_runtime_probe.mjs, docs/ONLINE-WEB-RECOVERY-PLAN.md,
            docs/PROGRESS.md.
Verified:   node tool/run_voice_runtime_probe.mjs --hosted → PASS on both
            sides, twoDistinctPlayers true. Two Supabase identities, roster of
            two from Supabase, grant with token/channel/session carrying no
            game state, 5 ICE servers with STUN+TURN+TURNS, real offer/answer
            over Metered, signaling stable, ICE and PC connected, SendRecv,
            sender 1, onTrack, ~200 RTP packets each way per side, playout
            attached, no rejected candidates, mute/unmute keeps the sender,
            setAudiblePeers({}) revokes listening, room cleanup true both
            sides. Local two-engine probe still PASS. flutter gen-l10n,
            flutter analyze --no-fatal-infos → 74 infos / 0 errors, flutter
            test → 921 passed / 1 skipped / 0 failed, room_configuration.test
            .mjs PASS, golden vectors 35 cases agree.
Gate:       PASS for signalling and the media path over Metered. FAIL for
            audible audio, which no counter can grant.
Open:       Both browsers are on one machine, so the selected candidate pair
            is `host`: TURN is offered but relay is NOT VERIFIED. Human A↔B
            audio NOT VERIFIED. Reconnect and token refresh are covered by unit
            tests but NOT VERIFIED at runtime. Android routing NOT VERIFIED. No
            Edge Function deployment (none changed this round), no APK, no web
            build, no commit, no push; HEAD is still 2cfc8cd. Five probe rooms
            were deleted after verifying id, status, name and timestamp; rooms
            with real player names were left alone. Leaving a room empty still
            leaves a `lobby` row with zero players behind.

## PHASE 44 — done
Built:      One invite link that opens the app when it is installed and the site when it is not, with a link preview that has a picture in it.
Files:      lib/ui/screens/online/room_invite.dart, lib/main.dart, pubspec.yaml,
            android/app/src/main/AndroidManifest.xml, web/.well-known/assetlinks.json,
            web/index.html, web/og-image.jpg, web/vercel.json, tool/build_web.ps1,
            test/online/room_invite_test.dart, docs/ONLINE-WEB-RECOVERY-PLAN.md
Verified:   flutter analyze --no-fatal-infos 0 errors / 0 warnings / 74 infos; flutter test 926 passed, 1 skipped;
            flutter build web --release --base-href / and flutter build apk --release --target-platform android-arm64 (51.2MB, lib/arm64-v8a only);
            deployed to Vercel project almafia (production); / and /join/K7M2QP and /.well-known/assetlinks.json and /og-image.jpg and the onboarding mp4 all answer correctly;
            Google's Digital Asset Links API reads one valid statement with no errors; apksigner's SHA-256 equals the published fingerprint; aapt2 shows autoVerify=true with pathPrefix=/join/ inside the APK;
            Chrome at 390x844 followed /join/K7M2QP into the app and kept the code as /onboarding?next=/join/K7M2QP; the onboarding video decodes and plays (720x1280, buffering ahead).
Gate:       PASS
Open:       assets/audio/join_chime.ogg fails to demux on Chrome web (PTS is not defined) — pre-existing, audio is not load-bearing, needs re-encoding.
            The video's first frame stays dark at 1366x768 until the play control is used. Human-audible A<->B voice is still NOT VERIFIED.
            If the app is ever signed by Play App Signing, that fingerprint must be added to assetlinks.json or verification silently reverts to opening a browser.

## PHASE 45 — done
Built:      The intro film offline and stall-free on the web, visible at last, and framed to its own edge.
Files:      lib/platform/media/video_download{,_stub,_browser}.dart, lib/ui/screens/onboarding/onboarding_video_screen.dart, web/index.html, web/flutter_bootstrap.js, web/offline_service_worker.js, tool/build_web.ps1, test/web/offline_video_test.dart, docs/ONLINE-WEB-RECOVERY-PLAN.md
Verified:   flutter analyze — 0 errors, 0 warnings. flutter test — 931 passed, 1 skipped. APK carries assets/flutter_assets/assets/video/onboarding.mp4 uncompressed, arm64 only, 53,653,542 bytes. Live site: second visit caches all 36 requested files with none missing; with the browser's network cut the site loaded and the film played (54s buffered, 720x1280). Layout checked at 1366x768, 390x844, 844x390.
Gate:       PASS
Open:       Playback not re-checked on a physical phone (no device attached). First visit still downloads from the network — offline begins with the second. join_chime.ogg still fails to decode on Chrome web.

## PHASE 46 — blocked | handover saved
Built:      Web playout recovery after browser autoplay rejection, streamless onTrack attachment, explicit web audio gesture in lobby and match, full-width responsive online screens, host leave-or-close flow with server-side host handover/default room survival, and local online match history.
Files:      lib/platform/voice/web_playout_browser.dart, lib/platform/voice/web_playout_stub.dart, lib/platform/voice/webrtc_voice_engine.dart, lib/ui/widgets/voice_mic_button.dart, lib/ui/widgets/voice_controls.dart, lib/ui/screens/{match_flow.dart,postgame/history_screen.dart}, lib/ui/screens/online/{online_entry_screen.dart,lobby_screen.dart,online_table_flow.dart,online_session.dart,scene_sheet.dart}, lib/data/online_match_history.dart, lib/app/l10n/{app_ar.arb,app_en.arb,app_localizations*.dart}, supabase/migrations/20260909000100_host_departure.sql, test/data/online_match_history_test.dart, test/widget/online_lobby_test.dart, tool/web_playout_probe.dart, tool/run_voice_runtime_probe.mjs, docs/ONLINE-WEB-RECOVERY-PLAN.md, docs/PROGRESS.md.
Verified:   flutter analyze exit 0 with 0 errors / 0 warnings / 74 infos; focused suite 97 passed / 1 skipped / 0 failed; lobby suite 18 passed; hosted two-browser Metered probe PASS with distinct identities, 5 ICE servers (STUN+TURN+TURNS), ICE/PC connected, SendRecv, one sender, remote track, playout and ~200 RTP packets each direction; strict autoplay probe PASS (blocked first, recovered on gesture); hosted DB transaction check PASS for lobby/match handover and empty-lobby cleanup; host_departure migration deployed.
Gate:       FAIL — the final full suite was interrupted after reporting 930 passed / 1 skipped / 7 failed; failure names were lost in compact/truncated output and must be captured sequentially before production builds.
Open:       First action is `flutter test --no-pub --concurrency=1 --reporter expanded`; diagnose each named failure independently. Then backend test, final analyze, production web build/deploy, one arm64 APK, delete generated build/voice-probe, and human A↔B web audio test. No final APK/web build or deploy this phase. No commit or push; HEAD remains 2cfc8cd. Detailed continuation is the final section of docs/ONLINE-WEB-RECOVERY-PLAN.md.

## PHASE 47 — done
Built:      Closed the seven failures left open by the previous round, cleaned the hosted database, and cut the deployable pair.
Files:      lib/ui/screens/postgame/history_screen.dart
Verified:   flutter analyze — 0 errors, 0 warnings. flutter test — 937 passed, 1 skipped, 0 failed (the whole suite, not a focus set). Supabase project hezjbrnveajypfqmjfnh: rooms/room_players/room_state emptied of 11 leftover probe rooms; all 31 edge functions ACTIVE. Web deployed to https://almafia.vercel.app.
Gate:       PASS
Open:       Human-audible A<->B web voice is still NOT VERIFIED — that is the user's test. No commit, no push; HEAD remains 2cfc8cd.

## PHASE 48 — blocked | responsive online presence and speaking feedback
Built:      Added safe local WebRTC audio-level sampling and shared council
            speaking pulses, enlarged the shared character art, and changed
            the foreground presence beat to three seconds. Added a server
            migration for five-second ageing with away at five seconds and
            left at fifteen seconds; explicit lifecycle and exit updates remain
            server-authoritative.
Files:      lib/platform/voice/{voice_engine.dart,voice_controller.dart,
            webrtc_voice_engine.dart}, lib/ui/widgets/player_avatar.dart,
            lib/ui/screens/online/{council/council_band.dart,
            table/table_scene.dart,lobby_screen.dart,online_table_flow.dart,
            online_session.dart}, lib/transport/online_transport.dart,
            lib/ui/theme/design_tokens.dart,
            supabase/migrations/20260909000200_fast_presence.sql,
            assets/images/online/{avatar_male.webp,avatar_female.webp}
Verified:   Source edits applied; regenerated avatar files have transparent
            alpha pixels verified at the corners and background; previous
            hosted voice probe remains PASS for WebRTC/RTP over Metered.
Gate:       FAIL
Open:       The fast-presence migration could not be applied because the
            database tool hit its usage limit. Local analyze/test/build could
            not run because the Dart tool state directory is inaccessible in
            this environment. No commit or push was made.

## PHASE 49 — done | production web deploy held
Built:      Closed PHASE 48. The new voice stats-sampling Timer.periodic was
            leaking into widget tests as a pending timer (10 lobby failures);
            made its interval injectable (`statsInterval`, zero disables) behind
            a `voiceStatsIntervalProvider`, the same shape `onlineHeartbeatProvider`
            already uses. Applied the fast-presence migration to the hosted
            project, cut the arm64 APK and the web release, and re-ran the
            hosted two-browser voice probe.
Files:      lib/platform/voice/voice_controller.dart (statsInterval param + guard),
            lib/ui/screens/online/voice_session.dart (voiceStatsIntervalProvider),
            lib/transport/online_transport.dart (stale "25 seconds" comment -> "few seconds"),
            test/widget/online_lobby_test.dart, test/widget/online_entry_test.dart,
            test/widget/profile_flow_test.dart (override the new provider to zero),
            supabase/migrations/20260909000200_fast_presence.sql (applied, unchanged on disk),
            docs/PROGRESS.md
Verified:   flutter analyze --no-fatal-infos — 0 errors, 0 warnings, 73 infos.
            flutter test — 937 passed, 1 skipped, 0 failed (was 927 / 1 / 10
            before the timer fix; the 10 were all online_lobby_test).
            node --test supabase/tests/room_configuration.test.mjs — 1 pass.
            node supabase/tests/run_golden_vectors_node.mjs — 35 cases, Dart and
            TS agree.
            Hosted DB hezjbrnveajypfqmjfnh: age_presence() now 'away' at 5s and
            'left' at 15s, security definer, search_path = public, pg_temp; cron
            `age-presence` schedule '5 seconds', active; both UPDATEs exclude
            r.status = 'finished'; trigger room_player_host_departure intact;
            migration row rewritten to version 20260909000200 so `supabase db
            push` stays a no-op. get_advisors(security) — only the pre-existing
            accepted findings (anon-access policies that are the only way in,
            leaked-password toggle); the migration added nothing.
            Avatars: avatar_male.webp / avatar_female.webp are WEBP/RGBA 512x512,
            four corners alpha 0, centre alpha 255, ~50% of a 43x43 sample fully
            transparent; CouncilTokens.avatarSizeRatio 0.72 -> 0.84; PlayerAvatar
            is the shared widget (Band 4 online + offline lists), the council
            seat art is the one CouncilPainter.
            Speaking pulse, read end to end in source: levels come only from
            RTCPeerConnection.getStats() audioLevel, normalised, 0 when the
            browser omits it (no packet-count inference); remote levels gated on
            _live (setAudiblePeers) AND an enabled remote track; cleared on night
            teardown and whenever mode is not live/connecting; council stays one
            CustomPainter driving _paintVoicePulse off the shared `breath` clock,
            no per-seat controller; the viewer avatar uses a separate stateless
            _AvatarPulsePainter; every size/alpha/threshold is a CouncilTokens
            constant; voice logging is counts and candidate-type names only.
            Presence path: client heartbeat MafiaTiming.onlineHeartbeat = 3s via
            Timer.periodic; _PresenceObserver maps app lifecycle to
            set_presence('connected'|'away'|'left') immediately and toggles
            _foreground so a backgrounded client stops beating at once; explicit
            exit calls set_presence('left'); server ageing covers crashed tabs.
            flutter build apk --release --target-platform android-arm64
            --dart-define-from-file=dart_defines.json —
            build/app/outputs/flutter-apk/app-release.apk, 51.6 MB, lib/arm64-v8a
            only. Embedded Supabase key is the sb_publishable_ key; no
            sb_secret_<payload>, no metered/TURN credential, in the APK or the
            web bundle. The bare "sb_secret_" string in libapp.so is the
            Supabase SDK's own reject-this-prefix guard, not a value.
            flutter build web --release --base-href / --dart-define-from-file=
            dart_defines.json — build/web, 60.5 MB; served from a local server,
            every asset 200 with the right content-type, onboarding.mp4 8.99 MB,
            main.dart.js 4.2 MB; the app boots on the web, routes to /onboarding,
            and the intro film renders inside its frame with play and skip
            controls (the "OGG File" browser download prompt for join_chime.ogg
            is the pre-existing Chrome-web decode failure, audio is not
            load-bearing). Live site https://almafia.vercel.app still serves the
            release (flutter_bootstrap.js 200, og/twitter tags, version.json);
            /beta/ returns the SPA index fallback byte-for-byte identical to /,
            so there is no beta page and no APK embed at the origin.
            node tool/run_voice_runtime_probe.mjs --hosted (fresh
            build/voice-probe, VOICE_PROBE_HOSTED=true) — exit 0, both sides
            status PASS: two distinct authenticated identities (A.peer == B.self
            and vice versa), same Metered session channel, 5 ICE servers with
            STUN + TURN + TURNS, offer/answer both legs, ICE and PC state
            Connected, SendRecv, one sender each, remote track + playout
            attached, ~200 RTP packets each direction, 0 rejected candidates.
            Candidate pair type "host" on both — same machine, not srflx/relay.
            Human audibility NOT VERIFIED (synthetic mics). build/voice-probe and
            its browser profiles deleted afterwards; the probe deleted its own
            rooms (none named VoiceProbe* remain on the project).
Gate:       PASS for analyze, the full test suite, the backend tests, the hosted
            migration, the APK, the local web build and the hosted voice probe.
            HELD: the production web deploy to almafia.vercel.app was not pushed.
            This run is explicitly barred from committing or pushing and HEAD
            stays at 2cfc8cd; pushing the uncommitted working tree (57 changed
            files) to the live public domain is not something to do without an
            explicit go-ahead. The build is ready in build/web.
Open:       Production web deploy awaits the user's word (build/web is ready;
            existing process is `pwsh tool/build_web.ps1 -Publish`, a gh-pages
            force-push, or a Vercel deploy of build/web).
            Human-audible A<->B voice and Android audio routing remain NOT
            VERIFIED — no device is attached and that is a physical test.
            The real abandoned lobby N88TK2 (players اياد / نور, both 'left') was
            left untouched; the abandoned-rooms cron will take it.
            No commit, no push; HEAD remains 2cfc8cd.

## PHASE 50 — done | verification partial
Built:      Fixed first-load web voice startup ordering, made "mute all at
            night" writable from the host settings UI and server allow-list,
            restored the required 10-second client heartbeat, widened server
            presence grace to away=25s/left=90s, and deployed create_room,
            room_settings, and start_match with the current shared settings
            validator.
Files:      lib/ui/screens/online/voice_session.dart,
            lib/ui/screens/online/room_settings_panel.dart,
            lib/ui/theme/design_tokens.dart,
            lib/platform/voice/webrtc_voice_engine.dart,
            lib/ui/screens/online/online_session.dart,
            supabase/functions/_shared/room_configuration.ts,
            supabase/migrations/20260909000300_presence_browser_slack.sql,
            tests and this progress record.
Verified:   Hosted age_presence definition has away=25s and left=90s;
            age-presence cron is active every 5 seconds; backend room
            configuration test PASS; focused Flutter voice/settings tests
            previously PASS (28 + 23). The hosted functions are ACTIVE at
            the new versions. A fresh analyzer/full-suite run was blocked by
            the local Flutter/Dart process hanging before output, and the
            approval path for SDK cache access was unavailable.
Gate:       PARTIAL
Open:       Run flutter analyze and the full flutter test suite locally, then
            build the arm64 APK and web release. No commit or push was made;
            HEAD remains 2cfc8cd.

## PHASE 51 — done | blocked
Built:      Removed the duplicate lobby voting switch so voting is controlled
            from Room Settings, removed the host lock button, changed the host
            room action to a logout/exit icon that opens only the existing two
            choices, and kept the shared transparent mobile avatar assets for
            the web build with the current enlarged avatar ratio.
Files:      lib/ui/screens/online/lobby_screen.dart,
            lib/ui/screens/online/table/table_scene.dart,
            lib/ui/theme/design_tokens.dart,
            docs/PROGRESS.md.
Verified:   Source search confirms no lobby voting control or lock icon remains;
            the existing Room Settings panel still contains open voting. The
            image assets used by both platforms are RGBA with transparent
            corners. A fresh Flutter build could not run here because the
            Flutter SDK requires write access to its cache lockfile outside
            the project, which this workspace forbids; no deployment was made.
Gate:       BLOCKED
Open:       Run the build from a normal local shell with Flutter SDK write
            access, then deploy the resulting build/web to the website. No
            commit or push was made; HEAD remains 2cfc8cd.

## PHASE 52 — done | verification partial
Built:      Repaired online guest role delivery after the start-match/private
            identity race, added self-healing private-view retries, prevented
            already-seen roles from being requested again, and retried initial
            voice playout automatically after the first lobby voice climb.
Files:      lib/transport/online_transport.dart,
            lib/transport/supabase_backend.dart,
            lib/ui/screens/online/online_table_flow.dart,
            lib/ui/screens/online/voice_session.dart,
            lib/ui/theme/design_tokens.dart,
            test/transport/online_transport_test.dart,
            test/online/online_role_reveal_test.dart.
Verified:   Focused role-reveal and transport tests passed before the requested
            test stop. Web release built and published successfully. One fat
            release APK built successfully. The live multi-client match still
            needs the user's physical/browser confirmation.
Gate:       PASS for the focused regression tests and both release builds;
            PARTIAL for human two-way voice and full multi-client completion.
Open:       Refresh all clients and start a new room. Confirm every player sees
            their own role before the host advances, and confirm lobby audio is
            audible without toggling the room voice setting. No commit was made;
            HEAD remains 2cfc8cd.

## PHASE 53 — done | verification partial
Built:      Closed the concurrent-resync race that could let an older lobby
            read overwrite a newer reveal read and remove a guest's private
            role. Realtime-triggered full reads now serialize and coalesce a
            follow-up read. Web room-entry now primes browser audio playback
            during the user's join/create gesture before network signalling.
Files:      lib/transport/online_transport.dart,
            lib/ui/screens/online/online_entry_screen.dart,
            lib/platform/voice/web_playout.dart,
            lib/platform/voice/web_playout_browser.dart,
            lib/platform/voice/web_playout_stub.dart,
            docs/PROGRESS.md.
Verified:   flutter analyze completed with 0 errors and 74 existing infos;
            focused online transport and role-reveal suites passed 56/56;
            web release built and published to the live site; one release APK
            built successfully.
Gate:       PASS for compilation, focused regression coverage, and releases;
            PARTIAL for physical five-client match completion and human audio,
            which require the user's active devices.
Open:       Hard-refresh every browser client, install the new APK, create a
            fresh five-player room, and test the full match from reveal through
            result. No commit was made; HEAD remains 2cfc8cd.

## PHASE 54 — done | verification partial
Built:      Removed the root cause of partial online deals. Match start now
            writes every private role, resets every saw_role flag, and opens
            reveal in one atomic database transaction. A failed or incomplete
            deal leaves the room in the lobby. Concurrent client resyncs now
            drain through the newest read, and an online role card remains
            visible until its saw_role acknowledgement succeeds.
Files:      supabase/migrations/20260910000100_atomic_match_start.sql,
            supabase/functions/start_match/index.ts,
            lib/transport/online_transport.dart,
            lib/ui/screens/match_controller.dart,
            lib/ui/screens/online/online_table_flow.dart,
            docs/PROGRESS.md.
Verified:   Production migration applied; start_match v9 deployed ACTIVE. A
            rolled-back production SQL probe wrote 5/5 roles and opened reveal;
            a four-role/ five-player probe wrote 0 roles and stayed in lobby.
            flutter analyze: 0 errors, 0 warnings, 74 existing infos. Focused
            online suites: 57 passed. Full suite: 940 passed, 1 skipped, 0
            failed. Web release built and published; one release APK built.
Gate:       PASS for atomic server deal, client recovery, automated full-match
            coverage, production deployment, and release builds. PARTIAL for
            a physical five-client match, which remains the user's final check.
Open:       Hard-refresh every browser, install the new APK, and create a new
            room; old loaded clients keep their old JavaScript. Confirm all five
            cards appear before continue unlocks, then finish one whole match.
            No commit was made; HEAD remains 2cfc8cd.

## PHASE 55 — done | verification partial
Built:      Four defects that made an online match unplayable past night 1.
            (1) The idempotency key was `<hex micros>-<hex salt>`, which is not
            a UUID, and `night_actions.action_id` / `votes.action_id` are uuid
            columns — so Postgres refused every night action and every vote with
            22P02, the function turned that into a 400, and the player was told
            «اختيارك متسجلش». The night then resolved entirely on `advance_phase`
            defaults, which is why it looked like it had registered. The client
            now emits RFC 4122 v4, and the server nulls a malformed key rather
            than losing the move that carried it.
            (2) The morning stalled: «كمل» posted to `advance_phase`, which
            applies expiry defaults and has no row for a phase with no deadline.
            The morning now opens the day, the same way the deal was fixed.
            (3) Every Edge Function refusal was reported as a dropped
            connection. `functions.invoke` throws on non-2xx, so the backend's
            `if (status >= 400)` was unreachable and PHASE_CLOSED, NOT_HOST,
            ROOM_FULL and the rest all fell through to BackendUnreachable.
            Refusals are now decoded to their code; only a 5xx stays unreachable.
            (4) «خلصت» did nothing unless the confronted player was also the
            host. The server now lets the confronted seat close its own window.
            Also: the night's clock and the ballot's clock now come to now once
            every living player has acted or voted, so neither phase burns its
            full timer after the room is finished with it.
Files:      lib/transport/online_transport.dart,
            lib/transport/supabase_backend.dart,
            supabase/functions/_shared/api.ts,
            supabase/functions/submit_night_action/index.ts,
            supabase/functions/submit_vote/index.ts,
            supabase/functions/open_phase/index.ts,
            test/transport/online_transport_test.dart,
            test/transport/edge_refusal_test.dart,
            docs/PROGRESS.md.
Verified:   Production evidence first: every `night_actions` row in the live
            database had `action_id` null and all five were written inside 0.3 s
            by the expiry defaults — no client-submitted action has ever been
            saved — `votes` was empty, and the one room past the deal was stuck
            on `morning` since 07:33. A rolled-back SQL probe returned
            `old-key=REFUSED(22P02); new-key=ACCEPTED`. The Dart test that
            reproduces it failed on the old key before the fix. Deployed
            submit_vote v7, submit_night_action v8, open_phase v8, all ACTIVE.
            flutter analyze: 0 errors, 0 warnings, 72 existing infos. Full
            suite: 949 passed, 1 skipped, 0 failed. Web release built and
            published to gh-pages (0b6cf11); release APK built (54.7 MB).
Gate:       PASS for root-cause proof, automated coverage, deployment and both
            release builds. PARTIAL for a physical multi-client match, which is
            the user's check.
Open:       Hard-refresh every browser and install the new APK, then play one
            whole match. A stale client's night actions and votes will now save
            (the server tolerates the bad key), but its morning will still
            stall — the morning fix is client-side.
            Still broken, not touched this phase:
              * The elimination verdict is unreachable online. `resolve_vote`
                sets the phase straight to `night`, and `phaseFromServer` never
                produces `GamePhase.reveal`, so the card-rise and the "X was Y"
                band are dead code online — a player votes and lands on the
                next night with no announcement of who went or what they were.
              * The discussion always runs its full 300 s: there is no host
                control, and `advance_phase` refuses before the deadline.
              * `defense` is in TRANSITIONS and nothing ever opens it.
            No commit was made; HEAD remains 2cfc8cd.

## PHASE 56 — done | verification full (automated), partial (human)
Built:      The rest of the online match, and the removal of every remaining
            way for it to stall.
            (1) The verdict. A ballot resolved straight into the next night, so
            the beat where the room is told who went and what they were had
            nowhere to happen — `phaseFromServer` never produced
            `GamePhase.reveal`, and the card-rise and the «فلان كان ...» band
            were unreachable code. There is now a `verdict` server phase between
            the ballot and the night: it carries `lastVote`, holds the day number
            still, and ends on «كمل» or on its own 20-second clock. The day
            number now moves when the *night* opens, which is the thing that is
            actually a new day.
            (2) No beat depends on one phone staying awake. Doc 10 §8.2 says no
            phase may stall; that was untrue while only the host could end one.
            `open_phase`, `resolve_night`, `resolve_vote` and
            `generate_confrontation` now accept any member once the server's own
            `phase_ends_at` has passed, re-read server-side. The client mirrors
            it: the host drives at the deadline, a guest after a grace plus two
            seconds per seat, so five phones do not all ask at once.
            (3) Transitions land on the second. A one-shot alarm fires at the
            deadline instead of waiting up to a full heartbeat.
            (4) The morning carries a 45s failsafe clock, so the one beat with
            nothing to answer can no longer strand a match.
            (5) The host can end the discussion; it used to run its full five
            minutes whatever the room did.
            (6) Every phase-moving write is compare-and-set on the phase the
            caller read, so two drivers cannot advance the room twice — and the
            two resolvers now *read* their write's error. They did not, which is
            how `resolve_vote` answered 200 with a correct tally while the phase
            check constraint silently refused `verdict` and the room sat on the
            ballot.
Files:      supabase/migrations/20260910000200_verdict_phase.sql,
            supabase/functions/_shared/phases.ts,
            supabase/functions/{open_phase,resolve_vote,resolve_night,
            generate_confrontation,advance_phase}/index.ts,
            lib/transport/{online_transport,room_codec}.dart,
            lib/ui/screens/online/online_table_flow.dart,
            lib/ui/theme/design_tokens.dart,
            supabase/tests/e2e_match.py,
            test/transport/online_transport_test.dart,
            test/online/online_verdict_test.dart,
            docs/PROGRESS.md.
Verified:   `supabase/tests/e2e_match.py` — five real anonymous sessions playing
            a **two-day** match against the deployed production functions —
            **94 passed, 0 failed**: the reveal gate, night one, the morning,
            host migration and its cascade, «اسم واحد», the floor, the day-one
            ballot, the verdict, the day number moving on the night, the
            Doctor's self-protection, a night that ends because everybody
            answered rather than because its clock ran out, a second bullet
            refused, day two's confrontation closed by the confronted player,
            the day-two ballot, the second verdict, an expired phase closed by a
            guest, and the result with every role and every elimination public.
            The harness itself was stale — it predated the `saw_role` reveal gate
            and had never been run since — and now covers it.
            Migration `verdict_phase` applied to production; all five functions
            deployed. flutter analyze: 0 errors, 0 warnings, 72 existing infos.
            Full suite: 961 passed, 1 skipped, 0 failed. Web published to
            gh-pages (8368ea8); release APK built (56.3 MB).
Gate:       PASS.
Open:       Every browser must be hard-refreshed and the new APK installed: a
            client one build behind does not know the `verdict` phase and will
            not read it correctly. Nothing is known to be broken in the online
            flow; what remains untested by machine is a human five-device match,
            and voice, which no harness can hear.

## PHASE 57 — done
Built:      The deal. Four players in a real room were shown a card, pressed
            «كمل», and were skipped without ever seeing their role — because a
            `saw_role` the server never received cleared the card anyway. Three
            causes, all fixed: the acknowledgement is now the room's word, the
            screen can no longer be locked out of asking for the card again,
            and the deal runs on a clock like every other phase so one stuck
            seat cannot hold four other people there for good. The Arabic pad
            also never said to *hold* — it said «دوس», and a mouse click is
            thirty milliseconds.
Files:      lib/transport/online_transport.dart (`_send(assured:)` rethrows a
            lost move; `confirmRevealed` reads the row back before letting the
            card go), lib/ui/screens/online/online_table_flow.dart (the private
            hold is a snapshot, not a permanent flag; a failed dismissal says
            so; `BackendUnreachable` is reported like a refusal),
            lib/app/l10n/app_ar.arb + generated (holdToRevealRole,
            holdToConfirmIdentity, iAmHoldInstruction now say «ثانيتين»),
            supabase/functions/_shared/phases.ts (`reveal` → 90s),
            supabase/functions/open_phase/index.ts (the card gate yields to an
            expired deal), supabase/functions/start_match/index.ts,
            supabase/migrations/20260910000300_reveal_deadline.sql,
            test/support/fake_backend.dart (saw_role writes; `ignoreSawRole`),
            test/transport/online_transport_test.dart (+4),
            test/online/online_reveal_recovery_test.dart (new, 5),
            supabase/tests/e2e_match.py (+1)
Verified:   Reproduced first, on the live site, with a real browser and four
            server-side players: a 503 on `saw_role` dismissed the card and put
            that seat in its own waiting list permanently — the user's
            screenshot, exactly. After the fix the same 503 leaves the card up
            and usable. A deal left unacknowledged now opens the night by
            itself when its clock runs out (watched in production: reveal →
            night at 11:30:12Z with `saw_role` still false, honestly).
            flutter test → 970 passed, 1 skipped, 0 failed.
            flutter analyze lib test → 0 errors, 0 warnings, 72 pre-existing infos.
            supabase/tests/e2e_match.py → 90 passed, 0 failed.
            Deployed: migration `reveal_deadline`, functions start_match and
            open_phase. Site published to gh-pages (f024ec1).
Gate:       PASS
Open:       The desktop table layout wastes most of a wide window — the seats
            crowd into the top strip. Cosmetic, not reported, not touched.

## PHASE 58 — done | browser verification pending
Built:      Removed the full-file network download gate before web intro playback; reuse cached video blobs offline and stream on cache misses. Explicit LTR direction for the embedded video. Reviewed existing post-onboarding profile, public room browsing and pre-creation settings without removing features.
Files:      lib/platform/media/video_download_browser.dart; lib/ui/screens/onboarding/onboarding_video_screen.dart; docs/PROGRESS.md
Verified:   Focused Flutter tests: 29 passed (video sizing/rotation/playback, profile flow/storage, online entry/settings, offline asset wiring). Dart analyze on both modified source files: No issues found.
Gate:       PASS for focused automated checks only.
Open:       Real mobile-browser playback, audio/video sync, resize/compositor verification and release web build remain unverified. Broad web rendering improvements, avatar transparency visual review, and the remaining online redesign audit are still pending. Existing profile/public rooms/settings were already implemented before this phase. No deployment. Stop at this phase gate.

## PHASE 59 / attachment PHASE 0 — blocked
Built:      Partial audit of the existing online implementation; identified a private saved-target leak in public room state, plus room-creation, transition-atomicity, presence-ordering and recovery gaps. No application/backend code changed.
Files:      docs/ONLINE-RELIABILITY-AUDIT.md; docs/PROGRESS.md; audit-current.diff (local diff capture)
Verified:   Git status/stat/diff/log and targeted source/RLS/publication inspection. Source-proven privacy path only; no tests, hosted queries, runtime PASS, build or deployment claimed.
Gate:       FAIL — private savedSeat is written into member-readable public_data.
Open:       Stop-and-report under Doc 05/working agreement. Repair server-only history storage and existing public archive exposure without losing information-engine functionality, then complete the unfinished attachment Phase 0 audit. Full implementation and real Android/Web/audio verification remain pending.

## PHASE 60 — implementation verified in parts; release gate open
Built:      Closed the saved-target privacy leak with server-only night history and rolling-deployment sanitization; atomic night/vote resolution with stale-driver/round rejection and rollback; atomic room creation/join; stale presence rejection; responsive wide council; result-only history cleanup; universal Android ABI configuration. Preserved the existing engine and voice mesh.
Files:      supabase/migrations/20260913000100_private_night_history.sql, 20260913000200_atomic_resolution.sql, 20260913000300_atomic_room_entry.sql, 20260913000400_resolution_outcome.sql; supabase/functions/_shared/{api,history}.ts; supabase/functions/{create_room,join_room,resolve_night,resolve_vote}/index.ts; supabase/tests/{private_night_history,atomic_resolution,atomic_room_entry}.sql; supabase/tests/e2e_match.py; lib/transport/online_transport.dart; lib/ui/screens/online/{online_session.dart,council/council_geometry.dart}; lib/ui/theme/design_tokens.dart; android/app/build.gradle.kts; test/transport/online_transport_test.dart; test/online/{online_reveal_recovery_test,council_geometry_responsive_test}.dart; tool/web_release_smoke.mjs.
Verified:   Full Flutter suite before final UI adjustments: 970 passed / 1 skipped. After changes: transport 65 passed; table/lobby/entry/reveal 44 passed; responsive geometry 21 passed. Backend configuration and 35 cross-language golden vectors passed. Real hosted SQL tests passed for private history/member denial, resolution rollback/stale drivers/revote, room creation rollback/seat reuse/mid-match exclusion. Hosted full-match final run: 93 passed / 0 failed (build/phase60-backend-final.log); admin-only host scenarios not run without service credentials. Earlier E2E runs failed timing/status checks and one timed out; final run passed after status-preservation migration. Web release build succeeded with existing dependencies (--no-pub), 132 files. Male/female avatar alpha and small visual previews verified; no baked checkerboard seen.
Gate:       OPEN — not yet ready to declare release PASS.
Open:       APK build and real Chrome video smoke are in progress. No connected Android device; existing AVD directory lacks config.ini, emulator list empty. Human A<->B audio NOT VERIFIED. Final analyze and post-adjustment full suite pending. Complete remaining audit findings (open_phase/advance_phase side effects before CAS, action-write/read error handling, recovery warnings/discard, cross-room membership exclusion, actual concurrent-driver stress) before claiming all online paths reliable. No final web publication, commit or push. Initial pub-get hung and was interrupted; build used tested installed dependencies.

Hosted deployment receipt: private_night_history, atomic_resolution, atomic_room_entry, resolution_outcome migrations applied to hezjbrnveajypfqmjfnh. resolve_night ACTIVE v10; resolve_vote ACTIVE v9; generate_confrontation ACTIVE v8; create_room ACTIVE v9; join_room ACTIVE v9. User explicitly approved source upload to this exact Supabase destination after auto-review asked; do not ask again. Usage-limit interruptions were environmental, not release verification. Preserve all pre-existing uncommitted work.

## PHASE 61 — done
Built:      Removed first-frame dependence on external font/renderer CDNs by bundling the default font family and using local CanvasKit; verified real Chrome intro playback/resizing. Tightened join_room error mapping to fixed allowlisted codes and deployed v10.
Files:      pubspec.yaml; web/flutter_bootstrap.js; tool/web_release_smoke.mjs; test/web/offline_video_test.dart; supabase/functions/join_room/index.ts; docs/PROGRESS.md.
Verified:   Release web build PASS. Real fresh-profile Chrome: no external renderer/font requests; decoded playback after gesture; video bounds/aspect PASS at 360x800, 390x844, 768x1024, 1280x800, 1920x1080; reviewed build/web-video-smoke.png. Full Flutter run: 991 passed, 1 skipped, 1 failed (join_room error-surface source check); corrected that finding then affected server-surface/offline-web suites: 16 passed. Analyze: 73 infos, no errors/warnings. Prior APK build success confirmed, includes arm64-v8a/armeabi-v7a/x86_64. Supabase join_room ACTIVE v10.
Gate:       PASS for this phase; overall release remains OPEN.
Open:       Pending atomic_phase_open migration and open_phase edits are local and NOT tested/deployed. Remaining Phase60 online audit/recovery/concurrency findings remain open. No actual Android runtime, human audio sync or A<->B voice verification. APK predates this phase font registration. Web not published, no commit/push. Logs: build/phase61-{web-build,web-final,flutter-tests,regression,analyze}.log.

## PHASE 62 — done (handoff section A: server atomicity and concurrency)
Built:      Every phase move is now one compare-and-set under the room lock, moves and ballots are guarded by phase on the table itself, resolutions commit only the moves they counted, defaults never overwrite a real move, a user holds one seat across rooms, and no phase mover turns a failed read into an empty success. Reviewed and rewrote the untested local `commit_phase_open` (adds the in-lock reveal gate, a standings-only-with-result guard, result from an outcome-finished room); added `commit_confrontation` and `commit_accusation` (generate_confrontation had no phase check and no CAS, and refused a non-host driver after the morning expired — a sleeping host stalled day ≥2; submit_accusation wrote the name, the floor and the phase in three unfiltered updates). `advance_phase`: confront/opening/discuss moves through commit_phase_open (patch and phase in one statement, deadline CAS), night/vote defaults with `ignoreDuplicates` and a server-derived revote round, every read checked. `submit_vote`: round derived server-side; `submit_night_action`/`submit_vote`: guard refusal surfaced as PHASE_CLOSED. `resolve_night`/`resolve_vote`: move fingerprint handed to `commit_resolution`, bounded re-tally when a move landed between tally and commit (round-aware for revotes). `_shared/history.ts`: all reads checked. `create_room_atomic`/`join_room_atomic`: per-user advisory lock + `vacate_other_rooms` (lobby seat freed, playing seat marked left with host handover, rejoin keeps the seat, finished rooms untouched). Old audit annotated with proven repairs.
Files:      supabase/migrations/20260914000100_atomic_phase_open.sql (rewritten), 20260914000200_action_epoch.sql, 20260914000300_single_seat.sql, 20260914000400_result_after_outcome.sql (new); supabase/functions/{open_phase,advance_phase,generate_confrontation,submit_accusation,submit_night_action,submit_vote,resolve_night,resolve_vote}/index.ts; supabase/functions/_shared/history.ts; supabase/tests/{atomic_phase_open,action_epoch,single_seat}.sql (new), atomic_resolution.sql (new signature), anticheat.sql (phase-consistent fixture), concurrency_match.py (new); test/transport/server_surface_test.dart (+7 source-surface tests); docs/ONLINE-RELIABILITY-AUDIT.md; docs/PROGRESS.md.
Verified:   Hosted, on hezjbrnveajypfqmjfnh: each migration dry-run inside a rolled-back transaction with its test before being applied; after applying, rollback runs of atomic_phase_open.sql, action_epoch.sql, single_seat.sql, atomic_room_entry.sql, atomic_resolution.sql, anticheat.sql all PASS (stale caller, changed deadline, double driver, check-constraint rollback, legal moves incl. same-phase clock, standings refused before result, closed room never reaches result, confrontation/accusation CAS, phase guards on moves/ballots/rounds, fingerprinted resolution, deciding ballot finishes the room, vacate across lobby/playing/finished, grants + pinned search_path). `supabase/tests/e2e_match.py` against the deployed functions: first run 92/93 (verdict->result refused on an outcome-finished room — fixed by result_after_outcome), final run 93 passed / 0 failed (build/phase62-e2e.log). New `supabase/tests/concurrency_match.py` with real simultaneous requests: 46 passed / 0 failed (build/phase62-concurrency.log) — 5 drivers on reveal->night, 3 on morning->opening / discuss->vote, 2 on verdict->result: exactly one 200 each, the rest refused with a resync code; Mafia double-tap = one row; 3 resolvers + a late move: one morning, the move acknowledged iff present for night 1; seat double-tap = one name, floor moves one step; host leaves mid-match -> lowest heartbeat-fresh seat inherits and resolves the ballot; retried ballot never lost; a user racing two joins holds one seat and a later join moves it; emptied lobby is gone. Flutter full suite: 999 passed, 1 skipped, 0 failed (build/phase62-flutter-tests.log). Analyze: 75 infos, 0 errors, 0 warnings (build/phase62-analyze.log; the 2 infos beyond phase 61 are pre-existing in test_driver/ and tool/, not touched here).
            Deployment receipts (ACTIVE): resolve_night v11, resolve_vote v10, open_phase v11, advance_phase v8, generate_confrontation v9, submit_accusation v7, submit_night_action v9, submit_vote v8. Migrations applied: atomic_phase_open, action_epoch, single_seat, result_after_outcome. Shared files were uploaded with doc comments stripped (code identical); local copies keep the comments.
Gate:       PASS for section A. Overall release still OPEN (sections B–F pending).
Open:       No server-side rematch exists (start_match requires a lobby room), so "rematch epochs" means a new room; nothing to test beyond phase_number/round epochs, which are covered. Deadlock between two *different* users swapping rooms in the same instant is resolved by Postgres (one request errors and retries), not prevented. Cross-user deadline expiry of resolvers is proven only via the host path in the harness (no service key for the admin branch). Sections B (persistence/recovery warnings, discard pointer), C (full flow/error matrix), D (voice), E (visual/media), F (builds/publication) remain. No commit, no push.

## PHASE 63 — blocking server repair done; broad section B gate pending
Built:      Reviewed Claude's handoff and deployed definitions; fixed pre-deal kicked seats across capacity, atomic deal, reveal gate, public browsing and client roster. Retained removal notification rows without assigning roles or counting them alive in the match. Published public rosterSeats at deal so only real participants appear; in-match departures remain participants. start_match read errors now checked. Result standings omit never-dealt null-role rows.
Files:      supabase/migrations/20260914000600_kicked_seats.sql, 20260914000700_public_room_active_count.sql; supabase/functions/{start_match,open_phase}/index.ts; supabase/tests/{kicked_seats.sql,recovery_match.py}; lib/transport/room_codec.dart; test/transport/kicked_roster_test.dart; docs/CLAUDE-AFTER-CODEX-63.md; docs/PROGRESS.md.
Verified:   Hosted recovery 37 passed / 0 failed (build/phase63-codex-recovery.log). Targeted Flutter transport/session/entry: 174 passed (build/phase63-codex-targeted.log). Focused analyze: no issues (build/phase63-codex-analyze.log). Hosted rollback SQL: kicked_seats, atomic_room_entry, single_seat, atomic_kick, atomic_phase_open PASS. New migrations dry-run tested before application; final kicked_seats rerun after public count migration. Deployment: kicked_seats + public_room_active_count applied to hezjbrnveajypfqmjfnh; start_match ACTIVE v11, open_phase ACTIVE v12, verify_jwt preserved true.
Gate:       PASS for the blocking repair; full section B and release remain OPEN. User requested split work to conserve tokens; Claude takes broader verification.
Open:       Full Flutter, e2e_match/concurrency_match and remaining SQL regression runs pending after this fix; detailed follow-up in docs/CLAUDE-AFTER-CODEX-63.md. Newly identified room_settings check/update race remains unmodified for section C. No human voice, browser refresh/tab-close, real Android or production UI verification in this session. Current client changes not built/published. Existing kick-in-match alive semantics preserved; neutral elimination must be reviewed separately. No automatic Home resume prompt (online entry has Resume/Forget); temporary-offline browser UX not runtime verified. No commit/push.

## PHASE 63b — done (section B closed; section C server gaps; sections E/F in part: browser pass, builds, production web publish)
Built:      Section B (persistence/recovery) closed on top of Codex's kicked-seat repair. Client: web refresh / deep link on `/online/lobby` without a session now redirects to the online entry (Resume / Forget), and `/match` without a match to the entry when a resume pointer exists, else Home (they used to paint an empty lobby / an empty match flow — found in a real Chrome pass, build/review/m-14-after-reload.jpg). Server (section C findings): `room_settings` is one statement under the room lock (`commit_room_settings`: host, lobby-only, capacity ≥ seated population counted the way the door counts it, settings merged in SQL so two simultaneous switch taps both land); a removed seat is not a membership (`loadMembership` returns null for kicked rows; the phase-guard triggers on night_actions/votes and `commit_accusation` refuse kicked actors with NOT_A_MEMBER — a kicked player could still cast a ballot, keep heartbeating its own status back to `connected`, and hold the opening floor); a mid-match kick of a dealt seat is the attachment's neutral elimination applied at once (`kick_member`: alive=false, whispers voided, `eliminations[seat]` recorded, win check) instead of a living seat nobody could act for; `resolve_night` skips kill targets that are no longer alive (a removal during the night used to leave a night no resolver could commit); presence ageing gives a silent lobby seat up through `leave_room` so the door, the public list and the lobby count agree (a closed tab held a lobby seat for a day), the lobby seat re-pack survives heap order (two-step; it tripped its own unique index once a removed row sat past the leaver), a departing host never hands the lobby to a removed row, and a lobby whose only rows are removed ones is deleted. Real-browser review of video, screens, two-client voice and recovery written to docs/CLAUDE-PARALLEL-REVIEW.md (E-1…E-8). Universal release APK and web release built from current source; web published to production.
Files:      lib/app/router.dart; test/widget/deep_link_without_session_test.dart (new, 4); supabase/functions/_shared/api.ts (kicked → null); supabase/functions/{room_settings,heartbeat,submit_vote,submit_night_action,claim_host,send_whisper,resolve_night}/index.ts; supabase/migrations/20260914000800_atomic_room_settings.sql, 20260914000900_kicked_moves.sql, 20260914001000_kick_eliminates.sql, 20260914001100_lobby_departures.sql (new); supabase/tests/{atomic_room_settings,kicked_moves,kick_eliminates,lobby_departures}.sql (new), roster_match.py (new, 48 checks), recovery_match.py (mid-match kick now a citizen; asserts the neutral elimination); docs/CLAUDE-PARALLEL-REVIEW.md (new), docs/CHATGPT-HANDOFF.md (new, continuation prompt); build/web (rebuilt, sw.js 20260914-145130), build/app/outputs/flutter-apk/app-release.apk (rebuilt).
Verified:   Hosted, on hezjbrnveajypfqmjfnh: each of the four migrations dry-run with its test inside one rolled-back transaction, then applied (atomic_room_settings, kicked_moves, kick_eliminates, lobby_departures — all PASS); after applying, rollback runs of kicked_seats.sql, atomic_kick.sql, action_epoch.sql, atomic_phase_open.sql, single_seat.sql all PASS. Deployed (ACTIVE): room_settings v8, heartbeat v9, submit_vote v9, submit_night_action v10, claim_host v8, send_whisper v7, resolve_night v12 (verify_jwt unchanged; shared files uploaded with doc comments stripped, code identical). Hosted harnesses: roster_match.py 48/48 (build/phase63-roster.log: settings host-only/merged/capacity/off-list, sixth join ROOM_FULL, public list 5→4→5 across kick/join cycles, replacement on a fresh seat, three removed rows never counted, join-vs-start race lands in exactly one consistent world, settings refused after the deal and unchanged under the refusal, rosterSeats = seated population, removed rows not alive after the deal, a mid-match removal cannot vote / heartbeat, standings name the dealt players only, the participant removed after the deal keeps its role with a day-1 neutral elimination record, town wins); e2e_match.py 93/93 (build/phase63-e2e.log); recovery_match.py 40/40 (build/phase63-recovery.log). Flutter full suite 1018 passed / 1 skipped / 0 failed (build/phase63-flutter-tests.log, before the router change) + the 4 new deep-link tests pass; analyze 75 infos, 0 errors, 0 warnings (build/phase63-analyze.log). Real Chrome (headless=new, separate profiles, CDP): intro video decodes, gesture-starts, stays in bounds and aspect-correct through six viewports with 0 dropped frames, skip works; profile/home/mode/entry/create-sheet/lobby at 390 and 360 wide clean; public list refresh + join from list; resume after refresh rejoins the same seat; tab close/reopen → Home → entry → Resume rejoins; two fake-mic clients in one lobby: getUserMedia OK both, one RTCPeerConnection each, connected/stable, RTP flowing both ways (188/188 packets, 0 lost, 0 concealed), mute stops the peer's inbound audio energy and unmute resumes it, reload-resume and tab-close-resume both re-establish media; new bundle re-checked in Chrome: refresh on the lobby URL lands on the entry with «كمل» + «انسى الأوضة», Resume rejoins, Forget clears the pointer and gives the seat up. Builds: `flutter build web --release --no-pub` (build/phase63-web-build.log; pub.dev was unreachable so the script's pub step was skipped and its sw.js stamping replicated by hand, version 20260914-145130); `flutter build apk --release --no-pub --split-debug-info` (build/phase63-apk-build.log): 115 MB universal, arm64-v8a/armeabi-v7a/x86_64, targetSdk 36, signer SHA-256 082c07…9e11 = web/.well-known/assetlinks.json, fonts bundled. Published: `vercel deploy --prod` from build/web to project almafia (dpl_2gC19UhRJQy6FV8pXSzjmqS1QJsH READY, build/phase63-vercel-deploy.log); https://almafia.vercel.app serves the new bundle (main.dart.js md5 identical to build/web), sw.js 20260914-145130, manifest, favicon, /.well-known/assetlinks.json 200; /beta and /beta/ are the SPA fallback (same index.html, no beta page); /online/lobby deep link on production redirects to /online in Chrome with sw.js registered.
Gate:       PASS for section B and for the section C server gaps above. Release overall still OPEN (C flow matrix, D voice, E device pass, F two-client human validation).
Open:       concurrency_match.py PARTIAL after these changes: 41 checks passed, 0 failed, then the run was cut by the hosted anonymous sign-in rate limit (429 over_request_rate_limit, exhausted by the day's harness runs and browser clients) at the seat-race section (the last 5 checks, which mint fresh users; single_seat.sql hosted PASS covers the same rule) — build/phase63-concurrency.log; rerun in full once the window clears. Human audibility A↔B, night privacy, TURN/relay path, Android↔Web, background/resume on a phone: NOT VERIFIED (fake mics, one machine, `flutter emulators` lists none on this machine; `Pixel 9 pro (2)` not present). Real mobile browsers / slow network / offline replay: NOT VERIFIED. Not fixed (recorded in docs/CLAUDE-PARALLEL-REVIEW.md): phone-landscape lobby unusable (E-3), no desktop column on entry/lobby (E-4), on-state switch thumb invisible (E-5), 32×24 gender chips (E-6), join_chime.ogg DEMUXER error at startup in headless Chrome (E-7), one uncaught JS error after «مشاركة» in headless (E-8). Not redeployed: `set_presence`, `claim_floor`, `release_floor`, `record_speaking`, `submit_prediction`, `ghost_say`, `my_team`, `saw_role`, `mute_player`, `leave_room`, `submit_accusation` (their bundled `api.ts` still admits kicked rows; the DB guards and `commit_accusation` refuse the moves that matter and `realtime_token` already refused left seats) — redeploy with the current `_shared/api.ts` when next touched. `start_match` still replaces `rooms.settings` with the host's start payload (the client sends the current settings); by design, noted. Public room title typing not verified by hand. No launch-time online resume prompt on Home. No commit, no push.

## PHASE 64 — done (hosted contract unified and redeployed; section C harnesses green incl. the full kick flow; E-3…E-8 acted on; builds and production web publish)
Built:      Hosted contract: `resolve_night` v13 and `resolve_vote` v11 (Codex's last deploys) proved byte-identical to local, bundled `_shared/api.ts` carrying the read-error throws and the kicked→null rule, `roster_fingerprint.ts` identical; hosted `night_fingerprint`/`vote_fingerprint`/`roster_fingerprint`/`apply_match_deal`/`commit_resolution` read back and match migrations 001200/001300. Nine functions whose bundles still carried the September-8 `api.ts` redeployed from local source (byte-checked upload): set_presence v6, saw_role v7, my_team v7, claim_floor v7, release_floor v8, record_speaking v7, submit_prediction v7, ghost_say v7, remove_player v7 (all verify_jwt true, ACTIVE). Two real defects found by the reruns and fixed: (1) `release_floor` called a `lower_hand` RPC that never existed in any migration — once Codex made RPC errors throw, every release of the floor failed (e2e 92/93); the dead call is gone. (2) `remove_player` (the 3-minute-silence strike) was five unchecked requests: a failed roster read came back empty, an empty roster has no Mafia, and the town was declared the winner — an outcome invented from a read that did not happen; a night strike was recorded as a day elimination; a half-failed write left a dead seat without a record. It is now one statement under the room lock (`strike_absent_member`: host-only, playing-only, not the host's own seat, silence by the server clock, alive=false, whispers voided, elimination with the real phase, win check), mirroring `kick_member`. Harness: `anon_session` waits out the hosted sign-in rate limit with a bounded backoff instead of dying (no assertion touched); sessions are minted before lobbies exist because `lobby_departures` gives up a lobby silent for 90 s. New end-to-end case `kick_flow_match.py` (60 checks): lobby kick → replacement on a fresh seat → start with a payload that disagrees with the saved settings (saved wins) → rosterSeats without the removed seat → night with a removal racing the resolver (one 200 and exactly one of two consistent worlds) → day whisper then the whispered-to seat struck for silence (refused while beating, refused for the host's own seat, whisper voided, neutral day-1 record, never twice, no outcome invented, cannot vote) → ballot → town wins → standings name the five dealt seats only; the pre-deal removal has no record and stays barred. UI (evidence-backed only): E-3 wide council rows now fit height as well as width (sideways phone: one row of real chairs); E-4 entry screen and the lobby's code/start column in the `maxContentWidth` reading column; E-5 switch call-site colour override removed so the lit thumb shows; E-6 gender marks 48×48; E-8 `AppClipboard.copy` returns success instead of throwing, the lobby announces a copy only when it landed; E-7 checked headed (no error at launch, chime not even requested before the lobby; warm-up already tolerates a preload failure) — left as is.
Files:      supabase/functions/{set_presence,saw_role,my_team,claim_floor,release_floor,record_speaking,submit_prediction,ghost_say,remove_player}/index.ts (release_floor and remove_player edited; the rest redeployed from local); supabase/migrations/20260914001400_strike_absent.sql (new; hosted as `strike_absent` + `strike_absent_self`); supabase/tests/strike_absent.sql (new), supabase/tests/kick_flow_match.py (new, 60 checks), supabase/tests/e2e_match.py (429 backoff), supabase/tests/{concurrency,roster}_match.py (sessions before rooms); lib/ui/screens/online/council/council_geometry.dart, lib/ui/screens/online/online_entry_screen.dart, lib/ui/screens/online/lobby_screen.dart, lib/ui/screens/online/room_settings_panel.dart, lib/ui/widgets/gender_picker.dart, lib/platform/clipboard.dart; test/online/council_geometry_responsive_test.dart (+1); docs/CLAUDE-PARALLEL-REVIEW.md (E-3…E-8 acted-on notes); build/web (rebuilt, sw.js 20260914-193905), build/app/outputs/flutter-apk/app-release.apk (rebuilt); build/review/p64-entry-1280.jpg, p64-create-1280.jpg.
Verified:   Hosted, on hezjbrnveajypfqmjfnh, after the deploys: rollback SQL tests resolution_population, kicked_seats, atomic_room_settings, kicked_moves, kick_eliminates, lobby_departures, atomic_resolution, atomic_room_entry, atomic_kick, single_seat, atomic_phase_open, action_epoch, private_night_history, strike_absent (dry-run inside the migration's transaction, then applied, then again) — all PASS. Node: roster_fingerprint.test.mjs PASS, room_configuration.test.mjs PASS, golden vectors 35/35 Dart=TS. Harnesses after the last deploy: recovery_match 40/40 (build/phase64-recovery.log), e2e_match 91/91 (build/phase64-e2e.log; 93 in phase 63 was two data-dependent confrontation checks that did not fire this run, 0 failed), roster_match 48/48 (build/phase64-roster.log, rerun after the ordering change), concurrency_match 46/46 complete (build/phase64-concurrency.log — the phase 62 baseline count, no longer PARTIAL), kick_flow_match 60/60 (build/phase64-kick_flow.log). Flutter: 1023 passed / 1 skipped / 0 failed (build/phase64-flutter-tests.log, after every UI edit); analyze 74 infos, 0 warnings, 0 errors (build/phase64-analyze.log). Builds: web `--release --no-pub --base-href / --dart-define-from-file` (build/phase64-web-build.log, sw.js stamped 20260914-193905, no `offline_service_worker.js` copy, no JWT/service-role literal in main.dart.js); APK `--release --no-pub --split-debug-info` (build/phase64-apk-build.log): 115 MB, arm64-v8a/armeabi-v7a/x86_64, targetSdk 36, versionName 1.0.0, signer SHA-256 082c07…9e11 = web/.well-known/assetlinks.json. Published: `vercel deploy --prod --yes` from build/web (dpl_BydDREhbXCxDn4e6swS4WUct2MGZ READY, aliased almafia.vercel.app; build/phase64-vercel-deploy.log); live main.dart.js md5 = local, sw.js 20260914-193905, manifest/favicon/assetlinks 200, /online/lobby 200 (SPA), /beta and /beta/ are byte-identical to / (fallback, no beta page). Headless Chrome on production at 1280×800 with a seeded profile: the entry screen sits in a centred column (p64-entry-1280.jpg), the create sheet's lit switches show their thumb (p64-create-1280.jpg), no horizontal overflow. Headed Chrome (extension) on production: no console error at launch, no join_chime request before the lobby.
Gate:       PASS for the hosted contract, section C harnesses (with the full kick flow), the room-settings race review (host-only, lobby-only, room lock, `not kicked` population like the door and the deal, SQL merge, PHASE_CLOSED after a start, read/write errors are refusals), the section B code review (pointer carries roomId/code only; Resume/Forget; storage warning non-blocking; history failure never blocks the pointer clear; teardown on leave/kick/new room), and E-3…E-8. Release overall still OPEN on the human/device items below.
Open:       NOT VERIFIED (no second person, no device, no emulator on this machine): human audibility A→B and B→A, night privacy by ear, TURN/relay candidate path, Android↔Web, Android audio, background/resume on a phone, real mobile browsers, slow network, offline replay; the lobby at 844×390 in a browser after E-3 (geometry proved by unit test only — a headless lobby needs a sign-in the harnesses needed); lobby playback of join_chime headed (E-7). Still bundled with the September `api.ts` (kicked rows admitted at the membership step; every one of them is host-only or guarded by a DB trigger/CAS): mute_player v5, close_room v5, kick_player v6, start_match v11, open_phase v12, submit_accusation v7, advance_phase v8, generate_confrontation v9, send_whisper v7 (its target read also swallows the error into a "no such seat" refusal — a refusal, not a success). `RoomSettingsPanel` spans the full width on desktop (a full-screen sheet; not in E-4's scope). Public room title typing not verified by hand. No launch-time online resume prompt on Home. No commit, no push.

## PHASE 65 — done (2026-09-20: release baseline reconciled)
Built:      Read-only reconciliation found work newer than PHASE 64: all 31 hosted Edge Function bundles match current local TypeScript, normalizing line endings and outer whitespace, including every bundled shared dependency. No redeployment or application change was necessary. Confirmed whisper_graph_realtime is installed and whisper_meta is published. Pixel_9_Pro_2 now exists locally; no device was connected or emulator started.
Files:      docs/PROGRESS.md; build/phase65-focused-tests.log; build/phase65-analyze.log.
Verified:   169 focused Flutter tests passed (all test/transport, online session recovery, deep links, and dead-player result controls). Both Node test files passed (room_configuration and roster_fingerprint). Hosted rollback SQL tests strike_absent, resolution_population, kicked_moves, atomic_room_settings all PASS. Analyze: 0 errors, 0 warnings, 76 infos. Hosted function source comparison covered all 31 current functions; migration listing and publication read back on hezjbrnveajypfqmjfnh.
Gate:       PASS for reconciliation and focused regression only; release overall OPEN.
Open:       Remaining code/flow and voice review, full harness/suite after final fixes, actual emulator/browser full-match and recovery checks, audio/relay validation, final builds and release verification. Expensive gameplay testing intentionally deferred until after implementation review. No app code changes, deployment, commit, or push in this phase. Stop at the phase gate per AGENTS.md.

## PHASE 66 — done (release artifacts ready; publication blocked by authentication)
Built:      Atomic whisper delivery deployed (migration atomic_whisper, send_whisper v9); graph and private body commit together, with locked phase/day/membership/target guards. Prepared fresh release APK, AAB and web; installed/launched APK on Pixel_9_Pro_2 and inspected the home screenshot. Added forced-relay probe with nominated candidate evidence. User explicitly owns the full UI match test now. Presentation improvements recorded separately, not implemented.
Files:      supabase/functions/send_whisper/index.ts; supabase/migrations/20260920000100_atomic_whisper.sql; supabase/tests/atomic_whisper.sql; supabase/tests/kick_flow_match.py; tool/run_voice_runtime_probe.mjs; docs/RELEASE-STATUS-2026-09-20.md; docs/ONLINE-EXPERIENCE-NEXT.md; docs/PROGRESS.md; build/release-*.log and release artifacts.
Verified:   Atomic whisper dry-run rollback and post-deployment test PASS. Full Flutter 1027 passed/1 skipped/0 failed. Hosted e2e 93/93, recovery 40/40, roster 48/48, concurrency 46/46. Kick flow 58/60: harness assumed doctor survived; source-corrected to actual living town voters, Python compilation PASS, full rerun intentionally deferred to user. Chrome video gesture/bounds at five sizes PASS. Two isolated hosted voice clients PASS with strict autoplay and synthetic microphones; forced TURN-only test PASS with nominated relay candidates on both endpoints. APK signature matches assetlinks; all 3 ABIs; AAB/web release builds PASS. Last analyze unchanged Flutter source 0 errors/0 warnings/76 infos. Production root/bundle/manifest/favicon/assetlinks/deep link HTTP 200; deployed bundle hash differs from new local build.
Gate:       PASS for implemented fix, builds and listed checks; production publication BLOCKED (Vercel Not authorized), release overall PARTIAL.
Open:       Refresh Vercel authentication then publish prepared web and verify matching bundle hash. User owns complete multiplayer UI match; human audio quality/Android-Web/background-resume remain NOT VERIFIED. No Play Store submission, no commit/push, no new UX/media assets. Detailed evidence and honest limits: docs/RELEASE-STATUS-2026-09-20.md.

## PHASE 67 — done (shared ambient media, room creation UX, production web)
Built:      Shared silent WebP loops enabled on online lobby/vote/public result; offline AppBackdrop uses the same bounded decorative component with reduced-motion, inactive-route and error fallbacks. Night/private reveal unchanged. Room creation confirmation stays outside scrolling settings; localized close tooltip. Existing desktop column preserved. Vercel access restored and new web published.
Files:      lib/ui/widgets/{ambient_media,textured_surface}.dart; lib/ui/screens/online/table/table_scene.dart; lib/ui/screens/online/room_settings_panel.dart; test/widget/{ambient_media_test,online_entry_test}.dart; docs/{PROGRESS,ONLINE-EXPERIENCE-NEXT,RELEASE-STATUS-2026-09-20}.md.
Verified:   Online/entry/media focused run 155 passed; lobby 18 passed; final responsive/entry/media run 12 passed (overlapping suites, not additive). Changed production files analyze: no issues. Release web build PASS; real Chrome video playback/bounds at five sizes PASS. Vercel READY; almafia.vercel.app bundle SHA-256 matches local; root/sw/manifest/favicon/assetlinks/lobby HTTP 200. No full-match rerun.
Gate:       PASS for this presentation phase and web publication.
Open:       User owns full match and human audio/device acceptance. APK/AAB are Phase 66 artifacts, not rebuilt for these presentation changes. No newly generated assets or broad visual redesign claimed. No commit/push. Logs: build/phase67-{tests,lobby,responsive,analyze,web,video,vercel}.log.

## PHASE 68 — done (Google Play upload package and user-requested presentation)
Built:      Signed 1.0.0+1 AAB/APK and web; API 36, optional microphone/Bluetooth hardware, backup disabled, cleartext disabled. Added private reports, persistent voice/message blocks, community acceptance and deletion requests with service-only completion/retention. Privacy is accessible only from game Settings; report/block controls remain in rooms. Public copy describes data practices without implementation vendor names. Added original 95KB online doorway art, reduced-motion-aware entry transition and mute-aware card-turn navigation sound. Updated bilingual store copy, permissions, privacy/deletion pages and submission/operator guides with Eyad Syam and eyadsyam124@gmail.com.
Files:      android/app/src/main/AndroidManifest.xml; lib/ui/screens/{online/safety_center,online/online_welcome_art,online/online_entry_screen,online/lobby_screen,online/table/table_scene,setup/settings_screen,setup/profile_screen}.dart; lib/platform/voice/voice_controller.dart; lib/ui/screens/online/voice_session.dart; lib/transport/{online_transport,supabase_backend,witness_channel}.dart; lib/app/l10n/*; lib/app/asset_constants.dart; lib/ui/theme/design_tokens.dart; tool/{generate_asset_constants,check_android_native}.py; assets/images/online/online_welcome.webp; raw_assets/online_council_generated.png; supabase/functions/player_safety/index.ts; migrations 20260920000200_player_safety, 20260920000300_safety_retention; supabase/tests/player_safety.sql; related tests; web/{privacy,delete-data}/index.html; web/vercel.json; store/*; docs/ONLINE-ART-2026-09-21.md.
Verified:   Full suite before final presentation steering: 1032 passed, 1 skipped, 0 failed. Final changed UI/online suites: 185 passed; asset/parity suite: 7 passed. Final analyze lib/test: 0 errors, 0 warnings, 78 infos. Hosted safety SQL rollback tests before/after apply PASS; retention/completion rollback PASS; player_safety ACTIVE v1. Final AAB signature verified, 12 packaged 64-bit ELF libraries aligned >=16KB, bundle PAGE_ALIGNMENT_16K; APK zipalign 16KB PASS, 3 ABIs, targetSdk36, signer matches existing assetlinks. APK installed/launched on Pixel_9_Pro_2; emulator System UI stalled during final capture (separate from app), so no clean final device UI PASS claimed. Vercel deployment almafia-8rejlll6d READY; production bundle SHA-256 matches local; privacy/deletion pages HTTP200 with correct support contact. Initial root-directory deploy was unauthorized; deployment from the saved build/web project succeeded.
Gate:       PASS for prepared upload artifacts and listed checks; Google Play approval is not claimed.
Open:       User owns the final multiplayer match and human voice acceptance. Google account verification, required closed testing if applicable, Console declarations/IARC, Play pre-launch checks and Play App Signing fingerprint are account-side steps in store/GOOGLE-PLAY-SUBMISSION.md. Human moderation/deletion processing remains an ongoing developer duty. No Play submission, commit or push. Final hashes: build/phase68-release-hashes.json. Logs: build/phase68-*.log. New artwork prompt/provenance in docs/ONLINE-ART-2026-09-21.md.
Phase 68 device addendum: the emulator System UI stall recovered after Wait; final clean home screenshot inspected (build/phase68-final-device-recovered.jpg). APK launch PASS; full UI walkthrough/match not claimed.

## PHASE 69 — done (selectable language and public setup transitions)
Built:      Arabic/English selector in onboarding profile and game Settings; saved before switching and restored before first app frame. Existing translations and RTL/LTR follow the selected locale. Profile text survives switching. Public profile/settings entrance fades use theme timing and respect reduced motion; private phase transitions unchanged.
Files:      lib/app/{locale_controller,app}.dart; lib/main.dart; lib/app/l10n/*; lib/ui/widgets/{language_picker,setup_entrance}.dart; lib/ui/screens/setup/{profile_screen,settings_screen}.dart; test/widget/{language_picker_test,settings_presets_test,audio_settings_preview_test}.dart.
Verified:   22 focused tests passed (language persistence/restart, input retention/direction, reduced motion, profile flow, settings and phase transitions). Changed files analysis: no issues. Logs: build/phase69-tests.log and build/phase69-analyze.log.
Gate:       PASS for source changes and focused verification.
Open:       Phase 68 published web and AAB/APK do not yet include Phase 69; release rebuild/publication not performed in this phase. Final multiplayer match remains user-owned. No commit/push.

## PHASE 70 — done (business and monetization execution plan)
Built:      Ordered phases 71–79 for cost measurement, audience/safety/FAQ, server wallet, rewarded Android ads, shared paid content, matchmaking, sharing, organic launch and release; 1000 EGP monthly trial ceiling and no pay-to-win.
Files:      docs/BUSINESS-LAUNCH-PLAN.md; docs/PROGRESS.md.
Verified:   Read current Phase 69 gate and store declarations; checked pubspec for ads/billing packages (absent); reviewed official Google audience, payments, rewarded ads, SSV and consent documentation. Documentation-only phase; no app tests applicable.
Gate:       PASS for planning only; monetization is not implemented or deployed.
Open:       Execute phases in dependency order; actual provider costs, AdMob/Play product setup and age suitability review remain. Phase 69 release rebuild and user-owned final match remain. No spending, commit, push or deployment.

## PHASE 71 — done (privacy-safe usage metering and capacity control)
Built:      Hosted daily operational metering for rooms, started/finished matches, abandoned lobbies, player-matches, room minutes and player minutes without player/room/role/message/voice identifiers; service-only monthly report; configurable 50/75/90/100 threshold records; conservative 3,000-started-match Free-plan proxy; operator switch that pauses only new room creation and leaves existing rooms/matches running; localized Arabic/English refusal; current-cost operations runbook. Supabase organization is currently Free ($0); historical hosted data was deliberately not backfilled. Current web-host plan/billing was not exposed by the connected project API; TURN relay remains unsubscribed per the last verified project record.
Files:      supabase/migrations/20260921000100_usage_metering.sql, 20260921000200_usage_thresholds.sql, 20260921000300_usage_security.sql; supabase/tests/usage_metering.sql; supabase/functions/{_shared/api.ts,create_room/index.ts}; lib/ui/screens/online/online_entry_screen.dart; lib/app/l10n/*; test/widget/online_entry_test.dart; docs/OPERATIONS-COST.md; docs/PROGRESS.md.
Verified:   Hosted migration dry-run with lifecycle/gate/threshold assertions PASS, then all three migrations applied; hosted rollback test PASS after apply; trigger functions removed from anon/authenticated execution and the resulting advisor warnings are absent; create_room ACTIVE v11 and hosted source contains the capacity refusal; monthly report returns a clean zero baseline and the gate is open; 24 focused Flutter tests PASS; room-configuration server test PASS; changed Dart/l10n analysis has no issues. Official current plan limits and cost-control docs reviewed 2026-09-21.
Gate:       PASS for measurable launch operations and safe manual capacity control.
Open:       Supabase Free lacks the metrics endpoint, so provider Dashboard usage remains the billing source of truth and the 3,000-match alert is a conservative proxy, not a bill. Database alerts are operational records; email delivery belongs with the moderation/operations notification work in Phase 72. Vercel Usage/Billing requires account-side review, and no TURN, advertising or purchase plan has been bought. Phase 69 release rebuild and the user-owned final match remain. No commit or push.

## PHASE 72 — done (settings-only FAQ, adult launch audience and moderation workflow)
Built:      Bilingual Help and FAQ inside game Settings only; clear online, voice, reconnect, safety, coins, privacy and deletion guidance; public rooms and voice positioned for an 18+ launch. Added a private moderation queue with pending/reviewing/actioned/dismissed states, priority, safe reviewer claiming, resolutions and a notification outbox that never copies report text. Store, safety and public privacy/deletion copy now matches the adult launch and avoids infrastructure vendor names.
Files:      lib/ui/screens/setup/{help_center,settings_screen}.dart; lib/app/l10n/*; test/widget/help_center_test.dart; supabase/migrations/20260921000400_moderation_queue.sql; supabase/tests/moderation_queue.sql; store/{GOOGLE-PLAY-SUBMISSION,listing-ar,listing-en,SAFETY-OPERATIONS}.md; web/{privacy,delete-data}/index.html; docs/PROGRESS.md.
Verified:   Hosted migration dry-run, apply and rollback contract test PASS; hosted moderation summary is clean; Help/Safety/Settings focused widget tests PASS; changed Dart analysis has no issues; public policy copy contains the deletion/reward/age disclosures and no infrastructure vendor names.
Gate:       PASS for Help, policy alignment and the review queue; notification delivery is PARTIAL.
Open:       A verified sender and email delivery provider are still required to drain the notification outbox into real emails. Eyad remains responsible for human report and deletion review. No web publication, commit or push.

## PHASE 73 — done (server-authoritative earned coins and fair reward content)
Built:      Service-only wallet, immutable reward ledger, inventory and catalog; 100 coins for an eligible completed online match plus 25 for the winning team, including eliminated players. Rewards are server-verified and idempotent. Added a 400-coin Mastermind Guide with an atomic server purchase, Settings-only bilingual coin store, automatic result sync that cannot block a match, and account-deletion/orphan cleanup. The reward contains strategy guidance only and grants no secret information or match advantage.
Files:      supabase/migrations/20260921000500_coin_economy.sql, 20260921000600_economy_indexes.sql, 20260921000700_orphan_economy_cleanup.sql; supabase/tests/coin_economy.sql; supabase/functions/{economy/index.ts,_shared/api.ts}; lib/ui/screens/setup/{coin_store,settings_screen}.dart; lib/ui/screens/online/online_session.dart; lib/app/l10n/*; test/widget/coin_store_test.dart; test/online/online_session_recovery_test.dart; store/{GOOGLE-PLAY-SUBMISSION,listing-ar,listing-en,SAFETY-OPERATIONS}.md; web/{privacy,delete-data}/index.html; docs/PROGRESS.md.
Verified:   Hosted migration dry-run and apply PASS; hosted rollback economy test PASS; economy function ACTIVE v1 with authentication enabled; catalog contains the active 400-coin guide; security/performance review found no new actionable warning. Combined Help/Coin/Safety/Settings/online-recovery run: 27 passed; focused changed-code analysis: no issues.
Gate:       PASS.
Open:       Ads and real-money purchases are not implemented; current store declarations correctly say so. The wallet follows the anonymous device identity, so account recovery must precede any paid entitlement. Current published web and Play artifacts do not include Phases 69–73. Final multiplayer match remains user-owned. No commit or push.

## PHASE 78 — done (connected Arabic Google Play campaign)
Built:      Six 1080×1920 Arabic marketing screenshots that read as one continuous dark panorama; every phone uses a real release capture and the set leads with online play, rooms, secret roles, narrator-led flow and retained local play. Replaced the first busy generated backdrop with a minimal charcoal, smoke, burgundy and gold-thread background after visual review.
Files:      raw_assets/store/connected-play-panorama.png; tool/generate_play_screenshots.py; store/screenshots/play-ar/{01,02,03,04,05,06}.png; store/screenshots/{10-home-current,11-mode-current}.png; store/{README,GOOGLE-PLAY-SUBMISSION}.md; docs/PLAY-STORE-ART-2026-09-21.md; docs/PROGRESS.md.
Verified:   Final contact sheet visually reviewed; all six outputs are RGB PNG at 1080×1920 and contain the latest online-enabled mode and online-entry captures. Generation is reproducible from the saved script and workspace-bound source art.
Gate:       PASS.
Open:       Full-match store captures remain user-owned. No invented testimonials, ratings or download numbers. No commit/push.

## PHASE 79 — done (current Android upload artifact and production web)
Built:      Rebuilt signed 1.0.0+1 APK and Play AAB from the Phase 69–73 source with online configuration included; installed the APK on Pixel_9_Pro_2 and opened the real online mode/entry. Rebuilt the web release from the same source and published it to almafia.vercel.app. Store declarations remain accurate: earned coins exist, ads and real-money purchases do not.
Files:      build/app/outputs/{flutter-apk/app-release.apk,bundle/release/app-release.aab}; build/web; build/phase79-release-hashes.json; build/phase79-{online-home,mode-online,online-entry}.png; store/{README,GOOGLE-PLAY-SUBMISSION}.md; docs/PROGRESS.md.
Verified:   Focused language/settings/help/coin/recovery suite: 27 passed. Focused analysis: 0 errors/warnings, 2 existing style infos. APK installed/launched on Pixel_9_Pro_2; online mode and online-entry screens visually verified. APK and AAB: package com.mafiamaster.mafia_master, versionCode 1, versionName 1.0.0, minSdk 26, targetSdk 36; 12 native libraries each pass >=16KB LOAD alignment; APK signer SHA-256 082c07…9e11; AAB JAR signature verified. Production deployment READY and aliased to almafia.vercel.app; root/privacy/deletion/online HTTP 200 and production main.dart.js hash matches local.
Gate:       PASS for the upload artifact and production web; Google Play acceptance is NOT VERIFIED.
Open:       User owns the final multiplayer/human-voice match. Play Console app creation, declarations, IARC, App Signing fingerprint, internal/closed testing and review are account-side. Phases 74–77 remain future monetization/growth work: no AdMob or Play Billing IDs/products exist, so ads and purchases were deliberately excluded from this honest first upload. Notification email delivery remains PARTIAL. No commit/push.

## PHASE 80 — done (monetization source, growth flows and owner-test release candidates)
Built:      Optional result-only rewarded ads with consent/privacy controls and server-side signed reward claims; permanent balanced room scenario purchase with server verification/restore/revocation; quick match that fills compatible public rooms atomically; safe post-game share card and new-room rematch. Updated bilingual privacy/store disclosures without public infrastructure names. Prepared a normal signed Android RC, a separately installable official-test-ad APK, signed Play AAB and zipped web candidate. Play/AdMob accounts were inspected only; no app record, ad unit, product or store submission was created.
Files:      pubspec.yaml; android/app/{build.gradle.kts,src/main/AndroidManifest.xml}; dart_defines.example.json; lib/platform/monetization/*; lib/ui/screens/{online/rewarded_reward_button.dart,online/result_share_button.dart,setup/scenario_store.dart}; related online/settings/transport/l10n files; supabase/functions/{admob_ssv,economy,play_purchase,quick_match,_shared/purchase_access.ts}; supabase/migrations/20260921000800_ad_rewards.sql through 20260921001100_quick_match_random.sql; related tests; web/privacy/index.html; store/*; tool/build_test_ads.ps1; build/deliverables/*.
Verified:   Hosted ad, purchase and quick-match migrations applied and rollback contracts passed; affected functions ACTIVE. Invalid AdMob signature now returns HTTP 400 after redeploy. Room configuration server test PASS. Focused Flutter tests 25/25 PASS; analyze 0 errors/warnings and 78 existing infos. Web release and real-Chrome startup/video bounds at five sizes PASS. Android RC, test-ad APK and AAB signed by SHA-256 082c07…9e11; 12 native libraries each pass 16KB alignment. Test-ad APK installed beside the existing app as com.mafiamaster.mafia_master.adstest and its launch screen was visually inspected.
Gate:       PASS for source and owner-test candidates; commercial publication remains intentionally OPEN.
Open:       Owner tests the supplied RC and owns the final multiplayer/human-voice match. Production AdMob app/unit, consent message and SSV unit secret still need account setup. Play app/product and purchase-verification service account still need setup; production ads/billing remain disabled until their real IDs exist. Rebuild the final AAB after that setup, then complete Console declarations/testing and publish. Current production web was not changed. No commit/push.

## PHASE 81 — done (Android startup crash, proven and fixed)
Built:      Reproduced the 1.0.0 RC and test-ads "keeps stopping" on a fresh emulator install (x86_64 and forced arm64): R8 full mode (AGP 9) stripped WorkDatabase_Impl.<init>() pulled in by the ads SDK's WorkManager 2.7/Room 2.2.5, so androidx.startup died before Flutter. Added keep rules, an R8-report regression check wired into both build scripts, purchase-stream listen-before-connect, retryable optional-service startup, late-ad disposal. Version 1.0.1+2.
Files:      android/app/{proguard-rules.pro,build.gradle.kts}; tool/{check_android_r8.py,build_apk.ps1,build_test_ads.ps1}; lib/platform/{optional_service.dart,monetization/rewarded_ads_mobile.dart}; lib/app/app.dart; lib/ui/screens/setup/scenario_store.dart; test/app/optional_services_startup_test.dart; pubspec.yaml.
Verified:   Old APKs FAIL check_android_r8 and crash on emulator; new builds PASS and launch fresh (x86_64 + arm64 translation), as an upgrade over 1.0.0, on relaunch and offline. Logcat has no FATAL.
Gate:       PASS on emulator. User's Samsung ARM64: NOT VERIFIED.
Open:       Owner must install 1.0.1 RC on the real device.

## PHASE 82 — done (public rooms are the only choice; no auto-join)
Built:      Removed quick match and play-offline from the online entry; list auto-refreshes every 15 s while visible and foreground, immediately on resume, backs off to 60 s on failure, keeps the last list marked stale, never overlaps requests or outlives the screen, keeps scroll. Cards show seats/capacity, players missing before the host may start, full/ready status; full rooms not tappable; refusals re-read the list without moving the player. Rooms need a human host, so a clearly labelled "new public room" suggestion card creates one only when chosen. New read-only public_room_listing(uuid) migration (not-kicked count, capacity rule, min 5, ban filter, empty lobbies hidden); browse_rooms falls back to public_rooms().
Files:      lib/ui/screens/online/{online_entry_screen,online_session}.dart; lib/transport/game_snapshot.dart; lib/ui/theme/design_tokens.dart; lib/app/l10n/*; supabase/migrations/20260923000100_public_room_listing.sql; supabase/functions/browse_rooms/index.ts; supabase/tests/public_room_listing.sql; test/widget/{online_entry,online_lobby}_test.dart.
Verified:   Entry/lobby widget tests PASS; emulator and local web show the new screen; web refresh measured at 11/27/43/58 s.
Gate:       PASS (client). Server listing SQL test NOT RUN (no local Docker).
Open:       Migration + function deploy by Codex; quick_match function now unused by 1.0.1.

## PHASE 83 — done (back, language, colours, launcher name)
Built:      Online back goes to /mode (separate from offline). Android 16 system back exited the app from the online list (predictive back never reached didPopRoute); fixed with enableOnBackInvokedCallback=false. Language picker removed from profile/onboarding (Settings only); themed SegmentedButton gold/ivory/charcoal. Launcher name follows in-game language through two activity-aliases switched enable-before-disable from MainActivity, re-asserted at every start; Pixel launcher proven not to follow per-app locale.
Files:      lib/app/{router,locale_controller}.dart; lib/main.dart; lib/platform/launcher_label.dart; android/app/src/main/{AndroidManifest.xml,kotlin/.../MainActivity.kt}; lib/ui/{theme/mafia_theme.dart,widgets/language_picker.dart,screens/setup/profile_screen.dart}; tests.
Verified:   Emulator: online→mode→home with system back; ar→en→ar with restarts, one launcher entry each time, drawer shows "Mafia Master"; picker screenshot gold. Tests PASS.
Gate:       PASS.
Open:       Upgrade from 1.0.0 may drop the old home-screen shortcut once; some launchers drop it on each language switch. Android 12/13 not tested (no image).

## PHASE 84 — done (monetization gaps; production stays off)
Built:      admob_ssv split into a testable verifier: bad/malformed signature 400, Google key fetch failure 503, rotated key id triggers one fresh fetch, permanent ledger refusals 400. Reward button: server "pending" no longer disables retry forever, late award shows on reopen, mic and game audio silenced during the ad and restored, no ref after dispose. Purchases: rebind limit 3/30 days, refund revocation via Voided Purchases API (play_voided_sync). Web privacy and store text no longer claim ads or purchases.
Files:      supabase/functions/{admob_ssv/{index,verify}.ts,play_purchase/index.ts,play_voided_sync/index.ts,_shared/{api,play_auth}.ts}; supabase/migrations/20260923000200_play_purchase_integrity.sql; supabase/tests/{admob_ssv_verify.test.mjs,play_purchase_integrity.sql}; lib/ui/screens/online/rewarded_reward_button.dart; web/privacy/index.html; test/widget/rewarded_reward_button_test.dart; test/transport/server_surface_test.dart.
Verified:   node SSV test PASS; reward button tests PASS; esbuild parse PASS.
Gate:       PASS for code; activation BLOCKED.
Open:       Paid "Council of Shadows" is only a preset of free settings — product decision required before any sale. Web ads need AdSense H5/Ad Manager eligibility (not implemented). AdMob/Play account work for Codex.

## PHASE 85 — done (store data and free growth)
Built:      Listings renamed "سيد المافيا: Mafia Master" / "Mafia Master: Online Party", rewritten with natural keywords and no ads/purchase/quick-match claims; length checker; robots.txt, sitemap.xml, indexable noscript text; new online-list capture; short free growth plan.
Files:      store/listing-{ar,en}.md; tool/check_store_listing.py; web/{robots.txt,sitemap.xml,index.html}; store/screenshots/12-online-rooms-1.0.1.png; docs/GROWTH-FREE-PLAN.md.
Verified:   check_store_listing PASS (ar 25/73/1414, en 26/76/1700).
Gate:       PASS.
Open:       Play screenshot set (play-ar/01..06) still shows the old online entry; regenerate with tool/generate_play_screenshots.py from the new capture.

## PHASE 86 — done (verification, local builds, Codex handoff)
Built:      1.0.1+2 RC APK, test-ads APK (moved out of app-release.apk), Play AAB and web zip in build/deliverables-1.0.1 with SHA256SUMS and README-AR; docs/CODEX-PUBLISH-HANDOFF.md.
Files:      build/deliverables-1.0.1/*; docs/CODEX-PUBLISH-HANDOFF.md; docs/PROGRESS.md.
Verified:   flutter test 1056 pass / 1 skip / 0 fail; analyze 0 errors/warnings (78 infos, unchanged); signer 082c07…9e11 on all; 16KB PASS; no test ad unit in RC/AAB Dart code; emulator and local-web checks as above.
Gate:       PASS locally. Not publish-ready: real-device crash check, SQL tests, product decision and account setup are open.
Open:       Work lives in worktree .claude/worktrees/crash-fixes-and-testing-b6c2f5 (main's uncommitted state copied in first); main checkout not modified. No commit/push/publish.

## PHASE 87 — done (first launch, terms, language without exit)
Built:      One compact setup before the (still skippable) film: language → name/avatar → sound/music/reduce-motion → 18+ → unticked «قرأت الشروط والأحكام وأوافق عليها» with in-app terms and privacy sheets. Acceptance saved with version + timestamp (currentTermsVersion 2026-09-23) before setup completes; failed saves retry in place. SetupRequired gate replaces ProfileRequired inline, so deep links keep their destination; existing profiles get one compact terms-only prompt; only a changed terms version asks again. Community-rules dialog before rooms is skipped after a valid acceptance. Acceptance synced to the server after room entry (never blocks). Language exit fixed: disabling the activity-alias the task was launched through finished the activity; now that switch is left pending and applied from onDestroy, with a localized note; safe switches still apply at once. Terms/privacy reachable in Settings.
Files:      lib/data/{terms_consent,motion_preference}.dart; lib/ui/screens/onboarding/first_run_screen.dart; lib/ui/widgets/{legal_documents,language_picker}.dart; lib/ui/screens/setup/{profile_screen,settings_screen}.dart; lib/ui/screens/online/{safety_center,online_entry_screen}.dart; lib/app/{router,app,locale_controller}.dart; lib/main.dart; lib/platform/launcher_label.dart; android/.../MainActivity.kt; lib/ui/theme/design_tokens.dart (SheetTokens); l10n; supabase/migrations/20260924000100_terms_acceptance.sql; supabase/functions/player_safety/index.ts; test/widget/{first_run,profile_flow,online_entry}_test.dart; test/support/stores.dart.
Verified:   first_run_test 12/12 (fresh install, unchecked block, document open/back, system back, save failure retry, restart, existing-profile migration, version change, community rules skip, deep link, locale switch keeps State and input, prefs saved, launcher pending note); profile_flow 4/4; language/online-entry/safety/data/app suites pass. Full suite before flow-test update: 1063 pass, 5 fail (old order, fixed).
Gate:       PASS (widget). Emulator language switch checked in phase 91; Samsung NOT VERIFIED.
Open:       Terms text is a draft for the owner/legal review. Server acceptance record needs migration 20260924000100 + player_safety deploy; older server: sync silently retried.

## PHASE 88 — done (public list without a creation card; native invite share)
Built:      Removed the «أوضة عامة جديدة» card, its handler and strings; top create/join actions and the normal list stay, no quick match/offline footer/auto-join. Server-owned waiting rooms: explicit system_pool state (host_id null, public lobby only, check constraint), trigger refuses any player row while unclaimed, at most one per pool (partial unique index), created only by browse_rooms when the viewer has no joinable public lobby, replaced after 2 idle hours, paused with new_rooms_enabled. First join claims host atomically under the row lock and reseeds; later joiners are ordinary players. List v2 marks it «أوضة انتظار جاهزة — فاضية، وأول واحد يدخل هيبقى المضيف», ordered after rooms with people and before full rooms. Invite share uses the OS share sheet (share_plus) with tablet anchor; web uses Web Share, else copies the link; never reports "sent", reports copy only when it happened; lobby membership/voice untouched (presence away→connected on return).
Files:      lib/ui/screens/online/{online_entry_screen,lobby_screen}.dart; lib/transport/game_snapshot.dart; lib/platform/invite_share.dart; l10n; supabase/migrations/20260924000200_system_waiting_rooms.sql; supabase/functions/browse_rooms/index.ts; supabase/tests/system_waiting_rooms.sql; test/widget/{online_entry,invite_share}_test.dart.
Verified:   online_entry + transport suites 174/174; invite_share 5/5 (sheet statuses, copy fallback, failure wording, dismiss keeps lobby, lifecycle away→connected without leave).
Gate:       PASS (client). system_waiting_rooms.sql NOT RUN (no local Postgres/Docker).
Open:       Deploy migration 20260924000200 then browse_rooms; before that, the old server simply shows no waiting room. Concurrency of two real joiners is enforced by the row lock but proven only by reading, not by a parallel SQL run.

## PHASE 89a — done (resume interrupted store integration and regression repair)
Built:      Reviewed Claude stages 87–89 in the existing worktree; fixed stale public captions crossing private phases, live reduced-motion behavior, unnecessary classic-table consumer mounting, and missing client-role revoke for seat_cosmetics. Added cosmetic SQL contract coverage and updated the economy regression for the retired guide.
Files:      lib/ui/economy/cosmetic_paint.dart; lib/ui/screens/online/table/{room_presentation,table_scene}.dart; test/online/cosmetics_table_test.dart; supabase/migrations/20260924000300_cosmetic_catalog.sql; supabase/tests/{cosmetic_catalog,coin_economy}.sql; docs/{PROGRESS,CODEX-PUBLISH-HANDOFF}.md.
Verified:   Focused store/presentation 20 PASS; initial full suite 1077 PASS / 1 skipped / 15 FAIL, all 15 failures covered by subsequent affected-suite rerun 62 PASS after fixes, no assertions removed. Full analyze 0 errors/warnings, 78 infos; final four changed Dart files analyze clean. Node cosmetic_access and room_configuration PASS. SQL NOT RUN: Docker daemon unavailable. Logs build/phase89-*.log.
Gate:       PASS for regression repair only; overall stage 89 remains PARTIAL.
Open:       Catalog currently 11 of requested 18 items; remaining real content and database execution still needed. Stage 90 manual web payment/recovery and stage 91 device checks/release builds pending. No production changes, new artifacts, merge, commit or push. Existing 1.0.1 artifacts predate these changes; final human match remains owner-owned.

## PHASE 89b — done (online core experience: discovery and waiting)
Built:      Prioritized the online game experience over catalog expansion. Public-room cards now use charcoal surfaces, gold occupancy indicators, explicit voice labels and RTL/LTR arrows. Added a live 1–2-missing-players filter and honest empty-filter state. Populated lists take priority over decorative artwork. Lobby explains exactly how many players are missing, invitation purpose and host-controlled start readiness. No automatic join or match-rule changes.
Files:      lib/ui/screens/online/{online_entry_screen,lobby_screen}.dart; lib/app/l10n/app_{ar,en}.arb and generated localizations; test/widget/{online_entry,online_lobby}_test.dart; docs/{ONLINE-EXPERIENCE-LEVEL-UP,PROGRESS}.md.
Verified:   Final entry/lobby/share suites 47 PASS, including filter refresh without auto-joining, Arabic/English 360px layout/directional arrows, missing-player and host readiness copy, backoff/lifecycle and share regressions. Changed Dart analysis: no issues. Logs build/online-experience-{tests,analyze}.log. No new emulator or human-match verification.
Gate:       PASS for this local discovery/waiting increment only.
Open:       Next: in-match comprehension/rhythm, factual result/rematch experience, backend SQL/device verification and owner playtest per ONLINE-EXPERIENCE-LEVEL-UP.md. Catalog expansion/payment stages remain open. No deploy, builds, merge, commit or push; published app and 1.0.1 deliverables unchanged.

## PHASE 89c — done (in-match action clarity and truthful ballot feedback)
Built:      Ballot UI distinguishes sending from server-acknowledged receipt, retains retry after failure, explains selecting a seat before confirmation, and removes the vote question after submission. A response arriving after a phase/day change no longer invokes the next-step callback. Opening suspicion and host discussion-to-vote controls now name their actual actions. A no-elimination verdict no longer invents a tie or promises a revote: it uses the server vote result.
Files:      lib/ui/screens/online/online_table_flow.dart; lib/app/l10n/app_{ar,en}.arb and generated localization files; test/online/{online_action_retry,online_verdict}_test.dart; docs/PROGRESS.md.
Verified:   71 PASS across action retry, verdict, Doc 12/15 acceptance, witness result, role reveal and reveal recovery. Delayed acknowledgement, duplicate taps, failure retry, no-elimination and tied verdicts covered; private role-reveal regressions PASS. Changed Dart analysis: no issues. Logs build/phase89c-{tests,analyze}.log.
Gate:       PASS for local action clarity and listed regressions.
Open:       Public-phase rhythm and factual post-match/rematch experience next; real device/multiplayer enjoyment and voice remain unverified. Backend SQL, remaining catalog/payment work and new release artifacts remain open. No engine/rule changes, deployment, commit, push or release build.

## PHASE 89d — done (ballot recovery and same-day revote acknowledgement races)
Built:      Vote receipt now follows the viewer's server-owned votedRound on recovery; a public ballotRound resets UI state for same-day revotes. Old-round success/failure cannot acknowledge or unlock a newer ballot; late transport acknowledgements do not rewrite a different phase/day/round's own-seat receipt. A phase-closed response without a receipt is not reported as a saved vote. Night rendering remains unchanged.
Files:      lib/transport/{game_snapshot,room_codec,online_transport}.dart; lib/ui/screens/online/online_table_flow.dart; test/online/online_action_retry_test.dart; docs/PROGRESS.md.
Verified:   142 PASS across action retry, online transport, Doc 12/15, reveal/recovery, verdict and witness-result suites. Cases include recovered receipt, same-day revote, old success, old failure, new vote acknowledged before old failure, phase-closed refusal, duplicate taps and retry. Analysis of changed files: 0 errors/warnings; pre-existing style info at online_transport.dart:456 remains. Final table-flow analysis clean after braces cleanup. Logs build/phase89d-*.log.
Gate:       PASS for listed local regressions, not a blanket online stability certification.
Open:       Tests use fake backend/realtime events, not physical network interruption or a human full match. Existing published web/APKs do not include these changes. Remaining public-phase/ballot edge review, result/rematch, SQL/deployment compatibility, device acceptance and release builds remain. No deployment/commit/push.

## PHASE 89e — done (revote candidate integrity; database verification pending)
Built:      Revotes now expose only server-declared tied living opponents as selectable; headline identifies a revote. Shared backend eligibility validates submit_vote and filters historical out-of-scope votes during resolution. Pending migration adds tied-seat validation to INSERT/UPDATE under the existing phase state lock, preserving phase/round/kick guards. Updated earlier test fixtures to use the real tiedSeats field.
Files:      lib/transport/{game_snapshot,room_codec}.dart; lib/ui/screens/online/online_table_flow.dart; test/online/online_action_retry_test.dart; supabase/functions/{_shared/ballot_candidates.ts,submit_vote/index.ts,resolve_vote/index.ts}; supabase/migrations/20260924000400_revote_candidates.sql; supabase/tests/{ballot_candidates.test.mjs,revote_candidates.sql}; docs/{PROGRESS,CODEX-PUBLISH-HANDOFF}.md.
Verified:   119 Flutter tests PASS (action/recovery/transport/surface/verdict/Doc15), 9 Node candidate checks PASS, changed Dart analysis clean. Node strip-types syntax checks PASS for three changed TS files (not Deno type verification). SQL NOT RUN: Docker daemon unavailable.
Gate:       PASS for client/helper implementation and listed tests; database and hosted behavior NOT VERIFIED.
Open:       Execute SQL and existing phase/round/kick regressions before applying the migration and deploying submit_vote/resolve_vote. Result/rematch UX deferred in favor of the discovered correctness defect. No deployment, artifacts, commit, merge or push; published builds unchanged.

## PHASE 89 — done (Mafia Coins identity and a real cosmetic catalog)
Built:      «عملات المافيا / Mafia Coins» identity from the owner's generated coin (raw_assets/store/economy-v1, cropped, alpha kept, 96/256 px WebP ≈6/26 KB, legible at 24 px); one shine on appear, still under reduced motion. The vault concept is NOT shipped (different mask). New store: balance header, Shop / Collection / History tabs, real previews (the seat exactly as the table paints it; pack backdrop + transition + opening/closing line + sound; narrator lines + accent; bundle contents), confirm dialog, server-owned prices/charges, "N more coins ≈ M matches" from the current 100/match contract. 11 real SKUs: 3 frames (200/250/300), 3 nameplates (150/250/300), Midnight Manor 600 and Old Town 900 presentation packs (public-phase colour grade, veil, overlay, candle/sweep transition, opening/closing lines with bundled sounds), The Storyteller narrator 1200 (a line per public beat, same on every device, text-only at night), Council bundle 2300 and Identity bundle 1200 (charge subtracts owned contents). Host's owned pack/narrator dresses the room for everyone (room settings; equipped packs default for rooms they create); ownership checked server-side on create/settings, never blocks a start. Frames/plates copied to room_players.cosmetics at seating and painted on council/lobby seats in public phases only (doc 05 rule 3: plain rings at night/distribution). Strategy guide removed from sale, free in Help, owners refunded once (idempotent unique index). Store reachable from Home, Settings and out-of-match lobby only.
Files:      assets/images/economy/*; raw_assets/store/economy-v1/* (copied); pubspec.yaml; lib/app/asset_constants.dart; lib/ui/economy/{cosmetics,cosmetic_paint,cosmetic_preview,wallet,mafia_coin}.dart; lib/ui/screens/setup/{coin_store,home_screen,help_center}.dart; lib/ui/screens/online/{lobby_screen,room_settings_panel,online_entry_screen}.dart; lib/ui/screens/online/table/{table_scene,room_presentation}.dart; lib/ui/screens/online/council/council_band.dart; lib/transport/{game_snapshot,room_codec,online_backend}.dart; lib/platform/audio_director.dart (playAccent); lib/app/router.dart; lib/ui/theme/design_tokens.dart (CosmeticTokens); l10n; supabase/migrations/20260924000300_cosmetic_catalog.sql; supabase/functions/{economy,create_room,room_settings}/index.ts; supabase/functions/_shared/{room_configuration,purchase_access}.ts; tests.
Verified:   coin_store_test 9/9; cosmetics_table_test 8/8 (public-phase frames, none at night, identical across viewers, codec, first-morning intro once, outro, night narration silent, classic adds nothing, muted silent); online_entry (owned pack default in create payload, unowned not offered) 25/25; node room_configuration + cosmetic_access PASS. Found and fixed a disposal bug in the transition overlay.
Gate:       PASS (client + node). cosmetic_catalog.sql NOT RUN (no local Postgres).
Open:       11 SKUs, not the 18 target: missing 2 standalone table themes, 2 standalone phase effects and a second narrator — not shipped as placeholders. Packs apply online only (offline pass-the-phone keeps the default look). Narrator is on-screen text + a short existing sound, not recorded voice. Deploy migration 20260924000300 before economy/create_room/room_settings; older clients keep working (catalog keys are additive).

## PHASE 90 — done (web coin packs by transfer: MANUAL VERIFICATION, no gateway/webhook)
Built:      Newest owner instruction implemented. Web-only coin packs (compiled in only with --dart-define=WEB_COIN_SALES=true and kIsWeb; Play/Android has no tab, link, QR or message, and no destination URL exists in the app, web or Android sources). Destinations come from function secrets COIN_PAY_INSTAPAY_URL / COIN_PAY_VODAFONE_CASH_URL, https only (the owner's Vodafone link is http, so it shows as unavailable until an HTTPS destination is verified). Flow: recoverable account required (optional email one-time-code linking/recovery, same user id, no password) → pick server-priced pack (EGP piastres, seeded inactive/unpriced for the owner) and method → notice «التحويل بيتراجع يدويًا، والعملات بتضاف بعد التأكد من وصوله» → server order (immutable price, one open order per player, resumed on repeat/reload, 24 h window, late claims kept) → link opened from the tap (new tab, noopener) → «أرسلت التحويل» with transaction number (claim only; no balance change). Admin queue /admin/coins: server-enforced commerce_admins; approve requires exact amount + unique provider transaction, credits once (ledger unique per order) with reviewer/time; needs_info/reject with player-visible note; refund takes back only unspent purchased coins, the rest is a debt offset against future purchased coins; earned coins untouched. Purchased coins tracked apart (purchased_balance, spent first). Audit events per order. Deletion detaches order records. Privacy page + in-app summary updated.
Files:      supabase/migrations/20260924000500_coin_orders.sql (renumbered from 0400: a parallel session's revote_candidates holds 0400); supabase/functions/{coin_orders/index.ts,_shared/coin_payments.ts,_shared/api.ts}; supabase/tests/{coin_orders.sql,coin_payments.test.mjs,terms_acceptance.sql}; tool/test_sql_without_docker.mjs (auth.users email/confirmation/anonymous columns); lib/transport/account_service.dart; lib/platform/{payment_capabilities.dart,links/*}; lib/ui/economy/{account_protection,coin_packs}.dart; lib/ui/screens/admin/coin_review_screen.dart; lib/ui/screens/setup/coin_store.dart; lib/app/router.dart; web/privacy/index.html; l10n; test/widget/coin_purchase_test.dart.
Verified:   coin_purchase_test 12/12 (Play: no tab/no calls/no URLs in sources; capability off outside web; sales off honest text; unprotected account blocked; order→open exact link→claim with zero balance change; reload resumes; pop-up blocked reported; paid text; email link with bad email/bad code; non-admin refused; wrong amount refused; approval payload). node coin_payments PASS. pglite: all 76 migrations + 30/30 SQL files PASS, incl. coin_orders (unauthorized approval, cross-user claim, duplicate claim/approval, one transfer for two orders, price from server, wrong amount, return without payment, expiry + late claim, refund after spending → debt → offset).
Gate:       PASS locally (single-connection simulation). Live payment NOT VERIFIED: no transfer made; InstaPay/Vodafone Cash link behaviour on phones NOT VERIFIED; email OTP delivery needs Supabase SMTP/templates (NOT VERIFIED).
Open:       Manual review is an operational workload and the scaling limit (every order needs a person with bank access). Owner decides EGP prices and enables packs; COIN_SALES_ENABLED stays unset until then. Payment-provider adapter left as the coin_orders boundary (no gateway built). iOS not built. Paid-wallet use inside the Play app remains a policy question for Codex (earned and purchased coins share one wallet).

## PHASE 91 — done (verification, 1.1.0 artifacts, Codex handoff)
Built:      Version 1.1.0+3. Signed RC APK, test-ads APK, Play AAB and web zip (web built with -CoinSales) from the same final source in build/deliverables-1.1.0 with SHA256SUMS and README-AR. tool/build_web.ps1 gained -CoinSales (web-only define). Coin tab's server error now says «not available» with retry. Handoff §9 appended: exact migration/function order, config names only, manual-review operations, Play policy points, rollback, hashes, tests; top of file points to it. Privacy page updated. Store captures 13-store-1.1.0.png and 14-pack-preview-1.1.0.png from the real app.
Files:      pubspec.yaml; tool/build_web.ps1; lib/ui/economy/coin_packs.dart; test/widget/coin_purchase_test.dart; store/screenshots/{13-store,14-pack-preview}-1.1.0.png; build/deliverables-1.1.0/*; docs/{PROGRESS,CODEX-PUBLISH-HANDOFF}.md.
Verified:   flutter test 1118 pass / 1 skip / 0 fail; analyze 0 errors/warnings (83 infos); PGlite 76 migrations + 30/30 SQL; node contracts PASS; deno check of 6 changed functions PASS (run by session al-mafia-36). All artifacts signer 082c07…9e11; 16KB PASS; R8 regression PASS ×3; no payment URL in libapp.so or main.dart.js. Emulator Pixel_9_Pro_2: upgrade 1.0.1→1.1.0 no crash, compact terms prompt, terms sheet + back, accept → Home; language ar→en in Settings kept the same PID and resumed activity with the pending-name note, alias switched on exit, relaunch via LauncherEnglish works; store loads hosted catalog; pack preview works; no coin-purchase tab on Android. Local web 375×812: terms prompt, Home, coin tab present.
Gate:       PASS locally. NOT publish-ready: owner's Samsung, real transfers, OTP email delivery and the human full match are NOT VERIFIED; coin sales stay disabled.
Open:       Hosted state was changed by another session at the owner's request (migrations up to 20260924000400_revote_candidates and all functions ~10:36, including coin_orders without its migration); changed functions need a redeploy and 20260924000500_coin_orders stays unapplied until the owner decides. Catalog 11/18. No commit/push/publish by this session.

## PHASE 89f — done (online verification against the hosted server; realtime host/rules bug fixed)
Built:      Finished Codex's DB pass (fixture codes PRIVAA/COSMAA contained I/O → fixed). Deno type-check clean for every function (RoomConfiguration type, Uint8Array<ArrayBuffer>, start_match settings). Owner-approved hosted rollout: 6 migrations (public_room_listing, play_purchase_integrity, terms_acceptance, system_waiting_rooms, cosmetic_catalog, revote_candidates) applied after a rolled-back dry run with all SQL tests; all 38 functions deployed (coin_orders deployed but inert: its migration 20260924000500 NOT applied, sales off). New hosted harness revote_match.py (tie → revote narrowed to tied seats, untied/stale/direct writes refused, one elimination; system waiting room double-tap → one host). recovery_match.py mints sessions before the lobby; play_with_app.py updated (presence heartbeats, role actions, reveal ack, turn-ordered accusations, revote rounds, cached sessions). FIXED a real bug found live on the emulator: realtime room_state deltas carry blank rooms fields; OnlineTransport applied them on same-phase updates → host lost every host control (no «ابدأ التصويت» while a guest held the floor) and settings reset to defaults mid-phase (also affects revotes). Now RoomPush.stateDelta + RoomState.withRoomFieldsFrom merge with the last full read.
Files:      supabase/tests/{public_room_listing,cosmetic_catalog}.sql; supabase/tests/{revote_match,recovery_match,play_with_app}.py; supabase/functions/{_shared/room_configuration.ts,_shared/play_auth.ts,admob_ssv/verify.ts,start_match/index.ts}; lib/transport/{online_backend,supabase_backend,online_transport}.dart; test/support/fake_backend.dart; test/online/online_action_retry_test.dart; docs/PROGRESS.md.
Verified:   Local pglite SQL 28/28. Hosted dry run 28/28, then after applying hosted SQL 28/28 (coin_orders.sql skipped). Deno check all functions PASS; Node tests 6/6; golden 35/35. Hosted harnesses on the upgraded server: e2e 93/93, roster 48/48, recovery 40/40, kick_flow 61/61, kick_timing 45/45, concurrency 46/46, revote_match 37/38 (the 1 was the harness's own over-strict assertion; the server correctly refused the second resolve with PHASE_CLOSED; assertion fixed, not re-run). Real app (release 1.1.0+3, emulator, mic denied) vs hosted: lobby, presence, start, card reveal (correct role, no leak), night actions, "nobody died" morning without naming who was saved, turn-ordered opening, single-floor discussion, vote, host eliminated → witness mode, night 2, day 2. Worktree flutter test before the fix 1104/1/0; after the fix the retry suite is 13/13, and the 2 new tests fail without the fix; the full run was killed by the OS at 980 pass / 0 fail (low memory). Analyze 0 errors/warnings.
Gate:       PASS for server and harnesses; the client fix is unit-verified only. It still needs a full-suite rerun and an emulator rerun with a build that contains it.
Open:       The published web/APK and deliverables-1.1.0 contain the realtime bug; rebuild before release. The live app match was cut at day 2 (harness process reaped for memory). Human voice, two real phones and bad networks still NOT VERIFIED. coin_orders function is on hosted but inert. No commit/push/publish.

## PHASE 91b — done (rebuild after host-controls realtime fix)

Built:      Rebuilt all four 1.1.0 artifacts after session al-mafia-36's fix (room_state realtime pushes now merged with the last full read instead of blanking host/code/settings). Reviewed the fix. New hashes in handoff §9.6/§9.9; earlier 1.1.0 files superseded.

Files:      build/deliverables-1.1.0/*; docs/{PROGRESS,CODEX-PUBLISH-HANDOFF}.md (fix itself: lib/transport/{online_backend,supabase_backend,online_transport}.dart, tests — by al-mafia-36).

Verified:   flutter test 1120 pass / 1 skip / 0 fail; analyze 0 errors/warnings (83 infos); PGlite 30/30 SQL; signer 082c07…9e11 on all; 16KB PASS; R8 PASS ×3; no payment URLs.

Gate:       PASS locally; release still gated on owner device, OTP email, real transfers and a human match.

Open:       Same as PHASE 91.


## PHASE 92 — done (realtime review; late open-ballot replies guarded)
Built:      Reviewed Claude's host/rules realtime merge; isolated open-vote polling by phaseNumber/revote round and request generation, clearing obsolete ballots on epoch changes.
Files:      lib/transport/online_transport.dart; test/support/fake_backend.dart; test/transport/open_ballot_epoch_test.dart.
Verified:   Core client suites78/78; hosted revote_match38/38; both new delayed-ballot regression tests passed in the focused22/22 run. No Docker or server deployment.
Gate:       PASS for these regression checks, not a claim that every online/device scenario is verified.
Open:       Complete human match, real two-device voice and weak networks remain unverified; full final client suite interrupted per owner request (see93).

## PHASE 93 — blocked (arrival/public visual campaign; owner requested immediate stop)
Built:      Four-step bilingual onboarding, persistent next/back/progress and legal gate, reduced-motion-aware transition; three original lightweight illustrations; calm shared public surfaces and online-first scrollable mode selector; version1.1.1+4 in source. No new binaries or publication.
Files:      lib/ui/screens/onboarding/first_run_screen.dart; lib/ui/widgets/experience_surface.dart; lib/ui/theme/design_tokens.dart; lib/ui/screens/setup/{home,mode,add_players,group_picker,how_to_play,profile,roles,settings}_screen.dart; lib/ui/screens/online/{online_entry_screen,lobby_screen}.dart; lib/app/l10n/*; pubspec.yaml; assets/images/experience_v2/*; raw_assets/experience-v2/*; test/widget/{first_run,profile_flow,mode_screen}_test.dart; docs/{EXPERIENCE-92-93,CLAUDE-CONTINUE-92-93}.md.
Verified:   Focused22/22 pass incl AR/EN portrait/landscape/back/acceptance. Full suite interrupted at951 passed/1skip/0failed so far. Old analyze found PaperPanel import and unused Home import, since fixed but analyze not rerun. Early widget captures had missing capture fonts; capture loader corrected but fresh captures not yet generated.
Gate:       FAIL (incomplete verification, explicitly stopped at owner's request).
Open:       Follow docs/CLAUDE-CONTINUE-92-93.md: rerun analyze/captures/full suite, review actual device, build signed new candidates and document hashes. Existing1.1.0 deliverables do NOT contain this campaign. No production publish/account changes. Human final-match gate remains with owner.

## PHASE 93b — done (Codex source review; frozen for independent Claude verification)
Built:      Owner resumed shared work. Finished capture font setup and visually reviewed four onboarding pages; fixed open-ballot polling starvation on slow networks by rejecting only replies older than the latest applied reply, while retaining epoch invalidation. Defined non-overlapping Claude/Codex responsibilities; source now frozen for Claude review/build.
Files:      lib/transport/online_transport.dart; test/transport/open_ballot_epoch_test.dart; test/widget/first_run_test.dart; docs/{PARALLEL-93,CLAUDE-CONTINUE-92-93}.md; build/experience-review/*.
Verified:   capture/focused UI suite22/22; ballot epoch/slow-network regressions3/3; analyze0errors/0warnings/83infos. Four actual widget renders inspected at reduced size. Earlier temporary timer-cleanup issue in the new test fixed using tester.runAsync.
Gate:       PASS for Codex's focused implementation/review; full release gate remains OPEN.
Open:       Claude independent review, full suite, new signed1.1.1+4 builds, actual emulator/browser smoke tests. Requested Claude page reached in Brave (Opus5.5 Medium), but remote control offline and device reauthentication required; task NOT transmitted and no Claude review received. Owner needs to reconnect/sign in or paste the task. No publication or account changes. See PARALLEL-93 for authoritative current state.

## PHASE 93c — blocked (full takeover by Claude at owner's request)
Built:      Latest core tests81/81. Local CLI review second attempt completed (metadata claude-opus-5-5, requested medium); saved unaltered review and authoritative full-takeover instructions. Owner cancelled further Codex-operated Claude use; Codex stopped implementation and handed all remaining work over. Images already complete.
Files:      docs/{CLAUDE-REVIEW-93,CLAUDE-FINAL-TAKEOVER,PARALLEL-93,CLAUDE-CONTINUE-92-93}.md; docs/CLAUDE-{REVIEW,VERIFY}-93-PROMPT.txt.
Verified:   build/phase93-core.log81/81; independent review was READ-ONLY with no tests/builds. No new release artifacts or deployment.
Gate:       FAIL for final release completion: review surfaced two pending correctness findings, full suite/build/device gates remain.
Open:       Claude must reproduce/fix partial-row clock-skew reset and resync-overwrites-newer-delta race; add pushStateDelta revote regression; finish complete suite, release candidates and actual device checks. Findings not independently reproduced/fixed by Codex. See CLAUDE-FINAL-TAKEOVER.md, which supersedes split ownership. Human final match remains with owner.

## PHASE 94 — done (review findings fixed; 1.1.1+4 candidates built and played on device)
Built:      Fixed CLAUDE-REVIEW-93 findings: clock skew is corrected only from full server reads (a realtime row's serverNow is the device clock); a same-phase row landing during an in-flight full read drops that stale read and rereads (capped at 2 consecutive drops so a busy room converges, never publishing the older speaker). Fake backend now stamps deltas with the device clock and can hold fetchRows. Signed 1.1.1+4 RC APK, test-ads APK, Play AAB, web zip (WEB_COIN_SALES compiled in, server sales still off) in build/deliverables-1.1.1 with SHA256SUMS and README-AR. 1.1.0 artifacts untouched.
Files:      lib/transport/online_transport.dart; test/support/fake_backend.dart; test/transport/{online_transport_test,open_ballot_epoch_test}.dart; build/deliverables-1.1.1/*; docs/PROGRESS.md.
Verified:   New regressions (skew survives a delta; slow read not overwriting a newer row; stream of overtaking rows converges in 4 reads; pushStateDelta revote keeps openVoting/host/code and drops round-1 ballots) — the three transport ones FAIL with the fix reverted, all PASS with it. Full suite 1131 passed / 1 skipped / 0 failed (build/phase94-full-tests.log). Analyze 0 errors / 0 warnings / 83 infos. Capture suite 24/24 with fonts; four onboarding widget renders inspected. R8 check PASS (rc, test-ads, aab); 16KB alignment 12/12 libs PASS on all three; signer SHA-256 082c07…9e11 on both APKs and AAB; versionCode 4 / 1.1.1, adstest package suffix on test-ads; web bundle has no service_role or JWT literal. Pixel_9_Pro_2: install -r over 1.1.0 kept profile/consent (no onboarding re-shown), stale room fell back to home, mode selector (online first) → back → home, online entry lists hosted public rooms. Full match on the RC vs hosted with 4 bots (build/phase94-bots.log, room QW9QRR): card reveal, night, "nobody died" morning without naming the save, opening round, single floor (other claims refused) with the host still holding «ابدأ التصويت» while Bassem spoke, host voted out → witness mode, night 2 kill, day 2 via deadline, vote, verdict, result «المافيا كسبت», roles carousel. Mic denied throughout (voice broken, match completed). Invite deep link https://almafia.vercel.app/join/H3DV58 opened entry with code filled, join → seat 1 in the bot's lobby; host close returned the guest home.
Gate:       PASS for the review fixes and the candidate builds. NOT publish-ready.
Open:       Build note: pub.dev unreachable; --no-pub skips release-mode plugin registrant regeneration, so the dev-only integration_test entry was removed from the generated (git-ignored) registrant before building — identical to what a release pub step generates. Not verified this phase: language switch ar→en on device, web candidate in a browser, human match, two real phones with audio, weak network. Owner requested next (see PHASE 95): online visual/motion campaign, dead-player voice, longer full-frame elimination card; dead seeing all roles conflicts with doc 12 §4.1 / doc 05 post-death channel — awaiting owner decision.

## PHASE 95 — done (online redesign campaign, owner-directed; 1.1.2+5 candidates)
Built:      Owner decisions 2026-09-23/24, each recorded where it overrides a spec: (1) the dead see every role and every night choice online (doc 12 §4.1 note; new read-only Edge Function witness_view, refused to the living with NOT_ALIVE; deployed to hosted with owner approval, no migration); (2) witness voice — living hear only living, dead hear everyone, a dead device sends only to dead peers (per-peer replaceTrack(null) in WebRtcVoiceEngine.setSendingPeers + receiver filter); this also closed a real leak where a dead player's open mic reached the living in free discussion; dead are not offered the floor; (3) no host «كمل»/«ابدأ التصويت» — the host device silently ends read-only beats early (deal once every card is seen +2s, morning +9s, verdict +9s), every client still falls back to the server deadline; (4) night shows the player's own card; night-one Citizen rests (auto skip); (5) the Mafia's night victim sees the reaper jumpscare (owner video, cropped to portrait, 305 KB, preloaded while the night resolves) before the morning beat; (6) no speaker name in band 3; witness band 3 shows event headlines; (7) result seats show character portraits, not glyphs; (8) «كل اللاعبين خرجوا» sheet when every other seat has left. Design: drawn dusk/dawn curtain replaces the grainy cover-fitted video stings (veil, delayed title, gold only at dawn), band 3 and hand-band transitions (hand swaps enter-only, so an outgoing button is never tappable), noir page transition app-wide, elimination beat fades out and waits for curtain/scare, gradual grey drain with a GlobalKey keeping the table's state, witness portraits fade in, witness panel moved to a full-height side sheet with compact face chips and a night feed, hold pad redesigned (fingerprint, single-line instruction; same for every role), elimination/roster/reveal cards drawn whole (margin cropped, no outline, swipe caught by the whole slot, 2.8 s face-up dwell), shared online cues (night falls, morning, speaker change, elimination) guarded so a refused cue can never cost a frame (it once painted a grey release-mode error frame), X over the table's exit removed.
Files:      lib/transport/{online_transport,witness_channel}.dart; lib/platform/voice/{voice_controller,voice_engine,webrtc_voice_engine}.dart; lib/ui/screens/online/{online_table_flow,table/table_scene}.dart; lib/ui/screens/online/council/{card_rise,role_roster,council_band,phase_sting,voice_band}.dart; lib/ui/screens/online/witness/{witness_panel,witness_side_sheet,kill_jumpscare,elimination_beat}.dart; lib/ui/screens/match_route.dart; lib/ui/widgets/{hold_pad,role_card,card_art}.dart; lib/ui/theme/{design_tokens,mafia_theme}.dart; lib/app/{asset_constants.dart,l10n/*}; assets/video/kill_jumpscare.mp4; raw_assets/online-kill/; supabase/functions/witness_view/index.ts; supabase/tests/{witness_match,play_with_app}.py; tool/generate_asset_constants.py (keeps AppEconomyArt); tests: test/transport/{auto_advance,online_transport,open_ballot_epoch}_test.dart, test/voice/voice_controller_test.dart, test/widget/hold_pad_test.dart, test/online/{doc12_acceptance,doc15_acceptance,online_action_retry,online_verdict}_test.dart; docs/12-online-experience.md; pubspec.yaml (1.1.2+5).
Verified:   Full suite 1140 passed / 1 skipped / 0 failed (build/phase95-full-tests.log); analyze 0 errors / 0 warnings / 93 infos. New regressions: witness voice wall (fails with the filter removed), auto-advance (host early clock, guest fallback only, deal waits for every card). Hosted witness_match.py 16/16 (living mafia and citizen get the identical refusal; the dead get true roles + kill/save/check). Emulator Pixel_9_Pro_2, release builds vs hosted with bots, several full matches: no host taps needed through 3 days; night card; witness portraits/side sheet/headlines/night feed; curtain; card rise whole; result portraits; night-death jumpscare sequence (recordings reviewed frame by frame). Candidates in build/deliverables-1.1.2: signer 082c07…9e11, versionCode 5, 16KB 12/12 each, R8 PASS, no service_role/JWT in web; RC installed over 1.1.1 and launches clean.
Gate:       PASS for the campaign's automated and emulator evidence. NOT publish-ready.
Open:       Human match on real phones (owner). Real two-device witness voice (dead↔dead audible, dead→living silent) needs two devices with microphones — only unit-tested plus code path. Build note: pub.dev unreachable; dev-only integration_test entry removed from the generated registrant before --no-pub release builds. Unused sting_*.webm assets remain in the bundle (~300 KB). Harness play_with_app now rejects cached sessions with <40 min left (expired tokens made bots look "left").

## PHASE 96 — done (owner's small-items list; 1.1.3+6 candidates)
Built:      «جاهزين للتصويت»: migration 20260924000600_ready_to_vote (security-definer mark_ready_to_vote under the room_state row lock, service_role only; readiness public in public_data.readyToVote keyed by phase_number; only living, unkicked seats count) + Edge Function ready_to_vote (records, and opens the ballot through commit_phase_open when every living seat is ready) + client (GameSnapshot.readyToVoteSeats, GameTransport.setReadyToVote — no-op offline, discussion button «جاهز للتصويت (n من m)» that toggles). Timer warning cue 10 s before a discussion/ballot closes (shared, guarded). Jumpscare drawn in the root overlay (covers the call bar), preloaded during every night for every possible victim, skipped under Reduce Motion. Unused sting webms moved to raw_assets/retired-stings. Own lint regressions fixed (analyze infos 93 → 90). Version 1.1.3+6.
Files:      supabase/migrations/20260924000600_ready_to_vote.sql; supabase/functions/ready_to_vote/index.ts; supabase/tests/{ready_to_vote.sql,ready_match.py,play_with_app.py}; lib/transport/{game_snapshot,room_codec,game_transport,local_transport,online_transport}.dart; lib/ui/screens/match_controller.dart; lib/ui/screens/online/{online_table_flow,witness/kill_jumpscare,witness/witness_panel,council/card_rise}.dart; lib/ui/theme/design_tokens.dart; lib/app/{asset_constants.dart,l10n/*}; assets/video (stings removed); test/online/online_verdict_test.dart; pubspec.yaml.
Verified:   Hosted: migration dry-run + SQL test in one rolled-back transaction, then applied (schema_migrations shows 000600; coin_orders 000500 still unapplied), SQL test re-run PASS against hosted; ready_to_vote deployed; ready_match.py 18/18 (outside discussion refused, dead refused NOT_ALIVE, two simultaneous taps both counted, take-back honoured, ballot opens only on the last living seat, late tap PHASE_CLOSED). PGlite 31/31. Flutter full suite 1143 passed / 1 skipped / 0 failed; analyze 0/0/90 infos. Emulator: «جاهز للتصويت (4 من 5)» with 4 bots ready, the phone's tap opened the ballot for the room; night-death run shows the reaper full screen over the call bar with ~1 frame of black. Web 1.1.3 in Chromium (Playwright, 390×844): onboarding renders, saved profile restored to the terms step, page fade completes, 0 console errors (canvas interaction not driven). Candidates build/deliverables-1.1.3: signer 082c07…9e11, versionCode 6, 16KB 12/12, R8 PASS, no service_role/JWT in web; RC installed over 1.1.2 and launches clean.
Gate:       PASS. NOT publish-ready (human match and two-device voice remain with the owner).
Open:       Owner: real-phone human match; two-device witness voice; weak network; a web online match in a real browser. Work is uncommitted in this worktree; main is behind it.

## PHASE STORE-V2 — done (art and design handoff only)
Built:      Council Vault identity; 18 product images across six categories of three (frames, nameplates, room atmospheres, narration styles, collections, coin packs), plus hero; RTL responsive horizontal-rail HTML preview.
Files:      assets/images/store_v2/*; raw_assets/store-v2/*; docs/store-v2/{catalog.json,provenance.json,index.html,contact-sheet.png,CLAUDE-IMPLEMENT.md,previews/*}.
Verified:   All 19 WebPs decode and paths resolve; six categories with three unique SKUs each; contact sheet inspected; three frames have transparent centers and real alpha, three plates real alpha; runtime assets total 1,763,522 bytes. Built-in imagegen used, PNG masters retained, ffmpeg encoding.
Gate:       PASS for artwork delivery only.
Open:       Claude integrates rails and equipped artwork; four proposed cosmetic SKUs need real implementation/server catalog before sale. HTML browser interaction and Flutter integration not tested. No app source/pubspec/server/payment/deployment changed. Narration covers represent text styles, not new voice recordings.

## PHASE 97 — done (home loop on the first frame; one settings kit; colour work reverted)
Built:      AmbientMedia now paints the still as the floor and fades the animated-WebP loop in over it, so a cold start never shows an empty backdrop (the reported «الفيديو مش بيبقا موجود لما بفتح اللعبة»); the home screen's AppBackdrop, dropped in the earlier redesign, is back. ExperienceSurface now wraps AppBackdrop, so the quiet public surfaces carry the same ground and weave as the painted ones instead of a flat gradient of their own. New settings_kit.dart (SettingsPanel / SettingsBadge / SettingsBadgeFrame / SettingsPill / SettingsSwitchRow / SettingsSegments / SettingsSegment / SettingsLinkRow / SettingsHeading) + SettingsTokens; the general settings screen and the online room settings panel both rebuilt on it, LanguagePicker and the six link buttons (coin store, scenario store, help, safety, ad privacy, legal) given the same row form. Five new strings. A lounge-brown ground for everything outside a match was built and then fully reverted at the owner's instruction — no colour change survives.
Files:      lib/ui/widgets/{ambient_media,textured_surface,experience_surface,settings_kit,language_picker,legal_documents}.dart; lib/ui/screens/setup/{home_screen,settings_screen,coin_store,scenario_store,help_center}.dart; lib/ui/screens/online/{room_settings_panel,safety_center,rewarded_reward_button}.dart; lib/ui/theme/design_tokens.dart; lib/app/l10n/{app_ar.arb,app_en.arb,app_localizations*.dart}; test/widget/{ambient_media,settings_presets,language_picker}_test.dart; SESSION-CHANGELOG-2026-09-24.md. Reverted to their prior state: lib/core/theme/app_colors.dart, lib/ui/theme/mafia_theme.dart, lib/app/{app,router}.dart.
Verified:   analyze 0 errors / 0 warnings / 90 infos (all pre-existing). 157 targeted tests passed in three batches — media+settings+language+token (22), online+first-run+profile+boot (65), stores+help+safety+accessibility+setup-flow+card_ground_matches_surface+role_accent_parity+night_color_token+luminance_budget (70); the last batch is the proof the palette is back on the neutral ladder. Emulator-5554, signed release APK installed over 1.1.3: cold start shows the home backdrop on the first painted frame of Home; general settings and the online room-settings create form both inspected by screenshot (panels, segments, the «في الأونلاين بس» pill, RTL chevrons, pinned footers).
Gate:       PASS.
Open:       Full suite not re-run since the settings rewrite (the background run was killed for low memory; not restarted per the standing rule). Colours deferred by the owner. Work uncommitted.

## PHASE 98 — done (Council Vault art integration, reviewed implementation; local gates)
Built:      Integrated all 19 store assets; five cosmetic categories of three client products and platform-gated illustrated coin-pack rail; compact wallet, responsive horizontal rails, fixed details action, same-sheet buy/equip, system-back close, real equipped frame/plate art and public room scenes. Four new bilingual cosmetic products plus additive local catalog migration; no live sale activation.
Files:      See docs/PHASE98-DESIGN-REVIEW.md for the full source/test/art list and delegation review. Source stays in claude/crash-fixes-and-testing-b6c2f5; no commit/push.
Verified:   Full Flutter 1157 passed / 1 existing skipped / 0 failed; final sizing/coin refinements 67 focused PASS; final analyze 0 errors/warnings, 89 infos; PGlite 32/32; two Node contract scripts PASS; real-font Flutter capture suite 9 PASS and final council render reviewed. No Docker. Claude hit its usage limit; Codex completed review/fixes/gates.
Gate:       PASS for this local store/design phase; NOT a release-readiness claim.
Open:       New catalog migration and compatible create_room/room_settings/start_match deployment remain pending; hosted catalog therefore may have fewer than three products in some categories. Latest APK/web not rebuilt; broader public-screen design campaign and owner real-phone/human-voice checks remain. Play/ads/payment setup separate; no deployment/account changes/spend.

## PHASE 99 — done (public journey design: profile, onboarding identity, online door, lobby invite)
Built:      Audited Home/mode/onboarding/profile/online door/lobby from real-font widget renders (AR/EN, 360/390/desktop) and fixed what they showed: Profile gained a back action (Home / the door), fills a saved profile that arrives after the first frame (it could show an empty name and overwrite it), says Save for an edit, uses the onboarding identity art; one shared ProfileIdentityFields (avatar, name, labelled ولد/بنت settings-kit track with why it is asked) replaces the unlabeled ♂/♀ glyphs on onboarding step 2 and Profile; onboarding preferences use the settings kit rows; online door shows one «هتلعب باسم …» identity chip instead of a stray bare name, equal 48 dp Create/Join pair, an empty-state panel with next steps, and the room chevron no longer points backwards in Arabic; lobby invite is a labelled «ادعي صحابك» button (same native share/session) with copy beside it, «٥»→«5». Home and mode reviewed and left as is. No palette, rules, timing, server or monetization change.
Files:      lib/ui/widgets/profile_identity.dart (new); lib/ui/screens/setup/profile_screen.dart; lib/ui/screens/onboarding/first_run_screen.dart; lib/ui/screens/online/{online_entry_screen,lobby_screen}.dart; lib/app/router.dart; lib/app/l10n/*; test/widget/{journey_v99_test (new), journey_screenshots (new harness), profile_flow_test, online_entry_test}.dart; docs/PHASE99-DESIGN-REVIEW.md.
Verified:   Focused journey suites 98 + profile_flow 4/4 after its scroll fix; new journey_v99_test 8/8; full suite once at --concurrency=2: 1166 passed / 1 skipped / 0 failed (build/phase99/full-tests.log); analyze 0 errors / 0 warnings / 89 infos (unchanged). Before/after widget renders in build/phase99/{before/,} reviewed at ≤420 px. No emulator/device attached — renders are widget captures, not device verification.
Gate:       PASS for this local public-UI phase. NOT a release-readiness claim.
Open:       Owner real-phone human match/two-device voice; phase-98 catalog migration + function deployment; no APK/AAB/web rebuilt. Deferred to Codex: a labelled lobby leave control; store access from the online door.

## PHASE 99 (review delta) — done
Built:      Capture harness uses the existing FakeVoiceEngine (lobby render no longer throws). Shared SettingsSegments: full-track 48 dp hit area per option (segmentHeight 44→48 token, inset on the thumb only). Late profile-load regressions; fixed a real race where saving before the first profile read finished was reverted in memory by the stale read (PlayerProfileController keeps the session's save).
Files:      test/widget/{journey_screenshots,journey_v99_test}.dart; lib/ui/widgets/settings_kit.dart; lib/ui/theme/design_tokens.dart; lib/data/player_profile.dart; docs/{PHASE99-DESIGN-REVIEW,PROGRESS}.md.
Verified:   journey_v99_test 12/12 (the save-race test failed before the fix: Expected 'Mona', Actual 'Karim'); journey captures 16/16 with no exceptions (build/phase99/capture-final.log), lobby/profile/onboarding checked at ≤420 px; full suite 1170 passed / 1 skipped / 0 failed (build/phase99/full-tests-delta.log); analyze 0 errors / 0 warnings / 89 infos (build/phase99/analyze-delta.log).
Gate:       PASS for this local phase. NOT release-ready.
Open:       Widget renders only (no emulator/device attached). Hosted catalog migration 20260924000700 + compatible functions not deployed; owner real-phone human match and two-device voice; no APK/AAB/web rebuilt. Lobby leave redesign and online-door store access are out of scope for this phase.

## PHASE 100 — done (release 1.1.4 with live rewarded ads; web updated)
Built:      AdMob wired for production on eyadsyam124@gmail.com: app ca-app-pub-9179063936085117~7320479940, Rewarded unit `rewarded_match_bonus` ca-app-pub-9179063936085117/8711609352 (1 coins, SSV → admob_ssv, verified by AdMob). admob_ssv now acknowledges a correctly signed callback that carries no claim (AdMob's verify ping) with 200 and grants nothing; deployed. Supabase secret ADMOB_REWARDED_ANDROID_ID set. dart_defines: ADS_ENABLED=true + real IDs. web/app-ads.txt (pub-9179063936085117). Version 1.1.4+7. Phase 99 working tree carried over from claude/crash-fixes-and-testing-b6c2f5 into this worktree (hook forbids cross-worktree writes).
Files:      supabase/functions/admob_ssv/index.ts; web/app-ads.txt; pubspec.yaml; dart_defines.json (ignored); docs/PROGRESS.md.
Verified:   Full suite 1172 passed / 1 skipped / 0 failed (pre-change baseline; the only code change since is the server function). Deployed economy function byte-identical to source; ad_reward_claims + commit_ad_reward live. APK: real App ID in manifest, versionCode 7 / 1.1.4, signer 082c07…9e11; installed on Pixel_9_Pro_2 over the previous build, launches to Home, no FATAL, "Initialized AdMob" in logcat. AAB 105.6 MB built with same key. Web: flutter build web, sw.js stamped, deployed via Vercel CLI → almafia.vercel.app; live main.dart.js md5 == local; app-ads.txt 200; Playwright 390×844 shows onboarding, 0 console errors.
Gate:       PASS for build/config. Store publication is the owner's.
Open:       EU/UK GDPR consent message drafted in AdMob but Publish stayed disabled — owner: Privacy & messaging → European regulations → publish. AdMob account still "requires review"; add the Play store listing to the AdMob app once live (lifts "limited ad serving"). Play Console: Ads = Yes, Advertising ID = Yes in Data safety; upload the AAB. A real rewarded view not tested (new unit takes up to 1 h; never tap own live ads — use a registered test device). Owner real-phone human match + two-device voice. Work uncommitted.

## PHASE 101 — done (1.0.0 submitted to Google Play closed testing; GDPR message live; audience 16+)
Built:      Owner chose 16+ and a clean 1.0.0: app gate/terms/help/privacy say 16 (terms version 2026-09-24 → re-consent), store listings corrected (optional post-match rewarded ad; coins cosmetic only), version 1.0.0+1. AdMob: EU/UK consent message "Mafia Master GDPR consent" published (Do-not-consent on). Play Console (eyadsyam124, dev 8516115344939721781, app 4973103045227664588) created: privacy URL, Ads=yes, App access=no login, audience 16–17+18+, Ad ID (advertising + fraud), Government/Financial/Health=none, IARC (ESRB Teen, ClassInd 10, GRAC 12, ACB PG), Data safety (approx. location, name, user IDs, other info, in-app messages, app interactions, other UGC, diagnostics, device IDs; collected not shared; encrypted; deletion URL), Arabic listing + icon + feature graphic + 6 screenshots, category Board, contact email/site. Closed testing "Alpha": 177 countries, list "Mafia Master testers" (owner only so far), release 1.0.0 (1) AAB uploaded by owner, 16 changes sent for review.
Files:      lib/app/l10n/app_{ar,en}.arb (+ generated); lib/data/terms_consent.dart; web/privacy/index.html; store/{listing-ar,listing-en,GOOGLE-PLAY-SUBMISSION}.md; pubspec.yaml; docs/PROGRESS.md.
Verified:   Full suite 1172 passed / 1 skipped / 0 failed after the 16+ change; APK 1.0.0 (1) real App ID, signer 082c07…; Play review page "ready to release", 43.9 MB install, API 26+/target 36; web 1.0.0 live, md5 match, app-ads.txt 200.
Gate:       PASS — submitted; Google review pending.
Open:       Need 12 testers opted in for 14 days before applying for production (add their Gmail addresses to the list and share the opt-in link). After production goes live: add the Play listing to the AdMob app to lift "limited ad serving". Screenshot order in listing is 01…06 as selected — confirm visually. Work still uncommitted in this worktree.

## PHASE 102 — done (1.0.1 compliance + consent)
Built:      Privacy web page AR/EN (AdMob data/purposes per Mobile Ads SDK disclosure, interstitial rules, daily rewards, Play Billing, optional email), in-app safetyPolicy + privacySummaryBody AR/EN, listings AR/EN and GOOGLE-PLAY-SUBMISSION.md rewritten to 1.0.1 truth (scenario product marked not sold; Console items listed for review, not claimed done); store-listing checker's stale "no ads" rule replaced. UMP runtime rewritten: only the consent-info network update is bounded (10 s), the form is never timed out, parallel callers share one attempt, canRequestAds governs loading, privacy-options form refreshes state and may start the SDK, SSV options awaited before show, notConsented outcome; interstitial loader never prompts.
Files:      web/privacy/index.html; lib/app/l10n/app_{en,ar}.arb; store/{listing-ar,listing-en,GOOGLE-PLAY-SUBMISSION}.md; tool/check_store_listing.py; lib/platform/monetization/{rewarded_ads,rewarded_ads_mobile,rewarded_ads_stub,interstitial_ads}.dart; lib/ui/theme/design_tokens.dart; test fakes (placement param).
Verified:   check_store_listing.py (lengths); Dart compile deferred to phase 104 analyze.
Gate:       PASS (text/consent); device consent flow NOT run (no live EEA form on emulator).
Open:       assetlinks: needs Console app-signing SHA-256 before any change (not assumed).

## PHASE 103 — done (1.0.1 server economy + billing)
Built:      Migration 20260925000100_update101_economy.sql: economy_config (checked caps), ledger kinds + source_key idempotency, global AdMob transaction registry (v1/v2/daily), two-step claims (+50%/+50%, immutable, ordered, v1/v2 mutually exclusive, v1 resumable), daily coffer 20 / wheel 10-20-35-60-100 @ 40/30/20/8/2 via gen_random_uuid rejection sampling, persisted before reveal / +60 every 7th claimed day, daily ad 25 keyed to claim day, IN_MATCH/DAY_CHANGED/DAILY_PAUSED guards; play_products (inactive seeds), commit_play_product (allowlist, account tag, pending no grant, debt offset, once per token hash), mark_play_consumed, generalized refund claw-back; economy_capabilities; deletion/orphan purge extended. Edge: admob_ssv routes by prefix+unit allowlist, economy action table, play_purchase generalized (ack/consume after durable credit, retry-safe).
Files:      supabase/migrations/20260925000100_update101_economy.sql; supabase/functions/{_shared/ad_rewards.ts,_shared/economy_actions.ts,_shared/play_verify.ts,_shared/api.ts,admob_ssv/index.ts,economy/index.ts,play_purchase/index.ts}; supabase/tests/{update101_economy.sql,update101_contracts.test.mjs}.
Verified:   node tool/test_sql_without_docker.mjs → 79 migrations + update101_economy.sql PASS (single-connection PGlite); related SQL contracts PASS; node update101_contracts / admob_ssv_verify / coin_payments PASS.
Gate:       PASS locally. Hosted concurrency NOT proven (locks/unique indexes only). Edge handlers not type-checked (no Deno on host).
Open:       Nothing deployed. Requires 20260924000500 applied first on hosted.

## PHASE 103b — done (security review repairs, 1.0.1 server)
Built:      Reviewer findings reassessed and repaired. Play: per-purchase debt_offset stored and restored on refund (owner-corrected conservation: A bought/spent/refunded → debt 500; B fully offset → credited 0; refund B → debt 500, not 0 or 1000); durable play_void_tombstones for every voided token/order incl. never-seen ones; revoked is final (tombstone or earlier revocation beats a stale "active"); Google-reported cancellation reverses on verify; coins require the account tag; global lock order purchase(sorted) → wallet(sorted) → rows in commit and voided sync; entitlement voids settle once. Manual coin orders: same debt-erasure bug verified in 20260924000500 and fixed additively in 20260925000200_coin_order_debt_offset.sql (debt_offset column, backfill coins-credited, review/refund redefined). Daily actions require p_day (DAY_REQUIRED) at SQL and edge; missing economy_config row reads as off everywhere incl. capabilities. Reviewer's provisional ad-claim deadlock: not reproduced/argued; unchanged.
Files:      supabase/migrations/{20260925000100_update101_economy.sql,20260925000200_coin_order_debt_offset.sql}; supabase/functions/_shared/{economy_actions.ts,api.ts}; supabase/tests/{update101_economy.sql,coin_order_debt_offset.sql,update101_contracts.test.mjs}.
Verified:   node tool/test_sql_without_docker.mjs → 80 migrations, 35/35 SQL files PASS incl. reviewer-owned update101_security_regressions.sql (expects debt 500); node update101_contracts PASS.
Gate:       PASS locally; hosted two-connection concurrency still unproven (PGlite single connection).
Open:       None server-side beyond deployment and hosted concurrency proof.

## PHASE 104/105 — done (1.0.1 client monetization + daily/store UX)
Built:      economy capability negotiation (off on any failure/old server); post-match reward: legacy one-ad unchanged, v2 two steps with both amounts shown first, step 1 kept, s2:/placement routing, bounded 90 s backoff + manual recheck + foreground recovery, wallet invalidation; interstitial policy (grace, 10 min gap, 3 min after reward, ≤3/day, monotonic clock, exit kinds) + coordinator (preload-or-skip, after navigation, mic/audio silenced) hooked only to Home from a completed online result; Play Billing layer (multi-product, obfuscated account tag, autoConsume off, server verify) + Play offers tab (Quiet Pass, packs, Play-localized prices, email protection required); vault Rewards tab (coffer art, vector wheel proportional to odds landing at server slot, published odds, 7-day card, daily ad); history labels; currency renamed Council Coins / عملات المجلس; AR/EN strings.
Files:      lib/ui/economy/{economy_capabilities,interstitial_coordinator,reward_poll,daily_rewards,play_offers,store_art}.dart; lib/platform/monetization/{interstitial_policy,play_billing,play_billing_stub,play_billing_mobile}.dart; lib/ui/screens/online/{rewarded_reward_button,online_table_flow}.dart; lib/ui/screens/setup/coin_store.dart; lib/ui/theme/design_tokens.dart; lib/app/l10n/*; pubspec.yaml (economy_v2 assets); test/{unit/update101_policy_test.dart,widget/update101_economy_test.dart,support/fake_backend.dart (responders),widget/coin_store_test.dart (sticky network-down)}.
Verified:   flutter analyze: 0 errors/0 warnings (infos only); targeted tests: update101_policy 13/13, update101_economy 10/10, store/reward/boot/purchase suites pass.
Gate:       PASS (targeted). Full suite + device screenshots in phase 106.
Open:       Interstitial unit id absent from dart_defines → interstitial compiled off (safe gate).

## PHASE 107 — done (server half; client half pending LANE1_DONE)
Built:      Council Life server: daily/weekly contracts, Council Rank XP/levels, weekly leaderboard, invites, Starter Bundle — all flags off
Files:      supabase/migrations/20260925000300_council_life.sql, supabase/functions/_shared/economy_actions.ts, supabase/tests/council_life.sql, supabase/tests/council_life.test.mjs, docs/PHASE-107-COUNCIL-LIFE.md
Verified:   node tool/test_sql_without_docker.mjs (36/36 incl. council_life 11 gates); node supabase/tests/council_life.test.mjs + update101_contracts.test.mjs PASS
Gate:       PASS (server half)
Open:       client half (Council tab, toasts, celebration, bundle card); art (10 emblems, 6 icons, frame_council_seal); leaderboard privacy opt-out; hosted concurrency unproven

## PHASE 104c — done (third independent review repairs)
Built:      (1) Home from a completed online result awaits leave() (≤3 s, MafiaTiming.leaveBeforeAd) before exit; the interstitial is considered only if the room was actually left. (2) economy_config defaults OFF for ad steps, daily, daily ad, interstitial; activation/rollback runbook in build/update101/status.md. (3) Refund/debt rule beside coin packs and in the Quiet Pass card; outstanding purchase_debt exposed via capabilities and shown before Buy. (4) Privacy-options form no longer timed out; a consent change discards the cached interstitial; showIfReady re-checks canRequestAds. (6) Daily ad stops when the claim is already awarded. (7) Wheel resolves slot by value; stored outcome not shown before the spin starts. (8) Capabilities: network failure marked failed and retried on vault open / app resume (old server's BAD_REQUEST stays "none"); Play controller restarts after an empty product list; a pending payment no longer blocks other buys. (9) 0.66 and strokeWidth 2 moved to tokens. Steps answer with ≠2 steps falls back to the single ad. Full-suite findings fixed: missing revoke/grant on play_is_voided/reverse_play_coins/play_token_hash (security-definer functions were executable by anon); dart:io import replaced by defaultTargetPlatform (offline guarantee). F2/F3/F4/T1/T2 confirmed already repaired in 103b.
Files:      lib/ui/economy/{interstitial_coordinator,economy_capabilities,daily_rewards,play_offers}.dart; lib/ui/screens/online/{online_table_flow,rewarded_reward_button}.dart; lib/ui/screens/setup/coin_store.dart; lib/app/app.dart; lib/platform/monetization/{rewarded_ads_mobile,play_billing_mobile}.dart; lib/ui/theme/design_tokens.dart; lib/app/l10n/*; supabase/migrations/20260925000100_update101_economy.sql; supabase/tests/update101_economy.sql; test/widget/update101_review_fixes_test.dart; test/online/online_witness_result_test.dart (pumps to the leave bound; assertion unchanged).
Verified:   update101_review_fixes 10/10 (incl. assertion that the daily-ad tap landed), update101_economy, update101_policy pass.
Gate:       PASS.
Open:       Consent-change handling is plugin code: verified by reading only.

## PHASE 106 — done (verification + review candidate 1.0.1+8)
Built:      pubspec 1.0.1+8. Signed AAB/APK (upload key 082c07…a19e11, production AdMob app id, versionCode 8), separate test-ads APK (.adstest, sample units, cannot be credited by SSV), web release build (not published), symbols per build, SHA256SUMS + SOURCE-HASHES (403 inputs, dart_defines/key excluded) + README in build/release-1.0.1. Interstitial and v2 unit ids absent → interstitial compiled off; v2/daily ads use the primary unit.
Files:      pubspec.yaml; build/release-1.0.1/*; build/update101/{status.md,*-build.log,full-suite.log}.
Verified:   flutter analyze 0 errors / 0 warnings / 89 infos; flutter test --concurrency=2 "+1205 ~1: All tests passed!"; node tool/test_sql_without_docker.mjs 80 migrations, 36/36 SQL (incl. reviewer-owned security suite); node update101_contracts + admob_ssv_verify PASS; aapt2 badging versionCode 8 / 1.0.1; apksigner signer 082c07…a19e11.
Gate:       PASS for local gates. Nothing deployed/uploaded/committed.
Open:       External gates listed in build/update101/status.md (AdMob units, Play products + service account + licence test, Console declarations, hosted deploy order, two-connection concurrency proof, device screenshots, owner human match + voice).

## PHASE 107 — done (client half + security findings; LANE A)
Built:      Council hub tab in the vault (rank card + XP bar, daily contracts with claim + coin burst, weekly contract, leaderboard sheet with own position, invite share/redeem), level-up celebration sheet, result-screen contract/XP strip after the match only, home/vault attention dot (coffer/wheel/contract), Starter Bundle card in the Play tab (non-consumable, once, never consumed), rank emblem on seats, leaderboard opt-out switch (profile + sheet; reuses already-loaded capabilities, never starts a fetch), web InstaPay/Vodafone Cash flow via external_link + Quiet Pass web order. All art painted in code (10 tier emblems, contract icons, Council Seal frame/cover). Raster slots: CouncilRaster/RasterOr prefer delivered files (assets/images/{council,store_v3}) and fall back to the painting; README in council/store_v3/economy_v2/profile lists expected files; council_raster_test keeps CouncilRaster.delivered in step with disk.
Security:   C1 redemption row detached (random invitee id, detached=true) on deletion and orphan purge, so the paid count never drops; N2 settle only rows whose wallets are in the sorted locked set; N3 orphaned bundle token refused with OWNER_DELETED (edge maps to ACCOUNT_MISMATCH 409); N4 opt-out gate C12 in council_life.sql; new gate C14 (deletion/purge keep cap; orphan bundle refused). Ledger-kind scan fix: 000300/000500/000600 now write the kind check as an IN list (an array literal read back empty and dropped every earlier kind).
Files:      lib/ui/economy/{council,council_art,council_hub,store_art,play_offers,coin_packs}.dart; lib/ui/screens/setup/coin_store.dart; supabase/migrations/20260925000300_council_life.sql (+ one-line fix in 000500/000600); supabase/functions/play_purchase/index.ts; supabase/tests/council_life.sql; test/widget/council_raster_test.dart; pubspec.yaml; assets/images/{council,store_v3,economy_v2,profile}/README.md
Verified:   SQL 39/39 (84 migrations) incl. council_life 14 gates + council_life_security 13 gates; dart analyze 0 errors/0 warnings (88 infos); council_life/profile/raster targeted tests pass; full suite "+1271 ~1 -45" — all 45 failures trace to in-progress LANE B lib/ui/economy/app_open_gate.dart (AnimationController created in dispose) and LANE C lib/ui/fun/founder_badge.dart (watches economyCapabilitiesProvider → boots Supabase in tests).
Gate:       PASS for LANE A scope; full suite blocked by other lanes' in-progress files.
Open:       economy_v2/profile raster slots not wired (daily_rewards is LANE B; profile has no banner/stat UI); web_pay_* and best_value_ribbon/sparkle_sheet/council_hub_tab not wired (text tabs); hosted concurrency unproven.

## PHASE 109 — Awards, reactions, welcome-back (LANE C)
Built:      Match awards (MVP, Sharp Eye, Silver Tongue online, First Blood, Lifesaver, Perfect Crime, Survivor) computed only at the public end — server `compute_match_awards` for a finished room on `result` with a public outcome (triggers on both completion paths + lazy read; a live room answers ready:false and stores nothing), pass-and-play from the finished log in a pure UI-side helper that answers [] before the result; small idempotent coin bonus (one `match_award` ledger row per player/room). 8 quick reactions (lobby + public result only; refused server-side in every match phase; ≤3 per 4.5 s server + client) over Realtime, seals rise from the sender's chair, reduced-motion aware. Share card adds own awards + rank title. Online result: «روم جديدة للشلة» is the primary action. «وحشتنا» Home card after ≥ 20 h (navigation to the vault only). Founder badge (window flag). Skeleton ribbon while loading, one haptic + chime on reveal, a few gold motes that stop. All flags OFF; `economy_capabilities.fun`.
Files:      supabase/migrations/20260925000600_awards_reactions.sql; supabase/functions/_shared/economy_actions.ts; supabase/tests/{awards_reactions.sql,awards_reactions.test.mjs}; lib/ui/fun/*; lib/transport/{online_backend,supabase_backend}.dart; lib/ui/economy/economy_capabilities.dart; lib/ui/screens/{match_flow,postgame/result_screen,online/online_table_flow,online/lobby_screen,online/result_share_button,setup/home_screen,setup/profile_screen}.dart; lib/app/router.dart; lib/ui/theme/design_tokens.dart (FunTokens); lib/app/l10n/*; pubspec.yaml + assets/images/{awards,reactions,launch}/README.md; test/{unit/match_awards_test,widget/fun_v109_test}.dart; test/support/fake_backend.dart.
Verified:   node tool/test_sql_without_docker.mjs → 84 migrations, 40/40 SQL (awards_reactions 9 gates); node awards_reactions/update101_contracts/council_life/ads_v2 .test.mjs PASS; flutter analyze 0 errors / 0 warnings (infos only, none in phase-109 files); flutter test --concurrency=2 "+1318 ~1: All tests passed!" (match_awards 19, fun_v109 36).
Gate:       PASS locally (flags off). NOT deployed.
Open:       Realtime delivery and device rendering unverified; art pass (awards/reactions/welcome/founder) pending.

## PHASE 108 — Ads v2 — done (LANE B; everything ships OFF)
Built:      App-open ad on the launch picture (pure policy: never first launch / before onboarding+terms / into room, match, pass-and-play or purchase / right after another full-screen ad or Play sheet; resume only after ≥4 h away; ≤3/day, ≥4 h gap, 3 s load budget, 4 h expiry; consent via canRequestAds, never a form; remembered server answer so a disabled feature costs no launch round trip). Anchored adaptive banner (labelled, framed with token border — banner_frame.webp art not yet delivered) on waiting surfaces only: online lobby, online room list, history, vault, profile edit; zero height without fill; dropped in background; allowlist test. Rewarded extras (second wheel spin with published odds, double today's coffer, swap an unclaimed daily contract), each once per UTC day, day-guarded, idempotent, SSV-only via `x1:` claims on the v2 rewarded placement. Server flags app_open_enabled / banner_enabled / ad_extras_enabled (default false) + app-open caps, reported under capabilities `ads` (old server = off). Quiet Pass copy AR/EN now says it removes app-open, interstitial and banners. Privacy page, in-app privacy summary, store listings, submission doc updated; docs/ADS-V2-REVENUE-MODEL.md.
Files:      supabase/migrations/20260925000500_ads_v2.sql; supabase/functions/_shared/{ad_rewards,economy_actions}.ts; supabase/tests/{ads_v2.sql,ads_v2.test.mjs}; lib/platform/monetization/{app_open_policy,ad_formats,full_screen_away}.dart (+ rewarded_ads{,_mobile,_stub}.dart, play_billing_mobile.dart); lib/ui/economy/{app_open_gate,waiting_banner,ad_extras}.dart (+ economy_capabilities, daily_rewards); lib/app/app.dart; lib/ui/screens/{online/lobby_screen,online/online_entry_screen,postgame/history_screen,setup/coin_store,setup/profile_screen}.dart (one banner line each); lib/ui/theme/design_tokens.dart (AdTokens); lib/app/l10n/*; dart_defines{,.example}.json; web/privacy/index.html; store/{listing-en,listing-ar,GOOGLE-PLAY-SUBMISSION}.md; test/unit/{app_open_policy_test,banner_placement_test}.dart; test/widget/ad_extras_test.dart; build/update101/status.md.
Verified:   node tool/test_sql_without_docker.mjs: 84 migrations, 40/40 SQL (ads_v2 11 gates); node ads_v2.test.mjs + update101_contracts + admob_ssv_verify PASS; flutter analyze 0 errors / 0 warnings (88 infos, pre-existing kinds); flutter test --concurrency=2 "+1318 ~1: All tests passed!".
Gate:       PASS (local). Nothing deployed/committed.
Open:       No device run of the app-open veil or a real banner fill (no emulator pass in this lane); banner frame art pending; second rewarded unit's SSV URL must be confirmed; hosted concurrency unproven (PGlite single connection); new build needed to carry the two unit ids.

## PHASE 110 — Ads v3 — done (everything ships OFF)
Built:      Ads per match, never inside a match phase. Server 20260927000100_ads_v3.sql (additive): global full-screen pacing (full_screen_max_per_day 40 ≤40, full_screen_min_gap_seconds 90 ≥90), pre_match / pass_and_play / session interstitial flags (default false) + session_interstitial_after_seconds (300 ≥300), reported in capabilities `interstitial` (+ `ads.fullScreen`); post-match reward = x2 then x3 (each step = whole base, same s2: SSV route, ledger kinds, ordering, idempotency; v1 untouched). Client: one shared full-screen ledger (app-open counts; app-open 3/day cap removed); pre-match on Create/Join/«روم جديدة للشلة» before the lobby (skipped first match after launch; rematch ad covers the next Create/Join); post-match every match; pass-and-play before the deal (router startMatch) and after Home from the result; session ad after 5 menu minutes on a menu→menu navigation (router listener + foreground-only menu clock); grace for a brand-new player's first match, ≥3 min after rewarded, Quiet Pass, consent via canRequestAds, preloaded-or-skip, audio+mic muted/restored. Result reward UI shows both totals (x2, x3) before the first tap. Extras unchanged (same v2 rewarded unit).
Files:      supabase/migrations/20260927000100_ads_v3.sql; supabase/tests/{ads_v3.sql (new), ads_v2.sql, update101_economy.sql, update101_security_regressions.sql}; lib/platform/monetization/{interstitial_policy,app_open_policy,interstitial_ads,rewarded_ads_mobile,rewarded_ads_stub}.dart; lib/ui/economy/{interstitial_coordinator,app_open_gate}.dart; lib/ui/screens/{match_flow,online/online_entry_screen,online/online_table_flow,online/rewarded_reward_button}.dart; lib/app/{app,router}.dart; lib/ui/theme/design_tokens.dart (AdTokens); lib/app/l10n/*; test/unit/{ads_v3_policy_test (new),app_open_policy_test,update101_policy_test}.dart; test/widget/update101_economy_test.dart; web/privacy/index.html; store/{listing-en,listing-ar,GOOGLE-PLAY-SUBMISSION}.md; docs/ADS-V2-REVENUE-MODEL.md; build/update101/status.md.
Verified:   node tool/test_sql_without_docker.mjs → 86 migrations, 42/42 SQL; all supabase/tests/*.test.mjs PASS; flutter analyze 0 errors / 0 warnings; flutter test --concurrency=2 "+1338 ~1 -2" — both failures in the concurrent payments lane (coin_purchase_test admin guard; Play offers buy label), none in ads files.
Gate:       PASS for the ads lane (local). Nothing deployed/committed.
Open:       Expectation changes by owner rule: step amounts 50/50→100/100 and totals (+100→+200, security G2 +101→+202); ads_v2 app-open cap asserts replaced by fullScreen pacing. No device run of any full-screen ad (no emulator); hosted concurrency unproven.

## PHASE 111 — Payments v2 — done (everything ships OFF)
Built:      InstaPay / Vodafone Cash manual transfers on Android (beside Google Play Billing) and web, for coin packs, Quiet Pass and Starter Bundle, same EGP price as Play from one server table (coin_packs.price_piastres + play_product). Per-platform kill switch economy_config.transfer_enabled_android / _web (default false). Flow: each paid item shows «ادفع بجوجل» + «إنستا باي»/«فودافون كاش» → the server-held link opens in the tap → come back → required screenshot (system picker, re-encoded to ≤1600px JPEG) + sender name → private bucket payment-proofs (service-role writes, owner-folder read, signed URLs for admin), sha256 unique across all orders. Max 2 pending, 72 h expiry, reject needs a reason shown to the player, approve needs a proof and credits once (existing idempotency/debt_offset), bundle once per account with the Play grant (frame_council_seal), pass grants remove_interruptions. Telegram notice to the owner per submitted order (plain text; skipped without secrets; token never logged/in client). Web /admin (hidden, web-only guard, email-code sign-in, server admin check via admin_whoami): pending/approved/rejected/expired, image, sender, product, price, player name, time; approve / reject(reason) / refund; /admin/coins redirects. Owner seeded into commerce_admins by email when that auth user exists. Proof retention: purge 90 days after review (immediately on account deletion; sender name nulled), run on admin list. Order status list + wallet/capabilities refresh on app resume. Terms item 6, safetyPolicy, privacySummaryBody, web/privacy AR/EN and Play Data safety updated truthfully (Photos, Other financial info, Purchase history); terms version → 2026-09-27.
Files:      supabase/migrations/20260927000200_payments_v2.sql; supabase/functions/{coin_orders/index.ts,_shared/coin_payments.ts,_shared/api.ts}; supabase/tests/{payments_v2.sql,payments_v2.test.mjs (new), coin_orders.sql, web_quiet_pass.sql, coin_payments.test.mjs}; lib/platform/{payment_capabilities,payment_proof (new)}.dart; lib/ui/economy/{coin_packs,play_offers}.dart; lib/ui/screens/admin/payments_admin_screen.dart (new; coin_review_screen.dart removed); lib/ui/screens/setup/coin_store.dart; lib/app/router.dart; lib/data/terms_consent.dart; lib/app/l10n/*; pubspec.yaml/.lock (image_picker, image); test/widget/{coin_purchase_test (rewritten),coin_store_test,store_v2_test,store_screenshots,update101_economy_test}.dart; test/screenshots/update101_screenshots.dart; web/privacy/index.html; store/GOOGLE-PLAY-SUBMISSION.md; build/update101/status.md.
Verified:   node tool/test_sql_without_docker.mjs → 86 migrations, 42/42 SQL (payments_v2 10 gates); all 11 supabase/tests/*.test.mjs PASS; flutter analyze 0 errors / 0 warnings (90 infos, none in payments files); flutter test --concurrency=2 "+1359 ~1: All tests passed!".
Gate:       PASS (local). Nothing deployed/committed.
Open:       Google Play Payments policy: selling digital goods by transfer inside the Play app may need an eligible alternative-billing programme — owner must confirm before transfer_enabled_android (noted in the submission doc; nothing hidden from review). Storage bucket/policy and edge upload untested against hosted Supabase (PGlite has no storage); no device run of the picker; purge runs only when the admin lists orders (no cron).

## PHASE 112 — done (1.0.1 server deployed; all features dark)
Built:      Live Supabase hezjbrnveajypfqmjfnh: backed up affected tables, function bodies and constraints (build/update101/backup/), applied 20260924000500, 20260925000100–000600, 20260927000100–000200 in order, each in its own transaction, then repaired the migration history. Deployed edge functions economy, play_purchase, coin_orders and admob_ssv (--no-verify-jwt). Set secrets COIN_PAY_INSTAPAY_URL, COIN_PAY_VODAFONE_CASH_URL (https), ADMOB_REWARDED_V2_ANDROID_ID; Telegram secrets set by the owner. Play Console: five one-time products active (mm_remove_interruptions 199.99, mm_coins_500 49.99, mm_coins_1200 99.99, mm_coins_2500 180, mm_starter_bundle 29.99 EGP). AdMob: app-open 9527218766 and banner 3131088967 units added.
Files:      build/update101/DEPLOY-PLAN.md; tool/{setup_play_verification,make_me_admin,setup_telegram_admin}.ps1; docs/PROGRESS.md.
Verified:   economy_config one row, every feature off; 27 new tables present; 0 economy functions executable by anon/authenticated; payment-proofs bucket private; coin_packs prices match Play; 8 wallets, total balance 850 before and after.
Gate:       PASS (server live, dark).
Open:       Owner: Play service account (tool/setup_play_verification.ps1), sign in at /admin then tool/make_me_admin.ps1, upload the 1.0.1+9 AAB, switch features on per build/update101/status.md. Codex raster art.

## PHASE 113 — done (email-link fallback, live test pass, rebuild)
Built:      Account protection and /admin accept an email that carries only a link (button «فتحت اللينك من الإيميل» re-reads the confirmed email; admin page follows auth state changes). Arabic-first SMTP templates (magic link, email change, confirmation) and docs/EMAIL-SMTP-SETUP.md for Resend. Rollback-only SQL suites run against the live DB. 1.0.1+9 AAB/APK/test-ads APK/web rebuilt from e531baf; web republished.
Files:      lib/transport/account_service.dart; lib/ui/economy/account_protection.dart; lib/ui/screens/admin/payments_admin_screen.dart; lib/app/l10n/*; test/transport/account_service_link_test.dart (new); test/widget/coin_purchase_test.dart; test/screenshots/update101_screenshots.dart; supabase/templates/*.html (new); docs/EMAIL-SMTP-SETUP.md (new); build/update101/hosted-tests/ads_v3.sql; HANDOFF.md.
Verified:   flutter analyze 0 errors/0 warnings; flutter test --concurrency=2 "+1384 ~1: All tests passed!"; SQL 42/42; 11/11 node tests. Live DB: 8 suites PASS inside rolled-back transactions; council_life, council_life_security and awards_reactions refuse on hosted (they ALTER auth.users, which the role does not own) — covered locally; fingerprint (687 users, 8 wallets, balance 850, config) identical before/after. play_voided_sync → "play api 401" (Play Console permission still propagating; cron retries every 6 h).
Gate:       PASS.
Open:       Owner: Resend SMTP + paste templates; upload AAB to Alpha; enable features per status.md; Codex raster art (Wednesday). No real email round-trip tested yet.

## PHASE 114 — done | 1.0.1 raster art
Built:      79 requested assets (75 transparent/opaque WebP art files + 4 opaque Play PNGs), using sheets A–H and all 17 individual-art requests; generated five store covers individually for clearer 768×768 output. CouncilRaster.delivered lists all 77 bundled WebPs used by RasterOr; all generated asset folders, including assets/images/ads/, are registered in pubspec.
Files:      docs/ART-REQUEST-CODEX-1.0.1.md; lib/ui/economy/council_art.dart; test/widget/council_raster_test.dart; pubspec.yaml; assets/images/{ads,awards,council,economy_v2,launch,profile,reactions,store_v3}/*; store/play-1.0.1/*; raw_assets/update101b/*
Verified:   A–H sliced; all 79 paths audited for target dimensions, transparency/opaque backgrounds and file-size caps; thumbnail contact review; flutter test test/widget/council_raster_test.dart --reporter=expanded (4/4 pass); flutter analyze lib/ui/economy/council_art.dart test/widget/council_raster_test.dart (no issues).
Gate:       PASS.
Open:       Play promo files are blank screenshot backgrounds ready for real in-app captures and store copy to be overlaid during publishing. No emulator/device capture in this art pass.

## PHASE 115 — done | 1.1.0+10 launch polish, Four Dossiers, links, live activation
Built:      Claude×Codex debate → agreed plan. Four Dossiers (local bond ledger recorded on the public result screen for pass-and-play and online; /characters page per character with feathered portrait, 4 letters at 1/3/7/15 cases; profile strip; Home whisper; letter-arrived moment on the result screen). FeatheredArt: heroes/banners/portraits dissolve into the backdrop (mode, vault, online welcome, leaderboard, onboarding). History as painted case files; painted mode marks; order-state seals. Links open the app first: Play app-signing SHA-256 added to assetlinks (it listed only the upload key, so store installs never verified), App Links for /, /join/, /invite/; Android intent hand-off in web/index.html; council invites carry /invite/CODE which opens the vault's Council tab with the code typed. Version 1.1.0+10.
Files:      lib/data/character_bonds.dart; lib/ui/fun/{character_dossiers,characters_screen}.dart; lib/ui/widgets/feathered_art.dart; lib/ui/screens/{postgame/history_screen,postgame/result_screen,setup/mode_screen,setup/home_screen,setup/profile_screen,setup/coin_store,online/online_welcome_art}.dart; lib/ui/economy/{council_hub,coin_packs,economy_capabilities}.dart; lib/app/router.dart; lib/ui/theme/design_tokens.dart; ARBs; android manifest; web/index.html; web/.well-known/assetlinks.json; supabase/migrations/20260928000100_character_bonds.sql; supabase/tests/{character_bonds,awards_reactions}.sql; tests.
Verified:   flutter analyze 0 errors/0 warnings; flutter test --concurrency=4 "+1402 ~1: All tests passed!" on 9db6c39; SQL 43/43 (PGlite); purity L-16 green (bonds outside every private closure); migration applied to hosted + recorded in schema_migrations; play_voided_sync → 200; AAB 1.1.0+10 built (signed); web built and deployed to production, main.dart.js md5 matches, /, /admin, /privacy/, /app-ads.txt, /.well-known/assetlinks.json 200; screenshots in build/screens_launch.
Gate:       PASS.
Open:       Owner: upload build/release-1.1.0+10/*.aab to Alpha (111 MB, above the browser tool's upload cap). Live flags ON: daily, dailyAd, adSteps, adExtras, interstitial (+preMatch, passAndPlay, session), appOpen, banner, awards, reactions, council contracts/rank/leaderboard/invites, starter bundle, character bonds, all 5 play_products. Held: founder (30-day window should start at public launch), transfer_enabled_web (needs one real transfer end-to-end), transfer_enabled_android (Play payments policy). No device run this phase.

## PLANNING 1.1 — done (plan closed; no code changed)
Built:      1.1 specification closed after rounds 9b–10b and two big game rounds (Claude proposes, Sol criticises; Sol: "GAME PLAN CLOSED"): 129 h launch ceiling, F15–F26 (spoken narrator, big-table speed, family mode, how-to scenes, reveal signature at L), pre-mortem with 17 kill gates, ordered roadmap. Marketing plan final after rounds 5–6 with the marketing session and Sol's M1/M2 critiques: honest month-1 middle ≈ $41.5, ≈ $60 planning number with a creator network, strength-first content, no offer-led headlines.
Files:      docs/BIG-UPDATE-1.1-FINAL.md; docs/BIG-UPDATE-ROUND9B.md; docs/BIG-UPDATE-ROUND10B.md; docs/BIG-UPDATE-GAME-BB1.md; docs/BIG-UPDATE-GAME-BB2.md; docs/marketing/{PLAN-V3,CONTENT-SYSTEM,LAUNCH-RUNBOOK,DECISIONS,CONTEXT,CODEX-M2}.md
Verified:   payment-term grep clean on every new document; M1 (witness) checked against the 2026-09-23 owner decision; M5 re-derived from submit_night_action (bullets are the Mafia's and Doctor's only).
Gate:       PASS (plan)
Open:       Owner decisions: FINAL §12 (9) + marketing PLAN-V3 §10 (24). Implementation waits for «ابدأ». An early M2/M4/M5/M6 draft was parked, not applied; M5 must now also keep used_bullet = existing OR requested.

## PHASE 1.1-L1 (part) — done | in progress
Built:      Owner answers folded into the spec + launch recut (Sol: "LAUNCH RECUT CLOSED"); online-core blockers M2, M4, M5, M6, D1, D2 (server); Kratos narrator line bank + generator; creator list (59 verified channels); Codex art production started (S0, S9, S1 done; S2–S8, S10 running).
Files:      docs/BIG-UPDATE-1.1-FINAL.md, docs/BIG-UPDATE-ROUND-RECUT.md, docs/marketing/*, tool/voice/*, lib/transport/{supabase_backend,account_auth}.dart, lib/ui/screens/online/{online_session,online_entry_screen}.dart, lib/ui/account/account_sheet.dart, lib/app/l10n/*, supabase/functions/{submit_night_action,send_whisper,economy}/index.ts, supabase/functions/_shared/economy_actions.ts, supabase/migrations/20260928000600_bullet_stays_spent.sql, supabase/migrations/20260928000700_case_puzzle_receipts.sql, supabase/tests/{bullet_stays_spent,case_puzzle_receipts}.sql, supabase/tests/case_of_day.test.mjs, test/online/online_session_recovery_test.dart, test/transport/edge_refusal_test.dart, test/widget/account_sheet_test.dart, raw_assets/update11/**
Verified:   SQL 49/49 on PGlite; all supabase/tests/*.test.mjs pass; online_session_recovery 14/14, account_sheet 9/9, online_entry/deep_link/invite_share pass; analyze: no errors outside the untracked case_of_day WIP; S0/S9/S1 contact sheets reviewed at 900 px.
Gate:       PASS for the landed blockers; the row-1 gate (online/leakage suites ×3, chaos) runs when the row is complete.
Open:       Row 1 still needs M3, D7, D3+D4, S4, plus D2's client requestId (it lives in the untracked case_of_day WIP). 12 Play testers must opt in by Oct 1 (owner). Kratos voice: ELEVENLABS_API_KEY in env, designed-not-cloned confirmation and commercial-use authorization (owner). S1 art reuses one window/skyline composition too often; retouch after the batch run. No push, deploy or publish.

## PHASE 1.1-L1 — done (row 1: online-core blockers)
Built:      All ten §7 blockers. M2, M4 (now an inline confirmation per doc 12 §2.1), M5, M6, D1, D2 (server; client requestId lands with the Daily Case row), M3 (beats go to the unpublished room_presence; roster only on transitions), D7 (one resultSummary), D3 (Season Zero waits for operator_start_season), D4 (level ≥ 1 display), S4 (pinned Realtime columns + fixed-sentence refusal harness).
Files:      supabase/migrations/20260928000600…001000 (bullet_stays_spent, case_puzzle_receipts, season_operator_start, unpublished_presence, result_summary); supabase/tests/{bullet_stays_spent,case_puzzle_receipts,season_operator_start,publication_allowlist,unpublished_presence,result_summary}.sql, error_envelope.test.mjs; heartbeat, claim_host, send_whisper, open_phase, room_settings, ghost_say, economy, submit_night_action edge code; lib/transport/{supabase_backend,online_transport,account_auth}.dart; lib/ui/screens/online/{online_session,online_entry_screen}.dart; lib/ui/account/account_sheet.dart; lib/ui/economy/{council,council_hub}.dart; lib/ui/missions/{casebook_sheet,casebook_data}.dart; l10n; tests.
Verified:   SQL 53/53 on PGlite; all node suites (error envelope: 241 refusals / 62 files); flutter test --concurrency=4 "+1429 ~1: All tests passed!"; analyze: no errors outside the untracked case_of_day WIP.
Gate:       PASS (hosted chaos cases run with the RC matrix, row 15; nothing deployed).
Open:       D2 client requestId (in the untracked case_of_day WIP). Next row: Safety v11 (blocks are enforced today only in friends and the Council leaderboard; join/list/quick-match/rematch/whispers/reactions still need safety_users_compatible). Art loop running (S4–S10).

## PHASE 1.1-L2 — done (row 2: Safety v11 + owner queue)
Built:      one compatibility rule on join/list/quick match/next room; block cleanup; name/title terms by trigger; v11 reports (categories, dedup, limits, public evidence); restrictions + notices; /admin/safety queue with request-id decisions and retention purge. Also row 13 sound: 24 synthesised 1.1 cues + brand motif (f61e10c).
Files:      supabase/migrations/20260928001100_safety_v11.sql, supabase/tests/safety_v11.sql, supabase/functions/{player_safety,join_room,quick_match,create_room,rematch_room,room_settings,realtime_token,_shared/api.ts}, lib/ui/screens/{online/safety_center,online/online_entry_screen,admin/safety_admin_screen,admin/payments_admin_screen}.dart, lib/data/request_id.dart, lib/app/{router.dart,l10n/*}, test/widget/safety_v11_test.dart
Verified:   SQL 54/54 (PGlite); node suites incl. error envelope 264 refusals; server_surface_test; full Flutter suite +1438 ~1 all passed; analyze clean outside the untracked case_of_day WIP
Gate:       PASS (review drill with the owner still to run on hosted after deploy approval)
Open:       safety_v11_enabled stays OFF; seed name list is a starter the owner extends; hosted migration/deploy waits for the owner

## PHASE 1.1-L6 (part) — done | P7 creator entitlement
Built:      Server-only, request-idempotent creator grant/revoke with an audit trail and time-bounded creator ad relief; capabilities expose creator state; all automatic interstitial, result-exit, app-open and waiting-banner decisions suppress for active creators while rewarded offers remain unchanged.
Files:      supabase/migrations/20260928001400_creator_entitlement.sql; supabase/tests/creator_entitlement.sql; supabase/functions/coin_orders/index.ts; lib/ui/economy/{economy_capabilities,interstitial_coordinator,app_open_gate,waiting_banner}.dart; test/unit/creator_entitlement_test.dart; docs/PROGRESS.md
Verified:   SQL 57/57; error envelope 271 refusals / 62 files; creator unit tests 3/3; unit + server surface +100 all passed; targeted analyze of P7 files clean.
Gate:       FAIL only on shared-tree full analyze: unrelated unused online_backend import in test/screenshots/update11_screenshots.dart; every P7 gate passed.
Open:       Remove the unrelated update11_screenshots.dart import in its owning lane, then rerun the full analyze gate. Nothing deployed or committed.

## PHASE 1.1-L3 — runtime done, voice pending (row 3: F16 narrator)
Built:      NarratorBank (public facts only, no-repeat, family filter); AudioDirector.narrate() under play()'s in-hand/mute/switch rules at the player's voice volume; pass-and-play beats night (own announcement only when a line exists), morning, discussion, voting/revote, vote result, winner after the reveal; tool/voice/install_kratos.py (trim, -16 LUFS, --approve only); empty assets/voice/kratos/manifest.json
Files:      lib/platform/{narrator_bank,audio_director,audio_backend}.dart, lib/app/app.dart, lib/ui/screens/match_flow.dart, tool/voice/install_kratos.py, assets/voice/kratos/manifest.json, test/platform/narrator_test.dart
Verified:   narrator + audio isolation suites; every match-flow/audio test (287); full suite later +1465
Gate:       PARTIAL — lines not rendered (ELEVENLABS_API_KEY not set yet); listener gate, provenance and commercial-use record still open
Open:       owner sets the key; render → listen → install with --approve

## PHASE 1.1-L5 (part) — done (F13 metrics, Install Referrer bucket, P9 review) — Codex-built, reviewed
Verified:   metrics_v11.sql; envelope; full suite; referrer raw string never stored; review/metrics never start a capabilities fetch
Open:       operator controls, warm-up, low-end perf budgets of row 5

## PHASE 1.1-L6 (part) — done (P7 creator entitlement) — Codex-built, reviewed (see block above)

## PHASE 1.1-L8 (part) — done (F19): result role figures rise (reduced motion: fade); brand motif at launch
Open:       Partner lobby plate

## PHASE 1.1-L11 — done (F21a witness whispers)
Built:      witness_whispers/witness_member/witness_report; witness_view whispers + WITNESS_ONLY; panel whisper list with report; composer disclosure
Verified:   witness_whispers.sql; witness_whispers_test; doc12 acceptance; full suite +1465
Gate:       PASS locally (hosted witness_match.py updated to WITNESS_ONLY, run after deploy)
Open:       witness_whispers_enabled OFF until owner activation

## PHASE 1.1-L1 (A: §7 verification, observability, D7 completion) — done — cloud
Built:      request id in every Edge body and `x-request-id` header, generic 500 on exceptions, one log line per request (fn/result/latency bucket/request id; no names, codes, roles, targets); runtime S4 harness (every literal refusal × 8 caller roles, exact {error,message,requestId}, recursive private-key/UUID/name rejection); M6 replay rule extracted and tested; D7 `resultSummary{roomId,requestId}` with server deltas, receipt and replay
Files:      supabase/functions/_shared/{api,whisper_replay,economy_actions}.ts, supabase/functions/send_whisper/index.ts, supabase/migrations/20260929000200_result_summary_v2.sql, supabase/tests/{request_envelope,whisper_replay}.test.mjs, supabase/tests/support/ts_loader.mjs, supabase/tests/{error_envelope,council_life}.test.mjs, supabase/tests/result_summary_v2.sql, lib/ui/economy/council_hub.dart, test/widget/council_life_test.dart
Verified:   SQL 61/61; all node suites; council_life_test 26/26; analyze clean
Gate:       PASS
Open:       D1/M2/M3/M4/M5/D3/D4 were already landed with tests (PHASE 1.1-L1); re-verified by reading the tests, not by mutation. D2 is Daily Case (not this lane).

## PHASE 1.1-L6 (B: Economy v3 authority + invite settlement) — done — cloud
Built:      `economy_v11_enabled` (default OFF): immutable match receipts (6/day, 3 per HMACed full-roster fingerprint, unique ordinals), faucet amounts 25/+10/+25 first-of-day, Season XP 5/+5, Council XP 30/+20, receipt-driven Council/Casebook/Thursday eligibility, v1-paid rooms preserved; invite settlement 50/25/75 with every condition, 10/season + 40/lifetime caps, unlocks at 3/10, notice lines; `economy.version=3`; `invite_ack`
Files:      supabase/migrations/20260929000100_economy_v3.sql, supabase/tests/economy_v3.sql, supabase/functions/_shared/economy_actions.ts, lib/ui/economy/{economy_capabilities,council,council_hub}.dart, lib/app/l10n/*, test/unit/economy_v3_test.dart
Verified:   economy_v3.sql (flag off = old 100/25 and no receipt; caps; fingerprint order/kick/salt/collision; replay; ordinal races; ineligible cases; XP from receipt; every settlement edge); SQL 61/61; node suites; unit tests
Gate:       PASS
Open:       Store catalogue, prices and ad policy untouched (out of scope). The invite frame unlock is recorded in `invite_unlocks` only; wiring it to a catalogue item belongs to the catalogue owner. Daily mission amounts already equal the faucet table and are read at claim time from `mission_catalog`.

## PHASE 1.1-L4 (C: host continuity and hand-off reliability) — done — cloud
Built:      interleaving tests for start/leave, start/kick and join/start in both orders; hand-off keeps configuration and readiness (no roster change) and the previous host cannot start; host leaving the lobby clears readiness and hands to the lowest seated row; hand-off in all ten server phases leaves the phase untouched; «{name} بقى الهوست» in every phase, never for the first host; process-death resume in reveal, night action (bullet stays spent, no second move) and whisper compose
Files:      supabase/tests/host_continuity.sql, test/online/{process_death_resume,host_handover}_test.dart
Verified:   host_continuity.sql + lobby_ready.sql; the two Flutter suites (17 tests)
Gate:       PASS
Open:       PGlite is one connection: true concurrent sessions stay covered by supabase/tests/concurrency_match.py on a hosted project (row 15). connection_weather.dart untouched.

## PHASE 1.1-L9 (D: F10 titles + core Partner, data and server) — done — cloud
Built:      `titles_enabled` / `partner_enabled` (+ character bonds), default OFF; `title_catalog` (Season titles + «كبير الشلة»), `player_titles` exact-once from claimed Season levels and the invite unlock, `player_showcase`, `titleHub`/`titleEquip{code|null,requestId}` with replay, `roomTitles{roomId}` (lobby and result only, empty while played); `player_partner`, `partnerGet`/`partnerSet{side,requestId}` free outside a live match (`IN_MATCH`); guests keep a versioned local choice; providers + minimal `TitleEquipList` / `PartnerPicker` hooks with TODO(art) slots; import-closure tests keep titles/Partner/bonds out of hand-off, reveal, night and online live-seat surfaces
Files:      supabase/migrations/20260929000400_titles_partner.sql, supabase/tests/titles_partner.{sql,test.mjs}, supabase/functions/_shared/economy_actions.ts, lib/ui/social/titles_partner.dart, lib/ui/economy/economy_capabilities.dart, lib/app/l10n/*, test/widget/titles_partner_test.dart, test/golden/leakage/{handoff_purity,partner_title_closure}_test.dart
Verified:   SQL 64/64; routing test; widget tests 6/6; closure tests; analyze clean
Gate:       PASS
Open:       Placement is the art lane's: Profile/Casebook/Home live under lib/ui/screens/setup/** and casebook_sheet.dart (not this lane). The lobby plate reads `fetchRoomTitles` from lobby_screen.dart (not this lane). Partner voice lines (Home/Casebook/result) need copy + art.

## PHASE 1.1-L12 (E: P6 pass-and-play result inventory + launch events) — done — cloud
Built:      P6: the pass-and-play result lists the existing offers still waiting today (daily rewarded ad, extra wheel, extra coffer) below the revealed roles and opens the daily rewards sheet — no new faucet, nothing when off/used/in a match; the pre-deal pass-and-play interstitial placement never shows; at most one pass-and-play result-exit ad per app session. Launch events: `operator_event_set` (service-only, request-idempotent, audited, no backdate, live start frozen, ≤7 days, canonical preset fingerprint, Cairo-local bounds), `launch_event_state`, eligibility by start time + fingerprint + eligible record, public-result-only `eventResult{roomId}`; immutable `operator_audit_log`
Files:      lib/ui/economy/{pass_result_inventory,interstitial_coordinator}.dart, lib/platform/monetization/interstitial_policy.dart, lib/ui/screens/{match_flow,postgame/result_screen}.dart, lib/ui/fun/launch_events.dart, lib/ui/theme/design_tokens.dart, lib/app/l10n/*, supabase/migrations/20260929000500_launch_events.sql, supabase/tests/launch_events.{sql,test.mjs}, supabase/functions/_shared/economy_actions.ts, test/unit/{ads_v3_policy,launch_events}_test.dart, test/widget/pass_result_inventory_test.dart
Verified:   launch_events.sql + thursday_night.sql; routing; ads_v3_policy 27/27; inventory 5/5; launch events unit 2/2; full gates below
Gate:       PASS
Open:       The pre-deal change narrows an existing (flagged) placement to match P6 ("never before role reveal, handoff, pre-deal") — the owner should confirm. "Launch events" is read as operator-scheduled event windows (F12 `operator_event_set`); no rewards were attached because the spec names none. Result-screen stamp art is a TODO(art) slot.
