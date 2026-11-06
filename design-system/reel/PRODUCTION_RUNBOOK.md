# Production runbook — execute after the user's «ابدأ»

## 0. Establish state and scope

Read START_HERE.md, then STATE.json. Run `python design-system/reel/verify_package.py` from the worktree root. Inspect any existing production files before resuming; never regenerate a completed voice or overwrite selected artwork just because a model changed.

This is original work; no external reference video is required. The requested render is the reel, not a Flutter build. Do not modify or deploy the game. Current identity references are drafts for the film; don't claim they already match the shipped app.

Create `design-system/reel/production/` with assets/{audio,character,art,fonts}, compositions/, qa/, transcripts/, exports/. Copy the needed frozen references there without altering source art. Record asset IDs, hashes, source paths and adaptation prompts.

## 1. Prepare the video runtime

The planning environment had Node v24.13.0, Python 3.14.5, ffmpeg 8.1.2 and ffprobe on PATH. HyperFrames was not installed or runtime-tested during preparation. Verify current tools; no assumptions about Python module compatibility.

Read user-scope GIGS-SKILL-REGISTRY.md. Keep reusable skills at user scope. Read current HyperFrames router and applicable general-video/core/creative/media-use/audio/animation/CLI skills. Select the custom general-video workflow: this is a character-led asset-based reel, not a website scrape or automatic faceless explainer.

On Windows prefer `npx.cmd` if PowerShell blocks npx.ps1. Known discovery entry points:

```powershell
npx.cmd hyperframes --help
npx.cmd hyperframes skills update general-video
```

Read current help/skills before init, check, snapshot or render flags. Do not invent a CLI API from this plan. Pin the working package version inside the video project and record it. Follow any framework-required usage check; report unavailable usage as unknown. Scaffold only the video project.

Use local fonts and media, with explicit load/decode readiness before any capture. One framework-owned audio track drives the VO, one seekable master timeline drives animation. No runtime remote URLs in final render. If tools return assets in another directory, copy them into the project and update the manifest before rendering.

## 2. Voice casting and full take

Use ElevenLabs MCP and VOICE_DIRECTION.md. Re-query voices; generate the audition prompt with Haytham, inspect returned variations, pick a valid take. Try the Egyptian Adam only if needed. Save call IDs immediately and poll the existing run; never submit a duplicate while status is pending.

Generate the full SCRIPT.eleven-v3.txt with the selected voice and same model. Choose one coherent complete take. Preserve provider-original bytes, decode a working copy, inspect and listen. Write `qa/voice-selection.md` with exact voice/model, generation IDs, selected take, errors fixed, duration and audibility notes.

The TTS schema checked during preparation is in references/tool-contracts. Re-read it via MCP before passing parameters in the new turn. The voice should say only SCRIPT.ar.txt words; tags are instructions, not dialogue.

## 3. Align and lock time BEFORE final animation

Transcribe with available speech tools (ElevenLabs speech-to-text or verified local aligner), compare to the script, and inspect the waveform/speech by listening. If returned transcript has no word timestamps, do not pretend it does: derive phrase times by actual review or use a real forced aligner.

Outputs:
- `transcripts/transcript.json`: actual text, word/phrase seconds, confidence where available, review status.
- `transcripts/transcript.srt`: real phrase timing, no performance tags.
- `timeline.locked.json`: same cue/scene IDs as plan, actual frame boundaries, verified speech triggers and retiming reasons.
- `assets/audio/voice-master.wav`: approved working narration only, 48 kHz.

Retiming policy:
1. First spoken onset at 0–150 ms. Remove excess leading silence only at a safe boundary; keep unmodified raw source.
2. Online label is present from frame 0; spoken «أونلاين» must finish before 10 s. If the first take is too slow here, re-perform the opening instead of delaying the product reveal.
3. Keep natural speech at original speed. Aim final spoken word at 56–57 s, leaving at least 1.5 s clean end hold. Film stays 59 s.
4. If a good take ends at 52–56 s, allocate spare time to the opening card hold, vote reaction and investigation decision, inserting pauses only at phrase boundaries. Do not add random dead air within a word or stretch vowel samples.
5. If it exceeds 57.5 s, first remove unnecessary long pauses. If still too long, re-perform briskly; if necessary apply the prepared SHORTENING.md substitutions in order. Re-align after every change.
6. No algorithmic atempo/time-stretch as the default fix. If timing cannot fit while intelligible, report the concrete issue rather than violating the one-minute brief.
7. For visual event at time t use round(t*30); keep audio sample precision. No fabricated phoneme-perfect sync. Cuts never split a stressed word; move to the nearest natural phrase boundary.
8. Reconcile scene lengths cumulatively: [start,end) spans cover exactly 0..1770 without gaps. A transition can overlap visual layers inside a scene; don't double-count duration.

Storyboard boundaries may move to match audio, but order, hook, online emphasis, role accuracy, identity switch and final callback are fixed. Store both planned and locked frame positions for review.

## 4. Presenter build and proof

Use CHARACTER_BUILD.md, imagegen built-in tools, and manifest references. Generate one canonical seated pose, then derive registered layers. Save all selected outputs and rig anchor metadata. Create the 4–6 second test using actual chosen voice. Check character identity, hand-card contact, jaw in speech/silence and seams before authoring all presenter scenes.

All frame generation for the final film is deterministic composition. Do not generate a fresh face for each shot. Do not use a stock mascot or replace the skull with a generic hooded avatar.

## 5. Assemble pictures and sound

Build the 12 scene compositions from timeline.locked.json and frozen assets.

Default online scene: editorial arrangement of three generic game avatars, in separate composition areas, becoming one game arrangement under the verified online statement. Keep the design cinematic, not a fake screenshot or product UI. No claimed voice/video chat.

If a real current app session or approved screen recording is already available, it may replace the editorial online/vote/offline insert after verifying the screen is true and readable. Don't make film production depend on accounts, real players, server writes, Flutter builds or deployments. Do not create fake implemented screens to fill missing footage.

Role actions and public vote result are illustrated examples. Doctor can attempt a save, not guarantee one; detective checks a player. Public citizen elimination may be represented by a whole citizen card leaving the group. These editorial graphics do not modify the app's secrecy rules or imply roles are publicly visible during actual private play.

Stories section follows case-public.json. No solution, truth fields, fabricated quotations or guilty stamps on named cast. If illustrating a move counter, 12→10 belongs to the fresh 2-cost interview action. The scene can simply show the decision and cost without revealing a clue body.

Separate sound tracks: VO, optional score, room tone and three motivated foley cues. Audition frozen audio candidates. Omit an unsuitable effect instead of forcing it into the film. No pre-existing case narration under the presenter.

## 6. Design and render QA

Follow QA_CHECKLIST.md. Run framework lint/check and capture real frames. Inspect full-speed draft with sound and representative 360×640 phone-size playback. Correct actual defects and re-render affected scenes. Do not waive text collisions because an element's bounding box is inconvenient.

Render a draft at output aspect ratio first; final 1080×1920/30 CFR after scene QA passes. Use the original high-resolution card/gallery source files. Do not call a 720px contact-sheet crop a full-resolution asset.

Use FFmpeg/ffprobe for codec, duration/frame count, audio and peak verification. Example metadata query (adapt only the actual output path):

```powershell
ffprobe -v error -count_frames -show_entries stream=index,codec_name,codec_type,width,height,r_frame_rate,avg_frame_rate,nb_read_frames,sample_rate,channels:format=duration -of json design-system/reel/production/exports/MAFIA_ONLINE_REEL_AR_59s.mp4
```

Do not equate successful export with successful QA. Inspect actual rendered images, sound and final encoded file. Account for AAC encoder padding: video must be 1770 frames; reported container duration must remain <60 s and decoded audio must not truncate a word.

## 7. Deliver and record

Deliver final MP4, final still/poster, aligned SRT, editable HyperFrames project, frozen media provenance, locked timeline, voice-selection note and QA report. Link actual absolute output paths. State which checks passed and any unverified item. Never mark STATE complete while any required gate is unverified.

Suggested export names:
- exports/MAFIA_ONLINE_REEL_AR_59s.mp4
- exports/MAFIA_ONLINE_REEL_AR.srt
- exports/MAFIA_ONLINE_REEL_POSTER.png
- qa/QA_REPORT.md

Do not publish, make a PR, commit unrelated staged changes, or clean existing worktrees as part of this video task.
