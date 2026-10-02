# Google Play upload package — September 21, 2026

**Prepared for upload, not yet submitted or approved by Google.**

- Upload: `build/app/outputs/bundle/release/app-release.aab` — 105,786,010 bytes.
- Install/test: `build/app/outputs/flutter-apk/app-release.apk` — 125,251,789 bytes.
- Package `com.mafiamaster.mafia_master`, version **1.0.0 (1)**, target API **36**.
- Signing verified; established local certificate preserved. Both AAB native
  alignment and APK packaging pass 16KB checks. A real 16KB device runtime was
  not used. ARM64, ARMv7 and x86_64 included.
- Current web deployed to https://almafia.vercel.app; production JavaScript
  hash matches local. Privacy and deletion pages respond with the actual text,
  not the SPA fallback, and use eyadsyam124@gmail.com.
- Tests: full suite 1032 pass / 1 skip before final presentation changes;
  final focused UI/online 185 pass, asset checks 7 pass; analyze no errors or
  warnings, 78 informational lints. No final full-match run by request.
- Android installation and launch succeeded. A transient emulator System UI
  stall recovered; the final home screenshot was inspected successfully in
  `build/phase68-final-device-recovered.jpg`. This is launch evidence only,
  not a full UI walkthrough or the user's final device/match acceptance.

## What changed

Privacy/data deletion is only in game Settings. Rooms have separate report and
block actions; public policy names service categories, not implementation tools.
Private report and deletion queues are deployed. Blocking applies to voice,
whispers and eliminated-player messages. The developer must monitor the queues.

Online discovery uses original council artwork with a brief motion effect and
existing card-turn feedback. The shipped image is only 95KB. Reduced-motion
and mute preferences are respected. No secret-dependent night media was added.

## Files to use

- `store/GOOGLE-PLAY-SUBMISSION.md`: upload steps, access instructions, Data
  safety draft and required Console actions.
- `store/SAFETY-OPERATIONS.md`: report review and deletion completion.
- `store/listing-ar.md`, `store/listing-en.md`: corrected store descriptions.
- `store/icon-512.png`, `store/feature-graphic-1024x500.png`: validated dimensions.
- `docs/ONLINE-ART-2026-09-21.md`: original generation prompt and asset provenance.
- `build/phase68-release-hashes.json`: SHA-256 hashes of final artifacts.

Final multiplayer match and real human voice acceptance remain with the user.
Play Console identity verification, audience/rating/Data safety declarations,
testing eligibility and Google review require the developer's account. After
Play App Signing enrollment, add its signing certificate to assetlinks if it
differs from the local upload certificate.
