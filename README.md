# سيد المافيا — Mafia Master

> A board-game companion that runs a whole match of Mafia: no human moderator, and no hint of who is who.

One phone goes around a table of 6–15 players. The app deals the roles, runs the night in secret, times the day, counts the votes and calls the winner. It is written in Egyptian Arabic and laid out right to left first.

- **Android:** live on Google Play (`com.mafiamaster.mafia_master`)
- **Web:** [saidalmafia.com](https://saidalmafia.com)

## What it does

- **Pass-the-phone matches.** Every player uses the phone the same way every night, with the same two steps, so nobody at the table can work out a role from how long someone held it or how often they tapped.
- **Online rooms.** Play the same match over the network, with voice chat on top. The rules engine is the same one the offline game uses.
- **Stories and cases.** Story-driven cases with suspects, clues and a reveal, read aloud at the table.
- **After the match.** Analytics, match history and a profile (including how accurate your votes were).

## Zero leakage

The one hard rule: during play, the device must give away **nothing** about a player's role. That covers what the screen shows, timing, sound, vibration, and how a screen is laid out. [`docs/specs/05-zero-leakage-spec.md`](docs/specs/05-zero-leakage-spec.md) sets the rule and wins every disagreement.

## Stack

| Layer | Tech |
|---|---|
| App | Flutter, Riverpod, go_router |
| Game engine | Pure Dart in `lib/engine/` (no Flutter, no clock, no unseeded random) |
| Local storage | Isar, shared_preferences |
| Online | Supabase (auth, Postgres, realtime, edge functions) |
| Web hosting | Cloudflare (`wrangler.jsonc`) |

## Project layout

```
lib/
  engine/     rules and match state machine (pure Dart)
  transport/  local and online transports: one engine, two transports
  data/       local stores and codecs
  platform/   ads, billing, push, voice, links (per platform)
  ui/         screens, widgets, theme (design tokens)
  stories/    story and case content
supabase/     migrations, SQL tests, edge functions
test/         unit, widget, golden, leakage and online tests
docs/         specs, plans, setup and the phase log
```

## Running it

```bash
cp dart_defines.example.json dart_defines.json   # fill in your own keys
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

## Checks

```bash
flutter analyze
flutter test
```

## Docs

| File | What it covers |
|---|---|
| [docs/specs/01-design-system.md](docs/specs/01-design-system.md) | Colours, type, spacing, components, motion |
| [docs/specs/02-user-flows.md](docs/specs/02-user-flows.md) | Match lifecycle, night, discussion, voting, win check |
| [docs/specs/03-screens-setup-night.md](docs/specs/03-screens-setup-night.md) · [04](docs/specs/04-screens-day-postgame.md) | Screen specs, setup through the end of the match |
| [docs/specs/05-zero-leakage-spec.md](docs/specs/05-zero-leakage-spec.md) | The binding leakage rules and acceptance tests |
| [docs/specs/10-online-architecture.md](docs/specs/10-online-architecture.md) | Online rooms on one engine |
| [docs/README.md](docs/README.md) | Map of everything else in `docs/` |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Phase log |
