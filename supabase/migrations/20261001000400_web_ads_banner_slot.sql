-- The AdSense display slot id can come from the server, so a new slot needs a
-- config update instead of a web rebuild. NULL means "use the build-time
-- WEB_ADSENSE_BANNER_SLOT". Same exposure path as web_ads_provider: the
-- `webAds` object of economy_capabilities.
alter table public.economy_config
  add column if not exists web_ads_banner_slot text
    check (web_ads_banner_slot is null or web_ads_banner_slot ~ '^[0-9]{5,20}$');

alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_web_banner_slot;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb; cfg public.economy_config;
begin
  base := public.economy_capabilities_pre_web_banner_slot(p_user);
  select * into cfg from public.economy_config where id=true;
  return jsonb_set(
    base,
    '{webAds}',
    coalesce(base->'webAds','{}'::jsonb) ||
      jsonb_strip_nulls(jsonb_build_object('bannerSlot',cfg.web_ads_banner_slot)),
    true);
end $$;
revoke all on function public.economy_capabilities_pre_web_banner_slot(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_web_banner_slot(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
