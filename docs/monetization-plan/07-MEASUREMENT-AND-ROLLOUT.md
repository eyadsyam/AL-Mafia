# Measurement, business model and rollout

## Observed baseline versus goals

Chrome's AdMob dashboard, last 7 days compared with previous 7: estimated revenue **EGP 0.92** (higher precision tooltip 0.922), requests **291**, impressions **32**, match rate **46.39%**, eCPM **EGP 28.80**. Yesterday tooltip EGP 0.081; month-to-date EGP 0.922; previous month zero. Dashboard timezone/exact date boundaries, unique users and production/test device mix were not supplied by this view. This very small sample is not a stable 28-day business baseline.

Derived for diagnosis only: 32/291 = 11.00% request-to-impression rate; approximately 135 matched requests from the rounded match rate, implying about 23.7% matched-to-impression rate if denominator definitions align. Preloads that are never eligible to show can explain part of the gap. Do not force ads to consume every matched request. Instrument lifecycle reasons and app approval first.

20× current seven-day estimated revenue is approximately **EGP 18.44 per comparable seven-day period**, not a large sustainable business by itself. At unchanged EGP 28.80 eCPM, 640 impressions give EGP 18.432. This arithmetic is not a forecast: real traffic mix, approvals, show rate and pricing change. Track absolute net contribution alongside the multiplier, and never compare a day with a month.

## Equations

For each format/country/platform cohort f:

`impressions_f = DAU × active_days × eligible_opportunities_per_user_day_f × consent_eligibility_f × match_rate_f × show_rate_f`

For rewarded, opportunities additionally include explicit opt-in rate and inventory availability; cap maximums are not average impressions. Measured eCPM already represents revenue per served impression, so do not multiply fill/show twice if using observed impressions.

`estimated_ad_revenue = Σ(impressions_f × eCPM_f / 1000)`

`net_contribution = finalized_ad_revenue + store_net_receipts + web_net_receipts - refunds_not_already_deducted - hosting - realtime/voice - support_variable_cost - acquisition_spend`

`D30_LTV = cumulative net contribution of a newly acquired cohort / acquired users in that cohort`

Use actual net store receipts to avoid double-deducting fees. Keep currency amounts separate until converted with a dated sourced rate. No taxes, store fee percentages, eCPM floors or paid marketing budgets are invented here.

`revenue-scenarios.csv` uses normalized revenue factors; these are **illustrative combinations**, not observed uplifts. The 20× case uses 5× active users × 2× healthy eligible visits × 1.25× served impressions/opportunity × 1.6× yield. Each factor requires independent evidence and can move down. Adding units has no independent multiplier.

## Event contract

Preserve existing F13 counters. New typed events:

| Event | Required finite fields / source |
|---|---|
| ad_opportunity | placement, format, platform, public_surface, config_version, decision enum; client |
| ad_load_result | attempt_id UUID, placement, result enum(loaded/no_fill/network/timeout/cancelled), latency bucket; client |
| ad_impression | impression_id UUID, attempt_id, placement, format, sdk_response_id hash if present; SDK |
| ad_dismissed | impression_id, placement, duration bucket; SDK |
| ad_paid_estimate | impression_id, placement, value_micros decimal-string, ISO currency, precision enum; SDK, untrusted estimate |
| reward_claim_created / settled / expired | scheme, placement, claim ID restricted to server receipt store, amount, settlement latency; server |
| match_started / completed | server-confirmed aggregate source for online; separate local-only counter; no role/seat metadata |
| public_session_active | platform, active_minutes bucket, app_version, assigned cohort; client, foreground only |
| purchase_verified / refunded | product ID, net receipt reference restricted server-side; purchase verification service |

`monetization_metrics` accepts authenticated body `{schemaVersion:1, batchId, events:[...]}`; <=20 events, <=16 KB, no arbitrary keys; max 120 accepted events/account/hour, excess dropped without UI error. Batch every 30s or 20 items only outside a match, queue max 100, expire 24h; consent and metric capability required. Network failures drop after bounded retries (1s/5s/30s, max three). Never background-loop to flush ads telemetry.

DB `monetization_event_receipts`: unique(subject_hash,event_id), ingestion day, typed payload columns, retained 7 days for diagnosis. `monetization_daily`: date/placement/platform/currency/config_version/experiment_variant buckets with event totals and revenue_micros sums. Client paid events flagged untrusted; they must not change wallets, payouts or daily ad eligibility. Exported AdMob finalized reports are finance source of truth; reconciliation never treats client totals as earned cash.

Cohorts: new opt-in `product_cohort_members` service-role-only table keyed by user ID (required for deletion), acquisition_date UTC, allowlisted acquisition bucket, experiment assignment and last_active_day. Derive D1/D7/D30 activity from public app activity/verified completion, not ad views. Retain 90 days then aggregate/delete identifiers. Stable cohort assignment uses server HMAC(userID + experimentID) modulo buckets; do not send the underlying identity/salt to a vendor. Existing daily salted receipts cannot do this longitudinal job; do not claim anonymous daily counts are retention. Update privacy wording before enabling longitudinal measurement.

## Dashboard definitions

North-star: weekly retained groups completing two or more matches, plus D30 net contribution/user. Group definition must not expose roster: server-only daily cohort summaries; initial launch uses returning-player completion until durable group semantics are implemented. Do not invent a stable group count from room IDs.

Activation: first-open→first completion, time to first playable action. Retention: D1/D7/D30 return and completed match; denominator is original acquisition cohort. Monetization: revenue/DAU, estimated yield by placement, rewarded opt-in and verified settlement, match/show rates, Quiet Pass conversion/refunds. Guardrails: match completion, join latency, crashes, p95 frame time, loading latency, ad complaints and deletion/opt-out rates.

Internal UI shows exact periods, sample sizes, estimated/finalized label and currency. Keep admin reports behind existing admin authorization; never query raw financial or cohort tables from public clients.

## Rollout and experiments

0. Fix approval/source risks and regression first. Gather 28 days; observed 32 impressions cannot power a revenue/retention A/B conclusion.
1. Staging test IDs with v4 all-off. Reward SSV old/new, consent, no-fill, active-match exclusions, entitlement and rollback must pass.
2. Production dry instrumentation with new units off for 7 days. Verify console reconciliation, exclude test/dev traffic and document expected provider reporting delay.
3. Reward v4 at 5% eligible accounts for 48h, then 25% for 7 complete days; retain legacy group, never migrate claims in flight. At each step inspect pending reward age/duplicates before expansion.
4. Automatic public inventory 5% then 25% then 50%; minimum 7 complete days per step. Progress only when stable D7 cohort data exists. Keep 10% persistent holdout through day 30, then decide 100%.
5. Native vs banner experiment on History/Vault only, assigned by account, never both. Same number of display slots; only format changes. Other variables (reward amounts, acquisition mix, pricing) frozen.

Stop immediately on role leakage, duplicate/missing earned credits, consent bypass, account restriction, pay entitlement ignored, or gameplay-blocking ad. Disable affected switch; keep SSV settlement running. Operational rollback triggers: crash-free sessions <99.5%; first-match completion drops >3 percentage points; D7 drops >2 points; p95 interaction latency worsens >20%; pending rewards >1% beyond 15min with >=100 earned callbacks. For low samples, inspect every error and hold rollout rather than declare statistical safety. These are operating guardrails, not proofs of causality.

Promotion test: preregister one primary metric, two-sided alpha .05, power .80, MDE +10% D30 net contribution, D7 noninferiority margin 2pp. Compute required sample from collected baseline variance before exposing cohort; cluster by account, analyze intent-to-treat. Do not repeatedly peek and stop for a positive revenue day. If sample is insufficient after 28 days, report inconclusive and leave density unchanged.

Mediation/floors become a separate later experiment only after approval and sufficient per-format/country impressions. Revenue growth driven by returning satisfied groups is preferable to growing request counts that never safely show.
