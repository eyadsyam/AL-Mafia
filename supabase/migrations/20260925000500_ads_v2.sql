-- Phase 108 "Ads v2": app-open and banner switches, and three voluntary
-- rewarded extras (a second wheel spin, a doubled coffer, a swapped daily
-- contract), each once per UTC day.
--
-- Additive and backward compatible:
-- * Every switch defaults to FALSE; a client reads them from
--   `economy_capabilities` → `ads`, and an old server (no `ads` key) is off.
-- * The existing v1 / v2-step / daily-ad claims and their SSV routes are not
--   touched; a signed transaction still pays exactly one claim, across all
--   schemes, through `register_ad_transaction`.
-- * Nothing here reads or writes match state. Extras are refused while the
--   player is seated in a room that has not finished.
-- * The contract swap only rewrites the caller's own not-yet-claimed row of
--   `council_daily_contracts` through a thin function here; the Council Life
--   functions themselves are unchanged and keep their invariants (slot 0 is
--   always a "finish" contract, the three rows come from three groups).
--
-- Lock order is unchanged: claim row, then wallet advisory lock.

-- 0. Configuration -----------------------------------------------------------
-- Caps are the product rules (AdMob app-open guidance + our own): at most
-- three app-open ads a day, at least four hours apart, and only on a return
-- after at least four hours away. An edit can widen them, never loosen them.
alter table public.economy_config
  add column if not exists app_open_enabled boolean not null default false,
  add column if not exists app_open_max_per_day int not null default 3
    check (app_open_max_per_day between 0 and 3),
  add column if not exists app_open_gap_seconds int not null default 14400
    check (app_open_gap_seconds >= 14400),
  add column if not exists app_open_resume_after_seconds int not null default 14400
    check (app_open_resume_after_seconds >= 14400),
  add column if not exists banner_enabled boolean not null default false,
  add column if not exists ad_extras_enabled boolean not null default false;

-- 1. Ledger kinds and the transaction registry -------------------------------
-- Extends whatever list is current instead of restating it.
do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct m[1]), '{}') into kinds
    from pg_constraint c, regexp_matches(pg_get_constraintdef(c.oid), '''([a-z0-9_]+)''', 'g') m
   where c.conname='wallet_ledger_kind_check' and c.conrelid='public.wallet_ledger'::regclass;
  select array_agg(distinct k order by k) into kinds from unnest(kinds || array[
    'ad_extra_spin','ad_extra_coffer']) k;
  alter table public.wallet_ledger drop constraint if exists wallet_ledger_kind_check;
  -- Written as an IN list so the constraint reads back as quoted words the
  -- next migration's scan finds (an array literal would read back empty).
  execute format('alter table public.wallet_ledger add constraint wallet_ledger_kind_check '
    'check (kind in (%s))', (select string_agg(quote_literal(k), ',' order by k) from unnest(kinds) k));
end $$;

alter table public.ad_ssv_transactions drop constraint if exists ad_ssv_transactions_scheme_check;
alter table public.ad_ssv_transactions add constraint ad_ssv_transactions_scheme_check
  check (scheme in ('v1','step','daily','extra'));

-- 2. Extra claims --------------------------------------------------------------
-- One row per player, UTC day and kind. `amount` is fixed at creation for the
-- coffer, drawn at settlement for the spin (the same published wheel), and
-- zero for the swap (it grants no coins).
create table public.ad_extra_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  day date not null,
  kind text not null check (kind in ('spin','coffer','swap')),
  slot smallint check (slot between 0 and 2),
  amount bigint not null default 0 check (amount >= 0),
  outcome smallint,
  outcome_code text,
  state text not null default 'pending' check (state in ('pending','awarded')),
  transaction_id text unique,
  ad_unit text,
  reward_amount bigint,
  created_at timestamptz not null default now(),
  awarded_at timestamptz,
  unique (user_id, day, kind)
);
create index ad_extra_claims_day on public.ad_extra_claims(day, kind);
alter table public.ad_extra_claims enable row level security;
revoke all on public.ad_extra_claims from public, anon, authenticated;
grant all on public.ad_extra_claims to service_role;

-- What a claim is for never changes; a pending swap may still change slot.
-- Once awarded, nothing about its settlement changes either.
create or replace function public.ad_extra_claim_immutable()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if new.id<>old.id or new.user_id<>old.user_id or new.day<>old.day or new.kind<>old.kind then
    raise exception 'CLAIM_IMMUTABLE';
  end if;
  if old.state='awarded' and (new.state<>'awarded'
      or new.transaction_id is distinct from old.transaction_id
      or new.amount<>old.amount or new.outcome is distinct from old.outcome
      or new.outcome_code is distinct from old.outcome_code
      or new.slot is distinct from old.slot) then
    raise exception 'CLAIM_IMMUTABLE';
  end if;
  if old.state='pending' and old.kind<>'spin' and new.amount<>old.amount then
    raise exception 'CLAIM_IMMUTABLE';
  end if;
  return new;
end $$;
create trigger ad_extra_claims_immutable before update on public.ad_extra_claims
  for each row execute function public.ad_extra_claim_immutable();

create or replace function public.ad_extras_on(p_kind text)
returns boolean language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config;
begin
  select * into cfg from public.economy_config;
  if not coalesce(cfg.ad_extras_enabled, false) then return false; end if;
  return case p_kind
    when 'spin' then coalesce(cfg.daily_enabled, false)
    when 'coffer' then coalesce(cfg.daily_enabled, false)
    when 'swap' then public.council_on('contracts')
    else false end;
end $$;

-- 3. The swap ------------------------------------------------------------------
-- Another active contract for the same slot: slot 0 stays a "finish"
-- contract; slots 1 and 2 keep three distinct groups. Deterministic per
-- player, day and slot, so a retry draws the same one.
create or replace function public.ad_swap_candidate(p_user uuid, p_day date, p_slot int)
returns public.council_contract_catalog language sql stable security definer
set search_path=public,pg_temp as $$
  select c.* from public.council_contract_catalog c
   where c.active
     and c.code not in (select d.code from public.council_daily_contracts d
                         where d.user_id=p_user and d.day=p_day)
     and case when p_slot=0 then c.grp='finish'
         else c.grp<>'finish' and c.grp not in (
           select k.grp from public.council_daily_contracts d
             join public.council_contract_catalog k on k.code=d.code
            where d.user_id=p_user and d.day=p_day and d.slot<>p_slot) end
   order by hashtextextended(p_user::text||':'||p_day::text||':'||c.code||':swap', 108)
   limit 1
$$;

-- Replaces one unclaimed contract row. Returns the new code, or null when
-- that slot was claimed meanwhile or nothing else is available.
create or replace function public.ad_swap_council_contract(p_user uuid, p_day date, p_slot int)
returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare row_ public.council_daily_contracts; pick public.council_contract_catalog;
begin
  select * into row_ from public.council_daily_contracts
   where user_id=p_user and day=p_day and slot=p_slot for update;
  if row_.user_id is null or row_.claimed_at is not null then return null; end if;
  pick := public.ad_swap_candidate(p_user, p_day, p_slot);
  if pick.code is null then return null; end if;
  update public.council_daily_contracts
     set code=pick.code, metric=pick.metric, target=pick.target, coins=pick.coins
   where user_id=p_user and day=p_day and slot=p_slot;
  return pick.code;
end $$;

-- 4. Status --------------------------------------------------------------------
create or replace function public.ad_extras_status(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); spin public.ad_extra_claims;
  coffer public.ad_extra_claims; swap public.ad_extra_claims;
  wheel public.daily_claims; box public.daily_claims; prizes jsonb; total int;
  in_match boolean;
begin
  select * into spin from public.ad_extra_claims where user_id=p_user and day=today and kind='spin';
  select * into coffer from public.ad_extra_claims where user_id=p_user and day=today and kind='coffer';
  select * into swap from public.ad_extra_claims where user_id=p_user and day=today and kind='swap';
  select * into wheel from public.daily_claims where user_id=p_user and day=today and kind='wheel';
  select * into box from public.daily_claims where user_id=p_user and day=today and kind='coffer';
  select sum(weight) into total from public.daily_wheel_prizes;
  select jsonb_agg(jsonb_build_object('slot',slot,'coins',coins,'weight',weight,
      'percent',round(weight*100.0/total,2)) order by slot)
    into prizes from public.daily_wheel_prizes;
  in_match := exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
    where p.user_id=p_user and not p.kicked and r.status<>'finished');
  return jsonb_build_object(
    'enabled', public.ad_extras_on('spin') or public.ad_extras_on('coffer')
      or public.ad_extras_on('swap'),
    'day', today, 'inMatch', in_match,
    'spin', jsonb_build_object('enabled', public.ad_extras_on('spin'),
      'ready', wheel.user_id is not null, 'state', coalesce(spin.state,'available'),
      'claimId', spin.id, 'slot', spin.outcome,
      'amount', case when spin.state='awarded' then spin.amount end,
      'prizes', coalesce(prizes,'[]')),
    'coffer', jsonb_build_object('enabled', public.ad_extras_on('coffer'),
      'ready', box.user_id is not null, 'state', coalesce(coffer.state,'available'),
      'claimId', coffer.id, 'amount', coalesce(coffer.amount, box.amount)),
    'swap', jsonb_build_object('enabled', public.ad_extras_on('swap'),
      'state', coalesce(swap.state,'available'), 'claimId', swap.id,
      'slot', swap.slot, 'code', swap.outcome_code));
end $$;

-- 5. Claims --------------------------------------------------------------------
create or replace function public.create_ad_extra_claim(p_user uuid, p_day date,
  p_kind text, p_slot int default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare today date := public.economy_today(); cfg public.economy_config;
  claim public.ad_extra_claims; box public.daily_claims; amount_ bigint := 0;
  current_row public.council_daily_contracts;
begin
  if p_kind is null or p_kind not in ('spin','coffer','swap') then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select * into cfg from public.economy_config;
  if not public.ad_extras_on(p_kind) then raise exception 'FEATURE_OFF'; end if;
  if p_day is null then raise exception 'DAY_REQUIRED'; end if;
  if p_day<>today then raise exception 'DAY_CHANGED'; end if;
  if exists(select 1 from public.room_players p join public.rooms r on r.id=p.room_id
      where p.user_id=p_user and not p.kicked and r.status<>'finished') then
    raise exception 'IN_MATCH';
  end if;
  select * into claim from public.ad_extra_claims
   where user_id=p_user and day=today and kind=p_kind for update;
  if claim.id is not null and claim.state='awarded' then
    return jsonb_build_object('claimId',claim.id,'state',claim.state,'kind',claim.kind,
      'amount',claim.amount,'slot',claim.slot,'day',claim.day);
  end if;
  if p_kind='spin' then
    -- The extra spin follows today's free one; never before it.
    if not exists(select 1 from public.daily_claims where user_id=p_user and day=today
        and kind='wheel') then raise exception 'EXTRA_NOT_READY'; end if;
  elsif p_kind='coffer' then
    select * into box from public.daily_claims where user_id=p_user and day=today and kind='coffer';
    if box.user_id is null then raise exception 'EXTRA_NOT_READY'; end if;
    amount_ := box.amount;
  else
    if p_slot is null or p_slot not between 0 and 2 then raise exception 'BAD_REQUEST'; end if;
    perform public.council_draw_contracts(p_user, today);
    select * into current_row from public.council_daily_contracts
     where user_id=p_user and day=today and slot=p_slot;
    if current_row.user_id is null or current_row.claimed_at is not null
       or (public.ad_swap_candidate(p_user, today, p_slot)).code is null then
      raise exception 'EXTRA_NOT_READY';
    end if;
  end if;
  if claim.id is null then
    if (select count(*) from public.ad_extra_claims where day=today and kind=p_kind)
        >= cfg.daily_global_cap then
      raise exception 'DAILY_PAUSED';
    end if;
    insert into public.ad_extra_claims(user_id,day,kind,slot,amount)
      values(p_user,today,p_kind,case when p_kind='swap' then p_slot end,amount_)
      on conflict (user_id,day,kind) do nothing;
    select * into claim from public.ad_extra_claims
     where user_id=p_user and day=today and kind=p_kind;
  elsif p_kind='swap' and claim.slot is distinct from p_slot then
    -- Still pending: the player picked another contract before watching.
    update public.ad_extra_claims set slot=p_slot where id=claim.id returning * into claim;
  end if;
  return jsonb_build_object('claimId',claim.id,'state',claim.state,'kind',claim.kind,
    'amount',claim.amount,'slot',claim.slot,'day',claim.day);
end $$;

-- Settled only by a signed AdMob callback (admob_ssv, custom_data `x1:<id>`).
-- Keyed by the claim's own day: a callback that lands after midnight pays the
-- day the ad was requested for, once.
create or replace function public.commit_ad_extra(
  p_claim uuid, p_transaction text, p_ad_unit text, p_reward_amount bigint, p_ssv_user uuid
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare claim public.ad_extra_claims; total int; draw int; acc int := 0;
  prize public.daily_wheel_prizes; granted bigint := 0; outcome_ smallint;
  code_ text; slot_ smallint; owner_ uuid;
begin
  if p_transaction is null or length(p_transaction)<8 or p_reward_amount<=0 then
    raise exception 'BAD_SSV';
  end if;
  -- Same lock order as create_ad_extra_claim (wallet, then claim row), so
  -- the two can never deadlock: the owner is read unlocked (user_id never
  -- changes, ad_extra_claim_immutable), the wallet taken, then the row.
  select c.user_id into owner_ from public.ad_extra_claims c where c.id=p_claim;
  if owner_ is null or owner_<>p_ssv_user then raise exception 'CLAIM_NOT_FOUND'; end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||owner_::text,91));
  select * into claim from public.ad_extra_claims where id=p_claim for update;
  if claim.id is null or claim.user_id<>p_ssv_user then raise exception 'CLAIM_NOT_FOUND'; end if;
  if claim.state='awarded' then
    if claim.transaction_id<>p_transaction then raise exception 'CLAIM_ALREADY_USED'; end if;
    return jsonb_build_object('state','awarded','kind',claim.kind,'amount',claim.amount,
      'slot',coalesce(claim.outcome,claim.slot),'code',claim.outcome_code);
  end if;
  perform public.register_ad_transaction(p_transaction,'extra',claim.id,claim.user_id);
  slot_ := claim.slot;
  if claim.kind='spin' then
    select sum(weight) into total from public.daily_wheel_prizes;
    draw := public.secure_random_below(total);
    for prize in select * from public.daily_wheel_prizes order by slot loop
      acc := acc + prize.weight;
      exit when draw < acc;
    end loop;
    if public.credit_earned(claim.user_id,'ad_extra_spin',prize.coins,null,claim.day::text) then
      granted := prize.coins;
    end if;
    outcome_ := prize.slot;
  elsif claim.kind='coffer' then
    if public.credit_earned(claim.user_id,'ad_extra_coffer',claim.amount,null,claim.day::text) then
      granted := claim.amount;
    end if;
  else
    code_ := public.ad_swap_council_contract(claim.user_id, claim.day, claim.slot);
    if code_ is null then
      -- The chosen contract was claimed meanwhile: the first unclaimed one.
      for slot_ in select d.slot from public.council_daily_contracts d
          where d.user_id=claim.user_id and d.day=claim.day and d.claimed_at is null
          order by d.slot loop
        code_ := public.ad_swap_council_contract(claim.user_id, claim.day, slot_);
        exit when code_ is not null;
      end loop;
      if code_ is null then slot_ := claim.slot; end if;
    end if;
  end if;
  update public.ad_extra_claims set state='awarded',transaction_id=p_transaction,
    ad_unit=p_ad_unit,reward_amount=p_reward_amount,awarded_at=now(),
    amount=case when claim.kind='spin' then prize.coins else amount end,
    outcome=outcome_, outcome_code=code_, slot=slot_
   where id=claim.id;
  return jsonb_build_object('state','awarded','kind',claim.kind,
    'amount',case when claim.kind='spin' then prize.coins else claim.amount end,'granted',granted,
    'slot',coalesce(outcome_,slot_),'code',code_);
end $$;

-- 6. Capabilities: `ads` -------------------------------------------------------
alter function public.economy_capabilities(uuid) rename to economy_capabilities_pre_ads;
create function public.economy_capabilities(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare cfg public.economy_config;
begin
  select * into cfg from public.economy_config;
  return public.economy_capabilities_pre_ads(p_user) || jsonb_build_object('ads',
    jsonb_build_object(
      'appOpen', jsonb_build_object('enabled', coalesce(cfg.app_open_enabled,false),
        'maxPerDay', coalesce(cfg.app_open_max_per_day,0),
        'gapSeconds', coalesce(cfg.app_open_gap_seconds,14400),
        'resumeAfterSeconds', coalesce(cfg.app_open_resume_after_seconds,14400)),
      'banner', jsonb_build_object('enabled', coalesce(cfg.banner_enabled,false)),
      'extras', jsonb_build_object('spin', public.ad_extras_on('spin'),
        'coffer', public.ad_extras_on('coffer'), 'swap', public.ad_extras_on('swap'))));
end $$;

-- 7. Deletion covers the new records -------------------------------------------
alter function public.complete_data_deletion(uuid) rename to complete_data_deletion_pre_ads;
create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;
  perform public.complete_data_deletion_pre_ads(p_request);
  if who is not null then delete from public.ad_extra_claims where user_id=who; end if;
end $$;

alter function public.purge_orphan_economy() rename to purge_orphan_economy_pre_ads;
create function public.purge_orphan_economy()
returns integer language plpgsql security definer set search_path=public,auth,pg_temp as $$
begin
  delete from public.ad_extra_claims d where not exists(select 1 from auth.users u where u.id=d.user_id);
  return public.purge_orphan_economy_pre_ads();
end $$;

-- 8. Grants: named one by one --------------------------------------------------
revoke all on function public.ad_extra_claim_immutable() from public, anon, authenticated;
revoke all on function public.ad_extras_on(text) from public, anon, authenticated;
grant execute on function public.ad_extras_on(text) to service_role;
revoke all on function public.ad_swap_candidate(uuid,date,int) from public, anon, authenticated;
grant execute on function public.ad_swap_candidate(uuid,date,int) to service_role;
revoke all on function public.ad_swap_council_contract(uuid,date,int) from public, anon, authenticated;
grant execute on function public.ad_swap_council_contract(uuid,date,int) to service_role;
revoke all on function public.ad_extras_status(uuid) from public, anon, authenticated;
grant execute on function public.ad_extras_status(uuid) to service_role;
revoke all on function public.create_ad_extra_claim(uuid,date,text,int) from public, anon, authenticated;
grant execute on function public.create_ad_extra_claim(uuid,date,text,int) to service_role;
revoke all on function public.commit_ad_extra(uuid,text,text,bigint,uuid) from public, anon, authenticated;
grant execute on function public.commit_ad_extra(uuid,text,text,bigint,uuid) to service_role;
revoke all on function public.economy_capabilities_pre_ads(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities_pre_ads(uuid) to service_role;
revoke all on function public.economy_capabilities(uuid) from public, anon, authenticated;
grant execute on function public.economy_capabilities(uuid) to service_role;
revoke all on function public.complete_data_deletion_pre_ads(uuid) from public, anon, authenticated;
grant execute on function public.complete_data_deletion_pre_ads(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public, anon, authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
revoke all on function public.purge_orphan_economy_pre_ads() from public, anon, authenticated;
grant execute on function public.purge_orphan_economy_pre_ads() to service_role;
revoke all on function public.purge_orphan_economy() from public, anon, authenticated;
grant execute on function public.purge_orphan_economy() to service_role;
