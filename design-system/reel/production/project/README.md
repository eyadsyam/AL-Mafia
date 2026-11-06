# سيد المافيا — إنت المافيا

Editable local HyperFrames project. 1080×1920,30fps,59s. Assets/fonts/vendor runtime are local. No game app changes or online services are needed to preview/render the existing film.

## Preview

`npm run dev`

## Re-render and verify

On this Windows workspace, from this folder:

```powershell
.\RENDER.ps1
```

Requires Node22+,Python,FFmpeg/ffprobe. HyperFrames is pinned to0.8.145 by project scripts. This wrapper checks the project, captures with the installed browser, renders delivery quality, and copies picture without re-encoding while mastering audio to measured loudness/peak limits.

The underlying source has12 mounted scene files, local GSAP, and deterministic scene state driven by composition time. `data.js` holds the locked cue/energy map. `scene-runtime.js` controls the skull, jaw, hand, cards and picture assembly. `style.css` holds layout/fonts. The root index embeds CSS when generated; edit `style.css` and run `../build_project.py` to refresh that embedded stylesheet. Do not rerun the old preparation helper.

Audio is Egyptian Haytham via ElevenLabs v3. Original raw take and silence-only edit map are preserved in the parent production folder. SRT is external; the film uses sparse editorial headlines. Brand fonts and imagery follow the two frozen identities. Source art was reused; three promotional character paintings/base edits were generated with the built-in image tool.

Final quality evidence and any unverified listening item are in ../qa/QA_REPORT.md. Do not describe a technical export check as a subjective voice-performance review.
