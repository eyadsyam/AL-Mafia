-- «قضية اليوم»: one fictional deduction puzzle per UTC day. The database
-- stores attempts and grants only; puzzle generation/correctness stays in the
-- edge function and never reads a room, match, player seat or live role.

-- 0. Capability and ledger ----------------------------------------------------
alter table public.economy_config
  add column if not exists case_of_day_enabled boolean not null default false;

create or replace function public.case_of_day_on()
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select case_of_day_enabled from public.economy_config limit 1),false)
$$;

do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check'
     and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds
    from unnest(kinds||array['case_puzzle']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))',
    (select string_agg(quote_literal(k),',' order by k) from unnest(kinds) k));
end $$;

-- 1. Attempts -----------------------------------------------------------------
create table public.case_puzzle_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  attempts smallint not null default 0 check (attempts between 0 and 3),
  solved_at timestamptz,
  failed_at timestamptz,
  answer_hash text check (answer_hash is null or answer_hash ~ '^[0-9a-f]{16}$'),
  updated_at timestamptz not null default now(),
  primary key(user_id,day),
  check (not (solved_at is not null and failed_at is not null)),
  check (failed_at is null or attempts=3),
  check (solved_at is null or attempts between 1 and 3)
);
create index case_puzzle_solved_days on public.case_puzzle_attempts(user_id,day)
  where solved_at is not null;

alter table public.case_puzzle_attempts enable row level security;
revoke all on public.case_puzzle_attempts from public,anon,authenticated;
grant all on public.case_puzzle_attempts to service_role;

-- Current streak is allowed to end yesterday: today's case is not a missed
-- day until UTC midnight. A failed row today resets it immediately.
create or replace function public.case_puzzle_streak(p_user uuid,p_today date)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  with solved as (
    select day,row_number() over(order by day) n
      from public.case_puzzle_attempts
     where user_id=p_user and solved_at is not null and day<=p_today
  ), runs as (
    select min(day) first_day,max(day) last_day,count(*)::int length
      from solved group by day-(n::int)
  ), facts as (
    select coalesce(max(length),0)::int best,
      coalesce(max(length) filter(where last_day in (p_today,p_today-1)),0)::int current
      from runs
  )
  select jsonb_build_object('streak',case when exists(
      select 1 from public.case_puzzle_attempts
       where user_id=p_user and day=p_today and failed_at is not null)
    then 0 else current end,'bestStreak',best) from facts
$$;

-- Internal persistence state. The edge adds the deterministic puzzle and,
-- only after solved/failed, its answer and explanation.
create or replace function public.case_puzzle_status(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date:=(now() at time zone 'utc')::date; row public.case_puzzle_attempts;
  streak jsonb;
begin
  if not public.case_of_day_on() then return jsonb_build_object('enabled',false); end if;
  select * into row from public.case_puzzle_attempts where user_id=p_user and day=today;
  streak:=public.case_puzzle_streak(p_user,today);
  return jsonb_build_object('enabled',true,'day',today,
    'attempts',coalesce(row.attempts,0),'maxAttempts',3,
    'solved',row.solved_at is not null,'failed',row.failed_at is not null,
    'streak',(streak->>'streak')::int,'bestStreak',(streak->>'bestStreak')::int,
    'reward',jsonb_build_object('coins',5,'xp',20));
end $$;

-- Correctness and answer_hash come only from the authenticated edge function.
-- The RPC is service-role-only and serializes with every other wallet grant.
create or replace function public.case_puzzle_record(
  p_user uuid,p_day date,p_pick text,p_correct boolean,p_answer_hash text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date:=(now() at time zone 'utc')::date; row public.case_puzzle_attempts;
  coins bigint:=0; season_xp int:=0; state jsonb;
begin
  if not public.case_of_day_on() then
    return jsonb_build_object('ok',false,'code','DISABLED');
  end if;
  if p_day is null or p_day<>today then
    return jsonb_build_object('ok',false,'code','DAY_CHANGED');
  end if;
  if p_pick is null or p_pick !~ '^s[0-6]$' or p_correct is null
      or p_answer_hash is null or p_answer_hash !~ '^[0-9a-f]{16}$' then
    return jsonb_build_object('ok',false,'code','BAD_REQUEST');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.case_puzzle_attempts(user_id,day,answer_hash)
    values(p_user,today,p_answer_hash) on conflict do nothing;
  select * into row from public.case_puzzle_attempts
   where user_id=p_user and day=today for update;
  if row.answer_hash is distinct from p_answer_hash then
    return jsonb_build_object('ok',false,'code','BAD_REQUEST');
  end if;
  if row.solved_at is not null then
    return jsonb_build_object('ok',false,'code','ALREADY_SOLVED');
  end if;
  if row.failed_at is not null or row.attempts>=3 then
    return jsonb_build_object('ok',false,'code','NO_ATTEMPTS');
  end if;

  update public.case_puzzle_attempts set
    attempts=attempts+1,
    solved_at=case when p_correct then now() else solved_at end,
    failed_at=case when not p_correct and attempts+1>=3 then now() else failed_at end,
    updated_at=now()
   where user_id=p_user and day=today;

  if p_correct then
    if public.credit_earned(p_user,'case_puzzle',5,null,today::text) then coins:=5; end if;
    season_xp:=public.casebook_grant_season_xp(p_user,'puzzle:'||today::text,20);
  end if;
  state:=public.case_puzzle_status(p_user);
  return jsonb_build_object('ok',true,'correct',p_correct,
    'grant',case when p_correct then jsonb_build_object('coins',coins,'xp',season_xp) end,
    'state',state);
end $$;

-- 2. Capability composition ---------------------------------------------------
alter function public.economy_capabilities(uuid)
  rename to economy_capabilities_pre_case_of_day;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare base jsonb;
begin
  base:=public.economy_capabilities_pre_case_of_day(p_user);
  return base||jsonb_build_object('caseOfDay',public.case_of_day_on());
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'case_of_day_on()','case_puzzle_streak(uuid,date)',
    'case_puzzle_status(uuid)','case_puzzle_record(uuid,date,text,boolean,text)',
    'economy_capabilities_pre_case_of_day(uuid)']
  loop
    execute format('revoke all on function public.%s from public,anon,authenticated',f);
    execute format('grant execute on function public.%s to service_role',f);
  end loop;
end $$;
revoke all on function public.economy_capabilities(uuid)
  from public,anon,authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;

-- Named one by one for the server-surface test.
revoke all on function public.case_of_day_on() from public, anon, authenticated;
grant execute on function public.case_of_day_on() to service_role;
revoke all on function public.case_puzzle_streak(uuid,date) from public, anon, authenticated;
grant execute on function public.case_puzzle_streak(uuid,date) to service_role;
revoke all on function public.case_puzzle_status(uuid) from public, anon, authenticated;
grant execute on function public.case_puzzle_status(uuid) to service_role;
revoke all on function public.case_puzzle_record(uuid,date,text,boolean,text) from public, anon, authenticated;
grant execute on function public.case_puzzle_record(uuid,date,text,boolean,text) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
