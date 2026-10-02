# 1.1 launch recut — owner answers of 2026-09-28 (Claude proposes, Sol critiques)

Historical record. The authoritative result is folded into `BIG-UPDATE-1.1-FINAL.md` (§0, §2, F16, F21a, P7, §6, §11, §12).

Claude's proposals R1–R6: the date rule driven by Play's 12-tester/14-day lock, the reordered 129 h list, testers as the listener panel, Witness v2 (whisper contents for the dead), the marketing consequence, and the kill list (viewer codes deleted).

## Sol's verdict

## 1. R1–R6 verdicts

| Item | Verdict | Correction |
|---|---|---|
| **R1 Date rule** | **MODIFY** | Target Oct 29; Nov 5 fallback. Define L as the first Thursday ≥7 days after production access **and after every P0 gate passes**. “Never move the date” applies only to removable features. Online integrity, Doc 05, safety, RC stability or store-access delays move L. Closed-test builds may evolve during the 14-day clock, but tester continuity must not be interrupted. |
| **R2 Recut** | **MODIFY** | The structure is right, but 16 h for narration, 4 h for Witness v2 and only +1 h for two native integrations are optimistic. Use 18 h, 6 h and 13 h respectively. Total remains 129 h by preserving the 5-hour slack. |
| **R3 Testers as listeners** | **MODIFY** | Closed testers are an excellent integration panel but not automatically blind or representative. At least four listeners should be weak ties who were not involved in development, and the form must be anonymous. Do not identify the voice as the owner’s before rating. Keep age, non-Cairo, noisy-room and tenth-match requirements. |
| **R4 Witness v2** | **MODIFY** | Doc 05 permits it only because the owner explicitly grants private knowledge to dead players, while living callers are refused. Disclosure must appear both in the lobby rule summary and composer; recipients also deserve notice. Do not exclude reported whispers—the report needs preserved evidence. A viewer-blocked sender’s body should be masked for that viewer while retained server-side for moderation. Dead players must be able to report a witnessed whisper. |
| **R5 Marketing consequence** | **KEEP, conditional** | Social audience-building starts now; pre-registration becomes the final spike. Do not publish Kratos-led content until provenance, commercial-use authorization and voice acceptance are complete. Creator entitlement replaces viewer codes everywhere. |
| **R6 Kill list** | **KEEP** | Viewer codes are deleted, not parked. Rematch vote, streak-save, extra clue and milestone automation remain outside L. Existing rematch remains. |

## 2. Final launch list

| # | Launch row | Hours | Changed-row gate |
|---:|---|---:|---|
| 1 | Online-core blockers + Doc 05 hardening | 8 | Online/leakage suites ×3; chaos and publication tests |
| 2 | Safety v11 + owner queue | 8 | Every block/report surface and owner review drill |
| 3 | Spoken Kratos narrator | 18 | Provenance and commercial-use record; private-phase silence; ≥9/12 natural and not-cringe; noisy-room/tenth-match gates |
| 4 | Ready-up, reconnect and host continuity | 6 | Two-client races, process death and phase resume |
| 5 | Operator controls, metrics, warm-up, low-end performance, Install Referrer and review integration | 13 | Cold-start regression <150 ms p95; raw referrer discarded; review remote-killable; low-end/web budgets |
| 6 | Economy v3, invite hardening, launch catalogue and creator entitlement | 10 | Creator receives no automatic ads; rewarded remains opt-in; revoke and ordinary-user regression tests |
| 7 | Daily Case, launch case and `/case/today` | 9 | Generator uniqueness, attempts/reveal and web route |
| 8 | Signature reveal, sonic mark and Partner surfaces | 7 | Result-only reveal; private/live import closure |
| 9 | Casebook, Season Zero, titles and core Partner | 10 | Inactive season, reward math and exact-once claims |
| 10 | Big-table speed, Family mode and tabletop layout | 9 | 10/15-player timings; immutable family setting; 2 m readability |
| 11 | Witness v2 whisper contents | 6 | Dead-only authorization, room isolation, masking/report tests |
| 12 | Thursday, result inventory and launch events | 6 | Cairo boundaries and public-result-only placement |
| 13 | Launch art + non-voice sound | 5 | Crop/size/reduced-motion and private-silence review |
| 14 | Listing, captures and trailer | 5 | Every depicted feature exists in RC |
| 15 | RC + device matrix | 9 | Full suites, Android classes, Safari, offline and soak |
|  | **Total** | **129 h** | |

If Oct 19 arrives with incomplete non-P0 work, drop **Family mode first**, then the **Partner lobby embellishment** while retaining the result signature. Never cut online integrity, Doc 05, safety, low-end stability or RC time.

## 3. Witness v2: Doc 05 and safety verdict

**Verdict:** permissible only as an explicit owner-authorized dead-player entitlement. It increases external-collusion and harassment exposure but does not leak information to a living client if implemented correctly.

Exact server rule:

```text
Return whisper content only when:
authenticated caller is a current member of the requested room
AND authoritative room_players.alive = false
AND witness mode is enabled for that immutable room configuration.
```

The RPC must read through server authority; clients cannot submit `dead=true`. Whispers must never enter the ordinary snapshot, Realtime publication, error bodies, analytics or client logs.

Required tests:

- Living member receives `403 WITNESS_ONLY`, with no roles, actions or `whispers` field.
- Non-member and member from another room receive the same non-revealing refusal.
- Dead member receives every committed whisper up to the authoritative read point, including whispers between other players.
- Uncommitted/failed whispers never appear.
- Direct table reads remain denied; only `witness_view` may expose content.
- F21 OFF returns public state only: no roles, night actions, whisper metadata or text.
- A blocked sender’s body is masked for that dead viewer; raw text does not reach the device.
- Reported content remains preserved for owner review and is not removed from evidence retention.
- Dead viewer can report a whisper by immutable whisper ID without resubmitting its text.
- Unicode, maximum length and hostile markup render as inert text.
- No whisper content appears in logs, error bodies, telemetry or cache after sign-out.
- Death/read races use authoritative committed membership state; no client becomes eligible merely from a stale local snapshot.

## 4. Owner critical-path actions

1. Opt in at least 12 testers by Sep 30 and monitor uninterrupted participation for the full 14 days.
2. Confirm whether Kratos is designed or cloned, secure the required commercial-use authorization, and approve the exact production-use record.
3. Assemble the diverse anonymous listening panel, including at least four uninvolved listeners and one non-Cairo governorate.
4. Submit the production-access application immediately when eligible and answer any review request promptly.
5. Give the final publish authorization only after console access, RC gates and launch rehearsal pass; choose Oct 29 or Nov 5 accordingly.

## Sign-off

**LAUNCH RECUT CLOSED.**

Voice provenance/licensing and tester continuity are execution blockers, not unresolved design questions.
