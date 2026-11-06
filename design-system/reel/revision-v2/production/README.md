# صاحبك اللي بريء — production V2

Owner authorized a full first film on 2026-10-11. This is the replacement for the creatively rejected V1, which stays separate. This film uses real generated acting, not a masked jaw over a still image.

## Sources and motion

Five Kling 3 Pro clips, generated through the connected ElevenLabs flow `VGfqmPBQWx3ZImBHYd2P`: Kareem hook, Kareem reveal, Salma suspicion/point, Omar protest, original Mafia host choosing a target. Frame strips in `qa/` show their temporal acting. Online montage and ending deliberately reuse those performances.

Adam Egyptian voice `OFHP1Qg30FPoNfkUFFlA`, eleven_v3 take 2, 55.68 seconds, no speech speed changes. Provider word timing is in `research/adam-take2-scribe.json`; the script matches after stripping annotation metadata. `timeline.locked.json` maps every spoken line to frames. Subjective tone/listening approval is not inferred from transcription.

The phone uses original screenshots of home, online rooms and private card delivery. These are illustrative separate captures, not a connected multiplayer recording. No video call/voice chat or fake gameplay tap is presented. The role selection and vote example are advertising graphics; Salma/Kareem/Omar are fictional advertising actors, not named case suspects.

Night roles use exact original card faces. Offline uses a physical phone/card passing sequence over actual game art. Stories uses the real public case cover, location, suspect and evidence on a persistent manila desk: independent paper assembly, folder opening, camera and question slips. No real case solution appears.

## Credit limitation

After the five completed acting clips, ElevenLabs rejected the extra cafe video: 237 credits remaining versus 3394 needed. A cheaper LTX estimate was 1454 credits, still over balance; it was not run. OpenArt also had 40 credits versus its cheapest default video at 50; no generation was submitted there. No credits were purchased. The offline group still is retained as development art, not falsely labelled animated footage; it is not used in the film. More offline acting or a generated moving cafe environment requires new credits and is an optional replacement of those prop scenes, not hidden completed work.

## Edit/render

`project/index.html` is the assembled editable HyperFrames project. `build.py` generates it from the measured timeline and `style.css`. Fonts, GSAP, screenshots, audio and video are local. Engine upgraded from 0.8.145 to 0.8.146 in this project; validation must pass before delivery. Native video and audio playback belong to HyperFrames, never JavaScript timers.

Run `python ../build.py` from `project/`, then `npm run check`. Windows uses the cached browser path in `render.ps1`. Target 1080×1920, 30fps, 57 seconds, H.264/AAC. Final output is under `exports/`. Do not run the old concept `finalize_review.py`: it resets STATE.json to review.

## Skill synthesis

Instagram-agent: immediate recognisable hook, early online benefit, wrong-accusation setup, visible payoff and one sharing CTA. Lemo: anticipation/action/reaction, actor identities, motivated camera, quiet before reveal. OneTake: independently authored phone/card carry and contact sequencing; its noncommercial engine is not copied into this marketing project. Collage B-roll: one case desk progressively assembles a few real source groups instead of resetting every shot. HyperFrames: measured paused GSAP timeline, native media, local fonts, reproducible frame render and QA. These are concrete uses of the guides, not a claim that importing names ensures marketing success.
