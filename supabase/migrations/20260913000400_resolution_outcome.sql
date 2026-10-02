-- All resolution effects commit together, and only one driver can commit them.
create or replace function public.commit_resolution(
  p_room uuid, p_phase text, p_number integer, p_round integer,
  p_victim uuid, p_saved_seat integer, p_archive jsonb,
  p_patch jsonb, p_next text, p_deadline timestamptz
) returns boolean language plpgsql security definer
set search_path = public, pg_temp as $$
declare s public.room_state; victim_seat integer;
begin
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase <> p_phase or s.phase_number <> p_number then return false; end if;
  if p_phase='vote' and coalesce((s.public_data #>> '{revote,round}')::integer,1) <> p_round then
    return false;
  end if;
  if not ((p_phase='night' and p_next='morning') or
          (p_phase='vote' and p_next in ('vote','verdict'))) then
    raise exception 'invalid resolution transition';
  end if;
  if p_victim is not null then
    update public.room_players set alive=false
      where room_id=p_room and user_id=p_victim and alive returning seat into victim_seat;
    if not found then raise exception 'resolution victim unavailable'; end if;
    perform public.set_public_path(p_room, array['eliminations',victim_seat::text],
      jsonb_build_object('phase',case when p_phase='night' then 'night' else 'day' end,'number',p_number));
    update public.whisper_meta set voided=true where room_id=p_room and to_id=p_victim and not voided;
  end if;
  if p_phase='night' then
    perform public.record_night_resolution(p_room,p_number,p_saved_seat,p_archive);
  end if;
  update public.room_state set public_data=public_data || p_patch,
    phase=p_next, phase_ends_at=p_deadline, active_speaker=null, updated_at=now()
    where room_id=p_room;
  if p_phase='vote' and p_patch->>'outcome' is not null then
    update public.rooms set status='finished',ended_at=now() where id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz)
  to service_role;
