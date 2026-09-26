-- The Quiet Pass on the web store, through the same manual-transfer orders as
-- coin packs (20260924000500). Additive: the order functions keep their names
-- and signatures and still do all the coin work; this adds the entitlement.
--
-- The web shows no ads at all, so what a web buyer gets is the Android app's
-- `remove_interruptions` on the same linked account. Granted only by an admin
-- approval that matched real money, removed by that order's refund, and never
-- touched by Google's void sync (its token is not a Play token).

-- 1. A pack may carry an entitlement instead of coins -----------------------
alter table public.coin_packs drop constraint if exists coin_packs_coins_check;
alter table public.coin_packs add column if not exists entitlement text
  check (entitlement in ('remove_interruptions'));
alter table public.coin_packs add constraint coin_packs_grant_shape check (
  (entitlement is null and coins > 0) or (entitlement is not null and coins = 0));
alter table public.coin_orders drop constraint if exists coin_orders_coins_check;
alter table public.coin_orders add constraint coin_orders_coins_check check (coins >= 0);

-- Seeded inactive and unpriced, like every pack: an operator prices it.
insert into public.coin_packs(code,coins,entitlement,sort_order)
  values('quiet_pass',0,'remove_interruptions',5)
on conflict (code) do nothing;

-- The order's own stand-in for a store token, so the entitlement row has the
-- purchase it came from.
create or replace function public.coin_order_token(p_order uuid)
returns text language sql immutable set search_path=public,pg_temp as $$
  select 'coin_order:'||p_order::text
$$;

-- 2. Shop: packs say what they grant; the pass says whether it is owned ----
alter function public.coin_shop(uuid) rename to coin_shop_base;
create function public.coin_shop(p_user uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare packs jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object('code',code,'coins',coins,
      'pricePiastres',price_piastres,'currency',currency,'entitlement',entitlement)
      order by sort_order),'[]')
    into packs from public.coin_packs where active;
  return public.coin_shop_base(p_user) || jsonb_build_object('packs',packs,
    'adFree',public.user_owns_entitlement(p_user,'remove_interruptions'));
end $$;

-- 3. Create: an owner is not sold the pass twice ----------------------------
alter function public.create_coin_order(uuid,text,text) rename to create_coin_order_base;
create function public.create_coin_order(p_user uuid, p_pack text, p_method text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare grant_code text;
begin
  select entitlement into grant_code from public.coin_packs where code=p_pack;
  if grant_code is not null and public.user_owns_entitlement(p_user, grant_code)
     and not exists(select 1 from public.coin_orders where user_id=p_user
       and status in ('awaiting_transfer','claimed','needs_info')) then
    raise exception 'ALREADY_OWNED';
  end if;
  return public.create_coin_order_base(p_user, p_pack, p_method);
end $$;

-- 4. Approval grants; refund removes ---------------------------------------
alter function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text)
  rename to admin_review_coin_order_base;
create function public.admin_review_coin_order(p_admin uuid, p_order uuid,
  p_decision text, p_provider_transaction text default null,
  p_received_piastres bigint default null, p_note text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; o public.coin_orders; grant_code text; token text;
begin
  result := public.admin_review_coin_order_base(p_admin,p_order,p_decision,
    p_provider_transaction,p_received_piastres,p_note);
  select * into o from public.coin_orders where id=p_order;
  select entitlement into grant_code from public.coin_packs where code=o.pack_code;
  if p_decision='approve' and o.status='paid' and grant_code is not null
     and o.user_id is not null then
    token := public.coin_order_token(o.id);
    -- No token hash and no order id: nothing Google's void sync reports can
    -- ever match this row.
    insert into public.play_purchases(purchase_token,user_id,product_id,state,
        purchased_at,granted_at)
      values(token,o.user_id,'web_'||o.pack_code,'active',o.paid_at,now())
      on conflict (purchase_token) do nothing;
    -- Already owned through Play: that purchase keeps the row.
    insert into public.player_entitlements(user_id,item_code,purchase_token)
      values(o.user_id,grant_code,token)
      on conflict (user_id,item_code) do nothing;
  end if;
  return result;
end $$;

alter function public.admin_refund_coin_order(uuid,uuid,text)
  rename to admin_refund_coin_order_base;
create function public.admin_refund_coin_order(p_admin uuid, p_order uuid, p_note text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare result jsonb; token text := public.coin_order_token(p_order);
begin
  result := public.admin_refund_coin_order_base(p_admin,p_order,p_note);
  delete from public.player_entitlements where purchase_token=token;
  update public.play_purchases set state='revoked', reversed_at=coalesce(reversed_at,now())
   where purchase_token=token;
  return result;
end $$;

revoke all on function public.coin_order_token(uuid) from public, anon, authenticated;
grant execute on function public.coin_order_token(uuid) to service_role;
revoke all on function public.coin_shop_base(uuid) from public, anon, authenticated;
grant execute on function public.coin_shop_base(uuid) to service_role;
revoke all on function public.coin_shop(uuid) from public, anon, authenticated;
grant execute on function public.coin_shop(uuid) to service_role;
revoke all on function public.create_coin_order_base(uuid,text,text) from public, anon, authenticated;
grant execute on function public.create_coin_order_base(uuid,text,text) to service_role;
revoke all on function public.create_coin_order(uuid,text,text) from public, anon, authenticated;
grant execute on function public.create_coin_order(uuid,text,text) to service_role;
revoke all on function public.admin_review_coin_order_base(uuid,uuid,text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_review_coin_order_base(uuid,uuid,text,text,bigint,text) to service_role;
revoke all on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) to service_role;
revoke all on function public.admin_refund_coin_order_base(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_refund_coin_order_base(uuid,uuid,text) to service_role;
revoke all on function public.admin_refund_coin_order(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_refund_coin_order(uuid,uuid,text) to service_role;
