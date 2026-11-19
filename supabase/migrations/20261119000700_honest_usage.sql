-- O6 (owner 2026-11-19): the admin numbers show real players only.
-- The live test harness (supabase/tests/e2e_match.py, play_with_app.py,
-- concurrency_match.py, recovery_match.py, kick_*_match.py, ready_match.py,
-- revote_match.py, roster_match.py, witness_match.py, the *_probe.py files)
-- seats players under a fixed set of first names. A room whose seats are at
-- least half harness names, and at least two of them, is a harness room and
-- leaves the usage counters and the owner's daily page.
-- Also adds the aggregate counts the queue and play-night functions write:
-- queue/{join,matched,expired,ready_yes,ready_no} and play_night/{remind,push}.
-- Idempotent (create or replace only).

create or replace function public.is_harness_room(p_room uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  -- At least four harness names and at least 80% of the seats: common first
  -- names on the list must not hide a real table.
  select coalesce(sum(s.h::int) >= 4 and sum(s.h::int) * 5 >= count(*) * 4, false)
    from (
      select (btrim(p.name) = any(array[
          'Amina','Bassem','Camelia','Dawoud','Enas',
          'Ghada','Hani','Ibrahim','Jumana','Karim','Laila',
          'Hala','Jana','Lina',
          'Rami','Salma','Taha','Uday','Wafa',
          'Rana','Sherif','Tamer','Yara','Ziad',
          'Wael','Xena','Yousef','Zeina','Adel',
          'Host','Bina','Cyra','Dina','Ezra'])
        or btrim(p.name) ~ '^(LiveBot|Bot)[0-9]*$') as h
        from public.room_players p
       where p.room_id = p_room and not p.kicked
    ) s
$$;
revoke all on function public.is_harness_room(uuid) from public, anon, authenticated;
grant execute on function public.is_harness_room(uuid) to service_role;

-- Rooms are counted when they are created, before any seat exists, so a harness
-- room is taken back out the first time it is seen to be one: when it starts,
-- or when it is closed without ever starting. Its start and finish are never
-- counted. Same body as 20260921000100 otherwise.
create or replace function public.capture_room_usage_after()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare players bigint:=0; seconds bigint:=0; metric_day date; harness boolean:=false;
begin
  if (old.status is distinct from 'playing' and new.status='playing')
     or (old.status is distinct from 'finished' and new.status='finished') then
    harness := public.is_harness_room(new.id);
  end if;
  if harness then
    if (old.status is distinct from 'playing' and new.status='playing')
       or (old.status is distinct from 'finished' and new.status='finished' and new.started_at is null) then
      update public.usage_daily
         set rooms_created=greatest(rooms_created-1,0), updated_at=now()
       where day=(new.created_at at time zone 'utc')::date;
    end if;
    return new;
  end if;

  if old.status is distinct from 'playing' and new.status='playing' then
    insert into public.usage_daily(day,matches_started)
      values((new.started_at at time zone 'utc')::date,1)
      on conflict(day) do update set matches_started=usage_daily.matches_started+1,updated_at=now();
  end if;

  if old.status is distinct from 'finished' and new.status='finished' then
    metric_day:=(coalesce(new.ended_at,now()) at time zone 'utc')::date;
    if old.status='playing' or new.started_at is not null then
      select count(*) into players from public.room_players
        where room_id=new.id and role is not null and not kicked;
      seconds:=greatest(0,extract(epoch from (coalesce(new.ended_at,now())-coalesce(new.started_at,new.created_at)))::bigint);
      insert into public.usage_daily(day,matches_finished,player_matches,match_seconds,player_seconds)
        values(metric_day,1,players,seconds,seconds*players)
        on conflict(day) do update set
          matches_finished=usage_daily.matches_finished+1,
          player_matches=usage_daily.player_matches+excluded.player_matches,
          match_seconds=usage_daily.match_seconds+excluded.match_seconds,
          player_seconds=usage_daily.player_seconds+excluded.player_seconds,
          updated_at=now();
    else
      insert into public.usage_daily(day,abandoned_rooms) values(metric_day,1)
        on conflict(day) do update set abandoned_rooms=usage_daily.abandoned_rooms+1,updated_at=now();
    end if;
  end if;
  return new;
end $$;
revoke all on function public.capture_room_usage_after() from public, anon, authenticated;

-- The owner's daily page, as of 20261030004000, with the online counts
-- (onlinePlayers, onlineMatches) leaving harness rooms out.
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
        where (r.created_at at time zone 'utc')::date=d.day
          and not public.is_harness_room(r.room_id)),
      'onlineMatches', (select count(distinct m.room_id) from public.council_match_records m
        where (m.created_at at time zone 'utc')::date=d.day
          and not public.is_harness_room(m.room_id)),
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

-- metric_record: the body of 20261119000200_first_run_events.sql plus
--   queue/{join,matched,expired,ready_yes,ready_no} and play_night/{remind,push}.
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

-- A count is never worth breaking the call that earned it: the queue and
-- play-night functions note their events through here, with a fresh request id.
create or replace function public.metric_note(p_user uuid, p_event text, p_prop text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.metric_record(p_user, p_event, p_prop, gen_random_uuid());
exception when others then
  null;
end $$;
revoke all on function public.metric_note(uuid, text, text) from public, anon, authenticated;
grant execute on function public.metric_note(uuid, text, text) to service_role;
