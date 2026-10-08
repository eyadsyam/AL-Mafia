# Identity source inventory

Static scan of all 190 Dart files under lib/ui; 88 screen/flow/sheet files below. This is a source inventory, not a claim of rendered visual review. Counts/patterns are triage signals; specialized art, game diagrams and semantic status marks are not interchangeable with generic cards. See IDENTITY-2026-10-08.md for decisions and gate failures.

| File | Before: structural drift candidates | Disposition |
|---|---|---|
| `lib/ui/account/account_sheet.dart` | base button treatment; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/account/delete_account_sheet.dart` | base button treatment; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/economy/ad_extras.dart` | local state composition | Existing shared store kit retained |
| `lib/ui/economy/coin_packs.dart` | bespoke surfaces; local state composition | Existing shared store kit retained |
| `lib/ui/economy/council_hub.dart` | bespoke surfaces; local state composition; local headings | Existing shared store kit retained |
| `lib/ui/economy/daily_rewards.dart` | bespoke surfaces; local state composition | Existing shared store kit retained |
| `lib/ui/economy/pass_result_inventory.dart` | bespoke surfaces; base button treatment | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/economy/play_offers.dart` | bespoke surfaces; local state composition; local headings | Existing shared store kit retained |
| `lib/ui/economy/table_tools.dart` | base button treatment; local state composition | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/fun/characters_screen.dart` | bespoke surfaces | Migrated public kit/theme; retain content and behavior |
| `lib/ui/missions/casebook_sheet.dart` | bespoke surfaces; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/admin/payments_admin_screen.dart` | local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/admin/safety_admin_screen.dart` | local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/day/confrontation_screen.dart` | base button treatment | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/day/day_card_check.dart` | base button treatment | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/day/discussion_screen.dart` | bespoke surfaces; base button treatment; local state composition; local headings | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/day/opening_round_screen.dart` | local headings | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/day/vote_result_screen.dart` | bespoke surfaces; base button treatment; local state composition; local headings | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/day/voting_screen.dart` | base button treatment; local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/day/whisper_compose_screen.dart` | local headings | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/distribution/role_reveal_screen.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/home_placeholder.dart` | No generic card/button drift detected structurally | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/match_controller.dart` | local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/match_flow.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/match_route.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/night/morning_screen.dart` | base button treatment; local state composition; local headings | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/night/night_action_screen.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/onboarding/first_run_screen.dart` | bespoke surfaces; base button treatment; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/onboarding/onboarding_video_screen.dart` | bespoke surfaces; base button treatment; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/online/council/card_rise.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/council_band.dart` | local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/council_geometry.dart` | local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/phase_sting.dart` | bespoke surfaces | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/revealed_whispers.dart` | local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/role_glyph.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/role_roster.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/seat_status.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/council/voice_band.dart` | bespoke surfaces; local headings | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/host_handover.dart` | bespoke surfaces; local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/host_sheet.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/invite_sheet.dart` | bespoke surfaces; local state composition | Existing shared store kit retained |
| `lib/ui/screens/online/lobby_screen.dart` | local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/online/online_entry_screen.dart` | bespoke surfaces; base button treatment; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/online/online_session.dart` | No generic card/button drift detected structurally | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/online/online_table_flow.dart` | base button treatment; local state composition; local headings | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/online_welcome_art.dart` | bespoke surfaces | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/online/result_share_button.dart` | local state composition; local headings | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/online/rewarded_reward_button.dart` | local state composition | Existing shared store kit retained |
| `lib/ui/screens/online/room_invite.dart` | No generic card/button drift detected structurally | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/online/room_settings_panel.dart` | bespoke surfaces; local headings | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/online/safety_center.dart` | base button treatment; local state composition | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/online/scene_sheet.dart` | bespoke surfaces | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/table/connection_weather.dart` | bespoke surfaces | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/table/room_presentation.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/table/table_mood.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/table/table_pulse.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/table/table_scene.dart` | bespoke surfaces | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/table/tool_feed.dart` | bespoke surfaces; local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/voice_session.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/witness/elimination_beat.dart` | No generic card/button drift detected structurally | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/witness/kill_jumpscare.dart` | local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/witness/own_record.dart` | local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/witness/witness_layer.dart` | bespoke surfaces; local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/online/witness/witness_panel.dart` | bespoke surfaces; local state composition | Preserve match geometry/privacy; no public gold theme |
| `lib/ui/screens/postgame/analytics_screen.dart` | bespoke surfaces; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/postgame/history_screen.dart` | bespoke surfaces; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/postgame/result_screen.dart` | bespoke surfaces; base button treatment; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/add_players_screen.dart` | bespoke surfaces; base button treatment; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/bot_match_sheet.dart` | base button treatment; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/coin_store.dart` | bespoke surfaces; base button treatment; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/group_follow_up.dart` | local state composition | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/setup/group_picker_screen.dart` | bespoke surfaces; base button treatment; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/help_center.dart` | No generic card/button drift detected structurally | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/home_screen.dart` | base button treatment; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/how_to_play_screen.dart` | bespoke surfaces; base button treatment; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/mode_screen.dart` | bespoke surfaces; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/profile_screen.dart` | base button treatment; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/roles_screen.dart` | bespoke surfaces; base button treatment; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/scenario_store.dart` | No generic card/button drift detected structurally | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/settings_screen.dart` | bespoke surfaces; base button treatment | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/setup/setup_draft.dart` | No generic card/button drift detected structurally | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/screens/stories/stories_screen.dart` | bespoke surfaces; base button treatment; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/stories/story_flow_screen.dart` | bespoke surfaces; base button treatment; local state composition | Migrated public kit/theme; retain content and behavior |
| `lib/ui/screens/stories/story_rewards.dart` | No generic card/button drift detected structurally | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/social/friends.dart` | base button treatment; local state composition; local headings | Migrated public kit/theme; retain content and behavior |
| `lib/ui/social/titles_partner.dart` | local state composition | Existing shared store kit retained |
| `lib/ui/widgets/legal_documents.dart` | base button treatment; local headings | Retain specialized utility/flow; detailed visual review pending |
| `lib/ui/widgets/pass_screen.dart` | No generic card/button drift detected structurally | Retain specialized utility/flow; detailed visual review pending |
