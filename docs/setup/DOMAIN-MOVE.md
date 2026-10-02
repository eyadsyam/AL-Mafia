# Domain move: saidalmafia.com

The canonical player link is `https://saidalmafia.com`. The existing `almafia.vercel.app` links continue to open the same app. Cloudflare hosting is already configured; preserve `wrangler.jsonc`, `web/_headers`, `web/.assetsignore`, and `web/vercel.json`.

Before enabling production traffic, the reviewer should:

1. Set Supabase Auth Site URL to `https://saidalmafia.com` and add `https://saidalmafia.com/**` to redirect URLs. Keep the Vercel and app callback redirect URLs while old links and clients are active.
2. Add `saidalmafia.com` to Firebase Authentication authorized domains. Check that web push and the service worker use the production Firebase project.
3. Add and verify `saidalmafia.com` in AdSense, then apply for H5 Games Ads. Confirm `https://saidalmafia.com/ads.txt` serves the publisher line.
4. Set AdMob's app-ads.txt website URL to `https://saidalmafia.com` and serve the required app-ads.txt file when AdMob supplies its exact publisher line.
5. Update the Play Store listing website to `https://saidalmafia.com`.
6. Publish identical `/.well-known/assetlinks.json` from both domains and verify each host against the Play signing certificate. The Android manifest claims both.
7. Set Edge Function `PUBLIC_WEB_ORIGIN=https://saidalmafia.com` when deploying push functions, so notification links match the canonical site.
