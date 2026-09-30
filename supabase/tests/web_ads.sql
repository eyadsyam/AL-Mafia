begin;
do $$
declare cfg public.economy_config; answer jsonb;
begin
  select * into cfg from public.economy_config where id=true;
  assert not cfg.web_ads_enabled and cfg.web_ads_provider='house';
  assert cfg.web_interstitial_every_matches=1 and cfg.web_app_open_enabled and cfg.web_banner_always;
  answer := public.economy_capabilities(gen_random_uuid())->'webAds';
  assert answer->>'enabled'='false' and answer->>'provider'='house', answer::text;
  update public.economy_config set web_ads_enabled=true, web_ads_provider='adsense_h5',
    web_interstitial_every_matches=2, web_app_open_enabled=false, web_banner_always=false;
  answer := public.economy_capabilities(gen_random_uuid())->'webAds';
  assert answer->>'enabled'='true' and answer->>'provider'='adsense_h5';
  assert (answer->>'interstitialEveryMatches')::int=2;
  assert answer->>'appOpen'='false' and answer->>'bannerAlways'='false';
  assert not has_function_privilege('authenticated','public.economy_capabilities_pre_web_ads(uuid)','execute');
end $$;
rollback;
