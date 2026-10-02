-- The public-room list is now the only way a player picks a room (quick match
-- no longer auto-seats anyone). Each card needs capacity and the real
-- minimum to start, from the same rules admission and start_match use:
--   * population = seats that are not kicked (as in join/quick-match/start);
--   * capacity   = maxPlayers when it is one of 5/8/10/15, otherwise 10;
--   * minimum    = 5, the start_match floor.
-- Rooms the viewer is banned from are not offered to them. Rooms with nobody
-- left in them are not offered to anyone: an empty lobby is not a room with
-- players, and the list must not suggest otherwise.
--
-- Joinable rooms nearest to starting come first; full rooms sink to the end.
-- Nothing private is returned: no user ids, names, seats or roles.
--
-- `public_rooms()` stays as it was, so an older browse_rooms function and older
-- clients keep working until the new function is deployed.
create or replace function public.public_room_listing(p_user uuid)
returns table (
  code text, title text, players int, capacity int, min_players int,
  voice boolean
)
language sql security definer set search_path=public,pg_temp stable as $$
  with listed as (
    select r.code, r.title, r.created_at,
      (select count(*) from public.room_players p
        where p.room_id=r.id and not p.kicked)::int as players,
      case when r.settings->>'maxPlayers' in ('5','8','10','15')
        then (r.settings->>'maxPlayers')::int else 10 end as capacity,
      coalesce((r.settings->>'voice')::boolean,true) as voice
    from public.rooms r
    where r.visibility='public' and r.status='lobby'
      and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
  )
  select code, title, players, capacity, 5, voice
  from listed
  where players > 0
  order by (players >= capacity), greatest(5 - players, 0), players desc,
    created_at desc
  limit 50;
$$;
revoke all on function public.public_room_listing(uuid)
  from public,anon,authenticated;
grant execute on function public.public_room_listing(uuid) to service_role;
