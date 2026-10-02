# Release ownership and policy notes — 2026-09-24

Owner's latest instruction: Claude does most implementation and tests; Codex owns priorities, accepts/rejects proposed scope, reviews results, and later operates release/advertising/account setup. No guarantee of revenue or approval. No paid campaign spend without an explicit budget. This document does not activate monetization or authorize a production deployment.

## Verified from source in this review
- payment_capabilities.dart enables web transfers only for kIsWeb AND WEB_COIN_SALES. Keep Play free of external payment links, QR codes or steering messages.
- Android ads and Play billing have separate configuration gates. Code presence is not evidence of production activation.
- store/GOOGLE-PLAY-SUBMISSION.md contains ads/purchase declarations which MUST be reconciled with the exact final build/configuration and SDK behavior, not copied blindly into Console. In particular, a configured optional scenario is not proof of an available paid product. Disabled ad presentation does not alone prove an embedded SDK collects nothing.
- No Play/AdMob account state was verified or changed in this phase.

## Current primary-source policy checks (recheck at release)
- Digital goods/virtual currency sold inside Play-distributed apps generally require Play billing; applicable regional/program exceptions require actual eligibility/enrollment, not a generic web-link workaround. Source: https://support.google.com/googleplay/android-developer/answer/9858738?hl=en and https://support.google.com/googleplay/android-developer/answer/10281818?hl=en
- For affected personal accounts created after 2023-11-13, the closed-test condition is at least 12 opted-in testers continuously for 14 days before applying for production access. This is NOT Google staff testing the game for two weeks and NOT guaranteed approval. Confirm account applicability in Console. Source: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
- Rewarded ads must clearly describe the required action and actual reward. Keep them voluntary, outside active matches, and deliver the promised reward with verified/idempotent server fulfillment. Do not ask users to click ads or watch merely to support the business. Source: https://support.google.com/admob/answer/7313578?hl=en-GB

## Release gates to reconcile against the FINAL binary
Final feature flags and backend deployment; real-device crash/startup; owner human match/witness voice; privacy and account deletion; UGC reporting/blocking/moderation; age/content rating; SDK data disclosure; ad identifiers and consent; production IDs and app-ads.txt when applicable; billing restoration if enabled; signer/16KB compatibility/target API; localized listing and actual up-to-date screenshots; App access instructions; tester/production-access conditions.

Do not submit until these are checked with evidence and required owner-only actions are explicit. This is a planning note, not a completed compliance audit.
