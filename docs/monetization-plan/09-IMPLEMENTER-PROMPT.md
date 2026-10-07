# Prompt for the next implementation model

You are implementing the approved Mafia Master monetization plan in this repository. The owner explicitly wants ads in the Android mobile app AND the responsive browser version on Android/iPhone/desktop. Android uses AdMob; mobile/desktop browsers use separately approved AdSense/H5. Do not attempt Android ad IDs on native iOS.

First read `AGENTS.md`, the latest section of `docs/PROGRESS.md`, then `docs/monetization-plan/00-START-HERE.md` and the requested phase in `08-EXECUTION-AND-TESTS.md`. Read the relevant sections of Doc 05 before UI/phase work and Doc 11 before writing tests. Other technical decisions are in 03/04/06/07. Read ranges, not entire unrelated specs.

For an initial start with no implementation phases completed, execute M00 and stop at its gate. For a later request to continue, use the latest completed phase and Next entry in PROGRESS/implementation-status, then execute that next phase only. Do not restart completed phases merely because the model changed. If the owner names a phase, execute it after checking dependencies. The owner has now authorized implementation; ordinary local phase work needs no repeated confirmation. External actions still follow their specific phase and applicable action-time requirements.

Do not redesign the plan or add a parallel engine. Implement its exact placement names, platform split, pacing, callback state machine, SSV binding, compatibility rules, schema boundaries, UI behavior and tests. Never make up a missing ID, publisher approval, report number, reward or policy issue. Missing external evidence closes only dependent enablement gates; continue independent authorized local work.

Key facts collected 2026-10-07:

- Existing Android app ID: `ca-app-pub-9179063936085117~7320479940`; five existing units, not three. Keep them intact for old clients. Plan creates 24 new v4 units, so transitional console count is 29.
- AdMob account approved and policy center clear, but app requires review and has no store link. Resolve listing readiness before scale.
- AdSense publisher `pub-5174049351369803` is associated with the requested second account and is not approved. Only generic policy-compliance rejection is visible. Do not assert low-value content as the diagnosed cause.
- Existing six reward flows already exist; new unit mapping needs SSV extension. Legacy reward items are `coins` and `reward_step`, quantity 1; preserve them. New v4 uses `verified_view` quantity 1 and server-stored actual benefit.
- Last-seven-day dashboard: 291 requests, 32 impressions, 46.39% match rate, EGP 0.92 estimated revenue. This sample cannot justify a revenue A/B winner or six-hour retention target.
- Local cached dependencies were prepared with the lockfile enforced. Targeted Flutter tests: 102 passed. Node: 18 passed, one role-page parity failure. No source fix was made during planning.

Hard implementation rules:

1. Ads never appear/request based on role or secret state. No automatic or rewarded ads throughout a live match/room, including dead-player views. No lobby ad in v4. Do not amend binding specs.
2. One fullscreen mutex and global device pacing across IDs; no unit rotation around caps. One public display slot, banner OR native. Ready-or-skip automatic ads; no forced house fullscreen fallback.
3. Never enable real IDs in debug/profile. Use Google's test inventory and fake adapters in tests. Never click production ads, fabricate impressions or grant reward from a client callback.
4. SSV signature + bound user/unit/scheme + immutable claim + transaction deduplication precedes reward. Preserve already-earned late/legacy settlements during rollout/rollback.
5. Unknown approval/CMP/entitlement/config means disabled dependent inventory. Paid web rewards stay off without independent trusted proof. Mobile ads are required and must not be removed just because the web account is rejected.
6. Keep existing coin/mission values, store localized pricing and Quiet Pass entitlement. No new currency, subscription or pay-to-win. Web and Play payment availability differ.
7. Canonicalize design tokens with compatibility export as specified; keep Arabic line-height 1.6, zero letter spacing, text scale 1.0 and all role trees/timings invariant.
8. Do not edit deployment scripts into auto-publish mode, run migrations on production for tests, push secrets into client builds, accept policy attestations, submit reviews or publish without the applicable authorized phase.
9. Never claim tests ran when only code inspection happened. Run meaningful tests, review output, record exact failures. Real Safari/device/SSV tests cannot be replaced by mocks.

After the requested phase, append:
```text
## PHASE Mxx — done | blocked
Built:      <one line>
Files:      <actual paths>
Verified:   <commands/device checks and results actually observed>
Gate:       PASS | FAIL
Open:       <specific remaining issues>
```
Report the same block and stop. No further phase without owner instruction.
