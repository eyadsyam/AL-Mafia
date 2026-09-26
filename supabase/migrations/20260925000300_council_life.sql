-- Phase 107 "Council Life": daily and weekly contracts, Council Rank (XP and
-- levels), a weekly leaderboard, invite-a-friend and the Starter Bundle.
--
-- Additive; 20260925000100/000200 are left as they are. Every feature ships
-- OFF (missing config reads as off) and is announced through
-- `economy_capabilities` → `council`.
--
-- Zero leakage (Doc 05): every fact here is read from a room that is already
-- `finished` with a public outcome — the moment the result screen flips every
-- card. Nothing is recorded, counted or shown while a match is live, and no
-- read returns a role: records keep only the team, and only the owner ever
-- sees their own. The engine never sees any of it.
--
-- Lock order is unchanged: purchase locks (sorted by token), then wallet
-- locks (sorted by user), then rows. Invite settlement is the only place that
-- takes two wallet locks and it takes them sorted, before anything else.

-- 0. Configuration -----------------------------------------------------------
-- Caps are product rules, so an edit cannot loosen them.
alter table public.economy_config
  add column if not exists council_contracts_enabled boolean not null default false,
  add column if not exists council_rank_enabled boolean not null default false,
  add column if not exists council_leaderboard_enabled boolean not null default false,
  add column if not exists council_invites_enabled boolean not null default false,
  add column if not exists starter_bundle_enabled boolean not null default false,
  add column if not exists council_contract_bonus bigint not null default 30
    check (council_contract_bonus between 0 and 100),
  add column if not exists council_weekly_target int not null default 10
    check (council_weekly_target between 1 and 50),
  add column if not exists council_weekly_coins bigint not null default 150
    check (council_weekly_coins between 0 and 300),
  add column if not exists council_weekly_xp int not null default 150
    check (council_weekly_xp between 0 and 500),
  add column if not exists council_xp_match int not null default 30
    check (council_xp_match between 1 and 100),
  add column if not exists council_xp_win int not null default 20
    check (council_xp_win between 0 and 100),
  -- XP stops after this many matches in a UTC day: no endless farming.
  add column if not exists council_xp_daily_matches int not null default 20
    check (council_xp_daily_matches between 1 and 50),
  add column if not exists council_invite_inviter_coins bigint not null default 100
    check (council_invite_inviter_coins between 0 and 300),
  add column if not exists council_invite_invitee_coins bigint not null default 50
    check (council_invite_invitee_coins between 0 and 300),
  add column if not exists council_invite_cap int not null default 20
    check (council_invite_cap between 0 and 20);

-- 1. Ledger kinds --------------------------------------------------------------
-- Extends whatever list is current instead of restating it, so this file
-- never drops a kind another migration added.
do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check' and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds from unnest(kinds || array[
    'council_contract','council_contract_bonus','council_weekly','council_level',
    'council_invite_inviter','council_invite_invitee']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  -- Written as an IN list so the constraint reads back as quoted words the
  -- next migration's scan finds (an array literal would read back empty).
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))', (select string_agg(quote_literal(k), ',' order by k) from unnest(kinds) k));
end $$;

create or replace function public.council_week(p_day date)
returns text language sql immutable set search_path=public,pg_temp as $$
  select to_char(p_day,'IYYY-"W"IW')
$$;

create or replace function public.council_on(p_flag text)
returns boolean language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config;
begin
  select * into cfg from public.economy_config;
  return coalesce(case p_flag
    when 'contracts' then cfg.council_contracts_enabled
    when 'rank' then cfg.council_rank_enabled
    when 'leaderboard' then cfg.council_rank_enabled and cfg.council_leaderboard_enabled
    when 'invites' then cfg.council_invites_enabled
    when 'bundle' then cfg.starter_bundle_enabled
    when 'any' then cfg.council_contracts_enabled or cfg.council_rank_enabled
      or cfg.council_invites_enabled
    end, false);
end $$;

-- 2. Completed-match records -----------------------------------------------------
-- One row per player and finished match, written only after the room is
-- finished. Team, not role; kept 21 days (contracts need a week at most).
create table public.council_match_records (
  user_id uuid not null,
  room_id uuid not null,
  ended_at timestamptz not null,
  day date not null,
  week text not null,
  team text not null check (team in ('town','mafia')),
  won boolean not null,
  hosted boolean not null,
  reunion boolean not null,
  co_players uuid[] not null default '{}',
  xp int,
  created_at timestamptz not null default now(),
  primary key (user_id, room_id)
);
create index council_records_day on public.council_match_records(user_id, day);
create index council_records_week on public.council_match_records(user_id, week);

-- XP is a ledger of its own: one grant per user and source (a match, a week).
create table public.council_xp_events (
  user_id uuid not null,
  source_key text not null,
  xp int not null check (xp >= 0),
  week text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, source_key)
);
create index council_xp_week on public.council_xp_events(week, user_id);

-- What the leaderboard shows: the name and look a player last sat down with.
create table public.council_identity (
  user_id uuid primary key,
  name text not null,
  gender text not null default 'unspecified',
  updated_at timestamptz not null default now()
);

-- A player may leave the leaderboard; they still see their own position.
create table public.council_preferences (
  user_id uuid primary key,
  leaderboard_visible boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.council_contract_catalog (
  code text primary key check (code ~ '^[a-z0-9_]{3,40}$'),
  grp text not null,
  metric text not null check (metric in ('finish','town','mafia','win','host','reunion')),
  target int not null check (target between 1 and 10),
  coins bigint not null check (coins between 15 and 40),
  active boolean not null default true
);
insert into public.council_contract_catalog(code,grp,metric,target,coins) values
  ('finish_1','finish','finish',1,15),
  ('finish_3','finish','finish',3,40),
  ('finish_town','team','town',1,25),
  ('finish_mafia','team','mafia',1,30),
  ('win_1','win','win',1,30),
  ('win_2','win','win',2,40),
  ('host_1','host','host',1,25),
  ('reunion_1','reunion','reunion',1,25)
on conflict (code) do nothing;

-- The day's three, fixed the first time they are drawn: a catalog edit
-- later that day never changes what a player was offered.
create table public.council_daily_contracts (
  user_id uuid not null,
  day date not null,
  slot smallint not null check (slot between 0 and 2),
  code text not null,
  metric text not null,
  target int not null,
  coins bigint not null,
  claimed_at timestamptz,
  primary key (user_id, day, slot)
);
create index council_daily_claimed on public.council_daily_contracts(day) where claimed_at is not null;

create table public.council_rank_tiers (
  tier smallint primary key check (tier between 1 and 10),
  min_level smallint not null unique,
  title_ar text not null,
  title_en text not null
);
insert into public.council_rank_tiers(tier,min_level,title_ar,title_en) values
  (1,1,'مبتدئ','Newcomer'),
  (2,6,'مخبر','Informant'),
  (3,11,'حارس الليل','Night Watch'),
  (4,16,'محقق','Investigator'),
  (5,21,'وجيه','Notable'),
  (6,26,'عضو المجلس','Councillor'),
  (7,31,'كابو','Capo'),
  (8,36,'مستشار','Consigliere'),
  (9,41,'شيخ المجلس','Council Elder'),
  (10,46,'عرّاب','Godfather')
on conflict (tier) do nothing;

create table public.council_invite_codes (
  user_id uuid primary key,
  code text not null unique check (code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$'),
  created_at timestamptz not null default now()
);
create table public.council_invite_redemptions (
  invitee uuid primary key,
  inviter uuid,
  code text not null,
  redeemed_at timestamptz not null default now(),
  rewarded_at timestamptz,
  inviter_paid boolean not null default false,
  -- The invitee's account is gone: the row stays, under a random id, so the
  -- inviter's paid count (the cap) can never be given back by a deletion.
  detached boolean not null default false,
  check (inviter is distinct from invitee)
);
create index council_redemptions_inviter on public.council_invite_redemptions(inviter);
-- Unknown-code attempts, kept a day: guessing codes is rate limited.
create table public.council_invite_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  at timestamptz not null default now()
);
create index council_invite_attempts_user on public.council_invite_attempts(user_id, at);

alter table public.council_match_records enable row level security;
alter table public.council_xp_events enable row level security;
alter table public.council_identity enable row level security;
alter table public.council_preferences enable row level security;
alter table public.council_contract_catalog enable row level security;
alter table public.council_daily_contracts enable row level security;
alter table public.council_rank_tiers enable row level security;
alter table public.council_invite_codes enable row level security;
alter table public.council_invite_redemptions enable row level security;
alter table public.council_invite_attempts enable row level security;
revoke all on public.council_match_records, public.council_xp_events, public.council_identity,
  public.council_preferences,
  public.council_contract_catalog, public.council_daily_contracts, public.council_rank_tiers,
  public.council_invite_codes, public.council_invite_redemptions, public.council_invite_attempts
  from public, anon, authenticated;
grant all on public.council_match_records, public.council_xp_events, public.council_identity,
  public.council_preferences,
  public.council_contract_catalog, public.council_daily_contracts, public.council_rank_tiers,
  public.council_invite_codes, public.council_invite_redemptions, public.council_invite_attempts
  to service_role;

-- 3. Levels ---------------------------------------------------------------------
-- Level L needs 100(L-1) + 10(L-1)(L-2) XP in total: 100 to reach 2, then
-- each step 20 more than the last; 28 420 XP for level 50.
create or replace function public.council_level_xp(p_level int)
returns int language sql immutable set search_path=public,pg_temp as $$
  select 100*(p_level-1) + 10*(p_level-1)*(p_level-2)
$$;

create or replace function public.council_level_for(p_xp bigint)
returns int language sql immutable set search_path=public,pg_temp as $$
  select coalesce(max(l),1) from generate_series(1,50) l where public.council_level_xp(l) <= p_xp
$$;

-- Every fifth level 100, level 50 300, the rest 25: 2 175 over the ladder.
create or replace function public.council_level_coins(p_level int)
returns bigint language sql immutable set search_path=public,pg_temp as $$
  select case when p_level=50 then 300 when p_level % 5 = 0 then 100 else 25 end::bigint
$$;

-- 4. Recording a finished match ------------------------------------------------
-- The same eligibility the completion reward uses. Returns true when a new
-- record was written. Takes no lock; callers that credit coins hold the
-- wallet lock.
create or replace function public.council_record_match(p_user uuid, p_room uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare m record; v_team text; mates uuid[]; n int;
begin
  if not public.council_on('any') then return false; end if;
  select r.id, r.ended_at, r.host_id, p.role, p.name, p.gender, s.public_data->>'outcome' as outcome
    into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found then return false; end if;
  v_team := case when m.role='mafia' then 'mafia' else 'town' end;
  select coalesce(array_agg(user_id order by user_id), '{}') into mates
    from public.room_players where room_id=p_room and user_id<>p_user and not kicked
      and role is not null;
  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,
      reunion,co_players)
    values(p_user,p_room,m.ended_at,(m.ended_at at time zone 'utc')::date,
      public.council_week((m.ended_at at time zone 'utc')::date),v_team,v_team=m.outcome,
      m.host_id is not distinct from p_user,
      exists(select 1 from public.council_match_records o where o.user_id=p_user
        and o.room_id<>p_room and o.ended_at < m.ended_at
        and o.ended_at > m.ended_at - interval '7 days' and o.co_players && mates),
      mates)
    on conflict do nothing;
  get diagnostics n=row_count;
  if n=0 then return false; end if;
  insert into public.council_identity(user_id,name,gender,updated_at)
    values(p_user,left(btrim(m.name),40),coalesce(m.gender,'unspecified'),now())
    on conflict (user_id) do update set name=excluded.name, gender=excluded.gender,
      updated_at=now()
    where council_identity.updated_at <= excluded.updated_at;
  return true;
end $$;

-- XP for recorded matches that have none yet. Rank must be on.
create or replace function public.council_grant_xp(p_user uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; rec public.council_match_records; earned int; used int;
begin
  if not public.council_on('rank') then return; end if;
  select * into cfg from public.economy_config;
  for rec in select * from public.council_match_records
      where user_id=p_user and xp is null order by ended_at, room_id loop
    select count(*) into used from public.council_match_records
     where user_id=p_user and day=rec.day and xp > 0;
    earned := case when used >= cfg.council_xp_daily_matches then 0
      else cfg.council_xp_match + case when rec.won then cfg.council_xp_win else 0 end end;
    insert into public.council_xp_events(user_id,source_key,xp,week)
      values(p_user,'match:'||rec.room_id,earned,rec.week) on conflict do nothing;
    update public.council_match_records set xp=earned
     where user_id=p_user and room_id=rec.room_id;
  end loop;
end $$;

-- Records a match the moment its completion reward is written. A failure
-- here must never cost a player the completion coins, so it is contained;
-- `council_sync` picks the match up again while the room exists (24 h).
create or replace function public.council_on_completion()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  begin
    if public.council_record_match(new.user_id, new.source_room) then
      perform public.council_grant_xp(new.user_id);
    end if;
  exception when others then
    raise warning 'council_on_completion: %', sqlerrm;
  end;
  return new;
end $$;
create trigger wallet_ledger_council_record after insert on public.wallet_ledger
  for each row when (new.kind='match_completion' and new.source_room is not null)
  execute function public.council_on_completion();

-- Records every eligible finished room, grants XP and level coins, prunes old
-- records. Holds the caller's wallet lock. Returns the levels credited now.
create or replace function public.council_sync(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare room uuid; total bigint; lvl int; l int; ups jsonb := '[]';
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not public.council_on('any') then return ups; end if;
  for room in
    select r.id from public.rooms r join public.room_players p on p.room_id=r.id
     where p.user_id=p_user and not p.kicked and p.role is not null
       and r.status='finished' and r.ended_at is not null
       and not exists(select 1 from public.council_match_records c
         where c.user_id=p_user and c.room_id=r.id)
     order by r.ended_at
  loop
    perform public.council_record_match(p_user, room);
  end loop;
  delete from public.council_match_records
   where user_id=p_user and ended_at < now() - interval '21 days';
  if public.council_on('rank') then
    perform public.council_grant_xp(p_user);
    select coalesce(sum(xp),0) into total from public.council_xp_events where user_id=p_user;
    lvl := public.council_level_for(total);
    for l in 2..lvl loop
      if public.credit_earned(p_user,'council_level',public.council_level_coins(l),null,'level:'||l) then
        ups := ups || jsonb_build_object('level',l,'coins',public.council_level_coins(l));
      end if;
    end loop;
  end if;
  return ups;
end $$;

-- 5. Invites -----------------------------------------------------------------------
-- Pays redemptions whose invitee has since completed an online match. Takes
-- both wallet locks sorted, first thing in the transaction.
create or replace function public.council_settle_invites(p_user uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; users uuid[]; u uuid; r public.council_invite_redemptions;
  paid int; pay_inviter boolean;
begin
  if not public.council_on('invites') then return; end if;
  select * into cfg from public.economy_config;
  select coalesce(array_agg(distinct x order by x), '{}') into users from (
    select p_user as x
    union select invitee from public.council_invite_redemptions
      where rewarded_at is null and (invitee=p_user or inviter=p_user)
    union select inviter from public.council_invite_redemptions
      where rewarded_at is null and invitee=p_user and inviter is not null) s;
  foreach u in array users loop
    perform pg_advisory_xact_lock(hashtextextended('wallet:'||u::text,91));
  end loop;
  for r in select * from public.council_invite_redemptions
      where rewarded_at is null and not detached and (invitee=p_user or inviter=p_user)
      order by redeemed_at limit 50 for update loop
    -- Only rows whose every wallet is in the sorted set locked above: a
    -- redemption committed after the set was read waits for the next call.
    continue when not (r.invitee = any(users))
      or (r.inviter is not null and not (r.inviter = any(users)));
    continue when not exists(select 1 from public.wallet_ledger
      where user_id=r.invitee and kind='match_completion' and source_room is not null);
    perform public.credit_earned(r.invitee,'council_invite_invitee',
      cfg.council_invite_invitee_coins,null,'invitee') where cfg.council_invite_invitee_coins > 0;
    select count(*) into paid from public.council_invite_redemptions
     where inviter=r.inviter and inviter_paid;
    pay_inviter := r.inviter is not null and paid < cfg.council_invite_cap;
    if pay_inviter and cfg.council_invite_inviter_coins > 0 then
      perform public.credit_earned(r.inviter,'council_invite_inviter',
        cfg.council_invite_inviter_coins,null,r.invitee::text);
    end if;
    update public.council_invite_redemptions set rewarded_at=now(), inviter_paid=pay_inviter
     where invitee=r.invitee;
  end loop;
end $$;

create or replace function public.council_account_created(p_user uuid)
returns timestamptz language plpgsql stable security definer set search_path=public,pg_temp as $$
declare j jsonb;
begin
  -- Read through jsonb so a schema without the column reads as unknown.
  select to_jsonb(u) into j from auth.users u where u.id=p_user;
  return (j->>'created_at')::timestamptz;
end $$;

create or replace function public.council_invite_status(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; mine public.council_invite_codes;
  red public.council_invite_redemptions; created timestamptz; alphabet text :=
  'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; candidate text; i int; tries int := 0;
begin
  select * into cfg from public.economy_config;
  if not public.council_on('invites') then
    return jsonb_build_object('enabled',false);
  end if;
  select * into mine from public.council_invite_codes where user_id=p_user;
  while mine.user_id is null and tries < 8 loop
    tries := tries + 1;
    candidate := '';
    for i in 1..7 loop
      candidate := candidate || substr(alphabet, public.secure_random_below(32)+1, 1);
    end loop;
    insert into public.council_invite_codes(user_id,code) values(p_user,candidate)
      on conflict do nothing;
    select * into mine from public.council_invite_codes where user_id=p_user;
  end loop;
  select * into red from public.council_invite_redemptions where invitee=p_user;
  created := public.council_account_created(p_user);
  return jsonb_build_object('enabled',true,
    'code',mine.code,
    'inviterCoins',cfg.council_invite_inviter_coins,
    'inviteeCoins',cfg.council_invite_invitee_coins,
    'cap',cfg.council_invite_cap,
    'rewarded',(select count(*) from public.council_invite_redemptions
      where inviter=p_user and inviter_paid),
    'pending',(select count(*) from public.council_invite_redemptions
      where inviter=p_user and rewarded_at is null and not detached),
    'redeemed',case when red.invitee is null then null else jsonb_build_object(
      'at',red.redeemed_at,'rewarded',red.rewarded_at is not null) end,
    'canRedeem',red.invitee is null and created is not null
      and created > now() - interval '7 days'
      and not exists(select 1 from public.wallet_ledger where user_id=p_user
        and kind='match_completion'),
    'redeemUntil',case when created is null then null else created + interval '7 days' end);
end $$;

create or replace function public.council_invite(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.council_settle_invites(p_user);
  perform public.council_sync(p_user);
  return public.council_invite_status(p_user);
end $$;

create or replace function public.redeem_council_invite(p_user uuid, p_code text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; v_code text := upper(btrim(coalesce(p_code,'')));
  owner uuid; existing public.council_invite_redemptions; created timestamptz;
begin
  if not public.council_on('invites') then raise exception 'FEATURE_OFF'; end if;
  select * into cfg from public.economy_config;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into existing from public.council_invite_redemptions where invitee=p_user;
  if existing.invitee is not null then
    -- A retry of the same redemption is not an error.
    if existing.code=v_code then
      return public.council_invite_status(p_user) || jsonb_build_object('status','redeemed');
    end if;
    raise exception 'INVITE_ALREADY';
  end if;
  if (select count(*) from public.council_invite_attempts
      where user_id=p_user and at > now() - interval '1 day') >= 10 then
    raise exception 'INVITE_RATE_LIMIT';
  end if;
  select c.user_id into owner from public.council_invite_codes c where c.code=v_code;
  if owner is null then
    -- Recorded, not raised, so the attempt counts toward the limit.
    insert into public.council_invite_attempts(user_id) values(p_user);
    delete from public.council_invite_attempts where at < now() - interval '1 day';
    return public.council_invite_status(p_user) || jsonb_build_object('status','not_found');
  end if;
  -- The tag binds purchases to one account; one account can never be both
  -- sides of an invite.
  if owner=p_user or public.account_tag(owner)=public.account_tag(p_user) then
    raise exception 'INVITE_SELF';
  end if;
  created := public.council_account_created(p_user);
  if created is null or created <= now() - interval '7 days' then
    raise exception 'INVITE_EXPIRED';
  end if;
  -- A new account: no completed online match yet, recorded or waiting.
  if exists(select 1 from public.wallet_ledger where user_id=p_user and kind='match_completion')
     or exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
       join public.room_state s on s.room_id=r.id
       where p.user_id=p_user and not p.kicked and p.role is not null
         and r.status='finished' and s.public_data->>'outcome' in ('mafia','town')) then
    raise exception 'INVITE_NOT_NEW';
  end if;
  if exists(select 1 from public.council_invite_redemptions where invitee=owner and inviter=p_user) then
    raise exception 'INVITE_LOOP';
  end if;
  if (select count(*) from public.council_invite_redemptions where inviter=owner and inviter_paid)
      >= cfg.council_invite_cap then
    raise exception 'INVITE_LIMIT';
  end if;
  insert into public.council_invite_redemptions(invitee,inviter,code) values(p_user,owner,v_code);
  return public.council_invite_status(p_user) || jsonb_build_object('status','redeemed');
end $$;

-- 6. Daily and weekly contracts ------------------------------------------------------
-- Slot 0 is always a "finish" contract, so every day has one a single match
-- completes; slots 1 and 2 come from two other groups. Deterministic per
-- player and day.
create or replace function public.council_draw_contracts(p_user uuid, p_day date)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if exists(select 1 from public.council_daily_contracts where user_id=p_user and day=p_day) then
    return;
  end if;
  with scored as (
    select c.*, hashtextextended(p_user::text||':'||p_day::text||':'||c.code, 107) as h
      from public.council_contract_catalog c where c.active
  ), per_group as (
    select distinct on (grp) * from scored order by grp, h
  ), ordered as (
    select *, row_number() over (order by (grp<>'finish'), h) - 1 as slot from per_group
  )
  insert into public.council_daily_contracts(user_id,day,slot,code,metric,target,coins)
    select p_user,p_day,slot,code,metric,target,coins from ordered where slot < 3
    on conflict do nothing;
end $$;

create or replace function public.council_metric(p_user uuid, p_day date, p_metric text)
returns int language sql stable security definer set search_path=public,pg_temp as $$
  select count(*)::int from public.council_match_records
   where user_id=p_user and day=p_day and case p_metric
     when 'finish' then true when 'town' then team='town' when 'mafia' then team='mafia'
     when 'win' then won when 'host' then hosted when 'reunion' then reunion else false end
$$;

create or replace function public.council_contracts_status(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; today date := public.economy_today(); wk text;
  list jsonb; claimed int; weekly int; weekly_claimed boolean;
begin
  if not public.council_on('contracts') then return jsonb_build_object('enabled',false); end if;
  select * into cfg from public.economy_config;
  wk := public.council_week(today);
  perform public.council_draw_contracts(p_user, today);
  select jsonb_agg(jsonb_build_object('slot',slot,'code',code,'metric',metric,
      'target',target,'coins',coins,
      'progress',least(public.council_metric(p_user,today,metric),target),
      'claimed',claimed_at is not null,
      'claimable',claimed_at is null and public.council_metric(p_user,today,metric) >= target)
      order by slot), count(*) filter (where claimed_at is not null)
    into list, claimed
    from public.council_daily_contracts where user_id=p_user and day=today;
  select count(*) into weekly from public.council_match_records r where r.user_id=p_user and r.week=wk;
  weekly_claimed := exists(select 1 from public.wallet_ledger where user_id=p_user
    and kind='council_weekly' and source_key=wk);
  return jsonb_build_object('enabled',true,'day',today,
    'nextDayAt',(today + 1)::timestamp at time zone 'utc',
    'contracts',coalesce(list,'[]'),
    'bonus',jsonb_build_object('coins',cfg.council_contract_bonus,'claimed',exists(
      select 1 from public.wallet_ledger where user_id=p_user and kind='council_contract_bonus'
        and source_key=today::text),'done',claimed),
    'weekly',jsonb_build_object('week',wk,
      'nextWeekAt',(today - extract(isodow from today)::int + 8)::timestamp at time zone 'utc',
      'target',cfg.council_weekly_target,'progress',least(weekly,cfg.council_weekly_target),
      'coins',cfg.council_weekly_coins,
      'xp',case when public.council_on('rank') then cfg.council_weekly_xp else 0 end,
      'claimed',weekly_claimed,
      'claimable',not weekly_claimed and weekly >= cfg.council_weekly_target));
end $$;

create or replace function public.council_contracts(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare ups jsonb;
begin
  perform public.council_settle_invites(p_user);
  ups := public.council_sync(p_user);
  return public.council_contracts_status(p_user) || jsonb_build_object('levelUps',ups);
end $$;

create or replace function public.claim_council_contract(p_user uuid, p_day date, p_slot int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; today date := public.economy_today(); c public.council_daily_contracts;
  granted bigint := 0; bonus bigint := 0;
begin
  if p_slot is null or p_slot not between 0 and 2 then raise exception 'BAD_REQUEST'; end if;
  perform public.council_settle_invites(p_user);
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not public.council_on('contracts') then raise exception 'FEATURE_OFF'; end if;
  select * into cfg from public.economy_config;
  -- Like the coffer: the request names the server day it was made for.
  if p_day is null then raise exception 'DAY_REQUIRED'; end if;
  if p_day<>today then raise exception 'DAY_CHANGED'; end if;
  perform public.council_sync(p_user);
  perform public.council_draw_contracts(p_user, today);
  select * into c from public.council_daily_contracts
   where user_id=p_user and day=today and slot=p_slot for update;
  if c.user_id is null then raise exception 'BAD_REQUEST'; end if;
  if c.claimed_at is null then
    if public.council_metric(p_user,today,c.metric) < c.target then
      raise exception 'CONTRACT_INCOMPLETE';
    end if;
    if (select count(*) from public.council_daily_contracts where day=today and claimed_at is not null)
        >= cfg.daily_global_cap * 3 then
      raise exception 'DAILY_PAUSED';
    end if;
    update public.council_daily_contracts set claimed_at=now()
     where user_id=p_user and day=today and slot=p_slot;
    if public.credit_earned(p_user,'council_contract',c.coins,null,today::text||':'||p_slot) then
      granted := c.coins;
    end if;
    if cfg.council_contract_bonus > 0 and (select count(*) from public.council_daily_contracts
        where user_id=p_user and day=today and claimed_at is not null)=3 then
      if public.credit_earned(p_user,'council_contract_bonus',cfg.council_contract_bonus,null,today::text) then
        bonus := cfg.council_contract_bonus;
      end if;
    end if;
  end if;
  return public.council_contracts_status(p_user) || jsonb_build_object('granted',granted,
    'bonusGranted',bonus,'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;

create or replace function public.claim_council_weekly(p_user uuid, p_week text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; wk text := public.council_week(public.economy_today());
  done int; granted bigint := 0; xp_granted int := 0;
begin
  perform public.council_settle_invites(p_user);
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not public.council_on('contracts') then raise exception 'FEATURE_OFF'; end if;
  select * into cfg from public.economy_config;
  if p_week is null then raise exception 'WEEK_REQUIRED'; end if;
  if p_week<>wk then raise exception 'WEEK_CHANGED'; end if;
  perform public.council_sync(p_user);
  if not exists(select 1 from public.wallet_ledger where user_id=p_user
      and kind='council_weekly' and source_key=wk) then
    select count(*) into done from public.council_match_records r
     where r.user_id=p_user and r.week=wk;
    if done < cfg.council_weekly_target then raise exception 'CONTRACT_INCOMPLETE'; end if;
    -- The ledger row is the claim; a zero-coin week still needs one.
    if public.credit_earned(p_user,'council_weekly',greatest(cfg.council_weekly_coins,1),null,wk) then
      granted := greatest(cfg.council_weekly_coins,1);
      if public.council_on('rank') and cfg.council_weekly_xp > 0 then
        insert into public.council_xp_events(user_id,source_key,xp,week)
          values(p_user,'weekly:'||wk,cfg.council_weekly_xp,wk) on conflict do nothing;
        xp_granted := cfg.council_weekly_xp;
      end if;
    end if;
  end if;
  return public.council_contracts_status(p_user) || jsonb_build_object('granted',granted,
    'xpGranted',xp_granted,'levelUps',public.council_sync(p_user),
    'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;

-- 7. Rank and leaderboard ---------------------------------------------------------
create or replace function public.council_visible(p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select leaderboard_visible from public.council_preferences
    where user_id=p_user), true)
$$;

-- The player's own choice; takes effect on the next leaderboard read.
create or replace function public.set_council_leaderboard_visible(p_user uuid, p_visible boolean)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_visible is null then raise exception 'BAD_REQUEST'; end if;
  insert into public.council_preferences(user_id,leaderboard_visible,updated_at)
    values(p_user,p_visible,now())
    on conflict (user_id) do update set leaderboard_visible=excluded.leaderboard_visible,
      updated_at=now();
  return jsonb_build_object('leaderboardVisible',p_visible);
end $$;

create or replace function public.council_rank_of(p_xp bigint)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare lvl int := public.council_level_for(p_xp); t public.council_rank_tiers;
begin
  select * into t from public.council_rank_tiers where min_level<=lvl order by min_level desc limit 1;
  return jsonb_build_object('level',lvl,'tier',t.tier,'titleAr',t.title_ar,'titleEn',t.title_en);
end $$;

create or replace function public.council_rank(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare ups jsonb; total bigint; lvl int; wk text := public.council_week(public.economy_today());
begin
  perform public.council_settle_invites(p_user);
  ups := public.council_sync(p_user);
  if not public.council_on('rank') then return jsonb_build_object('enabled',false); end if;
  select coalesce(sum(xp),0) into total from public.council_xp_events where user_id=p_user;
  lvl := public.council_level_for(total);
  return public.council_rank_of(total) || jsonb_build_object('enabled',true,'xp',total,
    'maxLevel',50,
    'levelXp',public.council_level_xp(lvl),
    'nextLevelXp',case when lvl<50 then public.council_level_xp(lvl+1) end,
    'nextReward',case when lvl<50 then public.council_level_coins(lvl+1) end,
    'weekXp',(select coalesce(sum(e.xp),0) from public.council_xp_events e
      where e.user_id=p_user and e.week=wk),
    'leaderboardVisible',public.council_visible(p_user),
    'levelUps',ups);
end $$;

-- Public by design: display name, avatar look, frame, level and week XP.
-- No user ids, no per-match rows, no team or role.
create or replace function public.council_leaderboard(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); wk text := public.council_week(today);
  top jsonb; me jsonb;
begin
  perform public.council_settle_invites(p_user);
  perform public.council_sync(p_user);
  if not public.council_on('leaderboard') then return jsonb_build_object('enabled',false); end if;
  with board as (
    select e.user_id, sum(e.xp) as xp, rank() over (order by sum(e.xp) desc) as pos
      from public.council_xp_events e where e.week=wk
       and (e.user_id=p_user or public.council_visible(e.user_id))
     group by e.user_id having sum(e.xp) > 0
  ), shown as (
    -- A hidden caller is ranked for their own eyes only.
    select * from board where public.council_visible(user_id)
     order by pos, user_id limit 50
  )
  select coalesce(jsonb_agg(jsonb_build_object('position',b.pos,'xp',b.xp,
      'name',coalesce(i.name,'—'),'gender',coalesce(i.gender,'unspecified'),
      'frame',(select q.item_code from public.player_equipment q
        where q.user_id=b.user_id and q.slot='frame'),
      'me',b.user_id=p_user) || public.council_rank_of(
        (select sum(a.xp) from public.council_xp_events a where a.user_id=b.user_id))
      order by b.pos, i.name), '[]'),
    (select jsonb_build_object('position',x.pos,'xp',x.xp) from board x where x.user_id=p_user)
    into top, me
    from shown b
    left join public.council_identity i on i.user_id=b.user_id
   -- Someone the caller blocked, or who blocked them, is left out of their view.
   where not exists(select 1 from public.player_blocks k
     where (k.blocker_id=p_user and k.blocked_id=b.user_id)
        or (k.blocker_id=b.user_id and k.blocked_id=p_user));
  return jsonb_build_object('enabled',true,'week',wk,
    'nextWeekAt',(today - extract(isodow from today)::int + 8)::timestamp at time zone 'utc',
    'entries',top,'me',coalesce(me,jsonb_build_object('position',null,'xp',0)),
    'visible',public.council_visible(p_user));
end $$;

-- 8. Starter Bundle ---------------------------------------------------------------
-- A one-time Play product: coins (settled exactly like a coin pack, debt and
-- refund included) plus one cosmetic sold nowhere else. Never consumed, so
-- Play itself keeps it one-per-Google-account; the server keeps it one per
-- game account.
insert into public.reward_catalog(code,coin_price,sort_order,kind,slot,contents,active,released)
  values('frame_council_seal',1500,140,'frame','frame','{}',false,false)
on conflict (code) do nothing;

alter table public.play_products add column if not exists item_code text
  references public.reward_catalog(code);
do $$
declare c record;
begin
  for c in select conname from pg_constraint
      where conrelid='public.play_products'::regclass and contype='c' loop
    execute format('alter table public.play_products drop constraint %I', c.conname);
  end loop;
end $$;
alter table public.play_products add constraint play_products_id_shape
  check (product_id ~ '^[a-z0-9_.]{3,100}$');
alter table public.play_products add constraint play_products_shape check (
  (kind='entitlement' and entitlement is not null and coins is null and item_code is null) or
  (kind='coins' and coins > 0 and entitlement is null and item_code is null) or
  (kind='bundle' and coins > 0 and item_code is not null and entitlement is null));
insert into public.play_products(product_id,kind,coins,entitlement,item_code,sort_order) values
  ('mm_starter_bundle','bundle',600,null,'frame_council_seal',5)
on conflict (product_id) do nothing;

-- Another granted, unreversed bundle on this account (not this token).
create or replace function public.owns_starter_bundle(p_user uuid, p_except text default null)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.play_purchases p join public.play_products x
    on x.product_id=p.product_id and x.kind='bundle'
    where p.user_id=p_user and p.granted_at is not null and p.reversed_at is null
      and p.state='active' and p.purchase_token is distinct from p_except)
$$;

-- Takes one granted bundle back: its coins as reverse_play_coins does, and
-- its cosmetic (the purchased good itself, never bought with coins) unless
-- another live bundle still covers it. Caller holds purchase, wallet and row
-- locks.
create or replace function public.reverse_play_bundle(p_token text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare hit public.play_purchases; item text;
begin
  select * into hit from public.play_purchases where purchase_token=p_token;
  select item_code into item from public.play_products where product_id=hit.product_id;
  if not public.reverse_play_coins(p_token) then return false; end if;
  if hit.user_id is not null and not public.owns_starter_bundle(hit.user_id, p_token) then
    delete from public.player_inventory where user_id=hit.user_id and item_code=item;
  end if;
  return true;
end $$;

create or replace function public.commit_play_bundle(
  p_user uuid, p_token text, p_product text, p_order text, p_state text,
  p_purchased_at timestamptz, p_quantity int, p_account_tag text
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare product public.play_products; existing public.play_purchases; rec public.play_purchases;
  w public.wallet_accounts; hash text; offset_debt bigint; credit bigint; effective text;
  already boolean := false;
begin
  if p_token is null or length(p_token)<8 or p_state not in ('active','pending','revoked')
    or coalesce(p_quantity,1)<>1 then
    raise exception 'INVALID_PURCHASE';
  end if;
  select * into product from public.play_products where product_id=p_product and kind='bundle';
  if product.product_id is null then raise exception 'PRODUCT_UNKNOWN'; end if;
  if p_account_tag is null or p_account_tag<>public.account_tag(p_user) then
    raise exception 'ACCOUNT_MISMATCH';
  end if;
  hash := public.play_token_hash(p_token);
  perform pg_advisory_xact_lock(hashtextextended('purchase:'||p_token,97));
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  select * into existing from public.play_purchases where purchase_token=p_token for update;
  if existing.purchase_token is not null and existing.product_id<>p_product then
    raise exception 'INVALID_PURCHASE';
  end if;
  if existing.purchase_token is not null and existing.user_id is not null
     and existing.user_id<>p_user then
    raise exception 'ACCOUNT_MISMATCH';
  end if;
  -- Granted to an account that has since been deleted: the grant went with
  -- it. Refused plainly rather than answered granted:true with nothing given.
  if existing.purchase_token is not null and existing.user_id is null
     and existing.granted_at is not null then
    raise exception 'OWNER_DELETED';
  end if;
  effective := case
    when public.play_is_voided(hash, coalesce(p_order, existing.order_id)) then 'revoked'
    when existing.state='revoked' then 'revoked'
    else p_state end;
  insert into public.play_purchases(purchase_token,user_id,product_id,order_id,state,
      purchased_at,token_hash,quantity)
    values(p_token,p_user,p_product,p_order,effective,p_purchased_at,hash,1)
    on conflict(purchase_token) do update set
      order_id=coalesce(excluded.order_id,play_purchases.order_id),
      state=case when play_purchases.state='revoked' then 'revoked' else excluded.state end,
      purchased_at=coalesce(excluded.purchased_at,play_purchases.purchased_at),
      verified_at=now();
  select * into rec from public.play_purchases where purchase_token=p_token for update;
  if rec.state='active' and rec.granted_at is null then
    if public.owns_starter_bundle(p_user, p_token) then
      -- Once per account. Left unacknowledged, so Play refunds it by itself.
      already := true;
    else
      select * into w from public.wallet_accounts where user_id=p_user for update;
      offset_debt := least(w.purchase_debt, product.coins);
      credit := product.coins - offset_debt;
      update public.wallet_accounts set balance=balance+credit,
        purchased_balance=purchased_balance+credit,
        lifetime_purchased=lifetime_purchased+product.coins,
        purchase_debt=purchase_debt-offset_debt, updated_at=now()
       where user_id=p_user;
      if credit > 0 then
        insert into public.wallet_ledger(user_id,kind,amount,source_key)
          values(p_user,'play_coin_purchase',credit,hash);
      end if;
      insert into public.player_inventory(user_id,item_code) values(p_user,product.item_code)
        on conflict do nothing;
      update public.play_purchases set granted_at=now(), credited=credit, debt_offset=offset_debt
       where purchase_token=p_token returning * into rec;
    end if;
  elsif rec.state='revoked' and rec.granted_at is not null and rec.reversed_at is null then
    perform public.reverse_play_bundle(p_token);
    select * into rec from public.play_purchases where purchase_token=p_token;
  end if;
  return jsonb_build_object('state',rec.state,'product',p_product,'kind','bundle',
    'granted',rec.granted_at is not null and rec.state='active' and rec.reversed_at is null,
    'alreadyOwned',already,'credited',rec.credited,'coins',product.coins,'item',product.item_code,
    'needsAcknowledge',rec.granted_at is not null and rec.state='active' and rec.reversed_at is null,
    'needsConsume',false,
    'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;

-- The existing entry points keep their names and signatures; bundles are
-- routed to the function above and everything else runs unchanged.
alter function public.commit_play_product(uuid,text,text,text,text,timestamptz,int,text)
  rename to commit_play_product_base;
create function public.commit_play_product(
  p_user uuid, p_token text, p_product text, p_order text, p_state text,
  p_purchased_at timestamptz, p_quantity int default 1, p_account_tag text default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if exists(select 1 from public.play_products where product_id=p_product and kind='bundle') then
    return public.commit_play_bundle(p_user,p_token,p_product,p_order,p_state,
      p_purchased_at,p_quantity,p_account_tag);
  end if;
  return public.commit_play_product_base(p_user,p_token,p_product,p_order,p_state,
    p_purchased_at,p_quantity,p_account_tag);
end $$;

-- Voids: bundles are settled first (coins and cosmetic), under the same
-- sorted locks the base function takes, which then finds them settled.
alter function public.revoke_voided_play_purchases(text[],text[])
  rename to revoke_voided_play_purchases_base;
create function public.revoke_voided_play_purchases(p_tokens text[], p_orders text[])
returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare changed int := 0; tokens text[]; users uuid[]; t text; u uuid; hit public.play_purchases;
begin
  insert into public.play_void_tombstones(token_hash)
    select distinct public.play_token_hash(x) from unnest(coalesce(p_tokens,'{}'::text[])) x
     where x is not null and length(x) >= 8
    on conflict do nothing;
  insert into public.play_void_tombstones(order_id)
    select distinct x from unnest(coalesce(p_orders,'{}'::text[])) x where x is not null and x <> ''
    on conflict do nothing;
  select coalesce(array_agg(p.purchase_token order by p.purchase_token), '{}') into tokens
    from public.play_purchases p
   where not (p.state='revoked' and (p.granted_at is null or p.reversed_at is not null))
     and exists(select 1 from public.play_void_tombstones v
       where v.token_hash=p.token_hash or (p.order_id is not null and v.order_id=p.order_id));
  foreach t in array tokens loop
    perform pg_advisory_xact_lock(hashtextextended('purchase:'||t,97));
  end loop;
  select coalesce(array_agg(distinct user_id order by user_id), '{}') into users
    from public.play_purchases where purchase_token=any(tokens) and user_id is not null;
  foreach u in array users loop
    perform pg_advisory_xact_lock(hashtextextended('wallet:'||u::text,91));
  end loop;
  for hit in
    select p.* from public.play_purchases p join public.play_products x
        on x.product_id=p.product_id and x.kind='bundle'
     where p.purchase_token=any(tokens) order by p.purchase_token for update of p
  loop
    changed := changed + 1;
    if hit.granted_at is not null and hit.reversed_at is null then
      perform public.reverse_play_bundle(hit.purchase_token);
    end if;
    update public.play_purchases set state='revoked', verified_at=now(),
      reversed_at=coalesce(reversed_at,now())
     where purchase_token=hit.purchase_token;
  end loop;
  return changed + public.revoke_voided_play_purchases_base(p_tokens, p_orders);
end $$;

-- 9. Capabilities ------------------------------------------------------------------
alter function public.economy_capabilities(uuid) rename to economy_capabilities_base;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb := public.economy_capabilities_base(p_user); products jsonb;
  owned boolean := public.owns_starter_bundle(p_user);
begin
  -- The bundle is offered only while its flag is on and the account has none.
  select coalesce(jsonb_agg(jsonb_build_object('id',product_id,'kind',kind,'coins',coins,
      'entitlement',entitlement,'item',item_code) order by sort_order),'[]')
    into products from public.play_products
   where active and (kind<>'bundle' or (public.council_on('bundle') and not owned));
  return base || jsonb_build_object('products',products,
    'council',jsonb_build_object(
      'contracts',public.council_on('contracts'),
      'rank',public.council_on('rank'),
      'leaderboard',public.council_on('leaderboard'),
      'invites',public.council_on('invites'),
      'starterBundle',public.council_on('bundle'),
      'starterBundleOwned',owned));
end $$;

-- 9b. Rank on the seat -------------------------------------------------------------
-- Copied with the frame and plate when a player takes a seat, so it is fixed
-- for the whole match and says nothing about this match: a level earned from
-- matches already over. Only while rank is on.
create or replace function public.seat_cosmetics()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  new.cosmetics := coalesce((select jsonb_object_agg(slot,item_code)
    from public.player_equipment where user_id=new.user_id and slot in ('frame','nameplate')),'{}');
  if public.council_on('rank') then
    new.cosmetics := new.cosmetics || jsonb_build_object('rank', public.council_level_for(
      (select coalesce(sum(xp),0) from public.council_xp_events where user_id=new.user_id)));
  end if;
  return new;
end $$;

-- 10. Deletion covers the new records --------------------------------------------
create or replace function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests where id=p_request and completed_at is null for update;
  if who is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
    where p.user_id=who and r.status<>'finished') then raise exception 'ACTIVE_ROOM'; end if;
  if exists(select 1 from public.coin_orders where user_id=who
    and status in ('claimed','needs_info')) then raise exception 'ORDER_UNDER_REVIEW'; end if;
  update public.coin_orders set user_id=null, payer_hint=null where user_id=who;
  delete from public.player_equipment where user_id=who;
  delete from public.player_entitlements where user_id=who;
  update public.play_purchases set user_id=null where user_id=who;
  delete from public.ad_reward_claims where user_id=who;
  delete from public.ad_step_claims where user_id=who;
  delete from public.daily_ad_claims where user_id=who;
  delete from public.daily_claims where user_id=who;
  update public.ad_ssv_transactions set user_id=null where user_id=who;
  delete from public.council_match_records where user_id=who;
  update public.council_match_records set co_players=array_remove(co_players,who)
   where co_players @> array[who];
  delete from public.council_xp_events where user_id=who;
  delete from public.council_identity where user_id=who;
  delete from public.council_preferences where user_id=who;
  delete from public.council_daily_contracts where user_id=who;
  delete from public.council_invite_codes where user_id=who;
  delete from public.council_invite_attempts where user_id=who;
  update public.council_invite_redemptions set invitee=gen_random_uuid(), detached=true
   where invitee=who;
  update public.council_invite_redemptions set inviter=null where inviter=who;
  delete from public.rooms where id in (select room_id from public.room_players where user_id=who);
  delete from public.player_blocks where blocker_id=who or blocked_id=who;
  delete from public.player_inventory where user_id=who;
  delete from public.wallet_ledger where user_id=who;
  delete from public.wallet_accounts where user_id=who;
  delete from auth.users where id=who;
  update public.data_deletion_requests set completed_at=now() where id=p_request;
end $$;

create or replace function public.purge_orphan_economy()
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare removed integer;
begin
  delete from public.player_equipment e where not exists(select 1 from auth.users u where u.id=e.user_id);
  delete from public.player_inventory i where not exists(select 1 from auth.users u where u.id=i.user_id);
  delete from public.daily_claims d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.daily_ad_claims d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.council_match_records d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.council_xp_events d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.council_identity d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.council_preferences d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.council_daily_contracts d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.council_invite_codes d where not exists(select 1 from auth.users u where u.id=d.user_id);
  delete from public.council_invite_attempts d where not exists(select 1 from auth.users u where u.id=d.user_id);
  update public.council_invite_redemptions d set invitee=gen_random_uuid(), detached=true
   where not d.detached and not exists(select 1 from auth.users u where u.id=d.invitee);
  delete from public.wallet_ledger l where not exists(select 1 from auth.users u where u.id=l.user_id);
  with gone as (
    delete from public.wallet_accounts a where not exists(select 1 from auth.users u where u.id=a.user_id)
    returning 1
  ) select count(*) into removed from gone;
  return removed;
end $$;

-- 11. Grants: named one by one ------------------------------------------------------
revoke all on function public.council_week(date) from public, anon, authenticated;
grant execute on function public.council_week(date) to service_role;
revoke all on function public.council_on(text) from public, anon, authenticated;
grant execute on function public.council_on(text) to service_role;
revoke all on function public.council_level_xp(int) from public, anon, authenticated;
grant execute on function public.council_level_xp(int) to service_role;
revoke all on function public.council_level_for(bigint) from public, anon, authenticated;
grant execute on function public.council_level_for(bigint) to service_role;
revoke all on function public.council_level_coins(int) from public, anon, authenticated;
grant execute on function public.council_level_coins(int) to service_role;
revoke all on function public.council_record_match(uuid,uuid) from public, anon, authenticated;
grant execute on function public.council_record_match(uuid,uuid) to service_role;
revoke all on function public.council_grant_xp(uuid) from public, anon, authenticated;
grant execute on function public.council_grant_xp(uuid) to service_role;
revoke all on function public.council_on_completion() from public, anon, authenticated;
revoke all on function public.council_sync(uuid) from public, anon, authenticated;
grant execute on function public.council_sync(uuid) to service_role;
revoke all on function public.council_settle_invites(uuid) from public, anon, authenticated;
grant execute on function public.council_settle_invites(uuid) to service_role;
revoke all on function public.council_account_created(uuid) from public, anon, authenticated;
grant execute on function public.council_account_created(uuid) to service_role;
revoke all on function public.council_invite_status(uuid) from public, anon, authenticated;
grant execute on function public.council_invite_status(uuid) to service_role;
revoke all on function public.council_invite(uuid) from public, anon, authenticated;
grant execute on function public.council_invite(uuid) to service_role;
revoke all on function public.redeem_council_invite(uuid,text) from public, anon, authenticated;
grant execute on function public.redeem_council_invite(uuid,text) to service_role;
revoke all on function public.council_draw_contracts(uuid,date) from public, anon, authenticated;
grant execute on function public.council_draw_contracts(uuid,date) to service_role;
revoke all on function public.council_metric(uuid,date,text) from public, anon, authenticated;
grant execute on function public.council_metric(uuid,date,text) to service_role;
revoke all on function public.council_contracts_status(uuid) from public, anon, authenticated;
grant execute on function public.council_contracts_status(uuid) to service_role;
revoke all on function public.council_contracts(uuid) from public, anon, authenticated;
grant execute on function public.council_contracts(uuid) to service_role;
revoke all on function public.claim_council_contract(uuid,date,int) from public, anon, authenticated;
grant execute on function public.claim_council_contract(uuid,date,int) to service_role;
revoke all on function public.claim_council_weekly(uuid,text) from public, anon, authenticated;
grant execute on function public.claim_council_weekly(uuid,text) to service_role;
revoke all on function public.council_rank_of(bigint) from public, anon, authenticated;
grant execute on function public.council_rank_of(bigint) to service_role;
revoke all on function public.council_rank(uuid) from public, anon, authenticated;
grant execute on function public.council_rank(uuid) to service_role;
revoke all on function public.council_visible(uuid) from public, anon, authenticated;
grant execute on function public.council_visible(uuid) to service_role;
revoke all on function public.set_council_leaderboard_visible(uuid,boolean) from public, anon, authenticated;
grant execute on function public.set_council_leaderboard_visible(uuid,boolean) to service_role;
revoke all on function public.seat_cosmetics() from public, anon, authenticated;
revoke all on function public.council_leaderboard(uuid) from public, anon, authenticated;
grant execute on function public.council_leaderboard(uuid) to service_role;
revoke all on function public.owns_starter_bundle(uuid,text) from public, anon, authenticated;
grant execute on function public.owns_starter_bundle(uuid,text) to service_role;
revoke all on function public.reverse_play_bundle(text) from public, anon, authenticated;
grant execute on function public.reverse_play_bundle(text) to service_role;
revoke all on function public.commit_play_bundle(uuid,text,text,text,text,timestamptz,int,text) from public, anon, authenticated;
grant execute on function public.commit_play_bundle(uuid,text,text,text,text,timestamptz,int,text) to service_role;
revoke all on function public.commit_play_product_base(uuid,text,text,text,text,timestamptz,int,text) from public, anon, authenticated;
grant execute on function public.commit_play_product_base(uuid,text,text,text,text,timestamptz,int,text) to service_role;
revoke all on function public.commit_play_product(uuid,text,text,text,text,timestamptz,int,text) from public, anon, authenticated;
grant execute on function public.commit_play_product(uuid,text,text,text,text,timestamptz,int,text) to service_role;
revoke all on function public.revoke_voided_play_purchases_base(text[],text[]) from public, anon, authenticated;
grant execute on function public.revoke_voided_play_purchases_base(text[],text[]) to service_role;
revoke all on function public.revoke_voided_play_purchases(text[],text[]) from public, anon, authenticated;
grant execute on function public.revoke_voided_play_purchases(text[],text[]) to service_role;
revoke all on function public.economy_capabilities_base(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities_base(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public, anon, authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
revoke all on function public.purge_orphan_economy() from public, anon, authenticated;
grant execute on function public.purge_orphan_economy() to service_role;
