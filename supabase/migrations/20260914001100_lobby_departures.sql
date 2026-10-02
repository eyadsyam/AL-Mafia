-- A lobby seat that went quiet is a departure, not a ghost.
--
-- Presence ageing marked a silent lobby row `left` and stopped there. The
-- row still counted at the door (`join_room_atomic`), in the public list and
-- in the lobby's own «N / M» line, while the lobby hid the seat — a tab
-- closed on a lobby held a seat for a day, and the host read "2 / 5" over a
-- single ring (build/review/v1-07-guest-tab-closed.jpg). Mid-match a left
-- seat is kept for its return; in the lobby nothing has been dealt against
-- it, and `leave_room` already knows how to give it up: the row goes, the
-- seats re-pack, the host hands over. Ageing now takes that path for lobby
-- rows. Removed (kicked) rows are not departures and stay where they are.
--
-- Three smaller things found beside it: the seat re-pack tripped its own
-- unique index once a removed row sat between the leaver and the end of the
-- table; a host leaving its lobby could hand the room to a removed row
-- (lowest seat, kicked or not); and a lobby whose only remaining rows were
-- removed ones was never deleted, so it sat in the public list with nobody
-- in it.
create or replace function public.leave_room(p_room uuid, p_user uuid) returns text
language plpgsql security definer set search_path=public,pg_temp as $$
declare room_status text; left_seat int;
begin
  select status into room_status from public.rooms where id = p_room for update;
  if room_status is null then return 'ROOM_NOT_FOUND'; end if;
  if room_status <> 'lobby' then
    update public.room_players set connected = false, status = 'left', last_seen = now()
      where room_id = p_room and user_id = p_user;
    return 'disconnected';
  end if;
  select seat into left_seat from public.room_players where room_id = p_room and user_id = p_user;
  if left_seat is null then return 'NOT_A_MEMBER'; end if;
  delete from public.room_players where room_id = p_room and user_id = p_user;
  -- Seat order is the night pass and the «اسم واحد» order, so a hole in it
  -- would put an empty chair in both. Two steps, because the unique index on
  -- (room, seat) is checked row by row and a one-step shift lands on a seat
  -- its neighbour has not vacated yet whenever the rows are not visited in
  -- seat order — which they are not once a row has been updated (a removed
  -- row, say) and moved on the heap.
  update public.room_players set seat = -(seat - 1) - 1 where room_id = p_room and seat > left_seat;
  update public.room_players set seat = -seat - 1 where room_id = p_room and seat < 0;
  -- The host leaving its own lobby hands the room to the lowest *seated* row.
  update public.rooms r set host_id = coalesce(
      (select user_id from public.room_players where room_id = p_room and not kicked order by seat limit 1),
      r.host_id)
    where r.id = p_room and r.host_id = p_user;
  return 'left';
end;
$$;
revoke all on function public.leave_room(uuid, uuid) from public, anon, authenticated;
grant execute on function public.leave_room(uuid, uuid) to service_role;

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
        and last_seen > now() - interval '30 seconds'
      order by seat limit 1;
    if heir is not null then
      update public.rooms set host_id = heir where id = target_room;
    end if;
  end if;
  return null;
end;
$$;

create or replace function public.age_presence() returns integer
language plpgsql security definer set search_path = public, pg_temp as $$
declare changed integer; departed record;
begin
  update public.room_players p set status = 'away'
    from public.rooms r
   where r.id = p.room_id and r.status <> 'finished'
     and p.status = 'connected' and p.last_seen < now() - interval '25 seconds';

  with gone as (
    update public.room_players p set status = 'left', connected = false
      from public.rooms r
     where r.id = p.room_id and r.status <> 'finished'
       and p.status <> 'left' and p.last_seen < now() - interval '90 seconds'
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
