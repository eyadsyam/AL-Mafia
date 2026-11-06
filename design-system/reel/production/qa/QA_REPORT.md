# سيد المافيا — export QA

Date: 2026-10-11 (Africa/Cairo). Status: **delivery export produced; independent subjective listening review remains open**.

## Delivery

- Final: `../exports/MAFIA_ONLINE_REEL_AR_59s.mp4`
- Poster: `../exports/MAFIA_ONLINE_REEL_POSTER.png`
- Arabic SRT: `../exports/MAFIA_ONLINE_REEL_AR.srt`
- Editable project: `../project/` (HyperFrames0.8.145, local GSAP3.14.2)
- Reproduction: `../project/RENDER.ps1`; final audio mastering via `../finish_export.py`.

The current numeric results are in final-probe.json and loudness-final.json, overwritten only after successful mastering/verification. They verify 1080×1920, H.264, 30fps,1770 video frames,59s, AAC48kHz stereo. Measured programme loudness is approximately **−15.03LUFS**, true peak approximately **−2.96dBTP**. No nearly-all-black intervals detected across the decoded film. Audio mastering copies the video stream without re-encoding it.

## Narration

Haytham voice ID `IES4nrmZdUBHByLBde0P`, ElevenLabs v3; selected full generation `tmyWsddiZqWMhQXSB8UU`.
Original take retained as `../assets/audio/voice-original.mp3`, working narration `../assets/audio/voice-master.wav`.
Raw narration64.08s approximately; working narration56.50002s. Only centres of measured long low-energy pauses were removed. Speech samples remain at native speed; no atempo/pitch shift. Exact edit map: voice-edit.json.

The selected-take ElevenLabs Scribe result includes word timing. Its10 bracketed performance annotations were removed as metadata, leaving **100 words**, matching the approved plain script after normalization. Raw provider data remains `../transcripts/scribe-selected-raw.json`. Edited timestamps derive from that source through the documented cut map; acoustic phrase groups independently determine natural cuts. These are provider/waveform checks, not a claim of phoneme-perfect or independently heard pronunciation.

No invented8/10 listening score is recorded. Audition variants were surfaced as audio in chat, but **subjective accent, expressiveness, music suitability and full-speed audiovisual listening were not independently verified by the agent**. Those remain human-review items. The video itself is fully exported and playable.

## Picture and rig

One canonical seated skull character was generated from the game's gallery/chair references with the built-in image tool, then two tightly scoped base edits removed the face and the forward forearm. Face, mandible and forearm use registered native clip-path layers from the SAME canonical image, preserving identity instead of separately regenerating each shot.
Sources/prompts: MEDIA_PROVENANCE.json. Original PNGs remain in ../assets/character. Runtime WebPs are lossless encodings; decoded RGB equality was tested for both canonical and clean base (lossless-image-check.json).

Talking is speech-energy-driven mandible motion, gated to measured speech intervals; no human lips or blinking. Bounded head motion, a card-contact/release gesture, vote reaction and a withdrawal are authored deterministically. Jaw motion is an approximation, not phoneme lipsync. Face/hand proof strips were inspected on rendered snapshots and the encoded draft before delivery. This used the first draft as the speech-motion test, rather than a separate pre-authoring short MP4.

Important layout corrections:
- Opening text now lives above the character, with84/60/64px Cairo sizes for its three phrases, keeping the lower reel-controls region clear.
- Host framing is consistent across opening/return shots; closing CTA is above the face rather than below the table.
- Online cards and brand caption have clear separation; portraits/case names enlarged where useful.
- Whole role cards remain unmodified, untinted and uncropped. The opening prop is physically occluded by the gloved hand, as a held card, rather than text being drawn over it.
- Card/folder match cut preserves centre and angle while the complete environment/font palette changes to Stories.
- Doctor/detective card switches and the three accusation questions use transformed provider word onsets.

## Inspection evidence

- `check-final.json`: runtime/lint/layout/contrast gate.0 lint errors; repeated-image discovery warnings are intentional distinct face/jaw/hand masks or generic repeated avatars/cards. No blanket overlap suppression was added.
- Any container-overflow warnings concern deliberately overscanned background/presenter imagery, not clipped essential text. Actual caption/card overlap and phone-safe hook placement were corrected.
- `film-contact-1..4.jpg`: decoded film sampled at1fps, phone-scale contact sheets.
- `transition-sheet-1..4.jpg`: frames at every scene boundary±2frames.
- `opening-strip-1.jpg`, `end-strip-1.jpg`: opening/contact and final clean hold evidence.
- `safe-area-proof/contact-sheet.jpg`: final geometry revision snapshots.
- `jaw-proof/contact-sheet.jpg`: speech/rest mandible proof from actual rendered snapshots.
- `frame-timing.json`: per-frame timestamp check, when generated by verify_delivery.py.
- `black-frame-check.log`, `loudness-final.json`, `final-probe.json`: decoded video and signal measurements.

Fonts were loaded locally: Cairo variable, IBM Plex Sans Arabic Medium/SemiBold, Aref Ruqaa Bold, IBM Plex Mono. RTL is scoped to text blocks, not the HTML root (which HyperFrames flags as unsafe). No disconnected Arabic, missing media, unexpected black tail, invented application screenshots, YouTube footage or story solution was used.

The online visuals are editorial game-art arrangements, not a claim to be recorded implemented UI. Stories uses verified public data from قهوة المعلم; fresh budget12→10 corresponds to interview cost2. No culprit/solution is exposed.

## Boundaries

No app-code changes, Flutter build, deployment or publication. No new reference video was needed. Local preview remains available through the project. STATE.json records the open listening-review item rather than falsely marking every sensory check complete.
