-- Web coin packs paid by InstaPay / Vodafone Cash transfer, verified by hand.
--
-- MANUAL VERIFICATION; NO GATEWAY OR WEBHOOK. Nothing a client sends can add
-- coins: opening a payment link, coming back from it, or claiming "I sent it"
-- only moves an order into the review queue. Coins are added by an admin who
-- has matched the money in the real account (amount, method, reference), in
-- one transaction that also marks the order paid, exactly once, with the
-- reviewer and time recorded. One provider transaction can fund one order.
--
-- Sold only to recoverable accounts (linked, confirmed email), so a paid
-- balance survives uninstall and a new phone. Play builds never call this.

-- 1. Packs: prices are the owner's decision. Seeded inactive and unpriced; an
-- operator sets price_piastres and active=true when ready.
create table public.coin_packs (
  code text primary key check (code ~ '^[a-z0-9_]{3,40}$'),
  coins bigint not null check (coins > 0),
  price_piastres bigint check (price_piastres > 0),
  currency text not null default 'EGP' check (currency = 'EGP'),
  active boolean not null default false,
  sort_order integer not null default 0,
  check (not active or price_piastres is not null)
);
insert into public.coin_packs(code,coins,sort_order) values
  ('coins_500',500,10),('coins_1200',1200,20),('coins_2500',2500,30)
on conflict (code) do nothing;

create table public.commerce_admins (
  user_id uuid primary key,
  note text not null default '',
  added_at timestamptz not null default now()
);

-- 2. Orders ---------------------------------------------------------------
create table public.coin_orders (
  id uuid primary key default gen_random_uuid(),
  -- Nulled (not deleted) on data deletion: payment records are kept.
  user_id uuid,
  reference text not null unique,
  pack_code text not null references public.coin_packs(code),
  coins bigint not null check (coins > 0),
  amount_piastres bigint not null check (amount_piastres > 0),
  currency text not null default 'EGP' check (currency = 'EGP'),
  method text not null check (method in ('instapay','vodafone_cash')),
  status text not null default 'awaiting_transfer' check (status in (
    'awaiting_transfer','claimed','needs_info','paid','rejected','cancelled',
    'expired','refunded')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  claim_reference text check (claim_reference ~ '^[A-Za-z0-9 ._/-]{4,64}$'),
  payer_hint text check (char_length(payer_hint) <= 60),
  claimed_at timestamptz,
  player_note text check (char_length(player_note) <= 300),
  provider_transaction text check (char_length(provider_transaction) between 4 and 80),
  received_piastres bigint,
  reviewed_by uuid,
  reviewed_at timestamptz,
  credited bigint not null default 0,
  paid_at timestamptz,
  refunded_at timestamptz
);
-- One open order per player: repeated taps resume it instead of stacking.
create unique index coin_orders_one_open on public.coin_orders(user_id)
  where status in ('awaiting_transfer','claimed','needs_info');
-- One real transfer funds at most one order, per provider.
create unique index coin_orders_transfer_once
  on public.coin_orders(method, provider_transaction)
  where provider_transaction is not null;
create index coin_orders_queue on public.coin_orders(status, created_at);

create table public.coin_order_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.coin_orders(id) on delete cascade,
  actor text not null check (actor in ('player','admin','system')),
  actor_id uuid,
  action text not null,
  -- Redacted: no PINs, passwords or full account numbers are ever collected.
  details jsonb not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.coin_packs enable row level security;
alter table public.commerce_admins enable row level security;
alter table public.coin_orders enable row level security;
alter table public.coin_order_events enable row level security;
revoke all on public.coin_packs, public.commerce_admins, public.coin_orders,
  public.coin_order_events from public, anon, authenticated;
grant all on public.coin_packs, public.commerce_admins, public.coin_orders,
  public.coin_order_events to service_role;

-- 3. Wallet: purchased coins are tracked apart from earned ones -----------
alter table public.wallet_accounts
  add column if not exists purchased_balance bigint not null default 0 check (purchased_balance >= 0),
  add column if not exists lifetime_purchased bigint not null default 0 check (lifetime_purchased >= 0),
  add column if not exists purchase_debt bigint not null default 0 check (purchase_debt >= 0);
alter table public.wallet_accounts add constraint wallet_purchased_within_balance
  check (purchased_balance <= balance);
alter table public.wallet_ledger add column if not exists source_order uuid;
create unique index if not exists wallet_order_once
  on public.wallet_ledger(source_order, kind) where source_order is not null;

-- 4. Helpers --------------------------------------------------------------
create or replace function public.is_commerce_admin(p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.commerce_admins where user_id=p_user)
$$;

create or replace function public.account_is_recoverable(p_user uuid)
returns boolean language sql stable security definer set search_path=public,auth,pg_temp as $$
  select exists(select 1 from auth.users u where u.id=p_user
    and coalesce(u.is_anonymous,false)=false
    and u.email is not null and u.email_confirmed_at is not null)
$$;

create or replace function public.coin_order_json(o public.coin_orders)
returns jsonb language sql stable set search_path=public,pg_temp as $$
  select jsonb_build_object('id',o.id,'reference',o.reference,'pack',o.pack_code,
    'coins',o.coins,'amountPiastres',o.amount_piastres,'currency',o.currency,
    'method',o.method,'status',o.status,'createdAt',o.created_at,
    'expiresAt',o.expires_at,'claimReference',o.claim_reference,
    'playerNote',o.player_note,'paidAt',o.paid_at)
$$;

create or replace function public.log_coin_order(p_order uuid, p_actor text,
  p_actor_id uuid, p_action text, p_details jsonb default '{}')
returns void language sql security definer set search_path=public,pg_temp as $$
  insert into public.coin_order_events(order_id,actor,actor_id,action,details)
  values(p_order,p_actor,p_actor_id,p_action,coalesce(p_details,'{}'))
$$;

-- Awaiting orders past their window become 'expired' (never deleted: a late
-- transfer can still be claimed and reconciled).
create or replace function public.expire_coin_orders(p_user uuid default null)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
  with gone as (
    update public.coin_orders set status='expired'
     where status='awaiting_transfer' and expires_at < now()
       and (p_user is null or user_id=p_user)
    returning id
  ), logged as (
    insert into public.coin_order_events(order_id,actor,action)
    select id,'system','expired' from gone returning 1
  ) select count(*) into n from logged;
  return n;
end $$;

-- 5. Player side ----------------------------------------------------------
create or replace function public.coin_shop(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare packs jsonb; orders jsonb;
begin
  perform public.expire_coin_orders(p_user);
  select coalesce(jsonb_agg(jsonb_build_object('code',code,'coins',coins,
      'pricePiastres',price_piastres,'currency',currency) order by sort_order),'[]')
    into packs from public.coin_packs where active;
  select coalesce(jsonb_agg(public.coin_order_json(o) order by o.created_at desc),'[]')
    into orders from (select * from public.coin_orders where user_id=p_user
      order by created_at desc limit 10) o;
  return jsonb_build_object('packs',packs,'orders',orders,
    'recoverable',public.account_is_recoverable(p_user));
end $$;

create or replace function public.create_coin_order(p_user uuid, p_pack text, p_method text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare pack public.coin_packs; existing public.coin_orders; created public.coin_orders;
begin
  if p_method not in ('instapay','vodafone_cash') then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended('coin_order:'||p_user::text,17));
  if not public.account_is_recoverable(p_user) then raise exception 'ACCOUNT_NOT_RECOVERABLE'; end if;
  perform public.expire_coin_orders(p_user);
  select * into existing from public.coin_orders where user_id=p_user
    and status in ('awaiting_transfer','claimed','needs_info');
  if found then
    -- Resume, never stack: the player sees the order they already have.
    return jsonb_build_object('order',public.coin_order_json(existing),'resumed',true);
  end if;
  select * into pack from public.coin_packs where code=p_pack and active;
  if not found or pack.price_piastres is null then raise exception 'PACK_UNAVAILABLE'; end if;
  insert into public.coin_orders(user_id,reference,pack_code,coins,amount_piastres,method)
  values(p_user,'MM-'||upper(substr(md5(gen_random_uuid()::text),1,8)),
    pack.code,pack.coins,pack.price_piastres,p_method)
  returning * into created;
  perform public.log_coin_order(created.id,'player',p_user,'created',
    jsonb_build_object('pack',pack.code,'amount',pack.price_piastres,'method',p_method));
  return jsonb_build_object('order',public.coin_order_json(created),'resumed',false);
end $$;

create or replace function public.claim_coin_order(p_user uuid, p_order uuid,
  p_reference text, p_payer_hint text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders;
begin
  select * into o from public.coin_orders where id=p_order and user_id=p_user for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if o.status not in ('awaiting_transfer','needs_info','expired') then
    raise exception 'ORDER_NOT_CLAIMABLE';
  end if;
  if exists(select 1 from public.coin_orders where user_id=p_user and id<>o.id
      and status in ('awaiting_transfer','claimed','needs_info')) then
    raise exception 'ORDER_OPEN';
  end if;
  update public.coin_orders set status='claimed', claim_reference=btrim(p_reference),
    payer_hint=nullif(btrim(coalesce(p_payer_hint,'')),''), claimed_at=now()
   where id=o.id returning * into o;
  -- A claim is evidence for a human, not a payment. No wallet change here.
  perform public.log_coin_order(o.id,'player',p_user,'claimed',
    jsonb_build_object('reference',o.claim_reference));
  return public.coin_order_json(o);
end $$;

create or replace function public.cancel_coin_order(p_user uuid, p_order uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders;
begin
  update public.coin_orders set status='cancelled'
   where id=p_order and user_id=p_user and status='awaiting_transfer'
  returning * into o;
  if not found then raise exception 'ORDER_NOT_CANCELLABLE'; end if;
  perform public.log_coin_order(o.id,'player',p_user,'cancelled');
  return public.coin_order_json(o);
end $$;

-- 6. Admin side -----------------------------------------------------------
create or replace function public.admin_coin_orders(p_admin uuid, p_status text default null)
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare rows jsonb;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  perform public.expire_coin_orders(null);
  select coalesce(jsonb_agg(public.coin_order_json(o) || jsonb_build_object(
      'payerHint',o.payer_hint,'claimedAt',o.claimed_at,
      'providerTransaction',o.provider_transaction,'reviewedAt',o.reviewed_at,
      'credited',o.credited,'account',(select u.email from auth.users u where u.id=o.user_id))
    order by o.claimed_at nulls last, o.created_at),'[]') into rows
  from public.coin_orders o
  where (p_status is null and o.status in ('claimed','needs_info','expired','awaiting_transfer'))
     or o.status=p_status;
  return jsonb_build_object('orders',rows);
end $$;

create or replace function public.admin_review_coin_order(p_admin uuid, p_order uuid,
  p_decision text, p_provider_transaction text default null,
  p_received_piastres bigint default null, p_note text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders; w public.wallet_accounts; offset_debt bigint; credit bigint;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  select * into o from public.coin_orders where id=p_order for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;

  if p_decision = 'approve' then
    if o.status not in ('awaiting_transfer','claimed','needs_info','expired') then
      raise exception 'ORDER_NOT_REVIEWABLE';
    end if;
    if o.user_id is null then raise exception 'ORDER_NOT_REVIEWABLE'; end if;
    if p_provider_transaction is null or char_length(btrim(p_provider_transaction)) < 4 then
      raise exception 'TRANSACTION_REQUIRED';
    end if;
    if p_received_piastres is distinct from o.amount_piastres then
      -- Wrong amounts are never "approved": ask, or reject and refund.
      raise exception 'AMOUNT_MISMATCH';
    end if;
    begin
      update public.coin_orders set provider_transaction=btrim(p_provider_transaction)
       where id=o.id;
    exception when unique_violation then
      raise exception 'TRANSFER_ALREADY_USED';
    end;
    perform pg_advisory_xact_lock(hashtextextended('wallet:'||o.user_id::text,91));
    insert into public.wallet_accounts(user_id) values(o.user_id) on conflict do nothing;
    select * into w from public.wallet_accounts where user_id=o.user_id for update;
    offset_debt := least(w.purchase_debt, o.coins);
    credit := o.coins - offset_debt;
    update public.wallet_accounts set balance=balance+credit,
      purchased_balance=purchased_balance+credit,
      lifetime_purchased=lifetime_purchased+o.coins,
      purchase_debt=purchase_debt-offset_debt, updated_at=now()
     where user_id=o.user_id;
    if credit > 0 then
      -- unique (source_order, kind): a second approval cannot credit again.
      insert into public.wallet_ledger(user_id,kind,amount,source_order)
        values(o.user_id,'coin_purchase',credit,o.id);
    end if;
    update public.coin_orders set status='paid', received_piastres=p_received_piastres,
      reviewed_by=p_admin, reviewed_at=now(), paid_at=now(), credited=credit,
      player_note=null
     where id=o.id returning * into o;
    perform public.log_coin_order(o.id,'admin',p_admin,'approved',
      jsonb_build_object('credited',credit,'debtOffset',offset_debt));
  elsif p_decision in ('reject','needs_info') then
    if o.status not in ('awaiting_transfer','claimed','needs_info','expired') then
      raise exception 'ORDER_NOT_REVIEWABLE';
    end if;
    if p_note is null or btrim(p_note)='' then raise exception 'NOTE_REQUIRED'; end if;
    update public.coin_orders set
      status=case when p_decision='reject' then 'rejected' else 'needs_info' end,
      player_note=left(btrim(p_note),300), reviewed_by=p_admin, reviewed_at=now(),
      received_piastres=p_received_piastres
     where id=o.id returning * into o;
    perform public.log_coin_order(o.id,'admin',p_admin,p_decision,
      jsonb_build_object('received',p_received_piastres));
  else
    raise exception 'BAD_REQUEST';
  end if;
  return public.coin_order_json(o);
end $$;

-- Money returned to the player after coins were added. Only still-unspent
-- purchased coins are taken back; the rest becomes a debt that is offset
-- against FUTURE PURCHASED coins only. Earned coins and free play are never
-- touched.
create or replace function public.admin_refund_coin_order(p_admin uuid, p_order uuid, p_note text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders; w public.wallet_accounts; taken bigint;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_note is null or btrim(p_note)='' then raise exception 'NOTE_REQUIRED'; end if;
  select * into o from public.coin_orders where id=p_order for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if o.status <> 'paid' then raise exception 'ORDER_NOT_REFUNDABLE'; end if;
  if o.user_id is not null then
    perform pg_advisory_xact_lock(hashtextextended('wallet:'||o.user_id::text,91));
    select * into w from public.wallet_accounts where user_id=o.user_id for update;
    taken := least(w.purchased_balance, o.credited);
    update public.wallet_accounts set balance=balance-taken,
      purchased_balance=purchased_balance-taken,
      purchase_debt=purchase_debt+(o.credited-taken), updated_at=now()
     where user_id=o.user_id;
    if taken > 0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_order)
        values(o.user_id,'coin_purchase_reversal',-taken,o.id);
    end if;
  end if;
  update public.coin_orders set status='refunded', refunded_at=now(),
    player_note=left(btrim(p_note),300) where id=o.id returning * into o;
  perform public.log_coin_order(o.id,'admin',p_admin,'refunded',
    jsonb_build_object('taken',coalesce(taken,0)));
  return public.coin_order_json(o);
end $$;

-- 7. Spending uses purchased coins first (the same buying power; this only
-- decides what a later refund can take back).
create or replace function public.buy_reward_item(p_user uuid,p_item text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare item public.reward_catalog; charge bigint;
begin
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  insert into public.wallet_accounts(user_id) values(p_user) on conflict do nothing;
  select * into item from public.reward_catalog where code=p_item and active and released;
  if not found then raise exception 'ITEM_NOT_FOUND'; end if;
  if exists(select 1 from public.player_inventory where user_id=p_user and item_code=p_item) then
    return public.wallet_snapshot(p_user);
  end if;
  charge := public.catalog_charge(p_user,p_item);
  if charge > 0 then
    update public.wallet_accounts set balance=balance-charge,
      purchased_balance=greatest(0,purchased_balance-charge),
      lifetime_spent=lifetime_spent+charge, updated_at=now()
     where user_id=p_user and balance>=charge;
    if not found then raise exception 'INSUFFICIENT_COINS'; end if;
    insert into public.wallet_ledger(user_id,kind,amount,item_code)
      values(p_user,'catalog_spend',-charge,p_item);
  end if;
  insert into public.player_inventory(user_id,item_code) values(p_user,p_item);
  if item.kind='bundle' then
    insert into public.player_inventory(user_id,item_code)
      select p_user, c from unnest(item.contents) c on conflict do nothing;
  end if;
  return public.wallet_snapshot(p_user);
end $$;

-- 8. Deletion keeps payment records but detaches them from the person.
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
  delete from public.rooms where id in (select room_id from public.room_players where user_id=who);
  delete from public.player_blocks where blocker_id=who or blocked_id=who;
  delete from public.player_inventory where user_id=who;
  delete from public.wallet_ledger where user_id=who;
  delete from public.wallet_accounts where user_id=who;
  delete from auth.users where id=who;
  update public.data_deletion_requests set completed_at=now() where id=p_request;
end $$;

-- Named one by one: a DO loop hides them from the surface audit.
revoke all on function public.is_commerce_admin(uuid) from public, anon, authenticated;
grant execute on function public.is_commerce_admin(uuid) to service_role;
revoke all on function public.account_is_recoverable(uuid) from public, anon, authenticated;
grant execute on function public.account_is_recoverable(uuid) to service_role;
revoke all on function public.coin_order_json(public.coin_orders) from public, anon, authenticated;
grant execute on function public.coin_order_json(public.coin_orders) to service_role;
revoke all on function public.log_coin_order(uuid,text,uuid,text,jsonb) from public, anon, authenticated;
grant execute on function public.log_coin_order(uuid,text,uuid,text,jsonb) to service_role;
revoke all on function public.expire_coin_orders(uuid) from public, anon, authenticated;
grant execute on function public.expire_coin_orders(uuid) to service_role;
revoke all on function public.coin_shop(uuid) from public, anon, authenticated;
grant execute on function public.coin_shop(uuid) to service_role;
revoke all on function public.create_coin_order(uuid,text,text) from public, anon, authenticated;
grant execute on function public.create_coin_order(uuid,text,text) to service_role;
revoke all on function public.claim_coin_order(uuid,uuid,text,text) from public, anon, authenticated;
grant execute on function public.claim_coin_order(uuid,uuid,text,text) to service_role;
revoke all on function public.cancel_coin_order(uuid,uuid) from public, anon, authenticated;
grant execute on function public.cancel_coin_order(uuid,uuid) to service_role;
revoke all on function public.admin_coin_orders(uuid,text) from public, anon, authenticated;
grant execute on function public.admin_coin_orders(uuid,text) to service_role;
revoke all on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) to service_role;
revoke all on function public.admin_refund_coin_order(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_refund_coin_order(uuid,uuid,text) to service_role;
revoke all on function public.buy_reward_item(uuid,text) from public, anon, authenticated;
grant execute on function public.buy_reward_item(uuid,text) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public, anon, authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
