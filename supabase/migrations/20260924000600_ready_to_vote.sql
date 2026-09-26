-- «جاهزين للتصويت» — the living end the discussion together (owner, 2026-09-24).
--
-- Once the match starts nobody drives it, the host included, so a discussion
-- that has plainly finished used to sit out its whole clock. Each living
-- player may now say they are ready; when every living player has, the ballot
-- opens. The clock still ends it for a room that never agrees.
--
-- The readiness is public (it is a fact about the table, not about a role) and
-- lives in `room_state.public_data.readyToVote` as {number, seats}: keyed by
-- the discussion's `phase_number`, so a stale set from an earlier day is read
-- as empty without anything having to clear it.
--
-- One function, under the room_state row lock, so two players tapping in the
-- same instant cannot overwrite each other's seat — a read-modify-write from
-- an Edge Function could.

create or replace function public.mark_ready_to_vote(
  p_room uuid, p_user uuid, p_ready boolean
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  s public.room_state;
  me public.room_players;
  ready integer[];
  living integer[];
begin
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'discuss' then
    raise exception 'PHASE_CLOSED' using errcode='P0001';
  end if;
  select * into me from public.room_players where room_id=p_room and user_id=p_user;
  if not found or me.kicked then
    raise exception 'NOT_A_MEMBER' using errcode='P0001';
  end if;
  if not me.alive then
    raise exception 'NOT_ALIVE' using errcode='P0001';
  end if;

  living := array(select seat from public.room_players
    where room_id=p_room and alive and not kicked order by seat);
  ready := case
    when (s.public_data #>> '{readyToVote,number}')::integer = s.phase_number
      then array(select (jsonb_array_elements_text(
        coalesce(s.public_data #> '{readyToVote,seats}', '[]'::jsonb)))::integer)
    else '{}'::integer[]
  end;
  if p_ready then
    ready := array_append(array_remove(ready, me.seat), me.seat);
  else
    ready := array_remove(ready, me.seat);
  end if;
  -- Only living seats count, in seat order: a seat that died or was removed
  -- since it said ready stops counting the moment it stops being alive.
  ready := array(select x from unnest(ready) x where x = any(living) order by x);

  update public.room_state
    set public_data = public_data || jsonb_build_object(
      'readyToVote', jsonb_build_object('number', s.phase_number, 'seats', to_jsonb(ready)))
    where room_id=p_room;

  return jsonb_build_object(
    'seats', to_jsonb(ready),
    'living', cardinality(living),
    'everyone', cardinality(ready) >= cardinality(living) and cardinality(living) > 0,
    'number', s.phase_number,
    'deadline', s.phase_ends_at
  );
end;
$$;
revoke all on function public.mark_ready_to_vote(uuid, uuid, boolean) from public,anon,authenticated;
grant execute on function public.mark_ready_to_vote(uuid, uuid, boolean) to service_role;
