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
