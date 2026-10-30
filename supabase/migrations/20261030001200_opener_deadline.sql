create or replace function public.commit_accusation(p_room uuid, p_number integer, p_seat integer, p_target integer, p_next_seat integer, p_next_deadline timestamptz, p_discuss_deadline timestamptz) returns boolean
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  if exists(select 1 from public.room_players where room_id=p_room and seat=p_seat and kicked) then
    raise exception 'NOT_A_MEMBER' using errcode='P0001';
  end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'opening' or s.phase_number<>p_number or
    (s.public_data->>'openingSeat')::integer is distinct from p_seat or
    s.phase_ends_at is null or clock_timestamp()>s.phase_ends_at+interval '2 seconds'
    then return false; end if;
  perform public.set_public_path(p_room, array['openingAccusations', p_seat::text], to_jsonb(p_target));
  if p_next_seat is not null then
    update public.room_state set public_data=public_data || jsonb_build_object('openingSeat', p_next_seat),
      phase_ends_at=p_next_deadline, updated_at=now() where room_id=p_room;
  else
    update public.room_state set public_data=public_data || jsonb_build_object('openingSeat', null),
      phase='discuss', phase_ends_at=p_discuss_deadline, active_speaker=null, updated_at=now()
      where room_id=p_room;
  end if;
  return true;
end $$;
