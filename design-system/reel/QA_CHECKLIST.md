# Acceptance checklist — real evidence required

Preparation checks and production checks are separate. Only the former can pass before generation.

## Package integrity (preparation)
- [ ] Every frozen asset exists and matches manifest SHA-256.
- [ ] Cue text reconstructs SCRIPT.ar.txt; stripping v3 tags reconstructs the same words.
- [ ] Planned cue/scene spans are ordered, non-overlapping and cover 1770 frames including final hold.
- [ ] All cue/scene asset IDs resolve; all identity snapshot files and fonts exist.
- [ ] Old opening, optional YouTube plan and missing-reference-video requests are archived and superseded.
- [ ] Source case public fields match actual case file; no truth/clue solution content in the public bundle.

## Voice gate
- [ ] Egyptian voice ID matches catalogue; exact voice/model/take recorded.
- [ ] Voice listened to; complete script intelligible; no spoken tags, skipped words or invented dialogue.
- [ ] Brand name, أونلاين، أوفلاين، المحقق، قهوة المعلم and هتتلقط are understood correctly.
- [ ] Opening speech begins within 150 ms; online spoken before 10 s.
- [ ] No horror whisper, announcer growl, forced evil laugh, unnatural chipmunk speed or harsh sibilance.
- [ ] True timing aligned and reviewed; raw provider output preserved.

## Character gate
- [ ] Same skull shape, hood and embroidered clothing as supplied artwork.
- [ ] No duplicated hands/teeth, loose mandible, exposed layer hole or floating wrist.
- [ ] Hand visibly contacts and releases card; card remains whole.
- [ ] Speech uses several readable but subtle jaw positions; rest during silence.
- [ ] Rig position/size remains consistent when returning to the host.
- [ ] Short speech test inspected before full film render.

## Picture/retention gate
- [ ] Frame 0 contains face, moving card and online label; no black/logo-only intro.
- [ ] Hook and product promise understood without replaying first 10 s.
- [ ] No simultaneous headline, dense subtitles and unreadably tiny UI.
- [ ] Viewer can follow roles → discussion → vote and understand offline availability.
- [ ] Reaction at «المافيا بتشكركم» has enough pause to land, without overacting.
- [ ] Stories cut changes environment/type/art palette at the cue; no Mafia art leaks into Stories.
- [ ] One case's actual cast/assets; no invented clue or spoiler; cost 2 means 12→10 if shown.
- [ ] Ending returns to original card/character and readable product name; hold >=1.5 s.
- [ ] Text/face/CTA remain inside safe area at entrances, overshoot and exits.
- [ ] Arabic connected RTL, unclipped dots/hamzas/descenders, loaded local fonts, no reversed numbers.
- [ ] Viewer can read the text and recognize character at 360×640.

## Required QA artefacts
- `qa/film-contact-sheet.jpg`: sample ~1 frame/s, label time.
- `qa/transition-sheet.jpg`: frames at each locked boundary -2,-1,0,+1,+2.
- `qa/opening-strip.jpg`: frames 0,3,6,12,15,24,36,60,84,120,164.
- `qa/jaw-speech-strip.jpg`: several actual speech envelope peaks and troughs.
- `qa/jaw-silence-strip.jpg`: frames across at least two reviewed pauses.
- `qa/card-contact-strip.jpg`: hand/card before contact, contact, release, after release.
- `qa/stories-switch-strip.jpg`: evidence of clean identity boundary and geometry match.
- `qa/end-strip.jpg`: entrance, CTA landing, last spoken word, last frame.
- `qa/QA_REPORT.md`: commands, measurements, image paths, defects fixed, honest outstanding items.

## Delivery gate
- [ ] HyperFrames checks pass; media/font readiness verified; deterministic seek tested by sampling same frame twice.
- [ ] 1080×1920, 30/1 CFR, H.264 video, AAC audio; 1770 video frames.
- [ ] Video =59 s; container <60 s; no unintended black tail or cut-off audio.
- [ ] Loudness and true peak measured, target -14..-16 LUFS / <=-1 dBTP; no clipping.
- [ ] Full film watched/listened to at normal speed, and phone-size/mono checked.
- [ ] SRT has real times, no overlapping accidental cues, no tags and no missing final line.
- [ ] Source project reopens with frozen local assets; provenance retained.

A transcript match is not a voice-performance check. A numeric contrast check is not a composition check. A valid MP4 is not proof the character animates correctly. If a sensory check cannot be performed with available tools, label it unverified; don't silently tick it.
