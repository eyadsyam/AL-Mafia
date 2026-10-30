-- Explicit lobby departures use the same live-heir rule as the departure
-- trigger. If no live heir exists, retain the previous seated fallback so a
-- room with remaining seats always has a host.
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
  update public.room_players set seat = -(seat - 1) - 1 where room_id = p_room and seat > left_seat;
  update public.room_players set seat = -seat - 1 where room_id = p_room and seat < 0;
  update public.rooms r set host_id = coalesce(
      (select user_id from public.room_players
        where room_id = p_room and status = 'connected' and connected and not kicked
          and last_seen > now() - interval '30 seconds'
        order by seat limit 1),
      (select user_id from public.room_players
        where room_id = p_room and not kicked order by seat limit 1),
      r.host_id)
    where r.id = p_room and r.host_id = p_user;
  return 'left';
end;
$$;
revoke all on function public.leave_room(uuid, uuid) from public, anon, authenticated;
grant execute on function public.leave_room(uuid, uuid) to service_role;
