-- Server-owned public waiting rooms.
--
-- A room normally exists only because a human created it and hosts it. When
-- the public list has nothing joinable, the server may keep ONE empty waiting
-- room per supported pool so the first player has somewhere to go without a
-- "create a room" detour. The state is explicit and private:
--   * system_pool is set and host_id is null, only while status='lobby' and
--     visibility='public' (check constraint);
--   * no room_players row can exist for it (trigger), so it cannot count as a
--     player, send presence or start a match (every host action compares
--     host_id to the caller, and null matches nobody);
--   * the first successful join claims host atomically under the room row
--     lock and clears system_pool in the same statement, so two simultaneous
--     joiners produce exactly one host;
--   * at most one per pool (partial unique index); created only on demand by
--     browse_rooms; replaced after two idle hours; the existing 24-hour lobby
--     purge also removes it.
-- No fake users, no client credentials: provisioning runs as service_role.

alter table public.rooms alter column host_id drop not null;
alter table public.rooms add column if not exists system_pool text;
alter table public.rooms add constraint rooms_system_pool_known
  check (system_pool is null or system_pool in ('default'));
alter table public.rooms add constraint rooms_system_waiting_shape check (
  (system_pool is null and host_id is not null) or
  (system_pool is not null and host_id is null and status='lobby'
    and visibility='public')
);
create unique index if not exists rooms_one_system_waiting
  on public.rooms(system_pool) where system_pool is not null;

create or replace function public.reject_system_room_players()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if exists (select 1 from public.rooms where id=new.room_id and system_pool is not null) then
    raise exception 'SYSTEM_ROOM_UNCLAIMED';
  end if;
  return new;
end $$;
drop trigger if exists room_players_not_in_system_room on public.room_players;
create trigger room_players_not_in_system_room
  before insert on public.room_players
  for each row execute function public.reject_system_room_players();

-- Demand-driven and bounded. Returns true only when it created a room.
create or replace function public.ensure_system_waiting_room(
  p_user uuid, p_pool text default 'default'
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare accepting boolean; new_code text; attempt integer;
begin
  if p_pool is distinct from 'default' then raise exception 'BAD_REQUEST'; end if;
  select new_rooms_enabled into accepting from public.operations_control where singleton=true;
  if accepting is false then return false; end if;
  perform pg_advisory_xact_lock(hashtext('system_waiting:'||p_pool));

  delete from public.rooms
   where system_pool=p_pool and created_at < now() - interval '2 hours';
  if exists (select 1 from public.rooms where system_pool=p_pool) then
    return false;
  end if;
  -- Demand: only when this player has no public lobby with a free seat.
  if exists (
    select 1 from public.rooms r
    where r.status='lobby' and r.visibility='public' and r.system_pool is null
      and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
      and (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked)
        between 1 and (case when r.settings->>'maxPlayers' in ('5','8','10','15')
          then (r.settings->>'maxPlayers')::int else 10 end) - 1
  ) then
    return false;
  end if;

  for attempt in 1..8 loop
    select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
      1+floor(random()*32)::integer,1),'') into new_code
      from generate_series(1,6);
    begin
      with created as (
        insert into public.rooms(code,host_id,match_seed,settings,visibility,title,system_pool)
        values(new_code,null,floor(random()*2147483647)::bigint,
          jsonb_build_object(
            'maxPlayers',10,'voice',true,'muteAllAtNight',true,
            'speechSeconds',45,'discussionSeconds',300,
            'openVoting',false,'traceEnabled',true,
            'discussionMode','structured','confrontationEnabled',true,
            'whisperEnabled',true,'scenarioCode','classic'),
          'public','',p_pool)
        returning id
      )
      insert into public.room_state(room_id,phase) select id,'lobby' from created;
      return true;
    exception when unique_violation then
      if exists (select 1 from public.rooms where system_pool=p_pool) then
        return false;
      end if;
    end;
  end loop;
  return false;
end $$;
revoke all on function public.ensure_system_waiting_room(uuid,text) from public,anon,authenticated;
grant execute on function public.ensure_system_waiting_room(uuid,text) to service_role;

-- join_room_atomic as of 20260914000600, plus the claim.
create or replace function public.join_room_atomic(p_code text,p_user uuid,p_name text,p_gender text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms; player public.room_players; n integer; cap integer; chosen text; suffix integer:=2; vacated integer; claimed boolean:=false;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtext('room_entry:'||p_user::text));
  select * into r from public.rooms where code=upper(btrim(p_code)) for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if r.status='finished' then raise exception 'ROOM_FINISHED'; end if;
  if p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])) then raise exception 'NOT_A_MEMBER'; end if;
  select * into player from public.room_players where room_id=r.id and user_id=p_user;
  if found then
    if player.kicked then raise exception 'NOT_A_MEMBER'; end if;
    vacated := public.vacate_other_rooms(p_user, r.id);
    update public.room_players set status='connected',connected=true,last_seen=now()
      where room_id=r.id and user_id=p_user;
    return jsonb_build_object('roomId',r.id,'seat',player.seat,'rejoined',true,'vacated',vacated);
  end if;
  if r.status <> 'lobby' then raise exception 'PHASE_CLOSED'; end if;
  select count(*) into n from public.room_players where room_id=r.id and not kicked;
  cap := coalesce((r.settings->>'maxPlayers')::integer,10);
  if cap not in (5,8,10,15) then cap:=10; end if;
  if n>=cap then raise exception 'ROOM_FULL'; end if;
  vacated := public.vacate_other_rooms(p_user, r.id);
  if r.system_pool is not null then
    -- First real join: this player becomes the host. The row is locked, so a
    -- concurrent joiner waits here and then joins as an ordinary player.
    update public.rooms
       set host_id=p_user, system_pool=null, created_at=now(),
           match_seed=floor(random()*2147483647)::bigint
     where id=r.id;
    claimed := true;
  end if;
  chosen:=btrim(p_name);
  while exists(select 1 from public.room_players where room_id=r.id and name=chosen) loop
    chosen:=left(btrim(p_name),20-length(suffix::text)-1)||' '||suffix;
    suffix:=suffix+1;
  end loop;
  select coalesce(max(seat),-1)+1 into n from public.room_players where room_id=r.id;
  insert into public.room_players(room_id,user_id,name,gender,seat)
    values(r.id,p_user,chosen,p_gender,n);
  return jsonb_build_object('roomId',r.id,'seat',n,'name',chosen,'vacated',vacated,'host',claimed);
end;
$$;

-- The list, with the waiting room marked as such (never as occupied).
create or replace function public.public_room_listing_v2(p_user uuid)
returns table (
  code text, title text, players int, capacity int, min_players int,
  voice boolean, waiting boolean
)
language sql security definer set search_path=public,pg_temp stable as $$
  with listed as (
    select r.code, r.title, r.created_at, r.system_pool is not null as waiting,
      (select count(*) from public.room_players p
        where p.room_id=r.id and not p.kicked)::int as players,
      case when r.settings->>'maxPlayers' in ('5','8','10','15')
        then (r.settings->>'maxPlayers')::int else 10 end as capacity,
      coalesce((r.settings->>'voice')::boolean,true) as voice
    from public.rooms r
    where r.visibility='public' and r.status='lobby'
      and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
  )
  select code, title, players, capacity, 5, voice, waiting
  from listed
  where players > 0 or waiting
  order by (players >= capacity), waiting, greatest(5 - players, 0),
    players desc, created_at desc
  limit 50;
$$;
revoke all on function public.public_room_listing_v2(uuid) from public,anon,authenticated;
grant execute on function public.public_room_listing_v2(uuid) to service_role;
