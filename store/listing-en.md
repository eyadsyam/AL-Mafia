# Store listing — English

> Secondary locale on Google Play. Arabic is the default; see `listing-ar.md`.

---

## App name (30 characters max)

```
Mafia Master
```

*12 characters.*

---

## Short description (80 characters max)

```
The app runs the night. You finally get to play instead of dealing the cards.
```

*76 characters.*

### Alternatives, if you want to test another

```
The app is the Game Master. You get to be a player for once.
```
*59 characters.*

```
Mafia on one phone. No cards, no setup, and nobody sits the game out.
```
*68 characters.*

---

## Full description (4000 characters max)

```
Every group that plays Mafia has one person who loses every single time: the
one running it.

They deal the cards. They know everything. They sit in silence while everyone
else argues and laughs and accuses each other. They never get to play.

Mafia Master takes that job off them.

The app deals, the app remembers, and the app tells the table each morning what
happened in the night — and you get to be a player like everybody else.

■ One phone is enough

No cards, no setup, and nobody sitting the game out. One phone goes round the
table. Each person takes it, sees their own role, makes their move, and passes
it on.

The whole thing is built on one rule: you cannot work out anybody's role from
the shape of their screen. Every screen has the same dimensions, the same
timings, and emits the same amount of light — whether you are the Mafia, the
Doctor, the Detective or a Citizen. Even how long you hold the phone is the
same for everyone, so the person beside you learns nothing from how fast you
were.

■ The morning is not just a name

Most Mafia apps tell you "so-and-so is dead" and stop there.

Here, the morning has something to say.

From what actually happened in the night, the app builds one true sentence —
something small that was said, or seen, or noticed — without giving anyone
away. Real information, not a guess and not flavour text. And when nothing
worth saying happened, the app says nothing. It never invents.

■ The quiet night, and the one bullet

Once per match, the Mafia may choose to kill nobody — and in the morning
nobody can tell whether that was them or the Doctor making a save.

Once per match, the Doctor may protect themselves.

Once each, for the whole game. Deciding when is the game.

■ Online, with your friends

Everyone on their own phone, with voice inside the app.
A six-character room code, and nobody has to make an account or type an email.
Five to ten players.

And a player who is eliminated does not leave the table — they watch, they
predict, and they can talk to the other eliminated players.

■ Your privacy is not the product

No account, no email, no phone number.
No ads, no tracking, no analytics.
Pass-the-phone play sends nothing off your device at all.
Online play: the room and everything in it deletes itself within 24 hours.

■ Arabic first, by design

The app was written in Arabic, not translated into it. Direction, typography,
spacing and the words themselves are set for an Arabic reader. English is there
if you prefer it.

■ Who it is for

Five to fifteen players on one phone.
Five to ten online.
Dinners, road trips, cafés, and any gathering with people in it that might run
long.

—

If you are the one who always ends up running the game: your turn.
```

*About 2,300 characters.*

---

## What's new (500 characters max) — for 1.0.0

```
First release.

• Pass-the-phone play, 5 to 15 players
• Online play, 5 to 10 players, with in-app voice
• Mornings that say something: the app draws one true fact out of last night instead of only naming the dead
• The quiet night for the Mafia, self-protection for the Doctor — once per match each
• Arabic first, with no accounts, no ads and no tracking
```

---

## Declared content rating

**PEGI 12 / ESRB Teen — suitable for ages 12 and over.**

The reason is **not** depicted content. There is no depicted violence, no
blood, no distressing imagery — the game is cards and text.

The reason is **user interaction**: online mode carries live voice and text
chat between players, which we neither read nor filter. That alone keeps the
app out of Google Play's *Designed for Families* programme and requires
"Users Interact" to be declared in the rating questionnaire.

### Google Play content questionnaire

| Question | Answer |
|---|---|
| Violence | No — elimination is a line of text and a turned card |
| Sexual content | No |
| Profanity | None in the app's own text; **possible** in user chat |
| Drugs / alcohol / tobacco | No |
| Gambling, real or simulated | No |
| Users interact | **Yes** — live voice and text between players, online mode |
| Shares location | No |
| Shares personal information | No |
| In-app purchases | No |
| Ads | No |

---

## Category and tags

- **Category:** Games → Puzzle
  (Games → Board is a defensible alternative.)
- **Tags:** party game, social deduction, pass and play, local multiplayer,
  online multiplayer

---

## Data safety form — the answers, and where each one is verified

| Play's question | Answer | Where it is true in the code |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (online mode only) | `lib/transport/supabase_backend.dart` |
| Location | No | no location permission, no plugin |
| Personal info — name | **Collected, not shared.** The display name typed when joining a room. Not linked to an identity; deleted with the room. | `join_room`, `create_room` |
| Personal info — email, phone, address, IDs | No | anonymous sign-in only, `signInAnonymously()` |
| Financial info | No | no payments |
| Health / fitness | No | — |
| Messages — in-app messages | **Collected, not shared.** Whisper text and eliminated-player messages, stored for the length of the match. | `send_whisper`, `ghost_say` |
| Photos / videos / files / contacts / calendar | No | no permission, no plugin |
| Audio — voice or sound recordings | **Not collected.** Voice is peer-to-peer WebRTC. Nothing is recorded and nothing reaches the server. | `lib/platform/voice/webrtc_voice_engine.dart` |
| App activity — in-app actions | **Collected, not shared.** Votes and night actions, because the server adjudicates. | `submit_vote`, `submit_night_action` |
| App info and performance — crash logs, diagnostics | No | no crash reporter, no analytics SDK |
| Device or other IDs | No | the anonymous user id is issued by us, not read from the device |
| Is all collected data encrypted in transit? | **Yes** — HTTPS/TLS to Supabase, DTLS-SRTP for voice | — |
| Can users request deletion? | **Yes** — leaving a room removes the seat; everything deletes automatically within 24 hours | `purge_finished_rooms()` |
| Is data collection optional? | **Yes** — the entire offline game works with no network at all | mode picker |
