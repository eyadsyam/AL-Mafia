-- Owner, 2026-10-30: a room belongs to its host, and a match is its players.
--   * A host who is gone (left, or silent past the 90-second presence limit) ends
--     the room for everybody, with no result and no reward. Nobody inherits it.
--   * Any other seat silent or left past that limit is struck automatically: a
--     neutral removal, no role announced, then the win check, exactly what the
--     host's own «خرج» button does (`strike_absent_member`). A match decided by
--     it pays nothing, as a decided removal already does.

create or replace function public.handover_departed_host() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  target_room uuid := old.room_id;
  owner_id uuid;
  room_status text;
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
  if owner_id = old.user_id and (room_status = 'playing' or exists(
      select 1 from public.room_players
       where room_id = target_room and user_id <> old.user_id and not kicked)) then
    update public.rooms set status = 'finished', ended_at = now() where id = target_room;
  end if;
  return null;
end;
$$;

-- Nobody claims a room any more. Still answers an older client's `claim_host`
-- with who the host is, so it stays where it is until the room closes.
create or replace function public.migrate_host(
  p_room     uuid,
  p_claimant uuid,
  p_timeout  interval default interval '30 seconds'
) returns uuid
language plpgsql security definer set search_path = public as $$
declare current_host uuid;
begin
  select host_id into current_host from public.rooms
   where id = p_room and status <> 'finished';
  return current_host;
end;
$$;
revoke all on function public.migrate_host(uuid, uuid, interval) from public, anon, authenticated;
grant execute on function public.migrate_host(uuid, uuid, interval) to service_role;

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

  -- A match does not wait for a seat nobody is in. One that said it was leaving
  -- has the same limit, so a mistaken exit can still come back.
  for departed in
    select p.room_id, p.seat, r.host_id from public.room_players p
      join public.rooms r on r.id = p.room_id
      join public.room_state s on s.room_id = p.room_id
     where r.status = 'playing' and p.status = 'left' and p.alive and not p.kicked
       and p.role is not null and p.user_id <> r.host_id
       and s.public_data->>'outcome' is null
       and public.heard_at(p.room_id, p.user_id, p.last_seen) < now() - interval '90 seconds'
     order by p.room_id, p.seat
  loop
    -- One room's refusal must not stop the sweep for the others.
    begin
      perform public.strike_absent_member(departed.room_id, departed.host_id, departed.seat);
    exception when others then
      raise warning 'strike skipped for a seat: %', sqlerrm;
    end;
  end loop;

  return changed;
end;
$$;
revoke all on function public.age_presence() from public, anon, authenticated;
