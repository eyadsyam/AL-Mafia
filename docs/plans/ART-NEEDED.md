# Art needed for 1.1

These are screens that ship today with a placeholder, a stand-in Material icon, or
no picture at all. Each image is to be made by an image model and dropped in at the
path given. The code already falls back safely until the file exists. Where a path
is new, a one-line code change is also needed, noted in "Wire".

## House style (applies to every item)

- **Look:** 1940s Cairo film noir. Near-black grounds (#0B0B0D to #1F1F23), warm
  candle or lamp light, and a single brass/gold accent close to **#C2AF81**.
  Surfaces are aged paper, felt and worn brass, with soft film grain.
- **Illustration:** painted, not photographic, and not cartoon or flat vector. It
  should match the existing card faces (`assets/images/card_face_*.webp`) and the
  Council art (`assets/images/council/`).
- **No text in any image.** All words are drawn in-app in Arabic or English.
- **Doc 05:** nothing shown during a match may hint at a role. Anything that could
  appear at the table must be neutral: no knives, no badges, no red crosses.
- **Transparent means** a real alpha channel (WebP with alpha) and a soft edge with
  no halo. Leave about 8% padding inside the canvas.
- **Format:** WebP, quality about 85. A transparent file stays transparent; a full
  ground is RGB.

## The list

| # | File to create | Size | Transparent | What it shows | Where it appears, and Wire |
|---|---|---|---|---|---|
| 1 | `assets/images/store_v2/frame_invite.webp` | 768×768 | yes | The «كبير الشلة» invite frame as a product. It is an ornate round brass frame with a moonlit silver inner ring, and small linked hands or interlocking rings worked into the brass. The centre is empty and dark. | The collection and the purchase reveal, where it is currently a generic icon. Wire: add `'frame_invite'` to `StoreArt.codes` in `lib/ui/economy/store_art.dart`. |
| 2 | `assets/images/store_v2/narrator_mark_storyteller.webp` | 96×96 | yes | An emblem of a small open book with a brass clasp and a faint glow. | The storyteller narrator's marker on every public caption, where it is currently a Material book glyph. Wire: `NarratorLook.marker` in `lib/ui/economy/cosmetics.dart` would take an asset instead of `IconData`. |
| 3 | `assets/images/store_v2/narrator_mark_keeper.webp` | 96×96 | yes | An emblem of an old iron archive key on a brass ring. | The same place, for the keeper narrator (currently a key glyph). |
| 4 | `assets/images/store_v2/narrator_mark_noir.webp` | 96×96 | yes | An emblem of a crescent moon behind thin smoke, silver on gold. | The same place, for the noir narrator (currently a moon glyph). |
| 5 | `assets/images/titles/title_seal_season_zero_night_scribe.webp` | 160×160 | yes | A wax seal in deep burgundy stamped with a quill crossing a crescent moon. | The title rows in Profile, the account sheet and the Casebook header (`TODO(art)` in `lib/ui/social/titles_partner.dart`). Wire: `TitleEquipList` row leading image. |
| 6 | `assets/images/titles/title_seal_season_zero_casekeeper.webp` | 160×160 | yes | The same wax seal family, in dark green, stamped with a tied case folder. | The same place. |
| 7 | `assets/images/titles/title_seal_kabir_elshella.webp` | 160×160 | yes | The same seal family, in gold wax, stamped with three linked rings. | The same place. It is earned by 3 settled invites. |
| 8 | `assets/images/social/invite_empty.webp` | 480×320 | yes | An empty café table with two cups, an unoccupied chair and a door ajar with warm light behind it. It should read as "invite someone". | The «ادعي صحابك» sheet when a tab has no rows (no friends yet, no search hits, nobody nearby). It is currently text only. Wire: the three empty states in `lib/ui/screens/online/invite_sheet.dart`. |
| 9 | `assets/images/social/invite_knock.webp` | 256×256 | yes | A gloved hand knocking on a dark wooden door with a brass knocker, and a sliver of light at the frame. | The incoming-invite popup (`lib/ui/social/incoming_invite.dart`), shown behind or beside the inviter's framed face. Optional; today the popup shows the face alone. |
| 10 | `assets/images/launch/event_stamp.webp` | 320×320 | yes | A round rubber-stamp impression in brass-gold ink on transparent. It is a ring border with an empty centre, because the event name is drawn in-app. | The result screen's launch-event stamp (`TODO(art)` in `lib/ui/fun/launch_events.dart`). |
| 11 | `assets/images/economy_v2/ticket_strip.webp` | 1080×200 | yes | A torn paper ticket stub in dark cream with perforated edges and a faint gold border, empty inside. | The pass-and-play result's "still waiting today" strip (`TODO(art)` in `lib/ui/economy/pass_result_inventory.dart`). |
| 12 | `assets/images/council/invite_notice_first_match.webp` | 96×96 | yes | A small brass coin stack with a ribbon. | The invite notices in the Council tab, «صاحبك خلّص أول ماتش» (`TODO(art)` in `lib/ui/economy/council_hub.dart`). |
| 13 | `assets/images/council/invite_notice_progress.webp` | 96×96 | yes | A small brass step counter, three notches with one lit. | The same list, for the progress lines. |
| 14 | `assets/images/council/invite_notice_settled.webp` | 96×96 | yes | A small sealed envelope with a gold wax seal. | The same list, for the settled lines. |
| 15 | `assets/images/casebook/season_zero_cover.webp` | 1080×420 | no | A season cover: an evidence board lit by one desk lamp, with pinned photographs whose faces are hidden, red string, and an open case file. It should be moodier than the generic header. | The Casebook header while Season Zero runs. Today it reuses the generic `online/casebook_header.webp`. Wire: `CasebookSheet` picks the cover by season code, falling back to the generic header. |
| 16 | `android/app/src/main/res/drawable-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_stat_mafia.png` | 24, 36, 48, 72, 96 px | yes, **pure white on transparent** | The game's fedora hat silhouette as a flat single-colour shape. Android tints it, so it must have no gradients. | The small icon of every invite and friend notification. It is currently a simple vector (`drawable/ic_stat_mafia.xml`). If PNGs are added, delete the XML so there is one source. |
| 17 | `web/icons/badge-72.png` | 72×72 | yes, **pure white on transparent** | The same fedora silhouette. | The badge of web push notifications on Android Chrome. It is currently a quick stand-in. |

## Already fine (checked, no new art needed)

- The Thursday banner (`launch/thursday_banner.webp`), leaderboard header,
  podiums, rank tiers and contract icons (`council/`).
- The daily coffer and wheel (`economy_v2/`), store covers (`store_v2/`, `store_v3/`)
  and the Casebook generic header.
- The Partner picker now shows the Four Dossiers' own gallery portraits
  (`assets/images/gallery/gallery_*.webp`) instead of plain chips.

## Added 1.1 final

All 17 requested assets are present at the specified paths. The 15 WebP files have the expected dimensions and alpha channels; the Android density icons and web badge are present. Foreground and FCM notification paths use the new icons.

Screen audit: Home uses its painted background; setup has card art; table phases have neutral furniture; results use the event stamp and ticket; store uses the invite frame and narrator marks; Council uses all three notice emblems; Casebook selects the Season Zero cover; invites have empty and incoming art. Remaining small icons are action controls. Onboarding is being changed in another worktree and needs a visual recheck after merge. No additional illustration slot was found in this worktree.
