-- Contract for 20260927000100_ads_v3 (phase 110). Rolled back.
-- Single connection: proves logic, ordering, idempotency and constraints.
begin;
do $$
declare
  u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); o uuid:=gen_random_uuid();
  r1 uuid:=gen_random_uuid(); r2 uuid:=gen_random_uuid(); r3 uuid:=gen_random_uuid();
  s jsonb; c1 uuid; c2 uuid; legacy jsonb; bal bigint; caps jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (u,null,null,true),(v,null,null,true),(o,null,null,true);
  insert into rooms(id,code,host_id,status,ended_at,match_seed) values
    (r1,'ADV3AA',u,'finished',now(),31),(r2,'ADV3AB',v,'finished',now(),32),
    (r3,'ADV3AC',o,'finished',now(),33);
  insert into room_players(room_id,user_id,seat,name,role,kicked) values
    (r1,u,0,'A','citizen',false),(r2,v,0,'B','citizen',false),(r3,o,0,'C','mafia',false);
  insert into room_state(room_id,phase,phase_number,public_data) values
    (r1,'result',1,jsonb_build_object('outcome','town')),
    (r2,'result',1,jsonb_build_object('outcome','town')),
    (r3,'result',1,jsonb_build_object('outcome','town'));
  perform public.sync_player_rewards(u);
  perform public.sync_player_rewards(v);
  perform public.sync_player_rewards(o);

  -- G1 Deployed OFF, pacing reported, earlier keys kept.
  caps := public.economy_capabilities(u);
  assert caps ? 'council' and caps ? 'products' and caps ? 'fun', 'earlier keys lost: '||caps::text;
  assert (caps->'interstitial'->>'enabled')::boolean = false
    and (caps->'interstitial'->>'preMatch')::boolean = false
    and (caps->'interstitial'->>'passAndPlay')::boolean = false
    and (caps->'interstitial'->>'session')::boolean = false, caps::text;
  assert (caps->'interstitial'->>'maxPerDay')::int = 40
    and (caps->'interstitial'->>'gapSeconds')::int = 90
    and (caps->'interstitial'->>'sessionAfterSeconds')::int = 300, caps::text;
  assert (caps->'ads'->'fullScreen'->>'maxPerDay')::int = 40, caps::text;
  assert caps->'ads' ? 'banner' and caps->'ads' ? 'extras', 'ads v2 keys lost';
  assert not (caps->'ads'->'appOpen') ? 'maxPerDay', 'app-open daily cap still reported';
  assert caps->>'adStepsMode' = 'multiply';

  -- G2 Floors: the cap never above 40, the gap never below 90 s, the session
  -- timer never below 5 minutes.
  begin update economy_config set full_screen_max_per_day=41; assert false, 'cap 41 accepted';
  exception when check_violation then null; end;
  begin update economy_config set full_screen_min_gap_seconds=60; assert false, 'gap 60 accepted';
  exception when check_violation then null; end;
  begin update economy_config set session_interstitial_after_seconds=120; assert false, 'session 120 accepted';
  exception when check_violation then null; end;
  update economy_config set full_screen_max_per_day=20, full_screen_min_gap_seconds=120,
    pre_match_interstitial_enabled=true, pass_and_play_interstitial_enabled=true,
    session_interstitial_enabled=true, interstitial_enabled=true, ad_steps_enabled=true;
  caps := public.economy_capabilities(u);
  assert (caps->'interstitial'->>'maxPerDay')::int=20 and (caps->'interstitial'->>'gapSeconds')::int=120
    and (caps->'interstitial'->>'preMatch')::boolean and (caps->'interstitial'->>'passAndPlay')::boolean
    and (caps->'interstitial'->>'session')::boolean, caps::text;

  -- G3 Both amounts are shown before the first tap: x2 then x3.
  s := public.ad_steps_status_v2(u,r1);
  assert s->>'mode'='multiply' and (s->>'base')::bigint=100
    and (s->>'double')::bigint=200 and (s->>'triple')::bigint=300, s::text;
  assert (s->'steps'->0->>'amount')::bigint=100 and (s->'steps'->1->>'amount')::bigint=100;
  assert (s->'steps'->0->>'totalAfter')::bigint=200 and (s->'steps'->1->>'totalAfter')::bigint=300;

  -- G4 Ordering: #2 only after #1 is verified (created AND committed).
  begin perform public.create_ad_step_claim_v2(u,r1,2); assert false;
  exception when others then assert sqlerrm='STEP_ORDER', sqlerrm; end;
  s := public.create_ad_step_claim_v2(u,r1,1); c1 := (s->>'claimId')::uuid;
  begin perform public.create_ad_step_claim_v2(u,r1,2); assert false, 'pending #1 unlocked #2';
  exception when others then assert sqlerrm='STEP_ORDER', sqlerrm; end;

  -- G5 Idempotent: a retried create reuses the claim; an AdMob retry pays once.
  assert (public.create_ad_step_claim_v2(u,r1,1)->>'claimId')::uuid=c1;
  select balance into bal from wallet_accounts where user_id=u;
  perform public.commit_ad_step_v2(c1,'v3-step-1-aaaa','unit',1,u);
  perform public.commit_ad_step_v2(c1,'v3-step-1-aaaa','unit',1,u);
  assert (select balance from wallet_accounts where user_id=u)=bal+100, 'x2 not exactly +base';
  begin perform public.commit_ad_step_v2(c1,'v3-step-1-bbbb','unit',1,u); assert false;
  exception when others then assert sqlerrm='CLAIM_ALREADY_USED', sqlerrm; end;

  s := public.create_ad_step_claim_v2(u,r1,2); c2 := (s->>'claimId')::uuid;
  begin perform public.commit_ad_step_v2(c2,'v3-step-1-aaaa','unit',1,u); assert false;
  exception when others then assert sqlerrm='TRANSACTION_ALREADY_USED', sqlerrm; end;
  perform public.commit_ad_step_v2(c2,'v3-step-2-aaaa','unit',1,u);
  perform public.commit_ad_step_v2(c2,'v3-step-2-aaaa','unit',1,u);
  assert (select balance from wallet_accounts where user_id=u)=bal+200, 'x3 not exactly +2*base';
  assert (select count(*) from wallet_ledger where user_id=u and source_room=r1
          and kind in ('ad_step_1','ad_step_2'))=2, 'ledger kinds changed';
  s := public.ad_steps_status_v2(u,r1);
  assert s->'steps'->0->>'state'='awarded' and s->'steps'->1->>'state'='awarded', s::text;

  -- G6 Ordering on commit too: a step-2 row can never pay before step 1.
  s := public.create_ad_step_claim_v2(v,r2,1);
  begin
    insert into ad_step_claims(user_id,room_id,step,base_amount,amount) values(v,r2,2,100,100)
      returning id into c2;
    perform public.commit_ad_step_v2(c2,'v3-order-aaaa','unit',1,v); assert false;
  exception when others then assert sqlerrm='STEP_ORDER', sqlerrm; end;

  -- G7 v1 (1.0.0) unchanged: one ad, +100% once; v2 then defers to it.
  legacy := public.create_ad_reward_claim(o,r3);
  s := public.create_ad_step_claim_v2(o,r3,1);
  assert s->>'scheme'='v1' and (s->>'claimId')::uuid=(legacy->>'claimId')::uuid, s::text;
  select balance into bal from wallet_accounts where user_id=o;
  perform public.commit_ad_reward((legacy->>'claimId')::uuid,'v3-legacy-aaaa','unit',1,o);
  perform public.commit_ad_reward((legacy->>'claimId')::uuid,'v3-legacy-aaaa','unit',1,o);
  assert (select balance from wallet_accounts where user_id=o)=bal+100, 'v1 changed';
  assert not exists(select 1 from ad_step_claims where user_id=o), 'step row next to v1';

  -- G8 Grants.
  assert not has_function_privilege('authenticated','public.economy_capabilities_pre_v3(uuid)','execute');
  assert not has_function_privilege('anon','public.create_ad_step_claim_v2(uuid,uuid,int)','execute');
end $$;
