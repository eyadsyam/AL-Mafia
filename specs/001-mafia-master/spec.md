# Feature Specification: Mafia Master

**Feature Branch**: `001-mafia-master`

**Created**: 2026-07-25

**Status**: Draft

**Input**: User description: "Mafia Master — an offline, no-moderator companion app that runs a complete game of Mafia on a single shared phone passed around the table, with an absolute zero-information-leakage guarantee. Covers setup, role distribution, night, discussion, voting, result, and post-game analytics."

## Clarifications

### Session 2026-07-25

- Q: When the Mafia's night votes tie, how should the engine resolve it (no extra phone pass allowed)? → A: Uniform random among the tied targets using the engine's seeded RNG — no weighting by vote count or voter order. The tie event, including which Mafia voted for which target, is logged in the match record for post-game analytics only.
- Q: What does the Detective learn on investigation? → A: The exact role, four-valued (Mafia / Doctor / Detective / Citizen); a second Detective resolves as Detective. The result is shown only for the hold duration, has no history screen, is never persisted to a viewable in-match log, and surfaces only in post-game analytics. Because this strengthens town information, the Balance Guard recommends 3 Mafia at 9+ players and warns when two Detectives are configured below 11 players.
- Q: What constraints apply to the Doctor's protection choice? → A: The Doctor may protect anyone including themselves, but may never protect the same player on two consecutive nights (the no-repeat rule is always on, not a toggle).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play a full match end-to-end without a human moderator (Priority: P1)

A group of 5–20 friends sits around one table with a single phone. One person sets up the
match (names in seating order, role counts, timing rules). The phone is then passed around
so each player privately learns their role, plays each night action, participates in timed
discussion, and casts a secret vote — until one side wins. The app narrates phases aloud and
manages all bookkeeping a human "Game Master" would normally do.

**Why this priority**: This is the product. Without a complete, moderator-free match loop
there is no reason for the app to exist. It is the minimum viable slice that delivers value.

**Independent Test**: Set up a 7-player match, run one full night → morning → discussion →
vote → reveal cycle to a win condition, and confirm the app reaches a Result screen with a
correct winner — all without any player needing to know the rules of moderation.

**Acceptance Scenarios**:

1. **Given** 7 players entered in seating order with a balanced role set, **When** the host
   starts the match, **Then** each player is guided through private role reveal via
   pass-the-phone and the app advances to Night 1 once all have seen their role.
2. **Given** it is night, **When** the phone is passed in seating order, **Then** every player
   is shown a private two-step action appropriate to their role and no one else can observe
   which action was taken.
3. **Given** all night actions are submitted, **When** morning begins, **Then** the app
   announces the outcome (a victim name, or that everyone survived) without revealing the
   victim's role.
4. **Given** a discussion and secret vote complete with a clear majority, **When** the vote
   resolves, **Then** the eliminated player's name and role are revealed and a win check runs.
5. **Given** all Mafia are eliminated (or Mafia reach parity with non-Mafia), **When** the win
   check runs, **Then** the match ends on a Result screen naming the winning side.

---

### User Story 2 - Guaranteed secrecy: no player can read another's role from the device (Priority: P1)

Throughout the match, players are watching each other and the shared screen. A player must not
be able to infer anyone else's secret role from anything the device does — how long a screen is
held, what it sounds like, how bright it is, how many taps occur, or any structural difference
between screens.

**Why this priority**: Secrecy is the core promise and the single hardest differentiator. A
leak makes the app strictly worse than the physical game. It is co-P1 with the match loop
because a working match that leaks roles is a failed product.

**Independent Test**: Video-record four players holding different roles through the night phase;
an outside observer, watching only the players and the screen, cannot identify roles better
than chance (acceptance test T1). Golden screenshot comparison of all four role screens shows
pixel-identical structure and dimensions (T3).

**Acceptance Scenarios**:

1. **Given** any two players with different roles, **When** each takes their night turn, **Then**
   the on-screen structure, element positions, tap count, and transition timings are identical.
2. **Given** any night screen, **When** a player attempts to confirm immediately, **Then** the
   confirm action is unavailable until a fixed minimum dwell (8 seconds) has elapsed, identically
   for every role.
3. **Given** a player is holding the phone during the night, **When** they interact with the
   screen, **Then** the device emits no role-distinguishing sound and no role-distinguishing
   haptic; narration only plays while the phone rests on the table.
4. **Given** the Detective learns a result, **When** they finish their turn, **Then** the result
   is shown once and is never stored or retrievable anywhere in the app.
5. **Given** any night screen, **When** its average luminance is measured, **Then** it is within
   ±2% of every other night screen, and no warm/red color appears.

---

### User Story 3 - Safe pass-the-phone handoff and wrong-hands protection (Priority: P1)

Because one device serves everyone, the moment of handing the phone between players is the most
dangerous for leaks and mistakes. Each handoff must clearly tell the group whose turn it is,
prevent the phone from being opened by the wrong person, and expose zero game content if the
wrong person does try.

**Why this priority**: The pass screen is the connective tissue of every private phase (reveal,
night, vote). If it is unsafe, both secrecy (US2) and the match loop (US1) fail.

**Independent Test**: On a handoff to "Ahmed", have a different player attempt to proceed; the
identity gate (deliberate long-press + "Not Ahmed?" escape) prevents any exposure and returns to
a neutral pass screen (acceptance test T6).

**Acceptance Scenarios**:

1. **Given** it is player X's turn, **When** the pass screen shows, **Then** it names X, requires
   a deliberate long-press to proceed, and plays no sound or haptic on open.
2. **Given** the wrong player holds the phone, **When** they select "Not X?", **Then** they can
   re-route to the correct player without any game content being shown.
3. **Given** the app is interrupted mid-night (crash, phone call, force-quit), **When** it
   relaunches, **Then** it resumes on the pass screen for the current player, never on secret
   action content (acceptance test T7).

---

### User Story 4 - Fast, balanced match setup (Priority: P2)

The host needs to go from "let's play" to "everyone has a role" in well under two minutes:
enter 5–20 names quickly in seating order, accept a sensible auto-suggested role balance (or
adjust it with live validation), and choose timing/discussion/tie rules.

**Why this priority**: Setup friction is the main reason group games stall. It is P2 because a
match can be demonstrated with a fixed configuration, but real-world adoption depends on speed.

**Independent Test**: Time a host entering 7 names and starting distribution; completion under
two minutes with a valid, balanced role set and no invalid configuration allowed to start.

**Acceptance Scenarios**:

1. **Given** fewer than 5 players, **When** the host tries to continue, **Then** the app blocks
   it and states the minimum is 5.
2. **Given** a player count, **When** the role screen opens, **Then** a balanced distribution is
   pre-filled and Citizens auto-fill the remainder as other roles change.
3. **Given** the host sets Mafia to at least half the players, **When** they try to start,
   **Then** the app blocks it with an explanation.
4. **Given** valid settings, **When** the host confirms, **Then** chosen timing/discussion/tie
   rules persist as defaults for the next match.

---

### User Story 5 - Post-game intelligence that makes players want a rematch (Priority: P2)

After the match, every meaningful tap becomes a story: a night-by-night timeline, each player's
suspicion accuracy and reasons, a suspicion map of who suspected whom, and earned achievements.
Secret information (who voted for whom, who suspected whom) is revealed only now, never during play.

**Why this priority**: Analytics drive replay and word-of-mouth, but the game is fully playable
without them, so P2.

**Independent Test**: Complete a match, open analytics, and confirm the timeline, per-player
suspicion accuracy, suspicion map, and at least one earned achievement all render from data
captured during play — and that ballot/suspicion details were not visible before match end.

**Acceptance Scenarios**:

1. **Given** a finished match, **When** the host opens analytics, **Then** a night-by-night
   timeline shows kills, saves, investigations, suspicions, and eliminations.
2. **Given** the timeline, **When** viewing a day's elimination, **Then** who-voted-for-whom is
   revealed (and was hidden during play).
3. **Given** a player's card, **When** viewed, **Then** it shows their suspicion accuracy with
   the reasons they recorded each night.

---

### User Story 6 - Resume and history across matches (Priority: P3)

An unfinished match can be resumed after the app is closed, and finished matches are stored
locally so the group can revisit past analytics.

**Why this priority**: Convenience and retention; not required to play a single session, so P3.

**Independent Test**: Start a match, close the app mid-match, reopen and resume from the correct
step; finish a match and confirm it appears in history with a re-openable analytics view.

**Acceptance Scenarios**:

1. **Given** an unfinished match, **When** the app is reopened, **Then** the host is offered
   Resume or End.
2. **Given** finished matches, **When** History is opened, **Then** each match lists players,
   winner, and night count, and opens its full analytics.

---

### Edge Cases

- **Wrong player opens the phone**: identity gate blocks it; "Not X?" returns to a neutral pass
  screen exposing zero content.
- **Player quits mid-match**: host removes them from the management menu; treated as a neutral
  elimination and an immediate win check runs.
- **Mafia vote tie at night**: resolved automatically by the configured rule (never by an extra
  phone pass, which would leak the Mafia count).
- **Day-vote tie**: tied players get a short defense, then a revote among only those players.
- **Doctor saves the target**: morning announces "someone was attacked but survived" with no name
  (protects the Doctor's pattern).
- **Fewer than viable players remain**: win check ends the match immediately when a side has won.
- **Reduce Motion enabled at OS level**: dramatic animations are shortened/removed without
  changing structure or timing parity.
- **Dead players**: excluded from every subsequent flow entirely (no fake passes, no partial
  stats during play).
- **Duplicate names entered**: automatically disambiguated (e.g. "Ahmed 2").

## Requirements *(mandatory)*

### Functional Requirements

**Setup & configuration**

- **FR-001**: System MUST let the host enter 5–20 player names, ordered to match physical seating.
- **FR-002**: System MUST block starting a match with fewer than 5 players and explain the minimum.
- **FR-003**: System MUST auto-suggest a balanced role distribution for the entered player count and
  auto-compute Citizens as the remainder as other roles change.
- **FR-004**: System MUST enforce role validity: at least 1 Mafia, Mafia strictly fewer than half of
  players, and total roles equal to player count; invalid sets MUST NOT be startable. The Balance Guard
  MUST recommend 3 Mafia at 9 or more players and MUST warn (non-blocking) when two Detectives are
  configured with fewer than 11 players.
- **FR-005**: System MUST let the host choose speech time, discussion mode (structured/free), vote-tie
  rule, and narration on/off, and MUST persist these as defaults for future matches.
- **FR-006**: System MUST disambiguate duplicate names automatically.

**Role distribution**

- **FR-007**: System MUST reveal each player's role privately via pass-the-phone, with an identity
  gate and a face-down card the player flips deliberately.
- **FR-008**: System MUST show teammates' names on the card for players who share a team (Mafia).
- **FR-009**: System MUST make role reveal identical in structure, tap count, and available-timing
  across all roles (the dismiss control appears after a fixed delay regardless of role).

**Night phase**

- **FR-010**: System MUST pass the phone in seating order to every living player each night,
  regardless of whether their role has a "special" action.
- **FR-011**: System MUST present exactly two steps per role each night (selection + a second step),
  with identical structure and element positions across all roles.
- **FR-012**: System MUST offer the correct action per role: Mafia pick an elimination target (seeing
  teammates' current votes); Doctor pick someone to protect — self-protection allowed, but never the
  same player on two consecutive nights (no-repeat always enforced); Detective investigate a player and
  see a one-time four-valued exact-role result (Mafia / Doctor / Detective / Citizen, with a second
  Detective resolving as Detective); Citizen record a suspicion with an optional short reason.
- **FR-013**: System MUST resolve Mafia vote ties automatically by uniform random selection among the
  tied targets using a seeded RNG (no weighting by vote count or voter order), without any additional
  phone pass, and MUST log the tie and each Mafia's vote to the match record for post-game analytics only.
- **FR-014**: System MUST resolve the night internally (Mafia target minus Doctor protection) and NOT
  reveal the victim's role in the morning.
- **FR-015**: System MUST announce morning outcomes: a victim name, a saved-but-unnamed attack, or that
  everyone survived.

**Discussion & voting**

- **FR-016**: System MUST run discussion as a table-centered timer/bell: structured mode with speaking
  turns and per-turn timers, or a single free-discussion timer.
- **FR-017**: System MUST exclude dead players from speaking order and all subsequent flows.
- **FR-018**: System MUST collect votes secretly via pass-the-phone among living players only, prevent
  self-votes, and offer abstain only when enabled.
- **FR-019**: System MUST show vote tallies and dramatically reveal the eliminated player and their role,
  without showing who-voted-for-whom during play.
- **FR-020**: System MUST resolve day-vote ties via short defense then a revote among tied players only.

**Win & result**

- **FR-021**: System MUST run a win check after every elimination (night or day): Citizens win when no
  Mafia remain; Mafia win when Mafia are ≥ the remaining non-Mafia; otherwise continue.
- **FR-022**: System MUST present a cinematic Result screen naming the winning side and a full role reveal
  with when each player left the game.

**Zero-leakage guarantees (cross-cutting, binding)**

- **FR-023**: System MUST render every role from a single layout structure; role differences MAY change
  text/data only, never structure, dimensions, or presence of elements.
- **FR-024**: System MUST enforce an 8-second minimum dwell before night confirmation and fixed minimum
  durations for second/terminal screens, identically for all roles.
- **FR-025**: System MUST keep all night screens within ±2% average luminance of one another and MUST NOT
  use warm/red colors at night.
- **FR-026**: System MUST emit no role-distinguishing sound or haptic while a player holds the phone, and
  MUST play narration only while the phone is on the table.
- **FR-027**: System MUST disable in-night back navigation; the only exit is an explicit "End match".
- **FR-028**: System MUST never store or re-display secret action results (e.g. the Detective's finding)
  after the turn ends.

**Persistence, resume, analytics**

- **FR-029**: System MUST operate fully offline with no network access and no telemetry.
- **FR-030**: System MUST persist full match state locally after each confirmed step and resume an
  interrupted match on the current player's pass screen, never on secret content.
- **FR-031**: System MUST capture, during play, the data needed for post-game analytics (kills, saves,
  investigations with their four-valued results, Mafia vote breakdowns including tie events, suspicions
  with reasons, questions asked, votes cast) without exposing any of it during play.
- **FR-032**: System MUST present post-game analytics: night-by-night timeline, per-player suspicion
  accuracy with reasons, a suspicion map, and achievements; and reveal ballots/suspicions only here.
- **FR-033**: System MUST store finished matches in a local history that reopens their full analytics and
  supports deletion with confirmation.

**Platform & accessibility**

- **FR-034**: System MUST support Arabic and English with an RTL-first layout and full LTR support.
- **FR-035**: System MUST meet contrast (primary ≥ 7:1, secondary ≥ 4.5:1), touch-target (≥ 48×48dp), and
  Dynamic-Type-to-130% requirements, and MUST NOT convey state by color alone — without any accessibility
  affordance leaking role information.
- **FR-036**: System MUST respect the OS "Reduce Motion" setting without breaking structural/timing parity.

### Key Entities *(include if feature involves data)*

- **Match**: one game session — its players, chosen rules, phase progression, and outcome; the unit stored
  in history.
- **Player**: a named participant with a seating position, a secret role, and alive/dead status.
- **Role**: Mafia, Doctor, Detective, or Citizen — each defining a night action and a win alignment.
- **Night Action**: a player's per-night decision (target/protect/investigate/suspicion) with any reason,
  captured for resolution and later analytics but never re-exposed during play.
- **Vote**: a per-player secret day ballot, revealed only in post-game analytics.
- **Suspicion Note**: a Citizen's recorded suspect plus optional reason, scored for accuracy post-game.
- **Timeline Event**: a recorded moment (kill, save, investigation, elimination, removal) for the analytics
  timeline.
- **Achievement**: a post-game recognition earned from captured play data.
- **Match Settings**: speech time, discussion mode, tie rule, narration — persisted as defaults.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A host can go from opening the app to all players knowing their roles in under 2 minutes for
  a 7-player match.
- **SC-002**: A group can complete a full match to a correct win result using only the app, with no player
  acting as moderator.
- **SC-003**: In blind observation of the night phase, outside observers identify players' roles no better
  than chance (≤ 25% for four roles).
- **SC-004**: Across 20 simulated night runs, per-role screen time shows no structural gap beyond normal
  user-behavior variance. *(Satisfied by construction: the 8-second dwell floor and token-identical
  transitions (invariants L-07/L-09) make all remaining screen-time variance purely behavioral;
  empirical confirmation is a manual QA measurement, not automated.)*
- **SC-005**: Every night and voting screen renders pixel-identical structure and dimensions across all
  four roles in automated golden comparison.
- **SC-006**: Average luminance across all night screens deviates by at most ±2%.
- **SC-007**: No role-distinguishing sound or haptic occurs on any night path while a player holds the phone.
- **SC-008**: Force-quitting mid-night and relaunching always resumes on the correct pass screen and never
  exposes secret action content.
- **SC-009**: The Detective's result cannot be retrieved anywhere in the app after the turn ends.
- **SC-010**: Post-game analytics correctly reflect 100% of the suspicions, votes, and night actions
  captured during play, with none of that detail visible before match end.
- **SC-011**: The app functions with device networking fully disabled, with no failed network attempts.

## Assumptions

- The group shares a single phone; multi-device play is out of scope for the MVP.
- Dark theme only in the MVP; a light theme is deferred.
- The four roles (Mafia, Doctor, Detective, Citizen) constitute the MVP role set; additional roles are a
  future extension.
- The night victim's role stays hidden by default (revealed only on day-vote elimination), with a possible
  future settings toggle.
- Voting is secret by default; public hand-raising is a future option.
- "Share summary" image export and cross-match streak achievements are out of scope for the MVP.
- Local persistence is sufficient; no cloud sync, account, or login is required.
- Players are adults comfortable with a dim, cinematic, text-forward interface in Arabic or English.
