-- A kick/removal can change the winner without changing any submitted move.
-- Compare the population as well as the actions while holding the room lock.
create or replace function public.roster_fingerprint(p_room uuid) returns text
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(string_agg(user_id::text||'|'||seat::text||'|'||case when alive then '1' else '0' end,
    ';' order by user_id), '') from public.room_players where room_id=p_room;
$$;
revoke all on function public.roster_fingerprint(uuid) from public,anon,authenticated;
grant execute on function public.roster_fingerprint(uuid) to service_role;

create or replace function public.night_fingerprint(p_room uuid, p_night integer) returns text
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(string_agg(actor_id::text||'|'||action||'|'||coalesce(target_id::text,'-'), ';' order by actor_id), '')
    ||'#roster:'||public.roster_fingerprint(p_room)
  from public.night_actions where room_id=p_room and night=p_night;
$$;
create or replace function public.vote_fingerprint(p_room uuid, p_day integer, p_round integer) returns text
language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(string_agg(voter_id::text||'|'||coalesce(target_id::text,'-'), ';' order by voter_id), '')
    ||'#roster:'||public.roster_fingerprint(p_room)
  from public.votes where room_id=p_room and day=p_day and round=p_round;
$$;
revoke all on function public.night_fingerprint(uuid,integer) from public,anon,authenticated;
revoke all on function public.vote_fingerprint(uuid,integer,integer) from public,anon,authenticated;
grant execute on function public.night_fingerprint(uuid,integer) to service_role;
grant execute on function public.vote_fingerprint(uuid,integer,integer) to service_role;
