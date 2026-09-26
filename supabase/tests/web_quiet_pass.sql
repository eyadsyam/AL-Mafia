-- Contract for 20260925000400_web_quiet_pass. Rolled back.
-- The web Quiet Pass: ordered like a coin pack, granted only by an approval,
-- carried to Android by the account, removed by a refund, never sold twice,
-- and coin packs unchanged.
begin;
do $$
declare buyer uuid:=gen_random_uuid(); admin uuid:=gen_random_uuid(); anon_user uuid:=gen_random_uuid();
  r jsonb; o uuid; c uuid; w public.wallet_accounts; s jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (buyer,'pass@example.test',now(),false),(admin,'admin-pass@example.test',now(),false),
    (anon_user,null,null,true);
  insert into public.commerce_admins(user_id) values(admin);
  insert into public.wallet_accounts(user_id,balance,lifetime_earned) values(buyer,300,300);
  -- 20260927000200 prices the pass; this contract starts from the 000400 seed.
  update public.coin_packs set active=false, price_piastres=null where code='quiet_pass';

  -- Seeded inactive and unpriced: nothing is sold until an operator prices it.
  assert not exists(select 1 from jsonb_array_elements(public.coin_shop(buyer)->'packs') p where p->>'code'='quiet_pass');
  begin perform public.create_coin_order(buyer,'quiet_pass','instapay'); assert false;
  exception when others then assert sqlerrm='PACK_UNAVAILABLE', sqlerrm; end;
  -- A pack grants coins or an entitlement, never neither or both.
  begin insert into public.coin_packs(code,coins) values('bad_pack',0); assert false;
  exception when check_violation then null; end;
  begin insert into public.coin_packs(code,coins,entitlement) values('bad_pass',10,'remove_interruptions'); assert false;
  exception when check_violation then null; end;

  update public.coin_packs set price_piastres=15000, active=true where code='quiet_pass';
  s := public.coin_shop(buyer);
  assert exists(select 1 from jsonb_array_elements(s->'packs') p
    where p->>'code'='quiet_pass' and p->>'entitlement'='remove_interruptions'
      and (p->>'coins')::int=0 and (p->>'pricePiastres')::int=15000), s::text;
  assert s->'adFree'='false'::jsonb;
  -- Recoverable accounts only, as for coins.
  begin perform public.create_coin_order(anon_user,'quiet_pass','instapay'); assert false;
  exception when others then assert sqlerrm='ACCOUNT_NOT_RECOVERABLE', sqlerrm; end;

  r := public.create_coin_order(buyer,'quiet_pass','vodafone_cash'); o := (r->'order'->>'id')::uuid;
  assert (r->'order'->>'coins')::int=0 and (r->'order'->>'amountPiastres')::int=15000, r::text;
  perform public.claim_coin_order(buyer,o,'VF-PASS-1');
  -- The claim alone grants nothing.
  assert not public.user_owns_entitlement(buyer,'remove_interruptions'), 'granted on claim';
  begin perform public.admin_review_coin_order(admin,o,'approve','T-P1',14000,null); assert false;
  exception when others then assert sqlerrm='AMOUNT_MISMATCH', sqlerrm; end;
  perform public.admin_review_coin_order(admin,o,'approve','T-P1',15000,null);
  assert public.user_owns_entitlement(buyer,'remove_interruptions'), 'not granted on approval';
  -- The Android app reads the same answer.
  assert (public.economy_capabilities(buyer)->>'adFree')::boolean, 'not carried to the app';
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.balance=300 and w.purchased_balance=0 and w.purchase_debt=0, 'coins moved: '||w::text;
  assert (public.coin_shop(buyer)->>'adFree')::boolean;
  -- Not sold twice; a coin pack still is.
  begin perform public.create_coin_order(buyer,'quiet_pass','instapay'); assert false;
  exception when others then assert sqlerrm='ALREADY_OWNED', sqlerrm; end;
  -- Google's void sync never touches a web order.
  perform public.revoke_voided_play_purchases(array[public.coin_order_token(o)], null);
  perform public.revoke_voided_play_purchases(null, array[(select reference from coin_orders where id=o)]);
  assert public.user_owns_entitlement(buyer,'remove_interruptions'), 'void sync removed a web pass';
  -- A refund removes it, and only it; the wallet is untouched.
  perform public.admin_refund_coin_order(admin,o,'returned');
  assert not public.user_owns_entitlement(buyer,'remove_interruptions'), 'kept after refund';
  select * into w from public.wallet_accounts where user_id=buyer;
  assert w.balance=300 and w.purchase_debt=0, 'refund moved coins: '||w::text;
  assert (select state from play_purchases where purchase_token=public.coin_order_token(o))='revoked';

  -- Coin packs behave exactly as before.
  update public.coin_packs set price_piastres=5000, active=true where code='coins_500';
  r := public.create_coin_order(buyer,'coins_500','instapay'); c := (r->'order'->>'id')::uuid;
  perform public.claim_coin_order(buyer,c,'IP-COIN-1');
  perform public.admin_review_coin_order(admin,c,'approve','T-C1',5000,null);
  assert (select balance from wallet_accounts where user_id=buyer)=800, 'coins not credited';
  assert not public.user_owns_entitlement(buyer,'remove_interruptions'), 'coins granted the pass';

  -- Already owned through Play: the web approval adds nothing and a web
  -- refund does not take the Play pass away.
  perform public.commit_play_product(buyer,'play-pass-token-web','mm_remove_interruptions','GPA.W1',
    'active',now(),1,public.account_tag(buyer));
  assert public.user_owns_entitlement(buyer,'remove_interruptions');
  begin perform public.create_coin_order(buyer,'quiet_pass','instapay'); assert false;
  exception when others then assert sqlerrm='ALREADY_OWNED', sqlerrm; end;

  -- Client roles reach none of it.
  assert not has_function_privilege('authenticated','public.create_coin_order(uuid,text,text)','execute');
  assert not has_function_privilege('authenticated','public.coin_shop(uuid)','execute');
  assert not has_function_privilege('anon','public.admin_review_coin_order(uuid,uuid,text,text,bigint,text)','execute');
  assert not has_function_privilege('authenticated','public.admin_refund_coin_order_base(uuid,uuid,text)','execute');
end $$;
rollback;
