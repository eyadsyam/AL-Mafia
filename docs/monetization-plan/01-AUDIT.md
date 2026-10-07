# Audit evidence

Snapshot: 2026-10-07, commit `5bc7ab0`, clean tracked working tree at entry. Reviewed the current progress tail, monetization source and contracts, routing, growth features, relevant migrations, web shell, build scripts, existing tests and the previous UX audit. No production DB or private configuration was read.

## Findings

| ID | Evidence | Meaning / required action |
|---|---|---|
| A01 | Source has five Android unit defines; Chrome confirmed five units, listed in `account-evidence.json` | Six reward experiences collapse onto two IDs; all interstitials/banners share IDs. Introduce placement registry, not 24 copies of ad SDK code. |
| A02 | `lib/ui/theme/design_tokens.dart:1722`: 40 automatic fullscreen/day; minimum gap 90 seconds | Existing density ceiling is already high. Do not increase it blindly. New baseline uses lower operating caps and measured experiments. |
| A03 | `lib/platform/monetization/rewarded_ads.dart`; `ad_reward_flow.dart`; `rewarded_reward_button.dart` | Optional match steps, daily ad, spin/coffer/swap flows already exist. Preserve successful receipt behavior and server-paid rewards. |
| A04 | `supabase/functions/_shared/ad_rewards.ts:44` accepts only primary/secondary env IDs; `admob_ssv/index.ts` verifies signatures before RPC | Merely creating more rewarded units will cause new SSV callbacks to be refused. Extend registry and claim binding before enabling new units. |
| A05 | Search for `onPaidEvent`, `eCPM`, `revenue` in `lib`, functions and tests returned no results | No located impression revenue instrumentation. Console reports are required to establish actual income; client callbacks become estimated diagnostics, never wallet credit. |
| A06 | `lib/platform/metrics.dart` exposes event + one allowlisted prop; `20260928001200_metrics_v11.sql` aggregates daily counts and purges salted receipts | Current counters cannot establish per-player D7 retention or confidently join ad yield to cohorts. Add privacy-preserving explicit schemas; do not pass arbitrary properties/roles to existing metrics. |
| A07 | `web/index.html:50–51` embeds publisher `ca-pub-5174049351369803`; Chrome verified this publisher under requested AdSense account | Keep this publisher; do not replace it with the AdMob publisher. Local ads.txt and app-ads.txt already contain both observed publisher IDs. Live endpoint/crawler validation remains required. |
| A08 | Static ad loader runs in web shell; bridge creates fixed-position display overlay and recreates unit on size-key change; `web_ads.dart` checks private moment and route, not web CMP state | Source has no located explicit CMP gate. Account-hosted consent settings are unknown. Require demonstrated consent behavior, and remove game-shell AFC overlays from the new design. |
| A09 | `waiting_banner.dart:43` returns `WebAdBanner` before native clearance logic; lobby, settings, home, result and other surfaces mount web banners | Native clearance does not carry to web. Lobby communication, non-content forms and canvas-ad adjacency need separate inventory policy. This is a risk finding, not the diagnosed console violation. |
| A10 | `web_ad_rules.dart:69` gates navigation breaks only; app-open and after-match bypass that pacer | No single cross-format web budget. Replace with explicit eligible-moment policy and global ledger. Never substitute house fullscreen promotions when paid fill fails. |
| A11 | `docs/setup/WEB-ADS-SETUP.md:33`; H5 callbacks are client-side | Web rewarded payout remains off. Do not forge trust using a browser callback signed by our own endpoint. |
| A12 | Privacy page says web consent appears before every relevant ad and web rewards are server-verified | Claims exceed what source plus this audit proves. Correct copy to shipped behavior after confirming live account configuration. |
| A13 | `lib/platform/payment_capabilities.dart` permits Android manual-transfer capability, gated by server | For Play distribution, entitlement to alternative payment programs/regions is unverified. Disable manual transfer in Play builds until documented eligible enrollment. Web and non-Play channels are distinct. |
| A14 | `MafiaSpacing.maxContentWidth=480`; Council wide breakpoint 768; Store width 960 | Responsiveness is inconsistent, not wholly absent. Apply shared width classes to public screens; preserve role parity in private flows. |
| A15 | `web/offline_service_worker.js:25` precaches onboarding video; asset is 8,993,180 bytes | A new SW install may consume ~9 MB for an optional film. Remove eager film precache, allow explicit on-demand caching. |
| A16 | Source includes missions, season track, Thursday event, friends, referrals, rematch, cosmetics, starter bundle and Quiet Pass | Improve existing loops and measurement. No need for a new social system or battle pass rewrite. Quiet Pass is an existing entitlement; do not silently convert it into a subscription. |
| A17 | Existing web publisher test fails on `roleMafiaDescription` | HTML still says a mafia member chooses a victim; ARB now says mafia agree and cannot select a teammate. Update both languages and all four role descriptions from the actual rules. |
| A18 | Only Android ad IDs located; no GAD app ID found in iOS plist | iPhone Safari is in scope; native iOS ads are not launch-ready. Never use Android IDs on native iOS. |
| A19 | `docs/ux/AUDIT-2026-10-02.md` is historical; current TurnShell includes `_confirmationElapsed` and confirmed-state detail gating | Do not mechanically reapply old UX fixes. Keep zero-leakage regression as a release gate. |

## Local environment

- Flutter 3.44.4 / Dart 3.12.2; Node 24.13.0 available. `adb` and `deno` not found on PATH; emulator inspection was not performed.
- `.dart_tool/package_config.json` initially absent. `flutter test --no-pub` initially failed to resolve test packages; `flutter_test` is actually present in pubspec. This was an unprepared worktree, not missing source dependencies.
- `flutter pub get --offline --enforce-lockfile` succeeded using cached dependencies. No dependency upgrade or tracked lockfile change was intended.
- `dart_defines.json` absent. Test with fakes; do not assume a local build connects to production. Native release requires verified public build settings and signing setup. Service-role/API secrets must never enter client defines.
- Chrome initially failed at the request-header policy layer, then recovered. Both requested accounts were inspected through their visible UI. No cookies, profile DBs, password stores or browser security settings were accessed.
- Public site requests through the web research tool were inaccessible. No live performance, live ads.txt result or live approval claim is made.

## Verification status

Node command (local only):
```powershell
node --test tool/web_ads_h5.test.mjs tool/web_publisher_consistency.test.mjs supabase/tests/ads_v2.test.mjs supabase/tests/admob_ssv_verify.test.mjs
```
Result: **19 tests, 18 passed, 1 failed**, exit 1. Failure: role description parity in `tool/web_publisher_consistency.test.mjs:68`. Passing mocked bridge/SSV tests do not prove real ad fill or production reward settlement.

Flutter targeted test outcome is recorded in `VERIFICATION.md` after dependency preparation. SQL migrations, device ads, live SSV callbacks, consent geographies, billing and Safari performance require later gates.
