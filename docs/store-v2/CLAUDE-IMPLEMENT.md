# Store V2 — Claude implementation handoff (2026-09-24)

## Scope and ownership
Owner requested a coherent identity for every store item, categories with at least THREE products each, and horizontal product scrolling per category while Claude continues application work.
Codex delivered art, catalog mapping and a static interactive design preview ONLY. No Dart, pubspec, SQL, payment configuration, account, build or deployment was modified. Do not interpret artwork as a deployed product.
Work in this worktree, preserving your newer phases. Do not copy the old main checkout over it.

## Read and inspect
- Open docs/store-v2/index.html in a browser: actual delivered imagery, six horizontal rails, Arabic, responsive layout, working image-preview dialogs.
- docs/store-v2/catalog.json: stable IDs, Arabic/English proposed display names, asset paths, existing/proposed status.
- docs/store-v2/provenance.json: per-image source and prompts; built-in imagegen, not API/CLI fallback.
- docs/store-v2/contact-sheet.png: overview in catalog order.
- assets/images/store_v2/: 19 optimized WebPs (18 product images + hero), total about 1.76 MB.
- raw_assets/store-v2/: unmodified generated PNG masters. Do NOT bundle these into the app.

## Identity
Council Vault / خزنة المجلس is the STORE title under the Mafia Master masterbrand.
Charcoal, muted antique gold, burgundy enamel, aged ivory/silver. Existing mask coin is retained. Characters inform materials and engraving; cosmetics do not indicate the player's secret role.
Keep backgrounds quiet. No rainbow rarity gradients, green selected states, dense wallpaper or fake discounts.
Copy, prices, coin counts, owned/equipped states and localization are Flutter text, never baked into artwork.
The gallery CSS is a standalone reference. Flutter colors/sizing/timings MUST live in design_tokens.dart; Arabic line height 1.6, zero letter spacing, existing text-scale rule.

## Catalog: 6 categories, 3 per category
1. Avatar frames: existing frame_gilded, frame_crimson, frame_moonlit.
2. Nameplates: existing plate_noir, plate_gilded, plate_ember.
3. Room atmospheres: existing pack_midnight_manor, pack_old_town; NEW pack_moonlit_archive.
4. Narration STYLES: existing narrator_storyteller; NEW narrator_keeper, narrator_noir.
5. Collections: existing bundle_council, bundle_identity; NEW bundle_nocturne.
6. Coins: existing codes coins_500, coins_1200, coins_2500. Their SALE availability remains platform/config dependent. A disabled or unavailable payment channel must not get a buy CTA just to fill a row.

Proposed new items are design proposals requiring implementation + server catalog migration before selling:
- pack_moonlit_archive: moonlit archive scene, restrained silver lighting, safe neutral atmosphere transitions. No different timing or game facts.
- narrator_keeper: concise, solemn archival phrasing for the existing publicly known beats.
- narrator_noir: terse noir mystery phrasing, no added suspicions or invented clues.
Both need complete Arabic AND English strings for all supported beats and actual preview. They are not voiced narrators. Don't claim new speech/audio unless separately delivered.
- bundle_nocturne: pack_moonlit_archive + frame_moonlit + plate_noir + narrator_keeper.
Existing bundles KEEP their actual entitlements: council = manor + old town + storyteller; identity = 3 frames + 3 plates. Artwork is a thematic cover; show exact constituent item previews on details, not only the stylized box.

## Honest product delivery
Current code renders frames and plates mainly as colors/rings; the new art must also be used for EQUIPPED cosmetics, not merely sold as a fancy store thumbnail.
Frames: real alpha exterior AND empty center; overlay around the circular avatar without covering face/status/voice controls. Fit aperture from each image; inspect alignment at small size.
Plates: real alpha exterior, blank center. Originals have different padded bounds/aspect ratios (do not blindly stretch every source square). Use normalized drawing rectangles or derive alpha bounds, preserve ornament, center dynamic name and ellipsize long Arabic/English names.
Room illustrations must be available in actual pack preview and appropriate room/background surfaces if represented as the bought visual. Preserve quiet readable overlays; never cover controls or encode role/team information.
Narrator cover objects are style emblems, not inventory tools or detective powers.
No purchased advantage, votes, clues, role odds, or timing advantage.

## Flutter layout
Replace the current vertical ListTile catalog with a vertically scrolling category screen and independent horizontal ListView.builder rails.
Category headings + optional View all, THREE real implemented products minimum per cosmetic category.
Mobile should expose the next card edge; RTL should start at the correct side. Desktop supports mouse wheel/trackpad, visible arrows and keyboard focus. No forced auto-scroll.
Each card: image, localized name, concise real benefit, server price, owned/equipped state. Tap opens in-app details/preview with actual contents and buy/equip.
Keep wallet balance in header, pending purchase state recoverable, no navigation away simply to inspect art.
Preserve CoinStore widget keys/contracts or update targeted tests with a justified behavior change.
Lazy image decode/cache sizing; no animated background per card, no image downloads during gameplay. Respect reduced motion.
Add assets/images/store_v2/ specifically to pubspec if directory declarations require it. Don't include raw_assets or docs.

## Backend and transactions
Client catalog filters unknown product codes: register new IDs in actual CosmeticCatalog and implement effects BEFORE enabling SQL items.
Backend owns prices, balances, ledger, entitlements, bundle duplicate handling and idempotency. Never infer ownership from preview selection.
Coin checkout remains the existing web-only gated architecture; this task did not apply coin-order migration or enable sales. No payment links or new purchase steering in Play build under the guise of art integration.
Do not promise payment readiness; carry unresolved gates into release handoff.

## Verification / acceptance
- Verify all six rails with Arabic and English, narrow mobile (360px), desktop and long player names.
- Preview, insufficient balance, owned, equipped, pending/error/retry states.
- Frames/plates in actual lobby/profile/table match sold image and don't expose hidden roles.
- Narrator wording uses only legal current beat facts; run information-leakage tests before enabling new styles. Respect later OWNER-approved spec overrides from phases95+ rather than reverting them.
- New bundle grants exact items once; repeat purchase doesn't duplicate currency debit.
- Test asset decode and targeted catalog/widget regressions, then normal required suite once after code changes.
- Don't claim a new release built or deployed from these artwork files. Build/production changes belong to your existing implementation/release scope.

## Codex verification
All 19 image files decoded and were viewed together in the contact sheet.
Three frames have real alpha (0..255) and center alpha zero. Three nameplates also have real alpha.
Runtime encoding via ffmpeg, WebP quality88, max768px; originals retained.
Static preview is authored but not yet browser-tested. No app integration/test was run for this asset-only delivery.

