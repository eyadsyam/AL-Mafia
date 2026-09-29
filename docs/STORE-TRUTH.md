# Store truth — every coin item, what it promises, where it works

Audit of 2026-09-29 (branch `cloud/store-truth`). One row per thing sold for
coins (`reward_catalog`, `active and released`). "Before" is what an owner saw
before this branch; "Now" is every place the item has an effect. All
placements are public: `cosmeticsVisibleIn(phase)` online,
`passCosmeticsVisibleIn(phase)` in «القعدة» (the stricter rule: the vote there
is passed hand to hand), never a hand-off, the deal, the reveal or the night
(Doc 05 rule 3). Painting is shared: `CosmeticFramePainter` /
`CosmeticPlatePainter` / `paintCosmeticFrame` / `paintCosmeticPlate` in
`lib/ui/economy/cosmetic_paint.dart`; nothing is forked.

Not sold for coins, and so out of this table: `scenario_shadows` and
`remove_interruptions` (Play entitlements, real money, untouched), the
Starter Bundle frame `frame_council_seal` (Play bundle only; drawn wherever the
frames below are drawn, and revocation is covered by `store_truth.sql`), and
`mastermind_guide` (retired, refunded in `20260924000300`).

## Frames — `frame_gilded` 200, `frame_crimson` 250, `frame_moonlit` 300

| | |
|---|---|
| Store promises | «إطار … تحت صورتك، يشوفه كل اللاعبين» (`cosmeticFrame*Desc`) |
| Before | Online council seats only: `lib/ui/screens/online/council/council_band.dart:833` (lobby and table). Leaderboard sent the frame but the client never drew it. |
| Now | Online seats (unchanged, `council_band.dart:833`, lobby via `lobby_screen.dart:980`); Profile avatar `lib/ui/widgets/profile_identity.dart:60` (from `profile_screen.dart`); account sheet `lib/ui/account/account_sheet.dart:222`; Home chip `lib/ui/screens/setup/home_screen.dart:185`; friends rows (each friend's own frame, server `20260929000600_store_truth.sql` `friends_status`) `lib/ui/social/friends.dart:499`; Council leaderboard rows `lib/ui/economy/council_hub.dart:946`; share card `lib/ui/screens/online/result_share_button.dart:223`; purchase reveal and try-on `lib/ui/economy/purchase_reveal.dart:193` |
| Should show | the buyer's avatar wherever it appears |
| Fix | `CosmeticFrameRing` (shared painter) in every own-identity placement; server adds frame to friends rows. «القعدة» has no avatars on its public screens, so a frame there has nothing to wrap: the host's plate carries their identity (see plates). |

## Nameplates — `plate_noir` 150, `plate_gilded` 250, `plate_ember` 300

| | |
|---|---|
| Store promises | «اسمك على لافتة …» (`cosmeticPlate*Desc`) |
| Before | Online council seats only (`council_band.dart:1004`). |
| Now | Online seats (unchanged); online result roster card `lib/ui/screens/online/council/role_roster.dart:67`; Profile (a live «كده اسمك بيبان» preview under the name field) `profile_identity.dart:95`; account sheet; Home chip; friends rows `friends.dart:509`; leaderboard rows `council_hub.dart:953` (server now sends `plate`); share card; «القعدة» host seat: discussion speaker `lib/ui/screens/day/discussion_screen.dart:284` and pass-and-play result row `lib/ui/screens/postgame/result_screen.dart:322` via `HostIdentityScope` (`lib/ui/economy/pass_table_dress.dart`) |
| Should show | the buyer's name wherever it appears |
| Fix | `CosmeticNameplate` (shared painter). In «القعدة» only the host phone's own name (its profile name) is dressed: the others typed their names on this phone and have no accounts. |

## Presentation packs — `pack_midnight_manor` 600, `pack_old_town` 900, `pack_moonlit_archive` 750

| | |
|---|---|
| Store promises | a hall behind the table, a transition between public phases, an opening and closing line with sound; «بيظهر لكل اللي في الأوضة» |
| Before | Online only: table backdrop `lib/ui/screens/online/table/table_scene.dart:639`, lobby `lobby_screen.dart:409`, transition and lines `room_presentation.dart`. «القعدة» — the owner's most played mode — showed nothing. |
| Now | Online (unchanged); «القعدة»: the host phone's equipped pack dresses every public backdrop (morning, «اسم واحد», confrontation, discussion, vote result, result) through `BackdropDressing` (`lib/ui/widgets/textured_surface.dart`) provided by `PassTableDress` in `lib/ui/screens/match_flow.dart:378`, plus the same transition and opening/closing lines via `RoomPresentationLayer.local` (`match_flow.dart:431`). In-hand surfaces pass no art and are never dressed. |
| Should show | every public phase background, online and «القعدة» |
| Fix | done as above; the same art the online table uses. |

## Narrator packs — `narrator_storyteller` 1200, `narrator_keeper` 1000, `narrator_noir` 1000

| | |
|---|---|
| Store promises | a short written line with a cue at each public phase; keeper/noir say «كلام مكتوب، مش صوت متسجّل» |
| Before | Online captions only, all three drawn in the same neutral box — the packs were only different words. «القعدة»: nothing. |
| Now | Each pack has its own look (`NarratorLook` in `lib/ui/economy/cosmetics.dart`: ground, rule, ink, type and marker glyph — book / key / moon) drawn by `NarrationCaption` (`cosmetic_paint.dart`) online and in «القعدة»; «القعدة» shows it at night-falls (neutral, text only), morning, discussion, the vote announcement and the result (`RoomPresentationLayer.local`, `match_flow.dart:431`). **1.1:** each pack now speaks with its own recorded voice (`assets/voice/narrator_*`, one clip per night/morning/discussion/voting/win): online from the room's narrator pack, in «القعدة» from the host's equipped pack, and in the store preview. A pack with no clip for a beat is silent rather than switching to the default «Kratos» voice mid-match. |
| Should show | every public beat, visibly distinct per pack |
| Fix | done as above. |

## Bundles — `bundle_council` 2300, `bundle_identity` 1200, `bundle_nocturne` 1800

| | |
|---|---|
| Store promises | «… مع بعض» (every listed part) |
| Before | Server granted every part (`buy_reward_item`), idempotent; the collection listed parts as owned. |
| Now | Unchanged server behaviour, now proved by `supabase/tests/store_truth.sql` (a second buy charges nothing, overlapping bundles charge only the missing parts, a part bought after is free, every part has an effect slot); the purchase reveal lists every part as now owned (`purchase_reveal.dart`). |
| Fix | tests + reveal. No bundle is equippable as a whole (refused by `equip_reward_item`). |

## Nothing sold without an effect

`store_truth.sql` walks every active catalogue code and fails if one has no
effect slot (or is a bundle of an item without one). Nothing was flagged for
removal.

## Equip and ownership (server truth)

- `equip_reward_item` refuses an unowned item, a wrong slot and a bundle with
  `ITEM_NOT_OWNED`, an unknown slot with `BAD_REQUEST`; the economy function
  maps both to the literal `fail("BAD_REQUEST", "item cannot be equipped")`.
- Room packs are checked by `ensureCosmeticAccess` in `create_room` and
  `room_settings` (literal `fail("PURCHASE_REQUIRED", "presentation pack is not owned", 403)`).
- A revoked item (the Starter Bundle frame after a refund) leaves the
  equipment through the inventory foreign key; other slots stay; a new seat
  never carries it (`store_truth.sql`).

## The buy → see loop

After a purchase the store shows `PurchaseReveal` (the item on the buyer's own
avatar/name, or the pack/narrator preview, or the bundle's parts) with one tap
to wear it; the collection lists worn items first with «لابسه دلوقتي» and one
line per item saying where it shows (`storeWhatItChanges`), plus «جرّبه»
(`TryOnPreview`) drawn with the same painters. Motion is one finite rise;
reduced motion shows it at rest.

## Placeholder art slots

No image file was added. Two drawn-with-tokens slots stand in for art:

| Slot | Size | What it shows |
|---|---|---|
| Share card identity seal | 132 px circle (`ShareCardTokens.identityAvatar`) | the sharer's initial on a dark seal, inside their frame, name on their plate; wants the player's avatar art composited |
| Narrator markers | 18 px glyph (`StoreTruthTokens.narratorMarker`) | Material glyphs (book, key, moon) standing in for three small drawn narrator emblems |
