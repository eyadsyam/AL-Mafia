# Design system — سيد المافيا

**Agents: start here.** The app has **two separate identities**. Pick the right one
before you design or build anything, then read only that folder.

| You are working on | Read | Never borrow from |
|---|---|---|
| Home, play setup, the Mafia match (offline / online / bots), pass & reveal, night, day, vote, result, الخزنة, المجلس, المهام, profile, settings | [`mafia/IDENTITY.md`](mafia/IDENTITY.md) | `stories/` |
| «قصص وتحقيقات»: archive, case sheet, cast, secret card, moves, discussion, accusation, reenactment, verdict | [`stories/IDENTITY.md`](stories/IDENTITY.md) | `mafia/` |

Owner rule (2026-10-09): «كل لعبة ليها هويتها». Never put story suspect portraits,
paper dossiers or Aref Ruqaa inside Mafia; never put card faces, hooded figures,
slate, oxblood or Cairo/Bebas inside Stories.

## What is in each identity folder

| File | What it is | Use it for |
|---|---|---|
| `IDENTITY.md` | the complete spec: rules, colour, type, signatures, components, image catalogue, art brief, motion, copy, do/don't, ship checklist | read first, every time |
| `tokens.json` | every value with its role and where it may or may not appear | code generation, Flutter `ThemeExtension`, checks |
| `tokens.css` | the same values as CSS variables + `@font-face` | HTML mockups (owner wants mockups before code) |
| `index.html` | the living identity page (open in a browser) | showing the owner, visual reference |
| `img/` | curated reference art, 720 px, grouped by use | look before you design |
| `img/_contact_sheet.jpg` | every image in `img/` on one sheet with its path | one-glance visual context for agents that read images |

Shared: [`fonts/`](fonts) (same files as `assets/fonts/`, OFL licence included) ·
[`index.html`](index.html) (hub page linking both identities).

## The two identities in one line each

- **Mafia:** a deck of hand-painted monochrome cards under one oil lamp. Three inks,
  never mixed: **ash** (cards, secrecy, 70%) · **slate** (stage, chapters, 20%) ·
  **house** (vault, verdict, money, 10%). Oxblood = something was decided; brass = value.
- **Stories:** an investigator's desk at night under one brass lamp. **Lamp** ground
  (60%) · **manila paper** for everything read closely (25%) · **amber** action (10%) ·
  **velvet** stamp/accusation and **nile** time (5%).

## Authority, and what this folder does not override

1. `.specify/memory/constitution.md` and `05-zero-leakage-spec.md` beat everything here.
   In-hand surfaces (phone in one player's hand) follow the leakage rules first.
2. Runtime truth is `lib/core/theme/app_colors.dart` and `lib/ui/theme/design_tokens.dart`.
   This folder is the target; until the owner signs it off, the code is what ships.
3. `docs/design/DECK-SYSTEM.md` (branch `claude/epic-roentgen-094f21`) holds the agreed
   navigation and component geometry. Mafia's house tokens equal DECK tokens; two
   things here differ from DECK and need the owner's call:
   - DECK uses Aref Ruqaa for the Mafia result headline and the casebook. Here Ruqaa is
     **Stories only**; Mafia headlines use Cairo 900.
   - DECK names the value colour "gold"; here it is "brass" (same `#C9A45C`) and is
     always matte.

## Process rules from the owner (still apply)

- HTML mockups first, agreed screen by screen, then polish, then Flutter. No code early.
- No builds or deploys unless the owner says so in the moment.
- Missing art → leave a labelled placeholder slot; Codex fills it later using the art
  brief in the identity file. Reuse existing art first.

## Legacy

[`_legacy/`](_legacy) holds the July 2026 pre-implementation proposal (gold `#C9A227`,
blue-grey ground, Cinzel). It is **superseded**; do not use its values.

Last updated 2026-10-10 · draft v1.0 · awaiting owner sign-off.
