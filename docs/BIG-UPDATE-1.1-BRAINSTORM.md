# The 1.1 "Big Update" — brainstorm (Claude's opening position)

Owner brief (2026-09-28, paraphrased): focus on **online**. Build a huge,
logical, *worth-it* world **outside the match** — a full missions system with
coins and rewards, the way Fortnite/PUBG/Clash Royale/Marvel Snap/Hearthstone
wrap their core loop. Deepen the relationship between the four characters and
the player. Strong, artful design (art melts into screens, no boxed images, no
"tips" clutter), simple for ordinary players. First launch must pre-load
everything so the game is smooth. Nothing ships until the owner says so; this
release must be the biggest, strongest update the game has had.

Constraints that never bend: Doc 05 zero leakage (nothing role-derived visible
or audible while a match is live; mission progress is computed only from
finished rooms with a public outcome, exactly like Council Life); one engine,
two transports; server-authoritative coins (every grant through the wallet
ledger with caps that a config edit cannot loosen); features ship OFF behind
`economy_capabilities`.

## What already exists (build on it, don't duplicate)

Council Life: daily contracts (3 + bonus), weekly contract, Council Rank
(XP → 10 tiers/levels), weekly leaderboard, invites, starter bundle. Economy:
wallet + ledger, daily coffer/wheel/7-day card, rewarded ads (SSV), store
(frames, plates, scene packs, narrators, bundles), Play Billing, web transfers.
Fun: match awards, reactions, founder badge, welcome-back. Characters: Four
Dossiers (local ledger, letters). Online: public rooms, quick match, voice,
whispers, witness (ghosts), safety centre.

## What the best games do outside the match — and what fits a social-deduction party game

| Pattern | Seen in | Fit for us |
|---|---|---|
| Season with a reward track (free + premium) | Fortnite, PUBG, Clash Royale, Snap | **Core.** "الموسم": 6-week seasons, 40 tiers, free track now; premium track later (Play product) |
| Layered missions: daily / weekly / season chapters / lifetime achievements | all of them | **Core.** Replaces "contracts" with one Missions hub; contracts become the daily layer |
| Story chapters unlocked weekly | Fortnite quests, Genshin | **Core, and ours is unique:** each week one character "opens a case" — a mission chain in that character's voice; finishing it opens a special letter + cosmetic |
| Friends, recent players, presence, invite-to-room | every online game | **Core for online.** "أصحابك": recent tables, add friend, see who is online/in a room, one-tap invite |
| Clans | Clash, PUBG | **"العائلة"** (crew of up to 20): shared weekly crew mission, crew tag on profile, crew leaderboard — phase 2 if time |
| Ranked ladder with divisions per season | Snap, Hearthstone, Clash | Risky with a small player base (empty queues). Use **"سمعة"** reputation from public rooms instead; ranked later |
| Rotating events / modifiers | Fortnite LTMs, Hearthstone Tavern Brawl | **"ليالي خاصة"**: server-scheduled weekend events with a twist + event missions (engine modifiers only if already supported by MatchSettings presets) |
| Collection + mastery | Snap collection levels, Brawl Stars mastery | Dossiers + titles + frames; mastery per character from missions |
| Daily shop rotation | Fortnite item shop | "عرض الليلة": 3 rotating cosmetics per day from the existing catalogue |
| Login streak | all | Exists (7-day card); fold into Season XP |
| Achievements with showcase | Steam/Play Games | Lifetime missions with badge showcase on profile |

## Proposed economy loop (must be *worth it*, not grind)

- Sources of **Season XP**: finishing a match (online > pass-and-play, capped
  per day like council XP), winning, daily missions, weekly missions, chapter
  steps. A casual player (3 online matches/day, 4 days/week) should reach tier
  ~30/40 in a 6-week season; a committed player finishes by week 4.
- **Coins** from the track (small, frequent), weekly missions (medium),
  chapter finales (large). Total season faucet sized against the store so a
  free player can afford ~2 premium cosmetics per season. Every grant through
  the existing ledger kinds pattern, idempotent per (user, mission, period).
- **Cosmetic rewards** on the track: frames/plates already in the catalogue;
  new season-exclusive frame at tier 40; titles from chapters.
- Anti-farming: progress only from finished online rooms with ≥ 5 humans and a
  public outcome (reuse council checks); daily caps; pass-and-play counts at a
  reduced rate (one device cannot prove who played).

## Missions design (the core of this update)

Mission = (id, layer, metric, target, reward_coins, reward_xp, period). Metrics
come only from finished public results (same facts Council Life already
reads): `finish`, `win`, `win_town`, `win_mafia`, `survive`, `host`,
`reunion` (play again with someone from a recent table), `public_room`,
`invite_joined`, `vote_correct` (voted for a mafia member — public after
result), `witness_reaction` (sent a reaction as a ghost), `streak_days`.
Never metrics that reward leaking, throwing, or in-match behaviour visible to
others (no "get voted out", no "reveal your role").

Layers: Daily (3, rerollable once via rewarded ad), Weekly (6), Chapter
(weekly character case, 5 steps), Lifetime (achievements, ~40).

## Online-first improvements

Friends/recent tables + presence + invite-to-room; "join friend's room";
public room list with better cards (host, players, language, voice on/off);
post-match "العب تاني مع نفس الترابيزة" rematch for online; reputation
(commendations after a match: «لعب حلو», «محترم») feeding the profile.

## Performance: first-launch preparation

A themed "preparing the table" screen on first launch (and after an update)
that precaches every image/video/audio asset in parallel batches with a real
progress bar, warms the Supabase session + capabilities + edge functions
(cold starts), and on web lets the service worker fill its cache. Later
launches warm in the background without blocking.

## Open questions for the debate

1. Seasons: 6 weeks × 40 tiers — right size for our audience?
2. Premium track now (Play product + web) or next update?
3. Crews now or later?
4. Which of the metrics above are safe under Doc 05, which are not?
5. Split of work between the two agents; what ships behind which flag.

## Already built since this was written (do not re-propose; build on them)
- First-launch preparation (asset read + decode + server warm) — `lib/ui/widgets/warmup_gate.dart`.
- Online table rematch — `rematch_room` + `20260928000200_table_rematch.sql`.
- Friends: recent tablemates, requests, presence, lobby invites — `friends` + `20260928000300_friends.sql`, `lib/ui/social/friends.dart` (flag `friends_enabled`).
- Full accounts: password, Google (linkIdentity for guests), forgot password, remember-me, email code confirmation, profile account card + stats — `lib/transport/account_auth.dart`, `lib/ui/account/*`, `docs/ACCOUNTS-SETUP.md`.
- Owner taste: secondary flows open as bottom sheets; images feathered, never boxed.
