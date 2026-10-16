-- A decided result stands when a host subsequently removes a seat. The kick
-- implementation is split across the public wrapper and its pre-economy body.

create or replace function public.kick_member_pre_economy(p_room uuid, p_host uuid, p_seat integer) returns uuid
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
    -- W8: the win check runs after the removal is applied, if still undecided.
    if s.public_data->>'outcome' is null then
      select count(*) filter (where public.is_mafia_team(role)), count(*) filter (where not public.is_mafia_team(role))
        into mafia, town from public.room_players where room_id=p_room and alive;
      if mafia=0 then
        perform public.merge_public_data(p_room, jsonb_build_object('outcome','town'));
      elsif mafia>=town then
        perform public.merge_public_data(p_room, jsonb_build_object('outcome','mafia'));
      end if;
    end if;
  end if;
  return p.user_id;
end;
$$;

revoke all on function public.kick_member_pre_economy(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.kick_member_pre_economy(uuid,uuid,integer) to service_role;

create or replace function public.kick_member(p_room uuid,p_host uuid,p_seat integer)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare playing boolean; removed uuid; prior_outcome text;
begin
  -- The same room lock used by the removal protects this before-value.
  perform 1 from public.rooms where id=p_room for update;
  select public_data->>'outcome' into prior_outcome
    from public.room_state where room_id=p_room for update;
  select r.status='playing' and p.alive and p.role is not null into playing
    from public.rooms r join public.room_players p on p.room_id=r.id
    where r.id=p_room and p.seat=p_seat;
  removed:=public.kick_member_pre_economy(p_room,p_host,p_seat);
  if playing and prior_outcome is null and exists(select 1 from public.room_state
      where room_id=p_room and public_data->>'outcome' in ('mafia','town')) then
    insert into public.economy_void_rooms(room_id) values(p_room) on conflict do nothing;
  end if;
  return removed;
end $$;

revoke all on function public.kick_member(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.kick_member(uuid,uuid,integer) to service_role;

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
  -- beating -- or went quiet less than three minutes ago -- is still here.
  if p.connected and public.heard_at(p.room_id, p.user_id, p.last_seen) > now() - interval '3 minutes' then
    raise exception 'STILL_HERE';
  end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  outcome := s.public_data->>'outcome';
  update public.room_players set alive=false where room_id=p_room and user_id=p.user_id;
  -- Doc 09 §3.4: anything still in flight to a seat that is gone is voided,
  -- exactly as it is for a seat that died.
  update public.whisper_meta set voided=true where room_id=p_room and to_id=p.user_id and not voided;
  perform public.set_public_path(p_room, array['eliminations', p_seat::text],
    jsonb_build_object('phase', case when s.phase='night' then 'night' else 'day' end, 'number', s.phase_number));
  -- W8: the win check runs after the removal is applied, if still undecided.
  if outcome is null then
    select count(*) filter (where public.is_mafia_team(role)), count(*) filter (where not public.is_mafia_team(role))
      into mafia, town from public.room_players where room_id=p_room and alive;
    if mafia=0 then outcome:='town';
    elsif mafia>=town then outcome:='mafia';
    end if;
    if outcome is not null then
      perform public.merge_public_data(p_room, jsonb_build_object('outcome',outcome));
      -- RL16 / D37: a strike that decides the match voids the rewards, as a kick
      -- does (`kick_member`, 20261009002200): the host cannot end a match by
      -- striking a seat and still pay out what that match would have earned.
      if p.role is not null then
        insert into public.economy_void_rooms(room_id) values(p_room) on conflict do nothing;
      end if;
    end if;
  end if;
  return jsonb_build_object('removed', p_seat, 'outcome', outcome);
end;
$$;

revoke all on function public.strike_absent_member(uuid,uuid,integer) from public, anon, authenticated;
grant execute on function public.strike_absent_member(uuid,uuid,integer) to service_role;
