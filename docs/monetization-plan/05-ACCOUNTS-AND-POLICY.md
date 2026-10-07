# Accounts, approval and policy work

## Observed 2026-10-07 in the user's Chrome

AdMob identity: `eyadsyam124@gmail.com`. Android app: `سيد المافيا: Mafia Master`, app ID `ca-app-pub-9179063936085117~7320479940`. Account approved; app settings say **requires review**, with **no store listing attached**. These are different approval layers. Policy Center explicitly says no current issues. European privacy messages: one active; US-state privacy messages: one active. Rendering/consent behavior in app still needs testing.

Five units are present, not three:

| Name | Numeric unit suffix | Observed format/cap |
|---|---|---|
| app_open_launch | 9527218766 | App-open; no unit cap |
| lobby_banner | 3131088967 | Banner |
| post_match_interstitial | 5836667020 | Interstitial; 3/user/day |
| rewarded_match_bonus | 8711609352 | Rewarded; no unit cap |
| rewarded_steps_v2 | 9448608978 | Rewarded; no unit cap |

Prefix for all: `ca-app-pub-9179063936085117/`. No active mediation groups or campaigns shown on the unit list. App-level cap absent. High-engagement ads on. Both rewarded units use SSV URL `https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/admob_ssv` and Google-optimized all-prices floor. V2 has quantity 1, item `reward_step`; legacy has quantity 1, item `coins`. Legacy allows video/ad pods/interactive; V2 shows video/interactive. Do not change existing reward items while old clients/claims remain. For new v4 units select video only initially, no ad pods; one opt-in should not unexpectedly become a sequence of multiple ads.

AdSense identity: `g11769841@gmail.com`, publisher `pub-5174049351369803`. Onboarding page says account not approved, with program-policy compliance heading and a confirmation checkbox plus Resubmit. No specific URL, issue code or low-value-content label is displayed. Notifications expose only a general notice, not an account-specific diagnosis. Do not claim the cause is duplicate accounts, content quality, invalid traffic or consent without further evidence.

## Immediate sequence when implementation is authorized

1. **AdMob readiness first:** inspect Play app publication/availability in the already-open Play Console. Verify package `com.mafiamaster.mafia_master` and the listing's actual visibility. Attach the correct supported store URL only when available; request app review through the normal supported process. Closed-test access alone is not assumed sufficient. If the console cannot locate it, wait for supported listing availability; do not register a duplicate app.
2. Confirm the developer website attached to the listing resolves to `saidalmafia.com`. Fetch its live `/app-ads.txt` from outside authentication; require correct plain-text response and AdMob crawler recognition. Local file already contains both verified publishers. Do not delete either line solely because the products use different accounts.
3. Inspect and save date range, currency, requests, matched requests, impressions, show rate, eCPM, estimated revenue by unit/country/app version for 7 and 28 complete days. Never treat rounded dashboard totals as settled payments. No ad clicks for validation.
4. Deploy additive SSV support to staging, test registry and legacy reward handling, then create the **24 new named v4 units** from CSV after approval to implement. Keep five current units intact for legacy versions: transitional console total will be **29**, with 24 v4 placements. Do not rewrite current IDs or silently remap current reward types.
5. New units: no manual eCPM floor initially; Google optimized/all-prices if offered. Reward item `verified_view`, quantity 1; verified current SSV endpoint; server-visible unit map written before any client requests. Reward actual amount still comes from the claim.
6. New interstitial units cap 3/user/day each; new app-open units cap 1/user/day each. Application safety cap 14 fullscreen/user/day only after verifying the console's exact scope includes the relevant fullscreen formats. App policy independently enforces 6 automatic/day, 2/hour and 8 rewarded/day. Never rotate units to escape caps. If dashboard cap scope differs, leave it unchanged and record the mismatch; client/server limits are mandatory.
7. Leave manual banner refresh off for initial rollout. Native setup must match SDK-supported templates and AdChoices. Turn off high-engagement ad behavior for the v4 rollout if the console setting controls extended interactive dismissal; capture exact setting description first. Do not guess unavailable controls.
8. Test UMP EEA, UK, Switzerland, US-state and non-required consent cases on test devices. Active console messages alone do not prove correct consent. Ensure privacy choices remain reachable.
9. Defer mediation expansion. Only after 28 days of stable volume and per-format data: evaluate one documented bidding partner at a time, verify Flutter/platform support, privacy partner disclosure, binary/startup budget and net yield. Do not add 20 networks or adapters to match the unit-count target.

M00 follow-up confirmed account impression-level ad revenue is **off**. In the authorized external configuration phase, enable the corresponding AdMob setting before expecting production SDK paid-event data. M03 must represent unavailable data as unknown, not zero. Account timezone is Africa/Cairo; detailed reports currently show USD while the dashboard is EGP. Report history is restricted to 20 September 2026 onward. Play production is inactive with 12 testers for 4 of the required 14 days. These are observed constraints, not application defects to work around.

## AdSense remediation decision tree

**Current branch: account-level generic rejection.** Keep web paid serving off. Review any rejection email/details through authorized account access if later available; record exact reason and affected property. Do not press the compliance checkbox merely to unlock the account. If no further detail exists, complete the concrete source fixes and public site checks below, document the evidence, then prepare a truthful resubmission for owner review. Approval is Google's decision, not a local test result.

Source fixes: accurate visible role/how-to content in both languages; visible public navigation and contact/about/privacy; correct privacy wording; remove AFC display overlays from Flutter game/lobby/settings/payment/auth shells; CMP-gated eligible editorial inventory; proper ads.txt; functional mobile/desktop page layout and no broken routes. Hidden SEO text alone is not evidence of a useful visitor page. Do not create filler articles or hide a broken experience from reviewers.

If a specific issue becomes visible, apply ONLY its branch:

| Console finding | Concrete response | Completion proof |
|---|---|---|
| Site not ready / low-value content | Provide original useful rule explanations, worked examples and real navigable content; eliminate empty/index-only shells from ad inventory | Public content usable with ordinary browser, matching game rules; follow-up Google review |
| Ads on no-content / private communication / navigation screens | Remove requests from those screens, not merely CSS-hide filled ads; disable Auto ads/vignettes in the game shell | Network trace has zero ad requests on forbidden routes; approved inventory allowlist |
| Consent/CMP | Publish supported certified CMP and correctly gate supported ad modes and revocation | Geo/test consent trace; no outdated cached permission shortcut |
| Invalid traffic / serving limit | Keep test devices on test IDs, inspect traffic sources and request bursts, remove incentives/accidental-click layouts | Source audit, rate safeguards; wait for platform evaluation without account evasion |
| Duplicate publisher account | Follow Google's account recovery/association guidance for the actual named issue | Owner-assisted resolution; no invented publisher or new identity |
| ads.txt / ownership | Match the actual authorized publisher lines and verified site property | Public plain text + crawler recognition |

Never submit a statement that a problem is fixed without evidence. Do not submit appeals, accept terms, create a new AdSense account, change payment identity or close an account under this planning task.

## Web inventory choice

Ordinary AdSense display: only substantial public editorial pages `/how-to-play/`, `/roles/`, `/about/` after approval/CMP. One reserved in-flow unit below substantive content; no auto-refresh. No ad on privacy, delete-data, login, beta signup, admin or error pages. H5 fullscreens in the game require separate H5 access approval; a working AdSense account alone is not sufficient. H5 initially only at completed-match exit, no first-open preroll. Web rewarded payout stays disabled under current trust model.

## Official sources checked for this plan

- [AdMob interstitial placement](https://support.google.com/admob/answer/6201362?hl=en): use predictable content breaks; do not add app-exit or every-action interstitials.
- [Flutter app-open guidance](https://developers.google.com/admob/flutter/app-open): loading-screen placement and skipping late delivery once content is usable.
- [Reward requirements](https://support.google.com/adsense/answer/9121589?hl=en): explicit choice/disclosure, restricted rewards, actual delivery.
- [UMP Flutter](https://developers.google.com/admob/flutter/privacy): refresh consent, check SDK eligibility and expose required privacy options.
- [AdSense placement](https://support.google.com/adsense/answer/1346295?hl=en) and [game pages](https://support.google.com/adsense/answer/2768340?hl=en): avoid accidental clicks/private communication and self-refreshing content ads; game separation guidance is a recommendation, not a blanket approval of any 150px layout.
- [AdSense policy issue categories](https://support.google.com/adsense/answer/15689616?hl=en) and [fix/review workflow](https://support.google.com/adsense/answer/7003627?hl=en-GB): distinguish actual issue type and serving status.
- [Certified CMP requirements](https://support.google.com/adsense/answer/13554116?hl=en): applies to personalized serving in named regions; limited/nonpersonalized eligibility differs. Our conservative unknown-consent behavior is a product decision.
- [H5 signup](https://developers.google.com/ad-placement/docs/signup) and [placement API](https://developers.google.com/ad-placement/apis): separate access and provider-controlled eligible breaks.
- [Play payments policy](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en-en): verify applicable program/region before exposing alternative payment for digital items. Do not infer broad eligibility from another region's exception.

Recheck account-specific requirements at execution time; this is not a guarantee of policy approval.
