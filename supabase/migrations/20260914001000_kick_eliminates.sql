-- A dealt seat the host removes is out of the match, at once and neutrally.
--
-- The ban and the `kicked` mark alone left a living seat nobody could act
-- for: the opening floor waited on it, the night and the ballot waited on
-- it, and the win check counted it as town for the rest of the match. The
-- attachment's `remove_player` is the neutral elimination — no role named,
-- nothing attributed, whispers to the seat voided, then a win check — and a
-- host who removes a player has decided the same thing without the three
-- silent minutes, because that player can never come back. So a mid-match
-- kick applies the same elimination, under the same room lock, in the same
-- statement as the ban. In the lobby nothing changes: no role, no seat to
-- eliminate, and `apply_match_deal` marks the row not alive when it deals.
create or replace function public.kick_member(p_room uuid, p_host uuid, p_seat integer) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms%rowtype; p public.room_players%rowtype; s public.room_state%rowtype;
        mafia integer; town integer;
begin
  select * into r from public.rooms where id=p_room and host_id=p_host for update;
  if not found then raise exception 'NOT_HOST'; end if;
  select * into p from public.room_players where room_id=p_room and seat=p_seat for update;
  if not found then raise exception 'BAD_REQUEST'; end if;
  if p.user_id=p_host then raise exception 'BAD_REQUEST'; end if;
  update public.rooms set banned_user_ids =
    case when p.user_id = any(banned_user_ids) then banned_user_ids
         else array_append(banned_user_ids, p.user_id) end
    where id=p_room;
  update public.room_players set status='left', connected=false, kicked=true
    where room_id=p_room and user_id=p.user_id;
  if r.status='playing' and p.alive and p.role is not null then
    select * into s from public.room_state where room_id=p_room for update;
    update public.room_players set alive=false where room_id=p_room and user_id=p.user_id;
    -- Doc 09 §3.4: anything still in flight to a seat that is gone is voided,
    -- exactly as it is for a seat that died.
    update public.whisper_meta set voided=true where room_id=p_room and to_id=p.user_id and not voided;
    perform public.set_public_path(p_room, array['eliminations', p_seat::text],
      jsonb_build_object('phase', case when s.phase='night' then 'night' else 'day' end, 'number', s.phase_number));
    -- W8: the win check runs after the removal is applied.
    select count(*) filter (where role='mafia'), count(*) filter (where role<>'mafia')
      into mafia, town from public.room_players where room_id=p_room and alive;
    if mafia=0 then
      perform public.merge_public_data(p_room, jsonb_build_object('outcome','town'));
    elsif mafia>=town then
      perform public.merge_public_data(p_room, jsonb_build_object('outcome','mafia'));
    end if;
  end if;
  return p.user_id;
end;
$$;
