-- Contract for 20260925000500_ads_v2. Rolled back.
--
-- Every gate runs in its own subtransaction and is rolled back on exit, so a
-- failing gate never masks the next. Failures are reported together.
-- Single connection (PGlite): logic, idempotency and guards only.
begin;

create temp table av_results(gate text primary key, ok boolean not null, detail text);
create function pg_temp.av_record(p_gate text, p_err text) returns void
language sql as $$
  insert into av_results values(p_gate, p_err='GATE_OK', nullif(p_err,'GATE_OK'))
$$;
create function pg_temp.av_user() returns uuid language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id) values(u);
  return u;
end $$;
create function pg_temp.av_balance(p_user uuid) returns bigint language sql as $$
  select coalesce((select balance from wallet_accounts where user_id=p_user),0)
$$;
create function pg_temp.av_refused(p_sql text, p_code text) returns boolean
language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when others then
  return sqlerrm like '%'||p_code||'%';
end $$;

-- A1. Everything is off by default, and says so ------------------------------
do $$
declare u uuid; caps jsonb; st jsonb; today date := public.economy_today();
begin
  begin
    u := pg_temp.av_user();
    caps := public.economy_capabilities(u);
    assert caps->'ads'->'appOpen'->>'enabled'='false', 'app open default on';
    assert caps->'ads'->'banner'->>'enabled'='false', 'banner default on';
    assert caps->'ads'->'extras'->>'spin'='false' and caps->'ads'->'extras'->>'coffer'='false'
      and caps->'ads'->'extras'->>'swap'='false', 'extras default on';
    assert (caps->'ads'->'appOpen'->>'maxPerDay')::int=3, 'app open cap';
    assert (caps->'ads'->'appOpen'->>'gapSeconds')::int=14400, 'app open gap';
    assert caps ? 'council' and caps ? 'interstitial' and caps ? 'products', 'earlier keys lost';
    st := public.ad_extras_status(u);
    assert st->>'enabled'='false', 'status enabled';
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L)',u,today,'spin'),'FEATURE_OFF'), 'spin while off';
    -- daily on, extras still off: still off
    update economy_config set daily_enabled=true;
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L)',u,today,'coffer'),'FEATURE_OFF'), 'coffer while off';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A1 off by default', sqlerrm);
  end;
end $$;

-- A2. Caps cannot be loosened -------------------------------------------------
do $$
begin
  begin
    assert pg_temp.av_refused('update economy_config set app_open_max_per_day=4','check'), 'max 4 accepted';
    assert pg_temp.av_refused('update economy_config set app_open_gap_seconds=600','check'), 'gap loosened';
    assert pg_temp.av_refused('update economy_config set app_open_resume_after_seconds=60','check'), 'resume loosened';
    update economy_config set app_open_max_per_day=1, app_open_gap_seconds=86400;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A2 caps', sqlerrm);
  end;
end $$;

-- A3. Extra spin: after the free one, once a day, server-drawn, replay-safe ----
do $$
declare u uuid; today date := public.economy_today(); c jsonb; r jsonb; before bigint; id uuid;
begin
  begin
    update economy_config set daily_enabled=true, ad_extras_enabled=true;
    u := pg_temp.av_user();
    assert (public.economy_capabilities(u)->'ads'->'extras'->>'spin')='true', 'caps spin';
    assert public.ad_extras_status(u)->'spin'->>'ready'='false', 'ready before spin';
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L)',u,today,'spin'),'EXTRA_NOT_READY'), 'before free spin';
    perform public.spin_daily_wheel(u,today);
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,null,%L)',u,'spin'),'DAY_REQUIRED'), 'day required';
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L)',u,today-1,'spin'),'DAY_CHANGED'), 'day guard';
    c := public.create_ad_extra_claim(u,today,'spin'); id := (c->>'claimId')::uuid;
    assert c->>'state'='pending', 'pending';
    assert (public.create_ad_extra_claim(u,today,'spin')->>'claimId')::uuid=id, 'one claim a day';
    before := pg_temp.av_balance(u);
    r := public.commit_ad_extra(id,'av-a3-tx-0001','unit',1,u);
    assert (r->>'amount')::int in (10,20,35,60,100), 'prize from wheel';
    assert pg_temp.av_balance(u)=before+(r->>'amount')::int, 'credited once';
    -- The same callback again: no second credit, same answer.
    assert (public.commit_ad_extra(id,'av-a3-tx-0001','unit',1,u)->>'amount')=(r->>'amount'), 'replay answer';
    assert pg_temp.av_balance(u)=before+(r->>'amount')::int, 'replay credited';
    assert pg_temp.av_refused(format('select public.commit_ad_extra(%L,%L,%L,1,%L)',id,'av-a3-tx-0002','unit',u),'CLAIM_ALREADY_USED'), 'second transaction';
    assert pg_temp.av_refused(format('select public.commit_ad_extra(%L,%L,%L,1,%L)',id,'av-a3-tx-0001','unit',gen_random_uuid()),'CLAIM_NOT_FOUND'), 'foreign user';
    assert public.ad_extras_status(u)->'spin'->>'state'='awarded', 'status awarded';
    assert (public.ad_extras_status(u)->'spin'->>'amount')=(r->>'amount'), 'status amount';
    assert public.create_ad_extra_claim(u,today,'spin')->>'state'='awarded', 'no second claim';
    assert (select count(*) from wallet_ledger where user_id=u and kind='ad_extra_spin')=1, 'ledger once';
    assert pg_temp.av_refused(format('update ad_extra_claims set amount=999 where id=%L',id),'CLAIM_IMMUTABLE'), 'immutable';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A3 extra spin', sqlerrm);
  end;
end $$;

-- A4. Double coffer: pays today's coffer amount once ------------------------
do $$
declare u uuid; today date := public.economy_today(); c jsonb; before bigint;
begin
  begin
    update economy_config set daily_enabled=true, ad_extras_enabled=true, daily_coffer_coins=20;
    u := pg_temp.av_user();
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L)',u,today,'coffer'),'EXTRA_NOT_READY'), 'before coffer';
    perform public.claim_daily_coffer(u,today);
    c := public.create_ad_extra_claim(u,today,'coffer');
    assert (c->>'amount')::int=20, 'coffer amount';
    before := pg_temp.av_balance(u);
    perform public.commit_ad_extra((c->>'claimId')::uuid,'av-a4-tx-0001','unit',1,u);
    perform public.commit_ad_extra((c->>'claimId')::uuid,'av-a4-tx-0001','unit',1,u);
    assert pg_temp.av_balance(u)=before+20, 'credited once';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A4 double coffer', sqlerrm);
  end;
end $$;

-- A5. One transaction pays one claim, across every scheme -----------------------
do $$
declare u uuid; today date := public.economy_today(); c jsonb; d jsonb;
begin
  begin
    update economy_config set daily_enabled=true, daily_ad_enabled=true, ad_extras_enabled=true;
    u := pg_temp.av_user();
    perform public.claim_daily_coffer(u,today);
    d := public.create_daily_ad_claim(u,today);
    perform public.commit_daily_ad((d->>'claimId')::uuid,'av-a5-tx-0001','unit',1,u);
    c := public.create_ad_extra_claim(u,today,'coffer');
    assert pg_temp.av_refused(format('select public.commit_ad_extra(%L,%L,%L,1,%L)',c->>'claimId','av-a5-tx-0001','unit',u),'TRANSACTION_ALREADY_USED'), 'daily tx reused';
    perform public.commit_ad_extra((c->>'claimId')::uuid,'av-a5-tx-0002','unit',1,u);
    d := public.create_daily_ad_claim(u,today);
    assert pg_temp.av_refused(format('select public.commit_daily_ad(%L,%L,%L,1,%L)',d->>'claimId','av-a5-tx-0002','unit',u),'CLAIM_ALREADY_USED'), 'extra tx on daily';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A5 cross-scheme replay', sqlerrm);
  end;
end $$;

-- A6. v1 one-ad claim is unchanged --------------------------------------------
do $$
declare u uuid:=pg_temp.av_user(); r uuid:=gen_random_uuid(); c jsonb; b bigint;
begin
  begin
    update economy_config set ad_extras_enabled=true, daily_enabled=true;
    insert into rooms(id,code,host_id,status,ended_at,match_seed) values(r,'AVTST6',u,'finished',now(),1);
    insert into room_players(room_id,user_id,seat,name,role,kicked) values(r,u,0,'A','citizen',false);
    insert into room_state(room_id,phase,phase_number,public_data)
      values(r,'result',1,jsonb_build_object('outcome','town'));
    perform public.sync_player_rewards(u);
    b := pg_temp.av_balance(u);
    c := public.create_ad_reward_claim(u,r);
    perform public.commit_ad_reward((c->>'claimId')::uuid,'av-a6-tx-0001','unit',1,u);
    assert pg_temp.av_balance(u)=b+100, 'v1 credit';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A6 v1 unchanged', sqlerrm);
  end;
end $$;

-- A7. Never while seated in a live room ---------------------------------------
do $$
declare u uuid:=pg_temp.av_user(); r uuid:=gen_random_uuid(); today date := public.economy_today();
begin
  begin
    update economy_config set daily_enabled=true, ad_extras_enabled=true;
    perform public.claim_daily_coffer(u,today);
    insert into rooms(id,code,host_id,status,match_seed) values(r,'AVTST7',u,'playing',1);
    insert into room_players(room_id,user_id,seat,name,role,kicked) values(r,u,0,'A','citizen',false);
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L)',u,today,'coffer'),'IN_MATCH'), 'in match';
    assert public.ad_extras_status(u)->>'inMatch'='true', 'status inMatch';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A7 not in a match', sqlerrm);
  end;
end $$;

-- A8. Contract swap: only with contracts on; keeps slot rules; once a day ---
do $$
declare u uuid; today date := public.economy_today(); c jsonb; r jsonb; before text; after text;
  grp0 text;
begin
  begin
    update economy_config set ad_extras_enabled=true, council_contracts_enabled=false;
    u := pg_temp.av_user();
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L,1)',u,today,'swap'),'FEATURE_OFF'), 'contracts off';
    update economy_config set council_contracts_enabled=true;
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L,null)',u,today,'swap'),'BAD_REQUEST'), 'slot required';
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L,5)',u,today,'swap'),'BAD_REQUEST'), 'slot range';
    c := public.create_ad_extra_claim(u,today,'swap',0);
    -- Changed its mind before watching: the pending claim follows.
    c := public.create_ad_extra_claim(u,today,'swap',2);
    assert (c->>'slot')::int=2, 'slot moved while pending';
    select code into before from council_daily_contracts where user_id=u and day=today and slot=2;
    r := public.commit_ad_extra((c->>'claimId')::uuid,'av-a8-tx-0001','unit',1,u);
    select code into after from council_daily_contracts where user_id=u and day=today and slot=2;
    assert after<>before and r->>'code'=after, 'swapped';
    assert (select count(distinct k.grp) from council_daily_contracts d
      join council_contract_catalog k on k.code=d.code where d.user_id=u and d.day=today)=3, 'groups distinct';
    select k.grp into grp0 from council_daily_contracts d join council_contract_catalog k on k.code=d.code
     where d.user_id=u and d.day=today and d.slot=0;
    assert grp0='finish', 'slot 0 still finish';
    assert pg_temp.av_balance(u)=0, 'swap grants no coins';
    assert public.create_ad_extra_claim(u,today,'swap',1)->>'state'='awarded', 'once a day';
    assert public.ad_extras_status(u)->'swap'->>'code'=after, 'status code';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A8 contract swap', sqlerrm);
  end;
end $$;

-- A9. A claimed contract cannot be swapped -------------------------------------
do $$
declare u uuid; today date := public.economy_today();
begin
  begin
    update economy_config set ad_extras_enabled=true, council_contracts_enabled=true;
    u := pg_temp.av_user();
    perform public.council_draw_contracts(u,today);
    update council_daily_contracts set claimed_at=now() where user_id=u and day=today and slot=1;
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L,1)',u,today,'swap'),'EXTRA_NOT_READY'), 'claimed slot';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A9 claimed contract', sqlerrm);
  end;
end $$;

-- A10. Global circuit breaker --------------------------------------------------
do $$
declare u uuid; v uuid; today date := public.economy_today();
begin
  begin
    update economy_config set daily_enabled=true, ad_extras_enabled=true, daily_global_cap=1;
    u := pg_temp.av_user(); v := pg_temp.av_user();
    perform public.claim_daily_coffer(u,today);
    update economy_config set daily_global_cap=2;
    perform public.claim_daily_coffer(v,today);
    update economy_config set daily_global_cap=1;
    perform public.create_ad_extra_claim(u,today,'coffer');
    assert pg_temp.av_refused(format('select public.create_ad_extra_claim(%L,%L,%L)',v,today,'coffer'),'DAILY_PAUSED'), 'paused';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A10 global cap', sqlerrm);
  end;
end $$;

-- A11. Orphan purge covers the new rows ----------------------------------------
do $$
declare today date := public.economy_today();
begin
  begin
    insert into ad_extra_claims(user_id,day,kind,amount) values(gen_random_uuid(),today,'coffer',20);
    perform public.purge_orphan_economy();
    assert not exists(select 1 from ad_extra_claims d where not exists(select 1 from auth.users u where u.id=d.user_id)), 'orphan left';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.av_record('A11 purge', sqlerrm);
  end;
end $$;

do $$
declare failed text;
begin
  select string_agg(gate||': '||coalesce(detail,'?'), E'\n' order by gate) into failed
    from av_results where not ok;
  if failed is not null then raise exception E'ads_v2 gates failed:\n%', failed; end if;
  if (select count(*) from av_results) <> 11 then
    raise exception 'ads_v2: expected 11 gates, got %', (select count(*) from av_results);
  end if;
end $$;
rollback;
