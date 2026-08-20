# Mafia Master — User Flows

> All diagrams are Mermaid — renderable in any Markdown viewer (VS Code, GitHub, Obsidian).

---

## 1. Match Lifecycle (Top-Level Flow)

```mermaid
flowchart TD
    A[Home screen] --> B[New match setup]
    B --> C[Enter player names]
    C --> D[Configure roles & rules]
    D --> E[Role distribution<br/>pass-the-phone]
    E --> F[Night 1]
    F --> G[Morning announcement<br/>+ night outcome]
    G --> H{Win condition check}
    H -- continue --> I[Discussion phase]
    I --> J[Voting phase]
    J --> K[Reveal eliminated player + role]
    K --> L{Win condition check}
    L -- continue --> F
    L -- game over --> M[Result screen]
    H -- game over --> M
    M --> N[Post-game analytics]
    N --> O{Play again?}
    O -- same group --> D
    O -- exit --> A
```

---

## 2. Setup Flow

```mermaid
flowchart TD
    A[New match] --> B[Add players]
    B --> B1{Player count >= 5?}
    B1 -- no --> B2[Warning: minimum is 5]
    B2 --> B
    B1 -- yes --> C[Role configuration]
    C --> C1[Auto-suggestion by count<br/>e.g. 7 players = 2 Mafia + Doctor + Detective + 3 Citizens]
    C1 --> C2{Manual adjustment?}
    C2 -- yes --> C3[Steppers per role<br/>with live balance validation]
    C3 --> D
    C2 -- no --> D[Match settings]
    D --> D1[Speech time: 45/60/90s]
    D1 --> D2[Discussion mode: structured / free]
    D2 --> D3[Vote tie rule: revote / no elimination]
    D3 --> E[Final review]
    E --> F[Start role distribution]
```

**Validation rules:**

| Rule | Behavior |
|---|---|
| Mafia ≥ 1 | Mandatory |
| Mafia < half of players | Block save + message |
| Doctor/Detective: 0 or more | Allowed, warning shown at 0 |
| Sum of roles = player count | Auto-balanced (Citizens = remainder) |

---

## 3. Role Distribution Flow

> **Principle:** every player goes through identical steps with the exact same number of taps.

```mermaid
flowchart TD
    A[Screen: Pass the phone to Ahmed] --> B[Ahmed taps: I am Ahmed]
    B --> C[600ms long-press confirmation]
    C --> D[Face-down role card<br/>uniform back face]
    D --> E[Long-press to flip]
    E --> F[Role + one-line description<br/>player controls duration]
    F --> G[Button: Got it — long-press]
    G --> H[Immediate blackout screen]
    H --> I{Last player?}
    I -- no --> J[Pass to next player]
    J --> B
    I -- yes --> K[Everyone is ready<br/>Button: Start Night 1]
```

**Anti-leakage notes:** card flip requires long-press (cannot be opened accidentally in view of others); the "Got it" button appears after a fixed 2-second delay for all roles (no timing difference between reading "Citizen" vs "Mafia").

---

## 4. Night Phase Flow — the critical one

> Internal resolution order is fixed (Mafia → Doctor → Detective), but **the phone is passed in seating order** — every player uses the phone every night regardless of role.

```mermaid
flowchart TD
    A[Announcement: Night falls<br/>narrator audio] --> B[Phone passed in seating order]
    B --> C[Pass screen: pass to X]
    C --> D[Identity confirmation via long-press]
    D --> E[Night action screen<br/>identical structure for everyone]
    E --> E1{Role? — internal only}
    E1 -- Mafia --> F1[Pick elimination target<br/>+ other Mafia's vote indicator]
    E1 -- Doctor --> F2[Pick a player to protect]
    E1 -- Detective --> F3[Pick a player to investigate<br/>result shows, then vanishes after confirm]
    E1 -- Citizen --> F4[Pick who you suspect<br/>+ optional note <= 40 chars]
    F1 --> G[Uniform confirmation screen]
    F2 --> G
    F3 --> G
    F4 --> G
    G --> H[Blackout + pass to next]
    H --> I{Everyone done?}
    I -- no --> C
    I -- yes --> J[Resolve internally<br/>Mafia vote minus Doctor protection]
    J --> K[Announcement: Morning has come]
```

### 4.1 Collaborative Mafia Voting

```mermaid
flowchart TD
    A[Mafia 1: picks a target] --> B[Mafia 2: sees Mafia 1's pick<br/>as a subtle indicator on the tile]
    B --> C{Agrees?}
    C -- yes --> D[Confirms same target]
    C -- no --> E[Picks a different target]
    D --> F[Mafia 3+: sees current vote state]
    E --> F
    F --> G{Tie after the last Mafia?}
    G -- no --> H[Target = most votes]
    G -- yes --> I[Resolved by configured tie rule<br/>default: auto-resolution — see note]
```

> **Design note:** a tie-revote CANNOT require an extra phone pass (instant leak of Mafia count!). Resolution: on tie, resolve automatically per the pre-configured rule (last Mafia's pick wins, or random among tied targets). A true "revote" is only possible if the night mode supports a silent second round for ALL players. Final ruling belongs in the rules document.

---

## 5. Discussion Phase Flow (Structured Mode)

```mermaid
flowchart TD
    A[Morning has come<br/>+ victim announcement or survival] --> B[Round 1: open statements]
    B --> B1[Every living player speaks in turn<br/>45-60s timer + turn chime]
    B1 --> C[Round 2: questions]
    C --> C1[Each player asks ONE question<br/>to ONE player — 30s answer]
    C1 --> D[Round 3: defense]
    D --> D1[Top accused players speak<br/>60s each]
    D1 --> E[Proceed to voting]
```

- The phone lies in the center of the table during discussion — it acts only as timer and bell.
- "Free mode": one global discussion timer, no speaking turns.

---

## 6. Voting & Elimination Flow

```mermaid
flowchart TD
    A[Start voting] --> B[Pass phone in seating order<br/>living players only]
    B --> C[Vote screen: pick a player<br/>or abstain — if rule enabled]
    C --> D[Confirm via long-press]
    D --> E{Everyone voted?}
    E -- no --> B
    E -- yes --> F[Results screen on the table]
    F --> G{Tie?}
    G -- yes --> H[30s defense for tied players<br/>then revote among them only]
    H --> B
    G -- no --> I[Dramatic reveal: eliminated name]
    I --> J[Card flip: role reveal]
    J --> K[Win condition check]
```

---

## 7. Win Check & Result Flow

```mermaid
flowchart TD
    A[After every elimination<br/>night or day] --> B{Living Mafia count}
    B -- "= 0" --> C[Citizens win]
    B -- ">= remaining non-Mafia" --> D[Mafia wins]
    B -- otherwise --> E[Match continues]
    C --> F[Cinematic result screen]
    D --> F
    F --> G[Full role reveal]
    G --> H[Post-game analytics]
```

---

## 8. Post-Game Intelligence Flow

```mermaid
flowchart TD
    A[Result screen] --> B[Match summary<br/>winners + duration + night count]
    B --> C[Full timeline<br/>night by night: kills, saves, investigations, suspicions]
    C --> D[Per-player suspicion log<br/>suspect + reason + was it correct?]
    D --> E[Prediction accuracy per player]
    E --> F[Achievements<br/>Most Accurate Citizen, Best Detective, Most Dangerous Mafia...]
    F --> G{Share / replay?}
    G -- replay same group --> H[Back to configuration]
    G -- exit --> I[Home screen]
```

---

## 9. Edge Flows

| Case | Flow |
|---|---|
| Player opens someone else's screen | Long-press identity gate blocks it; "I'm not {name}" returns to pass screen without revealing anything |
| App killed / crash | Full match state restore from local storage (Isar) to the last confirmed step |
| Player quits mid-match | From pause menu: "Remove player" → treated as neutral elimination + immediate win check |
| Back button during night | Dialog: "End match?" — never navigates back inside the night |
| Phone call during night | State saved instantly; on return, the pass screen for the same player is shown (never the action content) |
