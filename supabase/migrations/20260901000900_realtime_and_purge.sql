-- Realtime publication, the 24-hour purge, and the keep-alive (doc 10 §3.1,
-- §3.2, §9).

-- ── Realtime ─────────────────────────────────────────────────────────────
--
-- Exactly two tables are published, and the choice is a cost decision as much
-- as a security one (doc 10 §3.1: "batch the phase snapshot — one broadcast
-- per phase change, not one per field").
--
--   room_state    — the phase, the deadline, the public payload
--   room_players  — alive / connected / seat
--
-- `room_players` carries the secret `role` column, so it is published with
-- RLS **enforced on the replication stream**: Supabase Realtime applies the
-- table's policies to each change before delivering it, and the policy above
-- only ever matches rows in the subscriber's own room. A client still never
-- sees another player's role because the *view* is what it reads for role —
-- but publishing the base table means a change payload could carry one, so
-- the column is filtered out of the publication below.
--
-- `night_actions`, `votes`, `whisper_content` and `signals` are deliberately
-- not published. A live feed of night actions is the exact thing this design
-- exists to prevent.

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end
$$;

alter publication supabase_realtime add table public.room_state;

-- Column list, so a role never enters the replication stream at all. This is
-- belt-and-braces on top of RLS: it removes the column from the payload rather
-- than relying on every subscriber's policy evaluation being correct.
alter publication supabase_realtime
  add table public.room_players (room_id, user_id, name, seat, alive, connected, last_seen);

alter table public.room_state   replica identity full;
alter table public.room_players replica identity full;

-- ── The purge ────────────────────────────────────────────────────────────
--
-- Doc 10 §3.1: "Purge finished matches after 24 hours. The full record already
-- lives on each player's device." That last clause is what makes this safe —
-- online matches are written to local Isar as ordinary match records when they
-- end, so History and analytics never need the server.
--
-- Every child table cascades from `rooms`, so one delete is the whole purge.

create or replace function public.purge_finished_rooms()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  removed integer;
begin
  with gone as (
    delete from public.rooms
    where status = 'finished'
      and ended_at is not null
      and ended_at < now() - interval '24 hours'
    returning 1
  )
  select count(*) into removed from gone;

  -- Abandoned lobbies too (O3): a room nobody ever started is not "finished",
  -- so the clause above would never reach it and it would sit there forever.
  delete from public.rooms
  where status = 'lobby'
    and created_at < now() - interval '24 hours';

  -- Signalling is worthless within a minute of being written.
  delete from public.signals where created_at < now() - interval '1 hour';

  return removed;
end;
$$;

-- ── Schedules ────────────────────────────────────────────────────────────
--
-- `pg_cron` is not available on every plan, so both schedules are guarded.
-- A project without the extension still works; it simply grows until somebody
-- runs the function by hand, and the function is safe to run at any time.

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema extensions;

    perform cron.unschedule('purge-finished-rooms')
      where exists (select 1 from cron.job where jobname = 'purge-finished-rooms');
    perform cron.schedule(
      'purge-finished-rooms',
      '17 3 * * *',
      $cron$ select public.purge_finished_rooms(); $cron$
    );

    -- Doc 10 §3.2, the pause trap: a Free project pauses after 7 days of
    -- inactivity. One trivial query a week prevents it. It is deliberately
    -- cheap and deliberately not a no-op — a statement that touches nothing
    -- may not count as activity.
    perform cron.unschedule('keep-alive')
      where exists (select 1 from cron.job where jobname = 'keep-alive');
    perform cron.schedule(
      'keep-alive',
      '0 6 * * 1',
      $cron$ select count(*) from public.rooms; $cron$
    );
  end if;
end
$$;
