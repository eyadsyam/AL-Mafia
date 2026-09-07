# Mafia Master — Gameplay Depth & The Hint System

> Two problems this document solves:
> **1.** Every night is mechanically identical. Night 5 plays exactly like Night 1, so skill has nothing to express.
> **2.** New players do not know how to play, and there is currently nothing to teach them that does not leak.
>
> Binding on everything here: `05-zero-leakage-spec.md`, and the design law from `09-information-engine.md` — **the app never invents a fact.**

---

# PART 1 — DESIGN PRINCIPLES FOR GAMEPLAY CHANGES

| Principle | Meaning |
|---|---|
| **Depth before breadth** | Make the four existing roles interesting. Do not add a fifth role to fix boredom — that adds rules, not decisions |
| **Every choice must cost something** | A free choice is not a choice. If the Mafia can always kill with no downside, killing is not a decision |
| **Irreversibility creates weight** | A decision you can only make once, and cannot take back, is remembered. A repeatable one is routine |
| **Escalation** | The endgame must feel different from the opening. Same rules, tightening pressure |
| **Nothing may leak** | Any addition must pass the doc 05 checklist: same steps, same timing, same tap count, same screen structure for every role |

---

# PART 2 — «الطلقة الواحدة» — one irreversible choice per role

**The core change.** Every role gets exactly one powerful, single-use, irreversible action for the entire match. It transforms four passive roles into four roles that are each holding something.

| Role | The one bullet | Effect | Cost |
|---|---|---|---|
| **مافيا** | **«الليلة الهادية»** | Skip the kill entirely tonight | No victim → **no `T1` trace** → the town gets far less information. But no progress toward parity |
| **طبيب** | **«حماية النفس»** | Protect yourself | Usable once per match, ever. Otherwise self-protection is forbidden |
| **محقق** | **«فتح الملف»** | Publish every investigation result you have gathered, publicly and attributed | Immediately identifies you as the Detective to the Mafia |
| **مواطن** | **«الشهادة»** | Make tonight's suspicion public in the morning, attributed to you by name | Your credibility is now on the line. Wrong = you look like Mafia deflecting |

## 2.1 Why «الليلة الهادية» is the best of the four

It interacts directly with the Information Engine. The Mafia's real enemy is not the vote — it is the **Trace**. Every kill publishes the victim's last suspicion.

So the Mafia now hold a genuine dilemma:

```
Kill tonight     → you advance toward parity, but you publish a trace
Stay quiet       → you publish nothing, the town starves, but you gain no ground
```

And the morning message when they go quiet is pure atmosphere:

> «الليلة دي… عدّت من غير ما حد يموت.»

Nobody knows whether the Doctor saved someone or the Mafia chose silence. **That single line of ambiguity is worth more than a new role.**

**Balance guard:** once per match only. Without a cap, a Mafia team could stall until the town mislynches itself, which is degenerate.

## 2.2 «فتح الملف» — the Detective's real decision

The classic Detective problem: their information is useless unless they claim, and claiming gets them killed that night.

The bullet makes it a *timed* decision instead of a permanent trap:

- Results accumulate privately, night by night. The Detective sees their own file grow.
- At any morning, they may **open the file** — every result published at once, attributed.
- They will almost certainly die that night. The question is whether they have gathered enough for it to be worth it.

This turns a passive role into the most tense seat at the table.

**UI:** the file is visible **only** on the Detective's own night screen, inside the second step (which every role has). It occupies the same slot other roles use for their second-step content, so step count and dwell remain identical. Never a separate screen, never a badge on the day view.

> ⚠️ **This is the one place doc 09's "zero memory" rule is deliberately relaxed** — the Detective can review their own file. It is relaxed only because the file is worthless unless published, and publishing is public and attributed. The result is still never re-shown after the match unless the file was opened. Log this as an explicit trade-off in doc 05 §5.

## 2.3 «الشهادة» — giving the Citizen a real move

Citizens currently record suspicions that only feed analytics. The bullet lets a Citizen convert their private read into public capital, once:

> «سارة بتشهد: كانت شاكة في **خالد** الليلة اللي فاتت.»

- If Khaled turns out to be Mafia, Sara is now the most trusted voice at the table.
- If he is a Citizen, she looks like Mafia manufacturing a lynch.

**Leakage:** the testify toggle sits inside the Citizen's existing suspicion-note step. Mafia, Doctor, and Detective have the same-shaped control in the same slot on their second step — theirs performs their own bullet. **Same widget tree, same position, same dwell, always.**

## 2.4 Bullet UI (identical for all four roles)

```
┌──────────────────────────────┐
│  الليل ٣                     │
│                              │
│  { role question }           │
│                              │
│  [ table / player grid ]     │
│                              │
│  ┌──────────────────────────┐│
│  │  ◇  { bullet label }     ││  ← same slot, same size, every role
│  │     تستخدمها مرة واحدة   ││     dimmed + struck through once spent
│  └──────────────────────────┘│
│                              │
│  ┌────────────────────────┐  │
│  │  تأكيد — اضغط مطوّلًا   │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- Arming the bullet requires a **second long-press** on the bullet control, then the normal confirm. Two long-presses total — for every role, always, whether or not they arm it.
- Once spent, the control stays visible but struck through. It never disappears — a disappearing control changes layout height, and layout height is a tell.

---

# PART 3 — THE PRESSURE CURVE

The endgame currently plays at the same tempo as the opening. It should tighten.

| Living players | Discussion | Confrontation | Speaking turn |
|---|---|---|---|
| 9+ | 5:00 | 1 per day | 45s |
| 7–8 | 4:00 | 1 per day | 45s |
| 5–6 | 3:00 | 1 per day | 30s |
| 4 | 2:00 | **1 per day + 1 mid-discussion** | 30s |
| 3 | 1:30 | 1 per day + 1 mid | 20s |

Nothing changes about the rules. The clock simply closes. Players feel the walls coming in without being told.

**Audio reinforces it:** the ambient bed is unchanged (doc 05 forbids reactive audio), but the **turn-change chime rises in pitch** as the timer band shortens. It is a fixed property of the timer setting, not a reaction to game state, so it leaks nothing.

---

# PART 4 — THE HINT SYSTEM

## 4.1 The leakage constraint that governs everything here

**A hint whose text depends on the player's role is a leak in offline mode.**

Different text means different reading time, which means different dwell, which means a timing tell. It also means different layout height.

So:

| Mode | Role-specific hints |
|---|---|
| **Offline** | ❌ **Forbidden.** Every hint shown during a match is identical for every player |
| **Online** | ✅ Allowed — each player has a private screen and no shared dwell |
| **Post-match** | ✅ Allowed in both modes — the match is over |

This is a hard rule, not a preference. Build the hint engine with `mode` as a required parameter and make role-conditioned hints unreachable offline by construction.

## 4.2 Tier 1 — Interface hints (teach the app)

One line, shown once ever, then never again. Teaches the *control*, never the *game*.

| Trigger | Hint |
|---|---|
| First pass screen | «اضغط مطوّلًا عشان تأكد إنك انت» |
| First role card | «اضغط مطوّلًا عشان تقلب الكارت» |
| First night action | «اختار حد من الطاولة، وبعدين أكّد» |
| First bullet seen | «دي حاجة تستخدمها مرة واحدة في اللعبة كلها» |
| First whisper available | «همسة واحدة في اليوم. الكل هيشوف بعتها لمين، محدش هيشوف كتبت إيه» |
| First confrontation | «التطبيق بيسأل عن حاجة انت عملتها فعلًا» |
| First elimination (online) | «خرجت، بس لسه بتتفرج وبتتوقع» |

**Rules:**
- Maximum **one** hint per screen, ever.
- Auto-dismiss after 4 seconds, or on any tap.
- **Never a modal**, never a blocking overlay, never an arrow pointing at something.
- Stored as a seen-set in local settings, shared across offline and online.
- All of them appear in a fixed reserved slot that exists on every screen — so a screen showing a hint is the same height as one that is not.
- A "reset hints" option in settings, for showing a friend how to play.

## 4.3 Tier 2 — Play hints (teach the game)

Shown only in **dead time**: the lobby, waiting for other players, and the loading beat between phases. **Never while a decision is open.**

**Offline pool — generic only, identical for every player:**

> «اللي بيتكلم كتير مش دايمًا اللي بيخبّي.»
> «خلي بالك مين بيوافق على طول من غير ما يفكر.»
> «الصمت مش دليل. بس هو معلومة.»
> «مين بيغيّر رأيه بسرعة لما يتضغط؟»
> «المافيا الشاطرة بتتهم بدري عشان تبان بريئة.»
> «التصويت مع الأغلبية مريح. وده بالظبط اللي بيعتمدوا عليه.»
> «مين استفاد من اللي مات امبارح؟»

Selected by `deriveSeed(matchSeed, 'hint', phaseIndex)` — **not** by role, not by `Random()`. Same hint for every player at the same moment, guaranteed.

**Online pool — role-specific allowed:**

| Role | Hints |
|---|---|
| مافيا | «متقتلش اللي بيشك فيك على طول — شكه هيتنشر» · «الليلة الهادية بتجوّع الطاولة من المعلومات» · «اتكلم. المافيا الساكتة بتموت» |
| طبيب | «متحميش نفس الشخص مرتين ورا بعض» · «حماية النفس معاك مرة واحدة — استناها» · «لو نجحت في الحماية، المافيا هتعرف إن فيه دكتور» |
| محقق | «الملف بيكبر كل ليلة. بس افتحه وانت هتموت» · «حقق في اللي بيتكلم كتير، مش في اللي ساكت» |
| مواطن | «شكك مش رايح على فاضي — بيتسجّل» · «الشهادة معاك مرة واحدة. استناها لما تكون متأكد» |

**Rules:** maximum one per phase. Never during an open decision. Never above the fold — always in a secondary slot.

## 4.4 Tier 3 — Post-match coaching «كان ممكن»

The highest-value tier. Fully safe (the match is over) and directly drives replay.

Generated from the player's own real data:

| Trigger | Coaching |
|---|---|
| Suspected the same innocent 3+ nights | «شكيت في يوسف ٣ ليالي وهو مواطن. جرب تغيّر رأيك أسرع لما الدليل ما يجيش.» |
| Voted with the majority ≥80% of the time | «صوّت مع الأغلبية ٤ من ٤. جرب تكوّن رأيك قبل ما تسمع الباقي.» |
| Never used their bullet | «ماستخدمتش الشهادة. كانت هتفرق في اليوم التالت.» |
| Never whispered | «ماهمستش ولا مرة. الهمسة بتبني تحالفات.» |
| Correct early read that they abandoned | «كنت شاكك في عمر من الليلة الأولى وهو كان مافيا — وبعدين سبته. ثق في قراءتك الأولى.» |
| Bottom quartile speaking time | «انت من أقل اللي اتكلموا. الصمت بيخلي الطاولة تشك فيك.» |
| Mafia who survived to the end | «عشت للآخر. أدق حاجة عملتها: اتهمت بدري.» |
| Detective who never opened the file | «الملف فضل مقفول. ٣ نتايج راحوا معاك.» |

**Conformity rate is the sharpest metric here** — how often you voted with the crowd. A high rate means you are not thinking, and almost nobody realises it about themselves. Surface it as a number.

**Tone:** an observation, never a scold. It states what happened and offers one alternative. No score, no grade, no stars.

---

# PART 5 — MATCH PRESETS

Groups differ. Three presets on the settings screen, plus custom.

| | **سريعة** | **كلاسيكية** | **قاسية** |
|---|---|---|---|
| Speech | 30s | 45s | 30s |
| Discussion | 3:00 | 5:00 | 2:00 |
| Confrontation | 1/day | 1/day | 1/day + 1 mid |
| Trace | ON | ON | ON |
| Whisper | ON | ON | OFF |
| Bullets | OFF | ON | ON |
| Doctor | 1 | 1 | **0** |
| Mafia ratio | ¼ | ¼ | **⅓** |
| Night victim's role revealed | ON | OFF | OFF |

**«سريعة»** is the on-ramp: bullets off, fewer rules, ~15 minutes. Recommend it for a group's first match.
**«قاسية»** removes the safety net — no Doctor, more Mafia, no whispers, a brutal clock.

---

# PART 6 — AUTOMATED BALANCE TESTING

You already have a 10,000-match fuzz harness. Extend it into a **balance harness** — this is what makes these changes safe to ship.

```dart
// For each preset × player count, simulate and assert the win rate lands in band.
void main() {
  for (final preset in [fast, classic, brutal]) {
    for (final n in [5, 6, 7, 8, 9, 10, 12, 15]) {
      test('$preset @ $n players is balanced', () {
        var mafiaWins = 0;
        const runs = 5000;
        for (var seed = 0; seed < runs; seed++) {
          final r = simulateMatch(preset: preset, players: n, seed: seed);
          if (r.outcome == MatchOutcome.mafiaWin) mafiaWins++;
        }
        final rate = mafiaWins / runs;
        expect(rate, inInclusiveRange(0.40, 0.60),
            reason: '$preset @ $n → mafia win rate ${(rate*100).toStringAsFixed(1)}%');
      });
    }
  }
}
```

**Target band: 45–55%, fail outside 40–60%.**

The simulated agents do not need to be smart. Use simple heuristic policies:

| Policy | Behaviour |
|---|---|
| `RandomPolicy` | Uniform random legal move — the floor |
| `NaivePolicy` | Vote for whoever is most suspected; suspect randomly |
| `TracePolicy` | Uses published traces — votes for whoever the last victim suspected |
| `MafiaSmartPolicy` | Avoids killing players who suspect them; uses the quiet night when a trace would incriminate |

Run at least `NaivePolicy` and `TracePolicy` for every preset. If `TracePolicy` does not beat `NaivePolicy` for the town, **the Trace system is not actually producing usable information** — that alone justifies the harness.

**Additional assertions:**

- Median match length in nights, per player count, must sit in 3–6. Longer means the game drags
- The quiet night must not push the Mafia win rate above 60% at any player count
- No preset may produce a match exceeding 500 moves (the existing non-termination guard)

---

# PART 7 — SETTINGS

Under «إعدادات متقدمة»:

| Group | Setting | Default |
|---|---|---|
| **الطلقة الواحدة** | تفعيل الطلقات | ON |
| | الليلة الهادية (مافيا) | ON |
| | حماية النفس (طبيب) | ON |
| | فتح الملف (محقق) | ON |
| | الشهادة (مواطن) | ON |
| **الإيقاع** | منحنى الضغط | ON |
| | مدة الكلام | 45s |
| **التلميحات** | تلميحات الواجهة | ON |
| | تلميحات اللعب | ON |
| | «كان ممكن» بعد المباراة | ON |
| **الكشف** | دور ضحية الليل | OFF |

Every one is togglable. A group that dislikes a mechanic should be able to remove it, not endure it.

---

# PART 8 — LEAKAGE CHECKLIST FOR THIS DOCUMENT

Every item below must be re-verified after implementing anything in this file.

- [ ] Bullet control occupies the **same slot, same size** on every role's night screen
- [ ] Bullet arming is **two long-presses for every role**, armed or not
- [ ] A spent bullet is struck through, **never removed** — removal changes layout height
- [ ] The Detective's file lives **inside the existing second step**, not on a new screen
- [ ] Offline hints are **identical text for every player**, seeded by phase, never by role
- [ ] Hint slot exists on **every** screen, so a screen with a hint is the same height as one without
- [ ] The quiet-night morning message is **indistinguishable** from a successful Doctor save
- [ ] Pressure-curve timers are a function of **living player count only** — never of roles
- [ ] Turn-change chime pitch is a function of the **timer band**, never of game state
- [ ] Golden tests still pass: all four roles render structurally identical night screens
- [ ] Step count and tap count remain identical across roles

---

# PART 9 — ACCEPTANCE

- [ ] Every role has exactly one irreversible choice, and it is visible from Night 1
- [ ] Quiet night and Doctor save produce **byte-identical** morning output
- [ ] Balance harness passes: every preset × player count inside 40–60%
- [ ] `TracePolicy` outperforms `NaivePolicy` for the town — proving traces carry real information
- [ ] Median match length 3–6 nights across all configurations
- [ ] All Tier-1 hints appear once and never again; reset option works
- [ ] Zero role-conditioned hint text is reachable in offline mode — enforced by type, not by convention
- [ ] Post-match coaching generates from real data only; no generic filler
- [ ] All doc 05 golden and timing tests still pass
