-- A kick is one statement: the ban and the seat's `kicked` mark land together
-- under the room lock, and the ban is appended to whatever the list already
-- holds. `kick_player` used to read the list, add one id and write it back
-- unchecked — a read that failed wrote back a list of one, un-banning every
-- player removed before, and two kicks in the same instant lost one of them.
create function public.kick_member(p_room uuid, p_host uuid, p_seat integer) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid;
begin
  perform 1 from public.rooms where id=p_room and host_id=p_host for update;
  if not found then raise exception 'NOT_HOST'; end if;
  select user_id into target from public.room_players where room_id=p_room and seat=p_seat;
  if not found then raise exception 'BAD_REQUEST'; end if;
  if target=p_host then raise exception 'BAD_REQUEST'; end if;
  update public.rooms set banned_user_ids =
    case when target = any(banned_user_ids) then banned_user_ids
         else array_append(banned_user_ids, target) end
    where id=p_room;
  update public.room_players set status='left', connected=false, kicked=true
    where room_id=p_room and user_id=target;
  return target;
end;
$$;
revoke all on function public.kick_member(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.kick_member(uuid,uuid,integer) to service_role;
