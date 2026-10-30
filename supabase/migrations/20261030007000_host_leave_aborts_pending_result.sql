-- A resolved night/vote sets rooms.status=finished before the public result
-- opens. A host leaving during that gap still closes the table for everybody.
create or replace function public.leave_room(p_room uuid, p_user uuid) returns text
language plpgsql security definer set search_path=public,pg_temp as $$
declare room_status text; room_host uuid; room_phase text; left_seat int;
begin
  select status,host_id into room_status,room_host from public.rooms
    where id=p_room for update;
  if room_status is null then return 'ROOM_NOT_FOUND'; end if;
  select phase into room_phase from public.room_state where room_id=p_room;
  if room_host=p_user and (
      room_status='playing' or
      (room_status='finished' and room_phase<>'result') or
      (room_status='lobby' and exists(
        select 1 from public.room_players where room_id=p_room
          and user_id<>p_user and not kicked))) then
    if not exists(select 1 from public.room_players
        where room_id=p_room and user_id=p_user) then return 'NOT_A_MEMBER'; end if;
    update public.rooms set status='finished',ended_at=coalesce(ended_at,now())
      where id=p_room;
    -- The resolver may have published a pending winner. It is no longer a
    -- completed match, and the client uses the absence of outcome to leave.
    update public.room_state set public_data=public_data-'outcome'-'standings',
      phase_ends_at=null where room_id=p_room;
    update public.room_players set connected=false,status='left',last_seen=now()
      where room_id=p_room and user_id=p_user;
    return 'closed';
  end if;
  if room_status<>'lobby' then
    update public.room_players set connected=false,status='left',last_seen=now()
      where room_id=p_room and user_id=p_user;
    return 'disconnected';
  end if;
  select seat into left_seat from public.room_players
    where room_id=p_room and user_id=p_user;
  if left_seat is null then return 'NOT_A_MEMBER'; end if;
  delete from public.room_players where room_id=p_room and user_id=p_user;
  update public.room_players set seat=-(seat-1)-1
    where room_id=p_room and seat>left_seat;
  update public.room_players set seat=-seat-1
    where room_id=p_room and seat<0;
  return 'left';
end;
$$;
revoke all on function public.leave_room(uuid,uuid) from public,anon,authenticated;
grant execute on function public.leave_room(uuid,uuid) to service_role;
