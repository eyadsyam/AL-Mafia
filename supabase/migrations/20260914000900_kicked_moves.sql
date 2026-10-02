-- A removed seat cannot move. `kick_member` keeps the row (the ban and the
-- removed client's own notification live on it) and does not eliminate the
-- seat (`remove_player` is the neutral elimination, after three silent
-- minutes), but nothing stopped that row from acting: a kicked player could
-- still cast a ballot or a night move into the match it was banned from, and
-- `resolve_*` would count it. The guards that already hold the phase now
-- hold the membership too, on the table itself, so no function path can
-- let a banned row through.
create or replace function public.guard_night_action_phase() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  select * into s from public.room_state where room_id=new.room_id for share;
  if not found or s.phase<>'night' or s.phase_number<>new.night then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  if exists(select 1 from public.room_players where room_id=new.room_id and user_id=new.actor_id and kicked) then
    raise exception 'NOT_A_MEMBER' using errcode='P0001';
  end if;
  return new;
end;
$$;

create or replace function public.guard_vote_phase() returns trigger
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
  if exists(select 1 from public.room_players where room_id=new.room_id and user_id=new.voter_id and kicked) then
    raise exception 'NOT_A_MEMBER' using errcode='P0001';
  end if;
  return new;
end;
$$;

-- The opening accusation names its seat; a removed seat's name is refused
-- the same way, under the same lock.
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
    (s.public_data->>'openingSeat')::integer is distinct from p_seat then return false; end if;
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
end;
$$;
