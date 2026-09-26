-- Contract for 20260925000200_coin_order_debt_offset. Rolled back.
-- A bought, spent, refunded → debt 500; B approved entirely against that debt;
-- B refunded → debt back to 500 (not 0, not 1000); balance unchanged.
begin;
do $$
declare buyer uuid:=gen_random_uuid(); admin uuid:=gen_random_uuid();
  r jsonb; a uuid; b uuid; w public.wallet_accounts;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (buyer,'debt@example.test',now(),false),(admin,'admin2@example.test',now(),false);
  insert into public.commerce_admins(user_id) values(admin);
  update public.coin_packs set price_piastres=5000, active=true where code='coins_500';
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(buyer,300,300);

  r:=public.create_coin_order(buyer,'coins_500','instapay'); a:=(r->'order'->>'id')::uuid;
  perform public.claim_coin_order(buyer,a,'TXN-A-1');
  perform public.admin_review_coin_order(admin,a,'approve','T-A1',5000,null);
  perform public.buy_reward_item(buyer,'pack_midnight_manor'); -- 600: all 500 purchased + 100 earned
  perform public.admin_refund_coin_order(admin,a,'returned');
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.purchase_debt=500 and w.balance=200, w::text;

  r:=public.create_coin_order(buyer,'coins_500','instapay'); b:=(r->'order'->>'id')::uuid;
  perform public.claim_coin_order(buyer,b,'TXN-B-1');
  perform public.admin_review_coin_order(admin,b,'approve','T-B1',5000,null);
  assert (select credited from public.coin_orders where id=b)=0;
  assert (select debt_offset from public.coin_orders where id=b)=500;
  assert (select purchase_debt from public.wallet_accounts where user_id=buyer)=0;

  perform public.admin_refund_coin_order(admin,b,'returned');
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.purchase_debt=500 and w.balance=200, 'debt restored to 500, balance conserved: '||w::text;
end $$;
rollback;
