# Test plan: every way the game can go wrong (2026-11-19)

The owner's ask: check every edge case, online and offline, so we know the game
works. No test suite proves "zero bugs". What this plan does is close every path
we can reach with automated tests, show where each case is covered, and keep the
few things that need a real phone on a short device checklist.

Each row names the test that covers the case. **New** marks a test added by this
plan; **Gap** marks a case still open, with what closes it.

## 0. How the suite catches what nobody thought of

| Net | What it does | File |
|---|---|---|
| Engine fuzz | 10,000 random offline matches (5–15 seats, every role mix, bullets, ties, abstain); the four doc 11 invariants after every move; a stall guard | `test/engine/fuzz_harness_test.dart`, `test/support/fuzz_driver.dart` |
| Engine fuzz, sold roles | The same with Silencer, Elder, Sniper | `test/integration/bought_roles_fuzz_test.dart` |
| Fuzz coverage | Proves the fuzz reaches every phase, rule branch and role move | `test/engine/fuzz_coverage_test.dart` |
| **New: Elder night move in the fuzz** | The fuzz never chose «اكشف نفسي الصبح» (legal_moves had no such move), so the 1.7.0 night reveal was never fuzzed; it is now a legal move | `lib/engine/legal_moves.dart` |
| **New: online fuzz** | Whole random matches through the real server functions (every migration, PGlite): random members doing random things, legal or not; after every step no 5xx, a known phase, no living seat's role in the public state, the dead refused, the match reaches «result», the outcome agrees with who is alive | `supabase/tests/online_fuzz.test.mjs` |
| Online fuzz, results 2026-11-19 | 300 + 400 matches, every one finished with no 5xx, no leak, no stall; reached opening, confrontation, verdict, revotes, silence, Elder reveals, Sniper, whispers, 122 struck guests, 11 hosts leaving, 680 double resolves | `FUZZ_MATCHES=400 node --test supabase/tests/online_fuzz.test.mjs` |
| Golden vectors | The Dart engine and the server resolve the same nights and ballots the same way | `test/engine/golden_vectors_test.dart`, `night_vectors`, `vote_matrix`, `supabase/tests/run_golden_vectors_node.mjs` |
| Races on real Postgres | Double taps and two devices at once: charge once, own once, resolve once | `tool/real_pg/races.mjs` (needs the local docker stack) |

## 1. Setup and deal

| Case | Covered by |
|---|---|
| 4 seats refused, 5 to 15 accepted, role counts add up | `rule_matrix_test`, `live_local_m3` M3-9/M3-10, fuzz I4 |
| Elder below 6 seats, Sniper below 7, Silencer without a second Mafia refused | `live_local_m3` M3-10, `roles_offline_gaps_test`, `balance_guard_test` |
| Sold role without owning it | `store_roles_everywhere_test`, `store_gaps*.test.mjs` |
| Same name twice, bad name, restricted account | `add_players_test`, `safety_v11_test`, `match_queue.sql` |
| Lobby ready: unready seat blocks start, a seat that drops is not waited for | `lobby_ready_countdown_test`, `live_local_m3` M3-9 |
| Deal is private per seat (L1–L10) | `test/leakage/*`, `test/golden/*symmetry*`, `online_role_reveal_test` |

## 2. Night

| Case | Covered by |
|---|---|
| Mafia split votes, a tie, nobody voting | `night_matrix_test`, `night_vectors`, `resolver_test` |
| Doctor: same target twice refused, self-protect bullet once | `doctor_previous_target_test`, `doctor_self_protect_tile_test`, `night_rules.test.mjs` |
| Detective: one look a night, the answer stays private | `detective_result_ephemeral_test`, `night_isolation_test` |
| Silencer alone becomes the killer; silenced seat cannot vote | `new_roles_test`, `night_rules_2026_10_01_test`, `silence.test.mjs` |
| Sniper shot hits Mafia or town; once per match | `sniper_tools_quiet.test.mjs`, `roles_online_gaps.test.mjs` |
| Elder reveal at night: killed the same night reveals nothing; revealed once; undo before morning | `elder_night_reveal_test`, `elder_night_button_test`, `elder_night_reveal.sql`, fuzz (new) |
| **Elder chip after a reconnect** (review #10) | **New** `test/transport/own_elder_reveal_test.dart`; ships with the next update |
| Two resolutions at once kill once | `match_edges.test.mjs` |
| A seat struck mid-night: its move does not land, the night still ends | `struck_seat_phases.test.mjs` |
| Nobody acts: the clock ends the night | `auto_advance_test`, `phase_guards.test.mjs`, online fuzz |

## 3. Day, vote, end

| Case | Covered by |
|---|---|
| Opening round order, a dead or struck seat skipped | `opening_round_screen_test`, `struck_seat_phases.test.mjs` |
| Tie: revote narrows to the tied, second tie stands; «محدش يخرج» | `day_tie_revote_test`, `match_edges.test.mjs` |
| Abstain on and off; double tap counts once; dead vote refused | `abstain_vote_test`, `appeal_abstentions`, `match_edges.test.mjs`, online fuzz |
| Revealed Elder counts 3 | `vote_guard_test`, `vote_rules.test.mjs` |
| Town wins when the last Mafia goes; Mafia wins at parity; the last Mafia leaving | `win_check_test`, `win_condition_test`, `live_local_m3`, online fuzz |
| Rewards: once per match, none for a decided kick | `live_local_m3` M3-56 |

## 4. Offline only

| Case | Covered by |
|---|---|
| Wrong phone pass, the back button at night | `wrong_pass_test`, `night_back_lock_test` |
| App killed at every phase, resumed right | `crash_resume_test`, `resume_prompt_test` |
| Rotation never submits twice | `rotation_no_double_submit_test` |
| Saved groups, rematch, history | `saved_groups_test`, `group_rematch_test`, `history_test` |

## 5. Online only

| Case | Covered by |
|---|---|
| Host leaves: room closes for everybody; a guest silent 90 s is struck, the match goes on | `host_handover_test`, `live_local_m3` M3-15, `struck_seat_phases.test.mjs` |
| Reconnect and resync in every phase; process death | `online_session_recovery_test`, `process_death_resume_test`, `phase_resync_privacy_test`, `reconnect_stages_test` |
| Client clock wrong | `client_clock_skew_test` |
| Retries and refusals | `online_action_retry_test`, `retry_refusal_test`, `edge_refusal_test` |
| Voice fully broken: the match still ends | `voice_policy.test.mjs`, `test/voice/*` |
| Another player's role or vote can never be read or sent | `server_surface_test`, `request_envelope`, RLS in `supabase/tests/*.sql` |
| «استناني»: rounds, misses, expiry, two hours | `match_queue.sql`, `play_night.sql` |
| **Queue room host who never opens it** (review #3) | **New** `queue_absent_host.sql`; fixed live |
| Friends, crews, news, invites | `friends_*.sql`, `friends_test` |
| Force update follows Play | `force_update_on_release.sql`, `update_gate_test` |
| Old build (22) on the new server | `reveal_elder` kept for build 22; `update101_contracts.test.mjs` |

## 6. Store, coins, ads

| Case | Covered by |
|---|---|
| Buy twice, charge once; refund takes the item back | `tool/real_pg/races.mjs`, `payments_v2.sql`, `payments_v2.test.mjs`, `coin_payments.test.mjs` |
| Rewarded ad: reward once, stuck screen | `rewarded_retry_test`, `admob_ssv_verify.test.mjs` |
| Every bought item works in every mode | `store_roles_everywhere_test`, `store_truth_test` |

## 6b. Everything around the game

| Area | Cases | Covered by |
|---|---|---|
| First run | Terms first, consent, order of screens, permissions asked once, no dead end on a slow network | `first_run_*_test`, `onboarding_*_test`, `startup_permissions_test`, `warmup_gate_test` |
| Account | Guest, Google, switching accounts, a remembered account, delete account and what is forgotten | `account_*_test`, `google_switch_test`, `native_google_test`, `delete_account_test`, `forget_deleted_account_test`, `remembered_accounts_test`, `profile_per_account_test` |
| Home | Rooms list, return to a room, the nobody-waiting card, greeting, back button | `home_*_test`, `nobody_waiting_card_test`, `home_back_test` |
| Profile | Name check, record, titles, partner | `profile_*_test`, `titles_partner_test` |
| Friends | Add, privacy, invites, crews, news, suggestions | `friends_test`, `directory_settings_test`, `friends*.sql`, `friend_*.sql` |
| Coins and store | Buy, refuse, retry, refund, balance after a crash | `coin_*_test`, `store_*_test`, `tool_*_test`, `wallet_reconcile_test`, `payments_v2*` |
| Ads | Banner place, app-open rules, rewarded once, web ads | `ad_*_test`, `app_open_*_test`, `banner_*_test`, `rewarded_*_test`, `web_ads_test`, `ads_v3_policy_test` |
| Notifications | Token, invite push, game-night push, the off switch | `push_*_test`, `invites_push_test`, `invites_push.test.mjs`, `push_events.test.mjs` |
| Settings | Language, sound, reduced motion, how-to sheets | `settings_*_test`, `language_picker_test`, `audio_settings_preview_test`, `reduce_motion_test` |
| Force update | Below the minimum: the gate; Play not yet live: no gate | `update_gate_test`, `force_update_on_release.sql` |
| Web | Per device layout, iOS Safari, the live site matches the build, every page answers | `web_per_device_test`, `tool/verify_web_release.mjs` (run live 2026-11-19: all PASS) |
| Arabic and look | Every string translated, glyphs, Western digits, tokens only | `l10n_coverage_test`, `glyph_coverage_test`, `western_digits_test`, `token_discipline_test` |
| Accessibility | Labels, focus order, text scale | `accessibility_test`, `first_run_semantics_test` |
| Crashes | Reported, never silent | `crash_reporting_test` |

## 6c. How the code is held to quality

| Net | What it does |
|---|---|
| `flutter analyze lib test` | Zero warnings, every run |
| `engine_purity_test`, `architecture` tests | `lib/engine` stays pure; one engine, two transports |
| Server security advisor | Run 2026-11-19: nothing at error level; the warnings are by design (anonymous sign-in, own-row reads, deny-all tables) |
| Server performance advisor | Run 2026-11-19: one missing index on a new table, added live (20261119002400) |
| **Fixed: stale capabilities fixture** | `test/fixtures/capabilities_all_on.json` had missed the per-match ad budget since 2026-11-11, so the client parse test never saw it; refreshed, and the client test now checks the budget |
| **Fixed: both local server runners** | `tool/test_sql_without_docker.mjs` and `tool/edge_harness` stopped booting on 2026-11-18 (`storage.objects` missing), so the function tests had not run since; both boot again |

## 6d. Production signals (read 2026-11-19, last 24 hours)

| Signal | What it was | Done |
|---|---|---|
| `record_speaking` 500 ×8 | A speaking report landing after the floor moved on: SQL refuses `NOT_FLOOR_HOLDER`, the function threw it as a 500, the client read «no connection» and retried four times | The shared handler answers a refusal SQL raises by name with its code (`raisedRefusal`, `supabase/tests/raised_refusals.test.mjs`); every function gets it |
| `play_release_watch` 502 ×5 | Google Play's API answering 503; the next run succeeds | Nothing to fix; the force update still follows Play |
| `leave_room` 500 ×1 | Three leaves in the same second; no database error logged | Watch; now any named refusal is a 4xx |
| `browse_rooms` 401 ×29 in one minute, `join_room` 404 ×33, `realtime_token`/`set_presence` 403 | Expired session polling, dead room codes, voice/presence for a room already left | The client backs off or stops on each; check on a phone (section 7) |
| Security advisor | Nothing at error level | — |
| Performance advisor | One missing index | Added live (20261119002400) |
| Live site | Every page 200; the build on the site is the release build; Chromium and WebKit at phone, iPhone and desktop sizes draw the first screen with no errors and no sideways scroll | `tool/verify_web_release.mjs`; first visit downloads ~25 MB, time on a real phone to be measured (section 7) |

## 7. Needs a real phone (the owner's checklist)

These depend on Android itself, the network or a second person; no automated
test can stand in for them.

1. Install 1.7.0 from Play over 1.6: data, coins and profile are kept.
2. Offline match, 6 players, Elder in it: the Elder taps «اكشف نفسي الصبح», the morning says it.
3. Online match on two phones: turn wifi off on one at night for 20 s, then on: the same screen comes back (with the Elder: the chip and its undo).
4. «استناني» on 5 phones (or testers): ready, the match starts by itself; one phone closed after «أنا جاهز» still starts it within 30 s.
5. Home button at night for 2 minutes as a guest: struck, the others go on.
5b. The web game on a phone from a link, first visit: how many seconds until «كمل» shows.
6. Push: a friend's invite arrives with the app closed.
7. Play and pay a tool with a test card (licence tester).

## 8. Run order

1. `flutter analyze lib test` and `flutter test` (everything in `test/`).
2. `node tool/test_sql_without_docker.mjs` over `supabase/tests/*.sql` (PGlite).
3. `node --test supabase/tests/*.test.mjs` (edge harness; includes the online fuzz).
4. Live, read-only and rolled back: the SQL tests for anything changed that day.
5. Section 7 on a phone before a release goes past testers.

Results of each run go in `docs/PROGRESS.md`.
