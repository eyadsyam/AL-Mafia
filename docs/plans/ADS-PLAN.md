# Ads plan — more revenue, less annoyance (draft for the owner, 2026-10-29)

## Today (live economy_config, build 18)
- Banner: `banner_enabled = false` since 2026-10-29 (owner: too big, and an empty reserved box shows when no ad fills; AdMob store link only just done). Large anchored adaptive, 8 per-screen units + a shell unit.
- Native cards in menu lists: 7 placements (home, history, online hub, vault, council, characters, stories). Zero-size until filled.
- App-open: on, up to 10/day, 20 min gap, only after 15 min away.
- Interstitials: on, max 3/day, 10 min gap, first match free (grace 1), 2 min quiet after a rewarded ad. Moments: pre-match (before the deal), pass-and-play result, session (after 3 min of menu browsing).
- All full-screen: max 60/day, 60 s gap.
- Rewarded (opt-in): daily ad (25 coins), steps, ad extras, online reward button, offline result offers.
- Reality: 14 rewarded credits ever; AdMob was on limited serving until today's store link. Real fill, eCPM and impressions per format are UNKNOWN to us (AdMob report needed from the owner; Claude is blocked from AdMob).

## Principles
1. Never inside a match: no ad on role, night, day, discussion, vote or pass-the-phone screens (already enforced by tests).
2. Full-screen ads only at natural breaks the player already waits at: after a match result, and before a new deal. Revenue grows with matches played, not with menu taps.
3. No empty boxes: a banner is drawn only after an ad has filled, and its space is kept only while it is filled.
4. Small and quiet in menus: one ad per screen at most.
5. Rewarded ads are the best-liked and best-paid: more good moments to choose them, never forced.
6. Every change is a server number where possible, so we tune without a new build.

## Proposed changes
A. **Per-match interstitials instead of per-day.** One interstitial at the match break (after the result, or before the next deal, never both), every match after the first. Cap 3 per hour and 12 per day, gap 4 min. Server: `interstitial_max_per_day` 3→12, `interstitial_gap_seconds` 600→240; client: an hourly cap and "one per match" rule (next build).
B. **Drop the menu session interstitial.** An ad that fires while a player is just browsing menus is the most annoying and earns little. Server: `session_interstitial_enabled` → false (live switch).
C. **App-open softer.** Cold start only, max 2/day. Server: `app_open_max_per_day` 10→2, `app_open_resume_after_seconds` 900→3600 (live).
D. **Banner back, smaller.** Standard anchored adaptive (about 50–60 dp, not the large one), only on waiting screens (online lobby, online hub, history), collapsed until filled. Next build; then `banner_enabled` back on once AdMob shows fill.
E. **Native cards: one per screen, below the fold.** Never the first card a player sees.
F. **Rewarded moments.** Add opt-in offers at natural highs: after a loss («ضاعف كوينز الماتش»), after a win streak, before a paid tool (try once by ad). Rewards stay as they are (owner rule): we add moments, not amounts.
G. **Measure.** Turn on aggregate counts for ad shown/completed per format (metrics_enabled + new events), plus the owner's AdMob report weekly. Decide on numbers after 2 weeks.

## Order
1. Live now with the owner's word: B and C (switches), A's server half.
2. Next build: A's client half, D, E, F, G's events.
3. After 2 weeks of numbers: tune caps.

## Owner questions
- OK to drop the menu session interstitial (B) and cut app-open to 2/day (C)?
- Interstitial: after the result, or before the next deal?
- Send the AdMob report (last 7 days: impressions, eCPM by format) once a week?
