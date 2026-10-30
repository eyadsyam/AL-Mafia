-- The owner's notices (owner, 2026-10-30: «ضيف اشعار ليا علي حسابي لما حد
-- بيدفع او بيطلب الدفع او اي حاجه من الباقي»). Every commerce admin with a
-- device gets one push per event; it opens the matching admin page on the
-- website (_shared/push.ts OWNER_TEXT). The push carries the kind only: no
-- amount, name, reference or method ever leaves the database in it.
-- Idempotent (create or replace / if exists).

alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('room_start','night','daily','thursday','comeback',
                  'owner_order','owner_claimed','owner_play','owner_report','owner_tester'));

-- One notice to every admin. A day to live: a notice about a request is
-- still worth reading the next morning.
create or replace function public.push_owner(p_kind text, p_key text)
returns int language plpgsql security definer set search_path=public,pg_temp as $$
begin
  return public.push_enqueue(p_kind,
    coalesce((select array_agg(a.user_id) from public.commerce_admins a), '{}'),
    '{}'::jsonb, p_key, interval '1 day');
exception when others then
  return 0;  -- a notice must never stop the row that caused it
end $$;
revoke all on function public.push_owner(text,text) from public, anon, authenticated;

create or replace function public.push_owner_on_order()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if tg_op = 'INSERT' then
    perform public.push_owner('owner_order', 'order:'||new.id);
  elsif new.status = 'claimed' and old.status is distinct from 'claimed' then
    perform public.push_owner('owner_claimed', 'claimed:'||new.id||':'||coalesce(new.claimed_at::text,''));
  end if;
  return null;
end $$;
drop trigger if exists push_owner_order on public.coin_orders;
create trigger push_owner_order after insert or update of status on public.coin_orders
  for each row execute function public.push_owner_on_order();

create or replace function public.push_owner_on_play()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.push_owner('owner_play', 'play:'||md5(new.purchase_token));
  return null;
end $$;
drop trigger if exists push_owner_play on public.play_purchases;
create trigger push_owner_play after insert on public.play_purchases
  for each row execute function public.push_owner_on_play();

create or replace function public.push_owner_on_report()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.push_owner('owner_report', 'report:'||new.id);
  return null;
end $$;
drop trigger if exists push_owner_report on public.safety_reports;
create trigger push_owner_report after insert on public.safety_reports
  for each row execute function public.push_owner_on_report();

create or replace function public.push_owner_on_tester()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.push_owner('owner_tester', 'tester:'||new.id);
  return null;
end $$;
drop trigger if exists push_owner_tester on public.tester_signups;
create trigger push_owner_tester after insert on public.tester_signups
  for each row execute function public.push_owner_on_tester();

-- The claim takes the owner's notices like room events: at once, never held
-- back by the gentle reminders' once-a-day rule.
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
         where status='pending' and kind in ('room_start','night',
           'owner_order','owner_claimed','owner_play','owner_report','owner_tester'))
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
        else 'processing' end
    from picked where o.id=picked.id
    returning o.id, o.user_id, o.kind, o.payload, o.status
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',u.id,'kind',u.kind,'payload',u.payload,
      'tokens',(select coalesce(jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform)
                  order by t.updated_at desc),'[]'::jsonb)
                  from public.push_tokens t where t.user_id=u.user_id))),'[]'::jsonb)
    into out from upd u where u.status='processing';
  return out;
end $function$;
