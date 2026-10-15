# Stories V2 world format (format 2)

One JSON file per story in `assets/stories_v2/<id>.json`. The design is `docs/plans/STORIES-V2-PLAN.md` §2–§3; the writing rules are `.claude/skills/stories-case-writing/SKILL.md`. This file is the contract between the writer, the engine and the checker.

## Shape

```jsonc
{
  "id": "qahwet_el_moallem",
  "format": 2,
  "title": "قهوة المعلم",
  "category": "قتل في الحارة",
  "victim": { "name": "المعلم صابر", "tag": "صاحب القهوة" },
  "opening": "…",                 // the narrator's text; tells the story, never the method or the culprit
  "detective": {                   // an in-story person, never an outsider
    "name": "…", "tag": "…", "image": "assets/…",
    "card": "…",                   // read aloud by the detective's player: who he is, why he is here
    "goal": "…"
  },
  "places": [                      // 5 places; one search reveals every trace the assembled version put there
    { "id": "cafe_floor", "name": "صالة القهوة", "line": "…", "baseTrace": "…" }   // baseTrace: neutral, true in every version
  ],
  "baseFacts": ["…"],             // read by the detective at the start: what everyone knows; true in every version
  "suspects": [                    // exactly 10
    {
      "id": "n01", "name": "رضا المكوجي", "tag": "مكوجي أول الحارة", "image": "assets/images/stories/suspect_n24.webp",
      "card": "…",                 // first person, read aloud by his player; TRUE IN BOTH VERSIONS; ≤ 3 short sentences
      "goal": "…",                 // public goal, one line
      "hook": "…",                 // third person, read in the case facts; true in both versions; why people suspect him
      "innocent": {
        "trace": { "place": "coal_alley", "text": "…", "excludes": ["n01"] }   // clears HIM ONLY (excludes = [own id])
      },
      "guilty": {
        "motive": { "id": "forged_debt", "label": "…" },
        "method": { "id": "poisoned_bowl", "label": "…" },
        "omits": "…",              // writer's note: what his card leaves out; never shown
        "traces": [                // 2–3, in DIFFERENT places; may exclude other suspects; never name him outright
          { "place": "molasses_cabinet", "text": "…", "excludes": ["n03", "n05"] }
        ],
        "partner": {               // optional; only where the story supports one
          "id": "n02",
          "traces": [ { "place": "…", "text": "…", "excludes": [] } ],
          "reveal": "…"
        },
        "reveal": "…"              // the truth as a short scene, shown on screen (no narration)
      }
    }
  ]
}
```

## Rules the checker enforces

1. Exactly 10 suspects, 5 places, one detective; every `place` id exists; every id in `excludes` is a suspect.
2. **Innocent traces exclude only their own suspect.** Base traces and base facts exclude nobody. Only a guilty module's traces may exclude others (they exist only when that suspect is guilty, so they can never contradict another version).
3. A guilty trace never excludes its own suspect or his partner.
4. Cards, goals, hooks, base facts and base traces are the same in every version, so they must be true whoever is guilty (human review: read each card against all ten guilty modules).
5. No clock times, minutes or seconds; no Latin letters; every name in any text is the victim, the detective or a suspect (unnamed bystanders such as «الولد اللي بيلف بالطلبات» are fine).
6. Lengths: card ≤ 3 sentences (read aloud < 20 s), trace ≤ 2 sentences, hook 1 sentence, reveal ≤ 6 sentences.
7. **One window.** `baseFacts` name the moment the shisha (or whatever the story's murder hinges on) was tampered with; traces call it «ساعتها». An innocent trace is an alibi for that window with its proof, and never says anything about the method (the method changes with the culprit). Cards never say where their owner was «ساعتها».
8. **Three places.** Every guilty module has exactly 3 traces in 3 different places, so any 3 searches out of 5 find at least one of them (pigeonhole). Every guilty trace points at its culprit through a detail of his card, trade or tools, without naming him as the one who did it.

## How a version is assembled (engine)

Seated suspects for the count → culprit (and partner) among the played ones → the case facts = `baseFacts` + each seated suspect's `hook` → every place holds its `baseTrace` + the seated innocents' traces placed there + the culprit's (and partner's) traces placed there. A search shows everything in that place. The accusation lists the seated suspects, and the motives and methods of their guilty modules.

**Fair** (checker, per version and per choice of 3 places): at least one of the culprit's traces is found (rule 8 makes this every path), and every found trace that points at someone points at the culprit. Strict exclusion (every other suspect ruled out) is reported too, but it is not the bar: a first pilot showed that with 3 of 5 places no world can rule out eight people one alibi at a time. The detective solves by connecting a found trace to a card; alibis clear the red herrings he happens to search.
