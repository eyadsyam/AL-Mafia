-- O3 — "every player leaves → room archived after 5 minutes. Never left
-- 'playing' forever."
--
-- The 24-hour purge in the previous migration deletes *finished* rooms and
-- lobbies nobody started. Neither clause reaches a room that was mid-match when
-- the last player closed the app, and that is the room that would otherwise sit
-- in `playing` until the table was dropped — holding a code, counting against
-- the room list, and looking joinable to anybody who still had the six letters.
--
-- Five minutes is deliberately much longer than the 30 seconds a *player* is
-- given (doc 10 §8.1): one player dropping is an event the match survives, and
-- only the whole room going quiet is an abandonment.

create or replace function public.archive_abandoned_rooms(
  p_idle interval default interval '5 minutes'
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  archived integer;
begin
  with abandoned as (
    update public.rooms r
       set status = 'finished',
           ended_at = now()
     where r.status = 'playing'
       and not exists (
         select 1 from public.room_players p
          where p.room_id = r.id
            and p.connected
            and p.last_seen > now() - p_idle
       )
    returning 1
  )
  select count(*) into archived from abandoned;

  return archived;
end;
$$;

-- A room archived this way is still purged 24 hours later by
-- `purge_finished_rooms`, so this adds a state transition rather than a second
-- retention policy.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema extensions;

    perform cron.unschedule('archive-abandoned-rooms')
      where exists (select 1 from cron.job where jobname = 'archive-abandoned-rooms');
    perform cron.schedule(
      'archive-abandoned-rooms',
      '*/5 * * * *',
      $cron$ select public.archive_abandoned_rooms(); $cron$
    );
  end if;
end
$$;

revoke all on function public.archive_abandoned_rooms(interval) from anon, authenticated;
