-- A night action or a vote may only be written into the phase it belongs to,
-- and a resolution may only commit the set of moves it actually counted.
--
-- The resolvers tally outside the transaction that commits the outcome. That
-- is fine as long as nothing can slip in between the tally and the commit, and
-- two things close that gap here:
--
--  * every write into `night_actions` / `votes` takes a share lock on the
--    room's state row and checks, under it, that the room is still in that
--    night / that ballot round. A write that lands after the resolution
--    committed sees the new phase and is refused as PHASE_CLOSED; a write that
--    lands before it holds the lock the resolution needs, so the resolution
--    waits and then sees the move.
--  * the resolver hands the commit a fingerprint of the rows it tallied. The
--    commit recomputes it under the room lock and refuses to publish an
--    outcome computed from a different set of moves. The driver re-reads and
--    tries again; nobody's move is dropped from the count.

create function public.guard_night_action_phase() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  select * into s from public.room_state where room_id=new.room_id for share;
  if not found or s.phase<>'night' or s.phase_number<>new.night then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_night_action_phase() from public,anon,authenticated;
drop trigger if exists night_action_phase_guard on public.night_actions;
create trigger night_action_phase_guard
  before insert or update on public.night_actions
  for each row execute function public.guard_night_action_phase();

create function public.guard_vote_phase() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state; current_round integer;
begin
  select * into s from public.room_state where room_id=new.room_id for share;
  if not found or s.phase<>'vote' or s.phase_number<>new.day then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  current_round := coalesce((s.public_data #>> '{revote,round}')::integer, 1);
  if new.round<>current_round then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_vote_phase() from public,anon,authenticated;
drop trigger if exists vote_phase_guard on public.votes;
create trigger vote_phase_guard
  before insert or update on public.votes
  for each row execute function public.guard_vote_phase();

-- The set of moves a night or a ballot round holds, as one string. The
-- resolver builds the same string from the rows it read (see `resolve_night`
-- and `resolve_vote`); uuid order and hex-string order agree, so both sides
-- sort the same way.
create function public.night_fingerprint(p_room uuid, p_night integer) returns text
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(string_agg(actor_id::text||'|'||action||'|'||coalesce(target_id::text,'-'), ';' order by actor_id), '')
  from public.night_actions where room_id=p_room and night=p_night;
$$;
create function public.vote_fingerprint(p_room uuid, p_day integer, p_round integer) returns text
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(string_agg(voter_id::text||'|'||coalesce(target_id::text,'-'), ';' order by voter_id), '')
  from public.votes where room_id=p_room and day=p_day and round=p_round;
$$;
revoke all on function public.night_fingerprint(uuid,integer) from public,anon,authenticated;
revoke all on function public.vote_fingerprint(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.night_fingerprint(uuid,integer) to service_role;
grant execute on function public.vote_fingerprint(uuid,integer,integer) to service_role;

drop function public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz);
create function public.commit_resolution(
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
  -- The moves this outcome was computed from must be the moves the room holds
  -- now. Anything else is a driver that read too early; it re-reads.
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
  return true;
end;
$$;
revoke all on function public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text)
  from public,anon,authenticated;
grant execute on function public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text)
  to service_role;
