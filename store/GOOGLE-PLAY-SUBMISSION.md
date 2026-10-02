# Google Play submission — Mafia Master / سيد المافيا

Developer: **Eyad Syam**. Public support: **eyadsyam124@gmail.com**.
First upload: **1.0.0 (versionCode 1)**. Package: `com.mafiamaster.mafia_master`.
Upload the final **AAB**, not the APK: `build/app/outputs/bundle/release/app-release.aab`.
The APK is for sideload checks. Never upload key.properties, the keystore,
dart_defines.json or build logs containing credentials to a public listing.

## Listing and review access

- Arabic: `listing-ar.md`; English: `listing-en.md`.
- Icon: `icon-512.png`; feature graphic: `feature-graphic-1024x500.png`.
- `screenshots/play-ar/01.png` through `06.png` are the final connected Arabic
  marketing set. Every phone contains a real app capture; the surrounding dark
  panorama is generated campaign art. Upload them in numeric order. Raw current
  captures remain in `screenshots/` as review evidence. Full-match acceptance
  remains user-owned.
- Support website: https://almafia.vercel.app
- Privacy: https://almafia.vercel.app/privacy/
- Deletion: https://almafia.vercel.app/delete-data/
- Free download. Optional rewarded ads appear only after eligible matches; no interstitial or mid-match ads.
- One permanent non-consumable scenario purchase: `mafia_scenario_mastermind`. No subscription.
- Review access: no email/password is needed. Complete onboarding, enter a
  display name and avatar choice, then accept community rules for online play.
  Offline play can be reviewed on one device with five local players. Online
  review requires five distinct clients/anonymous sessions: create a private
  room and join via its code. Supply these instructions in App access; do not
  give reviewers service keys or claim every screen is reachable with one user.

## Data safety draft — review against Console's exact questions

Online collection is optional by choosing local play; online features need
their corresponding data. Purpose: app functionality, security/fraud prevention
responding to support requests, optional advertising rewards, purchase fulfillment
and fraud prevention. No analytics purpose.

| Data type | What happens |
| --- | --- |
| Name | Display name stored with room membership; other players see it. |
| User IDs | Anonymous online user identifier; this IS a user identifier even without email. |
| Other personal information | Avatar/gender selection submitted with membership. |
| In-app messages | Whispers, eliminated-player chat, report descriptions; stored server-side. |
| Other user-generated content | Public room titles and safety reports. |
| App interactions | Membership, votes, night actions, readiness/presence, predictions, earned-coin transactions, rewarded-ad claims, purchases and unlocked content. |
| Audio | Optional WebRTC media is encrypted between participants; TURN relays packets without the media keys. Google excludes qualifying end-to-end encrypted data from collection. Confirm this exemption against the actual provider configuration; do NOT base “not collected” merely on absence of recordings. If any service can decrypt/process media, declare audio collection and assess ephemeral processing instead. Connection metadata is separate. |
| Purchase history | Product and purchase identifiers are verified server-side to grant and restore the permanent scenario. Payment-card data is not received by the app. |
| Diagnostics/device or other identifiers | Service providers process IP/connection metadata and logs. The advertising SDK may process device and advertising identifiers for delivery, consent and fraud prevention. Review the final SDK disclosures in Console. |
| Email | No sign-in email collected by the app. Support email correspondence is handled when the user chooses to contact support. |

Data in transit: HTTPS/WSS and DTLS-SRTP. User-to-user communication and service
provider transfers may qualify for Play's sharing exceptions; apply the current
form definitions rather than blanket “not shared”. Names/messages are visible
to their intended recipients. Request deletion: **Yes**, in-app and external
page. A request receipt is not proof of completed deletion.

## Content, audience and operations

- Complete the IARC questionnaire honestly. Themes include Mafia, killing and
  elimination plus illustrated death/winner artwork. Do not preassign PEGI/ESRB
  or claim no violence based only on lack of a combat mechanic.
- Declare user interaction: live voice and text plus public room names.
- The launch audience is adults 18+ because public rooms contain live voice
  and free-form user communication. Do not select child age groups or Families.
- Declare **Contains ads: Yes**. Ads are voluntary and post-match only.
- Declare the non-consumable scenario as an in-app purchase. It adds a room scenario,
  grants no secret information or power within a match, and can be restored.
- There is no real-money or simulated wagering. Earned coins have no cash value,
  cannot be transferred and buy no match advantage.
- Monitor moderation and deletion queues as described in SAFETY-OPERATIONS.md.
  Providing a report button does not replace timely human moderation.

## Console steps that cannot be completed by building the app

1. Finish developer identity/contact verification and create the app record.
2. Enrol in Play App Signing and upload the AAB to an internal test track.
3. Take the **app signing certificate** SHA-256 from Play Console. If Google
   uses a different certificate from the local upload key, add that fingerprint
   to `web/.well-known/assetlinks.json` and redeploy. Do not replace or discard
   the established local key. Test a Play-installed invite link afterward.
4. Review App Bundle Explorer compatibility and the Play pre-launch report.
5. Create and activate the permanent Play product `mafia_scenario_mastermind`,
   configure the purchase-verification service account, and test buy/restore with a licensed tester.
6. Create the rewarded ad unit, configure its server-side verification callback,
   publish the consent message, and test reward/decline/offline recovery with test ads before switching to production IDs.
7. Complete store listing, App access, Ads, Data safety, content rating, audience
   and countries. Review every declaration against actual service settings.
8. If this is a personal developer account created after November 13, 2023,
   Google requires a closed test with at least 12 testers continuously opted in
   for 14 days, followed by an application for production access. Account age
   and eligibility were not provided; do not assume the requirement is waived.
9. User performs the final multiplayer match and real-device voice check.
10. Submit for review. Google approval and the Console's checks are not implied
   by a successful local build.

## Official references checked September 20, 2026

- Target API: https://developer.android.com/google/play/requirements/target-sdk
- 16KB native libraries: https://developer.android.com/guide/practices/page-sizes
- Account/data deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- Data safety definitions: https://support.google.com/googleplay/android-developer/answer/10787469
- UGC moderation: https://support.google.com/googleplay/android-developer/answer/12923286
- Personal-account testing: https://support.google.com/googleplay/android-developer/answer/14151465
