# Mafia Master — UI/UX Design Asset Package

> A premium board-game companion that fully manages a Mafia match — no human moderator, no internet, zero information leakage.
>
> **Audience:** these docs are written to be consumed by Claude Code (implementation) and Claude (design). Treat them as the single source of truth for UI/UX decisions.

## Package Contents

| File | Content |
|---|---|
| [01-design-system.md](01-design-system.md) | Colors, typography, spacing, component library, motion, audio direction, and Flutter/Material 3 binding |
| [02-user-flows.md](02-user-flows.md) | 9 Mermaid flow diagrams: match lifecycle, setup, role distribution, night phase, discussion, voting, win check, analytics, edge cases |
| [03-screens-setup-night.md](03-screens-setup-night.md) | Screen specs S-01 → S-10 with wireframes: home, players, roles, pass screen, role reveal, night action, morning |
| [04-screens-day-postgame.md](04-screens-day-postgame.md) | Screen specs S-11 → S-17: discussion rounds, voting, reveal, result, post-game analytics, history, dialogs |
| [05-zero-leakage-spec.md](05-zero-leakage-spec.md) | The BINDING document: threat model, ten rules, per-channel solutions, acceptance tests, trade-off log |

## Key Design Decisions (summary)

1. **Night passes in seating order for everyone** — no role call-outs; every player uses the phone every night with the same pattern.
2. **Every role = exactly two steps** at night (selection + second step) — structure, timing, and tap count are identical.
3. **Mafia vote ties resolve automatically** — any extra passing round would leak the Mafia count.
4. **The Detective's result vanishes forever** — the phone never holds extractable evidence.
5. **Citizen action = recording a suspicion + reason** — feeds post-game analytics and honors "every tap has value."
6. **Voting is secret via pass-the-phone** — who-voted-for-whom is revealed only in post-game analytics.

## Implementation Order (suggested)

1. Design tokens + component library (from 01)
2. Game engine state machine (from 02, flows 1/4/6/7)
3. Setup + role distribution screens (S-01 → S-07)
4. Night phase with leakage guards (S-08 → S-10 + doc 05)
5. Day phase (S-11 → S-13)
6. Result + analytics (S-14 → S-16)
7. Acceptance tests T1–T7 (from 05)

## Next Step

This package is ready to be turned into: high-fidelity mockups (design phase) and Flutter widgets driven by the design tokens in doc 01.
