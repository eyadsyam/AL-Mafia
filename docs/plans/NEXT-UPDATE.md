# Next update (after 1.6.0 build 22)

Live today: 1.6.0 (22) on Play production since 2026-11-11; web on saidalmafia.com.
Everything below is committed and waits for the next planned release (no extra
version for small fixes, owner rule). Nothing here is built or uploaded yet.

## In the app (needs the next Android build)

| Change | Commit / files |
|---|---|
| Home banner no longer misses a capabilities read that starts after its first frame | 73ea9d4c |
| Microphone asked on the tap that enters an online room, not at launch (Play audio policy) | 54b060b1 |
| Microphone closes while the app is off screen; the phase decides again on return | 41aca80f |
| Rewarded ads: the load no longer waits on itself (every tap without a ready ad used to sit out the whole tap budget); failed preloads retry at 15 s, 30 s, 60 s, then 120 s, up to 6 per placement per session; an offer warms its ad on its first frame; a tap joins the load already in flight | lib/platform/monetization/rewarded_ads_mobile.dart, lib/ui/economy/ad_extras.dart |
| «العب مع ناس دلوقتي»: one tap seats the player in a filling public room or opens one (server `quick_match`, deployed since October, never called before) | lib/ui/screens/online/{online_entry_screen,online_session}.dart |
| Crash reporting: Firebase Crashlytics on Android only, off in debug, no custom keys or logs | lib/platform/crash_reporting*.dart, lib/main.dart, android/ gradle, pubspec |

## Already live on the server (no build needed)

- Play products: all five were left inactive by the 2026-09-28 rollback, so the
  Google Play buy tab never appeared. Switched back on 2026-11-16.
- Owner alerts: no longer held back by the player-push switch; one reminder a day
  at 09:00 Cairo while a report waits (20261116000100_owner_alerts).

## Release checklist for this update

1. Play Console › App content › Data safety: add **Crash logs** and
   **Diagnostics** (App info and performance), collected, not shared, required,
   purpose App functionality + Analytics; processed by Firebase Crashlytics.
   Privacy page (web/privacy) gets the same line. Do this in the same release
   as the build that carries Crashlytics, not before.
2. Data safety deletion question: the web deletion URL is
   https://saidalmafia.com/delete-data/ (page live).
3. After rollout: read Crashlytics for the first crashes, AdMob for the rewarded
   match rate, and the usage page for quick-match rooms.
4. The test-ads build (`TEST_ADS_SUFFIX=true`) skips the Google Services plugin
   (its package is not in google-services.json) and keeps the hand-written
   Firebase values; it has no Crashlytics mapping upload.
