create table public.player_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('roles','online','store','look','idea','problem')),
  body text not null check (char_length(body) between 2 and 500),
  app_build int,
  platform text check (platform in ('android','web','ios')),
  status text not null default 'new' check (status in ('new','read','planned')),
  created_at timestamptz not null default now()
);
create index player_feedback_user_created on public.player_feedback(user_id,created_at desc);
alter table public.player_feedback enable row level security;
revoke all on public.player_feedback from anon, authenticated;
grant select, insert, update on public.player_feedback to service_role;

create function public.submit_feedback(p_user uuid, p_kind text, p_body text, p_build int, p_platform text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid;
begin
  if p_user is null or not exists(select 1 from auth.users where id=p_user)
    or p_kind not in ('roles','online','store','look','idea','problem')
    or p_kind is null or p_body is null or char_length(btrim(p_body)) not between 2 and 500
    or p_platform not in ('android','web','ios') or p_platform is null
    or (p_build is not null and p_build < 0) then
    raise exception 'BAD_REQUEST';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 0));
  if exists(select 1 from public.player_feedback where user_id=p_user
      and created_at > now()-interval '10 minutes')
    or (select count(*) from public.player_feedback where user_id=p_user
      and (created_at at time zone 'Africa/Cairo')::date =
          (now() at time zone 'Africa/Cairo')::date) >= 5 then
    raise exception 'RATE_LIMITED';
  end if;
  insert into public.player_feedback(user_id,kind,body,app_build,platform)
    values(p_user,p_kind,btrim(p_body),p_build,p_platform) returning id into v_id;
  perform public.push_owner('owner_feedback','feedback:'||v_id);
  return v_id;
end $$;
revoke all on function public.submit_feedback(uuid,text,text,int,text) from public,anon,authenticated;
grant execute on function public.submit_feedback(uuid,text,text,int,text) to service_role;

create function public.admin_feedback(p_admin uuid, p_status text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_rows jsonb;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_status is not null and p_status not in ('new','read','planned') then raise exception 'BAD_REQUEST'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'kind',f.kind,'body',f.body,
      'status',f.status,'createdAt',f.created_at,'appBuild',f.app_build,
      'platform',f.platform,'displayName',i.name) order by f.created_at desc),'[]'::jsonb)
    into v_rows from (select * from public.player_feedback
      where p_status is null or status=p_status order by created_at desc limit 100) f
    left join public.council_identity i on i.user_id=f.user_id;
  return jsonb_build_object('items',v_rows);
end $$;
revoke all on function public.admin_feedback(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_feedback(uuid,text) to service_role;

create function public.admin_feedback_mark(p_admin uuid, p_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_status text;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_status not in ('read','planned') or p_status is null or p_id is null then raise exception 'BAD_REQUEST'; end if;
  update public.player_feedback set status=p_status where id=p_id returning status into v_status;
  if v_status is null then raise exception 'BAD_REQUEST'; end if;
  return jsonb_build_object('id',p_id,'status',v_status);
end $$;
revoke all on function public.admin_feedback_mark(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.admin_feedback_mark(uuid,uuid,text) to service_role;
alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('room_start','night','daily','thursday','comeback',
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
         where status='pending' and kind in ('room_start','night',
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
  select coalesce(jsonb_agg(jsonb_build_object(
      'id',u.id,'kind',u.kind,'payload',u.payload,
      'tokens',(select coalesce(jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform)
                  order by t.updated_at desc),'[]'::jsonb)
                  from public.push_tokens t where t.user_id=u.user_id))),'[]'::jsonb)
    into out from upd u where u.status='processing';
  return out;
end $function$;

