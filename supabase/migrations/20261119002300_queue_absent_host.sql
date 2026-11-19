-- O1 «استناني», review #3: a queue room whose host never opens it.
--
-- queue_make_room seats the longest waiter as host. If that phone is closed,
-- nobody else may start the match (only the host's phone does), and at 90 s of
-- silence age_presence closes the room for everybody who did come.
--
-- A queue room is made by the server, not by a person, and before the deal
-- nobody holds a role, so the host-leaving rule (20261030006900: a host gone
-- ends the room) is about rooms people made. Here, every 15 seconds with the
-- queue tick: a queue room still in the lobby, 30 s old or more, whose host is
-- not connected, goes to the lowest connected seat. That phone already runs the
-- queue's auto start (lobby_screen._autoStart), so the match starts from it.
-- The old host becomes an ordinary seat: back in time, he plays; silent past
-- 90 s, age_presence gives his seat up as for anybody else.
-- Never a room that is playing, never a room anybody made by hand.
-- Idempotent.

create or replace function public.queue_hand_absent_hosts()
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; heir uuid; n integer := 0;
begin
  for r in
    select rm.id, rm.host_id from public.rooms rm
     where rm.status = 'lobby' and rm.visibility = 'public'
       and rm.title = 'لعب سريع' and rm.settings->>'autoStart' = 'true'
       and rm.created_at <= now() - interval '30 seconds'
       and not exists (
         select 1 from public.room_players h
          where h.room_id = rm.id and h.user_id = rm.host_id and not h.kicked
            and h.status = 'connected' and h.connected)
     for update of rm skip locked
  loop
    select p.user_id into heir from public.room_players p
     where p.room_id = r.id and p.user_id <> r.host_id and not p.kicked
       and p.status = 'connected' and p.connected
     order by p.seat
     limit 1;
    continue when heir is null;
    update public.rooms set host_id = heir
     where id = r.id and status = 'lobby' and host_id = r.host_id;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public.queue_hand_absent_hosts() from public, anon, authenticated;
grant execute on function public.queue_hand_absent_hosts() to service_role;

-- Same job, same 15 seconds: one more statement, no second job in cron history.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'match-queue-tick') then
      perform cron.unschedule('match-queue-tick');
    end if;
    perform cron.schedule('match-queue-tick', '15 seconds',
      'select public.queue_tick(); select public.queue_hand_absent_hosts();');
  end if;
end $$;
