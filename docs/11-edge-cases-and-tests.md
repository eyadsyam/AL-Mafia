# Mafia Master — Edge Cases & Test Matrix

> The safety net for the "no logic errors, no edge-case errors, 100% playable" requirement.
> **Every row below is a required test.** A case with no test is a case that will break in front of users.

---

## 0. Testing philosophy

| Layer | Type | Rule |
|---|---|---|
| Engine + Information Engine | **Pure unit tests** | No mocks, no I/O, no `DateTime.now()`. If a test needs a mock, the code is wrong |
| Transport | Integration | Local: real Isar. Online: real Supabase test project |
| UI | Golden tests | Zero-leakage parity across all four roles |
| Full match | **Property-based / fuzz** | Run 10,000 random matches; assert invariants never break |

### The four invariants — assert these after **every** state mutation

```dart
void assertInvariants(GameState s) {
  // I1 — the alive set is coherent
  assert(s.players.where((p) => p.isAlive).length == s.aliveCount);

  // I2 — the game is never in an unresolvable state
  assert(s.outcome != MatchOutcome.inProgress || s.aliveCount >= 2);

  // I3 — every phase has a way out
  assert(s.phase == Phase.result || s.phaseEndsAt != null || s.awaitingAction);

  // I4 — no role count ever exceeds the player count
  assert(s.roleCounts.values.fold(0, (a, b) => a + b) == s.players.length);
}
```

The fuzz harness runs these after every single transition. This one harness catches more than any hand-written suite.

---

# 1. Player count & setup

| # | Case | Expected | Test |
|---|---|---|---|
| S1 | 4 players | Blocked at setup with a clear message | unit |
| S2 | Exactly 5 | Allowed. Suggested: 1 Mafia, 1 Doctor, 0 Detective, 3 Citizens | unit |
| S3 | 16+ players | Offline: allowed to 20. Online: **hard cap 15** (voice mesh + message volume) | unit |
| S4 | Mafia = 0 | Blocked | unit |
| S5 | Mafia ≥ half | Blocked — the match would end on turn 1 | unit |
| S6 | Roles sum ≠ player count | Impossible — Citizens are always the remainder, computed not entered | unit |
| S7 | Two players named "أحمد" | Auto-suffix «أحمد ٢». Never silently merge | unit |
| S8 | Empty / whitespace-only name | Rejected at input | widget |
| S9 | 40-character name | Truncated with ellipsis in UI, stored in full | golden |
| S10 | Player removed during setup after roles configured | Role config re-validated; if now invalid, user is told before proceeding | unit |

---

# 2. Night phase

| # | Case | Expected | Test |
|---|---|---|---|
| N1 | Mafia targets another Mafia | Allowed. Resolves normally. May immediately trigger Citizens win | unit |
| N2 | Doctor protects the Mafia's target | No death. `saveOccurred = true`. `T2` becomes eligible | unit |
| N3 | Doctor protects themselves | Allowed only if the setting permits **and** not on consecutive nights | unit |
| N4 | Doctor protects the same player two nights running | **Blocked by default.** Tile renders disabled with a hint | unit + golden |
| N5 | Detective investigates a dead player | Dead players are not shown in the grid. Unreachable by construction | widget |
| N6 | Detective investigates themselves | Own tile is absent from the grid | widget |
| N7 | Multiple Mafia, tie in target votes | Resolved by the configured tie rule **with no extra phone pass** (doc 05 §5) | unit |
| N8 | Multiple Mafia, one disconnects (online) | Remaining Mafia's votes decide. Absent Mafia contributes nothing | integration |
| N9 | All Mafia disconnect (online) | Timer expiry → seeded random target from living non-Mafia. Match continues | integration |
| N10 | Citizen skips their suspicion | Recorded as `null`. Feeds `T6` and `C10` | unit |
| N11 | Citizen writes a 41-char note | Blocked at 40 by the input, server also truncates | unit + widget |
| N12 | Last living Doctor dies | No protection thereafter. No crash, no null deref | unit |
| N13 | Last living Detective dies | No investigation phase. Night is shorter — **offline: parity still enforced**, other roles unaffected | unit |
| N14 | Every living player is Mafia | Win check fires before the night begins | unit |
| N15 | Night action submitted twice (retry) | Idempotent via `action_id`. Second call is a no-op | integration |
| N16 | Action submitted after the phase ended | Rejected with `PHASE_CLOSED`. Client shows the new phase, does not error out | integration |
| N17 | Offline: app killed mid-night-action | Resume lands on the **pass screen** for the same player, never on the action content | integration |
| N18 | Online: player rotates device mid-action | Selection preserved. No resubmit | widget |

---

# 3. Day, voting, elimination

| # | Case | Expected | Test |
|---|---|---|---|
| D1 | All players abstain | No elimination. Proceed to night. Not a stall | unit |
| D2 | Two-way tie | Configured rule: revote among tied only, or no elimination | unit |
| D3 | Tie persists after revote | Hard-resolve: no elimination. **Never loop forever** — max 2 revote rounds | unit |
| D4 | Three-way tie | Same path as two-way | unit |
| D5 | Player votes for themselves | Own tile absent. Unreachable | widget |
| D6 | Player votes for a dead player | Dead not shown. Unreachable | widget |
| D7 | Only 2 players alive | Vote always ties → win check already fired at parity. Unreachable in practice; assert it | unit |
| D8 | Voter disconnects mid-vote | Abstain at expiry | integration |
| D9 | Everyone disconnects except one | Host migration; if nobody remains, match is abandoned and archived, not corrupted | integration |
| D10 | Vote submitted twice | Idempotent — last write per `(day, voter, round)` wins | integration |
| D11 | Eliminated player was the last Mafia | Reveal role → beat → Citizens win. **Never skip the reveal** | unit + widget |
| D12 | Elimination brings Mafia to parity | Reveal role → beat → Mafia win | unit |

---

# 4. Win detection

| # | Case | Expected |
|---|---|---|
| W1 | 1 Mafia vs 1 non-Mafia | `MAFIA_WIN` (parity) |
| W2 | 2v2 | `MAFIA_WIN` |
| W3 | 3v3 | `MAFIA_WIN` |
| W4 | 1 Mafia vs 2 non-Mafia | `IN_PROGRESS` |
| W5 | 0 Mafia, ≥1 alive | `CITIZENS_WIN` |
| W6 | 0 players alive | `DRAW` — defensive only, must not throw |
| W7 | Player quits and was the last Mafia | `CITIZENS_WIN`, annotated in the timeline as won-by-forfeit |
| W8 | Win condition met mid-night-resolution | Check runs **after all deaths are applied**, never mid-resolution |

Full detail in `06-win-conditions.md`. **Property test:** for 100,000 random `(mafia, nonMafia)` pairs, `evaluateOutcome` matches the parity rule exactly.

---

# 5. The Information Engine

## 5.1 Trace

| # | Case | Expected |
|---|---|---|
| T-E1 | No trace is eligible | `T0` — «الليلة دي ماسابتش أي أثر». **Never crash, never invent one** |
| T-E2 | Victim's suspicion target is now dead | `T1` ineligible → fall through to the next candidate |
| T-E3 | Victim recorded no suspicion (skipped) | `T1` ineligible → fall through |
| T-E4 | Nobody died (Doctor saved) | `T1` ineligible. `T2` eligible |
| T-E5 | Same trace type was published yesterday | Excluded from today's candidate set |
| T-E6 | Two candidates score identically | Deterministic seeded tie-break. **Same result on every device** |
| T-E7 | Night 1, all suspicions random | `T1` still fires — social value, not evidential. Documented, not a bug |
| T-E8 | `T5` (الظل) on night 1 | Ineligible — requires ≥2 nights elapsed |
| T-E9 | Online and offline given identical inputs | **Byte-identical trace output.** Golden-vector test in CI |

## 5.2 Confrontation

| # | Case | Expected |
|---|---|---|
| C-E1 | Day 1 | No confrontation. The «اسم واحد» opener runs instead |
| C-E2 | No candidate qualifies | **Silently skipped.** Day proceeds to free discussion. Never fabricate |
| C-E3 | Only candidate is the player confronted yesterday | Skipped rather than repeated, unless no alternative exists at all |
| C-E4 | Confronted player is eliminated before responding | Unreachable — the confrontation runs at the start of the day, before any vote |
| C-E5 | Confronted player disconnects (online) | 45s of silence, then the day proceeds. Silence is recorded and is itself information |
| C-E6 | Same player would be confronted a 3rd time | Fairness factor blocks it unless there are literally no other candidates |
| C-E7 | Evidence references a now-dead player | Still valid — «الميت يتكلم» is the point. Text must read correctly with a dead subject |
| C-E8 | Whisper-based confrontation (`C8`) with whispers disabled | Type excluded from the candidate set entirely |

## 5.3 Whisper

| # | Case | Expected |
|---|---|---|
| H-E1 | Second whisper on the same day | Rejected, **server-side**. UI disables the control after the first |
| H-E2 | Recipient dies before reading | Whisper voided. Sender told «الهمسة ماوصلتش» |
| H-E3 | Sender dies after sending | Whisper still delivers. The dead can accuse from the grave |
| H-E4 | Whisper to a dead player | Recipient picker only lists the living. Unreachable |
| H-E5 | Whisper to self | Own tile absent. Unreachable |
| H-E6 | 121 characters | Blocked client-side; server also rejects. Never truncate silently |
| H-E7 | Offline: recipient's next turn never comes (they die) | Same as H-E2 |
| H-E8 | Offline: player has no whisper waiting | **Must still show «مفيش همسات ليك»** — otherwise screen count leaks who received one. **Mandatory (doc 05)** |
| H-E9 | Blocked sender | Whisper silently dropped for the recipient. Sender is **not** told — do not create a harassment feedback loop |
| H-E10 | Empty whisper body | Rejected |

---

# 6. Online transport

| # | Case | Expected |
|---|---|---|
| O1 | Host leaves | **Automatic migration** to lowest-seat connected player. Match never ends because of it |
| O2 | Host and next-in-line leave together | Migration cascades down the seat order |
| O3 | Every player leaves | Room archived after 5 min. Never left "playing" forever |
| O4 | Player rejoins with the same `user_id` | Restored to their seat, role, and state |
| O5 | Player rejoins with a **new** `user_id` | Treated as a new player → rejected mid-match. Identity is the seat claim |
| O6 | Two devices, same account | Second is rejected with a clear message. Never mirror a secret role to two screens |
| O7 | Network partition (client thinks phase N, server is at N+1) | Client's action rejected `PHASE_CLOSED`; client force-resyncs from snapshot |
| O8 | Client clock is 10 minutes off | Timers render against `phase_ends_at` with skew correction. Client clock is never trusted |
| O9 | Supabase unreachable at match start | Clear error. **Offer offline mode.** Never a blank spinner |
| O10 | Supabase drops mid-match | Client shows «إعادة اتصال…», retries with backoff, resyncs on success. State preserved locally throughout |
| O11 | Supabase project paused (free tier) | Distinct, actionable error message — not a generic failure |
| O12 | Realtime message lost | Next snapshot corrects it. Deltas are the happy path, snapshots are the recovery path |
| O13 | Duplicate room code generated | Unique constraint → retry generation. Never collide |
| O14 | Join a `finished` room | Rejected with a clear message |
| O15 | Join a full room (15) | Rejected with a clear message |
| O16 | Malicious client requests another player's role | **RLS blocks it.** Automated test must attempt this and assert failure |
| O17 | Malicious client posts a vote for someone else | Edge Function rejects — `voter_id` is taken from the auth token, never from the body |
| O18 | Malicious client submits a night action for a role it does not have | Edge Function validates role → rejected |
| O19 | Replay of a captured request | Idempotency key makes it a no-op |
| O20 | Player backgrounds the app for 10 min | Marked disconnected, defaults applied at expiry, full resync on return |

---

# 7. Voice

| # | Case | Expected |
|---|---|---|
| V1 | Mic permission denied | Match continues, receive-only. Told once, calmly, then never again |
| V2 | No mic hardware | Same as V1 |
| V3 | STUN and TURN both fail | Text mode for that player. **Match unaffected** |
| V4 | Player speaks while not the active speaker | Locally hard-muted, and the server ignores their track. Not a polite request |
| V5 | Active speaker disconnects | Token passes to the next speaker at timer expiry |
| V6 | Voice connects during the night | **Impossible** — voice is torn down or hard-muted for the entire night phase |
| V7 | Echo / feedback (two players in one room) | Warn in the lobby: «لو قاعدين في نفس الأوضة، استخدموا سماعات» |
| V8 | Bandwidth collapses | Audio degrades; game state is unaffected — they are separate channels |
| V9 | Player joins a match already in progress | Not permitted mid-match. Rejoin only |

---

# 8. Zero-leakage regression (offline)

Re-run **after every change**, no exceptions. From `05-zero-leakage-spec.md`.

| # | Test | Pass criterion |
|---|---|---|
| L1 | Golden: all four roles, night action screen | Structurally identical trees and dimensions |
| L2 | Luminance across night screens | Within ±2%, measured after textures |
| L3 | Step count per role | Exactly 2 for every role |
| L4 | Tap count per role | Identical |
| L5 | Minimum dwell before Confirm | 8s for every role |
| L6 | Audio/haptic events during a private turn | **Zero** |
| L7 | Whisper card shown on every turn | Including the empty state |
| L8 | Card letterbox bars | Within 12 levels of each painting's outer edge |
| L9 | Route transition durations per role | Identical to the millisecond |
| L10 | Resume after kill during a private turn | Lands on the pass screen |

---

# 9. Fuzz harness — the highest-value test in the suite

```dart
void main() {
  test('10k random matches maintain all invariants', () {
    for (var seed = 0; seed < 10000; seed++) {
      final rng = Random(seed);
      final n = 5 + rng.nextInt(11);                 // 5–15 players
      var state = GameEngine.newMatch(
        players: _names(n),
        config: _randomValidConfig(n, rng),
        seed: seed,
      );

      var guard = 0;
      while (state.outcome == MatchOutcome.inProgress) {
        state = GameEngine.applyRandomLegalAction(state, rng);
        assertInvariants(state);
        if (++guard > 500) {
          fail('Match $seed did not terminate — infinite loop');   // catches stalls
        }
      }

      // Every match must reach a definite conclusion
      expect(state.outcome, isNot(MatchOutcome.inProgress));
      // And the information engine must never have thrown
      expect(state.errors, isEmpty);
    }
  });
}
```

**The `guard > 500` check is the single most valuable assertion in the codebase.** It catches every class of stall: infinite revote loops, phases with no exit, doctor-save cycles, and win conditions that never trigger.

Run it in CI on every commit. It takes seconds and it is the difference between "works in my testing" and "works".

---

# 10. Release gate

Nothing ships until every box is ticked.

**Engine**
- [ ] Fuzz harness: 10,000 matches, zero invariant violations, zero non-termination
- [ ] `evaluateOutcome` property test passes over 100,000 pairs
- [ ] Trace and Confrontation generators: every eligibility branch covered
- [ ] Golden vectors: Dart and TypeScript implementations produce identical output

**Offline**
- [ ] All L1–L10 leakage tests pass
- [ ] Kill and resume at every phase boundary → correct recovery every time
- [ ] Full match played end-to-end on the emulator with screenshots reviewed

**Online**
- [ ] `get_advisors(type: "security")` returns clean
- [ ] Automated attempt to read another player's role **fails**
- [ ] Automated attempt to vote as another player **fails**
- [ ] Host migration verified by force-quitting the host mid-night
- [ ] Full match with one player deliberately disconnecting at each phase
- [ ] Full match with voice entirely disabled → **completes normally**
- [ ] Airplane-mode mid-match → reconnect → resync correct

**Both**
- [ ] Same match seed produces the same traces and confrontations in both modes
- [ ] `flutter build apk --release` succeeds
- [ ] Zero analyzer warnings
