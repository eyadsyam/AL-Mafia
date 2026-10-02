# Phase 98 — Council Vault implementation and review

## Evaluation of Claude's September 24 session
Read the supplied SESSION-CHANGELOG and verified the active worktree/source. The first-frame media layering, shared settings kit and neutral ground were retained. The owner-requested brown-palette revert was respected. Those are useful structural improvements, not a reason to rewrite working navigation or match rules.
The largest remaining concrete design gap was the text-only store with unintegrated product artwork. This phase closes that gap; it does NOT claim a redesign of every public screen or release readiness.

## Collaboration
Used the explicitly requested claude-delegate skill, model claude-opus-5-5, effort medium, session 733ebd35-1b1a-48e7-b8ec-39bb1691677d.
Claude implemented most refinements, real new SKUs, SQL and test drafts. Its session hit the usage limit before finishing Flutter verification. Codex reviewed the diff and completed fixes/tests, rather than accepting a success claim.
Before-delegation source snapshot is now C:/Users/LENOVO/AppData/Local/Temp/mafia98-review-baseline. Keeping its pubspec inside build caused analyzer to discover an extra package; moved the snapshot outside the repository, no analyzer rules weakened.

## Design decisions accepted
- Compact wallet strip and earnings dialog; account protection stays accessible lower in the shop. Products are visible in the first 360dp screen.
- Restrained hero, independent horizontal rails, localized text, responsive readable desktop column; all prices/ownership come from the server.
- Five cosmetic categories of three client-implemented products, plus three platform-gated web coin packs. Coin selection also uses a horizontal illustrated rail with scrollbar.
- Store details keep the action at the bottom; successful buying offers equip in the same sheet; in-flight equip disables further action.
- Real alpha frame artwork, measured apertures and segmented nameplate drawing preserve ornaments. Shared canvas renderer means equipped artwork matches the preview.
- Room art remains under public-phase gating; result screens preserve the outcome illustration. Narrators are honest text styles plus existing cues, not recorded voice.
- Existing neutral background/media/settings design preserved.

## Codex review corrections
- Added separate PageStorageKey per horizontal rail to retain position independently.
- Fixed new tests that incorrectly assumed offscreen lazy rails remain mounted, and decoded art before fake-clock UI tests to avoid an async hang. Existing purchase assertions retained.
- Asset cache accepts only an asset-reader callback instead of importing all services into UI; the original haptic guard remains unchanged.
- Reworded Keeper dialogue that implied speech was being recorded.
- Capped table frame extent to avoid ornaments spilling out of tight seats; portraits fit the real aperture. Added pixel-bound regression with nonempty-art assertion.
- Corrected capture fixture prices to migration values; capture now waits for the council painter's art rather than accepting a blank image.
- Added missing coin-pack horizontal presentation; centralized new sizing values.
- Removed Codex's two one-shot editing scripts; original asset masters retained.

## Implemented new content, NOT live yet
pack_moonlit_archive; narrator_keeper; narrator_noir; bundle_nocturne.
Local additive migration 20260924000700_store_v2_catalog.sql and rollback test store_v2_catalog.sql.
Backend shared room_configuration.ts permits the new pack/style codes while existing ownership checks stay in force. Before enabling in production, deploy compatible create_room, room_settings and start_match functions together with catalog migration and recheck hosted contracts.
Older clients filter unknown IDs. New client also hides items absent from the server catalog. Therefore the hosted catalog may still have fewer than three items in some categories until coordinated deployment.
Proposed prices live in SQL, never in artwork. No sale activation, transfer settings, production ad IDs or account changes made.

## Files
- pubspec.yaml; assets/images/store_v2/plate_{noir,gilded,ember}.webp (runtime transparent padding normalized; original PNGs retained).
- lib/ui/economy/{store_art,cosmetic_art_cache,cosmetic_paint,cosmetic_preview,cosmetics,coin_packs}.dart.
- lib/ui/screens/setup/coin_store.dart; lib/ui/screens/online/{council/council_band,table/table_scene}.dart.
- lib/ui/theme/design_tokens.dart; lib/app/l10n/app_{ar,en}.arb and generated localization Dart.
- supabase/functions/_shared/room_configuration.ts; migration/test above; supabase/tests/room_configuration.test.mjs.
- test/widget/{coin_store_test,store_v2_test,store_screenshots}.dart.
- docs/CLAUDE-DESIGN-98-BRIEF.md; docs/CODEX-RELEASE-POLICY-98.md; this review; PROGRESS.md.
Pre-existing staged deletion web/beta/index.html was observed and left untouched. No commit/staging/push.

## Verification
- Full Flutter suite: 1157 passed / 1 pre-existing skipped / 0 failed (build/phase98/codex-full-final.log).
- Subsequent final artwork-bound/coin-rail refinements: 67 relevant tests passed (codex-final-targeted.log), including store actions, web payment flow, night cosmetic guards, council geometry and unchanged haptics guards.
- Analyze on final code: 0 errors / 0 warnings / 89 infos (codex-analyze-final.log).
- Local PGlite: 32/32 SQL test files passed (codex-sql.log), including the new catalog contract. Single connection simulation, not hosted concurrency evidence.
- Node room configuration + cosmetic ownership test scripts: 2/2 passed (codex-node.log).
- Actual Flutter widget captures with fonts and decoded art: 9 capture tests passed, then council capture repeated after final bounds fix. Reviewed Arabic/English 360dp shop, frame details, and equipped council. These are widget-render captures, not device or production-web validation.
- No Docker used. No Android release, AAB or web build generated/published in this phase.

## Evidence to open
build/phase98/01-store-ar-360.png
build/phase98/04-store-en-360.png
build/phase98/05-store-ar-desktop.png
build/phase98/06-detail-frame_gilded.png
build/phase98/06-detail-plate_ember.png
build/phase98/06-detail-pack_moonlit_archive.png
build/phase98/06-detail-narrator_noir.png
build/phase98/06-detail-bundle_nocturne.png
build/phase98/07-council-identity.png

## Remaining scope
Broader Home/profile/onboarding/online-entry/lobby visual campaign is not represented as finished by this store phase. Keep good existing screens and target observed issues next.
Real-device final human match/witness audio remain owner tasks. Latest device/web candidates precede this change.
New catalog/compatible functions require reviewed coordinated hosted deployment. Monetization/account/Play forms require the separate release review in CODEX-RELEASE-POLICY-98.md.
No promise of revenue, review approval or a two-week Google review. No advertising spend authorized.

## Design references
https://developer.android.com/guide/topics/ui/accessibility/views/apps-views
https://developer.android.com/design/ui/mobile/guides/layout-and-content/grids-and-units
https://docs.flutter.dev/perf/best-practices

