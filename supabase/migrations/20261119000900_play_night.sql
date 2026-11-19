-- O2 «ليلة اللعب» (owner 2026-11-19): every day at 21:00 Africa/Cairo the people
-- who want to play are asked to come at the same time; the window is 21:00-22:00.
--   * play_night_reminders: «فكّرني» for one night (the Cairo date of that 21:00).
--   * play_night_status: the times, whether it is on now, whether this player
--     asked to be reminded, how many did (only from 5 up) and how many wait in the queue.
--   * play_night_push (pg_cron every 5 minutes): once per Cairo date, between
--     20:45 and 21:00 Cairo time, push kind 'play_night' to tonight's reminders
--     and to everyone with an online match record in the last 30 days, except
--     players sitting in a lobby or a match. Counts play_night/{remind,push}.
--     Thursday (Cairo) sends nothing: Thursday Night has its own push.
-- The kind 'play_night' itself is added to the outbox in 20261119000800.
-- Times use the tz database, so Egypt's daylight saving is handled.
-- Idempotent.

create table if not exists public.play_night_reminders (
  user_id uuid not null references auth.users(id) on delete cascade,
  night date not null,
  created_at timestamptz not null default now(),
  primary key (user_id, night)
);
alter table public.play_night_reminders enable row level security;
revoke all on public.play_night_reminders from anon, authenticated;

-- One row per Cairo date the push already went out for.
create table if not exists public.play_night_sent (
  night date primary key,
  sent_at timestamptz not null default now(),
  recipients integer not null default 0
);
alter table public.play_night_sent enable row level security;
revoke all on public.play_night_sent from anon, authenticated;

-- The night that is "tonight" at p_now: today's 21:00 until 22:00 Cairo time has
-- passed, tomorrow's after that.
create or replace function public.play_night_window(p_now timestamptz)
returns table (starts_at timestamptz, ends_at timestamptz, night date)
language sql immutable security definer set search_path = public, pg_temp as $$
  with l as (select (p_now at time zone 'Africa/Cairo') as t),
  n as (
    select case when l.t < date_trunc('day', l.t) + interval '22 hours'
                then date_trunc('day', l.t)
                else date_trunc('day', l.t) + interval '1 day' end as d
      from l)
  select ((n.d + interval '21 hours') at time zone 'Africa/Cairo'),
         ((n.d + interval '22 hours') at time zone 'Africa/Cairo'),
         n.d::date
    from n
$$;

create or replace function public.play_night_status(p_user uuid, p_now timestamptz default now())
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare w record; reminded boolean; cnt integer; waiting integer;
begin
  select * into w from public.play_night_window(p_now);
  reminded := exists (select 1 from public.play_night_reminders
                       where user_id = p_user and night = w.night);
  select count(*) into cnt from public.play_night_reminders where night = w.night;
  select count(*) into waiting from public.match_queue;
  return jsonb_build_object(
    'startsAt', w.starts_at,
    'endsAt', w.ends_at,
    'active', p_now >= w.starts_at and p_now < w.ends_at,
    'reminded', reminded,
    'remindedCount', case when cnt >= 5 then cnt else null end,
    'queueCount', waiting);
end $$;

create or replace function public.play_night_remind(p_user uuid, p_on boolean, p_now timestamptz default now())
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare w record; n integer;
begin
  if p_user is null then raise exception 'BAD_REQUEST'; end if;
  select * into w from public.play_night_window(p_now);
  if coalesce(p_on, false) then
    insert into public.play_night_reminders(user_id, night) values (p_user, w.night)
      on conflict (user_id, night) do nothing;
    get diagnostics n = row_count;
    if n > 0 then perform public.metric_note(p_user, 'play_night', 'remind'); end if;
    return true;
  end if;
  delete from public.play_night_reminders where user_id = p_user and night = w.night;
  return false;
end $$;

create or replace function public.play_night_push(p_now timestamptz default now())
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare
  local_at timestamp := p_now at time zone 'Africa/Cairo';
  v_night date := local_at::date;
  n integer; ids uuid[]; u uuid; queued integer;
begin
  -- Thursday has its own push; outside 20:45-21:00 Cairo time nothing goes.
  if extract(isodow from local_at) = 4 then return 0; end if;
  if local_at::time < time '20:45' or local_at::time >= time '21:00' then return 0; end if;

  insert into public.play_night_sent(night) values (v_night) on conflict (night) do nothing;
  get diagnostics n = row_count;
  if n = 0 then return 0; end if;

  delete from public.play_night_reminders where night < v_night - 7;

  ids := coalesce(array(
    select r.u from (
      select user_id as u from public.play_night_reminders where night = v_night
      union
      select user_id from public.council_match_records
       where created_at > p_now - interval '30 days') r
     where not exists (
       select 1 from public.room_players p join public.rooms rm on rm.id = p.room_id
        where p.user_id = r.u and not p.kicked and p.status is distinct from 'left'
          and rm.status in ('lobby', 'playing'))
     order by r.u), '{}'::uuid[]);

  queued := public.push_enqueue('play_night', ids, '{}'::jsonb,
    'play_night:' || to_char(v_night, 'YYYY-MM-DD'), interval '1 hour');

  foreach u in array ids loop
    if exists (select 1 from public.push_outbox
                where dedupe_key = 'play_night:' || to_char(v_night, 'YYYY-MM-DD') || ':' || u) then
      perform public.metric_note(u, 'play_night', 'push');
    end if;
  end loop;

  update public.play_night_sent set recipients = queued where night = v_night;
  return queued;
end $$;

revoke all on function public.play_night_window(timestamptz) from public, anon, authenticated;
revoke all on function public.play_night_status(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.play_night_remind(uuid, boolean, timestamptz) from public, anon, authenticated;
revoke all on function public.play_night_push(timestamptz) from public, anon, authenticated;
grant execute on function public.play_night_window(timestamptz) to service_role;
grant execute on function public.play_night_status(uuid, timestamptz) to service_role;
grant execute on function public.play_night_remind(uuid, boolean, timestamptz) to service_role;
grant execute on function public.play_night_push(timestamptz) to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'play-night-push') then
      perform cron.unschedule('play-night-push');
    end if;
    perform cron.schedule('play-night-push', '*/5 * * * *', 'select public.play_night_push();');
  end if;
end $$;
