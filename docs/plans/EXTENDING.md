# Adding things later — the checklist (2026-10-09 review)

Each list is every place that must change. Miss one and the feature half-works (the review found two live: roles that could never be dealt online, tools that could never be bought).

## A new bought role (role #8)
- Engine: `lib/engine/models/enums.dart`, `legal_moves.dart`, `match_engine.dart`, `resolver.dart`, `win_check.dart`, `balance_guard.dart`, `bullets.dart`, `bots/bot_brain.dart`, `models/match_settings.dart` (field, copyWith, ==, hash, defaults), `presets.dart` (applyTo).
- Client: `lib/ui/screens/setup/optional_roles.dart` (OptionalRole — the one table the roles screen, bot sheet and store read), `role_rows.dart`, `lib/data/match_codec.dart`, `lib/transport/room_codec.dart`, `room_settings_panel.dart`, `lobby_screen.dart`, card face + gallery art (`AppImages`, `AppGallery`, result/card_spread/onboarding maps), ARB name/power/description.
- Server: `_shared/room_configuration.ts`, `_shared/purchase_access.ts` (ROLE_UNLOCKS), `start_match` whitelist, `submit_night_action`, `api.ts` (actionForRole), `_shared/teams.ts` if it is a mafia-side role, SQL: `room_players_role_valid`, `night_actions_action_valid`, `apply_match_deal` whitelist, `is_mafia_team()` if mafia-side, `reward_catalog` row.
- Tests: a seeded bot match with the role reaching a winner; online deal test.

## A new table tool (tool #18) — online only
- SQL migration: `table_tools` row (+ `use_table_tool` special-cases if it takes a note/face/secret answer).
- Server: `_shared/tools.ts` + its use in `resolve_night` / `resolve_vote` / `submit_*` / `claim_floor`; `TOOL_CODE` in `_shared/economy_actions.ts`.
- Client: `game_snapshot.dart` (ToolLogEntry), `tool_feed.dart`, `table_tools.dart`, ARB copy, `assets/images/tools/tool_<code>.webp`.
- Never reachable from one-phone or bot play.

## A new store category or item kind
- `StoreKind`, `storeKindLabel`, the CosmeticKind switch in `buildStoreEntries`, `StoreEntryArt`, `storeCategories` (one entry = one drawer). New ledger kinds need a `wallet_ledger_kind_check` migration (pattern: `20261008000300_bot_wins.sql`) and a history label in `coin_store.dart`.

## A new story (#25)
- `assets/stories/<id>.json` with a unique number, a line in `StoryCatalog.assetPaths`, cover/evidence/location art, narration under `assets/voice/stories/`, then `dart run tool/stories/check.dart` (must pass, including the per-bucket shared-action check) and update count-asserting tests.

## Open content issue
`tool/stories/check.dart` REALISM: some stories cannot be deduced at small tables or in solo within the move budget (el_arousa, farah_el_sotouh solo; several at 2–4 players). Needs authoring (more or redistributed clues), owner's call.
