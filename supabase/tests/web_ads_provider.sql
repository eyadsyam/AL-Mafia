begin;
do $$ begin
  update public.economy_config set web_ads_provider='adsense';
  if (select web_ads_provider from public.economy_config) <> 'adsense' then
    raise exception 'adsense provider unavailable';
  end if;
  begin
    update public.economy_config set web_ads_provider='invalid';
    raise exception 'invalid provider accepted';
  exception when check_violation then null;
  end;
end $$;
rollback;
