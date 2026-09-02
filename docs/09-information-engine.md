# Mafia Master — The Information Engine

> The system that solves *"I have nothing to say and no reason to suspect anyone."*
> Three layers: **Trace**, **Confrontation**, **Whisper**.
> Works identically in offline and online mode. Pure, deterministic, testable.

---

## 0. The design law

Classic Mafia has a mathematical flaw: **Day 1 contains zero information.** One player died at random. There is nothing to reason about, so players say "I don't know" and stall.

Two ways to fix it:

| Approach | Who | Consequence |
|---|---|---|
| **Invent** information (a crime, scripted clues) | Mafioso | Content runs out. Repeats. Becomes a puzzle to solve, not a table to read |
| **Surface** information the players themselves generated | **Us** | Never repeats. Never runs out. Impossible to copy without behavioural tracking |

**The law, binding on every feature in this document:**

> **The app never invents a fact. It only reveals a fact that a player actually created.**

If a proposed feature requires writing fiction, it is rejected.

---

# LAYER 1 — THE TRACE (الأثر)

## 1.1 What it is

Every morning, immediately after the death announcement, the app reveals **exactly one true forensic observation** about the night that just passed.

## 1.2 Why this fixes Day 1 specifically

Citizens already record a suspicion every night (`03-screens-setup-night.md`, S-08). That means **on Night 1, the future victim recorded a suspicion before dying.**

So Morning 1 can say:

> «خالد خرج من اللعبة.
> آخر حاجة سجّلها: كان شاكك في **يوسف**.»

The table now has a thread from the first second. Yousef must respond. Everyone watches how he responds. **The discussion starts itself.**

**Honest note on Night 1:** night-1 suspicions are near-random, so the *evidential* value is low. Its value is **social** — it forces a first interaction and gives the table a target to orbit. From Night 2 onward the evidential value becomes real, because suspicions are now informed.

## 1.3 The strategic engine this creates

This single mechanic creates a genuine dilemma for the Mafia every night:

```
The player who is onto you:
   kill them   → their suspicion is published → the table learns they were onto you
                 → you are now implicated
   spare them  → they keep pushing you in discussion
```

And a counter-play: **kill someone whose suspicion points at an innocent** — the published trace then misdirects the table *for* the Mafia. This is a real, skill-expressing decision that did not exist before.

## 1.4 Trace catalogue

Each trace is a pure function of the night's recorded data. `T1` is the highest-value trace and is always preferred when eligible.

| ID | Name | Eligibility | Reveal text | Names? |
|---|---|---|---|---|
| **T1** | آخر شك للضحية | A player died this night **AND** recorded a suspicion **AND** the target is still alive | «آخر حاجة سجّلها {victim}: كان شاكك في **{target}**» | ✅ both |
| **T2** | نجاة | Doctor successfully blocked a kill | «حد اتحمى الليلة دي… ونجا» | ❌ never |
| **T3** | تطابق | ≥2 living players suspected the same person | «**{n}** لاعبين شكّوا في نفس الشخص الليلة دي» | ❌ |
| **T4** | تحوّل | ≥1 player changed their suspicion vs. previous night | «**{n}** غيّر شكه الليلة دي» | ❌ |
| **T5** | الظل | ≥1 living player has never been suspected by anyone, and ≥2 nights have passed | «فيه لاعب لسه محدش شك فيه ولا مرة» | ❌ |
| **T6** | الصمت | ≥1 player skipped recording a suspicion | «فيه لاعب رفض يسجّل شكه الليلة دي» | ❌ |
| **T7** | الدائرة | Two living players suspected each other | «اتنين شاكّين في بعض» | ❌ |
| **T8** | الإجماع | ≥60% of living players suspected the same person | «أغلب الطاولة شكّت في نفس الشخص» | ❌ |
| **T0** | العدم | *Fallback — nothing else eligible* | «الليلة دي ماسابتش أي أثر» | ❌ |

**Naming rule:** only `T1` names players, and only because the victim is already dead and the target is publicly forced to respond. Every other trace is aggregate. Naming more would collapse the deduction into arithmetic.

## 1.5 Selection algorithm

```dart
/// Pure. Deterministic. No I/O. Same inputs → same output, offline or online.
TraceResult selectTrace({
  required NightRecord night,        // all recorded actions for this night
  required List<NightRecord> history,
  required List<Player> players,
  required int nightNumber,
  required int matchSeed,
}) {
  final eligible = <TraceCandidate>[];

  for (final type in TraceType.values) {
    final c = type.evaluate(night, history, players);
    if (c == null) continue;                       // not eligible
    if (_firedLastMorning(history, type)) continue; // never repeat back-to-back
    eligible.add(c);
  }

  if (eligible.isEmpty) return TraceResult.none();  // T0

  // score = drama × novelty × information
  for (final c in eligible) {
    c.score = c.type.dramaWeight
            * _noveltyFactor(history, c.type)      // 1.0 fresh → 0.4 used often
            * c.informationValue;                  // e.g. T3 with n=4 > T3 with n=2
  }

  eligible.sort((a, b) => b.score.compareTo(a.score));

  // Deterministic tie-break — never Random() without a seed
  final rng = Random(matchSeed ^ (nightNumber * 7919));
  final top = eligible.where((c) => c.score >= eligible.first.score - 0.01).toList();
  return top[rng.nextInt(top.length)].build();
}
```

**Drama weights (tune from playtests, not from taste):**

| Trace | Weight |
|---|---|
| T1 | 10.0 |
| T8 | 6.0 |
| T3 | 5.0 |
| T7 | 4.5 |
| T2 | 4.0 |
| T5 | 3.5 |
| T4 | 3.0 |
| T6 | 2.5 |

## 1.6 Balance analysis

| Concern | Analysis | Verdict |
|---|---|---|
| Does T1 make Citizens too strong? | Only when the victim was actually right. Mafia kill blind, so early T1s are usually noise. Later T1s are earned information | ✅ Balanced |
| Can Mafia exploit T1? | Yes — deliberately kill someone whose suspicion misdirects. This is *good*: it adds a skill axis | ✅ Feature |
| Does T2 out the Doctor? | No — it never names the saved player, and the Doctor's identity is not implied by the fact a save occurred | ✅ Safe |
| Could T5 (الظل) unfairly target a quiet Citizen? | Yes, and that is correct — being invisible in Mafia *should* be dangerous. It also punishes Mafia who hide too well | ✅ Feature |
| Does the Detective become redundant? | No. Traces are aggregate or about the dead. Only the Detective gets a definite living-player alignment | ✅ Safe |
| Can a Mafia player game T6 by always skipping? | The trace fires and the table learns *someone* refused. Repeated skipping becomes a Confrontation trigger (C10) | ✅ Self-correcting |

## 1.7 UI

Appears on the **morning screen** (`S-10`), on the table, after the death line, with a beat.

```
┌──────────────────────────────┐
│      أشرق الصباح ☀           │
│                              │
│   فقدنا « خالد »             │
│                              │
│  ─────  الأثر  ─────         │  ← divider, caption size, muted
│                              │
│   آخر حاجة سجّلها خالد:       │
│   كان شاكك في « يوسف »       │  ← title size, cream
│                              │
│  ┌────────────────────────┐  │
│  │      ابدأ النقاش       │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

- Trace text appears **1.2s after** the death line — never simultaneously. The pause is the drama.
- Same visual treatment for every trace type. No icons, no colour coding — colour-coding traces would let players classify them before reading.
- Table screen, so `surface-base` at normal brightness (not the dimmed night value).

---

# LAYER 2 — THE CONFRONTATION (المواجهة)

## 2.1 What it is

At the start of each day (Day 2 onward), the app names **one player** and states **one true observation about their own behaviour**, then gives them a timed window to respond in front of everyone.

This is not a prompt. It is **evidence generated from what they actually did.**

## 2.2 Day 1 exception — «اسم واحد»

Day 1 has no behavioural history, so a Confrontation is impossible without inventing something. Instead, Day 1 runs a **forced opener**:

> Every living player, in seating order, has **10 seconds** to say one name. No explanation permitted. No "I don't know" permitted.

- The app records each public accusation (this is now Day-1 history for later Confrontations)
- The whole round takes ~90 seconds for 9 players
- It kills the opening silence structurally rather than with content

**This is the single highest-value 90 seconds in the redesign.** It converts a dead start into a full suspicion map.

## 2.3 Confrontation catalogue

| ID | Name | Trigger condition | Text |
|---|---|---|---|
| **C1** | تناقض التصويت | Player publicly accused X, then voted for Y | «{p} — قلت إنك شاكك في {x}، وصوّت لـ{y}. اشرح.» |
| **C2** | الانقلاب | Player defended X on day N, voted for X on day N+1 | «{p} — امبارح دافعت عن {x}. النهارده صوّت له. إيه اللي اتغيّر؟» |
| **C3** | الثبات | Same night-suspicion target for 3 consecutive nights | «{p} — شاكك في نفس الشخص من ٣ ليالي. ليه متأكد كده؟» |
| **C4** | الظل | Player has never been suspected by anyone, ≥3 days elapsed | «{p} — محدش شك فيك ولا مرة. ليه في رأيك؟» |
| **C5** | التوأم | Player voted identically with another player ≥3 times | «{p} — انت و{x} صوّتوا نفس التصويت ٣ مرات. صدفة؟» |
| **C6** | الصامت | Lowest cumulative speaking time, ≥2 days elapsed | «{p} — انت أقل واحد اتكلم في اللعبة. عايز تقول إيه؟» |
| **C7** | الميت يتكلم | The last victim's recorded suspicion named this player | «{p} — آخر واحد مات كان شاكك فيك. ردّك؟» |
| **C8** | الهمّاس | Whispered to the same player on ≥2 consecutive days *(online / offline whisper enabled)* | «{p} — بتهمس لـ{x} كل يوم. ليه هو بالذات؟» |
| **C9** | التقلّب | Changed night-suspicion target ≥3 times in 4 nights | «{p} — غيّرت شكك ٣ مرات. انت شايف إيه بالظبط؟» |
| **C10** | الامتناع | Skipped recording a suspicion ≥2 times | «{p} — رفضت تسجّل شكك مرتين. ليه؟» |
| **C11** | الناجي | Player was targeted at night and survived (Doctor save), ≥1 day later | «{p} — حد حاول يوصلك وماعرفش. مين ممكن يحميك؟» |

> **C11 is dangerous** — it implies a save occurred and points at the target, which narrows the Doctor's read. Gate it behind a setting, default **OFF**. Listed for completeness only.

## 2.4 Selection algorithm

```dart
ConfrontationResult? selectConfrontation({
  required GameHistory history,
  required List<Player> alive,
  required int dayNumber,
  required int matchSeed,
}) {
  if (dayNumber <= 1) return null;   // Day 1 uses the forced opener instead

  final candidates = <ConfrontationCandidate>[];

  for (final type in ConfrontationType.enabled) {
    candidates.addAll(type.findAll(history, alive));   // may match several players
  }

  // Hard filters
  candidates.removeWhere((c) =>
      !alive.contains(c.target)                        // never confront the dead
   || c.target == history.lastConfrontedPlayer         // no back-to-back same player
   || c.type == history.lastConfrontationType);        // no back-to-back same type

  if (candidates.isEmpty) return null;                 // silently skip — never invent one

  for (final c in candidates) {
    c.score = c.type.severity                          // how damning
            * _recencyBoost(c.evidenceDay, dayNumber)  // fresher evidence scores higher
            * _fairnessFactor(history, c.target);      // 1.0 → 0.5 if already confronted often
  }

  candidates.sort((a, b) => b.score.compareTo(a.score));
  final rng = Random(matchSeed ^ (dayNumber * 104729));
  final top = candidates.where((c) => c.score >= candidates.first.score - 0.01).toList();
  return top[rng.nextInt(top.length)].build();
}
```

**Fairness factor is not optional.** Without it, one unlucky player gets confronted every single day and stops enjoying the game. Cap: no player may be confronted more than twice per match unless there are no other candidates.

## 2.5 Frequency — the tyranny problem

**Exactly one Confrontation per day. Never more.**

If the app interrupts constantly it stops being a Game Master and becomes an interrogator, and players start ignoring it. The app's job is to **open a door**, not to run the conversation.

Day structure:

```
Morning + Trace
      ↓
Confrontation  (one, 45s response)     ← Day 2+
      ↓
Free discussion  (timer, no interruption)
      ↓
Defense round
      ↓
Vote
```

## 2.6 UI

```
┌──────────────────────────────┐
│  النهار ٣                    │
│                              │
│  ──────  المواجهة  ──────    │
│                              │
│         « أحمد »             │  ← display size
│                              │
│   قلت إنك شاكك في عمر،        │
│   وصوّت لسارة.               │  ← body, cream
│                              │
│         اشرح.                │
│                              │
│         ┌────────┐           │
│         │   45   │           │  ← PhaseTimer
│         └────────┘           │
│                              │
│      [ خلّصت ]               │
└──────────────────────────────┘
```

- The named player may end early with «خلّصت».
- The rest of the table cannot interrupt — the app enforces one speaker.
- **Online:** only this player's mic is unmuted for the 45 seconds. Everyone else is receive-only.
- **Offline:** the phone stays on the table; the named player speaks aloud.

---

# LAYER 3 — THE WHISPER (الهمس)

## 3.1 What it is

Each living player may send **one private message per day** to one other living player.

**The existence and the recipient are public. The content is private.**

```
┌──────────────────────────────┐
│  همسات النهار ٢              │
│                              │
│   أحمد  ←  سارة              │
│   عمر   ←  أحمد              │
│   ليلى  ←  سارة              │
│                              │
│   (خالد ونور مابعتوش)         │
└──────────────────────────────┘
```

## 3.2 Why this is the strongest addition

- It creates a **visible alliance graph** that the whole table can reason about, while the actual content stays secret. Maximum paranoia per byte.
- It gives Citizens a private coordination channel they have never had. (Mafia already coordinate at night — this *narrows* the asymmetry rather than widening it.)
- It generates first-class evidence for Confrontations (`C8`) and for post-game analytics.
- Fake whispers become a real tactic: whisper nonsense to an innocent to make them look allied with you.
- It is the mechanic that makes **online genuinely richer than offline**, which is the stated goal.

## 3.3 Rules

| Rule | Value |
|---|---|
| Allowance | 1 per living player per day, non-cumulative (unused is lost) |
| Max length | 120 characters |
| Recipient | Any other living player |
| Self-whisper | Forbidden |
| Whisper to dead | Forbidden (recipient list only shows the living) |
| Sender + recipient | **Public**, shown on the day screen |
| Content | **Private**, visible only to the recipient |
| Delivery — online | Immediately, as a dismissible card |
| Delivery — offline | Queued; shown on the recipient's next private phone turn |
| Post-match reveal | Graph always revealed. Content revealed only if the "كشف الهمسات" setting is ON (default **OFF**) |

## 3.4 Undelivered whispers

If the recipient dies before reading, the whisper is **voided**. The sender is told:

> «الهمسة ماوصلتش.»

This is a small, cruel, excellent detail. Keep it.

## 3.5 Abuse protection

Whispers are private text between people who may be strangers online. This must be handled, not ignored.

| Control | Implementation |
|---|---|
| Rate limit | 1/day, enforced **server-side** in online mode — never trust the client |
| Length limit | 120 chars, enforced both client and server |
| Profanity filter | Client-side Arabic + English word list, applied on send with a warning, not a hard block |
| Report | Long-press a received whisper → report. Online: flags the row in Supabase. Offline: adds to a local block list |
| Block | Blocked player's whispers are silently dropped for that user (sender is not told — do not create a harassment feedback loop) |
| Private lobbies default | Room codes are private by default; no public matchmaking in v1. This removes 90% of the abuse surface |

## 3.6 Whispers in offline mode

They work, with a delay. The phone already passes to every player every night, so a queued whisper is delivered on the recipient's next turn.

**Leakage check (doc 05):** the whisper card must appear on **every** player's private turn — showing "مفيش همسات ليك" when empty — so that receiving a whisper is not distinguishable by screen count or timing. This is mandatory, not optional.

---

# 4. Determinism

Every generator in this document is a **pure function**. This is non-negotiable and gives three properties:

1. **No online/offline divergence.** Same match seed and same actions produce the same trace and confrontation on every device.
2. **Exhaustively testable.** No mocking, no I/O, no time dependency.
3. **Replayable.** Post-game analytics can reconstruct any moment from the action log.

Rules:

- `Random()` is **forbidden**. Always `Random(seed)` with a seed derived from `matchSeed` and the phase index.
- No `DateTime.now()` inside generators — pass timestamps in as data.
- No reads of device state, locale, or platform inside generators.
- Generators live in `lib/engine/information/` with **zero Flutter imports**.

```dart
// The single source of truth for all randomness in a match
int deriveSeed(int matchSeed, String salt, int index) =>
    matchSeed ^ (salt.hashCode * 31) ^ (index * 104729);
```

---

# 5. Data model

```dart
class NightRecord {
  final int nightNumber;
  final Map<PlayerId, PlayerId?> suspicions;   // null = skipped
  final Map<PlayerId, String?>   reasons;      // ≤40 chars, optional
  final PlayerId? mafiaTarget;
  final PlayerId? doctorProtect;
  final PlayerId? detectiveCheck;
  final PlayerId? victim;                      // null if saved
  final bool      saveOccurred;
  final TraceType? revealedTrace;              // what was published the next morning
}

class DayRecord {
  final int dayNumber;
  final Map<PlayerId, PlayerId> openingAccusations;  // Day 1 «اسم واحد»
  final Confrontation? confrontation;
  final Map<PlayerId, PlayerId?> votes;              // null = abstain
  final PlayerId? eliminated;
  final Map<PlayerId, int> speakingSeconds;
  final List<WhisperMeta> whispers;                  // sender, recipient, day (never content)
}

class Whisper {
  final PlayerId from, to;
  final int day;
  final String content;        // stored separately, access-controlled
  final bool delivered, read, voided;
}
```

**Storage split (important for privacy and for RLS):** `WhisperMeta` (the graph) is readable by everyone in the match. `Whisper.content` is readable only by sender and recipient. These are two tables online, two collections offline.

---

# 6. Post-game analytics — what this unlocks

The three layers turn the existing analytics screens (`04-screens-day-postgame.md`, S-15) from a summary into a genuine autopsy:

| New analytic | Source |
|---|---|
| خريطة التحالفات | Whisper graph across all days |
| منحنى الشك | Who was suspected, by how many, per night |
| أدق قراءة مبكرة | Earliest correct suspicion of a Mafia member |
| ثبات الموقف | How often each player changed their mind |
| كفاءة المافيا | Did their kills successfully misdirect the published traces? |
| صمود المواجهة | Was a confronted player eliminated within 2 days? |
| المُقنع | Player who was confronted and *still* survived to the end |

None of this requires new data collection. It all falls out of the records above.

---

# 7. Settings exposed to players

Grouped under «إعدادات متقدمة → محرك المعلومات»:

| Setting | Default | Note |
|---|---|---|
| الأثر | ON | Turning it off restores classic Mafia |
| المواجهة | ON | — |
| الهمس | ON online / OFF offline | Offline delay makes it less lively |
| كشف محتوى الهمسات بعد المباراة | OFF | Graph is always revealed |
| جولة «اسم واحد» في اليوم الأول | ON | — |
| C11 (الناجي) | OFF | Narrows the Doctor — advanced groups only |
| مدة المواجهة | 45s | 30 / 45 / 60 |

**Every one of these must be togglable.** Groups differ, and a mechanic that a group dislikes should be removable rather than endured.

---

# 8. What this deliberately is NOT

| Rejected | Why |
|---|---|
| A crime scenario / backstory | Content runs out; becomes a puzzle, not a table read. This is the Mafioso trap |
| Scripted clue decks | Same reason. Players memorise them |
| Generic prompt cards ("pick someone you trust") | Identical every match. Becomes wallpaper after three games |
| AI-generated narrative per match | Costs money, non-deterministic, breaks offline mode, and can produce nonsense at the worst moment |
| More than one Confrontation per day | The app becomes a tyrant and players tune it out |
| Traces that name living players (except T1's target) | Collapses deduction into arithmetic |
