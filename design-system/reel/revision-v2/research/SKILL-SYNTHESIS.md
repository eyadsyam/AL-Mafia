# Skills applied / verified boundaries

Read on 2026-10-11, current upstream main, alongside user registry. Sources are retained at user scope, not game code. Supplied prompt read fully from attachment `6f94b2a9-ded2-4370-8594-371ce2dd9e33/Pasted text.txt`.

| Source | Applied to this proposal | Deliberately adapted |
|---|---|---|
| [ig-reel](https://github.com/Jakeschincariol/instagram-agent-skill/tree/main/skills/ig-reel) | 3 distinct hooks, action from first image, online promise early, payoff/loop, separate visible/spoken hooks | Owner's Egyptian Arabic samples already provided; no request for three reference reels. 59s owner target retained. |
| [ig-human](https://github.com/Jakeschincariol/instagram-agent-skill/tree/main/skills/ig-human) | Ran humanize/detect; manual spoken-Arabic editing | Detectors use English lexicon; cannot certify Arabic naturalness or retention. |
| [Lemo director](https://github.com/lemomo-ai/lemo-opuscar/blob/main/DIRECTOR.md) | Three different structures, expressive acting sheets, shot motive, quiet before reveal, ending echoes opening | Generated artwork explicitly requested; no programme-drawn mascot. No reference requested. Toolchain stays HyperFrames; incomplete library clone stopped because large demos unnecessary for idea review. Read upstream director/AGENTS separately. |
| [OneTake](https://github.com/feitangyuan/onetake/blob/main/SKILL.md) | Camera follows cause; phone/card/folder carries; different tempos; prototype seek function | Engine/templates/source motion functions NOT copied or executed. Noncommercial licence retained in user scope. Original implementation of generic camera continuity, with HyperFrames intended for final production. |
| [Collage B-roll](https://github.com/pyang5166/gbro-collage-broll/blob/main/SKILL.md) | Single evidence metaphor: folder → portrait → clue → comparison; keep 3–6 major groups | This is concept review with imagegen as owner requested, not an Omni pipeline run. No video-generation/setup/key request needed now. No saturated cobalt/purple palette or complete film collage look. |
| [HyperFrames](https://github.com/heygen-com/hyperframes) | Plan editable seek-safe assembly of real character clips and true product screens; rendered-frame QA | HTML here is an idea prototype, not a falsely labelled HyperFrames render. Browser playback clock only drives a pure scene function; final runtime uses composition time. |
| frontend-design + UI/UX Pro Max | Editorial theatre page, clear hierarchy, usable tabs and scrubber, scoped motion | Existing Mafia/Stories palette wins over generated generic design-system defaults. UX search for reduced motion/keyboard control read. No autoplay. |

## Tools actually run

`hookscore.py hooks.ar.txt --json` → `hookscore-raw.json`.
`beats.py SCRIPT-A.ar.txt --target 59` → `beats-raw.txt`.
`humanize.py ... --report` → `script-clean.txt`; 0 edits reported.
`detect.py ...` → `human-raw.txt`.

**Important finding:** hookscore/beat tokenizer `[A-Za-z0-9...]` counts these Arabic texts as ZERO words. Their scores and durations are INVALID for this material. They were inspected and rejected, not shown as evidence of quality. Count Arabic whitespace words separately, then use actual Adam audio as master clock. Automated human report likewise is only a limited typography check.

## Editorial comparison, not performance prediction

A: strongest audience connection and clearest unanswered question; actual humans make deception readable. Prefer for first launch.
B: strongest mascot ownership and recognisable game art; risk of stiff skull performance, so body acting and first 4s proof required.
C: strongest spatial continuity and Stories transition; less social connection, better second ad.

Recommendation: A spine, B cameo at the entrance to the night world, C material handoff for the story section. Not three simultaneous styles. Use original game card paintings, filmed/referenced app UI, and one consistent generated cast. Measure real audience retention after publication, never claim a heuristic or combining skills predicts views.

## Acceptance before full production

- Human recognises social Mafia from the first 3s with sound off.
- Online is understood by 5s, privately held roles by 9s.
- The phone view is readable at final vertical size; never a thumbnail of a dense whole interface.
- At least one clear anticipation/action/reaction per cast appearance; no rigged still presented as completed acting.
- Hook question pays off, wrong vote is readable, clues do not reveal real case solution.
- Same object and actual action carry every main boundary.
- Adam first3lines listened to by owner before full narration; no automatic mouth or signal check substitutes for hearing it.
