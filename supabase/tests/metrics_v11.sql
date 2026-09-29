-- Contract for 20260928001200_metrics_v11 (F13/P9). Rolled back by the harness.
begin;
do $$
declare
  u uuid:='00000000-0000-4000-8000-00000000f013';
  r uuid:='10000000-0000-4000-8000-00000000f013';
  e text;
  result jsonb;
  no_prop text[]:=array[
    'eligible_app_open','case_open','case_attempt','case_solved','case_failed',
    'mission_hub_open','mission_claim','season_level_reached','chapter_started',
    'chapter_completed','academy_started','academy_passed','share_exported',
    'scenario_selected','house_rule_created','house_rule_imported','series_started',
    'series_completed','series_dropped','thursday_match','title_equipped','store_open',
    'product_view','purchase_started','purchase_succeeded','purchase_revoked','ad_offer',
    'ad_started','ad_completed','ad_no_fill','pass_view','pass_purchase',
    'invite_landing_open','invite_web_join','invite_first_match','case_share',
    'case_link_open','founder_grant','code_redeem'
  ];
begin
  foreach e in array no_prop loop
    perform public.metric_record(u,e,'',gen_random_uuid());
  end loop;
  perform public.metric_record(u,'invite_share','lobby',gen_random_uuid());
  perform public.metric_record(u,'partner_pick','doctor',gen_random_uuid());
  perform public.metric_record(u,'attributed_first_open','organic',gen_random_uuid());

  foreach e in array array['unknown','role','message','voice'] loop
    begin
      perform public.metric_record(u,e,'',gen_random_uuid());
      raise exception 'unknown metric accepted: %',e;
    exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  end loop;
  foreach e in array array['free text','mafia','side_unknown'] loop
    begin
      perform public.metric_record(u,'attributed_first_open',e,gen_random_uuid());
      raise exception 'unknown prop accepted: %',e;
    exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  end loop;
  begin
    perform public.metric_record(u,'case_open','unexpected',gen_random_uuid());
    raise exception 'property accepted on property-free event';
  exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;

  result:=public.metric_record(u,'case_open','',r);
  assert not (result->>'replayed')::boolean,result::text;
  result:=public.metric_record(u,'case_open','',r);
  assert (result->>'replayed')::boolean,result::text;
  assert (select total from public.product_metric_daily
    where day=(now() at time zone 'utc')::date and event='case_open' and prop='')=2,
    'replay counted twice';

  assert position(u::text in coalesce((select string_agg(subject::text||request_id::text,' ')
    from public.metric_receipts),''))=0,'raw account id stored';
  assert (select bool_and(octet_length(subject)=32) from public.metric_receipts),'bad HMAC width';

  -- purge_metrics_v11() cuts salts at (now() at time zone 'utc' - 48h)::date; anchor
  -- this probe row to that same UTC date (not the session-local current_date) so the
  -- assertion below does not flake when the session's local day has already rolled
  -- over past midnight UTC.
  insert into public.metric_salts(day,salt) values(((now() at time zone 'utc')::date-3),decode(repeat('01',32),'hex'));
  insert into public.metric_receipts(subject,request_id,day,created_at)
    values(decode(repeat('02',32),'hex'),gen_random_uuid(),((now() at time zone 'utc')::date-3),now()-interval '49 hours');
  perform public.purge_metrics_v11();
  assert not exists(select 1 from public.metric_receipts where created_at<now()-interval '48 hours');
  assert not exists(select 1 from public.metric_salts where day=((now() at time zone 'utc')::date-3));

  assert not has_table_privilege('authenticated','public.product_metric_daily','select');
  assert not has_table_privilege('authenticated','public.metric_receipts','select');
  assert not has_table_privilege('authenticated','public.metric_salts','select');
  assert not has_function_privilege('authenticated','public.metric_record(uuid,text,text,uuid)','execute');
  assert not has_function_privilege('authenticated','public.purge_metrics_v11()','execute');
  assert (public.economy_capabilities(u)->>'metrics')='false';
  assert (public.economy_capabilities(u)->>'reviewPrompt')='false';
  assert public.economy_capabilities(u) ? 'caseOfDay','earlier capabilities lost';
end $$;
rollback;
