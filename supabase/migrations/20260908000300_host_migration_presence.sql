-- Task 5 — the room survives its host, and now it notices immediately.
--
-- `migrate_host` measured liveness as `connected and last_seen > now() - 30s`,
-- which meant a host who *said* they were leaving still held the room for
-- thirty seconds while everybody watched a button nobody could press. With
-- three presence states the same question has a better answer: a host who is
-- `left` is gone now, and only a host who went quiet without saying so needs
-- the clock.
--
-- The heir is unchanged in spirit and sharper in fact: the lowest-seat player
-- whose status is `connected`. `away` is not eligible — somebody who stepped
-- out for ten seconds should not come back holding the room — and the cascade
-- of O2 falls out of the ordering exactly as it did before.

create or replace function public.migrate_host(
  p_room     uuid,
  p_claimant uuid,
  p_timeout  interval default interval '30 seconds'
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_host uuid;
  host_live    boolean;
  heir         uuid;
begin
  select host_id into current_host
    from public.rooms
   where id = p_room
     and status <> 'finished'
   for update;

  if current_host is null then
    return null;
  end if;

  select (status <> 'left' and connected and last_seen > now() - p_timeout)
    into host_live
    from public.room_players
   where room_id = p_room and user_id = current_host;

  if coalesce(host_live, false) then
    return current_host;
  end if;

  select user_id into heir
    from public.room_players
   where room_id = p_room
     and status = 'connected'
     and connected
     and last_seen > now() - p_timeout
   order by seat
   limit 1;

  if heir is null then
    return current_host;
  end if;

  if heir <> p_claimant then
    return heir;
  end if;

  update public.rooms set host_id = heir where id = p_room;
  return heir;
end;
$$;

revoke all on function public.migrate_host(uuid, uuid, interval)
  from public, anon, authenticated;
grant execute on function public.migrate_host(uuid, uuid, interval) to service_role;
