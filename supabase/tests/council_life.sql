-- Contract for 20260925000300_council_life. Rolled back.
--
-- Every gate runs in its own subtransaction and is rolled back on exit, so a
-- failing gate never masks or feeds the next. Failures are collected and
-- reported together at the end.
--
-- Single connection (PGlite): proves logic, idempotency, guards and
-- conservation, NOT hosted lock ordering under concurrency.
begin;

-- Hosted auth.users has created_at; the local harness does not.
alter table auth.users add column if not exists created_at timestamptz not null default now();

create temp table cl_results(gate text primary key, ok boolean not null, detail text);

create function pg_temp.cl_record(p_gate text, p_err text) returns void
language sql as $$
  insert into cl_results values(p_gate, p_err='GATE_OK', nullif(p_err,'GATE_OK'))
$$;

create function pg_temp.cl_user(p_age interval default '1 hour') returns uuid
language plpgsql as $$
declare u uuid := gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous,created_at)
    values(u, u::text||'@example.test', now(), false, now()-p_age);
  return u;
end $$;

create function pg_temp.cl_code() returns text language plpgsql as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text := ''; i int;
begin
  for i in 1..6 loop c := c || substr(a, public.secure_random_below(32)+1, 1); end loop;
  return c;
end $$;

-- A room with p_players in seat order and p_roles alongside. Finished (with
-- p_outcome) unless p_outcome is null, then 'playing'. Finished rooms pay
-- their completion rewards through the real path.
create function pg_temp.cl_room(p_host uuid, p_players uuid[], p_roles text[],
  p_outcome text) returns uuid language plpgsql as $$
declare r uuid := gen_random_uuid(); i int;
begin
  insert into rooms(id,code,host_id,status,ended_at,match_seed)
    values(r,pg_temp.cl_code(),p_host,case when p_outcome is null then 'playing' else 'finished' end,
      case when p_outcome is null then null else now() end,1);
  for i in 1..array_length(p_players,1) loop
    insert into room_players(room_id,user_id,seat,name,role,kicked)
      values(r,p_players[i],i-1,'Player '||i,p_roles[i],false);
  end loop;
  insert into room_state(room_id,phase,phase_number,public_data)
    values(r,case when p_outcome is null then 'night' else 'result' end,1,
      case when p_outcome is null then '{}'::jsonb else jsonb_build_object('outcome',p_outcome) end);
  if p_outcome is not null then
    for i in 1..array_length(p_players,1) loop
      perform public.sync_player_rewards(p_players[i]);
    end loop;
  end if;
  return r;
end $$;

-- One finished town-win match for p_user alone.
create function pg_temp.cl_match(p_user uuid) returns uuid language sql as $$
  select pg_temp.cl_room(p_user, array[p_user], array['citizen'], 'town')
$$;

create function pg_temp.cl_enable() returns void language sql as $$
  update economy_config set council_contracts_enabled=true, council_rank_enabled=true,
    council_leaderboard_enabled=true, council_invites_enabled=true, starter_bundle_enabled=true;
$$;

create function pg_temp.cl_balance(p_user uuid) returns bigint language sql as $$
  select coalesce((select balance from wallet_accounts where user_id=p_user),0)
$$;

-- Makes today's three contracts "finish one match" so claims are predictable.
create function pg_temp.cl_easy(p_user uuid) returns void language sql as $$
  select public.council_draw_contracts(p_user, public.economy_today());
  update council_daily_contracts set metric='finish', target=1
   where user_id=p_user and day=public.economy_today();
$$;

-- C1. Ships off; a missing config row reads as off ------------------------
do $$
declare u uuid; s jsonb; today date := public.economy_today(); bal bigint;
begin
  begin
    assert (select not council_contracts_enabled and not council_rank_enabled
      and not council_leaderboard_enabled and not council_invites_enabled
      and not starter_bundle_enabled from economy_config), 'migrated defaults not off';
    u := pg_temp.cl_user();
    s := public.economy_capabilities(u);
    assert s->'council'->'contracts'='false'::jsonb and s->'council'->'rank'='false'::jsonb
      and s->'council'->'leaderboard'='false'::jsonb and s->'council'->'invites'='false'::jsonb
      and s->'council'->'starterBundle'='false'::jsonb, 'capabilities: '||s::text;
    -- Existing answers are untouched.
    assert (s->>'version')::int=2 and s ? 'adSteps' and s ? 'accountTag', s::text;
    perform pg_temp.cl_match(u);
    assert not exists(select 1 from council_match_records where user_id=u), 'recorded while off';
    bal := pg_temp.cl_balance(u);
    assert public.council_contracts(u)->'enabled'='false'::jsonb;
    assert public.council_rank(u)->'enabled'='false'::jsonb;
    assert public.council_leaderboard(u)->'enabled'='false'::jsonb;
    assert public.council_invite(u)->'enabled'='false'::jsonb;
    assert not exists(select 1 from council_invite_codes where user_id=u), 'code minted while off';
    begin perform public.claim_council_contract(u,today,0); assert false, 'claim while off';
    exception when others then assert sqlerrm='FEATURE_OFF', 'claim: '||sqlerrm; end;
    begin perform public.claim_council_weekly(u,public.council_week(today)); assert false;
    exception when others then assert sqlerrm='FEATURE_OFF', 'weekly: '||sqlerrm; end;
    begin perform public.redeem_council_invite(u,'ABCDEFG'); assert false;
    exception when others then assert sqlerrm='FEATURE_OFF', 'redeem: '||sqlerrm; end;
    assert pg_temp.cl_balance(u)=bal, 'coins moved while off';
    -- Rank alone does not switch the leaderboard on.
    update economy_config set council_rank_enabled=true;
    assert public.council_leaderboard(u)->'enabled'='false'::jsonb, 'leaderboard without its flag';
    delete from economy_config;
    s := public.economy_capabilities(u);
    assert s->'council'->'contracts'='false'::jsonb and s->'council'->'rank'='false'::jsonb, s::text;
    begin perform public.claim_council_contract(u,today,0); assert false;
    exception when others then assert sqlerrm='FEATURE_OFF', 'no config: '||sqlerrm; end;
    -- Caps are product rules.
    insert into economy_config default values;
    begin update economy_config set council_invite_cap=21; assert false, 'cap loosened';
    exception when check_violation then null; end;
    begin update economy_config set council_xp_daily_matches=500; assert false, 'xp cap loosened';
    exception when check_violation then null; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C1 ships off', sqlerrm);
  end;
end $$;

-- C2. Nothing counts before the match completes ----------------------------
do $$
declare u uuid; v uuid; r uuid; s jsonb; today date := public.economy_today(); bal bigint;
begin
  begin
    perform pg_temp.cl_enable();
    u := pg_temp.cl_user(); v := pg_temp.cl_user();
    r := pg_temp.cl_room(u, array[u,v], array['mafia','citizen'], null);
    perform pg_temp.cl_easy(u);
    s := public.council_contracts(u);
    assert (s->'contracts'->0->>'progress')::int=0 and not (s->'contracts'->0->>'claimable')::boolean, s::text;
    assert not exists(select 1 from council_match_records where room_id=r), 'live room recorded';
    assert not exists(select 1 from council_xp_events where source_key='match:'||r), 'live xp';
    begin perform public.claim_council_contract(u,today,0); assert false, 'claimed during match';
    exception when others then assert sqlerrm='CONTRACT_INCOMPLETE', sqlerrm; end;
    -- A room that ended without a public outcome (abandoned) never counts.
    update rooms set status='finished', ended_at=now() where id=r;
    perform public.council_sync(u);
    assert not exists(select 1 from council_match_records where room_id=r), 'no-outcome room recorded';
    -- The result screen: outcome public, completion paid, record written.
    update room_state set phase='result', public_data=jsonb_build_object('outcome','mafia') where room_id=r;
    perform public.sync_player_rewards(u);
    assert exists(select 1 from council_match_records where room_id=r and user_id=u), 'trigger did not record';
    bal := pg_temp.cl_balance(u);
    s := public.claim_council_contract(u,today,0);
    assert (s->>'granted')::bigint > 0 and pg_temp.cl_balance(u)=bal+(s->>'granted')::bigint, s::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C2 not claimable before completion', sqlerrm);
  end;
end $$;

-- C3. Draw: deterministic, one "finish" slot, distinct groups, fixed once drawn
do $$
declare u uuid; first text[]; again text[]; today date := public.economy_today(); n int;
  s jsonb; offered bigint;
begin
  begin
    perform pg_temp.cl_enable();
    u := pg_temp.cl_user();
    perform public.council_draw_contracts(u,today);
    select array_agg(code order by slot) into first from council_daily_contracts where user_id=u and day=today;
    assert array_length(first,1)=3, 'not three: '||first::text;
    assert first[1] in ('finish_1','finish_3'), 'slot 0 not a finish contract: '||first::text;
    assert (select count(distinct c.grp) from council_daily_contracts d
      join council_contract_catalog c on c.code=d.code where d.user_id=u and d.day=today)=3, 'groups repeat';
    assert (select bool_and(coins between 15 and 40) from council_daily_contracts where user_id=u), 'coins out of range';
    delete from council_daily_contracts where user_id=u;
    perform public.council_draw_contracts(u,today);
    select array_agg(code order by slot) into again from council_daily_contracts where user_id=u and day=today;
    assert first=again, 'not deterministic';
    -- Different players get different days.
    select count(distinct codes) into n from (
      select (select string_agg(x.code, ',' order by x.h) from (
        select c.code, hashtextextended(g::text||':'||today::text||':'||c.code,107) h
          from council_contract_catalog c) x) codes
        from (select gen_random_uuid() g from generate_series(1,20)) users) t;
    assert n > 1, 'every player drew the same';
    -- A catalog edit later in the day does not change what was offered.
    select d.coins into offered from council_daily_contracts d where user_id=u and day=today and slot=1;
    update council_contract_catalog set coins=15 where code=first[2];
    update council_contract_catalog set active=false where code=first[3];
    s := public.council_contracts(u);
    assert (s->'contracts'->1->>'coins')::bigint=offered and s->'contracts'->2->>'code'=first[3], s::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C3 deterministic draw', sqlerrm);
  end;
end $$;

-- C4. Daily claims: day guards, replay, all-three bonus once ----------------
do $$
declare u uuid; s jsonb; today date := public.economy_today(); bal bigint; total bigint := 0; i int;
begin
  begin
    perform pg_temp.cl_enable();
    u := pg_temp.cl_user();
    perform pg_temp.cl_easy(u);
    perform pg_temp.cl_match(u);
    begin perform public.claim_council_contract(u,null,0); assert false;
    exception when others then assert sqlerrm='DAY_REQUIRED', 'null day: '||sqlerrm; end;
    begin perform public.claim_council_contract(u,today-1,0); assert false;
    exception when others then assert sqlerrm='DAY_CHANGED', 'yesterday: '||sqlerrm; end;
    begin perform public.claim_council_contract(u,today+1,0); assert false;
    exception when others then assert sqlerrm='DAY_CHANGED', 'tomorrow: '||sqlerrm; end;
    begin perform public.claim_council_contract(u,today,3); assert false;
    exception when others then assert sqlerrm='BAD_REQUEST', 'slot: '||sqlerrm; end;
    bal := pg_temp.cl_balance(u);
    s := public.claim_council_contract(u,today,0);
    total := (s->>'granted')::bigint;
    assert total > 0 and (s->>'bonusGranted')::bigint=0, s::text;
    s := public.claim_council_contract(u,today,0);
    assert (s->>'granted')::bigint=0, 'replay paid: '||s::text;
    assert (select count(*) from wallet_ledger where user_id=u and kind='council_contract')=1;
    for i in 1..2 loop
      s := public.claim_council_contract(u,today,i);
      total := total + (s->>'granted')::bigint;
    end loop;
    assert (s->>'bonusGranted')::bigint=30 and (s->'bonus'->>'claimed')::boolean, s::text;
    s := public.claim_council_contract(u,today,2);
    assert (s->>'bonusGranted')::bigint=0 and (s->>'granted')::bigint=0, 'bonus replay: '||s::text;
    assert (select count(*) from wallet_ledger where user_id=u and kind='council_contract_bonus')=1;
    assert pg_temp.cl_balance(u)=bal+total+30, 'balance '||pg_temp.cl_balance(u)||' vs '||(bal+total+30);
    assert (select sum(coins) from council_daily_contracts where user_id=u)=total;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C4 daily claim guards and replay', sqlerrm);
  end;
end $$;

-- C5. Weekly contract: week guards, target, once, XP bonus once -------------
do $$
declare u uuid; s jsonb; wk text := public.council_week(public.economy_today()); i int; bal bigint;
begin
  begin
    perform pg_temp.cl_enable();
    u := pg_temp.cl_user();
    for i in 1..9 loop perform pg_temp.cl_match(u); end loop;
    begin perform public.claim_council_weekly(u,null); assert false;
    exception when others then assert sqlerrm='WEEK_REQUIRED', 'null week: '||sqlerrm; end;
    begin perform public.claim_council_weekly(u,'2020-W01'); assert false;
    exception when others then assert sqlerrm='WEEK_CHANGED', 'old week: '||sqlerrm; end;
    begin perform public.claim_council_weekly(u,wk); assert false, '9 of 10 claimed';
    exception when others then assert sqlerrm='CONTRACT_INCOMPLETE', sqlerrm; end;
    perform pg_temp.cl_match(u);
    bal := pg_temp.cl_balance(u);
    s := public.claim_council_weekly(u,wk);
    assert (s->>'granted')::bigint=150 and (s->>'xpGranted')::int=150, s::text;
    assert (s->'weekly'->>'claimed')::boolean and not (s->'weekly'->>'claimable')::boolean, s::text;
    s := public.claim_council_weekly(u,wk);
    assert (s->>'granted')::bigint=0 and (s->>'xpGranted')::int=0, 'weekly replay: '||s::text;
    assert (select count(*) from wallet_ledger where user_id=u and kind='council_weekly')=1;
    assert (select count(*) from council_xp_events where user_id=u and source_key like 'weekly:%')=1;
    -- 150 coins plus level rewards (paid lazily, so all of them land in this
    -- claim), nothing else. 10 wins = 500 XP, +150 = 650: level 5.
    assert (select string_agg(source_key, ',' order by source_key) from wallet_ledger
      where user_id=u and kind='council_level')='level:2,level:3,level:4,level:5', 'levels paid';
    assert pg_temp.cl_balance(u)=bal+150+(select sum(amount) from wallet_ledger
      where user_id=u and kind='council_level'), 'weekly balance';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C5 weekly guards and once', sqlerrm);
  end;
end $$;

-- C6. XP: once per match, win and loss, daily cap, level coins once ---------
do $$
declare a uuid; b uuid; r1 uuid; r2 uuid; s jsonb; total bigint; i int; bal bigint;
begin
  begin
    perform pg_temp.cl_enable();
    a := pg_temp.cl_user(); b := pg_temp.cl_user();
    assert public.council_level_xp(1)=0 and public.council_level_xp(2)=100
      and public.council_level_xp(3)=220 and public.council_level_xp(50)=28420, 'curve';
    assert public.council_level_for(99)=1 and public.council_level_for(100)=2
      and public.council_level_for(28419)=49 and public.council_level_for(10000000)=50, 'level_for';
    assert public.council_level_coins(2)=25 and public.council_level_coins(5)=100
      and public.council_level_coins(50)=300, 'level coins';
    assert (select sum(public.council_level_coins(l)) from generate_series(2,50) l)=2175, 'ladder total';
    -- a town (won), b mafia (lost); both progress.
    r1 := pg_temp.cl_room(a, array[a,b], array['citizen','mafia'], 'town');
    assert (select xp from council_xp_events where user_id=a and source_key='match:'||r1)=50, 'win xp';
    assert (select xp from council_xp_events where user_id=b and source_key='match:'||r1)=30, 'loss xp';
    -- Replays of every path grant nothing more.
    perform public.sync_player_rewards(a);
    perform public.council_sync(a);
    perform public.council_rank(a);
    perform public.council_record_match(a, r1);
    assert (select count(*) from council_xp_events where user_id=a)=1, 'xp granted twice';
    -- Records captured while rank was off get XP once rank is on.
    update economy_config set council_rank_enabled=false;
    r2 := pg_temp.cl_match(a);
    assert (select xp from council_match_records where room_id=r2) is null, 'xp while rank off';
    update economy_config set council_rank_enabled=true;
    bal := pg_temp.cl_balance(a);
    s := public.council_rank(a);
    assert (s->>'xp')::bigint=100 and (s->>'level')::int=2, s::text;
    assert s->'levelUps'=jsonb_build_array(jsonb_build_object('level',2,'coins',25)), 'levelUps: '||s::text;
    assert pg_temp.cl_balance(a)=bal+25, 'level coins';
    s := public.council_rank(a);
    assert s->'levelUps'='[]'::jsonb and pg_temp.cl_balance(a)=bal+25, 'level paid twice';
    assert s->>'titleEn'='Newcomer' and s->>'titleAr'='مبتدئ' and (s->>'nextLevelXp')::int=220, s::text;
    -- The daily XP cap: matches beyond it complete, count for contracts, earn 0 XP.
    update economy_config set council_xp_daily_matches=2;
    r2 := pg_temp.cl_match(a);
    assert (select xp from council_match_records where room_id=r2)=0, 'xp over daily cap';
    assert public.council_metric(a, public.economy_today(), 'finish')=3, 'capped match not counted';
    -- Kicked players get nothing.
    r2 := pg_temp.cl_room(b, array[b,a], array['citizen','mafia'], null);
    update room_players set kicked=true where room_id=r2 and user_id=a;
    update rooms set status='finished', ended_at=now() where id=r2;
    update room_state set phase='result', public_data='{"outcome":"town"}' where room_id=r2;
    perform public.council_sync(a);
    assert not exists(select 1 from council_match_records where room_id=r2 and user_id=a), 'kicked recorded';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C6 xp once per match', sqlerrm);
  end;
end $$;

-- C7. Leaderboard: week XP, caller position, blocks, nothing private ------
do $$
declare a uuid; b uuid; c uuid; s jsonb; t text;
begin
  begin
    perform pg_temp.cl_enable();
    a := pg_temp.cl_user(); b := pg_temp.cl_user(); c := pg_temp.cl_user();
    perform pg_temp.cl_room(a, array[a,b], array['citizen','mafia'], 'town');
    perform pg_temp.cl_room(a, array[a,b], array['citizen','mafia'], 'town');
    perform pg_temp.cl_room(c, array[c,b], array['mafia','citizen'], 'mafia');
    s := public.council_leaderboard(b);
    assert s->>'week'=public.council_week(public.economy_today()), s::text;
    assert (s->'me'->>'xp')::bigint=90 and (s->'me'->>'position')::int=2, 'me: '||s::text;
    assert s->'entries'->0->>'position'='1' and (s->'entries'->0->>'xp')::int=100, s::text;
    assert (select count(*) from jsonb_array_elements(s->'entries') e where (e->>'me')::boolean)=1;
    t := s::text;
    assert position(a::text in t)=0 and position(b::text in t)=0 and position(c::text in t)=0, 'user id exposed';
    assert t !~ '"(role|team|won|userId|user_id|roomId|room_id|coPlayers|co_players)"', 'private key exposed: '||t;
    assert t !~ '"(mafia|town|citizen|doctor|detective)"', 'team or role value exposed: '||t;
    -- A caller never sees someone they blocked or who blocked them.
    insert into player_blocks(blocker_id,blocked_id) values(b,a);
    s := public.council_leaderboard(b);
    assert not exists(select 1 from jsonb_array_elements(s->'entries') e where (e->>'xp')::int=100), 'blocked shown';
    s := public.council_leaderboard(a);
    assert (select count(*) from jsonb_array_elements(s->'entries'))=2, 'blocker shown to blocked: '||s::text;
    assert (s->'me'->>'position')::int=1, s::text;
    -- No XP this week: listed nowhere, own position null.
    s := public.council_leaderboard(pg_temp.cl_user());
    assert s->'me'->'position'='null'::jsonb and (s->'me'->>'xp')::int=0, s::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C7 leaderboard', sqlerrm);
  end;
end $$;

-- C8. Invites: anti-farm guards, payment only after a completed match, once
do $$
declare a uuid; b uuid; x uuid; code text; code_b text; s jsonb; bal_a bigint; bal_b bigint; i int;
begin
  begin
    perform pg_temp.cl_enable();
    a := pg_temp.cl_user('30 days'); b := pg_temp.cl_user();
    s := public.council_invite(a);
    code := s->>'code';
    assert code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$', s::text;
    assert public.council_invite(a)->>'code'=code, 'code changed';
    assert not (s->>'canRedeem')::boolean, 'old account may redeem';
    assert (public.council_invite(b)->>'canRedeem')::boolean, 'new account may not redeem';
    -- Own code; lowercase and spaces are the same code.
    begin perform public.redeem_council_invite(a,code); assert false;
    exception when others then assert sqlerrm='INVITE_SELF', 'self: '||sqlerrm; end;
    s := public.redeem_council_invite(b,' '||lower(code)||' ');
    assert s->>'status'='redeemed' and not (s->>'canRedeem')::boolean, s::text;
    s := public.redeem_council_invite(b,code);
    assert s->>'status'='redeemed', 'retry: '||s::text;
    code_b := public.council_invite(b)->>'code';
    x := pg_temp.cl_user();
    begin perform public.redeem_council_invite(b,public.council_invite(x)->>'code'); assert false;
    exception when others then assert sqlerrm='INVITE_ALREADY', 'second code: '||sqlerrm; end;
    -- A mutual pair is refused.
    x := pg_temp.cl_user();
    insert into council_invite_redemptions(invitee,inviter,code) values(a,x,'AAAAAAA');
    begin perform public.redeem_council_invite(x,public.council_invite(a)->>'code'); assert false;
    exception when others then assert sqlerrm in ('INVITE_LOOP','INVITE_EXPIRED'), 'loop: '||sqlerrm; end;
    delete from council_invite_redemptions where invitee=a;
    -- Older than seven days; already played a match.
    x := pg_temp.cl_user('8 days');
    begin perform public.redeem_council_invite(x,code); assert false;
    exception when others then assert sqlerrm='INVITE_EXPIRED', 'expired: '||sqlerrm; end;
    x := pg_temp.cl_user(); perform pg_temp.cl_match(x);
    begin perform public.redeem_council_invite(x,code); assert false;
    exception when others then assert sqlerrm='INVITE_NOT_NEW', 'not new: '||sqlerrm; end;
    -- Guessing is rate limited, and the misses are kept.
    x := pg_temp.cl_user();
    for i in 1..10 loop
      assert public.redeem_council_invite(x,'ZZZZZZ'||i)->>'status'='not_found';
    end loop;
    begin perform public.redeem_council_invite(x,code); assert false;
    exception when others then assert sqlerrm='INVITE_RATE_LIMIT', 'rate: '||sqlerrm; end;
    -- Nothing is paid until the invitee completes an online match.
    bal_a := pg_temp.cl_balance(a); bal_b := pg_temp.cl_balance(b);
    s := public.council_invite(a);
    assert (s->>'pending')::int=1 and (s->>'rewarded')::int=0, s::text;
    assert pg_temp.cl_balance(a)=bal_a and pg_temp.cl_balance(b)=bal_b, 'paid before a match';
    perform pg_temp.cl_room(b, array[b,x], array['citizen','mafia'], null);
    perform public.council_invite(b);
    assert pg_temp.cl_balance(a)=bal_a, 'paid during a live match';
    perform pg_temp.cl_match(b);
    bal_b := pg_temp.cl_balance(b);
    -- Settled from the inviter's side as well as the invitee's.
    s := public.council_invite(a);
    assert (s->>'rewarded')::int=1 and (s->>'pending')::int=0, s::text;
    assert pg_temp.cl_balance(a)=bal_a+100 and pg_temp.cl_balance(b)=bal_b+50, 'rewards';
    perform public.council_invite(b); perform public.council_contracts(a); perform public.council_rank(b);
    assert pg_temp.cl_balance(a)=bal_a+100 and pg_temp.cl_balance(b)=bal_b+50, 'rewards replayed';
    assert (s->'redeemed') = 'null'::jsonb, 'inviter shown as redeemed';
    assert (public.council_invite(b)->'redeemed'->>'rewarded')::boolean;
    -- Cap: once the inviter has been paid for `cap` invites, new ones are refused.
    update economy_config set council_invite_cap=1;
    x := pg_temp.cl_user();
    begin perform public.redeem_council_invite(x,code); assert false;
    exception when others then assert sqlerrm='INVITE_LIMIT', 'cap: '||sqlerrm; end;
    -- A pending invite settled after the cap pays the invitee only.
    update economy_config set council_invite_cap=2;
    perform public.redeem_council_invite(x,code);
    update economy_config set council_invite_cap=1;
    perform pg_temp.cl_match(x);
    bal_a := pg_temp.cl_balance(a); bal_b := pg_temp.cl_balance(x);
    perform public.council_invite(x);
    assert pg_temp.cl_balance(a)=bal_a and pg_temp.cl_balance(x)=bal_b+50, 'cap not applied at payout';
    assert not (select inviter_paid from council_invite_redemptions where invitee=x);
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C8 invite anti-farm', sqlerrm);
  end;
end $$;

-- C9. Starter Bundle: once per account, debt and refund, tombstones --------
do $$
declare u uuid; v uuid; tag text; s jsonb; w public.wallet_accounts; p jsonb;
begin
  begin
    u := pg_temp.cl_user(); v := pg_temp.cl_user(); tag := public.account_tag(u);
    update play_products set active=true where product_id='mm_starter_bundle';
    -- Offered only with its flag on.
    assert not exists(select 1 from jsonb_array_elements(public.economy_capabilities(u)->'products') e
      where e->>'id'='mm_starter_bundle'), 'bundle offered while off';
    perform pg_temp.cl_enable();
    select e into p from jsonb_array_elements(public.economy_capabilities(u)->'products') e
      where e->>'id'='mm_starter_bundle';
    assert p->>'kind'='bundle' and (p->>'coins')::int=600 and p->>'item'='frame_council_seal', 'product: '||coalesce(p::text,'none');
    assert not exists(select 1 from reward_catalog where code='frame_council_seal' and active),
      'seal sold for coins';
    begin perform public.commit_play_product(u,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','active',now(),1,null); assert false;
    exception when others then assert sqlerrm='ACCOUNT_MISMATCH', 'untagged: '||sqlerrm; end;
    begin perform public.commit_play_product(u,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','active',now(),1,public.account_tag(v)); assert false;
    exception when others then assert sqlerrm='ACCOUNT_MISMATCH', 'wrong tag: '||sqlerrm; end;
    begin perform public.commit_play_product(u,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','active',now(),2,tag); assert false;
    exception when others then assert sqlerrm='INVALID_PURCHASE', 'quantity: '||sqlerrm; end;
    w := (select x from wallet_accounts x where user_id=u);
    s := public.commit_play_product(u,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','pending',now(),1,tag);
    assert not (s->>'granted')::boolean and pg_temp.cl_balance(u)=coalesce(w.balance,0), 'pending granted';
    s := public.commit_play_product(u,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','active',now(),1,tag);
    assert (s->>'granted')::boolean and (s->>'credited')::int=600 and (s->>'needsAcknowledge')::boolean
      and not (s->>'needsConsume')::boolean, s::text;
    s := public.commit_play_product(u,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','active',now(),1,tag);
    assert pg_temp.cl_balance(u)=coalesce(w.balance,0)+600, 'credited twice';
    assert (select purchased_balance from wallet_accounts where user_id=u)=600;
    assert public.user_owns_item(u,'frame_council_seal'), 'seal not granted';
    perform public.equip_reward_item(u,'frame','frame_council_seal');
    s := public.economy_capabilities(u);
    assert (s->'council'->>'starterBundleOwned')::boolean and not exists(
      select 1 from jsonb_array_elements(s->'products') e where e->>'id'='mm_starter_bundle'), 'still offered';
    -- Once per account: a second purchase grants nothing and is left
    -- unacknowledged for Play to refund.
    s := public.commit_play_product(u,'cl-bundle-token-bbbb','mm_starter_bundle','GPA.B2','active',now(),1,tag);
    assert (s->>'alreadyOwned')::boolean and not (s->>'granted')::boolean
      and not (s->>'needsAcknowledge')::boolean and pg_temp.cl_balance(u)=coalesce(w.balance,0)+600, s::text;
    -- Another account cannot take it over.
    begin perform public.commit_play_product(v,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','active',now(),1,public.account_tag(v)); assert false;
    exception when others then assert sqlerrm='ACCOUNT_MISMATCH', 'takeover: '||sqlerrm; end;
    -- Refund after spending 200: 400 unspent leaves, 200 becomes debt, the
    -- seal goes (and is unequipped), earned coins stay.
    update wallet_accounts set balance=balance-200, purchased_balance=purchased_balance-200 where user_id=u;
    update wallet_accounts set balance=balance+75, lifetime_earned=lifetime_earned+75 where user_id=u;
    w := (select x from wallet_accounts x where user_id=u);
    assert public.revoke_voided_play_purchases(array['cl-bundle-token-aaaa'],null)=1, 'void count';
    assert public.revoke_voided_play_purchases(array['cl-bundle-token-aaaa'],null)=0, 'void not idempotent';
    assert (select balance from wallet_accounts where user_id=u)=w.balance-400
      and (select purchase_debt from wallet_accounts where user_id=u)=200, 'refund split';
    assert not public.user_owns_item(u,'frame_council_seal')
      and not exists(select 1 from player_equipment where user_id=u and item_code='frame_council_seal'), 'seal kept';
    s := public.commit_play_product(u,'cl-bundle-token-aaaa','mm_starter_bundle','GPA.B1','active',now(),1,tag);
    assert not (s->>'granted')::boolean and s->>'state'='revoked', 'voided came back: '||s::text;
    -- After the refund the account may buy again; the debt is paid first.
    s := public.commit_play_product(u,'cl-bundle-token-bbbb','mm_starter_bundle','GPA.B2','active',now(),1,tag);
    assert (s->>'granted')::boolean and (s->>'credited')::int=400, 'rebuy: '||s::text;
    assert (select purchase_debt from wallet_accounts where user_id=u)=0
      and (select debt_offset from play_purchases where purchase_token='cl-bundle-token-bbbb')=200;
    -- Google reporting it cancelled reverses it on verify; the debt it paid returns.
    w := (select x from wallet_accounts x where user_id=u);
    s := public.commit_play_product(u,'cl-bundle-token-bbbb','mm_starter_bundle','GPA.B2','revoked',now(),1,tag);
    assert (select balance from wallet_accounts where user_id=u)=w.balance-400
      and (select purchase_debt from wallet_accounts where user_id=u)=200, 'cancel on verify';
    assert not public.user_owns_item(u,'frame_council_seal');
    -- Voided before its first verify: never granted.
    perform public.revoke_voided_play_purchases(null, array['GPA.B3']);
    s := public.commit_play_product(v,'cl-bundle-token-cccc','mm_starter_bundle','GPA.B3','active',now(),1,public.account_tag(v));
    assert s->>'state'='revoked' and not (s->>'granted')::boolean and pg_temp.cl_balance(v)=0, s::text;
    -- Coin packs still take the original path.
    s := public.commit_play_product(v,'cl-coins-token-dddd','mm_coins_500','GPA.B4','active',now(),1,public.account_tag(v));
    assert (s->>'kind')='coins' and (s->>'credited')::int=500, s::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C9 starter bundle', sqlerrm);
  end;
end $$;

-- C10. No read reveals a role, and nothing moves during a live match ------
do $$
declare p uuid; q uuid; r uuid; before jsonb; after jsonb; t text;
begin
  begin
    perform pg_temp.cl_enable();
    p := pg_temp.cl_user(); q := pg_temp.cl_user();
    perform pg_temp.cl_room(q, array[q,p], array['citizen','citizen'], 'town');
    -- A live match with roles dealt: every read is identical to before.
    r := pg_temp.cl_room(p, array[p,q], array[null,null], null);
    update rooms set status='lobby' where id=r;
    before := jsonb_build_object('c',public.council_contracts(p),'r',public.council_rank(p),
      'l',public.council_leaderboard(q),'i',public.council_invite(p),'k',public.economy_capabilities(p)->'council');
    update rooms set status='playing' where id=r;
    update room_players set role='mafia' where room_id=r and user_id=p;
    update room_players set role='detective' where room_id=r and user_id=q;
    update room_state set public_data=jsonb_build_object('phase','night') where room_id=r;
    after := jsonb_build_object('c',public.council_contracts(p),'r',public.council_rank(p),
      'l',public.council_leaderboard(q),'i',public.council_invite(p),'k',public.economy_capabilities(p)->'council');
    assert before=after, 'a read changed during a live match';
    t := (after - 'c')::text || (public.council_contracts(p) - 'contracts')::text;
    assert t !~ '"(role|team|won|userId|user_id|roomId|room_id|coPlayers|co_players|hosted|reunion)"', 'private key: '||t;
    assert t !~ '"(mafia|town|citizen|doctor|detective)"', 'role or team value: '||t;
    assert position(p::text in t)=0 and position(q::text in t)=0, 'user id exposed';
    -- Contract entries carry only the contract, never the match.
    assert not exists(select 1 from jsonb_array_elements(after->'c'->'contracts') e, jsonb_object_keys(e) k
      where k not in ('slot','code','metric','target','coins','progress','claimed','claimable')), 'contract keys';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C10 no role data exposed', sqlerrm);
  end;
end $$;

-- C11. Client roles cannot reach the new surface; deletion covers it ------
do $$
declare f record; t text; bad text := ''; u uuid; req uuid;
begin
  begin
    for f in
      select p.oid::regprocedure::text as sig, p.prosecdef, p.proconfig
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and (p.proname like 'council\_%' or p.proname in (
         'claim_council_contract','claim_council_weekly','redeem_council_invite',
         'owns_starter_bundle','reverse_play_bundle','commit_play_bundle',
         'commit_play_product','commit_play_product_base','revoke_voided_play_purchases',
         'revoke_voided_play_purchases_base','economy_capabilities','economy_capabilities_base',
         'complete_data_deletion','purge_orphan_economy','set_council_leaderboard_visible',
         'seat_cosmetics'))
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
    foreach t in array array['council_match_records','council_xp_events','council_identity',
        'council_contract_catalog','council_daily_contracts','council_rank_tiers',
        'council_invite_codes','council_invite_redemptions','council_invite_attempts',
        'council_preferences'] loop
      if has_table_privilege('anon','public.'||t,'select,insert,update,delete')
         or has_table_privilege('authenticated','public.'||t,'select,insert,update,delete') then
        bad := bad||' table:'||t;
      end if;
    end loop;
    assert bad='', 'exposed:'||bad;
    assert (select count(*) from pg_proc where proname in ('commit_play_product','economy_capabilities',
      'revoke_voided_play_purchases'))=3, 'wrapped entry point duplicated';
    -- Deletion removes every council row for the account.
    perform pg_temp.cl_enable();
    u := pg_temp.cl_user();
    perform public.council_invite(u);
    perform pg_temp.cl_match(u);
    perform public.council_contracts(u);
    insert into data_deletion_requests(user_id) values(u) returning id into req;
    perform public.complete_data_deletion(req);
    assert not exists(select 1 from council_match_records where user_id=u)
      and not exists(select 1 from council_xp_events where user_id=u)
      and not exists(select 1 from council_identity where user_id=u)
      and not exists(select 1 from council_daily_contracts where user_id=u)
      and not exists(select 1 from council_invite_codes where user_id=u), 'council rows survived deletion';
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C11 surface and deletion', sqlerrm);
  end;
end $$;

-- C12. Leaderboard opt-out: hidden players never appear, still see themselves
do $$
declare a uuid; b uuid; s jsonb;
begin
  begin
    perform pg_temp.cl_enable();
    a := pg_temp.cl_user(); b := pg_temp.cl_user();
    perform pg_temp.cl_room(a, array[a,b], array['citizen','mafia'], 'town');
    assert (public.council_rank(a)->>'leaderboardVisible')::boolean, 'default visible';
    s := public.set_council_leaderboard_visible(a, false);
    assert s->'leaderboardVisible'='false'::jsonb, s::text;
    s := public.council_leaderboard(b);
    assert (select count(*) from jsonb_array_elements(s->'entries'))=1
      and (s->'me'->>'position')::int=1, 'hidden player shown or ranked: '||s::text;
    s := public.council_leaderboard(a);
    assert not exists(select 1 from jsonb_array_elements(s->'entries') e where (e->>'me')::boolean),
      'hidden caller listed';
    assert (s->'me'->>'position')::int=1 and (s->'me'->>'xp')::int=50 and s->'visible'='false'::jsonb,
      'hidden caller lost their position: '||s::text;
    assert not (public.council_rank(a)->>'leaderboardVisible')::boolean;
    perform public.set_council_leaderboard_visible(a, true);
    assert (select count(*) from jsonb_array_elements(public.council_leaderboard(b)->'entries'))=2, 'back on';
    begin perform public.set_council_leaderboard_visible(a, null); assert false;
    exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C12 leaderboard opt-out', sqlerrm);
  end;
end $$;

-- C13. The seat carries the level, fixed at join, and only while rank is on
do $$
declare a uuid; b uuid; r uuid; c jsonb;
begin
  begin
    a := pg_temp.cl_user(); b := pg_temp.cl_user();
    perform pg_temp.cl_enable();
    for r in select pg_temp.cl_match(a) from generate_series(1,2) loop end loop;
    update economy_config set council_rank_enabled=false;
    r := pg_temp.cl_room(a, array[a], array[null], null);
    assert not ((select cosmetics from room_players where room_id=r and user_id=a) ? 'rank'), 'rank while off';
    update economy_config set council_rank_enabled=true;
    r := pg_temp.cl_room(a, array[a,b], array[null,null], null);
    c := (select cosmetics from room_players where room_id=r and user_id=a);
    assert (c->>'rank')::int=2, 'level 2 after 100 XP: '||c::text;
    assert (select (cosmetics->>'rank')::int from room_players where room_id=r and user_id=b)=1, 'newcomer';
    -- Nothing during the match moves it, and it carries no role.
    update room_players set role='mafia' where room_id=r and user_id=a;
    perform pg_temp.cl_match(a); perform pg_temp.cl_match(a);
    assert (select cosmetics from room_players where room_id=r and user_id=a)=c, 'seat changed mid-match';
    assert c::text !~ '(mafia|citizen|doctor|detective|town|role|team)', c::text;
    raise exception 'GATE_OK';
  exception when assert_failure or others then perform pg_temp.cl_record('C13 seat rank', sqlerrm);
  end;
end $$;

-- Report ----------------------------------------------------------------
do $$
declare failed text;
begin
  select string_agg(gate||' => '||detail, ' | ' order by gate) into failed
    from cl_results where not ok;
  if (select count(*) from cl_results) <> 13 then
    raise exception 'COUNCIL GATES INCOMPLETE: % recorded', (select count(*) from cl_results);
  end if;
  if failed is not null then raise exception 'COUNCIL GATES FAILED: %', failed; end if;
end $$;
rollback;
