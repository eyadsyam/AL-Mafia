# AI_BRIEF.md — the paste-in brief for photo & video generation

What to hand an AI tool so it understands **Mafia Master / سيد المافيا** before it
makes a single frame. Promotional and marketing imagery only.

| You want | Use |
|---|---|
| Promo photos, social posts, app-store art, trailers | **this file** |
| In-app assets — card faces, backdrops, onboarding art | `tool/IMAGE_PROMPTS.md` (has hard luminance budgets; this file has none) |
| The brand rules themselves | `BRAND_KIT.md` |

**Do not mix the two.** In-app art is leakage-critical and must pass `flutter test
test/golden/leakage/`. Marketing art is seen by everyone at once and is free —
it may be warm, lit, colourful and dramatic in ways no in-app surface may be.

---

## How to use this file

1. **Chat-style AI** (Claude, GPT, Gemini): paste **§1 THE BRIEF** first, then ask
   for what you want. It now knows the game.
2. **Image models** (Midjourney, Firefly, Flux, Higgsfield, Imagen): paste
   **§3 STYLE BLOCK** + one **§5** subject + **§4 NEGATIVE**.
3. **Video models** (Sora, Veo, Kling, Runway): use a **§6** shot prompt whole.
4. **A real camera:** §5 and §6 double as a shot list — framing, lens and lighting
   are written to be shootable.

---

# 1. THE BRIEF — paste this verbatim

```
PRODUCT: Mafia Master (Arabic: سيد المافيا). A mobile app that acts as the
moderator for the party game Mafia (also called Werewolf), played face-to-face
around a table.

HOW IT IS PLAYED: 6 to 15 friends sit in a circle. ONE phone is passed from hand
to hand. The app secretly deals each player a role — Mafia, Doctor, Detective, or
Citizen. At "night" each player takes the phone in turn, holds it privately, sees
only their own role and makes their secret move, then passes it on. At "day" the
phone lies face-up on the table for everyone and the group argues about who the
Mafia is, then votes someone out. Repeat until the Mafia are gone or they
outnumber the town.

THE APP REPLACES A HUMAN MODERATOR. There is no online play, no accounts, no
network, no profiles, no chat, no multiplayer lobby. Everyone is in the same
room. The phone is a physical prop on a table, like a deck of cards or a
scorepad.

WHO PLAYS IT: Egyptian Arabic speakers, roughly 16–35, in a living room, on a
balcony, in a café (ahwa), in a dorm. The app is Arabic-first and right-to-left;
English is a fallback. Ramadan evenings and long weekend nights are peak play.

THE CENTRAL PROMISE, AND THE THING TO DRAMATISE: the person NOT holding the phone
must learn nothing from watching. So the app is deliberately near-black and dim —
the screen does not light up the holder's face, does not flash, does not make a
sound, and takes exactly the same amount of time for every player whatever they
drew. A bright phone would give its holder away. This is the whole product.

WHAT IT LOOKS LIKE: a deck of hand-painted noir playing cards. Four painted role
cards in oil-and-gouache, warm-neutral, aged and printed rather than digital. The
app around them is charcoal, graphite and bone white, with a single aged-parchment
accent. Textured like canvas and old print stock. Typography is large, quiet and
confident. It is adult, cinematic and unhurried.

TONE: a fairy tale about a village that goes to sleep and wakes up with someone
missing. Warm about the story, cold about the screen. Tension, secrecy, laughter
between friends, accusation across a table. Never cute, never neon, never
celebratory.

IT IS NOT: a cartoon or kids' game; an online/social app; a hacker or cyber
aesthetic; a Las Vegas casino; a gangster shooter; Among Us; a corporate SaaS
product.
```

---

# 2. The one image that sells the app

If you make a single hero frame, make this one:

> A dark room lit warm by one lamp. Five or six friends around a low table, faces
> alert, leaning in. One person holds the phone low and tilted away from everyone
> else. **The phone's screen is nearly black — it does not light their face.** The
> warm room, the cold sliver of screen, and a face that stays in shadow.

That contrast — **warm room, cold screen, unlit face** — is the product promise
rendered literally. Every other shot is a variation on it.

---

# 3. STYLE BLOCK — paste verbatim

```
Cinematic editorial photograph. Shot on a full-frame camera, 35mm or 50mm prime,
f/1.8, shallow depth of field, natural grain, no digital sharpening. Low-key
lighting: one warm practical light source in frame or just outside it — a table
lamp, a hanging bulb, a candle — with deep falloff into shadow and no fill. Rich
blacks, warm amber and tungsten highlights against cool shadow. Muted, filmic
colour grade, slightly desaturated, gentle halation on the highlights. Real
lived-in interior with worn textures: fabric, wood, old paint, chipped glass.
Documentary feel, unposed, caught mid-moment. Adult, restrained, intimate,
tense. Composed with generous negative space and room at the top of the frame.
```

**For a flat-lay / product shot instead**, replace the last two sentences with:

```
Overhead flat-lay on a dark worn wooden surface, raking light from the upper
left, deep shadows, styled sparsely with generous negative space.
```

---

# 4. NEGATIVE PROMPT — paste verbatim

```
Arabic text, arabic script, text, letters, words, captions, subtitles, watermark,
logo, signature, UI, app interface, screenshot, bright phone screen, glowing
screen, screen glare lighting a face, neon, purple, cyan, RGB lighting, glow,
lens flare, HDR, oversaturated, teal-and-orange grade, cartoon, anime, 3D render,
CGI, plastic skin, stock-photo smiling, thumbs up, posed group photo looking at
camera, casino, poker chips, playing card suits, roulette, cash, guns, violence,
blood, masks over faces like a horror film, hoodie hacker, matrix code, confetti,
balloons, party hats, children, cluttered background, ceiling light, flat even
lighting, studio softbox
```

---

## Four gotchas that will ruin the shot

**1. Never let the model render Arabic.** Every image model produces broken,
meaningless Arabic glyphs — reversed, disconnected, misshapen. It looks illiterate
to your audience. Generate the frame with **no text at all**, then set the Arabic
in post using the brand faces (Cairo / Bebas Neue / IBM Plex Sans Arabic). This is
in the negative prompt for a reason.

**2. Never let the model render the app's screen.** It will invent a fake UI.
Prompt the phone as **switched off / screen dark and reflective**, then composite
a real screenshot in post. You get a correct, dim, on-brand screen for free.

**3. Faces.** The card art's own rule is *the face is never visible* — turned away,
hooded, or lost in shadow. Echo it. Faces cropped, turned, backlit or shadowed
look intentional, match the deck, dodge the uncanny-AI-face problem, and avoid
needing a model release. When you do want visible faces, keep them mid-action —
talking, pointing, laughing — never looking at the camera.

**4. Hands.** Hands holding a card or a phone are where models fail. Keep them
partly out of frame, in shadow, or gripping the phone edge-on rather than splayed.
Generate several and cut the bad ones.

---

# 5. PHOTO PROMPTS

Each is `[STYLE BLOCK]` + `SUBJECT` + `[NEGATIVE]`. Change only the SUBJECT line —
keeping the style block byte-identical is what makes the set look like one
campaign.

### P1 · The handoff — the hero
```
SUBJECT: Two pairs of hands at the centre of a low table in a dim living room,
one passing a dark phone to the other, the screen switched off and reflecting a
single warm lamp. Behind and out of focus, three or four seated friends lean in,
faces half-lit and unreadable. Tea glasses and an ashtray on the table. The moment
of transfer, caught mid-air.
```

### P2 · The holder — the promise
```
SUBJECT: A young woman sits slightly apart from the group, phone held low against
her chest and tilted sharply away from everyone, screen dark. Her face is turned
down and in shadow — the phone gives off no light on her at all. Behind her, warm
lamplight and the blurred shapes of friends watching her. Shot from the side at
table height.
```

### P3 · The accusation — the day
```
SUBJECT: Five friends around a table in a warm dim room, mid-argument. One person
points across the table, another laughs with a hand over their mouth, a third
leans back with arms crossed. The phone lies face-up and forgotten in the middle
of the table. Caught mid-sentence, nobody looking at the camera.
```

### P4 · The circle — the wide
```
SUBJECT: Overhead wide shot of six friends seated on floor cushions and a worn
sofa around a low table in a Cairo apartment at night. One lamp in the corner,
balcony doors open to city lights. A single phone at the centre of the table.
Bodies form a loose circle. Warm pools of light, deep shadow between them.
```

### P5 · The deck — the product flat-lay
```
SUBJECT: Overhead flat-lay on dark worn wood: four hand-painted noir playing
cards fanned face-down beside a dark phone lying face-down, a glass of black tea,
and a brass lighter. Raking light from the upper left. Nothing else in frame.
Generous empty space in the upper third.
```
> Composite the real card art and a real screenshot into this one. Prompt the
> cards as **plain dark backs with an engraved medallion**, never as invented art.

### P6 · The café
```
SUBJECT: Four young men at a small table outside an Egyptian ahwa at night,
plastic chairs, shisha and tea glasses, strings of warm bulbs overhead, street
dark behind them. One holds a phone low and shielded with his other hand. The
others watch him. Unposed, documentary, shot from across the street with a 50mm.
```

### P7 · The vertical — for stores and Reels
```
SUBJECT: Vertical 9:16 composition. A single dark phone held upright in one hand
in the foreground, screen off, occupying the lower third. Behind it, thrown far
out of focus, a warm-lit table of friends. Deep empty darkness across the top
half of the frame.
```
> The empty top half is deliberate — that is where your headline and app icon go.

### P8 · The Ramadan night
```
SUBJECT: A family and friends of mixed ages around a table after iftar, plates
cleared, lanterns and warm lamplight, late-night ease. One phone being passed
between two of them. Some women in hijab, some not. Relaxed, laughing, unposed.
```

---

# 6. VIDEO PROMPTS

Video models want **camera + subject + light + motion + duration**, and one shot
per prompt. Keep clips **5–8 seconds**, keep moves slow, and do not ask for
dialogue — the app's own promo is silent or scored, and lip-sync will betray you.

### V1 · The pass (5s) — the signature shot
```
Cinematic 5-second shot, 35mm, shallow depth of field, low-key warm lamplight in
a dim living room. Slow push-in on two pairs of hands at the centre of a low
table as a dark phone is passed from one to the other. The screen stays dark
throughout. Out-of-focus friends lean in behind. Handheld micro-movement, filmic
grain, no text.
```

### V2 · The holder (6s)
```
Cinematic 6-second shot, 50mm, f/1.8. Static camera at table height, side-on. A
young woman holds a phone low and angled away, her face in shadow, lit only by a
warm lamp behind her — the phone casts no light on her at all. She glances up
once, then hands the phone off to the left and out of frame. Slow, quiet,
tense. Filmic grain, no text.
```

### V3 · The circle (8s)
```
Cinematic 8-second shot, slow overhead descent from ceiling height toward a low
table where six friends sit in a loose circle in a warm dim Cairo apartment at
night. A single phone at the centre of the table grows in frame as the camera
lowers. One lamp, deep shadows, balcony light beyond. Smooth crane move, no text.
```

### V4 · The accusation (6s)
```
Cinematic 6-second shot, 35mm, handheld. Warm dim room. Slow arc around a table
of five arguing friends, mid-gesture — one pointing, one laughing, one leaning
back. The phone lies face-up and ignored at the centre. Faces pass in and out of
lamplight. Documentary energy, filmic grain, no text.
```

### V5 · Product turn (5s)
```
Cinematic 5-second macro shot. A dark phone lying face-down on worn wood beside
four face-down painted playing cards. Raking warm light from the upper left. The
camera drifts slowly right to left across the surface at a shallow angle. Dust in
the light. Static objects, no hands, no text.
```

## The 25-second trailer, assembled

| # | Shot | Length | Cut on |
|---|---|---|---|
| 1 | V3 · overhead descent to the circle | 5s | the phone filling frame |
| 2 | V1 · the pass | 4s | hands separating |
| 3 | V2 · the holder, unlit face | 5s | her glance up |
| 4 | *Composited app screen* — the reveal, real footage | 3s | the card turning |
| 5 | V4 · the accusation | 5s | the point across the table |
| 6 | V5 · product turn, title card over | 3s | end |

Shot 4 is a **screen recording of the real app**, not generated. Everything the
audience needs to believe about the product lives in that one cut, and a model
cannot fake it.

---

# 7. Framing specs

| Use | Ratio | Pixels | Leave room |
|---|---|---|---|
| App Store screenshot (6.7") | 9:19.5 | 1290 × 2796 | top 25% for headline |
| Play Store screenshot | 9:16 | 1080 × 1920 | top 25% |
| Play Store feature graphic | 16:9 | 1024 × 500 | left third for the mark |
| Instagram / TikTok vertical | 9:16 | 1080 × 1920 | top 15%, bottom 20% for UI |
| Instagram feed | 4:5 | 1080 × 1350 | — |
| YouTube / landscape trailer | 16:9 | 1920 × 1080 | — |

Generate **2× and downscale**. Detail survives and generation artefacts average
out.

---

# 8. Keeping a set consistent

Consistency comes from process, not from wording:

1. **Anchor on a reference image.** Once one frame is right, attach *it* to every
   subsequent generation. This matters more than any other item here.
2. **Generate the whole set in one session** without touching the style block.
3. **Change only the SUBJECT line.** Never edit the style block mid-set.
4. **Reuse the same room.** One apartment, one lamp, one table across the campaign
   reads as a real place instead of a series of stock photos.
5. **Reuse the same faces** where faces are visible — or keep them all obscured
   and the problem disappears.

---

# 9. Brand colour, for grading and titles

Marketing may be warm. The **screen and the type** may not.

| Use | Value |
|---|---|
| Backgrounds, letterboxing, title cards | `#0D0F14` charcoal |
| All headline and body text | `#E9E4D9` bone white |
| Secondary text | `#ADA89E` |
| The single accent — rules, underlines, buttons | `#C1BCB1` aged parchment |
| Elimination / danger beats only | `#AA3D28` |

Type: **Bebas Neue** over **Cairo** for display, **IBM Plex Sans Arabic** for body.
**Never letter-space Arabic** — the glyphs join, and tracking breaks them.

Grade the footage warm; keep every graphic element on the palette above. The
campaign should look like the app was printed on the same press as the cards.

---

# 10. Facts to get right

An AI will invent these if you let it. Correct it when it does.

- **One phone, passed by hand.** Not everyone on their own device. Not online.
- **6–15 players**, in one room, seated in a circle.
- **Four roles:** Mafia, Doctor, Detective, Citizen — مافيا، دكتور، محقق، مواطن.
- **Night is private, day is public.** The phone is in a hand at night and flat on
  the table by day.
- **The screen is dim on purpose.** A bright, glowing phone in a promo shot
  contradicts the product.
- **Arabic, right-to-left**, Egyptian spoken register — not Modern Standard.
- **No accounts, no internet, no notifications, no leaderboard.**
- **Egypt.** Cairo apartments, ahwas, balconies, Ramadan nights. Not an American
  basement, not a Berlin loft, not a casino.
- **No guns pointed at people, no blood.** The mafia here is a card in a fairy
  tale, not a crime scene.
