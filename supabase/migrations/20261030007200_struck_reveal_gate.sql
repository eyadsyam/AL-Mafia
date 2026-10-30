-- Re-check discussion readiness under the same room_state lock that opens the
-- ballot. mark_ready_to_vote takes this lock too, so an unready tap cannot
-- race between open_phase's read and the phase transition.
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
  if p_require_all_seen and p_expected='discuss' and p_next='vote' then
    if (s.public_data #>> '{readyToVote,number}')::integer is distinct from p_number
      or exists (
        select 1 from public.room_players p
        where p.room_id=p_room and p.alive and not p.kicked
          and not (coalesce(s.public_data #> '{readyToVote,seats}', '[]'::jsonb) @> to_jsonb(p.seat))
      ) then return false; end if;
  elsif p_require_all_seen and exists (
    select 1 from public.room_players where room_id=p_room and alive and not kicked and not saw_role
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
