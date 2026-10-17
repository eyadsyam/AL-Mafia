-- Keep the refund revoker's coverage order and tool handling; return the
-- components granted by a revoked catalog bundle as well.
create or replace function public.revoke_items_bought_since(
  p_user uuid, p_since timestamptz, p_need bigint, p_hash text
) returns bigint language plpgsql security definer set search_path=public,pg_temp as $$
declare spend record; covered bigint := 0; paid bigint; pack int; have int; t public.table_tools;
  item public.reward_catalog;
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
      select * into item from public.reward_catalog where code=spend.item_code;
      if item.kind='bundle' then
        -- Inventory has one row per item and no grant source. Keep an item
        -- with an older ownership row, another live purchase or owned bundle,
        -- or an active account-wide grant. The equipment FK cascades deletes.
        delete from public.player_inventory i
         where i.user_id=p_user and i.item_code=any(item.contents)
           and i.acquired_at>=spend.created_at
           and not public.has_all_access(p_user)
           and not exists (
             select 1 from public.wallet_ledger l
              where l.user_id=p_user and l.kind='catalog_spend'
                and l.item_code=i.item_code and l.amount<0
                and not exists(select 1 from public.play_refund_revocations r where r.ledger_id=l.id)
           )
           and not exists (
             select 1 from public.player_inventory b
               join public.reward_catalog c on c.code=b.item_code
              where b.user_id=p_user and c.kind='bundle'
                and i.item_code=any(c.contents)
           );
      end if;
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
