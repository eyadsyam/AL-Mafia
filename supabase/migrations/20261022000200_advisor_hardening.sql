-- Fix advisor search-path, RLS initplan, and foreign-key index findings.

alter function public.is_mafia_team(text) set search_path = public, pg_temp;
alter function public.tool_pack_price(bigint, int) set search_path = public, pg_temp;

drop policy if exists own_blocks on public.player_blocks;
create policy own_blocks on public.player_blocks for select to authenticated using (blocker_id = (select auth.uid()));

create index if not exists ad_reward_claims_room_id_fk_idx on public.ad_reward_claims (room_id);
create index if not exists ad_step_claims_room_id_fk_idx on public.ad_step_claims (room_id);
create index if not exists coin_order_events_order_id_fk_idx on public.coin_order_events (order_id);
create index if not exists coin_orders_pack_code_fk_idx on public.coin_orders (pack_code);
create index if not exists coin_packs_item_code_fk_idx on public.coin_packs (item_code);
create index if not exists creator_entitlement_audit_entitlement_id_fk_idx on public.creator_entitlement_audit (entitlement_id);
create index if not exists launch_event_participation_event_code_fk_idx on public.launch_event_participation (event_code);
create index if not exists mission_achievements_code_fk_idx on public.mission_achievements (code);
create index if not exists play_products_item_code_fk_idx on public.play_products (item_code);
create index if not exists player_equipment_item_code_fk_idx on public.player_equipment (item_code);
create index if not exists player_equipment_user_id_item_code_fk_idx on public.player_equipment (user_id, item_code);
create index if not exists player_showcase_equipped_title_fk_idx on public.player_showcase (equipped_title);
create index if not exists player_titles_code_fk_idx on public.player_titles (code);
create index if not exists player_tool_charges_tool_code_fk_idx on public.player_tool_charges (tool_code);
create index if not exists room_tool_uses_tool_code_fk_idx on public.room_tool_uses (tool_code);
create index if not exists season_reward_catalog_item_code_fk_idx on public.season_reward_catalog (item_code);
create index if not exists season_reward_claims_season_id_level_fk_idx on public.season_reward_claims (season_id, level);
create index if not exists story_solves_story_id_fk_idx on public.story_solves (story_id);
create index if not exists story_v2_sessions_story_id_fk_idx on public.story_v2_sessions (story_id);
create index if not exists thursday_aggregates_event_week_fk_idx on public.thursday_aggregates (event_week);
create index if not exists thursday_event_receipts_event_week_fk_idx on public.thursday_event_receipts (event_week);
create index if not exists thursday_participation_event_week_fk_idx on public.thursday_participation (event_week);
create index if not exists thursday_participation_room_id_fk_idx on public.thursday_participation (room_id);
create index if not exists thursday_participation_season_id_fk_idx on public.thursday_participation (season_id);
