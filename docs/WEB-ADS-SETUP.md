# Web ads setup (release 1.1)

The migration `20260930000900_web_ads.sql` adds web-only switches. They default to `web_ads_enabled=false`, `web_ads_provider=house`, one interstitial per completed match, app-open on, and banners on. The web pacing policy is in `WebAdRules`; it rejects every private phase and Quiet Pass. These settings are preparatory and do not activate H5 ads in this worktree.

The owner must verify `saidalmafia.com` in AdSense, apply for H5 Games Ads, and get the account approved before setting `web_ads_provider=adsense_h5` and `web_ads_enabled=true`. Publish the exact publisher line at `https://saidalmafia.com/ads.txt`. `WEB_ADSENSE_CLIENT` is the intended web build define.

Reward payouts must stay disabled on browser H5 ads. Google's H5 Ad Placement API exposes `adViewed` to page JavaScript, but does not document a signed server-to-server proof equivalent to AdMob SSV. A claim plus a short-lived token minted from that browser callback would remain forgeable. The existing mobile reward path settles only a signed AdMob callback. Implement an independently verifiable provider callback before enabling web coin rewards; keep the same server caps and claim ledgers when one is available.

References: https://developers.google.com/ad-placement/apis and https://developers.google.com/admob/android/ssv
