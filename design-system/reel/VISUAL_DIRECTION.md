# Picture, composition, identity and motion

## Canvas and safe regions

- Master 1080×1920 portrait, 30 fps; full-bleed art allowed.
- Conservative content box: **x=80..900, y=180..1540**. This reserves the rightmost 180 px and lower 380 px for common reel controls/captions. It is a working safe area, not a claim about every platform UI.
- Face, role names, CTA and clue labels must remain inside it throughout movement.
- Primary presenter face centre near (520,620); skull/hood occupies about 370–440 px width. Body extends lower. Table edge near y=1320.
- Opening card lands centred near (430,1180), whole card about 300×450 px, no text overlay on the painting. Final transform may tilt <=6 degrees; inspect all corners for safe-area clearance.
- Small permanent opening label «مافيا أونلاين» near x=100..460,y=200..280. Clear but subordinate to face and hook. It is visible at frame 0, not faded in five seconds later.
- Headline box x=100..880, y=1390..1530 when unobstructed; move to y=340..490 on card/hand shots. Do not blindly pin text over the card.
- Keep at least 48 px painted clearance between independent text, face, hands and essential card areas. Check actual raster edges, not just DOM bounds.

## Typography

- Mafia: Cairo 800/900 headline 68–84 px, max 2 lines, line-height 1.3; Plex Sans Arabic 500/600 labels 42–48 px.
- Stories: Aref Ruqaa Bold case title 72–86 px, generous line-height 1.5 for marks/descenders; Plex body/labels 44–52 px.
- Brand CTA 64–72 px. Secondary brand label >=40 px. No tiny UI screenshot at full-phone scale; use art-led closeups unless real UI is readable.
- RTL containers, explicitly LTR number groups. No letter-spacing on Arabic, no nonuniform text scale, no reverse-character hack. Fonts local.
- One editorial phrase at a time; max ~4 words generally. Three question labels can coexist only after each has landed.
- Main render uses sparse editorial text, not a dense full-script subtitle rail. Deliver an accurately aligned SRT separately. A captioned export may be added only if it remains readable without competing with scene headlines.

## Identity

Frozen design files: `references/identity/mafia/` and `references/identity/stories/`. Use their tokens, not colours from _legacy.

Mafia: #0F0F0F ground, #E9E4D9 bone, #C2BDB2 parchment. Slate #272F2E for the stage/phase inserts. Oxblood #562627 only for a public commitment/verdict if needed. No decorative gold headline. Brass represents value, which this reel is not selling.

Stories: #150B06 ground, #E1D0AC paper, #B36E2D amber, #6E1A16 verdict/accusation; warm full-colour portraits. Paper carries close reading. Ruqaa belongs to case title, not every sentence.

Use one upper-right light in the host setup (screen right, RTL start). Existing illustrations with a different painted light are separate inserts; do not mirror the whole artwork to fix lighting because that reverses card letters. Prior docs contain an upper-left/new-art contradiction: the approved host setup uses upper-right consistently.

## Scene language

The video explains with existing game art. Original abstract arrangements of portraits/cards are editorial illustrations, never presented as screenshots of an implemented UI. Do not build a fake lobby, chat, voice waveform, online map or fabricated player count. Online may be illustrated by separate portrait areas connecting across the composition under «كل واحد من مكانه»; no feature claim about voice/video chat.

One main subject per shot. Character appears at opening, brief reaction, pivot and ending. Actual cards illustrate roles. Extra-role cards, coins, shop and cosmetics remain out of this one-minute story.

Offline: existing table image + one card moving between two player positions. Don't draw fingers holding a phone with made-up UI. If actual pass-screen footage already exists and is readable, use it instead.

Stories: show ONLY the selected case. Use public action titles and cast in `case-public.json`. A drawn manila action slip is an editorial explanation. If showing move cost, illustrate a fresh-case budget **12 → 10** after the verified 2-point interview action. Do not imply one action is always one point. Do not show all clues from that action as if already verified on screen; avoid answer-revealing clue bodies altogether.

## Signature transition: card to dossier

On C13's invitation, host withdraws hand and leaves a complete card on the table.
At C14's «قصص وتحقيقات», hard cut to a **case folder in the same screen position and angle**. The card does not literally become an in-game investigation item. Change the entire environment to the warm desk at the cut. No crossfade mixing Mafia skull/hood into Stories.
For the first 8–12 frames after the cut, the folder stays aligned, then the view pulls back enough to reveal cover_01 and the warm scene. Pictures and paper assemble over ~12 frames without elastic bouncing.
Return to Mafia on C18; no Mafia host over Stories art between C14 and C17.

## Motion principles and values

- One master time, deterministic seek. Every transform is a function of composition time. Paused GSAP timelines are acceptable only if driven by HyperFrames time; no free-running CSS/WAAPI/GSAP/RAF, timers or unseeded noise.
- Entrances: typically 6–10 frames and 18–40 px travel. Text scales 0.98→1 at most, not huge elastic overshoot. Readability starts after the move.
- Camera: opening close to medium over 18–24 frames; night inserts use cuts at phrase boundaries; reaction uses one 1.04× push; Stories folder uses matched geometry then a slow 1.06→1 settle.
- Don't animate everything simultaneously. Static holds are intentional; card delivery, vote result, investigation choice each get a single clear action.
- Light and grain remain stable. No flickering texture, smoke over eyes, continuous idle pan, pulsing title or glowing eyes.
- Role cards stay whole, unmodified and untinted. Scale/position/rotation of the entire card is fine. Presenter is separately adapted promotional art.
- During body speech, tiny bounded head drift <=2 px and <=0.5°; meaningful gestures are authored, not random. Skull has no eyeball blink.

## Opening micro-timing (target until audio is aligned)

| Frames, exclusive end | Picture | Audio/text |
|---|---|---|
| 0–6 | Face already present. Card is already moving toward viewer; no empty establishing frame. | First speech onset within 0–150 ms; online badge already visible. |
| 6–15 | Card decelerates to its landing; hand still contacts edge. | Dry card-contact foley at contact, below speech. |
| 15–36 | Hand lifts off and retreats 30–50 px; head holds viewer. | «إنت المافيا». Hook text uses its own upper slot. |
| 36–84 | Card holds; very slight head tilt. | «وهما لسه مايعرفوش». Don't add scary sound. |
| 84–120 | Camera widens enough to reveal seated posture. | Challenge question begins. |
| 120–165 | Camera holds; no new competing object. | Challenge completes. |
| 165–315 | Editorial online connection composition or verified readable app insert. | Product name and online promise. |

These are design keyframes, NOT phoneme timings. Retarget speech gestures to true cue boundaries in timeline.locked.json.
