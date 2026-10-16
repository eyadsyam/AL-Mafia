# Stories V2 world format (format 3)

One JSON file per story in `assets/stories_v2/<id>.json`. The design is `docs/plans/STORIES-V2-PLAN.md` §2–§3; the writing rules are `.claude/skills/stories-case-writing/SKILL.md`. This file is the contract between the writer, the engine and the checker. Format 2 (alibis, `excludes`, `omits`, partners) is gone: the engine reads format 3 only and throws a `FormatException` for anything else.

## The idea

Nobody is ruled out by an alibi. Each suspect carries two **marks**: things that stick to his hands from places he went tonight (coal, cement, flour, sawdust, ta'meya oil). His card says why in plain words, and it is true whether or not he did it. When he is guilty, every place holds one trace of him, and each trace shows one or both of his marks. A detective who searches any three places reads marks that add up to exactly his pair, and no other suspect holds that pair. Everything else found (the suspicion lines) is true in every version and points at someone, guilty or not.

## Shape

```jsonc
{
  "id": "qahwet_el_moallem",
  "format": 3,
  "title": "قهوة المعلم",
  "category": "قتل في الحارة",
  "victim": { "name": "المعلم صابر", "tag": "صاحب القهوة" },
  "opening": "…",                  // the narrator's text; tells the story, never the method or the culprit
  "openingAudio": "assets/voice/stories_v2/qahwet_el_moallem.ogg",
  "detective": {                    // an in-story person, never an outsider
    "name": "…", "gender": "m", "tag": "…", "image": "assets/…",
    "card": "…",                    // read aloud by the detective's player; ≤ 3 sentences
    "goal": "…"
  },
  "marks": [                        // exactly 5
    { "id": "coal", "name": "سواد الفحم", "words": ["سواد فحم"] }   // words: the exact phrases that name the mark inside trace texts
  ],
  "places": [                       // exactly 5; one search shows every line the assembled version put there
    { "id": "cafe_floor", "name": "…", "line": "…", "baseTrace": "" }   // baseTrace: true in every version; "" when the place shows nothing of its own
  ],
  "baseFacts": ["…"],              // read by the detective at the start; true in every version
  "suspects": [                     // exactly 10
    {
      "id": "n01", "name": "…", "gender": "m", "tag": "…", "image": "assets/…",
      "card": "…",                  // first person, read aloud by his player; true in every version; ≤ 3 sentences; says in plain words why his hands carry the two marks
      "goal": "…",                  // public goal, one line
      "hook": "…",                  // third person, read in the case facts when he is seated; true in every version; one sentence
      "marks": ["coal", "tameya"],  // exactly 2 mark ids; no other suspect has the same pair
      "suspicion": { "place": "front_walk", "text": "…" },   // found against him in EVERY version, wherever he is seated; ≤ 2 sentences
      "guilty": {
        "motive": { "id": "rent_eviction", "label": "…" },
        "method": { "id": "sprayed_tobacco", "label": "…" },
        "traces": [                 // exactly 5, one in each place
          { "place": "cafe_floor", "text": "…", "marks": ["tameya"] }   // marks ⊆ his 2 marks, non-empty; ≤ 2 sentences
        ],
        "reveal": "…"               // the truth as a short scene shown after the decision; ≤ 6 sentences
      }
    }
  ]
}
```

`method` ids repeat between suspects (the pilot has two); `motive` ids are one per suspect. The server rows in `supabase/migrations/20261015000200_story_v2_sessions.sql` (`story_v2_suspects`, with `partner_id` null) must carry the same motive and method ids; `test/stories/v2/story_v2_server_rows_test.dart` fails on drift.

## Rules the checker enforces

`lib/stories/v2/world_checker.dart`, run by `test/stories/v2/story_v2_engine_test.dart` on the real world; a world with any problem does not ship.

1. Exactly 10 suspects, 5 places, 5 marks, one detective. Suspect, place and mark ids are unique; every mark has at least one non-empty word.
2. **Hands.** Each suspect has exactly 2 distinct known marks, and no two suspects have the same pair.
3. **Suspicion.** Its place exists. The suspicion text, the card, the hook and the goal contain none of any mark's words (a mark is read off traces only).
4. **Guilty traces.** Exactly one trace in each of the 5 places. Each trace's marks are non-empty and a subset of the suspect's 2. A trace's text contains at least one word of every mark it lists and no word of any mark it does not list.
5. **Fair, per choice of 3 places** (10 choices): the marks of the culprit's traces found there add up to exactly his pair, and the suspects whose marks include that union are exactly the culprit. Because pairs are unique, one trace per place and any 3 places are enough.
6. A guilty module with a partner is a problem: format 3 has no partners. (The engine, the server pick and the screens still carry a partner type; no world uses one.)
7. Text: no clock times, minutes or seconds; no Latin letters; card ≤ 3 sentences, trace ≤ 2, suspicion ≤ 2, hook 1, reveal ≤ 6.

Not machine-checkable, read by a human against all ten guilty modules: cards, goals, hooks, suspicions, base facts and base traces are the same in every version, so each must be true whoever is guilty; every name in any text is the victim, the detective or a suspect (unnamed bystanders are fine); a card explains its owner's two marks without using a mark word; no trace names its culprit outright.

## How a version is assembled (engine)

Seated suspects for the count → culprit among the played ones → the case facts = `baseFacts` + each seated suspect's `hook` → a search of a place shows its `baseTrace` (when not empty), then, in an order shuffled from the table's seed and the place id (the culprit's line has no fixed position), the `suspicion` of every seated suspect placed there and the culprit's trace placed there.

The accusation lists the seated suspects. With friends it asks **who** only; solo also asks why and how, from the motives and methods of the seated suspects' guilty modules, one choice per id. The app never marks or ranks anyone and never writes a sentence of its own: a place with nothing to show shows nothing.

**How it is solved.** The detective reads which marks the found traces name. Any three places name the culprit's pair; the suspicion lines name no mark, so they only point (and are true even for the innocent). The one suspect who carries those two marks did it.

## Adding a world

Pick 5 marks from the setting; give each suspect a distinct pair (10 pairs of 5 marks, so each mark sits on 4 suspects); write each card so it explains its two marks plainly; give every suspect one suspicion in some place; write 5 traces per guilty module, each of his two marks on at least 3 of them (so no 3 searches miss it); run the checker until it reports nothing; then read every card against all ten versions.
