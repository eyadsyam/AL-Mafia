---
name: stories-case-writing
description: Write or rewrite a «قصص وتحقيقات» case for Mafia Master — the world, the suspects' public cards, their marks, the red herrings, the guilty traces and the reveal — in plain Egyptian Arabic read aloud at a table. Use for any story text in assets/stories_v2, the pilot «قهوة المعلم», or a review of case writing. Enforces the owner's rules (hard but always solvable, logical, nothing decorative, no tips, no minutes or seconds) and the format-3 logic.
---

# Writing a «قصص وتحقيقات» case

The contract is `docs/plans/STORIES-WORLD-FORMAT.md` (format 3); the design is `docs/plans/STORIES-V2-PLAN.md`. This skill is how a case gets built and worded. The reference case is `assets/stories_v2/qahwet_el_moallem.json`.
The reader is a group of Egyptian friends at a café table, many playing for the first time, reading cards **aloud**. We are investigating and suspecting each other; we are not telling a tale.

## The owner's rules — non-negotiable

From 2026-10-15:
1. **No clock times, minutes or seconds.** Say «النهارده»، «امبارح»، «قبلها بشوية»، «ساعتها».
2. **Everyone suspects everyone.** Every seated suspect has a real motive (his hook) and a clue found against him (his suspicion).
3. **Every person is a character of the story,** the detective too. No outsiders. Never name a character who may not be seated in a card, a hook or a suspicion.
4. **Plain words** a first-timer at a café understands («ركن الشيش», never «الكونتر»).
5. **The app never marks or ranks anyone.** With friends the decision is **who** only; solo adds why and how.

From 2026-10-16 (after he played the pilot):
6. **Hard.** No single clue may give the answer. The old pilot was easy because every clue that pointed at someone pointed at the killer; that design is dead.
7. **Logical and real.** Every motive, method and event is something that really happens in an Egyptian alley. Ask of every sentence: could this physically happen, and would a person really do it this way? («مية القهوة نزلت على محلي» failed this; so did a contractor buying a café to enlarge a building.)
8. **Nothing decorative.** Every sentence either gives a motive, a mark, a red herring or a trace. A detail that doesn't change who did it is cut (the taxi parked outside was cut).
9. **No tips or advice lines** anywhere («قول اللي في كارتك»، «متخليش المحقق يوصلك»). They read as AI.
10. **No everyday activity as a moment in time** («قبل الدومنة»، «بعد الدومنة»). Dominoes is just something people play.
11. **Short and direct:** a card is 2–3 short sentences; a trace is one sentence.
12. **Clues that point at someone who turns out innocent** are wanted: they are the suspicions.

## How a hard case works (format 3)

- **The method is the same kind for everyone** (one poison, one way in), so the question is **who**, not a gadget per suspect. Solo's «how» picks between 2–3 realistic variants.
- **Marks.** Choose 5 places in the story's world (not search places) that leave something visible on a person's hands: coal, cement dust, flour from the bakery, sawdust from the carpenter, ta'meya oil. Each suspect went to exactly **2** of them tonight, for a reason his card states in plain words («جبت عيش من الفرن»), and **no two suspects share the same pair** (10 pairs of 5 = 10 suspects; each mark is held by 4).
- **Cards never name a mark word** (they say «الفرن», never «دقيق»). The table has to make the jump from «دقيق» on the evidence to «who went to the bakery».
- **Guilty traces:** 5 per culprit, one in each search place, on objects only the poisoner touched (under the foil, inside the mouthpiece, the tissue he wiped his hand on, the cap, the empty bottle). Pattern: mark A twice, mark B twice, A+B once, with the A+B trace in a different place for different culprits. Then **any 3 searches find both marks, and only the culprit has both** (the checker proves it for every path). Never put a mark where it is natural anyway (coal in the coal yard, cement on the pavement by the building site).
- **Suspicions (red herrings):** one per suspect, true in every version, shown whenever he is seated, guilty or not. They point at a person and look bad (a torn rent receipt, a pesticide bottle in the flower box, syringes in the nurse's bag) but carry **no mark words** and are not the poison. Some are cleared by a fact on the table (the poison is liquid roach spray; the bottle in her box says «للزرع»).
- **Base traces** only where they mislead or explain something real («باب الحوش اللي ورا كان مفتوح»); otherwise empty.
- **The killer may lie aloud** at 5–10. Cards are always true.

## Egyptian Arabic, out loud

- Natural Cairene, short sentences, one fact each. Follow `arabic-natural-writing`.
- No Latin letters. Names spelled exactly as on the cards.
- No AI tells: no «مش X… ده Y», no stacked lists, no self-answered questions, no closing moral. Run `humanizer` on every draft.

## Process

1. Build the logic first, in a table: 10 suspects × (motive, 2 marks with their plain reasons, suspicion). Check pairs are unique and each mark has 4 holders.
2. Write each culprit's 5 traces and reveal (≤ 6 sentences: motive, the act, where he threw what).
3. Run the format-3 checker (and the scratch check that every 3-place path leaves exactly one suspect). Fix until green.
4. Read every card against all ten reveals: true in every version?
5. Read-aloud pass; cut every sentence that doesn't change who did it.
6. The owner reads and edits it on the editing page; his wording wins and becomes the reference for the next story.

## Self-check before handing in

- [ ] No single trace or suspicion names the killer; every path of 3 searches is solvable and leaves one person.
- [ ] Every motive and action is something that really happens; nothing physically odd.
- [ ] No decorative sentence, no tip, no minutes or seconds, no activity used as a clock.
- [ ] Cards: 2–3 short sentences, both marks' places stated plainly, no mark words.
- [ ] Every suspicion points at its owner, is true in every version, has no mark words.
