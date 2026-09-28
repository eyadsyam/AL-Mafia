-- F9: Thursday Night. Cairo civil time is authoritative; the client never
-- supplies a clock or decides whether a completed match earns anything.

alter table public.economy_config
  add column if not exists thursday_event_enabled boolean not null default false;

alter table public.rooms
  add column if not exists scenario_fingerprint text not null default ''
    check (scenario_fingerprint='' or scenario_fingerprint ~ '^[0-9a-f]{32}$');

create table public.thursday_weekly_events (
  event_week date primary key,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  scenario_fingerprint text not null check (scenario_fingerprint ~ '^[0-9a-f]{32}$'),
  created_at timestamptz not null default now(),
  check (ends_at>starts_at)
);

-- One immutable room receipt is also the request-id replay record for rooms
-- opened through eventCreateRoom. Rooms created by another server path get a
-- receipt only when their eligible public result is recorded.
create table public.thursday_event_receipts (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  event_week date not null references public.thursday_weekly_events(event_week),
  creator_id uuid,
  request_id uuid,
  started_at timestamptz,
  scenario_fingerprint text not null check (scenario_fingerprint ~ '^[0-9a-f]{32}$'),
  created_at timestamptz not null default now()
);
create unique index thursday_event_request_replay
  on public.thursday_event_receipts(creator_id,request_id)
  where request_id is not null;

create table public.thursday_participation (
  user_id uuid not null references auth.users(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  event_week date not null references public.thursday_weekly_events(event_week),
  ordinal int not null check (ordinal between 1 and 2),
  season_id bigint not null references public.mission_seasons(id) on delete cascade,
  xp int not null default 20 check (xp=20),
  stamp_granted boolean not null default false,
  recorded_at timestamptz not null default now(),
  primary key(user_id,room_id),
  unique(user_id,event_week,ordinal)
);

create table public.thursday_aggregates (
  user_id uuid not null references auth.users(id) on delete cascade,
  event_week date not null references public.thursday_weekly_events(event_week),
  eligible_matches int not null default 0 check (eligible_matches between 0 and 2),
  season_xp int not null default 0 check (season_xp between 0 and 40),
  stamp_granted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key(user_id,event_week)
);

alter table public.thursday_weekly_events enable row level security;
alter table public.thursday_event_receipts enable row level security;
alter table public.thursday_participation enable row level security;
alter table public.thursday_aggregates enable row level security;
revoke all on table public.thursday_weekly_events,public.thursday_event_receipts,
  public.thursday_participation,public.thursday_aggregates from public,anon,authenticated;
grant all on table public.thursday_weekly_events,public.thursday_event_receipts,
  public.thursday_participation,public.thursday_aggregates to service_role;

create function public.thursday_preset()
returns jsonb language sql immutable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object(
    'maxPlayers',10,'voice',true,'muteAllAtNight',true,
    'discussionMode','structured','openVoting',false,
    'traceEnabled',true,'confrontationEnabled',true,'whisperEnabled',true,
    'speechSeconds',45,'discussionSeconds',300,'scenarioCode','classic')
$$;

create function public.thursday_preset_fingerprint()
returns text language sql immutable security definer set search_path=public,pg_temp as $$
  select md5(public.thursday_preset()::text)
$$;

-- The returned week is the Cairo Thursday date, including the Friday
-- 00:00-00:59 continuation. PostgreSQL's IANA zone rules carry Egypt DST.
create function public.thursday_cairo_state(p_at timestamptz)
returns jsonb language plpgsql immutable security definer set search_path=public,pg_temp as $$
declare local_at timestamp:=p_at at time zone 'Africa/Cairo'; local_day date;
  dow int; featured boolean; bonus boolean; event_day date;
begin
  local_day:=local_at::date;
  dow:=extract(isodow from local_at)::int;
  featured:=dow=4;
  bonus:=(dow=4 and local_at::time>=time '20:00')
    or (dow=5 and local_at::time<time '01:00');
  event_day:=case when dow=5 and local_at::time<time '01:00'
    then local_day-1 else local_day end;
  return jsonb_build_object('isThursday',featured,'inWindow',bonus,
    'eventWeek',event_day::text,'cairoAt',local_at::text);
end $$;

create function public.thursday_on()
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select thursday_event_enabled from public.economy_config limit 1),false)
    and exists(select 1 from public.mission_seasons where active)
$$;

create function public.thursday_ensure_event(p_week date)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare cairo_start timestamp:=p_week::timestamp;
begin
  insert into public.thursday_weekly_events(
      event_week,starts_at,ends_at,scenario_fingerprint)
    values(p_week,cairo_start at time zone 'Africa/Cairo',
      (cairo_start+interval '1 day 1 hour') at time zone 'Africa/Cairo',
      public.thursday_preset_fingerprint())
    on conflict(event_week) do nothing;
end $$;

create function public.thursday_record_match(p_user uuid,p_room uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare rec record; state jsonb; wk date; n int; season bigint;
begin
  if not public.thursday_on() then return; end if;
  select c.ended_at,r.started_at,r.scenario_fingerprint,r.host_id
    into rec from public.council_match_records c
    join public.rooms r on r.id=c.room_id
   where c.user_id=p_user and c.room_id=p_room and c.eligible;
  if not found or rec.started_at is null
     or rec.scenario_fingerprint<>public.thursday_preset_fingerprint() then return; end if;
  state:=public.thursday_cairo_state(rec.started_at);
  if not (state->>'inWindow')::boolean then return; end if;
  wk:=(state->>'eventWeek')::date;
  select id into season from public.mission_seasons
   where active and rec.ended_at>=starts_at and rec.ended_at<ends_at
   order by starts_at desc limit 1;
  if season is null then return; end if;

  perform pg_advisory_xact_lock(hashtextextended(
    'thursday:'||p_user::text||':'||wk::text,94));
  if exists(select 1 from public.thursday_participation
      where user_id=p_user and room_id=p_room) then return; end if;
  select count(*)::int into n from public.thursday_participation
    where user_id=p_user and event_week=wk;
  if n>=2 then return; end if;
  perform public.thursday_ensure_event(wk);
  insert into public.thursday_event_receipts(
      room_id,event_week,creator_id,started_at,scenario_fingerprint)
    values(p_room,wk,rec.host_id,rec.started_at,rec.scenario_fingerprint)
    on conflict(room_id) do nothing;
  insert into public.thursday_participation(
      user_id,room_id,event_week,ordinal,season_id,xp,stamp_granted,recorded_at)
    values(p_user,p_room,wk,n+1,season,20,n=1,rec.ended_at);
  insert into public.season_xp_events(user_id,season_id,source_key,xp,created_at)
    values(p_user,season,'thursday:'||p_room,20,rec.ended_at)
    on conflict do nothing;
  insert into public.thursday_aggregates(
      user_id,event_week,eligible_matches,season_xp,stamp_granted,updated_at)
    values(p_user,wk,n+1,(n+1)*20,n=1,rec.ended_at)
    on conflict(user_id,event_week) do update set
      eligible_matches=excluded.eligible_matches,season_xp=excluded.season_xp,
      stamp_granted=thursday_aggregates.stamp_granted or excluded.stamp_granted,
      updated_at=excluded.updated_at;
end $$;

create function public.thursday_event(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare state jsonb:=public.thursday_cairo_state(now()); wk date;
  agg public.thursday_aggregates;
begin
  wk:=(state->>'eventWeek')::date;
  select * into agg from public.thursday_aggregates
    where user_id=p_user and event_week=wk;
  return jsonb_build_object('enabled',public.thursday_on(),
    'isThursday',(state->>'isThursday')::boolean,
    'inWindow',(state->>'inWindow')::boolean,'event',wk::text,
    'progress',coalesce(agg.eligible_matches,0),
    'stamp',coalesce(agg.stamp_granted,false));
end $$;

create function public.event_create_room(
  p_user uuid,p_event text,p_request uuid,p_code text,p_seed bigint,p_at timestamptz)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare replay record; state jsonb; wk date; made jsonb; rid uuid;
  chosen_name text; chosen_gender text;
begin
  if p_event<>'thursday' or p_request is null or p_at is null then
    raise exception 'BAD_REQUEST';
  end if;
  select r.room_id,rooms.code into replay from public.thursday_event_receipts r
    join public.rooms rooms on rooms.id=r.room_id
   where r.creator_id=p_user and r.request_id=p_request;
  if found then return jsonb_build_object('roomId',replay.room_id,'code',replay.code,
    'seat',0,'vacated',0,'replayed',true); end if;
  if not public.thursday_on() then raise exception 'DISABLED'; end if;
  state:=public.thursday_cairo_state(p_at);
  if not (state->>'isThursday')::boolean then raise exception 'NOT_THURSDAY'; end if;
  wk:=(state->>'eventWeek')::date;
  select name,gender into chosen_name,chosen_gender from public.council_identity
    where user_id=p_user;
  chosen_name:=coalesce(nullif(btrim(chosen_name),''),'Player');
  chosen_gender:=coalesce(chosen_gender,'unspecified');
  made:=public.create_room_atomic(p_code,p_user,chosen_name,chosen_gender,p_seed,
    jsonb_build_object('visibility','private','title','',
      'settings',public.thursday_preset()));
  rid:=(made->>'roomId')::uuid;
  update public.rooms set scenario_fingerprint=public.thursday_preset_fingerprint()
    where id=rid;
  perform public.thursday_ensure_event(wk);
  insert into public.thursday_event_receipts(
      room_id,event_week,creator_id,request_id,scenario_fingerprint)
    values(rid,wk,p_user,p_request,public.thursday_preset_fingerprint());
  return made||jsonb_build_object('event','thursday','replayed',false);
end $$;

-- Match eligibility stays owned by council_record_match. This wrapper only
-- consumes its immutable eligible row after the existing Casebook recorder.
alter function public.casebook_record_match(uuid,uuid)
  rename to casebook_record_match_pre_thursday;
create function public.casebook_record_match(p_user uuid,p_room uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.casebook_record_match_pre_thursday(p_user,p_room);
  perform public.thursday_record_match(p_user,p_room);
end $$;

-- Capability composition follows the established rename-and-wrap chain.
alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_thursday;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_thursday(p_user);
  return base||jsonb_build_object('thursday',public.thursday_on());
end $$;

revoke all on function public.thursday_preset() from public,anon,authenticated;
grant execute on function public.thursday_preset() to service_role;
revoke all on function public.thursday_preset_fingerprint() from public,anon,authenticated;
grant execute on function public.thursday_preset_fingerprint() to service_role;
revoke all on function public.thursday_cairo_state(timestamptz) from public,anon,authenticated;
grant execute on function public.thursday_cairo_state(timestamptz) to service_role;
revoke all on function public.thursday_on() from public,anon,authenticated;
grant execute on function public.thursday_on() to service_role;
revoke all on function public.thursday_ensure_event(date) from public,anon,authenticated;
grant execute on function public.thursday_ensure_event(date) to service_role;
revoke all on function public.thursday_record_match(uuid,uuid) from public,anon,authenticated;
grant execute on function public.thursday_record_match(uuid,uuid) to service_role;
revoke all on function public.thursday_event(uuid) from public,anon,authenticated;
grant execute on function public.thursday_event(uuid) to service_role;
revoke all on function public.event_create_room(uuid,text,uuid,text,bigint,timestamptz) from public,anon,authenticated;
grant execute on function public.event_create_room(uuid,text,uuid,text,bigint,timestamptz) to service_role;
revoke all on function public.casebook_record_match_pre_thursday(uuid,uuid) from public,anon,authenticated;
grant execute on function public.casebook_record_match_pre_thursday(uuid,uuid) to service_role;
revoke all on function public.casebook_record_match(uuid,uuid) from public,anon,authenticated;
grant execute on function public.casebook_record_match(uuid,uuid) to service_role;
revoke all on function public.economy_capabilities_pre_thursday(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities_pre_thursday(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
