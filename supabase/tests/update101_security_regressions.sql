-- Independent adversarial regressions for Update 1.0.1 money paths
-- (docs/UPDATE-1.0.1-SECURITY-REVIEW.md). Rolled back.
--
-- Every gate runs in its own subtransaction and is rolled back on exit, so a
-- failing gate never masks or feeds the next. Failures are collected and
-- reported together at the end.
--
-- Single connection (PGlite): proves logic, idempotency and conservation, NOT
-- hosted lock ordering or deadlock freedom — see the review doc.
begin;

create temp table sec_results(gate text primary key, ok boolean not null, detail text);

-- Fixtures ---------------------------------------------------------------
create function pg_temp.sec_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u, u::text||'@example.test', now(), false);
  return u;
end $$;

-- A finished match `u` played, with a completion reward of exactly p_base.
create function pg_temp.sec_room(p_user uuid, p_code text, p_base bigint) returns uuid
language plpgsql as $$
declare r uuid := gen_random_uuid();
begin
  insert into rooms(id,code,host_id,status,ended_at,match_seed)
    values(r,p_code,p_user,'finished',now(),1);
  insert into room_players(room_id,user_id,seat,name,role,kicked)
    values(r,p_user,0,'S','citizen',false);
  insert into room_state(room_id,phase,phase_number,public_data)
    values(r,'result',1,jsonb_build_object('outcome','town'));
  insert into wallet_accounts(user_id) values(p_user) on conflict do nothing;
  insert into wallet_ledger(user_id,kind,amount,source_room)
    values(p_user,'match_completion',p_base,r);
  update wallet_accounts set balance=balance+p_base, lifetime_earned=lifetime_earned+p_base
   where user_id=p_user;
  return r;
end $$;

create function pg_temp.sec_earned(p_user uuid, p_amount bigint) returns void
language sql as $$
  insert into wallet_accounts(user_id) values(p_user) on conflict do nothing;
  update wallet_accounts set balance=balance+p_amount, lifetime_earned=lifetime_earned+p_amount
   where user_id=p_user;
$$;

-- Spending purchased coins first, as the catalogue does.
create function pg_temp.sec_spend_purchased(p_user uuid, p_amount bigint) returns void
language sql as $$
  update wallet_accounts set balance=balance-p_amount,
    purchased_balance=purchased_balance-p_amount, lifetime_spent=lifetime_spent+p_amount
   where user_id=p_user;
$$;

create function pg_temp.sec_wallet(p_user uuid) returns public.wallet_accounts
language sql as $$ select * from wallet_accounts where user_id=p_user $$;

-- Features ship off (G10); gates that exercise them turn them on explicitly.
create function pg_temp.sec_enable() returns void language sql as $$
  update economy_config set ad_steps_enabled=true, daily_enabled=true,
    daily_ad_enabled=true, interstitial_enabled=true;
$$;

-- Manual coin order: created by p_user, approved by p_admin at the exact price.
create function pg_temp.sec_paid_order(p_admin uuid, p_user uuid, p_pack text, p_tx text)
returns uuid language plpgsql as $$
declare o uuid;
begin
  o := (public.create_coin_order(p_user,p_pack,'instapay')->'order'->>'id')::uuid;
  perform public.admin_review_coin_order(p_admin,o,'approve',p_tx,
    (select amount_piastres from coin_orders where id=o),null);
  return o;
end $$;

create function pg_temp.sec_record(p_gate text, p_err text) returns void
language sql as $$
  insert into sec_results values(p_gate, p_err='GATE_OK', nullif(p_err,'GATE_OK'))
$$;

-- G1. v1/v2 mutual exclusion and cross-scheme replay ---------------------
do $$
declare u uuid; v uuid; ra uuid; rb uuid; rc uuid; s jsonb; legacy jsonb; c1 uuid; d1 uuid;
  bal bigint;
begin
  begin
    perform pg_temp.sec_enable();
    u := pg_temp.sec_user(); v := pg_temp.sec_user();
    ra := pg_temp.sec_room(u,'SECGAA',100); rb := pg_temp.sec_room(u,'SECGAB',100);
    rc := pg_temp.sec_room(v,'SECGAC',100);

    -- v2 first: v1 refused, no v1 row appears.
    s := public.create_ad_step_claim_v2(u,ra,1); c1 := (s->>'claimId')::uuid;
    begin perform public.create_ad_reward_claim(u,ra); assert false, 'v1 after v2 accepted';
    exception when others then assert sqlerrm='REWARD_SCHEME_V2', sqlerrm; end;
    assert not exists(select 1 from ad_reward_claims where user_id=u and room_id=ra), 'v1 row leaked';

    -- v1 first: v2 resumes v1, no step row appears.
    legacy := public.create_ad_reward_claim(u,rb);
    s := public.create_ad_step_claim_v2(u,rb,1);
    assert s->>'scheme'='v1', 'v2 did not defer to v1: '||s::text;
    s := public.create_ad_step_claim_v2(u,rb,2);
    assert s->>'scheme'='v1', 'step 2 did not defer to v1: '||s::text;
    assert not exists(select 1 from ad_step_claims where user_id=u and room_id=rb), 'step row leaked';

    -- Replays: same tx on same claim pays once; one tx never pays two schemes.
    bal := (pg_temp.sec_wallet(u)).balance;
    perform public.commit_ad_step_v2(c1,'sec-g1-step-0001','unit',1,u);
    perform public.commit_ad_step_v2(c1,'sec-g1-step-0001','unit',1,u);
    assert (pg_temp.sec_wallet(u)).balance=bal+100, 'step replay paid twice'; -- step = whole base since phase 110
    begin perform public.commit_ad_reward((legacy->>'claimId')::uuid,'sec-g1-step-0001','unit',1,u);
      assert false, 'step tx paid v1';
    exception when others then assert sqlerrm='TRANSACTION_ALREADY_USED', sqlerrm; end;
    s := public.create_daily_ad_claim(v, public.economy_today()); d1 := (s->>'claimId')::uuid;
    begin perform public.commit_daily_ad(d1,'sec-g1-step-0001','unit',1,v);
      assert false, 'step tx paid daily';
    exception when others then assert sqlerrm='TRANSACTION_ALREADY_USED', sqlerrm; end;
    assert (select state from daily_ad_claims where id=d1)='pending', 'daily moved on refused tx';

    -- Signed user must own the claim (v1, step, daily).
    begin perform public.commit_ad_reward((legacy->>'claimId')::uuid,'sec-g1-v1-00001','unit',1,v);
      assert false, 'v1 paid to wrong ssv user';
    exception when others then assert sqlerrm='CLAIM_NOT_FOUND', sqlerrm; end;
    begin perform public.commit_daily_ad(d1,'sec-g1-daily-001','unit',1,u);
      assert false, 'daily paid to wrong ssv user';
    exception when others then assert sqlerrm='CLAIM_NOT_FOUND', sqlerrm; end;
    s := public.create_ad_step_claim_v2(v,rc,1);
    begin perform public.commit_ad_step_v2((s->>'claimId')::uuid,'sec-g1-step-0002','unit',1,u);
      assert false, 'step paid to wrong ssv user';
    exception when others then assert sqlerrm='CLAIM_NOT_FOUND', sqlerrm; end;
    -- A refused commit leaves the tx unregistered for its rightful claim.
    assert not exists(select 1 from ad_ssv_transactions where transaction_id='sec-g1-step-0002'),
      'refused commit registered its tx';

    -- A v1 claim pays exactly base once, whatever the retries.
    bal := (pg_temp.sec_wallet(u)).balance;
    perform public.commit_ad_reward((legacy->>'claimId')::uuid,'sec-g1-v1-00002','unit',1,u);
    perform public.commit_ad_reward((legacy->>'claimId')::uuid,'sec-g1-v1-00002','unit',1,u);
    assert (pg_temp.sec_wallet(u)).balance=bal+100, 'v1 replay paid twice';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G1 v1/v2 exclusion + replay', sqlerrm);
  end;
end $$;

-- G2. Two steps pay exactly twice the base (x3 total, phase 110), odd bases included -----------------
do $$
declare u uuid; r uuid; s jsonb; bal bigint;
begin
  begin
    perform pg_temp.sec_enable();
    u := pg_temp.sec_user(); r := pg_temp.sec_room(u,'SECGBA',101);
    bal := (pg_temp.sec_wallet(u)).balance;
    s := public.create_ad_step_claim_v2(u,r,1);
    perform public.commit_ad_step_v2((s->>'claimId')::uuid,'sec-g2-step-0001','unit',1,u);
    s := public.create_ad_step_claim_v2(u,r,2);
    perform public.commit_ad_step_v2((s->>'claimId')::uuid,'sec-g2-step-0002','unit',1,u);
    assert (pg_temp.sec_wallet(u)).balance=bal+202, 'steps did not sum to twice the base';
    -- No third payment through a fresh create.
    s := public.create_ad_step_claim_v2(u,r,2);
    assert (select count(*) from ad_step_claims where user_id=u and room_id=r)=2, 'extra claim row';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G2 step amounts conserve base', sqlerrm);
  end;
end $$;

-- G3. Coin refund debt conservation (no punitive doubling) --------------
-- Case A: A500 spent+refunded -> debt 500; B500 fully offsets (credit 0);
-- refund B restores debt 500.
do $$
declare u uuid; tag text; w public.wallet_accounts; s jsonb;
begin
  begin
    u := pg_temp.sec_user(); tag := public.account_tag(u);
    perform pg_temp.sec_earned(u,300);
    perform public.commit_play_product(u,'sec-g3a-token-A','mm_coins_500','GPA.G3A.A','active',now(),1,tag);
    perform pg_temp.sec_spend_purchased(u,500);
    perform public.revoke_voided_play_purchases(array['sec-g3a-token-A'],null);
    w := pg_temp.sec_wallet(u);
    assert w.purchase_debt=500 and w.balance=300 and w.purchased_balance=0, 'after refund A: '||row_to_json(w)::text;
    s := public.commit_play_product(u,'sec-g3a-token-B','mm_coins_500','GPA.G3A.B','active',now(),1,tag);
    w := pg_temp.sec_wallet(u);
    assert (s->>'credited')::bigint=0 and w.purchase_debt=0 and w.balance=300, 'after B: '||row_to_json(w)::text;
    perform public.revoke_voided_play_purchases(array['sec-g3a-token-B'],null);
    w := pg_temp.sec_wallet(u);
    assert w.purchase_debt=500, 'refund of a debt-offsetting purchase must restore the offset: '||row_to_json(w)::text;
    assert w.balance=300 and w.purchased_balance=0, 'earned coins touched: '||row_to_json(w)::text;
    perform public.revoke_voided_play_purchases(array['sec-g3a-token-B'],null);
    assert (pg_temp.sec_wallet(u)).purchase_debt=500, 'second refund changed debt';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G3a refund restores fully-offset debt', sqlerrm);
  end;
end $$;

-- Case B: debt 500, B1200 -> offset 500 credit 700; unspent refund takes 700
-- and restores 500.
do $$
declare u uuid; tag text; w public.wallet_accounts; s jsonb;
begin
  begin
    u := pg_temp.sec_user(); tag := public.account_tag(u);
    perform pg_temp.sec_earned(u,300);
    perform public.commit_play_product(u,'sec-g3b-token-A','mm_coins_500','GPA.G3B.A','active',now(),1,tag);
    perform pg_temp.sec_spend_purchased(u,500);
    perform public.revoke_voided_play_purchases(array['sec-g3b-token-A'],null);
    s := public.commit_play_product(u,'sec-g3b-token-B','mm_coins_1200','GPA.G3B.B','active',now(),1,tag);
    w := pg_temp.sec_wallet(u);
    assert (s->>'credited')::bigint=700 and w.purchase_debt=0 and w.balance=1000
      and w.purchased_balance=700, 'after B: '||row_to_json(w)::text;
    perform public.revoke_voided_play_purchases(array['sec-g3b-token-B'],null);
    w := pg_temp.sec_wallet(u);
    assert w.balance=300 and w.purchased_balance=0, 'unspent credit not taken: '||row_to_json(w)::text;
    assert w.purchase_debt=500, 'offset not restored: '||row_to_json(w)::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G3b mixed refund, credit unspent', sqlerrm);
  end;
end $$;

-- Case C: as B but 100 of the 700 spent: refund takes 600, debt 600.
do $$
declare u uuid; tag text; w public.wallet_accounts;
begin
  begin
    u := pg_temp.sec_user(); tag := public.account_tag(u);
    perform pg_temp.sec_earned(u,300);
    perform public.commit_play_product(u,'sec-g3c-token-A','mm_coins_500','GPA.G3C.A','active',now(),1,tag);
    perform pg_temp.sec_spend_purchased(u,500);
    perform public.revoke_voided_play_purchases(array['sec-g3c-token-A'],null);
    perform public.commit_play_product(u,'sec-g3c-token-B','mm_coins_1200','GPA.G3C.B','active',now(),1,tag);
    perform pg_temp.sec_spend_purchased(u,100);
    perform public.revoke_voided_play_purchases(array['sec-g3c-token-B'],null);
    w := pg_temp.sec_wallet(u);
    assert w.balance=300 and w.purchased_balance=0, 'wrong take-back: '||row_to_json(w)::text;
    assert w.purchase_debt=600, 'expected debt 600: '||row_to_json(w)::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G3c mixed refund, 100 spent', sqlerrm);
  end;
end $$;

-- G4. A void seen before the first verify is never credited later ------
do $$
declare u uuid; tag text; w0 public.wallet_accounts; s jsonb;
begin
  begin
    u := pg_temp.sec_user(); tag := public.account_tag(u);
    perform pg_temp.sec_earned(u,10); w0 := pg_temp.sec_wallet(u);
    perform public.revoke_voided_play_purchases(array['sec-g4-token-void'],array['GPA.G4']);
    begin
      s := public.commit_play_product(u,'sec-g4-token-void','mm_coins_500','GPA.G4','active',now(),1,tag);
    exception when others then s := null; end;
    assert (pg_temp.sec_wallet(u)).balance=w0.balance, 'voided-before-verify token credited';
    assert not exists(select 1 from wallet_ledger where user_id=u and kind='play_coin_purchase'),
      'ledger credit for voided token';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G4 void before first verify', sqlerrm);
  end;
end $$;

-- G5. pending -> voided -> 'active' replay stays revoked (coins + pass) --
do $$
declare u uuid; tag text; w0 public.wallet_accounts; s jsonb;
begin
  begin
    u := pg_temp.sec_user(); tag := public.account_tag(u);
    perform pg_temp.sec_earned(u,10); w0 := pg_temp.sec_wallet(u);
    perform public.commit_play_product(u,'sec-g5-token-coin','mm_coins_500','GPA.G5C','pending',now(),1,tag);
    perform public.revoke_voided_play_purchases(array['sec-g5-token-coin'],null);
    begin
      s := public.commit_play_product(u,'sec-g5-token-coin','mm_coins_500','GPA.G5C','active',now(),1,tag);
    exception when others then s := null; end;
    assert (pg_temp.sec_wallet(u)).balance=w0.balance, 'revoked pending coin token credited on replay';
    assert (select state from play_purchases where purchase_token='sec-g5-token-coin')='revoked',
      'coin token left revoked state';

    perform public.commit_play_product(u,'sec-g5-token-pass','mm_remove_interruptions','GPA.G5P','pending',now(),1,tag);
    perform public.revoke_voided_play_purchases(array['sec-g5-token-pass'],null);
    begin
      s := public.commit_play_product(u,'sec-g5-token-pass','mm_remove_interruptions','GPA.G5P','active',now(),1,tag);
    exception when others then s := null; end;
    assert not public.user_owns_entitlement(u,'remove_interruptions'), 'voided pass re-granted on replay';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G5 pending-revoked-active replay', sqlerrm);
  end;
end $$;

-- G6. Coin packs require the Play account binding -----------------------
do $$
declare u uuid; w0 public.wallet_accounts; s jsonb;
begin
  begin
    u := pg_temp.sec_user(); perform pg_temp.sec_earned(u,10); w0 := pg_temp.sec_wallet(u);
    begin
      s := public.commit_play_product(u,'sec-g6-token-untagged','mm_coins_500','GPA.G6','active',now(),1,null);
    exception when others then s := null; end;
    assert (pg_temp.sec_wallet(u)).balance=w0.balance, 'untagged coin token credited';
    assert s is null or not coalesce((s->>'granted')::boolean,false), 'untagged coin token granted';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G6 null account tag rejected for coins', sqlerrm);
  end;
end $$;

-- G7. Missing configuration fails off -----------------------------------
do $$
declare u uuid; r uuid; s jsonb; bal bigint;
begin
  begin
    u := pg_temp.sec_user(); r := pg_temp.sec_room(u,'SECGGA',100);
    bal := (pg_temp.sec_wallet(u)).balance;
    delete from economy_config;

    begin s := public.economy_capabilities(u); exception when others then s := null; end;
    if s is not null then
      assert coalesce((s->>'adSteps')::boolean,false)=false, 'adSteps on without config';
      assert coalesce((s->>'daily')::boolean,false)=false, 'daily on without config';
      assert coalesce((s->>'dailyAd')::boolean,false)=false, 'dailyAd on without config';
      assert coalesce((s->'interstitial'->>'enabled')::boolean,false)=false, 'interstitial on without config';
    end if;
    begin perform public.create_ad_step_claim_v2(u,r,1); exception when others then null; end;
    assert not exists(select 1 from ad_step_claims where user_id=u), 'step claim created without config';
    begin perform public.spin_daily_wheel(u, public.economy_today()); exception when others then null; end;
    begin perform public.claim_daily_coffer(u, public.economy_today()); exception when others then null; end;
    begin perform public.create_daily_ad_claim(u, public.economy_today()); exception when others then null; end;
    assert not exists(select 1 from daily_claims where user_id=u), 'daily claim without config';
    assert not exists(select 1 from daily_ad_claims where user_id=u), 'daily ad claim without config';
    assert (pg_temp.sec_wallet(u)).balance=bal, 'coins credited without config';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G7 missing config fails off', sqlerrm);
  end;
end $$;

-- G8. Stale or future day is refused by every daily RPC ------------------
-- (A missing day is the Edge contract's job: see the review doc, T1.)
do $$
declare u uuid; bal bigint; dd date; fn text;
begin
  begin
    perform pg_temp.sec_enable();
    u := pg_temp.sec_user(); perform pg_temp.sec_earned(u,10);
    bal := (pg_temp.sec_wallet(u)).balance;
    foreach dd in array array[public.economy_today()-1, public.economy_today()+1] loop
      begin perform public.claim_daily_coffer(u,dd); assert false, 'coffer accepted '||dd;
      exception when others then assert sqlerrm='DAY_CHANGED', 'coffer '||dd||': '||sqlerrm; end;
      begin perform public.spin_daily_wheel(u,dd); assert false, 'wheel accepted '||dd;
      exception when others then assert sqlerrm='DAY_CHANGED', 'wheel '||dd||': '||sqlerrm; end;
      begin perform public.create_daily_ad_claim(u,dd); assert false, 'daily ad accepted '||dd;
      exception when others then assert sqlerrm='DAY_CHANGED', 'daily ad '||dd||': '||sqlerrm; end;
    end loop;
    -- A request that lost its day is never read as today's (T1, SQL half).
    begin perform public.claim_daily_coffer(u,null); assert false, 'coffer accepted null day';
    exception when others then assert sqlerrm='DAY_REQUIRED', 'coffer null: '||sqlerrm; end;
    begin perform public.spin_daily_wheel(u,null); assert false, 'wheel accepted null day';
    exception when others then assert sqlerrm='DAY_REQUIRED', 'wheel null: '||sqlerrm; end;
    begin perform public.create_daily_ad_claim(u,null); assert false, 'daily ad accepted null day';
    exception when others then assert sqlerrm='DAY_REQUIRED', 'daily ad null: '||sqlerrm; end;
    assert not exists(select 1 from daily_claims where user_id=u), 'stale day left a claim';
    assert not exists(select 1 from daily_ad_claims where user_id=u), 'stale day left an ad claim';
    assert (pg_temp.sec_wallet(u)).balance=bal, 'stale day credited';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G8 stale/future day refused', sqlerrm);
  end;
end $$;

-- G9. Client roles cannot reach the new surface --------------------------
do $$
declare f record; t text; bad text := '';
begin
  begin
    for f in
      select p.oid::regprocedure::text as sig, p.prosecdef, p.proconfig
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname in (
         'economy_today','credit_earned','register_ad_transaction','ad_reward_eligible',
         'ad_steps_status_v2','create_ad_step_claim_v2','commit_ad_step_v2',
         'create_ad_reward_claim','commit_ad_reward','secure_random_below','daily_status',
         'daily_guard','claim_daily_coffer','spin_daily_wheel','create_daily_ad_claim',
         'commit_daily_ad','account_tag','commit_play_product','mark_play_consumed',
         'revoke_voided_play_purchases','economy_capabilities')
    loop
      if has_function_privilege('anon',f.sig,'execute')
         or has_function_privilege('authenticated',f.sig,'execute') then
        bad := bad||' exec:'||f.sig;
      end if;
      if f.prosecdef and not exists(select 1 from unnest(coalesce(f.proconfig,'{}')) c
                                     where c like 'search_path=%') then
        bad := bad||' search_path:'||f.sig;
      end if;
    end loop;
    foreach t in array array['economy_config','ad_ssv_transactions','ad_step_claims',
        'daily_wheel_prizes','daily_claims','daily_ad_claims','play_products',
        'play_purchases','wallet_ledger','wallet_accounts'] loop
      if has_table_privilege('anon','public.'||t,'select,insert,update,delete')
         or has_table_privilege('authenticated','public.'||t,'insert,update,delete') then
        bad := bad||' table:'||t;
      end if;
    end loop;
    foreach t in array array['economy_config','ad_ssv_transactions','ad_step_claims',
        'daily_claims','daily_ad_claims','play_products'] loop
      if has_table_privilege('authenticated','public.'||t,'select') then
        bad := bad||' select:'||t;
      end if;
    end loop;
    assert bad='', 'exposed:'||bad;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G9 no client execute/table access', sqlerrm);
  end;
end $$;

-- G10. A fresh migration ships every feature off until an operator turns it on
do $$
declare u uuid; r uuid; s jsonb; bal bigint; today date := public.economy_today();
begin
  begin
    u := pg_temp.sec_user(); r := pg_temp.sec_room(u,'SECGJA',100);
    bal := (pg_temp.sec_wallet(u)).balance;
    assert (select not ad_steps_enabled and not daily_enabled and not daily_ad_enabled
              and not interstitial_enabled from economy_config),
      'migrated defaults not all off: '||(select row_to_json(c)::text from economy_config c);
    s := public.economy_capabilities(u);
    -- Explicit false, not a missing or null flag the client must interpret.
    assert s->'adSteps'='false'::jsonb and s->'daily'='false'::jsonb
       and s->'dailyAd'='false'::jsonb and s->'interstitial'->'enabled'='false'::jsonb,
      'capabilities not all off: '||s::text;
    assert jsonb_array_length(s->'products')=0, 'products live on a fresh migration';
    begin perform public.create_ad_step_claim_v2(u,r,1); assert false, 'step claim while off';
    exception when others then assert sqlerrm='FEATURE_OFF', 'step: '||sqlerrm; end;
    begin perform public.claim_daily_coffer(u,today); assert false, 'coffer while off';
    exception when others then assert sqlerrm='FEATURE_OFF', 'coffer: '||sqlerrm; end;
    begin perform public.spin_daily_wheel(u,today); assert false, 'wheel while off';
    exception when others then assert sqlerrm='FEATURE_OFF', 'wheel: '||sqlerrm; end;
    begin perform public.create_daily_ad_claim(u,today); assert false, 'daily ad while off';
    exception when others then assert sqlerrm='FEATURE_OFF', 'daily ad: '||sqlerrm; end;
    assert (pg_temp.sec_wallet(u)).balance=bal, 'coins moved while off';
    -- Daily on but its ad off: the ad still refuses.
    update economy_config set daily_enabled=true;
    begin perform public.create_daily_ad_claim(u,today); assert false, 'daily ad with only daily on';
    exception when others then assert sqlerrm='FEATURE_OFF', 'daily ad partial: '||sqlerrm; end;
    -- The explicit update is what turns them on.
    perform pg_temp.sec_enable();
    s := public.economy_capabilities(u);
    assert s->'adSteps'='true'::jsonb and s->'daily'='true'::jsonb
       and s->'dailyAd'='true'::jsonb and s->'interstitial'->'enabled'='true'::jsonb,
      'capabilities not on after update: '||s::text;
    assert public.create_ad_step_claim_v2(u,r,1)->>'claimId' is not null, 'step claim refused when on';
    assert (public.claim_daily_coffer(u,today)->>'granted')::bigint=20, 'coffer refused when on';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G10 fresh migration ships off', sqlerrm);
  end;
end $$;

-- G11. Quiet Pass: a void is final whatever state it caught ---------------
do $$
declare u uuid; tag text; s jsonb;
begin
  begin
    u := pg_temp.sec_user(); tag := public.account_tag(u);
    -- pending -> voided -> 'active' replay.
    perform public.commit_play_product(u,'sec-g11-token-pend','mm_remove_interruptions','GPA.G11P','pending',now(),1,tag);
    perform public.revoke_voided_play_purchases(array['sec-g11-token-pend'],null);
    begin
      s := public.commit_play_product(u,'sec-g11-token-pend','mm_remove_interruptions','GPA.G11P','active',now(),1,tag);
    exception when others then s := null; end;
    assert not public.user_owns_entitlement(u,'remove_interruptions'), 'pending-voided pass granted';
    -- active -> voided (by order only) -> 'active' replay.
    perform public.commit_play_product(u,'sec-g11-token-act','mm_remove_interruptions','GPA.G11A','active',now(),1,tag);
    assert public.user_owns_entitlement(u,'remove_interruptions'), 'fixture: pass not granted';
    perform public.revoke_voided_play_purchases(null,array['GPA.G11A']);
    assert not public.user_owns_entitlement(u,'remove_interruptions'), 'order void left the pass';
    begin
      s := public.commit_play_product(u,'sec-g11-token-act','mm_remove_interruptions','GPA.G11A','active',now(),1,tag);
    exception when others then s := null; end;
    assert not public.user_owns_entitlement(u,'remove_interruptions'), 'voided pass re-granted on replay';
    assert not (public.economy_capabilities(u)->>'adFree')::boolean, 'adFree after void';
    -- Voided before first verify.
    perform public.revoke_voided_play_purchases(array['sec-g11-token-early'],null);
    begin
      s := public.commit_play_product(u,'sec-g11-token-early','mm_remove_interruptions','GPA.G11E','active',now(),1,tag);
    exception when others then s := null; end;
    assert not public.user_owns_entitlement(u,'remove_interruptions'), 'pre-voided pass granted';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G11 Quiet Pass void is final', sqlerrm);
  end;
end $$;

-- G12. Manual coin orders conserve refund debt (operator refund) --------
-- Case A: A500 spent+refunded -> debt 500; B500 offsets fully; refund B -> 500.
do $$
declare admin uuid; u uuid; oa uuid; ob uuid; w public.wallet_accounts;
begin
  begin
    admin := pg_temp.sec_user(); u := pg_temp.sec_user();
    insert into commerce_admins(user_id) values(admin);
    update coin_packs set price_piastres=5000, active=true where code='coins_500';
    perform pg_temp.sec_earned(u,300);
    oa := pg_temp.sec_paid_order(admin,u,'coins_500','SEC-G12A-A');
    perform pg_temp.sec_spend_purchased(u,500);
    perform public.admin_refund_coin_order(admin,oa,'returned');
    w := pg_temp.sec_wallet(u);
    assert w.purchase_debt=500 and w.balance=300, 'after refund A: '||row_to_json(w)::text;
    ob := pg_temp.sec_paid_order(admin,u,'coins_500','SEC-G12A-B');
    w := pg_temp.sec_wallet(u);
    assert (select credited from coin_orders where id=ob)=0 and w.purchase_debt=0 and w.balance=300,
      'after B: '||row_to_json(w)::text;
    perform public.admin_refund_coin_order(admin,ob,'returned');
    w := pg_temp.sec_wallet(u);
    assert w.purchase_debt=500 and w.balance=300 and w.purchased_balance=0,
      'refund B must restore exactly the offset: '||row_to_json(w)::text;
    begin perform public.admin_refund_coin_order(admin,ob,'again'); assert false, 'double refund';
    exception when others then assert sqlerrm='ORDER_NOT_REFUNDABLE', sqlerrm; end;
    assert (pg_temp.sec_wallet(u)).purchase_debt=500, 'second refund changed debt';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G12a coin order refund restores offset', sqlerrm);
  end;
end $$;

-- Case B: debt 500, B1200 -> offset 500 credit 700; unspent refund takes 700,
-- debt back to 500. Then with 100 spent: take 600, debt 600.
do $$
declare admin uuid; u uuid; u2 uuid; o uuid; w public.wallet_accounts;
begin
  begin
    admin := pg_temp.sec_user(); u := pg_temp.sec_user(); u2 := pg_temp.sec_user();
    insert into commerce_admins(user_id) values(admin);
    update coin_packs set price_piastres=5000, active=true where code='coins_500';
    update coin_packs set price_piastres=12000, active=true where code='coins_1200';

    perform pg_temp.sec_earned(u,300);
    o := pg_temp.sec_paid_order(admin,u,'coins_500','SEC-G12B-A');
    perform pg_temp.sec_spend_purchased(u,500);
    perform public.admin_refund_coin_order(admin,o,'returned');
    o := pg_temp.sec_paid_order(admin,u,'coins_1200','SEC-G12B-B');
    w := pg_temp.sec_wallet(u);
    assert (select credited from coin_orders where id=o)=700 and w.purchase_debt=0
      and w.balance=1000 and w.purchased_balance=700, 'after B: '||row_to_json(w)::text;
    perform public.admin_refund_coin_order(admin,o,'returned');
    w := pg_temp.sec_wallet(u);
    assert w.balance=300 and w.purchased_balance=0 and w.purchase_debt=500,
      'unspent mixed refund: '||row_to_json(w)::text;

    perform pg_temp.sec_earned(u2,300);
    o := pg_temp.sec_paid_order(admin,u2,'coins_500','SEC-G12C-A');
    perform pg_temp.sec_spend_purchased(u2,500);
    perform public.admin_refund_coin_order(admin,o,'returned');
    o := pg_temp.sec_paid_order(admin,u2,'coins_1200','SEC-G12C-B');
    perform pg_temp.sec_spend_purchased(u2,100);
    perform public.admin_refund_coin_order(admin,o,'returned');
    w := pg_temp.sec_wallet(u2);
    assert w.balance=300 and w.purchased_balance=0 and w.purchase_debt=600,
      'partly spent mixed refund: '||row_to_json(w)::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.sec_record('G12b coin order mixed refunds', sqlerrm);
  end;
end $$;

-- Report ----------------------------------------------------------------
do $$
declare failed text;
begin
  select string_agg(gate||' => '||detail, ' | ' order by gate) into failed
    from sec_results where not ok;
  if (select count(*) from sec_results) <> 15 then
    raise exception 'SECURITY GATES INCOMPLETE: % recorded', (select count(*) from sec_results);
  end if;
  if failed is not null then raise exception 'SECURITY GATES FAILED: %', failed; end if;
end $$;
rollback;
