# Round 9b — Sol attacks the online-core audit and the Egypt economics

Claude review (2026-09-28): every finding accepted except **M1**, which is not a
defect. Online, the dead seeing every role is the owner decision of 2026-09-23
(doc 12 §4.1 note); the objection is recorded as an owner-accepted risk in the
final spec. The economics corrections replace the bands in
`BIG-UPDATE-EGYPT-ECONOMICS.md`.

## 1. Audit verdict

Claude’s audit is directionally strong, but it missed one P0 leakage violation and several P1 reliability defects. The concurrency suspicions are mostly false alarms.

### Severity corrections

- **D1:** Keep P1, but the stated OAuth callback sequence is not proven locally. What is proven is that `onAuthStateChange` has no error handling; Supabase explicitly requires an `onError` handler because stream errors can otherwise become unhandled exceptions. [Supabase documentation](https://supabase.com/docs/reference/dart/auth-onauthstatechange)
- **D2:** P1 confirmed.
- **D3:** P1 confirmed, though not online-core.
- **D4:** Downgrade P1 → **P3**. Displaying level 0 violates the product spec but cannot corrupt progress or a match.
- **D5:** P2 is right.
- **D6:** Not a present defect. It is a series acceptance requirement.
- **D7:** Upgrade P2 → **P1**, and the audit undercounted it. Result processing makes five calls per player: session `sync` at `online_session.dart:333`, then another `sync`, `contracts_get`, `rank_get`, and `missionHub` from `council_hub.dart:1340–1383`. A ten-player result can burst roughly 50 edge calls.
- **D8:** Delete from the defect register. An unconnected draft is unfinished work, not a runtime defect.
- **D9:** P3 is correct.

### Missed confirmed defects

| ID | Sev | Proof and blast radius | Fix |
|---|---|---|---|
| **M1** | **P0** | `05-zero-leakage-spec.md:19,57–59` says a dead player seeing extra information is a leakage channel and dead players are outside private flows. Yet `witness_view/index.ts:40–72` returns every living role and current night action to eliminated players. External messaging makes the claimed ghost wall irrelevant. Every online match with an eliminated player is exposed. | Witness receives public snapshot, ghost chat and private prediction only. Roles/actions unlock at public result. Replace the test that codifies the override. |
| **M2** | **P1** | `supabase_backend.dart:772–774` catches `FunctionsFetchException` and rethrows it raw despite `_guarded` promising `BackendUnreachable`. `OnlineTransport._send` and `OnlineSession.start` do not consistently catch that SDK type. Ordinary network loss can escape the state machine as an uncaught exception. | Convert it to `BackendUnreachable`; test `_enter`, start, action, heartbeat and resume using a thrown `FunctionsFetchException`. |
| **M3** | **P1** | Heartbeat every 10 seconds (`design_tokens.dart:972`) updates published `room_players` (`heartbeat/index.ts:26–39`); every client subscribes to those changes (`supabase_backend.dart:458–474`). A ten-player 20-minute match produces about 1,200 writes and roughly 12,000 delivered roster events. | Put beats in an unpublished presence table. Publish only semantic transitions: connected/away/left. |
| **M4** | **P1** | `/join/:code` always opens entry (`router.dart:353`), while `_enter` destroys the current transport before admission succeeds (`online_session.dart:277–285`). A failed invite join interrupts the live match; a successful one abandons it without explicit confirmation. | If already seated, offer “return to table” or explicit “leave and join.” Preserve the old transport until the decision/admission boundary. |
| **M5** | **P1** | `_send` creates a new action ID for every invocation (`online_transport.dart:820–835`). If a bullet action commits but its response is lost, retry sees `alreadySpent` and returns `RATE_LIMITED` (`submit_night_action/index.ts:100–127`). The Detective can permanently lose the private answer. | Persist one request ID across retries and store/replay the acknowledgement for that ID. |
| **M6** | **P2** | Whisper has the same lost-response ambiguity. `sendWhisper` is “assured” (`online_transport.dart:1056–1072`), but `commit_whisper` has no request receipt; retry becomes `RATE_LIMITED`. | Add `request_id`, unique sender/day/request, and replay the original whisper ID. |
| **M7** | **P2** | At 10,000 synthetic rooms, browse recomputed the same count four times per lobby and quick match twice. Measured locally: **113.174 ms / 93,637 buffers** and **47.931 ms / 38,459 buffers** respectively. | Calculate population once using a materialized/lateral aggregate; add a partial active-seat index. Longer-term, transactionally maintain lobby population. |

## 2. S1–S4 resolved

- **S1—safe.** `join_room_atomic` takes a per-user advisory lock, then locks the room row before counting and inserting (`20260924000200_system_waiting_rooms.sql:109–143`). Different users serialize on the room; unique `(room_id, seat)` is the backstop.
- **S2—safe, with a scaling concern.** Quick match holds global `quick_match:classic`, locks its candidate, then invokes the atomic join (`20260921001100_quick_match_random.sql:10–25`). The second caller observes the filled room and chooses another. It does not receive the final-seat race error. The global lock will eventually limit throughput.
- **S3—safe.** Start and leave both lock `rooms`. If leave wins, ownership/roster changes before the deal’s host/status predicate. If start wins, leave becomes a mid-match departure and the trigger handles handoff (`deal_preserves_settings.sql:29–40`; `lobby_departures.sql:23–45`).
- **S4—not a current defect, but a real regression gap.** No `lobby_ready` column exists. The final publication uses an explicit safe list (`20260924000300_cosmetic_catalog.sql:206–209`), but no test asserts its exact final columns. Add an allowlist test rejecting `role`, `match_seed`, private action fields, and any unreviewed future column.

PGlite is single-connection and Docker was unavailable, so true two-session execution was not possible. The conclusions above follow from exact lock order, predicate rechecks and constraints—not timing assumptions.

## 3. Mutation/race matrix

| Mutation | Authority / serialization | Idempotency and concurrent outcome |
|---|---|---|
| Create/join/rejoin | Edge identity; per-user advisory + room row | One seat per user; capacity serialized |
| Quick match | Global pool advisory + candidate room lock | Correct but globally serialized |
| Leave/kick/handoff | Room row; kick rechecks host | Start/leave/kick cannot mutate roster across the deal |
| Settings/start | Room row; host/status CAS | First start wins; retries refuse |
| Heartbeat/ageing | Row updates | Last valid write wins safely, but publication fan-out is excessive |
| Reveal acknowledgement | Own authenticated seat | Monotonic/idempotent |
| Night action | PK `(room,night,actor)` + phase trigger | Normal replay safe; bullet acknowledgement is not |
| Night resolution | Room/state locks + move fingerprint CAS | One resolution; changed input retries |
| Opening accusation | State lock + current-seat CAS | First accepted answer advances floor |
| Whisper | Room/state lock + sender/day unique | Duplicate prevented; response replay broken |
| Ready/vote | State lock; vote PK + phase trigger | Concurrent readiness merges; last ballot write wins |
| Vote resolution/advance | Room/state CAS | One phase transition |
| Reconnect/process resume | Same-user atomic rejoin | Seat preserved; raw-network classification and deep-link switching are defective |

## 4. Query plans and indexes

Synthetic dataset: 10,000 rooms, 50,000 seats.

- Browse: index scan on `rooms_public_browse`, but four correlated population subplans per 3,334 lobbies; **113.174 ms**.
- Quick match: same count twice over 2,857 candidates; **47.931 ms**.
- Heartbeat: primary-key index, **0.251 ms**.
- Resume room/state: primary keys, **0.017 ms each**.
- Resume roster: indexed bitmap + five-row sort, **0.172 ms**.
- Own actions/votes and whispers: **0.013–0.047 ms**.

Recommended:

```sql
create index room_players_active_room_seat
on room_players(room_id, seat) where not kicked;
```

Rewrite browse and quick match so the active count is computed once. A classic-public-lobby partial index helps filtering, but cannot solve “fullest room” ordering without a maintained population column. Resume needs no new index.

## 5. Observability and error-shape design

Missing before launch:

- A generated request ID in every edge response/header.
- Structured metrics: function, result code, latency bucket, CAS retry count, reconnect outcome, room-fill time, abandoned-room count and Realtime resync reason.
- Alerts for P95 join/start/action latency, failure rate, phase CAS exhaustion, reconnect failure and no-outcome finishes.
- Logs must never contain names, room codes, roles, targets, notes, whisper text, tokens or raw request bodies. Use hashed room correlation only.
- Client counters for deep-link interruption, resume success, subscription drops and voice setup degradation.

The error test should invoke every refusal path through an exported handler harness and assert the exact schema `{error, message}`. It must reject unexpected keys and scan recursively for `role`, `team`, `target`, `seed`, `action`, `note`, UUIDs and player names. Repeat each refusal with all four caller roles and require identical status/body where role must be undisclosed. Uncaught database errors must become generic 500 plus request ID, never database text.

## 6. Ordered blockers

1. **P0 Witness leakage** — Sol 45m; Claude 60m.
2. **Network exception normalization** — Claude 25m.
3. **Daily Case request receipt** — Sol 45m.
4. **Bullet request/ack replay** — Sol 60m; Claude 35m.
5. **Active-session deep-link guard** — Claude 45m.
6. **Presence/Reatime separation** — Sol 75m; Claude 30m.
7. **Single result-summary action** — Sol 60m; Claude 40m.
8. **Season activation** — Sol 30m. Level display — Claude 5m.
9. **Error-shape/security harness and publication allowlist** — Sol 70m.
10. **Whisper receipt** — Sol 45m; Claude 20m.
11. **Browse/quick-match rewrite** — Sol 45m.
12. **Minimum observability** — Sol 75m; Claude 45m.

The first nine are 1.1 blockers. Whisper replay and query optimization could follow immediately after if schedule forces a boundary.

Verification remained green: targeted Flutter **434/434**, SQL **47/47**, edge **13/13**. No tracked files were changed.

## 7. Egypt economics attack

The arithmetic in the scratch model reproduces the published totals, but the behavioral model is substantially weaker than the arithmetic.

### What is defensible

Claude’s eCPM ranges are not obviously inflated. Appodeal’s 2025 Android Middle East averages are approximately **$2.4 rewarded, $1.7 interstitial and $0.10 banner**. Claude’s middle assumptions—$1.5/$0.8/$0.08—are conservative relative to that regional dataset. However, it is MENA-wide, not Egypt-specific; no credible public source I found provides a current audited Egypt-only breakdown. [Appodeal 2025 report](https://appodeal.com/wp-content/uploads/2025/03/Appodeal-The-Latest-eCPM-Report-2025.pdf)

Use planning bands of:

- Rewarded: **$0.8 / $1.5 / $2.4**
- Automatic: **$0.35 / $0.75 / $1.3**
- Banner: **$0.03 / $0.08 / $0.10**
- Realized fill: **50% / 70% / 85%**, not 70% / 85% / 95% for an unproven Egypt-only launch.

### Fundamental model errors

1. **“Players/day” must become active devices/day.** Six cousins around one pass-and-play phone produce one ad-bearing device, not six. If 60% of human participation is in six-person local tables, 1,000 humans correspond to only about 500 active devices before online users are added. The current 3,385 EGP ads total can therefore be roughly twice reality.

2. **Online usage cannot be derived from DAU alone.** Fill depends on peak concurrency, session length, invitation density and time concentration. Fifty friends concentrated on Thursday may outperform 1,000 users scattered across a day.

3. **The MAU ratio is presented as fact without evidence.** MAU = 2.5–3.5×DAU implies unusually high 29–40% stickiness. MENA D30 retention is reported around 4%; game-wide benchmark data is also much weaker than this model implies. [Adjust retention benchmarks](https://www.adjust.com/blog/what-makes-a-good-retention-rate/), [GameAnalytics benchmark summary](https://gamedevreports.substack.com/p/gameanalytics-benchmarks-in-mobile)

4. **Tiny-population IAP is lumpy.** At 10 DAU, the model’s expected 4 EGP/month hides that a 30-MAU cohort at 0.3% conversion has roughly a **91% chance of zero buyers**. Show expected value and median outcome separately.

5. **Ad cohorts overlap incorrectly.** Web users, Quiet Pass owners, consent-limited users, weak-network users and pass-and-play guests cannot all receive the same impression assumptions. IAP buyers may also generate fewer ads.

6. **Ramadan ×1.5–2 is unsupported.** Keep it as an upside sensitivity, never in the operating forecast.

7. **Break-even at 600–700 active devices is infrastructure-only, not business break-even.** It omits voice relay/egress, monitoring, transactional email, moderation time, creative production, support, localization, accounting, devices and acquisition. Current official baselines do support roughly $25/month for Supabase Pro and $20/month for Vercel Pro; Vercel also describes Hobby as personal/non-commercial. [Supabase pricing](https://supabase.com/pricing), [Vercel pricing](https://vercel.com/pricing), [Vercel Hobby terms](https://vercel.com/docs/plans/hobby)

### Implication

Keep Claude’s table only after renaming the unit to **active devices**, adding platform/local-table composition, and showing realized impressions rather than assumed opportunities. At 10–100 active devices, optimize retention, invites and reliable table completion—not ad density. Treat **ads 22 EGP + IAP 4 EGP at 10 DAU as an expected-value illustration**, with the honest likely IAP total being zero. The 600–700 figure must be labelled “minimum infrastructure coverage”; a responsible operating break-even is likely materially above 1,000 active devices until actual Egyptian cohorts replace every assumption.
