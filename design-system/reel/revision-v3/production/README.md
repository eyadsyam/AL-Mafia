# سيد المافيا — V3 / صاحبك اللي بريء

Owner review: V2 was a promising start, but required a full picture audit, actual gameplay video, audible sound design and a more suitable narrator. Latest direction permits a different Egyptian male voice speaking naturally. This revision uses **Fekry**, not Adam or previously rejected Haytham.

## What changed

- Latest owner correction replaced the calm candidate with an actual **Fekry eleven_v3** performance (`io9GFXg4vAYJBQPCcmwZ`), directed for excitement, teasing, confident rules, a reveal punch and an eager CTA. Raw60.4s becomes55.676s by removing4.724s only from quiet intervals between protected word envelopes. Every join has5ms fades. Pitch/speech speed stay unchanged. Source/direction, exact cuts and mapped words are saved. Subjective passion is not claimed as a machine measurement.
- Native 30fps recordings of actual release Flutter widgets: online discussion, Mafia target selection, Doctor target selection, Detective selection, voting with confirmation, solo case actions/notes and accusation page. They use a seeded local backend, not a real network match. Capture harness is `captures/capture.dart`, executed against sibling release worktree; it changes no game code and contacts no live players.
- Online gameplay replaces the empty-room screenshot. Selection/click SFX correspond to frame 65 in the actual recorded capture, and vote confirmation to frame 105. All media source windows are verified against source duration so no clip silently freezes after its last source frame.
- New continuous generated offline group performance: phone passes across table; Salma catches it and Omar reacts. Original cast art is preserved; no still-image jaw rig.
- Fourteen original game sound assets are peak-balanced and placed as 22 events: night/morning, join, cards, selection, vote, elimination, paper, envelope, wax, string and share. Music ducks before the reveal. Very short fades prevent hard audio cuts. Voice has gentle EQ/compression and preserves pitch/speed.
- Old V2 timing is re-mapped to measured new words, with a **57.5s /1725-frame** root. «وتصوّتوا» and «أهو» are explicit timing anchors. Captions use edited native provider word times directly, not the old time map. The hook headline and the final innocent loop carry those words, so duplicate subtitles are removed.
- Voting UI enters after Salma's pointing beat and moves aside before Omar's reaction. Detached card pasted on top of private screenshot removed. Reveal is cut before the empty approaching phone fills the frame. Text has zero Arabic letter spacing. Evidence/question slips no longer cover the suspect name.
- Scene/video windows overlap by0.13s on each side, with0.26s blends. The Mafia card carries across the offline entrance. Later tweens continue current transforms rather than resetting from obsolete poses. Product phones have a restrained camera track, so a stationary app state does not become a frozen composition. No guessed frame extensions: every source range is checked after re-timing.
- `research/VOICE-DIRECTION.md` describes intended delivery per beat; `voice-energy-lane.json` records modest editorial voice accents. These complement the new acted recording; gain is not presented as a substitute for acting. The audition hook is in `exports/FEKRY_PASSION_HOOK.wav`.

## Audit method and its limits

All 1710 V2 frames were decoded into six ordered contact sheets, reviewed across the entire duration. Full-size targeted snapshots verified the identified problems. Every V3 source window is numerically verified. Every final V3 frame is decoded for contact sheets and frame statistics; targeted high-resolution transition snapshots and runtime/layout/contrast checks complement that. This is not a claim that each facial detail was individually certified at full resolution, or that technical checks measure audience retention.

`timeline.locked.json` contains the measured words/line frame ranges. `research/fekry-take2-scribe.json` is the provider transcript. `research/sound-palette.json`, `qa/media-windows.json` and `qa/check.json` retain evidence. Generated media uses existing flow `VGfqmPBQWx3ZImBHYd2P`; old Adam generations remain there but are not used in this cut.

## Reproduce

1. Capture game footage: from the release sibling worktree, run `flutter test --no-pub <absolute-path-to-captures/capture.dart> --reporter expanded`.
2. Run `python align.py`, `python prepare_sounds.py`, `python build.py`, `python verify_media.py` in this folder.
3. Run `render.ps1`. The project pins HyperFrames **0.8.147**, updated from V2's 0.8.146 and checked before rendering. Windows uses the known cached headless browser. Framework owns playback; composition uses paused GSAP and local assets.
4. `finish.py` produces mastered H.264/AAC video, poster and probe/loudness report. The final SRT is `exports/MAFIA_V3_AR.srt`.

No source game code, live backend, deployment, store listing or social post is changed. Original V2 output remains in its own folder.
