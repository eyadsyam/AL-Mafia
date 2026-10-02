-- Striking a silent seat is one statement under the room lock, like a kick.
--
-- `remove_player` — the host's removal of a player gone three minutes — did
-- its work in five separate requests and checked none of them: the seat was
-- marked dead, then the whispers voided, then the elimination recorded, then
-- the roster read back for the win check. A roster read that failed came back
-- empty, the empty roster had no Mafia in it, and the town was declared the
-- winner (an outcome invented from a read that did not happen). A write that
-- failed halfway left a dead seat with no elimination record, or a record for
-- a seat still alive. And a seat struck during the night was recorded as a
-- day elimination.
--
-- This is the same neutral elimination `kick_member` applies to a removed
-- seat, with the silence test in front of it instead of the ban: the seat is
-- out, no role is named, whispers to it are voided, the elimination carries
-- the phase it happened in, then the win check — all or nothing.
create or replace function public.strike_absent_member(p_room uuid, p_host uuid, p_seat integer)
returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; p public.room_players%rowtype; s public.room_state%rowtype;
        mafia integer; town integer; outcome text;
begin
  select * into r from public.rooms where id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if r.host_id<>p_host then raise exception 'NOT_HOST'; end if;
  if r.status<>'playing' then raise exception 'PHASE_CLOSED'; end if;
  select * into p from public.room_players where room_id=p_room and seat=p_seat for update;
  if not found then raise exception 'BAD_REQUEST'; end if;
  -- The host is the one asking; a host who is here cannot be gone.
  if p.user_id=p_host then raise exception 'BAD_REQUEST'; end if;
  if not p.alive then raise exception 'ALREADY_OUT'; end if;
  -- Three minutes of silence, by the server's clock. A seat that is still
  -- beating — or went quiet less than three minutes ago — is still here.
  if p.connected and p.last_seen > now() - interval '3 minutes' then
    raise exception 'STILL_HERE';
  end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  update public.room_players set alive=false where room_id=p_room and user_id=p.user_id;
  -- Doc 09 §3.4: anything still in flight to a seat that is gone is voided,
  -- exactly as it is for a seat that died.
  update public.whisper_meta set voided=true where room_id=p_room and to_id=p.user_id and not voided;
  perform public.set_public_path(p_room, array['eliminations', p_seat::text],
    jsonb_build_object('phase', case when s.phase='night' then 'night' else 'day' end, 'number', s.phase_number));
  -- W8: the win check runs after the removal is applied.
  select count(*) filter (where role='mafia'), count(*) filter (where role<>'mafia')
    into mafia, town from public.room_players where room_id=p_room and alive;
  if mafia=0 then outcome:='town';
  elsif mafia>=town then outcome:='mafia';
  end if;
  if outcome is not null then
    perform public.merge_public_data(p_room, jsonb_build_object('outcome',outcome));
  end if;
  return jsonb_build_object('removed', p_seat, 'outcome', outcome);
end;
$$;
revoke all on function public.strike_absent_member(uuid,uuid,integer) from public, anon, authenticated;
grant execute on function public.strike_absent_member(uuid,uuid,integer) to service_role;
