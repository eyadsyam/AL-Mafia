-- Row 12 remainder: launch events (spec §2 row 12; §4 F12
-- `operator_event_set{code,startsAt,endsAt,scenarioCode,enabled,requestId}`).
--
-- An operator schedules a named event window (the launch night, say) on the
-- canonical Thursday preset. A match counts for it when its eligible Council
-- record exists (the Economy v3 receipt when that is on), it *started* inside
-- the window, and its stored scenario fingerprint is the canonical one. It
-- grants nothing: participation is a public-result stamp, read only for a
-- finished room. Nothing is scheduled by this migration, so it ships dark.
--
-- Doc 05: every input is public (start time, stored preset fingerprint, the
-- finished result); the read names no role, seat or other player.

create table public.operator_audit_log(
  id bigint generated always as identity primary key,
  action text not null check (action ~ '^[a-z_]{3,60}$'),
  target text not null check (char_length(target) between 1 and 80),
  request_id uuid not null,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now(),
  unique(action,request_id)
);
alter table public.operator_audit_log enable row level security;
revoke all on public.operator_audit_log from public,anon,authenticated;
grant select,insert on public.operator_audit_log to service_role;

create function public.operator_audit_immutable() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  raise exception 'AUDIT_IMMUTABLE';
end $$;
create trigger operator_audit_log_immutable before update or delete on public.operator_audit_log
  for each row execute function public.operator_audit_immutable();

create table public.launch_events(
  code text primary key check (code ~ '^[a-z0-9_]{3,40}$'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  scenario_code text not null check (scenario_code='classic'),
  scenario_fingerprint text not null check (scenario_fingerprint ~ '^[0-9a-f]{32}$'),
  enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  check (ends_at>starts_at and ends_at-starts_at<=interval '7 days')
);

create table public.launch_event_participation(
  user_id uuid not null,
  room_id uuid not null,
  event_code text not null references public.launch_events(code),
  recorded_at timestamptz not null default now(),
  primary key(user_id,room_id,event_code)
);
alter table public.launch_events enable row level security;
alter table public.launch_event_participation enable row level security;
revoke all on public.launch_events,public.launch_event_participation from public,anon,authenticated;
grant all on public.launch_events,public.launch_event_participation to service_role;

create function public.launch_event_json(e public.launch_events) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object('code',e.code,'startsAt',e.starts_at,'endsAt',e.ends_at,
    'cairoStartsAt',(e.starts_at at time zone 'Africa/Cairo')::text,
    'cairoEndsAt',(e.ends_at at time zone 'Africa/Cairo')::text,
    'scenarioCode',e.scenario_code,'enabled',e.enabled)
$$;

-- Service-role only; idempotent by request id (a replay returns the first
-- answer); every change is audited. A live window's start never moves and
-- its end never moves into the past; a new window never starts in the past.
create function public.operator_event_set(p_code text,p_starts_at timestamptz,
  p_ends_at timestamptz,p_scenario_code text,p_enabled boolean,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare kept public.operator_audit_log; old public.launch_events; fresh public.launch_events;
  body jsonb;
begin
  if p_request is null then return jsonb_build_object('ok',false,'code','BAD_REQUEST'); end if;
  select * into kept from public.operator_audit_log
   where action='operator_event_set' and request_id=p_request;
  if found then return kept.after||jsonb_build_object('replayed',true); end if;
  if p_code is null or p_code !~ '^[a-z0-9_]{3,40}$' or p_starts_at is null or p_ends_at is null
     or p_enabled is null or p_scenario_code is distinct from 'classic'
     or p_ends_at<=p_starts_at or p_ends_at-p_starts_at>interval '7 days'
     or p_starts_at='infinity'::timestamptz or p_ends_at='infinity'::timestamptz then
    return jsonb_build_object('ok',false,'requestId',p_request,'code','BAD_REQUEST');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('operator_event:'||p_code,96));
  select * into old from public.launch_events where code=p_code for update;
  if old.code is null then
    if p_starts_at<now()-interval '1 minute' then
      return jsonb_build_object('ok',false,'requestId',p_request,'code','BACKDATED');
    end if;
  else
    if old.starts_at<=now() and p_starts_at<>old.starts_at then
      return jsonb_build_object('ok',false,'requestId',p_request,'code','EVENT_STARTED');
    end if;
    if old.starts_at>now() and p_starts_at<now()-interval '1 minute' then
      return jsonb_build_object('ok',false,'requestId',p_request,'code','BACKDATED');
    end if;
    if p_ends_at<now() and p_ends_at<>old.ends_at then
      return jsonb_build_object('ok',false,'requestId',p_request,'code','BACKDATED');
    end if;
  end if;
  insert into public.launch_events(code,starts_at,ends_at,scenario_code,scenario_fingerprint,
      enabled,updated_at)
    values(p_code,p_starts_at,p_ends_at,p_scenario_code,public.thursday_preset_fingerprint(),
      p_enabled,now())
    on conflict(code) do update set starts_at=excluded.starts_at,ends_at=excluded.ends_at,
      scenario_code=excluded.scenario_code,scenario_fingerprint=excluded.scenario_fingerprint,
      enabled=excluded.enabled,updated_at=now()
    returning * into fresh;
  body:=jsonb_build_object('ok',true,'requestId',p_request,
    'before',case when old.code is null then null else public.launch_event_json(old) end,
    'after',public.launch_event_json(fresh));
  insert into public.operator_audit_log(action,target,request_id,before,after)
    values('operator_event_set',p_code,p_request,body->'before',body);
  return body;
end $$;

-- Every enabled window open at [p_at]. Public schedule facts only.
create function public.launch_event_state(p_at timestamptz) returns jsonb
language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object('enabled',exists(select 1 from public.launch_events where enabled),
    'active',coalesce((select jsonb_agg(public.launch_event_json(e) order by e.starts_at)
      from public.launch_events e
      where e.enabled and p_at>=e.starts_at and p_at<e.ends_at),'[]'::jsonb),
    'upcoming',coalesce((select jsonb_agg(public.launch_event_json(e) order by e.starts_at)
      from public.launch_events e
      where e.enabled and e.starts_at>p_at and e.starts_at<=p_at+interval '7 days'),'[]'::jsonb))
$$;

-- Records the events a finished eligible match counts for. Idempotent.
create function public.launch_event_record_match(p_user uuid,p_room uuid) returns int
language plpgsql security definer set search_path=public,pg_temp as $$
declare rec record; n int;
begin
  select r.started_at,r.scenario_fingerprint into rec
    from public.council_match_records c join public.rooms r on r.id=c.room_id
   where c.user_id=p_user and c.room_id=p_room and c.eligible and r.status='finished';
  if not found or rec.started_at is null then return 0; end if;
  insert into public.launch_event_participation(user_id,room_id,event_code)
    select p_user,p_room,e.code from public.launch_events e
     where e.enabled and rec.started_at>=e.starts_at and rec.started_at<e.ends_at
       and rec.scenario_fingerprint is not distinct from e.scenario_fingerprint
    on conflict do nothing;
  get diagnostics n=row_count;
  return n;
end $$;

-- The public-result stamp: only for a finished room this caller sat in.
create function public.launch_event_result(p_user uuid,p_room uuid) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare st text;
begin
  select r.status into st from public.rooms r
    join public.room_players p on p.room_id=r.id and p.user_id=p_user and not p.kicked
   where r.id=p_room;
  if st is null then raise exception 'NOT_MEMBER'; end if;
  if st<>'finished' then return jsonb_build_object('enabled',true,'events','[]'::jsonb); end if;
  perform public.launch_event_record_match(p_user,p_room);
  return jsonb_build_object('enabled',true,'events',coalesce((
    select jsonb_agg(p.event_code order by p.event_code)
      from public.launch_event_participation p
     where p.user_id=p_user and p.room_id=p_room),'[]'::jsonb));
end $$;

-- Recorded at the same boundary as Thursday, after the Casebook recorder.
alter function public.casebook_record_match(uuid,uuid) rename to casebook_record_match_pre_events;
create function public.casebook_record_match(p_user uuid,p_room uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.casebook_record_match_pre_events(p_user,p_room);
  if exists(select 1 from public.launch_events where enabled) then
    perform public.launch_event_record_match(p_user,p_room);
  end if;
end $$;

alter function public.complete_data_deletion(uuid) rename to complete_data_deletion_pre_events;
create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;
  perform public.complete_data_deletion_pre_events(p_request);
  if who is not null then
    delete from public.launch_event_participation where user_id=who;
  end if;
end $$;

revoke all on function public.operator_audit_immutable() from public,anon,authenticated;
grant execute on function public.operator_audit_immutable() to service_role;
revoke all on function public.launch_event_json(public.launch_events) from public,anon,authenticated;
grant execute on function public.launch_event_json(public.launch_events) to service_role;
revoke all on function public.operator_event_set(text,timestamptz,timestamptz,text,boolean,uuid) from public,anon,authenticated;
grant execute on function public.operator_event_set(text,timestamptz,timestamptz,text,boolean,uuid) to service_role;
revoke all on function public.launch_event_state(timestamptz) from public,anon,authenticated;
grant execute on function public.launch_event_state(timestamptz) to service_role;
revoke all on function public.launch_event_record_match(uuid,uuid) from public,anon,authenticated;
grant execute on function public.launch_event_record_match(uuid,uuid) to service_role;
revoke all on function public.launch_event_result(uuid,uuid) from public,anon,authenticated;
grant execute on function public.launch_event_result(uuid,uuid) to service_role;
revoke all on function public.casebook_record_match_pre_events(uuid,uuid) from public,anon,authenticated;
grant execute on function public.casebook_record_match_pre_events(uuid,uuid) to service_role;
revoke all on function public.casebook_record_match(uuid,uuid) from public,anon,authenticated;
grant execute on function public.casebook_record_match(uuid,uuid) to service_role;
revoke all on function public.complete_data_deletion_pre_events(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion_pre_events(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
