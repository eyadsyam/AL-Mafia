# Store review: how every item applies, and what the owner's all-access gets (2026-10-29)

The owner's account (eyadsyam124) has the live all-access grant since 2026-10-29. Owner: «تطبيقها كلها وحش اوي»: tools must be in his game whenever he wants, and roles must be his to set up and deal, all with their assets and value.

## Catalogue (live)
- Roles: role_elder, role_silencer, role_sniper.
- Looks: 5 frames, 3 nameplates; 3 narrator packs; 3 presentation packs; mastermind_guide; 3 bundles.
- Table tools (17, online only by RL20): extra_minute, anon_note, last_will, spotlight, objection, last_word, vote_shield, half_door, double_vote, camouflage, revote, grave_vote (retired), sense, impersonate, narrator_whisper, lock_door, appeal.
- Play: mm_remove_interruptions, 3 coin packs, starter bundle.

## How each applies today, and what all-access does

| Item | Offline (one phone) | Online | All-access today | Finding |
|---|---|---|---|---|
| Bought roles | roles_screen / role_rows: on/off per role if `wallet.owned` has it | lobby deal; start_match checks the host owns it | all 3 owned (wallet lists every catalogue code) | OK in code. The mafia count is automatic (RL22 balance by table size); the host only switches optional roles on/off. No manual role counts. |
| Frames / nameplates | profile, home, result, share card | seat card for everyone | all owned; equip one per slot (materialised on equip) | OK in code; must be equipped from the store/profile, nothing is auto-equipped. |
| Narrator pack | host phone's equipped narrator (match_flow.dart:290) | room setting picked by the host from owned (room_settings_panel.dart:310) | all owned; equip/pick one | OK in code; needs equip (offline) or the room setting (online). |
| Presentation pack | host phone's equipped pack (match_flow.dart:541) | room setting (room_settings_panel.dart:304) | same | OK in code; same note. |
| Table tools | none: tools are online only (RL20) | tools sheet lists `charges > 0` that fit the phase (table_tools.dart:458) | every tool shows charges = 1 and is never spent (table_tools_snapshot / use_table_tool) | (1) the sheet and store show «· 1», reading like one use; (2) the per-match limits still apply to all-access: 4 tools a match, 2 heavy, each tool's per-match cap, one per phase (tool_guards.sql:93-99); (3) nothing offline. |
| Remove interruptions (ad-free) | — | — | NOT included: `user_owns_entitlement` excludes `remove_interruptions` (all_access_grants.sql:82) | The owner still sees ads on his account. |
| Coins | — | — | tools and items cost 0 (catalog_charge) | OK. |

## Owner decisions needed
1. Tools for all-access: lift the per-match limits (unlimited, any phase) or keep the fair-play limits in rooms with real players?
2. Tools offline: today none by design (RL20). Bring them to the one-phone game? (Big feature: each tool needs an offline meaning.)
3. Role setup: keep automatic mafia count, or let the host set counts per role?
4. Ad-free on the owner's account: include remove_interruptions in all-access?
5. What exactly looked bad on screen (screenshot of the store / the tools sheet / roles)?

## Small fixes ready once agreed
- Show «مفتوحة» instead of «· 1» for an all-access tool (store pill and in-match chip).
- Auto-equip nothing, but mark all-access items as owned with their art in the store grid (verify on device).
