-- The owner hears about reports (review, 2026-11-16): six reports sat pending
-- for weeks, one of them a threat. Two gaps closed here:
--   1. The owner's notices no longer ride on the player-invite switch. Turning
--      off pushes to players must not silence moderation or purchase notices.
--   2. One reminder a day while any report is still pending, so a notice that
--      was missed (no device registered yet, a phone off for a day) is not the
--      last word. The reminder carries the kind only, like every owner notice.
-- Idempotent (create or replace / unschedule first).

create or replace function public.push_enqueue(p_kind text, p_users uuid[], p_payload jsonb, p_key text, p_ttl interval)
returns integer language plpgsql security definer set search_path to 'public','pg_temp' as $function$
declare n int;
begin
  if left(p_kind, 6) <> 'owner_'
     and not coalesce((select push_invites_enabled from public.economy_config limit 1),false) then
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
end $function$;

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
         where status='pending' and kind in ('room_start','night','app_update',
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

-- One reminder per day while a report waits. The key is the date, so a second
-- run on the same day adds nothing.
create or replace function public.push_owner_pending_reports()
returns int language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not exists (select 1 from public.safety_reports where status in ('pending','reviewing')) then
    return 0;
  end if;
  return public.push_owner('owner_report',
    'pending:'||to_char((now() at time zone 'utc')::date, 'YYYY-MM-DD'));
end $$;
revoke all on function public.push_owner_pending_reports() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'owner-pending-reports') then
    perform cron.unschedule('owner-pending-reports');
  end if;
  -- 07:00 UTC is 09:00 in Cairo.
  perform cron.schedule('owner-pending-reports', '0 7 * * *',
    'select public.push_owner_pending_reports()');
end $$;
