# Ads v2 — revenue model, knobs and kill switch (phase 108)

Not a forecast. Every number below is a planning input to be replaced by
measured data from closed testing. Fill rate, eCPM, opt-in and retention in
Egypt are unknown until the units serve real traffic; nothing here promises
income, fill or Google approval.

## 1. The ad set (all Android; the web shows none)

| Format | Trigger | Hard product limits (code + SQL checks) | Server switch |
| --- | --- | --- | --- |
| App-open | Launch screen: cold start, or return after ≥ 4 h away | ≤ 3/day, ≥ 4 h apart, 3 s load budget, 4 h ad expiry; never first launch, before onboarding+terms, into a room/match/pass-and-play/purchase, or right after another ad | `app_open_enabled` (+ `app_open_max_per_day`, `app_open_gap_seconds`, `app_open_resume_after_seconds`) |
| Interstitial | Home from a completed match result | ≤ 3/day, ≥ 10 min apart, ≥ 3 min after a reward, first match exempt | `interstitial_enabled` (+ caps) |
| Banner (anchored adaptive) | Lobby, room list, history, vault, profile edit | Waiting surfaces only (allowlist test); zero height without fill; dropped in background | `banner_enabled` |
| Rewarded — post-match steps | Player's choice after a match | 2 steps, +50% / +50% of base | `ad_steps_enabled` |
| Rewarded — daily vault ad | Player's choice, outside a match | 1/day, fixed +25 | `daily_ad_enabled` |
| Rewarded — extras | Player's choice, outside a match | spin / coffer / swap, each 1/day | `ad_extras_enabled` (spin+coffer also need `daily_enabled`; swap needs `council_contracts_enabled`) |

The Quiet Pass (`remove_interruptions`) removes app-open, interstitial and
banners. Rewarded ads stay available to everyone.

## 2. Per-DAU impression model

For one day, per daily active user (DAU), after consent, fill, caps and
Quiet Pass owners are removed:

```
app-open impressions / DAU   = S_launch × P_eligible × F_ao
interstitial impressions/DAU = M × P_home × P_int_eligible × F_int
banner impressions / DAU     = (T_wait_minutes × 60 / R_refresh) × F_ban × V
rewarded impressions / DAU   = M × (o1 + o1·o2) × F_rw           (post-match)
                             + o_daily × F_rw                     (daily ad)
                             + (o_spin + o_coffer + o_swap) × F_rw (extras)
```

- `S_launch`: eligible launch-screen moments per DAU (cold starts + ≥4 h
  returns), capped by the policy at 3.
- `P_eligible`: share of those moments that pass every rule (not first launch,
  not into a room, not right after another ad, gap met).
- `M`: completed matches per DAU; `P_home`: share of results left via Home.
- `T_wait_minutes`: minutes on banner surfaces per DAU; `R_refresh`: banner
  refresh interval in seconds (set in AdMob, 30–120 s; do not go below
  AdMob's floor); `V`: share of that time the banner is actually on screen.
- `o1`, `o2`: opt-in to step 1 and to step 2 given step 1; `o_*`: daily
  opt-in to each extra; `F_*`: fill rate per format.

Monthly gross ≈ 30 × DAU × Σ(impressions/DAU × eCPM_format) / 1000.

### Worked illustration (made-up inputs, only to show the arithmetic)

1,000 DAU; 2 matches/DAU; `S_launch × P_eligible` = 0.6; `P_home × P_int_eligible` = 0.3;
6 banner minutes at 60 s refresh, V = 0.8; o1 = 0.4, o2 = 0.6; daily ad 0.15;
extras 0.10 each; fills 0.8 (banners 0.9).

- app-open: 0.6 × 0.8 = 0.48 / DAU
- interstitial: 2 × 0.3 × 0.8 = 0.48 / DAU
- banner: 6 × 0.8 × 0.9 = 4.32 / DAU
- rewarded: 2 × (0.4 + 0.24) × 0.8 + 0.15 × 0.8 + 0.30 × 0.8 = 1.38 / DAU

Multiply by *measured* eCPMs per format; do not plug in guesses and present
the result as income. Banners have many impressions and low eCPM; rewarded
has few impressions and the highest eCPM; longer sessions only earn through
banner minutes and more matches, never through idle payouts.

## 3. Knobs (all in `public.economy_config`, one row)

| Column | Default | Allowed | Effect |
| --- | --- | --- | --- |
| `app_open_enabled` | false | bool | App-open on/off |
| `app_open_max_per_day` | 3 | 0–3 | Daily cap per device |
| `app_open_gap_seconds` | 14400 | ≥ 14400 | Gap between app-open ads |
| `app_open_resume_after_seconds` | 14400 | ≥ 14400 | Time away before a return may show one |
| `banner_enabled` | false | bool | Banners on waiting surfaces |
| `ad_extras_enabled` | false | bool | Spin / coffer / swap extras |
| `interstitial_enabled` … | false … | existing | Unchanged (phase 103) |

Clients read these through `economy capabilities → ads`; a missing key (old
server) or a failed read is OFF. A build also needs the unit id compiled in
(`ADMOB_APP_OPEN_ANDROID_ID`, `ADMOB_BANNER_ANDROID_ID`; extras use the
rewarded units) or the placement stays off whatever the server says.

## 4. Recommended starting values (Egypt, closed testing first)

1. Week 1: `banner_enabled = true` only. Measure D1/D7 and matches/DAU against
   the previous week.
2. Week 2: `ad_extras_enabled = true` (needs `daily_enabled`; swap also needs
   contracts). Rewarded-only changes are opt-in and least risky.
3. Week 3: `app_open_enabled = true` with `app_open_max_per_day = 1`; raise to
   2, then 3, only if D1/D7 and first-session completed matches hold.
4. Keep the interstitial at its phase-103 caps; do not raise frequency and add
   app-open in the same week.

## 5. KPIs to watch (per build and per day)

- Retention D1 / D7 (cohort by first-open date), first-session completed match.
- Completed matches per DAU; lobby wait time; post-ad exit rate (session ends
  within 60 s of an automatic ad).
- Ad ARPDAU by format (AdMob reporting ÷ DAU), fill and eCPM per unit, rewarded
  opt-in (step 1, step 2, daily, each extra), SSV latency and failures.
- Quiet Pass conversion and refunds; support reports mentioning ads.

If retention or matches/DAU drop after an ad change, roll that change back
before trying any other placement.

## 6. Kill-switch runbook (seconds, no build)

```sql
-- Everything automatic off (app-open, interstitial, banners):
update public.economy_config set app_open_enabled=false, interstitial_enabled=false,
  banner_enabled=false, updated_at=now();
-- Rewarded extras off (pending claims stay payable by SSV; no new ones):
update public.economy_config set ad_extras_enabled=false, updated_at=now();
-- One format only, e.g. app-open less often:
update public.economy_config set app_open_max_per_day=1, updated_at=now();
```

Clients pick the change up on the next capabilities read (vault open, app
resume after a failed read, next launch). The app-open ad additionally uses
its last remembered answer at launch, so one more launch may still consider
it; set the flag off and it stops after that. For a unit-level emergency
(policy strike, invalid traffic), also pause the unit in AdMob. Never delete a
unit id from a shipped build's defines: remove it only in the next build.
