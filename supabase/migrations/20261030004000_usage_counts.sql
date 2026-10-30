-- Usage counts (owner, 2026-10-30: «شغله»). Two additions to the F13
-- allowlist and a daily usage page in the owner review. Still no names,
-- rooms, roles or codes: an event and one enum value, counted per day.
--   match_local_finished: a one-phone match reached its result, by table size.
--   ad_result: what a rewarded ad did, by offer, so a stuck or empty ad shows
--   up as a number instead of a complaint.
create or replace function public.metric_record(p_user uuid,p_event text,p_prop text,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
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
    'case_link_open','founder_grant','code_redeem'
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
end $$;
revoke all on function public.metric_record(uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function public.metric_record(uuid,text,text,uuid) to service_role;

-- The owner's daily page: the last 14 UTC days, newest first. Server facts
-- (accounts, online matches, rewarded ads asked and paid) need no client;
-- `events` adds the client counts above once a build sends them.
create or replace function public.owner_review_usage(p_admin uuid)
returns jsonb language plpgsql stable security definer
set search_path = public, auth, pg_temp as $$
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  return jsonb_build_object('items', coalesce((
    select jsonb_agg(jsonb_build_object(
      'day', to_char(d.day,'YYYY-MM-DD'),
      'newAccounts', (select count(*) from auth.users u
        where (u.created_at at time zone 'utc')::date=d.day),
      'onlinePlayers', (select count(distinct r.user_id) from public.match_receipts r
        where (r.created_at at time zone 'utc')::date=d.day),
      'onlineMatches', (select count(distinct m.room_id) from public.council_match_records m
        where (m.created_at at time zone 'utc')::date=d.day),
      'adsAsked', (select count(*) from (
          select created_at from public.ad_reward_claims
          union all select created_at from public.ad_step_claims
          union all select created_at from public.daily_ad_claims
          union all select created_at from public.ad_extra_claims) a
        where (a.created_at at time zone 'utc')::date=d.day),
      'adsPaid', (select count(*) from (
          select created_at, awarded_at from public.ad_reward_claims
          union all select created_at, awarded_at from public.ad_step_claims
          union all select created_at, awarded_at from public.daily_ad_claims
          union all select created_at, awarded_at from public.ad_extra_claims) a
        where a.awarded_at is not null and (a.created_at at time zone 'utc')::date=d.day),
      'events', coalesce((select jsonb_object_agg(
          case when p.prop='' then p.event else p.event||'/'||p.prop end, p.total)
        from public.product_metric_daily p where p.day=d.day), '{}'::jsonb)
    ) order by d.day desc)
    from (select ((now() at time zone 'utc')::date - g) as day
      from generate_series(0,13) g) d), '[]'::jsonb));
end $$;
revoke all on function public.owner_review_usage(uuid) from public,anon,authenticated;
grant execute on function public.owner_review_usage(uuid) to service_role;

-- The owner's word: counts on.
update public.economy_config set metrics_enabled = true;
