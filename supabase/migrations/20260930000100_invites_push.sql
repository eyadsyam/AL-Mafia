-- Invites that reach the phone: find anyone, invite anyone, and a push when
-- the app is closed.
--
-- * `player_directory`: one row per player who opened the online side, with a
--   unique searchable handle derived from their display name, a coarse
--   country (two letters, from the device time-zone name and locale the
--   client already has: never coordinates, never IP geolocation), and two
--   switches: «ماتظهرنيش في البحث» (`searchable`) and invites from people who
--   are not friends (`stranger_invites`).
-- * `directory_search` (prefix + normalised match on handle and name) and
--   `directory_discover` (ranked: same country, social closeness, online now,
--   similar Council level). Rows carry public identity only: handle, name,
--   gender, frame, plate, level and a state (away / online / lobby / playing).
--   No user id, no lobby code: an invite to a stranger names their handle.
-- * `room_invite_send`: friends as before, plus strangers found by search,
--   with a daily cap per sender and per recipient; a block stops everything.
--   `room_invites` gains an id, a status, an expiry and a snapshot of the
--   sender. Invites expire when the lobby starts or closes.
-- * `push_tokens` + `invite_push_targets`: what the Edge function needs to
--   send the notification. Push is OFF by default (`push_invites_enabled`).
--
-- Everything answers only while `friends_enabled` is on (the existing gate).
-- Doc 05: nothing here reads a role, a seat's secret or a match state. A push
-- carries the room code, the sender's handle and name, and the invite id.

-- ── Configuration ───────────────────────────────────────────────────────────

alter table public.economy_config
  add column if not exists push_invites_enabled boolean not null default false,
  add column if not exists stranger_invites_per_day int not null default 20
    check (stranger_invites_per_day between 1 and 100),
  add column if not exists stranger_invites_received_per_day int not null default 10
    check (stranger_invites_received_per_day between 1 and 100),
  add column if not exists directory_queries_per_minute int not null default 20
    check (directory_queries_per_minute between 1 and 120),
  add column if not exists handle_change_days int not null default 7
    check (handle_change_days between 0 and 365);

-- ── Tables ──────────────────────────────────────────────────────────────────

create table if not exists public.player_directory (
  user_id uuid primary key,
  handle text not null,
  handle_norm text not null unique,
  display_name text not null,
  name_norm text not null,
  gender text not null default 'unspecified',
  country text check (country ~ '^[A-Z]{2}$'),
  lang text check (lang ~ '^[a-z]{2}$'),
  searchable boolean not null default true,
  stranger_invites boolean not null default true,
  handle_changed_at timestamptz,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists player_directory_handle_prefix
  on public.player_directory(handle_norm text_pattern_ops);
create index if not exists player_directory_name_prefix
  on public.player_directory(name_norm text_pattern_ops);
create index if not exists player_directory_seen
  on public.player_directory(last_seen_at desc);

-- Search and discover calls, for the per-user rate limit (kept one hour).
create table if not exists public.directory_queries (
  user_id uuid not null,
  at timestamptz not null default now()
);
create index if not exists directory_queries_user on public.directory_queries(user_id, at);

-- Every invite sent, for the daily caps (kept two days). room_invites keeps
-- only the latest invite per room and recipient, so it cannot count.
create table if not exists public.invite_events (
  from_user uuid not null,
  to_user uuid not null,
  room_id uuid not null,
  stranger boolean not null,
  at timestamptz not null default now()
);
create index if not exists invite_events_from on public.invite_events(from_user, at);
create index if not exists invite_events_to on public.invite_events(to_user, at);

create table if not exists public.push_tokens (
  token text primary key check (length(token) between 20 and 4096),
  user_id uuid not null,
  platform text not null check (platform in ('android','web')),
  updated_at timestamptz not null default now()
);
create index if not exists push_tokens_user on public.push_tokens(user_id, updated_at);

alter table public.room_invites
  add column if not exists id uuid not null default gen_random_uuid(),
  add column if not exists status text not null default 'pending'
    check (status in ('pending','accepted','declined','expired')),
  add column if not exists expires_at timestamptz not null default now() + interval '30 minutes',
  add column if not exists from_name text,
  add column if not exists from_handle text,
  add column if not exists stranger boolean not null default false;
create unique index if not exists room_invites_id on public.room_invites(id);

alter table public.player_directory enable row level security;
alter table public.directory_queries enable row level security;
alter table public.invite_events enable row level security;
alter table public.push_tokens enable row level security;
revoke all on public.player_directory, public.directory_queries, public.invite_events,
  public.push_tokens from anon, authenticated;
grant all on public.player_directory, public.directory_queries, public.invite_events,
  public.push_tokens to service_role;

-- ── Normalisation ───────────────────────────────────────────────────────────
-- The Safety v11 name normaliser (case-folded; أ/إ/آ/ٱ→ا, ى/ی→ي; tatweel,
-- diacritics and invisible marks stripped), plus ة→ه, and only letters,
-- digits, underscore (and, for names, single spaces) kept.

create or replace function public.directory_norm(p_text text)
returns text language sql immutable set search_path=public,pg_catalog as $$
  select regexp_replace(translate(public.safety_normalize_name(p_text),'ة','ه'),
    '[^0-9a-z_ء-ي٠-٩]','','g')
$$;

create or replace function public.directory_name_norm(p_text text)
returns text language sql immutable set search_path=public,pg_catalog as $$
  select btrim(regexp_replace(regexp_replace(translate(public.safety_normalize_name(p_text),'ة','ه'),
    '[^0-9a-z_ء-ي٠-٩ ]','','g'),'\s+',' ','g'))
$$;

-- LIKE pattern for a normalised prefix (the underscore is a wildcard).
create or replace function public.directory_like(p_norm text)
returns text language sql immutable set search_path=pg_catalog as $$
  select replace(replace(p_norm,'\','\\'),'_','\_') || '%'
$$;

-- ── Helpers ─────────────────────────────────────────────────────────────────

create or replace function public.directory_level(p_user uuid)
returns int language sql stable security definer set search_path=public,pg_temp as $$
  select public.council_level_for(coalesce(
    (select sum(xp) from public.council_xp_events where user_id=p_user),0)::bigint)
$$;

-- away / online (seen in the last three minutes) / lobby / playing.
create or replace function public.directory_state(p_user uuid)
returns text language sql stable security definer set search_path=public,pg_temp as $$
  select case
    when public.friends_presence(p_user)->>'state' in ('lobby','playing')
      then public.friends_presence(p_user)->>'state'
    when exists(select 1 from public.player_directory d where d.user_id=p_user
      and d.last_seen_at > now() - interval '3 minutes') then 'online'
    else 'away' end
$$;

create or replace function public.directory_is_friend(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.friend_links
    where user_lo=least(p_a,p_b) and user_hi=greatest(p_a,p_b) and accepted_at is not null)
$$;

-- Whether p_user may appear to p_viewer in search or discover.
create or replace function public.directory_visible(p_viewer uuid, p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select p_user<>p_viewer
    and exists(select 1 from public.player_directory d where d.user_id=p_user and d.searchable)
    and public.safety_users_compatible(p_viewer, p_user)
    and not public.safety_restricted(p_user,'online')
$$;

-- The public row: the same frame/plate shape as the store-truth friends rows.
create or replace function public.directory_row(p_viewer uuid, p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object('handle',d.handle,'name',d.display_name,'gender',d.gender,
      'level',public.directory_level(d.user_id),'state',public.directory_state(d.user_id),
      'friend',public.directory_is_friend(p_viewer,d.user_id))
    || public.public_cosmetics(d.user_id)
    from public.player_directory d where d.user_id=p_user
$$;

create or replace function public.directory_rate(p_user uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare n int; cap int;
begin
  select directory_queries_per_minute into cap from public.economy_config;
  select count(*) into n from public.directory_queries
   where user_id=p_user and at > now() - interval '1 minute';
  if n >= coalesce(cap,20) then raise exception 'RATE_LIMITED'; end if;
  insert into public.directory_queries(user_id) values(p_user);
  delete from public.directory_queries where user_id=p_user and at < now() - interval '1 hour';
end $$;

create or replace function public.directory_guard(p_user uuid)
returns void language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if public.safety_restricted(p_user,'online') then raise exception 'NOT_ALLOWED'; end if;
end $$;

-- A free handle from a display name: spaces become underscores, anything
-- else outside letters/digits/underscore goes; «player» when too short or
-- refused by the name rules; _2, _3 … on a collision.
create or replace function public.directory_free_handle(p_name text, p_user uuid)
returns text language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base text; cand text; i int := 1;
begin
  base := left(regexp_replace(regexp_replace(btrim(coalesce(p_name,'')),'\s+','_','g'),
    '[^A-Za-z0-9_ء-ي٠-٩]','','g'),16);
  if length(public.directory_norm(base)) < 3 or not public.safety_name_allowed(base,'name') then
    base := 'player';
  end if;
  loop
    cand := case when i=1 then base else base||'_'||i end;
    exit when not exists(select 1 from public.player_directory
      where handle_norm=public.directory_norm(cand) and user_id<>p_user);
    i := i + 1;
  end loop;
  return cand;
end $$;

create or replace function public.directory_me(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select jsonb_build_object('handle',d.handle,'name',d.display_name,
      'searchable',d.searchable,'strangerInvites',d.stranger_invites,
      'handleChangeAt',case when d.handle_changed_at is null then null
        else d.handle_changed_at + make_interval(days => c.handle_change_days) end)
    from public.player_directory d, public.economy_config c where d.user_id=p_user),
    jsonb_build_object('handle',null))
$$;

-- ── Session start ───────────────────────────────────────────────────────────
-- Registers (or refreshes) the caller: display name, gender, coarse country,
-- language and last seen. The first call derives the handle.

create or replace function public.directory_hello(
  p_user uuid, p_name text, p_gender text, p_country text, p_lang text
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cur public.player_directory; nm text := btrim(coalesce(p_name,''));
  ok_name boolean; g text; c text; l text;
begin
  perform public.directory_guard(p_user);
  ok_name := length(nm) between 1 and 20 and public.safety_name_allowed(nm,'name');
  g := case when p_gender in ('male','female') then p_gender else 'unspecified' end;
  c := case when upper(coalesce(p_country,'')) ~ '^[A-Z]{2}$' then upper(p_country) end;
  l := case when lower(coalesce(p_lang,'')) ~ '^[a-z]{2}$' then lower(p_lang) end;
  perform pg_advisory_xact_lock(hashtextextended('directory:'||p_user::text, 23));
  select * into cur from public.player_directory where user_id=p_user;
  if cur.user_id is null then
    if not ok_name then raise exception 'NAME_NOT_ALLOWED'; end if;
    perform pg_advisory_xact_lock(hashtextextended('directory:handles', 23));
    insert into public.player_directory(user_id,handle,handle_norm,display_name,name_norm,gender,country,lang)
    select p_user, h, public.directory_norm(h), nm, public.directory_name_norm(nm), g, c, l
      from (select public.directory_free_handle(nm, p_user) as h) x;
  else
    update public.player_directory set
      display_name = case when ok_name then nm else display_name end,
      name_norm = case when ok_name then public.directory_name_norm(nm) else name_norm end,
      gender = g, country = coalesce(c, country), lang = coalesce(l, lang),
      last_seen_at = now()
     where user_id=p_user;
  end if;
  return public.directory_me(p_user);
end $$;

create or replace function public.directory_set_handle(p_user uuid, p_handle text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cur public.player_directory; h text := btrim(coalesce(p_handle,'')); days int;
begin
  perform public.directory_guard(p_user);
  if h !~ '^[A-Za-z0-9_ء-ي٠-٩]{3,20}$' or length(public.directory_norm(h)) < 3 then
    raise exception 'BAD_REQUEST';
  end if;
  if not public.safety_name_allowed(h,'name') then raise exception 'NAME_NOT_ALLOWED'; end if;
  select * into cur from public.player_directory where user_id=p_user for update;
  if cur.user_id is null then raise exception 'BAD_REQUEST'; end if;
  if cur.handle = h then return public.directory_me(p_user); end if;
  select handle_change_days into days from public.economy_config;
  if cur.handle_changed_at is not null
     and cur.handle_changed_at > now() - make_interval(days => coalesce(days,7)) then
    raise exception 'RATE_LIMITED';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('directory:handles', 23));
  if exists(select 1 from public.player_directory
      where handle_norm=public.directory_norm(h) and user_id<>p_user) then
    raise exception 'HANDLE_TAKEN';
  end if;
  update public.player_directory set handle=h, handle_norm=public.directory_norm(h),
    handle_changed_at=now() where user_id=p_user;
  return public.directory_me(p_user);
end $$;

create or replace function public.directory_prefs(
  p_user uuid, p_searchable boolean, p_stranger_invites boolean
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.directory_guard(p_user);
  update public.player_directory set
    searchable = coalesce(p_searchable, searchable),
    stranger_invites = coalesce(p_stranger_invites, stranger_invites)
   where user_id=p_user;
  return public.directory_me(p_user);
end $$;

-- ── Search ──────────────────────────────────────────────────────────────────

create or replace function public.directory_search(p_user uuid, p_query text, p_page int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare q text := public.directory_norm(p_query); pg int := greatest(coalesce(p_page,0),0);
  rows jsonb; total int;
begin
  perform public.directory_guard(p_user);
  perform public.directory_rate(p_user);
  if length(q) < 2 then
    return jsonb_build_object('rows','[]'::jsonb,'page',pg,'more',false);
  end if;
  with hits as (
    select d.user_id, d.handle,
      case when d.handle_norm=q then 0
           when d.handle_norm like public.directory_like(q) then 1
           else 2 end as rank_match
      from public.player_directory d
     where (d.handle_norm like public.directory_like(q)
         or d.name_norm like public.directory_like(q)
         or d.name_norm like '% '||public.directory_like(q)
         or replace(d.name_norm,' ','') like public.directory_like(q))
       and public.directory_visible(p_user, d.user_id)
  ), page as (
    select * from hits order by rank_match, handle limit 21 offset pg*20
  )
  select coalesce(jsonb_agg(public.directory_row(p_user,x.user_id) order by x.rank_match, x.handle)
      filter (where x.n <= 20),'[]'::jsonb), count(*)
    into rows, total
    from (select p.*, row_number() over (order by rank_match, handle) as n from page p) x;
  return jsonb_build_object('rows',rows,'page',pg,'more',total > 20);
end $$;

-- ── Discover («كل اللي منزلين اللعبة») ──────────────────────────────────────
-- Ranked, in order: (a) same country; (b) social closeness — a friend 4,
-- played together twice or more («شلة», the rematch table) 3, once 2, a
-- friend of a friend 1; (c) online now or at a table; (d) closest Council
-- level. Filters: near, online, played, level (within three levels).
-- Players not seen for 60 days are left out.

create or replace function public.directory_discover(p_user uuid, p_filter text, p_page int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare pg int := greatest(coalesce(p_page,0),0); my_country text; my_level int;
  rows jsonb; total int;
begin
  perform public.directory_guard(p_user);
  if p_filter is not null and p_filter not in ('near','online','played','level') then
    raise exception 'BAD_REQUEST';
  end if;
  perform public.directory_rate(p_user);
  select country into my_country from public.player_directory where user_id=p_user;
  my_level := public.directory_level(p_user);
  with mates as (
    select user_id, matches from public.friends_tablemates(p_user,'365 days')
  ), fr as (
    select case when user_lo=p_user then user_hi else user_lo end as other
      from public.friend_links where p_user in (user_lo,user_hi) and accepted_at is not null
  ), fof as (
    select distinct case when l.user_lo=f.other then l.user_hi else l.user_lo end as other
      from public.friend_links l join fr f on f.other in (l.user_lo,l.user_hi)
     where l.accepted_at is not null
  ), cand as (
    select d.user_id, d.handle, d.last_seen_at,
      (my_country is not null and d.country=my_country) as near,
      case when exists(select 1 from fr where fr.other=d.user_id) then 4
           when coalesce(m.matches,0) >= 2 then 3
           when coalesce(m.matches,0) = 1 then 2
           when exists(select 1 from fof where fof.other=d.user_id) then 1
           else 0 end as social,
      coalesce(m.matches,0) as together,
      public.directory_state(d.user_id) as state,
      public.directory_level(d.user_id) as level
      from public.player_directory d
      left join mates m on m.user_id=d.user_id
     where d.last_seen_at > now() - interval '60 days'
       and public.directory_visible(p_user, d.user_id)
  ), kept as (
    select *, row_number() over (order by near desc, social desc, (state<>'away') desc,
        abs(level-my_level), last_seen_at desc, handle) as n
      from cand
     where case p_filter
       when 'near' then near
       when 'online' then state<>'away'
       when 'played' then together > 0
       when 'level' then abs(level-my_level) <= 3
       else true end
  )
  select coalesce(jsonb_agg(public.directory_row(p_user,k.user_id) order by k.n)
      filter (where k.n > pg*20 and k.n <= pg*20+20),'[]'::jsonb),
    count(*) filter (where k.n > pg*20+20)
    into rows, total from kept k;
  return jsonb_build_object('rows',rows,'page',pg,'more',total > 0);
end $$;

-- ── Invites ─────────────────────────────────────────────────────────────────
-- Into the lobby the caller sits in, for a friend (by id, as before) or for
-- anyone found by search (by handle). Strangers: the recipient must be
-- searchable and accept invites from non-friends; per-sender and
-- per-recipient daily caps. A block, a restriction or an unknown handle is
-- the same generic NOT_ALLOWED. The same pending invite is not sent twice.

create or replace function public.room_invite_send(
  p_user uuid, p_handle text, p_target uuid, p_room uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; target uuid := p_target; friend boolean; n int;
  cur public.room_invites; seat_name text; my_handle text; new_id uuid;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if target is null and p_handle is not null then
    select user_id into target from public.player_directory
     where handle_norm=public.directory_norm(p_handle);
  end if;
  if target is null then raise exception 'NOT_ALLOWED'; end if;
  if target=p_user then raise exception 'BAD_REQUEST'; end if;
  if public.friends_blocked(p_user, target)
     or public.safety_restricted(p_user,'online')
     or public.safety_restricted(target,'online') then
    raise exception 'NOT_ALLOWED';
  end if;
  select p.name into seat_name from public.room_players p join public.rooms r on r.id=p.room_id
   where p.room_id=p_room and p.user_id=p_user and not p.kicked
     and p.status is distinct from 'left' and r.status='lobby';
  if seat_name is null then raise exception 'NOT_A_MEMBER'; end if;
  friend := public.directory_is_friend(p_user, target);
  select * into cfg from public.economy_config;
  if not friend then
    if not exists(select 1 from public.player_directory d
        where d.user_id=target and d.searchable and d.stranger_invites) then
      raise exception 'NOT_ALLOWED';
    end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('invite:'||target::text, 29));

  select * into cur from public.room_invites where room_id=p_room and to_user=target;
  if cur.room_id is not null and cur.status='pending' and cur.from_user=p_user
     and cur.expires_at > now() then
    return jsonb_build_object('invited',true,'inviteId',cur.id,'fresh',false);
  end if;

  if not friend then
    select count(*) into n from public.invite_events
     where from_user=p_user and stranger and at > now() - interval '1 day';
    if n >= cfg.stranger_invites_per_day then raise exception 'RATE_LIMITED'; end if;
    select count(*) into n from public.invite_events
     where to_user=target and stranger and at > now() - interval '1 day';
    if n >= cfg.stranger_invites_received_per_day then raise exception 'RATE_LIMITED'; end if;
  end if;
  select count(*) into n from public.invite_events
   where from_user=p_user and at > now() - interval '1 hour';
  if n >= 60 then raise exception 'RATE_LIMITED'; end if;

  select handle into my_handle from public.player_directory where user_id=p_user;
  new_id := gen_random_uuid();
  insert into public.room_invites(room_id,to_user,from_user,id,status,expires_at,
      from_name,from_handle,stranger,created_at)
    values(p_room,target,p_user,new_id,'pending',now()+interval '30 minutes',
      seat_name,my_handle,not friend,now())
    on conflict (room_id,to_user) do update set from_user=excluded.from_user,
      id=excluded.id, status='pending', expires_at=excluded.expires_at,
      from_name=excluded.from_name, from_handle=excluded.from_handle,
      stranger=excluded.stranger, created_at=now();
  insert into public.invite_events(from_user,to_user,room_id,stranger)
    values(p_user,target,p_room,not friend);
  delete from public.invite_events where at < now() - interval '2 days';
  delete from public.room_invites where expires_at < now() - interval '1 day';
  return jsonb_build_object('invited',true,'inviteId',new_id,'fresh',true);
end $$;

-- The friends-only entry point keeps its name and signature.
create or replace function public.friend_invite(p_user uuid, p_target uuid, p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  return public.room_invite_send(p_user, null, p_target, p_room);
end $$;

-- Pending invites to this player, newest first, with the sender's public face.
create or replace function public.invites_inbox(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('id',i.id,'roomId',i.room_id,'code',r.code,
      'from',case when not i.stranger then i.from_user end,
      'name',coalesce(i.from_name,p.name,'?'),'handle',i.from_handle,
      'gender',coalesce(d.gender,p.gender,'unspecified'),
      'stranger',i.stranger,'at',i.created_at,'expiresAt',i.expires_at)
      || public.public_cosmetics(i.from_user) order by i.created_at desc),'[]'::jsonb)
    from public.room_invites i
    join public.rooms r on r.id=i.room_id
    left join public.room_players p on p.room_id=i.room_id and p.user_id=i.from_user
    left join public.player_directory d on d.user_id=i.from_user
   where i.to_user=p_user and i.status='pending' and i.expires_at > now()
     and r.status='lobby' and not public.friends_blocked(p_user, i.from_user)
$$;

create or replace function public.invite_respond(p_user uuid, p_invite uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare code text;
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  update public.room_invites i set status=case when p_accept then 'accepted' else 'declined' end
   where i.id=p_invite and i.to_user=p_user and i.status='pending';
  select r.code into code from public.room_invites i join public.rooms r on r.id=i.room_id
   where p_accept and i.id=p_invite and i.to_user=p_user and r.status='lobby'
     and i.expires_at > now();
  return jsonb_build_object('open',code is not null,'code',code,
    'invites',public.invites_inbox(p_user));
end $$;

-- A lobby that starts or closes takes its invites with it.
create or replace function public.room_invites_expire()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if new.status is distinct from old.status and new.status<>'lobby' then
    update public.room_invites set status='expired'
     where room_id=new.id and status='pending';
  end if;
  return null;
end $$;
drop trigger if exists rooms_invites_expire on public.rooms;
create trigger rooms_invites_expire after update of status on public.rooms
  for each row execute function public.room_invites_expire();

-- friends_status: the invites list becomes the inbox (ids, handle, face), and
-- the caller's own directory entry rides along.
alter function public.friends_status(uuid) rename to friends_status_pre_invites_push;
create function public.friends_status(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base := public.friends_status_pre_invites_push(p_user);
  if not coalesce((base->>'enabled')::boolean,false) then return base; end if;
  return base || jsonb_build_object('invites',public.invites_inbox(p_user),
    'me',public.directory_me(p_user));
end $$;

-- ── Push ────────────────────────────────────────────────────────────────────

create or replace function public.push_token_register(p_user uuid, p_token text, p_platform text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not public.friends_on() then raise exception 'FEATURE_OFF'; end if;
  if p_platform not in ('android','web') or length(coalesce(p_token,'')) not between 20 and 4096 then
    raise exception 'BAD_REQUEST';
  end if;
  -- A device that signs into another account moves its token with it.
  insert into public.push_tokens(token,user_id,platform) values(p_token,p_user,p_platform)
    on conflict (token) do update set user_id=excluded.user_id, platform=excluded.platform,
      updated_at=now();
  -- At most ten devices per player: the oldest go.
  delete from public.push_tokens where user_id=p_user and token in (
    select token from public.push_tokens where user_id=p_user
     order by updated_at desc offset 10);
  return jsonb_build_object('registered',true,
    'enabled',coalesce((select push_invites_enabled from public.economy_config),false));
end $$;

create or replace function public.push_token_drop(p_token text)
returns void language sql security definer set search_path=public,pg_temp as $$
  delete from public.push_tokens where token=p_token
$$;

-- What the Edge function needs to notify the recipient of one fresh invite:
-- nothing while push is off, the invite is gone, or the lobby is no longer
-- open. The payload is the room code, the sender's name and handle, the id.
create or replace function public.invite_push_targets(p_invite uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((
    select jsonb_build_object('enabled',true,'kind','invite','inviteId',i.id,'code',r.code,
        'fromName',coalesce(i.from_name,'?'),'fromHandle',coalesce(i.from_handle,''),
        'tokens',coalesce((select jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform)
          order by t.updated_at desc) from public.push_tokens t where t.user_id=i.to_user),'[]'::jsonb))
      from public.room_invites i join public.rooms r on r.id=i.room_id
     where i.id=p_invite and i.status='pending' and i.expires_at > now() and r.status='lobby'
       and coalesce((select push_invites_enabled from public.economy_config),false)),
    jsonb_build_object('enabled',false))
$$;

-- ── Capabilities ────────────────────────────────────────────────────────────

alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_invites_push;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base := public.economy_capabilities_pre_invites_push(p_user);
  return base || jsonb_build_object('social', coalesce(base->'social','{}'::jsonb)
    || jsonb_build_object('directory', public.friends_on(),
      'pushInvites', public.friends_on()
        and coalesce((select push_invites_enabled from public.economy_config),false)));
end $$;

-- ── Grants (named one by one for the server-surface test) ───────────────────

revoke all on function public.directory_norm(text) from public, anon, authenticated;
grant execute on function public.directory_norm(text) to service_role;
revoke all on function public.directory_name_norm(text) from public, anon, authenticated;
grant execute on function public.directory_name_norm(text) to service_role;
revoke all on function public.directory_like(text) from public, anon, authenticated;
grant execute on function public.directory_like(text) to service_role;
revoke all on function public.directory_level(uuid) from public, anon, authenticated;
grant execute on function public.directory_level(uuid) to service_role;
revoke all on function public.directory_state(uuid) from public, anon, authenticated;
grant execute on function public.directory_state(uuid) to service_role;
revoke all on function public.directory_is_friend(uuid,uuid) from public, anon, authenticated;
grant execute on function public.directory_is_friend(uuid,uuid) to service_role;
revoke all on function public.directory_visible(uuid,uuid) from public, anon, authenticated;
grant execute on function public.directory_visible(uuid,uuid) to service_role;
revoke all on function public.directory_row(uuid,uuid) from public, anon, authenticated;
grant execute on function public.directory_row(uuid,uuid) to service_role;
revoke all on function public.directory_rate(uuid) from public, anon, authenticated;
grant execute on function public.directory_rate(uuid) to service_role;
revoke all on function public.directory_guard(uuid) from public, anon, authenticated;
grant execute on function public.directory_guard(uuid) to service_role;
revoke all on function public.directory_free_handle(text,uuid) from public, anon, authenticated;
grant execute on function public.directory_free_handle(text,uuid) to service_role;
revoke all on function public.directory_me(uuid) from public, anon, authenticated;
grant execute on function public.directory_me(uuid) to service_role;
revoke all on function public.directory_hello(uuid,text,text,text,text) from public, anon, authenticated;
grant execute on function public.directory_hello(uuid,text,text,text,text) to service_role;
revoke all on function public.directory_set_handle(uuid,text) from public, anon, authenticated;
grant execute on function public.directory_set_handle(uuid,text) to service_role;
revoke all on function public.directory_prefs(uuid,boolean,boolean) from public, anon, authenticated;
grant execute on function public.directory_prefs(uuid,boolean,boolean) to service_role;
revoke all on function public.directory_search(uuid,text,int) from public, anon, authenticated;
grant execute on function public.directory_search(uuid,text,int) to service_role;
revoke all on function public.directory_discover(uuid,text,int) from public, anon, authenticated;
grant execute on function public.directory_discover(uuid,text,int) to service_role;
revoke all on function public.room_invite_send(uuid,text,uuid,uuid) from public, anon, authenticated;
grant execute on function public.room_invite_send(uuid,text,uuid,uuid) to service_role;
revoke all on function public.friend_invite(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_invite(uuid,uuid,uuid) to service_role;
revoke all on function public.invites_inbox(uuid) from public, anon, authenticated;
grant execute on function public.invites_inbox(uuid) to service_role;
revoke all on function public.invite_respond(uuid,uuid,boolean) from public, anon, authenticated;
grant execute on function public.invite_respond(uuid,uuid,boolean) to service_role;
revoke all on function public.room_invites_expire() from public, anon, authenticated;
revoke all on function public.friends_status_pre_invites_push(uuid) from public, anon, authenticated;
grant execute on function public.friends_status_pre_invites_push(uuid) to service_role;
revoke all on function public.friends_status(uuid) from public, anon, authenticated;
grant execute on function public.friends_status(uuid) to service_role;
revoke all on function public.push_token_register(uuid,text,text) from public, anon, authenticated;
grant execute on function public.push_token_register(uuid,text,text) to service_role;
revoke all on function public.push_token_drop(text) from public, anon, authenticated;
grant execute on function public.push_token_drop(text) to service_role;
revoke all on function public.invite_push_targets(uuid) from public, anon, authenticated;
grant execute on function public.invite_push_targets(uuid) to service_role;
revoke all on function public.economy_capabilities_pre_invites_push(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities_pre_invites_push(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
