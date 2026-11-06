# V2 cut verification — 2026-10-11

Delivered full A cut: `../exports/MAFIA_V2_صاحبك_اللي_بريء.mp4`. This is separate from rejected V1.

- Actual exported file: 57.000 seconds, 1710 decoded CFR frames, 1080×1920, H.264 at 30fps, AAC stereo at 48kHz. File SHA-256 and stream probe are in `final.json`.
- Measured finished audio: -15.11 LUFS, -1.42 dBTP. Speech remains at native speed. Music ducks before the reveal. No subjective listening or retention score is claimed.
- Decode/black detection: no nearly-all-black interval of 20ms or more. Rendered contact sheet inspected, plus snapshots at 15 initial scene times and targeted fixes.
- Real acting strips inspected: Kareem's eye glance/smile/hands, Salma's eye lift and point, Omar's widened eyes/palms, Mafia's fingers/card/body, reveal's changing expression and approaching phone. These are actual video sources, not a still-image face rig. Reused shots are listed in the production README.
- Script matches selected Adam take 2 provider words after removing retained performance-annotation metadata. Captions use measured word chunks, with no adjacent overlap. Timing and line/frame map are in `timeline.locked.json`.
- HyperFrames 0.8.146: zero lint/runtime/layout/contrast errors, 16/16 sampled text contrast checks. Structural warnings remain: 61 nested-structure suggestions, 2 dense-track suggestions, 1 repeated-media-source warning for intentional card use. Motion audit was disabled by the CLI, so its zero count is not represented as a motion-quality pass. Motion was inspected through source strips, timeline snapshots and exported frames.
- One intentional paper-label occlusion remains after the questions are placed on the file; the suspect's name is readable in the earlier questioning beat. Case identity uses Ruqaa only for the case title; instructions use Plex. Oxblood is restricted to the wrong-vote verdict. Original card faces/screenshots are not repainted.
- Corrected during verification: later fromTo baselines were applying the citizen flip early; later tweens now use immediateRender:false. End brand/loop overlap corrected. Cue-end clipping removes overlapping captions. Evidence enters from the side so it does not cross the subtitle area.

## Honest limits

Five acting sources completed. Additional generated cafe and offline group clips are not completed: provider credits ran out. Offline is a moving physical phone/card sequence, and Stories is a persistent paper/camera composition with real artwork; neither is falsely described as new acting footage. No generated group still is passed off as animated. The complete second B concept is not produced in this turn; owner explicitly allowed A first.

The app inserts are genuine separate screenshots, not a live recorded multiplayer match. No voice-call UI, fake tap-result sequence, private-role leak on public UI, or actual case solution is introduced. Marketing effectiveness and subjective Adam tone remain for real viewer judgment.

Preview: `http://127.0.0.1:3033/design-system/reel/revision-v2/production/review.html`.
Editable Studio: `http://localhost:3034/#project/project`.
