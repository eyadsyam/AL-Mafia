-- Push beyond invites: one outbox, one drain.
--
-- Triggers and cron jobs only WRITE rows to `push_outbox` (and nudge the
-- `send_push` Edge function through pg_net). The function claims pending rows,
-- turns each into an FCM message and sends it. Nothing here is a secret: the
-- function's only input is "drain what is pending", so calling it by hand is
-- harmless, and the FCM service account (FCM_SERVICE_ACCOUNT_B64) stays in the
-- function's environment.
--
-- Doc 05 (zero leakage): a notification states a phase of the room that every
-- seat sees at the same time, never anything a seat alone knows. «الليل نزل»
-- goes to EVERY player of the room (alive or not, any role) with identical
-- wording; nothing is sent per role, per target or per outcome, so a
-- notification can never tell a Citizen from a Mafioso. No payload carries a
-- role, a seat, a name or a night result.
--
-- Same master switch as invites (`economy_config.push_invites_enabled`) and
-- the same device tokens (`push_tokens`, own-rows via the friends function).

create table if not exists public.push_outbox (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  kind text not null
    check (kind in ('room_start','night','daily','thursday','comeback')),
  payload jsonb not null default '{}'::jsonb,
  dedupe_key text unique,
  status text not null default 'pending'
    check (status in ('pending','sent','skipped')),
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  expires_at timestamptz not null default now() + interval '30 minutes'
);
create index if not exists push_outbox_pending on public.push_outbox(id)
  where status='pending';
create index if not exists push_outbox_user_kind
  on public.push_outbox(user_id, kind, claimed_at);

alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;
grant all on public.push_outbox to service_role;

-- ── Nudging the function ────────────────────────────────────────────────────

create or replace function public.push_wake()
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform net.http_post(
    url := 'https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/send_push',
    body := '{}'::jsonb,
    headers := '{"content-type":"application/json"}'::jsonb,
    timeout_milliseconds := 5000);
exception when others then
  null;  -- the 5-minute sweep below picks the rows up
end $$;

-- ── Enqueue helper ──────────────────────────────────────────────────────────

create or replace function public.push_enqueue(
  p_kind text, p_users uuid[], p_payload jsonb, p_key text, p_ttl interval)
returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare n int;
begin
  if not coalesce((select push_invites_enabled from public.economy_config limit 1),false) then
    return 0;
  end if;
  insert into public.push_outbox(user_id,kind,payload,dedupe_key,expires_at)
    select u, p_kind, coalesce(p_payload,'{}'::jsonb), p_key||':'||u, now()+p_ttl
      from unnest(p_users) u
     where exists (select 1 from public.push_tokens t where t.user_id=u)
    on conflict (dedupe_key) do nothing;
  get diagnostics n = row_count;
  if n > 0 then perform public.push_wake(); end if;
  return n;
end $$;

-- ── Room triggers ───────────────────────────────────────────────────────────

-- The host pressed start: everyone who is not looking at the app is told.
create or replace function public.push_on_room_start()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.push_enqueue('room_start',
    coalesce((select array_agg(p.user_id) from public.room_players p
       where p.room_id=new.id and p.user_id<>new.host_id
         and (not p.connected or p.last_seen < now()-interval '25 seconds')),'{}'),
    '{}'::jsonb, 'start:'||new.id, interval '10 minutes');
  return null;
end $$;
drop trigger if exists push_room_start on public.rooms;
create trigger push_room_start after update of status on public.rooms
  for each row when (old.status='lobby' and new.status='playing')
  execute function public.push_on_room_start();

-- The night begins: the same words to every seat. Not more than one per
-- player per room every three minutes.
create or replace function public.push_on_night()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.push_enqueue('night',
    coalesce((select array_agg(p.user_id) from public.room_players p
       where p.room_id=new.room_id
         and (not p.connected or p.last_seen < now()-interval '25 seconds')
         and not exists (select 1 from public.push_outbox o
              where o.user_id=p.user_id and o.kind='night'
                and o.payload->>'room'=new.room_id::text
                and o.created_at > now()-interval '3 minutes')),'{}'),
    jsonb_build_object('room',new.room_id),
    'night:'||new.room_id||':'||new.phase_number, interval '10 minutes');
  return null;
end $$;
drop trigger if exists push_night on public.room_state;
create trigger push_night after update of phase on public.room_state
  for each row when (new.phase='night' and old.phase is distinct from new.phase)
  execute function public.push_on_night();

-- ── Scheduled kinds ─────────────────────────────────────────────────────────

-- Today's wheel is still unclaimed (players who ever claimed a daily reward
-- and opened the app in the last two weeks).
create or replace function public.push_enqueue_daily()
returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today();
begin
  return public.push_enqueue('daily',
    coalesce((select array_agg(distinct t.user_id) from public.push_tokens t
      where t.updated_at > now()-interval '14 days'
        and exists (select 1 from public.daily_claims c where c.user_id=t.user_id)
        and not exists (select 1 from public.daily_claims c
              where c.user_id=t.user_id and c.day=today and c.kind='wheel')),'{}'),
    '{}'::jsonb, 'daily:'||today, interval '6 hours');
end $$;

-- Thursday night is tonight.
create or replace function public.push_enqueue_thursday()
returns int language plpgsql security definer set search_path=public,pg_temp as $$
begin
  return public.push_enqueue('thursday',
    coalesce((select array_agg(distinct user_id) from public.push_tokens
      where updated_at > now()-interval '30 days'),'{}'),
    '{}'::jsonb, 'thursday:'||public.economy_today(), interval '6 hours');
end $$;

-- Three quiet days (the app refreshes its token at every launch), at most one
-- reminder per ten days, nothing for players gone for a month.
create or replace function public.push_enqueue_comeback()
returns int language plpgsql security definer set search_path=public,pg_temp as $$
begin
  return public.push_enqueue('comeback',
    coalesce((select array_agg(q.u) from (
        select t.user_id u from public.push_tokens t group by t.user_id
         having max(t.updated_at) < now()-interval '3 days'
            and max(t.updated_at) > now()-interval '30 days') q
       where not exists (select 1 from public.push_outbox o
              where o.user_id=q.u and o.kind='comeback'
                and o.created_at > now()-interval '10 days')),'{}'),
    '{}'::jsonb, 'comeback:'||public.economy_today(), interval '12 hours');
end $$;

-- ── The drain's side of the contract ────────────────────────────────────────

-- Claims up to p_limit pending rows and returns the ones to send, each with
-- the recipient's tokens. Marks the rest skipped: push off, expired, or a
-- second "gentle" notification (daily / Thursday / comeback) within 20 hours.
create or replace function public.push_outbox_claim(p_limit int default 100)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
  enabled boolean := coalesce((select push_invites_enabled from public.economy_config limit 1),false);
  out jsonb;
begin
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
         where status='pending' and kind in ('room_start','night'))
     order by id limit greatest(1,least(p_limit,500)) for update skip locked
  ), upd as (
    update public.push_outbox o set claimed_at=now(),
      status = case
        when not enabled then 'skipped'
        when o.expires_at < now() then 'skipped'
        when o.kind in ('daily','thursday','comeback') and exists (
          select 1 from public.push_outbox x
           where x.user_id=o.user_id and x.id<>o.id and x.status='sent'
             and x.kind in ('daily','thursday','comeback')
             and x.claimed_at > now()-interval '20 hours') then 'skipped'
        else 'sent' end
    from picked where o.id=picked.id
    returning o.id, o.user_id, o.kind, o.payload, o.status
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',u.id,'kind',u.kind,'payload',u.payload,
      'tokens',(select coalesce(jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform)
                  order by t.updated_at desc),'[]'::jsonb)
                  from public.push_tokens t where t.user_id=u.user_id))),'[]'::jsonb)
    into out from upd u where u.status='sent';
  return out;
end $$;

create or replace function public.push_outbox_purge()
returns void language sql security definer set search_path=public,pg_temp as $$
  delete from public.push_outbox where created_at < now()-interval '7 days'
$$;

revoke all on function public.push_wake() from public, anon, authenticated;
revoke all on function public.push_enqueue(text,uuid[],jsonb,text,interval) from public, anon, authenticated;
revoke all on function public.push_enqueue_daily() from public, anon, authenticated;
revoke all on function public.push_enqueue_thursday() from public, anon, authenticated;
revoke all on function public.push_enqueue_comeback() from public, anon, authenticated;
revoke all on function public.push_outbox_claim(int) from public, anon, authenticated;
revoke all on function public.push_outbox_purge() from public, anon, authenticated;
grant execute on function public.push_outbox_claim(int) to service_role;

-- ── Schedule (UTC; Cairo is UTC+2, +3 in summer) ────────────────────────────
do $$
begin
  if exists (select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule('push-daily',    '0 16 * * *', 'select public.push_enqueue_daily()');
    perform cron.schedule('push-thursday', '0 15 * * 4', 'select public.push_enqueue_thursday()');
    perform cron.schedule('push-comeback', '0 17 * * *', 'select public.push_enqueue_comeback()');
    perform cron.schedule('push-sweep',    '*/5 * * * *',
      'select public.push_wake() where exists (select 1 from public.push_outbox where status=''pending'')');
    perform cron.schedule('push-purge',    '30 3 * * *', 'select public.push_outbox_purge()');
  end if;
end $$;
