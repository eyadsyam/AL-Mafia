-- Task 3 — presence is three states, not a boolean.
--
-- `connected` was doing two jobs badly. A player who backgrounded the app to
-- read a message and a player who closed it and went to bed were the same row,
-- and both of them kept a seat on the table with an avatar in it — which is
-- how a room ends up arguing with somebody who is not there.
--
-- The three states are aged by the clock, in one place, on the server:
--
--   heartbeat (every 10s)            → connected
--   last_seen older than 25 seconds  → away
--   last_seen older than 90 seconds  → left
--
-- The client also writes the state directly on a lifecycle change, because a
-- player who has just backgrounded the app should not wait 25 seconds to look
-- away — but the ageing below is what makes it true for a client that crashed
-- rather than closed, and that one cannot report anything.
--
-- `connected` stays, unchanged, and is not derived from this: host migration
-- (O1/O2) and `archive_abandoned_rooms` (O3) both read it, and re-pointing
-- them at a column that ages on a different clock is a change to who inherits
-- a room, which is not what this task is.

alter table public.room_players
  add column if not exists status text not null default 'connected';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'room_players_status_valid'
  ) then
    alter table public.room_players
      add constraint room_players_status_valid
      check (status in ('connected', 'away', 'left'));
  end if;
end
$$;

create index if not exists room_players_status
  on public.room_players (room_id, status);

create or replace view public.room_players_public
with (security_invoker = true) as
select room_id, user_id, name, seat, alive, connected, last_seen, gender,
       saw_role, status
from public.room_players;

grant select (status) on public.room_players to authenticated;
grant select on public.room_players_public to authenticated;

-- ── the ageing job ───────────────────────────────────────────────────────
--
-- Two statements rather than one `case`, so the second can overtake the first:
-- a row that has been silent for two minutes becomes `left` in the same pass
-- that would otherwise have made it `away`.
--
-- Only live rooms are touched. A finished room's roster is a record of who
-- played, and ageing it would rewrite that record every fifteen seconds for the
-- twenty-four hours before it is purged.

create or replace function public.age_presence()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  update public.room_players p
     set status = 'away'
    from public.rooms r
   where r.id = p.room_id
     and r.status <> 'finished'
     and p.status = 'connected'
     and p.last_seen < now() - interval '25 seconds';

  with gone as (
    update public.room_players p
       set status = 'left', connected = false
      from public.rooms r
     where r.id = p.room_id
       and r.status <> 'finished'
       and p.status <> 'left'
       and p.last_seen < now() - interval '90 seconds'
    returning 1
  )
  select count(*) into changed from gone;

  return changed;
end;
$$;

revoke all on function public.age_presence() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema extensions;

    perform cron.unschedule('age-presence')
      where exists (select 1 from cron.job where jobname = 'age-presence');
    -- Sub-minute schedules are pg_cron's interval syntax, not cron syntax.
    perform cron.schedule(
      'age-presence',
      '15 seconds',
      $cron$ select public.age_presence(); $cron$
    );
  end if;
end
$$;

-- ── leaving says so ──────────────────────────────────────────────────────
--
-- Mid-match a departure is still only a disconnection — the seat is the
-- identity claim and the role was dealt against it, so the row stays and the
-- player may come back to it (O4). What changes is that the room can now see
-- the difference between "went quiet" and "said goodbye".

create or replace function public.leave_room(
  p_room uuid,
  p_user uuid
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  room_status text;
  left_seat   int;
begin
  select status into room_status from public.rooms where id = p_room;
  if room_status is null then
    return 'ROOM_NOT_FOUND';
  end if;

  if room_status <> 'lobby' then
    update public.room_players
       set connected = false, status = 'left', last_seen = now()
     where room_id = p_room and user_id = p_user;
    return 'disconnected';
  end if;

  select seat into left_seat
    from public.room_players
   where room_id = p_room and user_id = p_user;
  if left_seat is null then
    return 'NOT_A_MEMBER';
  end if;

  delete from public.room_players
   where room_id = p_room and user_id = p_user;

  -- Seat order is the night pass and the «اسم واحد» order, so a hole in it
  -- would put an empty chair in both.
  update public.room_players
     set seat = seat - 1
   where room_id = p_room and seat > left_seat;

  -- The host leaving its own lobby hands the room to the new seat 0 rather
  -- than closing it: the other players are already in it.
  update public.rooms r
     set host_id = coalesce(
           (select user_id from public.room_players
             where room_id = p_room order by seat limit 1),
           r.host_id)
   where r.id = p_room and r.host_id = p_user;

  return 'left';
end;
$$;

revoke all on function public.leave_room(uuid, uuid) from public, anon, authenticated;
grant execute on function public.leave_room(uuid, uuid) to service_role;

-- ── the realtime column list ─────────────────────────────────────────────
--
-- The publication's column list is the client's whole view of a roster delta:
-- a column that is not in it arrives as null and overwrites what the client
-- already had. `gender` has been missing since it was added; `saw_role` and
-- `status` would have been missing from birth. `role` stays out, deliberately
-- and permanently — that is the one column this publication exists to exclude.
alter publication supabase_realtime drop table public.room_players;
alter publication supabase_realtime add table public.room_players
  (room_id, user_id, name, seat, alive, connected, last_seen, gender, saw_role, status);
