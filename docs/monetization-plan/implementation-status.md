# Implementation status

## M00 — blocked (2026-10-07)

Authorized start: owner requested implementation. Executed the first phase's read-only prerequisite checks; no runtime or external settings changed.

Verified live, unauthenticated HTTPS GET:

- `/ads.txt`: HTTP 200, `text/plain`, both expected Google DIRECT publisher lines.
- `/app-ads.txt`: HTTP 200, `text/plain`, both expected Google DIRECT publisher lines.
- This verifies public availability and content, not Google's crawler recognition.

Account refresh blocked: Chrome profile Eyad is advertised, but inventory/tab calls failed at request-header-policy loading, including a documented retry. The prior verified AdMob/AdSense observations remain historical; no new account status or report was invented. Missing: 28-day report, exact reporting period/timezone, Play release visibility and specific rejection detail if available.

Public Play listing lookup returned 404 to the web research tool. Publication status remains unknown because region/access/tool behavior can affect retrieval; Play Console is required to settle readiness.

Test run: `node --test tool/web_publisher_consistency.test.mjs` → six tests, five pass, one failure, native exit 1. Existing failure: current Arabic mafia role description absent from HTML roles page. No source repair belongs to M00; M01 contains that fix.

Gate: FAIL for completion of the account refresh. Live ads.txt checks passed. Production paid enablement remains blocked. M01–M09 local implementation can proceed independently when the next phase is requested, as specified by the roadmap.

This initial block records the failed attempt; the recovered audit and implementation below supersede its outstanding connection and source-test blockers.

## M00 — done after connection recovery (2026-10-07)

Chrome connection recovered. Verified requested account emails, AdMob app/publisher and AdSense publisher. AdMob app still requires review and lacks store linkage; AdSense still exposes only a generic program-policy rejection. No account setting was changed and no attestation/resubmission was performed.

Selected the 28-day dashboard preset and opened the detailed report. Actual available range is **2026-09-20 through 2026-10-06**; the date picker refuses an earlier start, so a full 28-day history cannot be collected yet. Report totals: 291 requests, 135 matched, 32 impressions; rounded estimated USD 0.02, eCPM USD 0.55. Three unit/country rows, all Egypt: rewarded_steps_v2 33/33/11, lobby_banner 191/35/21, post_match_interstitial 67/67/0 (requests/matched/impressions). No fake zero rows added for units absent from the report.

Account timezone is **Africa/Cairo**, currency EGP; report displays USD. Keep currencies/periods distinct; report-specific timezone was not independently exposed. Account impression-level ad revenue is **off**; enabling it belongs to the authorized external configuration phase. Temporary report changes were discarded without saving.

Play Console: package matches; closed testing, production inactive, 10 installed users shown. Production gate shows 12 opted-in testers for 4 days; requires 12 for 14 days, with request-production button disabled. Do not promise an exact approval date from rounded duration.

Gate: PASS for prerequisite audit with documented external constraints. Paid launch remains blocked by real platform readiness. No runtime implementation depends on fabricating approvals.

## M01 — done (2026-10-07)

Built:

- Canonicalized `lib/core/theme/design_tokens.dart`, leaving the old import path as a forwarding export. Automated comparison proved every token definition/value identical to HEAD apart from its relocated import. Updated palette tooling and the two source-reading leakage guards to the canonical location.
- Matched all four Arabic/English role descriptions on the HTML roles page to the game's current rules, including group doctor protection, one detective, teammate restriction and online citizen waiting.
- Corrected website privacy copy: browser rewarded payouts currently off, no claim that a live web consent form was verified; Play payments use Billing, and direct Android transfers have explicit eligibility requirements.
- Play Android transfers default off. Direct builds require explicit distribution and build approval; unknown channel defaults Play. Added a separate false-by-default server approval column combined with existing Android kill switch; web unchanged. Migration prepared locally, **not deployed**.

Files: `lib/core/theme/{design_tokens,app_colors}.dart`, `lib/ui/theme/design_tokens.dart`, `lib/platform/payment_capabilities.dart`, `dart_defines.example.json`, `web/{roles,privacy}/index.html`, `tool/{extract_palette.dart,generate_assets.py}`, `test/widget/coin_purchase_test.dart`, `test/golden/leakage/{handoff_purity,night_color_token}_test.dart`, `supabase/migrations/20261007000900_transfer_distribution_gate.sql`, `supabase/tests/{transfer_distribution,payments_v2}.sql`, `docs/setup/PAYMENT-DISTRIBUTION.md` and these phase records.

Verified:

- Flutter targeted commerce/theme/leakage/reveal/vote suite: **111 passed**.
- Node publisher/bridge/payment contracts: **19 passed**, including previously failing role-page parity.
- Local PGlite: **130 migrations applied in isolated memory; 2/2 SQL test files passed**. Initial invocation used prefixed filenames and was corrected; no production DB was touched. This harness is a single-connection simulation, not real hosted/RLS/Realtime deployment verification.
- `flutter analyze lib test tool`: strict exit 1 with info lints; `flutter analyze --no-pub --no-fatal-infos lib test tool`: **exit 0**, 102 info findings, no errors/warnings.
- Token-definition comparison and `git diff --check` passed. Formatting performed without broad unrelated test churn.

Gate: PASS for M01 local implementation. Open: migration deployment and live-device verification pending; Play/AdMob/AdSense approval constraints documented above. Native and browser ad expansion remains M02 onward, not claimed enabled here.

Next: M02 — shared policy, registry and safe configuration. Stop at this phase gate.

## M02 and account inventory — partial, 2026-10-07

User explicitly redirected work to create actual AdMob units. Created and verified 21 new Android units: seven banner, seven native, two interstitial, two app-open, three rewarded. Existing five preserved; console total is 26. Exact IDs are in created-admob-units.json and ad-units.csv. The failed reward_spin request showed the daily new-unit quota error; it was closed without retries or duplicate creation. reward_spin/coffer/swap are not created. Do not infer a quota-reset time.

Rewarded new units use verified_view quantity 1, video only, ad pods/interactive off; SSV is NOT configured. All new units remain off in runtime configuration. Account unit creation does not mean SDK integration or approved serving. App still requires review and store linking.

Local foundation implemented: exact 24-placement inventory, publisher/duplicate/revision/TTL validation, pure shared decision function, conservative rollback-safe pacing, session generation cancellation and bounded load ownership, serialized preference writes and legacy cap migration, additive adsV4 capabilities. A present v4 payload suppresses the old automatic display paths until the new adapter is wired; absence preserves legacy behavior.

M02 is NOT complete. Public route watcher, SDK ownership/voice lifecycle, production policy integration, full edge-case matrix and deployment remain. Do not activate the new payload before those are complete. Paid metrics/SSV/native/web phases remain pending.

Verification: 51 Flutter tests passed across v4 policy/storage, v3 policy, app-open and navigation. Additional final v4 rerun follows the resume/reward gap changes. No real ad request, emulator or deployment performed.

Next: complete M02 adapter integration; continue server/SDK phases in planned order. Finish three quota-blocked units only after Google allows creation. Never recreate the 21 already recorded.
Final verification: follow-up v4 tests 7/7 passed after resume/reward-gap changes; scoped analyze exited 0 with one info lint and no errors/warnings; git diff --check passed.

## PHASE MERGE-PREFLIGHT — done
Built:      Prepared named integration checkpoint, verified old-version compatibility, centralized v4 timing tokens, fixed web integer guard and serialized ledger migration/update callbacks; final release integration remains on hold.
Files:      lib/core/theme/design_tokens.dart; lib/platform/monetization/{ad_policy,ad_placement_registry,ad_session,ad_ledger_store}.dart; test/unit/ad_ledger_store_v4_test.dart; docs/monetization-plan/{MERGE-READINESS.md,runtime-candidate.json,implementation-status.md}; tool/verify_admob_inventory.mjs; docs/PROGRESS.md.
Verified:   Full Flutter run: 1741 passed, 5 skipped, 1 failed; sole failure fixed and targeted rerun 11/11 passed. Latest ad/legacy subset 51 passed before final storage changes; final storage concurrency covered in 11/11 rerun. Node 19 passed; local SQL 130 migrations and 2/2 suites passed; analyze exit 0 with 111 info/no errors/warnings; manifest and diff checks passed.
Gate:       PASS — checkpoint and compatibility audit only; NOT completed monetization rollout or final merge readiness.
Open:       SDK/route/lifecycle integration, SSV/server registry, telemetry, native/web/performance and release gates still incomplete; 3 units quota-blocked. Branch codex/monetization-v4-foundation is a checkpoint, not an instruction to merge now. Main checkout unchanged.