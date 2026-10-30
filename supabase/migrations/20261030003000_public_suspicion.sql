-- «أنا شاكك في» (owner, 2026-10-30): the online alternative to listening to
-- the table. A living, unsilenced player names one living other during the
-- discussion; it is public at once (room_state.public_data.suspicions, read by
-- every seat through the room's own realtime row) and the confrontation reads
-- it the next day. One per player per day, changeable until the vote opens.
-- Kept by seat, like every other public archive the generators read.

create or replace function public.set_public_suspicion(
  p_room uuid, p_user uuid, p_target_seat integer
) returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  st record;
  me record;
  day_key text;
  silenced integer;
  day_map jsonb;
begin
  select phase, phase_number, coalesce(public_data, '{}'::jsonb) as data
    into st from public.room_state where room_id = p_room for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if st.phase <> 'discuss' then raise exception 'PHASE_CLOSED'; end if;

  select seat, alive, coalesce(kicked, false) as kicked into me
    from public.room_players where room_id = p_room and user_id = p_user;
  if not found or me.kicked then raise exception 'NOT_A_MEMBER'; end if;
  if not me.alive then raise exception 'NOT_ALIVE'; end if;

  silenced := nullif(st.data -> 'morning' ->> 'silencedSeat', '')::integer;
  if silenced is not null and silenced = me.seat then raise exception 'SILENCED'; end if;

  if p_target_seat is not null then
    if p_target_seat = me.seat then raise exception 'BAD_REQUEST'; end if;
    perform 1 from public.room_players
      where room_id = p_room and seat = p_target_seat and alive and not coalesce(kicked, false);
    if not found then raise exception 'BAD_REQUEST'; end if;
  end if;

  day_key := st.phase_number::text;
  day_map := coalesce(st.data -> 'suspicions' -> day_key, '{}'::jsonb) - me.seat::text;
  if p_target_seat is not null then
    day_map := day_map || jsonb_build_object(me.seat::text, p_target_seat);
  end if;

  update public.room_state
     set public_data = st.data || jsonb_build_object(
       'suspicions',
       coalesce(st.data -> 'suspicions', '{}'::jsonb) || jsonb_build_object(day_key, day_map))
   where room_id = p_room;

  return jsonb_build_object('day', st.phase_number, 'suspicions', day_map);
end $$;
revoke all on function public.set_public_suspicion(uuid, uuid, integer) from public, anon, authenticated;
grant execute on function public.set_public_suspicion(uuid, uuid, integer) to service_role;
