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
  one ad (+100% of the completion coins); v3 servers (phase 110) offer ad 1 =
  x2 of the match's completion coins and optional ad 2 = x3 total, both totals
  shown before the choice, ad 2 only after ad 1 is verified. The vault
  offers one optional fixed daily ad (+25) outside a match. Rewards are
  credited only after AdMob's signed server-side verification callback.
- **Interstitials (automatic, Ads v3 / phase 110, each OFF by default).** Per
  match, never inside a match phase: pre-match (tap on Create / Join / «روم
  جديدة للشلة», before navigating to the lobby; skipped for the first match
  after launch), post-match (Home from a completed result), pass-and-play
  (after setup confirm and before the first pass screen; after leaving the
  result — never while the phone is passed or a role is visible), and a
  session interstitial (≥5 min of menu time without a full-screen ad, only on
  a navigation between two menu screens; never in a match, the lobby or its
  countdown). Global for every full-screen ad incl. app-open: ≤40/day safety
  cap, ≥90 s apart (server may only tighten), ≥3 min after any rewarded ad,
  none around a brand-new player's first match, consent (canRequestAds)
  required, preloaded-or-skip, game audio and mic muted and restored. Owners
  of the Quiet Pass get none.
- **App-open (automatic, phase 108, OFF by default).** Only while the branded
  launch screen is up: cold start, or a return after ≥4 h in the background.
  Never on first launch, before onboarding + terms, into an online room / live
  match / pass-and-play game / purchase, or right after another full-screen
  ad or the Play purchase sheet. Loaded within 3 s or skipped; an ad is
  discarded 4 h after load; phase 110: no own daily cap — the global
  full-screen pacing above (≤40/day, ≥90 s apart) applies. Needs
  consent that allows ad requests (never shows a consent form itself).
- **Banner (automatic, phase 108, OFF by default).** Anchored adaptive, labelled
  «إعلان»/"Advertisement", on waiting surfaces only (online lobby, online room
  list, match history, vault, profile edit). Never on role reveal, night/day/
  vote/discussion, pass-the-phone screens, dialogs or beside primary buttons
  (enforced by `test/unit/banner_placement_test.dart`); zero height with no
  fill; dropped while the app is in the background.
- **Rewarded extras (optional, phase 108, OFF by default).** From the vault,
  outside a match, each once per UTC day: a second wheel spin (same published
  odds, server-drawn), doubling today's coffer, swapping one unclaimed daily
  contract. Credited only after the signed SSV callback (`x1:` claims).
- **Play Billing** (off until the owner activates products): permanent
  `mm_remove_interruptions` («ممر الهدوء» / Quiet Pass, removes every automatic
  ad: app-open, every interstitial and banners; rewarded ads stay optional) and consumable Council Coins packs `mm_coins_500`, `mm_coins_1200`,
  `mm_coins_2500`. Prices are set in Console; the app shows Play's localized
  price only. Coins are cosmetic-only and non-transferable.
- **Manual transfers — InstaPay / Vodafone Cash (Payments v2, phase 111; OFF by
  default).** Offered in the Android app beside Google Play Billing, and on the
  website, for every coin pack, the Quiet Pass and the Starter Bundle, at the
  same EGP price as the Play product (one server price table). Each paid item
  shows «ادفع بجوجل» and «إنستا باي» / «فودافون كاش»; a transfer button opens the
  owner's payment link (held server-side) in the payment app or browser; the
  player then uploads the transfer screenshot and the sender name; an admin
  reviews by hand (approve / reject with a reason shown to the player /
  refund). Remote kill switch per platform (`economy_config.
  transfer_enabled_android` / `transfer_enabled_web`). **Policy note for the
  owner:** Google Play's Payments policy generally requires Play Billing for
  digital goods sold in a Play-distributed app, with country/programme
  exceptions. This build does not hide the transfer option from review; the
  owner must confirm eligibility (e.g. an alternative-billing programme for
  Egypt, if any applies) before enabling `transfer_enabled_android` on the
  Play build.
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
| Purchase history | Yes (when Billing or transfers are active) | Play: order id, product, purchase token/time, verified with Google. Transfers: product, amount, method, order status and review history. App functionality (order verification), fraud prevention. |
| Other financial info | Yes, **when the player pays by transfer** | The sender name exactly as shown in InstaPay / Vodafone Cash (may be a wallet number for Vodafone Cash). Used only to match the payment (also sent to the owner's own Telegram chat as the new-order notice, a service the developer uses, not a third-party recipient); not shared; removed from the order if the account is deleted. App functionality (order verification), fraud prevention. |
| Photos | Yes, **when the player pays by transfer** | The payment screenshot the player picks with the system photo picker (re-encoded on the device to a ≤1600 px JPEG). Stored in a private bucket (no public read; admin sees it through short-lived signed URLs), a duplicate image is refused, deleted 90 days after the order is reviewed (at once on account deletion). Not shared. App functionality (order verification), fraud prevention. |
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
fraud prevention); in-app purchases declared once products are active. The
transfer rows (Photos, Other financial info) are collected, not shared, are
required for that payment path only (optional for the player, who can pay with
Google Play or not buy at all), and can be deleted (retention above; data
deletion request).

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
   Phase 108: app-open unit `…/9527218766` (`ADMOB_APP_OPEN_ANDROID_ID`) and
   banner unit `…/3131088967` (`ADMOB_BANNER_ANDROID_ID`) are in the local
   `dart_defines.json`; the rewarded extras use the second rewarded unit, so its
   SSV callback must point at `admob_ssv` as well. In Console → Ads, the new
   formats need no new Data safety category (same Mobile Ads SDK).
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
