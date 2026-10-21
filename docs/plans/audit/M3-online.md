# M3 — Online lobby, continuity, timers, removals, voice, and result

Static audit of repository code and test definitions. `live` identifies a real-server test case in the suite; the suite was not run for this audit. `sql-sim` is the local, single-connection PGlite harness. A cited test establishes only the behavior named in its case. Rule references are to `docs/specs/17-roles-and-tools.md` (especially §12) and `docs/specs/10-online-architecture.md`; privacy also follows `docs/specs/05-zero-leakage-spec.md`.

## Lobby

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M3-1 | Create room seats one host, including concurrent create requests | §2.1; server owns roster (I2) | `supabase/migrations/20260928001100_safety_v11.sql:248` | `supabase/tests/kick_timing_match.py:46` — two create requests | live | OK |
| M3-2 | Join by code respects capacity and unique seat | §2.1; I2 | `supabase/migrations/20260928001100_safety_v11.sql:277` | `supabase/tests/roster_match.py:115` — sixth join hits capacity | live | OK |
| M3-3 | Invite link opens the code route | §2.1; I5 | `lib/ui/screens/online/lobby_screen.dart:325` | `test/online/room_invite_test.dart:26` — shared link | unit | OK |
| M3-4 | A second room join moves the same account's seat | §2.1; I2 | `supabase/migrations/20260928001100_safety_v11.sql:277` | `supabase/tests/concurrency_match.py:261` — joining elsewhere moves the seat | live | OK |
| M3-5 | Lobby departure deletes the seat and re-packs; last player closes room | §2.1; 10 §8.1 | `supabase/migrations/20260914001100_lobby_departures.sql:30` | `supabase/tests/concurrency_match.py:267` — emptied lobby is gone | live | OK |
| M3-6 | Ready applies to the shown roster revision and refuses stale or disconnected seats | §2.1; I2 | `supabase/migrations/20260928001600_lobby_ready.sql:100` | `supabase/tests/online_life_gaps.sql`: M3-6 stale and disconnected ready | sql-sim | OK |
| M3-7 | Host settings are validated, ownership checked, and locked after deal | §2.1; I2 | `supabase/functions/room_settings/index.ts:46` | `supabase/tests/roster_match.py:103` — guest refused, settings locked after deal | live | OK |
| M3-8 | Lobby kick bars rejoin and frees capacity; repeat kick is harmless | §2.1; I2/I9 | `supabase/migrations/20261009000300_silencer_is_mafia_team.sql:13` | `supabase/tests/kick_flow_match.py:49` — lobby kick and replacement | live | OK |
| M3-9 | Start with fewer than five or an unready roster is refused | §2.1; 10 §8; I2 | `supabase/functions/start_match/index.ts:56` | `supabase/tests/live_local_m3.test.mjs: M3-9: start refuses four seats and an unready five-seat roster` | edge-local | OK |
| M3-10 | Five-player table starts with legal roles; sold roles require their minimum | §2.1, §2.4, RL12 | `supabase/functions/start_match/index.ts:84` | `supabase/tests/live_local_m3.test.mjs: M3-10: five seats deal legal roles and refuse Elder or Sniper below their minimum` | edge-local | OK |
| M3-11 | Four-player online match | §2.1 minimum is five | `supabase/functions/start_match/index.ts:56` | — | none | N/A — below the rule-book minimum |
| M3-12 | Twenty-player online table | §2.1 online capacity tops out at fifteen | `supabase/functions/_shared/room_configuration.ts:30` | — | none | N/A — offline-only size |

## Host

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M3-13 | Host leaves a populated lobby; lowest seated member inherits | 10 §8.1; I4 | `supabase/migrations/20260914001100_lobby_departures.sql:42` | `supabase/tests/online_life_gaps.sql`: M3-13 lobby host departure | sql-sim | OK |
| M3-14 | Host leaves mid-match; seat remains and lowest connected player takes over | 10 §8.1; I4 | `supabase/migrations/20260928000900_unpublished_presence.sql:109` | `supabase/tests/concurrency_match.py:205` — host leaves, heir plays | live | OK |
| M3-15 | Host silently disconnects; claimant waits thirty seconds and races safely | 10 §8.1; I4/I9 | `supabase/migrations/20260928000900_unpublished_presence.sql:152` | `supabase/tests/live_local_m3.test.mjs: M3-15: host claim waits for stale presence and gives the lowest connected seat one host` | edge-local | OK |
| M3-16 | Host handover is announced without a role tell | 05; 10 §8.1; I1 | `lib/ui/screens/online/lobby_screen.dart:39` | `test/online/host_handover_test.dart:46` — hand-off in each phase | widget | OK |

## Connection

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M3-17 | Reconnect in lobby and night returns same seat and server snapshot | 10 §8.4; I5/I9 | `lib/transport/online_transport.dart:625` | `supabase/tests/recovery_match.py:40` — lobby refresh; `:61` — mid-match refresh | live | OK |
| M3-18 | Reconnect in deal restores own unacknowledged card only | 05; 10 §8.4; I1/I9 | `lib/transport/online_transport.dart:1275` | `test/online/process_death_resume_test.dart:22` — unacknowledged card returns | unit | OK |
| M3-19 | Reconnect in morning, confrontation, discussion, vote, verdict, or result resyncs authoritative phase | 10 §8.4; I5/I9 | `lib/transport/online_transport.dart:591` | `test/online/online_client_rows_test.dart: group M3-19 (six phases reread after a reconnect)` | widget | OK |
| M3-20 | App killed during a night action recovers submitted vs unsent move | 10 §8.4; I9 | `lib/ui/screens/online/online_session.dart:339` | `test/online/process_death_resume_test.dart:54` — held move; `:71` — unsent move | unit | OK |
| M3-21 | App killed during vote or paid write resyncs receipt before retry | 10 §8.3–8.4; I3/I9 | `lib/transport/online_transport.dart:864` | `test/online/online_client_rows_test.dart: group M3-21 (paid use sent once, shelf reread after restart)` | widget | OK |
| M3-22 | Two active devices for one account — one tab can mark the shared seat left while the other is playing or delete its lobby seat | 10 §8.4; I4/I5/I9 | `supabase/functions/set_presence/index.ts:31`; `supabase/migrations/20260914001100_lobby_departures.sql:30` | — | none | ACCEPTED (design limit) — one account plays on one device at a time; a second device can displace the first |
| M3-23 | Network loss backs off, rereads, and drops an older read overtaken by a push | 10 §8.4; I9 | `lib/transport/online_transport.dart:612`; `:683` | `test/online/online_client_rows_test.dart: group M3-23 (doubling backoff; older read never overwrites a newer push)` | widget | FIXED 8963e08 — a roster push during a read marks the read stale and rereads |
| M3-24 | Night, vote, and accusation double taps do not add two effects | 10 §8.3; I9 | `supabase/functions/submit_vote/index.ts:89` | `supabase/tests/concurrency_match.py:123` — one night row; `:169` — one name; `:199` — simultaneous ballots | live | OK |
| M3-25 | Every write, including kick, strike, settings, ready, floor, reward and rematch, is safe to retry after lost acknowledgement | 10 §8.3; I3/I9 | `lib/transport/online_transport.dart:877` | `supabase/tests/online_retry_rows.sql: M3-25 ready, settings, kick, strike, rematch and receipt each sent twice` | sql-sim | OK — floor claims grant or refuse without a charge; paid floor tools are M1 |
| M3-26 | Late action response cannot advance or erase a newer phase | 10 §8.4; I9 | `lib/ui/screens/online/online_table_flow.dart:898` | `test/online/online_action_retry_test.dart:299` — late acknowledgement | widget | OK |
| M3-27 | Stranger and kicked seat cannot regain membership by reconnect | 10 §8.4; I2 | `supabase/functions/_shared/api.ts:241` | `supabase/tests/recovery_match.py:85` — removed player refused | live | OK |

## Timers

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M3-28 | Deal expires with unseen card and opens night without inventing acknowledgement | 10 §8.2; I4/I7 | `supabase/functions/open_phase/index.ts:83` | `supabase/tests/new_roles_tools_match.py:536` — no acknowledgements, timer cycle | live | OK |
| M3-29 | Night expiry defaults Mafia and Doctor to legal seeded targets, other roles to skip | 10 §8.2; RL3/RL4; I4/I5 | `supabase/functions/advance_phase/index.ts:81` | `supabase/tests/timer_expiry_match.py:9` — timer match | live | OK |
| M3-30 | Morning expiry continues to opening when the round is enabled; other branches untested | 10 §8.2; I4/I7 | `lib/transport/online_transport.dart:1233` | `supabase/tests/live_local_m3.test.mjs: M3-30: expired morning opens optional first-day opening or ordinary discussion; decided morning opens result` | edge-local | OK |
| M3-31 | Opening-seat expiry records no invented accusation, then moves to next seat | 10 §8.2; I4/I7 | `supabase/functions/advance_phase/index.ts:191` | `supabase/tests/timer_expiry_match.py:9` — timer match | live | OK |
| M3-32 | Confrontation expiry records silence and opens discussion | 10 §8.2; I4/I7 | `supabase/functions/advance_phase/index.ts:185` | `supabase/tests/confront_expiry_match.py:1` — confrontation expiry | live | OK |
| M3-33 | Discussion expiry opens ballot in free and by-turns rooms | 10 §8.2; I4 | `supabase/functions/advance_phase/index.ts:218` | `supabase/tests/live_local_m3.test.mjs: M3-33: expired discussion opens vote in free and by-turns rooms` | edge-local | OK |
| M3-34 | Vote expiry adds abstentions to each missing living seat, including revote round | 10 §8.2; RL9/RL13; I4/I5 | `supabase/functions/advance_phase/index.ts:124` | `supabase/tests/timer_expiry_match.py:9` — timer match | live | OK |
| M3-35 | Verdict expiry goes to result if won, next night otherwise | 10 §8.2; I4/I5 | `lib/transport/online_transport.dart:1243` | `supabase/tests/live_local_m3.test.mjs: M3-35: expired verdict opens a numbered night if undecided or result if won` | edge-local | OK |
| M3-36 | Two clients advancing the same phase, or resolving night/vote, publish one result | 10 §8.3; I5/I9 | `supabase/functions/open_phase/index.ts:182`; `supabase/functions/resolve_vote/index.ts:221` | `supabase/tests/concurrency_match.py:87` — one winner; `:227` — verdict once | live | OK |
| M3-37 | All clients offline at deadline — archive closes room after inactivity, with no invented winner; no server phase driver found | 10 §8.1–8.2; I4/I7 | `supabase/migrations/20260928000900_unpublished_presence.sql:123`; `lib/transport/online_transport.dart:836` | `supabase/tests/online_retry_rows.sql: M3-37 every seat connected but silent ten minutes` | sql-sim | OK |

## Removals

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M3-38 | Mid-match kick is neutral elimination; target cannot act or rejoin; in-flight whisper is void | §6; I1/I2/I7 | `supabase/migrations/20261009000300_silencer_is_mafia_team.sql:32` | `supabase/tests/kick_flow_match.py:152` — whisper void; `:158` — cannot vote | live | OK |
| M3-39 | Kick races a night resolution or vote; winner and death are consistent | §6; I5/I9 | `supabase/migrations/20261009000300_silencer_is_mafia_team.sql:34` | `supabase/tests/kick_flow_match.py:114` — kick/night race; `supabase/tests/kick_timing_match.py:138` — kicked ballot void | live | OK |
| M3-40 | Kick after a winner is already written but before result — can rewrite outcome and void rewards even though the kick did not decide the match | R5/RL16; I5/I8 | `supabase/migrations/20261009000300_silencer_is_mafia_team.sql:43`; `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:16` | `supabase/tests/decided_outcome_stands.sql` | sql-sim | FIXED 5164053 — a kick or strike after a decided outcome leaves it and the rewards alone |
| M3-41 | Strike absent seat after three silent minutes; live, host, dead, and repeat requests refused | 10 §8.1; I2 | `supabase/migrations/20261016000500_strike_voids_rewards.sql:19` | `supabase/tests/kick_flow_match.py:138` — live refused; `supabase/tests/strike_voids_rewards.sql:45` — repeat refused | live | OK |
| M3-42 | Deciding strike of last Mafia or parity voids match rewards | RL16; I8 | `supabase/migrations/20261016000500_strike_voids_rewards.sql:45` | `supabase/tests/strike_voids_rewards.sql:26` — parity; `:39` — last Mafia | sql-sim | OK |
| M3-43 | Strike after a winner is written but before result — may rewrite outcome and void rewards although strike did not decide it | RL16; I5/I8 | `supabase/migrations/20261016000500_strike_voids_rewards.sql:43` | `supabase/tests/decided_outcome_stands.sql` | sql-sim | FIXED 5164053 — a kick or strike after a decided outcome leaves it and the rewards alone |
| M3-44 | Last player leaves a running match; idle archive closes it without winner/reward | 10 §8.1; I4/I7/I8 | `supabase/migrations/20260928000900_unpublished_presence.sql:134` | `supabase/tests/online_life_gaps.sql`: M3-44 idle archive | sql-sim | OK |
| M3-45 | Removal after deal at a five-player table leaves four; tally uses living seats | §2.1, §6; I4/I5 | `supabase/migrations/20261009000300_silencer_is_mafia_team.sql:39` | `supabase/tests/kick_flow_match.py:119` — four living, no invented outcome | live | OK |

## Voice

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M3-46 | Voice fully unavailable; table and phase flow continue | 10 §1.2; I6 | `lib/platform/voice/voice_controller.dart:868` | `test/voice/voice_controller_test.dart:723` — throwing engine cannot fail a phase | unit | OK |
| M3-47 | Reveal/night/vote mute and tear down media; public phases restore it | 10 §6; 05; I1/I6 | `lib/platform/voice/voice_controller.dart:357` | `test/voice/voice_controller_test.dart:411` — private stretch dark; `:426` — returns | unit | OK |
| M3-48 | By-turns floor belongs to named or server-granted speaker; no double release into next turn | 10 §6; I2/I6 | `supabase/functions/claim_floor/index.ts:58`; `supabase/functions/release_floor/index.ts:22` | `supabase/tests/live_local_m3.test.mjs: M3-48: named floor owner alone claims; repeated release never clears the next speaker` | edge-local | OK |
| M3-49 | Free discussion keeps living microphones open; silenced seat stays muted in either mode | RL8; I6 | `supabase/functions/claim_floor/index.ts:34`; `lib/platform/voice/voice_controller.dart:810` | `supabase/tests/voice_policy.test.mjs:18` — free; `:24` — turns | unit | OK |
| M3-50 | Dead player never sends voice to living; dead witness may hear only permitted peers | R4; I6 | `lib/platform/voice/voice_controller.dart:817`; `:846` | `test/voice/voice_controller_test.dart:142` — living cannot hear dead; `:162` — dead sends only to dead | unit | OK |
| M3-51 | Kick/disconnect during voice climb closes or rebuilds media | 10 §6; I6 | `lib/platform/voice/voice_controller.dart:599` | `test/voice/voice_controller_test.dart:637` — kick mid-climb; `:608` — roster burst | unit | OK |

## Match end

| # | Case | Expected (rule book ref) | Code (file:line) | Test (file: test name) | Evidence | Verdict |
|---|---|---|---|---|---|---|
| M3-52 | Night/vote winner comes from living Mafia-team parity, and only won match opens result | §5–6; I5/I7 | `supabase/functions/open_phase/index.ts:113`; `supabase/functions/resolve_night/index.ts:201` | `supabase/tests/recovery_match.py:133` — town win then result | live | OK |
| M3-53 | Role standings publish at result, never while roles are still secret | 05; §5; I1 | `supabase/functions/open_phase/index.ts:120` | `supabase/tests/concurrency_match.py:239` — standings with result only | live | OK |
| M3-54 | Closed or abandoned room has no invented winner or reward | 10 §8.1; I7/I8 | `supabase/migrations/20260928000900_unpublished_presence.sql:134` | `supabase/tests/online_life_gaps.sql`: M3-54 abandoned room no outcome or reward | sql-sim | OK |
| M3-55 | Finished result persists on reconnect; local history and reward sync attempted | 10 §8.4; I8/I9 | `lib/ui/screens/online/online_session.dart:359` | `test/online/online_client_rows_test.dart: group M3-55 (result survives reconnect; history once; reward sync once)` | widget | OK |
| M3-56 | Reward receipt once for an eligible participant; deciding removal voids it | R5/RL16; I8/I9 | `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:110` | `supabase/tests/online_retry_rows.sql: M3-56 receipt asked twice is one receipt; a deciding removal voids` | sql-sim | OK |
| M3-57 | Rematch reuses settings, creates one new room on repeated request | §7; I5/I9 | `supabase/migrations/20260928000200_table_rematch.sql:12` | `supabase/tests/table_rematch.sql:31` — first and repeated rematch | sql-sim | OK |
| M3-58 | Analytics/result copy derives from committed outcome and record, including silenced or kicked seats | §5–7; I1/I7 | `lib/ui/screens/online/online_table_flow.dart:2000` | `test/online/online_client_rows_test.dart: group M3-58 (result copy from the committed outcome, silenced and kicked seats)` | widget | OK |

## Findings

SUSPECT M3-40 [I5,I8]: Removals — a kick while status remains playing can overwrite an already decided outcome and void rewards it did not decide — `supabase/migrations/20261009000300_silencer_is_mafia_team.sql:43`; `supabase/migrations/20261009002200_receipt_participation_and_kick.sql:16`
SUSPECT M3-43 [I5,I8]: Removals — a strike after a winner is written can overwrite outcome and void rewards it did not decide — `supabase/migrations/20261016000500_strike_voids_rewards.sql:43`
SUSPECT M3-22 [I4,I5,I9]: Connection — device-level away/left and lobby leave mutate the account's one shared seat, so a second active tab can be displaced — `supabase/functions/set_presence/index.ts:31`; `supabase/migrations/20260914001100_lobby_departures.sql:30`
OK M3-6, M3-13, M3-44, M3-54: `supabase/tests/online_life_gaps.sql` proves readiness refusals, lobby host inheritance, and idle archive without an outcome or reward in SQL simulation.

## Resolution (2026-10-17, orchestrator)

| SUSPECT | Outcome |
|---|---|
| M3-40, M3-43 | FIXED 5164053 — a kick or strike after a decided outcome leaves it and the rewards alone (supabase/tests/decided_outcome_stands.sql) |
| M3-22 | ACCEPTED (design limit) — one account plays on one device at a time; a second device can displace the first |

### Needs live

- M3-9: Start refusal for fewer than five seats and an unready roster runs through inline `start_match` Edge Function logic.
- M3-10: Five-seat role validation and sold-role minimum run through inline `start_match` Edge Function logic.
- M3-15: Safe migration between simultaneous host claimants requires concurrent connections.
- M3-19: Phase-specific reconnect requires a running server and client session.
- M3-21: Paid-write receipt reconciliation after app death requires a running server and restarted client.
- M3-23: Push overtaking a pending read requires a live transport interleaving.
- M3-25: Lost acknowledgements across all named writes require live transport and server effects.
- M3-30: Morning expiry branch behavior requires the live phase driver.
- M3-33: Discussion expiry in both modes runs through inline `advance_phase` Edge Function logic.
- M3-35: Verdict expiry branch behavior requires the live phase driver.
- M3-37: All clients offline at deadline requires live scheduling and an end-to-end room lifecycle.
- M3-48: Floor release racing a new floor requires concurrent requests.
- M3-55: Reconnect, local history, and reward sync require the running client and server.
- M3-56: Receipt issuance and voiding under a live reward race require concurrent requests.
- M3-58: Analytics and result copy are assembled inline in the online widget and require a running client.
