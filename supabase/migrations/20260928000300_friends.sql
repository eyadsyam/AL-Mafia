-- «أصحابك»: friends made at the table, who is at a table right now, and
-- one-tap invites into your lobby.
--
-- Additive, OFF by default (`economy_config.friends_enabled`, announced as
-- `capabilities.social.friends`). No directory and no search: a request can
-- only go to somebody you have actually finished a match with in the last 30
-- days, so the feature cannot be used to find or spam strangers. Blocks
-- (player_blocks, either direction) hide people from each other entirely.
--
-- Zero leakage (Doc 05): nothing here reads a role or a private action.
-- Presence says only "in a lobby" (with its code, so a friend can join) or
-- "in a match" — never which match state or seat.

alter table public.economy_config
  add column if not exists friends_enabled boolean not null default false,
  add column if not exists friends_max int not null default 100
    check (friends_max between 1 and 200),
  add column if not exists friend_requests_per_day int not null default 30
    check (friend_requests_per_day between 1 and 50);

-- One row per unordered pair (user_lo < user_hi).
create table if not exists public.friend_links (
  user_lo uuid not null,
  user_hi uuid not null,
  requested_by uuid not null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (user_lo, user_hi),
  check (user_lo < user_hi),
  check (requested_by in (user_lo, user_hi))
);
create index if not exists friend_links_hi on public.friend_links(user_hi);

create table if not exists public.room_invites (
  room_id uuid not null,
  to_user uuid not null,
  from_user uuid not null,
  created_at timestamptz not null default now(),
  primary key (room_id, to_user)
);
create index if not exists room_invites_to on public.room_invites(to_user, created_at);

alter table public.friend_links enable row level security;
alter table public.room_invites enable row level security;
revoke all on public.friend_links, public.room_invites from anon, authenticated;
grant all on public.friend_links, public.room_invites to service_role;

create or replace function public.friends_on()
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select friends_enabled from public.economy_config limit 1), false)
$$;

create or replace function public.friends_blocked(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.player_blocks
    where (blocker_id=p_a and blocked_id=p_b) or (blocker_id=p_b and blocked_id=p_a))
$$;

-- Everyone this player finished a match with since p_since, newest first,
-- with the name they last sat down under.
create or replace function public.friends_tablemates(p_user uuid, p_since interval)
returns table(user_id uuid, name text, gender text, last_played timestamptz, matches int)
language sql stable security definer set search_path=public,pg_temp as $$
  with mine as (
    select r.id, r.ended_at from public.rooms r
      join public.room_players p on p.room_id=r.id
     where p.user_id=p_user and not p.kicked and p.role is not null
       and r.status='finished' and r.ended_at > now() - p_since
  ), mates as (
    select o.user_id, o.name, o.gender, m.ended_at from mine m
      join public.room_players o on o.room_id=m.id
     where o.user_id<>p_user and not o.kicked and o.role is not null
  )
  select distinct on (x.user_id) x.user_id, x.name, x.gender, x.ended_at,
         (select count(*)::int from mates y where y.user_id=x.user_id)
    from mates x
   where not public.friends_blocked(p_user, x.user_id)
   order by x.user_id, x.ended_at desc
$$;

-- Where a player is right now: a joinable lobby (with its code), a match, or
-- nowhere. Rooms left, kicked from or finished do not count.
create or replace function public.friends_presence(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((
    select case when r.status='lobby'
      then jsonb_build_object('state','lobby','roomId',r.id,'code',r.code,
        'players',(select count(*) from public.room_players q
          where q.room_id=r.id and not q.kicked and q.status is distinct from 'left'))
      else jsonb_build_object('state','playing') end
      from public.room_players p join public.rooms r on r.id=p.room_id
     where p.user_id=p_user and not p.kicked and p.status is distinct from 'left'
       and r.status in ('lobby','playing')
     order by r.created_at desc limit 1), jsonb_build_object('state','away'))
$$;

create or replace function public.friends_status(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare friends jsonb; incoming jsonb; outgoing jsonb; recent jsonb; invites jsonb;
begin
  if not public.friends_on() then return jsonb_build_object('enabled',false); end if;
  with links as (
    select case when l.user_lo=p_user then l.user_hi else l.user_lo end as other, l.*
      from public.friend_links l where p_user in (l.user_lo, l.user_hi)
  ), named as (
    select k.*, t.name, t.gender from links k
      left join lateral (select name, gender from public.friends_tablemates(p_user,'365 days')
        where user_id=k.other) t on true
     where not public.friends_blocked(p_user, k.other)
  )
  select
    coalesce(jsonb_agg(jsonb_build_object('id',other,'name',coalesce(name,'?'),'gender',
      coalesce(gender,'unspecified'),'since',accepted_at,'presence',public.friends_presence(other))
      order by name) filter (where accepted_at is not null), '[]'),
    coalesce(jsonb_agg(jsonb_build_object('id',other,'name',coalesce(name,'?'),'gender',
      coalesce(gender,'unspecified'))) filter (where accepted_at is null and requested_by<>p_user), '[]'),
    coalesce(jsonb_agg(jsonb_build_object('id',other,'name',coalesce(name,'?')))
      filter (where accepted_at is null and requested_by=p_user), '[]')
    into friends, incoming, outgoing from named;

  select coalesce(jsonb_agg(jsonb_build_object('id',t.user_id,'name',t.name,'gender',t.gender,
      'lastPlayed',t.last_played,'matches',t.matches) order by t.last_played desc), '[]')
    into recent
    from (select * from public.friends_tablemates(p_user,'30 days') m
           where not exists(select 1 from public.friend_links l
             where l.user_lo=least(p_user,m.user_id) and l.user_hi=greatest(p_user,m.user_id))
           order by m.last_played desc limit 20) t;

  select coalesce(jsonb_agg(jsonb_build_object('roomId',i.room_id,'code',r.code,
      'from',i.from_user,'name',coalesce(p.name,'?'),'at',i.created_at) order by i.created_at desc), '[]')
    into invites
    from public.room_invites i join public.rooms r on r.id=i.room_id
    left join public.room_players p on p.room_id=i.room_id and p.user_id=i.from_user
   where i.to_user=p_user and r.status='lobby' and i.created_at > now() - interval '30 minutes'
     and not public.friends_blocked(p_user, i.from_user);

  return jsonb_build_object('enabled',true,'friends',friends,'incoming',incoming,
    'outgoing',outgoing,'recent',recent,'invites',invites);
end $$;

create or replace function public.friend_request(p_user uuid, p_target uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; lo uuid; hi uuid; link public.friend_links; sent int; mine int;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if p_target is null or p_target=p_user then raise exception 'BAD_REQUEST'; end if;
  if public.friends_blocked(p_user, p_target) then raise exception 'NOT_ALLOWED'; end if;
  if not exists(select 1 from public.friends_tablemates(p_user,'30 days') where user_id=p_target) then
    raise exception 'NOT_ALLOWED';
  end if;
  select * into cfg from public.economy_config;
  lo := least(p_user,p_target); hi := greatest(p_user,p_target);
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

create or replace function public.friend_respond(p_user uuid, p_target uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare lo uuid := least(p_user,p_target); hi uuid := greatest(p_user,p_target);
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if p_accept then
    update public.friend_links set accepted_at=now()
     where user_lo=lo and user_hi=hi and accepted_at is null and requested_by=p_target;
  else
    delete from public.friend_links
     where user_lo=lo and user_hi=hi and accepted_at is null;
  end if;
  return public.friends_status(p_user);
end $$;

create or replace function public.friend_remove(p_user uuid, p_target uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  delete from public.friend_links
   where user_lo=least(p_user,p_target) and user_hi=greatest(p_user,p_target);
  delete from public.room_invites
   where (from_user=p_user and to_user=p_target) or (from_user=p_target and to_user=p_user);
  return public.friends_status(p_user);
end $$;

-- Invites a friend into the lobby the caller is sitting in.
create or replace function public.friend_invite(p_user uuid, p_target uuid, p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare n int;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if not exists(select 1 from public.friend_links
      where user_lo=least(p_user,p_target) and user_hi=greatest(p_user,p_target)
        and accepted_at is not null) then
    raise exception 'NOT_ALLOWED';
  end if;
  if public.friends_blocked(p_user, p_target) then raise exception 'NOT_ALLOWED'; end if;
  if not exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
      where p.room_id=p_room and p.user_id=p_user and not p.kicked
        and p.status is distinct from 'left' and r.status='lobby') then
    raise exception 'NOT_A_MEMBER';
  end if;
  select count(*) into n from public.room_invites
   where from_user=p_user and created_at > now() - interval '1 hour';
  if n >= 60 then raise exception 'RATE_LIMITED'; end if;
  insert into public.room_invites(room_id,to_user,from_user) values(p_room,p_target,p_user)
    on conflict (room_id,to_user) do update set created_at=now(), from_user=excluded.from_user;
  delete from public.room_invites where created_at < now() - interval '1 day';
  return jsonb_build_object('invited',true);
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'friends_on()','friends_blocked(uuid,uuid)','friends_tablemates(uuid,interval)',
    'friends_presence(uuid)','friends_status(uuid)','friend_request(uuid,uuid)',
    'friend_respond(uuid,uuid,boolean)','friend_remove(uuid,uuid)','friend_invite(uuid,uuid,uuid)']
  loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to service_role', f);
  end loop;
end $$;

-- Capabilities: `social.friends`, composed onto whatever answer is current.
alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_friends;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base := public.economy_capabilities_pre_friends(p_user);
  return base || jsonb_build_object('social', coalesce(base->'social','{}'::jsonb)
    || jsonb_build_object('friends', public.friends_on()));
end $$;
revoke all on function public.economy_capabilities_pre_friends(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities_pre_friends(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;

-- Named one by one as well, so the server-surface test can read every
-- revoke without executing the loop above.
revoke all on function public.friends_on() from public, anon, authenticated;
grant execute on function public.friends_on() to service_role;
revoke all on function public.friends_blocked(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friends_blocked(uuid,uuid) to service_role;
revoke all on function public.friends_tablemates(uuid,interval) from public, anon, authenticated;
grant execute on function public.friends_tablemates(uuid,interval) to service_role;
revoke all on function public.friends_presence(uuid) from public, anon, authenticated;
grant execute on function public.friends_presence(uuid) to service_role;
revoke all on function public.friends_status(uuid) from public, anon, authenticated;
grant execute on function public.friends_status(uuid) to service_role;
revoke all on function public.friend_request(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_request(uuid,uuid) to service_role;
revoke all on function public.friend_respond(uuid,uuid,boolean) from public, anon, authenticated;
grant execute on function public.friend_respond(uuid,uuid,boolean) to service_role;
revoke all on function public.friend_remove(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_remove(uuid,uuid) to service_role;
revoke all on function public.friend_invite(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_invite(uuid,uuid,uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
