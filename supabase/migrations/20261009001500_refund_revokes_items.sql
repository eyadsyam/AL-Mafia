-- A refunded or charged-back coin pack used to take back only the coins still
-- unspent; whatever had been bought with the rest stayed and the gap became
-- debt. Now the spent part is covered first by taking back what those coins
-- bought after the pack was granted (newest first: cosmetics, roles, unused
-- table tool charges); only what cannot be covered stays as debt. Earned
-- coins, items bought before the pack and charges already used are never
-- touched. When a taken-back item was paid partly with earned coins, that
-- earned part comes back to the wallet. Owner decision 2026-10-09.

create table if not exists public.play_refund_revocations(
  ledger_id uuid primary key references public.wallet_ledger(id),
  purchase_token_hash text not null,
  covered bigint not null,
  revoked_at timestamptz not null default now()
);
alter table public.play_refund_revocations enable row level security;
revoke all on public.play_refund_revocations from public, anon, authenticated;

-- Takes back items bought since p_since until p_need coins are covered.
-- Caller holds the wallet lock. Returns the coins covered.
create or replace function public.revoke_items_bought_since(
  p_user uuid, p_since timestamptz, p_need bigint, p_hash text
) returns bigint language plpgsql security definer set search_path=public,pg_temp as $$
declare spend record; covered bigint := 0; paid bigint; pack int; have int; t public.table_tools;
begin
  if p_need is null or p_need <= 0 then return 0; end if;
  for spend in
    select l.* from public.wallet_ledger l
     where l.user_id=p_user and l.kind in ('catalog_spend','tool_spend')
       and l.amount<0 and l.created_at>=p_since
       and not exists(select 1 from public.play_refund_revocations r where r.ledger_id=l.id)
     order by l.created_at desc, l.id desc
  loop
    exit when covered >= p_need;
    paid := -spend.amount;
    if spend.kind='catalog_spend' then
      delete from public.player_inventory where user_id=p_user and item_code=spend.item_code;
      if not found then continue; end if;
    else
      select * into t from public.table_tools where code=spend.item_code;
      pack := case
        when t.code is null then null
        when public.tool_pack_price(t.coin_price,1)=paid then 1
        when public.tool_pack_price(t.coin_price,3)=paid then 3
        when public.tool_pack_price(t.coin_price,7)=paid then 7 end;
      select charges into have from public.player_tool_charges
       where user_id=p_user and tool_code=spend.item_code for update;
      if pack is null or coalesce(have,0)=0 then continue; end if;
      -- Charges already used are gone; cover only the unused share.
      paid := paid * least(have,pack) / pack;
      update public.player_tool_charges set charges=charges-least(have,pack), updated_at=now()
       where user_id=p_user and tool_code=spend.item_code;
    end if;
    insert into public.play_refund_revocations(ledger_id,purchase_token_hash,covered)
      values(spend.id,p_hash,paid);
    covered := covered + paid;
  end loop;
  return covered;
end $$;
revoke all on function public.revoke_items_bought_since(uuid,timestamptz,bigint,text) from public, anon, authenticated;
grant execute on function public.revoke_items_bought_since(uuid,timestamptz,bigint,text) to service_role;

create or replace function public.reverse_play_coins(p_token text)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare hit public.play_purchases; w public.wallet_accounts; taken bigint := 0; covered bigint := 0;
  giveback bigint := 0;
begin
  select * into hit from public.play_purchases where purchase_token=p_token;
  if hit.purchase_token is null or hit.granted_at is null or hit.reversed_at is not null then
    return false;
  end if;
  if hit.user_id is not null then
    select * into w from public.wallet_accounts where user_id=hit.user_id for update;
    taken := least(coalesce(w.purchased_balance,0), hit.credited);
    covered := public.revoke_items_bought_since(hit.user_id, hit.granted_at,
      hit.credited-taken, hit.token_hash);
    giveback := greatest(0, covered-(hit.credited-taken));
    update public.wallet_accounts set balance=balance-taken+giveback,
      purchased_balance=purchased_balance-taken,
      purchase_debt=purchase_debt+hit.debt_offset+greatest(0,hit.credited-taken-covered),
      updated_at=now()
     where user_id=hit.user_id;
    if taken > 0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_key)
        values(hit.user_id,'play_coin_reversal',-taken,hit.token_hash)
        on conflict do nothing;
    end if;
    if giveback > 0 then
      insert into public.wallet_ledger(user_id,kind,amount,source_key)
        values(hit.user_id,'play_coin_reversal',giveback,hit.token_hash||':earned_back')
        on conflict do nothing;
    end if;
  end if;
  update public.play_purchases set reversed_at=now(), state='revoked'
   where purchase_token=p_token;
  return true;
end $$;
revoke all on function public.reverse_play_coins(text) from public, anon, authenticated;
grant execute on function public.reverse_play_coins(text) to service_role;
