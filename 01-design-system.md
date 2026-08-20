# Mafia Master — Design System

> **Visual identity:** Premium Board Game Companion — mysterious, cinematic, minimal, adult-oriented.
> **NOT:** a cartoon game, a kids' app, or a cluttered interface.

---

## 1. Design Philosophy

| Principle | Practical application |
|---|---|
| Mystery over decoration | Dark backgrounds, dim lighting, measured contrast — the screen feels like an interrogation room, not a nightclub |
| Visual calm | One dominant element per screen. Never more than one Primary Action |
| Absolute symmetry | Every role sees exactly the same visual structure (see Zero-Leakage spec) |
| Premium touch | Generous spacing, elegant type, short intentional motion |

---

## 2. Color Palette

### 2.1 Base Colors (Dark Theme — the only theme in MVP)

| Name | Token | Hex | Usage |
|---|---|---|---|
| Deep Night | `surface-base` | `#0D0F14` | App background |
| Charcoal | `surface-raised` | `#161A22` | Cards and raised surfaces |
| Light Charcoal | `surface-overlay` | `#1F2530` | Dialogs and sheets |
| Subtle Border | `border-subtle` | `#2A3140` | Dividers and card borders |

### 2.2 Text Colors

| Name | Token | Hex | Usage |
|---|---|---|---|
| Primary text | `text-primary` | `#EDEFF3` | Headings and main content |
| Secondary text | `text-secondary` | `#9AA3B2` | Descriptions and hints |
| Muted text | `text-muted` | `#5C6575` | Disabled or marginal text |

### 2.3 Accent Colors

| Name | Token | Hex | Usage |
|---|---|---|---|
| Muted Gold | `accent-gold` | `#C9A227` | Primary action, selection, logo |
| Pressed Gold | `accent-gold-pressed` | `#A8871F` | Pressed state |
| Crimson | `accent-crimson` | `#8E2A35` | Elimination and destructive moments only |
| Muted Sage | `accent-sage` | `#4C7A5C` | Success confirmations (rare) |

> ⚠️ **Critical anti-leakage rule:** never bind any color to a specific role during gameplay.
> Red must NEVER appear on night screens — a red glow reflected on a player's face signals they saw something "dangerous."
> All night screens share the same overall brightness (a unified **Luminance Budget**).

### 2.4 Role Colors (used ONLY in role reveal and post-game screens)

| Role | Hex | Note |
|---|---|---|
| Mafia | `#8E2A35` crimson | Appears only in private reveal or final reveal |
| Doctor | `#3F6E8C` night blue | — |
| Detective | `#C9A227` gold | — |
| Citizen | `#6B7484` silver gray | — |

---

## 3. Typography

### 3.1 Families

| Purpose | Arabic font | Latin font | Rationale |
|---|---|---|---|
| Headings | **Cairo** (Bold/SemiBold) | **Cinzel** or Cairo | Premium presence without excess |
| Body | **IBM Plex Sans Arabic** | IBM Plex Sans | Excellent legibility on small screens |
| Numerals & timers | IBM Plex Mono | IBM Plex Mono | Tabular figures for counters |

### 3.2 Type Scale

| Token | Size | Weight | Line height | Usage |
|---|---|---|---|---|
| `display` | 34sp | Bold | 1.2 | Phase titles ("Night falls") |
| `headline` | 26sp | SemiBold | 1.25 | Screen titles |
| `title` | 20sp | SemiBold | 1.3 | Card titles, player names |
| `body` | 16sp | Regular | 1.5 | General content |
| `body-small` | 14sp | Regular | 1.45 | Descriptions |
| `caption` | 12sp | Medium | 1.35 | Small labels, badges |
| `timer` | 48sp | Mono Medium | 1.0 | Timers |

### 3.3 Rules

- Direction: RTL-first with full LTR support (app ships in Arabic + English).
- No italics for Arabic text.
- Minimum size for any tappable text: 14sp.

---

## 4. Spacing & Layout

Spacing system built on a **4dp** unit:

| Token | Value | Usage |
|---|---|---|
| `space-xs` | 4dp | Icon-to-text gap |
| `space-sm` | 8dp | Inside components |
| `space-md` | 16dp | Default card padding |
| `space-lg` | 24dp | Between sections |
| `space-xl` | 32dp | Vertical screen margins |
| `space-2xl` | 48dp | Dramatic separation (phase screens) |

- Horizontal screen margins: 20dp.
- Max content width: 480dp (auto-centered on wider screens).
- Corner radii — cards: 16dp, buttons: 14dp, dialogs: 20dp.

---

## 5. Component Library

### 5.1 Buttons

| Component | Spec |
|---|---|
| `PrimaryButton` | `accent-gold` background, `#0D0F14` text, height 56dp, full width, SemiBold 16sp |
| `SecondaryButton` | 1.5dp `border-subtle` outline, `text-primary` label, same height |
| `TextButton` | `text-secondary` label, no background — marginal actions only |
| `DangerButton` | `accent-crimson` background — used ONLY for "End match" |

Rules: exactly one primary button per screen. Minimum touch target 48×48dp.

### 5.2 `PlayerTile`

The most important component — used on every selection screen.

```
┌─────────────────────────────┐
│  ◯  Ahmed                   │   ← 44dp circular avatar (initial or glyph)
└─────────────────────────────┘
```

| State | Appearance |
|---|---|
| Default | `surface-raised` background, `border-subtle` border |
| Selected | 2dp `accent-gold` border + 8% gold glow fill |
| Dead (day) | 40% dim + "Out of the game" badge |
| Disabled | 60% dim, non-tappable |

> **Leakage rule:** on night screens the player grid renders **identical elements for every role** — no badges, no extra visible indicators. Role-specific content (e.g. the Mafia vote indicator) lives inside a reserved slot that exists in the tile for ALL roles but stays empty for non-Mafia. Dimensions never differ.

### 5.3 `PassScreen`

The handoff screen between players:

- Full `surface-base` background, faint logo centered.
- Text: "Pass the phone to **{name}**".
- Single button: "I am {name}" — requires a 600ms long-press to prevent accidental opening.

### 5.4 `PhaseTimer`

- 96dp progress ring around a `timer`-scale number.
- Final 10 seconds: subtle ring-thickness pulse (no color change — avoids signaling tension).

### 5.5 `SuspicionNote`

- Single text field, max 40 characters, with counter.
- 6 quick-suggestion chips: "nervous", "too quiet", "defending someone", "suspicious reaction", "eye contact", "gut feeling".
- "Skip" and "Confirm" buttons have identical size and position (prevents timing analysis).

### 5.6 Other Components

| Component | Description |
|---|---|
| `RoleCard` | Role reveal card — uniform back face, flipped via long-press, dismissed via "Got it" |
| `VoteBar` | Vote results bar in the reveal screen — horizontal bars with names and counts |
| `PhaseBanner` | Phase label at top of screen ("Night 1" / "Day 2") in `caption` |
| `AchievementBadge` | 64dp circular achievement badge with gold ring — post-game only |
| `TimelineRow` | Analytics timeline row: icon + event + detail |

---

## 6. Iconography

- Library: **Phosphor Icons** (Regular weight for default, Fill for active state).
- Standard size: 24dp; primary actions: 28dp.
- Forbidden: cartoon icons, emoji inside gameplay UI.
- Role icons (reveal & analytics only): mask (Mafia), minimal medical cross (Doctor), magnifier (Detective), person (Citizen).

---

## 7. Motion

| Token | Duration | Easing | Usage |
|---|---|---|---|
| `motion-instant` | 100ms | linear | Button state changes |
| `motion-quick` | 200ms | ease-out | Element entrance, selection |
| `motion-standard` | 300ms | ease-in-out | Screen transitions |
| `motion-dramatic` | 600ms | ease-in-out | Role card flip, elimination reveal |

**Hard rules:**

1. **Uniform night transitions:** every player goes through identical transitions with identical durations — timing differences are leaks.
2. No confetti or celebratory haptics during gameplay — celebration is confined to the final result screen.
3. Haptics: light impact on select and confirm only — identical pattern for every role.
4. Respect the OS "Reduce Motion" setting.

---

## 8. Audio Direction

| Event | Sound design |
|---|---|
| "Night falls..." | Deep calm narrator + faint ambient layer (wind / night silence) |
| "Mafia, open your eyes" | Same narrator — no tension music (no hinting) |
| "Morning has come" | Gradual rise in the ambient layer |
| Speaker turn change | Short neutral chime (< 1s) |
| Timer end | Two ascending tones |
| Elimination reveal | Single deep drum hit |

- Forbidden: cartoon sounds, whistles, laughter.
- All night-phase audio plays from the device **for everyone at the table** — no sound ever plays while an individual player is holding the phone.

---

## 9. Accessibility

- Primary text contrast on background: ≥ 7:1; secondary: ≥ 4.5:1.
- All touch targets ≥ 48×48dp.
- Dynamic Type support up to 130% without layout breakage.
- States never rely on color alone (border + icon + text).

---

## 10. Flutter Binding (Material 3)

```dart
// Proposed tokens as a ThemeExtension
class MafiaColors extends ThemeExtension<MafiaColors> {
  final Color surfaceBase;    // #0D0F14
  final Color surfaceRaised;  // #161A22
  final Color accentGold;     // #C9A227
  final Color accentCrimson;  // #8E2A35
  // ...
}
```

- Custom `ColorScheme.dark` with the values above (never Material defaults).
- Fonts via `google_fonts`: Cairo + IBM Plex Sans Arabic.
- All values above are defined as Design Tokens in a single `design_tokens.dart` — hardcoded values in screens are forbidden.
