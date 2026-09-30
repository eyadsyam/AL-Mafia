-- H5 is requested first; the Flutter house creative fills any unavailable slot.
alter table public.economy_config
  drop constraint if exists economy_config_web_ads_provider_check;
alter table public.economy_config
  add constraint economy_config_web_ads_provider_check
  check (web_ads_provider in ('adsense','house'));
