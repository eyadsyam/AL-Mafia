-- Contract for 20260928000500_case_of_day. Rolled back by the SQL harness.
begin;

create temp table cp_results(gate text primary key,ok boolean not null,detail text);
create function pg_temp.cp_record(p_gate text,p_err text) returns void language sql as $$
  insert into cp_results values(p_gate,p_err='GATE_OK',nullif(p_err,'GATE_OK'))
$$;
create function pg_temp.cp_user() returns uuid language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,u::text||'@puzzle.test',now(),false);
  return u;
end $$;
create function pg_temp.cp_enable() returns void language sql as $$
  update economy_config set case_of_day_enabled=true
$$;
create function pg_temp.cp_balance(p_user uuid) returns bigint language sql as $$
  select coalesce((select balance from wallet_accounts where user_id=p_user),0)
$$;

-- P1. Dark launch, composed capability and service-role boundary.
do $$
declare u uuid; caps jsonb; result jsonb; today date:=(now() at time zone 'utc')::date;
begin
  begin
    u:=pg_temp.cp_user(); caps:=public.economy_capabilities(u);
    assert caps->>'caseOfDay'='false',caps::text;
    assert caps ? 'missions' and caps ? 'social' and caps ? 'fun','prior capability lost';
    assert public.case_puzzle_status(u)=jsonb_build_object('enabled',false);
    result:=public.case_puzzle_record(u,today,'s0',true,'0123456789abcdef');
    assert result=jsonb_build_object('ok',false,'code','DISABLED'),result::text;
    assert not exists(select 1 from case_puzzle_attempts where user_id=u);
    perform pg_temp.cp_enable();
    assert (public.economy_capabilities(u)->>'caseOfDay')::boolean;
    assert not has_function_privilege('authenticated','public.case_puzzle_status(uuid)','execute');
    assert not has_function_privilege('authenticated',
      'public.case_puzzle_record(uuid,date,text,boolean,text)','execute');
    assert not has_table_privilege('authenticated','public.case_puzzle_attempts','select');
    assert not has_function_privilege('authenticated',
      'public.economy_capabilities_pre_case_of_day(uuid)','execute');
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cp_record('P1 dark and private',sqlerrm); end;
end $$;

-- P2. One correct solve grants exactly once and increments the streak.
do $$
declare u uuid; today date:=(now() at time zone 'utc')::date; result jsonb;
  bal bigint; state jsonb;
begin
  begin
    perform pg_temp.cp_enable(); u:=pg_temp.cp_user(); bal:=pg_temp.cp_balance(u);
    state:=public.case_puzzle_status(u);
    assert state->>'day'=today::text and (state->>'attempts')::int=0
      and not (state->>'solved')::boolean and not (state->>'failed')::boolean,state::text;
    assert state->'reward'=jsonb_build_object('coins',5,'xp',20);
    result:=public.case_puzzle_record(u,today,'s4',true,'0123456789abcdef');
    assert (result->>'ok')::boolean and (result->>'correct')::boolean,result::text;
    assert result->'grant'=jsonb_build_object('coins',5,'xp',20),result::text;
    assert (result->'state'->>'attempts')::int=1
      and (result->'state'->>'solved')::boolean
      and (result->'state'->>'streak')::int=1,result::text;
    assert pg_temp.cp_balance(u)=bal+5;
    assert (select count(*) from wallet_ledger where user_id=u and kind='case_puzzle'
      and source_key=today::text)=1;
    assert (select count(*) from season_xp_events where user_id=u
      and source_key='puzzle:'||today::text and xp=20)=1;
    result:=public.case_puzzle_record(u,today,'s4',true,'0123456789abcdef');
    assert result->>'code'='ALREADY_SOLVED',result::text;
    assert pg_temp.cp_balance(u)=bal+5;
    assert (select attempts from case_puzzle_attempts where user_id=u and day=today)=1;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cp_record('P2 solve once',sqlerrm); end;
end $$;

-- P3. Wrong picks consume three attempts; hash drift and stale days do not.
do $$
declare u uuid; today date:=(now() at time zone 'utc')::date; result jsonb; i int;
begin
  begin
    perform pg_temp.cp_enable(); u:=pg_temp.cp_user();
    result:=public.case_puzzle_record(u,today-1,'s0',false,'1111111111111111');
    assert result->>'code'='DAY_CHANGED';
    result:=public.case_puzzle_record(u,today,'bad',false,'1111111111111111');
    assert result->>'code'='BAD_REQUEST';
    result:=public.case_puzzle_record(u,today,'s0',false,'1111111111111111');
    assert (result->>'ok')::boolean and not (result->>'correct')::boolean
      and result->'grant'='null'::jsonb,result::text;
    result:=public.case_puzzle_record(u,today,'s1',false,'2222222222222222');
    assert result->>'code'='BAD_REQUEST';
    assert (select attempts from case_puzzle_attempts where user_id=u and day=today)=1;
    for i in 2..3 loop
      result:=public.case_puzzle_record(u,today,'s'||i,false,'1111111111111111');
    end loop;
    assert (result->'state'->>'attempts')::int=3
      and (result->'state'->>'failed')::boolean
      and (result->'state'->>'streak')::int=0,result::text;
    result:=public.case_puzzle_record(u,today,'s4',true,'1111111111111111');
    assert result->>'code'='NO_ATTEMPTS';
    assert not exists(select 1 from wallet_ledger where user_id=u and kind='case_puzzle');
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cp_record('P3 attempts and guards',sqlerrm); end;
end $$;

-- P4. Consecutive UTC solved days, missed day and failure reset current only.
do $$
declare u uuid; v uuid; today date:=(now() at time zone 'utc')::date; streak jsonb;
begin
  begin
    perform pg_temp.cp_enable(); u:=pg_temp.cp_user(); v:=pg_temp.cp_user();
    insert into case_puzzle_attempts(user_id,day,attempts,solved_at,answer_hash) values
      (u,today-5,1,now(),'aaaaaaaaaaaaaaaa'),
      (u,today-4,1,now(),'aaaaaaaaaaaaaaaa'),
      (u,today-3,1,now(),'aaaaaaaaaaaaaaaa'),
      (u,today-1,1,now(),'aaaaaaaaaaaaaaaa');
    streak:=public.case_puzzle_streak(u,today);
    assert (streak->>'streak')::int=1 and (streak->>'bestStreak')::int=3,streak::text;
    insert into case_puzzle_attempts(user_id,day,attempts,failed_at,answer_hash)
      values(u,today,3,now(),'aaaaaaaaaaaaaaaa');
    streak:=public.case_puzzle_streak(u,today);
    assert (streak->>'streak')::int=0 and (streak->>'bestStreak')::int=3,streak::text;

    insert into case_puzzle_attempts(user_id,day,attempts,solved_at,answer_hash) values
      (v,today-2,1,now(),'bbbbbbbbbbbbbbbb'),
      (v,today-1,1,now(),'bbbbbbbbbbbbbbbb'),
      (v,today,1,now(),'bbbbbbbbbbbbbbbb');
    streak:=public.case_puzzle_streak(v,today);
    assert (streak->>'streak')::int=3 and (streak->>'bestStreak')::int=3,streak::text;
    delete from case_puzzle_attempts where user_id=v and day=today-1;
    streak:=public.case_puzzle_streak(v,today);
    assert (streak->>'streak')::int=1 and (streak->>'bestStreak')::int=1,streak::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cp_record('P4 streaks',sqlerrm); end;
end $$;

-- P5. The persistence layer has no dependency on any match table.
do $$
declare body text;
begin
  begin
    body:=lower(pg_get_functiondef('public.case_puzzle_record(uuid,date,text,boolean,text)'::regprocedure));
    assert body not like '%room_players%' and body not like '%rooms%'
      and body not like '%room_state%' and body not like '%role%',body;
    body:=lower(pg_get_functiondef('public.case_puzzle_status(uuid)'::regprocedure));
    assert body not like '%room_players%' and body not like '%rooms%'
      and body not like '%room_state%' and body not like '%role%',body;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cp_record('P5 no match dependency',sqlerrm); end;
end $$;

do $$
declare failures text;
begin
  select string_agg(gate||': '||detail,E'\n' order by gate) into failures from cp_results where not ok;
  assert failures is null,failures;
end $$;
rollback;
