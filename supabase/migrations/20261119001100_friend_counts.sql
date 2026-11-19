-- Improvement 12 (owner 2026-11-19): friends counts, aggregate only.
-- metric_record is the body of 20261119000700_honest_usage.sql plus
--   friend/{request,accept,ping}; the friends edge function notes them through
--   metric_note after the call that earned them succeeded.
CREATE OR REPLACE FUNCTION public.metric_record(p_user uuid, p_event text, p_prop text, p_request uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date:=(now() at time zone 'utc')::date;
  s bytea;
  subject_hash bytea;
  inserted integer;
  no_prop constant text[]:=array[
    'eligible_app_open','case_open','case_attempt','case_solved','case_failed',
    'mission_hub_open','mission_claim','season_level_reached','chapter_started',
    'chapter_completed','academy_started','academy_passed','share_exported',
    'scenario_selected','house_rule_created','house_rule_imported','series_started',
    'series_completed','series_dropped','thursday_match','title_equipped','store_open',
    'product_view','purchase_started','purchase_succeeded','purchase_revoked','ad_offer',
    'ad_started','ad_completed','ad_no_fill','pass_view','pass_purchase',
    'invite_landing_open','invite_web_join','invite_first_match','case_share',
    'case_link_open','founder_grant','code_redeem','app_open'
  ];
  ad_offers constant text[]:=array['match','match_step','match_step_two','daily','extra'];
  ad_outcomes constant text[]:=array['earned','dismissed','unavailable','failed','not_consented'];
begin
  if p_user is null or p_request is null or p_event is null or p_prop is null then
    raise exception 'BAD_REQUEST';
  end if;
  if not (
    (p_event=any(no_prop) and p_prop='') or
    (p_event='invite_share' and p_prop=any(array['home','lobby','result','case'])) or
    (p_event='partner_pick' and p_prop=any(array['detective','doctor','mafia','citizen'])) or
    (p_event='attributed_first_open' and p_prop=any(array[
      'side_detective','side_doctor','side_mafia','side_citizen',
      'creator','case','invite','organic'
    ])) or
    (p_event='match_local_finished' and p_prop=any(array['p4_6','p7_9','p10_12','p13_plus'])) or
    (p_event='mode_pick' and p_prop=any(array['local','online'])) or
    (p_event='match_local_started' and p_prop=any(array['p4_6','p7_9','p10_12','p13_plus'])) or
    (p_event='first_run' and p_prop=any(array['terms','account','kind','name','done'])) or
    (p_event='online_action' and p_prop=any(array['quick','create','join_code','join_public','home_line'])) or
    (p_event='queue' and p_prop=any(array['join','matched','expired','ready_yes','ready_no'])) or
    (p_event='play_night' and p_prop=any(array['remind','push'])) or
    (p_event='friend' and p_prop=any(array['request','accept','ping'])) or
    (p_event='ad_result' and split_part(p_prop,':',1)=any(ad_offers)
      and split_part(p_prop,':',2)=any(ad_outcomes)
      and p_prop=split_part(p_prop,':',1)||':'||split_part(p_prop,':',2))
  ) then
    raise exception 'BAD_REQUEST';
  end if;

  insert into public.metric_salts(day,salt)
    values(d,decode(replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''),'hex'))
    on conflict(day) do nothing;
  select salt into strict s from public.metric_salts where day=d;
  subject_hash:=public.metric_hmac_sha256(s,convert_to(p_user::text,'UTF8'));

  insert into public.metric_receipts(subject,request_id,day)
    values(subject_hash,p_request,d) on conflict do nothing;
  get diagnostics inserted=row_count;
  if inserted=0 then return jsonb_build_object('ok',true,'replayed',true); end if;

  insert into public.product_metric_daily(day,event,prop,total)
    values(d,p_event,p_prop,1)
    on conflict(day,event,prop) do update set total=public.product_metric_daily.total+1;
  return jsonb_build_object('ok',true,'replayed',false);
end $function$;
revoke all on function public.metric_record(uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function public.metric_record(uuid,text,text,uuid) to service_role;
