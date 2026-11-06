# Presenter asset specification and generation prompts

## Required preparation at production time

Read the installed imagegen skill and inspect frozen reference images with view_image. Use the built-in image generation/editing tool for raster creation/editing. Do not substitute Python/Pillow painting or a generic SVG face for the actual Mafia character. File copying, hashing and metadata inspection are fine.

References (see manifest IDs): `mafia_gallery`, `card_mafia`, `stage_chair`.
The original is a skull-faced torso/standing figure inside a card frame. There is **no ready seated speaking rig**. This is a real production dependency, not an existing file.

## A. Canonical key image prompt

Use the attached Mafia gallery and role-card images as strict character references. Create ONE canonical vertical 9:16 promotional illustration of the SAME character, seated behind a dark simple table, medium waist-up shot. Preserve the exact recognisable skull proportions, black hood silhouette, ornate dark coat, silver embroidery and painted engraving/oil texture. Bone-charcoal near-monochrome palette, calm green-grey room shadows. One soft but directional key light from upper screen right. The face must be readable at phone size, skull eyes remain hollow, no glowing eyes, no flesh or human lips. Confident quiet posture, torso facing viewer with only a slight three-quarter turn. Lower jaw resting closed. Both clothed forearms anatomically coherent and visible above the table. One gloved hand rests near an empty space where a playing card will be composited later; the other rests calmly. Background chair and simple shadowed room echo the chair reference, but do not reproduce a second hooded figure. Leave clear space near top left and below the face for separately typeset Arabic. No text, letters, symbols, playing cards, logo, speech bubble, new accessories, weapons, new face, cartoon style, glossy 3D, neon, smoke obscuring face or elaborate new scenery. Compose face near (520,620) in a 1080×1920 design, table edge near y1320, with essential content inside x80..900,y180..1540. Deliver high-resolution source preserving painterly detail.

Create a separate presenter asset; never overwrite the role-card or gallery files. Copy selected outputs into production/assets/character and record returned path, prompt, generation provenance and checksum.

## B. Build a reusable layer rig from the canonical image

Preferred layer set, with a documented fixed registration coordinate system:

1. `room-table-chair.png`: clean environment, no character/hand/card, opaque plate.
2. `torso-arms-rest.png`: transparent figure torso, sleeves and resting arms, with sufficient overlap behind head; no background.
3. `head-upper.png`: transparent skull upper/head+front hood; excludes separate mandible. Preserve geometry, teeth and texture.
4. `jaw.png`: isolated lower mandible/teeth from the SAME image, transparent. Upper teeth remain in head layer, lower teeth only in jaw.
5. `forearm-deal.png`: transparent matching sleeve/gloved hand in contact pose; prepare enough sleeve overlap so translation does not detach the wrist. Resting duplicate forearm must not remain visible underneath.

Do not ask a generator to return a flattened contact sheet as usable individual layers. Derive outputs through tightly scoped edits, one element at a time, with the canonical frame as reference; preserve registration and use alpha. The image tool may return differing sizes: record each actual size and align using measured landmarks, not an assumed matching canvas.

Edit instruction template:
“Using this canonical image, isolate ONLY [layer] with transparent background. Keep the same painted pixels/appearance, pose, proportions and lighting as closely as possible. No new face, outfit, pose or embellishment. Retain complete overlap area [description] needed for compositing. Do not draw text. Return a single layer, not a grid.”

For the clean plate, explicitly remove the figure and reconstruct only the previously occluded chair/room/table consistently. Never use that plate as a claim of a real photograph.

## C. Rig and talking behavior

- Record anchor points in `character-rig.json`: shoulder, elbow/wrist, neck rotation centre, left/right jaw hinges, card-contact point; units in source px plus normalised coordinates. No guessed rig values promoted to final without visual check.
- Jaw rotation starts at 0–2.5° and translation <=3 px at a displayed 400 px head height. Maximum opening <=6 px. Increase only if tiny and invisible; reject rubber stretching or floating teeth.
- No human phoneme lip shapes. A skull needs restrained mandible motion driven by speech energy, not human lipsync.
- Precompute audio energy at <=10 ms hops, smooth attack ~40 ms/release ~80 ms, and gate it with reviewed speech intervals. Use the envelope as the main jaw driver. A small deterministic syllable modulation is allowed only during real speech. Test it; no claim of phoneme-perfect sync.
- Gate the energy envelope down across the last 2 frames of each reviewed speech interval and clamp to rest by 2 frames after the offset; this overrides a longer release tail. During silence >120 ms the jaw stays at rest. No jaw chatter during music/foley.
- Turn/tilt whole head slightly around neck anchor; never rotate jaw independently out of its skull plane. No fabricated blinking.
- Card is a separate complete original image. Animate hand and card together while touching, then release; contact must be causal. Keep the actual card artwork undistorted beyond mild whole-plane perspective.

## D. Acceptance gate before all scenes

Render a 4–6 s test with actual audition audio. Inspect first, middle, open-jaw peak, silence, card contact and wrist overlap at output scale and 2×. Must pass:
same character as reference; intact outfit/skull; no double hands/teeth; correct card contact; mouth rests in silence; voice feels attached to the figure; readable face on phone.

If isolated layers drift, repair/re-register using the canonical image. A limited set of aligned mouth-region patches derived from the same canonical view is the fallback, after visually verifying seams. A static image with a global zoom is NOT an accepted talking-host substitute.

If neither rig approach yields acceptable speech animation, stop only the character-dependent full render and state the precise remaining issue; continue other independent production assets. Don't spend repeated full-video generations hoping character consistency improves.
