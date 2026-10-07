# Ad inventory: 24 planned Android units

`ad-units.csv` is the exact creation/mapping manifest: six rewarded, two app-open, two interstitial, seven adaptive banner and seven native units. Names are fixed; returned IDs must be copied from the verified Android app in AdMob. Create these as new v4 units only in the authorized account phase; retain all five observed legacy units unchanged, making a transitional console total of 29. Missing IDs mean disabled. No IDs have been created by this task.

Separate units provide placement reporting and experiment isolation. They do not represent 24 simultaneous ads, 24 ads per session, 24 advertisers or a guaranteed revenue increase. Some native units are mutually exclusive experiment alternatives to banners. If traffic cannot support the native experiment, leave those units inactive.

## Eligibility by format

| Format | Exact behavior |
|---|---|
| Rewarded | Existing six offers only. Explicit localized reward and skip choice. Server claim first; show available ad; SDK completion means pending; signed SSV means awarded. Double and triple use distinct placement IDs despite same legacy scheme. |
| App-open cold | Third or later cold launch, onboarding complete, one prior completed match, verified consent state, no active match/rejoin/purchase. Show only while real loading screen remains visible, within existing 3s load window; never hold content just for an ad. |
| App-open resume | Same rules; at least four hours away, actual loading screen visible. Return from ad, authentication, file picker or payment is excluded. At most two app-opens/day within the global automatic budget. |
| Interstitial online result | Only explicit Home after a completed match, after public result has been viewed. Never rematch, kicked/disconnected, room Join/Create, countdown or player turn. Ready-or-skip; do not await network. |
| Interstitial local result | Same explicit exit after full match ends. Match ID deduplicates impressions; never deal/pass/night/vote. |
| Banner | One visible adaptive anchored banner on an allowed public non-game screen. No timer-driven custom reload. Disabled in lobby, conversation-focused screens, settings, payments, authentication and profile editing. `profile` means read-only public profile summary; edit removes the slot. |
| Native | One labelled native ad after actual content on the named public screen. SDK-rendered ad assets and AdChoices remain intact. No imitation of role cards, currency rewards, player messages or navigation. Native/banners never coexist on a surface. |

For banner/native `online_hub`, any active room, quick-join operation or reconnect state removes the slot. History requires at least one result; casebook requires loaded nonempty mission content; vault requires actual catalog/reward content; all loading/error/empty states show no paid slot. Never insert an ad inside a personal conversation. The app never requests role-conditioned ad units.

## Operating policy (product choices, not Google-mandated numeric caps)

All counters use a device-wide persistent ledger for mobile and per-browser installation for web. Account reward caps additionally use server time/transactions. A new unit never resets budgets.

- Automatic fullscreen: at most **6/day**, **2/rolling hour**, **5 minutes apart**, and at least **3 minutes since reward dismissal**. App-open + interstitial share these caps. Count impression/show callback, not load.
- First completed match and first two cold launches: no automatic fullscreen. No automatic ad during a live room/match, even for eliminated players.
- Rewarded: maximum **8 new awards/day** across the six offers, maximum two steps for one match; daily/spin/coffer/swap each retain their current once/day limit. Additional explicit opt-in required each time. Minimum 30 seconds after prior rewarded dismissal. Pending claims reserve a cap slot until resolved/expired; retries of same claim do not consume another slot. Compatibility details are in the technical contract.
- No fullscreen immediately following a fullscreen dismissal. For post-match replay, the rematch action always works without an ad.
- Display: one banner OR native ad mounted, never both. At most one outstanding load per format, two total native/mobile loads, and no preload during a match. Do not prefetch all 24 IDs.
- Unknown config/entitlement/consent, no fill, SDK error, ad blocker or offline: continue play. Reward unavailable leaves the free base reward intact. No forced house fullscreen fallback.
- Quiet Pass suppresses every automatic format, including display/native, on every supported platform. It does not silently enroll a player in rewarded viewing.

## Load and teardown

Use a single fullscreen mutex across app-open, interstitial and rewarded. Dispose stale or late ads, cancel placement intent when its route leaves, recheck eligibility immediately before show. Route generation/intent token prevents a late ad opening over gameplay. Restore audio state from a captured token; never restore a microphone against an updated room phase.

Ad SDK banner auto-refresh, if enabled in the verified console, must stop when its widget is hidden/backgrounded. No custom rapid refresh, retry loop, ID rotation to evade caps, paid traffic farming or developer clicking production ads. Initial console banner refresh setting: disabled; test a documented SDK-managed setting only in a later experiment.

## Rollout choice

M04 wires six reward IDs but leaves legacy claims supported. M05 introduces the two app-open/two result IDs and seven banners behind switches. M06 adds seven native alternatives, starting only on content-rich History/Vault. Other native placements remain off until equivalent density/performance gates pass. Operating baseline keeps all new inventory off until staging and account prerequisites pass. Existing production behavior is unchanged by this plan.
