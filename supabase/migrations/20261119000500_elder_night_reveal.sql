-- The Elder reveals himself at night (owner, 2026-11-19).
-- 1) night_actions may hold a 'reveal' row (no target), written by
--    submit_night_action for the living, unrevealed Elder only.
-- 2) the morning commit marks him revealed (the same marker reveal_elder_role
--    writes: public_data.elderRevealedSeats) when he is alive after the night's
--    deaths, and publishes morning.elderRevealedSeat. The key exists only on a
--    morning that has a reveal: a payload that always carried it would tell
--    every table whether the Elder is in the match (doc 05). `morning` is
--    replaced whole each night, so no earlier morning's key survives.
alter table public.night_actions
  drop constraint if exists night_actions_action_valid;
alter table public.night_actions
  add constraint night_actions_action_valid check (
    action in ('kill','silence','protect','investigate','suspect','skip','reveal')
  );
alter table public.night_actions
  drop constraint if exists night_actions_target_matches_action;
alter table public.night_actions
  add constraint night_actions_target_matches_action check (
    (action in ('skip','reveal')) = (target_id is null)
  );

create or replace function public.commit_night_roles_resolution(
  p_room uuid, p_number integer, p_victims uuid[], p_saved_seat integer,
  p_archive jsonb, p_patch jsonb, p_next text, p_deadline timestamptz,
  p_fingerprint text
) returns boolean language plpgsql security definer
set search_path=public,pg_temp as $$
declare
  s public.room_state;
  victim uuid;
  victim_seat integer;
  reveal_seat integer;
  seats jsonb;
  patched jsonb;
begin
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'night' or s.phase_number<>p_number or p_next<>'morning' then
    return false;
  end if;
  if p_fingerprint is distinct from public.night_fingerprint(p_room,p_number) then
    return false;
  end if;

  -- Reject a stale tally after a removal has decided the match.
  if s.public_data->>'outcome' in ('mafia','town') and
    (p_patch->>'outcome' is distinct from s.public_data->>'outcome'
      or cardinality(coalesce(p_victims,array[]::uuid[]))>0) then return false; end if;
  foreach victim in array coalesce(p_victims, array[]::uuid[]) loop
    update public.room_players set alive=false
      where room_id=p_room and user_id=victim and alive
      returning seat into victim_seat;
    if not found then raise exception 'resolution victim unavailable'; end if;
    perform public.set_public_path(
      p_room, array['eliminations',victim_seat::text],
      jsonb_build_object('phase','night','number',p_number)
    );
    update public.whisper_meta set voided=true
      where room_id=p_room and to_id=victim and not voided;
  end loop;

  -- The Elder's night choice: only if he is alive once the deaths are settled
  -- and is not already revealed. A dead Elder reveals nothing.
  seats := coalesce(s.public_data->'elderRevealedSeats','[]'::jsonb);
  select p.seat into reveal_seat
    from public.night_actions a
    join public.room_players p on p.room_id=a.room_id and p.user_id=a.actor_id
    where a.room_id=p_room and a.night=p_number and a.action='reveal'
      and p.alive and p.role='elder'
    limit 1;
  if reveal_seat is not null and seats @> jsonb_build_array(reveal_seat) then
    reveal_seat := null;
  end if;

  perform public.record_night_resolution(
    p_room,p_number,p_saved_seat,p_archive
  );
  patched := p_patch;
  if reveal_seat is not null then
    patched := jsonb_set(
      patched, '{morning,elderRevealedSeat}', to_jsonb(reveal_seat), true
    );
  end if;
  update public.room_state set
    public_data=public_data||patched,
    phase='morning',phase_ends_at=p_deadline,active_speaker=null,updated_at=now()
    where room_id=p_room;
  if reveal_seat is not null then
    update public.room_state set
      public_data=jsonb_set(public_data,'{elderRevealedSeats}',
        seats||jsonb_build_array(reveal_seat),true)
      where room_id=p_room;
  end if;
  if p_patch->>'outcome' is not null then
    update public.rooms set status='finished',ended_at=now() where id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_night_roles_resolution(uuid,integer,uuid[],integer,jsonb,jsonb,text,timestamptz,text) from public,anon,authenticated;
grant execute on function public.commit_night_roles_resolution(uuid,integer,uuid[],integer,jsonb,jsonb,text,timestamptz,text) to service_role;
