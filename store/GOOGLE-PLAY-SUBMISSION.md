# Google Play submission — Mafia Master / سيد المافيا

Developer: **Eyad Syam**. Public support: **eyadsyam124@gmail.com**.
Submitted: **1.0.0 (versionCode 1)**, closed testing "Alpha" (2026-09-25).
Next candidate: **1.0.1 (versionCode 8)** — see `build/release-1.0.1/README.md`.
Package: `com.mafiamaster.mafia_master`. Upload the **AAB**; the APK is for
sideload checks. Never upload key.properties, the keystore, dart_defines.json
or build logs containing credentials.

> This file lists what to **review** in Console. Nothing here has been entered
> into Console by the build; every declaration below is the owner's to confirm.

## Listing and review access

- Arabic: `listing-ar.md`; English: `listing-en.md`. The purchases sentence is
  published only once Play products are active (see the listing notes).
- Icon: `icon-512.png`; feature graphic: `feature-graphic-1024x500.png`.
- Screenshots: `screenshots/play-ar/01.png`–`06.png`, in numeric order.
- Support website: https://almafia.vercel.app
- Privacy: https://almafia.vercel.app/privacy/ (updated 2026-09-25 for ads,
  daily rewards and Play Billing — deploy the web build before resubmitting).
- Deletion: https://almafia.vercel.app/delete-data/
- Free download.
- Review access: no email/password is needed. Complete onboarding, enter a
  display name and avatar choice, then accept community rules for online play.
  Offline play can be reviewed on one device with five local players. Online
  review requires five distinct clients/anonymous sessions.

## Monetization in 1.0.1 (as built)

- **Rewarded ads (optional).** After a completed online match: v1 servers offer
  one ad (+100% of the completion coins); v2 servers offer two optional steps
  (+50% then +50%), the count and amounts shown before the choice. The vault
  offers one optional fixed daily ad (+25) outside a match. Rewards are
  credited only after AdMob's signed server-side verification callback.
- **Interstitial (automatic).** At most one, only after the player taps
  «Home» on the result of a completed match; never on first completed match per
  install, never before/during a match, on resume, invite, back, kick or lost
  connection; ≥10 min between interstitials, ≥3 min after any rewarded ad,
  ≤3/day; preloaded-or-skip. Server off switch and caps. Owners of the Quiet
  Pass get none.
- **Play Billing** (off until the owner activates products): permanent
  `mm_remove_interruptions` («ممر الهدوء» / Quiet Pass, removes automatic ads
  only) and consumable Council Coins packs `mm_coins_500`, `mm_coins_1200`,
  `mm_coins_2500`. Prices are set in Console; the app shows Play's localized
  price only. Coins are cosmetic-only and non-transferable.
- **Daily rewards** (free, no purchase): coffer +20/day, wheel once per UTC day
  (10/20/35/60/100 at 40/30/20/8/2%, published beside the wheel), +60 on every
  seventh claimed day (no reset for missed days).
- The older non-consumable `mafia_scenario_mastermind` is **not sold** (its
  content is ordinary settings). Keep it inactive/unpublished in Console.

## Data safety — declarations to review

Source for SDK behaviour: https://developers.google.com/admob/android/privacy/play-data-disclosure
(checked 2026-09-25). Re-read that page when answering; Console wording wins.

| Data type | Collected | Purpose / notes |
| --- | --- | --- |
| Name | Yes | Display name; visible to room players. App functionality. |
| Email address | Yes, **optional** | Only when the player chooses account protection (one-time codes, restore). Account management. |
| User IDs | Yes | Anonymous online identifier. App functionality, fraud prevention. |
| Other personal info | Yes | Avatar/gender selection. |
| Purchase history | Yes (when Billing active) | Order id, product, purchase token/time, verified with Google. App functionality, fraud prevention. |
| In-app messages | Yes | Whispers, eliminated-player chat, report descriptions. |
| Other UGC | Yes | Public room titles, reports. |
| App interactions | Yes | Match actions, rewards, daily claims, purchases; **and** the Mobile Ads SDK's ad/app interaction data. Advertising, analytics (SDK), fraud prevention. |
| Approximate location | Yes (SDK) | Derived from IP by the Mobile Ads SDK. Advertising, fraud prevention. |
| Diagnostics | Yes | Service logs; Mobile Ads SDK crash/performance data. |
| Device or other IDs | Yes (SDK) | Advertising ID, App set ID. Advertising, analytics, fraud prevention. |
| Audio | Review | Optional WebRTC voice, encrypted in transit, not recorded. Confirm the end-to-end exemption against the actual relay configuration before answering "not collected". |

**Shared:** the Mobile Ads SDK sends the rows marked "(SDK)" to Google for
advertising. Answer "shared" for those types unless the disclosure page states
that Google acts only as a service provider for them. Do not answer a blanket
"not shared".

Data in transit: HTTPS/WSS, DTLS-SRTP. Deletion: **Yes**, in-app and external page.

Also review: **Ads = Yes**; **Advertising ID = Yes** (advertising, analytics,
fraud prevention); in-app purchases declared once products are active.

## Content, audience and operations

- IARC questionnaire answered honestly (Mafia themes, elimination artwork).
- Declare user interaction: live voice and text plus public room names.
- Target audience: 16–17 and 18+. No child age group, no Families.
- The free wheel has no purchase, no cash value and published odds; there are
  no paid random items.
- Monitor moderation and deletion queues (SAFETY-OPERATIONS.md).

## Console / account steps the build cannot do

1. **App signing certificate:** copy the SHA-256 from Play Console → Test and
   release → App integrity. Only if it differs from the upload key already in
   `web/.well-known/assetlinks.json`, add it (keep the existing entry) and
   redeploy the site. Then test a Play-installed invite link
   (`adb shell pm get-app-links com.mafiamaster.mafia_master`). Not assumed.
2. **AdMob:** optional second rewarded unit for v2 steps (or reuse the current
   unit); create an interstitial unit; point each rewarded unit's SSV at the
   same `admob_ssv` URL; set `ADMOB_REWARDED_ANDROID_ID` (+ optional
   `ADMOB_REWARDED_V2_ANDROID_ID`) function secrets; add the interstitial id to
   `dart_defines.json`. Register a test device before any live ad view.
3. **Play products:** create `mm_remove_interruptions` (one-time, non-consumable),
   `mm_coins_500/1200/2500` (one-time, consumable, multi-quantity OFF); set
   prices (owner range for the pass 150–200 EGP); link the Play service account
   (`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`) with "View financial data" and "Manage
   orders"; add a licence tester; then activate rows in `play_products`.
4. Deploy migrations `20260924000500` (if not yet applied) and
   `20260925000100_update101_economy.sql`, then the functions `economy`,
   `admob_ssv`, `play_purchase`, `play_voided_sync` (see the runbook).
5. Update Data safety / Ads declarations per the table above.
6. Closed testing: 12 testers opted in for 14 days before production access.
7. Owner performs the final multiplayer match and real-device voice check.

## Official references checked 2026-09-25

- Rewarded ads disclosure: https://support.google.com/admob/answer/7313578
- Unexpected ads / interstitial placement: https://support.google.com/googleplay/android-developer/answer/9857753 , https://support.google.com/googleplay/android-developer/answer/12271244
- Payments policy: https://support.google.com/googleplay/android-developer/answer/9858738
- Mobile Ads SDK data disclosure: https://developers.google.com/admob/android/privacy/play-data-disclosure
- Data safety definitions: https://support.google.com/googleplay/android-developer/answer/10787469
- Personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
