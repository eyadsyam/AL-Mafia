-- M3 — the heartbeat stops being a broadcast.
--
-- Every beat used to update `room_players.last_seen`, and `room_players` is a
-- published table: each beat became a Realtime event delivered to every seat.
-- At a three-second beat a ten-seat room delivers ~40,000 roster events in
-- twenty minutes, and none of them tells anybody anything — the roster only
-- changes when somebody arrives, steps away or leaves.
--
-- Beats now land in `room_presence`, which is not published. `room_players`
-- changes only on a transition (connected / away / left), so the stream carries
-- the three facts the table actually shows. Everything on the server that asks
-- "when was this seat last heard?" reads `heard_at()`: the newer of the last
-- published transition and the last beat. The thresholds are unchanged.

create table public.room_presence (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null,
  heard_at timestamptz not null default now(),
  primary key(room_id,user_id)
);
alter table public.room_presence enable row level security;
revoke all on public.room_presence from public,anon,authenticated;
grant all on public.room_presence to service_role;

-- When this seat was last heard. `greatest` skips a missing beat.
create function public.heard_at(p_room uuid,p_user uuid,p_last timestamptz)
returns timestamptz language sql stable security definer set search_path=public,pg_temp as $$
  select greatest(p_last,
    (select pr.heard_at from public.room_presence pr where pr.room_id=p_room and pr.user_id=p_user))
$$;
revoke all on function public.heard_at(uuid,uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.heard_at(uuid,uuid,timestamptz) to service_role;

-- One beat. False when the seat is not this user's (never joined, or removed).
create function public.presence_beat(p_room uuid,p_user uuid) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not exists (select 1 from public.room_players
                  where room_id=p_room and user_id=p_user and not kicked) then
    return false;
  end if;
  insert into public.room_presence(room_id,user_id,heard_at) values(p_room,p_user,now())
    on conflict(room_id,user_id) do update set heard_at=excluded.heard_at;
  -- Only a change of state reaches the room.
  update public.room_players set connected=true,status='connected',last_seen=now()
   where room_id=p_room and user_id=p_user and not kicked
     and (status<>'connected' or not connected);
  return true;
end $$;
revoke all on function public.presence_beat(uuid,uuid) from public,anon,authenticated;
grant execute on function public.presence_beat(uuid,uuid) to service_role;

-- ── Every reader of "last heard" asks heard_at() ────────────────────────────

create or replace function public.age_presence() returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare changed integer; departed record;
begin
  update public.room_players p set status = 'away'
    from public.rooms r
   where r.id = p.room_id and r.status <> 'finished'
     and p.status = 'connected'
     and public.heard_at(p.room_id, p.user_id, p.last_seen) < now() - interval '25 seconds';

  with gone as (
    update public.room_players p set status = 'left', connected = false
      from public.rooms r
     where r.id = p.room_id and r.status <> 'finished'
       and p.status <> 'left'
       and public.heard_at(p.room_id, p.user_id, p.last_seen) < now() - interval '90 seconds'
    returning p.room_id, p.user_id, r.status as room_status, p.kicked
  )
  select count(*) into changed from gone;

  -- A silent lobby row is given up like a departure; the seat is free again
  -- and every count agrees. Removed rows are left as they are.
  for departed in
    select p.room_id, p.user_id from public.room_players p
      join public.rooms r on r.id = p.room_id
     where r.status = 'lobby' and p.status = 'left' and not p.kicked
  loop
    perform public.leave_room(departed.room_id, departed.user_id);
  end loop;

  return changed;
end;
$$;
revoke all on function public.age_presence() from public, anon, authenticated;

create or replace function public.handover_departed_host() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  target_room uuid := old.room_id;
  owner_id uuid;
  room_status text;
  heir uuid;
begin
  if tg_op = 'UPDATE' and new.status <> 'left' then return new; end if;
  select host_id, status into owner_id, room_status from public.rooms
    where id = target_room for update;
  if not found or room_status = 'finished' then return null; end if;
  -- Removed rows are kept for their own client's notification; a lobby with
  -- nobody else in it is an empty lobby.
  if tg_op = 'DELETE' and room_status = 'lobby' and not exists
      (select 1 from public.room_players where room_id = target_room and not kicked) then
    delete from public.rooms where id = target_room;
    return null;
  end if;
  if owner_id = old.user_id then
    select user_id into heir from public.room_players
      where room_id = target_room and user_id <> old.user_id
        and status = 'connected' and connected and not kicked
        and public.heard_at(room_id, user_id, last_seen) > now() - interval '30 seconds'
      order by seat limit 1;
    if heir is not null then
      update public.rooms set host_id = heir where id = target_room;
    end if;
  end if;
  return null;
end;
$$;

create or replace function public.archive_abandoned_rooms(
  p_idle interval default interval '5 minutes'
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  archived integer;
begin
  with abandoned as (
    update public.rooms r
       set status = 'finished',
           ended_at = now()
     where r.status = 'playing'
       and not exists (
         select 1 from public.room_players p
          where p.room_id = r.id
            and p.connected
            and public.heard_at(p.room_id, p.user_id, p.last_seen) > now() - p_idle
       )
    returning 1
  )
  select count(*) into archived from abandoned;

  return archived;
end;
$$;

create or replace function public.migrate_host(
  p_room     uuid,
  p_claimant uuid,
  p_timeout  interval default interval '30 seconds'
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_host uuid;
  host_live    boolean;
  heir         uuid;
begin
  select host_id into current_host
    from public.rooms
   where id = p_room
     and status <> 'finished'
   for update;

  if current_host is null then
    return null;
  end if;

  select (status <> 'left' and connected
          and public.heard_at(room_id, user_id, last_seen) > now() - p_timeout)
    into host_live
    from public.room_players
   where room_id = p_room and user_id = current_host;

  if coalesce(host_live, false) then
    return current_host;
  end if;

  select user_id into heir
    from public.room_players
   where room_id = p_room
     and status = 'connected'
     and connected
     and public.heard_at(room_id, user_id, last_seen) > now() - p_timeout
   order by seat
   limit 1;

  if heir is null then
    return current_host;
  end if;

  if heir <> p_claimant then
    return heir;
  end if;

  update public.rooms set host_id = heir where id = p_room;
  return heir;
end;
$$;
revoke all on function public.migrate_host(uuid, uuid, interval)
  from public, anon, authenticated;
grant execute on function public.migrate_host(uuid, uuid, interval) to service_role;

create or replace function public.strike_absent_member(p_room uuid, p_host uuid, p_seat integer)
returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; p public.room_players%rowtype; s public.room_state%rowtype;
        mafia integer; town integer; outcome text;
begin
  select * into r from public.rooms where id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if r.host_id<>p_host then raise exception 'NOT_HOST'; end if;
  if r.status<>'playing' then raise exception 'PHASE_CLOSED'; end if;
  select * into p from public.room_players where room_id=p_room and seat=p_seat for update;
  if not found then raise exception 'BAD_REQUEST'; end if;
  -- The host is the one asking; a host who is here cannot be gone.
  if p.user_id=p_host then raise exception 'BAD_REQUEST'; end if;
  if not p.alive then raise exception 'ALREADY_OUT'; end if;
  -- Three minutes of silence, by the server's clock. A seat that is still
  -- beating — or went quiet less than three minutes ago — is still here.
  if p.connected and public.heard_at(p.room_id, p.user_id, p.last_seen) > now() - interval '3 minutes' then
    raise exception 'STILL_HERE';
  end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  update public.room_players set alive=false where room_id=p_room and user_id=p.user_id;
  -- Doc 09 §3.4: anything still in flight to a seat that is gone is voided,
  -- exactly as it is for a seat that died.
  update public.whisper_meta set voided=true where room_id=p_room and to_id=p.user_id and not voided;
  perform public.set_public_path(p_room, array['eliminations', p_seat::text],
    jsonb_build_object('phase', case when s.phase='night' then 'night' else 'day' end, 'number', s.phase_number));
  -- W8: the win check runs after the removal is applied.
  select count(*) filter (where role='mafia'), count(*) filter (where role<>'mafia')
    into mafia, town from public.room_players where room_id=p_room and alive;
  if mafia=0 then outcome:='town';
  elsif mafia>=town then outcome:='mafia';
  end if;
  if outcome is not null then
    perform public.merge_public_data(p_room, jsonb_build_object('outcome',outcome));
  end if;
  return jsonb_build_object('removed', p_seat, 'outcome', outcome);
end;
$$;
revoke all on function public.strike_absent_member(uuid,uuid,integer) from public, anon, authenticated;
grant execute on function public.strike_absent_member(uuid,uuid,integer) to service_role;
