begin;
do $$
declare u uuid:=gen_random_uuid(); tag text; t public.table_tools; credited bigint;
  w public.wallet_accounts; n int; price bigint;
begin
  insert into auth.users(id) values(u);
  tag:=public.account_tag(u);
  -- An item owned before the pack is never touched.
  insert into public.player_inventory(user_id,item_code) values(u,'pack_old_town');

  perform public.commit_play_product(u,'refund-token-0001','mm_coins_500','GPA.R1','active',now(),1,tag);
  select p.credited into credited from public.play_purchases p where purchase_token='refund-token-0001';
  assert credited>0, 'pack credited';

  -- Spend the pack: one cosmetic and a tool pack, the rest stays unspent.
  select * into t from public.table_tools where active order by coin_price limit 1;
  price:=public.tool_pack_price(t.coin_price,1);
  update public.wallet_accounts set balance=balance-100, purchased_balance=purchased_balance-100
   where user_id=u;
  insert into public.wallet_ledger(user_id,kind,amount,item_code,created_at)
    values(u,'catalog_spend',-100,'pack_midnight_manor',now()+interval '1 second');
  insert into public.player_inventory(user_id,item_code) values(u,'pack_midnight_manor');
  update public.wallet_accounts set balance=balance+price, purchased_balance=purchased_balance+price
   where user_id=u and balance<price;
  perform public.buy_table_tool(u,t.code,1);

  n:=public.revoke_voided_play_purchases(null,array['GPA.R1']);
  assert n=1, n::text;
  select * into w from public.wallet_accounts where user_id=u;
  assert not exists(select 1 from public.player_inventory where user_id=u and item_code='pack_midnight_manor'),
    'item bought with the refunded coins is taken back';
  assert exists(select 1 from public.player_inventory where user_id=u and item_code='pack_old_town'),
    'older item kept';
  assert coalesce((select charges from public.player_tool_charges where user_id=u and tool_code=t.code),0)=0,
    'unused tool charge taken back';
  assert w.purchase_debt=0, 'covered by the items, no debt: '||w.purchase_debt;
  assert (select count(*) from public.play_refund_revocations)>=2;
  -- Idempotent.
  assert public.revoke_voided_play_purchases(null,array['GPA.R1'])=0;
  assert not has_function_privilege('authenticated','public.revoke_items_bought_since(uuid,timestamptz,bigint,text)','execute');
end $$;
rollback;
