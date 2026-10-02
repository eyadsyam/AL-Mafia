# 1.1 — Master plan (Claude's draft for the debate with Sol)

Owner rule for this round: **the whole plan first, agreed in full with Sol, then
all implementation.** Every feature ships with its complete art, sound and motion,
or it does not ship. Nothing is published until the owner says so.

Status legend: ✅ built & committed · 🟡 in progress · ⬜ planned.

---

## 0. Pillars (why a player opens the app)

| Pillar | The feeling | Daily reason | Long reason |
|---|---|---|---|
| **The Table** (online play) | "a real night with friends" | friends online, rematch, scheduled night | better tables, series, events |
| **The Casebook** (meta) | "I'm building a career as an investigator" | 3 cases tonight | Season level, titles, achievements |
| **The Four** (characters) | "they know me" | the character of the week speaks | chapters, letters, dossier titles |
| **The Daily Case** (solo) | "one clever minute" | Case of the Day, streak | best streak, share grid |
| **The Crowd** (social) | "my people are here" | invites, commendations | friends list, reputation |
| **Presentation** | "anyone passing by is impressed" | — | every screen painted, every tap sounded |

Board-game lessons we take and how we beat them:
- **Chess.com / Lichess daily puzzle** → Case of the Day, but narrated by a
  character, seats around a table, and a Wordle-style share grid.
- **Blood on the Clocktower** (storyteller) → Scenario Deck + the four
  characters as narrators; later a host "storyteller console".
- **Codenames / Jackbox** (zero-friction groups) → one-tap rematch, invites,
  Best-of-3 series with a shareable final card.
- **Avalon / Secret Hitler** (tension, reputation) → commendations after the
  result, titles on the plate.
- **Ticket to Ride** (the map as progress) → the season trail of 20 stops.
- **BGA** (learning by playing) → the Academy: five playable lessons.
- **Catan / Exploding Kittens** (identity, humour) → Egyptian voice in every
  line; the four characters speak like people, never like a system.

---

## 1. Feature catalogue

Each entry: loop · variety (difficulty/fun) · rewards · Doc 05 · screens ·
**assets** (full list) · flag · owner.

### F1 ✅ The Casebook «ملف القضايا» — Tonight / Season / Legacy
- Loop: 3 daily cases (the existing contracts) + 1 weekly case → Season XP →
  20-level trail → coins/titles/items; lifetime achievements; council rank.
- Variety: daily set mixes one easy (finish 1), one medium (finish 3), one social
  (host / reunion / public table); weekly is the long one. Each case is voiced by
  one of the four (flavour).
- Rewards: per Sol's table (≈1,680 coins max per 4-week season).
- Doc 05: server counts finished rooms with a public outcome only.
- **Assets missing (must add):**
  - `casebook_hero` — painted case wall: cork board, red string, pinned photos
    in silhouette, a desk lamp; 1080×600, dark top fading to black bottom.
  - `season_zero_key` — Season Zero key art (Cairo rooftops at night, the four
    silhouettes looking down on a lit table); 1080×1350, used at level 20 and on
    the season intro.
  - Stop icons for the trail: coin pouch, title ribbon, frame, seal (4 icons,
    256², transparent).
  - Season reward items: **`frame_season_zero`** (gold-oxblood wax frame, the
    level-20 item) + 2 titles (`season_zero_sleuth`, `season_zero_legend`).
  - Sounds: `wax_press` (claim), `paper_slide` (page turn), `level_sting`
    (season level up), `string_pluck` (progress).
  - Motion: claimed slip gets a wax stamp that presses in (scale 1.3→1, 180 ms)
    with coin burst reuse; season level-up sheet reuses the council level-up.

### F2 🟡 Case of the Day «قضية اليوم»
- Loop: one fictional case/day, 5–7 suspects around a table, 3 attempts,
  reveal with the clue chain, streak, 5 coins + 20 Season XP.
- Variety: Sun–Tue easy (5 seats, direct clues), Wed–Thu medium (6 seats,
  seat-position clues), Fri–Sat hard (7 seats, groups + distance). **Friday
  special "big case"**: 7 suspects, the Mafia character narrates instead of the
  Detective (fun twist, same reward ×2).
- Share: «قضية اليوم #N 🔍 ✅ في محاولتين 🔥5» + grid of attempts (🟥🟥🟩) —
  text only, no hidden data. Viral hook.
- Doc 05: fiction; never reads match data.
- **Assets:** `case_room_backdrop` (interrogation room, one hanging lamp, round
  table seen from above) 1080×1080; **12 painted suspect busts** (6 m / 6 f,
  same painterly noir style, transparent, 512²) mapped to the 24 name keys;
  `seat_ring_accused` (red variant of the seat ring); sounds `gavel` (accuse),
  `reveal_swell`, `wrong_crack`; share card template `case_share` 1080×1080.

### F3 ⬜ Character Chapters «حكايات الأربعة»
- Loop: four fixed chapters, one per character, 5 steps each. Steps are
  existing safe metrics (finish/win/host/reunion/public/puzzle-solve/streak) with
  character-specific framing. Finishing a chapter: a sealed letter opens (5th
  letter per character, beyond the existing 4), a title («صاحب المحقق»…) and a
  character frame.
- Variety: Doctor chapter = gentle (finish, streaks); Detective = puzzles;
  Mafia = wins/hosting; Citizen = social (reunion, invites). "Character of the
  week" rotates which chapter is featured and doubles its step XP.
- Doc 05: steps count finished public facts only; no role-specific steps
  ("win as Mafia" is banned — no agency).
- **Assets:** 4 chapter covers (each character in their own place: clinic
  doorway, detective's office, back room of a café, a Cairo street), 1080×1350;
  4 character frames (`frame_doctor/detective/mafia/citizen`); letter paper
  texture with each character's seal (4 seals); sound `letter_open`.

### F4 ⬜ The Academy «المدرسة»
- Loop: 5 playable lessons on a scripted local table (engine + scripted seed,
  pass-and-play transport): roles · the night · the vote · reading the morning ·
  playing online politely. 2–3 minutes each. The Doctor teaches.
- Variety: each lesson ends with a 1-question check; the last lesson is a full
  mini-match against scripted seats.
- Rewards: 25 coins once per lesson (server claim, capped 5×/account) — worth it
  but not farmable.
- Doc 05: scripted, single device, no real roles of real people.
- **Assets:** 5 lesson covers (small, 720×480), the Doctor "teacher" pose,
  chalk-line icons (5), sound `lesson_done`.

### F5 ⬜ Verdict Share Card «كارت النتيجة»
- After the result: an image with the room title, winner side, awards, the
  player's title and season level, the four characters' reaction. Share via
  share_plus.
- Doc 05: result screen only, public facts only.
- **Assets:** 2 templates (town win / mafia win) 1080×1350 with empty panels,
  a watermark lockup.

### F6 ⬜ Scenario Deck «سيناريوهات الليلة» (host)
- Named presets from existing settings only: «ليلة سريعة» (short timers),
  «المجلس الكلاسيكي», «ترابيزة كبيرة» (10–15), «ليلة الهمس» (whispers on),
  «من غير رحمة» (no self-protect, revealed night victim off). Shown as painted
  cards in the online create flow.
- **Assets:** 5 preset card paintings (720×960).

### F7 ⬜ Best-of-3 series
- Rematches chain into a series; the lobby shows «الماتش 2 من 3 · المدينة 1 ·
  المافيا 0»; after 3 a series card (share). Public score only.
- **Assets:** series plaque, trophy icon, sound `series_win`.

### F8 ⬜ Return Route + streak shield
- After ≥3 days away: 3 gentle steps (open Case of the Day, play 1 match, claim)
  → 50 coins. One streak shield per month (earned at season level 5) protects
  the Case-of-the-Day streak once.
- **Assets:** shield icon, welcome-back painting (the four at the door).

### F9 ⬜ «ليلة الخميس» weekly event
- Thursday 20:00–01:00 Cairo: featured scenario + ×2 Season XP for eligible
  matches (still capped). Server-scheduled; banner on Online and Home.
- **Assets:** event banner 1080×480, sound sting.

### F10 ⬜ Commendations «تحية»
- After the result, give up to 2 tablemates one of «لعب حلو» «محترم» «عقل
  محقق». Positive only, rate-limited, profile shows counts; achievement at 25.
- Doc 05: result screen only.
- **Assets:** 3 badge icons, sound `tip_hat`.

### F11 ⬜ Titles & showcase
- Equip one title (season/chapter/achievement) shown on profile and on the
  lobby plate (not on night/reveal surfaces — cosmetics rule).
- **Assets:** title ribbon styles ×3 (bronze/silver/gold).

### LATER (explicitly not this release)
Crews, ranked ladder, spectating, tournaments, storyteller console, custom roles,
premium track, daily shop rotation, voice packs by dialect.

---

## 2. Difficulty & fun matrix

| Player | Tonight | Weekly | Daily case | Season by day 28 |
|---|---|---|---|---|
| Casual (2 matches, 4 days/wk) | 1–2 cases | maybe | easy days | ~level 9–11 |
| Regular (4 matches, 5 days/wk) | 3 cases | yes | most days | ~level 16–18 |
| Committed (6+/day) | 3 + bonus | yes | all + streak | 20 by day ~21 |

Every session should offer: one quick win (<5 min), one social goal, one
"clever" moment (the daily case).

## 3. Economy (combined, per 4 weeks, committed player)
Casebook ≈1,680 · Case of the Day ≤ 28×5 + Fridays 4×5 = 160 · Academy 125
once · Return 50 · Chapters 4×100 = 400 once. Sinks: store 150–2,300. A
committed free player can buy one bundle or two packs a season — generous,
not inflationary. (Sol to verify against catalogue prices.)

## 4. Asset production plan

- Style guide: the shipped painterly noir — oxblood `#8E1F24`, gold `#C9A45C`,
  near-black grounds, warm lamp light, no text baked in, no logos, figures
  unframed so FeatheredArt can dissolve them.
- Tool: a dedicated Codex session with image generation (model
  `gpt-5.6-terra`), run **after** the plan is agreed, so the reasoning budget
  stays with the debate. Outputs to `raw_assets/update11/`, then
  `tool/normalise_art.py` → `assets/images/update11/…` →
  `tool/generate_asset_constants.py`.
- Sounds: `tool/generate_audio.py` (synthesised cues; never speech).
- Manifest: `docs/ASSETS-1.1.md` — one row per asset: id, feature, size,
  transparency, prompt, destination, status.

## 5. Build order after agreement
1. Asset manifest + prompts (both agree) → asset session starts in parallel.
2. Finish F2 (Case of the Day) UI with its art.
3. F1 art pass. 4. F3 Chapters. 5. F5 Share card. 6. F6 Scenario Deck.
7. F10 Commendations. 8. F7 Series. 9. F8 Return/shield. 10. F9 Event.
11. F4 Academy. 12. F11 Titles.
Split: Sol = SQL/edge/generators/tests; Claude = all Dart UI, l10n, tokens,
integration, screenshots, commits.

## 6. Questions for Sol (answer each: agree / change / cut, with reason)
1. Is the Friday "Mafia narrates" twist fun or confusing?
2. Chapters: 5 steps enough? Are the per-character step themes right?
3. Academy reward 25/lesson — farmable? (5 total per account)
4. Commendations: abuse risk (collusion rings)? Cap design?
5. Series: does Best-of-3 need server state or only public_data on rematch?
6. Event: ×2 XP inside the same caps, or a separate event cap?
7. Which of F3–F11 would you cut to protect quality?
8. Asset list: what's missing / oversized? Should suspects be 12 or 24 busts?
9. Anything a top board-game designer would add that we still lack?
