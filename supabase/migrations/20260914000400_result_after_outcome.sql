-- Two things `atomic_phase_open` and `action_epoch` got wrong against the
-- room lifecycle `resolution_outcome` had already established:
--
--  * a ballot that decides the match marks the room `finished` at once, so a
--    table nobody drives to the result screen is still a finished room to the
--    public list and the purge (`resolution_outcome`). The fingerprinted
--    `commit_resolution` dropped that line; it is back.
--  * `commit_phase_open` insisted on `status='playing'` for every move, which
--    made the verdict -> result move impossible on exactly those rooms. The
--    move into `result` is now allowed from a finished room too — but only
--    one that holds an outcome. A room that was *closed* has none, and stays
--    where it is.
create or replace function public.commit_resolution(
  p_room uuid, p_phase text, p_number integer, p_round integer,
  p_victim uuid, p_saved_seat integer, p_archive jsonb,
  p_patch jsonb, p_next text, p_deadline timestamptz, p_fingerprint text
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
  if p_fingerprint is distinct from (case when p_phase='night'
      then public.night_fingerprint(p_room,p_number)
      else public.vote_fingerprint(p_room,p_number,p_round) end) then
    return false;
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

create or replace function public.commit_phase_open(
  p_room uuid, p_expected text, p_number integer, p_expected_deadline timestamptz,
  p_next text, p_next_number integer, p_deadline timestamptz, p_patch jsonb,
  p_require_all_seen boolean default false
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  if p_next <> 'result' and p_patch ? 'standings' then
    raise exception 'standings may only be published with the result';
  end if;
  perform 1 from public.rooms where id=p_room
    and (status='playing' or (p_next='result' and status='finished')) for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>p_expected or s.phase_number<>p_number or
    s.phase_ends_at is distinct from p_expected_deadline then return false; end if;
  if p_next='result' and s.public_data->>'outcome' is null then return false; end if;
  if p_require_all_seen and exists (
    select 1 from public.room_players where room_id=p_room and not saw_role
  ) then return false; end if;
  update public.room_state set phase=p_next,phase_number=p_next_number,
    phase_ends_at=p_deadline,public_data=public_data || p_patch,
    active_speaker=null,updated_at=now() where room_id=p_room;
  if p_next='result' then
    update public.rooms set status='finished',ended_at=coalesce(ended_at,now()) where id=p_room;
  end if;
  return true;
end;
$$;
