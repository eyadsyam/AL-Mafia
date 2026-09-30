# Web ads setup (release 1.1)

The migrations `20260930000900_web_ads.sql` and `20261001000100_web_ads_provider.sql` add web-only switches. The release enables them with `supabase/operations/20261001_enable_web_ads.sql`: provider `adsense`, one break per completed match, app-open on, and banners on. `WebAdRules` rejects private phases and Quiet Pass. House creatives fill every eligible slot when AdSense has no fill, is blocked, or is not yet approved.

The owner must verify `saidalmafia.com` in AdSense and apply for H5 Games Ads. The H5 break bridge loads `adsbygoogle.js` only when the provider is `adsense`; it calls `adConfig` and `adBreak`, then uses the house creative when Google reports no displayed ad. `WEB_ADSENSE_CLIENT` defaults to `ca-pub-9179063936085117`. A Google display banner additionally needs the AdSense-issued `WEB_ADSENSE_BANNER_SLOT` build define; until that slot exists, the persistent Flutter house banner fills Home, lobby, and results. The publisher line is at `https://saidalmafia.com/ads.txt`.

Reward payouts stay disabled on browser H5 ads. Google's H5 Ad Placement API exposes `adViewed` to page JavaScript, but does not document a signed server-to-server proof equivalent to AdMob SSV. A claim plus a short-lived token minted from that browser callback would remain forgeable. The existing Android reward path still requires signed AdMob SSV.

References: https://developers.google.com/ad-placement/apis and https://developers.google.com/admob/android/ssv
