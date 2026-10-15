---
name: stories-case-writing
description: Write or rewrite a «قصص وتحقيقات» case for Mafia Master — the world, the suspects' public cards, the innocent and guilty modules, traces and reveal — in natural Egyptian Arabic that is read aloud at a table. Use for any story text in assets/stories, the pilot «قهوة المعلم», or a review of case writing. Enforces the owner's rules (no minutes or seconds, everyone suspects everyone, every person is a character of the story) and fair play.
---

# Writing a «قصص وتحقيقات» case

The design lives in `docs/plans/STORIES-V2-PLAN.md` (§2–§4). This skill is how the words get written.
The reader is a group of Egyptian friends at a café table, most of them playing for the first time, reading cards **aloud** to each other. Write for the ear.

## The owner's rules (2026-10-15) — non-negotiable

1. **No clock times, no minutes, no seconds.** Never «٨:٤٣», «٧٤ ثانية», «بعد ٣ دقايق». People talking at a table say:
   «من فترة» · «امبارح» · «امبارح بالليل» · «النهارده الصبح» · «قبلها بساعة» · «قبلها بشوية» · «ساعتها» · «بعدها على طول».
2. **Everyone suspects everyone from the first minute.** The opening gives each seated suspect one suspicious fact («امبارح منير اتخانق مع المعلم على الإيجار»، «رضا كان شايل له فلوس»).
3. **Every person is a character of the story.** The detective too (an in-story officer, neighbour or relative). No outsider, nobody from nowhere.
4. **Private = only «بريء» or not** (and the partner's name). Everything else on a card is said out loud, so write it to be said out loud.
5. **No riddles.** If a sentence needs a second read, rewrite it. The old «برنامج الثمانية ونص باين في انعكاس المراية» is the example of what never ships.
6. The narrator's opening text may stay as it is; everything after it is rewritten.

## What you write for one story (a "world")

| Piece | Rules |
|---|---|
| Victim | name + one-line tag («المعلم صابر، صاحب القهوة») |
| Places (4–5) | one line each, concrete and visual («حوش الفحم: ممر ضيق ورا القهوة، أرضه سودا من التراب») |
| Detective (in-story) | name, tag, one-line reason he is there, public goal |
| 10 suspects — public card | who, relation to the victim, a **public goal**, a **suspicion hook** true in every version. ≤ 3 short sentences, sayable in one breath each |
| Innocent module (per suspect) | his account (true), one clearing trace placed in a place |
| Guilty module (per suspect) | motive, method, his account (a lie that sounds like the innocent one), 2+ exposing traces in different places, a reveal paragraph (narrated) |
| Base facts | events true in every version (the fight, the debt, who opened the shop) |

Structured facts sit beside the prose: `at(who, place, period)`, `has(who, item)`, `saw(a, b, place, period)`. Prose and facts must say the same thing; the checker reads the facts, people read the prose.

## Fair play (from `genre-craft` → `references/mystery-fair-play.md`)

- Every fact the detective needs is on a card or a trace before he decides.
- Motive, means and opportunity of the culprit each trace to a separate planted fact.
- Every red herring is plausible, belongs where it appears, and is **cleared for a reason that teaches something true**.
- The culprit's account contradicts at least one trace. The contradiction is findable by a first-timer.
- No trace names the culprit outright. Traces show what was seen, left or found; people connect them.

## Egyptian Arabic, out loud

- Natural Cairene, short sentences, one fact each. Follow `arabic-natural-writing`.
- Few ق-words; spell ق normally (the voice engine handles it). No Latin letters. English words, if unavoidable, in Arabic letters.
- No AI tells: no «مش X… ده Y» reveals, no «لا X ولا Y ولا Z» lists, no self-answered questions, no three-adjective stacks, no closing moral. Run `humanizer` and `sepia-review` on every draft.
- Names in traces are always cast names, spelled exactly as on the cards.
- A card read aloud takes under 20 seconds.

## Process

1. Plan the world with `story-planning` and `plot-structure`: base facts, the 10 suspects, why each could have done it.
2. Draft cards and modules with `creative-writing-craft` / `sepia-write`; voices per character with `voice-style` (a butcher does not talk like a teacher).
3. Self-review: `sepia-review`, `humanizer`, then a read-aloud pass (`line-editing`).
4. Reader test: `reader-sim` as «شاب مصري أول مرة يلعب، قاعد على قهوة» — report where he got lost.
5. Run the checker and linter (`dart run tool/stories/check.dart`); fix until green for every table size.
6. The owner reads the pilot before any other story is written.

## Self-check before handing in

- [ ] Zero digits next to دقيقة / ثانية / ساعة, zero «:» times.
- [ ] Every seated suspect has a suspicion hook in the opening.
- [ ] Every name in every text is on a card.
- [ ] Each card read aloud < 20 s; each trace ≤ 2 sentences.
- [ ] Each guilty account has a findable contradiction; each herring is cleared.
- [ ] No sentence needs a second read.
