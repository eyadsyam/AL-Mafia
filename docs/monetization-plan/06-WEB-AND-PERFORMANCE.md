# Adaptive web and performance contract

Target: desktop Chrome/Edge, Android Chrome, iPhone Safari, including installed PWA. Native iOS monetization is a separate program. Do not claim a Chrome device emulation run verifies Safari/WebKit.

## Layout decisions

Add public responsive tokens to canonical `lib/core/theme/design_tokens.dart`: compact below 600 logical px; medium 600–1023; expanded >=1024. Public form content max 480; editorial content 720; store/council/dashboard content max 1120. Horizontal page padding 16/24/32 for compact/medium/expanded; primary hit target >=48. Keep Arabic line-height 1.6, zero letter spacing and app text scale 1.0 per working agreement. Browser zoom must not be blocked.

Add `lib/ui/widgets/adaptive_public_scaffold.dart`: same semantic content and action ordering at every width. One column compact; two columns for content + summary on expanded Store/Council; no empty decorative third column. Forms remain readable-width and centered. Scroll body independently of a bottom action bar; keyboard/safe-area insets must not obscure actions. Short landscape screens scroll, never shrink text to fit.

Use this wrapper on home, mode, online hub, history, profile summary/edit, store, missions and characters. Preserve current Council geometry tests and dedicated table sizing; do not force private role/night screens into a different layout for particular roles. All four role trees, transitions and minimum timings stay identical. Fix private-flow problems only through the common component, never an ad-specific role branch.

## Web advertisement separation

Remove the current ordinary AdSense fixed-position overlay from the Flutter game shell. `WebAdBanner` call sites become no-paid-ad content or disappear; nonblocking house promotion can be a plain internal card, never a compulsory interstitial. Keep the landing/game route URLs and all existing `/join/:code` and `/invite/:code` behavior intact; no domain/path migration is needed.

Editorial AdSense resides in real HTML flow on eligible static pages only. Reserve height before request; one ad below substantive article content; no overlays or ad/CTA overlap. Pages whose content is too short get no ad. Implement `web/editorial_ads.js` shared loader, loaded only on the three eligible pages, with verified publisher/slot map and certified CMP integration. Do not fake CMP consent from localStorage or reuse mobile UMP status on web. Auto ads stay off for the game shell.

For approved H5 game access, use documented H5 flow in existing bridge with a distinct enabled flag, only on a completed-match exit. No AFC unit in a home-made fullscreen. Provider failure/timeout means immediate continuation, not house fullscreen. Callback arrival after intent cancellation cannot reopen a route; ads never pause a live room. Test provider-managed presentation start/end separately from an ordinary JavaScript promise timeout.

## Performance changes

1. Remove onboarding video from service-worker installation precache. Cache only on explicit play/download or after its fetch completes during idle; network failure does not block activation/play. Preserve range-request handling.
2. Namespace SW cache deletion: remove only this app's versioned caches, not every same-origin cache. Network-first shell; immutable hashed assets; bounded media cache (50 MB budget, remove oldest app-owned entry first). Never cache consent responses, ad resources, auth or personal API data.
3. Lazy-load ad SDK/script after eligibility and consent; no 24-unit preloading. No native/banner while match assets or reconnect are loading. Limit in-flight loads as specified in ad contract.
4. Audit `lib/main.dart` awaited work; preserve required local-state loading, defer optional marketing/media/monetization work after first interactive frame. Do not remove needed restore/zero-leakage guards to lower a stopwatch.
5. Lazy image decoding sized to rendered pixels; reuse existing WebP assets and cosmetic cache. Avoid decoding full-resolution card art for tiny store thumbnails. Stop offscreen tickers and media; honor existing reduced-motion support.
6. Verify page visibility pauses display ad activity, media previews, polls and animation. Voice remains governed by room rules; monetization failures never block gameplay.
7. Keep release renderer default until measurements show a justified change. No speculative Wasm/renderer migration or cross-origin isolation that breaks ads/voice to chase a score.

## Acceptance budgets (targets, not measured results)

Test cold/warm loads on fixed network profile: 4 Mbps down, 1 Mbps up, 150ms RTT, 4× CPU slowdown in desktop lab; record real hardware/browser/version separately. Three runs per scenario, report median plus worst. Signed-in and guest; ads denied, allowed, blocked and SDK offline.

- Editorial pages: p75 LCP <=2.5s, INP <=200ms, CLS <=0.1 where field samples exist; lab uses equivalent measurements but is not field evidence. [Web Vitals methodology](https://web.dev/articles/defining-core-web-vitals-thresholds?hl=en).
- Flutter canvas: custom `app_interactive` <=5s cold / <=2s warm on test profile; do not mistake a splash-screen LCP for a playable game. Ad integration adds <=200ms to interactive time relative to same release with ads disabled.
- Frame p95 <=16.7ms on representative 60Hz Android/desktop for ordinary public navigation; no ad-induced >100ms stall. Low-end devices additionally report long-frame count rather than claiming universal 60fps.
- No horizontal overflow at 320px; no obscured input/CTA with keyboard or safe areas; no ad overlaps; all actions keyboard accessible on desktop.
- Six-hour automated/manual mixed play soak: no crash, stuck ad mutex, lost match, duplicate wallet credit or steady memory growth. After warmup compare stabilized hour-1 and hour-6 measurements; target growth <20%, investigate any monotonic rise. Run with voice disabled and with ad endpoints blocked too.
- Battery and transferred bytes measured on one representative low-end Android plus a real iPhone; record baseline/change rather than inventing universal battery percentages.

## Device matrix

| Viewport logical px | Purpose |
|---|---|
| 320×568, 360×800 | small Android, long Arabic, keyboard |
| 390×844, 430×932 | iPhone Safari/WebKit and large phones |
| 844×390 | phone landscape + safe area |
| 768×1024 | tablet |
| 1024×768, 1440×900, 1920×1080 | desktop, mouse, keyboard, browser zoom 125/200% |

Screens: home, create/join, lobby, role/pass/night/vote (all roles), result, store, reward pending/no-fill, missions, profile with keyboard, consent, editorial pages. One downscaled screenshot per final screen/state at phase gate; preserve raw traces/measurements as files, not repeated full-size screenshots in chat.
