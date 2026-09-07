# Mafia Master — Consolidation & Cleanup

> **This document supersedes parts of `09`, `12`, and `13`.** Where it conflicts
> with them, this file wins.
>
> Three systems were added at once without first defining the moment-to-moment
> experience. The result is cluttered, confusing, and in places illogical. This
> document defines **one canonical flow** and states exactly what is removed,
> what changes, and what stays.

---

# PART 0 — WHAT WENT WRONG

| Mistake | Why it happened | Fix |
|---|---|---|
| Whispers forced into offline mode | Chased feature parity between modes instead of asking whether it *works* offline | **Whispers are online-only.** One shared phone during the day cannot deliver a private message |
| Ability control = tiny box + long-press | Solved the doc-05 parity requirement the laziest way | Abilities become **normal tiles inside the selection grid** |
| «فتح الملف» for the Detective | Added complexity with no visible payoff | **Removed entirely** |
| Play-hints on transition screens | Hints were dropped wherever there was space | Hints only in the lobby and settings. **Never inside a match** |
| Whisper text on the confirmation screen | Screens were edited independently, not as a sequence | Confirmation screen shows **one line only** |
| «اسم واحد» round added to the default flow | Solved a real problem, but imposed on everyone | **Default OFF**, opt-in with a clear description |
| Player list needs scrolling | Grid was never designed against a real player count | **All players visible without scrolling**, to 15 |
| Doctor self-protect framed as a special power | Over-designed a normal ability | It is a **normal option in the list**, once per match |
| Own name in the whisper recipient list | Spec said "self excluded" but it was not enforced | Enforced by construction — build the list from *other living players* |

**Rule going forward:** no new system ships until the full screen sequence
around it is written down first.

---

# PART 1 — THE CANONICAL OFFLINE FLOW

This is the entire game. Nothing else exists in offline mode.

```
الرئيسية
  → اللاعبون (أسماء + ترتيب الجلوس)
  → الأدوار (توزيع مقترح + تعديل)
  → إعدادات المباراة
  → توزيع الأدوار  [تمرير الهاتف]
  ┌─────────────────────────────────────┐
  │  الليل  [تمرير الهاتف لكل لاعب]      │
  │    → شاشة تمرير                     │
  │    → شاشة الإجراء (شبكة واحدة)       │
  │    → « تم تسجيل اختيارك »           │
  │  الصباح  (الضحية + الأثر)           │
  │  المواجهة  (يوم ٢+، واحدة فقط)      │
  │  النقاش   (مؤقت على الطاولة)        │
  │  الدفاع                             │
  │  التصويت  [تمرير الهاتف]            │
  │  الكشف    (المُقصى + دوره)          │
  └──────────── يتكرر ──────────────────┘
  → فيديو الفوز
  → النتيجة
  → التحليلات
```

**No whispers. No «اسم واحد» unless explicitly enabled. No file. No hints
inside the match.**

## 1.1 Direct night entry (final closure decision)

The last role handoff and a continuing vote result advance directly into the
next night handoff. There is no pre-night screen, start button or social
narration. Legacy saves at `preNightLobby` advance automatically through the
same engine command. Identity holds are fixed at two continuous seconds;
release, cancellation or leaving the pad cancels. All private night dwell
and luminance rules remain binding. Winner copy follows the full victory media.

The final closure brief supersedes earlier advice/hint requirements throughout
this document: no strategy tips or social coaching in the lobby, settings,
onboarding or results. Descriptions explain actual software controls only.

## 1.2 Screen: pass screen

Unchanged from `03-screens-setup-night.md` S-05. Name, "I am {name}"
long-press, "Not {name}?".

**Nothing about the night action appears here.** No "you will not choose
anyone", no preview, no options.

## 1.3 Screen: the night action — **one grid, all options**

### The special tile — one per role, same position, same size

| Role | Special tile | Meaning |
|---|---|---|
| **مافيا** | «مفيش قتل الليلة» | Skip the kill. No victim, so no `T1` trace is published |
| **طبيب** | «نفسي» *(their own name)* | Self-protect. **Available once per match** |
| **محقق** | «مش هحقق الليلة» | Skip |
| **مواطن** | «مش شاكك في حد» | Skip. Feeds `T6` |

**This single change fixes four of the reported problems at once:**

1. Every role's grid has the identical shape: *N−1 other players + 1 special
   tile in the last position.* Parity is preserved structurally, with no extra
   control and no second long-press.
2. The skip option is **among the choices**, not dumped at the bottom of a
   different screen.
3. The Doctor's self-protect is a normal option with their own name.
4. No tiny box, no awkward long-press. **One tap to select, one tap to
   confirm.**

### Grid sizing — no scrolling, ever

| Players | Layout | Tile |
|---|---|---|
| 5–6 | 2 columns | 148×64dp |
| 7–9 | 3 columns | 104×64dp |
| 10–12 | 3 columns | 104×56dp |
| 13–15 | 4 columns | 80×56dp |

The grid always fits the viewport. It shrinks; it never scrolls. Long names
truncate with ellipsis.

### Confirm

A **single tap** on «تأكيد». The long-press stays only on the two screens where
an accidental tap actually costs something: **identity confirmation** on the
pass screen and **the role card flip**. Everywhere else, one tap.

> This changes doc 05 rule 5's "identical tap count" — it is still satisfied,
> because the count is identical *across roles*. It was never a requirement that
> everything be a long-press.

### Once-per-match tiles

When the Doctor has used self-protect, the «نفسي» tile stays in place, dimmed to
40%, and is not tappable. **It never disappears** — a disappearing tile changes
the grid shape, and grid shape is a tell.

## 1.4 Screen: «تم تسجيل اختيارك»

**One line, and the detail slot.** No whisper, no summary, no hint.

> **Amended 2026-09-04.** This section used to read *"One line. Nothing else.
> No name, no whisper, no summary, no hint."* The name had to come back. What
> follows is why, and it is not a compromise — the literal rule leaked.

The whisper card, the keep-the-phone reminder and the hint are gone and stay
gone. The **echo of the name just picked** is not decoration and is not one of
them.

### Why the name stays

The Detective is told the answer *here*. This screen is the only place the
investigation result is ever rendered, because doc 05 rule 10 forbids writing it
down anywhere — not into `public_data`, not into the night's record, not into a
row any other client can read. It exists for one dwell and then it is gone.

So the Detective's confirmation screen has a word on it that the other three
roles' screens do not. Three dark panels and one lit one, and the lit one is the
Detective — which is a role tell visible from across a room, and one that does
not even need the phone to be read.

The echo is what the answer hides among. Every role's screen shows one line in
the same slot, the same size, the same weight: three of them a seat name, one of
them a role name. From any distance at which the tell would matter, they are the
same screen.

### The measurement

`test/golden/leakage/luminance_budget_test.dart` (L-05) requires every role to
be within **±2% of the set mean** emitted luminance in the `confirmed` state.
With the echo removed and the Detective's answer left standing alone:

```
detective in confirmed is 2.26% off the set mean (0.101005 vs 0.098775),
outside the ±2% budget
```

Reproduced 2026-09-04 by deleting the fallback in `TurnShell._detailSlot` and
running that suite. It is not close to the line; it is over it.

### The precedence, stated once

Doc 05 outranks this document. Not by seniority — because doc 05 is the only
one of the two whose claims are **executable**. It is not a file in `docs/`; it
is `test/leakage/` and `test/golden/leakage/`, and it adjudicates by running.
Where a sentence here and a test there disagree, the test is what ships, and
this document gets amended rather than the test relaxed.

**Never widen a leakage budget to make a rule in this document true.**

## 1.5 Screen: morning

When the Mafia skipped, or the Doctor saved:

> «الليلة دي… عدّت من غير ما حد يموت.»

**Byte-identical in both cases.** Then the trace, if one is eligible.

Then straight to discussion. **No «اسم واحد» round** unless the setting is on.

## 1.6 Screen: confrontation (Day 2+, one per day)

Unchanged from `09-information-engine.md` §2.6. If nothing qualifies, **the
screen does not appear at all.**

---

# PART 2 — THE CANONICAL ONLINE FLOW

Identical to offline, with four differences:

| | Offline | Online |
|---|---|---|
| Night | Sequential, pass the phone | **Simultaneous** |
| Whispers | ❌ Not available | ✅ **During discussion only** |
| Vote | Secret, passed | Visible and changeable until the timer ends |
| Eliminated players | Still at the table | Witness mode (`12` §4) |

---

# PART 3 — THE WHISPER SYSTEM, REBUILT

## 3.1 Online only

Offline mode has one shared screen during the day. A private message cannot be
delivered without passing the phone, which stops the discussion. **Whispers are
removed from offline mode entirely.**

## 3.2 When

**During the discussion phase only.** Not at night. Not during voting. Not
during the confrontation.

## 3.3 How it works

| Rule | Value |
|---|---|
| Allowance | 1 per living player per discussion phase |
| Available | Discussion phase only |
| Delivery | **Immediate** |
| Recipient list | **Other living players only.** Built from `alive.where((p) => p.id != me.id)` — self exclusion enforced by construction, not by a check |
| Sender + recipient | Public, drawn as a line on the table |
| Content | Private, shown once, never persisted on screen |
| Length | ≤ 120 characters |

## 3.4 The notification

- Slides in from the top, in the game's own styling — never a system toast.
- Stays until dismissed, or 12 seconds.
- Does **not** block the screen — the table and timer remain visible behind it.

---

# PART 4 — REMOVE / CHANGE / KEEP

## 4.1 Remove completely

| Item | Reason |
|---|---|
| «فتح الملف» (Detective) | Complexity with no payoff |
| Whispers in offline mode | Structurally impossible on one shared device |
| Play-hints inside a match | Clutter. They belong in the lobby and settings |
| Whisper text on the confirmation screen | Non-sequitur |
| Hint on «الليل يقترب» | That screen has three elements. That is all it gets |
| «مش هختار حد» as a separate line on the interstitial | It is now a tile in the grid |
| Two long-presses to arm an ability | Replaced by a grid tile |

## 4.2 Change

| Item | From | To |
|---|---|---|
| Doctor self-protect | Special "bullet" with its own control | **Normal grid tile with their own name**, once per match |
| Mafia quiet night | Special "bullet" | **Normal grid tile:** «مفيش قتل الليلة» |
| Citizen testify | Checkbox on the note sheet | **Deferred.** Re-evaluate after the cleanup lands |
| Skip options | Buried at the bottom | **Tiles in the grid** |
| «اسم واحد» Day-1 round | Always on | **Default OFF**, opt-in |
| Confirm action | Long-press | **Single tap** |
| Player grid | Scrollable | **Always fits**, 5–15 players |
| Settings | Wall of switches | Grouped with descriptions (Part 5) |

## 4.3 Keep

The Trace. The Confrontation. Long-press on identity confirm and card flip. The
Mafia quiet night *(as a grid tile)*. The pressure curve. Post-match coaching.

---

# PART 5 — SETTINGS, REORGANIZED

Four sections, each with a one-line description, using the right control for
each setting — not a switch for everything.

```
─── إيقاع اللعب ───
مدة الكلام            ( ٣٠ )( ٤٥ )( ٦٠ ) ثانية     ← segmented
مدة النقاش            ( ٣ )( ٥ )( ٧ ) دقائق
الوقت بيقل مع قلة اللاعبين                    [●]  ← switch + description

─── المعلومات ───
الأثر                                          [●]
المواجهة                                       [●]
جولة «اسم واحد» أول يوم                        [○]  ← DEFAULT OFF

─── الكشف ───
كشف دور ضحية الليل                             [○]
كشف دور المُقصى                                [●]

─── الأونلاين ───
الهمسات                                        [●]
تصويت مكشوف                                    [●]
الصوت                                          [●]

─── الصوت والحركة ───
الموسيقى / المؤثرات / تقليل الحركة
```

**Rules:**

- **Every switch has a one-line description underneath.**
- Use **segmented controls** for time values, **steppers** for counts,
  **switches** only for genuine on/off.
- Online-only settings are visibly grouped, and greyed with the note
  «في الأونلاين بس» when in offline mode.

---

# PART 6 — HINTS, REDUCED

| Tier | Where | Status |
|---|---|---|
| Interface hints | First time on each screen | **Keep** — outside a match |
| Play hints | **Lobby and settings only** | **Never inside a match** |
| Post-match coaching | Analytics screen | **Keep** |

**Absolute rule:** no hint, tip, or strategy line appears on any screen during a
live match, in either mode. The reserved hint slot exists on every screen for
layout parity, but during a match it is always empty.

---

# PART 7 — ACCEPTANCE

**Flow**
- [ ] Play a full offline match and write down every screen seen. It matches
      Part 1 exactly, with nothing extra
- [ ] «الليل يقترب» has exactly three elements
- [ ] «تم تسجيل اختيارك» has exactly one line
- [ ] No hint, tip, or strategy text appears anywhere during a match
- [ ] No whisper reference exists anywhere in offline mode

**Night grid**
- [ ] All players visible without scrolling at 5, 9, 12, and 15 players
- [ ] Every role's grid = (N−1) player tiles + 1 special tile in the last
      position
- [ ] Doctor's tile reads their own name; dims after use and never disappears
- [ ] Confirm is a single tap
- [ ] Golden tests: all four roles render structurally identical grids

**Whisper**
- [ ] Absent from offline mode entirely
- [ ] Available only during the discussion phase online
- [ ] Recipient list built from other living players — self exclusion is
      structural
- [ ] Delivered immediately as a styled, non-blocking card
- [ ] Graph line visible to everyone; content visible only to the recipient

**Settings**
- [ ] Four sections, each with descriptions
- [ ] Segmented controls for times, steppers for counts, switches only for
      on/off
- [ ] «اسم واحد» defaults OFF
- [ ] Online-only settings greyed with an explanation in offline mode

**Regression**
- [ ] All doc 05 golden and timing tests pass
- [ ] Fuzz harness: 10,000 matches, zero stalls
- [ ] `flutter build apk --release` succeeds
