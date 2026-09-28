-- F13: anonymous daily product counters. Raw subjects and arbitrary values
-- never cross this boundary; only the allowlisted enum pair is aggregated.
create table public.product_metric_daily(
  day date not null,
  event text not null,
  prop text not null default '',
  total bigint not null default 0 check(total>=0),
  primary key(day,event,prop)
);

create table public.metric_salts(
  day date primary key,
  salt bytea not null check(octet_length(salt)=32)
);

create table public.metric_receipts(
  subject bytea not null check(octet_length(subject)=32),
  request_id uuid not null,
  day date not null,
  created_at timestamptz not null default now(),
  primary key(subject,request_id,day)
);

revoke all on table public.product_metric_daily from public,anon,authenticated;
revoke all on table public.metric_salts from public,anon,authenticated;
revoke all on table public.metric_receipts from public,anon,authenticated;
grant select,insert,update,delete on table public.product_metric_daily to service_role;
grant select,insert,update,delete on table public.metric_salts to service_role;
grant select,insert,update,delete on table public.metric_receipts to service_role;

-- RFC 2104 HMAC-SHA256, expressed with PostgreSQL's built-in sha256 so the
-- migration does not depend on where a hosted project installed pgcrypto.
create function public.metric_hmac_sha256(p_key bytea,p_message bytea)
returns bytea language plpgsql immutable security definer set search_path=public,pg_temp as $$
declare
  k bytea:=p_key;
  inner_pad bytea:=decode(repeat('36',64),'hex');
  outer_pad bytea:=decode(repeat('5c',64),'hex');
  i integer;
begin
  if octet_length(k)>64 then k:=sha256(k); end if;
  k:=k||decode(repeat('00',64-octet_length(k)),'hex');
  for i in 0..63 loop
    inner_pad:=set_byte(inner_pad,i,get_byte(inner_pad,i)#get_byte(k,i));
    outer_pad:=set_byte(outer_pad,i,get_byte(outer_pad,i)#get_byte(k,i));
  end loop;
  return sha256(outer_pad||sha256(inner_pad||p_message));
end $$;
revoke all on function public.metric_hmac_sha256(bytea,bytea) from public,anon,authenticated;
grant execute on function public.metric_hmac_sha256(bytea,bytea) to service_role;

create function public.purge_metrics_v11()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare removed integer:=0; n integer;
begin
  delete from public.metric_receipts where created_at<now()-interval '48 hours';
  get diagnostics removed=row_count;
  delete from public.metric_salts where day<(now() at time zone 'utc'-interval '48 hours')::date;
  get diagnostics n=row_count;
  return removed+n;
end $$;
revoke all on function public.purge_metrics_v11() from public,anon,authenticated;
grant execute on function public.purge_metrics_v11() to service_role;

create function public.metric_record(p_user uuid,p_event text,p_prop text,p_request uuid)
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
    ]))
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

select cron.schedule('purge-metrics-v11','17 4 * * *','select public.purge_metrics_v11();');

alter table public.economy_config
  add column if not exists metrics_enabled boolean not null default false,
  add column if not exists review_prompt_enabled boolean not null default false;

alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_metrics;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_metrics(p_user);
  return base||jsonb_build_object(
    'metrics',coalesce((select metrics_enabled from public.economy_config limit 1),false),
    'reviewPrompt',coalesce((select review_prompt_enabled from public.economy_config limit 1),false));
end $$;
revoke all on function public.economy_capabilities_pre_metrics(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_metrics(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
