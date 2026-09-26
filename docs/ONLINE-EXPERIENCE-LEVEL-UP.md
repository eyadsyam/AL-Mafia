# Online experience — core-game priority

Owner direction: the online match is the product. Prioritize enjoyable, clear,
reliable play and a recognizable identity ahead of expanding monetization.
No claim of retention, stability on real devices, or fun follows from unit tests.
The final human multiplayer/voice match remains owner-owned.

## 89b — Discovery and waiting (implemented locally)

- Public rooms appear above decorative artwork when populated.
- Raised charcoal room cards, gold seat-occupancy indicators, explicit voice
  labels, and direction-aware navigation. Counts reflect server data only.
- Optional “need 1–2 players” filter; refresh updates its results without joining
  anyone. Ready rooms remain in All; filter explicitly describes its scope.
- Automatic-refresh explanation; existing stale/error/backoff behavior preserved.
- Lobby explains missing players, invitation purpose, and host-start ownership.
  Enough players does not imply automatic start or individual ready confirmations.

## Next gates, in order

1. Match comprehension: inspect every public phase's single primary action,
   timer, waiting reason, current speaker and recovery message; support voice
   failure without changing the engine. Private screens keep Doc 05 parity.
2. Rhythm and identity: public-only cohesive transitions/audio, reduced-motion
   support, clear voting feedback; no extra blocking scenes or role-derived cues.
3. Satisfying finish: trustworthy result narrative based only on eligible facts,
   understandable rewards and rejoining/rematch with the same group; no fabricated
   highlights, persuasion scoring, or private-information history.
4. Reliability gate: exercise reconnect, host departure, interrupted actions,
   concurrent room joins and backend deployment compatibility. Run outstanding SQL.
5. Owner playtest: ask whether players understood each step, where they waited,
   and whether they chose another match; record observations rather than invented
   retention metrics. Then build signed candidates and update release handoff.

Stage 89 catalog completion and stage 90 payments remain open, deliberately below
the core-experience work. No account changes/publication happened in 89b.
