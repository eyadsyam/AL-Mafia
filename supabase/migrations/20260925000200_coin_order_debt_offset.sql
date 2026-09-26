-- Manual coin orders: a refund restores the purchase debt the order had paid
-- off. Additive; 20260924000500 is left as it was applied.
--
-- The defect: approval stores `credited` net of any debt it offset, and the
-- refund only returned `credited - taken` to the debt. An order that went
-- entirely to an earlier debt (credited 0) could then be refunded and the
-- debt vanished: A 500 bought, spent, refunded → debt 500; B 500 approved →
-- credited 0, debt 0; B refunded → debt stayed 0. With this change B's refund
-- puts its 500 back (debt 500) — the money for both orders went back, and
-- the 500 coins spent from A remain owed. Conservation, not a double charge.

alter table public.coin_orders
  add column if not exists debt_offset bigint not null default 0 check (debt_offset >= 0);

-- Past approvals: whatever of the order's coins was not credited went to debt.
update public.coin_orders set debt_offset = coins - credited
 where status in ('paid','refunded') and credited <= coins and debt_offset = 0;

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
      insert into public.wallet_ledger(user_id,kind,amount,source_order)
        values(o.user_id,'coin_purchase',credit,o.id);
    end if;
    update public.coin_orders set status='paid', received_piastres=p_received_piastres,
      reviewed_by=p_admin, reviewed_at=now(), paid_at=now(), credited=credit,
      debt_offset=offset_debt, player_note=null
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

create or replace function public.admin_refund_coin_order(p_admin uuid, p_order uuid, p_note text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare o public.coin_orders; w public.wallet_accounts; taken bigint := 0;
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
    -- Unspent purchased coins leave; what was spent, plus the debt this order
    -- had paid off, is owed again against future purchased coins only.
    update public.wallet_accounts set balance=balance-taken,
      purchased_balance=purchased_balance-taken,
      purchase_debt=purchase_debt+o.debt_offset+(o.credited-taken), updated_at=now()
     where user_id=o.user_id;
    if taken > 0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_order)
        values(o.user_id,'coin_purchase_reversal',-taken,o.id);
    end if;
  end if;
  update public.coin_orders set status='refunded', refunded_at=now(),
    player_note=left(btrim(p_note),300) where id=o.id returning * into o;
  perform public.log_coin_order(o.id,'admin',p_admin,'refunded',
    jsonb_build_object('taken',taken,'debtRestored',o.debt_offset));
  return public.coin_order_json(o);
end $$;

revoke all on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_review_coin_order(uuid,uuid,text,text,bigint,text) to service_role;
revoke all on function public.admin_refund_coin_order(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.admin_refund_coin_order(uuid,uuid,text) to service_role;
