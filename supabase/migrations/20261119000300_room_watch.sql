-- B1: a player with nobody to play with asks to be told once when a public
-- lobby has people waiting. The watch is on or off per player; the sweep below
-- notifies every watcher who is not already in a room, at most one notice a
-- day, then turns that watch off.
-- Idempotent.

create table if not exists public.room_watchers (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.room_watchers enable row level security;
revoke all on public.room_watchers from anon, authenticated;

create or replace function public.room_watch_set(p_user uuid, p_on boolean)
returns boolean language plpgsql security definer set search_path to 'public','pg_temp' as $$
begin
  if p_user is null then raise exception 'BAD_REQUEST'; end if;
  if coalesce(p_on, false) then
    insert into public.room_watchers(user_id) values (p_user) on conflict (user_id) do nothing;
    return true;
  end if;
  delete from public.room_watchers where user_id = p_user;
  return false;
end $$;

create or replace function public.room_watch_get(p_user uuid)
returns boolean language sql security definer set search_path to 'public','pg_temp' stable as $$
  select exists (select 1 from public.room_watchers where user_id = p_user);
$$;

revoke all on function public.room_watch_set(uuid, boolean) from public, anon, authenticated;
revoke all on function public.room_watch_get(uuid) from public, anon, authenticated;
grant execute on function public.room_watch_set(uuid, boolean) to service_role;
grant execute on function public.room_watch_get(uuid) to service_role;

-- The new push kind. A game notification like 'room_start', never one of the
-- gentle daily ones.
alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('room_start','night','daily','thursday','comeback','app_update','rooms_gathering',
                  'owner_order','owner_claimed','owner_play','owner_report','owner_tester','owner_feedback'));

create or replace function public.push_outbox_claim(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $function$
declare
  enabled boolean := coalesce((select push_invites_enabled from public.economy_config limit 1),false);
  out jsonb;
begin
  update public.push_outbox
     set status='pending', claimed_at=null
   where status='processing'
     and claimed_at < now()-interval '2 minutes'
     and expires_at >= now();
  with picked as (
    -- One gentle kind per player per batch: the rest wait for the next drain,
    -- where the 20-hour rule below sees what was just sent.
    select id from public.push_outbox where status='pending' and id in (
        select w.id from (select id, kind,
            row_number() over (partition by user_id order by id) rn
          from public.push_outbox
         where status='pending' and kind in ('daily','thursday','comeback')) w
         where w.rn=1
        union all
        select id from public.push_outbox
         where status='pending' and kind in ('room_start','rooms_gathering','night','app_update',
           'owner_order','owner_claimed','owner_play','owner_report','owner_tester','owner_feedback'))
     order by id limit greatest(1,least(p_limit,500)) for update skip locked
  ), upd as (
    update public.push_outbox o set claimed_at=now(),
      status = case
        -- The player switch holds back players' pushes, never the owner's.
        when not enabled and left(o.kind, 6) <> 'owner_' then 'skipped'
        when o.expires_at < now() then 'skipped'
        when o.kind in ('daily','thursday','comeback') and exists (
          select 1 from public.push_outbox x
           where x.user_id=o.user_id and x.id<>o.id and x.status='sent'
             and x.kind in ('daily','thursday','comeback')
             and x.claimed_at > now()-interval '20 hours') then 'skipped'
        else 'processing' end
    from picked where o.id=picked.id
    returning o.id, o.user_id, o.kind, o.payload, o.status
  )
  -- An update notice goes only to the player's Android devices still behind it.
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',u.id,'kind',u.kind,'payload',u.payload,
      'tokens',(select coalesce(jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform,'build',t.app_build)
                  order by t.updated_at desc),'[]'::jsonb)
                  from public.push_tokens t where t.user_id=u.user_id
                   and (u.kind<>'app_update' or (t.platform='android'
                     and (t.app_build is null
                          or t.app_build < coalesce((u.payload->>'build')::int,0))))))),'[]'::jsonb)
    into out from upd u where u.status='processing';
  return out;
end $function$;

-- Every minute: if a public lobby has room and at least three people in it,
-- tell each watcher who is not in a room themselves, then turn their watch
-- off. The key carries the day, so a player is told at most once a day.
create or replace function public.rooms_gathering_sweep()
returns integer language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare w record; told integer := 0;
begin
  if not exists (select 1 from public.room_watchers) then return 0; end if;
  if not exists (
    select 1 from public.rooms r
     where r.visibility = 'public' and r.status = 'lobby'
       and (select count(*) from public.room_players p
             where p.room_id = r.id and p.connected and not p.kicked) >= 3
       and (select count(*) from public.room_players p
             where p.room_id = r.id and p.connected and not p.kicked)
           < case when r.settings->>'maxPlayers' in ('5','8','10','15')
                  then (r.settings->>'maxPlayers')::int else 10 end
  ) then return 0; end if;
  for w in select user_id from public.room_watchers loop
    if not exists (
      select 1 from public.room_players p join public.rooms r on r.id = p.room_id
       where p.user_id = w.user_id and not p.kicked and r.status in ('lobby','playing')
    ) then
      told := told + public.push_enqueue('rooms_gathering', array[w.user_id], '{}'::jsonb,
        'rooms_gathering:' || to_char((now() at time zone 'utc')::date, 'YYYY-MM-DD') || ':' || w.user_id,
        interval '1 day');
      delete from public.room_watchers where user_id = w.user_id;
    end if;
  end loop;
  return told;
end $$;
revoke all on function public.rooms_gathering_sweep() from public, anon, authenticated;
grant execute on function public.rooms_gathering_sweep() to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'rooms-gathering') then
      perform cron.unschedule('rooms-gathering');
    end if;
    perform cron.schedule('rooms-gathering', '* * * * *', 'select public.rooms_gathering_sweep();');
  end if;
end $$;
