-- Payments v2: manual InstaPay / Vodafone Cash transfers on Android AND web,
-- beside Google Play Billing on Android. Additive over 20260924000500,
-- 20260925000200 and 20260925000400: the order functions keep their names and
-- signatures; approval still credits exactly once and refunds keep debt_offset.
--
-- What changes:
--   * One server price table (coin_packs) for every transfer product, priced
--     in EGP exactly like its Play product (play_product), changeable by SQL.
--   * The Starter Bundle is sold by transfer too (same grant as Play, once per
--     account).
--   * Proof: a payment screenshot (private Storage bucket, sha256 unique across
--     all orders) plus the sender name as the payment app shows it.
--   * Up to 2 pending orders per player; an order with no proof expires after
--     72 h (one with proof stays pending until the owner reviews it);
--     a rejection needs a reason, which the player sees.
--   * Remote kill switch per platform (economy_config.transfer_enabled_*),
--     default OFF.
--   * Proof images are deleted 90 days after the order is settled (or at once
--     when the account is deleted); the order record itself is kept.
--   * The owner is seeded as a commerce admin when that auth user exists.

-- 1. Price table ----------------------------------------------------------------
alter table public.coin_packs
  add column if not exists play_product text unique,
  add column if not exists item_code text references public.reward_catalog(code);

insert into public.coin_packs(code,coins,item_code,sort_order)
  values('starter_bundle',
    coalesce((select coins from public.play_products where product_id='mm_starter_bundle'),600),
    'frame_council_seal',1)
on conflict (code) do nothing;

-- Same price on every method: the Play product's EGP price, in piastres.
update public.coin_packs p set play_product=v.play_product, price_piastres=v.price, active=true
  from (values
    ('coins_500','mm_coins_500',4999),
    ('coins_1200','mm_coins_1200',9999),
    ('coins_2500','mm_coins_2500',18000),
    ('quiet_pass','mm_remove_interruptions',19999),
    ('starter_bundle','mm_starter_bundle',2999)
  ) v(code,play_product,price)
 where p.code=v.code;

-- 2. Remote kill switch, per platform. OFF until the owner flips it. --------------
alter table public.economy_config
  add column if not exists transfer_enabled_android boolean not null default false,
  add column if not exists transfer_enabled_web boolean not null default false;

create or replace function public.transfer_enabled(p_platform text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select case p_platform
      when 'android' then c.transfer_enabled_android
      when 'web' then c.transfer_enabled_web
      else false end
    from public.economy_config c limit 1), false)
$$;

-- 3. Orders: proof, sender, platform ------------------------------------------------
alter table public.coin_orders
  add column if not exists platform text check (platform in ('android','web')),
  add column if not exists sender_name text check (char_length(sender_name) between 2 and 80),
  add column if not exists proof_path text check (char_length(proof_path) <= 300),
  add column if not exists proof_sha256 text check (proof_sha256 ~ '^[0-9a-f]{64}$'),
  add column if not exists proof_purged_at timestamptz;
alter table public.coin_orders alter column expires_at set default now() + interval '72 hours';

-- Up to two pending orders, counted in the functions (not one per player).
drop index if exists public.coin_orders_one_open;
-- One screenshot can back one order, ever (rejected and purged ones included:
-- the hash is kept after the image is deleted).
create unique index if not exists coin_orders_proof_once
  on public.coin_orders(proof_sha256) where proof_sha256 is not null;
create index if not exists coin_orders_user_recent on public.coin_orders(user_id, created_at desc);

-- A deleted account keeps its payment record, detached: the sender name goes
-- with the person and the proof image becomes due for deletion at once.
create or replace function public.coin_order_detach()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if old.user_id is not null and new.user_id is null then
    new.sender_name := null;
  end if;
  return new;
end $$;
drop trigger if exists coin_order_detach on public.coin_orders;
create trigger coin_order_detach before update of user_id on public.coin_orders
  for each row execute function public.coin_order_detach();

-- 4. Expiry: 72 h without proof ------------------------------------------------------
-- Only an order the player never sent proof for expires. Once a screenshot is
-- in (claimed, or needs_info after a review question), the player may have paid:
-- it stays pending until the owner approves or rejects it.
create or replace function public.expire_coin_orders(p_user uuid default null)
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
  with gone as (
    update public.coin_orders set status='expired'
     where status='awaiting_transfer' and proof_sha256 is null and expires_at < now()
       and (p_user is null or user_id=p_user)
    returning id
  ), logged as (
    insert into public.coin_order_events(order_id,actor,action)
    select id,'system','expired' from gone returning 1
  ) select count(*) into n from logged;
  return n;
end $$;

create or replace function public.coin_order_json(o public.coin_orders)
returns jsonb language sql stable set search_path=public,pg_temp as $$
  select jsonb_build_object('id',o.id,'reference',o.reference,'pack',o.pack_code,
    'coins',o.coins,'amountPiastres',o.amount_piastres,'currency',o.currency,
    'method',o.method,'status',o.status,'createdAt',o.created_at,
    'expiresAt',o.expires_at,'claimReference',o.claim_reference,
    'playerNote',o.player_note,'paidAt',o.paid_at,
    'senderName',o.sender_name,'proofSubmitted',o.proof_sha256 is not null,
    'submittedAt',o.claimed_at,'reviewedAt',o.reviewed_at)
$$;

create or replace function public.coin_pending_count(p_user uuid, p_except uuid default null)
returns integer language sql stable security definer set search_path=public,pg_temp as $$
  select count(*)::int from public.coin_orders where user_id=p_user
    and status in ('awaiting_transfer','claimed','needs_info')
    and id is distinct from p_except
$$;

-- 5. Create: resume the same unpaid pack, never more than two pending --------------
create or replace function public.create_coin_order_base(p_user uuid, p_pack text, p_method text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare pack public.coin_packs; existing public.coin_orders; created public.coin_orders;
begin
  if p_method not in ('instapay','vodafone_cash') then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended('coin_order:'||p_user::text,17));
  if not public.account_is_recoverable(p_user) then raise exception 'ACCOUNT_NOT_RECOVERABLE'; end if;
  perform public.expire_coin_orders(p_user);
  -- Tapping the same product again resumes its unpaid order (method may change).
  select * into existing from public.coin_orders where user_id=p_user
    and pack_code=p_pack and status='awaiting_transfer'
    order by created_at desc limit 1;
  if found then
    update public.coin_orders set method=p_method where id=existing.id returning * into existing;
    return jsonb_build_object('order',public.coin_order_json(existing),'resumed',true);
  end if;
  if public.coin_pending_count(p_user) >= 2 then raise exception 'TOO_MANY_PENDING'; end if;
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

-- The Starter Bundle's once-per-account rule, on the transfer side.
create or replace function public.coin_bundle_taken(p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select public.owns_starter_bundle(p_user) or exists(
    select 1 from public.coin_orders o join public.coin_packs p on p.code=o.pack_code
     where o.user_id=p_user and p.item_code is not null
       and o.status in ('claimed','needs_info','paid'))
$$;

create or replace function public.create_coin_order(p_user uuid, p_pack text, p_method text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare pack public.coin_packs;
begin
  select * into pack from public.coin_packs where code=p_pack;
  if pack.entitlement is not null and public.user_owns_entitlement(p_user, pack.entitlement)
     and not exists(select 1 from public.coin_orders where user_id=p_user
       and pack_code=p_pack and status='awaiting_transfer') then
    raise exception 'ALREADY_OWNED';
  end if;
  if pack.item_code is not null then
    if not public.council_on('bundle') then raise exception 'PACK_UNAVAILABLE'; end if;
    if public.coin_bundle_taken(p_user) then raise exception 'ALREADY_OWNED'; end if;
  end if;
  return public.create_coin_order_base(p_user, p_pack, p_method);
end $$;

-- The v2 entry point: the platform's kill switch first.
create or replace function public.create_coin_order_v2(p_user uuid, p_pack text,
  p_method text, p_platform text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r jsonb;
begin
  if not public.transfer_enabled(p_platform) then raise exception 'SALES_DISABLED'; end if;
  r := public.create_coin_order(p_user, p_pack, p_method);
  update public.coin_orders set platform=p_platform
   where id=(r->'order'->>'id')::uuid and platform is null;
  return r;
end $$;

-- 6. Proof ---------------------------------------------------------------------------
-- Read-only, before the edge function stores an image: the platform's switch,
-- ownership and a state that can take a proof. submit_coin_order_proof repeats
-- every check under the player's lock; this only keeps refused submissions
-- out of the bucket.
create or replace function public.coin_order_proof_precheck(p_user uuid, p_order uuid,
  p_platform text)
returns void language plpgsql stable security definer set search_path=public,pg_temp as $$
declare o public.coin_orders;
begin
  if not public.transfer_enabled(p_platform) then raise exception 'SALES_DISABLED'; end if;
  select * into o from public.coin_orders where id=p_order and user_id=p_user;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if o.status not in ('awaiting_transfer','needs_info','expired') then
    raise exception 'ORDER_NOT_CLAIMABLE';
  end if;
  if o.status='expired' and public.coin_pending_count(p_user, o.id) >= 2 then
    raise exception 'TOO_MANY_PENDING';
  end if;
end $$;

-- The edge function has already stored the image (service role, private bucket)
-- and computed its sha256 from the bytes it received. Returns the previous
-- proof path of this order (a resubmission), for the caller to delete.
create or replace function public.submit_coin_order_proof(p_user uuid, p_order uuid,
  p_sender text, p_path text, p_sha256 text, p_platform text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders; previous text; sender text := btrim(coalesce(p_sender,''));
begin
  if not public.transfer_enabled(p_platform) then raise exception 'SALES_DISABLED'; end if;
  if char_length(sender) < 2 or char_length(sender) > 80 then raise exception 'SENDER_REQUIRED'; end if;
  if p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' or p_path is null
     or p_path !~ ('^'||p_user::text||'/') then
    raise exception 'PROOF_REQUIRED';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('coin_order:'||p_user::text,17));
  perform public.expire_coin_orders(p_user);
  select * into o from public.coin_orders where id=p_order and user_id=p_user for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if o.status not in ('awaiting_transfer','needs_info','expired') then
    raise exception 'ORDER_NOT_CLAIMABLE';
  end if;
  if o.status='expired' and public.coin_pending_count(p_user, o.id) >= 2 then
    raise exception 'TOO_MANY_PENDING';
  end if;
  if exists(select 1 from public.coin_orders where proof_sha256=p_sha256 and id<>o.id) then
    raise exception 'DUPLICATE_PROOF';
  end if;
  previous := o.proof_path;
  begin
    update public.coin_orders set status='claimed', sender_name=sender,
      proof_path=p_path, proof_sha256=p_sha256, proof_purged_at=null,
      claimed_at=now(), expires_at=now()+interval '72 hours', player_note=null,
      platform=coalesce(platform,p_platform)
     where id=o.id returning * into o;
  exception when unique_violation then
    raise exception 'DUPLICATE_PROOF';
  end;
  perform public.log_coin_order(o.id,'player',p_user,'proof_submitted',
    jsonb_build_object('sha256',left(p_sha256,12)));
  return jsonb_build_object('order',public.coin_order_json(o),
    'previousPath',case when previous is distinct from p_path then previous end,
    'pack',o.pack_code,'coins',o.coins,'item',(select item_code from public.coin_packs where code=o.pack_code),
    'entitlement',(select entitlement from public.coin_packs where code=o.pack_code));
end $$;

-- 7. Shop -----------------------------------------------------------------------------
create or replace function public.coin_shop_v2(p_user uuid, p_platform text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare packs jsonb; bundle_open boolean := public.council_on('bundle')
  and not public.coin_bundle_taken(p_user);
begin
  select coalesce(jsonb_agg(jsonb_build_object('code',code,'coins',coins,
      'pricePiastres',price_piastres,'currency',currency,'entitlement',entitlement,
      'item',item_code,'playProduct',play_product) order by sort_order),'[]')
    into packs from public.coin_packs
   where active and price_piastres is not null and (item_code is null or bundle_open);
  return public.coin_shop(p_user) || jsonb_build_object('packs',packs,
    'enabled',public.transfer_enabled(p_platform),
    'maxPending',2,'pending',public.coin_pending_count(p_user));
end $$;

-- 8. Admin -----------------------------------------------------------------------------
create or replace function public.admin_coin_orders_v2(p_admin uuid, p_filter text default 'pending')
returns jsonb language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare rows jsonb; statuses text[];
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  statuses := case coalesce(p_filter,'pending')
    when 'pending' then array['claimed','needs_info']
    when 'approved' then array['paid','refunded']
    when 'rejected' then array['rejected']
    when 'expired' then array['expired','cancelled']
    else null end;
  if statuses is null then raise exception 'BAD_REQUEST'; end if;
  perform public.expire_coin_orders(null);
  select coalesce(jsonb_agg(public.coin_order_json(o) || jsonb_build_object(
      'proofPath',o.proof_path,'proofPurged',o.proof_purged_at is not null,
      'item',p.item_code,'entitlement',p.entitlement,'platform',o.platform,
      'credited',o.credited,'payerHint',o.payer_hint,
      'displayName',coalesce((select i.name from public.council_identity i where i.user_id=o.user_id),
        (select u.email from auth.users u where u.id=o.user_id)),
      'account',(select u.email from auth.users u where u.id=o.user_id))
    order by coalesce(o.claimed_at,o.created_at) desc),'[]') into rows
  from (select * from public.coin_orders where status=any(statuses)
         order by coalesce(claimed_at,created_at) desc limit 200) o
  left join public.coin_packs p on p.code=o.pack_code;
  return jsonb_build_object('orders',rows);
end $$;

-- Approve a submitted proof: the amount is the order's own (the admin matched
-- it in the payment app); the transfer id defaults to the proof's hash.
create or replace function public.admin_approve_coin_order(p_admin uuid, p_order uuid,
  p_transaction text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  select * into o from public.coin_orders where id=p_order;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if o.proof_sha256 is null then raise exception 'PROOF_REQUIRED'; end if;
  return public.admin_review_coin_order(p_admin, p_order, 'approve',
    coalesce(nullif(btrim(coalesce(p_transaction,'')),''), 'proof:'||left(o.proof_sha256,24)),
    o.amount_piastres, null);
end $$;

create or replace function public.admin_reject_coin_order(p_admin uuid, p_order uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_reason is null or char_length(btrim(p_reason)) < 3 then raise exception 'NOTE_REQUIRED'; end if;
  return public.admin_review_coin_order(p_admin, p_order, 'reject', null, null, p_reason);
end $$;

-- Approval of a Starter Bundle order: the same grant as Play (coins through
-- the base, debt included, plus frame_council_seal), once per account.
alter function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text)
  rename to admin_review_coin_order_pass;
create function public.admin_review_coin_order(p_admin uuid, p_order uuid,
  p_decision text, p_provider_transaction text default null,
  p_received_piastres bigint default null, p_note text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; o public.coin_orders; pack public.coin_packs; token text;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  select * into o from public.coin_orders where id=p_order;
  select * into pack from public.coin_packs where code=o.pack_code;
  if p_decision='approve' and pack.item_code is not null and o.user_id is not null
     and o.status<>'paid' and public.owns_starter_bundle(o.user_id) then
    -- Already has it (Play or another order): reject and return the money.
    raise exception 'ALREADY_OWNED';
  end if;
  result := public.admin_review_coin_order_pass(p_admin,p_order,p_decision,
    p_provider_transaction,p_received_piastres,p_note);
  select * into o from public.coin_orders where id=p_order;
  if p_decision='approve' and o.status='paid' and pack.item_code is not null
     and o.user_id is not null then
    token := public.coin_order_token(o.id);
    insert into public.play_purchases(purchase_token,user_id,product_id,state,
        purchased_at,granted_at,credited,debt_offset)
      values(token,o.user_id,coalesce(pack.play_product,'mm_starter_bundle'),'active',
        o.paid_at,now(),o.credited,o.debt_offset)
      on conflict (purchase_token) do nothing;
    insert into public.player_inventory(user_id,item_code) values(o.user_id,pack.item_code)
      on conflict do nothing;
  end if;
  return result;
end $$;

alter function public.admin_refund_coin_order(uuid,uuid,text)
  rename to admin_refund_coin_order_pass;
create function public.admin_refund_coin_order(p_admin uuid, p_order uuid, p_note text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; o public.coin_orders; pack public.coin_packs;
begin
  select * into o from public.coin_orders where id=p_order;
  select * into pack from public.coin_packs where code=o.pack_code;
  -- Coins and debt as for any order; the pass wrapper revokes the token row.
  result := public.admin_refund_coin_order_pass(p_admin,p_order,p_note);
  if pack.item_code is not null and o.user_id is not null
     and not public.owns_starter_bundle(o.user_id) then
    delete from public.player_inventory where user_id=o.user_id and item_code=pack.item_code;
  end if;
  return result;
end $$;

-- 9. Retention: proof images leave 90 days after the order is settled -----------------
create or replace function public.payment_proofs_due(p_limit integer default 100)
returns table(order_id uuid, path text)
language sql stable security definer set search_path=public,pg_temp as $$
  select id, proof_path from public.coin_orders
   where proof_path is not null and (
     user_id is null
     or (status in ('paid','rejected','refunded','cancelled')
         and coalesce(refunded_at, reviewed_at, created_at) < now() - interval '90 days')
     or (status='expired' and expires_at < now() - interval '90 days'))
   order by created_at
   limit greatest(1, least(coalesce(p_limit,100), 500))
$$;

create or replace function public.mark_payment_proofs_purged(p_paths text[])
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
  update public.coin_orders set proof_path=null, proof_purged_at=now()
   where proof_path = any(coalesce(p_paths,'{}'::text[]));
  get diagnostics n = row_count;
  return n;
end $$;

-- 10. Owner as commerce admin (idempotent; re-run after the owner first signs in) --------
insert into public.commerce_admins(user_id,note)
  select id,'owner' from auth.users
   where lower(email)='eyadsyam124@gmail.com' and coalesce(is_anonymous,false)=false
on conflict (user_id) do nothing;

-- 11. Private proof bucket (hosted Storage only; skipped where it does not exist) -------
do $$
begin
  if to_regclass('storage.buckets') is not null then
    execute $b$insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
      values('payment-proofs','payment-proofs',false,3145728,
        array['image/jpeg','image/png','image/webp'])
      on conflict (id) do update set public=false$b$;
  end if;
  -- No insert/update/delete policy at all: only the service role (the edge
  -- function) writes. A player may read back only their own folder; the admin
  -- sees images through short-lived signed URLs made by the service role.
  if to_regclass('storage.objects') is not null then
    execute 'drop policy if exists payment_proofs_owner_read on storage.objects';
    execute $p$create policy payment_proofs_owner_read on storage.objects
      for select to authenticated
      using (bucket_id='payment-proofs' and (storage.foldername(name))[1]=auth.uid()::text)$p$;
  end if;
end $$;

-- 12. Surface: service role only, named one by one ------------------------------------
revoke all on function public.transfer_enabled(text) from public, anon, authenticated;
grant execute on function public.transfer_enabled(text) to service_role;
revoke all on function public.coin_order_detach() from public, anon, authenticated;
revoke all on function public.coin_pending_count(uuid,uuid) from public, anon, authenticated;
grant execute on function public.coin_pending_count(uuid,uuid) to service_role;
revoke all on function public.expire_coin_orders(uuid) from public, anon, authenticated;
grant execute on function public.expire_coin_orders(uuid) to service_role;
revoke all on function public.coin_order_json(public.coin_orders) from public, anon, authenticated;
grant execute on function public.coin_order_json(public.coin_orders) to service_role;
revoke all on function public.create_coin_order_base(uuid,text,text) from public, anon, authenticated;
grant execute on function public.create_coin_order_base(uuid,text,text) to service_role;
revoke all on function public.coin_bundle_taken(uuid) from public, anon, authenticated;
grant execute on function public.coin_bundle_taken(uuid) to service_role;
revoke all on function public.create_coin_order(uuid,text,text) from public, anon, authenticated;
grant execute on function public.create_coin_order(uuid,text,text) to service_role;
revoke all on function public.create_coin_order_v2(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.create_coin_order_v2(uuid,text,text,text) to service_role;
revoke all on function public.coin_order_proof_precheck(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.coin_order_proof_precheck(uuid,uuid,text) to service_role;
revoke all on function public.submit_coin_order_proof(uuid,uuid,text,text,text,text) from public, anon, authenticated;
grant execute on function public.submit_coin_order_proof(uuid,uuid,text,text,text,text) to service_role;
revoke all on function public.coin_shop_v2(uuid,text) from public, anon, authenticated;
grant execute on function public.coin_shop_v2(uuid,text) to service_role;
revoke all on function public.admin_coin_orders_v2(uuid,text) from public, anon, authenticated;
grant execute on function public.admin_coin_orders_v2(uuid,text) to service_role;
revoke all on function public.admin_approve_coin_order(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_approve_coin_order(uuid,uuid,text) to service_role;
revoke all on function public.admin_reject_coin_order(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_reject_coin_order(uuid,uuid,text) to service_role;
revoke all on function public.admin_review_coin_order_pass(uuid,uuid,text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_review_coin_order_pass(uuid,uuid,text,text,bigint,text) to service_role;
revoke all on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) to service_role;
revoke all on function public.admin_refund_coin_order_pass(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_refund_coin_order_pass(uuid,uuid,text) to service_role;
revoke all on function public.admin_refund_coin_order(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_refund_coin_order(uuid,uuid,text) to service_role;
revoke all on function public.payment_proofs_due(integer) from public, anon, authenticated;
grant execute on function public.payment_proofs_due(integer) to service_role;
revoke all on function public.mark_payment_proofs_purged(text[]) from public, anon, authenticated;
grant execute on function public.mark_payment_proofs_purged(text[]) to service_role;
