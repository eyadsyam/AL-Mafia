-- Owner, 2026-11-11: «بين كل ماتش 3 لكل ماتش مش لليوم». Full-screen ads are
-- budgeted per match, not per day: up to 3 between one match and the next
-- (leaving the result, a stay on the menus, the next Create/Join), none
-- inside a match. The device counts them since its last completed match.
--
-- The new rhythm travels in its own `perMatch` object, read only by builds
-- that also enforce the per-match budget. Older builds keep reading the
-- existing keys, which stay as they are: a build without the budget never
-- gets the shorter gap or the menu slot.
--
-- Additive: three columns and a wrapper (the same pattern as every earlier
-- ads migration). Nothing here reads or writes match state.

alter table public.economy_config
  add column if not exists full_screen_max_per_match int not null default 3
    check (full_screen_max_per_match between 0 and 3),
  add column if not exists full_screen_match_gap_seconds int not null default 90
    check (full_screen_match_gap_seconds between 60 and 86400),
  add column if not exists per_match_session_enabled boolean not null default true;

alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_match_cap;

create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; base jsonb; per jsonb;
begin
  select * into cfg from public.economy_config;
  base := public.economy_capabilities_pre_match_cap(p_user);
  per := jsonb_build_object(
    'maxPerMatch', coalesce(cfg.full_screen_max_per_match, 3),
    'gapSeconds', coalesce(cfg.full_screen_match_gap_seconds, 90),
    'session', coalesce(cfg.per_match_session_enabled, false));
  return base || jsonb_build_object(
    'interstitial', coalesce(base->'interstitial', '{}'::jsonb)
      || jsonb_build_object('perMatch', per),
    'ads', coalesce(base->'ads', '{}'::jsonb) || jsonb_build_object(
      'fullScreen', coalesce(base->'ads'->'fullScreen', '{}'::jsonb)
        || jsonb_build_object('perMatch', per)));
end $$;

revoke all on function public.economy_capabilities_pre_match_cap(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities_pre_match_cap(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
