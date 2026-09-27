-- Contract for 20260927000200_payments_v2 (manual transfers on Android and web,
-- proof screenshots, admin review). Rolled back.
--
-- Every gate runs in its own subtransaction and is rolled back on exit, so a
-- failing gate never masks or feeds the next. Failures are collected and
-- reported together; the gate count is checked at the end.
begin;

create temp table pv_results(gate text primary key, ok boolean not null, detail text);
create function pg_temp.pv_record(p_gate text, p_err text) returns void
language sql as $$
  insert into pv_results values(p_gate, p_err='GATE_OK', nullif(p_err,'GATE_OK'))
$$;
create function pg_temp.pv_user(p_email text default null) returns uuid
language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u, coalesce(p_email, u::text||'@example.test'), now(), false);
  return u;
end $$;
create function pg_temp.pv_sha(p_seed text) returns text language sql as $$
  select md5(p_seed)||md5(p_seed||'#')
$$;
create function pg_temp.pv_on(p_android boolean, p_web boolean) returns void
language plpgsql as $$
begin
  insert into public.economy_config(id) values(true) on conflict do nothing;
  update public.economy_config set transfer_enabled_android=p_android, transfer_enabled_web=p_web;
end $$;
-- Create and submit proof; returns the order id.
create function pg_temp.pv_order(p_user uuid, p_pack text, p_seed text) returns uuid
language plpgsql as $$
declare o uuid;
begin
  o := (public.create_coin_order_v2(p_user,p_pack,'instapay','android')->'order'->>'id')::uuid;
  perform public.submit_coin_order_proof(p_user,o,'Eyad Sender',
    p_user::text||'/'||o::text||'/'||p_seed||'.jpg', pg_temp.pv_sha(p_seed),'android');
  return o;
end $$;

do $$
declare u uuid; v uuid; admin uuid; o uuid; o2 uuid; r jsonb; s jsonb; w public.wallet_accounts;
begin
  -- P1 price table ----------------------------------------------------------
  begin
    assert (select price_piastres from coin_packs where play_product='mm_coins_500')=4999, 'coins_500';
    assert (select price_piastres from coin_packs where play_product='mm_coins_1200')=9999, 'coins_1200';
    assert (select price_piastres from coin_packs where play_product='mm_coins_2500')=18000, 'coins_2500';
    assert (select price_piastres from coin_packs where play_product='mm_remove_interruptions')=19999, 'pass';
    assert (select price_piastres from coin_packs where play_product='mm_starter_bundle')=2999, 'bundle';
    assert (select item_code from coin_packs where code='starter_bundle')='frame_council_seal', 'bundle item';
    assert (select coins from coin_packs where code='starter_bundle')
      =(select coins from play_products where product_id='mm_starter_bundle'), 'bundle coins = Play';
    -- Changeable without a release: the server price is what an order charges.
    u := pg_temp.pv_user(); perform pg_temp.pv_on(true,false);
    update coin_packs set price_piastres=5555 where code='coins_500';
    r := public.create_coin_order_v2(u,'coins_500','instapay','android');
    assert (r->'order'->>'amountPiastres')::int=5555, r::text;
    s := public.coin_shop_v2(u,'android');
    assert exists(select 1 from jsonb_array_elements(s->'packs') p
      where p->>'code'='coins_500' and (p->>'pricePiastres')::int=5555
        and p->>'playProduct'='mm_coins_500'), s::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P1 price table', sqlerrm);
  end;

  -- P2 kill switch, per platform, default off --------------------------------
  begin
    assert not public.transfer_enabled('android') and not public.transfer_enabled('web'), 'default on';
    u := pg_temp.pv_user();
    assert (public.coin_shop_v2(u,'android')->>'enabled')::boolean = false, 'shop enabled';
    begin perform public.create_coin_order_v2(u,'coins_500','instapay','android'); assert false, 'sold while off';
    exception when others then assert sqlerrm='SALES_DISABLED', sqlerrm; end;
    perform pg_temp.pv_on(true,false);
    assert (public.coin_shop_v2(u,'android')->>'enabled')::boolean, 'android off';
    assert not (public.coin_shop_v2(u,'web')->>'enabled')::boolean, 'web on';
    begin perform public.create_coin_order_v2(u,'coins_500','instapay','web'); assert false, 'web sold';
    exception when others then assert sqlerrm='SALES_DISABLED', sqlerrm; end;
    begin perform public.create_coin_order_v2(u,'coins_500','instapay','ios'); assert false, 'ios sold';
    exception when others then assert sqlerrm='SALES_DISABLED', sqlerrm; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P2 kill switch', sqlerrm);
  end;

  -- P3 at most two pending orders --------------------------------------------
  begin
    perform pg_temp.pv_on(true,true); u := pg_temp.pv_user();
    o := (public.create_coin_order_v2(u,'coins_500','instapay','android')->'order'->>'id')::uuid;
    r := public.create_coin_order_v2(u,'coins_500','vodafone_cash','android');
    assert (r->>'resumed')::boolean and (r->'order'->>'id')::uuid=o and r->'order'->>'method'='vodafone_cash', r::text;
    perform public.create_coin_order_v2(u,'coins_1200','instapay','web');
    begin perform public.create_coin_order_v2(u,'coins_2500','instapay','android'); assert false, 'third';
    exception when others then assert sqlerrm='TOO_MANY_PENDING', sqlerrm; end;
    assert (public.coin_shop_v2(u,'android')->>'pending')::int=2, 'pending count';
    -- Submitted proofs still count.
    perform public.submit_coin_order_proof(u,o,'Sender',u::text||'/x.jpg',pg_temp.pv_sha('p3'),'android');
    begin perform public.create_coin_order_v2(u,'coins_2500','instapay','android'); assert false, 'third after proof';
    exception when others then assert sqlerrm='TOO_MANY_PENDING', sqlerrm; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P3 max pending', sqlerrm);
  end;

  -- P4 72 h expiry of orders without proof; proof keeps an order pending ----
  begin
    perform pg_temp.pv_on(true,true); u := pg_temp.pv_user();
    -- With proof (claimed): past its window it still waits for the review.
    o := pg_temp.pv_order(u,'coins_500','p4');
    assert (select expires_at from coin_orders where id=o) between now()+interval '71 hours' and now()+interval '73 hours', 'window';
    update coin_orders set expires_at=now()-interval '1 minute' where id=o;
    perform public.expire_coin_orders(null);
    assert (select status from coin_orders where id=o)='claimed', 'claimed order expired';
    -- needs_info (proof in, the owner asked a question): stays pending too.
    update coin_orders set status='needs_info' where id=o;
    perform public.expire_coin_orders(u);
    assert (select status from coin_orders where id=o)='needs_info', 'needs_info order expired';
    assert not exists(select 1 from coin_order_events where order_id=o and action='expired'), 'proof order logged expired';
    -- No proof (awaiting_transfer): expires after 72 h.
    o2 := (public.create_coin_order_v2(u,'coins_1200','instapay','android')->'order'->>'id')::uuid;
    assert (public.coin_shop_v2(u,'android')->>'pending')::int=2, 'pending before';
    update coin_orders set expires_at=now()-interval '1 minute' where id=o2;
    perform public.expire_coin_orders(null);
    assert (select status from coin_orders where id=o2)='expired', 'not expired';
    assert (public.coin_shop_v2(u,'android')->>'pending')::int=1, 'still pending';
    assert exists(select 1 from coin_order_events where order_id=o2 and action='expired'), 'no event';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P4 expiry', sqlerrm);
  end;

  -- P5 one screenshot, one order, across all orders and players ---------------
  begin
    perform pg_temp.pv_on(true,true); u := pg_temp.pv_user(); v := pg_temp.pv_user();
    o := pg_temp.pv_order(u,'coins_500','same-image');
    o2 := (public.create_coin_order_v2(v,'coins_500','instapay','android')->'order'->>'id')::uuid;
    begin perform public.submit_coin_order_proof(v,o2,'Other',v::text||'/y.jpg',pg_temp.pv_sha('same-image'),'android');
      assert false, 'duplicate accepted';
    exception when others then assert sqlerrm='DUPLICATE_PROOF', sqlerrm; end;
    -- Proof is required: sender name and hash, and the path is the player's own.
    begin perform public.submit_coin_order_proof(v,o2,' ',v::text||'/y.jpg',pg_temp.pv_sha('n'),'android'); assert false;
    exception when others then assert sqlerrm='SENDER_REQUIRED', sqlerrm; end;
    begin perform public.submit_coin_order_proof(v,o2,'Name',v::text||'/y.jpg','nothex','android'); assert false;
    exception when others then assert sqlerrm='PROOF_REQUIRED', sqlerrm; end;
    begin perform public.submit_coin_order_proof(v,o2,'Name',u::text||'/y.jpg',pg_temp.pv_sha('n2'),'android'); assert false;
    exception when others then assert sqlerrm='PROOF_REQUIRED', sqlerrm; end;
    begin perform public.submit_coin_order_proof(u,o2,'Name',u::text||'/y.jpg',pg_temp.pv_sha('n3'),'android'); assert false;
    exception when others then assert sqlerrm='ORDER_NOT_FOUND', sqlerrm; end;
    -- A rejected order's image stays spent.
    admin := pg_temp.pv_user(); insert into commerce_admins(user_id) values(admin);
    perform public.admin_reject_coin_order(admin,o,'Not received');
    begin perform public.submit_coin_order_proof(v,o2,'Other',v::text||'/z.jpg',pg_temp.pv_sha('same-image'),'android');
      assert false, 'rejected image reused';
    exception when others then assert sqlerrm='DUPLICATE_PROOF', sqlerrm; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P5 duplicate image', sqlerrm);
  end;

  -- P6 admin-only review, reasons, credit once ---------------------------------
  begin
    perform pg_temp.pv_on(true,true); u := pg_temp.pv_user(); admin := pg_temp.pv_user();
    insert into commerce_admins(user_id) values(admin);
    insert into wallet_accounts(user_id,balance,lifetime_earned) values(u,100,100);
    o := pg_temp.pv_order(u,'coins_500','p6');
    begin perform public.admin_approve_coin_order(u,o,null); assert false, 'player approved';
    exception when others then assert sqlerrm='NOT_ADMIN', sqlerrm; end;
    begin perform public.admin_coin_orders_v2(u,'pending'); assert false, 'player listed';
    exception when others then assert sqlerrm='NOT_ADMIN', sqlerrm; end;
    begin perform public.admin_reject_coin_order(u,o,'nope'); assert false;
    exception when others then assert sqlerrm='NOT_ADMIN', sqlerrm; end;
    s := public.admin_coin_orders_v2(admin,'pending');
    assert exists(select 1 from jsonb_array_elements(s->'orders') x
      where (x->>'id')::uuid=o and x->>'senderName'='Eyad Sender' and x->>'proofPath' like u::text||'/%'
        and (x->>'amountPiastres')::int=4999), s::text;
    -- A proof is required before approval.
    o2 := (public.create_coin_order_v2(u,'coins_1200','instapay','android')->'order'->>'id')::uuid;
    begin perform public.admin_approve_coin_order(admin,o2,null); assert false;
    exception when others then assert sqlerrm='PROOF_REQUIRED', sqlerrm; end;
    -- Rejection needs a reason, and the player sees it.
    perform public.submit_coin_order_proof(u,o2,'Eyad',u::text||'/r.jpg',pg_temp.pv_sha('p6r'),'android');
    begin perform public.admin_reject_coin_order(admin,o2,' '); assert false;
    exception when others then assert sqlerrm='NOTE_REQUIRED', sqlerrm; end;
    perform public.admin_reject_coin_order(admin,o2,'Amount not received');
    assert exists(select 1 from jsonb_array_elements(public.coin_shop_v2(u,'android')->'orders') x
      where (x->>'id')::uuid=o2 and x->>'status'='rejected' and x->>'playerNote'='Amount not received'), 'reason hidden';
    assert (select balance from wallet_accounts where user_id=u)=100, 'rejection credited';
    -- Approval credits exactly once.
    r := public.admin_approve_coin_order(admin,o,null);
    assert r->>'status'='paid', r::text;
    begin perform public.admin_approve_coin_order(admin,o,null); assert false, 'approved twice';
    exception when others then assert sqlerrm='ORDER_NOT_REVIEWABLE', sqlerrm; end;
    select * into w from wallet_accounts where user_id=u;
    assert w.balance=600 and w.purchased_balance=500, w::text;
    assert (select count(*) from wallet_ledger where source_order=o and kind='coin_purchase')=1, 'ledger rows';
    assert exists(select 1 from jsonb_array_elements(public.admin_coin_orders_v2(admin,'approved')->'orders') x
      where (x->>'id')::uuid=o), 'approved filter';
    assert exists(select 1 from jsonb_array_elements(public.admin_coin_orders_v2(admin,'rejected')->'orders') x
      where (x->>'id')::uuid=o2), 'rejected filter';
    begin perform public.admin_coin_orders_v2(admin,'everything'); assert false;
    exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
    -- Refund keeps the debt rules: spend, refund, debt.
    update wallet_accounts set balance=balance-500, purchased_balance=0 where user_id=u;
    perform public.admin_refund_coin_order(admin,o,'Money returned');
    select * into w from wallet_accounts where user_id=u;
    assert w.balance=100 and w.purchase_debt=500, w::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P6 admin review', sqlerrm);
  end;

  -- P7 Starter Bundle: once per account, same grant as Play --------------------
  begin
    perform pg_temp.pv_on(true,true); u := pg_temp.pv_user(); admin := pg_temp.pv_user();
    insert into commerce_admins(user_id) values(admin);
    update economy_config set starter_bundle_enabled=false;
    assert not exists(select 1 from jsonb_array_elements(public.coin_shop_v2(u,'android')->'packs') p
      where p->>'code'='starter_bundle'), 'bundle offered while off';
    begin perform public.create_coin_order_v2(u,'starter_bundle','instapay','android'); assert false;
    exception when others then assert sqlerrm='PACK_UNAVAILABLE', sqlerrm; end;
    update economy_config set starter_bundle_enabled=true;
    assert exists(select 1 from jsonb_array_elements(public.coin_shop_v2(u,'android')->'packs') p
      where p->>'code'='starter_bundle' and p->>'item'='frame_council_seal'), 'bundle hidden';
    o := pg_temp.pv_order(u,'starter_bundle','p7');
    -- A second bundle order while one is under review is refused.
    begin perform public.create_coin_order_v2(u,'starter_bundle','instapay','android'); assert false, 'second pending';
    exception when others then assert sqlerrm='ALREADY_OWNED', sqlerrm; end;
    perform public.admin_approve_coin_order(admin,o,null);
    assert (select balance from wallet_accounts where user_id=u)=600, 'bundle coins';
    assert exists(select 1 from player_inventory where user_id=u and item_code='frame_council_seal'), 'no frame';
    assert public.owns_starter_bundle(u), 'not owned';
    assert (public.economy_capabilities(u)->'council'->>'starterBundleOwned')::boolean, 'Play still offers it';
    assert not exists(select 1 from jsonb_array_elements(public.coin_shop_v2(u,'android')->'packs') p
      where p->>'code'='starter_bundle'), 'still offered';
    begin perform public.create_coin_order_v2(u,'starter_bundle','instapay','android'); assert false, 'twice';
    exception when others then assert sqlerrm='ALREADY_OWNED', sqlerrm; end;
    -- Owned through Play meanwhile: an approval is refused.
    v := pg_temp.pv_user();
    o2 := pg_temp.pv_order(v,'starter_bundle','p7b');
    insert into play_purchases(purchase_token,user_id,product_id,state,granted_at)
      values('play-token-p7b',v,'mm_starter_bundle','active',now());
    begin perform public.admin_approve_coin_order(admin,o2,null); assert false, 'double bundle';
    exception when others then assert sqlerrm='ALREADY_OWNED', sqlerrm; end;
    -- A refund takes the frame back.
    perform public.admin_refund_coin_order(admin,o,'returned');
    assert not exists(select 1 from player_inventory where user_id=u and item_code='frame_council_seal'), 'frame kept';
    assert not public.owns_starter_bundle(u), 'still owned after refund';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P7 bundle once', sqlerrm);
  end;

  -- P8 Quiet Pass by transfer -------------------------------------------------
  begin
    perform pg_temp.pv_on(true,true); u := pg_temp.pv_user(); admin := pg_temp.pv_user();
    insert into commerce_admins(user_id) values(admin);
    o := pg_temp.pv_order(u,'quiet_pass','p8');
    assert not public.user_owns_entitlement(u,'remove_interruptions'), 'granted on proof';
    perform public.admin_approve_coin_order(admin,o,null);
    assert public.user_owns_entitlement(u,'remove_interruptions'), 'not granted';
    assert (public.economy_capabilities(u)->>'adFree')::boolean, 'app not ad-free';
    begin perform public.create_coin_order_v2(u,'quiet_pass','instapay','android'); assert false;
    exception when others then assert sqlerrm='ALREADY_OWNED', sqlerrm; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P8 quiet pass', sqlerrm);
  end;

  -- P9 retention: images leave 90 days after settling; hashes stay ------------
  begin
    perform pg_temp.pv_on(true,true); u := pg_temp.pv_user(); v := pg_temp.pv_user(); admin := pg_temp.pv_user();
    insert into commerce_admins(user_id) values(admin);
    o := pg_temp.pv_order(u,'coins_500','p9');
    o2 := pg_temp.pv_order(v,'coins_500','p9b');
    perform public.admin_reject_coin_order(admin,o,'Not received');
    assert not exists(select 1 from public.payment_proofs_due(500) d where d.order_id=o), 'due too early';
    update coin_orders set reviewed_at=now()-interval '91 days' where id=o;
    assert exists(select 1 from public.payment_proofs_due(500) d where d.order_id=o), 'not due';
    assert not exists(select 1 from public.payment_proofs_due(500) d where d.order_id=o2), 'pending purged';
    -- A deleted account: detached, sender name gone, image due at once.
    update coin_orders set user_id=null where id=o2;
    assert (select sender_name from coin_orders where id=o2) is null, 'sender kept';
    assert exists(select 1 from public.payment_proofs_due(500) d where d.order_id=o2), 'detached not due';
    assert public.mark_payment_proofs_purged(array(select path from public.payment_proofs_due(500)))>=2, 'marked';
    assert (select proof_path is null and proof_purged_at is not null and proof_sha256 is not null
      from coin_orders where id=o), 'purge state';
    assert not exists(select 1 from public.payment_proofs_due(500) d where d.order_id in (o,o2)), 'due twice';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P9 proof retention', sqlerrm);
  end;

  -- P10 surface and owner seed ------------------------------------------------
  begin
    assert not has_function_privilege('authenticated','public.submit_coin_order_proof(uuid,uuid,text,text,text,text)','execute'), 'submit';
    assert not has_function_privilege('authenticated','public.admin_approve_coin_order(uuid,uuid,text)','execute'), 'approve';
    assert not has_function_privilege('anon','public.admin_coin_orders_v2(uuid,text)','execute'), 'list';
    assert not has_function_privilege('authenticated','public.payment_proofs_due(integer)','execute'), 'due';
    assert not has_function_privilege('authenticated','public.transfer_enabled(text)','execute'), 'switch';
    assert has_function_privilege('service_role','public.create_coin_order_v2(uuid,text,text,text)','execute'), 'service';
    assert not has_table_privilege('authenticated','public.coin_orders','select'), 'orders readable';
    u := pg_temp.pv_user('EyadSyam124@gmail.com');
    insert into public.commerce_admins(user_id,note)
      select id,'owner' from auth.users
       where lower(email)='eyadsyam124@gmail.com' and coalesce(is_anonymous,false)=false
    on conflict (user_id) do nothing;
    insert into public.commerce_admins(user_id,note)
      select id,'owner' from auth.users
       where lower(email)='eyadsyam124@gmail.com' and coalesce(is_anonymous,false)=false
    on conflict (user_id) do nothing;
    assert public.is_commerce_admin(u), 'owner not seeded';
    assert (select count(*) from commerce_admins where user_id=u)=1, 'seeded twice';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P10 surface and owner seed', sqlerrm);
  end;

  -- P11 cheap precheck before the image is stored ------------------------------
  begin
    perform pg_temp.pv_on(true,false); u := pg_temp.pv_user(); v := pg_temp.pv_user();
    o := (public.create_coin_order_v2(u,'coins_500','instapay','android')->'order'->>'id')::uuid;
    perform public.coin_order_proof_precheck(u,o,'android');
    begin perform public.coin_order_proof_precheck(u,o,'web'); assert false, 'web switch off';
    exception when others then assert sqlerrm='SALES_DISABLED', sqlerrm; end;
    begin perform public.coin_order_proof_precheck(v,o,'android'); assert false, 'not the owner';
    exception when others then assert sqlerrm='ORDER_NOT_FOUND', sqlerrm; end;
    perform public.submit_coin_order_proof(u,o,'Eyad',u::text||'/pre.jpg',pg_temp.pv_sha('p11'),'android');
    begin perform public.coin_order_proof_precheck(u,o,'android'); assert false, 'claimed again';
    exception when others then assert sqlerrm='ORDER_NOT_CLAIMABLE', sqlerrm; end;
    -- Nothing changed by asking.
    assert (select status from coin_orders where id=o)='claimed', 'precheck wrote';
    assert not has_function_privilege('authenticated','public.coin_order_proof_precheck(uuid,uuid,text)','execute'), 'precheck exposed';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.pv_record('P11 proof precheck', sqlerrm);
  end;
end $$;

do $$
declare failed text;
begin
  select string_agg(gate||' => '||detail, ' | ' order by gate) into failed
    from pv_results where not ok;
  if (select count(*) from pv_results) <> 11 then
    raise exception 'PAYMENTS V2 GATES INCOMPLETE: % recorded', (select count(*) from pv_results);
  end if;
  if failed is not null then raise exception 'PAYMENTS V2 GATES FAILED: %', failed; end if;
end $$;
rollback;
