# Mafia Master — The Online Experience

> Online is not a port of offline. It is the mode where the app becomes a **place**.
> This document defines the experience, the motion, and the asset usage that make it the product's strongest feature.
>
> Companion to `10-online-architecture.md` (the plumbing). This file is the surface.

---

# PART 1 — THE STRATEGIC ADVANTAGE

## 1.1 The unfair advantage online has

Offline, the app has **one screen shared by ten people**. It can only ever show one thing, to one person, at one time. Every interface decision is a compromise around that bottleneck.

Online, the app has **ten private, persistent, simultaneous surfaces**.

That is not a small difference. It is a categorically richer canvas, and almost every online Mafia app wastes it by treating the phone as a remote control for a card deck.

## 1.2 What only online can do

| Capability | Why offline can't | Impact |
|---|---|---|
| **Simultaneous night actions** | One phone, sequential passing | Night drops from ~4 minutes to ~45 seconds |
| **Private persistent notebook** | Nothing private can persist on a shared device | Every player builds their own case, all match |
| **Live whisper** | Delivery waits for the next physical turn | Real-time alliances and betrayal |
| **Visible vote switching** | Votes are secret until counted | Watching someone change their mind is information |
| **Rich presence** | Everyone is visible in the room already | Connection state becomes atmosphere |
| **Ghost mode for the dead** | The dead are physically at the table | Eliminated players stay engaged instead of leaving |
| **Per-player replay** | No per-player record exists | Post-game becomes an autopsy from every angle |

**The design mandate:** online must not merely match offline. Every one of the seven rows above must actually ship, or online is just offline with worse anti-cheat.

## 1.3 The night is the killer feature

In offline mode the night takes about four minutes of passing a phone around a table in silence. It is the least enjoyable part of the game.

Online, all ten players act **at the same time**, on their own screens, in about forty-five seconds.

**The night stops being dead time and becomes a tense, simultaneous, forty-five-second sprint.** Make this obvious in the marketing and in the first-run experience.

---

# PART 2 — THE TABLE

## 2.1 One scene, not a stack of screens

**Core decision: online mode is a single persistent scene that transforms between phases. It is not a sequence of pushed routes.**

Every competitor navigates screen → screen → screen. It feels like a form wizard. Instead, the online mode renders **one table, seen from above**, and every phase morphs that same table.

```
              ◆ سارة
       ◆ عمر           ◆ ليلى
   ◆ أحمد      ⬢          ◆ نور      ← ⬢ = the centre: phase, timer, trace
       ◆ خالد          ◆ يوسف
              ◆ منى
```

- Each `◆` is that player's **card back** — the same uniform back face from `assets/images/`, scaled to a seat.
- The centre `⬢` holds whatever the phase demands: the countdown, the trace text, the confrontation, the vote tally.
- Nothing is ever *pushed* on top. The table **changes state**.

**Why this matters:** continuity creates presence. Ten people looking at the same slowly-transforming space feel like they are in a room together. Ten people watching their own screens flip between forms feel like they are filling in a survey.

## 2.2 Table states

| Phase | The table looks like |
|---|---|
| **Lobby** | Seats fill one by one as players join. Empty seats are faint outlines |
| **Role reveal** | All seats dim. **Your own card lifts off the table toward the camera** and flips |
| **Night** | Table goes near-black. Only your card is lit. Other seats become faint silhouettes with no status indicators at all |
| **Morning** | Light returns from the top. The victim's card **tears and falls** out of its seat |
| **Trace** | Centre expands. Text fades in over the darkened table |
| **Confrontation** | Every seat dims to 20% **except the confronted player**, who is spotlit. Timer ring around their seat |
| **Discussion** | Active speaker's seat has a slow breathing glow. Everyone else is neutral |
| **Vote** | All cards rotate to face the centre. Your vote is a line drawn from your seat to your target |
| **Result** | Every card flips at once, revealing every role. Winning team's seats warm; losing team's dim |

## 2.3 Seat rendering

```
┌─────────┐
│         │  ← card back asset, 64×92dp
│ [glyph] │     states: idle · speaking · disconnected · dead · confronted
│         │
└─────────┘
   أحمد        ← name, caption size, below the card
   ● ● ○       ← whisper/vote/action dots (day only — NEVER at night)
```

| State | Treatment |
|---|---|
| Idle | Card back at 100%, subtle drop shadow |
| Speaking | Slow 1.4s breathing glow, `accent-gold` at 12% |
| Confronted | Spotlight cone from above, everything else at 20% |
| Disconnected | Card desaturates to 40%, a slow pulse — **never a red icon** |
| Dead | Card is torn, tilted 8°, lying flat, 35% opacity |
| Your own seat | Always has a thin cream hairline so you can find yourself instantly |

**Leakage rule (binding):** during the **night phase**, every seat renders identically — no speaking indicators, no connection dots, no action-complete ticks, no typing states. A player lagging while performing a role action must not be visible. Freeze all per-seat status for the entire night.

---

# PART 3 — SCREEN BY SCREEN

## 3.1 Lobby — the first impression

```
┌──────────────────────────────┐
│                              │
│     غرفة  « K7M2QP »         │  ← display, tracking wide, tap to copy
│        [ نسخ ]  [ مشاركة ]   │
│                              │
│         ◆ ◆ ◆                │
│      ◆    ⬢    ◆             │  ← the table, filling live
│         ◆ ◇ ◇                │     ◇ = empty seat outline
│                              │
│      ٧ / ١٠ لاعبين            │
│                              │
│  🎙 الصوت: متصل ✓            │  ← connects silently in background
│                              │
│  ┌────────────────────────┐  │
│  │      ابدأ المباراة     │  │  ← host only. others: «مستني الهوست»
│  └────────────────────────┘  │
└──────────────────────────────┘
```

**Animations:**
- A player joining: their seat outline **fills with the card back** over 400ms `ease-out`, plus a soft chime and a 2% ripple across the table.
- A player leaving: card fades out over 300ms, seat returns to outline.
- Room code: letters stagger in on first render, 60ms apart.
- Voice status: never a spinner. It says «بيتصل…» then «متصل ✓», and if it fails, «الصوت مش متاح — اللعبة هتشتغل عادي». Calm, one line, never a modal.

**Share:** a single button producing a deep link (`mafiamaster://join/K7M2QP`) plus a fallback text. This is the primary growth loop — make it one tap.

## 3.2 Role reveal — the moment that sells the product

This is the single most important animation in the app.

```
Beat 1 (0.0–0.6s)   Table dims to black. All seats fade to 15%.
Beat 2 (0.6–1.4s)   YOUR card lifts out of its seat toward the camera,
                    scaling 1.0 → 2.4, with a soft shadow growing beneath it.
Beat 3 (1.4s)       It settles, face-down, centred. Text: «اضغط مطوّلًا»
Beat 4 (on hold)    Progress ring fills around the card edge over 600ms.
Beat 5 (flip)       3D Y-axis flip, 600ms, ease-in-out, with a specular
                    sweep across the face at the 50% point.
Beat 6 (settle)     Role art + one-line description. «فهمت» appears after
                    a fixed 2.0s — identical for every role.
Beat 7 (dismiss)    Card flips back, shrinks into its seat, table relights.
```

- Uses the four role-face assets (`card_face_mafia.webp` etc.) with the **byte-identical back face**.
- The letterbox bars behind each painting must be exactly `surface-base` (see `PROMPT-critical-fixes.md` P0-2).
- Multiple Mafia: teammate names fade in **below** the card at 1.0s after the flip — never on the card itself, so the flip animation stays byte-identical across roles.

## 3.3 The night — simultaneous, silent, fast

```
┌──────────────────────────────┐
│  الليل ٢                     │
│         ┌────────┐           │
│         │   38   │           │  ← shared countdown, server-driven
│         └────────┘           │
│                              │
│      ◆   ◆   ◆   ◆           │  ← all seats identical, no status
│      ◆   ◆   ◆   ◆           │
│                              │
│   « مين تحمي الليلة؟ »        │  ← your role question
│                              │
│   [ اختار من الطاولة ]        │  ← tap a seat to select
│                              │
│  ┌────────────────────────┐  │
│  │  تأكيد — اضغط مطوّلًا   │  │  ← enabled after 8s minimum
│  └────────────────────────┘  │
└──────────────────────────────┘
```

**You select by tapping a seat on the table itself** — not from a separate list. Selection draws a thin cream line from your seat to theirs, and their card lifts 4dp.

**Animations:**
- Night entry: a 1.2s vignette closing in from the edges, all seats desaturating, the ambient bed dropping a fifth.
- Selection: target card lifts 4dp over 200ms, line draws in 180ms.
- Confirm: your card pulses once, then the whole table holds. Text: «تم. مستنيين الباقي…»
- **Waiting state must not show a progress count.** "6 of 10 done" tells the Mafia how many players are slow, which correlates with role complexity. Show only «مستنيين الباقي…».

**Mafia coordination:** other Mafia's selections appear as a **faint gold dot** on the target seat, in a slot that exists on every seat for every role and stays empty for non-Mafia. Same widget tree, always.

## 3.4 Morning + Trace

```
Beat 1   Light sweeps in from the top edge over 1.4s.
Beat 2   Victim's card TEARS — a jagged split animating across it over
         500ms — then tilts 8° and falls flat in its seat.
Beat 3   0.8s hold. Silence.
Beat 4   Centre expands. Trace text fades up over 600ms.
Beat 5   «ابدأ النقاش» appears.
```

The tear is the single most memorable moment of each round. Build it as a shader or a pre-rendered sprite sheet over the card back — not a crossfade to a "dead" image.

## 3.5 Confrontation — the spotlight

```
┌──────────────────────────────┐
│  ──────  المواجهة  ──────    │
│                              │
│      ·   ·   ◆   ·   ·       │  ← everyone at 20%, أحمد spotlit
│              أحمد            │
│         ╭────────╮           │
│         │   45   │           │  ← ring wraps HIS seat
│         ╰────────╯           │
│                              │
│   قلت إنك شاكك في عمر،        │
│   وصوّت لسارة. اشرح.          │
│                              │
│        [ خلّصت ]             │  ← only أحمد sees this button
└──────────────────────────────┘
```

- The spotlight is a radial gradient mask, animating in over 700ms.
- **Only the confronted player's mic is live.** Everyone else's is hard-muted server-side.
- Everyone else sees the same screen, without the button. They are an audience — that is the point.
- When time expires with no speech: «سكت.» stays on screen for 1.5s before the day continues. Silence is recorded and is itself evidence.

## 3.6 Voting — visible commitment

Online can do something offline cannot: **show votes forming in real time.**

```
Beat 1   All cards rotate 15° to face the centre (400ms, staggered 40ms).
Beat 2   As each player votes, a thin line animates from their seat
         to their target over 300ms.
Beat 3   Lines accumulate. The table becomes a visible graph of intent.
Beat 4   A player changing their vote: old line retracts, new line draws.
Beat 5   On resolve: all lines pulse once, then converge on the eliminated
         seat. That card lifts, flips to reveal the role, then tears.
```

**Design decision:** vote intention is **public and changeable** until the timer ends, then locked. Watching someone switch under pressure is real information, and it is only possible online. This deliberately differs from offline (secret ballot) — and that difference is a *feature* of online, not an inconsistency.

Make it a room setting: «تصويت مكشوف» (default ON online) / «تصويت سري» (matches offline).

## 3.7 Whisper

**Compose** — bottom sheet, does not leave the table:

```
┌──────────────────────────────┐
│  همسة  ·  ليك واحدة النهارده  │
│                              │
│  لمين؟   ◆ ◆ ◆ ◆ ◆          │  ← seats, tap to pick
│                              │
│  ┌──────────────────────────┐│
│  │ اكتب…              ٤٢/١٢٠││
│  └──────────────────────────┘│
│                              │
│      [ إلغاء ]   [ ابعت ]    │
└──────────────────────────────┘
```

**Send animation:** the sheet closes, and a **small light travels from your seat to theirs across the table** over 700ms. Everyone sees the light — nobody sees the words. That single animation communicates the entire mechanic without a tutorial.

**Receive:** a card slides in from the edge with the sender's name; tap to read; auto-dismisses after 8s or on tap. Content is never persisted on screen — it appears once.

**The whisper graph** stays rendered as faint lines on the table for the rest of the day. The table literally shows the social structure forming.

## 3.8 Result

```
Beat 1   Table freezes. 1.0s hold.
Beat 2   ALL seat rings flip simultaneously — 600ms, no stagger. Each comes
         back carrying its occupant's role glyph. The simultaneity is the
         drama.
Beat 3   Winning team's seats warm to cream at 20%; losing team's fade to 30%.
Beat 4   Centre: «فاز المواطنون» / «سيطرت المافيا», display size.
Beat 5   1.2s hold, then «شوف الأدوار» rises from the bottom — a roster that
         shows the full card art one player at a time at 280dp — with the
         analytics CTA beside it.
```

> **Superseded, 2026-09-07.** Beat 2 used to read *"ALL cards flip
> simultaneously"*. It cannot be built against doc 15 §5's floor — card art
> never renders below 200dp, and fifteen cards at 200dp do not fit on a 412dp
> screen. The simultaneity moved to the rings, which have no size floor to
> break, and the art moved to a roster that shows one card at a time at full
> size. See doc 15 §S-O13 for the full argument. Doc 15 governs the online
> surface where the two documents differ.

---

# PART 4 — THE DEAD PLAYER (online's biggest retention risk)

Offline, an eliminated player is still at the table, still talking, still part of the evening. **Online, they are alone in a room with a dead app.** They will close it, and they will not suggest the game next week.

This must be designed, not patched.

## 4.1 «الشاهد» — Witness mode

The moment a player is eliminated, their view transforms rather than ending:

| Capability | Detail |
|---|---|
| **Spectate the table** | Full view of every phase, live. They keep watching the game they were part of |
| **See the whisper graph** | Including new whispers forming — but never the contents |
| **Ghost chat** | Text chat with other eliminated players only. **Hard-walled: no channel from dead to living exists in the app** |
| **Prediction panel** | Privately predict the winner and name the remaining Mafia. Locked once submitted, scored in post-game |
| **Their own record** | Their suspicion log while alive — **without correctness marking** (see doc 09 leakage note) |

**What they must never see:** living players' roles, night action contents, whisper contents, or the trace before it is published to the living.

## 4.2 The elimination moment

Do not cut straight to a spectator UI. Give it weight:

```
Beat 1   Your card tears (the same animation the others see).
Beat 2   Screen desaturates fully to monochrome over 1.2s.
Beat 3   Text: «خرجت من اللعبة. بس لسه بتشوف.»
Beat 4   The table returns — in monochrome. You are still here, watching.
```

The permanent monochrome treatment for Witness mode is elegant: it is instantly legible, costs nothing, and makes being dead feel like a *state* rather than an ending.

## 4.3 Ghost chat and cheating

A dead player can obviously message a living friend outside the app. That is the same unsolvable problem as all online social deduction. In-app, the wall is absolute. Add one line in the lobby rules: «اللي بيخرج ما يتكلمش مع اللي لسه لاعب» — a social norm, stated once.

---

# PART 5 — CONNECTION STATES AS ATMOSPHERE

Most apps treat network problems as errors. In a noir game, they can be **weather**.

| State | Treatment | Copy |
|---|---|---|
| Connecting | Table renders at 60% with a slow fog drift over it | «بنتصل…» |
| Reconnecting | Fog thickens, table desaturates, everything stays visible | «الاتصال ضعيف — بنحاول» |
| Player disconnected | Their card desaturates and pulses slowly | Nothing. The card says it |
| Player returned | Card resaturates over 500ms with a soft chime | — |
| Host migrated | Brief centre line, no modal | «{name} بقى الهوست» |
| Server unreachable | Table freezes with heavy fog, action buttons disabled | «مفيش اتصال. المباراة محفوظة.» + «العب أوفلاين» |

**Absolute rules:**

- **No blocking modals during a match, ever.** A modal on a bad connection at the wrong moment is how a match dies.
- **No red.** Red is reserved for elimination. A red banner in a noir game reads as a fatal crash.
- **Never a bare spinner.** Always a state with words.
- The table remains readable in every failure state — a frozen, foggy table is far better than an error screen.

---

# PART 6 — ANIMATION CATALOGUE

All durations are tokens in `design_tokens.dart`. No inline `Duration` literals anywhere.

| Token | ms | Curve | Used by |
|---|---|---|---|
| `motion-instant` | 100 | linear | Button states |
| `motion-quick` | 200 | easeOut | Selection, seat lift |
| `motion-standard` | 300 | easeInOut | Line draw, card fade |
| `motion-phase` | 700 | easeInOut | Table state morphs, spotlight |
| `motion-dramatic` | 600 | easeInOut | Card flip |
| `motion-tear` | 500 | easeIn | Death tear |
| `motion-travel` | 700 | easeInOut | Whisper light travelling |
| `motion-reveal` | 1400 | easeOut | Morning light sweep |
| `motion-breathe` | 1400 | sine, loop | Speaking glow, fog drift |

**Performance budget:**

- 60fps sustained on a mid-range device with 15 seats rendered
- Never animate more than **3 seats simultaneously** except the result flip (which is a single batched transform)
- Fog and glow are shaders or pre-composed layers, **never** per-frame `BackdropFilter` — that is the most common cause of jank in Flutter
- The table is a single `CustomPainter` for lines and glows; seats are separate widgets. Do not repaint the whole table on every tick
- Profile with `flutter run --profile` after every animation lands, before moving on

**Reduce Motion:** every animation above has a cross-fade fallback. Dramatic *holds* remain (they are pacing, not motion). Verified on every screen.

---

# PART 7 — ASSET USAGE MAP

This table was written from `assets/` rather than from intent. **Two of the
names in the original draft did not exist** — there is no `Scense/` directory and
no `mafia-bed-hollow-v2.ogg` — so what follows is the real mapping, and where a
row's asset is absent that is said rather than implied.

Every path below is reachable from `AppImages` / `AppVideo` / `AppAudio` in
`lib/app/asset_constants.dart`, which is generated from the folder. The
authoritative list of what the table can draw is `TableMood.backdrops`; the
budget test in `test/online/doc12_acceptance_test.dart` measures that list, so a
backdrop added to the map and not to the budget fails the suite.

| Asset | Where it appears online |
|---|---|
| `card_back.webp` | Every seat on the table, every phase, lobby included. The single most-rendered asset in the app |
| `card_face_*.webp` | The role reveal only. **Never on the table** — the acceptance suite asserts that no role face is reachable from `table_seat.dart` |
| `bg_home.webp` + `bg_home_loop.webp` | Lobby |
| `bg_night.webp` + `bg_night_loop.webp` | Reveal, pre-night lobby, night. The loop only during the night itself |
| `bg_day.webp` | Morning, opening round, discussion |
| `bg_vote.webp` + `bg_vote_loop.webp` | Confrontation, ballot, elimination reveal |
| *(none)* | Result. The table carries the outcome itself; a backdrop under fifteen cards flipping at once is noise |
| `score_loop.ogg` | The bed. Continuous, never ducked by phase — this is the file doc 05 rule 12 is about, and it is what `mafia-bed-hollow-v2.ogg` was a name for |
| `join_chime` · `leave_chime` · `whisper_send` · `whisper_receive` · `vote_tick` · `death_tear` · `confrontation_swell` | §8, and **synthesised** rather than produced — see the note under Part 8 |
| `card_flip` · `elimination_reveal` · `timer_warning` · `timer_end` · `win` | Already in the folder; unchanged online |

**Phase → backdrop is keyed by phase and by nothing else.** `TableMood.of` takes a
`GamePhase` and has no `Role` parameter, so the table is role-blind by
construction rather than by review. That is what makes a backdrop safe here at
all: doc 05 forbids art behind an in-hand surface *whose content varies by role*,
and a still that varies only with the time of day is something the whole room
already knows.

**Backdrop rule:** stills sit **behind** the table at `TableMood.backdropOpacity`
— one number, 0.18, not a per-phase range, because an opacity that moved with the
phase would be a brightness channel. They cross-fade on phase change over
`motion-phase`. They are atmosphere, never content.

**Budget, measured.** The stills are already at 1080px on the longest edge:

    bg_home.webp    78.9 KB      bg_home_loop.webp    413.8 KB
    bg_night.webp   66.9 KB      bg_night_loop.webp   363.1 KB
    bg_day.webp    132.3 KB      bg_vote_loop.webp    419.5 KB
    bg_vote.webp   153.0 KB
    ───────────────────────      ───────────────────────────────
    stills         431.1 KB      loops               1196.4 KB

So the **1.5MB backdrop budget is a still budget and it passes with 3.5× of
headroom**. The loops are the `AppVideo` class — governed by that file's own
rules, and listed by doc 12 §7 under the ambient bed rather than under
backdrops — but they are three times the stills as a download, so they now carry
a ceiling of their own in the same test. A budget nobody measures is a paragraph.

---

# PART 8 — SOUND ONLINE

| Event | Sound |
|---|---|
| Player joins lobby | Soft chime, rising |
| Player leaves | Soft chime, falling |
| Night falls | Narrator + bed drops a fifth |
| Card flip | Paper, close-mic'd |
| Death tear | Paper tear + single low drum |
| Whisper sent | Very short airy sweep |
| Whisper received | Soft two-note motif, distinct from every other cue |
| Vote cast | Single tick |
| Confrontation begins | Low swell, 1s |
| Result | Cinematic sting, ≤5s |

**Rules:** the bed never ducks, swells, or stops at a phase boundary (doc 05).
Voice, when active, is a separate stream and never mixes into the bed. Everything
works with sound off — audio is reinforcement, never the sole carrier.

**Where these came from.** Seven of the rows above had no asset in the project,
so they were **synthesised** — additive synthesis and filtered noise, encoded to
Ogg Vorbis to match the rest of the folder. They are deliberately quieter than
their produced neighbours, because a generated tone beside a produced one reads
as louder than it measures and these fire far more often. They are placeholders
in provenance and not in quality: the join and leave chimes are literally the
same two notes in the two orders, and the whisper-received motif is a *falling*
minor third where the join chime is a rising fourth, so no player has to work out
which of the two just happened.

**And where none may sound.** Every cue in this table fires with the phone flat
and the room public. None may fire during a night, and that is not a discipline
kept by seven call sites — `AudioDirector.play` throws if the phone is in a hand,
and `AudioCue.cardFlip` has its own door for the one exception.

---

# PART 9 — ONBOARDING

Online has a cold start offline does not: a player joins a room having never seen the app.

- **First online match only:** a 4-card swipe before the lobby — «تليفونك دورك» · «الليل بيتعمل في نفس الوقت» · «الهمسة بتبان مين لمين، مش بتقول إيه» · «لو خرجت، لسه بتتفرج». Skippable, never shown again.
- **In-context hints, once each:** first night («اضغط على حد من الطاولة»), first whisper, first confrontation. One line, auto-dismissing, never a modal.
- **Never a tutorial match.** Nobody plays a fake round.

---

# PART 10 — ACCEPTANCE

**Experience**
- [ ] The table is one persistent scene — no route pushes between phases within a match
- [ ] Night completes in under 60 seconds with 10 players
- [ ] Every one of the seven online-only capabilities from §1.2 actually ships
- [ ] An eliminated player at minute 5 still has something to do at minute 35
- [ ] A first-time joiner completes their first night unaided in ≤ 10 seconds

**Motion**
- [ ] 60fps sustained with 15 seats, verified in profile mode
- [ ] No `BackdropFilter` in any per-frame path
- [ ] Reduce Motion verified on every screen
- [ ] All durations are tokens; zero inline `Duration` literals

**Leakage**
- [ ] Night phase: all seats render identically — no status, no indicators, no counts
- [ ] Waiting state shows no completion count
- [ ] Mafia vote dot occupies a slot present on every seat for every role
- [ ] Ghost chat has no channel to living players — proven by an automated test

**Resilience**
- [ ] No blocking modal appears during a match under any failure
- [ ] Every failure state keeps the table visible and readable
- [ ] Voice fully disabled → match completes normally
- [ ] Killing the app mid-night → resync lands on the correct phase, never on secret content

**Assets**
- [ ] Backdrop payload < 1.5MB total
- [ ] Card back byte-identical across all roles
- [ ] Letterbox bars within 12 levels of each painting's outer edge

---

## How these are checked

`test/online/doc12_acceptance_test.dart` is this list, executable. Every box
above that is a fact about the tree or about `assets/` is asserted there —
including the three that are only ever true until somebody forgets them:

* **no inline `Duration` literals** anywhere in `lib/ui/screens/online`, with two
  exemptions named in the test rather than inferred (a one-second wall clock,
  and the network heartbeat);
* **no `BackdropFilter`** in the online surface, scanned with comments stripped,
  because half the files quote this rule in their own prose;
* **no `Navigator.push`, `showDialog` or `showModalBottomSheet`** — which is
  §2.1's "one scene" and §5's "no blocking modals, ever" turning out to be the
  same assertion.

`test/online/table_scene_test.dart` is the other half: the same rules, rendered.
A correct rule and a widget that ignores it is the shape every leak has ever had,
so the night's collapse is asserted against seats that were actually built, from
a snapshot deliberately loaded with every marker at once.

**Three boxes a suite cannot close**, named in the test file where they are
skipped so a green run is never read as more than it is:

1. **60fps with fifteen seats, in profile mode.** Needs a device. What is checked
   is every structural precondition §6 names — one painter, value-compared
   repaints, no `BackdropFilter` — but a frame budget is measured, not proven.
2. **Night under 60 seconds with ten players.** Needs ten phones.
3. **A first-time joiner completes their first night unaided in ≤10s.** A
   usability finding, not an assertion.
