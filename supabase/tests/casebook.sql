-- Contract for 20260928000400_casebook. Rolled back by the local harness.
begin;

create temp table cb_results(gate text primary key,ok boolean not null,detail text);
create function pg_temp.cb_record(p_gate text,p_err text) returns void language sql as $$
  insert into cb_results values(p_gate,p_err='GATE_OK',nullif(p_err,'GATE_OK'))
$$;
create function pg_temp.cb_user() returns uuid language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,u::text||'@casebook.test',now(),false);
  return u;
end $$;
create function pg_temp.cb_code() returns text language plpgsql as $$
declare a text:='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text:=''; i int;
begin
  for i in 1..6 loop c:=c||substr(a,floor(random()*32)::int+1,1); end loop;
  return c;
end $$;
create function pg_temp.cb_room(p_users uuid[],p_status text default 'finished',
  p_outcome text default 'town',p_kick_first boolean default false,
  p_ended timestamptz default now()) returns uuid language plpgsql as $$
declare rid uuid:=gen_random_uuid(); i int;
begin
  insert into rooms(id,code,host_id,status,ended_at,match_seed)
    values(rid,pg_temp.cb_code(),p_users[1],p_status,
      case when p_status='finished' then p_ended end,7);
  for i in 1..array_length(p_users,1) loop
    insert into room_players(room_id,user_id,seat,name,role,kicked)
      values(rid,p_users[i],i-1,'Case '||i,
        case when i=2 then 'mafia' else 'citizen' end,p_kick_first and i=1);
  end loop;
  insert into room_state(room_id,phase,phase_number,public_data)
    values(rid,case when p_status='finished' then 'result' else 'night' end,1,
      case when p_outcome is null then '{}'::jsonb else jsonb_build_object('outcome',p_outcome) end);
  return rid;
end $$;
create function pg_temp.cb_five(p_user uuid) returns uuid[] language plpgsql as $$
declare result uuid[]:=array[p_user]; i int;
begin
  for i in 1..4 loop result:=result||pg_temp.cb_user(); end loop;
  return result;
end $$;
create function pg_temp.cb_enable() returns void language sql as $$
  update economy_config set missions_enabled=true
$$;
create function pg_temp.cb_balance(p_user uuid) returns bigint language sql as $$
  select coalesce((select balance from wallet_accounts where user_id=p_user),0)
$$;

-- B1. Dark launch, capability composition and refusal shape.
do $$
declare u uuid; caps jsonb; result jsonb;
begin
  begin
    u:=pg_temp.cb_user(); caps:=public.economy_capabilities(u);
    assert caps->>'missions'='false',caps::text;
    assert caps ? 'social' and caps ? 'fun' and caps ? 'council','earlier capability lost';
    assert public.mission_hub(u)=jsonb_build_object('enabled',false);
    result:=public.claim_mission(u,'daily',public.economy_today()::text,0);
    assert result=jsonb_build_object('ok',false,'code','DISABLED'),result::text;
    result:=public.claim_season_reward(u,'season_zero',1);
    assert result->>'code'='DISABLED';
    result:=public.claim_achievement(u,'first_case');
    assert result->>'code'='DISABLED';
    perform pg_temp.cb_enable();
    assert (public.economy_capabilities(u)->>'missions')::boolean;
    assert public.mission_hub(u)->>'enabled'='true';
    assert not has_function_privilege('authenticated','public.mission_hub(uuid)','execute');
    assert not has_function_privilege('authenticated','public.claim_mission(uuid,text,text,int)','execute');
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cb_record('B1 dark capability',sqlerrm); end;
end $$;

-- B2. Only a finished public result with five non-kicked humans is eligible.
do $$
declare u uuid; users uuid[]; rid uuid;
begin
  begin
    perform pg_temp.cb_enable(); u:=pg_temp.cb_user(); users:=pg_temp.cb_five(u);
    rid:=pg_temp.cb_room(users[1:4]);
    assert public.council_record_match(u,rid);
    assert (select not eligible and human_count=4 from council_match_records
      where user_id=u and room_id=rid),'four-human room eligible';

    rid:=pg_temp.cb_room(users,'playing',null);
    assert not public.council_record_match(u,rid);
    assert not exists(select 1 from council_match_records where user_id=u and room_id=rid);

    rid:=pg_temp.cb_room(users,'finished',null);
    assert not public.council_record_match(u,rid);
    assert not exists(select 1 from council_match_records where user_id=u and room_id=rid);

    rid:=pg_temp.cb_room(users,'finished','town',true);
    assert not public.council_record_match(u,rid);
    assert not exists(select 1 from council_match_records where user_id=u and room_id=rid);

    rid:=pg_temp.cb_room(users);
    assert public.council_record_match(u,rid);
    assert (select eligible and human_count=5 and group_fingerprint~'^[0-9a-f]{32}$'
      from council_match_records where user_id=u and room_id=rid),'valid room ineligible';
    assert (select xp from season_xp_events where user_id=u and source_key='match:'||rid)=30;
    assert not public.council_record_match(u,rid),'replayed insert said new';
    assert (select count(*) from season_xp_events where user_id=u and source_key='match:'||rid)=1;
    assert (select progress from mission_achievements where user_id=u and code='first_case')=1;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cb_record('B2 result eligibility',sqlerrm); end;
end $$;

-- B3. Same group stops after three; the day stops after six.
do $$
declare u uuid; same_users uuid[]; rid uuid; i int; eligible_count int;
begin
  begin
    perform pg_temp.cb_enable(); u:=pg_temp.cb_user(); same_users:=pg_temp.cb_five(u);
    for i in 1..4 loop
      rid:=pg_temp.cb_room(same_users);
      perform public.council_record_match(u,rid);
      assert (select eligible from council_match_records where user_id=u and room_id=rid)=(i<=3),
        'same group match '||i;
    end loop;
    for i in 1..4 loop
      rid:=pg_temp.cb_room(pg_temp.cb_five(u));
      perform public.council_record_match(u,rid);
      assert (select eligible from council_match_records where user_id=u and room_id=rid)=(i<=3),
        'daily cap match '||i;
    end loop;
    select count(*) into eligible_count from council_match_records
      where user_id=u and day=public.economy_today() and eligible;
    assert eligible_count=6,'eligible='||eligible_count;
    assert (select count(*) from season_xp_events where user_id=u and source_key like 'match:%')=6;
    assert public.casebook_metric(u,'daily',public.economy_today()::text,'host')=1,
      'host metric exceeded once/day';
    assert (select progress from mission_achievements where user_id=u and code='host_10')=1,
      'host achievement exceeded once/day';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cb_record('B3 anti-farming caps',sqlerrm); end;
end $$;

-- B4. Daily rows are Council rows; legacy and new claims share one marker.
do $$
declare u uuid; rid uuid; users uuid[]; today date:=public.economy_today();
  result jsonb; legacy jsonb; bal bigint; i int; total_coins int:=0; total_xp int:=0;
begin
  begin
    perform pg_temp.cb_enable(); u:=pg_temp.cb_user(); users:=pg_temp.cb_five(u);
    rid:=pg_temp.cb_room(users); perform public.council_record_match(u,rid);
    delete from council_daily_contracts where user_id=u and day=today;
    insert into council_daily_contracts(user_id,day,slot,code,metric,target,coins) values
      (u,today,0,'finish_1','finish',1,15),
      (u,today,1,'win_1','win',1,30),
      (u,today,2,'host_1','host',1,25);
    assert (select count(*) from mission_assignments where user_id=u and day=today)=3;
    bal:=pg_temp.cb_balance(u);
    legacy:=public.claim_council_contract(u,today,0);
    assert (legacy->>'granted')::int=5,legacy::text;
    result:=public.claim_mission(u,'daily',today::text,0);
    assert result->>'code'='ALREADY_CLAIMED',result::text;
    for i in 1..2 loop
      result:=public.claim_mission(u,'daily',today::text,i);
      assert (result->>'ok')::boolean,result::text;
      total_coins:=total_coins+(result->>'coins')::int;
      total_xp:=total_xp+(result->>'xp')::int;
    end loop;
    -- Slots 1+2 include their rewards and the final bonus: 10+10+10 coins,
    -- 40+40+25 XP. Slot 0 was 5 coins/25 XP via the legacy wrapper.
    assert total_coins=30 and total_xp=105,'coins/xp '||total_coins||'/'||total_xp;
    assert pg_temp.cb_balance(u)=bal+35,'daily balance';
    assert (select count(*) from wallet_ledger where user_id=u
      and kind in ('mission_daily','mission_daily_bonus'))=4,'daily ledger count';
    assert (select sum(xp) from season_xp_events where user_id=u
      and (source_key like 'daily:%' or source_key like 'daily-bonus:%'))=130;
    assert (public.mission_hub(u)->'daily'->'bonus'->>'claimed')::boolean;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cb_record('B4 shared daily claims',sqlerrm); end;
end $$;

-- B5. Weekly claim, season math/rewards and achievement claims are once-only.
do $$
declare u uuid; s public.mission_seasons; wk text:=public.council_week(public.economy_today());
  i int; result jsonb; hub jsonb; bal bigint;
begin
  begin
    perform pg_temp.cb_enable(); u:=pg_temp.cb_user();
    select * into s from mission_seasons where code='season_zero';
    -- Ten immutable eligible receipts are enough for the weekly public metric.
    for i in 1..10 loop
      insert into council_match_records(user_id,room_id,ended_at,day,week,team,won,
        hosted,reunion,co_players,eligible,human_count,group_fingerprint)
      values(u,gen_random_uuid(),now(),public.economy_today(),wk,'town',true,false,false,
        '{}',true,5,md5('weekly-'||i));
    end loop;
    result:=public.claim_mission(u,'weekly',wk,0);
    assert (result->>'ok')::boolean and (result->>'coins')::int=75
      and (result->>'xp')::int=180,result::text;
    assert public.claim_council_weekly(u,wk)->>'granted'='0','legacy weekly replay paid';
    result:=public.claim_mission(u,'weekly',wk,0);
    assert result->>'code'='ALREADY_CLAIMED';

    delete from council_match_records where user_id=u;
    delete from season_xp_events where user_id=u and season_id=s.id;
    insert into season_xp_events(user_id,season_id,source_key,xp)
      select u,s.id,'math-a-'||n,case when n=8 then 499 else 500 end
        from generate_series(1,8) n;
    hub:=public.mission_hub(u);
    assert (hub->'season'->>'level')::int=19,hub::text;
    insert into season_xp_events(user_id,season_id,source_key,xp)
      values(u,s.id,'math-b',1);
    hub:=public.mission_hub(u);
    assert (hub->'season'->>'level')::int=20,hub::text;
    bal:=pg_temp.cb_balance(u);
    result:=public.claim_season_reward(u,'season_zero',20);
    assert (result->>'ok')::boolean and (result->>'coins')::int=50,result::text;
    assert pg_temp.cb_balance(u)=bal+50;
    assert public.claim_season_reward(u,'season_zero',20)->>'code'='ALREADY_CLAIMED';

    insert into mission_achievements(user_id,code,progress,unlocked_at)
      values(u,'first_case',1,now()) on conflict(user_id,code) do update
      set progress=1,unlocked_at=now(),claimed_at=null;
    bal:=pg_temp.cb_balance(u);
    result:=public.claim_achievement(u,'first_case');
    assert (result->>'coins')::int=25 and (result->>'xp')::int=50,result::text;
    assert pg_temp.cb_balance(u)=bal+25;
    assert public.claim_achievement(u,'first_case')->>'code'='ALREADY_CLAIMED';
    assert (select sum(coins) from season_reward_catalog where season_id=s.id)=400;
    assert (select count(*) from season_reward_catalog where season_id=s.id)=20;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cb_record('B5 weekly season achievements',sqlerrm); end;
end $$;

do $$
declare failures text;
begin
  select string_agg(gate||': '||detail,E'\n' order by gate) into failures from cb_results where not ok;
  assert failures is null,failures;
end $$;
rollback;
