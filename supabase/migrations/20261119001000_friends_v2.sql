-- Friends v2 (owner 2026-11-19, social-and-night-reveal.html S2, S3, S4, S6).
--
-- S6 privacy: who may send a friend request (everyone / people I played with /
--    nobody) and whether friends see me online. `searchable` already exists.
-- S2 requests: a request no longer needs a recent tablemate when the target
--    allows everyone; by exact @handle too. A pending request older than 30
--    days is dropped by a nightly job.
-- S3 «يلا نلعب؟»: preset pings between friends, never free text.
-- S4 friend profile: our history from FINISHED online matches only
--    (council_match_records is written at match end), so nothing reveals a
--    role or team of a match still being played (doc 05).

alter table public.player_directory
  add column if not exists who_can_add text not null default 'everyone'
    check (who_can_add in ('everyone','tablemates','nobody')),
  add column if not exists show_online boolean not null default true;

-- ── Presence honours «أصحابي يشوفوني أونلاين» ───────────────────────────────
-- friends_presence and directory_state are only ever read about someone else
-- (the friends list, search and discover rows), so a hidden player reads as
-- away everywhere a friend or stranger could see him.
create or replace function public.friends_presence(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select case
    when exists(select 1 from public.player_directory d
                 where d.user_id=p_user and not d.show_online)
      then jsonb_build_object('state','away')
    else coalesce((
    select case when r.status='lobby'
      then jsonb_build_object('state','lobby','roomId',r.id,'code',r.code,
        'players',(select count(*) from public.room_players q
          where q.room_id=r.id and not q.kicked and q.status is distinct from 'left'))
      else jsonb_build_object('state','playing') end
      from public.room_players p join public.rooms r on r.id=p.room_id
     where p.user_id=p_user and not p.kicked and p.status is distinct from 'left'
       and r.status in ('lobby','playing')
     order by r.created_at desc limit 1), jsonb_build_object('state','away')) end
$$;
revoke all on function public.friends_presence(uuid) from public, anon, authenticated;
grant execute on function public.friends_presence(uuid) to service_role;

create or replace function public.directory_state(p_user uuid)
returns text language sql stable security definer set search_path=public,pg_temp as $$
  select case
    when public.friends_presence(p_user)->>'state' in ('lobby','playing')
      then public.friends_presence(p_user)->>'state'
    when exists(select 1 from public.player_directory d where d.user_id=p_user
      and d.show_online and d.last_seen_at > now() - interval '3 minutes') then 'online'
    else 'away' end
$$;
revoke all on function public.directory_state(uuid) from public, anon, authenticated;
grant execute on function public.directory_state(uuid) to service_role;

-- ── S6: the privacy row ─────────────────────────────────────────────────────
-- Reads (all nulls) or writes the caller's four choices and answers them.
create or replace function public.directory_privacy(
  p_user uuid, p_who_can_add text, p_show_online boolean, p_searchable boolean
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare d public.player_directory;
begin
  perform public.directory_guard(p_user);
  if p_who_can_add is not null
     and p_who_can_add not in ('everyone','tablemates','nobody') then
    raise exception 'BAD_REQUEST';
  end if;
  update public.player_directory set
    who_can_add = coalesce(p_who_can_add, who_can_add),
    show_online = coalesce(p_show_online, show_online),
    searchable = coalesce(p_searchable, searchable)
   where user_id=p_user
  returning * into d;
  if d.user_id is null then raise exception 'NOT_ALLOWED'; end if;
  return jsonb_build_object('whoCanAdd',d.who_can_add,'showOnline',d.show_online,
    'searchable',d.searchable,'strangerInvites',d.stranger_invites);
end $$;
revoke all on function public.directory_privacy(uuid,text,boolean,boolean) from public, anon, authenticated;
grant execute on function public.directory_privacy(uuid,text,boolean,boolean) to service_role;

-- ── S2: who may ask ─────────────────────────────────────────────────────────
-- Copied from 20260928000300_friends.sql; only the tablemate rule changed:
-- 'everyone' (the default) lets anyone ask, 'tablemates' keeps the old
-- 30-day rule, 'nobody' refuses all. A player with no directory row yet
-- keeps the old rule. Blocks, the daily cap and FRIENDS_FULL are unchanged,
-- and asking back still accepts.
create or replace function public.friend_request(p_user uuid, p_target uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; lo uuid; hi uuid; link public.friend_links; sent int; mine int;
  rule text; tablemate boolean; theirs_waiting boolean;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if p_target is null or p_target=p_user then raise exception 'BAD_REQUEST'; end if;
  if public.friends_blocked(p_user, p_target) then raise exception 'NOT_ALLOWED'; end if;
  lo := least(p_user,p_target); hi := greatest(p_user,p_target);
  -- Their request to me is always mine to accept, whatever my own rule says.
  theirs_waiting := exists(select 1 from public.friend_links
    where user_lo=lo and user_hi=hi and accepted_at is null and requested_by=p_target);
  if not theirs_waiting then
    select who_can_add into rule from public.player_directory where user_id=p_target;
    tablemate := exists(select 1 from public.friends_tablemates(p_user,'30 days')
      where user_id=p_target);
    if coalesce(rule,'tablemates') = 'nobody'
       or (coalesce(rule,'tablemates') = 'tablemates' and not tablemate) then
      raise exception 'NOT_ALLOWED';
    end if;
  end if;
  select * into cfg from public.economy_config;
  perform pg_advisory_xact_lock(hashtextextended('friends:'||lo::text||hi::text, 17));
  select * into link from public.friend_links where user_lo=lo and user_hi=hi for update;
  if link.user_lo is not null then
    -- Their request is waiting: asking back is accepting.
    if link.accepted_at is null and link.requested_by=p_target then
      update public.friend_links set accepted_at=now() where user_lo=lo and user_hi=hi;
    end if;
    return public.friends_status(p_user);
  end if;
  select count(*) into sent from public.friend_links
   where requested_by=p_user and created_at > now() - interval '1 day';
  if sent >= cfg.friend_requests_per_day then raise exception 'RATE_LIMITED'; end if;
  select count(*) into mine from public.friend_links
   where p_user in (user_lo,user_hi) and accepted_at is not null;
  if mine >= cfg.friends_max then raise exception 'FRIENDS_FULL'; end if;
  insert into public.friend_links(user_lo,user_hi,requested_by) values(lo,hi,p_user);
  return public.friends_status(p_user);
end $$;
revoke all on function public.friend_request(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_request(uuid,uuid) to service_role;

-- By exact @handle. An unknown handle and a refused one answer alike
-- (NOT_ALLOWED), so the call cannot be used to probe who exists. The answer
-- carries the target id so the edge function can ring his phone.
create or replace function public.friend_request_by_handle(p_user uuid, p_handle text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  select user_id into target from public.player_directory
   where handle_norm=public.directory_norm(regexp_replace(coalesce(p_handle,''),'^@',''));
  if target is null then raise exception 'NOT_ALLOWED'; end if;
  return public.friend_request(p_user, target) || jsonb_build_object('target', target);
end $$;
revoke all on function public.friend_request_by_handle(uuid,text) from public, anon, authenticated;
grant execute on function public.friend_request_by_handle(uuid,text) to service_role;

-- Pending requests nobody answered in 30 days go.
create or replace function public.friend_requests_purge()
returns integer language sql security definer set search_path=public,pg_temp as $$
  with gone as (
    delete from public.friend_links
     where accepted_at is null and created_at < now() - interval '30 days'
    returning 1)
  select count(*)::int from gone
$$;
revoke all on function public.friend_requests_purge() from public, anon, authenticated;
grant execute on function public.friend_requests_purge() to service_role;
select cron.schedule('friend_requests_purge', '55 4 * * *',
  $cron$select public.friend_requests_purge()$cron$);

-- ── S3: «يلا نلعب؟» ─────────────────────────────────────────────────────────
create table if not exists public.friend_pings (
  id bigserial primary key,
  from_user uuid not null references auth.users on delete cascade,
  to_user uuid not null references auth.users on delete cascade,
  kind text not null check (kind in ('lets_play','coming','five_min','not_now')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes'
);
create index if not exists friend_pings_to on public.friend_pings(to_user, expires_at);
create index if not exists friend_pings_from on public.friend_pings(from_user, to_user, created_at);
alter table public.friend_pings enable row level security;
revoke all on table public.friend_pings from public, anon, authenticated;
grant all on table public.friend_pings to service_role;
grant usage, select on sequence public.friend_pings_id_seq to service_role;

-- Friends only. «يلا نلعب؟» at most 3 times a Cairo day to the same friend;
-- a reply only to an unexpired «يلا نلعب؟» from that friend. A block is
-- answered ok and nothing is stored. Answers {sent, pingId|null}.
create or replace function public.friend_ping(p_user uuid, p_target uuid, p_kind text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare n int; new_id bigint; cairo_day date := (now() at time zone 'Africa/Cairo')::date;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if p_target is null or p_target=p_user
     or p_kind not in ('lets_play','coming','five_min','not_now') then
    raise exception 'BAD_REQUEST';
  end if;
  if public.friends_blocked(p_user, p_target) then
    return jsonb_build_object('sent',true,'pingId',null);
  end if;
  if not public.directory_is_friend(p_user, p_target) then raise exception 'NOT_ALLOWED'; end if;
  perform pg_advisory_xact_lock(hashtextextended('ping:'||p_user::text||p_target::text, 31));
  if p_kind = 'lets_play' then
    select count(*) into n from public.friend_pings
     where from_user=p_user and to_user=p_target and kind='lets_play'
       and (created_at at time zone 'Africa/Cairo')::date = cairo_day;
    if n >= 3 then raise exception 'RATE_LIMITED'; end if;
  else
    if not exists(select 1 from public.friend_pings
        where from_user=p_target and to_user=p_user and kind='lets_play'
          and expires_at > now()) then
      raise exception 'NOT_ALLOWED';
    end if;
    -- One answer per invitation: the earlier one is replaced.
    delete from public.friend_pings
     where from_user=p_user and to_user=p_target and kind<>'lets_play'
       and expires_at > now();
  end if;
  insert into public.friend_pings(from_user,to_user,kind) values(p_user,p_target,p_kind)
    returning id into new_id;
  delete from public.friend_pings where expires_at < now() - interval '2 days';
  return jsonb_build_object('sent',true,'pingId',new_id);
end $$;
revoke all on function public.friend_ping(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.friend_ping(uuid,uuid,text) to service_role;

-- My unexpired incoming pings, newest first, from friends I have not blocked.
create or replace function public.friend_pings_inbox(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'from',p.from_user,
      'name',coalesce(d.display_name,'?'),'handle',d.handle,'kind',p.kind,
      'at',p.created_at,'expiresAt',p.expires_at) order by p.created_at desc),'[]'::jsonb)
    from public.friend_pings p
    left join public.player_directory d on d.user_id=p.from_user
   where p.to_user=p_user and p.expires_at > now()
     and not public.friends_blocked(p_user, p.from_user)
     and public.directory_is_friend(p_user, p.from_user)
$$;
revoke all on function public.friend_pings_inbox(uuid) from public, anon, authenticated;
grant execute on function public.friend_pings_inbox(uuid) to service_role;

-- Push for one ping: the recipient's devices, the sender's name and the kind.
-- Quiet hours 01:00–10:00 Cairo time: stored, never rung.
create or replace function public.friend_ping_push_targets(p_ping bigint)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((
    select jsonb_build_object('enabled',true,'kind','friend_ping','ping',p.kind,
        'fromName',coalesce(d.display_name,'?'),
        'tokens',coalesce((select jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform)
          order by t.updated_at desc) from public.push_tokens t where t.user_id=p.to_user),'[]'::jsonb))
      from public.friend_pings p
      left join public.player_directory d on d.user_id=p.from_user
     where p.id=p_ping and p.created_at > now() - interval '1 minute'
       and extract(hour from (now() at time zone 'Africa/Cairo')) not between 1 and 9
       and public.safety_users_compatible(p.from_user,p.to_user)
       and public.friends_on()
       and coalesce((select push_invites_enabled from public.economy_config),false)),
    jsonb_build_object('enabled',false))
$$;
revoke all on function public.friend_ping_push_targets(bigint) from public, anon, authenticated;
grant execute on function public.friend_ping_push_targets(bigint) to service_role;

-- ── S4: our history ─────────────────────────────────────────────────────────
-- Friends (or self) only. Every number comes from council_match_records,
-- which exist only for finished online matches.
create or replace function public.friend_profile(p_user uuid, p_target uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare d public.player_directory; together int; won_together int; fooled int;
  theirs int; their_mafia int;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if p_target is null then raise exception 'BAD_REQUEST'; end if;
  if p_target<>p_user and (not public.directory_is_friend(p_user, p_target)
      or public.friends_blocked(p_user, p_target)) then
    raise exception 'NOT_ALLOWED';
  end if;
  select * into d from public.player_directory where user_id=p_target;
  select count(*),
         count(*) filter (where m.won and o.won),
         count(*) filter (where o.team='mafia' and m.team='town' and o.won)
    into together, won_together, fooled
    from public.council_match_records m
    join public.council_match_records o on o.room_id=m.room_id and o.user_id=p_target
   where m.user_id=p_user and p_target<>p_user;
  select count(*), count(*) filter (where team='mafia') into theirs, their_mafia
    from public.council_match_records where user_id=p_target;
  return jsonb_build_object(
    'userId',p_target,'handle',d.handle,'name',d.display_name,'gender',d.gender,
    'level',public.directory_level(p_target),
    'matchesTogether',coalesce(together,0),'wonTogether',coalesce(won_together,0),
    'fooledMe',coalesce(fooled,0),'matches',theirs,
    'mafiaShare',case when theirs >= 5 then round(100.0*their_mafia/theirs)::int end,
    'state',public.directory_state(p_target),
    'lastSeen',case when coalesce(d.show_online,false) then d.last_seen_at end)
    || public.public_cosmetics(p_target);
end $$;
revoke all on function public.friend_profile(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_profile(uuid,uuid) to service_role;
