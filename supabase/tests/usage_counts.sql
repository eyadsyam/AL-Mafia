-- Contract for 20261030004000_usage_counts. Rolled back by the harness.
begin;
do $$
declare
  u uuid:='00000000-0000-4000-8000-00000000f014';
  admin uuid:='00000000-0000-4000-8000-00000000f015';
  e text;
  result jsonb;
  today jsonb;
begin
  -- The new pairs are counted; everything around them is still refused.
  foreach e in array array['p4_6','p7_9','p10_12','p13_plus'] loop
    perform public.metric_record(u,'match_local_finished',e,gen_random_uuid());
  end loop;
  perform public.metric_record(u,'ad_result','daily:earned',gen_random_uuid());
  perform public.metric_record(u,'ad_result','extra:failed',gen_random_uuid());
  perform public.metric_record(u,'ad_result','match_step_two:not_consented',gen_random_uuid());
  foreach e in array array['','p3','mafia','10'] loop
    begin
      perform public.metric_record(u,'match_local_finished',e,gen_random_uuid());
      raise exception 'table size accepted: %',e;
    exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  end loop;
  foreach e in array array['','daily','daily:','daily:earned:x','room:earned','daily:mafia','x daily:earned'] loop
    begin
      perform public.metric_record(u,'ad_result',e,gen_random_uuid());
      raise exception 'ad result accepted: %',e;
    exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  end loop;
  -- The old pairs still pass.
  perform public.metric_record(u,'attributed_first_open','organic',gen_random_uuid());
  perform public.metric_record(u,'case_open','',gen_random_uuid());

  assert (select metrics_enabled from public.economy_config limit 1),'counts are not on';

  -- The owner page: 14 days, newest first, today's events keyed event/prop.
  begin
    perform public.owner_review_usage(u);
    raise exception 'usage page served to a non administrator';
  exception when raise_exception then assert sqlerrm='NOT_ADMIN',sqlerrm; end;
  insert into public.commerce_admins(user_id,note) values(admin,'usage test');
  result:=public.owner_review_usage(admin);
  assert jsonb_array_length(result->'items')=14,result::text;
  today:=result->'items'->0;
  assert today->>'day'=to_char((now() at time zone 'utc')::date,'YYYY-MM-DD'),today::text;
  assert (today->'events'->>'match_local_finished/p7_9')::int=1,today::text;
  assert (today->'events'->>'ad_result/daily:earned')::int=1,today::text;
  assert (today->'events'->>'case_open')::int>=1,today::text;
  foreach e in array array['newAccounts','onlinePlayers','onlineMatches','adsAsked','adsPaid'] loop
    assert today ? e,'missing '||e;
  end loop;
  assert result->'items'->13->'events'='{}'::jsonb or (result->'items'->13->'events') is not null;

  assert not has_function_privilege('authenticated','public.owner_review_usage(uuid)','execute');
  assert not has_function_privilege('anon','public.owner_review_usage(uuid)','execute');
end $$;
rollback;
