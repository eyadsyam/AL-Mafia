-- Web ad controls are independent of Android AdMob settings. Off until the
-- website and H5 Games account are approved. No reward settlement is added:
-- browser callbacks are not a signed proof of an ad view.
alter table public.economy_config
  add column if not exists web_ads_enabled boolean not null default false,
  add column if not exists web_ads_provider text not null default 'house'
    check (web_ads_provider in ('adsense_h5','house')),
  add column if not exists web_interstitial_every_matches int not null default 1
    check (web_interstitial_every_matches between 1 and 20),
  add column if not exists web_app_open_enabled boolean not null default true,
  add column if not exists web_banner_always boolean not null default true;

alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_web_ads;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb; cfg public.economy_config;
begin
  base := public.economy_capabilities_pre_web_ads(p_user);
  select * into cfg from public.economy_config where id=true;
  return base || jsonb_build_object('webAds',jsonb_build_object(
    'enabled',coalesce(cfg.web_ads_enabled,false),
    'provider',coalesce(cfg.web_ads_provider,'house'),
    'interstitialEveryMatches',coalesce(cfg.web_interstitial_every_matches,1),
    'appOpen',coalesce(cfg.web_app_open_enabled,true),
    'bannerAlways',coalesce(cfg.web_banner_always,true)));
end $$;
revoke all on function public.economy_capabilities_pre_web_ads(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_web_ads(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
