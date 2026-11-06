# Concept review QA / 2026-10-11

Scope: ideas-first proposal as explicitly requested. No V2 final film, no new full narration, no finished character acting claimed.

Verified:
- 3 new imagegen images visually inspected: human opening, skull host emerging from phone, 3-player / 2-expression cast sheet. Canonical hero is recognisable in both. Cast art needs more turnarounds and controlled performance before motion production.
- Real app screenshots inspected and copied unchanged from `epic-roentgen-094f21/store/screenshots`: `10-home-current.png`, `12-online-rooms-1.0.1.png`, `07-reveal.png`. The third is the back-of-card state, not a role-reveal recording. It is not a connected online match.
- Existing Mafia/Stories IDENTITY.md reviewed; actual role card, cafe location, suspect and evidence artwork preserved.
- HTML displayed in the in-app browser; actual opening frames inspected, correct connected Arabic after correcting font-relative paths.
- Concept A/B/C controls update title, artwork, hook, motivation and scene notes. Reset, play and keyboard scrubber operate. Keyboard scrub from 0 to about7.2s verified; in-app screenshot sometimes captures an older visual paint, refreshed tab screenshot used to inspect current state.
- Responsive breakpoint overrides exercised: DOM viewport reported1108px and300px (host browser applied scaling to requested1440/390). No horizontal overflow; image assets loaded. Overrides reset afterwards.
- Initial stage scaling bug fixed: each draw now sets stage transform from its container width; checked live DOM scale.
- Font badge/headline positions separated. No autoplay. Slider supports reduced-motion users inspecting static states.
- Node syntax check passes. Local asset/link existence checked by `finalize_review.py`; asset SHA manifest frozen.
- Instagram hooks/beats/human scripts run. English tokenizer returned0 Arabic words, so its timing and quality scores were rejected. Arabic whitespace count103; duration remains a planning range until Adam audio.
- Egyptian Adam catalogue identity verified via ElevenLabs MCP; preferred voice saved in STATE. No Haytham rerun and no English Adam selected.

Limits:
- The18s preview compresses the proposed narrative to illustrate camera / phone / paper moves. The final56–59s script pays off the hook after voting; the preview is not final scene timing.
- Character images are stills. No talking performance, eye movement, full lip-sync, actor clips or subjective voice audition are completed here.
- UI pointer ring is a concept review marker; final needs a believable hand/press and true state footage. Do not invent unverified voice chat/video call or gameplay outcomes in app screenshots.
- Concept C uses existing case-location art as a preview ground plus original role card, not yet a newly generated opening set.
- Some practical generated-image colour is warm; final cast plates should be graded to Mafia slate and foreground skin kept readable. Warm manila/amber dominant only on entering Stories.
- Product art inside UI is unchanged. Final QA must inspect actual moving scene transitions, hands, role secrecy, legibility and voice before exporting.
