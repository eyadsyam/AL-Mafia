# Ordered implementation tickets and phase gates

These tickets are for the next model after an explicit implementation request. This turn only prepares the plan. Each phase ends with the repository's PROGRESS block and stops. Runtime numbers are design decisions, not claimed Google requirements. `proposed-config.json` is an all-off planning fixture, never directly pushed.

## M00 — Refresh external prerequisites (read-only)

Inputs: `account-evidence.json`, actual Chrome accounts, current Git status/progress. Confirm no changed app/publisher. Complete missing 28-day reports and exact periods/timezone; inspect actual Play release availability and live ads.txt. Record specific AdSense rejection details if exposed. Do not accept compliance, resubmit, publish, create units or change settings in this phase.

Gate: evidence recorded with date/source/unknowns; account readiness is either verified or explicitly blocked. A blocked paid-launch path does not prevent M01–M09 local implementation and testing with fakes/test IDs. Never label rejected AdSense approved because code works.

## M01 — Policy/source foundations and token location

1. Canonical token move + compatibility export exactly as technical contract, fix internal import and leave values unchanged initially.
2. Fix `web/roles/index.html` Arabic/English descriptions against all four existing ARB role descriptions. No engine rule changes. Keep semantic article text beyond descriptions.
3. Correct `web/privacy/index.html` web consent/reward claims; describe only active behavior and planned new measurement only when actually enabled.
4. Set Play-distributed build's manual digital-item transfers off by default in `lib/platform/payment_capabilities.dart`, the corresponding server capability gate, and tests. Preserve browser transfer behavior. Add explicit distribution channel config defaulting Play for Android; non-Play/approved alternative programs need verified deployment configuration. Never choose based on client locale alone.
5. Add `docs/monetization-plan/implementation-status.md` tracking ticket/result/commit/evidence, no rewrite of binding specs.

Gate: role consistency test green; unchanged theme/parity tests; payment capability tests distinguish Play Android, web and unsupported native iOS. No account writes.

## M02 — Shared policy, registry and safe configuration

Create `ad_placement_registry.dart`, `ad_policy.dart`, `ad_session.dart`; versioned `adsV4` capabilities. Add token values from inventory. Legacy wrappers delegate shared rules when v4 enabled. Implement single fullscreen mutex, persisted unified ledger, cancellation token and fail-closed unknown config/entitlement. One route watcher supplies public eligibility. Remove pre-match and session automatic ad triggers only for v4; old client payloads remain compatible.

Tests: new `test/unit/ad_policy_v4_test.dart` table covers every placement × denied state; exact caps/gap boundaries; midnight, clock rollback, restart, route race, ad return, first launches/match, refund/adFree, consent revoke. New `test/widget/ad_session_v4_test.dart`: parallel load/show, failed ad, delayed callback, no-fill, auth/purchase/reconnect, disposal and voice restore. No late fullscreen can appear over a started game.

Gate: all 24 mappings unique; unit absent→off; iOS Android-ID use impossible; total budgets shared; old tests pass or are replaced with behavior-equivalent tests documenting intended v4 behavior.

## M03 — Typed monetization telemetry and baseline

Implement migration/function/contracts in technical + measurement docs. Reuse existing auth/rate-limit/admin boundaries. Add callback instrumentation to current formats, with unknown paid values excluded rather than fabricated. Add private cohort retention aggregation only after privacy/capability gating. Add an internal admin report to existing authorized admin surfaces, not a public analytics route.

Tests: event enum allowlist, bounds, duplicate events, forged subjects, missing consent, unknown precision/currency, deletion/purge, disabled capability, telemetry offline. SDK paid callback mocks never produce wallet credit. SQL tests run only against local/disposable/staging DB explicitly designated for tests; no tests on production by default.

Gate: estimates labelled and reconcilable, no hidden role/room/message fields, no gameplay waiting on ingestion. Account sample remains too small for causal uplift claims.

## M04 — Six rewarded placements and verified settlement

Implement additive registry/binding/budget migration and v4 create action; preserve old prefixes/unit aliases. Split match double/triple, daily, spin, coffer and swap call sites. New IDs come from verified console manifest only at account-configuration phase. Match rewards maintain current base and x2/x3 totals. Use existing pending polling UI and server receipts.

Tests: `supabase/tests/ads_v4.test.mjs`, `supabase/tests/ads_v4.sql`, `test/widget/rewarded_v4_test.dart`. Assert signature tamper, escaped custom data, wrong unit/user/scheme/item/amount, cross-claim transaction replay, two-device race, step ordering, cap reservation, expired unshown claim, valid delayed SSV, logout/resume, old claim compatibility, verified-credit-once and no credit from browser/onUserEarnedReward alone. Existing SSV verifier tests remain mandatory.

Gate: server-only payment; on-time and delayed callbacks settle correctly; all six offers work with test/fake ads; no invented real IDs.

## M05 — Android automatic fullscreens and adaptive banners

Wire two app-opens, two completed-result interstitials, seven banners to registry. Explicit Home exit only; rematch never intercepted. PublicAdSlot requires content ready, allowed surface and no active room. Remove v4 lobby banner. Reuse existing native SDK adapter, timeouts and test-mode safeguards; bind intents before showing.

Tests: adapt `app_open_policy`, `ads_v3_policy`, `ad_lifecycle`, `session_ad_navigation` and placement tests for v4; test no paid ad during setup/deal/night/vote/live result transition/disconnection. First two launches/first match ad-free. Quiet Pass covers every new format. Mock layout tests include keyboard and short screen. Real Android test ads on Pixel 9 pro (2) and one physical device after SDK tools are available.

Gate: no load waiting on navigation, no button overlap, no production ads in debug/profile, test ad callbacks/disposal observed.

## M06 — Android native alternatives

Add supported native template adapter and seven named placements; activate test placements on History and Vault first. Banner/native choice comes from assigned experiment variant, not random rebuilds. Remaining slots remain off until tested with actual content. All use the same one-display-at-a-time gate.

Tests: Native attribution/AdChoices visible, asset failure collapses slot, no custom overlay intercepts clicks, nonempty content rule, background/unmount disposal, duplicate load prevention, image decode/memory budget, Quiet Pass. Use test IDs/device, never click live ads.

Gate: one ad per surface; safe labels; measured performance delta within budget. SDK incompatibility blocks phase; no handwritten fake native creative.

## M07 — Web ads separation and approval-ready site

Separate editorial AdSense from H5; remove AFC overlays and static global game-shell loader dependence. Add certified consent path and revoke handling for eligible editorial requests. Add three editorial slot mapping keys, disabled until real AdSense units/approval exist. H5 completed-match exit only, access unknown→off; preserve untrusted-reward prohibition. Replace `needsHouseInterstitial` forced fallback with continue. Maintain existing routes/invites/PWA/voice.

Tests: update `web_ads_h5.test.mjs`, `web_publisher_consistency.test.mjs`, web rules/widget tests to assert new contract rather than retain old static-script assumption. New browser tests prove no ad request on forbidden routes, no form/private-chat inventory, no hidden overlay, no request on denied/unknown CMP, no refresh during resize/background, no forced fallback, revoked consent disposes inventory, provider late event cannot invade match.

Gate: accurate visible public content, consistent publisher lines, real CMP validated in staging. AdSense/H5 not approved means paid production flags remain off; phase may pass code tests while paid-enable gate remains blocked.

## M08 — Adaptive layout and performance

Apply shared public scaffold and width tokens to screens listed in web/performance contract; preserve existing private trees. Remove eager film SW precache; isolate versioned caches and bound media; defer optional startup tasks. No asset regeneration or renderer migration without a measured need.

Tests: `test/widget/adaptive_public_layout_test.dart`, current Council responsive suite; browser viewport matrix, long Arabic/English, keyboard, SafeArea, zoom, offline resume and Safari PWA. Measure cold/warm startup and ad-off/on deltas, app-interactive marker, memory. No claim of real iPhone verification from viewport emulation.

Gate: screenshots + traces meet defined budgets or enumerate specific failing device/scenario. No new hardcoded sizes/colours/durations outside canonical tokens.

## M09 — Product loops and commerce

Implement G01–G12 in order, using current missions/season/friends/referral/rematch systems. Preserve server economy values. Add missing events, one explicit post-second-match invite prompt, public result hierarchy, optional 60-minute result-screen break reminder and truthful welcome-back. Use current purchasable entitlements; no recurring subscription introduced.

Tests: invite through auth→lobby; match→rematch with voice broken; no private-state metrics; first-run skip/resume; mission claim idempotency; server Cairo event boundary; referral fraud/settlement existing gates; coin/purchase restore/refund; cancellation leaves base rewards/play available. No automated messages/posts to other people.

Gate: whole first-play and returning-group journey completes; commerce works without ads; ad-free users see no automatic format.

## M10 — External configuration and staged enablement

Only when user explicitly requests implementation/account changes: follow account runbook, resolve app readiness, create 24 new v4 units, fill a separate production manifest, configure SSV/CMP and verify callbacks. Preserve five old units. Prepare AdSense resubmission evidence; never accept legal attestations without required current user action/confirmation. No deploy command from this doc is authorization by itself.

Gate: correct emails/app/publishers, all real IDs format-validated and matched to console, test-device path separated, one genuine permitted production SSV settlement reconciled without self-clicking, no policy blockers for enabled inventory. Partial platform readiness enables only the approved platform; it does not block Android because AdSense is rejected.

## M11 — Release verification, rollout and optimization

Run full repository release gate from Doc 11, whole game with voice broken, migration/RLS/anti-cheat, builds and platform matrix. Six-hour soak is a separate recorded device run. Rollout percentage/cohort schedule in measurement doc is mandatory. Kill switch rollback retains settlement and restores last known compatible client/config. Do not repeatedly rewrite/adapt rewards to chase noisy income.

Gate: all required checks evidenced; remaining external rejection clearly recorded. No 20× or universal smoothness claim without measured results.

## Commands and operational cautions

Preparation (completed in this planning turn):
```powershell
flutter pub get --offline --enforce-lockfile
```

Baseline targeted suite (completed; 102 passing):
```powershell
flutter test --no-pub test/unit/ads_v3_policy_test.dart test/unit/app_open_policy_test.dart test/unit/web_ad_rules_test.dart test/unit/web_ad_placement_test.dart test/widget/ad_lifecycle_test.dart test/widget/ad_extras_test.dart test/widget/web_ads_test.dart test/widget/session_ad_navigation_test.dart test/online/council_geometry_responsive_test.dart 2>&1 | Select-Object -Last 40
```

Existing Node gate (18/19 in baseline; M01 fixes failure):
```powershell
node --test tool/web_ads_h5.test.mjs tool/web_publisher_consistency.test.mjs supabase/tests/ads_v2.test.mjs supabase/tests/admob_ssv_verify.test.mjs 2>&1 | Select-Object -Last 40
```

Later per-phase changes: targeted suites above plus relevant SQL tests. Before release:
```powershell
flutter analyze 2>&1 | Select-Object -Last 30
flutter test 2>&1 | Select-Object -Last 40
dart run tool/engine_purity.dart
flutter build web --release
```
Record native command exit code as well as truncated output; never let a successful pipe hide test failure. `flutter build web` without verified defines is an offline build, not a production-ready release. Existing `tool/build_web.ps1 -Publish` force-pushes deployment output: do not use during audit/tests. No `supabase db push`, Edge deploy or real AdSense submit before its explicit phase authorization. Do not execute SQL tests against live customer state.
