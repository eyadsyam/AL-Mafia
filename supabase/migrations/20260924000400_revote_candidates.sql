-- Preserve the existing phase/round/member guards and restrict every ballot
-- write to the server's tied candidates while holding the same state lock.
create or replace function public.guard_vote_phase() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state; current_round integer; target_seat integer;
begin
  select * into s from public.room_state where room_id=new.room_id for share;
  if not found or s.phase<>'vote' or s.phase_number<>new.day then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  current_round := coalesce((s.public_data #>> '{revote,round}')::integer,1);
  if new.round<>current_round then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  if exists(select 1 from public.room_players where room_id=new.room_id
      and user_id=new.voter_id and kicked) then
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
revoke all on function public.guard_vote_phase() from public,anon,authenticated;
