# Round 8 — Claude writes, Sol attacks
Topics: offline and pass-and-play entertainment · a deeper player↔character
bond · the long-term roadmap from 1.1 to 2.0.

Constraints never change: Doc 05, one engine with two transports, a pure
engine, no invented facts, voice never load-bearing, flags OFF until the owner
says.

---

## A. The offline table — pass-and-play becomes an evening, not a match

Most Egyptian play is one phone in a room of cousins or friends. Today that
player gets a great match and then nothing. 1.1 already gives them the
Scenario Deck (local), dossiers, the Academy and the Daily Case when online.
The list below adds what makes an evening.

### A1. «دفتر القعدة» — the Group Book (1.1, M)
The group picker already saves groups. A group becomes a place with a memory.

- **Record book.** Built only from finished, public results that the device
  already holds: nights played, town/mafia wins, longest win run for each side,
  "the table's most-trusted" (most times voted correctly *after* reveal? —
  **no**: vote correctness is role-linked history; cut). Keep only
  outcome-level facts: nights, sides won, days survived as a group, and who
  hosted.
- **Group titles, earned by the group, not a person:**
  - «قعدة الخميس» — 4 Thursdays.
  - «المدينة الصامدة» — 5 town wins.
  - «عيلة المافيا» — 5 mafia wins.
  - «١٠ ليالي» — ten nights.
- **The next-match line.** A single sentence from one of the four characters
  referencing the group's last public outcome, e.g. the Detective: «آخر مرة
  المافيا كسبت في يومين… المرة دي؟». It is shown **only in group follow-up /
  setup, never after the deal**.
- **Doc 05.** Nothing role-linked per person is stored. Only public outcomes,
  counts and names are kept, all local. A test enforces this: the Group Book
  storage schema has no role field.
- **Assets:** a book-cover painting and 4 group-title seals, reusing the
  council seal style.

### A2. Party modifiers «ليلة غريبة» (1.2, L)
- **What they are:** public twists that change *table behaviour*, never hidden
  information. Examples:
  - «ليلة الصمت»: day discussion by gestures only; the timer UI shows a
    silence glyph.
  - «ليلة السرعة»: half timers.
  - «المحكمة»: the accused gets a 20 s defence before the vote. This already
    exists as confrontation; reframe it.
  - «ليلة بدون دكتور»: a preset.
- **Engine rules:** each modifier must be expressible as an existing
  `MatchSettings` value or a pure-engine rule with tests. No UI-only fake
  rules.
- **Why 1.2:** new engine rules need the doc 11 edge-case treatment.

### A3. Warm-up pack: «كمّل المثل» (Proverb Bluff) (1.2, M)
Agreed LATER in round 2. The roadmap slot is 1.2, with an owned, reviewed
catalogue of 300 proverbs, regional wording checks, and a local round flow.
Players invent fake endings and vote for the real one. It is Jackbox-style
and Egyptian to the bone. A paid pack of 200 more proverbs is a revenue lever.

### A4. Local tournament «دوري القهوة» (1.3, L)
A host-managed bracket across several nights. It scores only public series
results and keeps its state local, with an optional share card.

### A5. Big-screen table (1.3, M)
On web, a read-only "table view" at `/tv/<code>` for a laptop or TV in the
room.

- **Shows:** public phase, timer, day number, eliminated players with their
  *publicly revealed* roles, and the vote tally when public.
- **Never:** the pass-and-play private screens. For pass-and-play the TV view
  is fed by the host device over a local session only if feasible. Otherwise
  the feature is online-only, driven by the existing public room state.
- **Doc 05:** the TV consumes exactly the public snapshot that spectators
  would see. It must be a public-snapshot-only consumer, with the same tests
  as spectating.

### A6. Storyteller mode «الراوي» (1.3–1.4, L)
In the Clocktower style: one human narrates with the host console, which shows
the public script, pacing cues, and an atmosphere soundboard (existing cues).

The narrator is never dealt a role. In pass-and-play the narrator phone is the
host device between hand-offs. That is a real leakage risk, so it needs its own
Doc 05 review before any build. It stays in the roadmap until that review
passes.

---

## B. The player↔character bond — from "they remember me" to "they're mine"

Today we have: the Four Dossiers (tiers at 1/3/7/15 cases), letters, home
whispers, moments on the result screen, casebook voices, and milestone scenes.
Chapters come in 1.1.

### B1. «شريكك» — pick a partner (1.1, M)
- **What it is:** the player chooses one of the four as their partner, and can
  change it at most once a week.
- **Where the partner shows up:**
  - Stands on Home beside the «الليلة» rail, feathered, not boxed.
  - Voices the Casebook header, the Daily Case intro (the Detective still
    authors the clues), and the reminder line.
  - Reacts on the result screen (post-public only) with a partner-specific
    line.
- **Partner affinity:** it grows from the existing bond ledger. There is no
  new currency. Affinity unlocks partner lines at 5/15/30/60 cases.
- **Home art:** each partner gets 3 poses (idle / pleased / thinking) — **12
  new transparent assets**.
- **Doc 05:** the partner never appears on any private or live surface. The
  existing import-closure ban for `character_bonds` extends to
  `partner_provider`.
- **Revenue tie-in:** partner outfits (see C) are cosmetic-only and visible
  only on Home, Casebook and result.

### B2. The fifth letter tier (1.1)
Chapters already grant the fifth letter. The dossier gains a fifth seal. The
tier thresholds stay as they are; chapter completion is the only route to
tier 5.

### B3. Anniversaries and memory (1.1, S)
- **What:** a local, deterministic "on this day" letter from the partner:
  - «سنة على أول قضية»;
  - «١٠٠ ليلة»;
  - «أول مرة كسبت سهرة».
- **Sources:** only the bond ledger and public outcomes.
- **Frequency:** at most one letter a week, shown on Home as the partner's
  line, never a banner.

### B4. Character reactions in the lobby (1.2, S)
Pre-deal only. The partner comments once on the chosen scenario, e.g. the
Doctor on «من غير رحمة»: «ليلة من غير دكتور… ربنا يستر». It is public and
flavour only.

### B5. The fifth character (1.3, L)
- **What:** a new role with its own engine rules, dossier, chapter and letters.
  It is the biggest long-term bond and content lever.
- **Candidates:** the Guard «الحارس», who protects someone other than
  himself, with a different rule from the Doctor; or the Mayor «العمدة», whose
  vote counts double after a public reveal.
- **Before any build:** the Doc 09/11 treatment, the information engine, and
  leakage tests.
- **Monetization:** the base role is free. Only cosmetics are sold.

---

## C. Revenue additions that come from A and B (for Sol's R7 model)

| Item | What | Where visible | Doc 05 | When |
|---|---|---|---|---|
| Partner outfits | 2 per character (e.g. the Detective's winter coat) | Home, Casebook, result, profile | never in-match | 1.1 art, sold in 1.2 |
| Group Book covers | leather / wood / gilt | Group Book | local | 1.2 |
| Proverb pack 2 | 200 more proverbs | warm-up | n/a | 1.2 |
| Storyteller soundboard pack | extra atmosphere cues | narrator console | public cues only | 1.4 |
| Big-screen themes | TV layouts | `/tv` | public view only | 1.3 |

---

## D. Long-term roadmap

| Release | Theme | Headline features | Why then |
|---|---|---|---|
| **1.1** (this) | "The Night Has a Home" | Casebook + Season Zero, Daily Case + reminders, Chapters, Academy, Deck / House Rules, Series + Draft, ready-up / rematch vote, Thursday, Titles, Safety v11, Economy C, Group Book, Partner, anniversaries | the foundation of meta, table and trust |
| 1.1.x (live ops, weeks 2–4) | Season One | Season One content pack by day 21, Thursday tuning, puzzle audits | the season must never go empty |
| **1.2** | "Party Night" | party modifiers, «كمّل المثل», House Rules library browse, lobby partner reactions, partner outfits for sale, Season Pass *if* R7 data says yes, Ramadan event framework | party breadth, first premium track |
| **1.3** | "The Fifth Seat" | the fifth character/role with dossier, chapter and letters; public spectating + big-screen view; Coffeehouse league; streamer tools | content depth, community |
| **1.4** | "The Family" | crews «العيلة» with the moderation stack, crew Thursday, crew chapters; storyteller mode (if its Doc 05 review passes) | social depth, only once safety scales |
| **2.0** | "Everywhere" | iOS app, voice rework, tournaments + creator kit, Gulf/Levant dialect copy packs, ranked-lite «دوري الخميس» if player density allows | platform and region growth |

Every release follows the same pattern: flags OFF, one normalized spec, art
gated by S0-style calibration, and staged rollout.

---

## E. Offline ↔ online bridge
- The Group Book offers «كمّلوا أونلاين» when the group is apart: it creates a
  series and shares the link.
- Pass-and-play results feed the local dossiers, the partner and the Group
  Book. Only online-eligible matches feed coins, XP and the Casebook. Say this
  in the Academy, not in tips.

## F. Questions for Sol — attack
1. The Group Book: is any stat still role-linked or inferable? Name it.
2. The partner: is a weekly switch limit good, or annoying? Is there a better
   affinity model?
3. The TV view for pass-and-play: feasible without leakage, or online-only?
4. The fifth character: Guard or Mayor, or something better for this audience?
   Engine risk?
5. Roadmap: is the order right? Is anything that should be sooner or later
   misplaced?
6. What entertainment tool am I missing that would beat every party game on
   Play in Egypt?
