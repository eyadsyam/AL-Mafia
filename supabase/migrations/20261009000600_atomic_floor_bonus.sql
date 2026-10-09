-- The phase guard, floor grant and bonus consumption share one row lock.
-- A repeated claim by its current holder preserves the original deadline.
create function public.claim_floor_with_tools(
  p_room uuid, p_user uuid, p_seconds int, p_phase text, p_number int
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state; me public.room_players; extra int; owner_seat int;
begin
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>p_phase or s.phase_number<>p_number
      or s.phase not in ('opening','confront','discuss','defense') then return false; end if;
  select * into me from public.room_players where room_id=p_room and user_id=p_user;
  if not found or not me.alive or me.kicked then return false; end if;
  if (s.public_data #>> '{morning,silencedSeat}')::int = me.seat then return false; end if;
  owner_seat := case s.phase
    when 'opening' then (s.public_data->>'openingSeat')::int
    when 'confront' then (s.public_data #>> '{confrontation,targetSeat}')::int
    when 'defense' then (s.public_data #>> '{confrontation,targetSeat}')::int
    else null end;
  if owner_seat is not null and owner_seat<>me.seat then return false; end if;
  if s.active_speaker is not null and s.speaker_until>now() then
    return s.active_speaker=p_user;
  end if;
  select coalesce(sum(case tool_code when 'extra_minute' then 45 else 30 end),0)
    into extra from public.room_tool_uses where room_id=p_room and user_id=p_user
      and phase_number=p_number and tool_code in ('extra_minute','objection')
      and consumed_at is null;
  update public.room_state set active_speaker=p_user,
    speaker_until=now()+make_interval(secs=>greatest(p_seconds,1)+extra),updated_at=now()
    where room_id=p_room;
  update public.room_tool_uses set consumed_at=now() where room_id=p_room and user_id=p_user
    and phase_number=p_number and tool_code in ('extra_minute','objection')
    and consumed_at is null;
  return true;
end $$;
revoke all on function public.claim_floor_with_tools(uuid,uuid,int,text,int) from public,anon,authenticated;
grant execute on function public.claim_floor_with_tools(uuid,uuid,int,text,int) to service_role;
