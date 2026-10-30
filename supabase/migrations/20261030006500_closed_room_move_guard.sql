-- A deliberate host leave finishes the room without changing its phase row.
-- Take the room lock first, as resolution commits do, so a move racing that
-- leave is either accepted before closure or refused afterwards.
create or replace function public.guard_night_action_phase() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  perform 1 from public.rooms where id=new.room_id and status='playing' for share;
  if not found then raise exception 'PHASE_CLOSED' using errcode='P0001'; end if;
  select * into s from public.room_state where room_id=new.room_id for share;
  if not found or s.phase<>'night' or s.phase_number<>new.night then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  if exists(select 1 from public.room_players
      where room_id=new.room_id and user_id=new.actor_id and kicked) then
    raise exception 'NOT_A_MEMBER' using errcode='P0001';
  end if;
  return new;
end;
$$;

create or replace function public.guard_vote_phase() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state; current_round integer; target_seat integer;
begin
  perform 1 from public.rooms where id=new.room_id and status='playing' for share;
  if not found then raise exception 'PHASE_CLOSED' using errcode='P0001'; end if;
  select * into s from public.room_state where room_id=new.room_id for share;
  if not found or s.phase<>'vote' or s.phase_number<>new.day then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  current_round := coalesce((s.public_data #>> '{revote,round}')::integer, 1);
  if new.round<>current_round then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  if exists(select 1 from public.room_players
      where room_id=new.room_id and user_id=new.voter_id and kicked) then
    raise exception 'NOT_A_MEMBER' using errcode='P0001';
  end if;
  if current_round>1 and new.target_id is not null then
    select seat into target_seat from public.room_players
      where room_id=new.room_id and user_id=new.target_id;
    if target_seat is null or not coalesce(
      (s.public_data #> '{revote,tiedSeats}') @> jsonb_build_array(target_seat), false) then
      raise exception 'INVALID_REVOTE_TARGET' using errcode='P0001';
    end if;
  end if;
  return new;
end;
$$;
