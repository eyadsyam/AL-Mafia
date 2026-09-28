-- The Casebook: one server-authoritative mission destination over Council Life.
-- Everything is dark by default. Progress is derived only from finished rooms
-- with a committed public outcome; no live or private role fact is returned.

-- 0. Capability and immutable product limits ---------------------------------
alter table public.economy_config
  add column if not exists missions_enabled boolean not null default false;

create or replace function public.missions_on()
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select missions_enabled from public.economy_config limit 1),false)
$$;

-- New grants use their own ledger kinds. Existing kinds are preserved.
do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check'
     and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds from unnest(kinds || array[
    'mission_daily','mission_daily_bonus','mission_weekly','season_reward','achievement']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))',
    (select string_agg(quote_literal(k), ',' order by k) from unnest(kinds) k));
end $$;

-- 1. Seasons, catalogue, assignments and claims -------------------------------
create table public.mission_seasons (
  id bigint generated always as identity primary key,
  code text not null unique check (code ~ '^[a-z0-9_]{3,40}$'),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  xp_per_level int not null default 200 check (xp_per_level=200),
  max_level int not null default 20 check (max_level=20),
  active boolean not null default true,
  check (ends_at=starts_at + interval '28 days')
);

insert into public.mission_seasons(code,starts_at,ends_at)
values('season_zero',now(),now()+interval '28 days')
on conflict(code) do nothing;

create table public.mission_catalog (
  code text primary key check (code ~ '^[a-z0-9_]{3,40}$'),
  layer text not null check (layer in ('daily','weekly')),
  metric text not null check (metric in ('finish','town','mafia','win','host','reunion')),
  voice text not null check (voice in ('mafia','doctor','detective','citizen')),
  target int not null check (target between 1 and 50),
  coins bigint not null check (coins between 0 and 100),
  xp int not null check (xp between 0 and 250),
  active boolean not null default true
);

insert into public.mission_catalog(code,layer,metric,voice,target,coins,xp) values
  ('finish_1','daily','finish','citizen',1,5,25),
  ('finish_3','daily','finish','detective',3,10,40),
  ('finish_town','daily','town','doctor',1,10,40),
  ('finish_mafia','daily','mafia','mafia',1,10,40),
  ('win_1','daily','win','detective',1,10,40),
  ('win_2','daily','win','mafia',2,10,40),
  ('host_1','daily','host','citizen',1,10,40),
  ('reunion_1','daily','reunion','doctor',1,10,40),
  ('weekly_finish_10','weekly','finish','detective',10,75,180)
on conflict(code) do nothing;

-- The assignment is the existing Council row. This view adds immutable
-- Casebook flavour/rewards without creating a second daily claim surface.
create view public.mission_assignments as
  select d.user_id,d.day,d.slot,d.code,c.metric,c.voice,c.target,c.coins,c.xp,d.claimed_at
    from public.council_daily_contracts d
    join public.mission_catalog c on c.code=d.code and c.layer='daily';

create table public.season_xp_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  season_id bigint not null references public.mission_seasons(id) on delete cascade,
  source_key text not null check (char_length(source_key) between 3 and 120),
  xp int not null check (xp between 0 and 500),
  created_at timestamptz not null default now(),
  primary key(user_id,season_id,source_key)
);
create index season_xp_totals on public.season_xp_events(season_id,user_id);

create table public.season_reward_catalog (
  season_id bigint not null references public.mission_seasons(id) on delete cascade,
  level int not null check (level between 1 and 20),
  coins bigint not null default 0 check (coins between 0 and 150),
  item_code text references public.reward_catalog(code),
  title_code text check (title_code is null or title_code ~ '^[a-z0-9_]{3,60}$'),
  primary key(season_id,level)
);

insert into public.season_reward_catalog(season_id,level,coins,title_code)
select s.id,l,
  case l when 2 then 25 when 5 then 50 when 8 then 50 when 11 then 50
    when 14 then 75 when 17 then 50 when 19 then 50 when 20 then 50 else 0 end,
  case l when 10 then 'season_zero_night_scribe'
    when 20 then 'season_zero_casekeeper' end
from public.mission_seasons s cross join generate_series(1,20) l
where s.code='season_zero'
on conflict do nothing;

create table public.season_reward_claims (
  user_id uuid not null references auth.users(id) on delete cascade,
  season_id bigint not null,
  level int not null,
  claimed_at timestamptz not null default now(),
  primary key(user_id,season_id,level),
  foreign key(season_id,level) references public.season_reward_catalog(season_id,level)
);

create table public.mission_achievement_catalog (
  code text primary key check (code ~ '^[a-z0-9_]{3,40}$'),
  metric text not null check (metric in ('finish','win','host','reunion')),
  target int not null check (target between 1 and 100),
  coins bigint not null check (coins between 0 and 150),
  xp int not null check (xp between 0 and 250),
  active boolean not null default true
);
insert into public.mission_achievement_catalog(code,metric,target,coins,xp) values
  ('first_case','finish',1,25,50),
  ('night_regular','finish',10,50,100),
  ('veteran_50','finish',50,100,200),
  ('victor_10','win',10,75,150),
  ('host_10','host',10,75,150),
  ('reunion_5','reunion',5,50,100)
on conflict(code) do nothing;

create table public.mission_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  code text not null references public.mission_achievement_catalog(code),
  progress int not null default 0 check (progress>=0),
  unlocked_at timestamptz,
  claimed_at timestamptz,
  primary key(user_id,code)
);

-- Lifetime progress needs a receipt independent of season retention. It does
-- not reference rooms because finished rooms are intentionally purged quickly.
create table public.mission_match_receipts (
  user_id uuid not null references auth.users(id) on delete cascade,
  room_id uuid not null,
  recorded_at timestamptz not null default now(),
  primary key(user_id,room_id)
);

-- Old rows are deliberately ineligible: applying the migration never creates
-- retroactive season currency or XP.
alter table public.council_match_records
  add column if not exists eligible boolean not null default false,
  add column if not exists human_count int not null default 0 check (human_count between 0 and 20),
  add column if not exists group_fingerprint text not null default ''
    check (group_fingerprint='' or group_fingerprint ~ '^[0-9a-f]{32}$');
create index council_eligible_day on public.council_match_records(user_id,day,eligible);
create index council_eligible_group on public.council_match_records(
  user_id,day,group_fingerprint) where eligible;

alter table public.mission_seasons enable row level security;
alter table public.mission_catalog enable row level security;
alter table public.season_xp_events enable row level security;
alter table public.season_reward_catalog enable row level security;
alter table public.season_reward_claims enable row level security;
alter table public.mission_achievement_catalog enable row level security;
alter table public.mission_achievements enable row level security;
alter table public.mission_match_receipts enable row level security;
revoke all on public.mission_seasons,public.mission_catalog,public.mission_assignments,
  public.season_xp_events,public.season_reward_catalog,public.season_reward_claims,
  public.mission_achievement_catalog,public.mission_achievements,public.mission_match_receipts
  from public,anon,authenticated;
grant all on public.mission_seasons,public.mission_catalog,public.season_xp_events,
  public.season_reward_catalog,public.season_reward_claims,
  public.mission_achievement_catalog,public.mission_achievements,public.mission_match_receipts
  to service_role;
grant select on public.mission_assignments to service_role;

-- 2. Finished-result recording -------------------------------------------------
create or replace function public.casebook_add_achievement(
  p_user uuid,p_code text,p_amount int)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if p_amount<=0 or not exists(select 1 from public.mission_achievement_catalog
      where code=p_code and active) then return; end if;
  insert into public.mission_achievements(user_id,code,progress)
    values(p_user,p_code,p_amount)
    on conflict(user_id,code) do update
      set progress=mission_achievements.progress+excluded.progress;
  update public.mission_achievements a set unlocked_at=coalesce(a.unlocked_at,now())
    from public.mission_achievement_catalog c
   where a.user_id=p_user and a.code=p_code and c.code=a.code
     and a.progress>=c.target and a.unlocked_at is null;
end $$;

create or replace function public.casebook_record_match(p_user uuid,p_room uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare rec public.council_match_records; season bigint; earned int;
  first_host boolean; receipt_count int;
begin
  select * into rec from public.council_match_records
   where user_id=p_user and room_id=p_room and eligible;
  if not found then return; end if;

  select id into season from public.mission_seasons
   where active and rec.ended_at>=starts_at and rec.ended_at<ends_at
   order by starts_at desc limit 1;
  if season is not null then
    earned := 20 + case when rec.won then 10 else 0 end;
    insert into public.season_xp_events(user_id,season_id,source_key,xp,created_at)
      values(p_user,season,'match:'||p_room,earned,rec.ended_at)
      on conflict do nothing;
  end if;

  -- A dedicated receipt keeps lifetime progress idempotent even after a
  -- season or the short-lived Council match record is eventually removed.
  insert into public.mission_match_receipts(user_id,room_id,recorded_at)
    values(p_user,p_room,rec.ended_at) on conflict do nothing;
  get diagnostics receipt_count=row_count;
  if receipt_count=1 then
      perform public.casebook_add_achievement(p_user,'first_case',1);
      perform public.casebook_add_achievement(p_user,'night_regular',1);
      perform public.casebook_add_achievement(p_user,'veteran_50',1);
      if rec.won then perform public.casebook_add_achievement(p_user,'victor_10',1); end if;
      select count(*)=1 into first_host from public.council_match_records
       where user_id=p_user and day=rec.day and eligible and hosted;
      if rec.hosted and first_host then
        perform public.casebook_add_achievement(p_user,'host_10',1);
      end if;
      if rec.reunion then
        perform public.casebook_add_achievement(p_user,'reunion_5',1);
      end if;
  end if;
end $$;

-- Replace the recorder so mission eligibility is captured once, immutably, at
-- the same public-result boundary Council Life already trusts.
create or replace function public.council_record_match(p_user uuid, p_room uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare m record; v_team text; mates uuid[]; n int; humans int; fp text;
  d date; wk text; day_used int; group_used int; reunion_credit boolean;
begin
  if not public.council_on('any') and not public.missions_on() then return false; end if;
  perform pg_advisory_xact_lock(hashtextextended('casebook:'||p_user::text,93));
  select r.id,r.ended_at,r.host_id,p.role,p.name,p.gender,
      s.public_data->>'outcome' as outcome
    into m
    from public.rooms r join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
   where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
     and r.status='finished' and r.ended_at is not null
     and s.public_data->>'outcome' in ('mafia','town');
  if not found then return false; end if;

  d := (m.ended_at at time zone 'utc')::date;
  wk := public.council_week(d);
  v_team := case when m.role='mafia' then 'mafia' else 'town' end;
  select coalesce(array_agg(user_id order by user_id) filter(where user_id<>p_user),'{}'),
      count(distinct user_id),md5(string_agg(user_id::text,',' order by user_id))
    into mates,humans,fp from public.room_players
   where room_id=p_room and not kicked and role is not null;
  select count(*) into day_used from public.council_match_records
   where user_id=p_user and day=d and eligible;
  select count(*) into group_used from public.council_match_records
   where user_id=p_user and day=d and eligible and group_fingerprint=fp;

  -- A reunion credit needs a previously met player, and that same player can
  -- unlock it only once in an ISO week.
  select exists(
    select 1 from unnest(mates) mate
     where exists(select 1 from public.council_match_records old
       where old.user_id=p_user and old.ended_at<m.ended_at
         and old.ended_at>m.ended_at-interval '7 days' and mate=any(old.co_players))
       and not exists(select 1 from public.council_match_records used
         where used.user_id=p_user and used.week=wk and used.reunion
           and mate=any(used.co_players))) into reunion_credit;

  insert into public.council_match_records(user_id,room_id,ended_at,day,week,team,won,hosted,
      reunion,co_players,eligible,human_count,group_fingerprint)
    values(p_user,p_room,m.ended_at,d,wk,v_team,v_team=m.outcome,
      m.host_id is not distinct from p_user,reunion_credit,mates,
      humans>=5 and day_used<6 and group_used<3,humans,fp)
    on conflict do nothing;
  get diagnostics n=row_count;
  if n=0 then return false; end if;
  insert into public.council_identity(user_id,name,gender,updated_at)
    values(p_user,left(btrim(m.name),40),coalesce(m.gender,'unspecified'),now())
    on conflict(user_id) do update set name=excluded.name,gender=excluded.gender,
      updated_at=now() where council_identity.updated_at<=excluded.updated_at;
  perform public.casebook_record_match(p_user,p_room);
  return true;
end $$;

-- Council sync must still discover finished rooms when only Casebook is on.
create or replace function public.council_sync(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare room uuid; total bigint; lvl int; l int; ups jsonb := '[]';
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if not public.council_on('any') and not public.missions_on() then return ups; end if;
  for room in
    select r.id from public.rooms r join public.room_players p on p.room_id=r.id
     where p.user_id=p_user and not p.kicked and p.role is not null
       and r.status='finished' and r.ended_at is not null
       and not exists(select 1 from public.council_match_records c
         where c.user_id=p_user and c.room_id=r.id)
     order by r.ended_at
  loop
    perform public.council_record_match(p_user,room);
  end loop;
  delete from public.council_match_records
   where user_id=p_user and ended_at<now()-interval '21 days';
  if public.council_on('rank') then
    perform public.council_grant_xp(p_user);
    select coalesce(sum(xp),0) into total from public.council_xp_events where user_id=p_user;
    lvl := public.council_level_for(total);
    for l in 2..lvl loop
      if public.credit_earned(p_user,'council_level',public.council_level_coins(l),null,'level:'||l) then
        ups := ups||jsonb_build_object('level',l,'coins',public.council_level_coins(l));
      end if;
    end loop;
  end if;
  return ups;
end $$;

create or replace function public.casebook_sync(p_user uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare rid uuid;
begin
  perform public.council_sync(p_user);
  for rid in select room_id from public.council_match_records
    where user_id=p_user and eligible order by ended_at loop
    perform public.casebook_record_match(p_user,rid);
  end loop;
end $$;

create or replace function public.casebook_metric(
  p_user uuid,p_layer text,p_period text,p_metric text)
returns int language plpgsql stable security definer set search_path=public,pg_temp as $$
declare result int;
begin
  if p_layer='daily' then
    select count(*)::int into result from public.council_match_records r
     where r.user_id=p_user and r.eligible and r.day=p_period::date and case p_metric
       when 'finish' then true when 'town' then r.team='town'
       when 'mafia' then r.team='mafia' when 'win' then r.won
       when 'host' then r.hosted when 'reunion' then r.reunion else false end;
  elsif p_layer='weekly' then
    select count(*)::int into result from public.council_match_records r
     where r.user_id=p_user and r.eligible and r.week=p_period and case p_metric
       when 'finish' then true when 'town' then r.team='town'
       when 'mafia' then r.team='mafia' when 'win' then r.won
       when 'host' then r.hosted when 'reunion' then r.reunion else false end;
  else result:=0;
  end if;
  -- Hosting can advance mission progress at most once per period.
  if p_metric='host' then result:=least(result,1); end if;
  return coalesce(result,0);
end $$;

create or replace function public.casebook_grant_season_xp(
  p_user uuid,p_source text,p_xp int)
returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare sid bigint; n int;
begin
  if p_xp<=0 then return 0; end if;
  select id into sid from public.mission_seasons
   where active and now()>=starts_at and now()<ends_at order by starts_at desc limit 1;
  if sid is null then return 0; end if;
  insert into public.season_xp_events(user_id,season_id,source_key,xp)
    values(p_user,sid,p_source,p_xp) on conflict do nothing;
  get diagnostics n=row_count;
  return case when n=1 then p_xp else 0 end;
end $$;

-- 3. Hub ----------------------------------------------------------------------
create or replace function public.mission_hub(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date:=public.economy_today(); wk text:=public.council_week(today);
  s public.mission_seasons; total_xp bigint:=0; season_level int:=0;
  daily_rows jsonb; weekly_rows jsonb; reward_rows jsonb; achievement_rows jsonb;
  daily_claimed int; bonus_claimed boolean; weekly_claimed boolean;
  rank_xp bigint; rank_level int;
begin
  if not public.missions_on() then return jsonb_build_object('enabled',false); end if;
  perform public.casebook_sync(p_user);
  perform public.council_draw_contracts(p_user,today);
  select * into s from public.mission_seasons
   where active and now()>=starts_at and now()<ends_at order by starts_at desc limit 1;

  select count(*) into daily_claimed from public.council_daily_contracts
   where user_id=p_user and day=today and claimed_at is not null;
  bonus_claimed:=exists(select 1 from public.wallet_ledger where user_id=p_user
    and source_key=today::text and kind in ('mission_daily_bonus','council_contract_bonus'));
  weekly_claimed:=exists(select 1 from public.wallet_ledger where user_id=p_user
    and source_key=wk and kind in ('mission_weekly','council_weekly'));

  select coalesce(jsonb_agg(jsonb_build_object(
      'slot',a.slot,'code',a.code,'metric',a.metric,'voice',a.voice,
      'target',a.target,'progress',least(public.casebook_metric(p_user,'daily',today::text,a.metric),a.target),
      'coins',a.coins,'xp',a.xp,'claimed',a.claimed_at is not null,
      'claimable',a.claimed_at is null and public.casebook_metric(p_user,'daily',today::text,a.metric)>=a.target)
      order by a.slot),'[]') into daily_rows
    from public.mission_assignments a where a.user_id=p_user and a.day=today;

  select jsonb_agg(jsonb_build_object('slot',0,'code',c.code,'metric',c.metric,
      'voice',c.voice,'target',c.target,
      'progress',least(public.casebook_metric(p_user,'weekly',wk,c.metric),c.target),
      'coins',c.coins,'xp',c.xp,'claimed',weekly_claimed,
      'claimable',not weekly_claimed and public.casebook_metric(p_user,'weekly',wk,c.metric)>=c.target))
    into weekly_rows from public.mission_catalog c
   where c.layer='weekly' and c.active;

  if s.id is not null then
    select coalesce(sum(xp),0) into total_xp from public.season_xp_events
     where user_id=p_user and season_id=s.id;
    season_level:=least(s.max_level,(total_xp/s.xp_per_level)::int);
    select coalesce(jsonb_agg(jsonb_build_object('level',r.level,'coins',r.coins,
        'item',r.item_code,'title',r.title_code,
        'claimed',c.user_id is not null,
        'claimable',c.user_id is null and r.level<=season_level) order by r.level),'[]')
      into reward_rows from public.season_reward_catalog r
      left join public.season_reward_claims c on c.season_id=r.season_id
        and c.level=r.level and c.user_id=p_user where r.season_id=s.id;
  else reward_rows:='[]'; end if;

  select coalesce(jsonb_agg(jsonb_build_object('code',c.code,'metric',c.metric,
      'target',c.target,'progress',least(coalesce(a.progress,0),c.target),
      'coins',c.coins,'xp',c.xp,'unlocked',a.unlocked_at is not null,
      'claimed',a.claimed_at is not null,
      'claimable',a.unlocked_at is not null and a.claimed_at is null)
      order by c.target,c.code),'[]') into achievement_rows
    from public.mission_achievement_catalog c
    left join public.mission_achievements a on a.code=c.code and a.user_id=p_user
   where c.active;

  select coalesce(sum(xp),0) into rank_xp from public.council_xp_events where user_id=p_user;
  rank_level:=public.council_level_for(rank_xp);
  return jsonb_build_object('enabled',true,
    'season',case when s.id is null then null else jsonb_build_object(
      'code',s.code,'startsAt',s.starts_at,'endsAt',s.ends_at,'level',season_level,
      'xp',total_xp,'xpPerLevel',s.xp_per_level,'maxLevel',s.max_level,'rewards',reward_rows) end,
    'daily',jsonb_build_object('period',today,'missions',daily_rows,'bonus',jsonb_build_object(
      'coins',10,'xp',25,'claimed',bonus_claimed,
      'claimable',not bonus_claimed and daily_claimed=3)),
    'weekly',jsonb_build_object('period',wk,'missions',coalesce(weekly_rows,'[]')),
    'achievements',achievement_rows,
    'rank',jsonb_build_object('level',rank_level,'xp',rank_xp,
      'next',case when rank_level<50 then public.council_level_xp(rank_level+1) end));
end $$;

-- 4. Claims -------------------------------------------------------------------
create or replace function public.claim_mission(
  p_user uuid,p_layer text,p_period text,p_slot int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date:=public.economy_today(); wk text:=public.council_week(today);
  c record; granted bigint:=0; xp_granted int:=0; bonus bigint:=0; bonus_xp int:=0;
  n int;
begin
  if not public.missions_on() then return jsonb_build_object('ok',false,'code','DISABLED'); end if;
  if p_layer not in ('daily','weekly') or p_slot is null then
    return jsonb_build_object('ok',false,'code','BAD_REQUEST'); end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  perform public.casebook_sync(p_user);
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;

  if p_layer='daily' then
    if p_period is null or p_period<>today::text then
      return jsonb_build_object('ok',false,'code','PERIOD_CHANGED'); end if;
    if p_slot not between 0 and 2 then
      return jsonb_build_object('ok',false,'code','BAD_REQUEST'); end if;
    perform public.council_draw_contracts(p_user,today);
    select d.*,m.metric as mission_metric,m.coins as mission_coins,m.xp as mission_xp
      into c from public.council_daily_contracts d join public.mission_catalog m on m.code=d.code
     where d.user_id=p_user and d.day=today and d.slot=p_slot for update of d;
    if c.user_id is null then return jsonb_build_object('ok',false,'code','NOT_FOUND'); end if;
    if c.claimed_at is not null then return jsonb_build_object('ok',false,'code','ALREADY_CLAIMED'); end if;
    if public.casebook_metric(p_user,'daily',today::text,c.mission_metric)<c.target then
      return jsonb_build_object('ok',false,'code','NOT_READY'); end if;
    update public.council_daily_contracts set claimed_at=now()
     where user_id=p_user and day=today and slot=p_slot;
    if public.credit_earned(p_user,'mission_daily',c.mission_coins,null,today::text||':'||p_slot) then
      granted:=c.mission_coins;
    end if;
    xp_granted:=public.casebook_grant_season_xp(p_user,'daily:'||today::text||':'||p_slot,c.mission_xp);
    select count(*) into n from public.council_daily_contracts
     where user_id=p_user and day=today and claimed_at is not null;
    if n=3 and not exists(select 1 from public.wallet_ledger where user_id=p_user
        and source_key=today::text and kind in ('mission_daily_bonus','council_contract_bonus')) then
      if public.credit_earned(p_user,'mission_daily_bonus',10,null,today::text) then bonus:=10; end if;
      bonus_xp:=public.casebook_grant_season_xp(p_user,'daily-bonus:'||today::text,25);
    end if;
  else
    if p_period is null or p_period<>wk then
      return jsonb_build_object('ok',false,'code','PERIOD_CHANGED'); end if;
    if p_slot<>0 then return jsonb_build_object('ok',false,'code','BAD_REQUEST'); end if;
    select * into c from public.mission_catalog where layer='weekly' and active limit 1;
    if exists(select 1 from public.wallet_ledger where user_id=p_user and source_key=wk
        and kind in ('mission_weekly','council_weekly')) then
      return jsonb_build_object('ok',false,'code','ALREADY_CLAIMED'); end if;
    if public.casebook_metric(p_user,'weekly',wk,c.metric)<c.target then
      return jsonb_build_object('ok',false,'code','NOT_READY'); end if;
    if public.credit_earned(p_user,'mission_weekly',c.coins,null,wk) then granted:=c.coins; end if;
    xp_granted:=public.casebook_grant_season_xp(p_user,'weekly:'||wk,c.xp);
  end if;
  return jsonb_build_object('ok',true,'coins',granted+bonus,'xp',xp_granted+bonus_xp,
    'balance',(select balance from public.wallet_accounts where user_id=p_user),
    'hub',public.mission_hub(p_user));
end $$;

create or replace function public.claim_season_reward(p_user uuid,p_season text,p_level int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.mission_seasons; r public.season_reward_catalog; total bigint; lvl int; n int;
  granted bigint:=0;
begin
  if not public.missions_on() then return jsonb_build_object('ok',false,'code','DISABLED'); end if;
  if p_season is null or p_level is null or p_level not between 1 and 20 then
    return jsonb_build_object('ok',false,'code','BAD_REQUEST'); end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  perform public.casebook_sync(p_user);
  select * into s from public.mission_seasons where code=p_season and active;
  if s.id is null then return jsonb_build_object('ok',false,'code','NOT_FOUND'); end if;
  if now()<s.starts_at or now()>=s.ends_at then
    return jsonb_build_object('ok',false,'code','SEASON_CLOSED'); end if;
  select * into r from public.season_reward_catalog where season_id=s.id and level=p_level;
  if r.season_id is null then return jsonb_build_object('ok',false,'code','NOT_FOUND'); end if;
  if exists(select 1 from public.season_reward_claims
      where user_id=p_user and season_id=s.id and level=p_level) then
    return jsonb_build_object('ok',false,'code','ALREADY_CLAIMED'); end if;
  select coalesce(sum(xp),0) into total from public.season_xp_events
   where user_id=p_user and season_id=s.id;
  lvl:=least(s.max_level,(total/s.xp_per_level)::int);
  if lvl<p_level then return jsonb_build_object('ok',false,'code','NOT_READY'); end if;
  insert into public.season_reward_claims(user_id,season_id,level)
    values(p_user,s.id,p_level) on conflict do nothing;
  get diagnostics n=row_count;
  if n=0 then return jsonb_build_object('ok',false,'code','ALREADY_CLAIMED'); end if;
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  if r.coins>0 and public.credit_earned(p_user,'season_reward',r.coins,null,
      s.code||':'||p_level) then granted:=r.coins; end if;
  return jsonb_build_object('ok',true,'coins',granted,'xp',0,
    'balance',(select balance from public.wallet_accounts where user_id=p_user),
    'hub',public.mission_hub(p_user));
end $$;

create or replace function public.claim_achievement(p_user uuid,p_code text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.mission_achievements; c public.mission_achievement_catalog;
  granted bigint:=0; xp_granted int:=0;
begin
  if not public.missions_on() then return jsonb_build_object('ok',false,'code','DISABLED'); end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  perform public.casebook_sync(p_user);
  select * into c from public.mission_achievement_catalog where code=p_code and active;
  if c.code is null then return jsonb_build_object('ok',false,'code','NOT_FOUND'); end if;
  select * into a from public.mission_achievements
   where user_id=p_user and code=p_code for update;
  if a.user_id is null or a.unlocked_at is null then
    return jsonb_build_object('ok',false,'code','NOT_READY'); end if;
  if a.claimed_at is not null then
    return jsonb_build_object('ok',false,'code','ALREADY_CLAIMED'); end if;
  update public.mission_achievements set claimed_at=now()
   where user_id=p_user and code=p_code;
  if public.credit_earned(p_user,'achievement',c.coins,null,p_code) then granted:=c.coins; end if;
  xp_granted:=public.casebook_grant_season_xp(p_user,'achievement:'||p_code,c.xp);
  return jsonb_build_object('ok',true,'coins',granted,'xp',xp_granted,
    'balance',(select balance from public.wallet_accounts where user_id=p_user),
    'hub',public.mission_hub(p_user));
end $$;

-- 5. Legacy claim compatibility -----------------------------------------------
alter function public.claim_council_contract(uuid,date,int)
  rename to claim_council_contract_pre_casebook;
create function public.claim_council_contract(p_user uuid,p_day date,p_slot int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  if not public.missions_on() then
    return public.claim_council_contract_pre_casebook(p_user,p_day,p_slot);
  end if;
  result:=public.claim_mission(p_user,'daily',p_day::text,p_slot);
  if not coalesce((result->>'ok')::boolean,false) then
    if result->>'code'='ALREADY_CLAIMED' then
      return public.council_contracts_status(p_user)||jsonb_build_object('granted',0,
        'bonusGranted',0,'balance',(select balance from public.wallet_accounts where user_id=p_user));
    end if;
    raise exception '%',result->>'code';
  end if;
  return public.council_contracts_status(p_user)||jsonb_build_object(
    'granted',(result->>'coins')::bigint,'bonusGranted',0,
    'balance',(result->>'balance')::bigint);
end $$;

alter function public.claim_council_weekly(uuid,text)
  rename to claim_council_weekly_pre_casebook;
create function public.claim_council_weekly(p_user uuid,p_week text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb;
begin
  if not public.missions_on() then
    return public.claim_council_weekly_pre_casebook(p_user,p_week);
  end if;
  result:=public.claim_mission(p_user,'weekly',p_week,0);
  if not coalesce((result->>'ok')::boolean,false) then
    if result->>'code'='ALREADY_CLAIMED' then
      return public.council_contracts_status(p_user)||jsonb_build_object('granted',0,
        'xpGranted',0,'levelUps','[]'::jsonb,
        'balance',(select balance from public.wallet_accounts where user_id=p_user));
    end if;
    raise exception '%',result->>'code';
  end if;
  return public.council_contracts_status(p_user)||jsonb_build_object(
    'granted',(result->>'coins')::bigint,'xpGranted',(result->>'xp')::int,
    'levelUps','[]'::jsonb,'balance',(result->>'balance')::bigint);
end $$;

-- 6. Capability composition and privileges ------------------------------------
alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_casebook;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_casebook(p_user);
  return base||jsonb_build_object('missions',public.missions_on());
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'missions_on()','casebook_add_achievement(uuid,text,int)',
    'casebook_record_match(uuid,uuid)','casebook_sync(uuid)',
    'casebook_metric(uuid,text,text,text)','casebook_grant_season_xp(uuid,text,int)',
    'mission_hub(uuid)','claim_mission(uuid,text,text,int)',
    'claim_season_reward(uuid,text,int)','claim_achievement(uuid,text)',
    'claim_council_contract_pre_casebook(uuid,date,int)',
    'claim_council_weekly_pre_casebook(uuid,text)',
    'economy_capabilities_pre_casebook(uuid)']
  loop
    execute format('revoke all on function public.%s from public,anon,authenticated',f);
    execute format('grant execute on function public.%s to service_role',f);
  end loop;
end $$;
revoke all on function public.claim_council_contract(uuid,date,int)
  from public,anon,authenticated;
grant execute on function public.claim_council_contract(uuid,date,int) to service_role;
revoke all on function public.claim_council_weekly(uuid,text)
  from public,anon,authenticated;
grant execute on function public.claim_council_weekly(uuid,text) to service_role;
revoke all on function public.economy_capabilities(uuid)
  from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
