# Read-only MCP guide snapshot — 2026-10-10

Re-query at production time; no speech generated.

# ElevenLabs TTS family — eleven_v4, eleven_v3, eleven_multilingual_v2, eleven_flash_v2_5, eleven_turbo_v2_5

The "prompt" for a TTS node is the text the voice will speak. There is no scene description.

## Rules

- **Punctuate for delivery.** Commas and periods create natural pauses. Ellipses (…) create longer thoughtful pauses. Em-dashes (—) create short beats.
- **For emphasis, capitalize key words sparingly** (e.g. "I told you NOT to do that") rather than describing the emphasis.
- **Numbers, prices, phone numbers, and URLs:** on `eleven_v4` and `eleven_v3`, keep them exactly as the user wrote them, in digits or words, including in a script the user provided. In a script you write, use the normal written form for the script's language ("19,99 €", "555 123 4567", "example.com/support"), not words. On other models, format them for natural delivery:
  - URLs: "example dot com slash support"
  - Phone numbers: pause-separated ("five five five… one two three… four five six seven")
  - Currency: "nineteen dollars and ninety-nine cents"
- **Pronunciation:** only when the user asks, or in a script you wrote when the voice will very likely misread a word; the fix replaces the word in the displayed text and captions. On `eleven_v4` and `eleven_v3`, replace the word with its IPA between slashes ("Meet Siobhan" is sent as "Meet /ʃɪˈvɔːn/"). On other models, respell it ("Meet Shih-VAWN").
- **Voice choice is at least as important as the text.** Pick a voice whose character matches the intended delivery before iterating on wording.

## Audio tags (`eleven_v4`, `eleven_v3` only)

Tags are free-form words in square brackets, placed right before the words they color. Descriptive phrases work too (`[frustrated sigh]`, `[laughs softly]`). A tag holds until the next one, so change tags where the delivery changes, not on every sentence.

- **Describe how the line is spoken**, not what the speaker does. Stage directions like `[grinning]`, `[pacing]`, `[standing]`, or `[music]` are not performed.
- **Plain words, no hyphens:** `[high voice]`, not `[high-pitched]`; `[singing]`, not `[sing-song]`.

- **Emotion:** `[excited]`, `[happy]`, `[sad]`, `[angry]`, `[nervous]`, `[curious]`, `[sarcastic]`, `[surprised]`, `[tired]`, `[warmly]`
- **Delivery:** `[whispers]`, `[shouting]`, `[softly]`, `[dramatically]`, `[mischievously]`, `[cautiously]`, `[slowly]`
- **Voice quality:** `[deep voice]`, `[high voice]`, `[raspy]`, `[breathless]`, `[trembling voice]`, `[childlike voice]`, `[elderly voice]`
- **Non-verbal:** `[laughs]`, `[laughs harder]`, `[chuckles]`, `[giggles]`, `[sighs]`, `[exhales]`, `[gasps]`, `[clears throat]`, `[crying]`, `[snorts]`
- **Pauses:** `[short pause]`, `[pause]`, `[long pause]`
- **Dialogue timing:** `[interrupting]`, `[jumping in]`, `[overlapping]`

Stack tags for layered emotion: "[sad] [whispers] I kept the porch light on every night, just in case you came back."

Example: "We did it. [gasps] We actually did it! [laughs] [whispers] Okay, nobody tell the boss yet."

### Examples by use case

- **Ad / promo:** "[excited] Big news! Every Tuesday, it's two pizzas for the price of one. [warmly] Bring a friend."
- **Narration:** "The house had been empty for years. [nervous] And yet, that night, someone had left the porch light on."
- **Meditation:** "[softly] [slowly] Breathe in… and let it go. [long pause] Notice how your shoulders feel."
- **Comedy:** "[sarcastic] Oh, great. Another Monday. [sighs] Just one more meeting, they said."
- **Dialogue** (one line per speaker node): "[excited] So I was thinking we could—" / "[jumping in] —test the new timing? [laughs] Lucky guess."

### Sound effects, accents, and singing

Use these only when the user asks or the script calls for them:

- **Sound effects:** `[applause]`, `[clapping]`, `[gunshot]`, `[explosion]`, `[swallows]`, `[gulps]` — "[clapping] And that's a wrap on season one! [explosion] Okay... who brought the fireworks?"
- **Accents:** `[strong X accent]` — "[strong Scottish accent] Right, pop the kettle on and we'll get started."
- **Singing:** `[singing]` — "[singing] Good morning, sunshine, the coffee's on its way..."

### Getting the best performance

- **Longer passages give tags more room.** For a one-line script, offer a few takes.
- **Tags, punctuation, and capitals work together:** "[tired] Twelve hours on the road... [sighs] and they gave our room AWAY."
- **Pauses** come from `[pause]` tags and ellipses; `<break>` is for the models in the next section.

## Models without tags (`eleven_multilingual_v2`, `eleven_flash_v2_5`, `eleven_turbo_v2_5`)

These models speak bracket text as words, so keep audio tags out. Shape emotion with punctuation, sparing capitals, and word choice. For a precise pause, use `<break time="1.0s" />` (up to 3s), a few per script at most.
