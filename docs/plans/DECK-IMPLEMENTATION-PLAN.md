# Deck redesign — implementation plan (2026-10-09)

Source of truth for every screen: `docs/design/DECK-SYSTEM.md` §10 and the HTML mockups in `build/` (untracked; regenerate from the scratchpad generators if missing).
Nothing in this plan starts until the owner says «ابدأ التنفيذ». Nothing is built (web/APK) or deployed until the owner says so separately.

## How it runs

- **Executor: Sonnet 5.5, effort medium** (owner, 2026-10-09: save tokens). One phase per session or per subagent call (`model: sonnet`, `effort: medium`). Opus only reviews the Doc 05-sensitive phases (P5, P6, P9, P12).
- Each phase: read `docs/PROGRESS.md`, then only this phase's section, its mockup, and the files it lists. Follow CLAUDE.md (tokens only, Arabic 1.6/0 letter-spacing, motion = transform/opacity over RepaintBoundary, reduced motion jumps to end).
- **Every phase starts with a review-and-polish step**: open the mockup next to the current Flutter screen, list what differs, then fix spacing, motion, empty/error states and short-phone fit (360×640) as part of the phase, not later.
- Gate per phase: `flutter analyze 2>&1 | tail -30` clean, targeted `flutter test` green, one downscaled screenshot (identity_screenshots golden or emulator), PROGRESS block appended. Stop and wait.
- Offline and online **match** screens and rules stay as they are. Enabling an owned role or tool inside a match uses the existing engine paths only.

## P0 — Final polish of the mockups (HTML only, owner sign-off)
- Bots sheet: centre the art. Stories: the small details listed in the session. Players (option 1): long-press lifts a card, drag to another seat, the others slide aside; tap ✕ removes with a fly-out.
- Output: updated `build/*.html`, owner says «تمام» → P1.

## P1 — Art intake (Codex art-v4)
- Brief: scratchpad `art4.txt` (24 Mafia player avatars, gallery portraits + matching card faces for silencer/elder/sniper, empty seat card). Mafia identity only — never story busts.
- Owner picks from `_contact_*.jpg`. Then `tool/normalise_art.py` (card faces only it writes), WebP for the rest under `assets/images/players/` and `assets/images/gallery/`, regenerate `lib/app/asset_constants.dart`.
- Fix `result_screen.dart` role→gallery map (silencer/elder/sniper currently borrow mafia/citizen) and `RoleGalleryPortrait.art`.
- Tests: `test/support/artwork.dart` loads every new asset; asset list test.

## P2 — First run
- `first_run_full.html`: 3 steps with dots, avatar cards, one checkbox (cards dim and shake until checked), name on the plate live, «نحفظ لعبك؟» only with a server, Home greets «أهلاً يا <name>» once. Sound/music/motion leave first run.
- Picked avatar (boy/girl now, any of the 24 after P1) saved in the profile.

## P3 — Home sheets: settings and «إزاي نلعب»
- `settings_howto_mockup.html`. Auto-save + «اتحفظ» toast. Booklet pages, flip role cards (all 7 roles), video, FAQ.

## P4 — «هتلعب إيه؟» (done in bf0db87) — polish only.

## P5 — «مين بيلعب؟» (option 1, dealt grid) — Opus review
- `players_4ways.html` v1. Group chips, add row (name + ولد/بنت + «+»), each player a dealt card with avatar (auto-assigned, unique per match, tap to change), name plate, seat number; empty seat card for the next slot.
- **Long-press to lift and drag to reorder** (seat order = circle order in the match); ✕ flies out; «كمّل» disabled below 5 with «لسه N».
- Keep `add_players_screen.dart` keys used by setup_flow/group tests or update the tests in the same phase.

## P6 — «الأدوار» — Opus review
- `players_roles_mockup.html` (bigger spread fan). Presets عادي/صعب/على مزاجك, balance sentence, role rows, citizens computed, «أدوار تانية».
- **Owned roles reach offline**: silencer/elder/sniper rows appear in «أدوار تانية»; locked ones show the lock pill and open the store drawer; owned ones toggle the existing `silencerEnabled/elderEnabled/sniperEnabled` in the match config (`lib/engine/presets.dart`). `balance_guard.dart` decides limits. No rule change.

## P7 — «ضد الكمبيوتر» sheet
- `bots_mockup.html` (art centred). Same owned-role toggles as P6; check `bot_brain.dart` plays each new role (tests: a seeded bot match per role reaches a win).

## P8 — Store «السوق السودة»
- `store_drawers.html`: search, «اللي عندي», «وصل جديد», one drawer per category from a single category list (adding a category = one entry), buy sheet with «عندك»/«اتباع»/«استخدم». Coins only on screen.

## P9 — Everything in the store works everywhere — Opus review
Build a coverage matrix (in PROGRESS) and a test per cell:

| Item | Offline (one phone) | Bots | Online |
|---|---|---|---|
| Roles silencer/elder/sniper | P6 | P7 | live (room settings) |
| 17 table tools | owner decision | owner decision | live |
| Frames | seat card + profile | your seat | seat |
| Narrator packs | narrator voice | narrator voice | narrator voice |
| Room packs | night/day transitions | same | same |
| Coin packs / bundles | wallet only | — | — |

- Every «استخدم» lands the item in the right slot; a bought item shows «عندك» on every surface; nothing owned is ever lost on reinstall (server inventory).
- Doc 05: no item may show on an in-hand screen in a way that differs by role (frames and narrators identical for every seat at night).

## P10 — Result + «ملف الماتش»
- `result_mockup.html`: outcome art, stamp, «كنت …» card with the new gallery portraits, cards flip in turn, coins count up into the pill, casebook progress.

## P11 — Profile and casebook (dark case file)
- `case_file_dark.html`. Profile tabs «شخصياتي · ألقابي · السجل»; avatar change uses the 24-avatar set.

## P12 — Stories (solo + with friends) — Opus review
- `stories_mockup.html`, `stories_group_mockup.html`. Stories keep their own look (story busts, case file); none of it enters Mafia screens. With friends: the private dossier is identical for every seat including the culprit, same hold time.

## P13 — Full check
- `flutter analyze`, full `flutter test`, identity screenshots for every screen at 360×640 and 430×932, Doc 05 audit of P5/P6/P9/P12. Report; wait for the owner before any build.
