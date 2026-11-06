# Mafia identity — «سيد المافيا»

> **For agents.** This file is complete on its own. Read it top to bottom once, open
> `img/_contact_sheet.jpg` to see every reference image with its path, and use
> `tokens.json` / `tokens.css` for values. The living page is `index.html` (open it
> in a browser). If anything here conflicts with `05-zero-leakage-spec.md` or the
> constitution, **the leakage rules win**.

Status: draft v1.0, 2026-10-10. Awaiting owner sign-off. Nothing here is wired into
`lib/` yet (owner rule: agree every screen in HTML first, then implement).

---

## 0. The ten rules (if you read nothing else)

1. **Three inks, never mixed on one screen:** ash (cards, secrecy), slate (stage,
   chapters), house (vault, verdict, money). Ratio across the app 70 / 20 / 10.
2. **In-hand screens use ash only.** Pass, reveal, night action: no slate, no house,
   no oxblood, no brass, no gallery art. This is the leakage rule, not a style.
3. **Oxblood means "the town spoke".** It appears only when something is decided:
   a purchase confirmed, a vote resolved, a player eliminated, a contract sealed.
4. **Brass is value only:** coins, prices, rewards, claim dots. Matte, no glow.
5. **One primary per screen**, parchment `#C2BDB2` fill (on house screens the commit
   button is oxblood instead).
6. **One light per screen**, a single shaft from the top start corner (top-right in
   RTL), max 12% opacity. No other gradients.
7. **Art is never boxed.** Paintings feather into the ground. No rounded image cards,
   no borders drawn around a painting, nothing drawn on top of a card face.
8. **The card index is the numbering system.** Chapter numbers, role letters and
   sheet indices are Bebas Neue tags in the corner, like a playing card.
9. **Two voices of type:** Cairo heavy is the narrator (titles, announcements),
   IBM Plex Sans Arabic is the ledger (everything else). Aref Ruqaa is forbidden here.
10. **No colour enters unmeasured.** New colours are sampled from a painting
    (`tool/extract_palette.dart` method), never picked.

---

## 1. Who, where, what it should feel like

**Scene:** six to fifteen friends in a dim Egyptian living room or café at night,
one phone passing hand to hand, everyone watching the holder's face and the light on
it. → dark, quiet, low-luminance UI; contrast bought with type, not brightness.

**The metaphor:** a deck of hand-painted Victorian playing cards, an oil lamp, a
narrator with a low voice. The app is printed on the same press as the cards.

| It is | It is not |
|---|---|
| monochrome painted cards, bone paper, engraved silver | neon, purple glow, "hacker" mafia apps |
| warm about the story, cold about the screen | celebratory (no confetti, no fanfare) |
| quiet enough to disappear behind the art | felt-and-wood board-game chrome |
| adult, cinematic, unhurried | Material defaults (ripples, elevation, stock switches) |

---

## 2. Where each ink applies

| Ink | Screens | In-hand allowed? |
|---|---|---|
| **ash** | home, mode picker, players, roles, pass screen, role reveal, night action, settings, how-to-play sheets | **yes, the only one** |
| **slate** | phase announcements (الليل نزل / الصبح طلع), chapter openers, day discussion table screen, outcome paintings | no |
| **house** | الخزنة (vault/store), المجلس (council/rank), المهام, verdict/result, purchase sheets, coin pill | no |

Transitions between inks are the feeling of changing place: from the table (ash) to
the street (slate) to the vault (house). Cross between inks with the existing curtain
crossfade through `#0E0807` (DECK-SYSTEM `seam`) over 400 ms.

A house *element* may sit on an ash screen (the coin pill on Home). A house *surface*
(a sheet) may slide over an ash screen. An ash screen may never be tinted house.

---

## 3. Colour

All values measured from the art in `img/`. Full list with roles: `tokens.json`.

### Ash — measured from `img/cards/face_*.webp`
| Token | Hex | Use |
|---|---|---|
| ground | `#0F0F0F` | background |
| raised | `#1A1A1A` | panels, rows |
| overlay | `#252525` | sheets, pressed |
| line | `#313131` | hairlines |
| rule | `#5A5852` | printed double rule |
| muted | `#908C83` | disabled, tertiary |
| text2 | `#ADA99F` | body |
| parchment | `#C2BDB2` | the one primary button |
| bone | `#E9E4D9` | titles, primary text |

### Slate — measured from `img/stage/*.webp` (chair, door, street)
The chapter paintings carry a faint green-grey cast that the cards do not. That cast
is what makes "the stage" feel like a different room from "the hand".
`deep #0B0D0D` · `wall #1C2222` · `stone #272F2E` · `mist #889697` · `paper #B3AF9E` · `text #E3DFD3`

### House — measured from `img/house/*.webp` (mask, key, raven, vault, seals)
`ground #140F0C` · `panel #1F1813` · `raised #2A211A` · `line #3A2D23` ·
**`oxblood #562627`** (commit) · `oxbloodDeep #3A1416` · `ember #8E3A32` (elimination text) ·
**`brass #C9A45C`** (value) · `brassDim #9F825C` · `text #F1E6D2` · `text2 #C2BBB3`

House ground/panel/brass equal the DECK-SYSTEM tokens (`docs/design/DECK-SYSTEM.md`
on branch `claude/epic-roentgen-094f21`) so nothing already agreed moves.

### Contrast (checked)
bone on ash ground 15.1:1 · text2 on ground 8.2:1 · muted on ground 5.7:1 ·
house text on oxblood 10.0:1 · onParchment on parchment 9.9:1 · slate text on deep 14.6:1 ·
mist on deep 6.4:1 · brass on house panel 7.5:1.

---

## 4. Typography

Fonts are in `../fonts/` and already ship in `assets/fonts/`.

| Voice | Family | Weights | Use |
|---|---|---|---|
| narrator | Cairo (variable) | 800, 900 | wordmark «سيد المافيا», screen titles, phase announcements |
| ledger | IBM Plex Sans Arabic | 400, 500, 600 | body, buttons, names, labels |
| index | Bebas Neue | 400 | Latin card-index tags only: `III`, `DR`, `M`, `CH 3` |
| figures | IBM Plex Mono | 500 | timers `00:47`, coins `1,200`, prices |

Scale (dp): wordmark 46 · announcement 30 · screen title 28 · card title 20 · body 17 ·
meta 15 · caption 13. Line height 1.6, letter spacing 0, Western digits in UI.

Rules: never letter-space Arabic; never use Cairo for body; never use Aref Ruqaa
(it belongs to Stories); Flutter variable fonts need `FontVariation('wght', …)`.

---

## 5. Signature elements (what makes a screenshot recognisable without a logo)

### 5.1 Card index tag
The role letter + suit glyph in the corner of every card face (`DR ✚`, `C ♠`, `M`)
becomes the numbering system of the whole game.
- Bebas Neue 26 dp over a 14 dp glyph, bone, top-start corner; optional mirrored copy
  rotated 180° in the bottom-end corner (only on framed panels).
- Used for: chapter numbers (`III ☾`), sheet headers, section numbers, rank tier.
- Never used as a decorative pattern, never more than two per screen.

### 5.2 The seal (الختم)
An oxblood wax disc carrying the two-faces mark (`img/brand/splash_mask.webp`, desaturated).
Existing art: `img/house/seal_trio.webp`, animated `img/motion/wax_seal_stamp.webp`.
- Appears only at commitment: confirm purchase, vote resolved, contract claimed, group saved.
- Size 52 dp beside a commit button, 96 dp as a moment.
- Always the same seal. No other round red icon exists in the game.

### 5.3 One lamp
`linear-gradient(215deg, rgba(233,228,217,.10), transparent 45%)` from the top start
corner. On slate it may reach .14. It never moves and never pulses.

### 5.4 Halftone grain (slate only)
The chapter paintings show a printed dot screen. Slate grounds carry it at 7%:
`radial-gradient(rgba(220,216,203,.07) 1px, transparent 1.3px) 0 0/4px 4px`.
Never on ash (in-hand) screens, never on house.

### 5.5 Printed double rule
Frames echo the card border: 1 dp `#5A5852` outer, 5 dp gap, 1 dp inner. Used for
framed panels and the index demo. Replaces drop shadows everywhere except the
sheet's single top shadow.

### 5.6 Feathered art
Paintings fade into the ground with a mask (bottom 40% for heroes, radial for
vignettes). Ratio of feather ≥ 48 dp. No rounded rectangles around art.

---

## 6. Components

All sizes in dp. RTL first; "start" = right.

**Primary button (ash).** 56 high, radius 4, parchment fill, Cairo 700 18, `#141312`
label. Pressed `#8D8169`. Disabled 40% + a reason line under it. One per screen.

**Ghost button.** 48 high, 1 dp `#313131` border, parchment label, Plex 500 15.

**Commit button (house).** 56 high, oxblood fill, 1 dp `#7A3A36` border, house text,
paired with the 52 dp seal at the end side. Only on house sheets.

**Value pill.** height 28, house panel fill, 1 dp `#3A2A20`, brass coin glyph 14 +
Plex Mono 12 brass amount. Hidden until the first match ends (DECK-SYSTEM rule).

**Sheet.** Top radius 18, slides from bottom 260 ms, handle 36×4, max 90% height,
primary pinned to bottom. Ash sheet = overlay `#252525`; house sheet = panel
`#1F1813` with the feathered hero art across its top 200 dp.

**Row.** 56 / 72 high, 46–56 art thumb radius 6 (only thumbnails get radius), title
Plex 500 15–17, meta 12–15, divider 1 dp in the ink's line colour.

**Phase announcement.** Slate deep ground, painting covering top 68% with bottom
feather, chapter index top-start, caption (mist 13) + headline (Cairo 800 30–34,
slate text), progress line 2 dp at bottom (stone track, paper fill). Holds 3 s.

**Role card.** Unchanged from `DESIGN.md`: one fixed 1024×1536 box, painting whole,
nothing drawn on it, name + one line under it in fixed-height slots.

**Empty / error.** Hooded figure (`img/people/avatar_*.webp`) feathered, one line,
one button «جرب تاني».

---

## 7. Imagery catalogue

Every file below is in `img/` (resized to 720 px for reference). The full-resolution
originals live at the app path shown. Open `img/_contact_sheet.jpg` to see them all.

| Reference | App path | Ink | Use |
|---|---|---|---|
| `cards/face_{mafia,doctor,detective,citizen,elder,silencer,sniper}.webp` | `assets/images/card_face_*.webp` | ash | role faces. Never crop, tint, overlay |
| `cards/back.webp` | `assets/images/card_back.webp` | ash | card back, home ornament |
| `grounds/home.webp` | `assets/images/bg_home.webp` | ash | home ground |
| `grounds/night.webp`, `day.webp`, `vote.webp` | `assets/images/bg_*.webp` | slate | phase grounds |
| `grounds/online_night.webp`, `online_verdict.webp` | `assets/images/online/backdrop_*.webp` | slate / house | online table, verdict spotlight |
| `grounds/canvas_texture.webp` | `assets/images/canvas_texture.webp` | any | paper grain source |
| `stage/chair.webp`, `door.webp`, `street.webp` | owner references 2026-10-10 (chapter art; prepared set lives in `raw_assets/update11/` on the epic-roentgen worktree, untracked) | slate | chapter openers, announcements |
| `outcomes/{death,saved,mafia_win,town_win}.webp` | `assets/images/outcome_*.webp` | slate | morning reveal, result |
| `people/avatar_{male,female}.webp`, `hood_gloved.webp` | `assets/images/online/avatar_*.webp` | ash | player seats, empty states |
| `people/council_table.webp` | `assets/images/experience_v2/council.webp` | house | council hero |
| `house/{mask,key,raven}.webp` | store items (owner references) | house | vault item art |
| `house/vault_hero.webp`, `store_hero.webp` | `assets/images/store_v3/vault_hero_v3.webp`, `store_v2/store_hero.webp` | house | vault sheet hero |
| `house/frame_{crimson,gilded}.webp`, `plate_ember.webp`, `narrator_noir.webp` | `assets/images/store_v2/*` | house | cosmetics |
| `house/seal_trio.webp` | `assets/images/council/contract_bonus_all3.webp` | house | seal reference |
| `house/coins.webp` | `assets/images/store_v3/coins_pack_medium.webp` | house | value art |
| `motion/*.webp` | `assets/images/motion/*` | per use | transparent sprite sheets (seal stamp, candle, smoke, crow) |
| `brand/splash_mask.webp` | `assets/images/splash_mask.webp` | ash | the two-faces mark |

### Art direction for new Mafia images (brief for Codex / image models)
> Hand-painted oil illustration, Victorian playing-card engraving feel, near-
> monochrome charcoal and bone, visible brush texture, single hard light from the
> upper left, deep shadow, faceless hooded figures (no visible faces), no text, no
> modern objects. For stage scenes add a faint green-grey cast and a subtle printed
> halftone. For house items: oxblood velvet, tarnished brass, aged gold leaf, black
> ground, soft smoke; matte not glossy. Square 1024 or portrait 1024×1536.

Never: story suspect portraits (they belong to Stories), colour photography,
cartoon style, faces on Mafia figures, bright skies.

---

## 8. Motion

| Token | ms | Use |
|---|---|---|
| press | 100 | press feedback |
| state | 200 | changes inside a screen |
| route | 300 | route and phase dips |
| sheet | 260 | sheet in/out |
| flip | 600 | the card flip |
| phaseHold | 3000 | announcement hold |
| stagger | 40 | post-game lists |

Ease: `cubic-bezier(.22,1,.36,1)`. No bounce, no elastic, no pulse on the lamp.
Reduce Motion ends in the finished state and never changes durations (a faster game
would itself be a signal). In-hand motion is identical for every role.

---

## 9. Copy voice

Egyptian spoken Arabic, narrator register. «الضلمة نزلت على البلد» not «حل الظلام».
Short. Titles are scenes, buttons are verbs: «ابدأ اللعبة», «سلّم الموبايل», «اختم الشرا».
No exclamation marks on loss. No emoji in UI.

---

## 10. Do / don't

**Do:** let the painting carry the screen · use the index tag for numbers · keep
oxblood rare so it weighs something · matte brass figures in mono · double printed
rules instead of shadows · one parchment button.

**Don't:** shiny gold, glow, gradient text · saturated red `#FF0000` family or neon
purple · identical icon+title+text card grids · code-drawn fleur-de-lis around
everything (ornament lives in the paintings) · glassmorphism or blur · any colour
not measured from a painting · Ruqaa, typewriter or handwriting fonts.

---

## 11. Ship checklist for any Mafia screen

- [ ] Which ink owns this screen? Only one.
- [ ] Reachable while the phone is in a hand? Then ash only, no art except the role card, identical for every role.
- [ ] Exactly one primary action.
- [ ] Oxblood used only for a commitment; brass only for value.
- [ ] One light, from top start. No other gradient.
- [ ] Every painting feathered, none boxed.
- [ ] Numbers in Mono, indices in Bebas, titles in Cairo, body in Plex.
- [ ] 360×640 and 430×932 checked, RTL.
- [ ] Leakage goldens still green (`test/golden/leakage/`).
