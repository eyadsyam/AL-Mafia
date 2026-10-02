-- Privacy-preserving operational metering. No user id, room code, role, voice,
-- message or per-match record is retained here.

alter table public.rooms add column if not exists started_at timestamptz;

create table if not exists public.usage_daily (
  day date primary key,
  rooms_created bigint not null default 0 check (rooms_created >= 0),
  matches_started bigint not null default 0 check (matches_started >= 0),
  matches_finished bigint not null default 0 check (matches_finished >= 0),
  abandoned_rooms bigint not null default 0 check (abandoned_rooms >= 0),
  player_matches bigint not null default 0 check (player_matches >= 0),
  match_seconds bigint not null default 0 check (match_seconds >= 0),
  player_seconds bigint not null default 0 check (player_seconds >= 0),
  updated_at timestamptz not null default now()
);
alter table public.usage_daily enable row level security;
revoke all on table public.usage_daily from public, anon, authenticated;
grant select, insert, update, delete on table public.usage_daily to service_role;

create table if not exists public.operations_control (
  singleton boolean primary key default true check (singleton),
  new_rooms_enabled boolean not null default true,
  reason text not null default '',
  updated_at timestamptz not null default now()
);
alter table public.operations_control enable row level security;
revoke all on table public.operations_control from public, anon, authenticated;
grant select, insert, update on table public.operations_control to service_role;
insert into public.operations_control(singleton) values(true) on conflict do nothing;

create table if not exists public.usage_thresholds (
  metric text primary key check (metric in ('matches_started','player_minutes','room_minutes')),
  monthly_limit bigint not null check (monthly_limit > 0),
  updated_at timestamptz not null default now()
);
alter table public.usage_thresholds enable row level security;
revoke all on table public.usage_thresholds from public, anon, authenticated;
grant select, insert, update, delete on table public.usage_thresholds to service_role;

create table if not exists public.usage_alerts (
  month_start date not null,
  metric text not null,
  level smallint not null check (level in (50,75,90,100)),
  observed bigint not null,
  monthly_limit bigint not null,
  created_at timestamptz not null default now(),
  primary key(month_start,metric,level)
);
alter table public.usage_alerts enable row level security;
revoke all on table public.usage_alerts from public, anon, authenticated;
grant select, insert, update, delete on table public.usage_alerts to service_role;

create or replace function public.capture_room_usage()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare players bigint:=0; seconds bigint:=0; metric_day date;
begin
  if tg_op='INSERT' then
    insert into public.usage_daily(day,rooms_created)
      values((new.created_at at time zone 'utc')::date,1)
      on conflict(day) do update set rooms_created=usage_daily.rooms_created+1,updated_at=now();
    return new;
  end if;

  if old.status is distinct from 'playing' and new.status='playing' then
    new.started_at:=coalesce(new.started_at,now());
  end if;
  return new;
end $$;

create or replace function public.capture_room_usage_after()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare players bigint:=0; seconds bigint:=0; metric_day date;
begin
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

drop trigger if exists rooms_usage_before on public.rooms;
create trigger rooms_usage_before before insert or update of status on public.rooms
for each row execute function public.capture_room_usage();
drop trigger if exists rooms_usage_after on public.rooms;
create trigger rooms_usage_after after update of status on public.rooms
for each row execute function public.capture_room_usage_after();

create or replace function public.refresh_usage_alerts(p_now timestamptz default now())
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare t record; observed_value bigint; alert_level int; inserted_count int:=0; month_day date;
begin
  month_day:=date_trunc('month',p_now at time zone 'utc')::date;
  for t in select * from public.usage_thresholds loop
    select case t.metric
      when 'matches_started' then coalesce(sum(matches_started),0)
      when 'player_minutes' then coalesce(sum(player_seconds)/60,0)
      when 'room_minutes' then coalesce(sum(match_seconds)/60,0)
    end into observed_value from public.usage_daily where day>=month_day;
    foreach alert_level in array array[50,75,90,100] loop
      if observed_value*100>=t.monthly_limit*alert_level then
        insert into public.usage_alerts(month_start,metric,level,observed,monthly_limit)
          values(month_day,t.metric,alert_level,observed_value,t.monthly_limit)
          on conflict do nothing;
        if found then inserted_count:=inserted_count+1; end if;
      end if;
    end loop;
  end loop;
  return inserted_count;
end $$;
revoke all on function public.refresh_usage_alerts(timestamptz) from public,anon,authenticated;
grant execute on function public.refresh_usage_alerts(timestamptz) to service_role;

create or replace function public.usage_month_report(p_month date default date_trunc('month',now() at time zone 'utc')::date)
returns table(rooms_created bigint,matches_started bigint,matches_finished bigint,abandoned_rooms bigint,
  player_matches bigint,room_minutes bigint,player_minutes bigint)
language sql security definer set search_path=public,pg_temp as $$
  select coalesce(sum(u.rooms_created),0),coalesce(sum(u.matches_started),0),coalesce(sum(u.matches_finished),0),
    coalesce(sum(u.abandoned_rooms),0),coalesce(sum(u.player_matches),0),coalesce(sum(u.match_seconds)/60,0),
    coalesce(sum(u.player_seconds)/60,0)
  from public.usage_daily u where u.day>=date_trunc('month',p_month)::date
    and u.day<(date_trunc('month',p_month)+interval '1 month')::date
$$;
revoke all on function public.usage_month_report(date) from public,anon,authenticated;
grant execute on function public.usage_month_report(date) to service_role;

do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.unschedule('refresh-usage-alerts') where exists(select 1 from cron.job where jobname='refresh-usage-alerts');
    perform cron.schedule('refresh-usage-alerts','13 * * * *',$cron$select public.refresh_usage_alerts();$cron$);
  end if;
end $$;

-- Keep active matches running; only creation of a new room is gated.
create or replace function public.create_room_atomic(
  p_code text,p_host uuid,p_name text,p_gender text,p_seed bigint,p_configuration jsonb
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r uuid; vacated integer; accepting boolean;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  select new_rooms_enabled into accepting from public.operations_control where singleton=true;
  if accepting is false then raise exception 'NEW_ROOMS_PAUSED'; end if;
  perform pg_advisory_xact_lock(hashtext('room_entry:'||p_host::text));
  vacated := public.vacate_other_rooms(p_host, null);
  insert into public.rooms(code,host_id,match_seed,settings,visibility,title)
    values(p_code,p_host,p_seed,coalesce(p_configuration->'settings','{}'),
      coalesce(p_configuration->>'visibility','private'),coalesce(p_configuration->>'title',''))
    returning id into r;
  insert into public.room_players(room_id,user_id,name,gender,seat)
    values(r,p_host,btrim(p_name),p_gender,0);
  insert into public.room_state(room_id,phase) values(r,'lobby');
  return jsonb_build_object('roomId',r,'code',p_code,'seat',0,'vacated',vacated);
end $$;
revoke all on function public.create_room_atomic(text,uuid,text,text,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.create_room_atomic(text,uuid,text,text,bigint,jsonb) to service_role;

