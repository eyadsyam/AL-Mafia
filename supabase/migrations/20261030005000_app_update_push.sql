-- A new build approved on Google Play reaches every Android device on its own
-- (owner, 2026-10-30). `play_release_watch` asks Play every ten minutes which
-- build is published and calls app_update_announce once per build: it raises
-- latest_build_android, which brings the in-app prompt, and queues one notice
-- for each player with an Android device still below that build.
--
-- Web is left out: a browser takes the new build by itself. Builds up to 19
-- report no build number, so app_build stays null for them and they count as
-- behind until they open a newer build. Idempotent.

alter table public.push_tokens
  add column if not exists app_build integer check (app_build between 0 and 100000);

drop function if exists public.push_token_register(uuid,text,text);
create or replace function public.push_token_register(
  p_user uuid, p_token text, p_platform text, p_build integer default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if p_platform not in ('android','web') or length(coalesce(p_token,'')) not between 20 and 4096
     or (p_build is not null and p_build not between 1 and 100000) then
    raise exception 'BAD_REQUEST';
  end if;
  -- A device that signs into another account moves its token with it.
  insert into public.push_tokens(token,user_id,platform,app_build)
    values(p_token,p_user,p_platform,p_build)
    on conflict (token) do update set user_id=excluded.user_id, platform=excluded.platform,
      app_build=coalesce(excluded.app_build,public.push_tokens.app_build), updated_at=now();
  -- At most ten devices per player: the oldest go.
  delete from public.push_tokens where user_id=p_user and token in (
    select token from public.push_tokens where user_id=p_user
     order by updated_at desc offset 10);
  return jsonb_build_object('registered',true,
    'enabled',coalesce((select push_invites_enabled from public.economy_config),false));
end $$;
revoke all on function public.push_token_register(uuid,text,text,integer) from public, anon, authenticated;
grant execute on function public.push_token_register(uuid,text,text,integer) to service_role;

alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('room_start','night','daily','thursday','comeback','app_update',
                  'owner_order','owner_claimed','owner_play','owner_report','owner_tester','owner_feedback'));

create table if not exists public.app_release_notices (
  build integer primary key check (build between 1 and 100000),
  announced_at timestamptz not null default now(),
  users integer not null default 0
);
alter table public.app_release_notices enable row level security;
revoke all on public.app_release_notices from public, anon, authenticated;

-- Build 19 was already live when this shipped. It is recorded without a notice,
-- so the first notice is the one for the next build and a device already on 19
-- is not told to update to what it has.
insert into public.app_release_notices(build) values(19) on conflict (build) do nothing;
update public.app_config set latest_build_android = greatest(latest_build_android, 19);

create or replace function public.app_update_announce(p_build integer)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare n int;
begin
  if p_build is null or p_build not between 1 and 100000 then raise exception 'BAD_REQUEST'; end if;
  if p_build <= coalesce((select max(build) from public.app_release_notices),0) then
    return jsonb_build_object('announced',false,'build',p_build);
  end if;
  insert into public.app_release_notices(build) values(p_build) on conflict (build) do nothing;
  if not found then return jsonb_build_object('announced',false,'build',p_build); end if;
  update public.app_config set latest_build_android = greatest(latest_build_android, p_build);
  n := public.push_enqueue('app_update',
    coalesce((select array_agg(distinct t.user_id) from public.push_tokens t
      where t.platform='android' and (t.app_build is null or t.app_build < p_build)),'{}'),
    jsonb_build_object('build',p_build), 'update:'||p_build, interval '3 days');
  update public.app_release_notices set users=n where build=p_build;
  return jsonb_build_object('announced',true,'build',p_build,'users',n);
end $$;
revoke all on function public.app_update_announce(integer) from public, anon, authenticated;
grant execute on function public.app_update_announce(integer) to service_role;

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
      'tokens',(select coalesce(jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform)
                  order by t.updated_at desc),'[]'::jsonb)
                  from public.push_tokens t where t.user_id=u.user_id
                   and (u.kind<>'app_update' or (t.platform='android'
                     and (t.app_build is null
                          or t.app_build < coalesce((u.payload->>'build')::int,0))))))),'[]'::jsonb)
    into out from upd u where u.status='processing';
  return out;
end $function$;

do $$
begin
  if exists (select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule('play-release-watch', '*/10 * * * *', $job$
      select net.http_post(url := 'https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/play_release_watch',
        headers := jsonb_build_object('x-sync-secret',
          (select decrypted_secret from vault.decrypted_secrets where name='play_sync_secret')))
    $job$);
  end if;
end $$;
