> **CURRENT — 2026-10-11 / V3 DELIVERED:** Read STATE.json, revision-v3/production/README.md and qa/QA_REPORT.md. Current57.5s1725-frame film uses Fekry eleven_v3 passion1 with protected pause edits, six actual Flutter gameplay capture sources and six generated acting sources, editorial SFX and repaired transitions. align.py restores the current passion take. Rejected neutral/Adam/Haytham versions are archived.

# START HERE — سيد المافيا، ريل «إنت المافيا»

**Handoff v2 · 2026-10-10 · For the next model in THIS conversation.**

**Production update — 2026-10-11:** the user said «ابدأ» and production files now exist under `production/`. Read `STATE.json` and `production/qa/QA_REPORT.md` before resuming. The preparation-only statements below describe the original handoff, not current generation/export status. Preserve completed voice/art; don't regenerate from scratch for an edit.

The user requested a complete preparation package now and will say **«ابدأ»** to start production. This package is ready for that handoff; no voice, presenter image or video has been generated. Do not start production before that message. Do not spawn a new chat or change the chat model yourself.

## The decisions are made

- Original concept; **there is no reference video**. Do not ask for one. This supersedes older discussion.
- The earlier pasted NAQLA prompt is inspiration for a speaking character and deliberate edits only. Its fictional brand, blue/cream palette, cartoon mascot, landscape canvas, mandatory full production at that time and locked supplied WAV are superseded by this reel brief.
- A seated skull-faced Mafia character deals a card toward the viewer and speaks conversational Egyptian Arabic.
- Hook: **«إنت المافيا. وهما لسه مايعرفوش.»** Online badge visible from frame 0; online is spoken in the first 10 seconds.
- Explain the core night → day/discussion → vote loop; offline gets one clear beat; Stories gets its own complete visual identity.
- Case: **قهوة المعلم**. Use the public facts frozen in `case-public.json`. Never show the solution.
- End: **«ونشوف… هتتلقط من أول جولة؟»** with a return to the opening card/character.
- Target: 1080×1920, 30 fps CFR, **59.0 s / 1770 frames**, H.264 + AAC. Final duration must remain under 60 s.
- Default voice candidate: **Haytham - Conversation**, alternate **Adam - Deep, Rich and Expressive** (Egyptian). IDs in `VOICE_DIRECTION.md`; catalogue choices verified, sound not yet auditioned.
- Default film is an **art-led illustrated explainer**, using real game assets. No invented application UI. Real app footage is optional only if already obtainable without modifying/building/deploying the game.
- No YouTube clips, no celebrity montage, no store section, no fake download URL. The latest creative direction supersedes the earlier optional montage.
- One render owner: **HyperFrames**. Read current core/creative/media/audio/CLI guidance before implementation. No onetake code or template dependency.

## Read in this order

1. This file; `SCRIPT.ar.txt` (spoken source of truth).
2. `VOICE_DIRECTION.md`; `AUDIO_EDIT_PLAN.md`; `SCRIPT.eleven-v3.txt` (same words with supported performance tags).
3. `STORYBOARD.md`; `timeline.plan.json` (all frames use inclusive start, exclusive end).
4. `VISUAL_DIRECTION.md`; `CHARACTER_BUILD.md`.
5. `assets.manifest.json`; `case-public.json`; `references/identity/` (frozen copies of both design systems).
6. `PRODUCTION_RUNBOOK.md`; `QA_CHECKLIST.md`; `STATE.json`.

`TREATMENT.md` is a concise current overview. Everything under `archive/` is historical, non-authoritative. Never reuse its old opening or requests for a reference video.

## Accuracy about timing

`timeline.plan.json` is an exact, gap-free **editorial target**, NOT fabricated word alignment. Voice performance cannot be promised to the millisecond before recording. After the selected take exists, transcribe/align it and write `production/timeline.locked.json`. Word-triggered actions follow the actual audio, quantized to 30 fps. Keep audio at native speed. `PRODUCTION_RUNBOOK.md` defines the retiming policy and finish budget.

## Scope after «ابدأ»

Execute the prepared production workflow, including normal voice audition, image generation for the presenter, animation, checks, corrections and local MP4 export. Continue through routine reversible choices without re-opening the creative brief. Respect tool-enforced permissions if they appear. Do not publish, upload to social accounts, message anyone, deploy the app, or change game code.

Do not treat the planned output as already made. If a needed tool is unavailable, use the documented honest fallback where possible and report the specific remaining limitation. Do not replace the animated presenter with a static zoom and call it complete.

## First command after reading

From the worktree root:

```powershell
python design-system/reel/verify_package.py
```

Then follow `PRODUCTION_RUNBOOK.md`, updating `STATE.json` at each completed milestone. Outputs belong in `design-system/reel/production/` and must reference frozen local media.

`prepare_package.py` was a preparation helper. **Do not rerun it during production**: it would restore the original planning script/timing and overwrite later editorial changes. Use the read-only verifier instead. The original worktree paths in the asset manifest are provenance, not runtime dependencies; the frozen paths work without the other checkout.

## Copyable start instruction

> ابدأ تنفيذ الريل من design-system/reel/START_HERE.md. اعتبره حزمة التسليم المعتمدة للاتجاه والسكريبت. نفّذ لحد فيديو MP4 تحت الدقيقة، وافحص الصوت والصورة والحركة فعليًا. خليك على صور اللعبة والهويتين، وحدّث STATE.json. مفيش فيديو مرجعي مطلوب، ومفيش نشر أو تعديل في كود اللعبة.
