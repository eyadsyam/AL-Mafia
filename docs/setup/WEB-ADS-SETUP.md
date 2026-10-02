# Web ads setup (release 1.1)

The migrations `20260930000900_web_ads.sql`, `20261001000200_web_ads_provider.sql` and `20261001000400_web_ads_banner_slot.sql` add the web-only switches. The release enables them with `supabase/operations/20261001_enable_web_ads.sql`: provider `adsense`, one break per completed match, app-open on, and banners on. `WebAdRules` rejects private phases and Quiet Pass. House creatives fill every eligible slot when AdSense has no fill, is blocked, or is not yet approved.

## How the pieces fit

- `web/index.html` carries, in `<head>`, the static AdSense site-verification tags (`<meta name="google-adsense-account">` and the `adsbygoogle.js?client=` script) and one bridge script.
- **Display banner** (`mafiaBannerShow` / `mafiaBannerHide`): a plain AdSense display unit. It needs only an approved site and a display slot id. It does not depend on H5. The unit is a fixed size (728x90, 320x100, 468x60 or 320x50, whichever fits the reserved slot, never larger), placed exactly over the slot Flutter reserved (`WebAdTokens.bannerHeight`, 90 px, inside SafeArea). The house creative stays visible until the unit's `data-ad-status` becomes `filled`; a late fill switches it on, and the overlay is inert (hidden, no pointer events) until then.
- **Interstitial breaks** (`mafiaH5Break`): the H5 Games `adBreak` API, used only between matches. Needs H5 Games Ads approval; without it every break reports no fill and Flutter shows the house break. Flutter holds a plain screen while Google decides (bounded by `WebAdTokens.googleBreakTimeout`), shows house art only after no fill, and ignores a late Google result.
- Only the top-most Flutter banner owns the single page element (`WebBannerController`); a screen opened over another hands it over and gives it back.
- Pacing: every completed match and app open breaks; entering local or online adds a break at most once per `WebAdTokens.minBreakGap` (90 s), so back-navigation cannot chain breaks.

## When the new AdSense account exists: what to change

The owner creates or upgrades a full AdSense account, adds `saidalmafia.com` under Sites and gets it approved. Then:

1. **Publisher id** (`ca-pub-XXXXXXXXXXXXXXXX` / `pub-XXXXXXXXXXXXXXXX`). Change it in exactly these places; `node --test tool/web_publisher_consistency.test.mjs` fails if any disagree:
   - `web/index.html`: the two adjacent lines at the top of `<head>` (the `google-adsense-account` meta and the `adsbygoogle.js?client=` script). The JS bridge reads the id back from the meta tag.
   - `lib/ui/economy/web_ads.dart`: the `defaultValue` of `WEB_ADSENSE_CLIENT` (or pass `--dart-define=WEB_ADSENSE_CLIENT=...` at build; keep it equal to the meta tag).
   - `web/ads.txt` and `web/app-ads.txt`: `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`. AdSense shows this exact line under Sites > ads.txt.
2. **Banner slot id.** In AdSense create a **Display ad** unit (fixed size is fine; do not rely on responsive or auto sizing) and copy its `data-ad-slot` number (5 to 20 digits). Preferred, no rebuild:
   ```sql
   update public.economy_config set web_ads_banner_slot = '1234567890' where id = true;
   ```
   Fallback, needs a rebuild: `--dart-define=WEB_ADSENSE_BANNER_SLOT=1234567890`. A slot from the server wins over the define. To go back to the define, set the column to `null`.
3. **AdSense site settings.** Turn **Auto ads off** for `saidalmafia.com`: this game draws its own layout and must never get overlay ads over a private phase. Only the manual display unit and the H5 breaks should run. Keep consent messaging (the EEA/UK/CH form) enabled.
4. **Verify**: AdSense > Sites > saidalmafia.com > Verify. Crawlable pages for review: `/how-to-play/`, `/roles/`, `/about/`, `/privacy/` (listed in `sitemap.xml`; `robots.txt` admits `Mediapartners-Google`).
5. **H5 Games Ads** (optional, for Google interstitial breaks): apply from the same account. Until approved, breaks use the house creative.
6. Deploy the web build and the migration only when the owner says so.

The publisher line is served at `https://saidalmafia.com/ads.txt`.

Reward payouts stay disabled on browser H5 ads. Google's H5 Ad Placement API exposes `adViewed` to page JavaScript, but does not document a signed server-to-server proof equivalent to AdMob SSV. A claim plus a short-lived token minted from that browser callback would remain forgeable. The existing Android reward path still requires signed AdMob SSV.

References: https://developers.google.com/ad-placement/apis and https://developers.google.com/admob/android/ssv
