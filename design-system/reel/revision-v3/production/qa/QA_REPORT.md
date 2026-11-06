# V3 final verification — 2026-10-11

Latest output: `../exports/MAFIA_V3_صاحبك_اللي_بريء.mp4`.

## Verified export

- 57.500 seconds, 1725 decoded CFR frames, 1080×1920, H.264 at30fps, stereo AAC48kHz. SHA-256/complete stream probe in `final.json`.
- Finished audio -15.07 LUFS / -1.50 dBTP. Regenerated Fekry eleven_v3 performance, original pitch/speech speed. Raw60.4s →55.676s after4.724s of protected quiet-gap editing; words/breath edges protected by45ms, joins faded5ms. No gain-only substitution for the rejected calm take.
- 104 spoken script words match the new provider transcript after removing retained performance annotations. Exact old/new source cut mapping: `passion-pause-edit.json`; measured words/line frames: `timeline.locked.json`.
- «أونلاين» starts around8.29s. «وتصوّتوا» and «أهو» are explicit picture timing anchors. Intended performance/pauses and small final voice accents are documented in `research/VOICE-DIRECTION.md` and `voice-energy-lane.json`. No independent numerical passion/listening score is claimed.
- Every final frame was decoded and checked: 1725frames, zero overlapping subtitle frames, no nearly-all-black interval. The longest low-resolution pixel-identical run is17frames (~0.57s), down from61frames in an earlier V3 check. This statistic alone does not certify acting/anatomy; complete ordered sheets and targeted full-size transition frames were visually inspected.
- All14 timed video windows fit their source files, including the0.13s lead/tail blends; no playback beyond a source's last frame. `media-windows.json` retains the actual ranges.
- HyperFrames0.8.147 checks pass with zero lint/runtime/layout/contrast errors and zero layout findings. Structural lint warnings remain and are retained in `check.json`; motion audit was disabled, so its zero count is not claimed as an automated motion-quality pass.

## Picture and sound changes

Six original acting sources plus six real Flutter capture sources. Online council video replaces the empty-room page. Night selections, voting/confirmation, case-note interaction and accusation view are actual release widgets with a seeded local backend. The story capture has240frames and real vertical drag gestures; it is not a live connected multiplayer recording. No game `lib/` code was edited.

New offline group video shows actual eye/shoulder/hand reactions and phone passing. The empty approaching phone in the reveal is covered by a motivated card carry into the group scene. Video/graphic scene windows blend over0.26s. Later tweens continue current transforms (`to`) instead of resetting from stale `from` poses. Phone/reading camera tracks remove long frozen compositions while keeping product text legible. No still-image jaw rig is used.

Fourteen game sound assets were prepared;13 are used across21 editorial sound events. Selection clicks line up with recorded input frame65, and vote confirmation with frame105. Card, join, night/morning, elimination, envelope, paper, wax, string and share events have balanced peaks and short fades. Editorial ad sounds do not modify or claim private in-game night audio.

Caption duplication at the hook and final innocent quote removed. Evidence/phone/question compositions no longer obscure names during their reading beat. Original card art and captured UI are preserved. No real case solution is shown.

## Review and reproducibility

Preview: `http://127.0.0.1:3033/review.html`.
Editable Studio: `http://localhost:3035/#project/project`.

`align.py` now routes to the current passion recording/edit, so running the documented pipeline cannot silently restore the rejected neutral take. That old script/timeline/voice snapshot remains in `research/align-neutral.py` and `qa/before-passion/`. `research/SHOT-BREAKDOWN.md` and `cut-list.json` provide measured scene/word/object timing. Human tone preference and real audience retention remain for the owner's judgment.
