begin;
do $$
declare answer jsonb;
begin
  answer := public.economy_capabilities(gen_random_uuid())->'webAds';
  assert not (answer ? 'bannerSlot'), 'no slot configured must expose nothing: '||answer::text;
  assert answer->>'provider'='house', answer::text;
  update public.economy_config set web_ads_banner_slot='1234567890';
  answer := public.economy_capabilities(gen_random_uuid())->'webAds';
  assert answer->>'bannerSlot'='1234567890', answer::text;
  assert answer->>'provider' is not null and answer ? 'enabled', answer::text;
  begin
    update public.economy_config set web_ads_banner_slot='abc';
    raise exception 'non-numeric slot accepted';
  exception when check_violation then null;
  end;
  begin
    update public.economy_config set web_ads_banner_slot='1234';
    raise exception 'short slot accepted';
  exception when check_violation then null;
  end;
  update public.economy_config set web_ads_banner_slot=null;
  assert not ((public.economy_capabilities(gen_random_uuid())->'webAds') ? 'bannerSlot');
  assert not has_function_privilege('authenticated','public.economy_capabilities_pre_web_banner_slot(uuid)','execute');
end $$;
rollback;
