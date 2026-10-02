-- Update 1.0.1: two-step rewarded ads, daily return, Play Billing products,
-- and one capability answer the client negotiates against.
--
-- Additive and backward compatible:
-- * 1.0.0 clients keep `create_ad_claim` / `ad_status` / `commit_ad_reward`
--   (one ad, +100% of the completion coins). v1 and v2 are mutually exclusive
--   per player and match: whichever claim exists first decides.
-- * A client that does not ask for `capabilities` sees nothing new.
-- * Nothing here reads or writes match state; the engine never sees coins.
--
-- Requires 20260924000500_coin_orders (purchased_balance / purchase_debt).
-- Hosted concurrency is enforced by the wallet advisory lock, row locks and
-- unique indexes below; the local PGlite suite runs on one connection and does
-- not prove concurrent behaviour on its own.

-- 0. Configuration -----------------------------------------------------------
-- One row, every feature OFF until an operator switches it on (activation
-- runbook in build/update101/status.md). The checks are the product rules, so an edit cannot loosen them:
-- at most 3 interstitials a day, at least 10 minutes apart, 3 minutes after
-- any rewarded ad, never in a player's first completed match.
create table public.economy_config (
  id boolean primary key default true check (id),
  ad_steps_enabled boolean not null default false,
  daily_enabled boolean not null default false,
  daily_ad_enabled boolean not null default false,
  interstitial_enabled boolean not null default false,
  interstitial_max_per_day int not null default 3 check (interstitial_max_per_day between 0 and 3),
  interstitial_gap_seconds int not null default 600 check (interstitial_gap_seconds >= 600),
  interstitial_after_reward_seconds int not null default 180 check (interstitial_after_reward_seconds >= 180),
  interstitial_grace_matches int not null default 1 check (interstitial_grace_matches >= 1),
  daily_coffer_coins bigint not null default 20 check (daily_coffer_coins between 1 and 100),
  daily_week_bonus bigint not null default 60 check (daily_week_bonus between 0 and 200),
  daily_ad_coins bigint not null default 25 check (daily_ad_coins between 1 and 100),
  -- A circuit breaker for the whole service, not a per-player promise.
  daily_global_cap int not null default 200000 check (daily_global_cap > 0),
  updated_at timestamptz not null default now()
);
insert into public.economy_config default values on conflict do nothing;
alter table public.economy_config enable row level security;
revoke all on public.economy_config from public, anon, authenticated;
grant all on public.economy_config to service_role;

-- 1. Ledger ------------------------------------------------------------------
alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
alter table public.wallet_ledger add constraint wallet_ledger_kind_check check (kind in (
  'match_completion','match_win','catalog_spend','operator_adjustment','ad_reward',
  'purchase','catalog_refund','coin_purchase','coin_purchase_reversal',
  'ad_step_1','ad_step_2','daily_coffer','daily_wheel','daily_week_bonus','daily_ad',
  'play_coin_purchase','play_coin_reversal'));
alter table public.wallet_ledger add column if not exists source_key text;
-- Daily rewards: one per player, kind and key (the UTC day or claim number).
create unique index if not exists wallet_keyed_once
  on public.wallet_ledger(user_id, kind, source_key) where source_key is not null;
-- Play coins: one credit and one reversal per purchase token hash, whoever
-- the token is later presented by.
create unique index if not exists wallet_play_token_once
  on public.wallet_ledger(kind, source_key)
  where kind in ('play_coin_purchase','play_coin_reversal');

create or replace function public.economy_today()
returns date language sql stable set search_path=public,pg_temp as $$
  select (now() at time zone 'utc')::date
$$;

-- Adds earned coins inside a caller that already holds the wallet lock.
create or replace function public.credit_earned(p_user uuid, p_kind text, p_amount bigint,
  p_room uuid, p_key text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare inserted_count integer;
begin
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  insert into public.wallet_ledger(user_id,kind,amount,source_room,source_key)
    values(p_user,p_kind,p_amount,p_room,p_key) on conflict do nothing;
  get diagnostics inserted_count=row_count;
  if inserted_count=1 then
    update public.wallet_accounts set balance=balance+p_amount,
      lifetime_earned=lifetime_earned+p_amount, updated_at=now()
     where user_id=p_user;
  end if;
  return inserted_count=1;
end $$;

-- 2. One registry of AdMob transactions --------------------------------------
-- A signed transaction id can pay exactly one claim, across v1, v2 and daily.
create table public.ad_ssv_transactions (
  transaction_id text primary key,
  scheme text not null check (scheme in ('v1','step','daily')),
  claim_id uuid not null,
  user_id uuid,
  created_at timestamptz not null default now()
);
insert into public.ad_ssv_transactions(transaction_id,scheme,claim_id,user_id)
  select transaction_id,'v1',id,user_id from public.ad_reward_claims
   where transaction_id is not null
  on conflict do nothing;
alter table public.ad_ssv_transactions enable row level security;
revoke all on public.ad_ssv_transactions from public, anon, authenticated;
grant all on public.ad_ssv_transactions to service_role;

create or replace function public.register_ad_transaction(p_transaction text,
  p_scheme text, p_claim uuid, p_user uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare existing public.ad_ssv_transactions;
begin
  insert into public.ad_ssv_transactions(transaction_id,scheme,claim_id,user_id)
    values(p_transaction,p_scheme,p_claim,p_user) on conflict do nothing;
  select * into existing from public.ad_ssv_transactions where transaction_id=p_transaction;
  if existing.claim_id<>p_claim or existing.scheme<>p_scheme then
    raise exception 'TRANSACTION_ALREADY_USED';
  end if;
end $$;

-- 3. Post-match rewarded ads: two steps (v2) -------------------------------
create table public.ad_step_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  room_id uuid not null references public.rooms(id) on delete cascade,
  step smallint not null check (step in (1,2)),
  base_amount bigint not null check (base_amount > 0),
  amount bigint not null check (amount > 0),
  state text not null default 'pending' check (state in ('pending','awarded')),
  transaction_id text unique,
  ad_unit text,
  reward_amount bigint,
  created_at timestamptz not null default now(),
  awarded_at timestamptz,
  unique (user_id, room_id, step)
);
create index ad_step_claims_user_time on public.ad_step_claims(user_id, created_at desc);
alter table public.ad_step_claims enable row level security;
revoke all on public.ad_step_claims from public, anon, authenticated;
grant all on public.ad_step_claims to service_role;

-- What a claim is for never changes after it is created; only its settlement.
create or replace function public.ad_claim_immutable()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if new.id<>old.id or new.user_id<>old.user_id or new.room_id is distinct from old.room_id
     or new.amount<>old.amount then
    raise exception 'CLAIM_IMMUTABLE';
  end if;
  if old.state='awarded' and (new.state<>'awarded' or new.transaction_id is distinct from old.transaction_id) then
    raise exception 'CLAIM_IMMUTABLE';
  end if;
  return new;
end $$;
create trigger ad_step_claims_immutable before update on public.ad_step_claims
  for each row execute function public.ad_claim_immutable();

create or replace function public.ad_reward_eligible(p_user uuid, p_room uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(
    select 1 from public.rooms r
    join public.room_players p on p.room_id=r.id
    join public.room_state s on s.room_id=r.id
    where r.id=p_room and p.user_id=p_user and not p.kicked and p.role is not null
      and r.status='finished' and r.ended_at is not null
      and s.public_data->>'outcome' in ('mafia','town'))
$$;

create or replace function public.ad_steps_status_v2(p_user uuid, p_room uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare legacy public.ad_reward_claims; base bigint; half bigint; steps jsonb;
begin
  select * into legacy from public.ad_reward_claims where user_id=p_user and room_id=p_room;
  if legacy.id is not null then
    -- A 1.0.0 claim already decides this match: resume it as one ad.
    return jsonb_build_object('scheme','v1','claimId',legacy.id,'state',legacy.state,
      'amount',legacy.base_amount);
  end if;
  select amount into base from public.wallet_ledger
   where user_id=p_user and source_room=p_room and kind='match_completion';
  base := coalesce(base, 100);
  half := base / 2;
  select jsonb_agg(jsonb_build_object(
      'step', n,
      'amount', coalesce(c.amount, case when n=1 then half else base-half end),
      'state', coalesce(c.state,'available'),
      'claimId', c.id) order by n)
    into steps
    from (values (1),(2)) v(n)
    left join public.ad_step_claims c on c.user_id=p_user and c.room_id=p_room and c.step=v.n;
  return jsonb_build_object('scheme','steps','base',base,'total',base,'steps',steps);
end $$;

create or replace function public.create_ad_step_claim_v2(p_user uuid, p_room uuid, p_step int)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare base bigint; half bigint; claim public.ad_step_claims;
begin
  if p_step not in (1,2) then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  -- A missing config row reads as off, never on.
  if not coalesce((select ad_steps_enabled from public.economy_config), false) then
    raise exception 'FEATURE_OFF';
  end if;
  if exists(select 1 from public.ad_reward_claims where user_id=p_user and room_id=p_room) then
    return public.ad_steps_status_v2(p_user,p_room);
  end if;
  if not public.ad_reward_eligible(p_user,p_room) then raise exception 'REWARD_NOT_ELIGIBLE'; end if;
  select amount into base from public.wallet_ledger
   where user_id=p_user and source_room=p_room and kind='match_completion';
  if base is null then raise exception 'REWARD_NOT_SYNCED'; end if;
  if p_step=2 and not exists(select 1 from public.ad_step_claims
      where user_id=p_user and room_id=p_room and step=1 and state='awarded') then
    raise exception 'STEP_ORDER';
  end if;
  half := base / 2;
  insert into public.ad_step_claims(user_id,room_id,step,base_amount,amount)
    values(p_user,p_room,p_step,base,case when p_step=1 then half else base-half end)
    on conflict (user_id,room_id,step) do nothing;
  select * into claim from public.ad_step_claims
   where user_id=p_user and room_id=p_room and step=p_step;
  return public.ad_steps_status_v2(p_user,p_room)
    || jsonb_build_object('claimId',claim.id,'step',claim.step,'claimState',claim.state);
end $$;

create or replace function public.commit_ad_step_v2(
  p_claim uuid, p_transaction text, p_ad_unit text, p_reward_amount bigint, p_ssv_user uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare claim public.ad_step_claims;
begin
  if p_transaction is null or length(p_transaction)<8 or p_reward_amount<=0 then
    raise exception 'BAD_SSV';
  end if;
  select * into claim from public.ad_step_claims where id=p_claim for update;
  if claim.id is null or claim.user_id<>p_ssv_user then raise exception 'CLAIM_NOT_FOUND'; end if;
  if claim.state='awarded' then
    if claim.transaction_id<>p_transaction then raise exception 'CLAIM_ALREADY_USED'; end if;
    return jsonb_build_object('state','awarded','amount',claim.amount);
  end if;
  perform public.register_ad_transaction(p_transaction,'step',claim.id,claim.user_id);
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||claim.user_id::text,91));
  if claim.step=2 and not exists(select 1 from public.ad_step_claims
      where user_id=claim.user_id and room_id=claim.room_id and step=1 and state='awarded') then
    raise exception 'STEP_ORDER';
  end if;
  perform public.credit_earned(claim.user_id,'ad_step_'||claim.step,claim.amount,claim.room_id,null);
  update public.ad_step_claims set state='awarded',transaction_id=p_transaction,
    ad_unit=p_ad_unit,reward_amount=p_reward_amount,awarded_at=now()
   where id=claim.id;
  return jsonb_build_object('state','awarded','amount',claim.amount);
end $$;

-- v1 stays as 1.0.0 knows it, with two additions: a match already on the
-- two-step path refuses a v1 claim, and v1 transactions join the registry.
create or replace function public.create_ad_reward_claim(p_user uuid,p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare base bigint; claim public.ad_reward_claims;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  if exists(select 1 from public.ad_step_claims where user_id=p_user and room_id=p_room) then
    raise exception 'REWARD_SCHEME_V2';
  end if;
  if not public.ad_reward_eligible(p_user,p_room) then raise exception 'REWARD_NOT_ELIGIBLE'; end if;
  select amount into base from public.wallet_ledger
    where user_id=p_user and source_room=p_room and kind='match_completion';
  if base is null then raise exception 'REWARD_NOT_SYNCED'; end if;
  insert into public.ad_reward_claims(user_id,room_id,base_amount)
    values(p_user,p_room,base)
    on conflict(user_id,room_id) do update set user_id=excluded.user_id
    returning * into claim;
  return jsonb_build_object('claimId',claim.id,'state',claim.state,'amount',claim.base_amount);
end $$;

create or replace function public.commit_ad_reward(
  p_claim uuid,p_transaction text,p_ad_unit text,p_reward_amount bigint,p_ssv_user uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare claim public.ad_reward_claims; inserted_count integer;
begin
  if p_transaction is null or length(p_transaction)<8 or p_reward_amount<=0 then
    raise exception 'BAD_SSV';
  end if;
  select * into claim from public.ad_reward_claims where id=p_claim for update;
  if claim.id is null or claim.user_id<>p_ssv_user then raise exception 'CLAIM_NOT_FOUND'; end if;
  if claim.state='awarded' then
    if claim.transaction_id<>p_transaction then raise exception 'CLAIM_ALREADY_USED'; end if;
    return jsonb_build_object('state','awarded','amount',claim.base_amount);
  end if;
  if exists(select 1 from public.ad_reward_claims where transaction_id=p_transaction and id<>p_claim) then
    raise exception 'TRANSACTION_ALREADY_USED';
  end if;
  perform public.register_ad_transaction(p_transaction,'v1',claim.id,claim.user_id);
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||claim.user_id::text,91));
  insert into public.wallet_ledger(user_id,kind,amount,source_room)
    values(claim.user_id,'ad_reward',claim.base_amount,claim.room_id)
    on conflict do nothing;
  get diagnostics inserted_count=row_count;
  if inserted_count=1 then
    update public.wallet_accounts
      set balance=balance+claim.base_amount,
          lifetime_earned=lifetime_earned+claim.base_amount,updated_at=now()
      where user_id=claim.user_id;
  end if;
  update public.ad_reward_claims set state='awarded',transaction_id=p_transaction,
    ad_unit=p_ad_unit,reward_amount=p_reward_amount,awarded_at=now()
    where id=claim.id;
  return jsonb_build_object('state','awarded','amount',claim.base_amount);
end $$;

-- 4. Daily return ------------------------------------------------------------
create table public.daily_wheel_prizes (
  slot smallint primary key check (slot between 0 and 9),
  coins bigint not null check (coins > 0),
  weight int not null check (weight > 0)
);
-- 10/20/35/60/100 at 40/30/20/8/2 % (expected value 23.8).
insert into public.daily_wheel_prizes(slot,coins,weight) values
  (0,10,40),(1,20,30),(2,35,20),(3,60,8),(4,100,2)
on conflict (slot) do nothing;

create table public.daily_claims (
  user_id uuid not null,
  day date not null,
  kind text not null check (kind in ('coffer','wheel')),
  amount bigint not null check (amount > 0),
  outcome smallint,
  claim_number int,
  created_at timestamptz not null default now(),
  primary key (user_id, day, kind)
);
create index daily_claims_day on public.daily_claims(day, kind);

create table public.daily_ad_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  room_id uuid,
  day date not null,
  amount bigint not null check (amount > 0),
  state text not null default 'pending' check (state in ('pending','awarded')),
  transaction_id text unique,
  ad_unit text,
  reward_amount bigint,
  created_at timestamptz not null default now(),
  awarded_at timestamptz,
  unique (user_id, day)
);
create trigger daily_ad_claims_immutable before update on public.daily_ad_claims
  for each row execute function public.ad_claim_immutable();

alter table public.daily_wheel_prizes enable row level security;
alter table public.daily_claims enable row level security;
alter table public.daily_ad_claims enable row level security;
revoke all on public.daily_wheel_prizes, public.daily_claims, public.daily_ad_claims
  from public, anon, authenticated;
grant all on public.daily_wheel_prizes, public.daily_claims, public.daily_ad_claims
  to service_role;

-- Uniform in [0, p_bound) from the database's cryptographic generator
-- (gen_random_uuid uses pg_strong_random; bytes 0–3 of a v4 UUID are fully
-- random). Rejection sampling removes modulo bias.
create or replace function public.secure_random_below(p_bound int)
returns int language plpgsql volatile set search_path=public,pg_temp as $$
declare b bytea; v bigint; top bigint;
begin
  if p_bound is null or p_bound <= 0 then raise exception 'BAD_REQUEST'; end if;
  top := (4294967296 / p_bound) * p_bound;
  loop
    b := uuid_send(gen_random_uuid());
    v := (get_byte(b,0)::bigint << 24) | (get_byte(b,1)::bigint << 16)
       | (get_byte(b,2)::bigint << 8) | get_byte(b,3)::bigint;
    exit when v < top;
  end loop;
  return (v % p_bound)::int;
end $$;

create or replace function public.daily_status(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config; today date := public.economy_today();
  coffer public.daily_claims; wheel public.daily_claims; ad public.daily_ad_claims;
  claims int; prizes jsonb; total int; in_match boolean;
begin
  select * into cfg from public.economy_config;
  select * into coffer from public.daily_claims where user_id=p_user and day=today and kind='coffer';
  select * into wheel from public.daily_claims where user_id=p_user and day=today and kind='wheel';
  select * into ad from public.daily_ad_claims where user_id=p_user and day=today;
  select count(*) into claims from public.daily_claims where user_id=p_user and kind='coffer';
  select sum(weight) into total from public.daily_wheel_prizes;
  select jsonb_agg(jsonb_build_object('slot',slot,'coins',coins,'weight',weight,
      'percent',round(weight*100.0/total,2)) order by slot)
    into prizes from public.daily_wheel_prizes;
  in_match := exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
    where p.user_id=p_user and not p.kicked and r.status<>'finished');
  return jsonb_build_object(
    'enabled', coalesce(cfg.daily_enabled, false),
    'day', today,
    'nextDayAt', (today + 1)::timestamp at time zone 'utc',
    'coffer', jsonb_build_object('claimed', coffer.user_id is not null,
      'amount', coalesce(coffer.amount, cfg.daily_coffer_coins)),
    'wheel', jsonb_build_object('spun', wheel.user_id is not null,
      'slot', wheel.outcome, 'amount', wheel.amount, 'prizes', coalesce(prizes,'[]')),
    'week', jsonb_build_object('claimedDays', claims, 'progress', claims % 7,
      'length', 7, 'bonus', cfg.daily_week_bonus),
    'ad', jsonb_build_object('enabled', coalesce(cfg.daily_enabled and cfg.daily_ad_enabled, false), 'amount',
      coalesce(ad.amount, cfg.daily_ad_coins), 'state', coalesce(ad.state,'available'),
      'claimId', ad.id, 'inMatch', in_match));
end $$;

create or replace function public.daily_guard(p_user uuid, p_day date, p_kind text)
returns date language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); cfg public.economy_config;
begin
  select * into cfg from public.economy_config;
  if not coalesce(cfg.daily_enabled, false) then raise exception 'FEATURE_OFF'; end if;
  -- Every 1.0.1 daily request names the server day it was made for: a retry
  -- of yesterday's request is never today's claim.
  if p_day is null then raise exception 'DAY_REQUIRED'; end if;
  if p_day<>today then raise exception 'DAY_CHANGED'; end if;
  if (select count(*) from public.daily_claims where day=today and kind=p_kind) >= cfg.daily_global_cap then
    raise exception 'DAILY_PAUSED';
  end if;
  return today;
end $$;

create or replace function public.claim_daily_coffer(p_user uuid, p_day date default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date; cfg public.economy_config; inserted_count int; n int; bonus bigint := 0;
  granted bigint := 0;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into cfg from public.economy_config;
  if exists(select 1 from public.daily_claims where user_id=p_user
      and day=public.economy_today() and kind='coffer') then
    return jsonb_build_object('granted',0,'bonus',0,'daily',public.daily_status(p_user),
      'balance',(select balance from public.wallet_accounts where user_id=p_user));
  end if;
  today := public.daily_guard(p_user,p_day,'coffer');
  select count(*)+1 into n from public.daily_claims where user_id=p_user and kind='coffer';
  insert into public.daily_claims(user_id,day,kind,amount,claim_number)
    values(p_user,today,'coffer',cfg.daily_coffer_coins,n) on conflict do nothing;
  get diagnostics inserted_count=row_count;
  if inserted_count=1 then
    perform public.credit_earned(p_user,'daily_coffer',cfg.daily_coffer_coins,null,today::text);
    granted := cfg.daily_coffer_coins;
    -- Every seventh claimed day, whenever it falls: a missed day costs nothing.
    if n % 7 = 0 and cfg.daily_week_bonus > 0 then
      if public.credit_earned(p_user,'daily_week_bonus',cfg.daily_week_bonus,null,'claim:'||n) then
        bonus := cfg.daily_week_bonus;
      end if;
    end if;
  end if;
  return jsonb_build_object('granted',granted,'bonus',bonus,'daily',public.daily_status(p_user),
    'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;

create or replace function public.spin_daily_wheel(p_user uuid, p_day date default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date; existing public.daily_claims; total int; draw int; prize public.daily_wheel_prizes;
  acc int := 0;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into existing from public.daily_claims where user_id=p_user
    and day=public.economy_today() and kind='wheel';
  if existing.user_id is not null then
    -- The outcome was fixed when it was drawn: a reload shows it again.
    return jsonb_build_object('slot',existing.outcome,'amount',existing.amount,'granted',0,
      'daily',public.daily_status(p_user),
      'balance',(select balance from public.wallet_accounts where user_id=p_user));
  end if;
  today := public.daily_guard(p_user,p_day,'wheel');
  select sum(weight) into total from public.daily_wheel_prizes;
  draw := public.secure_random_below(total);
  for prize in select * from public.daily_wheel_prizes order by slot loop
    acc := acc + prize.weight;
    exit when draw < acc;
  end loop;
  insert into public.daily_claims(user_id,day,kind,amount,outcome)
    values(p_user,today,'wheel',prize.coins,prize.slot);
  perform public.credit_earned(p_user,'daily_wheel',prize.coins,null,today::text);
  return jsonb_build_object('slot',prize.slot,'amount',prize.coins,'granted',prize.coins,
    'daily',public.daily_status(p_user),
    'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;

create or replace function public.create_daily_ad_claim(p_user uuid, p_day date default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); cfg public.economy_config; claim public.daily_ad_claims;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into cfg from public.economy_config;
  if not coalesce(cfg.daily_enabled and cfg.daily_ad_enabled, false) then
    raise exception 'FEATURE_OFF';
  end if;
  if p_day is null then raise exception 'DAY_REQUIRED'; end if;
  if p_day<>today then raise exception 'DAY_CHANGED'; end if;
  if exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
      where p.user_id=p_user and not p.kicked and r.status<>'finished') then
    raise exception 'IN_MATCH';
  end if;
  insert into public.daily_ad_claims(user_id,day,amount)
    values(p_user,today,cfg.daily_ad_coins) on conflict (user_id,day) do nothing;
  select * into claim from public.daily_ad_claims where user_id=p_user and day=today;
  return jsonb_build_object('claimId',claim.id,'state',claim.state,'amount',claim.amount,
    'day',claim.day);
end $$;

create or replace function public.commit_daily_ad(
  p_claim uuid, p_transaction text, p_ad_unit text, p_reward_amount bigint, p_ssv_user uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare claim public.daily_ad_claims;
begin
  if p_transaction is null or length(p_transaction)<8 or p_reward_amount<=0 then
    raise exception 'BAD_SSV';
  end if;
  select * into claim from public.daily_ad_claims where id=p_claim for update;
  if claim.id is null or claim.user_id<>p_ssv_user then raise exception 'CLAIM_NOT_FOUND'; end if;
  if claim.state='awarded' then
    if claim.transaction_id<>p_transaction then raise exception 'CLAIM_ALREADY_USED'; end if;
    return jsonb_build_object('state','awarded','amount',claim.amount);
  end if;
  perform public.register_ad_transaction(p_transaction,'daily',claim.id,claim.user_id);
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||claim.user_id::text,91));
  -- Keyed by the claim's own day: a callback that lands after midnight pays
  -- the day the ad was requested for, once.
  perform public.credit_earned(claim.user_id,'daily_ad',claim.amount,null,claim.day::text);
  update public.daily_ad_claims set state='awarded',transaction_id=p_transaction,
    ad_unit=p_ad_unit,reward_amount=p_reward_amount,awarded_at=now()
   where id=claim.id;
  return jsonb_build_object('state','awarded','amount',claim.amount);
end $$;

-- 5. Play Billing products ---------------------------------------------------
create table public.play_products (
  product_id text primary key check (product_id ~ '^[a-z0-9_.]{3,100}$'),
  kind text not null check (kind in ('entitlement','coins')),
  coins bigint,
  entitlement text,
  active boolean not null default false,
  sort_order int not null default 0,
  check ((kind='coins') = (coins is not null and coins > 0)),
  check ((kind='entitlement') = (entitlement is not null))
);
-- Seeded inactive: nothing is sold until Console products, the service
-- account and a licence test exist and an operator sets active=true.
insert into public.play_products(product_id,kind,coins,entitlement,sort_order) values
  ('mm_remove_interruptions','entitlement',null,'remove_interruptions',10),
  ('mm_coins_500','coins',500,null,20),
  ('mm_coins_1200','coins',1200,null,30),
  ('mm_coins_2500','coins',2500,null,40)
on conflict (product_id) do nothing;
alter table public.play_products enable row level security;
revoke all on public.play_products from public, anon, authenticated;
grant all on public.play_products to service_role;

alter table public.player_entitlements drop constraint if exists player_entitlements_item_code_check;
alter table public.player_entitlements add constraint player_entitlements_item_code_check
  check (item_code in ('scenario_shadows','remove_interruptions'));

alter table public.play_purchases
  add column if not exists quantity int not null default 1 check (quantity between 1 and 10),
  add column if not exists token_hash text,
  add column if not exists granted_at timestamptz,
  add column if not exists credited bigint not null default 0 check (credited >= 0),
  -- The purchase debt this purchase paid off instead of adding coins. A
  -- refund puts it back, so a refund loop can never erase debt.
  add column if not exists debt_offset bigint not null default 0 check (debt_offset >= 0),
  add column if not exists consumed_at timestamptz,
  add column if not exists reversed_at timestamptz;
create unique index if not exists play_purchases_token_hash on public.play_purchases(token_hash)
  where token_hash is not null;

-- Every void Google reports, kept for good — including tokens and orders this
-- server has never seen, so a purchase refunded before its first verify can
-- never be credited later.
create table public.play_void_tombstones (
  id bigint generated always as identity primary key,
  token_hash text,
  order_id text,
  voided_at timestamptz not null default now(),
  check (token_hash is not null or order_id is not null)
);
create unique index play_void_token on public.play_void_tombstones(token_hash)
  where token_hash is not null;
create unique index play_void_order on public.play_void_tombstones(order_id)
  where order_id is not null;
alter table public.play_void_tombstones enable row level security;
revoke all on public.play_void_tombstones from public, anon, authenticated;
grant all on public.play_void_tombstones to service_role;

create or replace function public.account_tag(p_user uuid)
returns text language sql immutable set search_path=public,pg_temp as $$
  select encode(sha256(convert_to(p_user::text,'UTF8')),'hex')
$$;

create or replace function public.play_token_hash(p_token text)
returns text language sql immutable set search_path=public,pg_temp as $$
  select encode(sha256(convert_to(p_token,'UTF8')),'hex')
$$;

update public.play_purchases set token_hash=public.play_token_hash(purchase_token)
 where token_hash is null;

create or replace function public.play_is_voided(p_hash text, p_order text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.play_void_tombstones
    where token_hash=p_hash or (p_order is not null and order_id=p_order))
$$;

-- Lock order for everything that touches Play purchases and wallets:
-- purchase locks (sorted by token), then wallet locks (sorted by user), then
-- rows. Functions that take only a wallet lock never take a purchase lock.

-- Takes back one granted coin purchase. The caller holds the purchase lock,
-- the owner's wallet lock and the row lock. Only still-unspent purchased
-- coins leave the wallet; the rest, plus any debt this purchase had paid
-- off, becomes debt against future purchased coins. Earned coins and owned
-- cosmetics are never touched.
create or replace function public.reverse_play_coins(p_token text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare hit public.play_purchases; w public.wallet_accounts; taken bigint := 0;
begin
  select * into hit from public.play_purchases where purchase_token=p_token;
  if hit.purchase_token is null or hit.granted_at is null or hit.reversed_at is not null then
    return false;
  end if;
  if hit.user_id is not null then
    select * into w from public.wallet_accounts where user_id=hit.user_id for update;
    taken := least(coalesce(w.purchased_balance,0), hit.credited);
    update public.wallet_accounts set balance=balance-taken,
      purchased_balance=purchased_balance-taken,
      purchase_debt=purchase_debt+hit.debt_offset+(hit.credited-taken), updated_at=now()
     where user_id=hit.user_id;
    if taken > 0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_key)
        values(hit.user_id,'play_coin_reversal',-taken,hit.token_hash)
        on conflict do nothing;
    end if;
  end if;
  update public.play_purchases set reversed_at=now(), state='revoked'
   where purchase_token=p_token;
  return true;
end $$;

create or replace function public.commit_play_product(
  p_user uuid, p_token text, p_product text, p_order text, p_state text,
  p_purchased_at timestamptz, p_quantity int default 1, p_account_tag text default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare product public.play_products; existing public.play_purchases; rec public.play_purchases;
  w public.wallet_accounts; hash text; gross bigint; offset_debt bigint; credit bigint := 0;
  moves int := 0; effective text;
begin
  if p_token is null or length(p_token)<8 or p_state not in ('active','pending','revoked')
    or coalesce(p_quantity,1) not between 1 and 10 then
    raise exception 'INVALID_PURCHASE';
  end if;
  select * into product from public.play_products where product_id=p_product;
  if product.product_id is null then raise exception 'PRODUCT_UNKNOWN'; end if;
  -- Bound at purchase time to this account. Every 1.0.1 purchase carries the
  -- tag, so a coins token without one is refused rather than credited to
  -- whoever presents it first.
  if (product.kind='coins' and p_account_tag is null)
     or (p_account_tag is not null and p_account_tag<>public.account_tag(p_user)) then
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
  -- Revoked is final: a void on record, or an earlier revocation, is never
  -- undone by a later (possibly stale) "active" answer.
  effective := case
    when public.play_is_voided(hash, coalesce(p_order, existing.order_id)) then 'revoked'
    when existing.state='revoked' then 'revoked'
    else p_state end;

  if product.kind='entitlement' then
    if existing.purchase_token is not null then
      moves := case when existing.last_rebound_at > now()-interval '30 days'
        then existing.rebind_count else 0 end;
    end if;
    if existing.user_id is not null and existing.user_id<>p_user then
      if moves >= 3 then raise exception 'REBIND_LIMIT'; end if;
      delete from public.player_entitlements where purchase_token=p_token;
      moves := moves + 1;
    end if;
    insert into public.play_purchases(purchase_token,user_id,product_id,order_id,state,
        purchased_at,token_hash,quantity)
      values(p_token,p_user,p_product,p_order,effective,p_purchased_at,hash,1)
      on conflict(purchase_token) do update set user_id=excluded.user_id,
        order_id=coalesce(excluded.order_id,play_purchases.order_id),
        state=case when play_purchases.state='revoked' then 'revoked' else excluded.state end,
        purchased_at=coalesce(excluded.purchased_at,play_purchases.purchased_at),
        verified_at=now(),token_hash=excluded.token_hash,rebind_count=moves,
        last_rebound_at=case when existing.user_id is not null and existing.user_id<>p_user
          then now() else play_purchases.last_rebound_at end;
    select * into rec from public.play_purchases where purchase_token=p_token;
    if rec.state='active' then
      insert into public.player_entitlements(user_id,item_code,purchase_token)
        values(p_user,product.entitlement,p_token)
        on conflict(user_id,item_code) do update set purchase_token=excluded.purchase_token;
      update public.play_purchases set granted_at=coalesce(granted_at,now())
       where purchase_token=p_token;
    else
      delete from public.player_entitlements where purchase_token=p_token;
    end if;
    return public.purchase_snapshot(p_user) || jsonb_build_object('state',rec.state,
      'product',p_product,'kind','entitlement','granted',rec.state='active',
      'needsAcknowledge',rec.state='active','needsConsume',false);
  end if;

  -- Coins. A token is credited once, to the account that first verified it.
  if existing.purchase_token is not null and existing.user_id is not null
     and existing.user_id<>p_user then
    raise exception 'ACCOUNT_MISMATCH';
  end if;
  insert into public.play_purchases(purchase_token,user_id,product_id,order_id,state,
      purchased_at,token_hash,quantity)
    values(p_token,p_user,p_product,p_order,effective,p_purchased_at,hash,coalesce(p_quantity,1))
    on conflict(purchase_token) do update set
      order_id=coalesce(excluded.order_id,play_purchases.order_id),
      state=case when play_purchases.state='revoked' then 'revoked' else excluded.state end,
      purchased_at=coalesce(excluded.purchased_at,play_purchases.purchased_at),
      verified_at=now();
  select * into rec from public.play_purchases where purchase_token=p_token for update;
  if rec.state='active' and rec.granted_at is null then
    select * into w from public.wallet_accounts where user_id=p_user for update;
    gross := product.coins * rec.quantity;
    offset_debt := least(w.purchase_debt, gross);
    credit := gross - offset_debt;
    update public.wallet_accounts set balance=balance+credit,
      purchased_balance=purchased_balance+credit,
      lifetime_purchased=lifetime_purchased+gross,
      purchase_debt=purchase_debt-offset_debt, updated_at=now()
     where user_id=p_user;
    if credit > 0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_key)
        values(p_user,'play_coin_purchase',credit,hash);
    end if;
    update public.play_purchases set granted_at=now(), credited=credit, debt_offset=offset_debt
     where purchase_token=p_token returning * into rec;
  elsif rec.state='revoked' and rec.granted_at is not null and rec.reversed_at is null then
    -- Google itself now reports the purchase cancelled: reverse it here too.
    perform public.reverse_play_coins(p_token);
    select * into rec from public.play_purchases where purchase_token=p_token;
  end if;
  return jsonb_build_object('state',rec.state,'product',p_product,'kind','coins',
    'granted',rec.granted_at is not null and rec.state='active','credited',rec.credited,
    'coins',product.coins*rec.quantity,
    'needsAcknowledge',false,
    'needsConsume',rec.granted_at is not null and rec.consumed_at is null and rec.state='active',
    'balance',(select balance from public.wallet_accounts where user_id=p_user));
end $$;

create or replace function public.mark_play_consumed(p_token text)
returns void language sql security definer set search_path=public,pg_temp as $$
  update public.play_purchases set consumed_at=coalesce(consumed_at,now())
   where purchase_token=p_token and granted_at is not null
$$;

-- Refunds and chargebacks from the Voided Purchases API. Records a tombstone
-- for every token and order first (known or not), then revokes and reverses
-- every purchase a tombstone covers that is not settled yet — including one
-- a race let through on an earlier run. Idempotent; returns how many
-- purchases changed.
create or replace function public.revoke_voided_play_purchases(
  p_tokens text[], p_orders text[]
) returns int language plpgsql security definer set search_path=public,pg_temp as $$
declare changed int := 0; hit public.play_purchases; tokens text[]; users uuid[];
  t text; u uuid;
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
    select * from public.play_purchases where purchase_token=any(tokens)
     order by purchase_token for update
  loop
    if hit.state='revoked' and (hit.granted_at is null or hit.reversed_at is not null) then
      continue;
    end if;
    changed := changed + 1;
    update public.play_purchases set state='revoked', verified_at=now()
     where purchase_token=hit.purchase_token;
    delete from public.player_entitlements where purchase_token=hit.purchase_token;
    if exists(select 1 from public.play_products where product_id=hit.product_id and kind='coins') then
      perform public.reverse_play_coins(hit.purchase_token);
    else
      -- Entitlements (and the legacy scenario) are settled by removal.
      update public.play_purchases set reversed_at=coalesce(reversed_at,now())
       where purchase_token=hit.purchase_token;
    end if;
  end loop;
  return changed;
end $$;

-- 6. Capabilities -------------------------------------------------------------
create or replace function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,auth,pg_temp as $$
declare cfg public.economy_config; products jsonb;
begin
  select * into cfg from public.economy_config;
  select coalesce(jsonb_agg(jsonb_build_object('id',product_id,'kind',kind,'coins',coins,
      'entitlement',entitlement) order by sort_order),'[]')
    into products from public.play_products where active;
  return jsonb_build_object(
    'version', 2,
    'adSteps', coalesce(cfg.ad_steps_enabled, false),
    'daily', coalesce(cfg.daily_enabled, false),
    'dailyAd', coalesce(cfg.daily_enabled and cfg.daily_ad_enabled, false),
    'interstitial', jsonb_build_object('enabled', coalesce(cfg.interstitial_enabled, false),
      'maxPerDay', coalesce(cfg.interstitial_max_per_day, 0), 'gapSeconds', coalesce(cfg.interstitial_gap_seconds, 600),
      'afterRewardSeconds', coalesce(cfg.interstitial_after_reward_seconds, 180),
      'graceMatches', coalesce(cfg.interstitial_grace_matches, 1)),
    'adFree', public.user_owns_entitlement(p_user,'remove_interruptions'),
    'recoverable', public.account_is_recoverable(p_user),
    'accountTag', public.account_tag(p_user),
    -- Shown before Buy: purchased coins that will settle an earlier refund.
    'purchaseDebt', coalesce((select purchase_debt from public.wallet_accounts
      where user_id=p_user), 0),
    'products', products);
end $$;

-- 7. Deletion covers the new records ----------------------------------------
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
  delete from public.wallet_ledger l where not exists(select 1 from auth.users u where u.id=l.user_id);
  with gone as (
    delete from public.wallet_accounts a where not exists(select 1 from auth.users u where u.id=a.user_id)
    returning 1
  ) select count(*) into removed from gone;
  return removed;
end $$;

-- Named one by one: a DO loop hides them from the surface audit.
revoke all on function public.economy_today() from public, anon, authenticated;
grant execute on function public.economy_today() to service_role;
revoke all on function public.credit_earned(uuid,text,bigint,uuid,text) from public, anon, authenticated;
grant execute on function public.credit_earned(uuid,text,bigint,uuid,text) to service_role;
revoke all on function public.register_ad_transaction(text,text,uuid,uuid) from public, anon, authenticated;
grant execute on function public.register_ad_transaction(text,text,uuid,uuid) to service_role;
revoke all on function public.ad_claim_immutable() from public, anon, authenticated;
revoke all on function public.ad_reward_eligible(uuid,uuid) from public, anon, authenticated;
grant execute on function public.ad_reward_eligible(uuid,uuid) to service_role;
revoke all on function public.ad_steps_status_v2(uuid,uuid) from public, anon, authenticated;
grant execute on function public.ad_steps_status_v2(uuid,uuid) to service_role;
revoke all on function public.create_ad_step_claim_v2(uuid,uuid,int) from public, anon, authenticated;
grant execute on function public.create_ad_step_claim_v2(uuid,uuid,int) to service_role;
revoke all on function public.commit_ad_step_v2(uuid,text,text,bigint,uuid) from public, anon, authenticated;
grant execute on function public.commit_ad_step_v2(uuid,text,text,bigint,uuid) to service_role;
revoke all on function public.create_ad_reward_claim(uuid,uuid) from public, anon, authenticated;
grant execute on function public.create_ad_reward_claim(uuid,uuid) to service_role;
revoke all on function public.commit_ad_reward(uuid,text,text,bigint,uuid) from public, anon, authenticated;
grant execute on function public.commit_ad_reward(uuid,text,text,bigint,uuid) to service_role;
revoke all on function public.secure_random_below(int) from public, anon, authenticated;
grant execute on function public.secure_random_below(int) to service_role;
revoke all on function public.daily_status(uuid) from public, anon, authenticated;
grant execute on function public.daily_status(uuid) to service_role;
revoke all on function public.daily_guard(uuid,date,text) from public, anon, authenticated;
grant execute on function public.daily_guard(uuid,date,text) to service_role;
revoke all on function public.claim_daily_coffer(uuid,date) from public, anon, authenticated;
grant execute on function public.claim_daily_coffer(uuid,date) to service_role;
revoke all on function public.spin_daily_wheel(uuid,date) from public, anon, authenticated;
grant execute on function public.spin_daily_wheel(uuid,date) to service_role;
revoke all on function public.create_daily_ad_claim(uuid,date) from public, anon, authenticated;
grant execute on function public.create_daily_ad_claim(uuid,date) to service_role;
revoke all on function public.commit_daily_ad(uuid,text,text,bigint,uuid) from public, anon, authenticated;
grant execute on function public.commit_daily_ad(uuid,text,text,bigint,uuid) to service_role;
revoke all on function public.play_token_hash(text) from public, anon, authenticated;
grant execute on function public.play_token_hash(text) to service_role;
revoke all on function public.play_is_voided(text,text) from public, anon, authenticated;
grant execute on function public.play_is_voided(text,text) to service_role;
revoke all on function public.reverse_play_coins(text) from public, anon, authenticated;
grant execute on function public.reverse_play_coins(text) to service_role;
revoke all on function public.account_tag(uuid) from public, anon, authenticated;
grant execute on function public.account_tag(uuid) to service_role;
revoke all on function public.commit_play_product(uuid,text,text,text,text,timestamptz,int,text) from public, anon, authenticated;
grant execute on function public.commit_play_product(uuid,text,text,text,text,timestamptz,int,text) to service_role;
revoke all on function public.mark_play_consumed(text) from public, anon, authenticated;
grant execute on function public.mark_play_consumed(text) to service_role;
revoke all on function public.revoke_voided_play_purchases(text[],text[]) from public, anon, authenticated;
grant execute on function public.revoke_voided_play_purchases(text[],text[]) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public, anon, authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
revoke all on function public.purge_orphan_economy() from public, anon, authenticated;
grant execute on function public.purge_orphan_economy() to service_role;
