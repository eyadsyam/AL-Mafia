# Implementation contract — Ads v4

This is a design, not an applied migration. Keep one engine and two transports. No ad SDK, revenue, random monetization decision or wall clock enters `lib/engine/**`. Derive public eligibility from transport/session state; widgets must not branch on `isOnline` to select ad behavior. Never inspect role, night action or secret result for monetization.

## File ownership

| Path | Action |
|---|---|
| `lib/core/theme/design_tokens.dart` | Make the canonical token file required by AGENTS.md. Move current `lib/ui/theme/design_tokens.dart` definitions here unchanged, fix its relative `app_colors.dart` import, and leave the old file as `export '../../core/theme/design_tokens.dart';`. Then add new presentation sizes/durations only here. Test import compatibility before ad changes. |
| `lib/platform/monetization/ad_placement_registry.dart` (new) | Typed 24-placement IDs, format/surface, nullable unit ID, config validation. IDs only from verified mapping. Unsupported platforms return disabled. |
| `lib/platform/monetization/ad_policy.dart` (new) | Pure `decideAd(context, rules, ledger, now)`; closed verdict enum. No Flutter/SDK/I/O. |
| `lib/platform/monetization/ad_session.dart` (new) | Single load/show ownership and fullscreen mutex, lifecycle cancellation and bounded load queue. |
| `lib/platform/monetization/ad_telemetry.dart` (new) | Typed lifecycle and estimated paid-event payloads; no arbitrary metadata map. |
| Existing `interstitial_policy.dart`, `app_open_policy.dart` | Delegate shared pacing to new policy, retain compatibility wrappers until call sites migrate. Do not keep conflicting budget implementations. |
| Existing `rewarded_ads_mobile.dart`, `ad_formats.dart`, `interstitial_ads.dart` | Placement-aware load/show interfaces, SDK callbacks, native adapter. Preserve stub imports for web; explicitly Android-only until native iOS is separately approved. |
| Existing `app_open_gate.dart`, `interstitial_coordinator.dart`, `ad_reward_flow.dart`, `ad_extras.dart`, `rewarded_reward_button.dart` | Use one session and explicit placement. Match step passes double vs triple; extra passes spin vs coffer vs swap. |
| `lib/ui/economy/public_ad_slot.dart` (new) | Banner/native exclusive slot, content-ready + route + entitlement gating. |
| Existing `economy_capabilities.dart`, `web_ad_rules.dart`, `web_ads.dart`, web bridge/browser/controller | Versioned config, separate H5 and editorial display eligibility, remove canvas display overlay usage. |
| `supabase/functions/_shared/ad_rewards.ts`, `admob_ssv/index.ts`, `economy_actions.ts` | Versioned registry resolution and bound claim, existing verifier remains mandatory. |
| New migration `20261007001000_ads_v4_registry.sql` | Registry, reward binding/budget tables and restricted RPCs. If timestamp exists when execution starts, choose the next unused timestamp and record the change. Never edit applied migrations. |
| New migration `20261007001100_monetization_metrics.sql` | Restricted typed telemetry and privacy-preserving cohort data defined below. |
| `supabase/functions/monetization_metrics/index.ts` (new) | Authenticated bounded ingestion; no wallet mutations. |

## Policy inputs and decision order

`AdContext`: placementId, platform, publicSurface enum, routeGeneration integer, foreground bool, contentReady bool, hasActiveMatchOrRoom bool, hasPendingRejoin bool, purchaseOrAuthActive bool, entitlementState enum(unknown/free/adFree), consentCanRequest bool, onboardingDone bool, completedMatches integer, launches integer, loadedAt nullable integer, userOptIn bool, eligibleClaim bool. No player/role/game data fields.

Order: disabled/invalid config → unsupported platform → nonforeground → private/active-game/rejoin → modal/purchase/auth → unknown entitlement → adFree automatic → onboarding/grace → consent → placement/exit/opt-in rules → cap/gap → mutex → ready/expiry → show. Return one stable reason. Rewarded is also excluded throughout an active match, even if the player is dead.

Use `InterstitialLedger` storage as migration source for automatic counters; maintain lastAnyFullscreenDismissMs, lastRewardDismissMs, shown timestamps in last rolling hour, UTC day, automatic/day, app-open/day, highWaterMs. Persist on actual shown/dismissed callbacks. If app dies mid-ad, retain the shown cap and conservative cooldown; do not clear counters on restart. Bound timestamp list to counts for the active window. Device clock rollback cannot open a fresh day. Forward-clock abuse cannot grant server rewards.

Config TTL: 24h for placement enablement, revalidated on foreground when no match is active; expired/missing enablement fails closed. Ads must not initiate anonymous sign-in just to render. Entitlement uncertainty disables automatic ads; server-verified ad-free entitlement survives ordinary offline startup. Logout discards ad caches and identity-bound claims without changing global device pacing.

## Mobile adapter

`load(placementId, intentToken)` and `show(placementId, intentToken, claimBinding?)` must use the exact same registry revision/unit. Do not reuse a rewarded object across claim intents. Cache at most one rewarded and one automatic fullscreen; display owns its own single visible object and loads count toward a shared maximum of two. Dispose after show/failure or consent/config/identity change.

Attach SDK impression, dismissal, error and paid callbacks to every format. Read actual installed plugin signatures during M03; do not upgrade the package to match an example. Native ads use the installed SDK's supported template path with visible attribution/AdChoices, no Flutter overlay that intercepts SDK clicks. If the installed plugin cannot meet the template requirements, M06 stays blocked rather than inventing a factory.

No callback waits on telemetry or wallet polling before closing an ad. Use existing bounded `reward_poll.dart` flow, then a persistent pending indicator for late SSV; resuming re-reads server claim state. Audio and voice pause/restore around all fullscreens using existing audio and voice session boundaries.

## Registry and SSV schema

All below tables enable RLS and revoke direct anon/authenticated table access. Service role alone writes; client receives a sanitized placement map via capabilities. Admin updates require authenticated admin authorization, never a client-supplied admin flag.

`ad_unit_registry`: placement_id text + revision integer composite PK; platform enum; format enum; unit_id text; numeric_unit_id text; enabled boolean default false; reward_scheme nullable enum(v1/step/daily/extra); created_at. Partial unique index on (platform,unit_id) where enabled; separate partial unique index on placement_id where enabled. Retain disabled historical revisions for bound claims. Allow legacy aliases explicitly in a separate `ad_unit_legacy_aliases` table keyed by numeric ID/scheme; do not use wildcard publisher matching.

`ad_claim_bindings`: claim_id UUID + scheme composite PK; user_id UUID; placement_id/revision FK; expected_numeric_unit_id text; expected_reward_item text; expected_sdk_reward_amount positive integer; created_at; show_by; settlement_until; reservation_day; state enum(reserved/shown/settled/expired). Binding is immutable. No client write access. FK to heterogeneous old claim tables is enforced by the create RPC and existing scheme-specific commit, not an invalid single FK.

`ad_reward_daily_budget`: (user_id, economy_day) PK; settled count, reserved count. Determine economy_day with existing `economy_today()` so resets match the current product, not device time. A single transaction locks budget row, checks eligibility and daily cap, creates/reuses the existing scheme claim and binding, reserves one slot and returns the complete disclosure + unit/placement/revision. A repeat request returns the same claim, amount and reservation. Expires unshown reservation after 15 minutes; settlement evidence is retained for 30 days. Release expired reservations idempotently. Do not drop old valid claims to force the new cap.

New `economy` action `ad_claim_v4`: body `{requestId, placementId, roomId?, slot?}`. Allowed fields depend on the six-placement enum. Existing authenticated subject supplies identity. Match room eligibility and base B are checked by server; client never sends reward amount. Response `{claimId, customData, placementId, registryRevision, unitId, showBy, state, reward:{kind,amount,baseAmount?,displayTotal?,odds?}}`. Numeric IDs/amounts follow existing safe JSON integer/string conventions.

Custom data for newly bound claims: `v4:<scheme>:<uuid>`. Keep old `<uuid>`, `s2:`, `d1:`, `x1:` routes. Verified callback processing: Google signature/raw query verification → parse strict prefix → find immutable claim/binding → match signed user, numeric unit, reward item and SDK reward amount → existing scheme commit inside transaction → settle budget/binding once. Actual coins always come from stored claim, not SDK amount. Per-unit console reward is `verified_view`, quantity 1; app disclosure comes from server. Record the exact signed Google field and encoding during integration, not guessed sample strings.

Unique transaction IDs remain global across every unit and scheme. Identical replay returns success without duplicate payment; same transaction with different claim is rejected. Unknown keys/unavailable verification keys retry as existing 503 behavior; malformed/signature errors are permanent. Unit kill switch stops NEW claims/loads, but genuine already-bound callbacks remain payable. A valid late callback for an ad begun before show_by pays exactly once during settlement retention even if its reservation was released; honor earned reward, flag cap overage in reconciliation and block additional claims that day. Never confiscate rewards because the callback was slow.

Keep legacy configured IDs accepted while legacy builds are supported, minimum 30 days after minimum-version gate removes them. Legacy rewards count in the unified settled budget during migration where possible, but do not reject already-promised claims. Deployment order: additive schema/SSV acceptance → client release with features off → verified console mapping → small rollout. Rollback disables new requests but leaves settlement endpoints running.

## Compatibility and privacy

v3 clients continue receiving existing response keys and existing policy values; v4 is an added `adsV4` block, never a reinterpretation that breaks old clients. Missing v4 means use v3 behavior. In v4 code, once new policy is active, v3 UI hooks must not independently show ads. Kill switches cover automatic, rewarded, display, native, web H5 and all new inventory.

Data deletion includes new user-associated budget/telemetry/cohort rows. Retain only legally/operationally necessary financial receipt records under the existing deletion policy; document retention accurately rather than promising deletion of records that are retained. Store no role, seat, room code, whisper body, raw invite link, email, advertising ID or ad creative content in product telemetry. No third-party analytics vendor is added by this plan.
