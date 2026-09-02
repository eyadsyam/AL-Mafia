# Claude Code Brief — Information Engine + Online Mode

> Paste this into Claude Code from the project root.
> **Read first, in this order:** `05-zero-leakage-spec.md` → `09-information-engine.md` → `10-online-architecture.md` → `11-edge-cases-and-tests.md`.
> Those four documents are the specification. This file is the build order and the gates.

---

## Prime directives

1. **Doc 05 wins every argument.** If a change would let a player infer another player's role, it does not ship. Stop and report instead of amending the spec.
2. **One engine, two transports.** Never write `OnlineGameEngine`. Never put `if (isOnline)` in a widget — the only permitted exceptions are voice controls and the connection banner.
3. **Purity is enforced.** `lib/engine/` has zero Flutter imports, zero `DateTime.now()`, zero unseeded `Random()`. This is checked by a lint rule you will add.
4. **Never invent a fact.** The Information Engine may only surface things players actually did. If no trace or confrontation is eligible, output nothing.
5. **Voice is never load-bearing.** An online match must complete normally with voice fully broken.
6. **Verify on the emulator.** No phase is complete without a screenshot you have actually looked at.

---

## Tools to use

You have MCP servers connected. Use them — do not hand-write what a tool does correctly.

### Supabase MCP (`mcp__d68dbed8-...`)

| Step | Tool |
|---|---|
| Inspect existing schema before changing it | `list_tables`, `list_extensions` |
| Every schema change | `apply_migration` — **never** `execute_sql` for DDL. Migrations are the audit trail |
| Ad-hoc reads while debugging | `execute_sql` |
| Deploy each Edge Function | `deploy_edge_function` |
| **After every migration** | `get_advisors(type: "security")` — **any finding is a release blocker** |
| Performance check before release | `get_advisors(type: "performance")` |
| Debug a failing function | `get_logs` |
| Client-side types for Edge Function payloads | `generate_typescript_types` |
| Safe experimentation | `create_branch` → test → `merge_branch` |
| Look up a Supabase API you are unsure about | `search_docs` — do not guess |

### Skills

| When | Skill |
|---|---|
| Before writing the transport layer | `engineering:system-design` — sanity-check the abstraction |
| Before writing tests | `engineering:testing-strategy` |
| **After the online mode compiles** | `security-review` — focus on RLS and role leakage |
| Before merging each phase | `engineering:code-review` |
| If a bug resists diagnosis | `engineering:debug` |

### Emulator

`Pixel 9 pro (2)` is running. `adb devices` → `flutter run -d <id>` → `adb exec-out screencap -p > /tmp/s.png` → **look at it**.

---

# PHASE 0 — Foundations (do this first, no exceptions)

**Goal: make the engine pure and testable before adding anything to it.**

1. Move all game logic into `lib/engine/`, free of Flutter imports.
2. Add a lint/CI check that fails the build if `lib/engine/**` imports `package:flutter` or calls `DateTime.now()` or bare `Random()`.
3. Introduce `matchSeed` (int) on every match, offline and online. All randomness derives from it:
   ```dart
   int deriveSeed(int matchSeed, String salt, int index) =>
       matchSeed ^ (salt.hashCode * 31) ^ (index * 104729);
   ```
4. Introduce the four invariants from `11-edge-cases-and-tests.md` §0 and assert them after every state mutation (assert-only in release).
5. Build the **fuzz harness** (§9 of doc 11). 10,000 matches, `guard > 500` non-termination check.

**Gate:** fuzz harness green on the *existing* game before you add a single new feature. If it finds stalls today, fix them now — they will be far harder to find once the Information Engine is layered on.

---

# PHASE 1 — Data model & records

Extend the model per `09-information-engine.md` §5:

- `NightRecord` — suspicions, reasons, actions, victim, saveOccurred, revealedTrace
- `DayRecord` — openingAccusations, confrontation, votes, eliminated, speakingSeconds, whispers
- `WhisperMeta` / `Whisper` — **stored separately**; the graph is public, the body is not
- `GameHistory` — the append-only log both generators read from

Isar schema migration for the offline side. Run `build_runner`. Verify existing match history still loads — write a migration test with a pre-change database fixture.

**Gate:** old matches still open in history. No data loss.

---

# PHASE 2 — Layer 1: The Trace

Implement `lib/engine/information/trace_generator.dart` exactly per doc 09 §1.

- All 8 trace types + `T0` fallback
- Eligibility functions are pure and individually tested
- Scoring: drama × novelty × information
- No back-to-back repeats of the same type
- Seeded deterministic tie-break

UI: morning screen (`S-10`), trace text appears **1.2s after** the death line, identical visual treatment for all types.

**Tests:** T-E1 → T-E9 from doc 11 §5.1, all passing.

**Gate:** play a full offline match on the emulator. Screenshot every morning screen. Confirm the Day-1 trace actually gives the table something to talk about — this is the whole point of the feature.

---

# PHASE 3 — Layer 2: The Confrontation + Day-1 opener

1. **Day-1 opener «اسم واحد»** — 10 seconds per living player, seating order, forced choice, recorded to `openingAccusations`.
2. `lib/engine/information/confrontation_generator.dart` — types C1–C10 (C11 gated OFF by default).
3. Hard filters: alive only, no back-to-back same player, no back-to-back same type.
4. **Fairness factor** — max twice per match per player unless no alternative. Do not skip this; without it one player gets targeted every day and stops enjoying the game.
5. Exactly **one** confrontation per day. Never two.

UI per doc 09 §2.6. Named player may end early. Nobody may interrupt.

**Tests:** C-E1 → C-E8.

**Gate:** emulator match reaching Day 3+, screenshots of each confrontation, and verify no player is targeted more than twice.

---

# PHASE 4 — Layer 3: The Whisper (offline first)

- 1 per living player per day, 120 chars, no self, no dead
- Graph public, content private
- Offline delivery: queued to the recipient's next private turn
- **Mandatory:** the whisper card appears on **every** player's turn, showing «مفيش همسات ليك» when empty. Without this, screen count leaks who received a whisper — a direct doc 05 violation
- Voiding when the recipient dies, with «الهمسة ماوصلتش» to the sender
- Abuse controls: length, rate limit, client-side profanity warning, report → local block list

**Tests:** H-E1 → H-E10. Add a golden test proving the whisper card renders identically whether or not a whisper is present.

**Gate:** L7 leakage test passes.

---

# PHASE 5 — Transport abstraction

Introduce `GameTransport` (doc 10 §7) and move offline play behind `LocalTransport`.

**This phase adds no features.** Its only job is to prove the interface is right while there is still exactly one implementation. If offline play behaves identically after this refactor, the abstraction is correct.

**Gate:** full offline match plays identically. Fuzz harness still green. Zero UI changes.

---

# PHASE 6 — Supabase backend

1. `create_branch` for a safe workspace.
2. `apply_migration` for the schema in doc 10 §4 — one migration per logical unit, never one giant file.
3. RLS policies + the `room_players_public` view.
4. **`get_advisors(type: "security")` → must be clean before proceeding.**
5. Edge Functions per doc 10 §5, deployed with `deploy_edge_function`.
6. Port `selectTrace` and `selectConfrontation` to TypeScript **and add golden-vector tests** comparing them to the Dart output. CI fails on divergence.
7. Write the anti-cheat tests **now**, not later:
   - attempt to read another player's role → must fail
   - attempt to vote as another user → must fail
   - attempt to submit a night action for a role you do not have → must fail

**Gate:** security advisors clean, all three anti-cheat tests failing correctly (i.e. the attacks are blocked).

---

# PHASE 7 — OnlineTransport + lobby

- Anonymous auth, room create/join by 6-character code (unambiguous alphabet)
- Realtime subscription → `GameSnapshot`
- **Snapshot-based resync on reconnect** — deltas for the happy path, snapshots for recovery
- Idempotency keys on every action
- Server-side `phase_ends_at` with client clock-skew correction
- Timer-expiry defaults per doc 10 §8.2 — every phase must have one
- **Host migration** to lowest-seat connected player

UI: lobby, room code share, connection banner, per-player connected state — **frozen during the night phase** (doc 10 §6.3).

**Tests:** O1 → O20.

**Gate:** full online match, 5 devices/emulators, with a deliberate disconnect at every phase boundary. Every one recovers.

---

# PHASE 8 — Whisper online + voice

1. Whispers over Supabase with **server-side** rate limiting.
2. `flutter_webrtc` mesh, **single active speaker enforced by the server**.
3. STUN → TURN → text-mode fallback ladder.
4. Mic policy table from doc 10 §6.3 — hard-muted during night, reveal, and voting.
5. Lobby warning: «لو قاعدين في نفس الأوضة، استخدموا سماعات».

**Tests:** V1 → V9.

**Gate:** a complete online match with voice **entirely disabled** finishes normally. This is the acceptance criterion for "voice is not load-bearing".

---

# PHASE 9 — Hardening & release

- Full fuzz harness
- All L1–L10 leakage regressions
- `get_advisors` security + performance, both clean
- 24-hour purge cron (`pg_cron`) for finished matches
- Weekly keep-alive ping so the free project does not pause
- `security-review` skill over the whole online surface
- Release build

---

# UI/UX requirements (all phases)

From `01-design-system.md` and `07-ux-ui-elevation.md`:

- Ground `#0D0F14`; panels `#161A22`; cream `#D9CDB4`; **zero hardcoded values outside `design_tokens.dart`**
- Text scale locked at 1.0; Arabic line-height 1.6; **zero letter-spacing on Arabic**
- Icons for navigation chrome only; **words for every game action**
- All primary actions in the bottom third; confirm targets ≥ 56dp
- One master light direction for every shadow
- Reduce-motion path verified on every animated screen
- Trace, Confrontation, and Whisper screens are **table screens** — large type, readable at 1.5m
- The whisper compose sheet is a **private screen** — dimmed, and subject to all doc 05 parity rules

---

# Definition of done

Every box in `11-edge-cases-and-tests.md` §10, plus:

- [ ] Offline mode works with the device in airplane mode, start to finish
- [ ] Online mode completes with voice disabled
- [ ] Same `matchSeed` + same actions → identical traces and confrontations in both modes
- [ ] No player can read another player's role — proven by a failing-attack test
- [ ] Fuzz harness: 10,000 matches, zero stalls, zero invariant violations

---

# Reporting

After each phase, report in this format — nothing else:

```
PHASE n — done
Built:      <one line>
Verified:   <what you actually ran / looked at>
Gate:       PASS | FAIL
Surprises:  <anything that contradicted the spec>
Next:       <phase n+1>
```

If a spec document is wrong or self-contradictory, **stop and say so.** Do not silently work around it — the specs are the shared source of truth and a silent divergence is worse than a delay.
