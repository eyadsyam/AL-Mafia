-- Contract for 20260925000100_update101_economy. Rolled back.
-- Single connection: proves logic, idempotency and constraints, not hosted
-- concurrency (that rests on the advisory locks and unique indexes).
begin;
do $$
declare
  u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); x uuid:=gen_random_uuid();
  r1 uuid:=gen_random_uuid(); r2 uuid:=gen_random_uuid(); r3 uuid:=gen_random_uuid();
  live uuid:=gen_random_uuid();
  s jsonb; c1 uuid; c2 uuid; legacy jsonb; bal bigint; d jsonb; w public.wallet_accounts;
  tag text; t text; n int;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (u,'u@example.test',now(),false),(v,null,null,true),(x,null,null,true);
  -- Three finished matches for u (r1, r2) and v (r3), one live room for x.
  insert into rooms(id,code,host_id,status,ended_at,match_seed) values
    (r1,'UPDTSA',u,'finished',now(),1),(r2,'UPDTSB',u,'finished',now(),2),
    (r3,'UPDTSC',v,'finished',now(),3),(live,'UPDLVE',x,'playing',null,4);
  insert into room_players(room_id,user_id,seat,name,role,kicked) values
    (r1,u,0,'A','citizen',false),(r2,u,0,'A','mafia',false),(r3,v,0,'B','citizen',false),
    (live,x,0,'C','citizen',false);
  insert into room_state(room_id,phase,phase_number,public_data) values
    (r1,'result',1,jsonb_build_object('outcome','town')),
    (r2,'result',1,jsonb_build_object('outcome','town')),
    (r3,'result',1,jsonb_build_object('outcome','town')),
    (live,'night',1,'{}');
  perform public.sync_player_rewards(u);
  perform public.sync_player_rewards(v);

  -- Deployed OFF: nothing is offered until an operator switches it on.
  s:=public.economy_capabilities(u);
  assert not (s->>'adSteps')::boolean and not (s->>'daily')::boolean
    and not (s->>'dailyAd')::boolean and not (s->'interstitial'->>'enabled')::boolean, s::text;
  update economy_config set ad_steps_enabled=true, daily_enabled=true, daily_ad_enabled=true,
    interstitial_enabled=true;

  -- Capabilities: versioned, nothing sold until activated.
  s:=public.economy_capabilities(u);
  assert (s->>'version')::int=2 and (s->>'adSteps')::boolean, s::text;
  assert jsonb_array_length(s->'products')=0, 'products seeded inactive';
  assert (s->>'recoverable')::boolean and not (s->>'adFree')::boolean;
  assert length(s->>'accountTag')=64;

  -- v2 status before any claim: exact amounts shown up front.
  s:=public.ad_steps_status_v2(u,r1);
  assert s->>'scheme'='steps' and (s->>'base')::bigint=100, s::text;
  assert (s->'steps'->0->>'amount')::bigint=50 and (s->'steps'->1->>'amount')::bigint=50;

  -- Step 2 cannot come before step 1 is verified.
  begin perform public.create_ad_step_claim_v2(u,r1,2); assert false;
  exception when others then assert sqlerrm='STEP_ORDER', sqlerrm; end;

  select balance into bal from wallet_accounts where user_id=u;
  s:=public.create_ad_step_claim_v2(u,r1,1); c1:=(s->>'claimId')::uuid;
  -- A retry reuses the same claim.
  assert (public.create_ad_step_claim_v2(u,r1,1)->>'claimId')::uuid=c1;
  -- Wrong user in the signed callback: refused, nothing credited.
  begin perform public.commit_ad_step_v2(c1,'tx-step-1-aaaa','unit',1,v); assert false;
  exception when others then assert sqlerrm='CLAIM_NOT_FOUND', sqlerrm; end;
  perform public.commit_ad_step_v2(c1,'tx-step-1-aaaa','unit',1,u);
  perform public.commit_ad_step_v2(c1,'tx-step-1-aaaa','unit',1,u); -- AdMob retry
  assert (select balance from wallet_accounts where user_id=u)=bal+50;
  begin perform public.commit_ad_step_v2(c1,'tx-step-1-bbbb','unit',1,u); assert false;
  exception when others then assert sqlerrm='CLAIM_ALREADY_USED', sqlerrm; end;

  -- Step 1 kept even if step 2 is never watched; step 2 completes the double.
  s:=public.create_ad_step_claim_v2(u,r1,2); c2:=(s->>'claimId')::uuid;
  -- The same transaction cannot pay two claims.
  begin perform public.commit_ad_step_v2(c2,'tx-step-1-aaaa','unit',1,u); assert false;
  exception when others then assert sqlerrm='TRANSACTION_ALREADY_USED', sqlerrm; end;
  perform public.commit_ad_step_v2(c2,'tx-step-2-aaaa','unit',1,u);
  assert (select balance from wallet_accounts where user_id=u)=bal+100, 'double base after both';
  s:=public.ad_steps_status_v2(u,r1);
  assert s->'steps'->0->>'state'='awarded' and s->'steps'->1->>'state'='awarded';

  -- Claims are immutable once made.
  begin update ad_step_claims set amount=999 where id=c1; assert false;
  exception when others then assert sqlerrm='CLAIM_IMMUTABLE', sqlerrm; end;

  -- A v2 match refuses a v1 claim (old client on the same identity).
  begin perform public.create_ad_reward_claim(u,r1); assert false;
  exception when others then assert sqlerrm='REWARD_SCHEME_V2', sqlerrm; end;

  -- A v1 claim made first (by 1.0.0) is resumed by the new app as one ad,
  -- and v2 steps are then refused for that match.
  legacy:=public.create_ad_reward_claim(u,r2);
  s:=public.create_ad_step_claim_v2(u,r2,1);
  assert s->>'scheme'='v1' and (s->>'claimId')::uuid=(legacy->>'claimId')::uuid, s::text;
  assert not exists(select 1 from ad_step_claims where room_id=r2);
  -- A v2 transaction id cannot pay the v1 claim.
  begin perform public.commit_ad_reward((legacy->>'claimId')::uuid,'tx-step-2-aaaa','unit',1,u); assert false;
  exception when others then assert sqlerrm='TRANSACTION_ALREADY_USED', sqlerrm; end;
  select balance into bal from wallet_accounts where user_id=u;
  perform public.commit_ad_reward((legacy->>'claimId')::uuid,'tx-legacy-aaaa','unit',1,u);
  assert (select balance from wallet_accounts where user_id=u)=bal+100, 'v1 still +100';
  -- ...and the v1 transaction cannot pay a v2 claim elsewhere.
  s:=public.create_ad_step_claim_v2(v,r3,1);
  begin perform public.commit_ad_step_v2((s->>'claimId')::uuid,'tx-legacy-aaaa','unit',1,v); assert false;
  exception when others then assert sqlerrm='TRANSACTION_ALREADY_USED', sqlerrm; end;

  -- Ineligible: a live room, or a match never synced.
  begin perform public.create_ad_step_claim_v2(x,live,1); assert false;
  exception when others then assert sqlerrm='REWARD_NOT_ELIGIBLE', sqlerrm; end;
  update economy_config set ad_steps_enabled=false;
  begin perform public.create_ad_step_claim_v2(v,r3,1); assert false;
  exception when others then assert sqlerrm='FEATURE_OFF', sqlerrm; end;
  update economy_config set ad_steps_enabled=true;

  -- Product rules cannot be loosened by an edit.
  begin update economy_config set interstitial_max_per_day=5; assert false;
  exception when check_violation then null; end;
  begin update economy_config set interstitial_gap_seconds=60; assert false;
  exception when check_violation then null; end;

  -- Daily coffer: once per UTC day, retries free, yesterday's request refused.
  select balance into bal from wallet_accounts where user_id=v;
  d:=public.claim_daily_coffer(v, public.economy_today());
  assert (d->>'granted')::bigint=20 and (d->'daily'->'coffer'->>'claimed')::boolean, d::text;
  d:=public.claim_daily_coffer(v, public.economy_today());
  assert (d->>'granted')::bigint=0;
  assert (select balance from wallet_accounts where user_id=v)=bal+20;
  begin perform public.claim_daily_coffer(x, public.economy_today()-1); assert false;
  exception when others then assert sqlerrm='DAY_CHANGED', sqlerrm; end;

  -- Seven claimed days pay the bonus once; a gap costs nothing.
  for n in 1..6 loop
    insert into daily_claims(user_id,day,kind,amount,claim_number)
      values(v, public.economy_today()-(n*2), 'coffer', 20, n+1);
  end loop;
  -- Six earlier claims on scattered days; today's claim is the seventh.
  delete from daily_claims where user_id=v and day=public.economy_today() and kind='coffer';
  select balance into bal from wallet_accounts where user_id=v;
  delete from wallet_ledger where user_id=v and kind='daily_coffer';
  d:=public.claim_daily_coffer(v, public.economy_today());
  assert (d->>'bonus')::bigint=60 and (d->>'granted')::bigint=20, d::text;
  assert (d->'daily'->'week'->>'progress')::int=0 and (d->'daily'->'week'->>'claimedDays')::int=7;
  assert (select balance from wallet_accounts where user_id=v)=bal+80;

  -- Wheel: persisted before any animation; a second spin returns the same.
  d:=public.spin_daily_wheel(u, public.economy_today());
  assert (d->>'granted')::bigint in (10,20,35,60,100), d::text;
  s:=public.spin_daily_wheel(u, public.economy_today());
  assert s->>'slot'=d->>'slot' and (s->>'granted')::bigint=0, 'no reroll';
  assert (select count(*) from wallet_ledger where user_id=u and kind='daily_wheel')=1;
  assert (select sum(weight) from daily_wheel_prizes)=100;
  assert (public.daily_status(u)->'wheel'->'prizes'->4->>'percent')::numeric=2;
  -- The generator stays in range and hits every slot over many draws.
  select count(distinct public.secure_random_below(5)) into n from generate_series(1,400);
  assert n=5, 'all outcomes reachable';
  assert (select max(public.secure_random_below(3)) from generate_series(1,200))<3;

  -- Daily ad: refused inside a live match; one claim per day; late callback
  -- after midnight pays the claim's own day once.
  begin perform public.create_daily_ad_claim(x, public.economy_today()); assert false;
  exception when others then assert sqlerrm='IN_MATCH', sqlerrm; end;
  s:=public.create_daily_ad_claim(v, public.economy_today()); c1:=(s->>'claimId')::uuid;
  assert (public.create_daily_ad_claim(v, public.economy_today())->>'claimId')::uuid=c1;
  select balance into bal from wallet_accounts where user_id=v;
  perform public.commit_daily_ad(c1,'tx-daily-aaaa','unit',1,v);
  perform public.commit_daily_ad(c1,'tx-daily-aaaa','unit',1,v);
  assert (select balance from wallet_accounts where user_id=v)=bal+25;
  begin perform public.commit_daily_ad(c1,'tx-daily-bbbb','unit',1,v); assert false;
  exception when others then assert sqlerrm='CLAIM_ALREADY_USED', sqlerrm; end;
  begin perform public.commit_daily_ad(c1,'tx-step-2-aaaa','unit',1,v); assert false;
  exception when others then assert sqlerrm in ('CLAIM_ALREADY_USED','TRANSACTION_ALREADY_USED'), sqlerrm; end;

  -- Play coins: unknown product and wrong account refused; pending grants
  -- nothing; active credits once; replay and another account never re-credit.
  tag:=public.account_tag(u); t:='play-token-coins-500-aaaa';
  begin perform public.commit_play_product(u,t,'mm_coins_999',null,'active',now(),1,tag); assert false;
  exception when others then assert sqlerrm='PRODUCT_UNKNOWN', sqlerrm; end;
  begin perform public.commit_play_product(u,t,'mm_coins_500',null,'active',now(),1,public.account_tag(v)); assert false;
  exception when others then assert sqlerrm='ACCOUNT_MISMATCH', sqlerrm; end;
  select * into w from wallet_accounts where user_id=u;
  s:=public.commit_play_product(u,t,'mm_coins_500','GPA.1','pending',now(),1,tag);
  assert not (s->>'granted')::boolean and not (s->>'needsConsume')::boolean;
  assert (select balance from wallet_accounts where user_id=u)=w.balance;
  s:=public.commit_play_product(u,t,'mm_coins_500','GPA.1','active',now(),1,tag);
  assert (s->>'granted')::boolean and (s->>'needsConsume')::boolean and (s->>'credited')::bigint=500, s::text;
  s:=public.commit_play_product(u,t,'mm_coins_500','GPA.1','active',now(),1,tag);
  assert (select balance from wallet_accounts where user_id=u)=w.balance+500, 'credited once';
  assert (select purchased_balance from wallet_accounts where user_id=u)=w.purchased_balance+500;
  begin perform public.commit_play_product(v,t,'mm_coins_500','GPA.1','active',now(),1,null); assert false;
  exception when others then assert sqlerrm='ACCOUNT_MISMATCH', sqlerrm; end;
  perform public.mark_play_consumed(t);
  s:=public.commit_play_product(u,t,'mm_coins_500','GPA.1','active',now(),1,tag);
  assert not (s->>'needsConsume')::boolean, 'consumed once recorded';

  -- Refund after spending: unspent purchased coins taken back, the rest is a
  -- debt; earned coins untouched; the next paid grant pays the debt first.
  update wallet_accounts set balance=balance+1000, lifetime_earned=lifetime_earned+1000 where user_id=u;
  perform public.buy_reward_item(u,'narrator_storyteller'); -- 1200, purchased first
  select * into w from wallet_accounts where user_id=u;
  assert w.purchased_balance=0, w::text;
  assert public.revoke_voided_play_purchases(array[t], null)=1;
  assert public.revoke_voided_play_purchases(array[t], null)=0, 'idempotent';
  assert (select balance from wallet_accounts where user_id=u)=w.balance, 'earned untouched';
  assert (select purchase_debt from wallet_accounts where user_id=u)=500;
  assert exists(select 1 from player_inventory where user_id=u and item_code='narrator_storyteller'),
    'cosmetics are not taken away';
  s:=public.commit_play_product(u,t,'mm_coins_500','GPA.1','active',now(),1,tag);
  assert (select balance from wallet_accounts where user_id=u)=w.balance, 'revoked stays revoked';
  s:=public.commit_play_product(u,'play-token-coins-1200-bbbb','mm_coins_1200','GPA.2','active',now(),1,tag);
  select * into w from wallet_accounts where user_id=u;
  assert w.purchase_debt=0 and (s->>'credited')::bigint=700, s::text;

  -- Refund loop (review H1, corrected expectation): A bought, spent, refunded
  -- → debt 500 (after the 1200 pack above paid it: debt 0). Pay a fresh debt
  -- with pack B entirely, refund B: the debt it paid comes back — 500, not 0
  -- and not 1000.
  update wallet_accounts set purchase_debt=500 where user_id=u;
  select * into w from wallet_accounts where user_id=u;
  s:=public.commit_play_product(u,'play-token-coins-500-dddd','mm_coins_500','GPA.4','active',now(),1,tag);
  assert (s->>'credited')::bigint=0, s::text;
  assert (select purchase_debt from wallet_accounts where user_id=u)=0;
  assert (select debt_offset from play_purchases where purchase_token='play-token-coins-500-dddd')=500;
  perform public.revoke_voided_play_purchases(array['play-token-coins-500-dddd'], null);
  assert (select purchase_debt from wallet_accounts where user_id=u)=500, 'debt restored, not erased';
  assert (select balance from wallet_accounts where user_id=u)=w.balance, 'balance conserved';
  update wallet_accounts set purchase_debt=0 where user_id=u;

  -- A void recorded before the first verify is never credited (tombstone).
  perform public.revoke_voided_play_purchases(array['play-token-void-early-eeee'], array['GPA.9']);
  select * into w from wallet_accounts where user_id=u;
  s:=public.commit_play_product(u,'play-token-void-early-eeee','mm_coins_500','GPA.9','active',now(),1,tag);
  assert s->>'state'='revoked' and not (s->>'granted')::boolean, s::text;
  assert (select balance from wallet_accounts where user_id=u)=w.balance;
  -- ...also when only the order id was voided.
  perform public.revoke_voided_play_purchases(null, array['GPA.10']);
  s:=public.commit_play_product(u,'play-token-order-void-ffff','mm_coins_500','GPA.10','active',now(),1,tag);
  assert s->>'state'='revoked';
  -- A pending purchase revoked by the sync never comes back as active.
  s:=public.commit_play_product(u,'play-token-pending-gggg','mm_coins_500','GPA.11','pending',now(),1,tag);
  perform public.revoke_voided_play_purchases(array['play-token-pending-gggg'], null);
  s:=public.commit_play_product(u,'play-token-pending-gggg','mm_coins_500','GPA.11','active',now(),1,tag);
  assert s->>'state'='revoked' and (select balance from wallet_accounts where user_id=u)=w.balance;
  -- Google reporting a granted purchase cancelled reverses it on verify too.
  s:=public.commit_play_product(u,'play-token-cancel-hhhh','mm_coins_500','GPA.12','active',now(),1,tag);
  s:=public.commit_play_product(u,'play-token-cancel-hhhh','mm_coins_500','GPA.12','revoked',now(),1,tag);
  assert (select balance from wallet_accounts where user_id=u)=w.balance, 'reversed on verify';
  assert public.revoke_voided_play_purchases(array['play-token-cancel-hhhh'], null)=0, 'already settled';
  -- Coins need the account tag.
  begin perform public.commit_play_product(u,'play-token-untagged-iiii','mm_coins_500','GPA.13','active',now(),1,null); assert false;
  exception when others then assert sqlerrm='ACCOUNT_MISMATCH', sqlerrm; end;
  -- The Quiet Pass: entitlement, restorable, revoked by a refund.
  s:=public.commit_play_product(u,'play-token-pass-cccc','mm_remove_interruptions','GPA.3','active',now(),1,tag);
  assert (s->>'needsAcknowledge')::boolean and not (s->>'needsConsume')::boolean;
  assert (public.economy_capabilities(u)->>'adFree')::boolean;
  perform public.revoke_voided_play_purchases(null, array['GPA.3']);
  assert not (public.economy_capabilities(u)->>'adFree')::boolean;
  assert public.revoke_voided_play_purchases(null, array['GPA.3'])=0, 'entitlement void idempotent';

  -- Daily requests must name their day; a missing config row reads as off.
  begin perform public.spin_daily_wheel(x, null); assert false;
  exception when others then assert sqlerrm='DAY_REQUIRED', sqlerrm; end;
  delete from economy_config;
  begin perform public.create_ad_step_claim_v2(v,r3,1); assert false;
  exception when others then assert sqlerrm='FEATURE_OFF', sqlerrm; end;
  begin perform public.spin_daily_wheel(x, public.economy_today()); assert false;
  exception when others then assert sqlerrm='FEATURE_OFF', sqlerrm; end;
  s:=public.economy_capabilities(u);
  assert not (s->>'adSteps')::boolean and not (s->>'daily')::boolean
    and not (s->'interstitial'->>'enabled')::boolean, s::text;
  insert into economy_config default values;
  -- Activation is an operator's row update, and only active products show.
  update play_products set active=true where product_id='mm_coins_500';
  assert jsonb_array_length(public.economy_capabilities(u)->'products')=1;

  -- Nothing here is reachable by clients directly.
  assert not has_function_privilege('authenticated','public.commit_ad_step_v2(uuid,text,text,bigint,uuid)','execute');
  assert not has_function_privilege('authenticated','public.spin_daily_wheel(uuid,date)','execute');
  assert not has_function_privilege('authenticated','public.commit_play_product(uuid,text,text,text,text,timestamptz,int,text)','execute');
  assert not has_table_privilege('authenticated','public.daily_claims','select');
  assert not has_table_privilege('authenticated','public.economy_config','update');
end $$;
rollback;
