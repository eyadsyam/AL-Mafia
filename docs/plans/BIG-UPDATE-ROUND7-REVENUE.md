--- codex final report ---
# 1. `BIG-UPDATE-1.1-FINAL.md` review

The consolidation is substantially better, but it is not sign-off ready. Its largest structural error is claiming to be the only authoritative document while still outsourcing essential definitions to the superseded SPEC.

## §1 Product shape — sign-off ready

The pillars, IA, navigation rule and Arabic terminology correctly reflect Rounds 1–6.

One future addition belongs to Round 8: “The Four” still describes only dossiers, four chapters and milestone scenes. That is not yet the “much stronger” long-term character relationship now requested, but it is not a consolidation error.

## §2 Economy — fixes required

1. **19,500 is not a ceiling.** It assumes 50% wins and expected-value wheels. Rename it “expected 28-day revenue-loop payout for a highly active 50%-win player.”

   The hard recurring maximum is approximately **24,600 coins**:

   - Six completions and wins daily plus first-match bonus: 6,580
   - Match rewarded ads: 8,400
   - Casebook maximum: 1,820
   - Daily Case: 140
   - Maximum coffer/wheels/daily ads/extras: 7,660

   Lifetime achievements, Academy, Council levels and referrals sit outside that figure.

2. “Identical 5+-player group fingerprint” is ambiguous. It must mean the normalized full eligible-human roster, not an arbitrary five-player subset of an eight-player table.

3. Academy’s row should say “10 each for drills 1–4; 25 graduation” and “20 each; 50 graduation.”

4. The account ad cap of 16 includes 12 match ads, daily ad, extra wheel, extra coffer and contract swap. State this explicitly.

5. Add paid purchases to a separate non-faucet table: 500/1,200/2,500 coins, 600-coin Starter Bundle and Quiet Pass.

6. The release must update the existing privacy copy. Generated/localized text still says automatic ads can appear up to 40/day, 90 seconds apart, and describes Android InstaPay/Vodafone Cash. That conflicts with the three/day server cap, ten-minute minimum and the decision to keep Android transfers OFF.

## §3 Features — fixes required

### Self-containment failures

The following must be embedded, not referenced from historical SPEC:

- F2’s six worked puzzle examples.
- F3’s four complete chapter premises/scenes/objectives/deductions/letters.
- F6’s four canonical preset definitions.
- F13’s success and kill metrics.
- F14’s exact asset groups.
- Motion durations.
- Staged-rollout gates.

### Specific defects

- **F1:** “Season One content pack by day 21” requires a 1.1.1 app release if it contains new bundled art. Call it a scheduled content-build release, not pure live ops.
- **F5:** Public awards appear only when Awards is enabled and available.
- **F7:** The draft can deadlock after 30 seconds if only the host can finalize. After the deadline, any authenticated series member may invoke deterministic finalization; one receipt wins.
- **F8:** Automatic removal of unready players should apply to public matchmaking. In private/invite rooms, show the expired state but leave removal to the host; otherwise a configuration-changing host can weaponize deadlines.
- **F11:** Spell out retention: open/actioned evidence 180 days, dismissed evidence 90, audit metadata 365.
- **F11:** Restore the omitted RPCs: `admin_safety_list`, `admin_safety_resolve`, `purge_safety_evidence`.
- **F12:** Give every operator RPC its exact request shape and request-id semantics.
- **F13:** Add commerce metrics: `store_open`, `product_view`, `billing_started`, `purchase_success`, `purchase_refunded`, `ad_offer`, `ad_started`, `ad_completed`, `ad_no_fill`, `pass_view`, `pass_purchase`.
- **Links:** name the notification route, preferably `/case/today`.

## §4 Flags — fixes required

The list is complete, but it is not the promised final flag table. It lacks capability keys, dependencies and exact activation steps per flag.

Additional fixes:

- `awards_enabled`, `reactions_enabled`, `founder_enabled`, banner/app-open placement flags and transfer-web have no explicit activation step.
- Season activation and `missions_enabled` should be one audited operator transaction or an ordered operation with rollback; avoid a visible active season with Missions still off.
- `play_products.active` needs one row per SKU, not a collective phrase.
- Add `season_pass_enabled` and `council_membership_enabled` if the revenue plan below is accepted.
- Safety failure must block public matching but should not block local or invite-only play.

## §5 Art, sound and motion — fixes required

The definitive dimensions, alpha requirements and per-asset prompts from earlier rounds were lost. S1–S6 is a batch index, not an asset manifest.

Restore for every asset:

```text
id, feature, dimensions, format, alpha, feather mode,
reuse/new, prompt, source batch, file-size target, QA status
```

“Motion durations per SPEC” violates self-containment. Embed the durations.

## §6 Build order — fixes required

- Add estimates and per-feature gates; both existed in earlier rounds.
- Art must be a blocking sub-step immediately before each dependent UI, not merely item 12 after the features.
- Commerce schema, Season Pass product verification and refund provenance must precede premium-track UI.
- Privacy/data-safety/store-listing updates need an explicit release task.

## §7 Rollout — fixes required

The rollout cannot point to SPEC Round 4. Embed every threshold. Include:

- Purchase verification and refund drill.
- Ad no-fill, invalid-traffic and consent metrics.
- Pass purchase/claim reconciliation.
- Privacy-copy and Play Data Safety verification.
- Season Pass test-license purchase, refund and reinstall restoration.

---

# 2. Revenue deep-dive

## A. Current model

### Real inventory

The repository currently contains:

| Product | Current price |
|---|---:|
| Starter Bundle: 600 coins + Council Seal frame | EGP 29.99 |
| 500 coins | EGP 49.99 |
| 1,200 coins | EGP 99.99 |
| 2,500 coins | EGP 180.00 |
| Permanent Quiet Pass | EGP 199.99 |

The earnable catalogue has:

- Three frames: 200/250/300 coins.
- Three nameplates: 150/250/300.
- Two room packs: 600/900.
- One narrator pack: 1,200.
- Council and Identity bundles: 2,300/1,200.
- The old 400-coin guide is disabled and free in Help.
- `frame_council_seal` is unreleased outside the Starter Bundle.

Advertising includes:

- Two voluntary rewarded ads after eligible online matches.
- Daily rewarded ad.
- Rewarded extra wheel, extra coffer and mission swap.
- Interstitial candidates before/after matches, pass-and-play deal/result and menu sessions.
- App-open ads.
- Banners on waiting surfaces.
- Quiet Pass removes automatic ads, not rewarded ones.

Current automatic pacing is server-bounded at three/day, ten minutes apart, three minutes after a rewarded ad and never around the first match. App-open requires a long return interval.

Web/manual commerce supports InstaPay and Vodafone Cash proofs, two pending orders, recoverable accounts only, exact-once admin approval and 90-day proof deletion.

### Main weaknesses

1. **The coin shop is economically broken.** An active player can earn about 19,500 coins in 28 days, while the entire non-overlapping catalogue costs roughly 4,150. The largest EGP 180 pack buys only about 3.6 active-player days.
2. The catalogue is shallow and exhaustible.
3. Most desirable cosmetics are earned, leaving little premium aspiration.
4. There is no Season Pass or recurring product.
5. Manual transfers do not scale and support only EGP.
6. The permanent Quiet Pass limits future recurring ad-free revenue, although removing it would violate trust.
7. Advertising has many theoretical placements but no mature yield/fill experimentation.
8. Commerce funnel analytics are absent.
9. At this moment, with flags/products inactive, realized revenue is effectively zero.

## B. Season Pass — ship with 1.1

This is the strongest revenue addition because the Casebook, season track, cosmetics and purchase verification already exist conceptually. Deferring it means launching Season Zero without monetizing the update’s central retention loop.

### Product

`mm_season_pass_s0`, Google Play `INAPP`, one-time, non-consumable for Season Zero. A Season Pass is not a subscription. Play defines one-time products as consumable or permanent/non-consumable purchases; this should be the latter. [Google Play one-time products](https://developer.android.com/google/play/billing/one-time-products)

Recommended localized prices:

| Market | Price |
|---|---:|
| Egypt | EGP 79.99 |
| US/default | USD 2.99 |
| Saudi Arabia | SAR 10.99 |
| UAE | AED 10.99 |
| Qatar | QAR 10.99 |
| Kuwait | KWD 0.99 |

Use a Play pricing template, then manually override Egypt and Gulf rather than blindly accepting exchange conversion. Play supports pricing templates and localized “price charming.” [Play pricing](https://support.google.com/googleplay/android-developer/answer/6334373), [price charming](https://support.google.com/googleplay/android-developer/answer/16526148)

### Premium track

Cosmetics only:

- Level 1: Season Zero premium nameplate.
- Level 3: four-reaction pack.
- Level 5: Detective dossier treatment.
- Level 7: Council-table scene pack.
- Level 10: premium title and seal.
- Level 12: Doctor dossier treatment.
- Level 15: Mafia dossier treatment.
- Level 17: Citizen dossier treatment.
- Level 20: premium animated/painted Season Zero frame and public-result flourish.

No coins, XP, additional missions, attempts, role information or matchmaking benefits. Buying late retroactively unlocks already-earned premium levels. It does not grant levels.

Character treatments appear only in Profile, Dossiers, Casebook and public result. They never replace live-seat art or expose a role.

### Refunds

Add entitlement provenance per inventory item. On void/refund:

- Revoke the pass entitlement.
- Revoke pass-only cosmetics that have no other ownership source.
- Unequip revoked items safely.
- Preserve free-track rewards.
- Never create coin debt because the pass contains no coins.
- Handle Voided Purchases and RTDN idempotently.

Google recommends backend verification/acknowledgement and supports cancellation/refund notifications. [One-time purchase lifecycle](https://developer.android.com/google/play/billing/lifecycle/one-time), [purchase security](https://developer.android.com/google/play/billing/security)

Expected conversion:

- Downside: 0.8% of MAU.
- Base: 2.0%.
- Strong execution: 4.0%.
- Egypt likely below base; Gulf and highly engaged players above it.

## C. Council Membership — 1.2, not 1.1

A subscription is worth building only after the team proves monthly content delivery.

Recommended offer:

**عضوية المجلس / Council Membership**

- All automatic ads removed.
- Rewarded ads remain optional.
- One authored cosmetic set each month.
- Read-only archive of the previous 30 Daily Cases, with no coins/XP.
- Monthly member dossier letter.
- Member seal on Profile/lobby/result only.
- Early preview—not exclusive access—to next month’s scenario art.

Pricing:

| Term | Egypt | US | Saudi/UAE |
|---|---:|---:|---:|
| Monthly | EGP 49.99 | USD 1.99 | SAR/AED 7.99 |
| Annual | EGP 399.99 | USD 14.99 | SAR/AED 59.99 |

Keep the EGP 199.99 permanent Quiet Pass and grandfather all owners. Membership must clearly distinguish archive/content benefits from ad-free ownership.

Do not include recurring coin drops as the core value. Google requires subscriptions to provide sustained recurring value, disclose billing frequency and renewal terms, and not disguise one-time credit bundles as subscriptions. [Play subscription policy](https://support.google.com/googleplay/android-developer/answer/9900533)

Backend must support active, grace, account-hold, cancelled-but-entitled, expired and revoked states; provide a Play manage-subscription link; and process full/prorated revocations. [Subscription lifecycle](https://developer.android.com/google/play/billing/subscriptions), [refund/revoke handling](https://developer.android.com/google/play/billing/manage-purchases)

Base conversion: 0.3–0.8% MAU. Do not launch until three future monthly cosmetic sets are complete.

## D. Catalogue that can sell

### Immediate 1.1

1. **Reprice coin packs before activation**

   The current packs are too small:

   - EGP 49.99 → 3,000 coins.
   - EGP 99.99 → 7,500 coins.
   - EGP 180 → 16,000 coins.
   - Starter Bundle → 2,000 coins plus its cosmetics.

   Since products are inactive, replace the Play SKUs before launch rather than shipping misleading `mm_coins_500` identifiers.

2. **Upgrade Starter Bundle**

   EGP 29.99:

   - 2,000 coins.
   - Council Seal frame.
   - Council candle/table accent.
   - Three-reaction mini-pack.

   Offer after three eligible matches or the first deliberate store visit. No aggressive countdown.

3. **New earnable coin sinks**

   - Reactions: 600–1,200 coins.
   - Nameplates: 1,000–2,500.
   - Table ambience: 2,500–5,000.
   - Narrator presentation packs: 4,000–8,000.
   - Bundles: 7,500–12,000.

   Preserve old prices as legacy-friendly; price new content for the new faucet rate.

4. **Direct premium cosmetics**

   - Small reaction/nameplate pack: EGP 19.99.
   - Table scene pack: EGP 39.99.
   - Four-character dossier portrait set: EGP 49.99.
   - Premium Council bundle: EGP 99.99–129.99.

### Safe product rules

- Character “skins” are dossier/profile/result portrait treatments, never live role skins.
- Table packs may alter the shared environment but never by a player’s role.
- Narrator packs may change art, music and public stingers; canonical text remains visible and voice is never load-bearing.
- Paid reactions are rate-limited and obey blocks.
- Nameplate effects remain lobby/profile/result only.
- Thursday bundles are “featured,” not permanently exclusive. Promise a return window within 60–90 days.
- Do not implement cosmetic gifting yet. Refund provenance, recipient revocation and fraud are disproportionately complex. Add wishlists/shareable item links first.

## E. Ads

### Launch configuration

Revenue should be maximized per retained player, not per single session.

Recommended initial caps:

- Full-screen automatic ads: **2/day**, 20-minute minimum gap.
- At least 5 minutes after rewarded ads.
- Grace: two completed matches.
- App-open: max one/day, only after eight hours away.
- Session interstitial: after ten minutes of menu activity.
- Online pre-match: OFF.
- Pass-and-play pre-deal: OFF.
- Post-match: only after the player explicitly leaves the public result.
- Pass-and-play: at most one post-result ad per session.
- Banner: room list, history, profile and vault; remove from the active lobby/table scene.

Never place an ad:

- During role handoff/reveal.
- During night, morning, discussion, vote or confrontation.
- Over reconnect.
- Before public result.
- Between a result and its role reveal.
- Inside a chapter letter, Academy drill or Daily Case reasoning step.

### Mediation

Start with AdMob alone until there is enough traffic to measure. At roughly 100,000 monthly impressions, test two bidding partners—not six SDKs at once:

1. Meta Audience Network.
2. Unity Ads bidding.

Then test AppLovin or Mintegral if fill or yield remains weak. Google officially lists Meta, Unity, AppLovin and Mintegral among supported bidding sources; each may require partnership, SDK and mapping. [AdMob bidding sources](https://support.google.com/admob/answer/11555701), [Flutter mediation sources](https://developers.google.com/admob/flutter/choose-networks)

Unity’s Flutter adapter supports banner, interstitial and rewarded formats; waterfall support ended in January 2026, so use bidding. [Unity mediation for Flutter](https://developers.google.com/admob/flutter/mediation/unity)

Each adapter requires:

- Consent propagation.
- Privacy/Data Safety review.
- Binary-size and startup profiling.
- Ad Inspector validation.
- Country/format A/B measurement.

### Planning eCPM

No public source can promise Mafia Master’s yield. Use conservative planning ranges:

| Market | Rewarded | Interstitial/app-open | Banner |
|---|---:|---:|---:|
| Egypt-heavy traffic | $1.25–$2.50 | $0.60–$1.25 | $0.05–$0.20 |
| Gulf traffic | $4–$10 | $2–$5 | $0.20–$0.80 |

An anecdotal Egypt/MENA report places rewarded around $1.5–$2.5 and interstitial around $0.7–$1.2; treat that as directional, not a forecast. [Egypt/MENA publisher discussion](https://www.reddit.com/r/admob/comments/1nurhxq/30000_active_users_daily_each_user_views_one/)

## F. Local pricing and payment friction

Google Play Billing is mandatory for digital goods offered inside the Play-distributed Android app unless the app is enrolled in a qualifying regional program. The Android build must not link or steer Egyptian users to InstaPay, Vodafone Cash or a web checkout. [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)

Therefore:

- Android: Play Billing only; `transfer_enabled_android=false`.
- Web: InstaPay/Vodafone Cash manual transfer is acceptable.
- Cross-platform ownership may recognize web purchases after account linking, but the Play app must not advertise the external purchase route.
- Gulf Android: Play Billing localized prices.
- Web Egypt: require recoverable account, show review SLA and exact sender/proof requirements.
- At scale, replace manual review with a licensed PSP/gateway supporting Egyptian wallets/cards/Fawry-like channels. That belongs in 1.2 after commercial onboarding, not improvised payment parsing.

Enroll the developer account in the applicable Play service-fee tier. Google currently documents 15% for the first $1M for enrolled developers and 15% for subscriptions, subject to current regional programs. [Google Play service fees](https://support.google.com/googleplay/android-developer/answer/112622)

## G. Twelve-month model

### Base assumptions

- MAU = 3 × DAU.
- Egypt-heavy traffic with a minority Gulf share.
- Ads ARPDAU: $0.0045:
  - 1.5 rewarded impressions/day around $2 blended eCPM.
  - 0.5 full-screen impressions/day around $1.20.
  - Five banner impressions/day around $0.12.
- Season Pass: 2% MAU conversion, $2.40 realized gross average price.
- Other IAP: 1% MAU buyers/month, $3 ARPPU.
- Membership: 0.5% MAU, $1.60 realized monthly price.
- Constant DAU; no organic growth.
- IAP owner proceeds estimated after 15% Play fee and 3% refunds.
- Ad revenue is modeled as publisher revenue.
- Hosting, support, tax and creator spend excluded.

| DAU | Ads/month | Pass/month | Other IAP/month | Membership/month | Gross/month | Gross/year | Approx. owner proceeds/year |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1,000 | $135 | $144 | $90 | $24 | $393 | $4,716 | ~$4,170 |
| 10,000 | $1,350 | $1,440 | $900 | $240 | $3,930 | $47,160 | ~$41,700 |
| 50,000 | $6,750 | $7,200 | $4,500 | $1,200 | $19,650 | $235,800 | ~$208,600 |

This is a model, not a promise. A weak-fill/low-conversion case can be roughly half; strong Gulf mix and good catalogue execution can approach twice the base. If Membership starts in month four, subtract about 25% of its first-year contribution.

### Top five levers by expected lift ÷ effort

1. **Correct pack value + Starter Bundle** — S/M effort; potentially 30–80% IAP lift from the current weak baseline.
2. **Season Pass** — M effort; likely the largest new IAP line.
3. **Localized pricing and storefront funnel tests** — S effort; 15–30% IAP improvement.
4. **A deeper premium/coin catalogue with regular rotation** — M effort; 25–50% IAP lift if content quality holds.
5. **Mediation after traffic is measurable** — M effort; typically target 10–25% ad-yield lift, subject to actual Egypt/Gulf demand.

Membership can become a top-five lever at ≥10,000 DAU, but its ongoing content obligation makes its initial lift-to-effort weaker.

## H. What not to do

- No pay-to-win, additional votes, role weighting, clue advantages or matchmaking priority.
- No payment to repair streaks or prevent loss.
- No paid Daily Case attempts.
- No random paid chests, loot boxes or gacha. Play has required odds disclosure for loot boxes, but disclosure would not solve the trust, minors or cultural-fit problems here. [Play policy announcement on loot-box odds](https://support.google.com/googleplay/android-developer/answer/14554978)
- No cash-out, player trading or transferable currency.
- No fake scarcity, reset countdowns or “only three left.”
- No guilt copy aimed at non-payers.
- No app-open ad on first launch.
- No ads during any private/live match phase.
- No premium character reaction tied to a current hidden role.
- No Android steering to external digital-payment methods.
- No subscription until sustained monthly value is operationally guaranteed.

# 3. Changes to Rounds 1–6 for the revenue goal

1. Reverse the earlier “no premium track” decision: ship a cosmetics-only Season Zero Pass in 1.1.
2. Reconfigure inactive coin packs before activation; their current amounts are commercially nonviable.
3. Expand new earnable catalogue prices while grandfathering legacy catalogue prices.
4. Add direct premium cosmetics alongside earnable cosmetics; do not introduce a second premium currency.
5. Keep Match Awards non-economic.
6. Launch automatic ads more conservatively than the schema maximum. Retention compounds revenue; pre-match and pre-deal ads are false optimization.
7. Add complete commerce/ad funnel metrics to the privacy-safe aggregate system.
8. Schedule Council Membership for 1.2 only after three months of content are already produced.
9. Add purchase/refund/restoration gates to rollout and operations.
10. Rewrite the current privacy and ad disclosures before any monetization flag is enabled.

The normalized product plan becomes sign-off ready only after its historical references are eliminated and the revenue decisions above are either incorporated or explicitly rejected.
--- end report ---
