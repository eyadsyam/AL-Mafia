# Codex review queue — provisional during implementation
Do not treat these as confirmed final defects; re-check after Claude finishes.
- New SQL commit_ad_step_v2 initially SELECT FOR UPDATE claim before wallet advisory lock, whereas create_ad_step_claim_v2 wallet lock before INSERT ON CONFLICT. Review consistent lock ordering across v1/v2/daily and purchase/refund; PGlite cannot prove hosted multi-connection races. Prefer wallet-first, then rowlock after nonlocking owner lookup, revalidate claim.
- AdsRuntime _Units.rewardedFor initially falls back from missingv2 ID tolegacy. Verify final capability gating cannot show v2/daily ad via legacyunit whose server router rejects that claim. Missing v2 ID should disableplacement unless backend intentionally supports secureclaimtype dispatch with sameunit.
- Daily replay across UTC midnight: require request day from server snapshot (reject stale; never silently turn ambiguous retry into newdayclaim); persistUIpending day/context.
- Do not equate Do-not-consent with canRequestAds=false. Existingprivacyoptions getsrefreshed and prestagedads must respect changedconsent.
- Confirm one sourceoftruth for adfreeentitlement; nointerstitial defaulton during capabilities/networkfail or beforewallet ownerknown. No teardownnav callback duplication.
- Actual Play signing cert/AdMob units/merchant products/account email delivery/licensed purchase/realSSV remain external verification gates; no fabricated IDs or readyclaims.

## Browser handoff — 2026-09-25
Codex created and visibly verified in Chrome on eyadsyam124@gmail.com:
- rewarded_steps_v2: ca-app-pub-9179063936085117/9448608978. Reward amount1/type reward_step. Ad pods DISABLED. SSV URL https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/admob_ssv verified successfully in AdMob and saved.
- post_match_interstitial: ca-app-pub-9179063936085117/5836667020. Unit frequency cap3 impressions/user/1day. Google optimized all prices.
Account still under review, store link pending. These are configuration readiness only, no real serving/reward flow proven. Legacy unit unchanged. Implementer should wire intended IDs only behind safe-off capabilities, ensure SSV correct allowlist/type routing. Do not activate new live server features or publish candidates. No live-ad clicks/tests.
Additional review requirements: disclose outstanding refund debt and net coins BEFORE new purchase (or block with explanation); no silent500->0 sale. Consent changes must invalidate cached ads appropriately. Missing v2 unit must not silently use legacy and produce unpaid reward. Distinguish Dart obfuscation symbols from native debug symbols/R8 mapping in release handoff.
Independent read-only reviewer session a6c702fe-c232-45c8-85db-7c20428695ba reports to %TEMP%/mafia-update101-third-readonly/final.txt. Integrate findings when available; main implementation remains sole source/build owner.

## Independent client review - must resolve before release
# Independent release review for 1.0.1 (read-only, no edits)

**Scope.** I checked the source against the implementation brief, `status.md`, the PROGRESS tail (102–103) and the security review. I did not run anything: no tests, no emulator, no build. Phases 104–106 are still being written, so every result below covers the source as it stands right now. This is not a readiness claim.

## Results

| Area | Result | Evidence |
|---|---|---|
| Automatic ad only after the player leaves a completed result | **FAIL** | The ad fires after `widget.onExit()` (`online_table_flow.dart:224-228`), but that path never calls `leave()`. Home is just `context.go(home)` (`router.dart:459`), so the heartbeat, channel and voice link are still running when the ad shows. The other result screen does leave first (`match_flow.dart:651-653`). Rematch, back and kick never show the ad: PASS. |
| Interstitial rules (first match exempt, 10 min gap, 3 min after reward, 3 a day, clock moved backwards) | PASS by reading | `interstitial_policy.dart:41-53, 90, 181-211`. The count is saved before the ad shows (`interstitial_coordinator.dart:106`). |
| Preloaded or skipped, never waits on the network | PASS | `interstitial_coordinator.dart:95-103`, `rewarded_ads_mobile.dart:339-341` |
| Consent change clears cached ads | **FAIL** | `showPrivacyOptions` (`rewarded_ads_mobile.dart:144-158`) never throws away the preloaded `_ad` (`:288`). `showIfReady` (`:339`) does not re-check `canRequestAds`. An ad loaded under the old answer can still be shown after a withdrawal. |
| Consent form has no time limit | **FAIL (minor)** | The privacy-choices form has a 10-minute cap (`rewarded_ads_mobile.dart:153`, `design_tokens.dart:1022`). The brief says only the network info request may be capped. The first-run form is not capped (`:135`), which is correct. |
| Two optional reward steps, +50% then the remaining 50% | PASS by reading | Both amounts show before the first tap (`rewarded_reward_button.dart:443-453, 478-482`). Step 2 unlocks only after step 1 is verified (`:462-465`). The wording makes no "upgrade pays more" claim (`app_en.arb:1808-1839`). The server total matches the base exactly (security gate G2). |
| Old one-ad claim and new two-step claim can't both pay for one match | PASS | Server gate G1 passed. An existing old claim stays resumable (`rewarded_reward_button.dart:191-197`). One robustness gap: a steps response with anything other than two steps leaves the button stuck on "loading" (`:208`). |
| Ad unit routing | PASS, with a note | The new placements fall back to the primary unit (`rewarded_ads_mobile.dart:32-36`), and the server accepts primary or second for new placements (`ad_rewards.ts:64-68`). Test mode sends Google's sample unit, which the server refuses, so the test-ads build can never credit a reward. That is expected, but it must be written in the build notes. |
| Features switch off when config is missing (client) | PASS, with a UX gap | Any failure falls back to "everything off" (`economy_capabilities.dart:52, 85-92`). But that failure is cached for the whole session (plain `FutureProvider`), and `PlayOffersController._started` stays true after an empty product list (`play_offers.dart:83-92`). One network blip hides daily rewards and the store until the app restarts. |
| Features switch off when config is missing (server) | **FAIL (release gate)** | The config table defaults everything to on: `interstitial_enabled`, `ad_steps_enabled`, `daily_enabled`, `daily_ad_enabled` are all `true` (migration `:22-25`), and the seed row is inserted (`:37`). Deploying the migration turns every feature on at once. |
| Ad-free ownership | PASS | Comes from the server entitlement (migration `:825`). It is checked before any automatic ad (`interstitial_policy.dart:190`) and refreshed after a purchase (`play_offers.dart:148-153`). |
| Payment pending, cancel, restore | Mostly PASS | Pending grants nothing, and the client only lets Play forget the Quiet Pass after the server has granted it (`play_offers.dart:118-120, 144-147`). Coin packs use `autoConsume:false` (`play_billing_mobile.dart:113`). Cancel clears the busy state (`:121-123`). Restore runs automatically each time the store opens (`:109`). **Gap:** a pending payment keeps `busyProduct` set, which disables every buy button for the rest of the session (`:118-120`). |
| Refund-debt disclosure before purchase | **FAIL** | No wording exists for it: `app_en.arb:1960-1989` only has "no cash value". Nothing in the client reads `purchase_debt` (grep of `lib/` for "debt" finds nothing). The pack cards (`play_offers.dart:283-296`) show neither the refund rule nor an outstanding debt the next pack would pay off first. |
| Account linking required before paying | PASS | `play_offers.dart:180-187`. The account tag is sent as the obfuscated account ID (`play_billing_mobile.dart:104-107`). |
| Daily wheel result decided by the server | PASS, with 2 defects | The server picks and stores the result before the animation, and the client animates to that slot (`daily_rewards.dart:287-300`). (a) The slot is used as a list index (`:714`), but the schema allows slots 0–9 with gaps (migration `:301`). It should look the slot up by value. (b) `_absorb` sets `wheelSpun` before the spin starts, so for one frame the wheel shows the final position (`:504-508`). |
| Daily ad | **Defect** | When the claim comes back already `awarded`, `createAdClaim` still returns the ID (`daily_rewards.dart:188-189`), and an ad is shown that can pay nothing (`:314-324`). |
| Paid-coin debt rule (buy 500, spend, refund → debt 500; next 500 pays it off; refund that one → debt 500, not 1000) | PASS by reading, not run | Migration `:554, :619, :720-731`: on refund, debt goes up by what the purchase had paid off plus what was already spent. Worked by hand for gates G3a, G3b and G3c, all correct. The regression SQL must be re-run to prove it. |
| Security findings F3, F4, T1 | Repaired in source | F3 (untagged coin purchase): `:649`. F4 (missing config): `:192`. T1 (daily actions need a day): `economy_actions.ts:70-71`. |
| Security findings F2 (void records) and T2 (deadlock) | **OPEN / NOT VERIFIED** | No void record is visible to grep in the migration or the functions. |
| Design-token rule | Minor FAIL | Hard-coded values: `daily_rewards.dart:770` (`0.66`) and `rewarded_reward_button.dart:474` (`strokeWidth: 2`). |
| Role leakage (Doc 05), pure engine, voice not load-bearing | PASS for what I read | Ads appear only on the result screen or outside a match (the in-match guard). Voice failures are caught (`rewarded_reward_button.dart:34-37`). No engine imports in the monetization code. Whether `lib/engine` has changed since 1.0.0 is NOT VERIFIED (the worktree was already dirty). |
| 1.0.0 artifacts kept | PASS (presence only) | `build/release-1.0.0/` contains the apk and aab. No symbols or README are in that folder. |

## Fixes, in priority order

1. **Leave the room before any automatic ad.** In `_homeAfterCompleted`, await `leave()` before `onExit()`, and only allow the ad after `leave()` has finished. If `leave()` is slow, skip the ad rather than delay the exit.
2. **Server defaults to off.** Set the four `*_enabled` defaults to `false` and turn features on explicitly in the activation runbook.
3. **Refund-debt disclosure.** Add AR/EN wording beside every coin pack and in the Quiet Pass sheet. Show any outstanding debt from the wallet or capabilities before the Buy button.
4. **Consent change.** After the privacy-options form closes, throw away the cached interstitial. Re-check `canRequestAds` in `showIfReady`. Remove the form timeout.
5. **Security.** Finish F2 (void records written for every voided token, revoked is final) and T2 (lock order), then re-run `update101_security_regressions.sql` and confirm every gate passes.
6. **Daily ad.** Stop when the claim comes back already `awarded`.
7. **Wheel.** Look slots up by value, and hold the displayed state until the spin starts.
8. **Retry and pending state.** Retry capabilities on resume or when the store opens, reset `_started` when the product list is empty, and let a pending payment clear the busy state.
9. **Token rule.** Move `0.66` and `strokeWidth: 2` into the design tokens.

## Gates and account setup (none of this has been done)

- **AdMob:** create the second rewarded unit (optional) and the interstitial unit. Set `ADMOB_REWARDED_V2_ANDROID_ID` in both the Edge env and the dart-defines, and `ADMOB_INTERSTITIAL_ANDROID_ID` in the dart-defines. Confirm the SSV callback URL applies to the new units.
- **Play Console:** create `mm_remove_interruptions` and the three coin packs, and set prices (suggested prices are only assumptions). Set up a service account with the Android Publisher API and the voided-purchases schedule. Add licence testers and run a test purchase.
- **Play Console declarations:** review Data safety (purchase history, and the ads identifier for interstitials). Paste in the updated privacy URL text.
- **Asset links:** get the app-signing SHA-256 from the Console before touching the asset-links file.
- **Deploy order:** `20260924000500`, then `20260925000100` (with the off defaults), then the Edge functions (never type-checked, because Deno isn't on this machine). Then prove concurrency on hosted Postgres with two connections.
- **Mark `play_products.active=true` only after** F1 and F2 are verified and a licence-test purchase and refund have been checked against the debt rule.
- **Device checks:** the EEA consent form on a device, one run with a fake interstitial unit, and full-suite, analyze and screenshots (Phase 106). All NOT VERIFIED.

This review says nothing about revenue, fill rate or Google approval.
