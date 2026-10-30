-- The update notice's tap goes straight to Play from build 20 on, so the sender
-- needs each device's build: the claim hands it over with the token.

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
