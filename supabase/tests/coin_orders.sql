-- Contract for 20260924000500_coin_orders (manual review, no gateway). Rolled back.
begin;
do $$
declare
  buyer uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
  anon uuid:=gen_random_uuid(); admin uuid:=gen_random_uuid();
  r jsonb; o1 uuid; o2 uuid; o3 uuid; w public.wallet_accounts;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (buyer,'buyer@example.test',now(),false),(other,'other@example.test',now(),false),
    (anon,null,null,true),(admin,'admin@example.test',now(),false);
  insert into public.commerce_admins(user_id) values(admin);
  update public.coin_packs set price_piastres=5000, active=true where code='coins_500';
  -- 20260927000200 prices and activates every pack; this contract predates it.
  update public.coin_packs set active=false where code='coins_2500';
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(buyer,300,300);

  -- Anonymous (unrecoverable) accounts cannot buy.
  begin perform public.create_coin_order(anon,'coins_500','instapay'); assert false;
  exception when others then assert sqlerrm='ACCOUNT_NOT_RECOVERABLE', sqlerrm; end;
  -- Inactive packs are not for sale.
  begin perform public.create_coin_order(buyer,'coins_2500','instapay'); assert false;
  exception when others then assert sqlerrm='PACK_UNAVAILABLE', sqlerrm; end;

  -- Price comes from the server, and repeated taps resume one order.
  r:=public.create_coin_order(buyer,'coins_500','instapay');
  o1:=(r->'order'->>'id')::uuid;
  assert (r->'order'->>'amountPiastres')::bigint=5000 and (r->'order'->>'coins')::bigint=500;
  r:=public.create_coin_order(buyer,'coins_500','vodafone_cash');
  assert (r->>'resumed')::boolean and (r->'order'->>'id')::uuid=o1;

  -- Returning without paying changes nothing; nor does a claim.
  assert (select balance from public.wallet_accounts where user_id=buyer)=300;
  begin perform public.claim_coin_order(other,o1,'TXN-1234'); assert false;
  exception when others then assert sqlerrm='ORDER_NOT_FOUND', sqlerrm; end;
  r:=public.claim_coin_order(buyer,o1,'TXN-1234','Buyer');
  assert r->>'status'='claimed';
  begin perform public.claim_coin_order(buyer,o1,'TXN-1234'); assert false;
  exception when others then assert sqlerrm='ORDER_NOT_CLAIMABLE', sqlerrm; end;
  assert (select balance from public.wallet_accounts where user_id=buyer)=300;

  -- Only admins review; wrong amounts are never approved.
  begin perform public.admin_review_coin_order(buyer,o1,'approve','T-777',5000,null); assert false;
  exception when others then assert sqlerrm='NOT_ADMIN', sqlerrm; end;
  begin perform public.admin_review_coin_order(admin,o1,'approve','T-777',4000,null); assert false;
  exception when others then assert sqlerrm='AMOUNT_MISMATCH', sqlerrm; end;
  begin perform public.admin_review_coin_order(admin,o1,'approve',null,5000,null); assert false;
  exception when others then assert sqlerrm='TRANSACTION_REQUIRED', sqlerrm; end;

  -- Approval credits exactly once, with a reviewer and time.
  r:=public.admin_review_coin_order(admin,o1,'approve','T-777',5000,null);
  assert r->>'status'='paid';
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.balance=800 and w.purchased_balance=500 and w.lifetime_purchased=500, w::text;
  begin perform public.admin_review_coin_order(admin,o1,'approve','T-778',5000,null); assert false;
  exception when others then assert sqlerrm='ORDER_NOT_REVIEWABLE', sqlerrm; end;
  assert (select count(*) from public.wallet_ledger where source_order=o1 and kind='coin_purchase')=1;
  assert exists(select 1 from public.coin_orders where id=o1 and reviewed_by=admin and reviewed_at is not null);

  -- One transfer cannot fund a second order.
  -- (o1 is vodafone_cash since 20260927000200: resuming records the method tapped.)
  r:=public.create_coin_order(other,'coins_500','vodafone_cash'); o2:=(r->'order'->>'id')::uuid;
  perform public.claim_coin_order(other,o2,'TXN-9999');
  begin perform public.admin_review_coin_order(admin,o2,'approve','T-777',5000,null); assert false;
  exception when others then assert sqlerrm='TRANSFER_ALREADY_USED', sqlerrm; end;
  -- Unmatched: ask the player, visibly.
  r:=public.admin_review_coin_order(admin,o2,'needs_info',null,null,'Reference not found');
  assert r->>'status'='needs_info' and r->>'playerNote'='Reference not found';

  -- Expired orders are kept and can still be claimed and reconciled.
  r:=public.create_coin_order(buyer,'coins_500','instapay'); o3:=(r->'order'->>'id')::uuid;
  update public.coin_orders set expires_at=now()-interval '1 minute' where id=o3;
  perform public.expire_coin_orders(buyer);
  assert (select status from public.coin_orders where id=o3)='expired';
  r:=public.claim_coin_order(buyer,o3,'LATE-555');
  assert r->>'status'='claimed';
  perform public.admin_review_coin_order(admin,o3,'approve','T-900',5000,null);

  -- Spend everything, then a refund: earned coins are untouched; the part
  -- already spent becomes a debt against future purchases only.
  perform public.buy_reward_item(buyer,'narrator_storyteller'); -- 1200 of 1300
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.balance=100 and w.purchased_balance=0, w::text;
  r:=public.admin_refund_coin_order(admin,o1,'Money returned');
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.balance=100 and w.purchase_debt=500, w::text;
  assert r->>'status'='refunded';
  begin perform public.admin_refund_coin_order(admin,o1,'again'); assert false;
  exception when others then assert sqlerrm='ORDER_NOT_REFUNDABLE', sqlerrm; end;

  -- The next purchase pays the debt first.
  r:=public.create_coin_order(buyer,'coins_500','instapay');
  perform public.claim_coin_order(buyer,(r->'order'->>'id')::uuid,'TXN-NEXT');
  perform public.admin_review_coin_order(admin,(r->'order'->>'id')::uuid,'approve','T-1000',5000,null);
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.balance=100 and w.purchase_debt=0, w::text;

  -- Cross-user reads: a player sees only their own orders.
  assert not (public.coin_shop(other)->'orders') @> jsonb_build_array(jsonb_build_object('id',o1));
  assert not has_function_privilege('authenticated','public.admin_review_coin_order(uuid,uuid,text,text,bigint,text)','execute');
  assert not has_table_privilege('authenticated','public.coin_orders','select');
end $$;
rollback;
